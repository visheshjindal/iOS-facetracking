import XCTest
@testable import facetracking

final class PositioningRulesTests: XCTestCase {
    private let target = FaceGeometry(centerX: 0.5, centerY: 0.5, width: 0.4, height: 0.6)

    // P01 — Target across portrait viewport sizes.
    func testP01TargetGeometry() throws {
        for (width, height) in [(320.0, 568.0), (390.0, 844.0), (430.0, 932.0)] {
            let target = try XCTUnwrap(PreviewGeometry.target(viewportWidthPoints: width, viewportHeightPoints: height))
            XCTAssertEqual(target.centerX, 0.5)
            XCTAssertEqual(target.centerY, 0.5)
            XCTAssertEqual((target.height * height) / (target.width * width), 1.35, accuracy: 1e-12)
            XCTAssertEqual(target.width * width, min(0.72 * width, 0.50 * height / 1.35), accuracy: 1e-12)
        }
        for dimensions in [(0.0, 800.0), (-1.0, 800.0), (390.0, 0.0), (.nan, 800.0), (390.0, .infinity)] {
            XCTAssertNil(PreviewGeometry.target(viewportWidthPoints: dimensions.0, viewportHeightPoints: dimensions.1))
        }
    }

    // P02 — Hold duration needs fresh, continuous observations.
    func testP02HoldAcquiresOnlyOnEligibleObservationAtTwoSeconds() {
        var history = PositioningHistory.empty
        let timestamps: [Int64] = [0, 250, 500, 750, 1_000, 1_250, 1_500, 1_750, 1_999]
        for timestamp in timestamps {
            let output = update(history, .aligning, face: face(), at: timestamp)
            XCTAssertEqual(output.stage, .aligning, "timestamp \(timestamp)")
            XCTAssertEqual(output.hint, .holdStill)
            history = output.history
        }
        let acquired = update(history, .aligning, face: face(), at: 2_000)
        XCTAssertEqual(acquired.stage, .following)
        XCTAssertEqual(acquired.hint, .following)
    }

    // P03 — Detection alone is insufficient.
    func testP03EveryIneligibleConditionPreventsAcquisition() {
        let fixtures: [FaceSample?] = [
            face(centerX: 0.561), face(centerY: 0.591), face(width: 0.381), face(width: 0.199),
            face(pose: nil), face(pose: FacePose(yawDegrees: 10.01, pitchDegrees: 0, rollDegrees: 0)),
            FaceSample(geometry: FaceGeometry(centerX: .nan, centerY: 0.5, width: 0.3, height: 0.45), pose: neutralPose),
            FaceSample(geometry: FaceGeometry(centerX: 1.2, centerY: 0.5, width: 0.2, height: 0.2), pose: neutralPose), nil
        ]
        for fixture in fixtures {
            var history = PositioningHistory.empty
            for timestamp in stride(from: Int64(0), through: 2_100, by: 300) {
                let output = update(history, .aligning, face: fixture, at: timestamp)
                XCTAssertEqual(output.stage, .aligning)
                XCTAssertNotEqual(output.hint, .following)
                history = output.history
            }
        }
    }

