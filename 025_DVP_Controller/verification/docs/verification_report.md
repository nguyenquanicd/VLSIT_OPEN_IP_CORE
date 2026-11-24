# DVP Controller block verification report

Block `m_dvp_controller` (HDS v0.3, CSR v1.1, APB4 Issue D). Verilator 5.053, plain SystemVerilog, 2026-11-24. Evidence: `../sim/final/` (one retained result set; `manifest.sha256` lists the hash of every source and output). AI-generated candidate (R-117): this report states measured results only (R-100). **It is not a closure and not a sign-off.**

## 1. Summary

| Item | Result |
|---|---|
| Checker qualification | **PASS**: 50 cases as expected (17 known answers, 33 injected faults), 10,211 checks |
| Regression | **107 of 107 cases PASS**, 0 fail, 560,124 checks, 0 testbench-assumption violations; 7 configurations, 14 simulation tests |
| Parameter legality | **PASS**: 9 of 9 elaborations as expected (finding F-001 fixed in the RTL and verified) |
| Scope review | PASS: 18 ports, none outside DVP capture + APB4 data endpoint + DMA REQ/ACK |
| Formal (`t_dvp_control_formal`) | **10 of 10 SymbiYosys tasks PASS**: `f_apb_data` and `f_dma_req` proven by k-induction (bmc, prove, cover); `f_ctrl` (depth 24) and `f_flush` (depth 30) bounded model checks with cover; all 15 cover statements reached (section 5) |
| Performance review (`t_dvp_performance_review`) | **not run**: needs the integrator's workload (RISK-001) |
| Mutation analysis | **20 of 22 mutants killed**, 2 survivors (M10 and M21, analysed in section 5.2); the unmutated control survives as it must |
| Code coverage (Verilator, `base` configuration, 49 cases) | DVP-owned RTL: **line 93.3%, branch 96.3%, toggle 76.5%**; the toggle target (80%) is not met (section 5.3) |
| Functional bins | 26 of 51 planned bins hit by name; 21 more bins hit under checker names that are not yet reconciled with the vplan (section 5) |
| Resources | one job; peak RAM 105.4 MB (budget 1 GiB); retained output of the regression step 1.12 MB; no waveforms |
| Gates | G0, G1, G3 approved (Nguyen Quan); G5, G6 pending, not requested |

## 2. Findings

| ID | Finding | Evidence | Status |
|---|---|---|---|
| F-001 | The RTL had no elaboration-time check of its parameters: PARA_DVP_DATA_W = 9 and PARA_FIFO_DEPTH = 1 or 3 elaborated without error, against REQ-PARAM-001 (power of two, at least 2) and ERR-006 (reject unsupported configurations). | first run: 3 of 9 legality cases mismatched; after the fix `sim/final/parameter_legality.log` shows 9 of 9 OK | **FIXED and verified.** `m_dvp_controller.sv` now reports an elaboration `$error` for an illegal PARA_DVP_DATA_W (not 8/10/12), PARA_FIFO_DEPTH (not a power of two >= 2), sample-edge/VSYNC/HREF polarity (not 0/1), PARA_AFIFO_CELL_TYPE (above 4), PARA_AFIFO_MEM_USE_MACRO (not 0/1) and PARA_FIFO_DATA_ADDR (not a 16-bit word-aligned address above 0x18). The branch sits under `ifndef VLSIT_SYNTHESIS` (rule R-027, same pattern as IP 023), so synthesis and lint do not see it. VLSIT rule check PASS and Verilator lint PASS (`lint/rtl_rule_check_2026-11-24.log`, `lint/verilator_lint_2026-11-24.log`). The 104-case regression and the qualification were rerun on the modified RTL. Only the first three illegal values are exercised by the legality test; the other illegal parameters were checked by hand with Verilator, not retained as a test. |
| F-002 | HDS REQ-IF-004 does not say what a watermark write of 0 or above the depth does to the DMA re-arm state; the RTL resets it. | decisions_and_gates.md, Q-DMA-1 | Decision: accept RTL behaviour. The specification owner still has to add the sentence to the HDS. |
| F-003 | A CTRL write issued while a flush is pending (ignored by ERR-007) can keep `dvp_ctrl.fifo_flush` set forever when the hardware done pulse falls in the cycle the software write is applied. The masked write data holds the request value of the SETUP cycle, and the generated CSR let a software write override the hardware clear of an `rwi` field; the flush FSM then waited in `WAIT_SW_CLEAR` for a clear that never came. Only a reset recovered; reads of FIFO_DATA stayed blocked and capture could not be enabled. | `t_dvp_flush_race` (new): failed at offset 19 (continuous) and 8 (gated) with both seeds on the original RTL; passes after the fix; mutant M22 (original defect restored) is killed by it | **FIXED and verified, decision Q-FLUSH-1.** (1) APB-CSR-Generator 3.7: an `rwi` field follows the hardware event over the software event in the same cycle, and a `w2c` field is cleared only by a write covering its own byte lanes; `m_vlsit_csr_dvp.sv` was regenerated with it (CSR_GENERATED.md). (2) Option C in `m_dvp_buffer.sv`: `WAIT_SW_CLEAR` returns to `CLEAR_REQ` while the request is still set, so the done pulse repeats. Each fix alone removes the stuck state (both measured, section 5.2); the HDS section 10.8 still has to describe the repeated done pulse (specification owner). A CTRL write one cycle earlier than the hardware clear can still re-set the request and start a second flush of an empty FIFO; this is not stuck and software polling sees it clear. It was not measured. |

