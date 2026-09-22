import SwiftUI

struct FaceReturnGuide: View {
    let target: FaceGeometry

    var body: some View {
        GeometryReader { proxy in
            let oval = CaptureGeometry.rect(for: target, in: proxy.size)
            ZStack {
                Ellipse()
                    .stroke(.white.opacity(0.82), lineWidth: 3)
                    .frame(width: oval.width, height: oval.height)
                    .position(x: oval.midX, y: oval.midY)

                GuideEyes(oval: oval)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("guide.return"))
            .accessibilityIdentifier("capture.returnGuide")
        }
        .allowsHitTesting(false)
    }
}

private struct GuideEyes: View {
    let oval: CGRect

    var body: some View {
        ForEach([-0.18, 0.18], id: \.self) { offset in
            let center = CGPoint(
                x: oval.midX + offset * oval.width,
                y: oval.midY - 0.11 * oval.height
            )
            Ellipse()
                .stroke(.white.opacity(0.82), lineWidth: 2)
                .frame(width: 0.13 * oval.width, height: 0.035 * oval.height)
                .position(center)
            Circle()
                .fill(.white.opacity(0.82))
                .frame(width: 2, height: 2)
                .position(center)
        }
    }
}
