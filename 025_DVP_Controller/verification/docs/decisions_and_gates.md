# Decisions, questions and gate record — DVP Controller block verification

Single record of the human decisions of this verification flow (consolidated 2026-11-24). An AI model cannot approve a gate; every entry below was given by the named person.

## Gate record

| Gate | Decision | Approver | Date | Scope and condition |
|---|---|---|---|---|
| G0 — plan | APPROVED | Nguyen Quan | 2026-11-23 | Plan, vplan, requirement index and test list. Permitted input freeze and preparation of G1 only. |
| G1 — environment architecture | APPROVED | Nguyen Quan (verification lead and design lead) | 2026-11-24 | Environment architecture of [architecture.md](architecture.md). Permitted environment code, resource budget and checker qualification only. |
| G3 — block plan/model | APPROVED | Nguyen Quan (verification lead) | 2026-11-24 | Independent model/checker qualification ([checker_qualification.md](checker_qualification.md)) and the resource budget (per-run output cap 512 MiB). Permitted the stimulus campaign. Accepted limits: qualification uses synthetic traffic. |
| G5 — coverage closure | PENDING | verification lead | — | Not requested. Formal, mutation and coverage have been run (verification_report.md section 5) but M10 survives and the toggle target is unmet. |
| G6 — sign-off | PENDING | project lead | — | Not requested. No sign-off is claimed anywhere in this folder. |

## Decisions and answered questions (user Nguyen Quan)

| ID | Question | Answer (2026-11-24 unless noted) |
|---|---|---|
| Q-G1-1 | Synchronizer latency models (`+AFIFO_MSYNC_EN`, `+RSTSYNC_MSYNC_EN`) in the CDC tests | Enabled with fixed seeds (the case seed). Digital latency only; no analog metastability, no MTBF claim. |
| Q-G1-2 | Named approvers | Nguyen Quan records G1, G3, G5 and G6. |
| Q-G1-3 | R-119: send spec and interface-only RTL data to an external AI service | Approved. Data: HDS v0.3, CSR v1.1, public ports/parameters/widths. Service: Claude. No RTL body is used when expected values are derived (R-232). |
| Q-ENV-1 | Completion cycle of an empty FIFO_DATA read for timeout N > 0 | Error at access cycle N; N = 0 and N = 1 both error in access cycle 1. A sample available at the decision cycle wins and pops once. |
| Q-ENV-2 | Delay window for behaviour the HDS only calls CDC-latency dependent | Parameterized window, default 16 APB cycles + 8 PCLK cycles. A DUT value beyond the window is a failure to triage, not a reason to widen it (R-243). |
| Q-G3-1 | G3 approval and the per-run output cap | G3 approved; cap 512 MiB. |
| Q-DMA-1 | After an acknowledge, what does a watermark write of 0 (or above PARA_FIFO_DEPTH) do to the DMA re-arm state? HDS REQ-IF-004 is silent; the RTL returns to the waiting state. | Accept the RTL behaviour. The checker, qualification case K14 and the default `t_dvp_dma_rearm` step follow it. **Open action for the specification owner:** add to HDS REQ-IF-004: "Writing dvp_wmark = 0 or a value above PARA_FIFO_DEPTH resets the re-arm state; a later nonzero watermark requests again at once if the occupancy is already at or above it." The verification flow does not edit the HDS. |
| Q-DISK-1 | The host volume had 2-4 GiB free, below the reviewed 4 GiB stop threshold | Stop threshold lowered to 2 GiB (recorded in `env/config/resource_budget.json`). |
| 2026-11-24 | Consolidation of `verification/` | The user instructed: keep a single final consolidated version, delete all old and intermediate information. Done: legacy archives, earlier runs, snapshots, old Icarus testbench and superseded documents were removed; see [README.md](README.md). |
| Q-FLUSH-1 | Finding F-003: a CTRL write captured while a flush is pending can keep the request bit set when the hardware done pulse falls in the same cycle (stuck flush, only reset clears it). How to fix it? | Option C: the flush FSM re-issues the done pulse while the request is still set after done. In addition (user instruction 2026-11-24): an `rwi` field follows the hardware event over the software event in the same cycle, and the software and hardware events are separate per field. Applied in `m_dvp_buffer.sv` (FSM) and by regenerating `m_vlsit_csr_dvp.sv` with APB-CSR-Generator 3.7. The HDS (section 10.8, flush FSM) still has to be updated by the specification owner. |
| Q-DISK-2 | The final regeneration run stopped because free disk (about 2.3 GB) was below the stop threshold plus working set (R-279). Free space, lower the threshold, or stop? | The user chose to stop, delete the unused temporary files and summarize. The threshold stays at 2 GiB. The retained `sim/final/` is incomplete (verification_report.md section 0). |

## Deferred integration inputs

- System resolution, frame rate or peak valid PCLK, APB clock and maximum DMA service stall for PERF-003 and FIFO sizing (RISK-001).
- Named camera/datasheet revision and output mode for physical timing and compatibility closure (RISK-002).

No default workload or camera has been invented.
