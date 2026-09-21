import XCTest
@testable import facetracking

final class SessionTransitionTests: XCTestCase {
    private let viewport = SessionViewport(widthPoints: 390, heightPoints: 844, transformRevision: 1)

    func testS01AllEligibilityCombinationsAndDuplicateEventsStartExactlyOnce() {
        for authorized in [false, true] {
            for active in [false, true] {
                for present in [false, true] {
                    for validViewport in [false, true] {
                        var state = SessionState()
                        var effects: [SessionEffect] = []
                        apply(.authorizationChanged(authorized ? .authorized : .denied, atMS: 0), to: &state, recording: &effects)
                        apply(.sceneActivityChanged(isActive: active, atMS: 1), to: &state, recording: &effects)
                        apply(.routePresenceChanged(isPresent: present, atMS: 2), to: &state, recording: &effects)
                        let candidate = validViewport ? viewport : SessionViewport(widthPoints: 0, heightPoints: 844, transformRevision: 1)
                        apply(.viewportChanged(candidate, atMS: 3), to: &state, recording: &effects)

                        let starts = effects.filter { if case .requestCameraStart = $0 { true } else { false } }
                        XCTAssertEqual(starts.count, authorized && active && present && validViewport ? 1 : 0)

                        let beforeDuplicate = state
                        XCTAssertUnchanged(.sceneActivityChanged(isActive: active, atMS: 4), state: state)
                        XCTAssertUnchanged(.routePresenceChanged(isPresent: present, atMS: 5), state: state)
                        XCTAssertUnchanged(.viewportChanged(candidate, atMS: 6), state: state)
                        XCTAssertEqual(state, beforeDuplicate)
                    }
                }
            }
        }
    }

    func testS02ObsoleteIdentityRevisionAndTimestampsLeaveEntireResultUnchanged() {
        var state = runningState()
        state.lightingHistory.candidateAssessment = .dark
        state.lightingHistory.candidateSinceMS = 10
        apply(.observation(observation(sessionID: 1, revision: 1, timestampMS: 100)), to: &state)

        XCTAssertUnchanged(.observation(observation(sessionID: 0, revision: 1, timestampMS: 101)), state: state)
        XCTAssertUnchanged(.observation(observation(sessionID: 1, revision: 0, timestampMS: 101)), state: state)
        XCTAssertUnchanged(.observation(observation(sessionID: 1, revision: 1, timestampMS: 100)), state: state)
        XCTAssertUnchanged(.observation(observation(sessionID: 1, revision: 1, timestampMS: 99)), state: state)

        var stopped = state
        apply(.sceneActivityChanged(isActive: false, atMS: 110), to: &stopped)
        XCTAssertUnchanged(.observation(observation(sessionID: 1, revision: 1, timestampMS: 111)), state: stopped)
    }

    func testS03RetryRestartAndMeaningfulViewportChangeOrderStopBeforeStart() {
        var state = runningState()
        let failure = SessionTransition.reduce(
            state: state,
            event: .cameraFailed(sessionID: 1, failure: .cameraUnavailable)
        )
        state = failure.state
        let retry = SessionTransition.reduce(state: state, event: .retry(atMS: 20))
        XCTAssertEqual(retry.state.activeSessionID, 2)
        XCTAssertEqual(retry.state.positioningHistory, .empty)
        XCTAssertEqual(retry.effects, [.requestCameraStart(sessionID: 2), .scheduleWatchdog(sessionID: 2, startedAtMS: 20)])
        assertStopBeforeStart(failure.effects + retry.effects, oldID: 1, newID: 2)

        var retryState = retry.state
        retryState.stage = .following
        retryState.rawFace = nil
        retryState.positioningHistory.previousObservationMS = 25
        let restart = SessionTransition.reduce(state: retryState, event: .restartAfterLoss(atMS: 30))
        assertStopBeforeStart(restart.effects, oldID: 2, newID: 3)
        XCTAssertEqual(restart.state.positioningHistory, .empty)
        XCTAssertEqual(restart.state.stage, .aligning)

        let jitter = SessionTransition.reduce(
            state: restart.state,
            event: .viewportChanged(SessionViewport(widthPoints: 390.49, heightPoints: 843.7, transformRevision: 1), atMS: 31)
        )
        XCTAssertEqual(jitter.state, restart.state)
        XCTAssertTrue(jitter.effects.isEmpty)

        let resized = SessionTransition.reduce(
            state: restart.state,
            event: .viewportChanged(SessionViewport(widthPoints: 390.5, heightPoints: 844, transformRevision: 1), atMS: 32)
        )
        XCTAssertEqual(resized.state.geometryRevision, 2)
        assertStopBeforeStart(resized.effects, oldID: 3, newID: 4)

        let transformed = SessionTransition.reduce(
            state: resized.state,
            event: .viewportChanged(SessionViewport(widthPoints: 390.5, heightPoints: 844, transformRevision: 2), atMS: 33)
        )
        XCTAssertEqual(transformed.state.geometryRevision, 3)
        assertStopBeforeStart(transformed.effects, oldID: 4, newID: 5)
    }

