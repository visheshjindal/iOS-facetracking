# Capture UI guidance

- `CaptureRoute` owns one stable `CaptureStore` with `@State`; body recomputation must not construct authorization or camera services.
- `CaptureStore` is `@MainActor @Observable`, publishes `private(set) CaptureViewState`, and keeps dependencies/session authority out of observation.
- Feed route, scene, viewport, authorization, service, retry, and exit events through `SessionTransition`; execute returned effects in array order.
- Consume observations only when session ID and geometry revision still match. At delivery age greater than 300 ms, preserve capture/result timestamps but withdraw face and lighting payloads before reducing.
- `AnalysisWatchdog` uses injected monotonic clock/scheduler: 250 ms cadence, failure only after 5,000 ms, and face expiry at the first millisecond beyond 300. Cancel watchdog and freshness tokens for every invalidated attempt.
- Face capture time controls ordering/freshness; successful Vision result time refreshes stall monitoring. A successful nil-face result is healthy analysis and cannot acquire a hold.
- The preview fills a stable viewport. Permission/error banners overlay it and must not resize the viewport or trigger restart jitter.
- Permission requests occur only from the Grant action while status is `notDetermined`. Settings and dismissal remain injected native actions.
- `CameraPreview` may attach the immutable session reference on MainActor, set aspect-fill, configure explicit mirroring, and derive preview rotation from `AVCaptureDevice.RotationCoordinator`; it must not configure/start/stop capture or assume a fixed sensor angle.
- UI previews and simulator UI tests must inject fakes if they would otherwise request camera access. Keep Exit available in every state.
- Store/timer tests use fake detector, mailbox consumer, monotonic clock, and scheduler; never sleep or dispatch real camera frames.
- `AGENTS.md` must remain outside app resources and bundles.
