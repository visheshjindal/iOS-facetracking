# Plan 01 — Pure models, geometry and positioning

## Outcome and prerequisites

Implement the positioning half of M1. Read root/scoped guidance, README, handoff `00.md`, and source sections 3–4, 6–7 and P01–P09 in section 12. Confirm the configuration compiles and tests run. This plan needs no camera or human face fixture.

Likely files: `TrackingModels.swift`, `PreviewGeometry.swift`, `PositioningRules.swift`, related history/hint types in `facetracking/Tracking/`, and focused unit suites. Do not implement the full session reducer (plan 02) or change configuration thresholds.

## Work

1. Define owned `Sendable` value types for geometry, optional pose, face sample and frame observation, following section 4. Include session ID and geometry revision (`UInt64`), monotonic milliseconds (`Int64`) and `Double` calculations. Define the lighting metrics value contract now if required by `FrameObservation`; measurement/rules remain later work. A nil angle makes the complete required pose unknown; no default neutral pose.
2. Validate finite geometry, positive dimensions and viewport intersection. Preserve partially outside coordinates; never clamp into apparent alignment. Validate finite complete pose independently. A valid box with unknown pose can be drawn later but cannot acquire or qualify for lighting.
3. Implement one target function for positive viewport W/H: width points `min(0.72*W, 0.50*H/1.35)`, height 1.35 times width, center `(0.5,0.5)`, normalize each dimension separately. Non-positive/non-finite viewport produces no target.
4. Implement explicit positioning history and a pure update function taking history, target, face and timestamp. No clock reads or strings. EMA uses `1-exp(-deltaMS/150)` on each known scalar; reset on absence or gap greater than 300 ms. Unknown pose must not borrow previous angles.
5. Pose latch uses entry yaw/pitch/roll 10/15/8 degrees and exit 13/20/11, inclusive. Unknown clears it. Across a gap preserve the prior valid latch only if current complete pose remains in the exit band; hold/filter continuity still resets.
6. Apply exact hint order: no face/target; horizontal; vertical; too large; too small; pose; hold/follow. Per provisional v2 (user-requested 2026-09-22 correction), center tolerances are 0.15 times target dimensions while aligning and 0.25 while following; scales are 0.50–0.95 inclusive. Oversized wins over undersized when axes disagree. Movement directions refer to the mirrored viewport during both alignment and following (2026-09-22 usability correction).
7. Acquisition compares filtered state to the fixed hold-start anchor, not adjacent frames. Restart on any normalized center/size delta greater than 0.025 or angle delta greater than 5 degrees. Clear anchor/time for ineligible observations. A fresh eligible sample at elapsed >=2,000 ms acquires; a timer never acquires. Following computes corrections without starting another hold; loss preserves following and fresh return resumes it.

## Automated verification

Implement P01–P09 as named tests; preserve IDs in names or comments. Run focused positioning tests, all unit tests, and unsigned device build.

- P01: multiple portrait W/H values, exact point ratio 1.35, center and no target for invalid sizes.
- P02: continuous eligible observations at 0,250,…,1,750,1,999 remain aligning; at 2,000 acquire. Feed enough intermediate samples so no gap invalidates the test.
- P03/P04: every hint condition, each axis/angle, exact equality and just-outside boundaries; unknown/NaN pose never acquires. Set fixtures so EMA does not hide the boundary being tested.
- P05: many small steps cross the fixed anchor threshold and reset; equality retains hold.
- P06: gap 300 continues, 301 resets; absence clears filter/anchor. Test the special pose-latch behavior across a gap.
- P07: equivalent continuous trajectories at different cadences have comparable time-based responses; assert against independently calculated values/tolerances.
- P08/P09: all following corrections, loss/recovery, and unknown pose retain following while preventing lighting eligibility. Confirm raw geometry remains distinct from filtered guidance.

## Human verification

No human step is needed to validate the pure calculations. Physical threshold suitability, prompt direction and pose bias remain R01/R02/R03 for later plans. Record that synthetic P tests do not close those gates.

## Layered AGENTS.md work

Create/update `facetracking/Tracking/AGENTS.md`: normalized mirrored coordinates, units, pure function ownership, optional-value semantics, timing comparisons, fixed-anchor rule, and positioning test command. Update `facetrackingTests/AGENTS.md` with continuous timestamp fixture builders and boundary-testing conventions. Keep runtime histories out of documentation.

## Completion and next chat

Write `handoffs/01.md` under `docs/implementation/`, update STATUS, and document signatures/locations for models, configuration, target builder, history and positioning result. Plan 02 consumes these to own lifecycle and reject obsolete events before algorithm updates.
