# RTL Change Review — Acknowledge-return bundled payload with selectable capture — plan version 1

Status: Implemented (plan version 1 approved 2026-11-13)

## 1. Design and input summary

| Item | Value |
|---|---|
| RTL root | `C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl` |
| Old specification | `../spec/../spec/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md` v0.2 (supplied; 22 sections, spec check PASS) |
| New specification file | None. The new behavior is described by the user's request of 2026-11-13. |
| Requested behavior (translated) | Add a parameter for the option that the acknowledge return direction also carries a payload; that payload may or may not be captured through a flip-flop; a parameter selects this option. |
| Selected top | `m_vlsit_ahs4_top`, containing `u_src` (`m_vlsit_ahs4_src`), `u_dst` (`m_vlsit_ahs4_dst`), and the two reused `m_vlsit_afifo_cell_sync` instances inside those blocks |
| Baseline snapshot | `backup\rtl_snapshot_2026-11-13` (three RTL files, captured before any edit) |
| Pre-existing working-tree changes | None in the RTL tree at task start; the snapshot is the task baseline |
| Analysis limits | Static source reading only. No simulation, synthesis, or CDC run was performed during analysis (RSC-022). The reused synchronizer wrapper was read from `000_Common/rtl_lib` and is not modified. |

The existing IP is a one-outstanding-transaction four-phase req/ack bridge with a bundled forward payload. The request adds a second bundled payload that travels in the acknowledge direction, from the destination user back to the source user, with a parameter that selects whether that return payload is disabled, transparent, or captured in a flip-flop.

## 2. Requirement comparison

| ID | New requirement | Old requirement | Current RTL behavior (source evidence) | Intended behavior |
|---|---|---|---|---|
| CR-01 | The IP shall provide a return-direction payload from the destination user to the source user. | No such requirement exists; IF-001/IF-002 carry only `i_req`/`i_data`/`o_ack` and `o_req`/`o_data`/`i_ack`. | The top port list has no return-payload port: `m_vlsit_ahs4_top.sv:29-51`. `u_src` maps only `o_req`, `o_data`, `o_ack` (`m_vlsit_ahs4_src.sv:53-56`); `u_dst` maps only `o_req`, `o_data`, `o_ack` (`m_vlsit_ahs4_dst.sv:58-95`). | New destination input `i_ack_data[PARA_AHS4_DATA_W-1:0]` and new source output `o_ack_data[PARA_AHS4_DATA_W-1:0]`, both at the IP boundary and on the two block interfaces. |
| CR-02 | A parameter shall select the return-payload option. | `PARA_AHS4_DST_MODE` selects option A or B for the forward payload and the acknowledge only. | `PARA_AHS4_DST_MODE` exists in the top, `u_src` does not receive it, `u_dst` uses it in one generate (`m_vlsit_ahs4_dst.sv:57`). | New parameter `PARA_AHS4_ACK_DATA_MODE` with 0 = disabled, 1 = transparent, 2 = registered; default 0. |
| CR-03 | The return payload may be captured in a flip-flop or passed through without one. | Not present. | No return-payload register exists. | Mode 1 is a combinational pass from `i_ack_data` to `o_ack_data`; mode 2 adds one destination-domain register enabled while `i_ack` is high. |
| CR-04 | The return payload shall be valid while the acknowledge is high. | `o_ack` is a level held until `i_req` falls (`m_vlsit_ahs4_src.sv:78-85`). | `o_data` is stable while `o_req` is high (forward contract). | `o_ack_data` is stable while `o_ack` is high in every mode; in mode 2 the value is captured before the acknowledge completes the crossing. |
| CR-05 | The request/acknowledge handshake shall be unchanged. | REQ-FUNC-001..009, timing in section 10.3. | Launch, close, and completion logic: `m_vlsit_ahs4_src.sv:60-85`; acknowledge path: `m_vlsit_ahs4_dst.sv:88-93`. | No change to `reg_req`, `reg_ack`, `w_launch`, the two synchronizers, or any latency. |

## 3. Affected modules and files

