# Plan 09 — Accessibility and deterministic UI regression

## Outcome and prerequisites

Finish M5 acceptance with U01–U06. Read handoffs 00, 03 and 08 plus source sections 9, 12 and accessibility/lifecycle rows in section 13. Confirm all states/actions exist and pure tests pass. Work in `CaptureUI`, `Resources`, `facetrackingUITests` and test fixture support; avoid changing camera/threshold behavior except a demonstrated scoped fix.

## Work

1. Finish a deterministic UI-test launch mode through dependency injection: fake authorization, camera command recorder, observations and controllable monotonic clock. Ensure the real camera service is never constructed in fake mode. Use explicit scenario identifiers and scripted clock advancement, not arbitrary sleeps or live permissions. Keep hooks Debug/test-only and prove release composition remains real.
2. Give meaningful elements stable accessibility identifiers without exposing implementation details in user text. Ensure full VoiceOver lighting label exists when badge is icon-only, guide is exposed once, eyes are hidden, warnings are not color-only and actions have >=44×44-point targets.
3. Test/adjust Dynamic Type through largest supported accessibility sizes on smaller phone layouts: wrap/reposition banner and badge without shrinking camera guide, changing viewport revisions or hiding primary actions. Keep localized strings in the catalog and avoid concatenating grammatically fragile fragments.
4. Add meaningful-prompt announcement deduplication/throttling with an injectable time source and documented cadence. Do not announce every frame. Announce user-relevant changes, ensure critical errors/actions are discoverable and assess actual cadence manually. Reduce Motion removes nonessential fade/badge motion while preserving acquisition/persistence timing.
5. Add UI suites mapping directly to U01–U06. Use bounded condition-based waits only for UI delivery; business time is advanced through test control. Extend weak-reference/ownership tests to repeated enter/Exit/retry paths. Test instrumentation may expose aggregate counters, never images or face identity data.

## Automated verification

- U01: all permission states, missing camera, detector error, interruption, Settings opener and Exit destination; no unauthorized fake camera start.
- U02: mask at 1,999 ms; eligible 2,000 ms enters following and creates green oval. Assert logical transition separately from animation completion; Reduce Motion leaves timing unchanged.
- U03: fixed guide while visible face and loss, green oval absent on loss, auto recovery without hold, explicit Restart restores initial state.
- U04: unknown/acceptable/all warnings including uneven left/right/no-side and high-contrast; copy, expansion, compact timing, colors via projections, accessible labels and position-first banner.
- U05: automated layout/accessibility audits available in the pinned SDK, largest text fixtures, announcement deduplication and Reduce Motion tests. Automated audits are partial evidence only.
- U06: repeated route entry/exit/scene cycles retain one owner, request stop and release store; no growing observer/task count in test probes. UI launches in fake mode remain deterministic.
- Run full unit/UI suites on an actual simulator destination and unsigned device build. Record failures, retries and skipped SDK-dependent audits explicitly. Do not mark flaky tests passed from a single lucky retry.

## Human verification

**F15/U05, accessibility reviewer with iPhone:** enable VoiceOver, navigate all actions, hear compact badge full text, confirm guide is announced once and eyes are silent. Move through positioning and lighting changes: instructions should be useful without per-frame chatter. Turn on Reduce Motion and repeat acquisition; logic still requires two seconds. At largest Dynamic Type, check wrapping, focus order and reachable controls on smallest supported screen. Check contrast in all supplied color states, not just green/amber distinction.

**U06, device user:** repeat route entry/Exit while following/lost/error and use background/lock/Control Center. Expect no hidden capture, stale overlay or retained capture route. Memory/performance proof follows plan 10.

Record reviewer/device/settings, exact scenario, observed outcome and unresolved accessibility issues. Leave spoken quality/contrast/usability pending if no human review is available.

## Layered AGENTS.md work

Update/create `facetrackingUITests/AGENTS.md` with launch scenarios, clock controls, selectors and commands; `CaptureUI/AGENTS.md` with announcement ownership, stable geometry and accessibility constraints; `Resources/AGENTS.md` with localization verification; and unit-test guidance for time-controlled announcement tests.

## Completion and next chat

Write `docs/implementation/handoffs/09.md`, update STATUS and identify U tests, fixture controls, release-hook isolation and pending accessibility review. Plan 10 uses the complete experience and lifecycle regression suite for device profiling.
