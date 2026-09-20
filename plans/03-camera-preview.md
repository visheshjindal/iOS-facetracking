# Plan 03 — Camera authorization, ownership and live preview

## Outcome and prerequisites

Implement M2. Read handoffs 00–02, source sections 3–5, 6 (viewport/preview), 9, 10 and S/U lifecycle cases. Confirm reducer/positioning tests pass. Add `CameraAuthorization`, `CameraSessionService`, `CaptureDependencies`, `CaptureRoute`, `CaptureStore`, minimal `CaptureViewState`, and `CameraPreview` in the planned directories. Preserve current entry-point identity.

## Work

1. Wrap permission behind an injectable protocol. Query camera authorization; request only for notDetermined and only on the appropriate user action. Denied offers Settings and Exit; restricted explains restriction without another request. Recheck on return to active scene/Settings. Use native URL routing and dismissal; never terminate the process.
2. Build one AVFoundation session with front wide-angle input and video-data output, no audio/photo/movie outputs. Missing front camera is a typed camera error; no rear fallback. Negotiate supported preset/format and frame rate starting near 640×480 and 30 fps; keep automatic exposure/white balance. Record actual selections, not presumed delivery, for later evidence.
3. Own setup/configuration/start/stop on a dedicated serial queue. Keep begin/commit configuration atomic. A separate serial output queue is reserved for later Vision; initially it may discard frames. Explicitly define token validity and cross-queue ownership; invalidate before teardown. Use an ordered effect runner, not independent Tasks that can overtake stop/start.
4. Bridge stable `AVCaptureVideoPreviewLayer` through `UIViewRepresentable`, resizeAspectFill and explicit mirrored portrait preview. Check rotation support against the pinned SDK. Prefer unmirrored buffers; record actual rotation policy for plan 04. Explain safe preview-session attachment under Swift 6; any narrowly needed interoperability wrapper must document ownership and synchronization.
5. Implement `@MainActor @Observable CaptureStore` with private(set) view state and ignored service dependencies. Route owns it via `@State`; body recomputation must not construct a new session/analyzer. Feed route/scene/geometry/auth events into plan 02 and dispatch its effects. Keep a stable viewport unaffected by banner layout.
6. Handle runtime errors, camera interruptions/end, access revocation, retry, dismissal and inactivity with typed events. Stop/remove observers/cancel work when leaving; no hidden capture. Do not attach a watchdog expecting analysis results until plan 05 provides the result path; document this temporary integration boundary.

## Automated verification

- Fake authorization tests: notDetermined requests once, denied/restricted never prompt again, Settings action uses injected opener and Exit dismisses. Authorized camera start waits for active route and valid viewport.
- Fake service/runner tests: stop completes before subsequent start, repeated eligibility does not duplicate session, stale completions are ignored, failures remain reliable during event bursts. Exercise 50 fake lifecycle/retry cycles with active-generation count <=1.
- Store/route tests: redraw does not recreate services; scene inactive and route exit request stop; interruption end restarts only if eligible; weak store reference releases after teardown.
- Run full unit suite and unsigned device build with strict concurrency enabled. Run existing UI smoke test. Thread Sanitizer on an available supported simulator/device configuration exercises service/fake paths; record scope and unavailable paths honestly.

## Human verification

**F01/F02/F13/F14, physical iPhone:** fresh permission state → deny → Settings → grant → return; separately grant initially and test the restricted fixture/managed-device state if available. Expect correct actions and no unauthorized capture. Enter capture, move visibly left/right, background/foreground, open Control Center, lock/unlock, Exit and reenter. Expect mirrored upright crop, capture stopped off-route, fresh state on return and no duplicate sessions. Simulated restricted UI proves copy only, not operating-system restriction handling.

Record delivered dimensions/rate, build/device/OS and concurrency test results. A real preview and race-free exercised paths are M2 acceptance; if no signed device is available, leave those checks NOT RUN and allow synthetic mapping work next.

## Layered AGENTS.md work

Create/update `Camera/AGENTS.md` with serial owners, safe token transfer, session/preview attachment and teardown; `CaptureUI/AGENTS.md` with stable route/store/preview ownership and action injection; `App/AGENTS.md` with composition-root construction rules. Update test guidance for command-recorder/authorization doubles. Exclude Markdown from build resources.

## Completion and next chat

Write `docs/implementation/handoffs/03.md`, update STATUS, and record concurrency choices, service/preview APIs, current output rotation/mirroring and physical verification gaps. Do not add live Vision, lighting or final overlay styling here.
