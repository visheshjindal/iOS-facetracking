# UI-test target guidance

- Use XCUITest and launch a fresh `XCUIApplication` per test with `-ui-testing`; do not rely on state from prior tests.
- Plan-00 and fake-driven UI tests must require no camera hardware or permission. Select controls by stable accessibility identifiers, not localized visible text.
- Keep simulator smoke coverage focused on launch, route entry, Exit, and deterministic fixture states. Physical camera acceptance belongs in recorded human/device evidence.
- Launch deterministic capture states with `-capture-fixture <fixture-id>` only in DEBUG. Fixture tests must not grant permission, construct live camera dependencies, wait for real detection, or select controls by localized text.
- Use `-capture-scenario <id>` for transitions driven by fake authorization/camera/observations and scripted monotonic time. Scenario IDs are `permission-not-determined`, `permission-denied`, `permission-restricted`, `camera-error`, `detector-error`, `interrupted`, `aligning-1999`, `acquired-2000`, `lost`, `recovered`, and `restarted`.
- Aggregate probes are `test.cameraStartCount`, `test.cameraStopCount`, `test.settingsOpenCount`, `test.showsMask`, `test.hasTrackedOval`, and `test.showsReturnGuide`. They may expose counts/booleans only—never frame, face, landmark, or identity data.
- Stable user selectors include `capture.permissionTitle`, `capture.permissionMessage`, `capture.statusMessage`, `capture.guidance`, `capture.lightingBadge`, `capture.returnGuide`, and the `capture.*` action IDs. Bounded waits are for UI delivery only; never sleep to advance business time.
- `-reduce-motion` disables fixture/scenario presentation animations. Use the system preferred-content-size launch argument for largest-text coverage and run `performAccessibilityAudit` where the pinned SDK supports it.
- Focused command: `xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingUITests test` with temporary DerivedData and result-bundle paths.
- `AGENTS.md` is excluded from synchronized-group target membership and test bundles.
