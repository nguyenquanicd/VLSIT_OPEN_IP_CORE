# APB I2S testbench and verification report

Design under test: `m_vlsit_apb_i2s_top` (`../rtl`, filelist `../rtl/filelist.f`). Specification: `../spec/VLSIT_APB_I2S_HDS.md`.
The testbench is derived from the specification (requirements, section 10.3, 11.4, 15) and from the standards (APB: Arm IHI 0024 issue D;
I2S: Philips bus specification 1996). The RTL was read only for port names, widths and parameters (R-023). Rules followed: R-022 to R-026,
R-033, R-034, R-047, R-048, R-088 to R-094 of the `vlsit-rtl-generator` skill.

## How to run

```sh
make quick      # one build, synthesis branch + metastability seeds 1, 2, 3 (logs/cdc/)
make regress    # quick + the configuration matrix (logs/matrix/, logs/summary.txt)
make wf         # 17 waveform scenarios, WaveJSON/SVG and comparison (waveforms_sim/)
make cov        # coverage build, three seeds, merged report (logs/coverage_report.md)
make mutants    # 17 injected-bug copies of the RTL and the suite on each (logs/mutants.txt)
make evidence   # vlsit_sim_evidence.py check of the waveforms and of the CDC logs
```

Without `make`: `sh regress.sh`, `sh run_wf.sh`, `sh run_mutants.sh`, `sh build.sh <name> [--syn] [--cov] [--wave] [-GPARAM=v]`.
One run of the executable: `build/<name>/Vtb_i2s.exe +TEST=<ALL|T001..|RND|FLOW> +SEED=<n> +N=<random iterations> +AFIFO_MSYNC_SEED=<n>
+AFIFO_MSYNC_EN=1 +RSTSYNC_MSYNC_SEED=<n>`; the last line of a regression log is `assertion failures: 0, assertions never exercised: 0` and
the log carries `SIM-BRANCH: synthesis` or `SIM-BRANCH: metastable seed=<n>`. Simulator: Verilator 5.053 (`--binary --timing`).
The build options are command-line arguments of `build.sh`, not environment variables (the msys shell of this machine drops them).

## Files

| Path | Content |
|---|---|
| `tb/tb_i2s.sv` | top: clocks, DUT, APB requester, two serial devices, scoreboard, DMA checks, report |
| `tb/i2s_apb_chk.sv` | 22 APB protocol and register-access assertions (IHI0024D clauses) |
| `tb/i2s_dev.sv` | serial device model (master or slave, capture or source) with 8 serial assertions |
| `tb/i2s_scn.svh`, `tb/i2s_tests.svh`, `tb/i2s_wf.svh` | scenario tasks, the tests of section 15, the waveform scenarios |
| `tools/` | `wf_tool.py` and `wf_report.py` (round 1 comparison), `wf_figures.py` with `wf_figures2.py`, `wf_spec_update.py`, `wf_report2.py` (redraw and index), `mutate.py`, `cov_report.py` |
| `logs/cdc`, `logs/matrix`, `logs/wf`, `logs/mutants`, `logs/cov` | evidence logs |
| `waveforms_sim/` | VCD, WaveJSON and SVG of the 17 waveforms and `waveform_compare.md` |

## Assertions (48, with hits)

22 APB (`APB-01` to `APB-22`), 8 serial (`SER-01` to `SER-08`), 12 scoreboard (`SB-01` to `SB-12`) and 6 DMA (`DMA-01` to `DMA-06`).
A run fails when an assertion fails or never fires; assertions that a build cannot reach (absent unit or feature) are named in the code
(`ser_na`, `sb_na`, `dma_na`). The full table with the hit counts is printed at the end of every log, for example `logs/cdc/synthesis.log`.
`APB-19` is a recommendation of IHI0024D 3.4 (PSLVERR low outside the completion cycle) and is counted, not failed: 12 cycles per run.

## Tests

Focused tests of one function first, integrated flows last (R-048). 23 test groups and the random and integrated runs:
TEST-001 reset and capability; TEST-018 APB access (byte lanes, protection, error response); TEST-019 data registers; TEST-003/005 transmit
formats; TEST-004/005 receive formats and slave at ratio 8; TEST-006 widths, alignment, packing; TEST-007 lines and masks; TEST-008 mask change and
tri-state; TEST-009 underrun; TEST-010 overrun; TEST-011 watermark (with the boundary level); TEST-012 sync error and hung clock; TEST-013 dividers;
TEST-014 shared clock; TEST-015 on-demand; TEST-016 interrupts; TEST-017 DMA; TEST-020 resets and flush (busy while a flush is pending);
TEST-021 APB clock ratios; TEST-022 absent features; TEST-023 configuration of a running unit; TEST-RND constrained random (`+SEED`, `+N`);
FLOW-001 duplex stream with DMA and interrupts. One run of the full build executes 1457 checks.

## Seeds, branches and configurations

