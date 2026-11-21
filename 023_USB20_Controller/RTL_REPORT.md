# USB 2.0 controller RTL report (2026-11-21)

Source of truth: `VLSIT_USB20_CONTROLLER_HDS.md` (decisions DEC-001 to DEC-024 and the open items TBD-015, TBD-016 of section 20 record what the RTL does).

## Files

| Folder / file | Content |
|---|---|
| `rtl/` | 26 hand or generated modules `m_usb2_*.sv`, the generated CSR in `rtl/csr/`, `filelist.f` (last top that was linted) and `filelist_{utmi,ulpi}_{axim,axis}.f`, lint logs, `rtl_check_report.md` |
| `rtl_gen/` | Generators and helpers: `gen_regs.py` (`m_usb2_regs`), `gen_core.py` with `core_body*.py` (`m_usb2_core` and the four wrappers), `fixports.py`, `rewrap.py`, `run_gen.sh`, `run_core.sh`, one-time patch scripts `patch_*.py` that record each edit |
| `verification/` | Scratch simulations (Verilator, `build.sh`, `run_all.sh`, `tb/`): link loop, FIFO, device (UTMI+ 8-bit, 16-bit with AXI 64-bit, ULPI, AXI slave, pipeline options, high-speed chirp, features, high-bandwidth isochronous, scatter-gather), host (UTMI+ 8-bit, 16-bit with AXI 64-bit, ULPI, features, split, isochronous) |
| `synth/` | Yosys (slang front end) scripts and results of the generic-gate synthesis, `cfg.py`, `area.py` |
| `csr/` | Register source `regs_usb2.json`, `gen_csr.py` and the workbook `VLSIT_USB20_CONTROLLER_CSR.xlsx` |

Tops: `m_usb2_top_utmi_axim`, `m_usb2_top_utmi_axis`, `m_usb2_top_ulpi_axim`, `m_usb2_top_ulpi_axis` (all instantiate `m_usb2_core`).

## Results

| Check | Result |
|---|---|
| Rule check `vlsit_rtl_check.py check rtl/m_usb2_*.sv` | 0 ERROR; warnings CMT-01, HIE-02, NAM-08, PAR-03 (see `rtl/rtl_check_report.md`) |
| Rule check of the generated CSR `rtl/csr/*.sv` | 0 ERROR (the earlier NAM-07 and NAM-TBL findings were removed by renaming fields in the workbook, DEC-021) |
| Verilator lint of the four tops (`vlsit_lint_rtl.py lint filelist_*.f`) | PASS, 0 errors, 263 to 290 warnings (unused bits, empty pins, width truncation of generated indexes, library warnings); extra lint with `PARA_USB2_SG_EN=1` and with 16-bit UTMI+, AXI 64-bit data and 64-bit address: 0 errors |
| Scratch regression `verification/run_all.sh` | 32 runs (26 tests and 6 with all pipeline options on), all 0 errors, log `verification/logs/run_all_final10.log` (final RTL: CSR of generator 3.6, `PARA_USB2_PIPE_AXS`, DEC-033) |
| Turn-around, end of receive to first transmit byte | 8 CLK-PHY without options, 11 with all pipeline options (limit 14) |
| Not run | ASIC STA (the SDC files are untested), synthesis with a technology library, formal, CDC and RDC tools, gate-level or timing simulation, coverage measurement, a UVM or protocol-checker testbench |

### Scratch simulations (Verilator)

