@preconcurrency import AVFoundation
import Foundation

/// Scalar-only diagnostics. Never retain notification userInfo, error descriptions,
/// arbitrary error domains, or underlying errors across queues or in logs.
struct CameraFailureDetails: Sendable, Equatable {
    enum Domain: String, Sendable { case avFoundation, cocoa, posix, other, missing }
    let domain: Domain
    let code: Int?

    init(error: NSError?) {
        guard let error else {
            domain = .missing
            code = nil
            return
        }
        switch error.domain {
        case AVFoundationErrorDomain: domain = .avFoundation
        case NSCocoaErrorDomain: domain = .cocoa
        case NSPOSIXErrorDomain: domain = .posix
        default: domain = .other
        }
        code = error.code
    }

    init(notification: Notification) {
        self.init(error: notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)
    }

    var isMediaServicesReset: Bool {
        domain == .avFoundation && code == AVError.Code.mediaServicesWereReset.rawValue
    }
}
