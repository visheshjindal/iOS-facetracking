# Plan 07 — Lighting hysteresis, persistence and guidance priority

## Outcome and prerequisites

Finish M4. Read handoffs 01–02 and 05–06, source sections 7–9 and L04–L10. Confirm validated metrics and observation timing are available. Files: `Tracking/LightingRules.swift`, `GuidanceRules.swift`, lighting history/assessment types and session integration. UI rendering is next; this plan exposes typed projections, not localized strings in reducers.

## Work

1. Define unknown, acceptable, too-dark, too-bright, uneven(side optional), and high-contrast assessments. Keep active assessment/side, pending candidate key/start, acceptable-evidence start and previous sample timestamp. Initialize unknown and clear on new attempt/freshness/loss/failure as specified.
2. Implement exposure bands: dark enters median <55 OR shadow >=0.25 and stays active under median <65 OR shadow >=0.20. Bright enters median >205 OR highlight >=0.20 and stays active under median >195 OR highlight >=0.15. Active high-contrast uses both exit bands. Exposure takes priority over imbalance; both exposure flags→high-contrast, otherwise remaining dark/bright.
3. Uneven entry needs difference >=28 AND darker/brighter ratio <=0.75; active uneven needs difference >20 AND ratio <0.82 on both axes. When brighter mean is zero use ratio 1. Any vertical imbalance (including both axes) has no side; horizontal-only uses the darker mirrored region. Physical instruction semantics remain subject to R02 validation.
4. Reject non-increasing timestamps before mutation. Invalid/missing eligible metrics immediately reset unknown. Gap >300 ms resets and discards that sample for classification; the next continuous valid sample starts settling. Do not reuse positioning's different gap behavior accidentally.
5. Candidates are keyed by assessment AND side. A candidate change restarts its timer; matching active state clears pending candidate. Commit warnings at elapsed >=400 ms and acceptable at >=700 ms. Preserve prior active assessment internally until commit. Per the 2026-09-22 correction, a retained warning with a pending replacement projects as checking/unknown so it cannot keep directing the user to an unsupported side. On acceptable commit, retain original candidate start and compact at >=1,500 ms from that start, based on fresh observations. Unknown immediately withdraws acceptable; an uncommitted warning does not replace active acceptable.
6. Combine after positioning update in the session reducer. Positioning other than hold/follow always wins primary banner; otherwise active warning replaces hold/follow. Bad/unknown light never changes the hold predicate. Badge exists only with fresh face and no blocking camera failure. Expand only when hold/follow and known warning or not-yet-compact acceptable; icon-only for corrections/unknown with full accessible label available later.

## Automated verification

Implement L04–L10 and rerun P/S plus full unit suite and unsigned device build. Use coherent synthetic metrics that meet count/fraction invariants, and continuous intermediate timestamps.

- L04: medians 54/55/64/65 and 195/196/205/206; fractions exactly at and immediately around each entry/exit threshold.
- L05: either difference or ratio alone cannot enter uneven; test strict exit equalities, both axes, zero denominator and no-side precedence.
- L06: active high-contrast retains both exit bands and recovers to remaining dark/bright before acceptable where appropriate.
- L07: candidate at 399/400 warning, 699/700 acceptable; alternating candidates never commit. Supply intermediate samples <=300 ms apart.
- L08: left/right and side/no-side changes require fresh 400 ms persistence; interrupt/change-back restarts or clears correctly.
- L09: gap 300 vs 301, invalid input, nil pose and stale/out-of-order timestamps. Out-of-order invalid metrics cannot erase a valid warning.
- L10: acceptable badge compacts at 1,500 from candidate start, not 2,200; no-clock-only settlement. Test every positioning priority against all lighting states, badge visibility and loss. Show a two-second hold completes despite continuous dark/unknown lighting.

## Human verification

**R02/R04:** physical left/right illumination must match intended helpful instruction; verify vertical and mixed exposure use soft-even advice. Slowly change illumination and observe warning settling/recovery; record oscillation/usability for calibration. If there is no UI yet, use injected/debug projections and repeat with final UI in plan 11. This step never closes calibration from a single trial.

## Layered AGENTS.md work

Update/create `Tracking/AGENTS.md` with active/candidate distinction, side keys, gap-discard rule, compact evidence origin and guidance priority. Update tests guidance with continuous boundary fixture construction. Note validated metric requirements and where configuration versions live; do not copy the entire threshold table into AGENTS.md.

## Completion and next chat

Write `docs/implementation/handoffs/07.md`, update STATUS and list projection APIs for banner, badge label/expansion, mask/return guide and raw oval. Plan 08 binds them to localized UI without a second source of decision logic.
