# Process review record for t_rev_process (2026-11-21)

Test `t_rev_process` is a review-only obligation (vplan row REQ-RTL-001, REQ-VER-001, REQ-VER-002, REQ-VER-003, REQ-DFT-001).
This record was written by an AI agent (the Claude model of this session). It is an advisory review (R-244, R-238): it lists
what was checked and with which command, what could not be checked, and what is still open. It is not a sign-off; a named
human reviewer has to agree or disagree in `verification_report.md` section 4.5.

## 1. REQ-RTL-001 - RTL rules and lint

| Check | Command (from the IP folder) | Result on the frozen RTL |
|---|---|---|
| Rule check of the 28 RTL files | `python <skill>/vlsit_rtl_check.py check rtl` | 0 errors, 412 warnings, PASS. Warned rules: CMT-01, HIE-02, NAM-08, PAR-03, R-027 (baseline of the RTL report, unchanged in kind) |
| Verilator lint of the four tops | `python <skill>/vlsit_lint_rtl.py lint rtl/filelist.f --top m_usb2_top_<top>` | utmi_axim 0 errors / 336 warnings, utmi_axis 0 / 342, ulpi_axim 0 / 358, ulpi_axis 0 / 364 (logs `rtl/lint_verilator_107.log` to `_110.log`) |

Not checked here: the manual rules of `vlsit_rtl_check.py coverage` were inspected for the RTL changes of this verification
round only (BUG-028 to BUG-032 of `verification/sim/docs/bugs.md`); the earlier modules keep the review of the RTL report.

## 2. REQ-VER-001 - a protocol checker per interface and a USB BFM per role

| Interface | Checker in the harness (always on, R-241) | Activity counter in the run log | State |
|---|---|---|---|
| UTMI+ | `a_utmi_tx` (no transmit while RXActive, data stable while TXReady is low), `a_utmi_w16` (width pin, TXValidH rules), `a_utmi_mode` (mode pins do not change while a packet is on the bus) | `ACTIVITY`, `ACTIVITY2` | present; `a_utmi_mode` found BUG-034 |
| APB4 | `a_apb` (PREADY within 200 cycles only) | `a_apb` | present but thin: PSLVERR and PRDATA rules are checked by the register scenarios, not by an assertion |
| Interrupt | `a_irq_level` (o_int_usb is the registered OR of enabled status bits) | `ACTIVITY2` | present |
| AXI4 master (DMA builds) | `a_axim` (16 checks: INCR only, 16 beats, full width, 4 KB, alignment, WLAST, stability of the address and data) and `a_axim_win` (REQ-IF-014) | `a_axim` | present |
| AXI4 slave (window builds) | `a_axis` (11 checks: response stability, response only after the request, RLAST position, IDs) and `a_dmareq` (a request does not fall without an acknowledge or a burst) | `a_axis`, `a_dmareq_checks` | present (new this round) |
| ULPI | `a_ulpi_bus` in `ulpi_phy_bfm.sv`: six rules (no link drive while DIR is high, STP one cycle, no STP without a transfer, idle bus 00h, no command while the PHY sleeps, STP not held after the wake DIR); the PHY side of low power is modeled only as DIR with an RX CMD after STP | `ULPI_ACTIVITY` | present |
| Formal (CRC, FIFO invariants, over-current, interrupt, reset) | `verification/sim/tb/formal/*` | cover goals | present; bounded depth, see the report |

USB bus functional model per role: the PHY side of the harness (`usb_phy_bfm` part of `tb_usb2_utmi_axim.sv`, with the ULPI
wrapper `ulpi_phy_bfm.sv`) plays the host for a device DUT and the device or hub (`DevPartner` of `verification/tests/hostlib.py`) for a host
DUT. Both roles exist; both run over UTMI+ 8-bit, UTMI+ 16-bit (device) and ULPI.

## 3. REQ-VER-002 - TSCALE

