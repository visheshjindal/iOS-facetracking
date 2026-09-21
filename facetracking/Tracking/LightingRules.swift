import Foundation

struct LightingResult: Sendable, Equatable {
    let history: LightingHistory
}

enum LightingRules {
    static func update(
        history original: LightingHistory,
        metrics: FaceLightingMetrics?,
        isEligible: Bool,
        timestampMS: Int64,
        configuration: TrackingConfiguration = .provisional
    ) -> LightingResult {
        guard original.previousSampleMS.map({ timestampMS > $0 }) ?? true else {
            return LightingResult(history: original)
        }

        guard isEligible, let metrics = metrics?.validated else {
            var reset = LightingHistory.empty
            reset.previousSampleMS = timestampMS
            return LightingResult(history: reset)
        }

        if let previous = original.previousSampleMS,
           timestampMS - previous > configuration.timing.maximumContinuousSampleGapMS {
            var reset = LightingHistory.empty
            reset.previousSampleMS = timestampMS
            return LightingResult(history: reset)
        }

        var history = original
        history.previousSampleMS = timestampMS
        let classified = classify(metrics: metrics, active: original.activeAssessment, configuration: configuration)
        let side = classified.assessment == .uneven ? classified.side : nil

        if classified.assessment == history.activeAssessment, side == history.activeSide {
            history.candidateAssessment = nil
            history.candidateSide = nil
            history.candidateSinceMS = nil
            return LightingResult(history: history)
        }

        if history.candidateAssessment != classified.assessment || history.candidateSide != side {
            history.candidateAssessment = classified.assessment
            history.candidateSide = side
            history.candidateSinceMS = timestampMS
            return LightingResult(history: history)
        }

        guard let candidateSinceMS = history.candidateSinceMS else {
            history.candidateSinceMS = timestampMS
            return LightingResult(history: history)
        }
        let persistence = classified.assessment == .acceptable
            ? configuration.timing.lightingAcceptablePersistenceMS
            : configuration.timing.lightingWarningPersistenceMS
        guard timestampMS - candidateSinceMS >= persistence else { return LightingResult(history: history) }

        history.activeAssessment = classified.assessment
        history.activeSide = side
        history.candidateAssessment = nil
        history.candidateSide = nil
        history.candidateSinceMS = nil
        history.acceptableEvidenceSinceMS = classified.assessment == .acceptable ? candidateSinceMS : nil
        return LightingResult(history: history)
    }

    static func classify(
        metrics: FaceLightingMetrics,
        active: LightingAssessment,
        configuration: TrackingConfiguration = .provisional
    ) -> (assessment: LightingAssessment, side: LightingSide?) {
        guard metrics.validated != nil else { return (.unknown, nil) }
        let lighting = configuration.lighting
        let darkUsesExit = active == .tooDark || active == .highContrast
        let brightUsesExit = active == .tooBright || active == .highContrast
        let dark = darkUsesExit
            ? metrics.median < lighting.darkExitMedianBelow || metrics.shadowFraction >= lighting.darkExitShadowFractionAtLeast
            : metrics.median < lighting.darkEntryMedianBelow || metrics.shadowFraction >= lighting.darkEntryShadowFractionAtLeast
        let bright = brightUsesExit
            ? metrics.median > lighting.brightExitMedianAbove || metrics.highlightFraction >= lighting.brightExitHighlightFractionAtLeast
            : metrics.median > lighting.brightEntryMedianAbove || metrics.highlightFraction >= lighting.brightEntryHighlightFractionAtLeast

        if dark && bright { return (.highContrast, nil) }
        if dark { return (.tooDark, nil) }
        if bright { return (.tooBright, nil) }

        let useUnevenExit = active == .uneven
        let horizontal = isImbalanced(
            metrics.leftTrimmedMean,
            metrics.rightTrimmedMean,
            useExit: useUnevenExit,
            configuration: configuration
        )
        let vertical = isImbalanced(
            metrics.topTrimmedMean,
            metrics.bottomTrimmedMean,
            useExit: useUnevenExit,
            configuration: configuration
        )
        if vertical { return (.uneven, nil) }
        if horizontal {
            return (.uneven, metrics.leftTrimmedMean < metrics.rightTrimmedMean ? .left : .right)
        }
        return (.acceptable, nil)
    }

    static func isAcceptableCompact(
        history: LightingHistory,
        atMS: Int64,
        configuration: TrackingConfiguration = .provisional
    ) -> Bool {
        guard history.activeAssessment == .acceptable,
              let start = history.acceptableEvidenceSinceMS,
              atMS >= start
        else { return false }
        return atMS - start >= configuration.timing.lightingCompactEvidenceMS
    }

    private static func isImbalanced(
        _ first: Double,
        _ second: Double,
        useExit: Bool,
        configuration: TrackingConfiguration
    ) -> Bool {
        let brighter = max(first, second)
        let darker = min(first, second)
        let difference = brighter - darker
        let ratio = brighter == 0 ? configuration.lighting.zeroBrighterMeanRatio : darker / brighter
        return useExit
            ? difference > configuration.lighting.imbalanceExitDifferenceGreaterThan
                && ratio < configuration.lighting.imbalanceExitDarkerToBrighterRatioBelow
            : difference >= configuration.lighting.imbalanceEntryDifferenceAtLeast
                && ratio <= configuration.lighting.imbalanceEntryDarkerToBrighterRatioAtMost
    }
}
