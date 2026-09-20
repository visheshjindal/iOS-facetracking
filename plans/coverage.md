# Source-to-plan coverage

This is a planning coverage map, not a test result. Exact acceptance criteria stay in `ios-swift-implementation-plan.mdx`. Each numbered plan requires the indicated source sections and preserves original IDs in implementation tests/evidence.

## Requirements

| Source ID | Implementation plans | Final verification |
| --- | --- | --- |
| F01 Camera permission | 00, 02, 03, 08 | 03 permission doubles/device; 09 U01; 11 cold start/Settings |
| F02 Live preview | 03, 04, 05 | G01/G02 and physical R02; 10 responsiveness |
| F03 Initial guide | 01, 08 | P01; 08/09 U02 visual checks |
| F04 Position corrections | 01, 07, 08 | P03/P04/P08/P09; 11 device positioning |
| F05 Stable acquisition | 01, 02, 05 | P02/P05–P07; S06; U02; 11 device hold |
| F06 Following visuals | 01, 08 | U02/U03 and manual fade/raw geometry |
| F07 Following corrections | 01, 08 | P08; 11 directions/edges |
| F08 Loss/recovery | 01, 02, 05, 08 | P09/S06/U03; physical loss/return |
| F09 Manual restart | 02, 03, 08 | S03/U03; physical fresh hold |
| F10 Adaptive lighting | 06, 07 | L01–L06; R04 calibration in 11 |
| F11 Stable lighting UI | 07, 08 | L07–L10/U04; R04 settling/oscillation |
| F12 Guidance priority | 07, 08 | L10/U04 including advisory hold |
| F13 Error recovery | 02, 03, 05, 08 | S04–S06/U01; 10/11 device interruption/stall |
| F14 Lifecycle | 02, 03, 05 | S01–S05/U06; 10 50 cycles/teardown |
| F15 Accessibility | 08, 09 | U05 plus human VoiceOver/contrast/large text |
| F16 Privacy | 03, 05, 06, 10, 11 | Buffer ownership, source/resource audit, human declarations |

## Automated test ownership

| IDs | First implemented | Integration/regression |
| --- | --- | --- |
| P01–P09 | 01 | 02, 05, 07, 09–11 |
| S01–S05 | 02 reducer | 03 runner/service, 05 asynchronous delivery, 10 stress |
| S06 | 02 reducer boundaries | 05 real scheduling contract, 10 load |
| G01 | 04 | 05 real Vision mapping, 10 format changes |
| G02 | 04 snapshots | 05 delivery, 06 same-frame luma |
| L01–L03 | 06 | 07 invalid inputs, 10 buffers |
| L04–L10 | 07 | 08/09 UI, 11 calibration regression |
| U01–U04 | 08 projections/focused UI | 09 full UI suite, 11 device matrix |
| U05 | 08 basic semantics | 09 automated + manual accessibility, 11 review |
| U06 | 03 ownership probes | 09 UI cycles, 10 leak/performance checks |

## Decisions and discovery

Plan 00 records all D01–D09: two-second hold, platform, architecture, first-usable face, advisory lighting, independent filtering/drawing, native permission/Exit, stale withdrawal and provisional profile. Later discovery updates the source specification, configuration and tests together when a decision changes.

| Research | Primary plans | Evidence required, never inferred from code |
| --- | --- | --- |
| R01 Pose availability | 05 | Request/revision/OS matrix and physical optional-pose/bias/sign observations |
| R02 Coordinates | 04, 05, 06, 08 | Asymmetric math plus actual mirror/crop/overlay/lighting-side trials |
| R03 Multiple people | 05, 11 | Entry/cross/exit behavior and explicit selector decision if changed |
| R04 Lighting calibration | 06, 07, 11 | Protocol, coverage, frozen profile, held-out performance vs tolerances |
| R05 Timebase/latency | 05, 10 | Related-clock proof and end-to-end stress age measurements |
| R06 Performance | 10 | Oldest-device latency distributions, memory/energy/thermal evidence |
| R07 Product/release | 00, 09, 11 | Platform/localization/privacy/accessibility decisions and human review |

All eleven section 13 device scenarios are assigned to plan 11's final matrix; earlier plans collect reusable evidence. Plan 10 owns the section 10 engineering targets. Plan 11 audits every section 14 completion condition; no passing synthetic suite substitutes for required human evidence.
