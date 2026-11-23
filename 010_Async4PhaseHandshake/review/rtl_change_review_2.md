# RTL Change Review — independent request and acknowledge payload widths — plan version 2

Status: Awaiting user sign-off

## 1. Design and input summary

| Item | Value |
|---|---|
| RTL root | `C:\HQuan\102_MyGithub\VLSIT_DEEPSEEK\common_rtl\010_Async4PhaseHandshake\rtl` |
| Old specification | `../spec/../spec/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md` v0.2 (authoritative for the delivered behavior) |
| New specification file | Not supplied. The requested behavior is described in the user's prose of 2026-11-13. |
| Task-start baseline | `backup\rtl_snapshot_2026-11-13_cs2` (the delivered change-set-1 RTL, captured before any edit of this task) |
| Selected top | `m_vlsit_ahs4_top` with `u_src`, `u_dst`, `u_sync_ack`, `u_sync_req`, `gen_dst_transparent`/`gen_dst_capture`, `gen_ack_data_off`/`gen_ack_data_transparent`/`gen_ack_data_capture` |
| Pre-existing changes | None. Change set 1 (acknowledge-direction payload) is already delivered, reviewed in `rtl_change_review.md`, and is the baseline of this task. |

Analysis limits: the review covers the three delivered `.sv` files only. There is no testbench, no synthesis flow, no timing constraints, and no CDC tool in the project folder, so functional and electrical claims are limited to elaboration, lint, and inspection.

## 2. Requirement comparison

| ID | New requirement | Old requirement | Current RTL behavior (file:line) | Intended behavior |
|---|---|---|---|---|
| RC-01 | The request-direction payload width and the acknowledge-direction payload width are configured by two independent parameters. | One width, `PARA_AHS4_DATA_W`, defines the bundled payload and both data ports (spec REQ-PARAM-001, section 9). | `rtl\m_vlsit_ahs4_top.sv:22` one width; `:42`, `:46`, `:54`, `:58` all ports use it; `rtl\m_vlsit_ahs4_src.sv:34`, `:38`, `:42`, `:46`; `rtl\m_vlsit_ahs4_dst.sv:43`, `:47`, `:51`, `:55`; `:113`, `:119` use it for the return payload as well. | `PARA_AHS4_DATA_W` keeps the request direction (`i_data`, `o_data`, `reg_data`, mode-1 `reg_data`). A new `PARA_AHS4_ACK_DATA_W` sizes `i_ack_data`, `o_ack_data`, `w_ack_data`, and mode-2 `reg_ack_data`. The two widths are independent. |
| RC-02 | Both width parameters are limited to 1..1024. | `PARA_AHS4_DATA_W` is limited to 1..256 (spec REQ-PARAM-001, sections 9 and 11). | `rtl\m_vlsit_ahs4_top.sv:19-21` states 1 to 256; the bound is documented only, not elaboration-enforced. | Both parameters state 1 to 1024 in their comment and in the delivery report. The bound remains documented only, matching the existing treatment of 1..256. |
| RC-03 | The parameter comment states that a larger width is harder for physical design. | No physical-design note exists. | `rtl\m_vlsit_ahs4_top.sv:19-21`, `rtl\m_vlsit_ahs4_src.sv:19-21`, `rtl\m_vlsit_ahs4_dst.sv:20-22` describe only function, values, and unit. | Each width parameter carries a physical-design paragraph: register size, crossing width, and the setup/max-delay constraint of the bundled-data crossing all grow with the width. |
| RC-04 | The parameter comment states that a real design can split the channel into several four-phase handshake clusters whose payloads stay below 256 bits. | No clustering guidance exists. | No statement anywhere in the RTL. | Each width parameter states that a real design may split one transfer into several four-phase handshake clusters with payloads below 256 bits each. |
| RC-05 | The handshake behavior, latency, reset behavior, and port set are unchanged. | Spec sections 7, 10, and DEC-004/DEC-010. | `rtl\m_vlsit_ahs4_src.sv:56-104`, `rtl\m_vlsit_ahs4_dst.sv:58-103`, `:135-145`. | Unchanged. Only widths and comments change; no port is added or removed, no register is added or removed, no latency changes. |