    func testS04StopAndFailureClearFaceHistoriesAndLateObservationCannotRestore() {
        var events = [
            SessionEvent.sceneActivityChanged(isActive: false, atMS: 200),
            .authorizationChanged(.denied, atMS: 200)
        ]
        events.append(contentsOf: [
            SessionFailure.frontCameraUnavailable,
            .cameraUnavailable,
            .detectorUnavailable
        ].map { .cameraFailed(sessionID: 1, failure: $0) })

        for event in events {
            var state = populatedRunningState()
            let result = SessionTransition.reduce(state: state, event: event)
            state = result.state
            assertAttemptDataCleared(state)

            let late = SessionTransition.reduce(
                state: state,
                event: .observation(observation(sessionID: 1, revision: 1, timestampMS: 201))
            )
            XCTAssertEqual(late.state, state)
            XCTAssertTrue(late.effects.isEmpty)
        }
    }

    func testS05LateCompletionsErrorsAndObservationsCannotAffectReplacementAttempt() {
        var state = runningState()
        state.failure = .cameraUnavailable
        state.activeSessionID = nil
        state.desiredRunning = false
        state.cameraStatus = .stopping(sessionID: 1)
        let retry = SessionTransition.reduce(state: state, event: .retry(atMS: 50)).state
        XCTAssertEqual(retry.activeSessionID, 2)

        let lateEvents: [SessionEvent] = [
            .cameraStarted(sessionID: 1),
            .cameraStopped(sessionID: 1),
            .cameraFailed(sessionID: 1, failure: .detectorUnavailable),
            .cameraInterrupted(sessionID: 1),
            .observation(observation(sessionID: 1, revision: 1, timestampMS: 51)),
            .freshnessExpired(sessionID: 1, expectedSampleMS: 50, atMS: 400),
            .watchdogFired(sessionID: 1, atMS: 6_000)
        ]
        for event in lateEvents { XCTAssertUnchanged(event, state: retry) }

        var permissionRevoked = runningState()
        apply(.authorizationChanged(.denied, atMS: 55), to: &permissionRevoked)
        for event in lateEvents where event != .cameraStopped(sessionID: 1) {
            XCTAssertUnchanged(event, state: permissionRevoked)
        }
        let completedStop = SessionTransition.reduce(state: permissionRevoked, event: .cameraStopped(sessionID: 1))
        XCTAssertEqual(completedStop.state.cameraStatus, .stopped)
        XCTAssertTrue(completedStop.effects.isEmpty)

        var interrupted = runningState()
        apply(.cameraInterrupted(sessionID: 1), to: &interrupted)
        for event in lateEvents { XCTAssertUnchanged(event, state: interrupted) }
        let resumed = SessionTransition.reduce(state: interrupted, event: .interruptionEnded(atMS: 60)).state
        XCTAssertEqual(resumed.activeSessionID, 2)
        XCTAssertUnchanged(.cameraStopped(sessionID: 1), state: resumed)
    }

