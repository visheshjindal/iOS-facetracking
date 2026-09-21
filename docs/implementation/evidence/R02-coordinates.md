# R02 coordinate evidence

- Research ID: R02
- Requirements/tests: G01, transform portion of G02
- Date: 2026-09-21
- Build identification: uncommitted plan-04 working tree based on `ecb4088`
- Xcode/Swift: Xcode 27.0 (27A266a), Swift 6.4
- Configuration profile: `ios-provisional-v1`

## Implemented synthetic policy

- Raw buffer samples use top-left pixel edge coordinates; luma uses cell centers `(column + 0.5, row + 0.5)`.
- Clean aperture is either the full delivered buffer or an explicit raw-pixel crop.
- Raw-to-oriented conversion supports 0°, 90°, 180°, and 270° clockwise quarter-turns.
- Vision rectangles are already oriented and use lower-left normalized coordinates. They never pass through the raw-sample entry point.
- Aspect fill uses the actual oriented image and viewport sizes, centered crop offsets, and one explicit preview mirror.
- Final face geometry is normalized separately by viewport width/height, retained when partly clipped, and rejected when completely outside.
- Plan-03 policy prefers physically rotated, unmirrored output buffers. Once a frame proves upright delivery, use rotation 0° with `bufferAlreadyOriented`; otherwise record the actual raw quarter-turn with `visionAppliesSnapshotRotation`. Never combine physical rotation with a second Vision rotation.
- Apple documents that `videoRotationAngle` physically rotates frames delivered by `AVCaptureVideoDataOutput`, and that `CMFormatDescription.cleanAperture(originIsAtTopLeft: true)` returns a top-left aperture. Preview-layer metadata conversion accounts for `videoGravity`, but its top-left metadata space is distinct from Vision's lower-left bounds, so the mapper keeps the Vision conversion explicit.

Synthetic fixtures label all corners, use non-square rectangles, horizontal and vertical aspect-fill crops, an offset clean aperture, raw cell centers, a partially clipped face, and unequal left/right luma. These fixtures contain no participant data.

## Physical iPhone preview procedure — PARTIAL PASS

- Required: signed debug build with plan-05 live box integration or a debug-only transform inspector; supported physical iPhone; geometry/camera reviewer.
- Device/model/OS: iPhone 17, iOS 27
- Vision request/revision: NOT APPLICABLE until plan 05
- Delivered dimensions/pixel format/range: NOT RECORDED
- Clean aperture/stabilization crop: NOT RECORDED
- Reviewer/date: user verification, 2026-09-21

1. Display an asymmetric scene with distinct labeled corners and visibly unequal physical left/right brightness; do not record or save frames.
2. In portrait, compare the mirrored preview with mapped corner/sample diagnostics at center and all viewport edges.
3. Repeat for every supported portrait viewport layout and after a meaningful layout revision.
4. Move a non-square object partly beyond each edge; verify intersecting geometry remains unclamped and fully outside geometry disappears.
5. Record delivered buffer dimensions, applied data-output rotation, clean aperture, stabilization/crop behavior, preview viewport, and whether one mirror maps physical movement to expected screen movement.
6. After plan 05 supplies face boxes, repeat center/edge checks with live boxes before considering R02 closure.

Expected: labeled corners, asymmetric rectangle, and left/right brightness map through one rotation/crop/mirror policy; old geometry revisions never remap through a new viewport.

Actual: PARTIAL PASS. On an iPhone 17 running iOS 27, the user reported that portrait orientation passed, mirrored left/right movement passed, edge cropping looked consistent, and reopening preserved orientation. No participant imagery was recorded. Delivered dimensions, clean aperture, stabilization crop, and mapped live face-box alignment were not observed.

Status: **OPEN**. The physical preview policy is supported by this device observation and synthetic tests permit plans 05/06 to consume the contract, but live mapped overlay, delivered-format/clean-aperture measurements, and regional-lighting sign-off remain pending.