## 3. Affected modules and files

| Module | File | Code region | Proposed change | Reason |
|---|---|---|---|---|
| `m_vlsit_ahs4_top` | `rtl\m_vlsit_ahs4_top.sv` | `:19-21` | Rewrite the `PARA_AHS4_DATA_W` comment: request direction, 1 to 1024, physical-design note with the cluster guidance | RC-01, RC-02, RC-03, RC-04 |
| `m_vlsit_ahs4_top` | same | after `:30` (before `:31`) | Insert `PARA_AHS4_ACK_DATA_W` declaration with its three mandatory lines plus the physical-design note | RC-01 to RC-04 |
| `m_vlsit_ahs4_top` | same | `:46`, `:58` | `o_ack_data` and `i_ack_data` become `[PARA_AHS4_ACK_DATA_W-1:0]` | RC-01 |
| `m_vlsit_ahs4_top` | same | `:65` | `w_ack_data` becomes `[PARA_AHS4_ACK_DATA_W-1:0]` | RC-01 |
| `m_vlsit_ahs4_top` | same | `:86-89` | Add `.PARA_AHS4_ACK_DATA_W (PARA_AHS4_ACK_DATA_W)` to the `u_dst` parameter map | RC-01 |
| `m_vlsit_ahs4_src` | `rtl\m_vlsit_ahs4_src.sv` | `:19-21` | `PARA_AHS4_DATA_W` comment: request direction, 1 to 1024, physical-design note | RC-02 to RC-04 |
| `m_vlsit_ahs4_src` | same | after `:26` | Insert `PARA_AHS4_ACK_DATA_W` declaration | RC-01 to RC-04 |
| `m_vlsit_ahs4_src` | same | `:38`, `:42` | `i_ack_data` and `o_ack_data` become `[PARA_AHS4_ACK_DATA_W-1:0]` | RC-01 |
| `m_vlsit_ahs4_src` | same | `:12-13` | Header description: name the two widths | Documentation accuracy |
| `m_vlsit_ahs4_dst` | `rtl\m_vlsit_ahs4_dst.sv` | `:20-22` | `PARA_AHS4_DATA_W` comment: request direction, 1 to 1024, physical-design note | RC-02 to RC-04 |
| `m_vlsit_ahs4_dst` | same | after `:31` | Insert `PARA_AHS4_ACK_DATA_W` declaration | RC-01 to RC-04 |
| `m_vlsit_ahs4_dst` | same | `:47`, `:55` | `i_ack_data` and `o_ack_data` become `[PARA_AHS4_ACK_DATA_W-1:0]` | RC-01 |
| `m_vlsit_ahs4_dst` | same | `:113` | Folding expression becomes `i_ack_data & {PARA_AHS4_ACK_DATA_W{1'b0}}` | RC-01; keeps the disabled configuration lint-clean (deviation D-1 of change set 1) |
| `m_vlsit_ahs4_dst` | same | `:119` | `reg_ack_data` becomes `[PARA_AHS4_ACK_DATA_W-1:0]` | RC-01 |
| `m_vlsit_ahs4_dst` | same | `:12-14` | Header description: name the two widths | Documentation accuracy |

Supporting records, updated after approval only:

| File | Change |
|---|---|
| `RTL_RULE_CHECK_REPORT.md` | Regenerated for the three delivered files |
| `RTL_DELIVERY_REPORT.md` | New parameter row, new range, revised port widths, revised lint evidence, specification-gap row |
| `lint\lint_slang_d0_a0.log`, `_d0_a1`, `_d0_a2`, `_d1_a2` and the four matching `lint_verilator_*` logs | Regenerated against the new RTL |
| `lint\lint_slang_mixed_w.log`, `lint_slang_mixed_w_rev.log` and the two matching `lint_verilator_*` logs | New asymmetric-width evidence |
| `rtl_change_review_2.md` | This document, extended with the final implementation report of section 9 |