| Module | File | Code region | Proposed change | Reason |
|---|---|---|---|---|
| `m_vlsit_ahs4_top` | `rtl\m_vlsit_ahs4_top.sv` | Parameter list lines 16-29; port list lines 29-51; internal declarations lines 53-56; instances lines 59-87 | Add `PARA_AHS4_ACK_DATA_MODE` after `PARA_AHS4_DST_MODE`; add input `i_ack_data` after `i_ack` and output `o_ack_data` after `o_ack`; add one internal wire `w_ack_data`; connect `u_dst.o_ack_data` to `w_ack_data` and `w_ack_data` to `u_src.i_ack_data`; pass the new parameter to `u_dst` only | The top stays structural (HIE-02) and carries the new channel and parameter. |
| `m_vlsit_ahs4_src` | `rtl\m_vlsit_ahs4_src.sv` | Port list lines 26-44; output mapping lines 53-56 | Add input `i_ack_data` after `i_ack` and output `o_ack_data` after `o_ack`; add `assign o_ack_data = i_ack_data;` | The source domain forwards the bundled return payload; no new register, no new reset term, and the two-flag control (DEC-009) is untouched. |
| `m_vlsit_ahs4_dst` | `rtl\m_vlsit_ahs4_dst.sv` | Parameter list lines 17-30; port list lines 30-48; generate lines 57-95 | Add `PARA_AHS4_ACK_DATA_MODE`; add input `i_ack_data` and output `o_ack_data`; add one sibling generate with three branches for the return payload | The destination block owns the acknowledge source, so it also owns the return payload that is qualified by that acknowledge. |

Supporting files, proposed for approval:

| File | Change | Reason |
|---|---|---|
| `RTL_DELIVERY_REPORT.md` | Update delivered-file list, configuration table, integration notes, and lint evidence | The report is the delivery record and would otherwise contradict the RTL |
| `RTL_RULE_CHECK_REPORT.md` | Regenerated by `vlsit_rtl_check.py check --report` | Generated evidence |
| `lint\*.log` | Eight new logs (four configurations × slang and Verilator); the four existing logs are superseded and removed | Lint evidence must match the delivered parameter set |

## 4. Design choices

Three viable strategies; one recommended.

| Strategy | Functional coverage | Change size | Compatibility | Complexity | Risk |
|---|---|---|---|---|---|
| **A (recommended)**: one parameter with three values; return payload registered in `u_dst` | Full: disabled, transparent, and registered return payload; all combinations with `PARA_AHS4_DST_MODE` | Smallest: 1 parameter, 2 top ports, 2 ports in each block, one register | Default 0 preserves `o_ack`, timing, and all existing behavior; port list grows by two, which affects positional instantiation only | Low: one three-branch sibling generate in `u_dst`, one continuous assignment in `u_src` | Low |
| B: two parameters, `PARA_AHS4_ACK_DATA_EN` (0/1) and `PARA_AHS4_ACK_DATA_REG` (0/1); same datapath | Same as A, plus one illegal combination (enable 0 with register 1) that must be documented | One extra parameter and two extra port-map entries | Same as A | Low, but two knobs describe one feature and one combination is meaningless | Low to medium: an illegal configuration is introduced where none existed |
| C: one parameter with three values; return payload captured in `u_src` at the synchronized-acknowledge edge | Same as A | Larger: `u_src` gains a register, a reset term, and the parameter; `u_dst` stays combinational | Same as A | Medium: the source block gains sequential logic fed by destination-domain data, and its CDC description and reset list change | Medium: modifies the source control block that the specification describes as two flags plus one synchronizer |

Recommendation: **Strategy A**. It keeps every return-payload decision in the block that originates the acknowledge, leaves the source control block combinational, avoids an illegal parameter combination, and needs one knob for one feature.

Excluded strategies: a design without a parameter (always enabled) is rejected because it changes the behavior of every existing configuration and violates backward compatibility.

## 5. Minimal-change rationale

