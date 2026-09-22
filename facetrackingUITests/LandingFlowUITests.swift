import XCTest

final class LandingFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchEnterAndExitReturnsToLanding() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.buttons["landing.startCapture"].waitForExistence(timeout: 5))

        app.buttons["landing.startCapture"].tap()
        XCTAssertTrue(app.buttons["capture.exit"].waitForExistence(timeout: 5))

        app.buttons["capture.exit"].tap()
        XCTAssertTrue(app.buttons["landing.startCapture"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLossFixtureOffersRestartAndRestoresAlignment() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-capture-fixture", "loss"]
        app.launch()

        let restart = app.buttons["capture.restart"]
        XCTAssertTrue(restart.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["capture.guidance"].exists)
        restart.tap()
        XCTAssertFalse(restart.exists)
        XCTAssertTrue(app.staticTexts["capture.guidance"].exists)
    }

    @MainActor
    func testLightingFixtureShowsBadgeWithoutCameraPermission() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-capture-fixture", "lighting-left"]
        app.launch()

        XCTAssertTrue(app.otherElements["capture.lightingBadge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["capture.exit"].exists)
    }
}
