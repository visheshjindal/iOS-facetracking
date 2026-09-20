# Tracking guidance

- This directory owns camera-free, nonisolated `Sendable` value types and pure algorithms. Do not import SwiftUI, Vision, AVFoundation, clocks, or localized copy.
- Face geometry uses normalized mirrored-preview coordinates with a top-left origin. Normalize width and height separately; retain partially outside coordinates and reject non-finite, non-positive, or non-intersecting boxes.
- Calculations use `Double`; session and geometry revisions use `UInt64`; injected monotonic timestamps use `Int64` milliseconds.
- A missing or non-finite pose is unknown, never neutral. It may accompany drawable geometry but cannot pass positioning or lighting eligibility.
- A 300 ms gap remains continuous; 301 ms resets filter and hold. EMA uses elapsed time. Acquisition occurs only on an eligible observation at 2,000 ms or later.
- Hold stability compares against the fixed hold-start anchor. Across a gap only the valid-pose latch may survive, and only when the current complete raw pose remains in the exit band.
- Focused tests: `xcodebuild ... -only-testing:facetrackingTests/PositioningRulesTests test` using the simulator and temporary paths recorded in `docs/implementation/toolchain.md`.
- Keep this file excluded from synchronized-group target membership and the app bundle.
