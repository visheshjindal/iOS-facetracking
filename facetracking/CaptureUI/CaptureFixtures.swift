@preconcurrency import AVFoundation
import Observation
import SwiftUI

#if DEBUG
enum CaptureFixture: String, CaseIterable {
    case permissionNotDetermined = "permission-not-determined"
    case permissionDenied = "permission-denied"
    case permissionRestricted = "permission-restricted"
    case noFace = "no-face"
    case center = "center"
    case closer = "closer"
    case farther = "farther"
    case lookStraight = "look-straight"
    case hold = "hold"
    case following = "following"
    case loss = "loss"
    case lightingUnknown = "lighting-unknown"
    case lightingAcceptable = "lighting-acceptable"
    case lightingDark = "lighting-dark"
    case lightingBright = "lighting-bright"
    case lightingLeft = "lighting-left"
    case lightingRight = "lighting-right"
    case lightingUneven = "lighting-uneven"
    case lightingHighContrast = "lighting-high-contrast"
    case interrupted = "interrupted"
    case cameraError = "camera-error"
    case detectorError = "detector-error"

    var viewState: CaptureViewState {
        var session = baseSession
        switch self {
        case .permissionNotDetermined:
            session.authorization = .notDetermined
        case .permissionDenied:
            session.authorization = .denied
        case .permissionRestricted:
            session.authorization = .restricted
        case .noFace:
            break
        case .center:
            session.positioningHint = .centerFace
            session.rawFace = face
        case .closer:
            session.positioningHint = .closer
            session.rawFace = face
        case .farther:
            session.positioningHint = .farther
            session.rawFace = face
        case .lookStraight:
            session.positioningHint = .lookStraight
            session.rawFace = FaceSample(geometry: face.geometry, pose: nil)
        case .hold:
            session.positioningHint = .holdStill
            session.rawFace = face
        case .following:
            configureFollowing(&session)
        case .loss:
            session.stage = .following
            session.positioningHint = .trackingLost
        case .lightingUnknown:
            configureFollowing(&session, assessment: .unknown)
        case .lightingAcceptable:
            configureFollowing(&session, assessment: .acceptable)
        case .lightingDark:
            configureFollowing(&session, assessment: .tooDark)
        case .lightingBright:
            configureFollowing(&session, assessment: .tooBright)
        case .lightingLeft:
            configureFollowing(&session, assessment: .uneven, side: .left)
        case .lightingRight:
            configureFollowing(&session, assessment: .uneven, side: .right)
        case .lightingUneven:
            configureFollowing(&session, assessment: .uneven)
        case .lightingHighContrast:
            configureFollowing(&session, assessment: .highContrast)
        case .interrupted:
            session.isInterrupted = true
        case .cameraError:
            session.failure = .cameraUnavailable
        case .detectorError:
            session.failure = .detectorUnavailable
        }
        return CaptureViewState(session: session, selection: nil)
    }

    private var baseSession: SessionState {
        var session = SessionState()
        session.authorization = .authorized
        session.isSceneActive = true
        session.isRoutePresent = true
        session.viewport = SessionViewport(widthPoints: 390, heightPoints: 700, transformRevision: 0)
        session.positioningHint = .placeFace
        return session
    }

    private var face: FaceSample {
        FaceSample(
            geometry: FaceGeometry(centerX: 0.5, centerY: 0.48, width: 0.46, height: 0.44),
            pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
        )
    }

    private func configureFollowing(
        _ session: inout SessionState,
        assessment: LightingAssessment = .acceptable,
        side: LightingSide? = nil
    ) {
        session.stage = .following
        session.positioningHint = .following
        session.rawFace = face
        session.lastAcceptedSampleMS = 1_000
        session.lightingHistory.activeAssessment = assessment
        session.lightingHistory.activeSide = side
        session.lightingHistory.acceptableEvidenceSinceMS = assessment == .acceptable ? 0 : nil
    }
}