| Test | Covers | Result |
|---|---|---|
| `tb_lnk_loop` 8/16-bit | packet layer loop: tokens, data, CRC5, CRC16, handshakes | 215 checks each, 0 errors |
| `tb_fifo` | FIFO manager, one and two RAM ports, 8/16-bit | 39 checks each, 0 errors |
| `tb_dev_utmi` PIPE 0/1 | device UTMI+ 8-bit, AXI master, SETUP, OUT, IN, NAK, all pipeline options | 185 checks each, 0 errors; turn-around 8 and 11 CLK |
| `tb_dev_utmi16` | device UTMI+ 16-bit, AXI 64-bit | 185 checks, 0 errors |
| `tb_dev_ulpi` | device ULPI | 185 checks, 0 errors |
| `tb_dev_axis` | device with AXI slave windows | 110 checks, 0 errors |
| `tb_dev_chirp` | high-speed chirp handshake | 9 checks, 0 errors |
| `tb_dev_feat` | Test_SE0_NAK, Test_J, Test_Packet, LPM response, suspend, resume, remote wake | 71 checks, 0 errors |
| `tb_dev_hbiso` | high-bandwidth isochronous IN (DATA2, DATA1, DATA0) | 136 checks, 0 errors |
| `tb_dev_sg` | scatter-gather descriptors: two OUT and two IN packets, last and ioc bits kept, overflow, pointer advance, re-arm | 228 checks, 0 errors |
| `tb_host_utmi` | host connect, reset, SOF, OUT, IN | 33 checks, 0 errors |
| `tb_host_feat` | host LPM request, suspend, resume | 43 checks, 0 errors |
| `tb_host_split` | host split transactions: start-split and complete-split of an OUT and an IN, NYET retry | 30 checks, 0 errors |
| `tb_host16` | host UTMI+ 16-bit with AXI 64-bit | 43 checks, 0 errors |
| `tb_host_iso` | host isochronous OUT and IN without handshakes, polling interval | 35 checks, 0 errors |
| `tb_host_ulpi` | host over ULPI: SOF, OUT, IN, PHY register write and read, LPM request, suspend, resume, low-power wake | 51 checks, 0 errors |
| `tb_host_flags` | host `babble` (with channel halt), `iso_inc`, `poll_miss`, `frm_ovr`, over-current filter and power-off (ASM-022) | 13 checks, 0 errors |
| `tb_dev_sg64` | scatter-gather with UTMI+ 16-bit and AXI 64-bit | 228 checks, 0 errors |
| `tb_dev_nyet` | high-speed bulk OUT: NYET with a full FIFO, PING answered NAK then ACK, data after the drain | 141 checks, 0 errors |
| `tb_host_sg` | scatter-gather on host channels (OUT list of two descriptors, IN descriptor with a larger buffer) | 34 checks, 0 errors |
| `tb_dev_ulpi_lp` | device over ULPI: suspend, SuspendM = 0, PHY clock stopped, remote wake request with stp held, wake handshake, `rmt_wake` cleared | 7 checks, 0 errors |

## Bugs found by the new simulations in this round

| Finding | Where | Decision |
|---|---|---|
| A repeated command (re-arm of an endpoint with `ep_en`) was not seen: the CLK-PHY shadow word kept the consumed command bits | `m_usb2_xreg` | DEC-014 |
| Host could not send the complete-split of an OUT (no queue data), counted the ACK of a start-split IN as an error | `m_usb2_host` | DEC-015 |
| Host LPM request was lost when the handler was busy at the moment the bit rose | `m_usb2_host` | DEC-016 |
| ULPI wake request came from CLK-PHY, which is stopped in low power, and crossed without a synchronizer | `m_usb2_ulpilp`, `m_usb2_core` | DEC-022 |
| PHY register access: `rd_wr` was inverted, so a CSR write ran a read on the ULPI bus | `m_usb2_core` | DEC-023 |
| ULPI register read data was decoded as an RX CMD and changed the line state | `m_usb2_phyif_ulpi` | DEC-024 |
| NYET decision subtracted the packet rows twice (17-bit wrap-around, ACK with a full FIFO) | `m_usb2_dev` | DEC-026 |
| Three old testbenches (`tb_dev_utmi`, `tb_dev_utmi16`, `tb_dev_ulpi`) no longer compiled after a signal rename and had not been rebuilt | testbenches | fixed |

## Resource estimate (Yosys, generic gates, RAM macro excluded)

Yosys 0.69 with the slang front end, `synth -flatten`, generic gates, the SRAM macro as a black box (`synth/cfg.py`, results in `synth/area_configs.txt`, previous run in `synth/area_configs_prev.txt`). `ltp_len` is the longest topological path in generic gates, not a timing result.

| Configuration | Top | Cells | Flops | ltp_len | Cells before the resource pass |
|---|---|---|---|---|---|
| CFG-MIN (device, 2 endpoints, UTMI+ 8-bit, AXI slave) | `m_usb2_top_utmi_axis` | 30456 | 5602 | 46 | 33123 (-8.1 %) |
| CFG-FC-DEV (device, 6 endpoints, ULPI, AXI slave) | `m_usb2_top_ulpi_axis` | 49066 | 8381 | 52 | 52357 (-6.3 %) |
| CFG-CAM-HOST (host, 8 channels, UTMI+ 16-bit, AXI 64-bit, split) | `m_usb2_top_utmi_axim` | 50482 | 8138 | 60 | 52607 (-4.0 %) |
| CFG-CAM-HOST-SG (same with `PARA_USB2_SG_EN` = 1) | `m_usb2_top_utmi_axim` | 50843 | 8152 | 61 | 52802 (-3.7 %) |
| CFG-DUAL-FULL (dual role, 8 endpoints, 8 channels, LPM, split) | `m_usb2_top_utmi_axim` | 86728 | 13006 | 66 | 91828 (-5.6 %) |

