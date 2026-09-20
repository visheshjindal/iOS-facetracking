import XCTest
@testable import facetracking

final class TrackingConfigurationTests: XCTestCase {
    func testProvisionalProfileIdentityAndCoreTiming() {
        let configuration = TrackingConfiguration.provisional

        XCTAssertEqual(configuration.version, "ios-provisional-v1")
        XCTAssertEqual(configuration.timing.acquisitionHoldMS, 2_000)
        XCTAssertEqual(configuration.timing.maximumContinuousSampleGapMS, 300)
        XCTAssertEqual(configuration.timing.faceFreshnessMS, 300)
        XCTAssertEqual(configuration.timing.analysisStallMS, 5_000)
        XCTAssertEqual(configuration.timing.watchdogCadenceMS, 250)
    }
}
