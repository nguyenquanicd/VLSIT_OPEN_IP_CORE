# Review of the lines that the line coverage run does not hit

Source: `COVERAGE_LINE.md` (Verilator line coverage of the top tests and the block unit tests, 2026-11-26) and the annotated
files in `verification/sim/cov_annotate` (lines starting with `%000000`). The program ROMs are left out (see `COVERAGE_LINE.md`).
Each never-hit line is put in one group below. "Phase 1" means the Icarus test of the CSR, control block and buffer
(`tests/dsig_p1/tb_tests.svh`): it runs the real RTL of these blocks, but Icarus gives no coverage, so these lines are hit
there and not counted here. A group marked **gap closed** had no test before this review; the test was added and its
mutant is caught.

## A. Default arms of complete case statements and illegal FSM states (not reachable)

`m_vlsit_dsig_axi.sv` 237, 268; `m_vlsit_dsig_brd.sv` 95; `m_vlsit_dsig_bwr.sv` 93; `m_vlsit_dsig_ctl.sv` 402, 454, 459,
610 to 612 (illegal state: goes to ENUM_ST_CLEAR and raises `w_state_bad`), 735; `m_vlsit_dsig_ec.sv` 518, 732, 1004, 1018,
1019, 1144, 1145; `m_vlsit_dsig_hbs.sv` 530, 688; `m_vlsit_dsig_hfeed.sv` 225, 274; `m_vlsit_dsig_hseq.sv` 331;
`m_vlsit_dsig_key.sv` 176; `m_vlsit_dsig_lat.sv` 517; `m_vlsit_dsig_rng.sv` 270; `m_vlsit_sha_core256.sv` 129;
`m_vlsit_sha_keccak.sv` 116; `m_vlsit_csr_dsig.sv` 2540 (read of an unmapped offset inside the decoded range).

The state registers are binary-encoded with every used code listed, so the default arm needs a corrupted state register
(fault injection, not in the scope of this verification).

## B. Instructions of the engine instruction sets that the current programs do not use

`m_vlsit_dsig_lat.sv` 278 to 282, 646, 649 (SAR, SARI), 671 (read of the algorithm code), 682 to 684 (FNOT, FAND, FOR),
705 to 708 (ERR); `m_vlsit_dsig_hbs.sv` 667 (XOR; the programs use XORR), 695 to 697 (FNOT, FAND, FOR);
`m_vlsit_dsig_ec.sv` 955 (BRN taken), 991, 992 (immediate string into the middle part of a hash).

Checked by searching the program generators (`models/lat/lat_prog*.py`, `models/hbs/hbs_prog_*.py`): the lattice programs
emit no SAR, SARI, FNOT, FAND, FOR or ERR; the hash-based programs emit no XOR, FNOT, FAND or FOR. These lines can only
matter if the programs change; they are candidates for removal (area) or need a test when a program starts to use them.

## C. Defensive checks inside an engine that the control block makes unreachable

`m_vlsit_dsig_hbs.sv` 496, 645 to 647 and `m_vlsit_dsig_lat.sv` 453, `m_vlsit_dsig_ec.sv` 643 (an engine started with an
algorithm whose group is not built): the control block rejects such a start first with `dsig_err.opuns` (phase 1, ERR-002
cases of `t_errors`, lines 440 to 452), so the engine never sees it. The same holds for `m_vlsit_dsig_hbs.sv` 515 and 718
to 721: the only ERR instruction of the hash-based programs is `SLH_OPUNS` (`hbs_prog_slh.py` line 256), reached for a
form code of 2 or 3, which the control block rejects first (`t_errors` lines 448, 449).

## D. Hit in the engine tests alone (not part of the coverage run)

- `m_vlsit_dsig_ec.sv` 661, 958 to 961: the ERR instruction (BADKEY, BADPT). Run by `tb_ec p256` vectors "sign d = 0
  (BADKEY)", "sign d = n (BADKEY)" and "verify point not on curve" (`models/ec/gen_ec_vec.py`, `ecdsa_set`).
