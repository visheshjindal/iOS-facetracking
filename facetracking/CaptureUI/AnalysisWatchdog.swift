import Foundation

protocol ScheduledCancellation: AnyObject, Sendable {
    func cancel()
}

protocol MonotonicScheduling: Sendable {
    func schedule(afterMilliseconds delayMS: Int64, action: @escaping @Sendable () -> Void) -> ScheduledCancellation
}

private final class DispatchCancellation: ScheduledCancellation, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    var isCancelled: Bool { lock.withLock { cancelled } }
}

struct SystemMonotonicScheduler: MonotonicScheduling {
    func schedule(
        afterMilliseconds delayMS: Int64,
        action: @escaping @Sendable () -> Void
    ) -> ScheduledCancellation {
        let token = DispatchCancellation()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(max(0, delayMS)))) {
            guard !token.isCancelled else { return }
            action()
        }
        return token
    }
}

@MainActor
final class AnalysisWatchdog {
    private let clock: any MonotonicClock
    private let scheduler: any MonotonicScheduling
    private let configuration: TrackingConfiguration
    private var watchdog: (sessionID: UInt64, token: ScheduledCancellation)?
    private var freshness: (sessionID: UInt64, token: ScheduledCancellation)?
    var onEvent: ((SessionEvent) -> Void)?

    init(
        clock: any MonotonicClock,
        scheduler: any MonotonicScheduling,
        configuration: TrackingConfiguration = .provisional
    ) {
        self.clock = clock
        self.scheduler = scheduler
        self.configuration = configuration
    }

    func start(sessionID: UInt64) {
        cancelWatchdog()
        scheduleWatchdogTick(sessionID: sessionID)
    }

    func cancel(sessionID: UInt64) {
        if watchdog?.sessionID == sessionID { cancelWatchdog() }
        if freshness?.sessionID == sessionID { cancelFreshness() }
    }

    func scheduleFreshness(sessionID: UInt64, expectedSampleMS: Int64) {
        cancelFreshness()
        let firstExpiredMS = expectedSampleMS + configuration.timing.faceFreshnessMS + 1
        let delay = max(0, firstExpiredMS - clock.nowMilliseconds())
        let token = scheduler.schedule(afterMilliseconds: delay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.freshness?.sessionID == sessionID else { return }
                self.onEvent?(.freshnessExpired(
                    sessionID: sessionID,
                    expectedSampleMS: expectedSampleMS,
                    atMS: self.clock.nowMilliseconds()
                ))
            }
        }
        freshness = (sessionID, token)
    }

    func cancelFreshness(sessionID: UInt64) {
        if freshness?.sessionID == sessionID { cancelFreshness() }
    }

    private func scheduleWatchdogTick(sessionID: UInt64) {
        let token = scheduler.schedule(afterMilliseconds: configuration.timing.watchdogCadenceMS) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.watchdog?.sessionID == sessionID else { return }
                self.onEvent?(.watchdogFired(sessionID: sessionID, atMS: self.clock.nowMilliseconds()))
                guard self.watchdog?.sessionID == sessionID else { return }
                self.scheduleWatchdogTick(sessionID: sessionID)
            }
        }
        watchdog = (sessionID, token)
    }

    private func cancelWatchdog() {
        watchdog?.token.cancel()
        watchdog = nil
    }

    private func cancelFreshness() {
        freshness?.token.cancel()
        freshness = nil
    }

    deinit {
        watchdog?.token.cancel()
        freshness?.token.cancel()
    }
}
