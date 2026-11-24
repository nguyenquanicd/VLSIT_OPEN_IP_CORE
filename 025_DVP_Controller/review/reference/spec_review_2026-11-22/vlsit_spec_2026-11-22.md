# Specification review of DVP_Controller - 2026-11-22

## 1. Summary

| Item | Value |
|---|---|
| Design | `DVP_Controller` |
| Review | Specification review |
| Date | 2026-11-22 |
| Findings | 31 |
| Critical | 0 |
| High | 19 |
| Medium | 11 |
| Low | 1 |
| Waivable | 1 |
| Fixable | 30 |

Verdict: **Conditional** (weighted score 2.76 of 5, no Blocker). The bilingual report is `REVIEW_DVP_Controller.md`; the severities Critical, High, Medium and Low here correspond to Blocker, Major, Minor and Observation there.

Gate: `RESULT: PASS, 31 finding(s), written C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\025_DVP_Controller\review\reference\gate_metrics.json`. Group: `RESULT: 31 finding(s) in 17 group(s), written C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\025_DVP_Controller\review\reference\root_cause_groups.json`. Waiver usage 1 of 10. Audit sample 4 of 31: false positive 0, false negative 0 (section 21.5 of the report). Deep analysis: 31 of 31 traced, none aggregated.

## 2. Findings

Each finding has an assessment, a verdict and, when it can be fixed, the RTL change and the reason it works.

### F-001 No workload is fixed, and the one-sample-per-APB-read contract cannot be shown to serve a camera

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:74`
- Severity: `High`
- Label: INFERENCE; locator: §1.4 (line 74), §9 (line 497), §13 PERF-002 (line 1962), REQ-IF-001 (line 122)
- Assessment: The application is named (smart camera) but the budget that would prove the IP fits it is absent, and the spec contract makes the APB the bottleneck for ordinary sensors. The finding is an inference from the spec numbers plus the supplied sensor timing; the 4-cycle DMA beat is an assumption.
- Verdict: `fix`
- Fix: Add a reference workload table to §13 (resolution, fps, PCLK, YUV or RAW, f_APB, DMA beat cost, maximum stall) and derive PARA_FIFO_DEPTH and the minimum f_APB from it; decide F-013 (packing) against that table.
- Why: A stated budget turns f_APB/2 and the FIFO depth from open formulas into pass/fail checks, and shows early whether packing is needed.

### F-002 No frame-done event, line or frame counter, flush, or snapshot mode

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:426`
- Severity: `High`
- Label: INFERENCE; locator: §6.3 DMA re-arm row (line 426), §10.1 (line 560), CSR dvp_fifo_sts (workbook)
- Assessment: Frame boundaries are the unit every camera driver works in. Without a hardware frame-done and a line count, the driver has to count pixels itself, and one dropped pixel (F-008) shifts every later pixel with no way to detect it.
- Verdict: `fix`
- Fix: Add a HREF falling-edge line counter and an active-VSYNC frame counter to the capture side, a sticky dvp_fifo_sts.frame_done (W1C), and a dvp_ctrl.snapshot bit that clears capture_en at the end of one frame. Define frame end as the next active VSYNC edge or the programmed line count, and record it in §10.
- Why: The two counters cost about 30 flops and give the driver a frame boundary, a line count to check against the sensor mode, and a stop point, which is what the DMA tail flush (F-005) and the interrupt (F-006) need.

### F-003 Sensor modes in the research corpus are outside the supported profile

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2180`
- Severity: `Medium`
- Label: INFERENCE; locator: §1.1 Excluded (line 54), ASM-001 (line 2180), research D03, D04, D07
- Assessment: The exclusions are decisions and are recorded, so this is not a defect, but the compatibility claim should be stated as a supported-sensor list, not as a goal.
- Verdict: `fix`
- Fix: Replace ASM-001 by a table of supported sensor modes (device, register-selected mode, PCLK behaviour, VSYNC and HREF semantics) taken from the ten datasheets already in research/, and mark every other mode unsupported.
- Why: A supported-mode table is testable and tells an integrator at once whether their sensor can work.

### F-004 The DMA re-arm rule can leave the request low while the FIFO is above the watermark

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:125`
- Severity: `High`
- Label: INFERENCE; locator: REQ-IF-004 (line 125), §10.1 FSM (lines 552-560), figure 10-1
- Assessment: The DMA engine does not know the occupancy; it moves a programmed burst. A request protocol that depends on the occupancy falling below the threshold is therefore fragile at high arrival rates. This is the scenario TEST-005 does not cover (F-026).
- Verdict: `fix`
- Fix: Make the service burst count-based: ACK loads a pop counter with the watermark, the FSM returns to WAIT_WATERMARK when that many reads completed, and a still-high occupancy then re-requests at once. State the DMA contract in §6.3: burst length equals dvp_wmark.level, fixed address, 32-bit reads.
- Why: The request no longer depends on a level the DMA cannot see, and every burst is followed by a fresh decision, so a drain slower than the arrival rate shows as overflow instead of as a silent stall.

