
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
- BUG-050 (fixed, RTL, DEC-048; found 2026-11-25 by checking the PHY rows against ULPI 1.1 Table 40 during the TUSB1210
  integration review, plan review/2026-11-25_phy_compat_change_plan.md approved by the user): five states of `m_usb2_spd` drove a
  combination of XcvrSelect / TermSelect / OpMode / pull-downs that a PHY does not ensure. PHY-01 host port reset 01/1/11 (OpMode 11b
  is optional and not implemented by TUSB1210, USB3320, USB3500; with no transmit the line stays J, so no device would be reset on
  such a PHY) -> 00/0/00 (SE0 from the high-speed terminations); PARA_USB2_RST_OPMODE removed. PHY-02 host suspend of a high-speed
  port 00/0/00 -> 01/1/00. PHY-03 host resume of a high-speed port 00/0/10 -> 01/1/10. PHY-04 device suspend and L1 after high
  speed 00/0/00 (D+ pull-up removed: the hub would see a disconnect; this also violated the spec row of section 6.3) -> 01/1/00.
  PHY-05 soft-disconnected device 01/0/00 without pull-downs -> non-driving 01 (also the reset value of the registered mode
  outputs: in the PIPE_MODE build a soft reset showed 01/0/00 for 7 cycles, caught by a_phy_row in run r4183). PHY-06 new CSR field
  u2_hport.ext_vbus: ULPI OTG Control DrvVbusExternal = DrvVbus AND ext_vbus (TUSB1210 CPEN). Mutants M28 to M33.
- FND-016 (oracle weakness behind BUG-050, same class as INTEGRITY_HOLD): the PHY models of the harness did not derive the line state
  from the termination rows, so the scenarios forced the line themselves: host_bringup checked OpMode 11b on the pins and then drove
  SE0 by `LS 0`; the device suspend checks masked every mode pin except SuspendM; the host suspend and resume had no mode-pin check;
  t_host_conn (ls) kept the low-speed idle on the line during the whole reset. Every host test passed although the reset row could
  not produce SE0 on a real PHY. Corrective action: assertion a_phy_row in every run (defined rows of Table 40, only suspend rows
  while SuspendM is low); op LSR: the line follows the row (SE0 only under the host high-speed terminations, otherwise the idle state
  of the attached device) until the scenario takes the line back with LS; ULPI PHY model rejects OpMode 11b (bus rule 7); full-mask
  row checks in the host reset, suspend, resume and device suspend, L1 and soft-disconnect steps; new checkpoints DBU-OFF,
  HCN-LSRST (also closes the old gap "low-speed reset length not measured"), FOC-EXTVBUS. A first form of LSR set the line once and
  made t_host_conn (ls) fail at the end of the reset (r4129); LSR became continuous. CORRECTION 2026-11-26: the r4129 failure was
  wrongly attributed to the model and the test was not rerun after the model change; full regression r4312 failed the same way
  (identical four checks), and the cause is the RTL defect BUG-051 below.
- BUG-051 (fixed 2026-11-26, RTL, introduced by BUG-050 PHY-01; found by t_host_conn (ls), runs r4129 and r4312): at the end of a
  host port reset without the high-speed handshake, `m_usb2_spd` set the port speed again from the line state (K idle = low
  speed). With the PHY-01 reset row 00/0/00 the line is SE0 until the reset ends, so a low-speed device became a full-speed port
  (hsts.port_speed 1, full-speed row 01/1/00 instead of the low-speed row 10/1/00). Before BUG-050 the low-speed reset row let the
  line show the low-speed idle, which hid the dependency. Fix: keep the low-speed result of the connect, otherwise full speed
  (a failed chirp falls back to full speed as before). Checkpoints HCN-LSRST, HCN-LSENUM, HCN-LSROW detect it.
- Results after BUG-050 and BUG-051 (2026-11-26): rebuild of all 21 builds PASS (sim/rebuild_22.txt); full regression
  sim/regress_full_22.txt 189 runs, 188 PASS, 1 GENERATOR FAILED (t_rand_dev16_traffic seed 2, OSError Errno 22 while writing the
  .ops file; environment, rerun r4566-r4568 PASS, sim/regress_rand16_22.txt). The same Errno 22 hit t_fi_axi_err and
  t_dev_ulpi_traffic in sim/regress_full_21.txt; it moves between tests and is not caused by the RTL (cause not found; a transient
  lock of the file on Windows is suspected). Mutants M28 to M34 all KILLED by the intended check (sim/mutate_phy_22.txt,
  r4569-r4575): M28, M29, M31, M32 by a_phy_row; M30, M33, M34 by scenario checkpoints. header_check 50/50; testcase review
  effective 37, weak 12, not_run 1 (t_dir_clkstop, FND-015, unchanged).
- ENV-2026-11-26 (environment, not RTL): Errno 22 at the .ops write. All generators write through usb2lib.Seq.save; it now
  retries the open up to 6 times (0.5 s steps) and reports each retry on stderr. Generated content is unchanged (host_conn_ls_s1
  and dev_enum_bulk_dma compared byte for byte with the run inputs of r4500 and r4577); header_check 50/50. The root cause (which
  process holds the file) is not identified.
- CSR regeneration note (2026-11-25): the CSR generator repository moved to a5ec92e, whose rwi write priority differs from the
  delivered CSR (generated with a8fb7d4 plus a local VLSIT_SYNTHESIS guard). The new field was generated with a8fb7d4 and
  spec/csr/csr_guard.py; with the old workbook this flow reproduces the delivered file byte for byte, and the new file differs only
  by u2_hport.ext_vbus. The workbook tool `fill` drops row 9 "Register Event Sideband"; it was restored by hand.
