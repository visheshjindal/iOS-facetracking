import SwiftUI

struct GuidanceText: View {
    let guidance: PrimaryGuidance
    let isFollowing: Bool

    var body: some View {
        Text(LocalizedStringKey(GuidanceTextKey.key(for: guidance)))
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(24)
            .foregroundStyle(isFollowing ? Color.white : Color.black)
            .background(isFollowing ? Color.black.opacity(0.70) : Color.white)
            .accessibilityIdentifier("capture.guidance")
    }
}
