# Plan 00 — Project foundation and durable records

## Outcome and inputs

Implement M0 only: a buildable, camera-free landing/capture shell, test targets, versioned configuration, and reproducible toolchain records. Read root `AGENTS.md`, `plans/README.md`, and source specification sections 1–4, 7–9, 11 (M0), and 12–14. No prerequisite handoff exists.

The inspected starter has `facetracking.xcodeproj`, `facetracking/ContentView.swift`, and `facetracking/facetrackingApp.swift`. It currently declares iOS 27, Swift 5, default MainActor isolation, iPhone/iPad and landscape support, and one app target. Reinspect rather than assuming these settings remain unchanged. The source's `GuidedFaceTracking` names are illustrative; retain this project's names.

Tooling shortcut: follow the root `AGENTS.md` Xcode tooling section. On 2026-09-21, Xcode MCP was configured but not callable in the checking chat. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` successfully found Xcode 27.0 (27A266a) and `mcpbridge`; the default Command Line Tools path did not. Use the explicit override for CLI discovery/build/test commands instead of diagnosing that same default-path failure again. This is availability evidence, not approval of a deployment minimum or proof of any project build.

## Work

1. Discover Xcode, SDKs, Swift version, project targets/schemes and simulator destinations. Record actual values in `docs/implementation/toolchain.md`. Prefer the proposed iOS 17 minimum, Swift 6 language mode, iPhone-only portrait target on a supported stable SDK; record feasibility and any unresolved platform decision as D02/R07. Never invent an installed SDK, downgrade project format blindly, or replace the whole project.
2. Preserve bundle identifier/signing identity unless a demonstrated build requirement needs a documented change. Reconcile deployment settings across Debug/Release and tests. Explicitly address default actor isolation so future pure types and camera work do not accidentally inherit MainActor; record the chosen compiler configuration and implications.
3. Add `facetrackingTests` and `facetrackingUITests`, target dependencies, a shared `facetracking` scheme and test membership. Choose XCTest for deterministic unit tests and XCUITest for UI tests to keep one test vocabulary. Validate an actual discovered simulator can execute a small unit test and launch/navigation smoke test.
4. Establish folders corresponding to the source ownership map as code is introduced. Keep one `@main` entry point. Add a landing screen with a capture entry, a temporary capture placeholder and Exit returning to landing. No camera permission request or session creation yet.
5. Add String Catalog infrastructure and the exact `NSCameraUsageDescription` from section 5: “Camera access helps position and follow your face on this device.” Do not add microphone/photo permissions. Verify the generated app Info.plist, not just the project text.
6. Add `Tracking/TrackingConfiguration.swift` with version `ios-provisional-v1`. Transcribe and name all algorithm constants from sections 7 and 8: timing, EMA, geometry tolerances/scales, pose entry/exit, anchor limits, sampling dimensions/count minima, range normalization, histogram trims/cutoffs, exposure and imbalance entry/exit, and persistence. Include 300 ms freshness, 5,000 ms stall and 250 ms watchdog cadence. Keep display constants separately named; avoid unexplained literals and represent units explicitly.
7. Create `docs/implementation/decisions.md` with D01–D09, source decisions, actual implementation choices, reasons, evidence and open questions. Create `docs/implementation/research.md` with R01–R07, required evidence, owner role, status OPEN, and blocking acceptance. No physical discovery is implicitly closed by setup.

## Automated verification

- Run discovery and record the working command templates from `plans/README.md` with real destinations.
- Run initial unit and UI smoke tests: configuration identifies the provisional profile; launch starts at landing; entering and exiting the placeholder returns to landing. These must run, not merely compile.
- Build for a generic iOS device without signing and inspect produced Info.plist for camera usage text, portrait support and phone family. Confirm all targets use the chosen language/minimum settings, and test files/Markdown are not bundled into the app.
- Verify there is no AVFoundation session initialization or permission request in the shell. Record baseline failures rather than claiming the scaffold works if tooling is unavailable.

## Human verification

**D02/R07, product/device owner:** confirm supported iPhone list, minimum iOS, English baseline, bundle/signing ownership, and availability of oldest/newer test devices. Record unresolved choices; they need not block pure algorithm work.

**Shell smoke, human with simulator/device:** launch; enter capture; press Exit; repeat. Expect landing restored, no camera permission prompt or capture indicator, no process termination. Leave NOT RUN if launch cannot be observed.

## Layered AGENTS.md work

Create/update `facetracking/AGENTS.md` with target/folder ownership and actor-isolation configuration; `facetrackingTests/AGENTS.md` with XCTest, deterministic clocks and fixture conventions; `facetrackingUITests/AGENTS.md` with test launch isolation and no real camera requirement; and `docs/implementation/AGENTS.md` with evidence/status/decision formats. Exclude these from app/test resources where not needed. Keep root commands/map accurate without duplicating all child instructions.

## Completion and next chat

Save `docs/implementation/handoffs/00.md`, update STATUS, and list actual scheme, destinations, unit framework, profile type, folders and pending decisions. Plan 01 needs compiling configuration and runnable unit tests; pending physical-device acceptance may remain open. Do not implement positioning, camera services or live detection here.
