# Tracking guidance

- This directory owns camera-free, nonisolated `Sendable` value types and pure algorithms. Do not import SwiftUI, Vision, AVFoundation, clocks, or localized copy.
- Face geometry uses normalized mirrored-preview coordinates with a top-left origin. Normalize width and height separately; retain partially outside coordinates and reject non-finite, non-positive, or non-intersecting boxes.
- Calculations use `Double`; session and geometry revisions use `UInt64`; injected monotonic timestamps use `Int64` milliseconds.
- A missing or non-finite pose is unknown, never neutral. It may accompany drawable geometry but cannot pass positioning or lighting eligibility.
- `LightingMeasurement` consumes owned canonical 0–255 samples already mapped to the mirrored viewport. It uses the raw current face box and inner ellipse radii 0.40/0.38; equality at region splits belongs to right/bottom.
- Five 256-bin histograms produce rank-exact median, 10%-per-tail trimmed means (including partial buckets), and inclusive shadow `<=24` / highlight `>=235` fractions. Require total `>=96`, every region `>=32`, consistent partitions, finite 0–255 means, and valid fractions.
- Missing face/pose/transform, failed pose eligibility, unsupported data, or invalid counts yields nil metrics for that frame. Never carry forward previous metrics. Classification, persistence, advice, and threshold tuning belong to plan 07/11.
- A 300 ms gap remains continuous; 301 ms resets filter and hold. EMA uses elapsed time. Acquisition occurs only on an eligible observation at 2,000 ms or later.
- Hold stability compares against the fixed hold-start anchor. Across a gap only the valid-pose latch may survive, and only when the current complete raw pose remains in the exit band.
- `SessionState.swift` is the lifecycle authority and owns generation, revision, attempt, raw-face, positioning, future-lighting, and typed-failure state. `SessionTransition.reduce(state:event:)` is the only session transition entry point and returns ordered `SessionEffect` values.
- Invalidate `activeSessionID` before requesting camera teardown. Replacements record stop before start; stale session/revision events and non-increasing observation timestamps must return the entire state and effect list unchanged before touching any history.
- Viewport bounds changes below 0.5 point are ignored relative to the last accepted viewport. Accumulated changes eventually cross that threshold, and every transform-revision change is meaningful.
- `SessionViewport` describes the stable preview container in points; frame-specific raw/oriented/crop/mirror details belong to Camera's immutable transform snapshot. Face geometry entering Tracking is already normalized to the mirrored top-left viewport and may remain partly outside it when intersecting.
- Session and geometry increments are checked. Identifier exhaustion and geometry-revision exhaustion are explicit non-retryable failures; never wrap an old identity back into use.
- Focused tests: `LightingMeasurementTests`, `PositioningRulesTests`, and `SessionTransitionTests` using the simulator and temporary paths recorded in `docs/implementation/toolchain.md`.
- Keep this file excluded from synchronized-group target membership and the app bundle.
