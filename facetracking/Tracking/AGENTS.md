# Tracking guidance

- This directory owns camera-free, nonisolated `Sendable` value types and pure algorithms. Do not import SwiftUI, Vision, AVFoundation, clocks, or localized copy.
- Face geometry uses normalized mirrored-preview coordinates with a top-left origin. Normalize width and height separately; retain partially outside coordinates and reject non-finite, non-positive, or non-intersecting boxes.
- Calculations use `Double`; session and geometry revisions use `UInt64`; injected monotonic timestamps use `Int64` milliseconds.
- A missing or non-finite pose is unknown, never neutral. It may accompany drawable geometry but cannot pass positioning or lighting eligibility.
- `LightingMeasurement` consumes owned canonical 0–255 samples already mapped to the mirrored viewport. It uses the raw current face box and inner ellipse radii 0.40/0.38; equality at region splits belongs to right/bottom.
- Five 256-bin histograms produce rank-exact median, 10%-per-tail trimmed means (including partial buckets), and inclusive shadow `<=24` / highlight `>=235` fractions. Require total `>=96`, every region `>=32`, consistent partitions, finite 0–255 means, and valid fractions.
- Missing face/pose/transform, failed pose eligibility, unsupported data, or invalid counts yields nil metrics for that frame. Never carry forward previous metrics.
- `LightingRules` owns active-versus-candidate lighting state. Candidate identity includes assessment and optional side; invalid/ineligible input resets immediately, while a gap over 300 ms resets and discards that sample.
- Acceptable compact evidence starts at the original acceptable-candidate timestamp and advances only on fresh observations. All lighting constants remain in versioned `TrackingConfiguration.provisional` (`ios-provisional-v2`); calibration changes require a new profile and plan 11 evidence.
- `GuidanceRules` is the sole typed presentation projection. Positioning corrections outrank lighting; warnings may replace only hold/follow. Lighting never participates in acquisition eligibility.
- A 300 ms gap remains continuous; 301 ms resets filter and hold. EMA uses elapsed time. Acquisition occurs only on an eligible observation at 2,000 ms or later.
- Hold stability compares against the fixed hold-start anchor. Across a gap only the valid-pose latch may survive, and only when the current complete raw pose remains in the exit band.
- `SessionState.swift` is the lifecycle authority and owns generation, revision, attempt, raw-face, positioning, future-lighting, and typed-failure state. `SessionTransition.reduce(state:event:)` is the only session transition entry point and returns ordered `SessionEffect` values.
- Invalidate `activeSessionID` before requesting camera teardown. Replacements record stop before start; stale session/revision events and non-increasing observation timestamps must return the entire state and effect list unchanged before touching any history.
- Viewport bounds changes below 0.5 point are ignored relative to the last accepted viewport. Accumulated changes eventually cross that threshold, and every transform-revision change is meaningful.
- `SessionViewport` describes the stable preview container in points; frame-specific raw/oriented/crop/mirror details belong to Camera's immutable transform snapshot. Face geometry entering Tracking is already normalized to the mirrored top-left viewport and may remain partly outside it when intersecting.
- Session and geometry increments are checked. Identifier exhaustion and geometry-revision exhaustion are explicit non-retryable failures; never wrap an old identity back into use.
- Focused tests: `LightingMeasurementTests`, `LightingRulesTests`, `GuidanceRulesTests`, `PositioningRulesTests`, and `SessionTransitionTests` using the simulator and temporary paths recorded in `docs/implementation/toolchain.md`.
- Keep this file excluded from synchronized-group target membership and the app bundle.

- Camera generations do not own completed acquisition: retain following through pause/interruption/retry/viewport changes within the route, clearing all measured/history/timer data. Only explicit Restart, Exit, or route removal resets alignment. Partial holds always reset on suspension.
- Center corrections use mirrored left/right/up/down during both alignment and following; retain horizontal-before-vertical priority and existing inclusive thresholds.

- Profile v2 permits center offsets of 0.15 target dimensions during alignment and 0.25 while following; minimum face scale is 0.50. These are user-requested provisional usability settings, not completed R04 calibration.
- A retained lighting warning with a pending replacement candidate projects as checking until settled or supported again. Keep reducer hysteresis history intact; never show the stale side while current evidence contradicts it.

- `cameraMediaServicesReset` recovers only the current desired-running generation, with ordered teardown/start and cleared measurements; preserve acquired stage. Other failures still require explicit Retry. Pose-gap behavior follows filter reset to raw pose; the latch applies exit bands when previously valid.
