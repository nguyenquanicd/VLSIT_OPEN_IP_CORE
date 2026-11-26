# Checker and model qualification (R-125, R-128, R-243, R-263)

Block `m_dvp_controller` (HDS v0.3, CSR v1.1, APB4 Issue D). AI-generated candidate (R-117); measured evidence is `../sim/final/qualification.log`. Not a sign-off.

## 1. What is qualified

`env/scoreboards/dv_dvp_checker.sv` (passive checkers and the HDS-derived reference model) is driven by `env/tb/tb_qual_checker.sv` with synthetic traffic and a scripted DUT. Expected values come from the HDS, CSR and APB4 text, never from the RTL (R-103, R-232).

Final result: **50 cases, 50 as expected, 0 unexpected, 10211 checks** (17 known-answer cases that must give 0 errors, 33 injected faults that must give at least one error from the intended checker).

| Area | Known answers | Injected faults |
|---|---|---|
| Pixel order, data, zero extension | K1 | F1 wrong data, F2 reorder, F3 drop, F4 duplicate, F5 phantom pop, F6 upper bits |
| Empty-read timeout (Q-ENV-1) | K2, K3 | F7a-d early/late/zero/error with data |
| CSR values, decode policy | K3, K5 | F8, F10a-d, F11c |
| APB4 protocol | K4 | F9a address change in wait, F9b PSTRB on read |
| Overflow and W1C | K6b, K12 (W1C inside the window) | F11a overwrite, F11b ovf not set, F18 (ovf set without event outside the window) |
| CDC-window FIFO acceptance | K13 (stale full), K15 (gated pop window) | F19 (certain entry lost), F20 (gated full without pop accepted) |
| DMA request (REQ-IF-004) | K7, K14 (watermark 0 re-arms) | F12a-d |
| Reset | K8 | F13 |
| Frame counter | K9, K9b | F14a-b |
| Mode guard, flush | K10, K10b, K11 | F15, F16, F17 |

## 2. Triage records (R-243: no oracle change without a record)

| ID | Observation | Root cause | Category | Resolution | Oracle weakened? |
|---|---|---|---|---|---|
| TR-Q-001 | First qualification run: known answers failed, no VSYNC frame armed | `bit act = ...` with an initializer inside an `always` block is a static variable initialised once | checker | declared at module level and assigned in the block | no |
| TR-Q-002 | Faults on the last transfer of a case "not detected" | the qualification bench read the error counter in the same time step as the last transfer, before the monitor processed it | testbench | verdict taken three APB cycles after the last transfer | no |
| TR-Q-003 | DMA errors leaked between cases; known-answer request outside the window | the scripted `o_dma_req` was left high across cases and raised later than the CDC window | testbench | request dropped in reset like a real DUT; request raised inside the window | no (window unchanged) |
| TR-C-001 | Slow consumer in continuous mode: data mismatch after a sample accepted under a stale full flag | model gap in the approved CDC-window design: a later drop was treated as certain and the only remaining entry could not be skipped | checker | uncertain entries may be accepted beyond the depth and are skipped at read time; occupancy checks use certain/possible bounds | no new tolerance outside Q-ENV-2; K13/F19 qualify it |
| TR-C-002 | `ovf set without an overflow` after a W1C raced a dropped sample | a drop inside the CDC window can set ovf after the clear (REQ-FUNC-003, REQ-IF-004) | checker | a clear within one window of the last drop leaves ovf "maybe set" | window only; K12/F18 qualify it |
| TR-C-003 | DMA re-arm "without crossing" in gated random tests | DUT-visible occupancy lags the model by the pixel-in-flight latency | checker | re-arm uses a lower bound of the DUT-visible occupancy; required requests still use the certain bound | window only; F12c still detected |
| TR-C-004 | Gated depth-4 random test: data mismatch | the SFIFO write happens a few APB cycles after the PCLK edge, so a pop inside that window can make room the model did not see | checker | a full-FIFO drop in gated mode is certain only when no pop happened in the window | window only; K15/F20 qualify it |
| TR-T-001 | Gated tests: the mode write was "rejected" | simulator artifact: 2-state Verilator never creates the power-up falling edge of an asynchronous reset, so a flop reset value was never loaded | tool | build uses `--x-initial-edge`; the bench starts `rst_n` high | no |
| TR-T-002 | Timeout race: repeated pixel | HREF left active in a free-running PCLK | testbench | HREF dropped after the single sample | no |
| TR-T-003 | Gated tests wrote mode and capture enable in one APB write | REQ-FUNC-004: the mode is accepted only while capture is disabled | testbench | mode first, wait beyond the CDC window, then enable, read back | no |
| TR-T-004 | Reset recovery: pending read "not aborted" | a sensor pixel satisfied the read before the reset | testbench | the pixel is sent while reset is asserted | no |
| TR-T-005 | Mode guard test: free-running PCLK in gated mode | bench violated the gated-profile contract | testbench | PCLK stopped before entering gated mode | no |
| TR-M-001 | Mutant M10 (flush guard forced to 1) survives all simulation tests | the guard is masked by the CSR (ERR-007) and the reset outlasts the in-flight pipeline | environment (no scenario separates it) | no check changed; a slower-PCLK flush sweep was tried, did not kill it and was removed; left open: the formal harness `f_flush` (bounded, depth 30) did not kill it either, so it is treated as unobservable at the ports but not proven equivalent | multi-clock formal property or equivalence check |
| TR-M-002 | Mutant M21 (`rwi` software-first CSR restored) is not detected by simulation | the repeated done pulse added with the hardware-first CSR (F-003, option C) masks it at the ports of the IP; each fix alone removes the stuck state | environment (defence in depth) | no check changed; M22 (both fixes reverted) is killed by `t_dvp_flush_race`; M21 is killed by the formal harness `f_csr` (k-induction) and by the generator golden test | none |
| Q-DMA-1 | After an ACK, watermark 0 then nonzero re-requests at once (RTL) while HDS is silent | specification gap | spec | the user accepted the RTL behaviour (decisions_and_gates.md); checker follows it | spec owner to add the sentence to REQ-IF-004 |

## 3. Limits of this qualification (R-100)

- The qualification bench fixes W=8, rising edge, active-high qualifiers and a 4-deep FIFO; other profiles use the same checker code but are exercised only by the DUT regression.
- The window tolerances (16 APB + 8 PCLK cycles; pop windows) make some detections weaker by design; each tolerance has a paired fault case that proves detection outside the window.
- The checker is qualified by the injected faults and by the 19-mutant analysis of the report (section 5.2); no formal qualification of the checker exists.
- The checker has run against the RTL only in the regression of [verification_report.md](verification_report.md).
