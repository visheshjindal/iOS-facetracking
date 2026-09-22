import XCTest
@testable import facetracking

@MainActor
final class PromptAnnouncementCoordinatorTests: XCTestCase {
    func testU05FirstPromptIsImmediateAndDuplicateIsIgnored() {
        let fixture = AnnouncementFixture()

        fixture.coordinator.promptChanged(key: "position.center", message: "Center")
        fixture.coordinator.promptChanged(key: "position.center", message: "Center")

        XCTAssertEqual(fixture.announcer.messages, ["Center"])
        XCTAssertEqual(fixture.scheduler.pendingCount, 0)
    }

    func testU05RapidChangesCoalesceToLatestAtDocumentedCadence() {
        let fixture = AnnouncementFixture()
        fixture.coordinator.promptChanged(key: "position.center", message: "Center")

        fixture.clock.now = 200
        fixture.coordinator.promptChanged(key: "position.closer", message: "Closer")
        fixture.clock.now = 400
        fixture.coordinator.promptChanged(key: "position.hold", message: "Hold")

        XCTAssertEqual(fixture.announcer.messages, ["Center"])
        fixture.advance(to: 1_199)
        XCTAssertEqual(fixture.announcer.messages, ["Center"])
        fixture.advance(to: 1_200)
        XCTAssertEqual(fixture.announcer.messages, ["Center", "Hold"])
    }

    func testU05PromptAfterCadenceIsImmediate() {
        let fixture = AnnouncementFixture()
        fixture.coordinator.promptChanged(key: "position.center", message: "Center")
        fixture.clock.now = PromptAnnouncementCoordinator.minimumIntervalMS

        fixture.coordinator.promptChanged(key: "position.hold", message: "Hold")

        XCTAssertEqual(fixture.announcer.messages, ["Center", "Hold"])
    }

    func testU05ReturningToLastAnnouncedPromptCancelsStalePendingPrompt() {
        let fixture = AnnouncementFixture()
        fixture.coordinator.promptChanged(key: "position.center", message: "Center")
        fixture.clock.now = 200
        fixture.coordinator.promptChanged(key: "position.closer", message: "Closer")
        fixture.clock.now = 400
        fixture.coordinator.promptChanged(key: "position.center", message: "Center")

        fixture.advance(to: 1_200)

        XCTAssertEqual(fixture.announcer.messages, ["Center"])
        XCTAssertEqual(fixture.scheduler.pendingCount, 0)
    }
}

@MainActor
private final class AnnouncementFixture {
    let clock = AnnouncementClock()
    let scheduler: AnnouncementScheduler
    let announcer = AnnouncementRecorder()
    let coordinator: PromptAnnouncementCoordinator

    init() {
        scheduler = AnnouncementScheduler(clock: clock)
        coordinator = PromptAnnouncementCoordinator(clock: clock, scheduler: scheduler, announcer: announcer)
    }

    func advance(to timestamp: Int64) {
        clock.now = timestamp
        scheduler.runDue()
    }
}

private final class AnnouncementClock: MonotonicClock, @unchecked Sendable {
    var now: Int64 = 0
    func nowMilliseconds() -> Int64 { now }
}

private final class AnnouncementToken: ScheduledCancellation, @unchecked Sendable {
    var isCancelled = false
    func cancel() { isCancelled = true }
}

private final class AnnouncementScheduler: MonotonicScheduling, @unchecked Sendable {
    struct Item: @unchecked Sendable {
        let deadline: Int64
        let token: AnnouncementToken
        let action: @Sendable () -> Void
    }

    private let clock: AnnouncementClock
    private var items: [Item] = []
    var pendingCount: Int { items.filter { !$0.token.isCancelled }.count }

    init(clock: AnnouncementClock) { self.clock = clock }

    func schedule(afterMilliseconds delayMS: Int64, action: @escaping @Sendable () -> Void) -> ScheduledCancellation {
        let token = AnnouncementToken()
        items.append(Item(deadline: clock.now + delayMS, token: token, action: action))
        return token
    }

    func runDue() {
        let due = items.filter { $0.deadline <= clock.now }
        items.removeAll { $0.deadline <= clock.now }
        due.filter { !$0.token.isCancelled }.forEach { $0.action() }
    }
}

@MainActor
private final class AnnouncementRecorder: AccessibilityAnnouncing {
    private(set) var messages: [String] = []
    func announce(_ message: String) { messages.append(message) }
}
