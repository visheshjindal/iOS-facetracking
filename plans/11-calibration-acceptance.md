# Plan 11 — Lighting calibration and final acceptance

## Outcome and prerequisites

Complete M6 acceptance work without overstating evidence. Read every prerequisite handoff, source sections 1–2, 8–14, `decisions.md`, `research.md`, STATUS and evidence records. All implemented P/S/G/L/U tests should pass before evaluating a release candidate. This plan may end with a fully implemented app and explicit pending human release gates; never equate that with release-ready.

## Work

1. Create `docs/implementation/evidence/R04-calibration.md` and `docs/implementation/acceptance.md`. Before held-out evaluation, obtain/record R07 reviewer choices for supported devices/OS, multiple-face expectations, English/translations, navigation/privacy declarations and quantitative false-warning/missed-warning tolerances. If tolerances or participant access are missing, prepare the protocol and mark evaluation blocked; do not invent product approval.
2. Specify development and held-out participant/device cohorts separately. Cover oldest/newer iPhones, varied skin tones, facial hair, glasses and supported face sizes. Include diffuse frontal, dim, direct bright, backlight, screen-left/right, overhead/under-light, mixed shadow/bright and exposure transitions. Track automatic exposure, output range, screen brightness and white-mask lighting as confounders. Use consented aggregate records; no routine participant images or identifying data.
3. Measure false warnings, missed warnings, advice usefulness, settling time and oscillation against predefined labels/tolerances. Explain limitations of face-box histograms (no skin segmentation, potential symmetric/small-patch misses). A human reviewer supplies labels/usability judgments; a coding agent can calculate metrics from non-identifying collected data.
4. Tune only on the development set if evidence justifies it. Version any normalization/threshold/profile change; update source specification, decisions, configuration and affected boundary tests together. Preserve hold/freshness/priority contracts. Evaluate the frozen profile on held-out data without retuning to that set; failure remains a failure requiring another documented cycle.
5. Run the entire section 13 device matrix: permission cold start; initial center/distance/pose; tracking directions/edges; loss/return/Restart; physical mirroring and lighting side; interruptions; Settings revoke/regrant; lighting; people entering/crossing/leaving; ten-minute/load performance; accessibility. Incorporate existing valid evidence by build/profile and rerun cases invalidated by changes.
6. Review every F01–F16, D01–D09, R01–R07 and test ID against linked evidence. Build an acceptance table with implemented, automated, human and unresolved columns. Record product/release reviewer decision separately from engineering checks. No recognition/liveness/medical/quality-certification claim, network service or frame persistence may appear.
7. Make only evidence-driven focused fixes, then rerun affected tests and full unit/UI/device build checks. If a fix alters geometry/timebase or lighting profile, rerun dependent physical checks too. End with an explicit accepted/not-accepted release assessment and concrete remaining tasks. Do not archive, publish, submit to App Store or upload data as part of this plan.

## Automated verification

- Run full unit and UI suites on pinned toolchain and actual simulator; unsigned generic device build; signed device tests when available. Preserve exact command/result records and test IDs. Inspect release configuration for test hooks and accidental documentation/test resource packaging.
- For every changed threshold, maintain entry/exit equality tests and L04–L10 persistence coverage. Retain P02/P06/S06 timing and L10 advisory-lighting regressions.
- Validate any aggregate calibration calculations with small synthetic labeled examples; reports must include denominator, scenario/device coverage and missing observations. Do not count unknown lighting as acceptable by default.
- Audit file/code changes for forbidden capture outputs, persistence/network paths, sensitive logging and unsupported claims. Source inspection complements, rather than replaces, device/privacy review.

## Human verification and release gates

**R04, calibration engineer/reviewer:** execute the protocol and review held-out results versus previously chosen tolerances. Record profile, cohorts in non-identifying terms, device/OS coverage and actual pass/fail. No data means NOT RUN, never “calibrated.”

**R07, product/release reviewer:** sign off supported platform/list, two-second decision, multiple-face behavior, navigation, localization coverage, accessibility findings, lighting limitations and data-handling declarations. Review R01/R02/R03/R05/R06 evidence and unresolved matrix cells. An agent does not sign for a human or silently approve missing tolerances.

**Final device matrix, human tester:** follow section 13 procedures and each earlier handoff's unresolved check. Record observed result, build/profile, tester role and limitations. Missing mandatory evidence keeps acceptance OPEN even if all synthetic tests pass.

## Layered AGENTS.md work

Update/create `docs/implementation/AGENTS.md` with calibration versioning, frozen held-out evaluation and acceptance evidence locations. Update `Tracking/AGENTS.md` for any accepted profile changes and `Camera`/`CaptureUI`/`Resources` guidance only where verified contracts changed. Ensure every layer describes current implementation and focused checks; remove obsolete temporary assumptions, preserving unresolved limitations in research records.

## Completion and final handoff

Write `docs/implementation/handoffs/11.md`, update STATUS/decisions/research and link acceptance report. Report separately: code complete or gaps; automated results; human results; unresolved gates; and release assessment. If mandatory human checks remain, provide a prioritized exact checklist with prerequisites and expected evidence. The app is fully accepted only when the source section 14 definition is evidenced.