No other DUT discrepancy was found by the 107 cases. Every other mismatch during development was a checker, testbench or tool defect, triaged in [checker_qualification.md](checker_qualification.md) (R-243).

## 3. Test results

Planned tests are those of `../tests/regression/testlist.yaml` (18). Review columns (R-244): no engineer or independent AI review has been recorded yet; every row is `pending`.

| Test | Cases | Pass | Configurations | Checks | Review |
|---|---:|---:|---|---:|---|
| t_dvp_continuous_e2e | 11 | 11 | base, d16, e1v0h0, w10e1v0, w12h0 | 14,659 | pending |
| t_dvp_gated_e2e | 9 | 9 | base, e1v0h0, w10e1v0, w12h0 | 6,696 | pending |
| t_dvp_apb_protocol | 3 | 3 | base | 2,631 | pending |
| t_dvp_timeout_boundary | 5 | 5 | base, d2 | 50,910 | pending |
| t_dvp_flush_handshake | 9 | 9 | base, d16, d2, d4 | 89,244 | pending |
| t_dvp_flush_race | 3 | 3 | base | 148,086 | pending |
| t_dvp_overflow | 13 | 13 | base, d16, d2, d4, w10e1v0, w12h0 | 52,627 | pending |
| t_dvp_reset_recovery | 3 | 3 | base | 6,279 | pending |
| t_dvp_dma_rearm | 5 | 5 | base, d16 | 9,465 | pending |
| t_dvp_endpoint_errors | 3 | 3 | base | 4,665 | pending |
| t_dvp_frame_counter | 7 | 7 | base, d2, e1v0h0 | 39,827 | pending |
| t_dvp_mode_guard | 5 | 5 | base, d4 | 11,490 | pending |
| t_dvp_profiles | 9 | 9 | base, e1v0h0, w10e1v0, w12h0 | 23,751 | pending |
| t_dvp_performance_characterization (constrained random, both modes) | 22 | 22 | base, d16, d2, d4 | 99,794 | pending |
| t_dvp_parameter_legality | 9 elaborations | 9 | 8/10/12 and 2/8/16 elaborate; width 9 and depth 1, 3 rejected | n/a | pending |
| t_dvp_scope_review | 1 | 1 | n/a | n/a | pending |
| t_dvp_control_formal | 10 tasks | 10 | f_apb_data (bmc, prove, cover), f_dma_req (bmc, prove, cover), f_ctrl (bmc depth 24, cover), f_flush (bmc depth 30, cover) | n/a | pending |
| t_dvp_performance_review | not run | - | - | - | needs workload |

