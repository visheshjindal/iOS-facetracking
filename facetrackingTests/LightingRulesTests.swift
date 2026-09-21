import XCTest
@testable import facetracking

final class LightingRulesTests: XCTestCase {
    func testL04ExposureEntryAndExitBoundaries() {
        XCTAssertEqual(classify(metrics(median: 54)).assessment, .tooDark)
        XCTAssertEqual(classify(metrics(median: 55)).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(shadow: 0.25)).assessment, .tooDark)
        XCTAssertEqual(classify(metrics(shadow: 0.249_999)).assessment, .acceptable)

        XCTAssertEqual(classify(metrics(median: 64), active: .tooDark).assessment, .tooDark)
        XCTAssertEqual(classify(metrics(median: 65), active: .tooDark).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(shadow: 0.20), active: .tooDark).assessment, .tooDark)
        XCTAssertEqual(classify(metrics(shadow: 0.199_999), active: .tooDark).assessment, .acceptable)

        XCTAssertEqual(classify(metrics(median: 205)).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(median: 206)).assessment, .tooBright)
        XCTAssertEqual(classify(metrics(highlight: 0.20)).assessment, .tooBright)
        XCTAssertEqual(classify(metrics(highlight: 0.199_999)).assessment, .acceptable)

        XCTAssertEqual(classify(metrics(median: 195), active: .tooBright).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(median: 196), active: .tooBright).assessment, .tooBright)
        XCTAssertEqual(classify(metrics(highlight: 0.15), active: .tooBright).assessment, .tooBright)
        XCTAssertEqual(classify(metrics(highlight: 0.149_999), active: .tooBright).assessment, .acceptable)
    }

    func testL05ImbalanceRequiresDifferenceAndRatioWithStrictExit() {
        XCTAssertEqual(classify(metrics(left: 70, right: 100)).assessment, .uneven)
        XCTAssertEqual(classify(metrics(left: 70, right: 100)).side, .left)
        XCTAssertEqual(classify(metrics(left: 73, right: 100)).assessment, .acceptable) // difference alone too small
        XCTAssertEqual(classify(metrics(left: 57, right: 80)).assessment, .acceptable) // ratio alone is insufficient

        XCTAssertEqual(classify(metrics(left: 80, right: 100), active: .uneven).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(left: 82, right: 102), active: .uneven).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(left: 79, right: 100), active: .uneven).assessment, .uneven)

        XCTAssertEqual(classify(metrics(left: 0, right: 0)).assessment, .acceptable)
        XCTAssertEqual(classify(metrics(left: 0, right: 30)).assessment, .uneven)
    }

    func testL05VerticalOrBothAxesProducesNoSide() {
        let vertical = classify(metrics(top: 60, bottom: 100))
        XCTAssertEqual(vertical.assessment, .uneven)
        XCTAssertNil(vertical.side)

        let both = classify(metrics(left: 60, right: 100, top: 60, bottom: 100))
        XCTAssertEqual(both.assessment, .uneven)
        XCTAssertNil(both.side)
    }

    func testL06HighContrastKeepsBothExitBandsAndRecoversToRemainingWarning() {
        XCTAssertEqual(classify(metrics(median: 54, highlight: 0.20)).assessment, .highContrast)
        XCTAssertEqual(classify(metrics(median: 64, highlight: 0.15), active: .highContrast).assessment, .highContrast)
        XCTAssertEqual(classify(metrics(median: 64, highlight: 0.149), active: .highContrast).assessment, .tooDark)
        XCTAssertEqual(classify(metrics(median: 65, shadow: 0.19, highlight: 0.15), active: .highContrast).assessment, .tooBright)
    }

    func testL07Warning399And400AndAcceptable699And700() {
        var warning = LightingHistory()
        warning = update(warning, metrics: metrics(median: 54), at: 0)
        warning = update(warning, metrics: metrics(median: 54), at: 200)
        warning = update(warning, metrics: metrics(median: 54), at: 399)
        XCTAssertEqual(warning.activeAssessment, .unknown)
        warning = update(warning, metrics: metrics(median: 54), at: 400)
        XCTAssertEqual(warning.activeAssessment, .tooDark)

        var acceptable = LightingHistory()
        for timestamp: Int64 in [0, 250, 500, 699] { acceptable = update(acceptable, metrics: metrics(), at: timestamp) }
        XCTAssertEqual(acceptable.activeAssessment, .unknown)
        acceptable = update(acceptable, metrics: metrics(), at: 700)
        XCTAssertEqual(acceptable.activeAssessment, .acceptable)
        XCTAssertEqual(acceptable.acceptableEvidenceSinceMS, 0)
    }

    func testL07AlternatingCandidatesNeverCommit() {
        var history = LightingHistory()
        for (timestamp, median): (Int64, Double) in [(0, 54.0), (200, 206.0), (400, 54.0), (600, 206.0), (800, 54.0)] {
            history = update(history, metrics: metrics(median: median), at: timestamp)
        }
        XCTAssertEqual(history.activeAssessment, .unknown)
    }

    func testL08SideAndNoSideChangesNeedFreshPersistence() {
        var history = LightingHistory(activeAssessment: .uneven, activeSide: .left, previousSampleMS: -1)
        for timestamp: Int64 in [0, 200, 399] { history = update(history, metrics: metrics(left: 100, right: 60), at: timestamp) }
        XCTAssertEqual(history.activeSide, .left)
        history = update(history, metrics: metrics(left: 100, right: 60), at: 400)
        XCTAssertEqual(history.activeSide, .right)

        history = update(history, metrics: metrics(top: 60, bottom: 100), at: 600)
        history = update(history, metrics: metrics(left: 100, right: 60), at: 800) // change-back clears candidate
        history = update(history, metrics: metrics(top: 60, bottom: 100), at: 1_000)
        history = update(history, metrics: metrics(top: 60, bottom: 100), at: 1_200)
        history = update(history, metrics: metrics(top: 60, bottom: 100), at: 1_399)
        XCTAssertEqual(history.activeSide, .right)
        history = update(history, metrics: metrics(top: 60, bottom: 100), at: 1_400)
        XCTAssertNil(history.activeSide)
    }

    func testL09GapInvalidAndOutOfOrderRules() {
        var history = update(.empty, metrics: metrics(median: 54), at: 0)
        history = update(history, metrics: metrics(median: 54), at: 300)
        XCTAssertEqual(history.candidateSinceMS, 0)
        history = update(history, metrics: metrics(median: 54), at: 601)
        XCTAssertEqual(history.activeAssessment, .unknown)
        XCTAssertNil(history.candidateAssessment) // gap sample discarded
        history = update(history, metrics: metrics(median: 54), at: 800)
        XCTAssertEqual(history.candidateSinceMS, 800)

        var warning = LightingHistory(activeAssessment: .tooDark, previousSampleMS: 1_000)
        let oldInvalid = update(warning, metrics: nil, eligible: false, at: 999)
        XCTAssertEqual(oldInvalid, warning)
        warning = update(warning, metrics: nil, eligible: false, at: 1_100)
        XCTAssertEqual(warning.activeAssessment, .unknown)
    }

    func testL10AcceptableCompactsAt1500FromCandidateStartOnlyOnFreshObservation() {
        var history = LightingHistory()
        for timestamp: Int64 in [0, 250, 500, 700] { history = update(history, metrics: metrics(), at: timestamp) }
        XCTAssertEqual(history.activeAssessment, .acceptable)
        XCTAssertFalse(LightingRules.isAcceptableCompact(history: history, atMS: 700))
        XCTAssertFalse(LightingRules.isAcceptableCompact(history: history, atMS: 1_499))
        for timestamp: Int64 in [950, 1_200, 1_450] {
            history = update(history, metrics: metrics(), at: timestamp)
        }
        history = update(history, metrics: metrics(), at: 1_500) // fresh evidence
        XCTAssertTrue(LightingRules.isAcceptableCompact(history: history, atMS: 1_500))
    }

    private func classify(_ value: FaceLightingMetrics, active: LightingAssessment = .unknown) -> (assessment: LightingAssessment, side: LightingSide?) {
        LightingRules.classify(metrics: value, active: active)
    }
    private func update(
        _ history: LightingHistory,
        metrics: FaceLightingMetrics?,
        eligible: Bool = true,
        at timestamp: Int64
    ) -> LightingHistory {
        LightingRules.update(history: history, metrics: metrics, isEligible: eligible, timestampMS: timestamp).history
    }
}

func metrics(
    median: Double = 100,
    shadow: Double = 0,
    highlight: Double = 0,
    left: Double = 100,
    right: Double = 100,
    top: Double = 100,
    bottom: Double = 100
) -> FaceLightingMetrics {
    FaceLightingMetrics(
        median: median,
        globalTrimmedMean: 100,
        leftTrimmedMean: left,
        rightTrimmedMean: right,
        topTrimmedMean: top,
        bottomTrimmedMean: bottom,
        shadowFraction: shadow,
        highlightFraction: highlight,
        totalCount: 128,
        leftCount: 64,
        rightCount: 64,
        topCount: 64,
        bottomCount: 64
    )
}
