import SwiftUI

enum CaptureActionIdentifier {
    static let grant = "capture.grant"
    static let settings = "capture.settings"
    static let retry = "capture.retry"
    static let restart = "capture.restart"
    static let exit = "capture.exit"
}

enum GuidanceTextKey {
    static func key(for guidance: PrimaryGuidance) -> String {
        switch guidance {
        case let .positioning(hint): positioningKey(hint)
        case let .lighting(advice): lightingKey(advice)
        }
    }

    static func lightingKey(_ advice: LightingAdvice) -> String {
        switch advice {
        case .checking: "lighting.checking"
        case .acceptable: "lighting.okay"
        case .addLightLeft: "lighting.left"
        case .addLightRight: "lighting.right"
        case .useSoftEvenLight: "lighting.soften"
        case .addMoreLight: "lighting.more"
        case .reduceDirectLight: "lighting.reduce"
        }
    }

    static func failureKey(_ failure: SessionFailure) -> String {
        failure == .detectorUnavailable ? "error.detector" : "error.camera"
    }

    private static func positioningKey(_ hint: PositioningHint) -> String {
        switch hint {
        case .placeFace: "position.place"
        case .trackingLost: "position.lost"
        case .centerFace: "position.center"
        case .moveLeft: "position.left"
        case .moveRight: "position.right"
        case .moveUp: "position.up"
        case .moveDown: "position.down"
        case .farther: "position.farther"
        case .closer: "position.closer"
        case .lookStraight: "position.straight"
        case .holdStill: "position.hold"
        case .following: "position.following"
        }
    }
}

extension CaptureViewState {
    var accessibilityPromptKey: String {
        switch authorization {
        case .notDetermined, .denied:
            return "permission.title"
        case .restricted:
            return "permission.restricted"
        case .authorized:
            if isInterrupted { return "camera.interrupted" }
            if let failure { return GuidanceTextKey.failureKey(failure) }
            return GuidanceTextKey.key(for: guidance.primary)
        }
    }
}

enum LightingBadgeStyle: Equatable {
    case unknown
    case acceptable
    case warning

    static func style(for assessment: LightingAssessment) -> Self {
        switch assessment {
        case .unknown: .unknown
        case .acceptable: .acceptable
        case .tooDark, .tooBright, .uneven, .highContrast: .warning
        }
    }

    var foreground: Color {
        switch self {
        case .unknown, .acceptable: .white
        case .warning: .black
        }
    }

    var background: Color {
        switch self {
        case .unknown: .black.opacity(0.68)
        case .acceptable: Color(red: 18 / 255, green: 138 / 255, blue: 82 / 255)
        case .warning: Color(red: 255 / 255, green: 176 / 255, blue: 32 / 255)
        }
    }
}

enum CaptureGeometry {
    static func rect(for geometry: FaceGeometry, in size: CGSize) -> CGRect {
        CGRect(
            x: (geometry.centerX - geometry.width / 2) * size.width,
            y: (geometry.centerY - geometry.height / 2) * size.height,
            width: geometry.width * size.width,
            height: geometry.height * size.height
        )
    }
}
