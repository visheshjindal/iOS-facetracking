# Capture UI guidance

- `CaptureRoute` owns one stable `CaptureStore` with `@State`; body recomputation must not construct authorization or camera services.
- `CaptureStore` is `@MainActor @Observable`, publishes `private(set) CaptureViewState`, and keeps dependencies/session authority out of observation.
- Feed route, scene, viewport, authorization, service, retry, and exit events through `SessionTransition`; execute returned effects in array order.
- The preview fills a stable viewport. Permission/error banners overlay it and must not resize the viewport or trigger restart jitter.
- Permission requests occur only from the Grant action while status is `notDetermined`. Settings and dismissal remain injected native actions.
- `CameraPreview` may attach the immutable session reference on MainActor, set aspect-fill, configure explicit mirroring, and derive preview rotation from `AVCaptureDevice.RotationCoordinator`; it must not configure/start/stop capture or assume a fixed sensor angle.
- UI previews and simulator UI tests must inject fakes if they would otherwise request camera access. Keep Exit available in every state.
- `AGENTS.md` must remain outside app resources and bundles.
