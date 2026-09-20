# Implementation status

Planning files created on 2026-09-21. No application implementation or verification is claimed by this planning work. Update each row from the actual checkout and executed checks at the end of that plan; link the resulting numbered handoff. A missing handoff means there is no recorded completion evidence.

| Plan | Code | Automated verification | Human acceptance | Handoff |
| --- | --- | --- | --- | --- |
| 00 Project foundation | Complete | Passed | Pending D02/R07 and human shell/device smoke | [00](handoffs/00.md) |
| 01 Models and positioning | Not started | Not run | Not applicable to pure code | Not created |
| 02 Session state | Not started | Not run | Not applicable to pure code | Not created |
| 03 Camera and preview | Not started | Not run | Pending | Not created |
| 04 Coordinate mapping | Not started | Not run | Pending R02 | Not created |
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

Plan 01 is implementation-ready: plan 00 provides a compiling `ios-provisional-v1` configuration, shared scheme, and passing XCTest/UI smoke plumbing. Open a new chat with [plan 01](../../plans/01-models-positioning.md), following [the usage instructions](../../plans/README.md). Keep D02/R07 and R01–R07 open unless their required evidence is supplied.
