import Foundation

enum TrackingStage: Sendable, Equatable {
    case aligning
    case following
}

enum PositioningHint: Sendable, Equatable {
    case placeFace
    case trackingLost
    case centerFace
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case farther
    case closer
    case lookStraight
    case holdStill
    case following
}

struct PositioningHistory: Sendable, Equatable {
    var filteredFace: FaceSample?
    var poseIsValid = false
    var holdAnchor: FaceSample?
    var stableSinceMS: Int64?
    var previousObservationMS: Int64?

    static let empty = PositioningHistory()
}

struct PositioningResult: Sendable, Equatable {
    let history: PositioningHistory
    let stage: TrackingStage
    let hint: PositioningHint
    let rawFace: FaceSample?
    let filteredFace: FaceSample?
    let isLightingEligible: Bool
}

enum PositioningRules {
    static func update(
        history original: PositioningHistory,
        stage originalStage: TrackingStage,
        target: FaceGeometry?,
        face rawFace: FaceSample?,
        timestampMS: Int64,
        configuration: TrackingConfiguration = .provisional
    ) -> PositioningResult {
        var history = original
        let face = rawFace?.validated
        let deltaMS = history.previousObservationMS.map { timestampMS - $0 }
        let continuous = deltaMS.map { $0 > 0 && $0 <= configuration.timing.maximumContinuousSampleGapMS } == true

        if let face {
            history.filteredFace = filtered(face, from: continuous ? history.filteredFace : nil, deltaMS: deltaMS, configuration: configuration)
        } else {
            history.filteredFace = nil
        }

        let previousLatch = history.poseIsValid
        history.poseIsValid = updatedPoseLatch(
            previous: previousLatch,
            pose: history.filteredFace?.pose,
            configuration: configuration
        )
        history.previousObservationMS = timestampMS

        guard let target, target.isUsableInViewport, let filteredFace = history.filteredFace else {
            history.holdAnchor = nil
            history.stableSinceMS = nil
            return result(history: history, stage: originalStage, hint: originalStage == .aligning ? .placeFace : .trackingLost, rawFace: face)
        }

        let correction = hint(stage: originalStage, target: target, face: filteredFace, poseIsValid: history.poseIsValid, configuration: configuration)

        guard originalStage == .aligning else {
            history.holdAnchor = nil
            history.stableSinceMS = nil
            return result(history: history, stage: .following, hint: correction, rawFace: face)
        }

        guard correction == .holdStill else {
            history.holdAnchor = nil
            history.stableSinceMS = nil
            return result(history: history, stage: .aligning, hint: correction, rawFace: face)
        }

        let stableSinceMS: Int64
        if continuous, let anchor = history.holdAnchor, let since = history.stableSinceMS,
           !movedBeyondAnchor(filteredFace, anchor: anchor, configuration: configuration) {
            stableSinceMS = since
        } else {
            history.holdAnchor = filteredFace
            stableSinceMS = timestampMS
        }
        history.stableSinceMS = stableSinceMS

        let acquired = timestampMS - stableSinceMS >= configuration.timing.acquisitionHoldMS
        if acquired {
            history.holdAnchor = nil
            history.stableSinceMS = nil
        }
        return result(history: history, stage: acquired ? .following : .aligning, hint: acquired ? .following : .holdStill, rawFace: face)
    }

    private static func result(history: PositioningHistory, stage: TrackingStage, hint: PositioningHint, rawFace: FaceSample?) -> PositioningResult {
        PositioningResult(
            history: history,
            stage: stage,
            hint: hint,
            rawFace: rawFace,
            filteredFace: history.filteredFace,
            isLightingEligible: rawFace?.pose != nil && history.poseIsValid && (hint == .holdStill || hint == .following)
        )
    }

    private static func filtered(
        _ face: FaceSample,
        from previous: FaceSample?,
        deltaMS: Int64?,
        configuration: TrackingConfiguration
    ) -> FaceSample {
        guard let previous, let deltaMS else { return face }
        let alpha = 1 - exp(-Double(deltaMS) / configuration.timing.guidanceEMATimeConstantMS)
        func value(_ old: Double, _ new: Double) -> Double { old + alpha * (new - old) }
        let geometry = FaceGeometry(
            centerX: value(previous.geometry.centerX, face.geometry.centerX),
            centerY: value(previous.geometry.centerY, face.geometry.centerY),
            width: value(previous.geometry.width, face.geometry.width),
            height: value(previous.geometry.height, face.geometry.height)
        )
        let pose: FacePose?
        if let old = previous.pose, let new = face.pose {
            pose = FacePose(
                yawDegrees: value(old.yawDegrees, new.yawDegrees),
                pitchDegrees: value(old.pitchDegrees, new.pitchDegrees),
                rollDegrees: value(old.rollDegrees, new.rollDegrees)
            )
        } else {
            pose = face.pose
        }
        return FaceSample(geometry: geometry, pose: pose)
    }

