# Review of the phase 1 tests (2026-11-24)

Purpose: find tests whose pass says less than it seems. The author of the testbench is also the author of the RTL and of the
reference model, so this review uses means that do not depend on the author's judgement: a count of how often each check runs,
mutation of the RTL at places sampled by a random seed, and a reading of every place where the testbench was changed after a
failure. What was found, what was fixed, and what is still weak are listed below without rounding up.

## 1. Statements of the earlier reports that overstated the evidence

| Earlier statement | What is true |
|---|---|
| "21,600 checks per run, 0 failed" | The run has 264 different checks and 22,121 executions. 12,578 of them are the bookkeeping check "no PSLVERR on an APB access" that every register access makes (6,847 writes, 5,731 reads). The count measures activity, not strength. |
| "Waveforms WF-003 ... 016 MATCH" | After the figures of the specification were replaced by the simulated waveforms, the comparison agrees by construction. It is not evidence. The index now says DIFFERENT, resolved by the replacement, with no independent MATCH claimed. Only WF-015 is a real MATCH (the figure was drawn from the specification and the simulation agrees in all 70 slots). For the other eight waveforms nothing in the project now checks the cycle behavior of the figure against an independent source; the assertions and tests of section 15 check the behavior in other ways. |
| "Mutation 38 of 38 caught" | The 38 bugs were chosen by the author with the tests in mind. The automatic run of section 3 is the fair measure. |
| "APB assertions from IHI 0024D" | APB-01 to APB-20 and APB-29 come from the standard. APB-21 to APB-28 come from section 11.4 of the specification, which records the behavior of the generated CSR as it was measured; they check that the generated CSR still does what it did, not that it meets an independent intent. |
| "Reference model written from the specification" | True for the rules, but it was written and later adjusted by the same person who wrote the RTL, after reading the RTL while analysing failures. It is not an independent model. |

## 2. Where the testbench was changed after a failure (every case)

| Change | Reason | Judgement |
|---|---|---|
| "resvld stays 0" checked only after a clear command | A previous result stays until the clear command (workbook) | Testbench fault, correct |
| Hybrid policy applied to every ML-DSA size | DEC-030 text says every ML-DSA verification | Correct, from the specification |
| Prehash length rule limited to ECDSA, ML-DSA and (now) Ed25519ph and Ed448ph with SHA-512; random stimulus avoids the prehash form of the other algorithms | The specification does not say (TBD-015) | Coverage was given up to match the RTL. **This is a hole**, listed in section 4. |
| Random stimulus does not run Ed25519ctx and Ed25519ph verifications | TBD-016 | Same: a hole |
| Key generation forced to pure form, length 0 in the random test | Showed an RTL difference before F-2 was fixed | Removed on 2026-11-24 (the RTL now agrees) |
| Assertions 9 and 38 moved from ENUM_ST_CHECK to ENUM_ST_ERR | The specification says ENUM_ST_ERR holds the flags | Correct |
| Wait times and engine latency of three tests | The operation ended before the checks | Testbench fault, correct |
| Checks of the disabled-IP start and of `dsig_cmd.clr` made normal after the decisions DEC-042 and DEC-043 | The designer decided; the RTL was changed | Correct |

## 3. Checks of the strength of the tests

**Count of executions.** `CHECKSTAT` lines at the end of every log give executions and failures of each check. 56 checks run once or twice
and are killed by a mutant; 179 checks never fail in any of the 38 handpicked mutants. Most of these are register reset-value and
read-write checks of the generated CSR, which no mutant of the control block or the buffer can reach; they check the CSR against
the workbook and are meaningful. The others are listed in section 4.

**Automatic mutation** (`env/dsig_p1/run_auto_mutation.py`, `auto_mutation_report.md` and `auto_mutation_report_sync.md`): 80 places of
`m_vlsit_dsig_ctl.sv` and `m_vlsit_dsig_buf.sv` sampled by seed 20261124, one operator flipped at each, 60 random operations per run.

| Build | Caught | Survived |
|---|---:|---|
| Asynchronous CSR clocks | 77 of 80 | A05, A13, A62 (A13 is a weakness, the other two are equivalent) |
| One clock | 78 of 80 (A09 after the correction of the reset release, see below) | A05, A62 (equivalent) |

Analysis of the survivors and of the first run (five survivors before the tests were strengthened):

