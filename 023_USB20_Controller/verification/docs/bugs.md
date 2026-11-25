
- HDR-2026-11-25 (testcase headers, R-281 and R-286; done on the user's request "viết header R-281/R-286 cho các generator"). Every
  generator of tests/usb20/testlist.csv now starts with the template header (test ID, priority, purpose, requirements, configuration,
  software flow, stimulus, checkpoint table, expected outcome, defect targeted, oracle, replay command, waveform, evidence); the five
  configuration-sweep tests (t_dev_pipe_equiv, t_dev_ulpi_traffic, t_dir_timing_ts1, t_host_ulpi_ocp, t_ulpi_axis) have their header
  in tests/usb20/tc_<test>.txt; the shared bring-up checkpoints (DBR-*, DBU-*, HBU-*) are catalogued in usb2lib.py, devlib.py and
  hostlib.py. Each checkpoint ID is executable: the generator emits op `CHK <id>` before the checks that belong to it; the harness logs
  `CHKPT @t: <id>` and `CHKPT_END <id> checks=<n>` and fails the run when a checkpoint executed no check (negative control r3900,
  tests/ops/nc_chk_empty.ops: FAIL "checkpoint EMPTY executed no check", as intended). env/scripts/header_check.py checks the headers
  and the regenerated operation files of every testlist row and seed (H1 fields, H2 at least five documented IDs, H3 listed = emitted,
  H4 every CHK followed by a check, H5 at least five distinct checkpoints per test): 49 of 49 tests pass. ops_audit.py now counts XK,
  TC and WS as checks (they were missing from its list). The operation files changed only by the CHK lines (zero-time), so every
  build was rebuilt and the regression must be rerun for run-bound evidence.
  Claims of the old prose docstrings that no check backs (found while writing the headers; now listed under "Known gaps" in the
  headers and no longer claimed): t_fi_ram_parity (data after the faulty read is FLUSHed unchecked; OUT memory after the faulty drain
  not compared); t_host_babble (ch_halt and the memory behind the babble buffers not compared); t_dev_axis_udf (XP with mask 0 checks
  nothing; fifo_udf/unf only printed); t_host_conn (return to the full-speed idle row and the low-speed reset length not checked);
  t_dev_edge (len error flags only printed; acceptance of the earliest ACK not checked); t_dir_test_mode (J/K stream bytes not
  compared); t_dir_loopback (the "frozen after exit" claim is not shown by a saturated counter); t_host_periodic (only the first poll
  interval measured); t_fi_ulpi_abort (truncated packet FLUSHed; M09 survives); t_dev_ulpi_traffic (M08 survives). None of these turned
  a failing behavior into a PASS that a check reported; they are untested claims. The requirement ID REQ-PERF-002 that the agent first
  wrote into the pipe header does not exist in the specification; it was replaced by DEC-003 and DEC-029 before any run.
- LOG-CLEANUP-2026-11-25 (on the user's instruction "xóa hẳn mọi log, giữ lại test vectors và waveform"): all 2003 files *.log under
  verification/sim were deleted permanently (sim.log of every run, build.log of every build, formal and parameter-build logs, the
  regress/rebuild/mutate/oracle/priority-wave logs). Kept: every wave.vcd (23), the test vectors (in__*.ops of each run and tests/ops),
  bins.txt, run_record.json, resource_usage.json, build records, sim/index.csv and the generated reports. Consequence: the CHKPT and
  RESULT lines can no longer be re-read; testcase_review.py, make_report.py and update_vplan.py give wrong numbers until the regression
  is rerun (python env/scripts/regress.py full, then run_builds.py).
