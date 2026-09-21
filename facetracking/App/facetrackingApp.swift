import SwiftUI

@main
struct facetrackingApp: App {
    private let dependencies = CaptureDependencies.live()

    var body: some Scene {
        WindowGroup {
            LandingView(dependencies: dependencies)
        }
    }
}
