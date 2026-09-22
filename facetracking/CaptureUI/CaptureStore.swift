import Observation

@MainActor
@Observable
final class CaptureStore {
    private(set) var viewState: CaptureViewState

    @ObservationIgnored private var session = SessionState()
    @ObservationIgnored private let dependencies: CaptureDependencies
    @ObservationIgnored private let dismiss: () -> Void
    @ObservationIgnored private var authorizationRequestInFlight = false
    @ObservationIgnored private var latestSelection: CameraSelection?
    @ObservationIgnored private let watchdog: AnalysisWatchdog

    var previewSession: CameraPreviewSession { dependencies.camera.previewSession }

    init(dependencies: CaptureDependencies, dismiss: @escaping () -> Void) {
        self.dependencies = dependencies
        self.dismiss = dismiss
        watchdog = AnalysisWatchdog(clock: dependencies.clock, scheduler: dependencies.scheduler)
        viewState = CaptureViewState(session: session, selection: nil)
        watchdog.onEvent = { [weak self] event in self?.send(event) }
    }

    func routeAppeared(isSceneActive: Bool) {
        send(.routePresenceChanged(isPresent: true, atMS: now))
        send(.sceneActivityChanged(isActive: isSceneActive, atMS: now))
        refreshAuthorization()
    }

    func routeDisappeared() {
        send(.routePresenceChanged(isPresent: false, atMS: now))
        dependencies.camera.tearDown()
    }

    func sceneActivityChanged(isActive: Bool) {
        send(.sceneActivityChanged(isActive: isActive, atMS: now))
        if isActive { refreshAuthorization() }
    }

    func viewportChanged(width: Double, height: Double) {
        send(.viewportChanged(
            SessionViewport(widthPoints: width, heightPoints: height, transformRevision: 0),
            atMS: now
        ))
    }

    func grantCameraAccess() {
        guard session.authorization == .notDetermined, !authorizationRequestInFlight else { return }
        authorizationRequestInFlight = true
        dependencies.authorization.requestAuthorization { [weak self] authorization in
            Task { @MainActor in
                guard let self else { return }
                self.authorizationRequestInFlight = false
                self.send(.authorizationChanged(authorization, atMS: self.now))
            }
        }
    }

    func openSettings() {
        dependencies.settingsOpener.openSettings()
    }

    func retry() {
        send(.retry(atMS: now))
    }

    func restartAfterLoss() {
        send(.restartAfterLoss(atMS: now))
    }

    func exit() {
        send(.exit(atMS: now))
    }

    private var now: Int64 { dependencies.clock.nowMilliseconds() }

    private func refreshAuthorization() {
        send(.authorizationChanged(dependencies.authorization.currentAuthorization(), atMS: now))
    }

    private func send(_ event: SessionEvent) {
        let result = SessionTransition.reduce(state: session, event: event)
        session = result.state
        publish()
        for effect in result.effects { dispatch(effect) }
    }

    private func dispatch(_ effect: SessionEffect) {
        switch effect {
        case let .requestCameraStart(sessionID):
            guard let viewport = session.viewport else { return }
            dependencies.camera.start(
                context: FrameAnalysisContext(
                    sessionID: sessionID,
                    geometryRevision: session.geometryRevision,
                    viewportPoints: CoordinateSize(width: viewport.widthPoints, height: viewport.heightPoints),
                    previewMirrored: true,
                    outputRotationDegrees: 0
                ),
                eventHandler: cameraEventHandler,
                observationHandler: observationHandler
            )
        case let .requestCameraStop(sessionID):
            dependencies.camera.stop(sessionID: sessionID, eventHandler: cameraEventHandler)
        case .dismissCapture:
            dismiss()
        case let .scheduleWatchdog(sessionID, _):
            watchdog.start(sessionID: sessionID)
        case let .cancelWatchdog(sessionID):
            watchdog.cancel(sessionID: sessionID)
        case let .scheduleFreshness(sessionID, expectedSampleMS):
            watchdog.scheduleFreshness(sessionID: sessionID, expectedSampleMS: expectedSampleMS)
        case let .cancelFreshness(sessionID):
            watchdog.cancelFreshness(sessionID: sessionID)
        }
    }

    private var observationHandler: @Sendable (FrameObservation) -> Void {
        { [weak self] observation in
            MainActor.assumeIsolated { self?.receive(observation) }
        }
    }

    private func receive(_ observation: FrameObservation) {
        guard session.desiredRunning,
              observation.sessionID == session.activeSessionID,
              observation.geometryRevision == session.geometryRevision
        else { return }
        let delivered = now - observation.capturedAtMS > TrackingConfiguration.provisional.timing.faceFreshnessMS
            ? FrameObservation(
                sessionID: observation.sessionID,
                geometryRevision: observation.geometryRevision,
                capturedAtMS: observation.capturedAtMS,
                resultAtMS: observation.resultAtMS,
                face: nil,
                lighting: nil
            )
            : observation
        send(.observation(delivered))
    }

    private var cameraEventHandler: @Sendable (CameraServiceEvent) -> Void {
        { [weak self] event in
            Task { @MainActor in self?.receive(event) }
        }
    }

    private func receive(_ event: CameraServiceEvent) {
        switch event {
        case let .started(sessionID, selection):
            latestSelection = selection
            send(.cameraStarted(sessionID: sessionID))
        case let .stopped(sessionID):
            send(.cameraStopped(sessionID: sessionID))
        case let .mediaServicesReset(sessionID):
            send(.cameraMediaServicesReset(sessionID: sessionID, atMS: now))
        case let .interrupted(sessionID):
            send(.cameraInterrupted(sessionID: sessionID))
        case .interruptionEnded:
            send(.interruptionEnded(atMS: now))
        case let .failed(sessionID, failure):
            send(.cameraFailed(sessionID: sessionID, failure: failure))
        }
    }

    private func publish() {
        viewState = CaptureViewState(session: session, selection: latestSelection)
    }
}
