import SwiftUI

@main
struct facetrackingApp: App {
    private let dependencies: CaptureDependencies?
#if DEBUG
    private let fixture: CaptureFixture?
#endif

    init() {
#if DEBUG
        let fixture = Self.fixtureFromArguments
        self.fixture = fixture
        dependencies = fixture == nil ? CaptureDependencies.live() : nil
#else
        dependencies = CaptureDependencies.live()
#endif
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let fixture {
                CaptureFixtureHost(fixture: fixture)
            } else {
                LandingView(dependencies: dependencies!)
            }
#else
            LandingView(dependencies: dependencies!)
#endif
        }
    }

#if DEBUG
    private static var fixtureFromArguments: CaptureFixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let marker = arguments.firstIndex(of: "-capture-fixture"),
              arguments.indices.contains(marker + 1)
        else { return nil }
        return CaptureFixture(rawValue: arguments[marker + 1])
    }
#endif
}
