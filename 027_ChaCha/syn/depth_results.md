# Structural logic depth of the RTL (2026-11-24)

Not a synthesis and not a timing report: unit-delay levels of 2-input gates from `syn/depth.sh`
(yosys with the slang front end, Kogge-Stone adders, no timing-driven restructuring). Absolute
numbers depend on the adder structure and the gate delays of a real library; use them to rank the
paths, not to predict a frequency (TBD-002).

| Module | Parameters | Longest path (levels) | Path |
|---|---|---:|---|
| m_chacha_qr | one quarter round | 48 | 4 additions and 4 XOR in series |
| m_chacha_cipher | QR_NUM 4, RND_CYC 1 | 54 | round state register -> quarter round -> state update mux |
| m_chacha_cipher | QR_NUM 1 or 2, RND_CYC 1 | 54 | same |
| m_chacha_cipher | QR_NUM 4, RND_CYC 2 (1 or 2 cores) | 100 | two rounds in series |
| m_chacha_pfold | fold twice | 32 | |
| m_chacha_poly | POLY_ARCH 0 | 52 | 32 x 32 multiply-accumulate |
| m_chacha_poly | POLY_ARCH 1 | 62 | product registers -> assembly -> two folds (state RED) |
| m_chacha_poly | POLY_ARCH 2 | 90 | block + accumulator -> 131 x 128 multiplier -> two folds |
| m_chacha_axi_win | | 38 | |
| m_chacha_ingest | DW 64 | 40 | |
| m_chacha_ctrl | | 29 | after DEC-037 (was 25) |
| m_chacha_egress | DW 64 | 18 | |
| m_chacha_dma_ch | | 17 | |
| m_chacha_flush | | 10 | |
| m_chacha_key | | 6 | |
| m_chacha_core | CFG-LP | 54 | cipher |
| m_chacha_core | CFG-BASE | 62 | Poly1305 architecture 1 |
| m_chacha_core | CFG-HP | 100 | cipher, two rounds |

With the pipeline options of DEC-036 (all 0 by default):

| Module | Parameters | Longest path (levels) | Flip-flops added |
|---|---|---:|---:|
| m_chacha_cipher | QR_NUM 1, 2 or 4, RND_CYC 1, PIPE_CHACHA 1 | 30 | 1059 per core |
| m_chacha_cipher | QR_NUM 4, RND_CYC 2, PIPE_CHACHA 1 | 52 | 1059 per core |
| m_chacha_poly | POLY_ARCH 0, PIPE_POLY 1 | 45 | 66 |
| m_chacha_poly | POLY_ARCH 1, PIPE_POLY 1 | 46 | 385 |
| m_chacha_poly | POLY_ARCH 2, PIPE_POLY 1 | 52 | 631 |
| m_chacha_ingest | DW 64, PIPE_IO 1 | 24 | 1 |
| m_chacha_axi_win | PIPE_IO 1 | 25 | 1 |

Modules that instantiate library cells (dma_req, int, msg_cap, flush_hs, rst_ctrl) were not run.
Compared with the author's estimates of HDS section 13.3 (about 32, 64 and 45 to 60): the
quarter round is 48 not 32, two rounds are 100 not 64, and architecture 2 is 90 not 45 to 60.