Explicitly excluded (RSC-043): `../spec/../spec/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md`, the six waveform JSON/SVG pairs, and the block-diagram JSON/drawio/SVG.

## 4. Design choices

### Proposed parameter block (strategy A, recommended)

```systemverilog
module m_vlsit_ahs4_top #(
  // Parameter Description: width of the request-direction bundled payload and of i_data and o_data.
  // Parameter values: 1 to 1024; default is 32.
  // Parameter unit: bit
  // Physical design: a wider payload is harder to close. It enlarges the source payload register
  //   and the bundled-data crossing and it tightens the setup/max-delay constraint of that
  //   crossing. A real design can split one transfer into several four-phase handshake clusters
  //   whose payloads stay below 256 bits.
  parameter logic [31:0] PARA_AHS4_DATA_W = 32,
  // Parameter Description: synchronizer depth for the request and acknowledge crossings.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_SYNC_TYPE = 2,
  // Parameter Description: destination data-presentation mode; selects option A or option B.
  // Parameter values: 0 = transparent (option A), 1 = captured (option B); default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_DST_MODE = 0,
  // Parameter Description: width of the acknowledge-direction return payload and of i_ack_data
  //   and o_ack_data; independent of PARA_AHS4_DATA_W.
  // Parameter values: 1 to 1024; default is PARA_AHS4_DATA_W.
  // Parameter unit: bit
  // Physical design: a wider return payload is harder to close. Modes 1 and 2 of
  //   PARA_AHS4_ACK_DATA_MODE make the return path combinational or add PARA_AHS4_ACK_DATA_W
  //   destination flops, so a width below 256 bits is easier to place and route. A real design
  //   can split the return side into several four-phase handshake clusters as well.
  parameter logic [31:0] PARA_AHS4_ACK_DATA_W = PARA_AHS4_DATA_W,
  // Parameter Description: return-direction payload mode on the acknowledge channel.
  // Parameter values: 0 = disabled, 1 = transparent, 2 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_ACK_DATA_MODE = 0
) (
```

| Strategy | Functional coverage | Change size | Compatibility | Complexity | Risk |
|---|---|---|---|---|---|
| **A (recommended)**: keep `PARA_AHS4_DATA_W` as the request width; add `PARA_AHS4_ACK_DATA_W` defaulting to `PARA_AHS4_DATA_W`; both 1..1024 | Full RC-01 to RC-05 | 13 non-comment RTL lines touched, no port or register count change | Name and position 1 of the existing width preserved; existing instantiations that override only `PARA_AHS4_DATA_W` keep a symmetric payload. `PARA_AHS4_ACK_DATA_MODE` moves from positional index 4 to 5. | Lowest: widths propagate as declared parameters | Low; default tracking and one positional shift |
| B: rename the request width to `PARA_AHS4_REQ_DATA_W` and add `PARA_AHS4_ACK_DATA_W` | Full RC-01 to RC-05 | Similar to A | Breaks every existing instantiation that overrides `PARA_AHS4_DATA_W` and diverges from spec REQ-PARAM-001 | Low | Medium; avoidable interface break in a delivered IP |
| C: keep only `PARA_AHS4_DATA_W` and derive the acknowledge width by a ratio parameter | Partial; cannot express arbitrary pairs, and the ratio must divide exactly | Similar to A | Adds a second knob with hidden rounding | Medium: two parameters must be reasoned about together | Medium; fails RC-01 for non-multiple widths |

The default `PARA_AHS4_ACK_DATA_W = PARA_AHS4_DATA_W` is chosen over a fixed default of 32 because it keeps the delivered behavior identical for every integration that overrides only `PARA_AHS4_DATA_W`, and because `PARA_AHS4_ACK_DATA_MODE` = 0 (the default) already drives `o_ack_data` to zero, so the width default cannot change function.

## 5. Minimal-change rationale

Each edit is required by RC-01 to RC-04:

