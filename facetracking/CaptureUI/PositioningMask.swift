import SwiftUI

struct PositioningMask: View {
    let target: FaceGeometry

    var body: some View {
        GeometryReader { proxy in
            OvalCutoutShape(cutout: CaptureGeometry.rect(for: target, in: proxy.size))
                .fill(.white, style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct OvalCutoutShape: Shape {
    let cutout: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: cutout)
        return path
    }
}