```systemverilog
// m_dvp_dma_req: end one service burst after `level` pops instead of waiting for occupancy < watermark
case (reg_fsm_dma)
  ENUM_ST_WAIT_WATERMARK: if (w_wm_enable && (i_occupancy >= i_wmark_level))
                            reg_fsm_dma <= ENUM_ST_REQ_PENDING;
  ENUM_ST_REQ_PENDING:    if (i_dma_ack) begin
                            reg_burst_left <= i_wmark_level;
                            reg_fsm_dma    <= ENUM_ST_SERVICE_ACTIVE;
                          end
  ENUM_ST_SERVICE_ACTIVE: if (i_fifo_pop) begin
                            reg_burst_left <= reg_burst_left - 1'b1;
                            if (reg_burst_left == 1'b1) reg_fsm_dma <= ENUM_ST_WAIT_WATERMARK;
                          end
  default:                reg_fsm_dma <= ENUM_ST_WAIT_WATERMARK;
endcase
// occupancy >= level at the end of the burst re-requests at once; a short tail is flushed by F-002.
```

### F-005 Samples left after the last full batch never request service

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:426`
- Severity: `High`
- Label: FACT; locator: §6.3 DMA re-arm row (line 426), §10.1 (line 560)
- Assessment: A frame is split across two buffers, the driver cannot tell which pixel starts a frame, and the stale tail adds one frame of latency. The firmware can poll dvp_fifo_level, but nothing tells it that the frame is over (F-002).
- Verdict: `fix`
- Fix: Add a tail flush: when frame_done (F-002) is set and occupancy is nonzero but below the watermark, raise o_dma_req once for the remaining count and expose the count in dvp_fifo_level.count; or make dvp_wmark.level equal to the frame size when a frame fits the FIFO.
- Why: The last pixels of every frame reach memory in the same frame period, which keeps frame and buffer boundaries aligned.

### F-006 There is no interrupt output; DMA REQ is the only notification

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:432`
- Severity: `High`
- Label: FACT; locator: §6.4 (line 432), §1.1 (line 50)
- Assessment: An SoC interrupt controller cannot be used, so a flight-controller-class CPU has to poll at the frame rate and cannot react to an overflow within a line time.
- Verdict: `fix`
- Fix: Add one level output o_dvp_irq driven by a new dvp_irq_sts (W1C) and dvp_irq_en with the bits frame_done, vsync_seen, ovf, rd_timeout and gated_ovr, using the interrupt register pattern of rule R-040.
- Why: The CPU gets the frame boundary and the fault events without polling and without touching FIFO_DATA.

```systemverilog
// one level interrupt; event bits are sticky W1C in a new dvp_irq_sts, masked by dvp_irq_en (same pattern as dvp_fifo_sts.ovf)
assign o_dvp_irq = |(r_irq_sts & r_irq_en);   // bits: frame_done, vsync_seen, ovf, rd_timeout, gated_ovr
```