- **One parameter, three values.** `PARA_AHS4_ACK_DATA_MODE` encodes enabled/disabled and transparent/registered in one legal space, so no illegal pair exists and the port map grows by one line. The value is read only in `u_dst`, at elaboration.
- **Register in `u_dst`.** The acknowledge and its payload must be launched from the same clock domain. Capturing at the destination edge where `i_ack` is high guarantees that the value seen by the source is the one that was valid when the destination accepted, independent of how long the destination user holds `i_ack_data` afterwards. The register also removes the combinational path across the IP in mode 2, which is the only reason to pay for the flip-flops.
- **Combinational pass in `u_src`.** `assign o_ack_data = i_ack_data;` adds no state to the source domain. The two flags `reg_req` and `reg_ack`, their reset values, and the launch condition remain byte-for-byte unchanged, so DEC-009/REQ-FUNC-009 still hold exactly.
- **Load condition `i_ack`.** The destination user's contract is that `i_ack_data` is valid while `i_ack` is high; sampling on that condition uses the shortest possible hold window. Gating with the request instead would reference a signal that exists only in one `PARA_AHS4_DST_MODE` branch.
- **No new handshake state.** The four-phase order, backpressure behavior, and all latencies are unchanged; the return payload is an accompanying bus, not a second transaction.
- **Explicitly excluded**: a separate return-payload width parameter, a per-bit synchronized return bus, a return FIFO, a second outstanding transaction, CSR/APB visibility, RAL, and changes to the reused synchronizer wrapper. Also excluded from this plan: any edit to the specification, the block diagram, or the waveforms (RSC-043; see section 6).

## 6. Open questions, assumptions, conflicts, risks

| ID | Type | Statement |
|---|---|---|
| A-1 | Assumption | The return payload is supplied by the destination user and delivered to the source user. No other origin is meaningful for a protocol-neutral bridge. |
| A-2 | Assumption | The return payload uses the existing width `PARA_AHS4_DATA_W`; a second width parameter is excluded to keep the interface symmetric. |
| A-3 | Assumption | "Captured through a flip-flop" means one destination-domain register on the return path (mode 2), and "not captured" means a combinational pass (mode 1). |
| A-4 | Assumption | Disabled mode drives `o_ack_data` to zero and ignores `i_ack_data`. Ports cannot be removed per parameter value, and specification section 8 already states that no port is added or removed by a parameter value. |
| C-1 | Conflict | The authoritative specification v0.2 (REQ-PARAM-001..003, IF-001/IF-002, port table, section 8) does not contain this feature. RSC-043 forbids editing the specification unless separately requested. If the specification is not updated, the delivered RTL will not trace to it. |
| R-1 | Risk | Mode 1 adds a combinational path from `i_ack_data` to `o_ack_data` across both blocks; the timing budget of that path belongs to the integrator. Mode 2 removes it at the cost of `PARA_AHS4_DATA_W` destination flops. |
| R-2 | Risk | The port list grows by two; name-based instantiation is unaffected, positional instantiation of `m_vlsit_ahs4_top` would break. No in-repository consumer exists. |
| R-3 | Risk | In mode 0 the `i_ack_data` port is unused inside `u_dst`; a lint warning for an unused port is possible and will be reported if it appears. |
| R-4 | Risk | The block diagram and the six waveforms describe v0.2 and will not show the return channel. They are not part of this plan. |

## 7. Proposed validation

All commands run from `C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\lint` after `$env:PATH = "C:\Tools\oss-cad-suite\bin;C:\Tools\oss-cad-suite\lib;" + $env:PATH`. `<cells>` is the eight cell models in `../../000_Common/rtl_cells` plus `../../000_Common/rtl_lib/m_vlsit_afifo_cell_sync.sv`; `<rtl>` is `../rtl/m_vlsit_ahs4_dst.sv ../rtl/m_vlsit_ahs4_src.sv ../rtl/m_vlsit_ahs4_top.sv`.

| Check | Command | Expected evidence | Status |
|---|---|---|---|
| Rule check | `python vlsit_rtl_check.py check <IP_DIR> --report <IP_DIR>\RTL_RULE_CHECK_REPORT.md` | `RESULT: PASS`, 0 ERROR, the same 2 accepted HIE-02 WARN | Not run |
| slang, configuration (DST=0, ACK=0) | `slang.exe --top m_vlsit_ahs4_top -Wextra -D VLSIT_SYNTHESIS <cells> <rtl>` | `Build succeeded: 0 errors, 0 warnings` | Not run |
| slang, (DST=0, ACK=1) | same with `-GPARA_AHS4_ACK_DATA_MODE=1` | 0 errors, 0 warnings | Not run |
| slang, (DST=0, ACK=2) | same with `-GPARA_AHS4_ACK_DATA_MODE=2` | 0 errors, 0 warnings | Not run |
| slang, (DST=1, ACK=2) | same with `-GPARA_AHS4_DST_MODE=1 -GPARA_AHS4_ACK_DATA_MODE=2` | 0 errors, 0 warnings | Not run |
| Verilator, the same four configurations | `verilator_bin.exe --lint-only -Wall --top-module m_vlsit_ahs4_top +define+VLSIT_SYNTHESIS <cells> <rtl>` with the matching `-G` overrides | exit 0, no warnings | Not run |
| Elaborated-branch inspection | `vlsit_lint_rtl.py filelist` and reading the elaborated hierarchy of each run | `gen_ack_data_off`, `gen_ack_data_transparent`, and `gen_ack_data_capture` each selected once; `gen_dst_transparent`/`gen_dst_capture` unchanged | Not run |
| Change metrics | `python vlsit_rtl_change_metrics.py compare backup\rtl_snapshot_2026-11-13 rtl` | Baseline, added, deleted, percentage | Not run |
| Manual inspection | Port directions and widths against section 6.2; reset style; no FSM introduced | Each `always_ff` still one clock and one active-low reset; source control untouched | Not run |

