import SwiftUI

@main
struct facetrackingApp: App {
    private let dependencies: CaptureDependencies?
#if DEBUG
    private let fixture: CaptureFixture?
    private let scenario: CaptureTestScenario?
#endif

    init() {
#if DEBUG
        let fixture = Self.fixtureFromArguments
        let scenario = Self.scenarioFromArguments
        self.fixture = fixture
        self.scenario = scenario
        dependencies = fixture == nil && scenario == nil ? CaptureDependencies.live() : nil
#else
        dependencies = CaptureDependencies.live()
#endif
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let scenario {
                CaptureScenarioHost(scenario: scenario)
            } else if let fixture {
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

    private static var scenarioFromArguments: CaptureTestScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let marker = arguments.firstIndex(of: "-capture-scenario"),
              arguments.indices.contains(marker + 1)
        else { return nil }
        return CaptureTestScenario(rawValue: arguments[marker + 1])
    }
#endif
}
