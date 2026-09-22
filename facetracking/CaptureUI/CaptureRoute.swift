import SwiftUI

@MainActor
struct CaptureRoute: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: CaptureStore
    @State private var announcements: PromptAnnouncementCoordinator

    init(dependencies: CaptureDependencies, onDismiss: @escaping () -> Void) {
        _store = State(initialValue: CaptureStore(dependencies: dependencies, dismiss: onDismiss))
        _announcements = State(initialValue: PromptAnnouncementCoordinator(
            clock: dependencies.clock,
            scheduler: dependencies.scheduler
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.viewState.showsPreview {
                CameraPreview(
                    previewSession: store.previewSession,
                    onViewportChanged: reportViewport
                )
            }

            CaptureScreen(
                viewState: store.viewState,
                onGrant: store.grantCameraAccess,
                onSettings: store.openSettings,
                onRetry: store.retry,
                onRestart: store.restartAfterLoss,
                onExit: store.exit,
                announcements: announcements
            )
        }
        .onAppear { store.routeAppeared(isSceneActive: scenePhase == .active) }
        .onDisappear { store.routeDisappeared() }
        .onChange(of: scenePhase) { _, phase in
            store.sceneActivityChanged(isActive: phase == .active)
        }
    }

    private func reportViewport(_ size: CGSize) {
        store.viewportChanged(width: size.width, height: size.height)
    }
}
