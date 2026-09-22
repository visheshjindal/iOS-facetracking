import SwiftUI

struct CaptureScreen: View {
    let viewState: CaptureViewState
    let onGrant: () -> Void
    let onSettings: () -> Void
    let onRetry: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void
    let announcements: PromptAnnouncementCoordinator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                authorizedOverlays
                modalContent
                exitButton
            }
        }
        .onAppear { announcePrompt() }
        .onChange(of: viewState.accessibilityPromptKey) { _, _ in announcePrompt() }
    }

    @ViewBuilder
    private var authorizedOverlays: some View {
        if viewState.authorization == .authorized,
           viewState.failure == nil,
           !viewState.isInterrupted,
           let target = viewState.target {
            PositioningMask(target: target)
                .opacity(viewState.guidance.showsInitialMask ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: Double(CaptureDisplayConfiguration.maskFadeDurationMS) / 1_000),
                    value: viewState.guidance.showsInitialMask
                )

            if viewState.guidance.showsReturnGuide {
                FaceReturnGuide(target: target)
            }
            if let face = viewState.guidance.trackedOval {
                TrackedFaceOverlay(face: face)
            }

            VStack(spacing: 0) {
                GuidanceText(
                    guidance: viewState.guidance.primary,
                    isFollowing: viewState.guidance.showsReturnGuide
                )
                if let badge = viewState.guidance.badge {
                    HStack {
                        Spacer(minLength: 0)
                        LightingBadge(badge: badge)
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                Spacer(minLength: 0)
                if viewState.isTrackingLost {
                    actionButton("action.restart", identifier: CaptureActionIdentifier.restart, action: onRestart)
                        .padding(.bottom, 72)
                }
            }
        }
    }

    @ViewBuilder
    private var modalContent: some View {
        switch viewState.authorization {
        case .notDetermined:
            centeredPanel {
                permissionMessage(bodyKey: "permission.body")
                actionButton("permission.grant", identifier: CaptureActionIdentifier.grant, action: onGrant)
            }
        case .denied:
            centeredPanel {
                permissionMessage(bodyKey: "permission.body")
                actionButton("permission.settings", identifier: CaptureActionIdentifier.settings, action: onSettings)
            }
        case .restricted:
            centeredPanel { permissionMessage(bodyKey: "permission.restricted") }
        case .authorized:
            if viewState.isInterrupted {
                centeredPanel { message("camera.interrupted") }
            } else if let failure = viewState.failure {
                centeredPanel {
                    message(GuidanceTextKey.failureKey(failure))
                    if failure.isRetryable {
                        actionButton("action.retry", identifier: CaptureActionIdentifier.retry, action: onRetry)
                    }
                }
            }
        }
    }

    private var exitButton: some View {
        VStack {
            Spacer()
            HStack {
                actionButton("action.exit", identifier: CaptureActionIdentifier.exit, action: onExit)
                Spacer()
            }
            .padding(16)
        }
    }

    private func permissionMessage(bodyKey: String) -> some View {
        VStack(spacing: 12) {
            Text("permission.title")
                .font(.title2.bold())
                .accessibilityIdentifier("capture.permissionTitle")
            Text(LocalizedStringKey(bodyKey))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("capture.permissionMessage")
        }
    }

    private func message(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.headline)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("capture.statusMessage")
    }

    private func centeredPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 20) {
            content()
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 16))
        .padding(32)
    }

    private func actionButton(_ key: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(key))
                .frame(minWidth: CaptureDisplayConfiguration.minimumActionTargetPoints,
                       minHeight: CaptureDisplayConfiguration.minimumActionTargetPoints)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(identifier)
    }

    private func announcePrompt() {
        let key = viewState.accessibilityPromptKey
        announcements?.promptChanged(
            key: key,
            message: String(localized: String.LocalizationValue(key))
        )
    }
}
