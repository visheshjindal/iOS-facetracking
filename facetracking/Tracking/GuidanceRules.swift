enum LightingAdvice: Sendable, Equatable {
    case checking
    case acceptable
    case addLightLeft
    case addLightRight
    case useSoftEvenLight
    case addMoreLight
    case reduceDirectLight
}

enum PrimaryGuidance: Sendable, Equatable {
    case positioning(PositioningHint)
    case lighting(LightingAdvice)
}

enum BadgePresentation: Sendable, Equatable {
    case iconOnly
    case expanded
}

struct LightingBadgeProjection: Sendable, Equatable {
    let assessment: LightingAssessment
    let side: LightingSide?
    let advice: LightingAdvice
    let presentation: BadgePresentation
}

struct CaptureGuidanceProjection: Sendable, Equatable {
    let primary: PrimaryGuidance
    let badge: LightingBadgeProjection?
    let showsInitialMask: Bool
    let showsReturnGuide: Bool
    let trackedOval: FaceGeometry?
}

enum GuidanceRules {
    static func project(session: SessionState, configuration: TrackingConfiguration = .provisional) -> CaptureGuidanceProjection {
        let assessment = session.lightingHistory.activeAssessment
        let side = session.lightingHistory.activeSide
        let positioningAllowsLighting = session.positioningHint == .holdStill || session.positioningHint == .following
        let primary: PrimaryGuidance
        if positioningAllowsLighting, assessment.isWarning {
            primary = .lighting(advice(for: assessment, side: side))
        } else {
            primary = .positioning(session.positioningHint)
        }

        let badge: LightingBadgeProjection?
        if session.rawFace != nil, session.failure == nil {
            let compact = session.lastAcceptedSampleMS.map {
                LightingRules.isAcceptableCompact(history: session.lightingHistory, atMS: $0, configuration: configuration)
            } ?? false
            let known = assessment != .unknown
            let expanded = positioningAllowsLighting && known && (assessment.isWarning || !compact)
            badge = LightingBadgeProjection(
                assessment: assessment,
                side: side,
                advice: advice(for: assessment, side: side),
                presentation: expanded ? .expanded : .iconOnly
            )
        } else {
            badge = nil
        }

        return CaptureGuidanceProjection(
            primary: primary,
            badge: badge,
            showsInitialMask: session.stage == .aligning,
            showsReturnGuide: session.stage == .following,
            trackedOval: session.stage == .following ? session.rawFace?.geometry : nil
        )
    }

    static func advice(for assessment: LightingAssessment, side: LightingSide?) -> LightingAdvice {
        switch assessment {
        case .unknown: .checking
        case .acceptable: .acceptable
        case .tooDark: .addMoreLight
        case .tooBright: .reduceDirectLight
        case .highContrast: .useSoftEvenLight
        case .uneven:
            switch side {
            case .left: .addLightLeft
            case .right: .addLightRight
            case .top, .bottom, nil: .useSoftEvenLight
            }
        }
    }
}
