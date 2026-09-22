import XCTest

final class CaptureAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testU01PermissionFailureInterruptionAndSettingsScenarios() {
        let notDetermined = launchScenario("permission-not-determined")
        XCTAssertTrue(notDetermined.buttons["capture.grant"].waitForExistence(timeout: 3))
        XCTAssertEqual(notDetermined.staticTexts["test.cameraStartCount"].label, "0")

        let denied = launchScenario("permission-denied")
        let settings = denied.buttons["capture.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.tap()
        XCTAssertEqual(denied.staticTexts["test.settingsOpenCount"].label, "1")

        let restricted = launchScenario("permission-restricted")
        XCTAssertTrue(restricted.staticTexts["capture.permissionMessage"].waitForExistence(timeout: 3))
        XCTAssertFalse(restricted.buttons["capture.grant"].exists)
        XCTAssertEqual(restricted.staticTexts["test.cameraStartCount"].label, "0")

        for scenario in ["camera-error", "detector-error"] {
            let app = launchScenario(scenario)
            XCTAssertTrue(app.staticTexts["capture.statusMessage"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["capture.retry"].exists)
            XCTAssertTrue(app.buttons["capture.exit"].exists)
        }

        let interrupted = launchScenario("interrupted")
        XCTAssertTrue(interrupted.staticTexts["capture.statusMessage"].waitForExistence(timeout: 3))
        XCTAssertFalse(interrupted.buttons["capture.retry"].exists)
    }

    @MainActor
    func testU02AcquisitionBoundaryAndReduceMotion() {
        let before = launchScenario("aligning-1999")
        XCTAssertEqual(before.staticTexts["test.showsMask"].label, "true")
        XCTAssertEqual(before.staticTexts["test.hasTrackedOval"].label, "false")

        let acquired = launchScenario("acquired-2000", extraArguments: ["-reduce-motion"])
        XCTAssertEqual(acquired.staticTexts["test.showsMask"].label, "false")
        XCTAssertEqual(acquired.staticTexts["test.hasTrackedOval"].label, "true")
        XCTAssertTrue(acquired.otherElements["capture.returnGuide"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testU03LossRecoveryAndRestart() {
        let lost = launchScenario("lost")
        XCTAssertEqual(lost.staticTexts["test.showsReturnGuide"].label, "true")
        XCTAssertEqual(lost.staticTexts["test.hasTrackedOval"].label, "false")
        XCTAssertTrue(lost.buttons["capture.restart"].exists)

        let recovered = launchScenario("recovered")
        XCTAssertEqual(recovered.staticTexts["test.hasTrackedOval"].label, "true")
        XCTAssertFalse(recovered.buttons["capture.restart"].exists)

        let restarted = launchScenario("restarted")
        XCTAssertEqual(restarted.staticTexts["test.showsMask"].label, "true")
        XCTAssertEqual(restarted.staticTexts["test.showsReturnGuide"].label, "false")
    }

    @MainActor
    func testU04LightingStatesExposeTextLabels() {
        let fixtures = [
            "lighting-unknown", "lighting-acceptable", "lighting-dark", "lighting-bright",
            "lighting-left", "lighting-right", "lighting-uneven", "lighting-high-contrast"
        ]
        for fixture in fixtures {
            let app = launchFixture(fixture)
            let badge = app.otherElements["capture.lightingBadge"]
            XCTAssertTrue(badge.waitForExistence(timeout: 3), fixture)
            XCTAssertFalse(badge.label.isEmpty, fixture)
            XCTAssertTrue(app.staticTexts["capture.guidance"].exists, fixture)
        }
    }

    @MainActor
    func testU05LargestAccessibilityTextKeepsPrimaryControlsReachable() throws {
        let app = launchFixture(
            "lighting-left",
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge", "-reduce-motion"]
        )
        XCTAssertTrue(app.staticTexts["capture.guidance"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["capture.lightingBadge"].exists)
        XCTAssertTrue(app.buttons["capture.exit"].isHittable)
        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit(for: [.dynamicType, .hitRegion, .sufficientElementDescription])
        }
    }

    @MainActor
    func testU06FakeLaunchAndRetryHaveBoundedOwnershipCommands() {
        for _ in 0..<3 {
            let app = launchScenario("acquired-2000")
            XCTAssertEqual(app.staticTexts["test.cameraStartCount"].label, "1")
            app.terminate()
        }

        let failed = launchScenario("camera-error")
        XCTAssertEqual(failed.staticTexts["test.cameraStartCount"].label, "1")
        failed.buttons["capture.retry"].tap()
        XCTAssertEqual(failed.staticTexts["test.cameraStartCount"].label, "2")
    }

    @MainActor
    private func launchScenario(_ identifier: String, extraArguments: [String] = []) -> XCUIApplication {
        launch(arguments: ["-capture-scenario", identifier] + extraArguments)
    }

    @MainActor
    private func launchFixture(_ identifier: String, extraArguments: [String] = []) -> XCUIApplication {
        launch(arguments: ["-capture-fixture", identifier] + extraArguments)
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["capture.exit"].waitForExistence(timeout: 3))
        return app
    }
}
