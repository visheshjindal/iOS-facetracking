import XCTest
@testable import facetracking

final class ObservationMailboxTests: XCTestCase {
    func testCapacityOneNewestObservationReplacesPendingAndOnlyOneDrainIsScheduled() {
        let scheduler = MailboxScheduler()
        let mailbox = ObservationMailbox(scheduler: scheduler.schedule)
        let delivered = SendableBox<[Int64]>([])
        mailbox.activate { delivered.value.append($0.capturedAtMS) }

        for timestamp in 1...100 { mailbox.publish(observation(Int64(timestamp))) }
        XCTAssertEqual(scheduler.count, 1)
        scheduler.runNext()
        XCTAssertEqual(delivered.value, [100])
        XCTAssertEqual(scheduler.count, 0)
    }

    func testPublishDuringConsumptionSchedulesOneFollowupAndDeliversNewest() {
        let scheduler = MailboxScheduler()
        let mailbox = ObservationMailbox(scheduler: scheduler.schedule)
        let delivered = SendableBox<[Int64]>([])
        mailbox.activate { observation in
            delivered.value.append(observation.capturedAtMS)
            if observation.capturedAtMS == 1 {
                mailbox.publish(FrameObservation(sessionID: 1, geometryRevision: 1, capturedAtMS: 2, face: nil, lighting: nil))
                mailbox.publish(FrameObservation(sessionID: 1, geometryRevision: 1, capturedAtMS: 3, face: nil, lighting: nil))
            }
        }
        mailbox.publish(observation(1))
        scheduler.runAll()
        XCTAssertEqual(delivered.value, [1, 3])
    }

    func testInvalidateDropsPendingAndReleasesCapturedOwner() {
        final class Owner: @unchecked Sendable {}
        let scheduler = MailboxScheduler()
        let mailbox = ObservationMailbox(scheduler: scheduler.schedule)
        weak var weakOwner: Owner?
        do {
            let owner = Owner()
            weakOwner = owner
            mailbox.activate { _ in _ = owner }
            mailbox.publish(observation(1))
            mailbox.invalidate()
        }
        XCTAssertNil(weakOwner)
        scheduler.runAll()
    }

    private func observation(_ timestamp: Int64) -> FrameObservation {
        FrameObservation(sessionID: 1, geometryRevision: 1, capturedAtMS: timestamp, face: nil, lighting: nil)
    }
}

private final class SendableBox<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

private final class MailboxScheduler: @unchecked Sendable {
    private var actions: [@Sendable () -> Void] = []
    var count: Int { actions.count }
    func schedule(_ action: @escaping @Sendable () -> Void) { actions.append(action) }
    func runNext() { actions.removeFirst()() }
    func runAll() { while !actions.isEmpty { runNext() } }
}
