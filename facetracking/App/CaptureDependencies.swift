import Foundation
import UIKit

protocol MonotonicClock: Sendable {
    func nowMilliseconds() -> Int64
}

struct SystemMonotonicClock: MonotonicClock {
    func nowMilliseconds() -> Int64 {
        Int64(clamping: DispatchTime.now().uptimeNanoseconds / 1_000_000)
    }
}

@MainActor
protocol SettingsOpening: AnyObject {
    func openSettings()
}

@MainActor
final class SystemSettingsOpener: SettingsOpening {
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct CaptureDependencies {
    let authorization: CameraAuthorizing
    let camera: CameraSessionControlling
    let clock: any MonotonicClock
    let settingsOpener: SettingsOpening

    @MainActor
    static func live() -> CaptureDependencies {
        CaptureDependencies(
            authorization: SystemCameraAuthorization(),
            camera: CameraSessionService(),
            clock: SystemMonotonicClock(),
            settingsOpener: SystemSettingsOpener()
        )
    }
}
