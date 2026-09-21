import Foundation

/// A capacity-one, newest-wins channel. Scheduling is explicit so a frame flood
/// can enqueue at most one drain callback and one pending owned observation.
final class ObservationMailbox: @unchecked Sendable {
    typealias Scheduler = @Sendable (@escaping @Sendable () -> Void) -> Void
    typealias Consumer = @Sendable (FrameObservation) -> Void

    private let lock = NSLock()
    private let scheduler: Scheduler
    private var consumer: Consumer?
    private var pending: FrameObservation?
    private var drainScheduled = false

    init(scheduler: @escaping Scheduler) {
        self.scheduler = scheduler
    }

    func activate(consumer: @escaping Consumer) {
        lock.withLock {
            self.consumer = consumer
            pending = nil
            drainScheduled = false
        }
    }

    func invalidate() {
        lock.withLock {
            consumer = nil
            pending = nil
            drainScheduled = false
        }
    }

    func publish(_ observation: FrameObservation) {
        let shouldSchedule = lock.withLock { () -> Bool in
            guard consumer != nil else { return false }
            pending = observation
            guard !drainScheduled else { return false }
            drainScheduled = true
            return true
        }
        if shouldSchedule { scheduler { [weak self] in self?.drain() } }
    }

    private func drain() {
        let delivery = lock.withLock { () -> (Consumer, FrameObservation)? in
            guard let consumer, let pending else {
                drainScheduled = false
                return nil
            }
            self.pending = nil
            return (consumer, pending)
        }
        guard let (consumer, observation) = delivery else { return }
        consumer(observation)

        let shouldReschedule = lock.withLock { () -> Bool in
            guard consumer != nil, pending != nil else {
                drainScheduled = false
                return false
            }
            return true
        }
        if shouldReschedule { scheduler { [weak self] in self?.drain() } }
    }
}
