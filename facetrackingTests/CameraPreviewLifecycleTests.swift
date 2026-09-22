import AVFoundation
import XCTest
@testable import facetracking

@MainActor
final class CameraPreviewLifecycleTests: XCTestCase {
    func testAuthorizationRequestsOnceAndDeniedRestrictedNeverRequest() {
        let authorization = AuthorizationDouble(.notDetermined)
        let camera = CameraDouble()
        let store = makeStore(authorization: authorization, camera: camera)

        store.routeAppeared(isSceneActive: true)
        store.grantCameraAccess()
        store.grantCameraAccess()
        XCTAssertEqual(authorization.requestCount, 1)

        authorization.complete(.denied)
        store.grantCameraAccess()
        XCTAssertEqual(authorization.requestCount, 1)

        authorization.status = .restricted
        store.sceneActivityChanged(isActive: false)
        store.sceneActivityChanged(isActive: true)
        store.grantCameraAccess()
        XCTAssertEqual(authorization.requestCount, 1)
        XCTAssertEqual(store.viewState.authorization, .restricted)
    }

    func testSettingsAndExitUseInjectedActions() {
        let authorization = AuthorizationDouble(.denied)
        let camera = CameraDouble()
        let settings = SettingsDouble()
        var dismissCount = 0
        let store = makeStore(
            authorization: authorization,
            camera: camera,
            settings: settings,
            dismiss: { dismissCount += 1 }
        )

        store.routeAppeared(isSceneActive: true)
        store.openSettings()
        store.exit()

        XCTAssertEqual(settings.openCount, 1)
        XCTAssertEqual(dismissCount, 1)
    }

    func testAuthorizedStartWaitsForSceneRouteAndValidViewport() {
        let camera = CameraDouble()
        let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)

        store.routeAppeared(isSceneActive: false)
        store.viewportChanged(width: 390, height: 700)
        XCTAssertTrue(camera.commands.isEmpty)

        store.sceneActivityChanged(isActive: true)
        XCTAssertEqual(camera.commands, [.start(1)])
        store.sceneActivityChanged(isActive: true)
        store.viewportChanged(width: 390.1, height: 700.1)
        XCTAssertEqual(camera.commands, [.start(1)])
    }

    func testOrderedStopBeforeRestartAndStaleCompletionIgnored() {
        let camera = CameraDouble(autoComplete: false)
        let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)
        store.routeAppeared(isSceneActive: true)
        store.viewportChanged(width: 390, height: 700)
        store.viewportChanged(width: 430, height: 700)

        XCTAssertEqual(camera.commands, [.start(1), .stop(1), .start(2)])
        camera.emit(.started(sessionID: 1, selection: .fixture))
        XCTAssertEqual(store.viewState.cameraStatus, .starting(sessionID: 2))
        camera.emit(.failed(sessionID: 1, failure: .cameraUnavailable))
        XCTAssertNil(store.viewState.failure)
    }

    func testInterruptionRestartsOnlyWhenEligible() {
        let camera = CameraDouble(autoComplete: false)
        let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)
        store.routeAppeared(isSceneActive: true)
        store.viewportChanged(width: 390, height: 700)
        camera.emit(.interrupted(sessionID: 1))
        store.sceneActivityChanged(isActive: false)
        camera.emit(.interruptionEnded)
        XCTAssertEqual(camera.commands, [.start(1), .stop(1)])

        store.sceneActivityChanged(isActive: true)
        XCTAssertEqual(camera.commands, [.start(1), .stop(1), .start(2)])
    }

    func testFiftyLifecycleCyclesNeverExposeMoreThanOneGeneration() {
        let camera = CameraDouble()
        let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)
        store.routeAppeared(isSceneActive: true)
        store.viewportChanged(width: 390, height: 700)

        for _ in 0..<50 {
            store.sceneActivityChanged(isActive: false)
            store.sceneActivityChanged(isActive: true)
        }

        XCTAssertLessThanOrEqual(camera.maximumActiveCount, 1)
        XCTAssertEqual(camera.commands.filter(\.isStart).count, 51)
        XCTAssertEqual(camera.commands.filter(\.isStop).count, 50)
    }

    func testRouteDisappearStopsAndStoreReleases() {
        let camera = CameraDouble()
        weak var weakStore: CaptureStore?
        do {
            let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)
            weakStore = store
            store.routeAppeared(isSceneActive: true)
            store.viewportChanged(width: 390, height: 700)
            store.routeDisappeared()
        }
        XCTAssertNil(weakStore)
        XCTAssertEqual(camera.commands.prefix(2), [.start(1), .stop(1)])
        XCTAssertEqual(camera.tearDownCount, 1)
    }

    func testU06RepeatedFailureRetryExitStopsOneOwnerAndReleasesStore() async {
        let camera = CameraDouble()
        weak var weakStore: CaptureStore?
        do {
            let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)
            weakStore = store
            store.routeAppeared(isSceneActive: true)
            store.viewportChanged(width: 390, height: 700)

            for sessionID in UInt64(1)...10 {
                camera.emit(.failed(sessionID: sessionID, failure: .cameraUnavailable))
                await Task.yield()
                store.retry()
            }
            store.exit()
            store.routeDisappeared()
        }

        XCTAssertNil(weakStore)
        XCTAssertLessThanOrEqual(camera.maximumActiveCount, 1)
        XCTAssertEqual(camera.commands.filter(\.isStart).count, 11)
        XCTAssertEqual(camera.commands.filter(\.isStop).count, 11)
        XCTAssertEqual(camera.tearDownCount, 1)
    }

    func testMailboxConsumptionAt300KeepsFaceAnd301WithdrawsPayload() {
        for (capturedAt, expectsFace) in [(700, true), (699, false)] {
            let camera = CameraDouble()
            let store = makeStore(authorization: AuthorizationDouble(.authorized), camera: camera)
            store.routeAppeared(isSceneActive: true)
            store.viewportChanged(width: 390, height: 700)
            camera.emitObservation(FrameObservation(
                sessionID: 1,
                geometryRevision: 1,
                capturedAtMS: Int64(capturedAt),
                resultAtMS: 1_000,
                face: FaceSample(
                    geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 0.3, height: 0.3),
                    pose: nil
                ),
                lighting: nil
            ))
            XCTAssertEqual(store.viewState.rawFace != nil, expectsFace)
        }
    }

    private func makeStore(
        authorization: AuthorizationDouble,
        camera: CameraDouble,
        settings: SettingsDouble = SettingsDouble(),
        dismiss: @escaping () -> Void = {}
    ) -> CaptureStore {
        CaptureStore(
            dependencies: CaptureDependencies(
                authorization: authorization,
                camera: camera,
                clock: FixedClock(),
                scheduler: InertScheduler(),
                settingsOpener: settings
            ),
            dismiss: dismiss
        )
    }
}