### F-007 A read of an empty FIFO_DATA can hold the shared APB for up to 2^32 cycles

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:126`
- Severity: `High`
- Label: INFERENCE; locator: REQ-IF-002 (line 123), REQ-IF-005 (line 126), CSR dvp_timeout.cycles [31:0], §11.4 (line 1937)
- Assessment: The shared single-outstanding APB turns the wait-on-empty feature into a possible system stall. PRDATA on the error cycle is also not stated, and IHI 0024 Issue D 3.4 allows a read with an error to return invalid data.
- Verdict: `fix`
- Fix: Narrow dvp_timeout.cycles to 16 bits, keep the reset value 0 (immediate error), state that PRDATA is 0 on a timeout error, add a sticky dvp_fifo_sts.rd_to (W1C), and add an integration rule that the APB bridge has its own timeout shorter than the SoC watchdog.
- Why: The worst blocked time becomes bounded and visible, and the driver can tell a timeout from a data error.

### F-008 The DMA handshake is a local scheme with no burst size or request-type stated

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:387`
- Severity: `Medium`
- Label: INFERENCE; locator: IF-003 (line 387), DEC-008 (line 2189), §6.2 (lines 411-412)
- Assessment: An integrator needs an adapter for most DMA engines and cannot size it from the HDS. This is documentation of an interface, not a functional gap.
- Verdict: `fix`
- Fix: Add a DMA contract table to §6.3: burst length equals dvp_wmark.level, source address FIFO_DATA fixed, 32-bit non-incrementing reads, ACK ignored while REQ is low, and one example hookup for a level-REQ and pulse-ACK DMA.
- Why: The contract is what the DMA channel descriptor is programmed from, so the integrator no longer guesses.

### F-009 The gated-mode launch registers are clocked by PCLK but reset from the CLK-APB reset

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2210`
- Severity: `High`
- Label: FACT; locator: §2.2 item 4 (line 99), §7.3 (lines 459-464), CDC-005 (line 452), DEC-029 (line 2210), REQ-RESET-001 (line 136)
- Assessment: A reset released synchronously in CLK-APB reaches flops of CLK-DVP at an unrelated phase, so recovery and removal cannot be met by construction (reset-domain crossing) and the spec contradicts its own rule. The stated reason, a stopped PCLK, is real but needs no reset on these registers.
- Verdict: `fix`
- Fix: Remove the reset from the PCLK-domain data and toggle registers and let CLK-APB take the baseline from the synchronized toggle while capture is disabled, then delete the reset-removal obligation from DEC-029 and §7.3.
- Why: No reset signal crosses into CLK-DVP any more, the first pixel is still kept because the baseline is set before capture starts, and the design returns to the REF-003 reset rule.

```systemverilog
// PCLK domain: launch registers without reset (no reset-removal path from CLK-APB into CLK-DVP)
always_ff @(posedge i_clk_dvp) begin : p_ff_launch
  if (w_pixel_qual) begin
    reg_hold_data <= i_dvp_data;
    reg_pix_tgl   <= ~reg_pix_tgl;
  end
end
// APB domain: take the baseline from the synchronized toggle, so power-up state does not matter
always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_tgl_seen
  if (!i_rst_n_apb)        reg_tgl_seen <= 1'b0;
  else                     reg_tgl_seen <= w_tgl_sync2;   // event = w_tgl_sync2 ^ reg_tgl_seen
end
assign w_pix_event = (w_tgl_sync2 ^ reg_tgl_seen) && i_capture_en && w_frame_active;
// simulation only: force an initial value of reg_pix_tgl and reg_hold_data in the testbench.
```

### F-010 Violating the gated-mode spacing or VSYNC width gives silent pixel loss

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:1834`
- Severity: `High`
- Label: FACT; locator: §10.6 (line 1834), REQ-FUNC-007 (line 132), REQ-PERF-001 (line 135), CDC-003 and CDC-004 (lines 450-451)
- Assessment: The contract depends on the sensor, the board and the APB clock, none of which the RTL controls, and a violation produces corrupted data that looks valid. A two-flop echo of the consumed toggle back to PCLK detects it at low cost.
- Verdict: `fix`
- Fix: Add an acknowledge toggle from CLK-APB, synchronize it into PCLK, and flag a new pixel that arrives while the previous toggle is unconsumed; carry the flag back to CLK-APB as a toggle event that sets dvp_fifo_sts.ovf or a new gated_ovr bit.
- Why: A spacing violation becomes a sticky, software-visible fault at the cost of about 6 flops, so the integration condition can be verified on silicon, not only in STA.

