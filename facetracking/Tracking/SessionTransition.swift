enum SessionEvent: Sendable, Equatable {
    case authorizationChanged(CameraAuthorization, atMS: Int64)
    case sceneActivityChanged(isActive: Bool, atMS: Int64)
    case routePresenceChanged(isPresent: Bool, atMS: Int64)
    case viewportChanged(SessionViewport, atMS: Int64)
    case retry(atMS: Int64)
    case restartAfterLoss(atMS: Int64)
    case observation(FrameObservation)
    case freshnessExpired(sessionID: UInt64, expectedSampleMS: Int64, atMS: Int64)
    case watchdogFired(sessionID: UInt64, atMS: Int64)
    case cameraStarted(sessionID: UInt64)
    case cameraStopped(sessionID: UInt64)
    case cameraFailed(sessionID: UInt64, failure: SessionFailure)
    case cameraMediaServicesReset(sessionID: UInt64, atMS: Int64)
    case cameraInterrupted(sessionID: UInt64)
    case interruptionEnded(atMS: Int64)
    case exit(atMS: Int64)
}

enum SessionEffect: Sendable, Equatable {
    case requestCameraStart(sessionID: UInt64)
    case requestCameraStop(sessionID: UInt64)
    case scheduleWatchdog(sessionID: UInt64, startedAtMS: Int64)
    case cancelWatchdog(sessionID: UInt64)
    case scheduleFreshness(sessionID: UInt64, expectedSampleMS: Int64)
    case cancelFreshness(sessionID: UInt64)
    case dismissCapture
}

struct SessionTransitionResult: Sendable, Equatable {
    let state: SessionState
    let effects: [SessionEffect]
}