| Item | Finding |
|---|---|
| Default | `PARA_USB2_TSCALE` defaults to 1 in the core and in the four wrappers (`grep` of `rtl/m_usb2_*.sv`). A delivered netlist must keep 1: this is an integration review item (the parameter list of the delivery) and cannot be proven by a simulation |
| Scaled and unscaled measurements | Host timing at TSCALE 16 and at 1 give the same functional results; the SOF interval at 16 shows the jitter of FND-009 (the host divides its transaction estimate), at 1 it stays inside 125 us +- 62.5 ns (runs of `t_dir_timing_ts1`: UTMI+ host `r0334`, ULPI host `r0335`; final regression runs are listed in the report) |
| Each timing requirement once at TSCALE = 1 | Run at 1: device enumeration with chirp, suspend, L1 (LPM), reset and resume paths (`t_dir_timing_ts1`), isochronous throughput (`t_perf_iso_in`), host connect debounce, reset, chirp, SOF accuracy and frame guard with traffic (`t_dir_timing_ts1` host rows). NOT run at 1: host suspend and resume timing, remote-wake timing in the host direction, over-current filter over a real-time bring-up (the filter counts bus cycles and does not scale), and the device resume and L1 timers on the ULPI wrapper |

## 4. REQ-VER-003 - interoperability tests and compliance pre-check list

Interoperability with real host and device stacks (CDC-ACM, mass storage, UVC) needs an FPGA prototype or an emulation platform;
none exists in this environment, so these tests are NOT run (plan section 2.2). The pre-check list that the plan row asks for,
with the simulation evidence available for each item:

| Pre-check item (USB 2.0 and USB-IF practice) | Source | Evidence in this package | Status |
|---|---|---|---|
| Device framework: address, configuration, control transfers, STALL | USB 2.0 chapter 9 | `t_dev_enum_bulk_dma`, `t_fi_bus_errors` | simulated |
| Bulk, interrupt, isochronous transfers with data toggle and short packets | chapter 5, 8 | `t_dev_enum_bulk_dma`, `t_dev_iso_int_mix`, `t_rand_dev_traffic`, `t_rand_host_traffic` | simulated |
| Packet error handling: CRC, PID check, time-out, babble | chapter 8 | `t_fi_bus_errors`, `t_fi_host_bus_errors` | simulated |
| Suspend, resume, remote wake, reset | chapter 7 | `t_dev_suspend_lpm_reset`, `t_dir_reset_midxfer` | simulated (device side) |
| LPM L1 | ECN LPM | `t_dev_suspend_lpm_reset` | simulated |
| Chirp handshake and high-speed fall-back | 7.1.7.5 | `t_dev_enum_bulk_dma`, `t_host_enum_bulk_dma` | simulated |
| Test modes Test_J, Test_K, Test_SE0_NAK, Test_Packet (EHSET) | 7.1.20 | `t_dir_test_mode` | simulated with the packet content, no electrical measurement |
| Split transactions | chapter 8.4.2 | `t_host_split_poll` | simulated against a scripted hub |
| Electrical signal quality, eye diagram, inrush, back-voltage | USB 2.0 chapter 7 | none | PHY and board: outside this IP |
| USB-IF compliance workshop, USBCV chapter 9 and MSC tests | USB-IF | none | needs hardware and a PHY |

## 5. REQ-DFT-001 - scan and test mode

| Item | Finding (by reading the RTL, not by a scan tool) |
|---|---|
| Clock gates | No clock gate exists in the RTL (no instance or gated-clock expression found): the "test-enable on every clock gate" part is vacuously true |
| Test mode overrides the reset only in the reset controller | `i_dft_test_en` is used only in `m_usb2_rst.sv` (lines 108 to 110); it is a pass-through of the raw resets |
| Scannable flip-flops | All flip-flops are plain edge-triggered flops with reset (`rtl_check` rules P1 to P33 clean); `i_dft_scan_en` is an input of the core and the wrappers that no logic uses. Scan insertion and its coverage are a flow task that was not run (no DFT tool in this environment) |

## 6. Open points for the human reviewer

1. The PHY side of the ULPI low-power sequence is only partly modeled (item 2); `a_cdc_struct` and `a_fifo_dbuf` are missing.
2. The TSCALE = 1 gaps of item 3.
3. Interoperability and compliance (item 4) are not executed.
4. `i_dft_scan_en` is unused (item 5): confirm that the scan flow does not need it inside the RTL.
