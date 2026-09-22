@preconcurrency import AVFoundation
import SwiftUI

@MainActor
struct CameraPreview: UIViewRepresentable {
    let previewSession: CameraPreviewSession
    let onViewportChanged: (CGSize) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.onViewportChanged = onViewportChanged
        view.attach(session: previewSession.session)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.onViewportChanged = onViewportChanged
        if view.previewLayer.session !== previewSession.session {
            view.attach(session: previewSession.session)
        }
        view.configureConnection()
    }
}

@MainActor
final class PreviewView: UIView {
    var onViewportChanged: ((CGSize) -> Void)?

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
        onViewportChanged?(bounds.size)
    }

    func attach(session: AVCaptureSession) {
        previewLayer.session = session
        configureConnection()
    }

    func configureConnection() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        if let input = previewLayer.session?.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first {
            _ = CameraPortraitOrientation.configure(connection, device: input.device)
        }
    }
}
