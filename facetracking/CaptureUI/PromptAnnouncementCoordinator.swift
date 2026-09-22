import UIKit

@MainActor
protocol AccessibilityAnnouncing: AnyObject {
    func announce(_ message: String)
}

@MainActor
final class SystemAccessibilityAnnouncer: AccessibilityAnnouncing {
    func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

@MainActor
final class PromptAnnouncementCoordinator {
    static let minimumIntervalMS: Int64 = 1_200

    private let clock: any MonotonicClock
    private let scheduler: any MonotonicScheduling
    private let announcer: AccessibilityAnnouncing
    private var lastAnnouncedKey: String?
    private var lastAnnouncementMS: Int64?
    private var pending: (key: String, message: String, token: ScheduledCancellation)?

    init(
        clock: any MonotonicClock,
        scheduler: any MonotonicScheduling,
        announcer: AccessibilityAnnouncing = SystemAccessibilityAnnouncer()
    ) {
        self.clock = clock
        self.scheduler = scheduler
        self.announcer = announcer
    }

    func promptChanged(key: String, message: String) {
        guard key != pending?.key else { return }
        if key == lastAnnouncedKey {
            pending?.token.cancel()
            pending = nil
            return
        }
        pending?.token.cancel()
        pending = nil

        let now = clock.nowMilliseconds()
        guard let lastAnnouncementMS else {
            announce(key: key, message: message, atMS: now)
            return
        }
        let elapsed = max(0, now - lastAnnouncementMS)
        guard elapsed < Self.minimumIntervalMS else {
            announce(key: key, message: message, atMS: now)
            return
        }

        let delay = Self.minimumIntervalMS - elapsed
        let token = scheduler.schedule(afterMilliseconds: delay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.pending?.key == key else { return }
                self.pending = nil
                self.announce(key: key, message: message, atMS: self.clock.nowMilliseconds())
            }
        }
        pending = (key, message, token)
    }

    func cancel() {
        pending?.token.cancel()
        pending = nil
    }

    private func announce(key: String, message: String, atMS: Int64) {
        lastAnnouncedKey = key
        lastAnnouncementMS = atMS
        announcer.announce(message)
    }

    deinit {
        pending?.token.cancel()
    }
}
