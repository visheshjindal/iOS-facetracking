# Acquisition retention and directional guidance — corrective handoff

- Scope: follow-up to initial acquisition fix, relevant plans 01/02/08; user reports screenshot-associated reset and repetitive centering.
- Date: 2026-09-22; existing uncommitted UI and orientation work preserved.
- Code status: complete.
- Automated verification: PASS, 21/21 focused positioning/session tests; 89/89 full unit/UI tests; unsigned device build.
- Human acceptance: pending R01/R02/F14 physical check.

## Changes and contracts

`Tracking/SessionTransition.swift` now preserves completed acquisition while invalidating camera generations for scene inactivity, interruption, geometry changes, and recoverable failures/retry within the same route. All raw face data, lighting/filter/hold history and timestamps still clear immediately; stop/start order and stale-generation rejection are unchanged. Exit, route removal and explicit Restart tracking reset alignment. An incomplete hold never survives a pause.

`Tracking/PositioningRules.swift` now gives mirrored left/right/up/down corrections during initial alignment, using existing localization and horizontal-first priority. Generic center advice is no longer returned for off-center detected geometry. No threshold, filter, pose requirement or hold duration changed.

`PositioningRulesTests.swift` and `SessionTransitionTests.swift` cover all initial directions, priority, acquisition through continuous observations, scene/interruption/geometry recovery without a new hold, ordered effects, stale rejection, partial-hold reset, explicit Restart and Exit/route removal. Tracking/test AGENTS, specification F04/F14/transition table, plans 01/02 and decision register document the intentional behavior change.

The provided screenshot establishes successful following and a detected face at that instant. It does not identify the later event that reset tracking. No participant image was copied into the repository or test fixtures. Physical detection reliability remains unmeasured.

## Verification evidence

| Check | Exact tool/command | Environment | Result |
| --- | --- | --- | --- |
| Compile | Xcode MCP `BuildProject(buildForTesting: true)` | iPhone 17 simulator, iOS 27.0, Xcode 27 | PASS |
| P/S focused | `GetTestList`, then `RunSomeTests` with all discovered PositioningRulesTests/SessionTransitionTests | Same | 21/21 PASS |
| Full suite | Xcode MCP `RunAllTests` | Same | 89/89 PASS, no skipped/failed/not-run |
| Unsigned device | Command below, approved outside sandbox for Swift macro plugins | Generic iOS device | PASS, exit 0 |
| Diff | `git diff --check` | Working tree | PASS |

Temporary result bundles: `Test-facetracking-2026.09.22_08-36-19-+0530.xcresult` and `Test-facetracking-2026.09.22_08-36-34-+0530.xcresult`, under the Xcode ActionArtifacts temporary directory. Build log: `/tmp/facetracking-retention-fix-device.log`. Active Xcode destination restored to the previously selected physical iPhone.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project facetracking.xcodeproj -scheme facetracking -destination 'generic/platform=iOS' -derivedDataPath /tmp/facetracking-acquisition-fix-device CODE_SIGNING_ALLOWED=NO build
```

## Human verification remaining

R01/R02/F14 — NOT RUN after this change. Device owner should rebuild/run on the same phone and record device/OS/build, Vision revision 3, profile `ios-provisional-v1`, and observations without saving imagery.

1. Enter alignment; move visibly left/right/up/down. Expected: specific opposite-direction corrections move the visible face toward the target. Once centered and sized, straight pose plus two-second hold acquires.
2. After acquisition, take a screenshot and dismiss any system preview. Expected: acquired state is retained; if frames pause the outline disappears, then fresh observations restore it without a new hold.
3. Open/dismiss Control Center; background/foreground. Expected: capture stops while inactive, then a fresh generation resumes following without stale geometry or reacquisition.
4. During an incomplete hold, pause/resume. Expected: a full fresh two-second hold is still required.
5. Exit/reenter or use Restart tracking during face loss. Expected: initial alignment returns deliberately.

## Decisions and next work

F04/F14 changes intentionally supersede original generic centering and automatic reacquisition behavior; no numeric profile change. R01–R07 remain OPEN. Plan 09 remains next. If device alignment is still difficult, record the new directional prompt sequence and inspect aggregate pose availability/geometry/hold-reset reasons before any calibration change.
