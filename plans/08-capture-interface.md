# Plan 08 — Complete capture interface and localized states

## Outcome and prerequisites

Implement the visual portion of M5. Read handoffs 03–07, source sections 2–4, 6 (visual contract), 7–9, and U01–U04/U06. Confirm typed state projections, real pipeline and stable route/preview exist. Files: `CaptureScreen`, `CaptureViewState`, `PositioningMask`, `FaceReturnGuide`, `TrackedFaceOverlay`, `LightingBadge`, `GuidanceText`, route actions and `Resources/Localizable.xcstrings`.

## Work

1. Render immutable projections from authoritative session state. Keep one stable preview host and store; no camera/session creation from view body or overlay callbacks. Use actual preview container W/H after safe-area layout; overlay banner/badge without resizing the viewport. Keep transforms identical to measurement.
2. Initial mask is an opaque white rectangle with a centered transparent oval cutout using an even-odd path. Use the shared target formula; do not darken the hole or substitute a face image. Following begins immediately on acquisition and fades mask opacity 1→0 over 450 ms. Respect Reduce Motion without changing state timing.
3. Following draws raw fresh geometry as green #00FF87, 5-point oval stroke. Always retain fixed centered white return guide at opacity 0.82, 3-point stroke, even when a face exists. On loss remove green outline and badge, retain return guide and loss message. Unknown pose with valid fresh geometry can still draw following outline.
4. Add decorative target eye details exactly: centers x ±0.18 oval widths, y minus 0.11 oval heights; ellipses 0.13 widths ×0.035 heights, 2-point strokes and 2-point center dots. They are guide illustration, not landmarks, and do not rotate with face.
5. Banner uses 24-point padding, wrapping, white background/black text in alignment and black at 0.70/white text in following. Lighting badge is top trailing with 16-point margin, 8-point gap under banner, minimum 40-point visual height, 22-point icon. Unknown black 0.68/white; acceptable #128A52/white; warning #FFB020/black. Consume plan 07 expansion/priority without recalculating lighting in views.
6. Wire Grant, Settings, Exit, Try again and loss-only Restart to existing actions/events. Restart makes a fresh alignment attempt; ordinary face return resumes following. Permission/error/interruption views use typed failures and exact source English copy. No results/completion screen, recording, progress countdown or identity claims.
7. Populate every stable String Catalog key from section 9, including full compact-badge accessibility labels. Implement basic Dynamic Type/44×44 action targets and accessibility-hidden decorations now; comprehensive verification is plan 09.
8. Add deterministic dependency-injected preview fixtures for permission states, no face, corrections, hold, following, loss, each lighting assessment/side, interruption and errors. Test/preview dependencies must avoid camera construction and never alter release behavior via an unguarded launch argument.

## Automated verification

- Unit-test view projections for U01–U04: actions/copy keys for each permission/failure, mask only before acquisition, fresh green oval only following, return guide throughout following and loss, correct badge state for every assessment.
- Use shared geometry fixtures to check target/return guide equality and raw-vs-filtered outline. Verify text/badge changes do not mutate viewport revision.
- Add focused UI checks using fake observations where the launch harness exists; plan 09 completes the full suite. Assert at 1,999 ms mask remains and an eligible 2,000 ms sample transitions; no waiting on real detector or two-second sleeps.
- Run full unit suite, existing UI suite and unsigned device build. Inspect resulting app resources for absent AGENTS.md/test fixtures not intended for production.

## Human verification

**F03/F06/U02–U04, simulator fixture and real iPhone:** inspect each deterministic state; check transparent cutout, exact target placement, white return guide during visible face and loss, mask fade/Reduce Motion, wrapping and badge placement. Return face without pressing Restart: expect following immediately; press Restart during loss: expect full fresh hold.

At viewport edges verify real green oval remains aligned; this final presentation check complements R02. Use synthetic screenshots for review if useful; do not save participant frames. Missing real-device proof remains pending, not replaced by attractive previews.

## Layered AGENTS.md work

Update/create `CaptureUI/AGENTS.md` with projection ownership, stable viewport/preview, visual geometry and fixture entry points. Create/update `Resources/AGENTS.md` with stable localization keys, baseline copy source, asset scope and no participant imagery. Update test guidance with fixture injection and release isolation checks.

## Completion and next chat

Save `docs/implementation/handoffs/08.md`, update STATUS and list available fixture IDs, action identifiers and localization keys. Plan 09 extends accessibility/testing rather than redesigning business rules. Keep R01/R02/R04 sign-off distinct from UI implementation.
