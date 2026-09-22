# Decision register

Updated 2026-09-21 by plan 00. “Recorded” means the implementation direction is explicit; it does not close related physical-device or product-review gates.

| ID | Source decision | Plan-00 implementation choice and reason | Evidence | Status / open questions |
| --- | --- | --- | --- | --- |
| D01 | Alignment requires 2,000 ms continuously, resolving the prior 1,000 ms discrepancy. | `TrackingConfiguration.Timing.acquisitionHoldMS = 2_000`; preserve the specified product behavior for later deterministic tests. | Configuration profile test. | Recorded; live behavior begins in plan 01 and physical acceptance remains pending. |
| D02 | iPhone, portrait, front camera; proposed iOS 17+, Swift 6, stable Xcode. | Provisional iOS 17.0 minimum, Swift 6, iPhone family 1, portrait only, Xcode 27 SDK; nonisolated default actor isolation with explicit UI isolation. This lets pure and camera types avoid accidental MainActor inheritance. | Generated Info.plist, Debug/Release build settings, `toolchain.md`. | OPEN under R07: supported iPhone list, minimum iOS, and oldest/newer physical devices need product confirmation. No iOS 17 runtime is installed here. |
| D03 | SwiftUI + AVFoundation preview; one app, unit-test, and UI-test targets; ordinary initializer injection. | Created the three named targets and shared scheme using XCTest/XCUITest. The M0 shell is SwiftUI only and intentionally has no AVFoundation code. | `xcodebuild -list`, passing smoke suites, source scan. | Recorded; preview/service implementation is deferred to plan 03. |
| D04 | Use the first usable face; no identity or multi-face failure. | No detector exists in M0; the rule is retained for later implementation without speculative selector code. | Source specification and R03 record. | Recorded; R03 OPEN. |
| D05 | Lighting is advisory and never blocks positioning completion. | Constants are recorded but no lighting reducer/UI behavior is implemented in M0. | `TrackingConfiguration.swift`. | Recorded; behavior deferred to plans 06–07 and R04 remains OPEN. |
| D06 | Filter guidance over 150 ms; draw current raw geometry independently. | `guidanceEMATimeConstantMS = 150`; no drawing/filtering algorithms are introduced in M0. | Configuration profile. | Recorded; implementation and tests deferred to plan 01/UI plans. |
| D07 | Native permission handling; Exit returns/dismisses and never terminates the process. | The placeholder Exit dismisses its full-screen route back to landing. There is no permission request yet. | Passing XCUITest landing → capture → Exit → landing. | Recorded; denied/restricted/Settings behavior is deferred to plan 03. Human shell smoke remains NOT RUN. |
| D08 | Withdraw stale face after age >300 ms; fail analysis after >5,000 ms. | Profile records `faceFreshnessMS = 300`, `analysisStallMS = 5_000`, and `watchdogCadenceMS = 250`; no watchdog/state machine is implemented in M0. | Configuration profile test. | Recorded; behavior deferred to plans 02 and 05; R05 OPEN. |
| D09 | Start with provisional lighting profile `ios-provisional-v1`. | All section 7/8 constants are grouped by timing, positioning, sampling, luma, and lighting; presentation values are separate. | Passing profile identity test and source review. | Recorded as provisional; R04 calibration OPEN and any threshold change requires a new version plus tests. |

## D02 / R02 acquisition correction — 2026-09-22

The fixed portrait interface now uses one device-aware orientation policy for both preview and video-data output. Previously preview followed the rotation coordinator while output hard-coded 90°, and the analyzer treated every other applied angle as needing another 90° rotation. This violated the shared-viewport contract and could produce misleading center/distance guidance or invalid pose. `CameraPortraitOrientation` uses the iOS 27 static device-relative query; iOS 17–26 deliberately uses the deprecated but supported semantic portrait API because a gravity-based angle is not a fixed interface orientation. The two deprecation warnings are localized to that compatibility branch. No concurrency checks are disabled.

The camera owner requires successful physical orientation before start; Vision receives `.up` and luma uses the same delivered-pixel transform. D01 hold, D04 selection, D05 advisory lighting, and all `ios-provisional-v1` thresholds remain unchanged. See [acquisition fix handoff](handoffs/acquisition-fix.md). R01/R02 remain OPEN pending actual face/pose testing.

## F04/F14, D08 / R02 usability correction — 2026-09-22

User reports one successful acquisition followed by a reset around taking a screenshot, and repeated unhelpful centering advice. The supplied screenshot shows following with a raw green oval; it is not proof of the exact lifecycle event that followed. Source review establishes that scene inactivity, camera interruption and meaningful viewport changes all discarded completed acquisition.

Separate camera generations from the acquired stage: suspend capture and clear observations/history/timers immediately as before, but retain following within the route across those events and recoverable errors. Retry allocates a fresh generation without reacquiring. Explicit Restart tracking and Exit/route removal restore alignment. Incomplete holds always restart. This intentionally supersedes the original plan-02 automatic reacquisition policy; specification F14 and transition table are updated.

For F04/P04, use the existing mirrored directional hints during initial alignment too. The generic center prompt supplied no actionable axis or direction. Numerical thresholds, two-second duration and unknown-pose semantics remain unchanged. R01/R02/R04 stay OPEN; no calibration is inferred from one image.

## D09 / F04/F07/L08 — provisional v2 comfort and current lighting evidence

2026-09-22 user explicitly requested more positioning tolerance, acceptance farther from the camera, and a fix for persistent right-side advice. Profile `ios-provisional-v2` changes alignment center tolerance from 10% to 15% of each target dimension, following tolerance from 10% to 25%, and minimum face scale from 65% to 50%. Maximum size, pose bands, two-second hold, EMA, anchor, freshness, and all exposure/imbalance thresholds remain unchanged. This is provisional usability tuning authorized by the user; R04 calibration is still OPEN.

A verified presentation defect retained the previous active side while replacement candidates changed without settling, potentially displaying that old instruction indefinitely. The projection now withdraws a contradicted warning and shows checking while the replacement settles, without bypassing 400/700 ms persistence or modifying reducer history. A synthetic Y-plane pipeline test confirms raw-left darkness maps to mirrored-right advice, swapping light reverses advice, equal light settles acceptable, and dark/bright produce their own guidance. There is no hard-coded right-side branch. This proves controlled-input behavior, not the cause of every physical right-side warning; genuine asymmetric light or measurement bias still needs R02/R04 device evidence.

## F13/F14 runtime recovery and code review cleanup — 2026-09-22

User approved review fixes. AVFoundation media-services reset is now distinguished from generic runtime errors using the notification's error domain/code. It triggers reducer-owned ordered stop/start with fresh generation when the current attempt is still eligible. Other errors retain manual Retry. This is a scoped recovery exception to the earlier generic-runtime-error policy; following is preserved per the prior accepted lifecycle correction. Observer registration captures session identity so an older queued reset cannot restart a replacement attempt.

Logs retain only an allowlisted domain category and integer code, never error descriptions/userInfo or arbitrary domains. FPS validation and reported configured FPS use the requested value. Pose latch simplification relies on the existing filter reset after a gap; optional bindings replace hold force unwraps without threshold/behavior changes.
