# Plan 04 — Coordinate transforms and asymmetric proof

## Outcome and prerequisites

Implement the geometry portion of M3. Read handoffs 00–03 and source sections 4–6, R02, G01/G02 and section 10 layout pitfalls. Confirm stable preview geometry and ownership APIs exist. This plan produces transforms and proof fixtures; live Vision and production overlays come later.

Likely files: `Camera/FrameCoordinateMapper.swift`, frame-transform snapshot value types, `Tracking/PreviewGeometry.swift` only as necessary, geometry tests and synthetic resources. Keep formulas independently testable without a running camera.

## Work

1. Name every coordinate space: raw buffer pixels, oriented unmirrored image pixels, Vision lower-left normalized bounds, preview points and mirrored top-left normalized viewport. Define an immutable frame snapshot containing geometry revision, raw/oriented dimensions, orientation/rotation, clean aperture policy, viewport and mirroring. Distinguish a raw-sample mapping from an already-oriented Vision rectangle mapping.
2. For Vision bounds, convert `(x,y,w,h)` to oriented pixels using left `x*Iw`, top `(1-y-h)*Ih`, width `w*Iw`, height `h*Ih`. Aspect fill scale is `max(W/Iw,H/Ih)`; offsets center the crop. Mirror point X as `W-X`, map four corners and rebuild the bounding box. Mirrored left is W minus unmirrored right. Normalize X/width by W and Y/height by H.
3. Map raw luma cell centers through actual rotation, clean aperture/crop and the same mirror/viewport snapshot. Do not feed raw coordinates into the Vision-normalized path. Expose a reusable point transform to plan 06. Missing/non-finite/invalid transform yields unavailable geometry/lighting; do not synthesize an identity transform.
4. Reconcile actual data-output rotation and Vision orientation policy with plan 03. Never rotate buffers and instruct Vision to rotate them again. Check delivered format/clean aperture and preview conversion APIs with the installed SDK. Keep portrait interface orientation distinct from physical sample layout.
5. Update viewport/transform revisions only for meaningful changes; snapshot per frame so later layout cannot remap an older result. Stop/start/reset through existing reducer for real changes. Preserve off-viewport geometry when it intersects; reject completely outside boxes without clamping.
6. Create labeled asymmetric synthetic fixtures, including a non-square rectangle near one edge, distinct corner markers and unequal left/right luma. A small debug-only transform inspection view or test fixture renderer may be used for human checks; it must not become a production feature or record camera frames.

## Automated verification

Implement G01 and transform parts of G02, then run full unit suite and unsigned device build.

- Map all corners under each supported portrait-related orientation; test at least two unequal viewport aspect ratios, horizontal and vertical aspect-fill crops, non-square bounds and partly clipped faces.
- Use independently hand-calculated expected points/bounds. Test mirror exactly once, lower-left to top-left conversion, clean-aperture offsets and raw pixel centers. A centered symmetric fixture alone cannot pass this suite.
- Reject zero/non-finite dimensions and unsupported transform conditions explicitly.
- Assert the same frame snapshot maps face and luma consistently. Wrong revision is discarded through session integration; identical layout callbacks do not allocate new attempts.
- Verify target cutout dimensions remain from plan 01 and independent of badge/banner changes.

## Human verification

**R02, physical iPhone:** with debug inspection enabled, compare a clearly asymmetric scene at center and all viewport edges against the mirrored preview; repeat with supported portrait viewport layouts. Verify physical left/right against screen-left/right and note clean aperture or stabilization crop. When plan 05 adds live boxes, repeat using face boxes and close R02 only after both synthetic and physical proof.

Record transformation policy and observations in `docs/implementation/evidence/R02-coordinates.md`. If physical mapping is uncertain, keep R02 OPEN: plan 05/06 can exercise synthetic contracts, but do not accept live overlay or side advice.

## Layered AGENTS.md work

Update/create `Camera/AGENTS.md` with transform snapshot fields, all named spaces, rotation/mirror policy and point-vs-rectangle entry points. Update `Tracking/AGENTS.md` only for shared viewport contracts and `facetrackingTests/AGENTS.md` for asymmetric fixtures/provenance and focused G tests. Do not duplicate formulas across instruction files.

## Completion and next chat

Write `docs/implementation/handoffs/04.md`, update STATUS and identify mapper signatures, revisions, supported orientation/aperture cases and unverified hardware assumptions. Plan 05 consumes these for Vision; plan 06 consumes raw sample mapping. Do not claim a synthetic transform proves the preview's actual hardware configuration.