enum SessionTransition {
    static func reduce(
        state original: SessionState,
        event: SessionEvent,
        configuration: TrackingConfiguration = .provisional
    ) -> SessionTransitionResult {
        var state = original
        var effects: [SessionEffect] = []

        switch event {
        case let .authorizationChanged(authorization, nowMS):
            guard authorization != state.authorization else { break }
            state.authorization = authorization
            reconcileEligibility(state: &state, nowMS: nowMS, effects: &effects)

        case let .sceneActivityChanged(isActive, nowMS):
            guard isActive != state.isSceneActive else { break }
            state.isSceneActive = isActive
            reconcileEligibility(state: &state, nowMS: nowMS, effects: &effects)

        case let .routePresenceChanged(isPresent, nowMS):
            guard isPresent != state.isRoutePresent else { break }
            state.isRoutePresent = isPresent
            if !isPresent { clearAttemptData(state: &state, preservingStage: false) }
            reconcileEligibility(state: &state, nowMS: nowMS, effects: &effects)

        case let .viewportChanged(viewport, nowMS):
            if let old = state.viewport, !viewport.isMeaningfullyDifferent(from: old) { break }
            guard incrementGeometryRevision(state: &state, effects: &effects) else { break }
            state.viewport = viewport
            restartIfEligible(state: &state, nowMS: nowMS, effects: &effects)

        case let .retry(nowMS):
            guard state.failure?.isRetryable == true else { break }
            state.failure = nil
            restartIfEligible(state: &state, nowMS: nowMS, effects: &effects)

        case let .restartAfterLoss(nowMS):
            guard state.isTrackingLost else { break }
            clearAttemptData(state: &state, preservingStage: false)
            restartIfEligible(state: &state, nowMS: nowMS, effects: &effects)

        case let .observation(observation):
            guard state.desiredRunning,
                  state.failure == nil,
                  observation.sessionID == state.activeSessionID,
                  observation.geometryRevision == state.geometryRevision,
                  state.lastAcceptedSampleMS.map({ observation.capturedAtMS > $0 }) ?? true
            else { break }

            let result = PositioningRules.update(
                history: state.positioningHistory,
                stage: state.stage,
                target: state.target,
                face: observation.face,
                timestampMS: observation.capturedAtMS,
                configuration: configuration
            )
            state.positioningHistory = result.history
            state.stage = result.stage
            state.positioningHint = result.hint
            state.rawFace = result.rawFace
            state.lastAcceptedSampleMS = observation.capturedAtMS
            state.lastSuccessfulAnalysisMS = observation.resultAtMS
            state.lightingHistory = LightingRules.update(
                history: state.lightingHistory,
                metrics: observation.lighting,
                isEligible: result.isLightingEligible,
                timestampMS: observation.capturedAtMS,
                configuration: configuration
            ).history
            effects.append(.scheduleFreshness(
                sessionID: observation.sessionID,
                expectedSampleMS: observation.capturedAtMS
            ))

        case let .freshnessExpired(sessionID, expectedSampleMS, nowMS):
            guard state.desiredRunning,
                  sessionID == state.activeSessionID,
                  state.lastAcceptedSampleMS == expectedSampleMS,
                  elapsed(from: expectedSampleMS, to: nowMS, exceeds: configuration.timing.faceFreshnessMS)
            else { break }
            state.rawFace = nil
            state.positioningHint = state.stage == .following ? .trackingLost : .placeFace
            state.positioningHistory = .empty
            state.lightingHistory = .empty
            effects.append(.cancelFreshness(sessionID: sessionID))

        case let .watchdogFired(sessionID, nowMS):
            guard state.desiredRunning,
                  sessionID == state.activeSessionID,
                  let baseline = state.lastSuccessfulAnalysisMS ?? state.attemptStartedAtMS,
                  elapsed(from: baseline, to: nowMS, exceeds: configuration.timing.analysisStallMS)
            else { break }
            failCurrentAttempt(
                state: &state,
                sessionID: sessionID,
                failure: .detectorUnavailable,
                effects: &effects
            )

        case let .cameraStarted(sessionID):
            guard state.desiredRunning,
                  state.activeSessionID == sessionID,
                  state.cameraStatus == .starting(sessionID: sessionID)
            else { break }
            state.cameraStatus = .running(sessionID: sessionID)

        case let .cameraStopped(sessionID):
            guard state.activeSessionID == nil,
                  state.cameraStatus == .stopping(sessionID: sessionID)
            else { break }
            state.cameraStatus = .stopped

        case let .cameraFailed(sessionID, failure):
            guard state.desiredRunning, state.activeSessionID == sessionID else { break }
            failCurrentAttempt(state: &state, sessionID: sessionID, failure: failure, effects: &effects)

        case let .cameraMediaServicesReset(sessionID, nowMS):
            guard state.desiredRunning, state.activeSessionID == sessionID else { break }
            restartIfEligible(state: &state, nowMS: nowMS, effects: &effects)

        case let .cameraInterrupted(sessionID):
            guard state.desiredRunning, state.activeSessionID == sessionID else { break }
            invalidateCurrentAttempt(state: &state, effects: &effects)
            state.isInterrupted = true
            state.cameraStatus = .interrupted

        case let .interruptionEnded(nowMS):
            guard state.isInterrupted else { break }
            state.isInterrupted = false
            reconcileEligibility(state: &state, nowMS: nowMS, effects: &effects)

        case .exit:
            if let sessionID = state.activeSessionID {
                invalidateCurrentAttempt(state: &state, effects: &effects)
                state.cameraStatus = .stopping(sessionID: sessionID)
            } else {
                clearAttemptData(state: &state)
            }
            clearAttemptData(state: &state, preservingStage: false)
            state.isRoutePresent = false
            effects.append(.dismissCapture)
        }

        return SessionTransitionResult(state: state, effects: effects)
    }

