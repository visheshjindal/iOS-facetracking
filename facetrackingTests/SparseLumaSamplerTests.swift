import CoreVideo
import XCTest
@testable import facetracking

final class SparseLumaSamplerTests: XCTestCase {
    func testL01PaddedRowsNeverSampleSentinelAndGridIsAtMost4096() {
        let width = 64, height = 64, stride = 68
        var bytes = Array(repeating: UInt8(250), count: stride * height)
        for row in 0..<height {
            for column in 0..<width { bytes[row * stride + column] = 100 }
        }
        let sampler = SparseLumaSampler()
        let count = bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: width, height: height, bytesPerRow: stride, range: .full, transform: snapshot(width: width, height: height))
        }
        XCTAssertEqual(count, 4_096)
        XCTAssertEqual(sampler.samples.count, 4_096)
        XCTAssertTrue(sampler.samples.allSatisfy { $0.value == 100 })
    }

    func testL01TinyDimensionsClampSafelyAndInvalidLayoutsReturnUnavailable() {
        let sampler = SparseLumaSampler()
        let bytes: [UInt8] = [77, 250]
        let count = bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: 1, height: 1, bytesPerRow: 2, range: .full, transform: snapshot(width: 1, height: 1))
        }
        XCTAssertEqual(count, 4_096)
        XCTAssertTrue(sampler.samples.allSatisfy { $0.value == 77 })

        XCTAssertEqual(bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: 2, height: 1, bytesPerRow: 1, range: .full, transform: snapshot(width: 2, height: 1))
        }, 0)
        XCTAssertEqual(bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: 1, height: 1, bytesPerRow: 2, range: .full, transform: nil)
        }, 0)
    }

    func testL02FullAndVideoRangeCanonicalExamples() {
        XCTAssertEqual(SparseLumaSampler.canonical(0, range: .full), 0)
        XCTAssertEqual(SparseLumaSampler.canonical(255, range: .full), 255)
        XCTAssertEqual(SparseLumaSampler.canonical(0, range: .video), 0)
        XCTAssertEqual(SparseLumaSampler.canonical(16, range: .video), 0)
        XCTAssertEqual(SparseLumaSampler.canonical(126, range: .video), 128)
        XCTAssertEqual(SparseLumaSampler.canonical(235, range: .video), 255)
        XCTAssertEqual(SparseLumaSampler.canonical(255, range: .video), 255)
    }

    func testL01OnlyExplicitBiPlanarFormatsAreSupported() {
        XCTAssertEqual(SparseLumaSampler.range(for: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), .full)
        XCTAssertEqual(SparseLumaSampler.range(for: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), .video)
        XCTAssertNil(SparseLumaSampler.range(for: kCVPixelFormatType_32BGRA))
    }

    func testG02MappedAsymmetricRawSamplesUseSingleSharedSnapshot() {
        let width = 64, height = 64
        var bytes = Array(repeating: UInt8(0), count: width * height)
        for row in 0..<height {
            for column in 0..<width { bytes[row * width + column] = column < 32 ? 40 : 200 }
        }
        let sampler = SparseLumaSampler()
        _ = bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: width, height: height, bytesPerRow: width, range: .full, transform: snapshot(width: width, height: height, mirrored: true))
        }
        let face = FaceSample(
            geometry: FaceGeometry(centerX: 0.5, centerY: 0.5, width: 1, height: 1),
            pose: FacePose(yawDegrees: 0, pitchDegrees: 0, rollDegrees: 0)
        )
        let metrics = LightingMeasurement.measure(
            samples: sampler.samples,
            face: face,
            isPoseEligible: true,
            workspace: LightingHistogramWorkspace()
        )
        // One preview mirror means raw-buffer right becomes screen-left.
        XCTAssertEqual(metrics?.leftTrimmedMean, 200)
        XCTAssertEqual(metrics?.rightTrimmedMean, 40)
    }

    func testL03MissingTransformAfterValidFrameClearsReusableSamples() {
        let sampler = SparseLumaSampler()
        let bytes = Array(repeating: UInt8(100), count: 64 * 64)
        XCTAssertEqual(bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: 64, height: 64, bytesPerRow: 64, range: .full, transform: snapshot(width: 64, height: 64))
        }, 4_096)
        XCTAssertEqual(bytes.withUnsafeBytes {
            sampler.sampleBytes($0, width: 64, height: 64, bytesPerRow: 64, range: .full, transform: nil)
        }, 0)
        XCTAssertTrue(sampler.samples.isEmpty)
    }

    private func snapshot(width: Int, height: Int, mirrored: Bool = false) -> FrameTransformSnapshot {
        FrameTransformSnapshot(
            geometryRevision: 1,
            rawBufferPixels: CoordinateSize(width: Double(width), height: Double(height)),
            orientedImagePixels: CoordinateSize(width: Double(width), height: Double(height)),
            rawToOrientedRotation: .degrees0,
            visionOrientationPolicy: .bufferAlreadyOriented,
            cleanAperturePolicy: .fullBuffer,
            viewportPoints: CoordinateSize(width: Double(width), height: Double(height)),
            interfaceOrientation: .portrait,
            isPreviewMirrored: mirrored
        )
    }
}
