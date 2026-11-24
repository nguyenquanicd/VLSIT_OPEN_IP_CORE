# Change proposal for 019_SHA2_SHA3_Hash: split out a bus-free hash engine `m_vlsit_sha_eng`

Status: **proposal, approved by the user on 2026-11-24, not applied; the user chose option C (the wrapper is built inside 028 and 019 stays unchanged)**. Nothing in `019_SHA2_SHA3_Hash` has been changed. Date: 2026-11-24.
Requested by the user in the specification of `028_Digital_Signature` (decision DEC-003, answers 1B and 4b).

## 1. Why

The digital signature IP needs SHA-2 (SHA-256, SHA-384, SHA-512) and SHA-3/SHAKE for every algorithm (Ed25519: SHA-512; Ed448: SHAKE256; ECDSA: SHA-2 or SHA-3; ML-DSA and SLH-DSA: SHAKE; LMS and XMSS: SHA-256 or SHAKE256). The user wants the core logic of 019 reused so that no private hash core is built in 028, without the bus interfaces of 019 (APB4 CSR, AXI4 subordinate, DMA, FIFOs, context memory).

## 2. What 019 has today (read from the RTL, not simulated)

| Item | Where | Observation |
|---|---|---|
| Compression cores | `m_vlsit_sha_core256`, `m_vlsit_sha_core512`, `m_vlsit_sha_keccak` | Clean ports: `i_clk_core`, `i_rst_n_core`, `i_start`, `i_clr`, `o_done`, `i_block`, `i_state`, `o_result`, `o_par_err`; parameter `PARA_UNR` (rounds per cycle) and `PARA_PAR` (parity). No bus signals. |
| Masked Keccak | `m_vlsit_sha_keccak_dom` with `m_vlsit_sha_prng` | Instantiated in the top when `PARA_MASK` is 1; the header of the top says this belongs to stage 2b and that its parameters must be 0 for now. |
| Padder | `m_vlsit_sha_pad` | Instantiated inside the sequencer `m_vlsit_sha_seq`; takes algorithm code, one block, byte count, last flag and total length; algorithm codes 2 to 5 (SHA-2 512 family), 8 to 11 (SHA-3), 12 and 13 (SHAKE). |
| Core instances and result selection | `m_vlsit_sha_top` (instances around lines 900 to 1100) and `m_vlsit_sha_sel` | The top instantiates the cores on a shared block bus `w_core_blk` and state bus `w_core_state`, duplicated cores when `PARA_FAULT_DUP` is 1, and the selector `m_vlsit_sha_sel`. |
| Sequencer | `m_vlsit_sha_seq` (1024 lines) | Owns the context table, prefetch, init, final, abort and clear commands; coupled to the input FIFO, the output path and the CSR commands. **Not reusable** by the signature IP. |

## 3. Proposed change

Create one new module `m_vlsit_sha_eng` that contains exactly what is now inline in the top: the core instances, the optional duplicate cores, the parity and duplicate checks, and the result selector. It has no context memory and no bus. The interface is block-level:

| Port | Direction | Width | Meaning |
|---|---|---:|---|
| `i_clk_core`, `i_rst_n_core` | Input | 1 | Clock and reset |
| `i_alg` | Input | 4 | Algorithm code, same encoding as `m_vlsit_sha_pad` |
| `i_start` | Input | 1 | Pulse: process the block now on the block bus |
| `i_clr` | Input | 1 | Clear the state of the selected core |
| `i_block` | Input | 1344 (parameter dependent) | Padded block |
| `i_state` | Input | 1600 (3200 with masking) | Chaining state or sponge state |
| `i_rnd`, `i_mask_en` | Input | parameter dependent | Masking randomness and enable, only when `PARA_MASK` is 1 |
| `o_done` | Output | 1 | Block result ready |
| `o_result` | Output | 1600 | Next state or digest bits |
| `o_par_err`, `o_dup_err` | Output | 1 | Parity and duplicate mismatch flags |

Parameters: `PARA_EN_*` for the algorithm families built, `PARA_S256_UNR`, `PARA_S512_UNR`, `PARA_KEC_UNR`, `PARA_FAULT_PAR`, `PARA_FAULT_DUP`, `PARA_MASK`.

Changes to 019:
1. Add `rtl/m_vlsit_sha_eng.sv`.
2. In `m_vlsit_sha_top.sv`, replace the inline core, duplicate-core and selector instances by one `u_eng` instance. No behavior change, no port change, no CSR change.
3. Add `m_vlsit_sha_eng.sv` to `rtl/filelist.f`.

Changes in 028 (not in 019): a small single-context streaming sequencer built on `m_vlsit_sha_eng` and `m_vlsit_sha_pad` that provides a byte-stream input, SHAKE absorb and continuous squeeze (repeated permutation) and SHA-2 multi-block hashing, plus an arbiter that serializes the users.

## 4. What stays unchanged in 019

The sequencer, FIFOs, context memory, APB4 CSR, AXI4 port, DMA, interrupts and fault logic of 019 are untouched, so 019 keeps all its features, including several contexts.

## 5. Risks and open points

