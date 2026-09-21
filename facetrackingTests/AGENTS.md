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
- Build lifecycle fixtures through reducer events; direct state mutation is reserved for otherwise unreachable overflow boundaries and seeding history that a test explicitly names.
- Focused command: `xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingTests test` with temporary DerivedData and result-bundle paths.
- `AGENTS.md` is excluded from synchronized-group target membership and test bundles.