Resource pass (DEC-027): the pointers and row counters of `m_usb2_fifo` and the credit counters of `m_usb2_dma` had the width of the CSR fields (16 and 17 bits) although the RAM needs `clog2(rows)` bits; they now follow the RAM depth. At the default depth `m_usb2_fifo` alone went from 13156 to 10001 cells and from 1307 to 989 flops, and the longest generic path of CFG-MIN from 59 to 46 gates (narrower carry chains). The regression passes unchanged. The comparison column is the run before this pass (`synth/area_configs_r3.txt`). The scatter-gather engine costs 361 cells and 14 flops (0.7 %) in the host configuration. No technology library, no STA and no power estimate exist, so the numbers show relative size only.

## Standard-cell timing and area (FreePDK45, DEC-034)

`synth/asic_sta.py` maps each design on the OSU FreePDK45 cells (`synth/pdk_freepdk45/gscl45nm.lib`, typical corner, from the PDK archive supplied by the user) and reports the longest combinational delay with the ABC `stime` command after buffering and gate sizing. TOP-MIN is the device-only AXI slave configuration, TOP-HOST the host AXI master configuration, TOP-DUAL the dual-role configuration; PIPE means all pipeline options on.

| Run | Top or module | Period ps | Longest delay ps | Slack ps | Area um2 |
|---|---|---|---|---|---|
| TOP-MIN-OPT0 | `m_usb2_top_utmi_axis` | 6667 | 1560 | 5107 | 119263 |
| TOP-MIN-PIPE | `m_usb2_top_utmi_axis` | 6667 | 1528 | 5139 | 125724 |
| TOP-HOST-OPT0 | `m_usb2_top_utmi_axim` | 6667 | 1513 | 5154 | 186933 |
| TOP-DUAL-OPT0 | `m_usb2_top_utmi_axim` | 6667 | 1490 | 5177 | 315036 |
| TOP-DUAL-PIPE | `m_usb2_top_utmi_axim` | 6667 | 1632 | 5035 | 339760 |
| MOD-dev | `m_usb2_dev` | 8333 | 1010 | 7323 | 27348 |
| MOD-host | `m_usb2_host` | 8333 | 1549 | 6784 | 25614 |
| MOD-fifo | `m_usb2_fifo` | 8333 | 1328 | 7005 | 35158 |
| MOD-lnk | `m_usb2_lnk` | 8333 | 1146 | 7187 | 5848 |
| MOD-spd | `m_usb2_spd` | 8333 | 1518 | 6815 | 4608 |
| MOD-axs | `m_usb2_axs` | 6667 | 999 | 5668 | 10369 |
| MOD-dma | `m_usb2_dma` | 6667 | 1287 | 5380 | 28740 |
| MOD-csr | `m_vlsit_csr_usb2` | 6667 | 815 | 5852 | 83098 |

Reading: the longest combinational delay is 1.49 to 1.63 ns for every top. Adding the flip-flop clock-to-output delay (0.4 to 1.7 ns in this library, depending on load) and setup time (up to 0.6 ns) gives less than 4 ns, below the 6.67 ns period of CLK-BUS at 150 MHz and the 8.33 ns period of CLK-PHY at 120 MHz, with the pipeline options off. The pipeline options do not shorten the longest path of the whole chip in this library (1.56 to 1.53 ns for TOP-MIN, 1.49 to 1.63 ns for TOP-DUAL, within mapping noise); they cost 5 to 8 percent area and stay available for wire-dominated or FPGA targets.

Limits of this measurement: no wire load, no clock tree, typical corner only, FIFO RAM macro excluded, IO budgets of `sdc/usb2_io.sdc` not applied, a 31-cell library with one resettable flip-flop. It is a pre-layout estimate, not a sign-off STA.

Status (DEC-035, accepted by the user on 2026-11-21): the 120 MHz CLK-PHY and 150 MHz CLK-BUS targets are met in this pre-layout estimate and are not signed off; the timing optimization round is closed.

## FPGA place-and-route timing (nextpnr-ecp5)

