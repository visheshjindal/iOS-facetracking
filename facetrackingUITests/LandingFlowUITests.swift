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
}