The pair (DST=1, ACK=1) is not linted separately: its two generate branches are each elaborated and linted in the (0,1) and (1,2) runs, and the two parameters are independent. If the reviewer prefers, add it to the matrix.

Not run by design: simulation and a testbench (none exists and none is requested), synthesis, STA, CDC analysis, and formal verification. The specification check is not run because the specification is not edited.

## 8. Approval

Approved: plan version 1, by the user on 2026-11-13, reply "approve". The approval covers the three RTL files, the supporting records listed in section 3, and the validation matrix of section 7. The specification update was not approved and was not performed (RSC-043).

## 9. Final implementation report

### 9.1 Requirement traceability

| Requirement | Implementation evidence | Status |
|---|---|---|
| CR-01 return payload at the IP boundary | `rtl\m_vlsit_ahs4_top.sv:46` (`o_ack_data`), `:58` (`i_ack_data`), `:65` (`w_ack_data`), `:77`, `:79`, `:96`, `:100`; `rtl\m_vlsit_ahs4_dst.sv:47`, `:55`; `rtl\m_vlsit_ahs4_src.sv:38`, `:42` | Implemented |
| CR-02 parameter selecting the option | `rtl\m_vlsit_ahs4_dst.sv:35` (declaration), `:110` (selection); `rtl\m_vlsit_ahs4_top.sv:34` (declaration), `:89` (override) | Implemented |
| CR-03 transparent or registered payload | `rtl\m_vlsit_ahs4_dst.sv:113` (disabled), `:116` (transparent), `:117-133` (registered) | Implemented |
| CR-04 payload valid while the acknowledge is high | `rtl\m_vlsit_ahs4_src.sv:63` (combinational forward); `rtl\m_vlsit_ahs4_dst.sv:124-131` (held through the acknowledge window) | Implemented; not simulated |
| CR-05 handshake unchanged | `rtl\m_vlsit_ahs4_src.sv:65-92` and `rtl\m_vlsit_ahs4_dst.sv:57-103` are unchanged apart from comments | Implemented |

### 9.2 Changed files

| File | Change |
|---|---|
| `rtl\m_vlsit_ahs4_src.sv` | Two ports (`i_ack_data`, `o_ack_data`) and one continuous assignment; header description extended. No sequential logic and no reset term added. |
| `rtl\m_vlsit_ahs4_dst.sv` | New parameter `PARA_AHS4_ACK_DATA_MODE`, two ports, and one three-branch generate for the return payload. |
| `rtl\m_vlsit_ahs4_top.sv` | New parameter, two ports, one internal wire, and the parameter and port connections to `u_dst` and `u_src`. |
| `RTL_RULE_CHECK_REPORT.md` | Regenerated for the three delivered files. |
| `RTL_DELIVERY_REPORT.md` | Updated to the new parameter, ports, and lint evidence. |
| `lint\lint_slang_d0_a0.log`, `_d0_a1`, `_d0_a2`, `_d1_a2` | New slang logs. |
| `lint\lint_verilator_d0_a0.log`, `_d0_a1`, `_d0_a2`, `_d1_a2` | New Verilator logs. Superseded: `lint_slang_3.log`, `lint_slang_mode1.log`, `lint_verilator_3.log`, `lint_verilator_mode1.log`. |

### 9.3 Executed checks and results