| Run | Result |
|---|---|
| full build, synthesis branch (`logs/cdc/synthesis.log`) | PASS, 0 failures, 0 assertions never exercised |
| full build, metastability model seeds 1, 2, 3 (`logs/cdc/metastable_seed*.log`) | PASS, PASS, PASS |
| matrix `lines2` (2 lines, depth 8), `dual` (4 lines, depth 64), `mic` (no TX, 4 lines), `min` (minimum build), `rxonly`, `txonly`, `sync3` (synchronizer depth 3) | PASS on every build (`logs/summary.txt`), each with 0 failures and 0 assertions never exercised |

`vlsit_sim_evidence.py check ../spec/VLSIT_APB_I2S_HDS.md waveforms_sim --logs logs/cdc`: 0 errors (17 warnings, one per DIFFERENT waveform).

## Waveform evidence

17 of 17 waveforms of section 10.3 are simulated (synthesis branch, one VCD per scenario, `run_wf.sh`). Round 1 compared the original figures with the
simulation: all 17 were DIFFERENT (`waveforms_sim/waveform_compare_round1.md`: the figures disagreed with the RTL by a cycle or a signal, were drawn at a
scale the IP cannot be configured to, or used helper signals). The designer asked to correct the figures according to the RTL, so the 17 figures of the
specification were redrawn from the simulated windows (`tools/wf_figures.py`, `tools/wf_spec_update.py`; the old figures are in
`../rtl/spec_original/figures_before_redraw`). The index `waveforms_sim/waveform_compare.md` therefore says MATCH for all 17 because the figure is the simulated
window; this is a statement that the figures follow the RTL, not an independent comparison. `vlsit_sim_evidence.py check` reports 0 errors and 0 warnings.
Behaviors that the figures now show and that the old figures did not: the register events one cycle before PREADY, PSLVERR held until the next SETUP (a known
deviation of the generated CSR, APB-19), the DMA request returning two cycles after the acknowledge falls, busy high while a flush is pending.

## Coverage

See `logs/coverage_report.md` (status `baseline_only`: no target was set). Metrics: line, branch and toggle (Verilator records branch points with the
line instrumentation; it has no separate condition metric). Scope: the DUT own RTL, the generated CSR, the reused library and the testbench are reported
separately; the figures of the DUT own RTL are in the table of that file and are not copied here.

## Injected bugs (mutation)

17 copies of the RTL with one bug each (`tools/mutate.py list`), the suite run once on each (`logs/mutants_round1.txt`, `logs/mutants_round2.txt`):

| Result | Bugs |
|---|---|
| caught in round 1 (11) | M01 I2S frame sync not early, M02 left-justified sync early, M03 status OR instead of AND, M04 overrun cause lost, M06 tri-state ignored, M07 divider off by one, M11 pack halves swapped, M12 alignment inverted, M13 sync error lost, M16 pin not the OR of the status, M17 full flag never set |
| not caught in round 1, test gap closed (5) | M09 and M10 watermark boundary, M14 hung timeout x128 instead of x256, M15 busy without the pending flush, M05 (the build failed once under load, then caught): boundary tests added to TEST-011, TEST-012, TEST-020; all four caught in round 2 |
| not caught (1) | M08 DMA request raised while the acknowledge is high: equivalent under the legal handshake, because the acknowledge only follows a request and the FSM is in the request state, not in IDLE, then; an illegal stimulus (acknowledge without request) would be needed |

Result: 16 of 17 caught, 1 equivalent.

## Findings

| ID | Finding | Analysis (R-026) | Status |
|---|---|---|---|
| F-1 | with `i_slverr_en` = 0 a partial-strobe write updates only the strobed lanes (`0xFFFF5678`), the specification said whole word | cause: the specification (old generator text); generator 3.6 REQ-ERR-004 states the lane write | specification corrected (DEC-021), test follows it |
| F-2 | synchronizer depth 3: a slave at ratio 8 receives data after the device sampling edge | cause: TBD-001 (minimum ratio versus depth); not a bug | test uses ratio 12 for depth > 2; TBD-001 stays open |
| F-3 | two RTL defects found by the testbench: false frame sync error just after a window open, and a missed early frame sync edge before the window open tick | cause: RTL (`m_vlsit_i2s_frame.sv`, flop `reg_win_open_d`, `reg_act_seen`) | fixed, passes on 3 seeds |
| F-4 | APB-19 recommendation not met: PSLVERR stays high until the next SETUP (12 cycles per run) | cause: generated CSR (generator DEV-001) | recommendation only; figure WF-002 differs |
| F-5 | waveform figures differed from the RTL (see waveform evidence) | cause: figures | figures redrawn from the RTL on 2026-11-21 |

## Not verified

TEST-023 service-latency sweep and performance (PERF) targets; formal proof; CDC and RDC tool runs (only the simulation branches); synthesis and timing;
gate-level simulation; coverage target (none set); a slave with a bit clock slower than the minimum ratio; I2S formats other than Philips have no standard
in the converted collection (only the specification text and the databook-derived rules).
