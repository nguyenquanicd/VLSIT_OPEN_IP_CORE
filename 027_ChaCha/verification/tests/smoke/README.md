# Smoke tests of the first RTL (not a delivered testbench)

These files are the scratch simulations that were run while the RTL of `027_ChaCha` was written. They are not the verification environment of the IP: they have no protocol assertion set (rules R-022 to R-026 of the RTL generator were not applied), no coverage and no waveform evidence. Expected values come from `../../models/chacha20poly1305_ref.py`, which was written from RFC 8439.

| File | What it runs |
|---|---|
| `tb_block.sv` | one ChaCha20 core, RFC 8439 section 2.3.2 block, all four `PARA_QR_NUM` / `PARA_RND_CYC` settings |
| `tb_poly.sv` | the Poly1305 block, the three `PARA_POLY_ARCH` options, RFC vector, random and all-ones blocks |
| `tb_core.sv`, `runcore.sh` | `m_chacha_core` with behavioral buffers, key store and flush model: encryption, decryption, bad tag, widths, configurations, random lengths |
| `tb_top.sv`, `runtop.sh` | `m_chacha_top` through APB and AXI4: polling and DMA flows, four clock combinations |
| `tb_err.sv` | directed error and protocol cases: len_err, nonce guard, key error, abort, AXI refusals, AXI reset, disabled engine |
| `tb_hw.sv` | the hardware-nonce build |
| `tb_perf.sv`, `gen_perf.py`, `runperf.sh`, `cmp_perf.py` | start-to-done cycles of `m_chacha_core` for 17 messages and the three configurations against the formula of HDS section 13.2 (`python gen_perf.py`, `bash runperf.sh BASE 2 > res_BASE_kd2.txt` for LP, BASE and HP, then `python cmp_perf.py 2`); `perf_results.txt` keeps the result of 2026-11-24 |
| `runperf_all.sh`, `cmp_perf_pipe.py` | the same measurement for the 4 combinations of `PARA_PIPE_CHACHA` and `PARA_PIPE_POLY` (environment variables `PC`, `PP`, `PI` of `runperf.sh`) and the comparison with the extended formula; `perf_results_pipe.txt` keeps the result of 2026-11-24 |
| `tb_pair.sv`, `trace_wf018.txt`, `trace_wf019.txt`, `trace_wf020.txt`, `build_wf_pairs.py` | trace of `m_chacha_block_p` and the script that builds the waveforms WF-018 to WF-020 of the HDS from it |
| `empty_cases.sh` | encryption and decryption of the ten messages `r0` to `r9` (lengths 0 to 1280, empty parts included) on three core shapes with `runcore.sh`; prints `EMPTY-CASES pass=N fail=M` |
| `regress_pipe.sh` | top-level regression of the 8 combinations of the three pipeline parameters: polling and DMA flows, decryption, wrong tag, clock relations, widths 32 to 256, CFG-LP, CFG-BASE, CFG-HP shapes, `tb_err`, `tb_hw`; prints `SUMMARY pass=N fail=M` |
| `gen_core.py` | writes the vector files (`*_in.hex`, `*_out.hex`, `key.hex`, `nonce.hex`) with the reference model |

How to run (Icarus Verilog 12 from the OSS CAD Suite; the scripts expect `srctop.txt` and `srclist.txt` with the source list in compile order, for example the lines of `../../../rtl/filelist.f` with absolute paths, and the vector files in the current folder):

```sh
python gen_core.py                      # vectors
iverilog -g2012 -DVLSIT_SYNTHESIS -o tb_err.vvp tb_err.sv $(cat srctop.txt) && vvp tb_err.vvp
```

Without `-DVLSIT_SYNTHESIS` the library synchronizers use their metastability model; the seeds are set with `+AFIFO_MSYNC_SEED=<n>` and `+RSTSYNC_MSYNC_SEED=<n>`.
