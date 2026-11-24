# Phase 1 verification: CSR, control block and buffer

Simulation testbench of the delivered blocks of the digital signature IP: the generated CSR
(`rtl/csr/`), `m_vlsit_dsig_ctl` and `m_vlsit_dsig_buf`. It is written from the specification
`spec/VLSIT_DIGITAL_SIGNATURE_HDS.md` and from the APB specification IHI 0024D; the RTL was read
only for port names and widths (R-023). The blocks that are not written yet (engines, key block,
random block, verify-after-sign block, zeroization of the secrets, AXI4 block) are behavioral models in
`env/dsig_p1/tb_models.svh`; they follow sections 10.1, 10.2 and 11.3 of the specification.

What was found and what is open: `FINDINGS.md`. Results of the last run: the tables at the end of this file.

## Folder (repository layout: docs, tests, models, env, sim)

| Path | Content |
|---|---|
| `docs/` | This README, `FINDINGS.md`, `TEST_REVIEW.md` (review of the strength of the tests), `mutation_report.md`, `auto_mutation_report.md`, `auto_mutation_report_sync.md`, `waveform_compare.md` (copy of the index of the evidence folder) |
| `tests/dsig_p1/` | `tb_dsig_p1.sv` (testbench top) and `tb_tests.svh` (operation helper, 19 test groups, waveform scenarios, main sequence) |
| `models/dsig_p1/` | `tb_ref.svh`: reference model of the control block written from the specification (order of the checks, DEC-030 to DEC-035) |
| `env/dsig_p1/` | `dsig_p1_wrap.sv` (wrapper that connects CSR, control block and buffer as sections 11.3 and 14.2 describe; replaced by `m_vlsit_dsig_top` later), `tb_tasks.svh` (APB4 requester, buffer bus helpers, reset, operation helpers), `tb_models.svh` (behavioral models), `tb_chk.svh` and `tb_checkers.svh` (assertion tables and instances), `dsig_apb_assert.sv` (29 APB4 assertions), `dsig_p1_assert.sv` (38 assertions on the control block, buffer and interfaces), `dsig_wf_probe.sv` (names of the figure signals for the VCD), the scripts `run_regress.py`, `run_waveforms.py`, `vcd_compare.py`, `run_mutation.py` and the `Makefile` |
| `sim/regress/` | One log per run: `syn_async1`, `sim_async1_seed1..3`, `syn_async0` |
| `sim/waveforms_sim/` | VCD, WaveJSON, SVG of each simulated waveform and `waveform_compare.md` (evidence of R-033) |
| `sim/build/` | Compiled simulation images (can be deleted) |
| `../archive/pre_testbench_rtl_2026-11-24/` | `m_vlsit_dsig_buf.sv` and `m_vlsit_dsig_ctl.sv` before the fixes of `FINDINGS.md` |

## Run

Simulator: Icarus Verilog 14 (OSS CAD Suite). On Windows put `C:\Tools\oss-cad-suite\bin` and `lib` on PATH and
set `TMP` and `TEMP` to an existing folder. The filelist uses paths relative to `rtl/`; the scripts run the
simulator from there.

```powershell
python env/dsig_p1/run_regress.py --n 200 --seeds 1,2,3     # all runs, logs in sim/regress/
python env/dsig_p1/run_waveforms.py --skill <skills>/vlsit-asic-ip-microspec --python python
python env/dsig_p1/run_mutation.py --n 80 --jobs 4          # works in $TEMP, report in docs/
python <skills>/vlsit-rtl-generator/scripts/vlsit_sim_evidence.py check spec/VLSIT_DIGITAL_SIGNATURE_HDS.md verification/sim/waveforms_sim --logs verification/sim/regress
```

Plusargs of one run: `+ONLY=<1..19>` one test group, `+N=<n>` random operations, `+SEED=<n>` random stream,
`+AFIFO_MSYNC_SEED=<n>` metastability model of the library, `+TAPB=<ns>` APB clock period (asynchronous build),
`+WAVE=<n> +DUMP=<file>` one waveform scenario.