```systemverilog
// APB domain: echo the last consumed toggle back to the PCLK domain
assign o_tgl_ack = reg_tgl_seen;
// PCLK domain: two-flop synchronizer of o_tgl_ack gives w_ack_sync2; a new pixel while the old one is unconsumed is an overrun
assign w_unconsumed = (reg_pix_tgl != w_ack_sync2);
always_ff @(posedge i_clk_dvp, negedge i_rst_n_dvp) begin : p_ff_overrun
  if (!i_rst_n_dvp)                          reg_gate_ovr_tgl <= 1'b0;
  else if (w_pixel_qual && w_unconsumed)     reg_gate_ovr_tgl <= ~reg_gate_ovr_tgl;   // toggle event to CLK-APB
end
// CLK-APB: synchronize reg_gate_ovr_tgl and set dvp_fifo_sts.ovf (sticky, set-dominant W1C) on either edge.
```

### F-011 PCLK edge, VSYNC and HREF polarity are fixed at elaboration

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:119`
- Severity: `High`
- Label: INFERENCE; locator: §8 (lines 475-478), REQ-FUNC-002 (line 119), DEC-001 (line 2182)
- Assessment: An ASIC cannot change the profile after tape-out, so a different sensor mode or a board with an inverted VSYNC would need a respin. Compile-time selection saves a few gates but removes post-silicon flexibility.
- Verdict: `fix`
- Fix: Keep the compile-time default and add a dvp_cfg register (pclk_edge, vsync_pol, href_pol) writable only while capture_en is 0; implement the edge choice with a static-select clock XOR or library mux cell, with set_case_analysis per mode in STA and a scan bypass.
- Why: One build then covers rising and falling sample edges and both polarities, and the static select keeps the clock path single-edge for timing and DFT.

### F-012 Wide CSR fields allow values that silently disable service

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:495`
- Severity: `Medium`
- Label: INFERENCE; locator: §9 (line 495), CSR dvp_wmark.level [31:0], dvp_timeout.cycles [31:0]
- Assessment: The field should carry exactly what the hardware can honour and report an out-of-range write.
- Verdict: `fix`
- Fix: Size dvp_wmark.level to OCC_W bits, clamp or reject a larger write with PSLVERR (the generator already supports PSLVERR) or a sticky wmark_err, and size dvp_timeout.cycles as in F-007.
- Why: An impossible configuration is refused at write time instead of appearing as a dead DMA, and about 28 flops are saved at the default depth.

### F-013 One sample per 32-bit word wastes 62.5 to 75 percent of the APB data bus, with no packed option

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:133`
- Severity: `Medium`
- Label: INFERENCE; locator: §9 (line 493), REQ-FUNC-008 (line 133), DEC-014 (line 2196)
- Assessment: The decision is recorded (DEC-014), but it fixes the throughput limit of F-019 and the byte order of YUV pairs is left unstated.
- Verdict: `fix`
- Fix: Add dvp_ctrl.pack: 4 x 8-bit samples or 2 x (10 or 12-bit) samples per 32-bit word, first sample in the least significant lane, written when the word is complete, with the tail handled by the flush of F-005.
- Why: The APB read count per frame falls by 4 (8-bit) or 2 (10/12-bit) and the lane order is defined once for software and DMA.

### F-014 Falling-edge sampling and a stoppable PCLK domain need explicit clock and constraint handling

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:476`
- Severity: `Medium`
- Label: INFERENCE; locator: §8 PARA_DVP_SAMPLE_EDGE (line 476), §10.6 (lines 1822-1824), §14.3 (lines 2018-2028)
- Assessment: Not a blocker for synthesis; the choice affects constraints (F-016) and DFT (F-022). Single-edge flops with a clock XOR at the port are the usual answer.
- Verdict: `fix`
- Fix: State in §14.3 how the falling edge is built (one clock inversion at the port feeding posedge flops, not mixed-edge flops), that PCLK may stop in mode 1, and which paths are critical (synchronized-toggle detect to SFIFO write at the APB clock).
- Why: Synthesis, STA and DFT then share one clocking assumption instead of three.