Yosys `synth_ecp5` and nextpnr-ecp5 (LFE5UM5G-85F, speed grade 8, seed 1, target 60 MHz on both clocks, `synth/fpga.py`, results in `synth/fpga_results.txt` and the `fpga_*_pnr.log` files). This is a placed-and-routed result on one real FPGA family: it is not an ASIC number, but it shows which clock limits the design and what the timing options do. Configuration of all three rows: device, 2 endpoints, UTMI+ 8-bit, AXI slave, FIFO depth 256.

| Configuration | LUT4 | FF | Fmax CLK-PHY (target 60 MHz) | Fmax CLK-BUS |
|---|---|---|---|---|
| first measurement, all options 0 | 11623 | 4863 | 95.5 MHz | 99.7 MHz |
| first measurement, `PIPE_PHY_IN`, `PIPE_RX`, `PIPE_CRC`, `PIPE_XREG` = 1 | 11693 | 5421 | 98.3 MHz | 122.2 MHz |
| first measurement, the four options and `RAM_1P` = 1 | 11631 | 5345 | 93.4 MHz | 111.2 MHz |
| **after the optimization of `m_usb2_xreg` (DEC-025), all options 0** | **11590** | **4863** | **99.6 MHz** | **118.4 MHz** |
| after DEC-025, the four options and `PIPE_MODE` = 1 | 11607 | 5428 | 94.2 MHz | 109.1 MHz |

Optimization iteration: the report of the first measurement showed that the critical path of CLK-PHY ended in the update FIFO of `m_usb2_xreg` and passed through the push decision, which depended on the 32-bit comparison of a published word with the pushed one. The scanner now decides from the registered dirty flag that was already there (DEC-025). With all options off this gave 33 fewer LUT4 and no extra flop, CLK-BUS from 99.7 to 118.4 MHz (+19 %) and CLK-PHY from 95.5 to 99.6 MHz (+4 %). The new critical path of CLK-PHY (about 100 MHz) starts at the receive-valid flop and runs through a carry chain; the synthesized names do not say which counter it is, so it was not attributed. The option `PARA_USB2_PIPE_MODE` was added for the mode outputs of the speed engine, which appeared in the names of the first critical path; its measured effect is inside the placer spread.

Target-driven runs (DEC-029, `synth/fpga_target.py`, LPF targets CLK-PHY 120 MHz and CLK-BUS 150 MHz, same device, three seeds per row, results in `synth/fpga_target_results.txt` and `fpgat_*.log`). Fmax in MHz as reported after routing:

| Configuration (UTMI+ 8-bit device) | LUT4 / FF | CLK-PHY seeds 1, 2, 3 (mean) | CLK-BUS seeds 1, 2, 3 (mean) |
|---|---|---|---|
| all options 0, before `PIPE_XREG` stages the update FIFO | 10766 / 4623 | 100.7, 104.8, 100.8 (102.1) | 106.6, 111.0, 97.6 (105.1) |
| the four options and `PIPE_MODE` = 1, before that change | 10848 / 5188 | 99.4, 99.5, 100.5 (99.8) | 112.3, 112.2, 118.5 (114.3) |
| all options 0, after | 10828 / 4623 | 104.1, 103.6, 100.4 (102.7) | 102.7, 122.3, 95.2 (106.7) |
| the four options and `PIPE_MODE` = 1, after | 10808 / 5228 | 108.7, 103.6, 104.4 (105.6) | 97.8, 109.1, 92.8 (99.9) |

Result: no configuration reaches 120 MHz / 150 MHz; all close at about 100 MHz on both clocks, 1.7 times the 60 MHz of the PHY. The means of the rows differ by less than the spread between seeds of one row (up to 27 MHz on CLK-BUS), so no option set is shown to be better; the critical paths of the last runs are routing-dominated (about 78 % of the path on CLK-PHY and over 90 % on CLK-BUS is routing, 2.0 ns logic against 7.2 ns routing on CLK-PHY), which points to placement and reset fanout on this FPGA more than to logic depth. The options are therefore kept as a way to trade flops for logic depth where a technology needs it, not as a measured gain on this FPGA. Finding while testing them: the pipeline options must not change function, so the device tests that have a `PIPE` parameter (`tb_dev_utmi`, `tb_dev_feat`, `tb_dev_hbiso`, `tb_dev_chirp`, `tb_dev_sg`, `tb_dev_nyet`) now run with `PIPE` = 0 and 1; running the high-bandwidth test with the options exposed a bug of the testbench AXI read model (it dropped the last beat when `rready` was low), fixed in all 18 testbenches that use it.

