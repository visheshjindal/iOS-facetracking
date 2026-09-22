import AVFoundation
import XCTest
@testable import facetracking

final class CameraFailureDetailsTests: XCTestCase {
    func testRuntimeNotificationRecognizesOnlyAVFoundationResetCode() {
        let reset = NSError(domain: AVFoundationErrorDomain, code: AVError.Code.mediaServicesWereReset.rawValue)
        let details = CameraFailureDetails(notification: Notification(name: .AVCaptureSessionRuntimeError,
            userInfo: [AVCaptureSessionErrorKey: reset]))
        XCTAssertTrue(details.isMediaServicesReset)
        XCTAssertEqual(details.domain, .avFoundation)
        let wrongDomain = CameraFailureDetails(error: NSError(domain: "private-payload", code: reset.code,
            userInfo: [NSLocalizedDescriptionKey: "must not be retained"]))
        XCTAssertEqual(wrongDomain.domain, .other)
        XCTAssertFalse(wrongDomain.isMediaServicesReset)
        XCTAssertFalse(CameraFailureDetails(error: NSError(domain: AVFoundationErrorDomain,
            code: AVError.Code.unknown.rawValue)).isMediaServicesReset)
    }

    func testMissingAndMalformedErrorPayloadsAreSafeGenericFailures() {
        for info: [AnyHashable: Any] in [[:], [AVCaptureSessionErrorKey: "not an error"]] {
            let details = CameraFailureDetails(notification: Notification(name: .AVCaptureSessionRuntimeError, userInfo: info))
            XCTAssertEqual(details.domain, .missing)
            XCTAssertNil(details.code)
            XCTAssertFalse(details.isMediaServicesReset)
        }
    }
}
