# Gate records: USB 2.0 controller block verification

An AI model never signs a gate (R-230). Each record needs a named human approver.

| Gate | Date | Approver | Decision | Evidence | Conditions |
|---|---|---|---|---|---|
| G0 plan approved | 2026-11-21 | the user (repository owner), in the planning session; engineer name still to be recorded (Q-002) | approved: "duyệt G0, chấp nhận Q-001 và Q-003, làm tiếp, mọi testcase phải được lưu làm bằng chứng" | `verification_plan.md`, `vplan.csv`, `requirements.txt`, `functional_matrix.md`, `plan_check.log` | Q-001 accepted (inventory = 75 REQ IDs); Q-003 accepted (targets of section 9); every testcase and its run are retained as evidence |

## Decisions recorded before G0

| Date | Decision | Source |
|---|---|---|
| 2026-11-21 | Target: 023_USB20_Controller, block level | user answer in the planning session |
| 2026-11-21 | This run stops at G0; no verification code before approval | user answer |
| 2026-11-21 | Environment: SystemVerilog BFM harness on Verilator with an independent Python model, no UVM | user answer |

## Not done in this run

- Scope matrix of the seven scenario dimensions per requirement and configuration (R-265): the `dimension` column of the vplan gives one dimension per obligation; the frozen matrix with N/A entries is produced after G0.
- Model contract, no-VIP agent contracts, tool baseline record, closure contract: after G0.
- No simulation, formal run or coverage measurement was made for this plan.
