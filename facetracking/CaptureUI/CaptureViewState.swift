import Foundation

struct CaptureViewState: Equatable {
    let authorization: CameraAuthorization
    let failure: SessionFailure?
    let isInterrupted: Bool
    let cameraStatus: CameraStatus
    let selection: CameraSelection?
    let rawFace: FaceSample?

    var showsPreview: Bool {
        authorization == .authorized && failure == nil
    }

    init(session: SessionState, selection: CameraSelection?) {
        authorization = session.authorization
        failure = session.failure
        isInterrupted = session.isInterrupted
        cameraStatus = session.cameraStatus
        self.selection = selection
        rawFace = session.rawFace
    }
}
