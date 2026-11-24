# DVP Controller — Consolidated Review Status

**Date:** 2026-11-23  
**Purpose:** Merge the conclusions from the specification review, RTL cross-check, and implementation report into one current status index. This is a documentation consolidation, not a fresh RTL sign-off.

## Current design baseline

The normative package is [HDS v0.3 and CSR v1.1](../spec/README.md). The RTL update added a programmable FIFO-empty timeout (reset 0xFFFF_FFFF), a frame counter, and FIFO flush. The current register map and software sequence are documented by the HDS and CSR package.

The older specification review was performed against HDS v0.2 (Draft) and its then-current RTL. Its findings remain useful as dated design and integration observations; they must not be read as 31 confirmed bugs in the current RTL. The old specification snapshot was later removed when the project was reduced to one normative package. Its generated finding list is retained under [reference/spec_review_2026-11-22](reference/spec_review_2026-11-22/).

## Review history

| Date | Review step | Result at the time | How to use it now |
|---|---|---|---|
| 2026-11-22 | [Specification review](REVIEW_DVP_Controller.md) | Conditional, score 2.76/5; 31 findings (19 Major, 11 Minor, 1 Observation), no Blocker. | Historical review of HDS v0.2. Several findings are scope or integration gaps, not RTL defects. |
| 2026-11-22 | [Independent RTL cross-check](rtl_crosscheck_2026-11-22__vlsit_impl_2026-11-22.md) | Qualified, not sign-off. Confirmed risks around DMA service liveness, gated-mode reset/CDC, bundled-data timing, and long APB empty-read waits. | Retain as the independent static rebuttal; it predates the latest recorded regression. |
| 2026-11-22 | [RTL implementation report](rtl_change_2026-11-22__rtl_ip_report.md) | Approved timeout/frame-counter/FIFO-flush changes were implemented. Static scanner item BUG-001 was rejected as a mutually exclusive generate-branch false positive. BUG-002 was rejected as an RTL defect under the selected DMA contract. | The DMA contract still needs integration agreement: the DMA must drain below the watermark or otherwise poll/service residual occupancy. |
| 2026-11-24 | [Verification report](../verification/docs/verification_report.md) | Consolidated verification package: checker qualification 50/50, regression 107/107 cases pass (Verilator), parameter legality 9/9 (finding F-001, RTL did not reject illegal parameters, fixed). Formal 10/10 tasks pass, mutation 20/22 killed (M10 and M21 survive), code coverage of the DVP-owned RTL line 93.3% / branch 96.3% / toggle 76.5%. Finding F-003 (stuck flush request) fixed in `m_dvp_buffer.sv` and in the regenerated CSR (generator 3.7). | This replaces the 2026-11-23 Icarus verification record, which was removed. No closure or sign-off. |

## Finding disposition against the current package

| Historical finding(s) | Current disposition | Remaining action |
|---|---|---|
| F-001, F-019 — no fixed camera workload or numeric throughput budget | Integration input remains open by design; the user will supply workload values. | Size FIFO and prove APB/DMA service rate against the selected resolution, frame rate, PCLK, and stall budget. |
| F-002 — missing frame service state | Partly addressed: frame counter and FIFO flush were added. The proposed line counter, frame-done interrupt, and snapshot mode were not selected. | No RTL change unless product requirements add those functions. |
| F-004, F-005, F-008 — DMA request re-arm and residual samples | Not classified as a demonstrated RTL bug. The current REQ behavior follows the approved watermark contract, but a DMA that stops after a short fixed batch can leave residual data without another request. | SoC/DMA integration must drain below the watermark or define a tail-service/polling contract. Any RTL protocol change needs a separate design decision. |
| F-007 — APB can wait on empty FIFO_DATA | Timeout is now software programmable and resets to 0xFFFF_FFFF; an empty read can still hold APB for a long time if software leaves that value. | Firmware/integration should program a bounded timeout appropriate to the APB topology. |
| F-009 — gated capture reset recovery/removal | Remains an RDC/STA sign-off item. The implementation followed the documented reset choice; the reports do not establish recovery/removal or physical timing closure. | Review reset release and the gated bundled-data crossing with RDC and STA constraints/results. |
| F-010, F-029 — gated-mode timing and sensor profile | The four-APB-cycle spacing and VSYNC-width constraints are integration assumptions, not runtime-checked RTL faults. | Validate the chosen sensor mode and clock ratio; preserve the timing requirements in integration constraints. |
| F-025 — no behavioral simulation | Superseded by the later 2026-11-23 Makefile record of 27 directed checks. The generation report's “not run” statement describes its earlier generation pass. | Treat the checked-in logs as the evidence for that run; this reorganization did not rerun simulation. |
| F-026 — verification depth | Partly addressed by the directed regression and its current checks. The separate verification-generator v2 package is planning collateral and has not entered G1 environment approval. | Continue the v2 process only after its architecture gate is reviewed; do not treat its plan as executed coverage. |
| F-003, F-006, F-011–F-018, F-020–F-024, F-027–F-031 | Primarily compatibility, product-scope, diagnosability, or integration sign-off proposals from the v0.2 review. | Keep as roadmap/integration items; none should be presented as a confirmed current RTL bug without new evidence. |

## Current evidence boundary

The [verification report](../verification/docs/verification_report.md) is the only verification record. The [RTL generation report](../spec/RTL_GENERATION_REPORT.md) records the earlier rule/lint/spec pass and explicitly limits that pass to its own date. Neither report claims CDC/RDC, STA, synthesis, DFT, sensor setup/hold, or SoC workload sign-off.

The verification package was consolidated on 2026-11-24 into one version under [verification/](../verification/docs/README.md); the earlier workspaces, run archives, snapshots and the Icarus testbench were removed. Gates G0, G1 and G3 are approved; G5 and G6 are pending.

## Review file map

- [Specification review report](REVIEW_DVP_Controller.md)
- [Generated v0.2 findings retained as reference](reference/spec_review_2026-11-22/vlsit_spec_2026-11-22.md)
- [Independent RTL cross-check](rtl_crosscheck_2026-11-22__vlsit_impl_2026-11-22.md)
- [Timeout/frame counter/FIFO flush implementation report](rtl_change_2026-11-22__rtl_ip_report.md)
- Supporting scan, scorecard, findings, and audit evidence: [reference](reference/)
