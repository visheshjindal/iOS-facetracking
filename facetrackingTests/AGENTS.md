# Unit-test target guidance

- Use XCTest and `@testable import facetracking`; keep one test vocabulary across unit and UI targets.
- Algorithm tests must be deterministic and camera-free. Inject monotonic milliseconds and service doubles; never use real sleeps for hold, freshness, watchdog, or persistence behavior.
- Express boundary expectations independently of production helpers, including exact equality and just-over-threshold cases.
- Keep synthetic geometry/luma fixtures small and labeled with coordinate convention, units, session ID, geometry revision, and timestamps.
- Build hold fixtures with explicit continuous timestamps (no gap over 300 ms), including intermediate observations before exact duration boundaries.
- For EMA boundary tests, seed/reset history so smoothing cannot accidentally move a raw boundary fixture. Calculate expected filter values independently with `1 - exp(-deltaMS / 150)`.
- Test fixed-anchor drift with multiple individually sub-threshold steps, and pair every inclusive limit with a just-outside value.
- Focused command: `xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingTests test` with temporary DerivedData and result-bundle paths.
- `AGENTS.md` is excluded from synchronized-group target membership and test bundles.
