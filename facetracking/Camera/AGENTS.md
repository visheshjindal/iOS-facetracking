# Camera integration guidance

- `CameraSessionService` exclusively configures and starts/stops its single `AVCaptureSession` on `cameraQueue`; frame callbacks use the separate serial `outputQueue`.
- Commands carry reducer session IDs and are enqueued in effect order. Invalidate reducer generations before teardown, and never accept a callback as authority to revive an obsolete generation.
- `CameraPreviewSession` is an immutable reference wrapper marked `@unchecked Sendable`: the camera queue mutates session configuration/running state, while MainActor only attaches that same session to `AVCaptureVideoPreviewLayer`.
- Preview is portrait, aspect-fill, and mirrored. Video-data output is portrait and explicitly unmirrored; plan 04 must preserve this one-mirror policy in its transform snapshot.
- `FrameTransformSnapshot` names raw top-left buffer pixels, oriented top-left image pixels, Vision lower-left normalized bounds, preview points, and mirrored top-left normalized viewport coordinates. It carries geometry revision, raw/oriented sizes, quarter-turn, Vision orientation policy, clean aperture, viewport, portrait interface orientation, and mirroring.
- Use `FrameCoordinateMapper.mapVisionBounds` only for already-oriented Vision rectangles. Use `mapRawSamplePoint` for raw luma cell centers; it applies clean-aperture offset and raw rotation before the shared aspect-fill/mirror transform. Missing or inconsistent snapshots return unavailable values.
- Plan 03 requests a physically rotated data output. When delivered pixels are confirmed upright, snapshot them with `.degrees0` plus `.bufferAlreadyOriented`; never also ask Vision to rotate. If delivery is not physically oriented, record the actual quarter-turn and `.visionAppliesSnapshotRotation` instead.
- Output currently discards frames. Plan 05 owns analysis, result delivery, freshness, and watchdog activation; do not start the detector watchdog before that path exists.
- Keep only front wide-angle video input plus one video-data output. Do not add rear fallback, audio, photo, movie, recording, persistence, or participant imagery diagnostics.
- Focused tests: `CameraPreviewLifecycleTests` and `FrameCoordinateMapperTests`. Physical format, clean aperture, stabilization crop, delivered rotation, mirroring, interruption, and race evidence remain device gates.
- `AGENTS.md` must remain outside app resources and bundles.
