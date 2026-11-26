# DVP Controller verification package

Single consolidated version (2026-11-24). Earlier workspaces, run archives, snapshots, the Icarus testbench and superseded notes were removed by decision of the project owner; this folder describes only what is kept.

## Layout

| Path | Content |
|---|---|
| `docs/` (flat) | this index; [verification_plan.md](verification_plan.md), `vplan.csv`, `requirements.txt`; [architecture.md](architecture.md); [checker_qualification.md](checker_qualification.md); [test_review_notes.md](test_review_notes.md) (for the human test reviewer); [decisions_and_gates.md](decisions_and_gates.md); [verification_report.md](verification_report.md) |
| `env/bfm/` | APB4 requester and DVP sensor source BFMs (project-local, not released VIP) |
| `env/scoreboards/` | `dv_dvp_checker.sv`: passive checkers and the HDS-derived reference model on the public pins |
| `env/tb/` | `tb_dvp_controller.sv` (DUT harness and the test tasks), `tb_qual_checker.sv` (checker qualification with a scripted DUT) |
| `env/scripts/` | `dvp_regress.py`, the single driver (qualification, parameter legality, scope review, regression matrix) |
| `env/config/` | `resource_budget.json` (reviewed RAM/disk/output limits) |
| `tests/regression/` | `testlist.yaml`, the planned tests with requirements, interactions and tiers |
| `models/` | empty (`.gitkeep`): the reference model is part of the checker |
| `sim/final/` | the single retained result set: one log per case, `summary.json/csv`, `qualification.log`, `parameter_legality.log`, `scope_review.log`, `coverage_bins.json`, `commands.json`, `resource_usage.json`, `manifest.sha256` |

## How to run

~~~sh
make -C 025_DVP_Controller regress RUN=<new-name>
~~~

or `python verification/env/scripts/dvp_regress.py --out verification/sim/<new-name>` (Windows, Verilator 5, MSYS2 ucrt64 g++; tool paths at the top of the script). The driver refuses an existing output directory and builds in a temporary directory outside the repository.

## Status

Gates G0, G1 and G3 are approved; G5 and G6 are pending. Results, findings and what was not run are in [verification_report.md](verification_report.md). Formal verification, mutation analysis and code coverage have been run with the limits stated in the report; nothing here is a closure or a sign-off.