    private static func updatedPoseLatch(
        previous: Bool,
        pose: FacePose?,
        configuration: TrackingConfiguration
    ) -> Bool {
        guard let pose else { return false }
        let limits = configuration.positioning
        // Discontinuous observations already reset the filter to the raw pose.
        return previous
            ? within(pose, yaw: limits.poseExitYawDegrees, pitch: limits.poseExitPitchDegrees, roll: limits.poseExitRollDegrees)
            : within(pose, yaw: limits.poseEntryYawDegrees, pitch: limits.poseEntryPitchDegrees, roll: limits.poseEntryRollDegrees)
    }

    private static func within(_ pose: FacePose, yaw: Double, pitch: Double, roll: Double) -> Bool {
        abs(pose.yawDegrees) <= yaw && abs(pose.pitchDegrees) <= pitch && abs(pose.rollDegrees) <= roll
    }

    private static func hint(
        stage: TrackingStage,
        target: FaceGeometry,
        face: FaceSample,
        poseIsValid: Bool,
        configuration: TrackingConfiguration
    ) -> PositioningHint {
        let position = configuration.positioning
        let dx = face.geometry.centerX - target.centerX
        let dy = face.geometry.centerY - target.centerY
        let centerTolerance = stage == .following
            ? position.followingCenterToleranceTargetFraction
            : position.centerToleranceTargetFraction
        let horizontalTolerance = centerTolerance * target.width
        let verticalTolerance = centerTolerance * target.height
        if outsideInclusive(face.geometry.centerX, center: target.centerX, delta: horizontalTolerance) {
            return dx < 0 ? .moveRight : .moveLeft
        }
        if outsideInclusive(face.geometry.centerY, center: target.centerY, delta: verticalTolerance) {
            return dy < 0 ? .moveDown : .moveUp
        }
        if face.geometry.width > position.maximumFaceScaleTargetFraction * target.width
            || face.geometry.height > position.maximumFaceScaleTargetFraction * target.height {
            return .farther
        }
        if face.geometry.width < position.minimumFaceScaleTargetFraction * target.width
            || face.geometry.height < position.minimumFaceScaleTargetFraction * target.height {
            return .closer
        }
        if !poseIsValid { return .lookStraight }
        return stage == .aligning ? .holdStill : .following
    }

    static func movedBeyondAnchor(
        _ face: FaceSample,
        anchor: FaceSample,
        configuration: TrackingConfiguration
    ) -> Bool {
        let limits = configuration.positioning
        let geometryMoved = outsideInclusive(face.geometry.centerX, center: anchor.geometry.centerX, delta: limits.anchorPositionDeltaNormalized)
            || outsideInclusive(face.geometry.centerY, center: anchor.geometry.centerY, delta: limits.anchorPositionDeltaNormalized)
            || outsideInclusive(face.geometry.width, center: anchor.geometry.width, delta: limits.anchorSizeDeltaNormalized)
            || outsideInclusive(face.geometry.height, center: anchor.geometry.height, delta: limits.anchorSizeDeltaNormalized)
        guard !geometryMoved else { return true }
        guard let pose = face.pose, let anchorPose = anchor.pose else { return true }
        return outsideInclusive(pose.yawDegrees, center: anchorPose.yawDegrees, delta: limits.anchorAngleDeltaDegrees)
            || outsideInclusive(pose.pitchDegrees, center: anchorPose.pitchDegrees, delta: limits.anchorAngleDeltaDegrees)
            || outsideInclusive(pose.rollDegrees, center: anchorPose.rollDegrees, delta: limits.anchorAngleDeltaDegrees)
    }

    private static func outsideInclusive(_ value: Double, center: Double, delta: Double) -> Bool {
        value < center - delta || value > center + delta
    }
}
