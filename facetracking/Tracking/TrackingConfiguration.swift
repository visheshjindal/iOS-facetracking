/// Provisional, versioned algorithm constants from specification sections 7 and 8.
///
/// Values are not calibrated device measurements. Changing one requires a new
/// profile version, corresponding tests, and an explicit decision record.
struct TrackingConfiguration: Sendable, Equatable {
    static let provisional = TrackingConfiguration()

    let version = "ios-provisional-v1"
    let timing = Timing()
    let positioning = Positioning()
    let sampling = Sampling()
    let luma = Luma()
    let lighting = Lighting()

    struct Timing: Sendable, Equatable {
        let acquisitionHoldMS: Int64 = 2_000
        let maximumContinuousSampleGapMS: Int64 = 300
        let faceFreshnessMS: Int64 = 300
        let analysisStallMS: Int64 = 5_000
        let watchdogCadenceMS: Int64 = 250
        let guidanceEMATimeConstantMS: Double = 150
        let lightingWarningPersistenceMS: Int64 = 400
        let lightingAcceptablePersistenceMS: Int64 = 700
        let lightingCompactEvidenceMS: Int64 = 1_500
    }

    struct Positioning: Sendable, Equatable {
        let centerToleranceTargetFraction: Double = 0.10
        let minimumFaceScaleTargetFraction: Double = 0.65
        let maximumFaceScaleTargetFraction: Double = 0.95
        let poseEntryYawDegrees: Double = 10
        let poseEntryPitchDegrees: Double = 15
        let poseEntryRollDegrees: Double = 8
        let poseExitYawDegrees: Double = 13
        let poseExitPitchDegrees: Double = 20
        let poseExitRollDegrees: Double = 11
        let anchorPositionDeltaNormalized: Double = 0.025
        let anchorSizeDeltaNormalized: Double = 0.025
        let anchorAngleDeltaDegrees: Double = 5
    }

    struct Sampling: Sendable, Equatable {
        let gridColumns: Int = 64
        let gridRows: Int = 64
        let maximumSampleCount: Int = 4_096
        let minimumTotalSampleCount: Int = 96
        let minimumRegionalSampleCount: Int = 32
        let faceEllipseCenterU: Double = 0.5
        let faceEllipseCenterV: Double = 0.5
        let faceEllipseHorizontalRadius: Double = 0.40
        let faceEllipseVerticalRadius: Double = 0.38
        let horizontalRegionSplitU: Double = 0.5
        let verticalRegionSplitV: Double = 0.5
    }

    struct Luma: Sendable, Equatable {
        let canonicalMinimum: Int = 0
        let canonicalMaximum: Int = 255
        let videoRangeBlackLevel: Int = 16
        let videoRangeSpan: Int = 219
        let histogramBinCount: Int = 256
        let histogramTrimFractionPerTail: Double = 0.10
        let shadowMaximumInclusive: Int = 24
        let highlightMinimumInclusive: Int = 235
    }

    struct Lighting: Sendable, Equatable {
        let darkEntryMedianBelow: Double = 55
        let darkEntryShadowFractionAtLeast: Double = 0.25
        let darkExitMedianBelow: Double = 65
        let darkExitShadowFractionAtLeast: Double = 0.20
        let brightEntryMedianAbove: Double = 205
        let brightEntryHighlightFractionAtLeast: Double = 0.20
        let brightExitMedianAbove: Double = 195
        let brightExitHighlightFractionAtLeast: Double = 0.15
        let imbalanceEntryDifferenceAtLeast: Double = 28
        let imbalanceEntryDarkerToBrighterRatioAtMost: Double = 0.75
        let imbalanceExitDifferenceGreaterThan: Double = 20
        let imbalanceExitDarkerToBrighterRatioBelow: Double = 0.82
        let zeroBrighterMeanRatio: Double = 1
    }
}

/// Presentation-only values. These do not participate in tracking decisions.
enum CaptureDisplayConfiguration {
    static let maskFadeDurationMS: Int64 = 450
    static let minimumActionTargetPoints: Double = 44
}
