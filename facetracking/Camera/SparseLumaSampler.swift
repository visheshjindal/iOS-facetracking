@preconcurrency import CoreVideo
import Foundation

enum LumaRange: Sendable, Equatable {
    case full
    case video
}

struct LumaSamplingDiagnostics: Sendable, Equatable {
    let pixelFormat: OSType
    let range: LumaRange?
    let planeWidth: Int
    let planeHeight: Int
    let bytesPerRow: Int
    let sampledGridCount: Int
}

final class SparseLumaSampler {
    private(set) var samples: [CanonicalLumaSample] = []
    private let workspace = LightingHistogramWorkspace()

    init() {
        samples.reserveCapacity(TrackingConfiguration.provisional.sampling.maximumSampleCount)
    }

    func measure(
        pixelBuffer: CVPixelBuffer,
        transform: FrameTransformSnapshot?,
        face: FaceSample?,
        isPoseEligible: Bool,
        configuration: TrackingConfiguration = .provisional
    ) -> (metrics: FaceLightingMetrics?, diagnostics: LumaSamplingDiagnostics) {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let range = Self.range(for: pixelFormat)
        guard let range,
              CVPixelBufferIsPlanar(pixelBuffer),
              CVPixelBufferGetPlaneCount(pixelBuffer) >= 2
        else {
            return (nil, LumaSamplingDiagnostics(
                pixelFormat: pixelFormat, range: nil, planeWidth: 0, planeHeight: 0,
                bytesPerRow: 0, sampledGridCount: 0
            ))
        }

        let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard lockStatus == kCVReturnSuccess else {
            return (nil, LumaSamplingDiagnostics(
                pixelFormat: pixelFormat, range: range, planeWidth: 0, planeHeight: 0,
                bytesPerRow: 0, sampledGridCount: 0
            ))
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        guard width > 0, height > 0, bytesPerRow >= width,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        else {
            return (nil, LumaSamplingDiagnostics(
                pixelFormat: pixelFormat, range: range, planeWidth: width, planeHeight: height,
                bytesPerRow: bytesPerRow, sampledGridCount: 0
            ))
        }

        let byteCount = bytesPerRow.multipliedReportingOverflow(by: height)
        guard !byteCount.overflow else {
            return (nil, LumaSamplingDiagnostics(
                pixelFormat: pixelFormat, range: range, planeWidth: width, planeHeight: height,
                bytesPerRow: bytesPerRow, sampledGridCount: 0
            ))
        }
        let bytes = UnsafeRawBufferPointer(start: base, count: byteCount.partialValue)
        let sampled = sampleBytes(
            bytes,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            range: range,
            transform: transform,
            configuration: configuration
        )
        let diagnostics = LumaSamplingDiagnostics(
            pixelFormat: pixelFormat,
            range: range,
            planeWidth: width,
            planeHeight: height,
            bytesPerRow: bytesPerRow,
            sampledGridCount: sampled
        )
        return (
            LightingMeasurement.measure(
                samples: samples,
                face: face,
                isPoseEligible: isPoseEligible,
                workspace: workspace,
                configuration: configuration
            ),
            diagnostics
        )
    }

    @discardableResult
    func sampleBytes(
        _ bytes: UnsafeRawBufferPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        range: LumaRange,
        transform: FrameTransformSnapshot?,
        configuration: TrackingConfiguration = .provisional
    ) -> Int {
        samples.removeAll(keepingCapacity: true)
        guard width > 0, height > 0, bytesPerRow >= width,
              bytesPerRow.multipliedReportingOverflow(by: height).overflow == false,
              bytes.count >= bytesPerRow * height,
              let transform, transform.isValid
        else { return 0 }

        let columns = configuration.sampling.gridColumns
        let rows = configuration.sampling.gridRows
        guard columns > 0, rows > 0, columns * rows <= configuration.sampling.maximumSampleCount else { return 0 }
        for row in 0..<rows {
            let continuousY = (Double(row) + 0.5) * Double(height) / Double(rows)
            let pixelY = min(height - 1, max(0, Int(floor(continuousY))))
            for column in 0..<columns {
                let continuousX = (Double(column) + 0.5) * Double(width) / Double(columns)
                let pixelX = min(width - 1, max(0, Int(floor(continuousX))))
                guard let point = FrameCoordinateMapper.mapRawSamplePoint(
                    RawBufferPoint(xPixels: continuousX, yPixels: continuousY),
                    using: transform
                ) else { continue }
                let byte = bytes[pixelY * bytesPerRow + pixelX]
                samples.append(CanonicalLumaSample(
                    value: Self.canonical(byte, range: range),
                    viewportPoint: point
                ))
            }
        }
        return samples.count
    }

    static func range(for pixelFormat: OSType) -> LumaRange? {
        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: .full
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: .video
        default: nil
        }
    }

    static func canonical(_ byte: UInt8, range: LumaRange) -> UInt8 {
        switch range {
        case .full:
            byte
        case .video:
            UInt8(clamping: Int((Double(Int(byte) - 16) * 255 / 219).rounded()).clamped(to: 0...255))
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
