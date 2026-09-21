import SwiftUI

struct LandingView: View {
    let dependencies: CaptureDependencies
    @State private var isPresentingCapture = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "face.smiling")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("landing.title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Button("action.start") {
                isPresentingCapture = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("landing.startCapture")
        }
        .padding(32)
        .fullScreenCover(isPresented: $isPresentingCapture) {
            CaptureRoute(dependencies: dependencies) {
                isPresentingCapture = false
            }
        }
    }
}

#Preview {
    LandingView(dependencies: .live())
}
