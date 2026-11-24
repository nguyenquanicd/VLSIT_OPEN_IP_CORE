# Findings of the phase 1 verification

Record of what the testbench found, how each failure was analysed under R-026 (is the RTL, the test or the
specification at fault), and what is still open. The first RTL (before the testbench) is kept in `archive/pre_testbench_rtl_2026-11-24/`.

## 1. Bugs of the RTL found and fixed (the cause was clear from the specification)

| No. | Test that found it | Specification says | RTL did | Fix |
|---|---|---|---|---|
| F-1 | TEST-033 (numbered example 1, step 2), later every window write | Section 10.5 and example 1: a window write of 32 bits stores the written value at the window address | `m_vlsit_dsig_buf` wrote the data register `i_win_wr_data` in the cycle of the register event. The generated CSR raises `o_reg_wr_en` in the cycle in which the data register loads (the event is combinational on the captured APB transfer), so the old value was stored. The window read of the same address returned the old content | The buffer registers the event and writes one cycle later; the address is added after that write. DEC-039. The 47 failed checks of the buffer test disappeared |
| F-2 | TEST-010 (prehash with a wrong digest length) | Section 9 data table: "Prehash digests must match the selected hash length. Wrong digest length: bad-length error"; `dsig_op.hash` selects the hash "of ECDSA and of every prehash digest" | `m_vlsit_dsig_ctl` checked the length only for ECDSA and for Ed25519ph and Ed448ph | ML-DSA added to the check. DEC-040 |
| F-3 | TEST-028 (clear command) | Section 10.1 table: ENUM_ST_CLEAR is entered "after `dsig_cmd.clr`" and clears the key words; workbook `dsig_cmd.clr`: "Clears ... the secret state"; step S18 | `dsig_cmd.clr` in ENUM_ST_IDLE only cleared the result flags; key words written by software stayed | IDLE goes to ENUM_ST_CLEAR on the clear command. DEC-041 |

## 2. Faults of the testbench found and fixed (the cause was clear: the test broke a clause)

- The check "resvld stays 0 after a failing check" ignored that the result flag of an earlier operation stays until `dsig_cmd.clr` (random runs without a clear).
- The reference model applied the hybrid policy to ML-DSA-44 only; the specification says every ML-DSA verification (DEC-030). The RTL was right.
- The reference model applied the prehash length rule and the buffer rule to every algorithm and to key generation. Where the specification does not say (TBD-015) the stimulus avoids the case.
- A test used a stale counter value (`c0_ops`) and an engine latency shorter than the test itself (the operation had ended before the "while busy" checks).
- Assertions 9 and 38 assumed that the error flag is raised in ENUM_ST_CHECK; the flag is raised in ENUM_ST_ERR (section 10.1: ENUM_ST_ERR holds the error flags).

## 3. Decisions of the designer after the first run

| Item | Question | Decision (2026-11-24) | Change |
|---|---|---|---|
| TBD-013 | Start with `dsig_ctrl.en` 0: through ENUM_ST_CHECK (A) or rejected before the FSM (B) | A (DEC-042) | `m_vlsit_dsig_ctl`: the start is taken in IDLE, the first check fails with `algdis`, then ERR and CLEAR; the immediate error path was removed. Secrets are cleared and `cnt_fail` counts it |
| TBD-014 | `dsig_cmd.clr` and the error flags: hardware clears them (A) or the workbook text changes (B) | A (DEC-043) | New output `o_flags_clr` of the control block; the CSR hardware load writes 0 into `dsig_err`, `irq_raw.done` and `irq_raw.err` (a set of the same cycle wins); alarm and `irq_raw.sec` stay. The wrapper `dsig_p1_wrap.sv` shows the connection for the top |

After these changes all runs pass (see `README.md`).

## 3a. Still open (the specification does not decide; the testbench avoids these cases)

| Item | Question |
|---|---|
| TBD-015 | Prehash form and digest length of Ed25519, Ed25519ctx, Ed448, Ed25519ph, Ed448ph, SLH-DSA, LMS, XMSS (the RTL accepts the form without a length check for the first group and needs 64 bytes for the `ph` algorithms) |
| TBD-016 | Do Ed25519ctx and Ed25519ph verifications latch `edok`? (the RTL latches Ed25519 only) |

## 4. Not verified in this phase

- Saturation of the counters at 0xFFFFFFFF (about 4 billion operations; needs a force or a formal check).
- The AXI4 protocol (the AXI4 block `m_vlsit_dsig_axi` is not written; the buffer port of the bus side is driven directly) and the DMA handshake.
- Timeouts of the key block and the random block are modelled in the testbench (1024 core clocks per unit); the real blocks are not written.
- Waveforms WF-001, 002, 004, 006, 010, 013, 014, 017, 018 need blocks that are not written (NOT-SIMULATED).
- The DPA parameters (`PARA_EN_DPA_EC`, `PARA_EN_DPA_PQ`) and the ECDSA nonce parameter other than 2, and other build parameters: one build configuration is simulated (the defaults of `dsig_p1_wrap`).
- Code coverage was not requested (R-047: not_requested).
