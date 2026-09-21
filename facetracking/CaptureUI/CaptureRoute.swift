import SwiftUI

@MainActor
struct CaptureRoute: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: CaptureStore

    init(dependencies: CaptureDependencies, onDismiss: @escaping () -> Void) {
        _store = State(initialValue: CaptureStore(dependencies: dependencies, dismiss: onDismiss))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.viewState.showsPreview {
                CameraPreview(previewSession: store.previewSession)
                    .ignoresSafeArea()
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { reportViewport(proxy.size) }
                                .onChange(of: proxy.size) { _, size in reportViewport(size) }
                        }
                    }
            }

            content
                .padding(32)
        }
        .onAppear { store.routeAppeared(isSceneActive: scenePhase == .active) }
        .onDisappear { store.routeDisappeared() }
        .onChange(of: scenePhase) { _, phase in
            store.sceneActivityChanged(isActive: phase == .active)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            Spacer()
            switch store.viewState.authorization {
            case .notDetermined:
                permissionMessage(bodyKey: "permission.body")
                Button("permission.grant") { store.grantCameraAccess() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("capture.grant")
            case .denied:
                permissionMessage(bodyKey: "permission.body")
                Button("permission.settings") { store.openSettings() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("capture.settings")
            case .restricted:
                permissionMessage(bodyKey: "permission.restricted")
            case .authorized:
                if store.viewState.isInterrupted {
                    message("camera.interrupted")
                } else if let failure = store.viewState.failure {
                    message(failure == .detectorUnavailable ? "error.detector" : "error.camera")
                    if failure.isRetryable {
                        Button("action.retry") { store.retry() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("capture.retry")
                    }
                }
            }
            Button("action.exit") { store.exit() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("capture.exit")
        }
        .foregroundStyle(.white)
    }

    private func permissionMessage(bodyKey: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Text("permission.title").font(.title2.bold())
            Text(bodyKey).multilineTextAlignment(.center)
        }
    }

    private func message(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding()
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }

    private func reportViewport(_ size: CGSize) {
        store.viewportChanged(width: size.width, height: size.height)
    }
}
