# Plan 05 Vision research evidence

Recorded 2026-09-21. No participant image, face crop, landmark, or identifying data is stored here.

## R01 request/revision/pose matrix

| Environment | Request | Revision | Pose API | Result |
| --- | --- | --- | --- | --- |
| Xcode 27.0 / iOS 27 SDK headers | `VNDetectFaceRectanglesRequest` | 3 | Optional `yaw`, `pitch`, `roll` radians on `VNFaceObservation` | Confirmed by SDK headers and compiled app/device build |
| Project minimum iOS 17 | Same | Revision 3 is available from iOS 15 | Missing any required angle maps to nil pose; no zero substitution | Synthetic adapter tests PASS |
| Physical minimum/newer devices | Same | 3 | Availability frequency, bias, direction signs | NOT RUN — R01 remains OPEN |

Revision 3 was selected because its SDK contract reports pitch in addition to yaw and roll. One request instance is serially reused. A complete triple is converted once from radians to degrees; otherwise pose is unavailable.

## R03 selection assumption

The baseline selector walks the current Vision result array and returns the first rectangle that maps to usable viewport geometry. Invalid earlier results do not mask later valid results. Result order is not treated as identity, so switches are expected when people enter, cross, or leave. Physical behavior and product acceptance are NOT RUN; R03 remains OPEN.

## R05 clocks and timing

- `capturedAtMS`: `DispatchTime` uptime milliseconds sampled immediately at delegate analysis entry; drives observation ordering and 300 ms face freshness.
- `resultAtMS`: the same monotonic clock sampled after successful Vision completion; drives the 5,000 ms analysis-stall baseline.
- sample presentation timestamp: retained as Core Media seconds only in aggregate analyzer diagnostics. It is not subtracted from uptime because their relationship/discontinuities are unproven.
- strict boundaries: payload remains eligible at exactly 300 ms and is withdrawn at 301 ms; watchdog remains healthy at exactly 5,000 ms and fails on the first 250 ms tick beyond it.

Physical p50/p95 capture-to-analysis-to-display latency, thermal/load behavior, drop reasons, and restart discontinuities are NOT RUN; R05 remains OPEN.

## Reproducible physical procedures (NOT RUN)

### R01/R02 pose and geometry

1. Install the plan 05 build on the oldest supported iPhone/iOS and one newer device; record model, OS, build commit, Vision revision 3, pixel format, and viewport.
2. In portrait, present one face neutrally at center, then near each edge; slowly exercise positive and negative yaw, pitch, and roll separately.
3. Record counts only: frames with complete pose versus nil pose, neutral bias, observed sign for each direction, acquisition behavior, overlay/crop/mirror alignment. Do not capture participant imagery.
4. Expected: pose is unavailable whenever any angle is missing; acquisition never treats unknown as zero; mirrored movement and edge geometry remain aligned.

### R03/R05 selection and load

1. Have two people enter, cross, separate, and leave the view in a scripted order without recording imagery.
2. Record timestamps and anonymous labels A/B for observed primary-face switches; compare to first-usable-result behavior without claiming identity.
3. Under CPU/thermal load, record aggregate arrival-to-result and result-to-display ages, frame/drop counts, p50/p95, interruptions, and restarts.
4. Expected: UI stays responsive, at most one analysis plus one pending observation exists, detector failure remains reliable, and stale geometry disappears after the strict 300 ms threshold.
