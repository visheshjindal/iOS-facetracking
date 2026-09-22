import SwiftUI

struct TrackedFaceOverlay: View {
    let face: FaceGeometry

    var body: some View {
        GeometryReader { proxy in
            let oval = CaptureGeometry.rect(for: face, in: proxy.size)
            Ellipse()
                .stroke(Color(red: 0, green: 1, blue: 135 / 255), lineWidth: 5)
                .frame(width: oval.width, height: oval.height)
                .position(x: oval.midX, y: oval.midY)
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}