## What is simulated

| Run | Branch of the synchronizer wrapper | APB and register clock | Purpose |
|---|---|---|---|
| `syn_async1` | synthesis (`VLSIT_SYNTHESIS`, library cells) | asynchronous, 10 ns core and 17 ns APB | the netlist that is built |
| `sim_async1_seed1..3` | simulation model with random extra latency | asynchronous | metastability model, three seeds (R-034) |
| `syn_async0` | synthesis | one clock (`PARA_ASYNCHRONOUS` 0) | the build of the figures of section 10.3.1 |

Test groups (focused group first, then integrated flows; every test names its TEST-ID and requirement IDs):
1 reset values, version, capability (TEST-015); 2 register read and write; 3 APB4 access cases of section 11.4
(TEST-016); 4 enable bits and start (TEST-013); 5 errors of the check with DEC-038 priority (TEST-009, 010, 023);
6 buffer and numbered example 1 (TEST-033, 017, 020); 7 clearing of the secrets (TEST-028); 8 verify-after-sign
mismatch (TEST-026); 9 key and entropy timeouts (TEST-030); 10 engine errors; 11 abort and reset during an
operation; 12 start and window write while busy (ERR-012); 13 interrupts and alarm (TEST-018); 14 lock (TEST-014);
15 counters and log lock (TEST-029); 16 corrupted state encoding (DEC-035); 17 flows of every algorithm and
operation; 18 hybrid verification, numbered example 2 and every policy (TEST-012); 19 constrained-random
operations against the reference model of the specification.

Build used: all algorithms, signing of the first 12 algorithms, verification of all 15, 1 KiB buffer with
64-bit words, verify-after-sign, hybrid, lock and log built, ECDSA nonce selected by the CSR. Other values of
the build parameters are not simulated (see `FINDINGS.md`, section 4).

## Results of the last run (2026-11-24)

| Item | Result |
|---|---|
| Regression, 5 runs (`sim/regress/`) | all PASS: 19 test groups, 264 different checks, about 22,000 to 24,000 executions per run (over half of them the bookkeeping check that an APB access gave no error), 0 failed checks |
| Assertions | 29 APB4 and 38 core assertions: 0 failures, 0 never exercised in every run |
| CDC runs (R-034) | `vlsit_sim_evidence.py cdc`: PASS (synthesis runs 2, metastability seeds 1, 2, 3) |
| Mutation (`mutation_report.md`, `auto_mutation_report*.md`, `TEST_REVIEW.md`) | 38 handpicked bugs: 38 caught (chosen by the author of the tests, weak evidence). 80 automatic operator flips at places sampled by a random seed: 77 caught in the asynchronous build and 78 in the one-clock build; survivors A05 and A62 are equivalent, A13 is a remaining weakness of the asynchronous build |
| Waveforms (`sim/waveforms_sim/waveform_compare.md`) | WF-015 MATCH with the original figure; WF-003, 005, 007, 008, 009, 011, 012, 016 were DIFFERENT (schematic figures) and the figures of the specification were replaced by the simulated waveforms on 2026-11-24 (designer decision; `spec/figures/make_sim_figures.py`, former figures in `archive/spec_figures_before_sim_2026-11-24/`), the index keeps DIFFERENT (resolved by the replacement) because agreement with a figure made from the simulation is not evidence; WF-001, 002, 004, 006, 010, 013, 014, 017, 018 NOT-SIMULATED (blocks not written). `vlsit_sim_evidence.py check` reports 18 errors, all for the NOT-SIMULATED waveforms |
| Rule check and lint of `rtl/` | PASS; Verilator `-Wall` 0 warnings for the control block and the buffer; one justified HIE-02 warning |
| Not requested | code coverage (R-047: not_requested) |