Reading: both clocks meet the 60 MHz of a UTMI+ 8-bit PHY with about 65 % margin without any option (a 16-bit PHY needs only 30 MHz). The pipeline options cost 70 LUT4 and 540 to 560 flops and the placer results with them (93 to 98 MHz on CLK-PHY, 109 to 122 MHz on CLK-BUS) are not better than the optimized baseline beyond the run-to-run spread, which was not measured (one seed per row, the rows differ by up to 5 % without any change of the clock path), so on this FPGA at 60 MHz no option is needed; they stay in the design for the cases where a technology is slower. Latency is measured in simulation, not here (DEC-028): the first transmitted byte follows the fall of `rxactive` after 4 CLK-PHY cycles (one to the end-of-packet event, one to the transmit request, two to `txvalid`), i.e. 32 high-speed bit times against the REF-001 window of 8 to 192; the testbench figure of 8 cycles (11 with all pipeline options, limit 14) includes its own receive-end delay. No cycle was removed because the margin to the minimum is what keeps the answer legal.

### Round 2: logic depth reduction (DEC-031) and CSR of generator 3.6 (DEC-030)

Longest topological path per module (generic gates): device 58 to 48, host 65 to 49, FIFO manager 52 to 39.

| Configuration | Cells before | Cells after | Flops after | Longest path before | after |
|---|---|---|---|---|---|
| CFG-MIN | 30456 | 30514 | 5587 | 46 | 45 |
| CFG-FC-DEV | 49066 | 49926 | 8366 | 52 | 45 |
| CFG-CAM-HOST | 50482 | 50473 | 8156 | 60 | 46 |
| CFG-CAM-HOST-SG | 50843 | 50771 | 8170 | 61 | 46 |
| CFG-DUAL-FULL | 86728 | 87651 | 13010 | 66 | 50 |

Target-driven FPGA runs after the change (`synth/fpga_target.py`, device-only configuration, LFE5UM5G-85F speed 8, targets CLK-PHY 120 MHz and CLK-BUS 150 MHz):

| Configuration | Seed | LUT4 | FF | CLK-PHY MHz | CLK-BUS MHz |
|---|---|---|---|---|---|
| OPT0 | 1 | 10909 | 4608 | 103.3 | 97.9 |
| OPT0 | 2 | 10909 | 4608 | 120.4 | 94.9 |
| OPT0 | 3 | 10909 | 4608 | 113.0 | 120.1 |
| PIPE-ALL | 1 | 11220 | 5213 | 124.0 | 117.4 |
| PIPE-ALL | 2 | 11220 | 5213 | 120.6 | 125.0 |
| PIPE-ALL | 3 | 11220 | 5213 | 127.5 | 128.4 |

Reading: with all pipeline options on, CLK-PHY meets the 120 MHz target on all three seeds (before: 103.6 to 108.7 MHz) and CLK-BUS reaches 117 to 128 MHz (before: 93 to 109 MHz); the 150 MHz CLK-BUS target is not reached. With the options off the result still depends on the seed (CLK-PHY 103 to 120 MHz). The pipeline options now show a measured benefit on both clocks. These are FPGA numbers; no ASIC STA was run because no technology library or STA tool is available.

### Round 3: `PARA_USB2_PIPE_AXS` (DEC-032) and timing-weighted placement

`PIPE-ALL` now includes `PARA_USB2_PIPE_AXS`; `synth/fpga_target.py` runs the placer with `--placer-heap-critexp 4 --placer-heap-timingweight 20` (best of eight placer settings tried on seed 1).

| Configuration | Seed | LUT4 | FF | CLK-PHY MHz | CLK-BUS MHz |
|---|---|---|---|---|---|
| OPT0 | 1 | 10963 | 4608 | 114.6 | 129.6 |
| OPT0 | 2 | 10963 | 4608 | 110.1 | 105.7 |
| OPT0 | 3 | 10963 | 4608 | 111.5 | 120.0 |
| PIPE-ALL | 1 | 11365 | 5252 | 124.5 | 136.4 |
| PIPE-ALL | 2 | 11365 | 5252 | 120.7 | 128.5 |
| PIPE-ALL | 3 | 11365 | 5252 | 128.5 | 128.3 |

Reading: CLK-PHY meets 120 MHz on all seeds with the options on (twice the 60 MHz the PHY needs). CLK-BUS reaches 128 to 136 MHz and does not meet the 150 MHz target. The CLK-BUS critical path has 7 to 8 LUT levels (1.3 to 2.0 ns of logic) and 6.4 to 7.9 ns of routing between cells placed far apart, also in a run without IO pads (`--out-of-context`, 109 MHz with the default placer); the limit is placement and routing of this FPGA flow, not logic depth. `PARA_USB2_PIPE_AXS` alone gave no measurable CLK-BUS gain. No ASIC STA was run (no technology library, no STA tool).

