import SwiftUI

struct CapturePlaceholderView: View {
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("capture.placeholder")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("capture.placeholder.body")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("action.exit", action: onExit)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("capture.exit")
        }
        .padding(32)
    }
}

#Preview {
    CapturePlaceholderView(onExit: {})
}
