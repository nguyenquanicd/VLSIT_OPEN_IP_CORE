# Reproductions for the review of 2026-11-22

Two small testbenches that run the real RTL modules (unchanged) to confirm a review finding. Run `sh run_repro.sh` from Git Bash; the result of 2026-11-22 is in `repro_result.log`. Build folders go to the temporary folder (`build_run.sh`, Verilator 5.053 with the MSYS2 ucrt64 compiler, the same recipe as `verification/build.sh`). Icarus Verilog 14 cannot compile `m_usb2_axs.sv` (packed-array index inside `always_comb`), so Verilator is used.

| Testbench | DUT | What it checks | Result |
|---|---|---|---|
| `tb_repro_f021.sv` | `rtl/m_usb2_axs.sv` | One AXI write to the window of channel 0 and of the last legal channel; a channel `c < PARA_USB2_NUM_DMA_CH` with an enabled write map must be accepted, channel `NUM_DMA_CH` must be refused | 4 and 15 channels: PASS. **16 channels: channel 0 and channel 15 are refused with SLVERR** (F-021 confirmed) |
| `tb_repro_nep1.sv` | `rtl/m_usb2_regs.sv` (with the CSR, the register crossing and the FIFO library) | An APB write to `EPI_IEN[0]`, `EPI_IEN[NEP1-1]`, `HC_IEN[0]`, `HC_IEN[NHC-1]`; the write decode must forward it to CLK-PHY (`w_dec_vld` = 1) | NEP1 = 9 / NHC = 8 and NEP1 = 15: PASS. **NEP1 = 16 (NUM_EP = 15) or NHC = 16: every write of those banks is not forwarded** |

Cause in both cases: the 4-bit index is compared with `PARA[3:0]`; for a parameter value of 16 the slice is 0 and no index is smaller. The HDS allows NUM_DMA_CH 1 to 16, NUM_EP 1 to 15 (NEP1 up to 16) and NUM_HC 1 to 16, and `m_usb2_cfgchk` does not reject these values.

Limits: the observation of the NEP1/NHC case is the internal decode result (`dut.w_dec_vld`) at the cycle of the accepted write, not the effect on the engines in CLK-PHY; the F-021 case observes the error flag of the burst, which drives SLVERR, and does not wait for the response of an accepted write (no credit is supplied). Only the banks `EPI_IEN` and `HC_IEN` were exercised; the other banks in `m_usb2_regs.sv:1286-1350` use the same comparison.
