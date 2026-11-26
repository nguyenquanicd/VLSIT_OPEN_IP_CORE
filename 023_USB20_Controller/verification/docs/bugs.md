
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
- BUG-052 (fixed 2026-11-26, RTL, DEC-049; was FND-015 from review F-005, runs r2108 and r2109): a UTMI+ build could not leave
  suspend when the PHY stopped CLK-PHY (UTMI 1.05 p. 21 and p. 48 allow it and require the link to negate SuspendM without the
  clock): every wake decision was in m_usb2_spd (CLK-PHY). Fix (plan review/2026-11-26_utmi_clkstop_wake_change_plan.md, option B,
  answers Q1-Q4 recommended): new always-on m_usb2_utmilp in CLK-BUS (CDC-008, EXC-006, SVA-017); o_utmi_suspend_n = engine
  request OR wake request. Found while planning: G-1 a suspended host port ignored the line (remote-wake K lost, disconnect not
  reported) -> HP_SUSP exits on the K of the port speed and on SE0 after a 4 ms reversion window; G-2 device chirp 1.6 ms could
  end after TUCHEND (7.0 ms) with a PHY that starts its clock in 5.6 ms -> 1.2 ms. Two design points found during the RTL work:
  on a low-speed port the K is LineState 01b (J and K swap), and a high-speed device shows SE0 for up to 3 ms after the port
  suspends, so the detector never stores SE0 as the idle value and the host ignores SE0 during the window. Harness: t_dir_clkstop
  waited in CLK-PHY cycles while the clock was stopped (it could never pass); waits during clock stop now count CLK-BUS cycles
  (op IB); new ops PCLKD (PHY clock start delay) and XWAKE (SVA-017 activity); five scenarios dev, devrst, host, hostrw,
  hostdisc moved from the open tier to nightly; mutants M35 to M39.
- BUG-053 (fixed 2026-11-26, RTL, found by t_dir_clkstop host, hostrw, hostdisc, runs r4593-r4595): the speed engine dropped
  SuspendM in the first cycle of DV_SUSP / HP_SUSP. Status words and events reach CLK-BUS through the m_usb2_xreg scanner (one
  slot per cycle, up to 169 slots), so with a PHY that stops CLK-PHY 8 cycles after SuspendM falls hsts.port_susp_sts stayed 0
  for the whole suspend (poll failed after 3000 reads; the port itself was suspended and resumed correctly). The same applies to
  sts.suspended, the suspend interrupt and the ULPI low power entry. Fix: m_usb2_xreg output o_upd_busy (published word not yet
  pushed, pending event set or command clear, output stage full) through m_usb2_regs to m_usb2_spd; SuspendM falls only after 8
  quiet cycles in suspend (reg_sq). Not caught before because no scenario stopped the PHY clock and then read the status. A first form also raised SuspendM again whenever the crossing became busy during suspend (LineState is a published field):
  on a disconnect the SE0 raised SuspendM, the wake detector disarmed and could not re-arm on SE0, and the disconnect was never
  reported (hostdisc r4603); only the first fall of a suspend period waits now.
- FND-017 (checker weakness, fixed 2026-11-26): check_cdc_struct.py read the name of every port declared with a width as the type
  keyword ('logic'), so vector connections were never classified (26 of 99 ports of m_usb2_regs, 64 of 134 wires). Fixed parser;
  m_usb2_regs gets per-port domains (*_ph_* and o_xreg_busy on CLK-PHY). Result after the fix: 0 violations on 134 wires.
- Results after DEC-049 (2026-11-26): rebuild of all builds PASS; full regression sim/regress_full_25.txt 194 runs, 0 not passing
  (t_dir_clkstop 5 scenarios in the nightly tier, no longer open); parameter builds 0 FAIL (sim/run_builds_25.txt). Mutants M35 to
  M40 (sim/mutate_wake_25.txt): M35, M37 to M40 killed; M36 (no glitch filter) first SURVIVED because XWAKE checked 'at least
  0 wakes' and could not fail; XWAKE now checks the exact wake count and M36 is killed (r4819). header_check 50/50; testcase review
  effective 38, weak 12; report 187 of 188 rows pass (the one open row is the AI review record r0647). Priority waveforms: only
  tests 1 to 4 were regenerated (r4820 to r4823); tests 5 to 10 stopped at the disk guard R-279 (free disk 1.9 GB, limit 2.0 GB),
  so sim/waveform_index.csv still holds the pre-DEC-049 waveforms (r4576 to r4585) for those six.
- Open (2026-11-26): the host_port state diagram (spec/figures/usb2_fsm_host_port.drawio and .svg) was not redrawn for DEC-049; the layout check of the
  tool failed with crossings (36 arrows on 11 states), the old picture is kept and the spec figure caption says so; the JSON and the state table are current.
- CSR regeneration note (2026-11-25): the CSR generator repository moved to a5ec92e, whose rwi write priority differs from the
  delivered CSR (generated with a8fb7d4 plus a local VLSIT_SYNTHESIS guard). The new field was generated with a8fb7d4 and
  spec/csr/csr_guard.py; with the old workbook this flow reproduces the delivered file byte for byte, and the new file differs only
  by u2_hport.ext_vbus. The workbook tool `fill` drops row 9 "Register Event Sideband"; it was restored by hand.
