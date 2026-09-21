# Implementation status

Planning files created on 2026-09-21. No application implementation or verification is claimed by this planning work. Update each row from the actual checkout and executed checks at the end of that plan; link the resulting numbered handoff. A missing handoff means there is no recorded completion evidence.

| Plan | Code | Automated verification | Human acceptance | Handoff |
| --- | --- | --- | --- | --- |
| 00 Project foundation | Complete | Passed | Pending D02/R07 and human shell/device smoke | [00](handoffs/00.md) |
| 01 Models and positioning | Complete | Passed (P01–P09; 10 total unit tests) | Not applicable to pure code; R01/R02/R03 remain open | [01](handoffs/01.md) |
| 02 Session state | Complete | Passed (S01–S06; 19 total unit tests; unsigned build) | Not applicable to pure reducer; F13/F14 physical integration pending plans 03/05 | [02](handoffs/02.md) |
| 03 Camera and preview | Complete | Passed (27 total tests; unsigned build; focused simulator TSan fake paths) | Partial pass: user verified physical permission flow and live camera view; extended lifecycle/race and measured-format checks pending | [03](handoffs/03.md) |
| 04 Coordinate mapping | Complete | Passed (G01/G02 transforms; 35 total tests; unsigned build) | Partial pass on iPhone 17/iOS 27: portrait, mirror, edge crop, reopen passed; live mapped boxes/clean aperture pending R02 | [04](handoffs/04.md) |
| 05 Vision and freshness | Complete | Passed (46/46 tests; unsigned device build) | Pending R01/R02/R03/R05 physical evidence | [05](handoffs/05.md) |
| 06 Lighting measurement | Complete | Passed (L01–L03/G02; 59/59 tests; unsigned build) | Pending R02/R04 physical evidence and calibration | [06](handoffs/06.md) |
| 07 Lighting guidance | Complete | Passed (L04–L10; 74/74 tests; unsigned build) | Pending R02/R04 physical direction, stability, and usefulness evidence | [07](handoffs/07.md) |
| 08 Capture interface | Not started | Not run | Pending | Not created |
| 09 Accessibility/UI tests | Not started | Not run | Pending | Not created |
| 10 Reliability/performance | Not started | Not run | Pending R05/R06 | Not created |
| 11 Calibration/acceptance | Not started | Not run | Pending R04/R07 and all unresolved gates | Not created |

## Research gate status

All R01–R07 remain OPEN. Plan 00 created the detailed [research register](research.md); its simulator/build evidence closes none of the physical, measured, calibration, or release gates. Pending research is not silently waived by proceeding to an independent code plan.

## Next action

Plan 08 is implementation-ready from automated prerequisites. Plan 07 provides typed `CaptureGuidanceProjection` values for primary guidance, lighting badge/advice/presentation, initial mask, return guide, and raw tracked oval. Plan 08 must localize and render those projections without duplicating classification or priority logic. R02/R04 and all other unaccepted research gates remain open.
