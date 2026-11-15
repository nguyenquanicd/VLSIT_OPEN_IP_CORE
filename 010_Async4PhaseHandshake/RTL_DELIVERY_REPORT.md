# RTL Delivery Report - VLSIT Asynchronous 4-Phase Handshake

| Item | Value |
|---|---|
| IP | Asynchronous four-phase request/acknowledge handshake with bundled data |
| Top module | `m_vlsit_ahs4_top` |
| Specification | `VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md` v0.2 (22 sections, check PASS) |
| Specification status | v0.2 does not yet describe `PARA_AHS4_ACK_DATA_MODE`, `i_ack_data`, or `o_ack_data`; the RTL is ahead of the specification (see sections 3.6 and 5) |
| Configuration delivered | CFG-BASE: `PARA_AHS4_DATA_W` = 32, `PARA_AHS4_SYNC_TYPE` = 2, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 0. Also rule-checked and linted: `PARA_AHS4_ACK_DATA_MODE` = 1, `PARA_AHS4_ACK_DATA_MODE` = 2, and `PARA_AHS4_DST_MODE` = 1 with `PARA_AHS4_ACK_DATA_MODE` = 2 |
| Rule baseline | VLSIT RTL Design Rules v2 (REF-001) plus the VLSIT RTL Generator skill rules |
| Date | 2026-11-13 |
| Author | Nguyen Quan (user) |
| Output folder | `C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake` |

## 1. Delivered files

| File | Role |
|---|---|
| `VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md` | Authoritative micro-architecture specification |
| `rtl/m_vlsit_ahs4_src.sv` | Source request and completion flags, payload register, acknowledge synchronizer; no FSM |
| `rtl/m_vlsit_ahs4_dst.sv` | Request synchronizer; transparent (mode 0) or captured (mode 1) forward data and acknowledge path; return payload disabled, transparent, or registered by `PARA_AHS4_ACK_DATA_MODE` |
| `rtl/m_vlsit_ahs4_top.sv` | Structural top, complete port list, `PARA_AHS4_DST_MODE` and `PARA_AHS4_ACK_DATA_MODE` plumbing |
| `rtl/filelist.f` | Compile order of the three delivered `.sv` files, made by `vlsit_lint_rtl.py filelist` |
| `rtl_change_review.md` | Plan version 1 change review, approval record, and final implementation report |
| `backup/rtl_snapshot_2026-11-13/` | Task-start RTL snapshot used as the code-change baseline |
| `lint/filelist_lint.f` | Elaboration/lint set: flow macro, eight plain cell models, reused wrapper, design RTL |
| `lint/lint_slang_d0_a0.log` | slang lint log, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 0 |
| `lint/lint_slang_d0_a1.log` | slang lint log, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 1 |
| `lint/lint_slang_d0_a2.log` | slang lint log, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 2 |
| `lint/lint_slang_d1_a2.log` | slang lint log, `PARA_AHS4_DST_MODE` = 1, `PARA_AHS4_ACK_DATA_MODE` = 2 |
| `lint/lint_verilator_d0_a0.log` | Verilator lint log, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 0 |
| `lint/lint_verilator_d0_a1.log` | Verilator lint log, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 1 |
| `lint/lint_verilator_d0_a2.log` | Verilator lint log, `PARA_AHS4_DST_MODE` = 0, `PARA_AHS4_ACK_DATA_MODE` = 2 |
| `lint/lint_verilator_d1_a2.log` | Verilator lint log, `PARA_AHS4_DST_MODE` = 1, `PARA_AHS4_ACK_DATA_MODE` = 2 |
| `RTL_RULE_CHECK_REPORT.md` | `vlsit_rtl_check.py check --report` output |
| `RTL_DELIVERY_REPORT.md` | This report |
| `figures/vlsit_ahs4_block_diagram.drawio` / `.svg` / `_spec.json` | Editable and rendered block diagram with its source spec |
| `figures/vlsit_ahs4_block_diagram_generator_report.txt` | Block-diagram generator result |
| `figures/vlsit_ahs4_wf001_success.json` / `.svg` | WF-001 success waveform, mode 0 |
| `figures/vlsit_ahs4_wf002_backpressure.json` / `.svg` | WF-002 backpressure waveform, mode 0 |
| `figures/vlsit_ahs4_wf003_reset.json` / `.svg` | WF-003 reset waveform |
| `figures/vlsit_ahs4_wf004_backtoback.json` / `.svg` | WF-004 back-to-back waveform, mode 0 |
| `figures/vlsit_ahs4_wf005_dst_reset.json` / `.svg` | WF-005 illegal destination-only reset waveform |
| `figures/vlsit_ahs4_wf006_capture.json` / `.svg` | WF-006 captured transfer waveform, mode 1 |
| `backup/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS_2026-11-11.md` | Original specification copy |
| `backup/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS_2026-11-12.md` | Pre-edit specification copy for the v0.2 change |

