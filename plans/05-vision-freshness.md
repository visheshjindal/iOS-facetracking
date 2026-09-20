# Plan 05 — Vision, bounded delivery and freshness

## Outcome and prerequisites

Complete M3's live pipeline. Read handoffs 00–04, source sections 3–5, 6–7, 10, S02/S04–S06, G02 and R01/R02/R03/R05. Confirm mapper, ordered command runner, reducer and test clocks exist. Likely files: `FrameAnalyzer`, `VisionFaceDetector`, observation mailbox, `AnalysisWatchdog`, and store/service integration. Lighting remains unavailable until plans 06–07.

## Work

1. Verify available Vision request/revisions and optional yaw/pitch/roll on the pinned SDK/minimum OS. Begin with serially reused `VNDetectFaceRectanglesRequest`. Convert radians to degrees once; any missing required angle makes pose nil. If rectangles cannot reliably supply pose, investigate landmarks as R01 with documented cost/scope and explicit decision updates; never use zeros or require depth to make tests pass.
2. Attach synchronous detection to the serial video-output queue with `alwaysDiscardsLateVideoFrames = true`. Permit only one in-flight analysis. Capture monotonic delegate-arrival milliseconds immediately and store sample presentation time separately for aggregate latency diagnostics. Snapshot active generation and transform revision for that frame.
3. Select first usable geometry result; invalid earlier rectangles must not hide a later usable detection. Result order is not identity. Assemble small owned observations using plan 04. Successful no-face is normal; thrown Vision request is a typed detector failure on the reliable event path. Never retain buffers/Vision objects in observable state.
4. Add capacity-one newest-observation mailbox with an explicit scheduling/draining mechanism; avoid an unbounded Task per frame. Keep failure/auth/lifecycle/completion events on a separate ordered reliable channel. Check generation and age again at consumption. Stop invalidates before teardown; an in-progress synchronous call may finish, but must discard stale work and release references.
5. If analysis completes more than 300 ms after arrival, publish unavailable face/lighting rather than usable stale geometry. Repeat stale-payload withdrawal at mailbox consumption. Preserve increasing observation timestamps while distinguishing successful-result arrival for stall monitoring from face capture/arrival freshness.
6. Start watchdog when attempt starts; check every 250 ms using injected clock/scheduler. A successful face or no-face result refreshes stall timing. At elapsed >5,000 ms emit detector-unavailable failure and stop until retry. Independently expire face at age >300 ms, tagged with expected accepted sample time, so a stale expiration cannot erase newer geometry. Cancel timers/mailbox work on stop.
7. Record R01 request/revision/pose matrix, R03 selection behavior assumptions and R05 timing/timebase investigation. Add only a debug inspection overlay if necessary for R02; the final UI belongs to plan 08. No participant frames in evidence or logs.

## Automated verification

Run detector adapter tests with controlled results/errors, mailbox/clock tests, S02/S04–S06 and G02, then full unit suite and unsigned device build.

- Slow detector and slow consumer: maximum one in-flight analysis and one pending small observation; newest value replaces older pending values. Reliable failure survives observation floods.
- Missing angle yields nil pose; no-face succeeds; thrown request fails; first invalid result followed by usable result selects usable; no identity assumption.
- Delay at exactly 300 ms preserves eligibility, 301 withdraws payload at analysis and consumption. Observation wrong generation/revision or stopped attempt has no effect.
- Watchdog uses attempt start before first result; face absence still keeps it alive. At 5,000 ms no failure; first scheduled check beyond threshold fails (e.g. 5,250 with 250 ms ticks). Check face expiry at first tick beyond 300 ms and expected-time protection.
- Advance fake clock without observations: never acquire a hold or settle lighting. Stop/retry/interruption cancels old timers and late completion cannot mutate a new attempt.
- Verify buffer/reference release using controlled ownership probes where possible; no raw pixel/observation objects cross store boundary.

## Human verification

**R01/R02:** on minimum supported iOS and newer device, exercise neutral pose and each yaw/pitch/roll direction, center and edges. Record missing-angle frequency/bias/signs, request revision, overlay alignment and mirror behavior. Acquire only with complete valid pose. If no device is available, leave live acquisition acceptance blocked while synthetic work proceeds.

**R03/R05:** have people enter/cross/leave without recording imagery; document primary-face switches. Under load, inspect responsiveness and capture/analysis/delivery age. Do not subtract unrelated sample and monotonic clocks; record unresolved timebase relationship for plan 10.

Save procedures/results in research/evidence records. Physical pose reliability, crop correctness and end-to-end freshness are not proven by unit tests.

## Layered AGENTS.md work

Update/create `Camera/AGENTS.md` with request ownership/revision, bounded mailbox, buffer lifetime, event channels and timer clock definitions. Update `CaptureUI/AGENTS.md` with result-consumption guards and tests guidance with fake detector/clock/consumer controls. Record any narrow Swift concurrency wrapper and why it is safe.

## Completion and next chat

Write `docs/implementation/handoffs/05.md`, update STATUS and give plan 06 the exact same-frame sampling insertion point, pixel format negotiation, transform snapshot and ownership lifetime. State separately whether R01/R02 live gates passed. Do not implement lighting heuristics here.