    func testS06FreshnessBoundariesExpectedTimestampAndFollowingRetention() {
        var state = populatedRunningState(timestampMS: 100)
        state.stage = .following
        XCTAssertUnchanged(
            .freshnessExpired(sessionID: 1, expectedSampleMS: 100, atMS: 400),
            state: state
        )
        XCTAssertUnchanged(
            .freshnessExpired(sessionID: 1, expectedSampleMS: 99, atMS: 401),
            state: state
        )

        let expired = SessionTransition.reduce(
            state: state,
            event: .freshnessExpired(sessionID: 1, expectedSampleMS: 100, atMS: 401)
        )
        XCTAssertNil(expired.state.rawFace)
        XCTAssertEqual(expired.state.stage, .following)
        XCTAssertTrue(expired.state.isTrackingLost)
        XCTAssertEqual(expired.state.positioningHistory, .empty)
        XCTAssertEqual(expired.state.lightingHistory, .empty)
    }

    func testS06WatchdogBoundaryAndNilFaceAnalysisResetBaseline() {
        let state = runningState(startedAtMS: 100)
        XCTAssertUnchanged(.watchdogFired(sessionID: 1, atMS: 5_100), state: state)

        let failed = SessionTransition.reduce(state: state, event: .watchdogFired(sessionID: 1, atMS: 5_101))
        XCTAssertEqual(failed.state.failure, .detectorUnavailable)
        XCTAssertFalse(failed.state.desiredRunning)

        var keptAlive = state
        apply(.observation(observation(
            sessionID: 1,
            revision: 1,
            timestampMS: 5_000,
            resultAtMS: 5_300,
            face: nil
        )), to: &keptAlive)
        XCTAssertEqual(keptAlive.lastSuccessfulAnalysisMS, 5_300)
        XCTAssertUnchanged(.watchdogFired(sessionID: 1, atMS: 10_300), state: keptAlive)
        XCTAssertEqual(
            SessionTransition.reduce(state: keptAlive, event: .watchdogFired(sessionID: 1, atMS: 10_301)).state.failure,
            .detectorUnavailable
        )
    }

    func testCheckedIdentifierAndGeometryRevisionOverflowNeverWraps() {
        var identifierState = SessionState()
        identifierState.authorization = .authorized
        identifierState.isSceneActive = true
        identifierState.isRoutePresent = true
        identifierState.viewport = viewport
        identifierState.geometryRevision = 1
        identifierState.lastAllocatedSessionID = .max
        let identifier = SessionTransition.reduce(state: identifierState, event: .sceneActivityChanged(isActive: false, atMS: 0))
        var eligibleAgain = identifier.state
        eligibleAgain.isSceneActive = false
        let overflow = SessionTransition.reduce(state: eligibleAgain, event: .sceneActivityChanged(isActive: true, atMS: 1))
        XCTAssertEqual(overflow.state.failure, .sessionIdentifierExhausted)
        XCTAssertNil(overflow.state.activeSessionID)
        XCTAssertTrue(overflow.effects.isEmpty)

        var revisionState = runningState()
        revisionState.geometryRevision = .max
        let revision = SessionTransition.reduce(
            state: revisionState,
            event: .viewportChanged(SessionViewport(widthPoints: 500, heightPoints: 844, transformRevision: 1), atMS: 2)
        )
        XCTAssertEqual(revision.state.failure, .geometryRevisionExhausted)
        XCTAssertNil(revision.state.activeSessionID)
        XCTAssertFalse(revision.state.desiredRunning)
        XCTAssertFalse(revision.effects.contains(.requestCameraStart(sessionID: 0)))
    }