Reused and not delivered (shared library): `000_Common/rtl_lib/m_vlsit_afifo_cell_sync.sv`.

## 2. Check and lint results

| Check | Command | Result |
|---|---|---|
| Specification structure | `vlsit_spec_tool.py check VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md` | `PASS: 0 error(s), 22 section(s)` |
| RTL rule check | `vlsit_rtl_check.py check <dst> <src> <top> --report RTL_RULE_CHECK_REPORT.md` | `RESULT: PASS`, 0 ERROR, 2 WARN, 0 INFO |
| Filelist | `vlsit_lint_rtl.py filelist ... --top m_vlsit_ahs4_top` | 3 delivered files, top named; one expected WARN for the reused library module |
| Block diagram | `vlsit_spec_diagram.py check` then `build` | `PASS: the diagram spec is consistent`; build `PASS`, 0 findings, frame 640x220 (diagram still shows v0.2) |
| Lint, slang, four configurations | `slang --top m_vlsit_ahs4_top -Wextra -D VLSIT_SYNTHESIS <lint set>` with `(DST, ACK)` = (0,0), (0,1), (0,2), (1,2) | `Build succeeded: 0 errors, 0 warnings` in all four |
| Lint, Verilator, four configurations | `verilator_bin --lint-only -Wall --top-module m_vlsit_ahs4_top +define+VLSIT_SYNTHESIS <lint set>` with the same four override pairs | exit code 0, 0 errors, 0 warnings in all four (Verilator 5.053 devel) |
| Change metrics | `vlsit_rtl_change_metrics.py compare backup\rtl_snapshot_2026-11-13 rtl` | 156 baseline lines, 37 added, 6 deleted, 27.56 % |
| Waveform JSON | `vlsit_waveform_svg.py check` on WF-001 to WF-006 | `OK` for all six |
| Waveform SVG | `vlsit_waveform_svg.py render` on WF-001 to WF-006 | All six rendered |

The `vlsit_lint_rtl.py filelist` WARN says `m_vlsit_afifo_cell_sync` is instantiated but defined in none of the delivered files. This is expected: the wrapper is reused unmodified from `000_Common/rtl_lib` and is not an IP deliverable; `lint/filelist_lint.f` includes it for elaboration and lint.

## 3. Rule-ID report

### 3.1 Rules failed

None. `vlsit_rtl_check.py check` printed `RULES FAILED : none`.

### 3.2 Rules warned and justified

| Rule | Location | Finding | Reason and disposition |
|---|---|---|---|
| HIE-02 | `rtl/m_vlsit_ahs4_src.sv:17` | Module contains a cell instance and also logic | The block is a source-clock-domain functional block, not the design top. It must contain `u_sync_ack` in the source domain so that CLK-02 and HIE-07 hold (synchronizer cells only in a dedicated wrapper inside their domain). Moving the instance to the structural top would put a clock-domain cell outside the domain block; adding a third hierarchy level for one cell adds no function. Accepted by the designer on 2026-11-11. |
| HIE-02 | `rtl/m_vlsit_ahs4_dst.sv:18` | Module contains a cell instance and also logic | Same reason for `u_sync_req` in the destination domain. Accepted by the designer on 2026-11-11. |

