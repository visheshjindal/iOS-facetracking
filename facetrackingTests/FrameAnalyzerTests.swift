import CoreVideo
import ImageIO
import XCTest
@testable import facetracking

final class FrameAnalyzerTests: XCTestCase {
    func testInvalidFirstCandidateDoesNotHideLaterUsableCandidateAndMissingAngleMakesPoseNil() throws {
        let detector = DetectorDouble(results: [
            candidate(x: 0, y: 0, width: 0, height: 0, yaw: 0, pitch: 0, roll: 0),
            candidate(x: 0.25, y: 0.25, width: 0.5, height: 0.5, yaw: 0.1, pitch: nil, roll: 0.2)
        ])
        let harness = AnalyzerHarness(detector: detector)
        harness.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: 12.5)
        harness.scheduler.runAll()

        XCTAssertEqual(harness.observations.count, 1)
        XCTAssertNotNil(harness.observations[0].face)
        XCTAssertNil(harness.observations[0].face?.pose)
        XCTAssertNil(harness.observations[0].lighting)
        XCTAssertEqual(harness.analyzer.diagnostics.lastPresentationTimeSeconds, 12.5)
        XCTAssertEqual(detector.requestRevision, Int(VisionFaceDetector.pinnedRevision))
    }

    func testAllAnglesConvertFromRadiansToDegreesOnce() throws {
        let detector = DetectorDouble(results: [
            candidate(x: 0.25, y: 0.25, width: 0.5, height: 0.5, yaw: .pi / 2, pitch: -.pi / 4, roll: .pi)
        ])
        let harness = AnalyzerHarness(detector: detector)
        harness.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: nil)
        harness.scheduler.runAll()
        let pose = try XCTUnwrap(harness.observations.first?.face?.pose)
        XCTAssertEqual(pose.yawDegrees, 90, accuracy: 0.000_001)
        XCTAssertEqual(pose.pitchDegrees, -45, accuracy: 0.000_001)
        XCTAssertEqual(pose.rollDegrees, 180, accuracy: 0.000_001)
    }

    func testNoFaceIsSuccessfulObservationAndThrownRequestUsesReliableFailurePath() throws {
        let noFace = AnalyzerHarness(detector: DetectorDouble(results: []))
        noFace.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: nil)
        noFace.scheduler.runAll()
        XCTAssertEqual(noFace.observations.count, 1)
        XCTAssertNil(noFace.observations[0].face)
        XCTAssertTrue(noFace.failures.isEmpty)

        let throwing = AnalyzerHarness(detector: DetectorDouble(error: TestError.failed))
        throwing.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: nil)
        XCTAssertTrue(throwing.observations.isEmpty)
        XCTAssertEqual(throwing.failures, [.detectorUnavailable])
    }

    func testAnalysisCompletionAt300KeepsFaceAnd301WithdrawsIt() throws {
        for (elapsed, expectsFace) in [(300, true), (301, false)] {
            let clock = MutableClock(1_000)
            let detector = DetectorDouble(results: [candidate()], onDetect: { clock.value += Int64(elapsed) })
            let harness = AnalyzerHarness(detector: detector, clock: clock)
            harness.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: nil)
            harness.scheduler.runAll()
            XCTAssertEqual(harness.observations.first?.face != nil, expectsFace)
            XCTAssertEqual(harness.observations.first?.capturedAtMS, 1_000)
            XCTAssertEqual(harness.observations.first?.resultAtMS, 1_000 + Int64(elapsed))
        }
    }

    func testInvalidatedGenerationDropsInFlightCompletion() throws {
        let clock = MutableClock(1_000)
        var harness: AnalyzerHarness!
        let detector = DetectorDouble(results: [candidate()], onDetect: { harness.analyzer.invalidate(sessionID: 7) })
        harness = AnalyzerHarness(detector: detector, clock: clock)
        harness.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: nil)
        harness.scheduler.runAll()
        XCTAssertTrue(harness.observations.isEmpty)
        XCTAssertTrue(harness.failures.isEmpty)
    }

    func testSameFrameSupportedLumaProducesMetricsAndStaleCompletionWithdrawsBothPayloads() throws {
        let fresh = AnalyzerHarness(detector: DetectorDouble(results: [candidate()]))
        fresh.analyzer.analyze(pixelBuffer: try fullRangePixelBuffer(luma: 100), presentationTimeSeconds: nil)
        fresh.scheduler.runAll()
        let metrics = try XCTUnwrap(fresh.observations.first?.lighting)
        XCTAssertEqual(metrics.median, 100)
        XCTAssertLessThanOrEqual(metrics.totalCount, 4_096)
        XCTAssertEqual(fresh.analyzer.diagnostics.lastLumaSampling?.range, .full)

        let clock = MutableClock(1_000)
        let stale = AnalyzerHarness(
            detector: DetectorDouble(results: [candidate()], onDetect: { clock.value = 1_301 }),
            clock: clock
        )
        stale.analyzer.analyze(pixelBuffer: try fullRangePixelBuffer(luma: 100), presentationTimeSeconds: nil)
        stale.scheduler.runAll()
        XCTAssertNil(stale.observations.first?.face)
        XCTAssertNil(stale.observations.first?.lighting)
    }

    // G01/G02: buffers are already portrait, including sensors needing 270°.
    func testPhysicallyOrientedBuffersAreNeverRotatedAgainForAnySensorAngle() throws {
        for angle in [0.0, 90.0, 180.0, 270.0] {
            let detector = DetectorDouble(results: [candidate(x: 0.1, y: 0.2, width: 0.2, height: 0.3)])
            let harness = AnalyzerHarness(detector: detector, outputRotationDegrees: angle)
            harness.analyzer.analyze(pixelBuffer: try pixelBuffer(), presentationTimeSeconds: nil)
            harness.scheduler.runAll()
            XCTAssertEqual(detector.orientations, [.up])
            let box = try XCTUnwrap(harness.observations.first?.face?.geometry)
            // 480×640 buffer and viewport: only lower-left conversion + one mirror.
            XCTAssertEqual(box.centerX, 0.8, accuracy: 0.000_001)
            XCTAssertEqual(box.centerY, 0.65, accuracy: 0.000_001)
            XCTAssertEqual(box.width, 0.2, accuracy: 0.000_001)
            XCTAssertEqual(box.height, 0.3, accuracy: 0.000_001)
        }
    }

    // F04/F05/P02: exercise real mapping before positioning, not a pre-mapped face.
    func testPortraitDetectionReachesHoldAndAcquiresAtTwoSeconds() throws {
        // Target is 320/1.35 points wide × 320 high. Face is 80% on both axes.
        let width = 32.0 / 81.0
        let detector = DetectorDouble(results: [candidate(x: (1 - width) / 2, y: 0.3, width: width, height: 0.4)])
        let clock = MutableClock(0)
        let harness = AnalyzerHarness(detector: detector, clock: clock, outputRotationDegrees: 270)
        let buffer = try pixelBuffer()
        var history = PositioningHistory.empty
        let target = PreviewGeometry.target(viewportWidthPoints: 480, viewportHeightPoints: 640)
        for timestamp: Int64 in [0, 250, 500, 750, 1_000, 1_250, 1_500, 1_750, 1_999, 2_000] {
            clock.value = timestamp
            harness.analyzer.analyze(pixelBuffer: buffer, presentationTimeSeconds: nil)
            harness.scheduler.runAll()
            let observation = try XCTUnwrap(harness.observations.last)
            let result = PositioningRules.update(history: history, stage: .aligning, target: target,
                                                 face: observation.face, timestampMS: timestamp)
            history = result.history
            XCTAssertEqual(result.hint, timestamp < 2_000 ? .holdStill : .following)
            XCTAssertEqual(result.stage, timestamp < 2_000 ? .aligning : .following)
        }
    }

    // G02/L04/L08/L10: real Y-plane sampling -> mirrored mapping -> reducer -> advice.
    func testLightingChangesFromRightToLeftEvenDarkAndBrightThroughPixelPipeline() throws {
        let width = 32.0 / 81.0
        let detector = DetectorDouble(results: [candidate(x: (1 - width) / 2, y: 0.3, width: width, height: 0.4)])
        let clock = MutableClock(0)
        let harness = AnalyzerHarness(detector: detector, clock: clock, sessionID: 1, geometryRevision: 1)
        var state = SessionState()
        for event in [SessionEvent.routePresenceChanged(isPresent: true, atMS: 0),
                      .sceneActivityChanged(isActive: true, atMS: 0),
                      .authorizationChanged(.authorized, atMS: 0),
                      .viewportChanged(SessionViewport(widthPoints: 480, heightPoints: 640, transformRevision: 0), atMS: 0)] {
            state = SessionTransition.reduce(state: state, event: event).state
        }
        func process(_ time: Int64, rawLeft: UInt8, rawRight: UInt8) throws -> CaptureGuidanceProjection {
            clock.value = time
            harness.analyzer.analyze(pixelBuffer: try fullRangePixelBuffer(luma: rawLeft, rightLuma: rawRight), presentationTimeSeconds: nil)
            harness.scheduler.runAll()
            let observation = try XCTUnwrap(harness.observations.last)
            XCTAssertNotNil(observation.lighting)
            state = SessionTransition.reduce(state: state, event: .observation(observation)).state
            return GuidanceRules.project(session: state)
        }
        for time in stride(from: Int64(0), through: 2_000, by: 250) {
            _ = try process(time, rawLeft: 100, rawRight: 100)
        }
        XCTAssertEqual(state.stage, .following)
        // Preview mirrors once: dark raw LEFT becomes dark screen RIGHT.
        for time: Int64 in [2_200, 2_400, 2_600] { _ = try process(time, rawLeft: 60, rawRight: 140) }
        XCTAssertEqual(GuidanceRules.project(session: state).primary, .lighting(.addLightRight))
        let changingSide = try process(2_800, rawLeft: 140, rawRight: 60)
        XCTAssertEqual(changingSide.primary, .positioning(.following))
        XCTAssertEqual(changingSide.badge?.advice, .checking)
        for time: Int64 in [3_000, 3_200] { _ = try process(time, rawLeft: 140, rawRight: 60) }
        XCTAssertEqual(GuidanceRules.project(session: state).primary, .lighting(.addLightLeft))
        _ = try process(3_400, rawLeft: 100, rawRight: 100)
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.advice, .checking)
        for time: Int64 in [3_650, 3_900, 4_100] { _ = try process(time, rawLeft: 100, rawRight: 100) }
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.advice, .acceptable)
        for time: Int64 in [4_300, 4_500, 4_700] { _ = try process(time, rawLeft: 30, rawRight: 30) }
        XCTAssertEqual(GuidanceRules.project(session: state).primary, .lighting(.addMoreLight))
        for time: Int64 in [4_900, 5_100, 5_300] { _ = try process(time, rawLeft: 220, rawRight: 220) }
        XCTAssertEqual(GuidanceRules.project(session: state).primary, .lighting(.reduceDirectLight))
        XCTAssertEqual(state.stage, .following)
    }

    private static func candidate(
        x: Double = 0.25, y: Double = 0.25, width: Double = 0.5, height: Double = 0.5,
        yaw: Double? = 0, pitch: Double? = 0, roll: Double? = 0
    ) -> DetectedFaceCandidate {
        DetectedFaceCandidate(
            bounds: VisionNormalizedRect(x: x, y: y, width: width, height: height),
            yawRadians: yaw, pitchRadians: pitch, rollRadians: roll
        )
    }

    private func candidate(
        x: Double = 0.25, y: Double = 0.25, width: Double = 0.5, height: Double = 0.5,
        yaw: Double? = 0, pitch: Double? = 0, roll: Double? = 0
    ) -> DetectedFaceCandidate { Self.candidate(x: x, y: y, width: width, height: height, yaw: yaw, pitch: pitch, roll: roll) }

    private func pixelBuffer() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 480, 640, kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        return try XCTUnwrap(buffer)
    }

    private func fullRangePixelBuffer(luma: UInt8, rightLuma: UInt8? = nil) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        XCTAssertEqual(CVPixelBufferCreate(
            nil, 480, 640, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes, &buffer
        ), kCVReturnSuccess)
        let result = try XCTUnwrap(buffer)
        XCTAssertEqual(CVPixelBufferLockBaseAddress(result, []), kCVReturnSuccess)
        defer { CVPixelBufferUnlockBaseAddress(result, []) }
        let width = CVPixelBufferGetWidthOfPlane(result, 0)
        let height = CVPixelBufferGetHeightOfPlane(result, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(result, 0)
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(result, 0))
        for row in 0..<height {
            memset(base.advanced(by: row * stride), Int32(luma), width / 2)
            memset(base.advanced(by: row * stride + width / 2), Int32(rightLuma ?? luma), width - width / 2)
        }
        return result
    }
}

