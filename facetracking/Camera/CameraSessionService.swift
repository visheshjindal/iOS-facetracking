@preconcurrency import AVFoundation
import Foundation

struct CameraSelection: Sendable, Equatable {
    let widthPixels: Int32
    let heightPixels: Int32
    let requestedFramesPerSecond: Int
    let configuredFramesPerSecond: Double?
    let previewMirrored: Bool
    let outputMirrored: Bool
    let rotationDegrees: CGFloat
}

enum CameraServiceEvent: Sendable, Equatable {
    case started(sessionID: UInt64, selection: CameraSelection)
    case stopped(sessionID: UInt64)
    case interrupted(sessionID: UInt64)
    case interruptionEnded
    case failed(sessionID: UInt64, failure: SessionFailure)
}

/// The session reference is immutable. Configuration and running state remain
/// confined to CameraSessionService.cameraQueue; UIKit only attaches it to a
/// preview layer on MainActor.
final class CameraPreviewSession: @unchecked Sendable {
    let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
    }
}

protocol CameraSessionControlling: AnyObject {
    var previewSession: CameraPreviewSession { get }
    func start(
        context: FrameAnalysisContext,
        eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void,
        observationHandler: @escaping @Sendable (FrameObservation) -> Void
    )
    func stop(sessionID: UInt64, eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void)
    func tearDown()
}

final class CameraSessionService: CameraSessionControlling, @unchecked Sendable {
    let previewSession: CameraPreviewSession

    private let cameraQueue = DispatchQueue(label: "xim.facetracking.camera.session")
    private let outputQueue = DispatchQueue(label: "xim.facetracking.camera.output")
    private let analyzer: FrameAnalyzer
    private var configured = false
    private var selection: CameraSelection?
    private var activeSessionID: UInt64?
    private var notificationTokens: [NSObjectProtocol] = []
    private var eventHandler: (@Sendable (CameraServiceEvent) -> Void)?

    init(
        session: AVCaptureSession = AVCaptureSession(),
        detector: FaceDetecting = VisionFaceDetector(),
        clock: any MonotonicClock = SystemMonotonicClock()
    ) {
        previewSession = CameraPreviewSession(session: session)
        let mailbox = ObservationMailbox { action in DispatchQueue.main.async(execute: action) }
        analyzer = FrameAnalyzer(detector: detector, clock: clock, mailbox: mailbox)
    }

    func start(
        context: FrameAnalysisContext,
        eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void,
        observationHandler: @escaping @Sendable (FrameObservation) -> Void
    ) {
        cameraQueue.async { [weak self] in
            self?.startOnCameraQueue(
                context: context,
                eventHandler: eventHandler,
                observationHandler: observationHandler
            )
        }
    }

    func stop(sessionID: UInt64, eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void) {
        cameraQueue.async { [weak self] in
            self?.stopOnCameraQueue(sessionID: sessionID, eventHandler: eventHandler)
        }
    }

