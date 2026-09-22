import XCTest
@testable import facetracking

final class CapturePresentationTests: XCTestCase {
    func testU01PermissionFailureCopyKeysAndStableActionIdentifiers() {
        XCTAssertEqual(GuidanceTextKey.failureKey(.frontCameraUnavailable), "error.camera")
        XCTAssertEqual(GuidanceTextKey.failureKey(.cameraUnavailable), "error.camera")
        XCTAssertEqual(GuidanceTextKey.failureKey(.detectorUnavailable), "error.detector")
        XCTAssertEqual(CaptureActionIdentifier.grant, "capture.grant")
        XCTAssertEqual(CaptureActionIdentifier.settings, "capture.settings")
        XCTAssertEqual(CaptureActionIdentifier.retry, "capture.retry")
        XCTAssertEqual(CaptureActionIdentifier.restart, "capture.restart")
        XCTAssertEqual(CaptureActionIdentifier.exit, "capture.exit")
    }

    func testU02MaskRemainsAt1999AndEligible2000SampleTransitionsImmediately() {
        var state = runningState()
        for timestamp: Int64 in [0, 250, 500, 750, 1_000, 1_250, 1_500, 1_750, 1_999] {
            state = observe(state, at: timestamp, face: face)
        }
        XCTAssertTrue(GuidanceRules.project(session: state).showsInitialMask)
        XCTAssertEqual(state.stage, .aligning)

        state = observe(state, at: 2_000, face: face)
        let projection = GuidanceRules.project(session: state)
        XCTAssertEqual(state.stage, .following)
        XCTAssertFalse(projection.showsInitialMask)
        XCTAssertEqual(projection.trackedOval, face.geometry)
    }

    func testU03ReturnGuidePersistsOnFaceLossAndRestartRestoresMask() {
        var state = runningState()
        for timestamp in stride(from: Int64(0), through: 2_000, by: 250) {
            state = observe(state, at: timestamp, face: face)
        }
        XCTAssertTrue(GuidanceRules.project(session: state).showsReturnGuide)

        state = observe(state, at: 2_250, face: nil)
        var projection = GuidanceRules.project(session: state)
        XCTAssertTrue(projection.showsReturnGuide)
        XCTAssertNil(projection.trackedOval)
        XCTAssertTrue(state.isTrackingLost)

        state = SessionTransition.reduce(state: state, event: .restartAfterLoss(atMS: 2_251)).state
        projection = GuidanceRules.project(session: state)
        XCTAssertTrue(projection.showsInitialMask)
        XCTAssertFalse(projection.showsReturnGuide)
    }

    func testU04EveryAssessmentMapsToBadgeStyleAndFullLabel() {
        let cases: [(LightingAssessment, LightingAdvice, LightingBadgeStyle, String)] = [
            (.unknown, .checking, .unknown, "lighting.checking"),
            (.acceptable, .acceptable, .acceptable, "lighting.okay"),
            (.tooDark, .addMoreLight, .warning, "lighting.more"),
            (.tooBright, .reduceDirectLight, .warning, "lighting.reduce"),
            (.uneven, .useSoftEvenLight, .warning, "lighting.soften"),
            (.highContrast, .useSoftEvenLight, .warning, "lighting.soften")
        ]
        for (assessment, advice, style, key) in cases {
            XCTAssertEqual(LightingBadgeStyle.style(for: assessment), style)
            XCTAssertEqual(GuidanceTextKey.lightingKey(advice), key)
        }
        XCTAssertEqual(GuidanceTextKey.lightingKey(.addLightLeft), "lighting.left")
        XCTAssertEqual(GuidanceTextKey.lightingKey(.addLightRight), "lighting.right")
    }

    func testTargetAndReturnGuideUseSharedGeometryAndOutlineUsesRawFace() {
        var state = runningState()
        state.stage = .following
        state.positioningHint = .following
        state.rawFace = face
        state.positioningHistory.filteredFace = FaceSample(
            geometry: FaceGeometry(centerX: 0.4, centerY: 0.4, width: 0.3, height: 0.3),
            pose: face.pose
        )
        let viewState = CaptureViewState(session: state, selection: nil)
        XCTAssertEqual(viewState.target, PreviewGeometry.target(viewportWidthPoints: 390, viewportHeightPoints: 700))
        XCTAssertEqual(viewState.guidance.trackedOval, face.geometry)
        XCTAssertNotEqual(viewState.guidance.trackedOval, state.positioningHistory.filteredFace?.geometry)
    }

    func testGuidanceAndBadgeChangesNeverMutateViewportRevision() {
        var state = runningState()
        let revision = state.geometryRevision
        state.positioningHint = .centerFace
        state.lightingHistory.activeAssessment = .tooDark
        _ = CaptureViewState(session: state, selection: nil)
        XCTAssertEqual(state.geometryRevision, revision)
        state.positioningHint = .holdStill
        state.lightingHistory.activeAssessment = .acceptable
        _ = CaptureViewState(session: state, selection: nil)
        XCTAssertEqual(state.geometryRevision, revision)
    }

    @MainActor
    func testPreviewHostBoundsAreTheViewportAuthority() {
        let preview = PreviewView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        var reported: [CGSize] = []
        preview.onViewportChanged = { reported.append($0) }
        preview.layoutSubviews()
        preview.frame = CGRect(x: 0, y: 0, width: 430, height: 760)
        preview.layoutSubviews()

        XCTAssertEqual(reported.first, CGSize(width: 390, height: 700))
        XCTAssertEqual(reported.last, CGSize(width: 430, height: 760))
    }

    func testAllFixtureIDsBuildWithoutCameraDependencies() {
        XCTAssertEqual(CaptureFixture.allCases.count, 22)
        for fixture in CaptureFixture.allCases {
            _ = fixture.viewState
        }
    }

    private let face = FaceSample(
        geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 0.5, height: 0.4),
        pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    )

    private func runningState() -> SessionState {
        var state = SessionState()
        func apply(_ event: SessionEvent) { state = SessionTransition.reduce(state: state, event: event).state }
        apply(.authorizationChanged(.authorized, atMS: 0))
        apply(.sceneActivityChanged(isActive: true, atMS: 0))
        apply(.routePresenceChanged(isPresent: true, atMS: 0))
        apply(.viewportChanged(SessionViewport(widthPoints: 390, heightPoints: 700, transformRevision: 0), atMS: 0))
        return state
    }

    private func observe(_ state: SessionState, at timestamp: Int64, face: FaceSample?) -> SessionState {
        SessionTransition.reduce(
            state: state,
            event: .observation(FrameObservation(
                sessionID: 1,
                geometryRevision: 1,
                capturedAtMS: timestamp,
                face: face,
                lighting: nil
            ))
        ).state
    }
}