private enum TestError: Error { case failed }

private final class DetectorDouble: FaceDetecting {
    let requestRevision = Int(VisionFaceDetector.pinnedRevision)
    private(set) var orientations: [CGImagePropertyOrientation] = []
    private let results: [DetectedFaceCandidate]
    private let error: Error?
    private let onDetect: () -> Void

    init(results: [DetectedFaceCandidate] = [], error: Error? = nil, onDetect: @escaping () -> Void = {}) {
        self.results = results
        self.error = error
        self.onDetect = onDetect
    }
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [DetectedFaceCandidate] {
        orientations.append(orientation)
        onDetect()
        if let error { throw error }
        return results
    }
}

private final class MutableClock: MonotonicClock, @unchecked Sendable {
    var value: Int64
    init(_ value: Int64) { self.value = value }
    func nowMilliseconds() -> Int64 { value }
}

private final class ManualMailboxScheduler: @unchecked Sendable {
    private var actions: [@Sendable () -> Void] = []
    func schedule(_ action: @escaping @Sendable () -> Void) { actions.append(action) }
    func runAll() {
        while !actions.isEmpty { actions.removeFirst()() }
    }
}

private final class AnalyzerHarness: @unchecked Sendable {
    let scheduler = ManualMailboxScheduler()
    let analyzer: FrameAnalyzer
    var observations: [FrameObservation] = []
    var failures: [SessionFailure] = []

    init(detector: FaceDetecting, clock: MutableClock = MutableClock(1_000), outputRotationDegrees: Double = 90, sessionID: UInt64 = 7, geometryRevision: UInt64 = 3) {
        let mailbox = ObservationMailbox(scheduler: scheduler.schedule)
        analyzer = FrameAnalyzer(detector: detector, clock: clock, mailbox: mailbox)
        analyzer.activate(
            context: FrameAnalysisContext(
                sessionID: sessionID,
                geometryRevision: geometryRevision,
                viewportPoints: CoordinateSize(width: 480, height: 640),
                previewMirrored: true,
                outputRotationDegrees: outputRotationDegrees
            ),
            observationHandler: { [weak self] in self?.observations.append($0) },
            failureHandler: { [weak self] _, failure in self?.failures.append(failure) }
        )
    }
}
