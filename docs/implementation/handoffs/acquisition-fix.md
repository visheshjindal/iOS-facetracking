# Initial acquisition — corrective handoff

- Scope: user-requested review/fix of initial tracking and center/farther guidance; relevant plans 01, 04, 05, 08. No plan 09–11 implementation.
- Date: 2026-09-22, existing uncommitted plan-08 working tree preserved.
- Code status: complete.
- Automated verification: 8/8 focused analyzer tests and 86/86 full unit/UI tests passed, no skips or not-run tests.
- Human acceptance: pending physical R01/R02 check.

## Changes and contracts

- `Camera/CameraPortraitOrientation.swift`: one fixed portrait policy for preview and output, accounting for camera sensor mounting. Uses iOS 27 `videoRotationAngleRelative(toDeviceOrientation:)`; supported semantic `videoOrientation = .portrait` on iOS 17–26. The latter deliberately has two deprecation warnings; it avoids guessing a sensor angle or using independently changing gravity angles.
- `Camera/CameraSessionService.swift`: removed fixed 90° output rotation; require orientation support before capture starts and retain the actual applied angle for diagnostics.
- `CaptureUI/CameraPreview.swift`: use the same fixed portrait policy. Preserve mirroring, stable preview identity, and bounds-driven viewport reporting.
- `Camera/FrameAnalyzer.swift`: delivered buffers are physically upright for any applied sensor angle; use Vision `.up`, delivered dimensions, and zero additional luma rotation. Previously every angle except 90° was treated as requiring another quarter-turn, swapping dimensions and distorting mapped bounds.
- `FrameAnalyzerTests.swift`: asymmetric bounds test across 0/90/180/270 applied angles and a mapped-detection-to-positioning regression proving hold through 1,999 ms and following at 2,000 ms.
- Camera/CaptureUI/test scoped instructions, specification section 6, D02/R02 decision note, and STATUS updated. No product thresholds, pose requirements, freshness policy, or guidance priority changed.

The inconsistent orientation paths are established by source review. Whether they fully explain the reported physical failure remains subject to device confirmation; synthetic detector doubles cannot establish real Vision pose availability.

## Verification evidence

| Requirement | Command / tool | Environment | Result |
| --- | --- | --- | --- |
| SDK contract | Read pinned Xcode 27 AVFoundation headers, including static angle API availability and physical data-output rotation; checked [Apple RotationCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator) | Xcode 27.0 SDK | API compiles; iOS 17–26 branch guarded |
| Build | Xcode MCP `BuildProject(buildForTesting: true)` | iPhone 17 simulator, iOS 27.0 | PASS |
| G01/G02/F04/F05/P02 | Xcode MCP `RunSomeTests`, all eight `FrameAnalyzerTests` discovered by `GetTestList` | Same simulator | 8/8 PASS |
| Full integration | Xcode MCP `RunAllTests` | Same simulator | 86/86 PASS, 0 failed/skipped/not-run |
| Unsigned build, first attempt | Command below inside sandbox | Generic iOS | FAILED: sandbox prevented Swift macro plugin execution |
| Unsigned build, approved rerun | Same command outside sandbox; log `/tmp/facetracking-acquisition-fix-device.log` | Generic iOS | PASS, exit 0 |
| Diff audit | `git diff --check` | Working tree | PASS |

Temporary focused result: `Test-facetracking-2026.09.22_08-26-48-+0530.xcresult`.
Temporary full result: `/var/folders/kv/hynb8lv50ml31bkt5_cdf_pm0000gn/T/ActionArtifacts/default/RunAllTests/Test-facetracking-2026.09.22_08-27-00-+0530.xcresult`.
Xcode destination restored to the previously selected physical iPhone. Session workspace identifiers are not durable configuration.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project facetracking.xcodeproj -scheme facetracking -destination 'generic/platform=iOS' -derivedDataPath /tmp/facetracking-acquisition-fix-device CODE_SIGNING_ALLOWED=NO build
```

## Human verification remaining

Gate R01/R02, actual result **NOT RUN**: device owner runs a rebuilt signed app on the reported iPhone, with one person, normal room lighting, portrait interface, and face straight toward the camera. Record device/OS/build, request revision 3 and profile `ios-provisional-v1`; no images or identifying face data.

1. Exit/reopen capture. Move face into the oval, adjust distance until hold guidance (or advisory lighting advice) appears, and stay still for two seconds. Expected: white mask fades and green following oval appears.
2. Move left/right and up/down after acquisition. Expected: green oval follows the visible face and corrections lead toward center; verify edges and mirror once.
3. Tilt/roll the phone slightly without changing the portrait interface and repeat. Expected: preview and measured geometry stay in the same coordinate frame; invalid pose may ask to look straight, never silently pass.
4. Leave/reenter frame. Expected: following recovers without another initial hold. Exit/reopen should require a fresh hold.
5. If still blocked, record the exact prompt sequence and whether look-straight or hold ever appears; inspect aggregate pose-availability and timing on device under the existing R01/R05 procedure. Do not substitute neutral angles or widen thresholds to force acquisition.

## Decisions and next work

D01–D09 product choices and all numerical thresholds are preserved. R01–R07 stay OPEN; no physical calibration or latency evidence is claimed. Plan 09 remains the next numbered plan. This fix provides no permission to skip its accessibility work or close R01/R02. Minimum-OS orientation branch runtime verification remains pending on an actual supported device.
