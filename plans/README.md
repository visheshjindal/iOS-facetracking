# Implement one plan per Luna chat

These plans decompose [the source specification](../ios-swift-implementation-plan.mdx) into twelve bounded changes. They target Codex using the user-selected Luna model; select Luna when opening each new chat. The plans do not change model settings or require previous conversation history.

Keep this repository available in every chat. Give the agent one numbered plan, not the whole sequence as an implementation request. Each plan specifies which source sections to read, prerequisite code, tests, manual checks, and scoped agent guidance. The source specification remains authoritative for exact requirements and copy.

The [coverage map](coverage.md) maps every feature, automated test group, decision and research gate to its implementation and verification plans.

## Start a chat

Use this prompt, replacing the filename:

```text
Implement plans/00-project-foundation.md in this repository.
Read AGENTS.md, plans/README.md, the selected plan, its source-specification
sections, and prerequisite handoffs. Inspect actual code before editing.
Implement only this plan and its required layered AGENTS.md updates.
Run the specified automated checks where available. Record exact results;
leave unavailable device/human checks as NOT RUN with reproducible steps.
Write the plan handoff and update docs/implementation/STATUS.md.
Do not implement the next plan or claim pending research gates are closed.
```

For a partially completed plan, use the same prompt and add: “Resume from current files and the handoff; preserve completed work.” For human results, give the next chat the evidence record or add it to the repository first.

## Sequence and dependency map

Run 00 through 11 in order. The dependency column identifies the actual code prerequisites; all preceding handoffs should still be reviewed for relevant decisions and unresolved gates.

| Plan | Outcome | Code prerequisites | Source milestone |
| --- | --- | --- | --- |
| [00 — Project foundation](00-project-foundation.md) | Pinned project, targets, configuration, records | Existing starter project | M0 |
| [01 — Models and positioning](01-models-positioning.md) | Pure geometry, pose, filter, two-second hold | 00 | M1, positioning |
| [02 — Session state machine](02-session-state.md) | Deterministic lifecycle, events, effects, stale rejection | 01 | M1, transitions |
| [03 — Camera and preview](03-camera-preview.md) | Permission, ordered camera ownership, stable preview/store | 02 | M2 |
| [04 — Coordinate mapping](04-coordinate-mapping.md) | Frame transform snapshots and asymmetric fixtures | 03 | M3, geometry |
| [05 — Vision and freshness](05-vision-freshness.md) | Serial analysis, bounded delivery, watchdog | 04 | M3, pipeline |
| [06 — Lighting measurements](06-lighting-measurement.md) | Sparse Y sampling and validated metrics | 05 | M4, measurement |
| [07 — Lighting guidance](07-lighting-guidance.md) | Classifier, persistence, badge/banner projections | 06 | M4, rules |
| [08 — Capture interface](08-capture-interface.md) | Complete visual states and native actions | 07 | M5, UI |
| [09 — Accessibility and UI tests](09-accessibility-ui-tests.md) | Accessible, localized flow and deterministic UI regression suite | 08 | M5, acceptance |
| [10 — Reliability and performance](10-reliability-performance.md) | Device lifecycle, latency, memory, thermal evidence and fixes | 09 | M6, engineering |
| [11 — Calibration and acceptance](11-calibration-acceptance.md) | Calibration, product decisions, full acceptance report | 10 | M6, release gates |

## Completion and gates

Track **code**, **automated verification**, and **human acceptance** separately in [STATUS](../docs/implementation/STATUS.md). Initially nothing is implemented or verified by these planning documents. A plan is implementation-ready when its required interfaces exist and prerequisite automated checks pass; a prose handoff alone is not proof.

- Missing prerequisites: describe the smallest missing contract; finish independent in-scope work and record a blocker for dependent work.
- Missing hardware or reviewer: finish fake-driven code and tests where possible, write exact human steps, and keep the physical gate open. Do not label the plan fully accepted.
- R01 pose availability and R02 physical transforms gate live acquisition/overlay sign-off. Code using explicit unknown values and synthetic transforms can proceed; do not assert live correctness until evidence exists.
- R03 multiple people, R04 calibration, R05 latency, R06 performance, and R07 product/release decisions gate final acceptance. Discovery failures may require explicit source/configuration/test updates before dependent behavior can be accepted.
- A failed deterministic test for a prerequisite blocks dependent integration until fixed. Pending unrelated human evidence does not block pure code development.

Every plan saves `docs/implementation/handoffs/NN.md` from [the template](../docs/implementation/handoffs/TEMPLATE.md). Reports include exact changed interfaces, executed commands, failures, pending manual procedures, research status, and next-plan readiness. Reports are the durable bridge between chats.

## Commands used by the plans

Plan 00 discovers the installed toolchain and creates a shared scheme, then writes exact working commands to `docs/implementation/toolchain.md`. Keep project/target names `facetracking`, `facetrackingTests`, and `facetrackingUITests` unless inspection establishes an intentional existing change. These are templates, not evidence of execution:

Read the root `AGENTS.md` Xcode tooling note first: Xcode MCP is configured but was not exposed in the checked chat. The verified CLI fallback is the explicit developer directory below; the system default points to Command Line Tools. Use available, working MCP tools where appropriate; otherwise go straight to this fallback rather than rediscovering the setup. Apply the export in each new shell invocation.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun swift --version
xcodebuild -list -project facetracking.xcodeproj
xcodebuild -project facetracking.xcodeproj -scheme facetracking -showdestinations
xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingTests test
xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS Simulator,id=<DISCOVERED_UDID>' -only-testing:facetrackingUITests test
xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project facetracking.xcodeproj -scheme facetracking -destination 'platform=iOS,id=<SIGNED_DEVICE_UDID>' test
```

Replace placeholders using actual destinations; never execute them literally. Add a unique temporary `-derivedDataPath` and, for test evidence, `-resultBundlePath` when useful. Device tests require signing. Use focused `-only-testing:Target/TestSuite` checks during implementation; run the whole unit suite and unsigned device build before handoff for code plans, plus the UI suite once introduced. Plan 00 runs its starter tests. Record unavailable checks rather than repeatedly retrying an unavailable destination.

## Layered AGENTS.md convention

The existing [root AGENTS.md](../AGENTS.md) holds global contracts. Each plan must create the named scoped layer if absent or update it if present. Create layers with the corresponding implementation, not empty speculative files now. Use actual file/interface names discovered during the work.

A useful child file contains: directory purpose and exclusions; local input/output units and ownership; key invariants; focused test command/test names; fixture conventions; and specific SDK/lifetime pitfalls. Keep it short and avoid copying root rules. Exclude it from app resources, including synchronized Xcode groups. Preserve layer guidance when refactoring directories. Store completion history in handoffs, not instruction files.

| First introduced | Scoped guidance |
| --- | --- |
| 00 | `facetracking/AGENTS.md`, `facetrackingTests/AGENTS.md`, `facetrackingUITests/AGENTS.md`, `docs/implementation/AGENTS.md` |
| 01 | `facetracking/Tracking/AGENTS.md` |
| 03 | `facetracking/Camera/AGENTS.md`, `facetracking/CaptureUI/AGENTS.md`, `facetracking/App/AGENTS.md` |
| 08 | `facetracking/Resources/AGENTS.md` |

Later plans update relevant existing layers. They should not manufacture deeper directories solely to add another AGENTS.md.

This structure uses [OpenAI's documented instruction layering](https://learn.chatgpt.com/docs/agent-configuration/agents-md); the bounded tasks, repository handoffs, and verification gates are tailored to this app.
