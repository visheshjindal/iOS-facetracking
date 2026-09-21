import Foundation

/// Dimensions in pixels or points, as named by the containing property.
struct CoordinateSize: Sendable, Equatable {
    let width: Double
    let height: Double

    var isValid: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

/// A top-left-origin rectangle in raw buffer pixel edge coordinates.
struct RawPixelRect: Sendable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var isFiniteAndPositive: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite
            && width > 0 && height > 0
    }
}

/// A raw buffer point in top-left-origin pixel edge coordinates. Luma callers
/// pass cell centers such as (column + 0.5, row + 0.5).
struct RawBufferPoint: Sendable, Equatable {
    let xPixels: Double
    let yPixels: Double
}

/// A Vision lower-left-origin normalized rectangle, before preview crop/mirror.
struct VisionNormalizedRect: Sendable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

/// A top-left-origin point in the mirrored normalized preview viewport.
struct NormalizedViewportPoint: Sendable, Equatable {
    let x: Double
    let y: Double
}

enum FrameQuarterTurn: Int, Sendable, Equatable, CaseIterable {
    case degrees0 = 0
    case degrees90Clockwise = 90
    case degrees180 = 180
    case degrees270Clockwise = 270
}

enum FrameCleanAperturePolicy: Sendable, Equatable {
    case fullBuffer
    case crop(RawPixelRect)
}

/// Records how plan 05 must present this frame to Vision. Vision rectangles
/// supplied to this mapper are always already in oriented-image coordinates.
enum VisionOrientationPolicy: Sendable, Equatable {
    /// The data output physically delivered upright pixels; no Vision rotation.
    case bufferAlreadyOriented
    /// Vision must apply `rawToOrientedRotation` to the raw buffer exactly once.
    case visionAppliesSnapshotRotation
}

enum PortraitInterfaceOrientation: Sendable, Equatable {
    case portrait
    case portraitUpsideDown
}

/// Immutable geometry captured with a frame. Later layout changes must create a
/// new revision rather than remapping observations from this snapshot.
struct FrameTransformSnapshot: Sendable, Equatable {
    let geometryRevision: UInt64
    let rawBufferPixels: CoordinateSize
    let orientedImagePixels: CoordinateSize
    let rawToOrientedRotation: FrameQuarterTurn
    let visionOrientationPolicy: VisionOrientationPolicy
    let cleanAperturePolicy: FrameCleanAperturePolicy
    let viewportPoints: CoordinateSize
    let interfaceOrientation: PortraitInterfaceOrientation
    let isPreviewMirrored: Bool

    var cleanAperturePixels: RawPixelRect? {
        switch cleanAperturePolicy {
        case .fullBuffer:
            RawPixelRect(x: 0, y: 0, width: rawBufferPixels.width, height: rawBufferPixels.height)
        case let .crop(rect):
            rect
        }
    }

    var isValid: Bool {
        guard rawBufferPixels.isValid,
              orientedImagePixels.isValid,
              viewportPoints.isValid,
              let aperture = cleanAperturePixels,
              aperture.isFiniteAndPositive,
              aperture.x >= 0,
              aperture.y >= 0,
              aperture.x + aperture.width <= rawBufferPixels.width,
              aperture.y + aperture.height <= rawBufferPixels.height
        else { return false }

        let expectedOriented = rawToOrientedRotation.swapsDimensions
            ? CoordinateSize(width: aperture.height, height: aperture.width)
            : CoordinateSize(width: aperture.width, height: aperture.height)
        guard approximatelyEqual(orientedImagePixels.width, expectedOriented.width),
              approximatelyEqual(orientedImagePixels.height, expectedOriented.height)
        else { return false }

        if visionOrientationPolicy == .bufferAlreadyOriented,
           rawToOrientedRotation != .degrees0 {
            return false
        }
        return true
    }

    private func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.000_001
    }
}

private extension FrameQuarterTurn {
    var swapsDimensions: Bool {
        self == .degrees90Clockwise || self == .degrees270Clockwise
    }
}

