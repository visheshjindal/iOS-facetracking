import XCTest
@testable import facetracking

final class GuidanceRulesTests: XCTestCase {
    func testL10EveryPositioningCorrectionWinsOverEveryLightingState() {
        let corrections: [PositioningHint] = [
            .placeFace, .trackingLost, .centerFace, .moveLeft, .moveRight,
            .moveUp, .moveDown, .farther, .closer, .lookStraight
        ]
        let assessments: [(LightingAssessment, LightingSide?)] = [
            (.unknown, nil), (.acceptable, nil), (.tooDark, nil), (.tooBright, nil),
            (.uneven, .left), (.uneven, .right), (.uneven, nil), (.highContrast, nil)
        ]
        for hint in corrections {
            for (assessment, side) in assessments {
                var state = projectionState(hint: hint, assessment: assessment, side: side)
                state.stage = hint == .trackingLost ? .following : .aligning
                XCTAssertEqual(GuidanceRules.project(session: state).primary, .positioning(hint))
            }
        }
    }

    func testL10WarningsReplaceOnlyHoldAndFollowingAndAdviceHasCorrectSide() {
        var hold = projectionState(hint: .holdStill, assessment: .uneven, side: .left)
        XCTAssertEqual(GuidanceRules.project(session: hold).primary, .lighting(.addLightLeft))
        hold.lightingHistory.activeSide = .right
        XCTAssertEqual(GuidanceRules.project(session: hold).primary, .lighting(.addLightRight))
        hold.lightingHistory.activeSide = nil
        XCTAssertEqual(GuidanceRules.project(session: hold).primary, .lighting(.useSoftEvenLight))

        for assessment in [LightingAssessment.tooDark, .tooBright, .highContrast] {
            let state = projectionState(hint: .following, assessment: assessment, side: nil)
            guard case .lighting = GuidanceRules.project(session: state).primary else {
                return XCTFail("Expected lighting guidance for \(assessment)")
            }
        }
        XCTAssertEqual(
            GuidanceRules.project(session: projectionState(hint: .holdStill, assessment: .acceptable, side: nil)).primary,
            .positioning(.holdStill)
        )
    }

    func testL10BadgeVisibilityExpansionCompactAndLoss() {
        var state = projectionState(hint: .holdStill, assessment: .unknown, side: nil)
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.presentation, .iconOnly)

        state.lightingHistory.activeAssessment = .acceptable
        state.lightingHistory.acceptableEvidenceSinceMS = 0
        state.lastAcceptedSampleMS = 700
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.presentation, .expanded)
        state.lastAcceptedSampleMS = 1_500
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.presentation, .iconOnly)

        state.lightingHistory.activeAssessment = .tooDark
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.presentation, .expanded)
        state.positioningHint = .centerFace
        XCTAssertEqual(GuidanceRules.project(session: state).badge?.presentation, .iconOnly)
        state.rawFace = nil
        XCTAssertNil(GuidanceRules.project(session: state).badge)
        state.rawFace = face
        state.failure = .cameraUnavailable
        XCTAssertNil(GuidanceRules.project(session: state).badge)
    }

    func testL10MaskReturnGuideAndTrackedOvalProjection() {
        var state = projectionState(hint: .holdStill, assessment: .unknown, side: nil)
        var projection = GuidanceRules.project(session: state)
        XCTAssertTrue(projection.showsInitialMask)
        XCTAssertFalse(projection.showsReturnGuide)
        XCTAssertNil(projection.trackedOval)

        state.stage = .following
        state.positioningHint = .following
        projection = GuidanceRules.project(session: state)
        XCTAssertFalse(projection.showsInitialMask)
        XCTAssertTrue(projection.showsReturnGuide)
        XCTAssertEqual(projection.trackedOval, face.geometry)
    }

    func testL10TwoSecondHoldCompletesDespiteContinuousDarkLighting() {
        var state = runningState()
        for timestamp in stride(from: Int64(0), through: 2_000, by: 250) {
            let result = SessionTransition.reduce(
                state: state,
                event: .observation(FrameObservation(
                    sessionID: 1,
                    geometryRevision: 1,
                    capturedAtMS: timestamp,
                    face: face,
                    lighting: metrics(median: 54)
                ))
            )
            state = result.state
        }
        XCTAssertEqual(state.stage, .following)
        XCTAssertEqual(state.lightingHistory.activeAssessment, .tooDark)
    }

    func testL09NilPoseImmediatelyWithdrawsLightingAssessment() {
        var state = runningState()
        for timestamp: Int64 in [0, 200, 400] {
            state = SessionTransition.reduce(
                state: state,
                event: .observation(FrameObservation(
                    sessionID: 1,
                    geometryRevision: 1,
                    capturedAtMS: timestamp,
                    face: face,
                    lighting: metrics(median: 54)
                ))
            ).state
        }
        XCTAssertEqual(state.lightingHistory.activeAssessment, .tooDark)

        let poseUnknown = FaceSample(geometry: face.geometry, pose: nil)
        state = SessionTransition.reduce(
            state: state,
            event: .observation(FrameObservation(
                sessionID: 1,
                geometryRevision: 1,
                capturedAtMS: 600,
                face: poseUnknown,
                lighting: metrics(median: 54)
            ))
        ).state
        XCTAssertEqual(state.lightingHistory.activeAssessment, .unknown)
        XCTAssertEqual(state.positioningHint, .lookStraight)
    }

    private let face = FaceSample(
        geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 0.5, height: 0.4),
        pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    )

    private func projectionState(
        hint: PositioningHint,
        assessment: LightingAssessment,
        side: LightingSide?
    ) -> SessionState {
        var state = SessionState()
        state.positioningHint = hint
        state.rawFace = face
        state.lastAcceptedSampleMS = 1_000
        state.lightingHistory.activeAssessment = assessment
        state.lightingHistory.activeSide = side
        return state
    }

    private func runningState() -> SessionState {
        var state = SessionState()
        func apply(_ event: SessionEvent) { state = SessionTransition.reduce(state: state, event: event).state }
        apply(.authorizationChanged(.authorized, atMS: 0))
        apply(.sceneActivityChanged(isActive: true, atMS: 0))
        apply(.routePresenceChanged(isPresent: true, atMS: 0))
        apply(.viewportChanged(SessionViewport(widthPoints: 390, heightPoints: 700, transformRevision: 0), atMS: 0))
        return state
    }
}
