# Camera and positioning review fixes

- Scope: user-approved findings in the supplied review, within plans 01/02/03/05; no new numbered-plan implementation.
- Date: 2026-09-22; prior uncommitted changes preserved.
- Code: complete. Automated verification: passed. Physical media-services reset acceptance: NOT RUN.

## Changes and contracts

- CameraSessionService reads runtime notification errors into CameraFailureDetails, a Sendable value containing only an allowlisted domain category and optional integer code. No notification/error object, description, userInfo, arbitrary domain string, or identifying data enters logs or crosses the camera queue boundary.
- AVFoundation mediaServicesWereReset emits a reliable typed event. CaptureStore forwards it to SessionTransition, which rejects obsolete/ineligible callbacks and issues ordered stop/start for a fresh generation. Completed tracking is preserved; measurements/history/timers are cleared. Other errors continue to show cameraUnavailable with explicit Retry. Existing session configuration is reused, as it already was for manual Retry.
- Runtime observers capture the session ID at registration and are replaced on each start; a queued notification from an old registration cannot affect a new generation. Camera queue assertions cover observer installation/removal and diagnostic logging.
- Requested FPS now drives range validation, frame duration, and reported configured FPS. Removed the redundant post-start ID guard; queue-confinement comment explains why no stop command can interleave inside startRunning.
- PositioningRules removes the equivalent raw-pose/gap latch branch. After a gap the existing filter returns the raw face, so the retained latch still applies exit bands. Optional bindings and a local stableSinceMS replace both hold force unwraps. No threshold, timing, or positioning behavior changed.
- Tests added in CameraFailureDetailsTests and SessionTransitionTests. Camera/Tracking/test scoped instructions, specification transition table, decisions, and STATUS updated.

## Verification evidence

| Check | Exact tool/command | Environment | Result |
| --- | --- | --- | --- |
| Build with tests | Xcode MCP BuildProject(buildForTesting: true) | Xcode 27, iPhone 17 simulator iOS 27 | PASS |
| Focused | GetTestList then RunSomeTests for CameraFailureDetailsTests, SessionTransitionTests, PositioningRulesTests, CameraPreviewLifecycleTests | Same | 33/33 PASS |
| Full unit/UI | Xcode MCP RunAllTests | Same | 95/95 PASS, no skipped/failed/not-run |
| Unsigned device | Command below | Generic iOS | PASS, exit 0 |
| Whitespace/scope | git diff --check; source audit | Working tree | PASS |

Temporary result bundles: `Test-facetracking-2026.09.22_12-46-59-+0530.xcresult` (focused), `Test-facetracking-2026.09.22_12-47-13-+0530.xcresult` (full), under Xcode ActionArtifacts. Device log `/tmp/facetracking-review-fixes-device.log`. Xcode destination restored to previously selected physical iPhone.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project facetracking.xcodeproj -scheme facetracking -destination 'generic/platform=iOS' -derivedDataPath /tmp/facetracking-review-fixes-device CODE_SIGNING_ALLOWED=NO build
```

## Human verification remaining

F13/F14 physical media-services recovery — NOT RUN. On a supported signed-device build, a device owner can exercise a controlled media-services reset using available developer tooling, then return to the capture route. Expected: a fresh camera generation resumes without reacquiring an already-following face; ordinary runtime errors retain Retry. Repeat with the capture route dismissed/inactive and verify no camera restart. Record device/OS/build, error category/code, ordered generation events, recovery outcome, and reviewer; no participant imagery. Automated tests prove classification and reducer policy, not an actual OS media-server restart.

## Decisions and next work

F13/F14 now distinguishes media-services reset from generic failures; no threshold/profile change. Prior user-confirmed positioning/lighting acceptance remains recorded. R01–R07 are not closed by these changes. Plan 09 remains next; physical reset evidence is a later reliability gate.
