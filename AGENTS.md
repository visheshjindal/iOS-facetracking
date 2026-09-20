# Guided Face Tracking — agent instructions

## Start here

- Implement only the plan requested by the user. Read `plans/README.md`, that plan, and its prerequisite handoffs in `docs/implementation/handoffs/` before editing.
- The behavioral source of truth is `ios-swift-implementation-plan.mdx`. Preserve its F/P/S/G/L/U requirement and test IDs and D/R decision and research IDs. Read the sections identified by the active plan; do not rely on previous chat context.
- Inspect current files and `git status --short`. Preserve unrelated and uncommitted user changes. Do not recreate the project, rename targets, change signing identities, or add dependencies without a concrete task need.
- Read applicable nested `AGENTS.md` files before changing files beneath them, even when the task starts at repository root. Do not assume descendant guidance was automatically loaded.
- If prerequisite code is missing or contradicts its handoff, identify the exact gap. Complete independent in-scope work, but do not silently implement several later plans or claim a blocked dependency works.

## Repository map

- `facetracking.xcodeproj`: existing Xcode project; retain its name.
- `facetracking/`: app source. Planned boundaries: `App`, `CaptureUI`, `Tracking`, `Camera`, `Resources`.
- `facetrackingTests/`, `facetrackingUITests/`: planned test targets, created in plan 00.
- `plans/`: ordered implementation instructions; `docs/implementation/`: durable decisions, verification, and handoffs.
- This map includes planned directories. Inspect the checkout before assuming they exist. Root guidance describes contracts, not proof that features are implemented.

## Architecture and invariants

- Pure `Tracking` value types own algorithms and transitions. No camera, Vision, SwiftUI, clocks, or localized strings inside reducers. Use explicit inputs and injected monotonic milliseconds.
- The `@MainActor @Observable` store publishes `private(set)` state and processes transitions synchronously. The route owns stable store lifetime using `@State`.
- One serial camera owner configures/starts/stops; a separate serial output queue analyzes one frame at a time. Never run blocking camera or Vision work on MainActor.
- Cross isolation boundaries with small owned `Sendable` values. Never publish framework buffers, observations, or borrowed pointers. Use a capacity-one observation mailbox and a separate reliable control-event path.
- Serialize stop/start commands. Invalidate generation before teardown. Reject old session IDs, geometry revisions, and non-increasing observation timestamps before mutating history.
- Geometry uses the mirrored viewport with a top-left origin. Share frame-specific transforms between face bounds and luma samples. Draw raw geometry; guidance alone uses the time-based filter.
- Acquire on a fresh eligible observation after 2,000 ms. Gaps greater than 300 ms reset continuity. Expire faces at age greater than 300 ms. A stall is greater than 5,000 ms. Timers cannot acquire a face.
- Unknown pose is never zero; unknown lighting is never acceptable. Lighting is advisory. Following survives face loss; only an explicit new attempt restores alignment.
- Process frames in memory only. No recording, image persistence, uploads, recognition, accounts, audio capture, or quality-certification claims. Diagnostics must not include participant images, face crops, landmarks, or identifying face data.

## Implementation loop

1. Confirm prerequisite interfaces, toolchain, and target membership. Use the smallest cohesive change and ordinary initializer injection.
2. Add deterministic behavioral tests with boundary values and independently specified expected results. Inject clocks and services; no real sleeps for hold/persistence tests.
3. Implement, run focused checks, fix failures, then run the plan's integration checks. Inspect the final diff for unrelated changes, privacy issues, lifecycle races, and stale docs.
4. Verify framework APIs against the pinned SDK and official Apple documentation when needed. Never invent APIs or globally disable concurrency checking to obtain a build. Document a narrowly justified interoperability wrapper with ownership and lifetime proof.
5. Record exact commands and outcomes. A skipped test, unavailable simulator, signing issue, or missing physical device is NOT a pass. Do not weaken a test or change thresholds to conceal a failure.

## Xcode tooling: use Xcode MCP first

