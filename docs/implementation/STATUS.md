# Implementation status

Planning files created on 2026-09-21. No application implementation or verification is claimed by this planning work. Update each row from the actual checkout and executed checks at the end of that plan; link the resulting numbered handoff. A missing handoff means there is no recorded completion evidence.

| Plan | Code | Automated verification | Human acceptance | Handoff |
| --- | --- | --- | --- | --- |
| 00 Project foundation | Complete | Passed | Pending D02/R07 and human shell/device smoke | [00](handoffs/00.md) |
| 01 Models and positioning | Complete | Passed (P01–P09; 10 total unit tests) | Not applicable to pure code; R01/R02/R03 remain open | [01](handoffs/01.md) |
| 02 Session state | Complete | Passed (S01–S06; 19 total unit tests; unsigned build) | Not applicable to pure reducer; F13/F14 physical integration pending plans 03/05 | [02](handoffs/02.md) |
| 03 Camera and preview | Complete | Passed (27 total tests; unsigned build; focused simulator TSan fake paths) | Partial pass: user verified physical permission flow and live camera view; extended lifecycle/race and measured-format checks pending | [03](handoffs/03.md) |
| 04 Coordinate mapping | Complete | Passed (G01/G02 transforms; 35 total tests; unsigned build) | Partial pass on iPhone 17/iOS 27: portrait, mirror, edge crop, reopen passed; live mapped boxes/clean aperture pending R02 | [04](handoffs/04.md) |
| 05 Vision and freshness | Not started | Not run | Pending R01/R02/R03/R05 | Not created |
| 06 Lighting measurement | Not started | Not run | Pending R02/R04 | Not created |
| 07 Lighting guidance | Not started | Not run | Pending R02/R04 | Not created |
| 08 Capture interface | Not started | Not run | Pending | Not created |
| 09 Accessibility/UI tests | Not started | Not run | Pending | Not created |
| 10 Reliability/performance | Not started | Not run | Pending R05/R06 | Not created |
| 11 Calibration/acceptance | Not started | Not run | Pending R04/R07 and all unresolved gates | Not created |

## Research gate status

All R01–R07 remain OPEN. Plan 00 created the detailed [research register](research.md); its simulator/build evidence closes none of the physical, measured, calibration, or release gates. Pending research is not silently waived by proceeding to an independent code plan.

## Next action

Plan 05 is implementation-ready from automated prerequisites: plan 04 provides immutable frame-transform snapshots, separate Vision-rectangle and raw-sample mapping paths, asymmetric G01/G02 fixtures, and passing integration checks. Open a new chat with [plan 05](../../plans/05-vision-freshness.md), following [the usage instructions](../../plans/README.md). Keep R02 physical proof, extended F13/F14 checks, and all R01–R07 gates open unless their required evidence is supplied.
