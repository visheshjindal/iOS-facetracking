# Plan 10 — Device reliability, timebase and performance

## Outcome and prerequisites

Implement engineering acceptance work from M6. Read handoffs 03–09, source sections 5, 10, 12–14 and R01/R02/R03/R05/R06. Confirm complete unit/UI suites pass, or first identify the exact prerequisite defect. This plan makes measured fixes and durable evidence; it does not calibrate lighting thresholds or declare release acceptance.

## Work

1. Prepare `docs/implementation/evidence/R05-R06-performance.md` with exact build/device/OS/profile/request/format metadata, repeatable baseline/stress procedures and results tables initially NOT RUN. Use oldest supported and newer iPhone, minimum and current supported iOS where available. Record unavailable matrix cells.
2. Add minimal, consented aggregate signposts/counters around detection, sampling, mapping, delivery and display age. Separate delegate-arrival time from sample presentation time. No face coordinates, landmarks, frames or identifying data in routine logs; remove temporary detailed probes after diagnosis.
3. Investigate R05: prove relation of sample presentation timestamps to chosen monotonic clock, measure upstream delay under stress, inspect frame-drop reasons. Never subtract unrelated clocks. If required, implement documented Core Media timebase conversion with explicit discontinuity/reset behavior and synthetic tests. Freshness cannot be declared satisfied solely from delegate-arrival age.
4. Profile warm-up then ten-minute baseline and stressed sessions using Instruments. Measure p50/p95 stages, preview responsiveness, main-actor blocking, retained buffers, memory growth, energy and thermal pressure. Targets are p95 analysis <100 ms, responsive roughly 30 fps preview where supported, one in-flight frame, one pending observation, no monotonic buffer growth, and no overlapping generations.
5. Exercise 50 lifecycle/retry cycles with fake services and physical route/scene/interruption scenarios. Inspect deallocation of store, observers, mailbox drains and timers. Inject delayed detector/consumer and demonstrate stale payload withdrawal still works under load.
6. Fix demonstrated leaks/races/hot paths with bounded changes and regressions. Implement or validate pressure-driven cadence/resolution reduction while preserving freshness/continuity; a resolution/transform change must obey revision/reset rules. Do not extend 300 ms windows or hide overload by silently calling old frames fresh. Record tradeoffs and unresolved limitations.
7. Recheck privacy: no unauthorized camera work, audio/output additions, disk persistence, telemetry/network dependencies or sensitive diagnostics. Verify output format/sampler path avoids RGB conversions and remains bounded. Keep proposed targets distinct from measurements.

## Automated verification

- Rerun all P/S/G/L/U tests and generic unsigned device build; device test/build only with valid signing/destination.
- Add regression tests only for actual fixes; test 50 cycles active-generation count <=1, cleanup counters stable, delayed delivery/failures bounded and stale-event rejection intact.
- If timebase conversion is introduced, test conversions using known related clocks, discontinuities, impossible/future timestamps and restart reset. Document how future timestamps are rejected rather than granting unlimited freshness.
- If adaptive cadence/resolution changes, inject pressure state and assert bounded workload, transform revision changes/reset when applicable and unchanged 300 ms semantics. Preserve unknown when analysis cannot produce eligible data.
- Run Thread Sanitizer where supported and record exercised paths; supplement with device Instruments. Lack of sanitizer findings is not proof of all possible races.

## Human verification

**F13/F14/R05/R06, engineer with devices/Instruments:** run baseline/stress sessions; background, lock/unlock, Control Center, camera contention, Settings revoke/regrant and repeated Exit/reentry. Watch for stale green overlays, duplicate capture, responsiveness loss and hidden capture. Capture only aggregate metrics and non-sensitive Instruments evidence.

For each run record stage p50/p95, upstream/display-age method, memory trend after warm-up, maximum retained frames/pending observations, thermal state, format/cadence transitions and pass/fail versus targets. Without hardware/tools, deliver instrumentation/tests/procedures and leave R05/R06 OPEN. Do not manufacture performance figures.

## Layered AGENTS.md work

Update/create `Camera/AGENTS.md` with measured ownership/timing hazards and adaptive policy; `CaptureUI/AGENTS.md` with teardown findings; test guidance with regression commands; and `docs/implementation/AGENTS.md` with reproducible profiling records and privacy limits. Keep long metrics tables in evidence, not AGENTS.md.

## Completion and next chat

Save `docs/implementation/handoffs/10.md`, update STATUS/research and state which engineering gates are actually closed. Plan 11 can prepare calibration/review with unresolved hardware cells, but final acceptance must remain blocked until required evidence exists. Preserve lighting profile unless a separately justified change is documented.