    func tearDown() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            activeSessionID = nil
            eventHandler = nil
            analyzer.invalidate()
            if previewSession.session.isRunning { previewSession.session.stopRunning() }
            removeObservers()
        }
    }

    private func startOnCameraQueue(
        context: FrameAnalysisContext,
        eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void,
        observationHandler: @escaping @Sendable (FrameObservation) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(cameraQueue))
        self.eventHandler = eventHandler
        let sessionID = context.sessionID
        do {
            if !configured { try configureSession() }
            guard let selection else { throw SessionFailureError(.cameraUnavailable) }
            let activeContext = FrameAnalysisContext(
                sessionID: sessionID,
                geometryRevision: context.geometryRevision,
                viewportPoints: context.viewportPoints,
                previewMirrored: selection.previewMirrored,
                outputRotationDegrees: selection.rotationDegrees
            )
            analyzer.activate(
                context: activeContext,
                observationHandler: observationHandler,
                failureHandler: { [weak self] id, failure in
                    self?.cameraQueue.async { [weak self] in
                        guard let self, activeSessionID == id else { return }
                        activeSessionID = nil
                        analyzer.invalidate(sessionID: id)
                        self.eventHandler?(.failed(sessionID: id, failure: failure))
                    }
                }
            )
            activeSessionID = sessionID
            installObserversIfNeeded()
            if !previewSession.session.isRunning { previewSession.session.startRunning() }
            guard activeSessionID == sessionID else { return }
            eventHandler(.started(sessionID: sessionID, selection: selection))
        } catch let failure as SessionFailureError {
            activeSessionID = nil
            eventHandler(.failed(sessionID: sessionID, failure: failure.failure))
        } catch {
            activeSessionID = nil
            eventHandler(.failed(sessionID: sessionID, failure: .cameraUnavailable))
        }
    }

    private func stopOnCameraQueue(
        sessionID: UInt64,
        eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(cameraQueue))
        if activeSessionID == sessionID {
            activeSessionID = nil
            analyzer.invalidate(sessionID: sessionID)
        }
        if previewSession.session.isRunning { previewSession.session.stopRunning() }
        eventHandler(.stopped(sessionID: sessionID))
    }

    private func configureSession() throws {
        dispatchPrecondition(condition: .onQueue(cameraQueue))
        let session = previewSession.session
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        var addedInput: AVCaptureDeviceInput?
        var addedOutput: AVCaptureVideoDataOutput?
        do {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                throw SessionFailureError(.frontCameraUnavailable)
            }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw SessionFailureError(.cameraUnavailable) }
            session.addInput(input)
            addedInput = input

            if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            } else if session.canSetSessionPreset(.medium) {
                session.sessionPreset = .medium
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            let supportedFormats = output.availableVideoPixelFormatTypes
            let selectedFormat = supportedFormats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                : supportedFormats.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                    ? kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                    : nil
            if let selectedFormat {
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: selectedFormat]
            }
            output.setSampleBufferDelegate(analyzer, queue: outputQueue)
            guard session.canAddOutput(output) else { throw SessionFailureError(.cameraUnavailable) }
            session.addOutput(output)
            addedOutput = output

            let requestedFPS = 30
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
            let duration = CMTime(value: 1, timescale: CMTimeScale(requestedFPS))
            let configuredFPS: Double?
            if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                configuredFPS = 30
            } else {
                configuredFPS = nil
            }

            let requestedRotation: CGFloat = 90
            var appliedRotation: CGFloat = 0
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(requestedRotation) {
                    connection.videoRotationAngle = requestedRotation
                    appliedRotation = requestedRotation
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            selection = CameraSelection(
                widthPixels: dimensions.width,
                heightPixels: dimensions.height,
                requestedFramesPerSecond: requestedFPS,
                configuredFramesPerSecond: configuredFPS,
                previewMirrored: true,
                outputMirrored: false,
                rotationDegrees: appliedRotation
            )
            configured = true
        } catch {
            if let addedOutput {
                addedOutput.setSampleBufferDelegate(nil, queue: nil)
                session.removeOutput(addedOutput)
            }
            if let addedInput { session.removeInput(addedInput) }
            selection = nil
            throw error
        }
    }

    private func installObserversIfNeeded() {
        guard notificationTokens.isEmpty else { return }
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: previewSession.session,
            queue: nil
        ) { [weak self] _ in self?.forwardInterruption() })
        notificationTokens.append(center.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: previewSession.session,
            queue: nil
        ) { [weak self] _ in self?.forwardInterruptionEnded() })
        notificationTokens.append(center.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: previewSession.session,
            queue: nil
        ) { [weak self] _ in self?.forwardRuntimeError() })
    }

    private func forwardInterruption() {
        cameraQueue.async { [weak self] in
            guard let self, let id = activeSessionID else { return }
            eventHandler?(.interrupted(sessionID: id))
        }
    }

    private func forwardInterruptionEnded() {
        cameraQueue.async { [weak self] in self?.eventHandler?(.interruptionEnded) }
    }

    private func forwardRuntimeError() {
        cameraQueue.async { [weak self] in
            guard let self, let id = activeSessionID else { return }
            activeSessionID = nil
            analyzer.invalidate(sessionID: id)
            eventHandler?(.failed(sessionID: id, failure: .cameraUnavailable))
        }
    }

    private func removeObservers() {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        notificationTokens.removeAll()
    }
}

private struct SessionFailureError: Error {
    let failure: SessionFailure
    init(_ failure: SessionFailure) { self.failure = failure }
}