`m_vlsit_ahs4_top` is instance-only, so the intent of HIE-02 for the design top is met.

### 3.3 Rules clean by script (67-rule checker)

`ARI-04, CMT-01, CMT-05, COM-02, COM-03, COM-04, COM-06, COM-07, ENM-01, ENM-03, ENM-04, ENM-05, ENM-06, FIL-01, FIL-02, FIL-03, FIL-04, FIL-05, FIL-06, HIE-01, HIE-03, HIE-05, NAM-07, NAM-08, NAM-09, NAM-TBL, P1, P11, P12, P13, P14, P17, P18, P19, P2, P20, P21, P22, P24, P25, P26, P27, P29, P3, P30, P4, P6, P7, PAR-01, PAR-02, PAR-03, R-019, R-027, R-032, R-035, R-036, R-038, R-071, R-072, SCP-01, SEC-8.1, SEQ-01, TYP-02, TYP-06`

Notes:

- `R-027` is clean because no design file contains a `VLSIT_SYNTHESIS` code branch. The macro appears only in the lint filelist to select the plain cell models; there is no simulation-only code in the delivered RTL and therefore no `WARN R-027`.
- `R-077` is clean because no CSR generator output exists.
- `PAR-03` produced no magic-number warning.
- `SEQ-02` and `SEQ-04` are no longer applicable: the source has no FSM (DEC-009, REQ-FUNC-009). Each flag is updated in its own `always_ff` with a defined reset value.

### 3.4 Rules covered by lint

| Rule | Meaning | Evidence |
|---|---|---|
| TYP-03 | `default_nettype none`, no undeclared identifier | slang and Verilator, 0 errors, four configurations |
| COM-05 | No combinational loop | slang and Verilator, 0 errors, four configurations |
| ARI-01 | Explicit operand sizes / width warnings | Verilator `-Wall`, 0 warnings, four configurations |
| P5 | No implicit net | slang and Verilator, 0 errors, four configurations |
| P8 | No multiple driver | slang and Verilator, 0 errors, four configurations |
| P23 | No combinational loop | slang and Verilator, 0 errors, four configurations |

### 3.5 Rules inspected by hand

| Rule | Result | Inspection evidence |
|---|---|---|
| NAM-01 | PASS (N/A) | No replicated names and no `gen_` replication of a module; the three generate blocks (`gen_dst_transparent`/`gen_dst_capture` and the `gen_ack_data_*` group) are mutually exclusive parameter selectors, not replications. |
| NAM-05 | PASS | The only active-low signals are the two resets, `i_rst_n_src` and `i_rst_n_dst`; no other active-low name exists. |
| COM-01 | PASS | `o_req`, `o_data`, `o_ack`, and `o_ack_data` each have exactly one driver in the elaborated configuration: the source flag registers and the continuous assignments, and in `u_dst` one branch of the mode generate and one branch of the return-payload generate. No net has two active drivers in one configuration. |
| SEQ-01 | PASS | Each `always_ff` has one edge-triggered clock and one asynchronous active-low reset; there is no inferred latch. |
| RST-01 | PASS | Every `always_ff` uses the same style: `posedge i_clk_*` with `negedge i_rst_n_*` and an active-low `if (!i_rst_n_*)` branch. |
| RST-02 | PASS (N/A by contract) | No reset synchronizer exists inside the IP; DEC-002 states that both resets are pre-synchronized by the SoC. |
| CLK-01 | PASS | CDC-001 and CDC-002 are one-bit level crossings through `m_vlsit_afifo_cell_sync`. The forward payload and the return payload are not synchronized; the forward payload is held by the source from launch until the cycle closes, and the return payload is valid while the acknowledge is high, captured in the destination domain when `PARA_AHS4_ACK_DATA_MODE` = 2. |
| P9 | PASS (N/A) | No function is declared in the delivered RTL. |
| P15 | PASS (N/A) | No clock gating and no clock used as data; `i_clk_src` and `i_clk_dst` drive only clock pins. |
| P16 | PASS | All sequential processes are rising-edge only; no dual-edge state. |
| P28 | PASS | No combinational logic is inserted around a synchronizer: `w_ack_s` drives flag conditions directly, `w_req_s` drives `o_req` (destination mode 0) or the capture register input (destination mode 1), the destination-mode acknowledge register sits before the source synchronizer, and the return-payload register is independent of both synchronizers. |
| PRT-01 | PASS with a specification gap | Port names follow the specification convention. `i_req`, `i_data`, `o_ack`, `o_req`, `o_data`, `i_ack` match section 6.2; `i_ack_data` and `o_ack_data` are the approved additions of plan version 1 and are not yet listed in section 6.2. |
| SCP-02 | PASS | Specification section 14.3 records top, filelist, frontend, parameters, libraries, memory flow, and lint configuration. |
| CHK-11 | PASS (N/A by DEC-006) | Section 11 is not required because the IP has no CSR; the mandatory 11.2 hardware use flow is present at lines 368-401. |
| R-068 | PASS (N/A to delivered RTL) | No cell model is delivered. The reused wrapper `m_vlsit_afifo_cell_sync` was not edited; the instances use its actual pins `i_clk_dst`, `i_rst_n_dst`, `i_d`, `o_q`. |
| R-040 | PASS (N/A) | No CSR was generated or requested (DEC-006); there is no `csr` folder. |
| R-049 | PASS | The two synchronizer crossings reuse `m_vlsit_afifo_cell_sync` (DEC-008); no duplicate synchronizer module exists. |