    // P04 — Inclusive positioning, pose, and anchor boundaries.
    func testP04ExactBoundariesPassAndJustOutsideFails() {
        XCTAssertEqual(update(.empty, .aligning, face: face(centerX: 0.56), at: 0).hint, .holdStill)
        XCTAssertEqual(update(.empty, .aligning, face: face(centerX: 0.560_001), at: 0).hint, .moveLeft)
        XCTAssertEqual(update(.empty, .aligning, face: face(centerY: 0.59), at: 0).hint, .holdStill)
        XCTAssertEqual(update(.empty, .aligning, face: face(centerY: 0.590_001), at: 0).hint, .moveUp)
        XCTAssertEqual(update(.empty, .aligning, face: face(width: 0.38, height: 0.57), at: 0).hint, .holdStill)
        XCTAssertEqual(update(.empty, .aligning, face: face(width: 0.380_001, height: 0.39), at: 0).hint, .farther)
        XCTAssertEqual(update(.empty, .aligning, face: face(width: 0.20, height: 0.30), at: 0).hint, .holdStill)
        XCTAssertEqual(update(.empty, .aligning, face: face(width: 0.199_999, height: 0.57), at: 0).hint, .closer)

        let entryEdges = [
            FacePose(yawDegrees: 10, pitchDegrees: 0, rollDegrees: 0),
            FacePose(yawDegrees: 0, pitchDegrees: -15, rollDegrees: 0),
            FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 8)
        ]
        for pose in entryEdges { XCTAssertEqual(update(.empty, .aligning, face: face(pose: pose), at: 0).hint, .holdStill) }
        for pose in [FacePose(yawDegrees: 10.001, pitchDegrees: 0, rollDegrees: 0), FacePose(yawDegrees: 0, pitchDegrees: 15.001, rollDegrees: 0), FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: -8.001)] {
            XCTAssertEqual(update(.empty, .aligning, face: face(pose: pose), at: 0).hint, .lookStraight)
        }
        XCTAssertEqual(update(.empty, .aligning, face: face(pose: FacePose(yawDegrees: .nan, pitchDegrees: 0, rollDegrees: 0)), at: 0).hint, .lookStraight)

        for (edge, outside) in [
            (FacePose(yawDegrees: 13, pitchDegrees: 0, rollDegrees: 0), FacePose(yawDegrees: 13.001, pitchDegrees: 0, rollDegrees: 0)),
            (FacePose(yawDegrees: 0, pitchDegrees: -20, rollDegrees: 0), FacePose(yawDegrees: 0, pitchDegrees: -20.001, rollDegrees: 0)),
            (FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 11), FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 11.001))
        ] {
            let validHistory = PositioningHistory(filteredFace: face(pose: edge), poseIsValid: true, previousObservationMS: 0)
            XCTAssertEqual(update(validHistory, .aligning, face: face(pose: edge), at: 1).hint, .holdStill)
            let invalidHistory = PositioningHistory(filteredFace: face(pose: outside), poseIsValid: true, previousObservationMS: 0)
            XCTAssertEqual(update(invalidHistory, .aligning, face: face(pose: outside), at: 1).hint, .lookStraight)
        }

        let anchor = face()
        for changed in [face(centerX: 0.525), face(centerY: 0.525), face(width: 0.325), face(height: 0.475), face(pose: FacePose(yawDegrees: 5, pitchDegrees: -5, rollDegrees: 5))] {
            XCTAssertFalse(PositioningRules.movedBeyondAnchor(changed, anchor: anchor, configuration: .provisional))
        }
        XCTAssertTrue(PositioningRules.movedBeyondAnchor(face(centerX: 0.525_001), anchor: anchor, configuration: .provisional))
        XCTAssertTrue(PositioningRules.movedBeyondAnchor(face(pose: FacePose(yawDegrees: 5.001, pitchDegrees: 0, rollDegrees: 0)), anchor: anchor, configuration: .provisional))
    }

    // P05 — Fixed-anchor comparison catches accumulated drift.
    func testP05SmallAdjacentStepsEventuallyResetFixedAnchor() {
        var history = PositioningHistory.empty
        var output = update(history, .aligning, face: face(), at: 0)
        history = output.history
        for (index, centerX) in [0.508, 0.516, 0.524, 0.532, 0.540].enumerated() {
            output = update(history, .aligning, face: face(centerX: centerX), at: Int64((index + 1) * 100))
            history = output.history
        }
        XCTAssertGreaterThan(history.stableSinceMS ?? 0, 0)
        XCTAssertEqual(history.holdAnchor?.geometry.centerX, history.filteredFace?.geometry.centerX)
    }

    // P06 — Continuity boundaries, absence, and latch gap exception.
    func testP06ContinuityAndPoseLatchAcrossGap() {
        let history = update(.empty, .aligning, face: face(), at: 0).history
        let at300 = update(history, .aligning, face: face(centerX: 0.51), at: 300)
        XCTAssertNotEqual(at300.filteredFace?.geometry.centerX, 0.51)
        XCTAssertEqual(at300.history.stableSinceMS, 0)

        let at601 = update(at300.history, .aligning, face: face(pose: FacePose(yawDegrees: 12, pitchDegrees: 0, rollDegrees: 0)), at: 601)
        XCTAssertEqual(at601.filteredFace?.geometry.centerX, 0.5)
        XCTAssertTrue(at601.history.poseIsValid)
        XCTAssertEqual(at601.history.stableSinceMS, 601)

        let beyondExit = update(at300.history, .aligning, face: face(pose: FacePose(yawDegrees: 13.001, pitchDegrees: 0, rollDegrees: 0)), at: 601)
        XCTAssertFalse(beyondExit.history.poseIsValid)
        XCTAssertEqual(beyondExit.hint, .lookStraight)

        let absent = update(at300.history, .aligning, face: nil, at: 500)
        XCTAssertNil(absent.history.filteredFace)
        XCTAssertNil(absent.history.holdAnchor)
        XCTAssertNil(absent.history.stableSinceMS)
    }

    // P07 — Time-based EMA is cadence-independent for a constant input.
    func testP07EquivalentCadencesHaveSameTimeBasedResponse() throws {
        func response(cadence: Int64) -> Double {
            var history = update(.empty, .following, face: face(centerX: 0.4), at: 0).history
            var output = update(history, .following, face: face(centerX: 0.6), at: cadence)
            history = output.history
            if cadence < 300 {
                var timestamp = cadence * 2
                while timestamp <= 300 {
                    output = update(history, .following, face: face(centerX: 0.6), at: timestamp)
                    history = output.history
                    timestamp += cadence
                }
            }
            return output.filteredFace!.geometry.centerX
        }
        let expected = 0.4 + (1 - exp(-300.0 / 150.0)) * 0.2
        XCTAssertEqual(response(cadence: 300), expected, accuracy: 1e-12)
        XCTAssertEqual(response(cadence: 100), expected, accuracy: 1e-12)
        XCTAssertEqual(response(cadence: 50), expected, accuracy: 1e-12)
    }

    // P08 — Following reports every correction without reacquisition.
    func testP08FollowingCorrectionsAndPriority() {
        let fixtures: [(FaceSample?, PositioningHint)] = [
            (nil, .trackingLost), (face(centerX: 0.399), .moveRight), (face(centerX: 0.601), .moveLeft),
            (face(centerY: 0.349), .moveDown), (face(centerY: 0.651), .moveUp),
            (face(width: 0.381), .farther), (face(width: 0.199), .closer),
            (face(width: 0.381, height: 0.389), .farther),
            (face(pose: FacePose(yawDegrees: 10.01, pitchDegrees: 0, rollDegrees: 0)), .lookStraight),
            (face(), .following)
        ]
        for (fixture, hint) in fixtures {
            let output = update(.empty, .following, face: fixture, at: 0)
            XCTAssertEqual(output.stage, .following)
            XCTAssertEqual(output.hint, hint)
            XCTAssertNil(output.history.stableSinceMS)
        }
    }

    // P09 — Loss/recovery and unknown pose retain following but block lighting.
    func testP09RecoveryUnknownPoseAndRawGeometry() {
        let lost = update(.empty, .following, face: nil, at: 0)
        XCTAssertEqual(lost.stage, .following)
        XCTAssertEqual(lost.hint, .trackingLost)
        let recovered = update(lost.history, .following, face: face(), at: 100)
        XCTAssertEqual(recovered.hint, .following)
        XCTAssertTrue(recovered.isLightingEligible)

        let unknown = update(recovered.history, .following, face: face(centerX: 0.51, pose: nil), at: 200)
        XCTAssertEqual(unknown.stage, .following)
        XCTAssertEqual(unknown.hint, .lookStraight)
        XCTAssertFalse(unknown.isLightingEligible)
        XCTAssertEqual(unknown.rawFace?.geometry.centerX, 0.51)
        XCTAssertNotEqual(unknown.filteredFace?.geometry.centerX, unknown.rawFace?.geometry.centerX)
        XCTAssertNil(unknown.filteredFace?.pose)

        let corrected = update(.empty, .following, face: face(centerX: 0.601), at: 0)
        XCTAssertFalse(corrected.isLightingEligible)
    }

    func testP04AlignmentGivesActionableDirectionsWithHorizontalPriority() {
        let fixtures: [(FaceSample, PositioningHint)] = [
            (face(centerX: 0.439), .moveRight), (face(centerX: 0.561), .moveLeft),
            (face(centerY: 0.409), .moveDown), (face(centerY: 0.591), .moveUp),
            (face(centerX: 0.439, centerY: 0.591), .moveRight)
        ]
        for (sample, expected) in fixtures {
            let result = update(.empty, .aligning, face: sample, at: 0)
            XCTAssertEqual(result.hint, expected)
            XCTAssertNil(result.history.stableSinceMS)
            XCTAssertEqual(result.stage, .aligning)
        }
    }

    func testP04FollowingAllowsNaturalMovementAndFartherFaceAtInclusiveLimits() {
        // Target width .4, height .6: following margins .10/.15; min size .20/.30.
        for sample in [face(centerX: 0.4), face(centerX: 0.6),
                       face(centerY: 0.35), face(centerY: 0.65),
                       face(width: 0.20, height: 0.30)] {
            let result = update(.empty, .following, face: sample, at: 0)
            XCTAssertEqual(result.hint, .following)
            XCTAssertTrue(result.isLightingEligible)
        }
        for (sample, expected) in [(face(centerX: 0.399_999), PositioningHint.moveRight),
                                   (face(centerX: 0.600_001), .moveLeft),
                                   (face(centerY: 0.349_999), .moveDown),
                                   (face(centerY: 0.650_001), .moveUp),
                                   (face(width: 0.199_999), .closer),
                                   (face(height: 0.299_999), .closer)] {
            XCTAssertEqual(update(.empty, .following, face: sample, at: 0).hint, expected)
        }
        // This comfortable following position still needs adjustment for first acquisition.
        XCTAssertEqual(update(.empty, .aligning, face: face(centerY: 0.62), at: 0).hint, .moveUp)
        XCTAssertEqual(update(.empty, .following, face: face(centerY: 0.62), at: 0).hint, .following)
        var history = PositioningHistory.empty
        for time in stride(from: Int64(0), through: 2_000, by: 250) {
            let result = update(history, .aligning, face: face(width: 0.20, height: 0.30), at: time)
            XCTAssertEqual(result.stage, time < 2_000 ? .aligning : .following)
            history = result.history
        }
    }

    private var neutralPose: FacePose { FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0) }

    private func face(
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.3,
        height: Double = 0.45,
        pose: FacePose? = FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
    ) -> FaceSample {
        FaceSample(geometry: FaceGeometry(centerX: centerX, centerY: centerY, width: width, height: height), pose: pose)
    }

    private func update(
        _ history: PositioningHistory,
        _ stage: TrackingStage,
        face: FaceSample?,
        at timestamp: Int64
    ) -> PositioningResult {
        PositioningRules.update(history: history, stage: stage, target: target, face: face, timestampMS: timestamp)
    }
}