enum CaptureTestScenario: String, CaseIterable {
    case permissionNotDetermined = "permission-not-determined"
    case permissionDenied = "permission-denied"
    case permissionRestricted = "permission-restricted"
    case cameraError = "camera-error"
    case detectorError = "detector-error"
    case interrupted
    case aligning1999 = "aligning-1999"
    case acquired2000 = "acquired-2000"
    case lost
    case recovered
    case restarted
}

@MainActor
struct CaptureScenarioHost: View {
    @State private var harness: CaptureScenarioHarness
    private let reduceMotion = ProcessInfo.processInfo.arguments.contains("-reduce-motion")

    init(scenario: CaptureTestScenario) {
        _harness = State(initialValue: CaptureScenarioHarness(scenario: scenario))
    }

    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            CaptureScreen(
                viewState: harness.store.viewState,
                onGrant: harness.store.grantCameraAccess,
                onSettings: harness.store.openSettings,
                onRetry: harness.store.retry,
                onRestart: harness.store.restartAfterLoss,
                onExit: harness.store.exit,
                announcements: nil
            )
            .transaction { transaction in
                if reduceMotion { transaction.disablesAnimations = true }
            }
            VStack(spacing: 0) {
                Text("\(harness.camera.startCount)")
                    .accessibilityIdentifier("test.cameraStartCount")
                Text("\(harness.camera.stopCount)")
                    .accessibilityIdentifier("test.cameraStopCount")
                Text("\(harness.settings.openCount)")
                    .accessibilityIdentifier("test.settingsOpenCount")
                Text(harness.store.viewState.guidance.showsInitialMask ? "true" : "false")
                    .accessibilityIdentifier("test.showsMask")
                Text(harness.store.viewState.guidance.trackedOval == nil ? "false" : "true")
                    .accessibilityIdentifier("test.hasTrackedOval")
                Text(harness.store.viewState.guidance.showsReturnGuide ? "true" : "false")
                    .accessibilityIdentifier("test.showsReturnGuide")
            }
            .font(.caption2)
            .opacity(0.01)
            .allowsHitTesting(false)
        }
    }
}

@MainActor @Observable
private final class CaptureScenarioHarness {
    let clock = ScenarioClock()
    let camera = ScenarioCamera()
    let settings = ScenarioSettings()
    let store: CaptureStore

    init(scenario: CaptureTestScenario) {
        let authorization = ScenarioAuthorization(Self.authorization(for: scenario))
        store = CaptureStore(
            dependencies: CaptureDependencies(
                authorization: authorization,
                camera: camera,
                clock: clock,
                scheduler: ScenarioScheduler(),
                settingsOpener: settings
            ),
            dismiss: {}
        )
        store.routeAppeared(isSceneActive: true)
        store.viewportChanged(width: 390, height: 700)
        script(scenario)
    }

    private static func authorization(for scenario: CaptureTestScenario) -> CameraAuthorization {
        switch scenario {
        case .permissionNotDetermined: .notDetermined
        case .permissionDenied: .denied
        case .permissionRestricted: .restricted
        default: .authorized
        }
    }

    private func script(_ scenario: CaptureTestScenario) {
        switch scenario {
        case .cameraError:
            camera.emit(.failed(sessionID: 1, failure: .cameraUnavailable))
        case .detectorError:
            camera.emit(.failed(sessionID: 1, failure: .detectorUnavailable))
        case .interrupted:
            camera.emit(.interrupted(sessionID: 1))
        case .aligning1999:
            advanceHold(through: 1_999)
        case .acquired2000:
            advanceHold(through: 2_000)
        case .lost:
            advanceHold(through: 2_000)
            emit(face: nil, at: 2_250)
        case .recovered:
            advanceHold(through: 2_000)
            emit(face: nil, at: 2_250)
            emit(face: Self.face, at: 2_500)
        case .restarted:
            advanceHold(through: 2_000)
            emit(face: nil, at: 2_250)
            clock.now = 2_251
            store.restartAfterLoss()
        case .permissionNotDetermined, .permissionDenied, .permissionRestricted:
            break
        }
    }