Verified on 2026-09-21: the Xcode MCP server initialized successfully as `xcode-tools` against Xcode 27.0 (27A266a). Its user configuration is `[mcp_servers.xcode]` with `command = "xcrun"`, `args = ["mcpbridge"]`, and `env = { DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer" }`. Keep that per-server override because global `xcode-select` points to `/Library/Developer/CommandLineTools`, where `mcpbridge` is unavailable.

- For future Xcode commands, use exposed Xcode MCP tools first whenever they support the operation. Start with `XcodeListWorkspaces`, reuse returned identifiers only within the current session, and record actual MCP results as verification evidence; workspace identifiers are session-specific and must not be saved as durable configuration.
- Tool exposure does not prove that the current agent is approved for this project. If discovery reports that the agent is not approved, call `XcodeOpenWorkspace` once with the absolute path `/Users/nidhigupta/xcodeProjects/facetracking/facetracking.xcodeproj` to trigger Xcode's agent-and-folder approval, then retry the read-only discovery call. Do not create a new project or bypass the approval flow.
- Use CLI commands only when Xcode MCP is not exposed in the current chat, cannot perform the required operation, or a plan explicitly requires a reproducible shell command. Do not duplicate the same expensive build or test through both MCP and CLI without a concrete reason.
- For CLI fallback, prefix every Xcode command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; shell exports do not necessarily persist between tool calls. Do not change global `xcode-select`.
- If MCP tools unexpectedly disappear, inspect the effective MCP server status and startup logs once. Preserve the configured `DEVELOPER_DIR`, confirm Xcode Settings > Intelligence > Model Context Protocol allows external agents, then refresh the Codex client. Do not install another server or repeatedly rediscover the known Xcode path.
- Keep the installed Xcode version distinct from the toolchain/product choice recorded by plan 00. A connected MCP server is not itself proof that a build or test passed.

## Verification commands

Plan 00 records actual Xcode/Swift versions, shared scheme, destinations, and reproducible commands in `docs/implementation/toolchain.md`. Until then, discover rather than assume:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun swift --version
xcodebuild -list -project facetracking.xcodeproj
xcodebuild -project facetracking.xcodeproj -scheme facetracking -showdestinations
```

After confirming the scheme, run unit/UI tests against an actual discovered simulator ID and an unsigned generic device build. See `plans/README.md` for templates. Keep DerivedData and result bundles in a permitted temporary directory; do not commit them. Physical camera, pose, lighting, latency, thermal, and VoiceOver checks need separate evidence.

## Layered guidance and handoff

- Every plan creates or updates the scoped `AGENTS.md` files named in that plan. Add durable local ownership rules, public interfaces, units, focused test commands, fixture conventions, and real pitfalls discovered during implementation.
- Keep each scoped file concise (aim below 100 lines). Inherit root rules; do not copy the whole specification, logs, task history, or generic advice. Do not create one per Swift file or empty layer. Update existing guidance rather than accumulating contradictory instructions.
- Keep agent docs out of application resources/build phases, especially inside Xcode filesystem-synchronized groups. Verify target membership when adding them.
- Root contains global contracts; child instructions specialize their subtree and must remain consistent with product requirements. Resolve behavioral conflicts explicitly in the decision log and affected tests, not through a hidden child override.
- Save one report per plan using `docs/implementation/handoffs/TEMPLATE.md`; update `docs/implementation/STATUS.md`. Separate code completion, automated verification, and human acceptance.
- Human checks need setup, exact actions, expected results, evidence fields, and a named gate. Pending human work is an honest handoff, not a reason to invent evidence or abandon independent code work.
- Do not mark R01–R07 closed without their required evidence. Keep thresholds provisional until calibration is accepted. Finish with changed files, checks/results, pending human steps, and next-plan readiness.

## Guidance reference

Instruction layering follows [OpenAI's AGENTS.md documentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md). Repository-specific architecture, test gates, and handoff rules above come from this project's specification and implementation workflow.
