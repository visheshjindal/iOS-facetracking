# Positioning tolerance and responsive lighting — corrective handoff

- Scope: explicit user request to allow natural movement/farther faces and investigate persistent right-side lighting guidance. Relevant plans 01/06/07/08; prerequisite handoffs and current camera/measurement contracts reviewed.
- Date: 2026-09-22, existing uncommitted UI/orientation/lifecycle work preserved.
- Code: complete. Automated verification: passed. Physical acceptance: user-confirmed for the reported positioning/lighting issues on 2026-09-22. Broader R02/R04 research remains open.

## Changes and contracts

- `TrackingConfiguration.swift`: version `ios-provisional-v2`. Center tolerance is 15% of target width/height for alignment (was 10%), 25% for following (was 10%); minimum face dimensions are 50% of target (was 65%). These percentages describe image geometry, not measured physical distance. User explicitly requested this provisional tuning.
- `PositioningRules.swift`: select center tolerance by stage. Positioning priority, maximum size, complete-pose checks, fixed-anchor stability, two-second hold, 300 ms gap/freshness and filtering remain intact.
- `GuidanceRules.swift`: while a warning has a pending replacement candidate, project checking/unknown and positioning text instead of the old warning. Reducer history and persistence remain intact. Previously alternating replacement candidates could leave the old side displayed indefinitely even though current measurements contradicted it.
- Tests: profile values/version; stage-specific inclusive/just-outside boundaries; acquisition at smaller size; contradicted warning withdrawal; real Y-plane buffer sampling through analyzer, mirrored mapping, session reducer and presentation, covering right → left → even → dark → bright.
- Updated app/tracking/test AGENTS, specification D09/section 7/lighting persistence, plans 01/07, decisions and STATUS. Earlier handoffs intentionally retain their historical v1 evidence.

The pipeline test establishes both sides and exposure advice work for controlled buffers. The user's screenshot does not establish raw luma values or prove a detector/calibration bias. No lighting thresholds were blindly relaxed or side labels swapped. No participant image or identifying data was copied to the repository.

## Verification evidence

| Check | Exact command/tool | Environment | Result |
| --- | --- | --- | --- |
| Initial MCP attempt | XcodeSwitchRunDestination; BuildProject | Earlier turn | NOT EXECUTED: automatic approval review hit usage limit; resumed normally after user continuation |
| Build | Xcode MCP `BuildProject(buildForTesting: true)` | Xcode 27, iPhone 17 simulator iOS 27 | PASS |
| Focused | `GetTestList` then `RunSomeTests` for FrameAnalyzerTests, GuidanceRulesTests, PositioningRulesTests, TrackingConfigurationTests | Same | 28/28 PASS, no skips |
| Full unit/UI | Xcode MCP `RunAllTests` | Same | 92/92 PASS, 0 failed/skipped/not-run |
| Unsigned device | Command below, approved outside sandbox for Swift macro plugins | Generic iOS, existing deployment/signing configuration unchanged | PASS, exit 0 |
| Diff | `git diff --check` | Working tree | PASS |

Temporary focused result: `Test-facetracking-2026.09.22_12-36-09-+0530.xcresult`.
Temporary full result: `/var/folders/kv/hynb8lv50ml31bkt5_cdf_pm0000gn/T/ActionArtifacts/default/RunAllTests/Test-facetracking-2026.09.22_12-36-37-+0530.xcresult`.
Device build log: `/tmp/facetracking-tolerance-v2-device.log`. Existing warnings: semantic portrait API deprecations in iOS 17–26 compatibility branch; mailbox non-optional comparison. No build errors. Xcode destination restored to the previously selected physical iPhone.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project facetracking.xcodeproj -scheme facetracking -destination 'generic/platform=iOS' -derivedDataPath /tmp/facetracking-tolerance-v2-device CODE_SIGNING_ALLOWED=NO build
```

## Physical user acceptance and broader verification

User reported on 2026-09-22: “All looks good on Physical device now.” This accepts the reported repeated up-correction, farther-distance usability, and persistent right-side advice fixes in the tested flow. Exact device model, OS/build, lighting setup, and individual scenario results were not supplied and are not inferred. This scoped acceptance does not close the full R02/R04 device/calibration matrix. The following procedure remains available for detailed regression evidence:

1. Acquire once, then relax head position slightly downward and move moderately farther away. Expected: following remains active without repeated up/closer correction inside the new bounds. Large offsets still produce useful corrections.
2. Reenter capture farther from the camera, keeping the detected face at least half the guide dimensions. Expected: two-second acquisition remains possible with valid pose; insufficient luma samples may correctly produce checking instead of fabricated advice.
3. Hold still and place a diffuse light first on one side, then the other, then in front; keep each setup for at least two seconds. Expected: side advice reverses with sufficiently asymmetric measurements; balanced light becomes acceptable. When evidence changes, old side advice withdraws while settling. Darkness and overexposure produce their respective advice when thresholds are met.
4. Confirm face loss, screenshot/system interruption recovery and explicit Restart still behave as in the previous handoff.

If the same side remains under both physically reversed lighting setups, inspect current aggregate regional measurements and physical transform alignment under R02/R04. Synthetic tests do not prove that real Vision bounds/illumination are calibrated. R01–R07 remain OPEN.

## Next work

Code, automated verification, and user acceptance of the reported live-device issues are complete. Plan 09 remains the next numbered implementation plan. Wider bounds are provisional and must be included in later calibration, rather than reported as accepted R04 values.
