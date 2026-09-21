@preconcurrency import AVFoundation
import Foundation
import ImageIO

struct FrameAnalysisContext: Sendable, Equatable {
    let sessionID: UInt64
    let geometryRevision: UInt64
    let viewportPoints: CoordinateSize
    let previewMirrored: Bool
    let outputRotationDegrees: CGFloat
}

struct FrameAnalysisDiagnostics: Sendable, Equatable {
    let completedFrameCount: UInt64
    let lastPresentationTimeSeconds: Double?
    let lastLumaSampling: LumaSamplingDiagnostics?
}

final class FrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let detector: FaceDetecting
    private let clock: any MonotonicClock
    private let mailbox: ObservationMailbox
    private let lumaSampler: SparseLumaSampler
    private let lock = NSLock()
    private var context: FrameAnalysisContext?
    private var failureHandler: (@Sendable (UInt64, SessionFailure) -> Void)?
    private var analyzing = false
    private var completedFrameCount: UInt64 = 0
    private var lastPresentationTimeSeconds: Double?
    private var lastLumaSampling: LumaSamplingDiagnostics?

    init(
        detector: FaceDetecting,
        clock: any MonotonicClock,
        mailbox: ObservationMailbox,
        lumaSampler: SparseLumaSampler = SparseLumaSampler()
    ) {
        self.detector = detector
        self.clock = clock
        self.mailbox = mailbox
        self.lumaSampler = lumaSampler
    }

    func activate(
        context: FrameAnalysisContext,
        observationHandler: @escaping @Sendable (FrameObservation) -> Void,
        failureHandler: @escaping @Sendable (UInt64, SessionFailure) -> Void
    ) {
        lock.withLock {
            self.context = context
            self.failureHandler = failureHandler
        }
        mailbox.activate(consumer: observationHandler)
    }

    /// Called before session teardown so an in-flight older generation cannot publish.
    func invalidate(sessionID: UInt64? = nil) {
        lock.withLock {
            if sessionID == nil || context?.sessionID == sessionID {
                context = nil
                failureHandler = nil
            }
        }
        mailbox.invalidate()
    }

    var diagnostics: FrameAnalysisDiagnostics {
        lock.withLock {
            FrameAnalysisDiagnostics(
                completedFrameCount: completedFrameCount,
                lastPresentationTimeSeconds: lastPresentationTimeSeconds,
                lastLumaSampling: lastLumaSampling
            )
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let cleanAperture: RawPixelRect?
        if let description = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let aperture = CMVideoFormatDescriptionGetCleanAperture(description, originIsAtTopLeft: true)
            cleanAperture = RawPixelRect(
                x: aperture.origin.x,
                y: aperture.origin.y,
                width: aperture.width,
                height: aperture.height
            )
        } else {
            cleanAperture = nil
        }
        analyze(
            pixelBuffer: pixelBuffer,
            presentationTimeSeconds: presentation.isValid ? presentation.seconds : nil,
            cleanAperture: cleanAperture
        )
    }

    func analyze(
        pixelBuffer: CVPixelBuffer,
        presentationTimeSeconds: Double?,
        cleanAperture: RawPixelRect? = nil
    ) {
        let capturedAtMS = clock.nowMilliseconds()
        guard let snapshotContext = lock.withLock({ () -> FrameAnalysisContext? in
            guard !analyzing, let context else { return nil }
            analyzing = true
            return context
        }) else { return }
        defer { lock.withLock { analyzing = false } }

        let width = Double(CVPixelBufferGetWidth(pixelBuffer))
        let height = Double(CVPixelBufferGetHeight(pixelBuffer))
        let apertureWidth = cleanAperture?.width ?? width
        let apertureHeight = cleanAperture?.height ?? height
        let physicallyOriented = snapshotContext.outputRotationDegrees == 90
        let rotation: FrameQuarterTurn = physicallyOriented ? .degrees0 : .degrees90Clockwise
        let oriented = physicallyOriented
            ? CoordinateSize(width: apertureWidth, height: apertureHeight)
            : CoordinateSize(width: apertureHeight, height: apertureWidth)
        let transform = FrameTransformSnapshot(
            geometryRevision: snapshotContext.geometryRevision,
            rawBufferPixels: CoordinateSize(width: width, height: height),
            orientedImagePixels: oriented,
            rawToOrientedRotation: rotation,
            visionOrientationPolicy: physicallyOriented ? .bufferAlreadyOriented : .visionAppliesSnapshotRotation,
            cleanAperturePolicy: cleanAperture.map(FrameCleanAperturePolicy.crop) ?? .fullBuffer,
            viewportPoints: snapshotContext.viewportPoints,
            interfaceOrientation: .portrait,
            isPreviewMirrored: snapshotContext.previewMirrored
        )

        do {
            let candidates = try detector.detect(
                in: pixelBuffer,
                orientation: physicallyOriented ? .up : .right
            )
            let detectedFace = firstUsableFace(candidates, transform: transform)
            let measurement = lumaSampler.measure(
                pixelBuffer: pixelBuffer,
                transform: transform,
                face: detectedFace,
                isPoseEligible: isPoseEligibleForMeasurement(detectedFace)
            )
            let resultAtMS = clock.nowMilliseconds()
            let isStale = resultAtMS - capturedAtMS > TrackingConfiguration.provisional.timing.faceFreshnessMS
            let face = isStale ? nil : detectedFace
            let lighting = isStale ? nil : measurement.metrics
            guard isStillActive(snapshotContext) else { return }
            lock.withLock {
                completedFrameCount &+= 1
                lastPresentationTimeSeconds = presentationTimeSeconds
                lastLumaSampling = measurement.diagnostics
            }
            mailbox.publish(FrameObservation(
                sessionID: snapshotContext.sessionID,
                geometryRevision: snapshotContext.geometryRevision,
                capturedAtMS: capturedAtMS,
                resultAtMS: resultAtMS,
                face: face,
                lighting: lighting
            ))
        } catch {
            guard isStillActive(snapshotContext) else { return }
            let handler = lock.withLock { failureHandler }
            handler?(snapshotContext.sessionID, .detectorUnavailable)
        }
    }

    private func isStillActive(_ expected: FrameAnalysisContext) -> Bool {
        lock.withLock { context == expected }
    }

    private func firstUsableFace(
        _ candidates: [DetectedFaceCandidate],
        transform: FrameTransformSnapshot
    ) -> FaceSample? {
        for candidate in candidates {
            guard let geometry = FrameCoordinateMapper.mapVisionBounds(candidate.bounds, using: transform) else { continue }
            let pose: FacePose?
            if let yaw = candidate.yawRadians,
               let pitch = candidate.pitchRadians,
               let roll = candidate.rollRadians {
                let radiansToDegrees = 180 / Double.pi
                pose = FacePose(
                    yawDegrees: yaw * radiansToDegrees,
                    pitchDegrees: pitch * radiansToDegrees,
                    rollDegrees: roll * radiansToDegrees
                )
            } else {
                pose = nil
            }
            if let validated = FaceSample(geometry: geometry, pose: pose).validated { return validated }
        }
        return nil
    }

    private func isPoseEligibleForMeasurement(_ face: FaceSample?) -> Bool {
        guard let pose = face?.pose, pose.isFinite else { return false }
        let limits = TrackingConfiguration.provisional.positioning
        return abs(pose.yawDegrees) <= limits.poseExitYawDegrees
            && abs(pose.pitchDegrees) <= limits.poseExitPitchDegrees
            && abs(pose.rollDegrees) <= limits.poseExitRollDegrees
    }
}