### F-015 No SDC is delivered and the clock and I/O budgets are all TBD

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2100`
- Severity: `High`
- Label: FACT; locator: §17.1 (lines 2094-2120), CLK-APB and CLK-DVP rows (lines 2100-2101)
- Assessment: Timing closure cannot start. Constraints depend on the SoC, but the IP can ship a parameterised SDC template so that the structure (clocks, async groups, input delay formulas) is fixed.
- Verdict: `fix`
- Fix: Deliver sdc/dvp_controller.sdc with create_clock for both clocks, set_input_delay on the DVP pins relative to the sensor clock using tco, setup and hold from the selected datasheet, the APB I/O delays as parameters, and set_clock_groups -asynchronous only together with the bounded crossings of F-016.
- Why: The integrator edits numbers, not structure, and the asynchronous relationship cannot hide the bundled-data path.

### F-016 The bundled-data constraint has no value and the 4-cycle rule leaves one APB cycle of margin

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2118`
- Severity: `High`
- Label: INFERENCE; locator: EXC-003 (line 2118), REQ-PERF-001 (line 135), §10.6 (lines 1830-1836)
- Assessment: The correctness of mode 1 rests on a number nobody has written. The derivation (three edges consumed, four available, one period left for the physical margin) gives the constraint at once.
- Verdict: `fix`
- Fix: Replace EXC-003 by the two set_max_delay -datapath_only constraints (payload: 2 x T_APB, toggle: 1 x T_APB) with the derivation, add a set_min_delay hold check, and state the real condition as T_PIX,min >= 4 x T_APB + T_margin with T_margin computed in the SDC.
- Why: The constraint is checkable by STA and tied to the same derivation as the HDS, and the CDC tool can accept the bundled bus as reviewed instead of waived.

```tcl
# Bundled-data crossing of the gated mode (period of CLK-APB = $T_apb); derive 2*T_apb from 4-cycle spacing minus
# the 2-FF + detect latency (3 edges) in the worst phase, keep one T_apb for setup/hold/uncertainty
set T_apb [get_property period [get_clocks clk_apb]]
set_max_delay -datapath_only [expr {2.0 * $T_apb}] \
  -from [get_cells u_dvp_capture/reg_hold_data*] -to [get_cells *u_dvp_sfifo*/*mem*]
set_max_delay -datapath_only [expr {1.0 * $T_apb}] \
  -from [get_cells u_dvp_capture/reg_pix_tgl]     -to [get_cells *u_dvp_gate_bridge*/*tgl_sync_ff1*]
set_clock_groups -asynchronous -group [get_clocks clk_apb] -group [get_clocks clk_dvp]   ;# only with the two lines above kept
```

### F-017 No area or power basis is given, not even a structural proxy

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:1965`
- Severity: `High`
- Label: FACT; locator: PPA-002 and PPA-003 (lines 1965-1966), §13 (line 1969)
- Assessment: Without a proxy the integrator cannot compare the build with the SoC budget. The proxy needs no library; a mapped number needs Yosys and a Liberty file, which were not available to this review.
- Verdict: `fix`
- Fix: Add an area proxy table to §13 (storage bits per FIFO, pointer and synchronizer flops, CSR flops, counters) as a function of PARA_DVP_DATA_W and PARA_FIFO_DEPTH, labelled proxy, and add a mapped result when a library is chosen; state that no clock gating is implemented, so dynamic power follows the sample rate.
- Why: The estimate scales with the two parameters the integrator controls, and the labels keep a proxy from being read as a synthesis result.

### F-018 Both mode FIFOs are always built, so storage is doubled while one mode is active

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:121`
- Severity: `Medium`
- Label: INFERENCE; locator: REQ-PARAM-001 (line 121), §5.1 (lines 159-163), §13 (line 1969)
- Assessment: The cost is invisible at depth 8 and large at the depths the HDS itself recommends. A single storage array shared by both modes is possible if the SFIFO write side is driven by the APB clock.
- Verdict: `fix`
- Fix: Decide between a shared array (write clock of the AFIFO selected statically between PCLK and CLK-APB, with the clock mux treated as in F-011) and a parameter that builds only one of the two paths; record the choice and its area in §13.
- Why: Halving storage at large depth is the single largest area saving available, and the parameter makes the cost explicit.

