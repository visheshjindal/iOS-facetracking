@preconcurrency import CoreVideo
import Foundation
import ImageIO
@preconcurrency import Vision

struct DetectedFaceCandidate: Sendable, Equatable {
    let bounds: VisionNormalizedRect
    let yawRadians: Double?
    let pitchRadians: Double?
    let rollRadians: Double?
}

protocol FaceDetecting: AnyObject {
    var requestRevision: Int { get }
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [DetectedFaceCandidate]
}

/// Used only from FrameAnalyzer's serial analysis path. The request is reused
/// serially; no Vision observation or pixel buffer crosses that boundary.
final class VisionFaceDetector: FaceDetecting {
    static let pinnedRevision = VNDetectFaceRectanglesRequestRevision3
    private let request: VNDetectFaceRectanglesRequest

    var requestRevision: Int { Int(request.revision) }

    init() {
        request = VNDetectFaceRectanglesRequest()
        request.revision = Self.pinnedRevision
    }

    func detect(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> [DetectedFaceCandidate] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        try handler.perform([request])
        return (request.results ?? []).map { observation in
            DetectedFaceCandidate(
                bounds: VisionNormalizedRect(
                    x: observation.boundingBox.origin.x,
                    y: observation.boundingBox.origin.y,
                    width: observation.boundingBox.width,
                    height: observation.boundingBox.height
                ),
                yawRadians: observation.yaw?.doubleValue,
                pitchRadians: observation.pitch?.doubleValue,
                rollRadians: observation.roll?.doubleValue
            )
        }
    }
}
