# Plan 06 lighting-measurement evidence

Recorded 2026-09-21. R02 and R04 remain OPEN. No participant image, face crop, landmark, or identifying data is stored.

## Implemented measurement contract

- Negotiation supports only `420f` (`kCVPixelFormatType_420YpCbCr8BiPlanarFullRange`) and `420v` (`kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`), preferring full range. Unsupported delivered formats/layouts produce nil lighting.
- Plane zero is read while locked read-only. Actual width, height, and bytes-per-row are used; the sampler copies at most 64×64 canonical luma samples and never includes padding.
- Full-range bytes are unchanged. Video-range bytes use rounded and clamped `(Y-16)*255/219`; verified examples include 16→0, 126→128, and 235→255.
- Continuous raw grid-cell centers use the same immutable frame snapshot as the raw current face. The mirrored viewport face ellipse and regional partitions are measured before the buffer unlocks.
- Metrics are immutable 0–255/fraction/count scalars. Missing transform/face/complete eligible pose, insufficient counts, inconsistent partitions, bad fractions, stale results, or unsupported layout produces nil for that frame; no previous metrics are reused.

## Physical R02/R04 procedure — NOT RUN

Required: oldest supported iPhone and one newer iPhone, iOS/build identifiers, signed Debug build, diffuse and directional controllable lighting, and Xcode debugger. Do not record participant imagery.

1. Add a symbolic/file breakpoint immediately after `lumaSampler.measure` returns in `FrameAnalyzer.analyze`; inspect only `measurement.diagnostics` and `measurement.metrics` scalar values.
2. For each device, record actual pixel-format FourCC, range, plane width/height/stride, grid count, viewport, clean aperture, and profile `ios-provisional-v1`.
3. Hold an eligible neutral pose under diffuse frontal light; record aggregate median, trimmed means, fractions, and counts for at least 30 observations.
4. Illuminate screen-left, screen-right, above, and below separately. Record regional aggregate means only and confirm the darker/brighter region changes without inversion through the mirrored transform.
5. Exercise a small and partly cropped face. Expected: insufficient total or any regional count yields nil rather than reused values.
6. If both `420f` and `420v` can be produced without changing product scope, repeat equivalent scenes and compare canonical aggregate values. Do not claim equivalence from normalization alone.

Expected: supported bi-planar layout, no padding contamination, regional direction matching the mirrored preview, honest nil on insufficient coverage, and stable aggregate scalars. Actual: NOT RUN. This plan has no user-visible lighting UI, and synthetic tests do not close R02/R04.

Calibration across participants, appearance, automatic exposure, mask/display light, devices, and held-out sessions remains plan 11 work. No warning threshold is accepted or tuned here.
