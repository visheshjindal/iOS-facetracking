import XCTest
@testable import facetracking

@MainActor
final class AnalysisWatchdogTests: XCTestCase {
    func testWatchdogDoesNotFailAt5000AndFiresAtFirstLaterCadence5250() {
        let clock = SchedulerClock()
        let scheduler = TestMonotonicScheduler(clock: clock)
        let watchdog = AnalysisWatchdog(clock: clock, scheduler: scheduler)
        var events: [SessionEvent] = []
        watchdog.onEvent = { events.append($0) }
        watchdog.start(sessionID: 4)

        scheduler.advance(to: 5_000)
        XCTAssertEqual(events.last, .watchdogFired(sessionID: 4, atMS: 5_000))
        scheduler.advance(to: 5_250)
        XCTAssertEqual(events.last, .watchdogFired(sessionID: 4, atMS: 5_250))
    }

    func testFreshnessFiresAt301AndCancellationStopsBothTimers() {
        let clock = SchedulerClock()
        let scheduler = TestMonotonicScheduler(clock: clock)
        let watchdog = AnalysisWatchdog(clock: clock, scheduler: scheduler)
        var events: [SessionEvent] = []
        watchdog.onEvent = { events.append($0) }
        watchdog.start(sessionID: 9)
        watchdog.scheduleFreshness(sessionID: 9, expectedSampleMS: 0)
        scheduler.advance(to: 300)
        XCTAssertFalse(events.contains { if case .freshnessExpired = $0 { true } else { false } })
        scheduler.advance(to: 301)
        XCTAssertTrue(events.contains(.freshnessExpired(sessionID: 9, expectedSampleMS: 0, atMS: 301)))

        watchdog.cancel(sessionID: 9)
        let count = events.count
        scheduler.advance(to: 6_000)
        XCTAssertEqual(events.count, count)
    }
}

private final class SchedulerClock: MonotonicClock, @unchecked Sendable {
    var value: Int64 = 0
    func nowMilliseconds() -> Int64 { value }
}

private final class TestScheduledCancellation: ScheduledCancellation, @unchecked Sendable {
    var cancelled = false
    func cancel() { cancelled = true }
}

private final class TestMonotonicScheduler: MonotonicScheduling, @unchecked Sendable {
    struct Item { let deadline: Int64; let token: TestScheduledCancellation; let action: @Sendable () -> Void }
    let clock: SchedulerClock
    var items: [Item] = []
    init(clock: SchedulerClock) { self.clock = clock }
    func schedule(afterMilliseconds delayMS: Int64, action: @escaping @Sendable () -> Void) -> ScheduledCancellation {
        let token = TestScheduledCancellation()
        items.append(Item(deadline: clock.value + delayMS, token: token, action: action))
        return token
    }
    func advance(to target: Int64) {
        while let index = items.indices.filter({ !items[$0].token.cancelled && items[$0].deadline <= target })
            .min(by: { items[$0].deadline < items[$1].deadline }) {
            let item = items.remove(at: index)
            clock.value = item.deadline
            if !item.token.cancelled { item.action() }
        }
        clock.value = target
    }
}