Configurations: `base` W8, rising edge, VSYNC/HREF active high, depth 8; `w10e1v0` W10, falling edge, VSYNC active low; `w12h0` W12, HREF active low; `e1v0h0` W8, falling edge, both active low; `d2`, `d4`, `d16` FIFO depth 2, 4, 16. Directed tests use seeds 1-3 (1-2 outside `base`), the random test seeds 1-5 in `base` and 1-2 elsewhere, in continuous and gated mode. The 24-profile matrix of the plan is covered by 4 builds (not all 24 profile combinations).

Every case runs with the passive checker, the synchronizer latency models (`+AFIFO_MSYNC_EN=1`, `+RSTSYNC_MSYNC_EN=1`, seed = case seed) and known-answer self-checks of the test itself. Fixed timeout 2,000,000 ns per case.

## 4. Failure analysis by category

| Category | Count | Detail |
|---|---:|---|
| DUT (RTL) | 1 | F-001 (fixed) |
| Specification | 1 | F-002 |
| Checker | 5 | TR-Q-001, TR-C-001..004 |
| Testbench | 6 | TR-Q-002/003, TR-T-002..005 |
| Tool/simulator | 1 | TR-T-001 (`--x-initial-edge`) |

All records, causes and fixes are in [checker_qualification.md](checker_qualification.md); none of the fixes removed a check or widened a window beyond Q-ENV-2 without a paired fault case.

## 5. Formal, mutation and coverage

### 5.1 Formal (`env/formal/`, `env/scripts/dvp_formal.py`, logs `sim/final/formal_*.log`, `formal_summary.json`)

| Harness | Tasks | Result | What it states |
|---|---|---|---|
| `f_apb_data` (module `m_dvp_apb_data`) | bmc, prove, cover | PASS, k-induction proof, 3 of 3 covers reached | one pop only on a successful aligned read of an available sample; writes and misaligned accesses error and never pop; the empty read times out at access cycle N (N = 0 and 1 complete in cycle 1); a sample present in the first access cycle completes at once |
| `f_dma_req` (module `m_dvp_dma_req`) | bmc, prove, cover | PASS, k-induction proof, 4 of 4 covers reached | request state: set at the watermark, held until ACK, no re-request while above, re-arm after dropping below, watermark 0 raises nothing |
| `f_ctrl` (control path of `m_dvp_apb_service` with its real FIFOs, depth 2) | bmc (depth 24), cover | PASS, bounded only, 3 of 3 covers reached | mode guard: the mode changes only while capture is disabled before and after, never in the write that enables capture; capture is enabled only by a CTRL write that sets it |
| `f_flush` (module `m_dvp_buffer` with the real `m_dvp_capture`, FIFO depth 2) | bmc (depth 30), cover | PASS, bounded only, 5 of 5 covers reached | flush handshake: a pending flush shows an empty, full, zero-occupancy FIFO; when the flush completes the FIFO is empty and stays empty while capture is disabled (no sample in flight survives the reset); the done pulse only occurs with a pending request and capture off; a request that stays set after done gets another done pulse two cycles later (option C). The CSR/service contract is modelled as assumptions listed in the harness header (request held until done, capture and mode guards, gated-sensor spacing) |

`f_flush` k-induction (`prove`) was tried on the earlier harness and returned UNKNOWN after 25 minutes; it is not part of the task list, so the flush result is a bounded check.

Limits: the timeout is proven only for N <= 6 (the 32-bit value is bounded in the assumptions); `f_ctrl` ties the sensor clock to the APB clock, so no CDC behaviour and no reset-recovery claim; `f_flush` is also single-clock, so the AFIFO reset round trip across two real clocks is not modelled formally; the formal bins `cg_formal_*` of the plan are covered by the cover statements above but are not reconciled by name (section 6).

### 5.2 Mutation (`env/scripts/dvp_mutation.py`, logs `sim/final/mutation_*.log`, `mutation_summary.csv/json`)

