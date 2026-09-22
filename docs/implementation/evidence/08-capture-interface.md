# Plan 08 capture-interface evidence

Recorded 2026-09-22. F03/F06/U02–U04 and the presentation portion of R02 remain pending human/device review. No participant imagery is stored.

## Deterministic fixture catalog

The DEBUG-only launch form is `-capture-fixture <fixture-id>`. It bypasses `CaptureDependencies.live()` and therefore constructs no authorization or camera service. Available IDs:

- Permission and failures: `permission-not-determined`, `permission-denied`, `permission-restricted`, `interrupted`, `camera-error`, `detector-error`.
- Alignment/following: `no-face`, `center`, `closer`, `farther`, `look-straight`, `hold`, `following`, `loss`.
- Lighting: `lighting-unknown`, `lighting-acceptable`, `lighting-dark`, `lighting-bright`, `lighting-left`, `lighting-right`, `lighting-uneven`, `lighting-high-contrast`.

Automated simulator coverage launches `loss` and `lighting-left`. Unit coverage constructs all 22 fixtures, checks U01–U04 projections, proves that `PreviewView.bounds`—not overlay layout—is the viewport authority, and drives acquisition with injected observations through 1,999/2,000 ms without sleeping.

## Simulator and physical-device visual procedure — NOT RUN

Required: iPhone 17-class simulator plus one signed supported physical iPhone, portrait orientation, normal and largest supported Dynamic Type sizes, Reduce Motion both off/on, and a reviewer. For live checks, use a consenting participant but save only written observations or synthetic fixture screenshots—never participant frames.

1. Launch every fixture ID above. Confirm exact English copy, wrapped banner text, Exit in every state, Grant only before determination, Settings only when denied, Try again only for retryable failures, and Restart only in `loss`.
2. In alignment fixtures, confirm an opaque white exterior with a genuinely transparent centered oval. Measure that the oval uses the shared 1.35 height/width target and that its eye centers, ellipse dimensions, strokes, and center dots match the section-6 specification.
3. Compare `following` and `loss`: the centered white return guide must remain at 0.82 opacity in both; the 5-point `#00FF87` raw-face oval appears only with a fresh following face; the badge disappears on loss.
4. Acquire on a signed physical device. Expected: session changes to following immediately and the white mask fades from opacity 1 to 0 over 450 ms. With Reduce Motion enabled it disappears without a nonessential transition, while the two-second state timing is unchanged.
5. During loss, return the face without pressing Restart. Expected: following and the green raw oval resume without another hold. Lose the face again, press Restart, and verify the initial mask and full fresh two-second hold return.
6. Review every lighting fixture: unknown black/white, acceptable `#128A52`/white, warnings `#FFB020`/black; 22-point icon, at least 40-point height, compact/expanded behavior, correct left/right/soft/more/reduce copy, and full VoiceOver label even when compact.
7. At large text sizes verify banners and badges wrap/reposition without resizing the preview viewport, moving the target/return guide, obscuring primary actions, or causing camera restart jitter.
8. On the physical front camera, move the face to the center and all viewport edges. Expected: the green oval remains aligned with current raw geometry while the fixed guide remains centered. Record device/OS/build, viewport points, delivered format/range, Vision revision, and any crop/mirror discrepancy for R02.

Actual result: **NOT RUN**. Automated fixture/UI tests are not human visual, VoiceOver, Reduce Motion, animation-duration, physical overlay, or R02 evidence. Plan 09 may extend automated accessibility coverage; final physical presentation and calibration acceptance remain separate.
