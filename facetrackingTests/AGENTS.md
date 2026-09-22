# Unit-test target guidance

- Use XCTest and `@testable import facetracking`; keep one test vocabulary across unit and UI targets.
- Algorithm tests must be deterministic and camera-free. Inject monotonic milliseconds and service doubles; never use real sleeps for hold, freshness, watchdog, or persistence behavior.
- Express boundary expectations independently of production helpers, including exact equality and just-over-threshold cases.
- Keep synthetic geometry/luma fixtures small and labeled with coordinate convention, units, session ID, geometry revision, and timestamps.
- Build hold fixtures with explicit continuous timestamps (no gap over 300 ms), including intermediate observations before exact duration boundaries.
- For EMA boundary tests, seed/reset history so smoothing cannot accidentally move a raw boundary fixture. Calculate expected filter values independently with `1 - exp(-deltaMS / 150)`.
- Test fixed-anchor drift with multiple individually sub-threshold steps, and pair every inclusive limit with a just-outside value.
- Session fixtures record the complete ordered effect stream. Race permutations must assert that obsolete start/stop/error/observation events leave both state and effects unchanged, not merely that the final active ID looks correct.
- Camera lifecycle doubles record every start/stop command with its session ID, can withhold and reorder callbacks, and track simultaneous active generations. Authorization doubles retain the pending completion so repeated Grant actions can be tested before resolution.
- Store tests run on `MainActor`, inject authorization/camera/clock/Settings/dismissal, and clear callback retention before asserting weak deallocation.
- G01/G02 fixtures must label all four raw corners, use non-square rectangles, unequal viewport aspects, explicit clean-aperture offsets, raw pixel centers, and unequal left/right luma. Expected coordinates are hand-calculated in comments rather than produced by mapper helpers.
- Pair Vision lower-left rectangles with raw top-left sample points only through the same immutable `FrameTransformSnapshot`; never disguise raw samples as Vision-normalized inputs. Include one-mirror and completely-outside rejection assertions.
- Detector doubles return ordered candidate arrays or throw synchronously. Cover incomplete pose, radians-to-degrees conversion, invalid-before-usable selection, nil-face success, stale completion, and generation invalidation.
- Mailbox fixtures manually drain scheduled closures and assert one scheduled drain plus one pending newest observation. Timer fixtures advance injected monotonic milliseconds through 300/301 and 5,000/5,250 boundaries.
- Luma byte fixtures use explicit width/height/stride, padding sentinels, tiny dimensions, range labels, and hand-computed values. Assert the 4,096 cap and never derive expected statistics through production helpers.
- Histogram fixtures name every bucket/count and cover even/odd ranks, partial-bucket trimming, inclusive 24/235 cutoffs, 95/96 totals, 31/32 regions, partition errors, NaN, ellipse edges, and right/bottom equality.
- Lighting classification fixtures must satisfy metric count/fraction invariants and state expected outcomes independently. For persistence boundaries, include intermediate samples no more than 300 ms apart; a 301 ms gap intentionally discards the current sample.
- Exercise candidate changes as `(assessment, side)` keys. Separate exposure entry/exit, imbalance entry/strict-exit, high-contrast recovery, invalid/nil-pose reset, out-of-order rejection, and fresh-observation-only compact timing.
- U01–U04 projection fixtures assert stable localization/action identifiers, mask/guide/outline state, badge style/label, and raw-versus-filtered geometry without introspecting SwiftUI layout. Build acquisition fixtures with injected timestamps through 1,999/2,000 ms.
- `CaptureFixture.allCases` must construct state without authorization or camera services. Keep the DEBUG launch harness isolated from release composition and cover that invariant by source/bundle audit.
- Build lifecycle fixtures through reducer events; direct state mutation is reserved for otherwise unreachable overflow boundaries and seeding history that a test explicitly names.
- Focused command: `xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingTests test` with temporary DerivedData and result-bundle paths.
- `AGENTS.md` is excluded from synchronized-group target membership and test bundles.

- Acquisition regressions must pass asymmetric detector bounds through `FrameAnalyzer`, then positioning. Cover physically upright buffers whose applied sensor angles are 0/90/180/270; Vision must receive `.up` and no second rotation.

- Acquire through continuous reducer observations before lifecycle retention assertions; test fresh-generation recovery, stale callback rejection, incomplete-hold reset, and explicit Restart/Exit separately.

- Cover stage-specific center boundaries and acquisition with minimum-size faces. Luma direction regressions should use patterned Y-plane buffers through analyzer, reducer, and projection (both mirrored sides, recovery, dark and bright), not only fabricated metrics.

- Runtime-error tests cover AVFoundation code/domain matching, missing/malformed payloads, recovery effect order and stale/inactive/denied/exit rejection. Never use a real media-services reset in automated camera-free tests.
