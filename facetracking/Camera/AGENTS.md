# Camera integration guidance

- `CameraSessionService` exclusively configures and starts/stops its single `AVCaptureSession` on `cameraQueue`; frame callbacks use the separate serial `outputQueue`.
- Commands carry reducer session IDs and are enqueued in effect order. Invalidate reducer generations before teardown, and never accept a callback as authority to revive an obsolete generation.
- `CameraPreviewSession` is an immutable reference wrapper marked `@unchecked Sendable`: the camera queue mutates session configuration/running state, while MainActor only attaches that same session to `AVCaptureVideoPreviewLayer`.
- Preview is portrait, aspect-fill, and mirrored. Video-data output is portrait and explicitly unmirrored; plan 04 must preserve this one-mirror policy in its transform snapshot.
- Output currently discards frames. Plan 05 owns analysis, result delivery, freshness, and watchdog activation; do not start the detector watchdog before that path exists.
- Keep only front wide-angle video input plus one video-data output. Do not add rear fallback, audio, photo, movie, recording, persistence, or participant imagery diagnostics.
- Focused fake tests: `CameraPreviewLifecycleTests`. Physical format, delivered rate, mirroring, interruption, and race evidence remains a device gate.
- `AGENTS.md` must remain outside app resources and bundles.
