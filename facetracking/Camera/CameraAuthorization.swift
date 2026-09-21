@preconcurrency import AVFoundation

protocol CameraAuthorizing: AnyObject {
    func currentAuthorization() -> CameraAuthorization
    func requestAuthorization(_ completion: @escaping @Sendable (CameraAuthorization) -> Void)
}

final class SystemCameraAuthorization: CameraAuthorizing, @unchecked Sendable {
    func currentAuthorization() -> CameraAuthorization {
        Self.map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func requestAuthorization(_ completion: @escaping @Sendable (CameraAuthorization) -> Void) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else {
            completion(currentAuthorization())
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { _ in
            completion(Self.map(AVCaptureDevice.authorizationStatus(for: .video)))
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> CameraAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}