### F-019 The performance metrics are formulas with no values, and the derived demand is high

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:1961`
- Severity: `High`
- Label: INFERENCE; locator: PERF-001..003 (lines 1961-1963), §13 sizing (line 1969), REQ-PERF-001 (line 135)
- Assessment: The IP is feasible only for modest sensors or with a high APB clock, and the HDS does not say so. The FIFO must also bridge the peak rate over the DMA stall, which at depth 8 is only 333 ns at 24 MHz.
- Verdict: `fix`
- Fix: Give PERF-001..003 numeric targets for named workloads (VGA YUV at 24 MHz, 720p30), add the minimum f_APB, the FIFO depth for a stated DMA stall, and the latency from the last sample of a frame to its visible level, and verify them in TEST-010.
- Why: Each metric becomes a test with a pass level, and the integrator learns the APB clock the IP really needs.

### F-020 There is no flush, so recovery from overflow or a stall needs a full IP reset or a blind drain

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:462`
- Severity: `High`
- Label: INFERENCE; locator: §12 (line 1955), DEC-025 (line 2206), RST-SW (line 462), §7.3 (line 464)
- Assessment: Firmware can recover only by resetting the whole IP or by reading until the empty timeout, which is slow and cannot be aligned to a frame boundary. The common AFIFO already has a software reset input (i_rst_n_sw) that the HDS ties inactive.
- Verdict: `fix`
- Fix: Add a self-clearing dvp_ctrl.fifo_clr that resets the selected FIFO (use i_rst_n_sw of the AFIFO and a pointer clear of the SFIFO) while capture is disabled, and document the recovery sequence after ovf: clear capture_en, fifo_clr, clear ovf, restart at the next VSYNC.
- Why: Recovery is one register write and the next frame starts clean, with the sample stream re-aligned to a VSYNC.

### F-021 A refused PCLK_MODE write completes with OKAY and no flag

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:129`
- Severity: `Medium`
- Label: FACT; locator: REQ-FUNC-004 (line 129), DEC-018 (line 2199), §10.6 (line 1817), D28 (line 1828)
- Assessment: A silent partial write is the pattern a driver gets wrong. The CSR already supports PSLVERR and W1C flags.
- Verdict: `fix`
- Fix: Set a sticky dvp_fifo_sts.mode_rej (W1C) on a refused mode write, or return PSLVERR for that write, and describe the readback loop of D28 as a driver rule.
- Why: The driver learns about the refusal in the same transfer or at the next status read, with no need to compare readbacks.

### F-022 DFT is deferred to the SoC while the design has structures that decide scan eligibility

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2081`
- Severity: `High`
- Label: INFERENCE; locator: §16 (lines 2079-2088), G-004..G-006 of the gap scan
- Assessment: Scan insertion will need a clock mux and a lockup structure, and the SoC team cannot decide them without the IP statement.
- Verdict: `fix`
- Fix: Replace the TBD rows by: scan clock is the SoC test clock muxed onto both domains, the PCLK input and the clock XOR of F-011 get a scan bypass, no latches or gated clocks inside the IP, reset is held inactive in test mode, and the memory array is RTL flops (scannable) unless a macro with its own wrapper is chosen.
- Why: The DFT owner gets concrete constraints and the clock structure of F-011 and F-014 is made testable.

### F-023 PPROT is ignored, protection is disabled, and pixel privacy is left to the SoC

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:62`
- Severity: `Low`
- Label: FACT; locator: §1.2 (line 62), §18 (lines 2139-2142)
- Assessment: Acceptable for a first release when the interconnect enforces isolation, as the HDS states.
- Verdict: `waive`
- Why: The SoC interconnect owns privilege isolation (§1.2) and the IP has no secret to protect.
- Risk: low; any APB requester that can reach FIFO_DATA can read the video.
- Owner: SoC architect
- Invalidation: The SoC places the IP behind an unprivileged APB requester or a product requires frame data to be secure-only; then enable i_protect_en with a PPROT rule for FIFO_DATA.

### F-024 No integrity scheme is decided and the diagnostics are one sticky flag

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2143`
- Severity: `Medium`
- Label: INFERENCE; locator: §18 ECC and diagnostics rows (lines 2143-2145), ERR-001..006 (lines 1946-1953)
- Assessment: The stance is explicit but thin. A counter of dropped samples and the flags of F-007, F-010 and F-021 are cheap and give the RAS information the HDS says "should be software-visible".
- Verdict: `fix`
- Fix: Add a 16-bit saturating dvp_drop_cnt, list rd_to, gated_ovr and mode_rej in the status register, and state "no ECC, no safety claim" as the decision, with the condition under which it is revisited.
- Why: Faults become countable and diagnosable on the bench, and the safety stance is a recorded decision, not a gap.