    private func advanceHold(through finalTimestamp: Int64) {
        for timestamp: Int64 in [0, 250, 500, 750, 1_000, 1_250, 1_500, 1_750, finalTimestamp] {
            emit(face: Self.face, at: timestamp)
        }
    }

    private func emit(face: FaceSample?, at timestamp: Int64) {
        clock.now = timestamp
        camera.emitObservation(FrameObservation(
            sessionID: camera.latestSessionID ?? 1,
            geometryRevision: camera.latestGeometryRevision ?? 1,
            capturedAtMS: timestamp,
            face: face,
            lighting: nil
        ))
    }

    private static let face = FaceSample(
        geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 0.5, height: 0.4),
        pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    )
}

private final class ScenarioClock: MonotonicClock, @unchecked Sendable {
    var now: Int64 = 0
    func nowMilliseconds() -> Int64 { now }
}

private struct ScenarioScheduler: MonotonicScheduling {
    func schedule(afterMilliseconds: Int64, action: @escaping @Sendable () -> Void) -> ScheduledCancellation {
        ScenarioCancellation()
    }
}

private final class ScenarioCancellation: ScheduledCancellation, @unchecked Sendable {
    func cancel() {}
}

private final class ScenarioAuthorization: CameraAuthorizing, @unchecked Sendable {
    private let status: CameraAuthorization
    init(_ status: CameraAuthorization) { self.status = status }
    func currentAuthorization() -> CameraAuthorization { status }
    func requestAuthorization(_ completion: @escaping @Sendable (CameraAuthorization) -> Void) {
        completion(status)
    }
}

@MainActor @Observable
private final class ScenarioSettings: SettingsOpening {
    var openCount = 0
    func openSettings() { openCount += 1 }
}

@Observable
private final class ScenarioCamera: CameraSessionControlling, @unchecked Sendable {
    let previewSession = CameraPreviewSession(session: AVCaptureSession())
    private var eventHandler: (@Sendable (CameraServiceEvent) -> Void)?
    private var observationHandler: (@Sendable (FrameObservation) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var latestSessionID: UInt64?
    private(set) var latestGeometryRevision: UInt64?

    func start(
        context: FrameAnalysisContext,
        eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void,
        observationHandler: @escaping @Sendable (FrameObservation) -> Void
    ) {
        self.eventHandler = eventHandler
        self.observationHandler = observationHandler
        startCount += 1
        latestSessionID = context.sessionID
        latestGeometryRevision = context.geometryRevision
        eventHandler(.started(sessionID: context.sessionID, selection: .scenarioFixture))
    }

    func stop(sessionID: UInt64, eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void) {
        stopCount += 1
        eventHandler(.stopped(sessionID: sessionID))
    }

    func tearDown() {
        eventHandler = nil
        observationHandler = nil
    }

    func emit(_ event: CameraServiceEvent) { eventHandler?(event) }
    func emitObservation(_ observation: FrameObservation) { observationHandler?(observation) }
}

private extension CameraSelection {
    static let scenarioFixture = CameraSelection(
        widthPixels: 640,
        heightPixels: 480,
        requestedFramesPerSecond: 30,
        configuredFramesPerSecond: 30,
        previewMirrored: true,
        outputMirrored: false,
        rotationDegrees: 90
    )
}

struct CaptureFixtureHost: View {
    @State private var state: CaptureViewState
    private let reduceMotion = ProcessInfo.processInfo.arguments.contains("-reduce-motion")

    init(fixture: CaptureFixture) {
        _state = State(initialValue: fixture.viewState)
    }

    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            CaptureScreen(
                viewState: state,
                onGrant: {},
                onSettings: {},
                onRetry: {},
                onRestart: { state = CaptureFixture.noFace.viewState },
                onExit: {},
                announcements: nil
            )
            .transaction { transaction in
                if reduceMotion { transaction.disablesAnimations = true }
            }
        }
    }
}

#Preview("Alignment") {
    CaptureFixtureHost(fixture: .hold)
}

#Preview("Following warning") {
    CaptureFixtureHost(fixture: .lightingLeft)
}

#Preview("Tracking loss") {
    CaptureFixtureHost(fixture: .loss)
}
#endif
