# UI-test target guidance

- Use XCUITest and launch a fresh `XCUIApplication` per test with `-ui-testing`; do not rely on state from prior tests.
- Plan-00 and fake-driven UI tests must require no camera hardware or permission. Select controls by stable accessibility identifiers, not localized visible text.
- Keep simulator smoke coverage focused on launch, route entry, Exit, and deterministic fixture states. Physical camera acceptance belongs in recorded human/device evidence.
- Focused command: `xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingUITests test` with temporary DerivedData and result-bundle paths.
- `AGENTS.md` is excluded from synchronized-group target membership and test bundles.