### F-025 No behavioural simulation has been run; the evidence is lint and static checks

- Evidence: `verification/README.md:5`
- Severity: `High`
- Label: FACT; locator: verification/README.md, RTL_GENERATION_REPORT.md (Verification boundary), §15.1 (line 2034)
- Assessment: The honesty of the boundary is good, but a spec whose ordering, timeout, mode-lock and CDC rules have never been exercised cannot be signed off. This review does not claim the RTL works.
- Verdict: `fix`
- Fix: Build the APB requester, DVP sensor model (rising and falling edge, both polarities, continuous and gated PCLK) and scoreboard, run TEST-001..015 for the 8, 10 and 12-bit profiles, and report pass/fail with coverage numbers.
- Why: The behaviours the HDS defines, such as the terminal-cycle priority of REQ-IF-005 and the pop-exactly-once rule, become measured results.

### F-026 Assertions have no IDs, formal is pending, and the stall and silent-failure scenarios are not tested

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2056`
- Severity: `High`
- Label: INFERENCE; locator: §15.3 (lines 2056-2067), §15.4 (lines 2069-2075), TEST-005 (line 2045)
- Assessment: A complete trace to tests that miss the dangerous cases is weaker than it looks. The assertion list is the cheapest way to make the invariants of §5.3 executable.
- Verdict: `fix`
- Fix: Assign IDs SVA-001.. to the properties of §15.3, add tests for the four scenarios above and a sensor-timing test per supported mode, and write the formal property set (push/pop safety, REQ/ACK, reset invariants) before the RTL freeze.
- Why: Every invariant and every known failure mode has a check that fails when the behaviour is wrong.

### F-027 Template text and a broken link remain in the normative document

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2232`
- Severity: `Medium`
- Label: FACT; locator: Purpose block (line 17), §22 (lines 2230-2243), link at line 2232
- Assessment: Cosmetic but confusing for a reader who relies on the normative references.
- Verdict: `fix`
- Fix: Delete the template purpose block and the template references of §22, keep the DVP research list, and correct the anchor to #21-normative-references or #2-normative-references-and-precedence.
- Why: The document then contains only content that belongs to this IP.

### F-028 Version, status and the duplicate baseline are not aligned, and decision order and local paths are untidy

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:6`
- Severity: `Medium`
- Label: FACT; locator: Front matter (lines 1-11), IP README, §20 DEC order (lines 2188-2196), REF-003 (line 90)
- Assessment: Two files of the same name make it easy to review or implement the wrong one (this review had to ask).
- Verdict: `fix`
- Fix: Set version and status to the approved state, rename the baseline file or move it under an archive folder, sort the DEC list, and cite repository-relative paths.
- Why: One authoritative file and a stable identifier order make traceability checks mechanical.

### F-029 No sensor mode is validated, so the gated-mode contract is not shown to be satisfiable

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:2187`
- Severity: `High`
- Label: INFERENCE; locator: REF-006 (line 93), DEC-006 (line 2187), §2.3 (line 111), research D01 D04 D08
- Assessment: The integration risk sits in the sensor, and nobody has shown that a real part meets the condition. A walk through one OV7670 mode and one onsemi mode would settle it.
- Verdict: `fix`
- Fix: Add an integration table: for each of two reference sensors list the register setting, the PCLK behaviour in blanking, the VSYNC width in PCLK cycles, the data setup and hold, and the resulting minimum f_APB, and mark mode 1 unsupported where the sensor cannot meet it.
- Why: Mode 1 is accepted or refused per sensor by evidence instead of by assumption.

### F-030 Fifteen integration items remain open and no integration guide exists

- Evidence: `verification/static/hds_gaps.log:2`
- Severity: `Medium`
- Label: FACT; locator: verification/static/hds_gaps.log (G-001..G-015), §20 ASM-001, ASM-002
- Assessment: The items are legitimately integrator inputs, but a checklist of what must be supplied and what to verify is missing.
- Verdict: `fix`
- Fix: Add an integration checklist to §20: the 15 inputs with owner and due stage, the tie-offs (i_protect_en, i_slverr_en), clock and reset relationships, the DMA contract of F-008 and the sensor table of F-029.
- Why: The integrator knows what to provide and what to check before bring-up.

### F-031 The IP lacks the frame-level automation of commercial camera interfaces