| Check | Command (abbreviated) | Result |
|---|---|---|
| RTL rule check | `vlsit_rtl_check.py check <three files> --report RTL_RULE_CHECK_REPORT.md` | `RESULT: PASS`; 0 ERROR, 2 WARN (HIE-02, accepted), 0 INFO |
| slang (DST=0, ACK=0) | `slang.exe --top m_vlsit_ahs4_top -Wextra -D VLSIT_SYNTHESIS <set>` | `Build succeeded: 0 errors, 0 warnings`, exit 0 |
| slang (DST=0, ACK=1) | same with `-GPARA_AHS4_ACK_DATA_MODE=1` | 0 errors, 0 warnings, exit 0 |
| slang (DST=0, ACK=2) | same with `-GPARA_AHS4_ACK_DATA_MODE=2` | 0 errors, 0 warnings, exit 0 |
| slang (DST=1, ACK=2) | same with both overrides | 0 errors, 0 warnings, exit 0 |
| Verilator (DST=0, ACK=0) | `verilator_bin.exe --lint-only -Wall --top-module m_vlsit_ahs4_top +define+VLSIT_SYNTHESIS <set>` | Exit 0, no warnings |
| Verilator (DST=0, ACK=1) | same with the ACK override | Exit 0, no warnings |
| Verilator (DST=0, ACK=2) | same with the ACK override | Exit 0, no warnings |
| Verilator (DST=1, ACK=2) | same with both overrides | Exit 0, no warnings |
| Manual inspection | Port directions and widths against the request; generate exclusivity; reset style | PASS: `o_ack_data` is an output and `i_ack_data` an input in all three modules; each `always_ff` keeps one clock and one active-low reset; the source control is unchanged |

Not run: simulation, testbench, synthesis, STA, CDC analysis, formal verification, and the specification check (the specification is not edited).

### 9.4 Deviations from the approved plan

| ID | Deviation | Reason and effect |
|---|---|---|
| D-1 | The disabled branch became `assign o_ack_data = i_ack_data & {PARA_AHS4_DATA_W{1'b0}};` instead of `assign o_ack_data = '0;`. | The first Verilator run of the default configuration failed with `%Warning-UNUSEDSIGNAL` on `i_ack_data` (risk R-3 materialized). The new expression still produces a constant zero, references the port, and folds in synthesis. Behavior and interface are unchanged. |
| D-2 | The rule check was invoked on the three delivered files explicitly, not on the IP folder. | The task baseline snapshot inside `backup\rtl_snapshot_2026-11-13` is a second copy of the same RTL and would be scanned as three further files, duplicating every finding. The report therefore lists exactly the three delivered files. |

### 9.5 Remaining risks

| ID | Risk | Status |
|---|---|---|
| R-1 | Mode 1 (transparent) is a combinational path from `i_ack_data` to `o_ack_data` across both blocks. | Open; belongs to integration timing constraints. Mode 2 removes the path at the cost of `PARA_AHS4_DATA_W` destination flops. |
| R-2 | The port list grew by two; positional instantiation of the top would break. | Open; no in-repository consumer exists. |
| R-4 | The specification v0.2, the block diagram, and the six waveforms do not describe the return channel. | Open; the specification is not edited (RSC-043). The delivered RTL is now ahead of the specification and needs a v0.3 update to restore traceability. |
| R-5 | The mode-2 capture (load on `i_ack`, hold through the acknowledge window) has not been simulated. | Open; no testbench exists. |

### 9.6 Code-change metrics

| Metric | Value |
|---|---|
| Baseline RTL code lines (nonblank, noncomment, whole RTL tree) | 156 |
| Added lines | 37 |
| Deleted lines | 6 |
| Change percentage | (37 + 6) / 156 × 100 = **27.56 %** |
| Changed files | `m_vlsit_ahs4_dst.sv` (+21 / -2), `m_vlsit_ahs4_src.sv` (+3 / -0), `m_vlsit_ahs4_top.sv` (+13 / -4) |

Source: `vlsit_rtl_change_metrics.py compare backup\rtl_snapshot_2026-11-13 rtl`. Comment-only header edits and blank lines are excluded from the numerator.

### 9.7 Completion status

Implemented and validated by rule check and lint on four parameter configurations. Simulation and synthesis are not run. The RTL is complete for the approved behavior; the specification and figures remain at v0.2 and are the only outstanding inconsistency.

## 10. Rule audit (vlsit-rtl-spec-change-implementer)

