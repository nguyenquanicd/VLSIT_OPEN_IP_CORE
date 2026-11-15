# CRC simulation and synthesis / Simulation và synthesis CRC

Source: `rtl/m_crc_engine.sv`; golden contract: `CRC_Design_Specification.md`.
RTL source hashes are recorded in `rtl_source_hashes.json`; this run changes no design RTL.

## Simulation

14 configurations, 42 runs, 5376 completed frames (generation and checking combined).
Golden values use arbitrary-precision polynomial long division in Python. The C++
testbench drives only the top ports and checks handshakes, CRCs, exact final-beat
latency, matching/mismatching references, backpressure, reset aborts and independent progress.
Each configuration uses seeds 20261027, 19 and 97; 64 frames per channel per seed.
Verilator uses two-state simulation; X propagation, formal proof and code coverage are not claimed.

| Configuration | Runs | Frames | Assertion checks per run | Result |
|---|---:|---:|---:|---|
| base0 | 3 | 384 | 23 | PASS |
| base1 | 3 | 384 | 25 | PASS |
| base2 | 3 | 384 | 25 | PASS |
| base3 | 3 | 384 | 25 | PASS |
| base4 | 3 | 384 | 25 | PASS |
| chunk32 | 3 | 384 | 25 | PASS |
| chunk6_partial | 3 | 384 | 25 | PASS |
| full32 | 3 | 384 | 25 | PASS |
| ref0 | 3 | 384 | 23 | PASS |
| ref1 | 3 | 384 | 25 | PASS |
| ref2 | 3 | 384 | 25 | PASS |
| ref3 | 3 | 384 | 25 | PASS |
| ref4 | 3 | 384 | 25 | PASS |
| word8_crc16 | 3 | 384 | 25 | PASS |

Mutation: **PASS**. An intentionally inverted CRC bit in a copied method-2 RTL must fail the requirement scoreboard; see `mutation/simulation.log`.

## Generic synthesis / Tổng hợp generic

Yosys + slang elaborates each configuration, runs `synth`, ABC generic mapping,
and `check -assert`, and saves the netlist, statistics, command script and full log.
No standard-cell Liberty library is selected. Counts below are generic cells, not
ASIC area, NAND2 equivalents, or timing signoff. Flip-flops include data/control state.

| Configuration | Total cells | Flip-flops | Combinational cells | Latches | Result |
|---|---:|---:|---:|---:|---|
| base0 | 168 | 52 | 116 | 0 | PASS |
| base1 | 449 | 138 | 311 | 0 | PASS |
| base2 | 480 | 118 | 362 | 0 | PASS |
| base3 | 722 | 126 | 596 | 0 | PASS |
| base4 | 480 | 118 | 362 | 0 | PASS |
| ref0 | 174 | 52 | 122 | 0 | PASS |
| ref1 | 461 | 138 | 323 | 0 | PASS |
| ref2 | 481 | 118 | 363 | 0 | PASS |
| ref3 | 708 | 126 | 582 | 0 | PASS |
| ref4 | 481 | 118 | 363 | 0 | PASS |
| chunk6_partial | 640 | 100 | 540 | 0 | PASS |
| word8_crc16 | 395 | 104 | 291 | 0 | PASS |
| chunk32 | 4608 | 242 | 4366 | 0 | PASS |
| full32 | 1981 | 238 | 1743 | 0 | PASS |

Synthesis diagnostics: CRC-width-32 configurations can report three
`shift-count-overflow` warnings in the parameter high-bit legality checks. Shifting
a 32-bit unsigned value right by 32 intentionally yields zero; all 32 bits are active.
These are elaboration checks, not datapath shifts. No warnings are suppressed.
Synthesis completed with no inferred latches or structural check failures.

## Evidence and reproduction / Bằng chứng và chạy lại

From the CRC directory: `make v2-verify`. Individual targets: `v2-sim`, `v2-synth`,
`v2-mutation`, `v2-waveforms`, `v2-report`; `make v2-help` describes them.
The single project Makefile owns all run commands. Test sources are in `tests/`;
vectors, assertion-hit tables, tool commands and logs are retained in `sanity/`.
Ten actual VCD/JSON/SVG windows are in `tests/waveforms_sim/`.
The comparison index labels literal differences from illustrative specification figures;
functional and cycle-contract checks are reported separately by the assertions.

Đã kiểm tra CRC bằng mô hình chia đa thức độc lập, reset, stall và hai kênh đồng thời.
Synthesis dùng cell generic; số cell không phải diện tích hoặc timing của thư viện ASIC.
Có thể chạy lại toàn bộ bằng `make v2-verify`; không chỉnh RTL để làm test pass.