- The two width parameters must exist in every module that declares a port of that width; otherwise the port width cannot be independent of the request width. That is the only reason `PARA_AHS4_ACK_DATA_W` is declared in all three modules rather than in the top alone, and it matches the existing propagation of `PARA_AHS4_DATA_W` and `PARA_AHS4_DST_MODE`.
- `i_ack_data`, `o_ack_data`, `w_ack_data`, and `reg_ack_data` are the four declarations that carry the return payload; nothing else in the design touches it.
- The folding expression at `rtl\m_vlsit_ahs4_dst.sv:113` is re-based on `PARA_AHS4_ACK_DATA_W` so the disabled configuration stays lint-clean at asymmetric widths.
- The comments are required by RC-03 and RC-04. They are comments only: the design is not clustered automatically, and no structure is added.

Excluded on purpose: the source launch/completion logic (`rtl\m_vlsit_ahs4_src.sv:65-92`), the destination request and acknowledge paths (`rtl\m_vlsit_ahs4_dst.sv:61-103`), both synchronizer instances, the port order and port names, the module names, and every file under `figures\`. None of them depends on the payload width. No elaboration-time range check is added, because the current 1..256 bound is also documented only (assumption A-2).

## 6. Open questions, assumptions, conflicts, risks

### Assumptions

| ID | Assumption | Basis |
|---|---|---|
| A-1 | `PARA_AHS4_DATA_W` keeps its name and becomes the request-direction width. | Minimal deviation from spec REQ-PARAM-001; strategy B would break existing instantiations. |
| A-2 | The 1..1024 bounds are documented constraints, not elaboration-enforced. | The existing 1..256 bound is documented only; the specification states that an illegal configuration "shall not be elaborated" by the integrator, not that the IP detects it. |
| A-3 | The physical-design text is a comment. No automatic clustering, no extra pipeline stage, and no gearing is added. | The user asked for a comment, not for a structural change. |
| A-4 | The default of `PARA_AHS4_ACK_DATA_W` tracks `PARA_AHS4_DATA_W`. | Preserves delivered behavior for integrations that override only the request width. |

### Conflicts and gaps

| ID | Item | Effect |
|---|---|---|
| C-1 | Spec v0.2 states 1..256 in sections 1, 5, 8, 9, 11, and 13, and does not describe a second width at all. | The RTL will diverge further from the specification. Per RSC-043 the specification is not edited; a v0.3 update is required to restore traceability. |
| C-2 | The mandatory comment style of spec section 8 is three lines: Parameter Description / values / unit. | The physical-design note adds two to four comment lines per width parameter. This is an approved-by-plan extension of the style, not a rule violation; it is recorded here so the reviewer sees the divergence. |
| C-3 | `PARA_AHS4_ACK_DATA_MODE` moves from positional parameter index 4 to index 5. | Named association is unaffected. A positional instantiation of the top would silently map mode 1/2 onto the width. No in-repository consumer exists. |
| C-4 | The block diagram and the six waveforms show a single payload width. | Figures remain correct in structure and wrong in annotation; updating them is out of scope. |

### Risks

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| R2-1 | A 1024-bit payload in mode 1 is a 1024-bit combinational path across both blocks; in mode 2 it is 1024 destination flops. | Medium | Documented in the parameter comment as required by RC-03/RC-04; the integrator selects mode 0 or mode 2 and splits clusters. |
| R2-2 | The range is not enforced; 0 or 1025 elaborates to a degenerate or oversized design. | Low | Same exposure as today for 0 or 257; documented in the delivery report. |
| R2-3 | Positional parameter use breaks as described in C-3. | Low | Named association is the delivered convention in the report and in the lint commands. |
| R2-4 | No simulation exists, so the asymmetric width pair is verified by elaboration and lint only. | Medium | The asymmetric lint configurations exercise both extremes; the limitation is stated in the report. |
| R2-5 | Spec, figures, and parameters disagree after this change. | Medium | Recorded as C-1/C-4 and in the delivery report; a v0.3 specification change needs a separate request. |

## 7. Proposed validation

All commands assume the Windows toolchain of change set 1: Python at `C:\Users\PC\AppData\Local\Programs\Python\Python312\python.exe`, slang and Verilator from `C:\Tools\oss-cad-suite\bin`, with that `bin` and `lib` prepended to `PATH`.

| Check | Command (abbreviated) | Expected evidence | Status |
|---|---|---|---|
| RTL rule check, three delivered files | `vlsit_rtl_check.py check rtl\m_vlsit_ahs4_dst.sv rtl\m_vlsit_ahs4_src.sv rtl\m_vlsit_ahs4_top.sv --report RTL_RULE_CHECK_REPORT.md` | `RESULT: PASS`, 0 ERROR, and at most the two accepted HIE-02 warnings | Not run |
| slang, default (32/32, DST 0, ACK 0) | `slang.exe --top m_vlsit_ahs4_top -Wextra -D VLSIT_SYNTHESIS <cells> <rtl>` | `Build succeeded: 0 errors, 0 warnings` | Not run |
| slang, 32/32, DST 0, ACK 1 | same with `-GPARA_AHS4_ACK_DATA_MODE=1` | same | Not run |
| slang, 32/32, DST 0, ACK 2 | same with `-GPARA_AHS4_ACK_DATA_MODE=2` | same | Not run |
| slang, 32/32, DST 1, ACK 2 | same with `-GPARA_AHS4_DST_MODE=1 -GPARA_AHS4_ACK_DATA_MODE=2` | same | Not run |
| slang, asymmetric wide request | same with `-GPARA_AHS4_DATA_W=1024 -GPARA_AHS4_ACK_DATA_W=1 -GPARA_AHS4_DST_MODE=1 -GPARA_AHS4_ACK_DATA_MODE=2` | same; log `lint_slang_mixed_w.log` | Not run |
| slang, asymmetric wide acknowledge | same with `-GPARA_AHS4_DATA_W=1 -GPARA_AHS4_ACK_DATA_W=1024 -GPARA_AHS4_DST_MODE=1 -GPARA_AHS4_ACK_DATA_MODE=2` | same; log `lint_slang_mixed_w_rev.log` | Not run |
| Verilator `-Wall`, the same six configurations | `verilator_bin.exe --lint-only -Wall --top-module m_vlsit_ahs4_top +define+VLSIT_SYNTHESIS <cells> <rtl>` with the matching `-G` overrides | exit 0, no warning; matching `lint_verilator_*.log` | Not run |
| Elaborated width inspection | read the elaborated parameter values of each run | `i_data`/`o_data` = `PARA_AHS4_DATA_W`, `i_ack_data`/`o_ack_data` = `PARA_AHS4_ACK_DATA_W` in every configuration | Not run |
| Manual inspection | read the three files | one clock and one active-low reset per `always_ff`; no port added or removed; no register added or removed; both comments carry the physical-design and cluster text | Not run |
| Change metrics | `vlsit_rtl_change_metrics.py compare backup\rtl_snapshot_2026-11-13_cs2 rtl` | baseline, added, and deleted lines; percentage; changed-file list | Not run |

Not proposed: simulation, a testbench, synthesis, STA, CDC analysis, and formal verification, because no such flow exists in the project folder and none was requested. The specification check is not run because the specification is not edited.

## 8. Approval

The proposed change set is: three RTL files (`rtl\m_vlsit_ahs4_top.sv`, `rtl\m_vlsit_ahs4_src.sv`, `rtl\m_vlsit_ahs4_dst.sv`) plus the supporting records listed in section 3, strategy A, assumptions A-1 to A-4, and the six-configuration lint matrix of section 7. The specification, figures, and waveforms are excluded.

Do you approve plan version 2, including the listed RTL files, proposed behavior, and validation commands? Reply APPROVE, REVISE, or STOP.

If a different width-parameter name, a fixed default of 32 for `PARA_AHS4_ACK_DATA_W`, or an elaboration-time range check is wanted, reply REVISE with the preference; that is a materially different behavior and needs this gate.

## 9. Final implementation report (added after approval)

Not yet applicable.
