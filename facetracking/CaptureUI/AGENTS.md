# Capture UI guidance

- `CaptureRoute` owns one stable `CaptureStore` with `@State`; body recomputation must not construct authorization or camera services.
- `CaptureStore` is `@MainActor @Observable`, publishes `private(set) CaptureViewState`, and keeps dependencies/session authority out of observation.
- Feed route, scene, viewport, authorization, service, retry, and exit events through `SessionTransition`; execute returned effects in array order.
- Consume observations only when session ID and geometry revision still match. At delivery age greater than 300 ms, preserve capture/result timestamps but withdraw face and lighting payloads before reducing.
- `AnalysisWatchdog` uses injected monotonic clock/scheduler: 250 ms cadence, failure only after 5,000 ms, and face expiry at the first millisecond beyond 300. Cancel watchdog and freshness tokens for every invalidated attempt.
- Face capture time controls ordering/freshness; successful Vision result time refreshes stall monitoring. A successful nil-face result is healthy analysis and cannot acquire a hold.
- The preview fills a stable viewport. Permission/error banners overlay it and must not resize the viewport or trigger restart jitter.
- `CaptureScreen` renders immutable `CaptureViewState` projections only. It never classifies lighting, filters geometry, or mutates session state; all actions return through injected closures.
- Initial cutout and return guide use the shared `SessionState.target`. Following draws `guidance.trackedOval` raw geometry, retains the fixed return guide during face presence/loss, and fades only the mask presentation over 450 ms (or immediately with Reduce Motion).
- `PreviewView.bounds` is the sole live viewport-size authority. Banner and badge are overlays inside that geometry; overlay `GeometryReader` values, text wrapping, badge expansion, and Dynamic Type must never report viewport changes or recreate `CameraPreview`.
- `CaptureFixture` is the deterministic state catalog. The `-capture-fixture <id>` harness is compiled only in DEBUG and skips `CaptureDependencies.live()` entirely; release argument handling must never select fixtures.
- Permission requests occur only from the Grant action while status is `notDetermined`. Settings and dismissal remain injected native actions.
- `CameraPreview` may attach the immutable session reference on MainActor, set aspect-fill, configure explicit mirroring, and apply the shared fixed-portrait `CameraPortraitOrientation` policy; it must not configure/start/stop capture or assume a fixed sensor angle.
- UI previews and simulator UI tests must use `CaptureFixtureHost` if they would otherwise request camera access. Keep Exit available in every state and Restart only during following loss.
- Store/timer tests use fake detector, mailbox consumer, monotonic clock, and scheduler; never sleep or dispatch real camera frames.
- `AGENTS.md` must remain outside app resources and bundles.
