import XCTest
@testable import facetracking

final class TrackingConfigurationTests: XCTestCase {
    func testProvisionalProfileIdentityAndCoreTiming() {
        let configuration = TrackingConfiguration.provisional

        XCTAssertEqual(configuration.version, "ios-provisional-v2")
        XCTAssertEqual(configuration.positioning.centerToleranceTargetFraction, 0.15)
        XCTAssertEqual(configuration.positioning.followingCenterToleranceTargetFraction, 0.25)
        XCTAssertEqual(configuration.positioning.minimumFaceScaleTargetFraction, 0.50)
        XCTAssertEqual(configuration.timing.acquisitionHoldMS, 2_000)
        XCTAssertEqual(configuration.timing.maximumContinuousSampleGapMS, 300)
        XCTAssertEqual(configuration.timing.faceFreshnessMS, 300)
        XCTAssertEqual(configuration.timing.analysisStallMS, 5_000)
        XCTAssertEqual(configuration.timing.watchdogCadenceMS, 250)
    }
}