Each mutant is a one-line edit of a temporary copy of the RTL; the simulation list stops at the first failing test and the relevant formal harness is run on the mutant. M00 is the unmutated copy (pipeline control).

| Result | Mutants |
|---|---|
| Control M00 | survives, as required (the harness does not flag a correct design) |
| Killed by simulation | M01 wrong sample edge, M02 toggle polarity, M03 overwrite on full, M04 pop on write, M06 timeout off by one, M07 data/timeout priority, M08 timeout without PSLVERR, M09 sign extension, M12 DMA re-arm, M13 DMA hold, M14 DMA zero watermark, M15 frame counter, M16 frame state, M17 HREF polarity, M18 VSYNC polarity, M19 decode |
| Killed only by formal | M05 pop on empty FIFO (benign at system level because the FIFO guards empty reads), M11 mode write accepted while capture is enabled |
| Killed by simulation and formal | M20 repeated done pulse removed (formal `f_flush`), M22 original defect restored (both fixes reverted: simulation `t_dvp_flush_race`) |
| **Survived** | **M10** premature flush (`w_flush_safe` forced to 1: the flush no longer waits for capture off and a quiescent source); **M21** `rwi` software-first CSR restored while the repeated done pulse is kept |

Score: 20 of 22 mutants killed (90.9%). The plan target is 100% of the listed critical mutants killed with equivalent and surviving faults separately reviewed, so the target is **not met**.

M10, analysis (reasoning from the RTL, not a measurement; triage record TR-M-001): the CSR path masks a flush request while capture is enabled (`m_dvp_apb_service.sv`, ERR-007), so the `~i_capture_en` term of the guard cannot be reached from the DUT ports. The source-quiescent term only delays the start of the reset by the in-flight pipeline (about three PCLK cycles), and the selected FIFO reset is then held for a full busy round trip, longer than that pipeline, so a sample in flight is cleared by the reset either way. The sensor in flight during the flush is exercised by the 12-iteration loop of `t_dvp_flush_handshake` (continuous mode) and by randomised synchronizer latencies; none of them distinguishes the mutant. The new harness `f_flush` (bounded depth 30, covers the stale-sample and empty-after-flush properties) did not kill it either; a first counterexample of that harness was a harness defect (capture and request both set in the first cycle after reset) and was removed by a constraint, not a DUT result. A trial that also swept the sensor clock to 2x, 4x and 8x slower than the default did not kill it either and was removed again, so the retained testbench is the one of the result set. M21, analysis: the two fixes of F-003 are independent and each removes the stuck state, so reverting only the CSR priority is masked by the repeated done pulse and no test can see it from the ports (measured: `csr_fix_only`, `fsm_fix_only` and both fixes pass `t_dvp_flush_race`, only neither fails). M21 is a defence-in-depth survivor; the CSR priority itself is checked in the generator's own golden test (mutant `rwi: software write wins over a hardware load`). The `WAIT_SW_CLEAR` to `CLEAR_REQ` branch is not reachable from the bus once the CSR is hardware-first (it is the uncovered branch at `m_dvp_buffer.sv:185`) and is verified by formal only.

M10 is therefore treated as a redundant defensive guard that is not observable at the ports, **not proven equivalent**; a formal equivalence or a multi-clock property of the flush handshake is the way to settle it and is open work. No claim is made that the guard is useless.

### 5.3 Code coverage (`env/scripts/dvp_coverage.py`, `sim/final/coverage_summary.txt`, `coverage_uncovered.txt`)

Verilator `--coverage` on the `base` configuration (49 cases: 13 directed tests x 3 seeds plus 10 random cases; all pass). Points are line, branch and toggle points as Verilator defines them; FSM state and transition coverage is not measured by this tool.