### 3.6 Not run

| Item | Status | Reason |
|---|---|---|
| Testbench and simulation | Not run | No testbench was requested (R-022); none was written. No simulation log, assertion table, or `waveforms_sim` evidence exists. |
| CDC verification, synthesis and metastability branches | Not run | Requires the testbench and the library metastability model. R-034, R-092, R-093 are therefore not demonstrated; this is a verification gap for sign-off, not a rule failure. |
| Synthesis, STA, area and power | Not run | Only lint elaboration was performed. PPA-001, PPA-002, PPA-003 remain unverified. |
| Formal verification | Not run | Specification section 15.1 marks it recommended, not mandatory for the first delivery. |
| CSR generation and CSV/DOCX/PDF export | Not applicable | No CSR and no document export were requested. |
| Specification consistency | Open | Specification v0.2 contains no requirement, port, parameter, or decision for the acknowledge-direction payload. The RTL change was approved as an RTL-only change; a v0.3 specification update is required to restore traceability. |
| Return-payload simulation | Not run | No testbench exists. The mode-2 capture (load on `i_ack`, hold through the acknowledge window) is verified by lint and inspection only. |

## 4. Reproduction commands

```powershell
python "C:\Users\PC\.claude\skills\vlsit-rtl-generator\scripts\vlsit_rtl_check.py" check "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl\m_vlsit_ahs4_dst.sv" "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl\m_vlsit_ahs4_src.sv" "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl\m_vlsit_ahs4_top.sv" --report "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\RTL_RULE_CHECK_REPORT.md"
python "C:\Users\PC\.claude\skills\vlsit-rtl-generator\scripts\vlsit_rtl_check.py" coverage
python "C:\Users\PC\.claude\skills\vlsit-asic-ip-microspec\scripts\vlsit_spec_tool.py" check "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md"
python "C:\Users\PC\.claude\skills\vlsit-asic-ip-microspec\scripts\vlsit_spec_diagram.py" check "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\figures\vlsit_ahs4_block_diagram_spec.json"
python "C:\Users\PC\.claude\skills\vlsit-asic-ip-microspec\scripts\vlsit_spec_diagram.py" build "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\figures\vlsit_ahs4_block_diagram_spec.json" --out-dir "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\figures" --gap-h 80 --gap-v 90 --seed 7
python "C:\Users\PC\.claude\skills\vlsit-rtl-generator\scripts\vlsit_lint_rtl.py" filelist "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl" --out "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl\filelist.f" --top m_vlsit_ahs4_top --force
python "C:\Users\PC\.claude\skills\vlsit-rtl-spec-change-implementer\scripts\vlsit_rtl_change_metrics.py" compare "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\backup\rtl_snapshot_2026-11-13" "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl"
```

