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
| Elliptic curve | `tests/ec/tb_ec.sv`, vectors `models/ec/gen_ec_vec.py` | RFC 8032 section 7.1 and 7.4 (Ed25519, Ed448), RFC 6979 appendix A.2.5 to A.2.7 (P-256, P-384, P-521, nonce given), textbook group law (secp256k1), rejection of corrupted inputs | independent (standard vectors) |
| Lattice | `tests/lat/tb_lat.sv`, vectors `models/lat/gen_lat_vec.py` | OpenSSL 3.6 (ML-DSA-44/65/87: public key from a seed, deterministic signature, valid signatures); the reference model `mldsa_ref.py` for the hedged signature | independent for everything except the hedged signature (the model agrees with OpenSSL on every deterministic case) |
| Hash-based, SLH-DSA | `tests/hbs/tb_hbs.sv`, vectors `models/hbs/gen_hbs_vec.py` | OpenSSL 3.6 signatures of all 12 sets, with and without a context string | independent |
| Hash-based, LMS/HSS and XMSS/XMSS^MT | same | signers and verifiers written for the test (`lms_ref.py`, `xmss_ref.py`); XMSS sizes agree with RFC 8391 (2500 and 9251 bytes), hash constructions and identifiers from SP 800-208 | **not independent**: the RFC 8554 and RFC 8391 text is not available; a misreading shared by the model and the RTL would not be seen |
| Key, random | `tests/key_rng/tb_key_rng.sv` | directed checks written from the block description | self-written, directed |
| AXI4 block | `tests/axi/tb_axi.sv` | shadow memory updated only from the AXI4 rules of IHI 0022 | self-written, directed; 2 of 3 mutants caught (the third is an equivalent mutant) |
| Top | `tests/top/tb_top_ec.sv`, `tb_top_pq.sv` | the vectors above through APB4, AXI4, key registers, entropy port, verify-after-sign and clearing | as above |

The programs of the three engines were first run in bit-exact Python models of the processors (`models/*/*_isa.py`) and
compared with the references before the RTL existed; the RTL is the same instruction set (see the module headers).

## Commands

```powershell
python verification/env/ec/run_ec.py [quick|ed25519|ed448|p256|p384|p521|k256]     # EC engine, sets run in parallel
python verification/env/hbs/run_hbs.py [quick|slh|lms|xmss]                         # hash-based engine
python verification/env/lat/run_lat.py [quick|all]                                  # lattice engine
python verification/env/misc/run_unit.py key_rng                                    # key and random blocks
python verification/env/misc/run_unit.py axi                                        # AXI4 block with the buffer
python verification/env/misc/run_unit.py hfeed +VEC=<file from models/hash/gen_hfeed_vec.py>
python verification/env/misc/run_unit.py top_ec +VEC=<hex of models/ec/gen_ec_vec.py quick> +NVEC=10
python verification/env/misc/run_unit.py top_pq +DIR=<dir of gen_lat_vec.py or gen_hbs_vec.py> +KIND=lat|hbs +NVEC=<n>
python verification/models/hbs/test_hbs_slh.py ; python verification/models/lat/test_lat_prog.py   # Python models against OpenSSL
```

The Python models need OpenSSL 3.5 or later (`OPENSSL` environment variable, default `C:/Users/PC/Tools/msys64/usr/bin/openssl.exe`).
Logs and build products are in `sim/` (not versioned).

## Results of the last full run

See the table in section 15.6 of the specification and the logs in `sim/`. Honest limits:

- No code or functional coverage was measured; there is no formal, CDC, RDC, SDC or synthesis run for this phase.
- The tops were simulated with `PARA_CSR_ASYNC` 0 and the default 64-bit buffer word; the other widths are not supported.
- The sets exercised: Ed25519 and Ed448 (all RFC 8032 vectors up to 120 bytes), P-256 (all RFC 6979 vectors), P-384 (two vectors), P-521 (one
  vector), secp256k1 (three random keys), ML-DSA-44 (11 vectors), ML-DSA-65 and 87 (7 each), SLH-DSA all 12 sets, LMS 10 combinations of type,
  one-time type and levels, XMSS and XMSS^MT 8 of the 44 sets (the sets with h = 16 and 20 and with 60/3, 60/6, 40/2, 40/4 are not run: their trees are
  too slow to build in the Python signer, the program is the same).
- Not built, so not tested: Ed25519ctx, Ed25519ph, Ed448ph, prehash forms of ML-DSA, SLH-DSA, LMS, XMSS, deterministic ECDSA nonce (RFC 6979), masking
  (DPA), the internal hash-based random generator.
- Zeroization is checked by hierarchical references to the registers and the word RAM of the engines, not by a property of the ports.
