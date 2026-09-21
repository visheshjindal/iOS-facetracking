# Plan 07 lighting-guidance evidence

Recorded 2026-09-21. R02 and R04 remain OPEN. This record stores no participant image, face crop, landmark, or identifying data.

## Automated evidence

- L04–L10 use validated synthetic metrics in canonical 0–255 units and injected monotonic milliseconds.
- Exact exposure entry/exit boundaries, imbalance difference-plus-ratio rules, strict uneven exits, vertical/both-axis no-side behavior, high-contrast recovery, and zero denominators are covered.
- Persistence fixtures include continuous intermediate observations at gaps no greater than 300 ms. They cover warning 399/400 ms, acceptable 699/700 ms, side-key changes, gap 300/301 ms, invalid/nil-pose withdrawal, and out-of-order rejection.
- Typed guidance tests cover every positioning correction against every lighting state, badge visibility/expansion/compaction/loss, mask/return-guide/raw-oval projections, and acquisition under continuous dark lighting.
- The profile remains `ios-provisional-v1`; synthetic success does not validate its thresholds or directional advice on people or physical devices.

## Physical R02/R04 procedure — NOT RUN

Required: oldest supported iPhone and one newer supported iPhone, signed Debug build, Xcode debugger, diffuse light, and controllable light from screen-left, screen-right, above, and behind/front. Do not capture or retain participant imagery.

1. At the return from `LightingRules.update` in `SessionTransition.reduce`, inspect only aggregate `observation.lighting`, `state.lightingHistory`, `state.positioningHint`, and `GuidanceRules.project(session:)`. Record device model, iOS, build/commit, Vision revision 3, delivered pixel format/range, and profile `ios-provisional-v1`.
2. Hold an eligible neutral pose under diffuse frontal light. Expected: acceptable commits only after at least 700 ms of continuous fresh observations; its expanded badge projection becomes icon-only at 1,500 ms from the original candidate start.
3. Make the scene dark, bright, and high-contrast slowly. Expected: warnings commit only after at least 400 ms, recover through the exit bands without rapid oscillation, and never prevent the two-second positioning hold from completing.
4. Illuminate screen-left and screen-right separately. Expected: the horizontal-only uneven result identifies the darker mirrored viewport side and projects the corresponding `addLightLeft` or `addLightRight` advice. Confirm that following the instruction improves the measured imbalance. This directional meaning is not accepted until reviewed physically.
5. Illuminate above/below, then create mixed horizontal and vertical imbalance. Expected: vertical or mixed imbalance has no side and projects `useSoftEvenLight`.
6. Move out of valid positioning, hide the face, and restore it. Expected: positioning corrections replace lighting primary guidance, the badge becomes icon-only during corrections, face loss removes it, and lighting history restarts honestly rather than reusing old evidence.
7. Slowly vary illumination around each transition for at least 30 seconds. Record warning/recovery timestamps, visible or projected oscillations, missed/false warnings, whether advice was understandable and helpful, and any automatic-exposure or display-light confounder.

Actual result: **NOT RUN**. Plan 07 exposes typed projections but deliberately adds no visible rendering; repeat these scenarios against the localized UI in plan 11. Required evidence is an anonymous aggregate record for each device/environment plus reviewer sign-off. A single trial cannot close R02 or R04.
