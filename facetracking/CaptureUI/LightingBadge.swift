import SwiftUI

struct LightingBadge: View {
    let badge: LightingBadgeProjection

    var body: some View {
        let key = GuidanceTextKey.lightingKey(badge.advice)
        let style = LightingBadgeStyle.style(for: badge.assessment)
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .accessibilityHidden(true)
            if badge.presentation == .expanded {
                Text(LocalizedStringKey(key))
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(style.background, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(key)))
        .accessibilityIdentifier("capture.lightingBadge")
    }

    private var iconName: String {
        switch badge.assessment {
        case .unknown: "sun.min"
        case .acceptable: "checkmark.circle.fill"
        case .tooDark: "sun.min.fill"
        case .tooBright: "sun.max.fill"
        case .uneven: "circle.lefthalf.filled"
        case .highContrast: "circle.righthalf.filled"
        }
    }
}