- `m_vlsit_dsig_ec.sv` 515 to 517: SHA3-256/384/512 for ECDSA. **Gap closed**: no vector used them before this review
  (DEC-018); set `tb_ec sha3` (15 vectors, signatures checked by OpenSSL) and mutant M13 were added.

## E. Hit in phase 1 (Icarus, real control block and CSR)

- `m_vlsit_dsig_ctl.sv` 429, 430, 434 (XMSS set out of range and the high sets): `t_errors` lines 463 to 467.
- `m_vlsit_dsig_ctl.sv` 464, 467, 483, 487 (reserved hash 6/7, reserved hybrid policy, HSS level 0 and above 8, prehash
  length that does not match the digest): `t_errors` lines 449 to 452, 470, 487 to 499, and the random test `t_random`.
- `m_vlsit_dsig_ctl.sv` 508 (`bufovf` in the check): `t_buffer` and `t_random` (offsets past the buffer).
- `m_vlsit_dsig_ctl.sv` 589 (abort in ENUM_ST_RUN): `t_abort`; 590 (engine error): `t_eng_err`; 600 (verify-after-sign
  mismatch): `t_vas`; 831 (log lock): `t_lock`, `t_log`.
- `m_vlsit_dsig_ctl.sv` 581 (abort in ENUM_ST_RNG) and 598 (abort in ENUM_ST_VAS): **gap closed**: no test aborted in these
  two states before this review (REQ-SEC-005 allows an abort at any time); `t_abort` now aborts in both and checks no
  result, no error, no flag and cleared key words.
- `m_vlsit_csr_dsig.sv` 2485 to 2494, 2513, 2514, 2520 (reads of the capability, interrupt status, alarm and log-lock
  registers): `t_reset_regs` (lines 187 to 216) and `t_log`; 827 (PSLVERR register, loaded only with `i_slverr_en` 1, which
  the top tests tie to 0): `t_apb_proto` (lines 321 to 340).
- `m_vlsit_csr_dsig.sv` 2512 (read of `dsig_irq_inj`): **gap closed**: phase 1 only wrote this rw register; `t_irq` now
  reads it back.

## F. Corner paths without a test (reviewed, not closed)

| Line | Path | Why it is not tested | Risk |
|---|---|---|---|
| `m_vlsit_dsig_ec.sv` 671, 1028 to 1032 | POW multiplication through the bit-serial multiplier | POW runs only with the odd moduli p and n, whose products go to the Montgomery multiplier (ENUM_ST_MM); the bit-serial path is used for the even moduli, which no POW uses | none for the current programs; dead logic |
| `m_vlsit_dsig_ec.sv` 901, 902, 904 | POW with exponent 0 or 1 | the programs use the constant exponents p - 2, n - 2, (p - 5) / 8, (p - 3) / 4 | none for the current programs |
| `m_vlsit_dsig_hbs.sv` 836 | table-2 address without a buffer offset | not used by the programs (every table-2 read is relative to a buffer field) | none for the current programs |
| `m_vlsit_dsig_hbs.sv` 767 | byte compare of length 0 sets the equal flag | no program compares 0 bytes | none for the current programs |
| `m_vlsit_dsig_hbs.sv` 857 | the buffer has no valid data when the engine reads it | the buffer answers every engine read in one cycle; the wait is for a slower buffer | low |
| `m_vlsit_dsig_hseq.sv` 317, 318 | output phase with a digest length of 0 | no job asks for 0 output bytes (the engines always ask for a digest) | low |
| `m_vlsit_dsig_rng.sv` 293 | reseed command in the same cycle as a clear | timing coincidence; the command is kept pending, the same code as line 299 that is hit | low |
| `m_vlsit_sha_pad.sv` 84 | SHA3-224 block size | the IP never selects SHA3-224 (the hash library supports it) | none |
| `m_vlsit_dsig_axi.sv` (now hit) | buffer busy in the middle of a burst | **gap closed**: `tb_axi` mid-burst test, mutants M10 and M11 (DEC-050) | - |
| `m_vlsit_dsig_key.sv` 117, 118 (now hit) | `PARA_KEY_SRC` 0 and 1 | **gap closed**: `tb_key_rng` section 7, mutant M12 (DEC-051) | - |