### Round 4: narrower counters in `m_usb2_axs` (DEC-033)

Device-only FPGA configuration: LUT4 10963 to 10809 and FF 4608 to 4535 with the options off; LUT4 11365 to 10680 and FF 5252 to 5179 with all pipeline options on. Fmax after the change, same placer settings:

| Configuration | Seed | CLK-PHY MHz | CLK-BUS MHz |
|---|---|---|---|
| OPT0 | 1 | 114.7 | 128.5 |
| OPT0 | 2 | 112.5 | 118.2 |
| OPT0 | 3 | 119.4 | 102.3 |
| PIPE-ALL | 1 | 120.3 | 125.2 |
| PIPE-ALL | 2 | 112.7 | 105.1 |
| PIPE-ALL | 3 | 112.4 | 129.8 |

Reading: the seed-to-seed spread (about 25 MHz on CLK-BUS, also seen in an eleven-seed sweep of the previous netlist: CLK-PHY 104 to 129 MHz, CLK-BUS 109 to 136 MHz) is larger than the effect of any RTL change of rounds 3 and 4. With this flow the Fmax of this design is limited by placement and routing (critical paths of 7 to 8 LUT levels with 75 to 85 percent routing delay); it cannot show whether the 150 MHz CLK-BUS target is reachable. That needs a technology library and an STA tool, or a vendor FPGA flow.

## Pipeline and resource options (all default 0)

`PARA_USB2_PIPE_PHY_IN` (UTMI+ receive pins), `PARA_USB2_PIPE_RX` (link input), `PARA_USB2_PIPE_CRC` (before CRC16 and field processing), `PARA_USB2_PIPE_XREG` (shadow words), `PARA_USB2_RAM_1P` (single-port serialization of the RAM accesses), `PARA_USB2_RAM_PAR_EN` (parity), and build options that remove logic: `PARA_USB2_ROLE`, `PARA_USB2_NUM_EP`, `PARA_USB2_NUM_HC`, `PARA_USB2_FIFO_DEPTH`, `PARA_USB2_LPM_EN`, `PARA_USB2_SPLIT_EN`, `PARA_USB2_DBUF_EN`, `PARA_USB2_SG_EN`.

## Implemented, simplified, not implemented

Implemented and simulated: packet layer for 8-bit and 16-bit UTMI+ and ULPI (CRC5, CRC16, PID check, EXT/LPM extended token decode), device engine (SETUP, OUT, IN, PING, NAK, NYET, STALL, toggle, high-bandwidth isochronous IN, LPM response, Test_SE0_NAK), host engine (SOF, scheduler, OUT, IN, split transactions, isochronous, LPM request, suspend, resume), speed engine (device and host chirp, suspend, resume, remote wake, test modes), FIFO manager with credit-based bus port, AXI master DMA (INCR bursts, 4 KB rule, scatter-gather descriptors), AXI slave windows, ULPI adapter (TX CMD, RX CMD, register access, low-power wake), CSR integration with the shadow-word crossing.

Every feature of the specification is implemented and has a directed simulation; the limits that remain are recorded in TBD-016 (fixed AXI width, `last` and `ioc` not interpreted, no ASIC library, ASIC STA, CDC or formal tool).

Simplified (DEC-007 to DEC-013): double buffering is the ring only; one AXI beat is one RAM row so `AXI_DATA_W` = 4 x UTMI+ width; DMA buffer addresses must be row aligned; scatter-gather uses one descriptor per packet and does not interpret `last` and `ioc`.

Assumptions to confirm: host reset SE0 drive with OpMode 3 (TBD-015), ULPI behavior against a real PHY (the PHY model of the scratch tests was written from the REF-007 text), UTMI+ and ULPI texts of the converted standards are unofficial copies.

## Commands

```sh
sh rtl_gen/run_gen.sh          # regenerate m_usb2_regs from csr/regs_usb2.json and rtl/csr
sh rtl_gen/run_core.sh         # regenerate m_usb2_core and the four wrappers
sh verification/run_all.sh     # scratch regression (needs the Verilator recipe of the OSS CAD Suite note)
python synth/cfg.py            # generic-gate synthesis of five configurations (run in rtl/, PATH with yosys)
```