    func testRepeatedLifecycleCyclesAllocateMonotonicallyAndExitDismissesAfterStopRequest() {
        var state = runningState()
        for cycle in 0..<4 {
            let stop = SessionTransition.reduce(state: state, event: .sceneActivityChanged(isActive: false, atMS: Int64(cycle * 10 + 1)))
            XCTAssertEqual(stop.effects.last, .requestCameraStop(sessionID: UInt64(cycle + 1)))
            let start = SessionTransition.reduce(state: stop.state, event: .sceneActivityChanged(isActive: true, atMS: Int64(cycle * 10 + 2)))
            XCTAssertEqual(start.state.activeSessionID, UInt64(cycle + 2))
            state = start.state
        }

        let exit = SessionTransition.reduce(state: state, event: .exit(atMS: 100))
        XCTAssertEqual(exit.effects.suffix(2), [.requestCameraStop(sessionID: 5), .dismissCapture])
        XCTAssertFalse(exit.state.isRoutePresent)
    }

    private func runningState(startedAtMS: Int64 = 0) -> SessionState {
        var state = SessionState()
        apply(.authorizationChanged(.authorized, atMS: startedAtMS), to: &state)
        apply(.sceneActivityChanged(isActive: true, atMS: startedAtMS), to: &state)
        apply(.routePresenceChanged(isPresent: true, atMS: startedAtMS), to: &state)
        apply(.viewportChanged(viewport, atMS: startedAtMS), to: &state)
        return state
    }

    private func populatedRunningState(timestampMS: Int64 = 100) -> SessionState {
        var state = runningState()
        apply(.observation(observation(sessionID: 1, revision: 1, timestampMS: timestampMS)), to: &state)
        state.lightingHistory.activeAssessment = .dark
        state.lightingHistory.candidateAssessment = .acceptable
        state.lightingHistory.previousSampleMS = timestampMS
        return state
    }

    private func observation(
        sessionID: UInt64,
        revision: UInt64,
        timestampMS: Int64,
        resultAtMS: Int64? = nil,
        face: FaceSample? = FaceSample(
            geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 0.5, height: 0.32),
            pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
        )
    ) -> FrameObservation {
        FrameObservation(
            sessionID: sessionID,
            geometryRevision: revision,
            capturedAtMS: timestampMS,
            resultAtMS: resultAtMS,
            face: face,
            lighting: nil
        )
    }

    private func apply(_ event: SessionEvent, to state: inout SessionState, recording effects: inout [SessionEffect]) {
        let result = SessionTransition.reduce(state: state, event: event)
        state = result.state
        effects.append(contentsOf: result.effects)
    }

    private func apply(_ event: SessionEvent, to state: inout SessionState) {
        var ignored: [SessionEffect] = []
        apply(event, to: &state, recording: &ignored)
    }

    private func XCTAssertUnchanged(_ event: SessionEvent, state: SessionState, file: StaticString = #filePath, line: UInt = #line) {
        let result = SessionTransition.reduce(state: state, event: event)
        XCTAssertEqual(result.state, state, file: file, line: line)
        XCTAssertTrue(result.effects.isEmpty, file: file, line: line)
    }

    private func assertStopBeforeStart(_ effects: [SessionEffect], oldID: UInt64, newID: UInt64, file: StaticString = #filePath, line: UInt = #line) {
        guard let stopIndex = effects.firstIndex(of: .requestCameraStop(sessionID: oldID)),
              let startIndex = effects.firstIndex(of: .requestCameraStart(sessionID: newID))
        else {
            return XCTFail("Missing ordered stop/start effects: \(effects)", file: file, line: line)
        }
        XCTAssertLessThan(stopIndex, startIndex, file: file, line: line)
    }

    private func assertAttemptDataCleared(_ state: SessionState, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(state.rawFace, file: file, line: line)
        XCTAssertNil(state.lastAcceptedSampleMS, file: file, line: line)
        XCTAssertEqual(state.positioningHistory, .empty, file: file, line: line)
        XCTAssertEqual(state.lightingHistory, .empty, file: file, line: line)
        XCTAssertFalse(state.desiredRunning, file: file, line: line)
    }
}