    private static func reconcileEligibility(
        state: inout SessionState,
        nowMS: Int64,
        effects: inout [SessionEffect]
    ) {
        if state.isEligibleToRun {
            guard !state.desiredRunning else { return }
            startNewAttempt(state: &state, nowMS: nowMS, effects: &effects)
        } else if state.desiredRunning {
            invalidateCurrentAttempt(state: &state, effects: &effects)
        }
    }

    private static func restartIfEligible(
        state: inout SessionState,
        nowMS: Int64,
        effects: inout [SessionEffect]
    ) {
        if state.desiredRunning {
            invalidateCurrentAttempt(state: &state, effects: &effects)
        } else {
            clearAttemptData(state: &state)
        }
        if state.isEligibleToRun {
            startNewAttempt(state: &state, nowMS: nowMS, effects: &effects)
        }
    }

    private static func startNewAttempt(
        state: inout SessionState,
        nowMS: Int64,
        effects: inout [SessionEffect]
    ) {
        let (sessionID, overflow) = state.lastAllocatedSessionID.addingReportingOverflow(1)
        guard !overflow else {
            state.failure = .sessionIdentifierExhausted
            state.desiredRunning = false
            state.activeSessionID = nil
            state.cameraStatus = .stopped
            clearAttemptData(state: &state)
            return
        }
        state.lastAllocatedSessionID = sessionID
        state.activeSessionID = sessionID
        state.desiredRunning = true
        state.cameraStatus = .starting(sessionID: sessionID)
        clearAttemptData(state: &state, preservingStage: true)
        state.attemptStartedAtMS = nowMS
        effects.append(.requestCameraStart(sessionID: sessionID))
        effects.append(.scheduleWatchdog(sessionID: sessionID, startedAtMS: nowMS))
    }

    private static func invalidateCurrentAttempt(
        state: inout SessionState,
        effects: inout [SessionEffect]
    ) {
        guard let sessionID = state.activeSessionID else {
            state.desiredRunning = false
            clearAttemptData(state: &state)
            return
        }
        state.activeSessionID = nil
        state.desiredRunning = false
        clearAttemptData(state: &state)
        effects.append(.cancelWatchdog(sessionID: sessionID))
        effects.append(.cancelFreshness(sessionID: sessionID))
        effects.append(.requestCameraStop(sessionID: sessionID))
        state.cameraStatus = .stopping(sessionID: sessionID)
    }

    private static func failCurrentAttempt(
        state: inout SessionState,
        sessionID: UInt64,
        failure: SessionFailure,
        effects: inout [SessionEffect]
    ) {
        invalidateCurrentAttempt(state: &state, effects: &effects)
        state.failure = failure
        state.cameraStatus = .stopping(sessionID: sessionID)
    }

    private static func incrementGeometryRevision(
        state: inout SessionState,
        effects: inout [SessionEffect]
    ) -> Bool {
        let (revision, overflow) = state.geometryRevision.addingReportingOverflow(1)
        guard !overflow else {
            if state.desiredRunning {
                invalidateCurrentAttempt(state: &state, effects: &effects)
            } else {
                clearAttemptData(state: &state)
            }
            state.failure = .geometryRevisionExhausted
            return false
        }
        state.geometryRevision = revision
        return true
    }

    private static func clearAttemptData(
        state: inout SessionState,
        preservingStage: Bool = true
    ) {
        if !preservingStage { state.stage = .aligning }
        state.positioningHint = preservingStage && state.stage == .following ? .trackingLost : .placeFace
        state.rawFace = nil
        state.lastAcceptedSampleMS = nil
        state.positioningHistory = .empty
        state.lightingHistory = .empty
        state.attemptStartedAtMS = nil
        state.lastSuccessfulAnalysisMS = nil
    }

    private static func elapsed(from startMS: Int64, to endMS: Int64, exceeds thresholdMS: Int64) -> Bool {
        guard endMS > startMS else { return false }
        let (boundary, overflow) = startMS.addingReportingOverflow(thresholdMS)
        return !overflow && endMS > boundary
    }
}
