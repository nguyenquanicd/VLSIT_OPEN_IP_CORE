# Verification of the second RTL phase: hash stack, engines, key, random, AXI4 and top

Scope: `m_vlsit_sha_eng`, `m_vlsit_dsig_hseq`, `m_vlsit_dsig_harb`, `m_vlsit_dsig_hfeed`, `m_vlsit_dsig_key`,
`m_vlsit_dsig_rng`, `m_vlsit_dsig_axi`, the elliptic-curve engine (`m_vlsit_dsig_ec`, `brd`, `bwr`, generated `ec_rom`),
the lattice engine (`m_vlsit_dsig_lat`, generated `lat_rom`), the hash-based engine (`m_vlsit_dsig_hbs`, generated `hbs_rom`)
and `m_vlsit_dsig_top`. The first phase (CSR, control block, buffer) is described in `README.md` and `FINDINGS.md`.

All simulations run in Verilator 5 (OSS CAD Suite) with the real RTL; only the buffer and the sources of the key and the
entropy are behavioral. Every test has an expected value that does not come from the RTL (column "Reference").

## Algorithms: what the expected values are

| Block | Test | Reference of the expected values | Independence |
|---|---|---|---|
| Hash stack | `tests/hash/tb_hseq.sv`, `tb_hfeed.sv` | Python `hashlib` (SHA-256/384/512, SHA3, SHAKE) | independent |
| Elliptic curve | `tests/ec/tb_ec.sv`, vectors `models/ec/gen_ec_vec.py` | RFC 8032 section 7.1 to 7.5 (Ed25519, Ed25519ctx, Ed25519ph, Ed448 with and without context, Ed448ph), RFC 6979 appendix A.2.5 to A.2.7 (P-256, P-384, P-521, nonce given, and the deterministic nonce computed by the engine), textbook group law (secp256k1), ECDSA with SHA3-256/384/512 (set `sha3`, DEC-018: textbook group law, every signature verified by OpenSSL `dgst -verify` when the vectors are made), rejection of corrupted inputs | independent (standard vectors) |
| Lattice | `tests/lat/tb_lat.sv`, vectors `models/lat/gen_lat_vec.py` | OpenSSL 3.6 (ML-DSA-44/65/87: public key from a seed, deterministic signature, hedged signature with `hextest-entropy`, valid signatures; HashML-DSA with message-encoding 0 over M' of FIPS 204) | independent |
| Hash-based, SLH-DSA | `tests/hbs/tb_hbs.sv`, vectors `models/hbs/gen_hbs_vec.py` | OpenSSL 3.6 signatures of all 12 sets, with and without a context string; HashSLH-DSA with OpenSSL message-encoding 0 over M' of FIPS 205 | independent |
| Hash-based, LMS/HSS and XMSS/XMSS^MT | same | LMS/HSS: RFC 8554 Appendix F test case 1 (`rfc8554_vectors.py`, set `rfc8554`: valid, corrupted, wrong message) plus signers written for the test (`lms_ref.py`); XMSS/XMSS^MT: signer written for the test (`xmss_ref.py`), its constructions checked against the RFC 8391 text by `test_xmss_rfc8391.py` (prefixes, address layout, identifiers, address types) | LMS test case 1 independent; test case 2 is not run (it mixes LMS types per level, which the IP does not support). XMSS **not independent**: RFC 8391 has no test vectors, so a misreading of a construction shared by the model and the RTL that the text check does not cover would not be seen |
| Key, random | `tests/key_rng/tb_key_rng.sv`; `tests/key_rng/tb_rng_drbg.sv` | directed checks written from the block description (key source with PARA_KEY_SRC 0, 1, 2: DEC-051); Hash_DRBG (SP 800-90A, SHA-512) against `models/rng/hash_drbg_ref.py` with reseed interval 3, and the KAT health test forced to fail (+KATFAIL) | key: self-written, directed; DRBG reference written for the test from SP 800-90A section 10.1.1 |
| Montgomery multiplier | `tests/ec/tb_mmul.sv`, vectors `models/ec/gen_mmul_vec.py` | Python integers: the Montgomery product a·b·2^(-w·nd) mod m for the moduli p and n of Ed25519, Ed448, P-256, P-384, P-521 and secp256k1, built with TB_W 32, 64 or 128; every product must take exactly nd + 1 cycles (start to done), whatever the operands | independent (Python big integers) |
| Hash arbiter (formal) | `formal/harb.sby`, properties `formal/harb_props.sv` | properties from section 10.4 (one owner, grant only to a requester, owner keeps the grant, fixed-priority hand-over, stream isolation); proven by k-induction; a mutant that re-arbitrates every cycle must fail | independent of the RTL text |
| Masking (DPA) | `tb_ec` with `TB_DPA`, `tb_top_ec` with `TB_DPA_EC`, `tb_lat` with `TB_DPA`, `tb_top_pq` with `TB_DPA_PQ` | same vectors as without masking (the result must not change); monitors count the blinded scalar multiplications and the masked products; `test_ec_dpa.py`, `test_lat_dpa.py` check the models | functional only: the result is unchanged and the masking path is taken; no leakage assessment |
| AXI4 block | `tests/axi/tb_axi.sv` | shadow memory updated only from the AXI4 rules of IHI 0022; a buffer that becomes busy in the middle of a burst (DEC-050: earlier beats kept, later beats refused, SLVERR) | self-written, directed; mutants M10 and M11 (refusal in the middle of a burst ignored) are caught |
| Top | `tests/top/tb_top_ec.sv`, `tb_top_pq.sv`, `tb_top_err.sv` | the vectors above through APB4, AXI4, key registers, entropy port, verify-after-sign and clearing; `tb_top_err`: time-outs, abort, lock, capability words, Ed25519ph form and length, `PARA_CSR_ASYNC` 1 with unrelated clocks | as above; error checks from section 12 |

The programs of the three engines were first run in bit-exact Python models of the processors (`models/*/*_isa.py`) and
compared with the references before the RTL existed; the RTL is the same instruction set (see the module headers).

## Commands

```powershell
python verification/env/misc/regress_all.py          # every test on the current RTL, logs at fixed places, then the matrix
python verification/env/misc/coverage_matrix.py      # docs/COVERAGE_MATRIX.md from the logs (PASS only with the exact counts)
python verification/env/misc/perf.py                 # docs/PERF.md: measured cycles against REQ-PERF-001/002
python verification/env/misc/run_mutants.py          # 13 defects put back into RTL copies (M12, M13 were run in a second call)
python verification/env/misc/run_params.py           # REQ-PARAM-001/002: 22 illegal, 8 legal parameter combinations
python verification/env/misc/run_unit.py top_sys +DIR=<dir of models/top/gen_sys_vec.py>   # combined system test
python verification/env/misc/run_unit.py rng_drbg +VEC=<models/rng/gen_drbg_vec.py> [+KATFAIL]
python verification/env/misc/run_unit.py mmul +VEC=<models/ec/gen_mmul_vec.py>      # with UNIT_DEFS=-DTB_W=32|64|128
python verification/env/ec/run_ec.py [quick|ed25519|ed448|edvar|det|p256|p384|p521|k256]     # EC engine, sets run in parallel
python verification/env/hbs/run_hbs.py [quick|slh|lms|xmss]                         # hash-based engine
python verification/env/lat/run_lat.py [quick|all]                                  # lattice engine
python verification/env/misc/run_unit.py key_rng                                    # key and random blocks
python verification/env/misc/run_unit.py axi                                        # AXI4 block with the buffer
python verification/env/misc/run_unit.py hfeed +VEC=<file from models/hash/gen_hfeed_vec.py>
python verification/env/misc/run_unit.py top_ec +VEC=<hex of models/ec/gen_ec_vec.py quick> +NVEC=10
python verification/env/misc/run_unit.py top_err                                    # time-outs, abort, lock, capability, Ed25519ph checks
python verification/env/misc/run_unit.py top_pq +DIR=<dir of gen_lat_vec.py or gen_hbs_vec.py> +KIND=lat|hbs +NVEC=<n>
python verification/models/hbs/test_hbs_slh.py ; python verification/models/lat/test_lat_prog.py   # Python models against OpenSSL
python verification/models/lat/test_lat_prehash.py ; python verification/models/hbs/test_hbs_slh_prehash.py   # pre-hash forms
python verification/models/ec/test_rfc6979_retry.py                                 # retry branch of the RFC 6979 nonce
python verification/models/hbs/test_xmss_rfc8391.py                                 # XMSS model against the RFC 8391 text
python verification/env/misc/run_formal.py           # SymbiYosys proof of the hash arbiter and its mutant
python verification/env/misc/check_sdc.py            # every port of the top constrained in sdc/m_vlsit_dsig_top.sdc
python verification/env/misc/check_cdc.py            # CDC and RDC structure of the CSR (yosys netlist walk) and 3 mutants
python verification/env/misc/check_hash_share.py     # REQ-FUNC-011: one instance of each hash core (Verilator elaboration)
python verification/env/misc/run_synth.py            # docs/SYNTH.md: generic yosys synthesis of blocks, 0 latches
python verification/env/misc/run_coverage.py         # docs/COVERAGE_LINE.md: line coverage of the top and block tests
                                                     # (--merge-only, --runs=a,b); never-hit lines: docs/COVERAGE_LINE_REVIEW.md
```

The Python models need OpenSSL 3.5 or later (`OPENSSL` environment variable, default `C:/Users/PC/Tools/msys64/usr/bin/openssl.exe`).
Logs and build products are in `sim/` (not versioned).

## Results of the last full run

See the table in section 15.6 of the specification and the logs in `sim/`. Honest limits:

- Line coverage of the top tests and the block unit tests is in `COVERAGE_LINE.md` (Verilator, line only); every line that
  is never hit is classified in `COVERAGE_LINE_REVIEW.md` (unreachable, unused instruction, hit in phase 1 or in the engine tests,
  or untested corner with its risk). No toggle, branch or functional coverage.
- Formal: only the hash arbiter is proven (SymbiYosys). No commercial CDC/RDC tool and no STA tool was run (`check_cdc.py` is a structural check of the one block with two clocks, see
  `../cdc/CDC_RDC_NOTES.md`); the SDC is checked only for port coverage and syntax patterns (`check_sdc.py`). Synthesis is generic yosys without a library
  (`SYNTH.md`): cell counts are not an area, and the Montgomery multiplier was synthesized without abc (not optimized).
- The tops `tb_top_ec` and `tb_top_pq` were simulated with `PARA_CSR_ASYNC` 0 and `tb_top_err` with 1 (APB clock 14 ns, core clock 10 ns); the buffer word is 64 bits, other widths are not supported.
- The sets exercised: Ed25519 and Ed448 (all RFC 8032 vectors up to 120 bytes), Ed25519ctx, Ed25519ph, Ed448 with context and Ed448ph (all RFC 8032 section 7.2 to 7.5 vectors, 68 vectors), P-256 (all RFC 6979 vectors), P-384 (two vectors), P-521 (one
  vector), secp256k1 (three random keys), ML-DSA-44 (11 vectors), ML-DSA-65 and 87 (7 each), SLH-DSA all 12 sets, LMS 10 combinations of type,
  one-time type and levels, XMSS and XMSS^MT 8 of the 44 sets (the sets with h = 16 and 20 and with 60/3, 60/6, 40/2, 40/4 are not run: their trees are
  too slow to build in the Python signer, the program is the same).
- Ed25519ph and Ed448ph take the digest PH(M) from software (ASM-023); the RFC 6979 nonce is built for SHA-2 only (ASM-024); HashML-DSA and HashSLH-DSA take PH(M) from software, LMS and XMSS verify the digest as the message (ASM-025). Masking (DPA) is tested only
  functionally (the result is unchanged and the masked path is taken): the EC scalar is blinded (k + r·n) and the ML-DSA masking covers the
  linear products of the rejection loop only (DEC-049); no power or leakage analysis. The RFC 6979 retry branch (k out of range) is
  reached only in the Python model (probability about 2^-128 with real vectors). The constant time of the Montgomery multiplier is
  checked by cycle count in simulation, not by a timing analysis.
- Zeroization is checked by hierarchical references to the registers and the word RAM of the engines, not by a property of the ports.
