# Plan 06 — Sparse luma sampling and pure statistics

## Outcome and prerequisites

Implement measurement half of M4. Read handoffs 01, 04, 05 and source sections 4–6, 8 (sampling/statistics), 10, L01–L03 and R04. Confirm serial analyzer and raw-point transforms exist. Files: `Camera/SparseLumaSampler.swift`, `Tracking/LightingMeasurement.swift`, metrics models and sampler/statistics tests. Do not classify warnings or tune thresholds.

## Work

1. Negotiate an explicitly supported 8-bit bi-planar YCbCr format, preferring full range when available. Inspect available formats and delivered plane layout. Unsupported format/layout returns unavailable lighting rather than RGB conversion or unsafe access. Record format/range in aggregate diagnostics.
2. Lock plane zero read-only and unlock via defer on every exit. Use actual plane width/height/bytes-per-row and validate accessible layout. Copy at most a 64×64 grid: index `floor((c+0.5)*width/64)` and corresponding row, clamp to valid indices. For mapping, use continuous cell centers rather than pretending sample indices are Vision coordinates.
3. Map each sample through the same frame snapshot as its raw current face box. Inner ellipse membership is `((u-0.5)/0.40)^2 + ((v-0.5)/0.38)^2 <= 1`. Split u/v at 0.5 with equality assigned to right/bottom. Use raw face geometry, never the positioning EMA, to sample the corresponding pixels.
4. Full-range bytes map directly to canonical 0–255. Video range provisionally maps `clamp((Y-16)*255/219,0...255)`, rounded to nearest histogram bin. This is range conversion, not skin exposure calibration. No per-frame UIImage/BGRA conversion.
5. Compute five 256-bin histograms (all/left/right/top/bottom), using reusable workspace owned only by serial analysis. Produce median as average of ranks `(n-1)/2` and `n/2`; trim exactly floor(n/10) samples from both tails, including partial buckets. Compute global/regional trimmed means, fractions <=24 and >=235, total/regional counts.
6. Require >=96 total and >=32 each regional count. Reject inconsistent partitions, invalid/non-finite metrics, impossible fractions, bad dimensions, missing transform/face or unknown/ineligible pose. Never reuse prior metrics. Return a small owned metrics value in the same observation as its face; no borrowed arrays escape to consumers.
7. Keep pure calculations separate from buffer access so byte fixtures exercise statistics without AVFoundation. Integrate production sampling inside the existing single analysis pass and buffer lifetime; make metrics unavailable on stale results through existing plan 05 guards.

## Automated verification

Implement L01–L03 and same-frame G02 coverage. Run focused tests, full unit suite and unsigned device build.

- L01: synthetic padded rows containing sentinel padding, very small/edge dimensions, ellipse edges, unsupported formats, invalid layout and at most 4,096 grid samples. Ensure padding is not sampled and no out-of-bounds read occurs.
- L02: full/video-range byte examples including 16→0, 235→255 and clamping; even/odd median; partial-bucket rank trim; uniform and asymmetric distributions; exact shadow/highlight cutoff inclusion. Expected values must be hand-computed independently.
- L03: 95 vs 96 total and 31 vs 32 regional thresholds, invalid partitions/fractions/NaN, missing transform, unknown pose and no face all yield unknown. Reject fractions whose sum exceeds one.
- Test left/right/top/bottom classification of sample locations before any advice strings, and that changing frame revision/face cannot reuse previous metrics.
- Verify workspace remains analyzer-owned and pipeline's buffering/freshness tests continue to pass with sampling enabled.

## Human verification

**R02/R04, physical devices:** record actual pixel format/plane dimensions/range on oldest and newer iPhone. Compare diffuse light and clearly asymmetric left/right and top/bottom illumination using aggregate metrics; expect corresponding region differences without inversion. Compare full/video range if both supported. Sampling accuracy and limited coverage for small/cropped faces must be recorded honestly; insufficient count should show unknown later.

Leave numerical calibration OPEN until plan 11. No claim that normalization alone proves accurate lighting assessment.

## Layered AGENTS.md work

Update/create `Camera/AGENTS.md` with supported buffer formats, locking/stride/grid lifetime and shared transform; `Tracking/AGENTS.md` with histogram/statistics validity and canonical units; and tests guidance with synthetic byte buffers, padding sentinels and independent expected calculations.

## Completion and next chat

Save `docs/implementation/handoffs/06.md`, update STATUS and document measurement API, supported formats, unknown conditions and real-format evidence. Plan 07 consumes immutable metrics only; do not add candidate persistence or warning UI here.
