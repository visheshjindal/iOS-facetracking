# Plan 02 — Deterministic session state and effects

## Outcome and prerequisites

Finish M1 with a pure state machine. Read handoffs 00–01 and source sections 3–4, 5 (watchdog contract), 7, 12 (S01–S06). Confirm P01–P09 pass. Likely files: `Tracking/SessionState.swift`, `SessionTransition.swift`, event/effect/failure types, and session tests. No real camera or asynchronous runner belongs here.

## Work

1. Model authorization, route/scene eligibility, viewport and revision, active/desired running state, camera status, session generation, aligning/following stage, raw face, accepted timestamp, histories and typed failure. Derive loss from following plus absence. Define future lighting history storage as necessary, retaining unknown until plan 07; do not implement its classifier here.
2. Define synchronous transition `(state,event) -> state/effects` with explicit time inputs. Events cover authorization, scene/route lifecycle, viewport, retry/restart, observations, freshness, camera completion/error/interruption and Exit. Effects request ordered start/stop and watchdog setup/cancellation/dismissal. No framework objects, Tasks or clock access in reducer.
3. Start exactly once only when authorized, active, route present and positive viewport with no blocking failure. Allocate an increasing checked ID; handle overflow as an explicit terminal/recoverable policy without wrapping into an old ID. Duplicate lifecycle/layout events produce no start. Document a reasonable meaningful-viewport comparison policy so subpixel jitter does not cause loops; do not quantize real transform changes away.
4. Stop/invalidate before teardown on inactivity, Exit, access loss, failure or interruption. Clear face/histories/timers and ignore obsolete completions. Retry, explicit loss Restart and real geometry changes reset alignment and issue stop before new start. Increment checked geometry revision for real viewport/transform changes.
5. Reject wrong session/revision, stopped attempts and equal/decreasing timestamps before any positioning or lighting mutation. Accept current observations and feed plan 01 rules. Following loss/recovery never creates a new hold. Unknown pose retains raw usable outline but stays ineligible.
6. Model freshness with expected last-sample timestamp so an old timer cannot clear a newer face. Expire at age >300 ms, clear continuity/lighting, retain acquired stage. Model stall at >5,000 ms after attempt start/last successful analysis result; no-face results count as successful analysis. Timer scheduling/physical delivery is implemented in plan 05.
7. Distinguish interruption from authorization denial and detector failure. Interruption end while still eligible allocates a fresh attempt; otherwise no restart. A current failure stops and requires retry. Failures cannot be overwritten by a late observation.

## Automated verification

Run S01–S05 and reducer portions of S06, all positioning tests, full unit suite, unsigned device build.

- S01: all eligibility combinations and duplicated events; exactly one requested start.
- S02: wrong IDs/revisions and non-increasing timestamps leave the entire state/effects unchanged, including histories.
- S03: retry, Restart on loss and real geometry changes produce ordered stop/start, increasing IDs and empty histories; repeated stable/subpixel layout does not restart.
- S04: stop and each failure clear face/badge inputs/history; an observation after failure cannot restore them.
- S05: permute late start/stop/error/observation events after stop, retry, permission loss and interruption. Old stop completion cannot stop the new logical attempt.
- S06: at age 300 retain; at 301 expire; expected-timestamp mismatch ignores freshness. At elapsed 5,000 do not fail, at the first check beyond it fail. Valid nil-face results reset stall timing.
- Add checked-overflow and repeated scene/lifecycle tests. Use recorded effects to prove order, not inferred final state alone.

## Human verification

None required for reducer acceptance. Actual command serialization, Settings lifecycle, camera interruptions and timer delivery await plans 03/05. Keep F13/F14 physically unverified.

## Layered AGENTS.md work

Update/create `Tracking/AGENTS.md` with event/effect API locations, state authority, generation invalidation and timestamp rejection ordering. Update test guidance with fake transition/effect recording and race permutation fixtures. Preserve plan 01 numeric conventions.

## Completion and next chat

Save `docs/implementation/handoffs/02.md`, update STATUS, and give plan 03 the reducer entry point, event/effect enums, allocation/viewport policy and ordered command expectations. Complete pure behavior only; do not invent placeholder camera success paths in production.
