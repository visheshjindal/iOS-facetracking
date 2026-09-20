enum PreviewGeometry {
    static func target(viewportWidthPoints width: Double, viewportHeightPoints height: Double) -> FaceGeometry? {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }

        let ovalWidthPoints = min(0.72 * width, (0.50 * height) / 1.35)
        return FaceGeometry(
            centerX: 0.5,
            centerY: 0.5,
            width: ovalWidthPoints / width,
            height: 1.35 * ovalWidthPoints / height
        )
    }
}
