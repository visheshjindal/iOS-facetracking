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

    private func fullRangePixelBuffer(luma: UInt8) throws -> CVPixelBuffer {
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
        for row in 0..<height { memset(base.advanced(by: row * stride), Int32(luma), width) }
        return result
    }
}

private enum TestError: Error { case failed }

private final class DetectorDouble: FaceDetecting {
    let requestRevision = Int(VisionFaceDetector.pinnedRevision)
    private let results: [DetectedFaceCandidate]
    private let error: Error?
    private let onDetect: () -> Void

    init(results: [DetectedFaceCandidate] = [], error: Error? = nil, onDetect: @escaping () -> Void = {}) {
        self.results = results
        self.error = error
        self.onDetect = onDetect
    }
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [DetectedFaceCandidate] {
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

    init(detector: FaceDetecting, clock: MutableClock = MutableClock(1_000)) {
        let mailbox = ObservationMailbox(scheduler: scheduler.schedule)
        analyzer = FrameAnalyzer(detector: detector, clock: clock, mailbox: mailbox)
        analyzer.activate(
            context: FrameAnalysisContext(
                sessionID: 7,
                geometryRevision: 3,
                viewportPoints: CoordinateSize(width: 480, height: 640),
                previewMirrored: true,
                outputRotationDegrees: 90
            ),
            observationHandler: { [weak self] in self?.observations.append($0) },
            failureHandler: { [weak self] _, failure in self?.failures.append(failure) }
        )
    }
}
