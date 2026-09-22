@preconcurrency import AVFoundation

/// Both preview and analysis are fixed to the portrait interface, not gravity.
/// Call on the owning connection's queue, before starting the data output.
enum CameraPortraitOrientation {
    static func configure(_ connection: AVCaptureConnection, device: AVCaptureDevice) -> Bool {
        if #available(iOS 27.0, *) {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
            let angle = coordinator.videoRotationAngleRelative(toDeviceOrientation: .portrait)
            guard connection.isVideoRotationAngleSupported(angle) else { return false }
            connection.videoRotationAngle = angle
        } else {
            // iOS 17–26 has no static, device-relative angle query. The semantic
            // orientation API accounts for sensor mounting without guessing 90°
            // or using a gravity angle that changes independently of the viewport.
            guard connection.isVideoOrientationSupported else { return false }
            connection.videoOrientation = .portrait
        }
        return true
    }
}