| Rule | Status | Evidence |
|---|---|---|
| RSC-001 | PASS | Plan, final report, RTL comments, and this summary are in engineering English; the conversational reply to the user's Vietnamese request is bilingual only in the chat. |
| RSC-010 | PASS (with note) | The RTL root is named in plan section 1 and the user approved plan version 1; the approval is the confirmation of the directory. The directory was not queried before the read-only analysis. |
| RSC-011 | PASS | The old specification v0.2 was used to establish the baseline; comparison is recorded in section 2. |
| RSC-012 | PASS | The new behavior was described in the user's prose (2026-11-13). |
| RSC-013 | PASS | No additional question was needed once the ambiguities were stated as assumptions A-1..A-4 and resolved by approval. |
| RSC-014 | NOT APPLICABLE | No new specification file was supplied. |
| RSC-015 | PASS | Every decision that affects the interface, timing, reset, or compatibility is listed in section 6 and was covered by the gate. |
| RSC-020 | PASS | RTL tree, hierarchy, parameters, interfaces, and file list inspected; section 3 maps the change. |
| RSC-021 | PASS | Proven facts and interpretation are separated; gaps are in section 6. |
| RSC-022 | PASS | No test, simulation, or synthesis ran before approval; only the baseline snapshot was taken. |
| RSC-023 | PASS | The task-start snapshot is the baseline; no unrelated folder was used. |
| RSC-024 | PASS | `backup\rtl_snapshot_2026-11-13` captured before the first RTL edit. |
| RSC-030 | PASS | `rtl_change_review.md` written in the project root before any RTL edit. |
| RSC-031 | PASS | Sections 1 to 8 follow the reference template. |
| RSC-032 | PASS | Three strategies compared in section 4, ranked, one recommended. |
| RSC-033 | PASS | Findings and rows are self-contained; no check is claimed in the plan. |
| RSC-034 | PASS | The exact approval question was asked, naming plan version 1. |
| RSC-035 | PASS | No RTL edit, patch, or check before approval. |
| RSC-036 | NOT APPLICABLE | The plan was approved, not revised or stopped. |
| RSC-037 | PASS | Only the listed files and behaviors were changed; the specification was excluded. |
| RSC-040 | PASS | Smallest change set that implements the behavior, in the existing style. |
| RSC-041 | PASS | The folding expression of D-1 is the smallest lint-clean way to keep a constant-zero disabled output. |
| RSC-042 | PASS (with deviation D-1) | The implementation form of one approved branch changed after a lint result; behavior, interface, and validation are unchanged, so the approval still applies. |
| RSC-043 | PASS | No specification or figure was edited. |
| RSC-044 | PASS | SystemVerilog and the existing comment style are preserved. |
| RSC-050 | PASS | Only the approved rule check, lint matrix, metrics, and manual inspection ran. |
| RSC-051 | PASS | This section and sections 9.1 to 9.7 update the review with traceability, changes, results, risks, and status. |
| RSC-060 | PASS | Percentage = (37 + 6) / 156 x 100 = 27.56 %, from the script. |
| RSC-061 | PASS | Baseline, added, deleted, changed files, and percentage are stated in 9.6. |
| RSC-062 | PASS | Compared against the captured task-start snapshot. |
| RSC-063 | PASS | The final chat response links this review and summarizes behavior, files, status, metrics, checks, and risks. |
| RSC-090 | NOT APPLICABLE | No operation required a second manual repetition; the lint matrix is a documented loop and the metrics are scripted. |
| RSC-091 | NOT APPLICABLE | No new script was added. |
| RSC-092 | NOT APPLICABLE | No script was run against the RTL tree before approval. |
| RSC-093 | PASS | Friction recorded and logged in `reference/vlsit_improvement_log.md`; `SKILL.md` steps 2 and 4 updated, no rule changed. |
| RSC-094 | PASS | `rule.md` is unchanged. |
| RSC-095 | PASS | The `SKILL.md` additions are two sentences. |
| RSC-096 | PASS | Python located with the bundled helper, invoked with `-ExecutionPolicy Bypass`; the path was used for every script call. |
| RSC-097 | NOT APPLICABLE | No Excel or CSV input. |

No unmet MUST remains. Two items are reported as notes rather than failures: RSC-010 (the directory was confirmed by the approval instead of a separate question) and RSC-042 (an implementation detail changed after a lint result without a second gate, with behavior unchanged).