Lint, from the `lint` folder. slang needs `C:\Tools\oss-cad-suite\bin` and `C:\Tools\oss-cad-suite\lib` on `PATH` (otherwise it exits with `STATUS_ENTRYPOINT_NOT_FOUND`). The exact commands are the first two lines of each log.

```powershell
cd "C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\lint"
$cells = @("../../000_Common/rtl_cells/VLSIT_CELL_SYNC_DFF_RN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_DFF_SN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_2FF_RN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_2FF_SN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_3FF_RN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_3FF_SN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_4FF_RN.sv", "../../000_Common/rtl_cells/VLSIT_CELL_SYNC_4FF_SN.sv", "../../000_Common/rtl_lib/m_vlsit_afifo_cell_sync.sv")
$rtl = @("../rtl/m_vlsit_ahs4_dst.sv", "../rtl/m_vlsit_ahs4_src.sv", "../rtl/m_vlsit_ahs4_top.sv")
$cfg = @(@(), @("-GPARA_AHS4_ACK_DATA_MODE=1"), @("-GPARA_AHS4_ACK_DATA_MODE=2"), @("-GPARA_AHS4_DST_MODE=1", "-GPARA_AHS4_ACK_DATA_MODE=2"))
foreach ($g in $cfg) {
  & slang.exe --top m_vlsit_ahs4_top -Wextra -D VLSIT_SYNTHESIS @g @cells @rtl
  & verilator_bin.exe --lint-only -Wall --top-module m_vlsit_ahs4_top +define+VLSIT_SYNTHESIS @g @cells @rtl
}
```

## 5. Integration notes

- Both resets must be asserted together for every reset event (DEC-003). A destination-only reset leaves the source with `reg_req` high and `o_ack` low unless the destination acknowledges the re-asserted request; the defined recovery is a source reset.
- The IP has one outstanding transaction and no timeout, FIFO, pipelining, busy output, or software-visible register.
- The source control is the two flags `reg_req` and `reg_ack`; there is no FSM (DEC-009). `reg_req` is set only at a launch edge and cleared when the synchronized acknowledge returns; `reg_ack` is set by that acknowledge and cleared when `i_req` falls.
- `PARA_AHS4_DST_MODE` selects the destination data path. Mode 0 (default) is transparent: `o_req` follows the synchronizer, `o_data` is the bundled payload, and `o_ack` returns `i_ack` unchanged. Mode 1 captures: `o_req` and `o_data` are registered one destination cycle after the synchronized request, and `o_ack` is the registered `reg_req && i_ack`.
- `PARA_AHS4_ACK_DATA_MODE` selects the acknowledge-direction payload. Mode 0 (default) disables the channel and drives `o_ack_data` to zero; mode 1 passes `i_ack_data` through combinationally; mode 2 captures `i_ack_data` in the destination domain while `i_ack` is high and holds it through the acknowledge window. None of the three changes the request/acknowledge timing.
- `i_ack_data` must be valid while `i_ack` is high. In mode 1 it is sampled at the destination clock edge that first observes `i_ack` high, so it may change only after the acknowledge has been accepted.
- Mode 1 creates a combinational path from `i_ack_data` to `o_ack_data` across both blocks; the integrator must constrain that path or select mode 2, which adds `PARA_AHS4_DATA_W` destination flops.
- The top always returns the acknowledge through `u_dst` (`w_ack`) so that the destination mode can select the transparent or the captured acknowledge path while the top stays structural.
- The payload is captured in `reg_data` at launch and held stable until the four-phase cycle closes; in mode 1 the destination keeps a second copy in its own clock domain.
- The two synchronizer instances use `PARA_AHS4_SYNC_TYPE` (legal 1..4) directly; the wrapper maps 1..4 to the 2-FF, 3-FF, 4-FF library cells.
- In the 1:1 aligned 10.3 example the mode-0 latency is 6 source cycles from launch to `o_ack` with a 12-cycle initiation interval; mode 1 adds two source cycles and gives 8 and 15.