private struct FixedClock: MonotonicClock {
    func nowMilliseconds() -> Int64 { 1_000 }
}

private final class InertCancellation: ScheduledCancellation, @unchecked Sendable {
    func cancel() {}
}

private struct InertScheduler: MonotonicScheduling {
    func schedule(afterMilliseconds: Int64, action: @escaping @Sendable () -> Void) -> ScheduledCancellation {
        InertCancellation()
    }
}

private final class AuthorizationDouble: CameraAuthorizing, @unchecked Sendable {
    var status: CameraAuthorization
    var requestCount = 0
    private var completion: (@Sendable (CameraAuthorization) -> Void)?

    init(_ status: CameraAuthorization) { self.status = status }
    func currentAuthorization() -> CameraAuthorization { status }
    func requestAuthorization(_ completion: @escaping @Sendable (CameraAuthorization) -> Void) {
        requestCount += 1
        self.completion = completion
    }
    func complete(_ result: CameraAuthorization) {
        status = result
        let callback = completion
        completion = nil
        callback?(result)
    }
}

@MainActor
private final class SettingsDouble: SettingsOpening {
    var openCount = 0
    func openSettings() { openCount += 1 }
}

private enum CameraCommand: Equatable {
    case start(UInt64)
    case stop(UInt64)
    var isStart: Bool { if case .start = self { true } else { false } }
    var isStop: Bool { if case .stop = self { true } else { false } }
}

private final class CameraDouble: CameraSessionControlling, @unchecked Sendable {
    let previewSession = CameraPreviewSession(session: AVCaptureSession())
    let autoComplete: Bool
    var commands: [CameraCommand] = []
    var maximumActiveCount = 0
    var tearDownCount = 0
    private var activeIDs: Set<UInt64> = []
    private var eventHandler: (@Sendable (CameraServiceEvent) -> Void)?
    private var observationHandler: (@Sendable (FrameObservation) -> Void)?

    init(autoComplete: Bool = true) { self.autoComplete = autoComplete }

    func start(
        context: FrameAnalysisContext,
        eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void,
        observationHandler: @escaping @Sendable (FrameObservation) -> Void
    ) {
        self.eventHandler = eventHandler
        self.observationHandler = observationHandler
        let sessionID = context.sessionID
        commands.append(.start(sessionID))
        activeIDs.insert(sessionID)
        maximumActiveCount = max(maximumActiveCount, activeIDs.count)
        if autoComplete { eventHandler(.started(sessionID: sessionID, selection: .fixture)) }
    }

    func stop(sessionID: UInt64, eventHandler: @escaping @Sendable (CameraServiceEvent) -> Void) {
        self.eventHandler = eventHandler
        commands.append(.stop(sessionID))
        activeIDs.remove(sessionID)
        if autoComplete { eventHandler(.stopped(sessionID: sessionID)) }
    }

    func tearDown() {
        tearDownCount += 1
        activeIDs.removeAll()
        eventHandler = nil
        observationHandler = nil
    }

    func emit(_ event: CameraServiceEvent) { eventHandler?(event) }
    func emitObservation(_ observation: FrameObservation) { observationHandler?(observation) }
}

private extension CameraSelection {
    static let fixture = CameraSelection(
        widthPixels: 640,
        heightPixels: 480,
        requestedFramesPerSecond: 30,
        configuredFramesPerSecond: 30,
        previewMirrored: true,
        outputMirrored: false,
        rotationDegrees: 90
    )
}
