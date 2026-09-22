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

struct CaptureFixtureHost: View {
    @State private var state: CaptureViewState

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
                onExit: {}
            )
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