enum FrameCoordinateMapper {
    /// Maps an already-oriented Vision rectangle into mirrored normalized
    /// viewport geometry. It never applies raw-buffer rotation.
    static func mapVisionBounds(
        _ bounds: VisionNormalizedRect,
        using snapshot: FrameTransformSnapshot?
    ) -> FaceGeometry? {
        guard let snapshot, snapshot.isValid,
              bounds.x.isFinite, bounds.y.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0
        else { return nil }

        let imageWidth = snapshot.orientedImagePixels.width
        let imageHeight = snapshot.orientedImagePixels.height
        let left = bounds.x * imageWidth
        let top = (1 - bounds.y - bounds.height) * imageHeight
        let right = left + bounds.width * imageWidth
        let bottom = top + bounds.height * imageHeight
        let corners = [
            ImagePoint(x: left, y: top),
            ImagePoint(x: right, y: top),
            ImagePoint(x: left, y: bottom),
            ImagePoint(x: right, y: bottom)
        ]
        let mapped = corners.compactMap { mapOrientedPoint($0, using: snapshot) }
        guard mapped.count == corners.count,
              let minX = mapped.map(\.x).min(), let maxX = mapped.map(\.x).max(),
              let minY = mapped.map(\.y).min(), let maxY = mapped.map(\.y).max()
        else { return nil }

        let geometry = FaceGeometry(
            centerX: (minX + maxX) / 2,
            centerY: (minY + maxY) / 2,
            width: maxX - minX,
            height: maxY - minY
        )
        return geometry.isUsableInViewport ? geometry : nil
    }

    /// Maps a raw luma cell center through clean aperture, rotation, aspect-fill
    /// crop, and preview mirror. This path must not receive Vision coordinates.
    static func mapRawSamplePoint(
        _ point: RawBufferPoint,
        using snapshot: FrameTransformSnapshot?
    ) -> NormalizedViewportPoint? {
        guard let snapshot, snapshot.isValid,
              point.xPixels.isFinite, point.yPixels.isFinite,
              let aperture = snapshot.cleanAperturePixels,
              point.xPixels >= aperture.x,
              point.xPixels <= aperture.x + aperture.width,
              point.yPixels >= aperture.y,
              point.yPixels <= aperture.y + aperture.height
        else { return nil }

        let localX = point.xPixels - aperture.x
        let localY = point.yPixels - aperture.y
        let oriented: ImagePoint
        switch snapshot.rawToOrientedRotation {
        case .degrees0:
            oriented = ImagePoint(x: localX, y: localY)
        case .degrees90Clockwise:
            oriented = ImagePoint(x: aperture.height - localY, y: localX)
        case .degrees180:
            oriented = ImagePoint(x: aperture.width - localX, y: aperture.height - localY)
        case .degrees270Clockwise:
            oriented = ImagePoint(x: localY, y: aperture.width - localX)
        }
        return mapOrientedPoint(oriented, using: snapshot)
    }

    private static func mapOrientedPoint(
        _ point: ImagePoint,
        using snapshot: FrameTransformSnapshot
    ) -> NormalizedViewportPoint? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let image = snapshot.orientedImagePixels
        let viewport = snapshot.viewportPoints
        let scale = max(viewport.width / image.width, viewport.height / image.height)
        guard scale.isFinite, scale > 0 else { return nil }
        let offsetX = (viewport.width - image.width * scale) / 2
        let offsetY = (viewport.height - image.height * scale) / 2
        var previewX = point.x * scale + offsetX
        let previewY = point.y * scale + offsetY
        if snapshot.isPreviewMirrored { previewX = viewport.width - previewX }
        let normalized = NormalizedViewportPoint(
            x: previewX / viewport.width,
            y: previewY / viewport.height
        )
        return normalized.x.isFinite && normalized.y.isFinite ? normalized : nil
    }
}

private struct ImagePoint {
    let x: Double
    let y: Double
}
