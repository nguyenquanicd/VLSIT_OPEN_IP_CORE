# Pipeline options for timing closure: evaluation and result (2026-11-24)

Status: the three options are specified (HDS DEC-036, REQ-PARAM-004, TEST-034, TBD-028) and
implemented in `rtl/` with the parameters `PARA_PIPE_CHACHA`, `PARA_PIPE_POLY` and `PARA_PIPE_IO`,
all 0 by default so that the configurations behave as before. The target clock and the technology
are not known (TBD-002): this document ranks options and does not say which one a product needs.

## 1. Method

Depths are unit-delay levels of 2-input gates from `syn/depth.sh` (yosys with the slang front end,
Kogge-Stone adders, no timing-driven restructuring, longest path between flip-flops and ports).
They rank paths and are not nanoseconds. Flip-flop counts are the yosys counts of the same runs.
Cycle counts are from the scratch simulation of `m_chacha_core` (`verification/tests/smoke`:
`tb_perf.sv`, `runperf_all.sh`, `cmp_perf_pipe.py`), key store answering after 2 cycles, whole input
loaded before the start, 17 messages, three configurations.

## 2. Result: depth and area

| Part | Levels without | Levels with | Flip-flops added | Option |
|---|---:|---:|---:|---|
| ChaCha20 core, 1 round per cycle | 54 | 30 | 1059 per core | `PARA_PIPE_CHACHA` |
| ChaCha20 core, 2 rounds per cycle | 100 | 52 | 1059 per core | `PARA_PIPE_CHACHA` |
| Poly1305 architecture 0 | 52 | 45 | 66 | `PARA_PIPE_POLY` |
| Poly1305 architecture 1 | 62 | 46 | 385 | `PARA_PIPE_POLY` |
| Poly1305 architecture 2 | 90 | 52 | 631 | `PARA_PIPE_POLY` |
| Input stream adapter | 40 | 24 | 1 | `PARA_PIPE_IO` |
| AXI window logic | 38 | 25 | 1 | `PARA_PIPE_IO` |

Corrections to the first evaluation of the same day, found by measuring the RTL: architecture 1
reached only 56 levels with the first cut (reduction split in two cycles) because the third
multiplication starts with a 67-bit addition; registering the two operand sums brought it to 46.
Architecture 0 reaches 45, not 30, because the limb selection and the 32 by 32 multiplier remain
in one cycle.

## 3. Result: throughput

Relative to CFG-BASE without options (25.6 Gbit/s per GHz at 62 levels), computed as (rate per
GHz) x (62 / critical depth) / 25.6, with the rate per GHz limited by Poly1305 when its interval
is longer (23, 6 and 2 cycles with `PARA_PIPE_POLY`):

| Configuration | No option | `PARA_PIPE_CHACHA` | `PARA_PIPE_POLY` | Both |
|---|---:|---:|---:|---:|
| CFG-LP | 0.26 | 0.27 | 0.25 | 0.30 (depth 45, Poly1305) |
| CFG-BASE | 1.00 | 1.00 | 0.96 | 1.12 (depth 46, Poly1305) |
| CFG-HP | 2.48 | 2.76 | 1.55 | 2.98 (depth 52, cipher; Poly1305 limits the rate to 64 Gbit/s per GHz) |

- A single option helps only with `PARA_PIPE_CHACHA`: +4 percent (CFG-LP), none (CFG-BASE), +11
  percent (CFG-HP). `PARA_PIPE_POLY` alone lowers all three.
- Both together give +15, +12 and +20 percent. The gain is smaller than the first estimate (1.3
  times) because the Poly1305 paths stay at 45 to 52 levels.
- `PARA_PIPE_IO` changes none of the numbers: the critical path stays above 40 levels, so the
  unregistered input and window paths (40 and 38) never limit. It matters only if the engine
  paths are cut below 40 levels.
- The gain assumes that the clock follows the depth (ASM-016); it needs STA with a library.

## 4. Result: cycles

The formula of HDS 13.2 extends to the options without a new constant (pair granularity
$2C + 1$ for the ChaCha20 term and for the start of Poly1305, $P + 1$ for Poly1305, tail 6). Largest
difference of the measurement above the formula, for messages of at least one byte (limit 10
percent of REQ-PERF-001):

| Configuration | No option | `PARA_PIPE_CHACHA` | `PARA_PIPE_POLY` | Both |
|---|---:|---:|---:|---:|
| CFG-LP | +7.6 % | +5.9 % | +8.1 % | +6.6 % |
| CFG-BASE | +3.4 % | +5.1 % | +8.0 % | +6.4 % |
| CFG-HP | +10.0 % | +11.8 % | +9.1 % | +6.1 % |

These numbers are after DEC-037 (hand-off to Poly1305 and sequencer tail, requested for CFG-HP): before it CFG-HP was +25.0, +19.2, +18.2 and +12.1 percent (TBD-027). CFG-LP and CFG-BASE meet the limit in all combinations;
CFG-HP meets it with no option (at the limit) and with `PARA_PIPE_POLY`, and is 1.8 points above with `PARA_PIPE_CHACHA` alone
(0 bytes of associated data, 640 bytes of message: 85 cycles against 76); REQ-PERF-001 is stated for the
configurations without options. `PARA_PIPE_IO` gave identical cycle counts in all 51 rows compared. Cost of
the pairing: the key block alone (empty message) takes 21 cycles more on CFG-BASE (57 against 36), a message of
three blocks 22 more (117 against 95).

## 5. Verification done

- RFC 8439 reference model against `m_chacha_core` (after DEC-037) for the four combinations of
  `PARA_PIPE_CHACHA` and `PARA_PIPE_POLY` and the three configurations: 17 messages each, 0 data
  errors; with `PARA_PIPE_IO` = 1 also.
- Top-level simulation (`verification/tests/smoke/regress_pipe.sh`): 22 cases for each of the 8
  combinations of the three parameters, 176 runs, 176 pass, 0 fail: polling and DMA flows,
  decryption, wrong tag in hold mode, equal and unequal clocks, data widths 32 to 256, the core
  shapes of CFG-LP, CFG-BASE and CFG-HP, other quarter-round and core numbers, `tb_err` (40
  checks) and `tb_hw` (11 checks). The cases with `PARA_SYNC_*` = 1 use equal clocks.
- Message lengths 0 to 1280 with empty parts (`empty_cases.sh`, after DEC-037): encryption and decryption of 10
  messages on three core shapes, 60 cases, 60 pass.
- Metastability-model branch (no `VLSIT_SYNTHESIS`), all three options on, 3 seeds: pass.
- Rule check 0 errors (29 files); Verilator lint 0 errors for the default and for 24 parameter
  combinations (20 before the last Poly1305 edit, 4 after it).

Not done: waveforms of the block pairs, the DFT reset override, STA, synthesis with a library
(TBD-002, TBD-028).
