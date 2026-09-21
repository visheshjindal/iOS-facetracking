# Composition-root guidance

- Preserve `facetrackingApp` as the sole `@main` entry point.
- Construct `CaptureDependencies.live()` once at app composition. Pass the same dependency graph into each presented route; never create camera services in a view body.
- `LandingView` owns presentation only. `CaptureRoute` owns capture lifetime and returns through its injected dismissal closure.
- Native Settings routing belongs in `SystemSettingsOpener`; test stores with an injected opener.
- Do not add camera policy, algorithms, or frame handling in this directory.
- `AGENTS.md` must remain outside app resources and bundles.