- Evidence: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md:66`
- Severity: `High`
- Label: INFERENCE; locator: §1.3 (lines 66-71), §6.4 (line 432), §9 (line 493); sources in section 19 of this report
- Assessment: For a CPU-light embedded vision SoC the missing frame events, packing and interrupt make the driver heavier than on the compared parts. The gated mode and the explicit overflow policy are strengths worth keeping.
- Verdict: `fix`
- Fix: Prioritise F-002 (frame events and counters), F-006 (interrupt), F-013 (packing) and F-011 (runtime polarity) for the first release, and leave crop and decimation as a stated later option.
- Why: These four close most of the gap to the compared interfaces for the smallest hardware cost.

## 3. Actions

| Action | Owner | Blocks sign-off |
|---|---|---|
| Change the DMA FSM to burst-counted service and update REQ-IF-004, DEC-008 (F-004, P0) | Spec, RTL | yes |
| Define the end-of-frame flush request in §6.3 and §10.1 (F-005, P0) | Spec, RTL | yes |
| Re-implement DEC-029 without a cross-domain reset (F-009, P0) | Spec, RTL | yes |
| Run the directed and random simulation for TEST-001..015 (F-025, P0) | Verification | yes |
| Write the reference workload table and sizing result in §13 (F-001, P1) | Spec | yes |
| Add frame/line counters, frame_done and snapshot to the CSR workbook and §10 (F-002, P1) | Spec, RTL | yes |
| Add the interrupt output and registers (spec, CSR workbook, RTL) (F-006, P1) | Spec, RTL | yes |
| Bound dvp_timeout, define PRDATA on error, add rd_to flag (F-007, P1) | Spec, RTL, SoC | yes |
| Add the gated-mode overrun detector and flag (F-010, P1) | Spec, RTL | yes |
| Decide runtime polarity and edge selection (HAS decision, then RTL) (F-011, P1) | Spec, RTL, DFT | yes |
| Deliver the SDC template with parameterised clock and I/O budgets (F-015, P1) | SDC, SoC | yes |
| Quantify EXC-003 and the margin rule (F-016, P1) | SDC | yes |
| Quantify PERF-001..003 and the supported workload range (F-019, P1) | Spec | yes |
| Add fifo_clr and the overflow recovery sequence to §11.2 (F-020, P1) | Spec, RTL | yes |
| Add SVA IDs, the missing tests and the formal property list (F-026, P1) | Verification, Spec | yes |
| Validate mode 0 and mode 1 against two real sensor modes (F-029, P1) | Integration, Spec | yes |
| Adopt the four priority features for release 1 (F-031, P1) | Spec | yes |
| Add the supported sensor-mode table to §1 and §8 (F-003, P2) | Spec | no |
| Write the DMA contract table (F-008, P2) | Spec | no |
| Bound the CSR field widths and add the range check (F-012, P2) | Spec, RTL | no |
| Specify the packed read mode and lane order (F-013, P2) | Spec, RTL | no |
| Document the clocking structure in §14.3 (F-014, P2) | Spec | no |
| Add the area proxy and power statement to §13 (F-017, P2) | Spec | no |
| Decide shared FIFO array or single-path build (F-018, P2) | Spec, RTL | no |
| Flag a refused mode write (F-021, P2) | Spec, RTL | no |
| Write the DFT statement for both clocks and the reset (F-022, P2) | DFT, Spec | no |
| Add drop counter and diagnostic flags; record the safety stance (F-024, P2) | Spec, RTL | no |
| Write the integration checklist (F-030, P2) | Spec, Integration | no |
| Record the waiver in the integration guide (F-023, P3) | SoC architect | no |
| Remove template residue from the HDS (F-027, P3) | Spec | no |
| Align front matter, archive the baseline, sort DEC (F-028, P3) | Spec | no |

## 4. Limits

- No behavioural simulation, synthesis, CDC, RDC, formal or STA run exists, and none was run here; the RTL was not cross-checked against the HDS.
- Area is a structural proxy (about 320 flops, default build), not a mapped number; no library was available.
- Commercial data are web search summaries dated 2026-11-22; no reference manual was opened.
- The audit sample was judged by the same reviewer; a second reviewer is needed for an independent false-negative rate.
- Reviewed file: `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md`; the baseline HDS was read for traceability only.