| Mutant | Place | Verdict |
|---|---|---|
| A05 | `m_vlsit_dsig_buf.sv:176` default value of `w_wr_en` in the write multiplexer | Equivalent: every branch of the `casez` sets the value |
| A62 | `m_vlsit_dsig_ctl.sv:720` `default` of the hybrid policy case | Equivalent: the reserved policy 3 is rejected in ENUM_ST_CHECK, the branch is unreachable |
| A08 | `m_vlsit_dsig_buf.sv:256` reset value of the read-reject flop | **Hole, fixed**: no test looked at the buffer outputs during reset. Assertion 35 now checks them |
| A13 | `m_vlsit_dsig_buf.sv:271` capture of the window read data | **Hole, fixed in the one-clock build only**: needs a window read in the same cycle as a bus read. The new test of the buffer group does this and the one-clock build catches the mutant. In the asynchronous build the crossing of the CSR makes the timing of the read event vary and the 24 cases do not hit the cycle, so A13 still survives there: a weakness that remains |
| A09 | `m_vlsit_dsig_buf.sv:263` reset value of the busy-error flop | **Hole, fixed**: survived the full one-clock run because the testbench released the APB reset (the register reset of the CSR in that build) many cycles after the core reset, so the wrong value had gone before the CSR could see it. The reset release is now simultaneous in that build and assertion 35 checks the buffer error outputs in reset; rerun: caught |
| A42 | `m_vlsit_dsig_ctl.sv:479` digest length of Ed25519ph and Ed448ph | **Hole, fixed**: tests use SHA-512 (unambiguous) with lengths 63, 64 and 65 |

## 4. Weak or missing checks that remain

- Prehash form of Ed25519, Ed25519ctx, Ed448, SLH-DSA, LMS and XMSS, and Ed25519ph and Ed448ph with other hash codes (TBD-015); latching of `edok` by Ed25519ctx and Ed25519ph (TBD-016). Not tested.
- Timeouts (ERR-008, ERR-009): the control block only reacts to the timeout pulse; the counting in units of 1024 clocks is done by the model of the testbench, so the tests do not check any timing of the real blocks. The CSR value `dsig_tmo` is only shown to reach the model.
- `n_zero_req >= 1` shows that the zeroization was requested, not when. The 100-clock limit is checked by assertion 14 with a model that needs at most 50 clocks.
- Assertions 19 and 20 (interrupt equations) and 13 (`o_zero` follows ENUM_ST_CLEAR) repeat the equations of the RTL; they are taken from the specification but cannot fail unless the RTL is edited.
- The checks of `dsig_cap_feat` skip the bits that the wrapper ties (`axi`, `dma`, `win`, `keyif`, `keyreg`, `rngsrc`).
- The edok and mlok latches are exercised by the hybrid tests; no handpicked mutant touched them. The automatic run decides.
- One build configuration only. The ECDSA nonce parameter other than 2, DPA, `PARA_EN_VAS` 0, `PARA_EN_HYBRID` 0, `PARA_EN_LOG` 0, `PARA_EN_LOCK` 0 and other buffer sizes are not simulated.
- Counter saturation is not tested.
- The handshakes with the key, random, engine and verify-after-sign blocks are the testbench models' idea of them (one-cycle pulses); no real block has been connected.
- The generated CSR is checked as a black box. Its register decoding is tested by reading and writing; its clock-domain crossing is tested by the three seeds of the metastability model and by one clock ratio (10 ns and 17 ns), not by a CDC tool.

## 5. Changes made by this review

- Engine read path: the data that the engine reads are now compared with the word written to the buffer (before, only "a valid arrived" was checked).
- Assertion 1 (state transitions) no longer allows the transitions that the specification does not list (CHECK to IDLE or CLEAR, IDLE to ERR, RESULT to IDLE, KEY, RNG, RUN and VAS to IDLE). Assertions 28 and 37 no longer accept the extra alternatives. Assertion 35 checks the buffer outputs in reset.
- New test: window read concurrent with a bus read (24 cases).
- New cases: Ed25519ph and Ed448ph prehash length with SHA-512.
- The random test no longer avoids key generation with a prehash length.
- Per-check counters (`CHECKSTAT`) in every log.
- The evidence index of the waveforms no longer shows MATCH for the replaced figures.
- Automatic mutation script and reports.
