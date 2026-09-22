# App target guidance

- This tree belongs to the `facetracking` application target. Keep one `@main` entry point under `App/`.
- `App/` owns composition and top-level routes; `CaptureUI/` owns SwiftUI presentation; `Tracking/` owns camera-free value types and algorithms; future `Camera/` owns framework integration; `Resources/` owns localized strings and assets.
- The target uses Swift 6 with complete concurrency checking and `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. Mark UI state and UI-owning reference types `@MainActor` explicitly; pure tracking types must remain nonisolated and `Sendable` where appropriate.
- Keep camera, Vision, persistence, networking, and permission requests out of the plan-00 shell. UI previews and tests must not start capture work.
- `TrackingConfiguration.provisional` is the `ios-provisional-v2` profile. Its algorithm values are units-explicit; version changes and tests must accompany threshold changes.
- Localize user-facing copy through `Resources/Localizable.xcstrings`. Do not add microphone or photo-library usage descriptions.
- `AGENTS.md` is excluded from synchronized-group target membership and must not be copied into the application bundle.
