# Author response to the independent AI review (2026-11-21)

Author: the AI agent that built the package. Reviewer: see `review_ai_2026-11-21.md`. This is not a human decision.

| Item | Finding | Response | Action |
|---|---|---|---|
| 1 | Functional bins are generator markers | Agreed | Report 0 and 5.0 now label them "scenario markers, stimulus intent, not sampled from the DUT"; no monitor-based bin sampling exists |
| 2 | R-243 claim too strong | Agreed | Rule row set to partial; the eight loosened or re-targeted items are listed in report 19.3 |
| 3 | "All fixed" | Agreed in part | BUG-012 is partly fixed, BUG-037 is untested, M08 and M09 survive; recorded in bugs.md and report 13.2 |
| 4 | Stale text | Fixed | Report, README and the 4.4 status column regenerated |
| 5 | vplan "passing" does not mean exercised | Fixed | `update_vplan.py` sets a row to `implemented` when none of its bins was marked, and appends the unhit bins to `notes`; 29 passing rows still list some unhit bins (note in report 5.0); REQ-FUNC-020 and REQ-FUNC-037 listed in 13.2 as without stimulus |
| 6 | Babble not exercised | Agreed | Listed in report 13.2; no scenario was written |
| 7 | `t_fml_cdc_xreg` is a simulation; `t_dir_param_builds` lint-only | Agreed | Both already stated in report 7.1; the plan type column keeps the plan wording |
| 8 | `dev_fs_s1.ops` overwritten by another TSCALE variant | Fixed | `gen_dev_fs.py` writes `dev_fs_ts1_s1.ops` for the TSCALE 1 variant; the two runs were repeated (r1359 to r1361) |
| 9 | Code coverage not reproducible | Fixed | `scripts/run_coverage.py` |
| 10 | Activity counters count cycles | Agreed | Listed in 13.2 |
| 11 | ULPI AXI-slave wrapper not run | Partly fixed | It is now elaborated by `t_dir_param_builds` (`cfg_dev_ulpi_axis`, r1358); it is still not simulated |
| 12 | Orphan run folder r0313 | Noted | It is an aborted run (missing ops file) kept as evidence of the failed start |
