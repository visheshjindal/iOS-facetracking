@preconcurrency import AVFoundation
import SwiftUI

@MainActor
struct CameraPreview: UIViewRepresentable {
    let previewSession: CameraPreviewSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.attach(session: previewSession.session)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== previewSession.session {
            view.attach(session: previewSession.session)
        }
        view.configureConnection()
    }
}

@MainActor
final class PreviewView: UIView {
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureConnection()
    }

    func attach(session: AVCaptureSession) {
        rotationCoordinator = nil
        previewLayer.session = session
        configureConnection()
    }

    func configureConnection() {
        guard let connection = previewLayer.connection else { return }
        if rotationCoordinator == nil,
           let input = previewLayer.session?.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: input.device,
                previewLayer: previewLayer
            )
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