| Group | Line | Branch | Toggle |
|---|---:|---:|---:|
| DVP-owned RTL (`m_dvp_*`, `m_vlsit_csr_dvp`) | 84/90 = 93.3% | 131/136 = 96.3% | 2977/3892 = 76.5% |
| Shared 000_Common/001/002 modules reused by this IP | 54/59 = 91.5% | 117/132 = 88.6% | 1232/1972 = 62.5% |
| Verification environment (checker, BFMs, testbench) | 200/211 = 94.8% | 264/310 = 85.2% | 907/1002 = 90.5% |

Plan targets (>= 90% line and branch, >= 80% toggle) are met for line and branch of the DVP-owned RTL and **not met for toggle (76.5%)**. The 11 uncovered DVP-owned line/branch points (listed in `coverage_uncovered.txt`) are: parameter-selected arms that the `base` configuration cannot reach (opposite VSYNC/HREF polarity and the asynchronous register-clock option, covered or not applicable in the other configurations but not measured there); the CSR option arms for the asynchronous register clock (`PARA_ASYNCHRONOUS` is fixed to 0 in this IP) and for `i_protect_en` / `i_slverr_en` (tied off through `m_vlsit_tie`); and `default` arms of the flush and DMA state machines, a buffer `case` and the occupancy mux, which legal stimulus does not reach (not proven unreachable). Low toggle values are mostly wide counters, address and data bits that never take both values (for example `m_dvp_apb_data` 57.0%, `m_dvp_dma_req` 61.1%, SFIFO pointers 31-34%); no toggle exclusion was reviewed. The coverage run measures `base` only; the other six configurations are not merged.

### 5.4 Functional bins

`sim/final/coverage_bins.json` holds 47 bins hit by the checker. Of the 68 distinct entries of the `coverage_bin` and `combines` columns of `vplan.csv`, 26 match a hit bin by name; the others are named differently in the checker, are the 5 formal bins (now covered by the formal cover statements, section 5.1), 2 static-review bins, or are not collected. Reconciling the two catalogs is open work (R-252); no functional-coverage percentage is claimed.

## 6. Exclusions, waivers, deviations, VIP

No exclusion, waiver or protocol deviation is recorded. No VIP was created or changed; the APB requester/monitor and the sensor source are project-local scoped BFMs. No signal of the DUT is forced or read internally (R-258).

## 7. AI provenance (R-117, R-119)

All environment code, tests and documents here were produced by the Claude model under Nguyen Quan's direction; data sent to the model: HDS v0.3, CSR v1.1, RTL ports and, for failure analysis only, RTL excerpts (decision Q-G1-3). Expected values derive from the HDS, CSR and APB4 text. Human approval exists for G0, G1, G3 only.

## 8. Residual risk and what was not checked

- The missing HDS sentence (F-002) is open. F-001 is fixed, but the other illegal parameters (polarity, cell type, macro select, FIFO address) were checked once by hand and are not part of the retained legality test.
- Formal is bounded where stated in section 5.1; mutation has one survivor (M10) and 19 hand-chosen mutants cannot represent every fault class; toggle coverage is below target and coverage was measured on `base` only. A missed class of fault in the RTL is possible.
- The flush handshake has no formal property; its safety rests on simulation (9 cases, 89,244 checks) and the unresolved M10 analysis.
- CDC behaviour is checked inside a modelled window (16 APB + 8 PCLK cycles; pop windows) with digital latency models; there is no analog metastability, MTBF or STA evidence.
- 4 of the plan's 24 compile-time profiles are built; gated mode needs the sensor contract (>=4 APB cycles between pixels and for VSYNC), which the BFM guarantees by construction.
- PERF-003 (FIFO depth for a real workload) and any named camera mode are not verified.
- The checker was developed against this RTL's behaviour in places where the HDS leaves latency open (decisions Q-ENV-1, Q-ENV-2, Q-DMA-1).
- The HDS working copy differs from the G0-hashed copy: by 16 bytes before 2026-11-24 (probably figure links) and, since then, by the edit for F-003 (section 10.8, REQ-FUNC-010, DEC-033/034). The edited HDS is not re-approved at G0; the checker and the new tests follow the edited text.
- Replay: `dvp_regress.py` reproduces the result set; no independent cold replay on another machine was done.