- **019 is not re-certified.** Its README says that functional, lint, CDC, RDC and synthesis status was not rerun. A refactor must be followed by the full regression of 019 and a comparison with the previous results; the proposal does not claim any of that.
- **Masked Keccak.** Masking in 019 is stage 2b. The signature IP option `PARA_EN_DPA_PQ` for hash-based operations depends on a working masked Keccak; until then that option cannot rely on 019.
- **Interface width.** The block bus is as wide as the largest block (SHAKE128 rate); the stream sequencer in 028 pads and splits the data into blocks.
- **Area.** Moving instances does not change area; sharing one engine between 019 and 028 inside one SoC requires the integrator to decide whether the two IPs share one engine or build two (not decided here).
- **Not yet read in full:** the result selector and the duplicate-compare logic of the top (lines about 1060 to 1210). The exact port list of `m_vlsit_sha_eng` must be confirmed against them before editing.

## 6. Verification plan after the change

1. Run lint of 019 and compare with the old log.
2. Run the existing regression of 019 (functional, mutation) and compare pass counts.
3. Add a directed test that drives `m_vlsit_sha_eng` directly with the known-answer vectors of FIPS 180-4 and FIPS 202.
4. Synthesize 019 and compare the area report with the previous one.

## 7. Decision needed

Approve or change this proposal. Only after approval will 019 be edited, through the skill `vlsit-rtl-spec-change-implementer` or `vlsit-rtl-generator` in modify mode, with a snapshot of the original files.

## 8. Baseline check before the edit (2026-11-24, nothing in 019 changed)

The proposal was approved by the user on 2026-11-24. Before editing, the baseline of 019 was run in this environment; it is **not clean**, so the edit was not made.

| Check | Command (from `019_SHA2_SHA3_Hash/rtl`) | Result |
|---|---|---|
| `make lint` | Skill script `vlsit_lint_rtl.py lint rtl/filelist.f` | Fails: the script does not accept the comment lines at the head of `rtl/filelist.f` ("file(s) in the filelist not found: # Master filelist ..."). |
| Verilator lint, direct | `verilator_bin.exe --lint-only -Wall -Wno-fatal --top-module m_vlsit_sha_top -f filelist.f` | Fails with MODMISSING: `m_vlsit_rst_sync` is not in `rtl/filelist.f` (it is in `000_Common/rtl_lib/m_vlsit_rst_sync.sv`). With that file added on the command line the run passes with 68 warnings (BLKSEQ 5, PINCONNECTEMPTY 10, UNSIGNED 2, UNUSEDPARAM 3, UNUSEDSIGNAL 31, WIDTHTRUNC 17). |
| `make verify` | iverilog | Fails: the temporary directory `C:\TEMP` does not exist; with `TMP` set, `tb_sha_top` needs `verification/env/legacy_tb/sha_checkers.sv` (not in the Makefile), and then iverilog stops with 8 errors in `m_vlsit_sha_seq.sv` (non-constant index, assignments that need a cast), constructs that iverilog does not accept. |
| Verilator simulation | Not run | A binary link failed earlier in this environment (`ld returned 5`), so no Verilator simulation of 019 was possible in this session. |

Consequence: the regression of section 6 cannot be run here, so a refactor could not be shown to leave behavior unchanged by simulation. Options for the user: (a) first repair the 019 flow (filelist dependency, lint script comment handling, a Verilator run) and then refactor; (b) refactor and prove equivalence of `m_vlsit_sha_top` before and after with a yosys equivalence check (OSS CAD Suite is installed) plus lint; (c) leave 019 as is and build the engine copy inside 028 (cores unchanged, a thin wrapper `m_vlsit_sha_eng` inside 028 that instantiates the 019 cores), changing 019 later.

## 9. Flow repair done (2026-11-24)

At the request of the user ("fix the 019 flow first") the flow of 019 was repaired; the RTL was not changed. A snapshot of the old `rtl/filelist.f` and `Makefile` is in `019_SHA2_SHA3_Hash/archive/pre_flow_repair_2026-11-24.tar`.

| Change | Result |
|---|---|
| `rtl/filelist.f`: add `../../000_Common/rtl_lib/m_vlsit_rst_sync.sv`; header lines changed from `#` to `//` | `make lint` (skill script, Verilator): `RESULT: PASS (0 errors, 68 warnings)`, the same 68 warnings as the direct Verilator run of the baseline; `make rule`: PASS |
| `Makefile`: lint log goes to `lint/lint_verilator_make.log` (not into `rtl/`); `verify` runs the new runner | `make verify SUITES=perf_u1`: scoreboard 40 pass, 0 fail, 33056 cycles |
| New `verification/env/run_regress_ws.py`: copies the testbench, vectors, reference vectors and scripts into the layout that the old scripts expect, in a temporary workspace, runs `run_regress.py`, optionally saves the logs under `verification/sim/` | Five suites reproduce the earlier summary exactly: main64 14865 pass and 1040480 cycles, dma64 1022 and 33569, fault_dup64 231 and 44053, mask_reg64 593 and 19499, perf_u1 40 and 33056; all with 0 failures and 0 assertion failures |

Not done: the other suites of the earlier summary (main32, main128, dma32, dma128, fault_par64, fault_redo64, fault_all64, mask_reg32, mask_ent64, mask_stat64, mask_statctl64, mask_fault64, main64_mask, perf_u2, perf_u4, perf_redo, perf_mask), the static and unit steps of `run_all.py`, mutation, coverage, CDC, RDC and synthesis. With the flow repaired, the refactor of option A or B of section 8 can be checked by running the same suites before and after.
