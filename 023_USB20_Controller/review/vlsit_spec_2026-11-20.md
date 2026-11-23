# Specification review of USB20_CONTROLLER - 2026-11-20

## 1. Summary

| Item | Value |
|---|---|
| Design | `USB20_CONTROLLER` |
| Review | Specification review |
| Date | 2026-11-20 |
| Findings | 34 |
| Critical | 1 |
| High | 12 |
| Medium | 16 |
| Low | 5 |
| Waivable | 0 |
| Fixable | 32 |

Gate: `RESULT: FAIL` (vlsit_review_gate.py metrics): 34 findings, Critical 1, High 12, Medium 16, Low 5; waiver usage 0/10 (budget 10); sampling 32 %; reason: 1 unwaived Critical finding(s): F-001. The gate stays FAIL until F-001 is fixed in the specification; no waiver was granted.

Audit: 4 of 34 findings sampled by vlsit_review_gate.py sample (F-009, F-003, F-010, F-019): tp 4, fp 0, fn 0 observed; false-positive rate 0 %; false-negative rate 0 % inside the sample (the sample cannot measure issues that were never reported, so the false-negative rate is a lower bound).

Severity mapping: Blocker is Critical, Major is High, Minor is Medium, Observation is Low. The full bilingual review is REVIEW_USB20_CONTROLLER.md.

## 2. Findings

Each finding has an assessment, a verdict and, when it can be fixed, the RTL change and the reason it works. The fixes are changes of the specification (HAS) that precede RTL.

### F-001 No approved crossing structure for the multi-bit endpoint and channel registers

- Severity: `Critical`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:930`
- Assessment: FACT: CDC-001 says the bundled values change only while the core is disabled, but S13, S15 and S17 of section 11.2 write ep_en, ch_en, set_nak, set_d0, stall and port_rst while core_en = 1, and section 11.3 routes the whole u2_epi_*, u2_epo_* and u2_hc_* banks (about 3 800 control flip-flops at the default counts, proxy from regs_usb2.json) through CDC-001 and CDC-003, which are a level synchronizer and a pulse synchronizer. No structure carries a 32-bit field such as u2_epi_dma.addr safely from CLK-BUS to CLK-PHY.
- Verdict: `fix`
- Fix: Define a request and acknowledge handshake per bank entry (data held stable while the toggle crosses), or keep the endpoint and channel registers in CLK-PHY and write them from CLK-BUS through an asynchronous FIFO; update CDC-001 and CDC-003 and the CDC verification.
- Why: A held-data handshake lets a multi-bit value cross while the sender keeps it constant until the receiver acknowledges, so no bit is sampled mid-change; the two-flop synchronizers of the current text are valid only for one-bit levels.

```systemverilog
// toggle handshake, sender side (CLK-BUS); data is held until ack_sync toggles
always_ff @(posedge i_clk_bus or negedge i_rst_n_bus)
  if (!i_rst_n_bus) reg_req_tog <= 1'b0;
  else if (w_wr_pulse && (reg_req_tog == w_ack_tog_sync)) begin
    reg_data    <= w_wdata;   // stable until the next request
    reg_req_tog <= ~reg_req_tog;
  end
```

### F-002 Hardware-updated counters are read across CLK-PHY to CLK-BUS as levels

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:931`
- Assessment: FACT: xsize, pkt_cnt and the DMA address are counted down or advanced by hardware (section 11.3, rwi), and CDC-002 transfers status as synchronized levels. INFERENCE: a software read of a 19-bit counter that changes at packet rate can return a mixed value, and the rule that a software write wins over a hardware load can drop one decrement.
- Verdict: `fix`
- Fix: Snapshot the counters in CLK-PHY and cross them with the same handshake as F-001, and state how a lost load is repeated.
- Why: A snapshot taken while the source is stable gives software one consistent value per read.

### F-003 The single-port FIFO RAM has no bandwidth margin in the 16-bit UTMI+ configuration

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4668`
- Assessment: INFERENCE: section 10.4 shows 50 % use of 240 MB/s (32 bits at 60 MHz). With PARA_USB2_UTMI_W = 16 the RAM is in CLK-PHY at 30 MHz (section 7.1), so one port gives 120 MB/s while the packet engine needs 60 MB/s and the bus side up to 60 MB/s, which is 100 % use with no margin for arbitration or double buffering.
- Verdict: `fix`
- Fix: Add a bandwidth table per configuration, and either widen the RAM word to 64 bits when UTMI+ is 16 bits, run the RAM on a faster clock, or limit the 16-bit configuration to full-speed traffic.
- Why: A wider word halves the access count per byte, so the same traffic uses about half of the RAM cycles at 30 MHz.

### F-004 ULPI low power mode, clock restart and resume are not specified

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:5205`
- Assessment: FACT: TBD-005 leaves the ULPI low power mode open, section 7.4 says the PHY clock stops in suspend, and the ulpi_if FSM has no low-power, wake or reset state. INFERENCE: without them the link cannot enter suspend or L1 in a ULPI build, nor detect resume while CLK-PHY is stopped.
- Verdict: `fix`
- Fix: Read the low power sections of REF-007 (Figures 46 to 49, Table 15), add the states ENUM_ST_UL_LP and ENUM_ST_UL_WAKE and requirements for the stp and dir sequences and the clock restart wait.
- Why: The ULPI link must drive stp and wait for the PHY clock restart before sending data, so the sequence is part of the interface contract.

### F-005 The UTMI+ mode signals have no value table per bus state

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:802`
- Assessment: FACT: section 6.2 names OpMode, XcvrSelect and TermSelect but gives no table of the values for high-speed, full-speed, low-speed, preamble, chirp and suspend, and REF-006 section 2.1.1.4 requires TXReady during chirp data. The chirp, level 3 preamble and suspend sequences depend on these values.
- Verdict: `fix`
- Fix: Add a table from REF-006 and REF-007 that maps each state of the speed FSMs to XcvrSelect, TermSelect, OpMode, DpPulldown and DmPulldown.
- Why: The table makes the speed and port FSMs implementable without reading the PHY datasheet first.

### F-006 The AXI4 profile is specified against AXI3 text

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:162`
- Assessment: FACT: the only AXI text in md_doc is AXI v1.0 (AXI3 era); ASM-007 limits the profile to INCR bursts of at most 16 beats with no lock, QoS, region or user. INFERENCE: AXI4 behavior (for example awlen of 8 bits and the 4 KB rule wording) cannot be checked against a source.
- Verdict: `fix`
- Fix: Add the AXI4 standard (IHI 0022 Issue H.c) to md_doc and recheck REQ-IF-006 and REQ-IF-007, or state the profile as AXI3-compatible only.
- Why: A requirement is checkable only against a text that was read.

### F-007 UTMI+ and ULPI statements rest on unofficial copies and unverified conversions

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:5178`
- Assessment: FACT: ASM-001 records that UTMI+ 1.0 (nxp.com mirror, 26 pages) and ULPI 1.1 (sparkfun.com mirror) are third-party copies, and the conversion check reported CHECK for every converted document with 114 pages of USB 2.0 differing by more than 5 %. The protocol statements of REQ-IF-001 to REQ-IF-004 and many REQ-FUNC lines cite them.
- Verdict: `fix`
- Fix: Replace the copies by the official documents, inspect the pages that differ by more than 5 %, and record the result in section 2.1.
- Why: An authoritative text removes the risk that a table or a figure was lost in conversion.

### F-008 Split transactions have a token format but no timing or retry rules

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:80`
- Assessment: FACT: REQ-FUNC-017 gives the SPLIT PID and the NYET and ERR handshakes only. It has no rule for the earliest and latest complete-split microframe, no retry count, no handling of isochronous MDATA, and the host_xact FSM has one ENUM_ST_HX_SPLIT state; WF-013 is not to scale.
- Verdict: `fix`
- Fix: Derive requirements from REF-001 sections 11.17 to 11.21 for the start-split and complete-split scheduling, the TT buffering responses and the retry limit, and split ENUM_ST_HX_SPLIT into start and complete states.
- Why: These rules decide whether a full-speed device behind a hub works at all, and software cannot add them.

### F-009 The 192 bit-time turnaround budget is stated but not derived

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4847`
- Assessment: FACT: PERF-002 gives an internal budget of 20 CLK-PHY cycles for a handshake start within 192 bit times (24 cycles) including the ULPI pipeline. INFERENCE: REF-007 Tables 8 to 10 (PHY pipeline delays, link decision times) are not applied, and the path token decode to first RAM byte to TXValid has no cycle count, so the figure is a claim.
- Verdict: `fix`
- Fix: Add a cycle budget table per response path for UTMI+ 8-bit, UTMI+ 16-bit and ULPI, using the pipeline delays of REF-006 and REF-007.
- Why: A table of stage delays shows whether the 24-cycle limit has margin before RTL exists.

### F-010 The UTMI+ and ULPI interface timing budgets have no numbers

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:5003`
- Assessment: FACT: the rows of section 17.1.2 for the UTMI+ and ULPI pins say TBD-007 and name REF-007 Table 5 as the source to apply. Interface timing is the first path that fails at 60 MHz.
- Verdict: `fix`
- Fix: Transcribe the input and output delay and clock jitter values of REF-007 Table 5 and the UTMI+ timing into the table, and derive the set_input_delay and set_output_delay values.
- Why: The constraints are the contract the integrator closes timing against.

### F-011 The SDC files named by the specification do not exist

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4994`
- Assessment: FACT: sections 17.1.1 and 17.1.2 name sdc/usb2_clocks.sdc and sdc/usb2_io.sdc as constraint sources, and the folder 023_USB20_Controller has no sdc or constraints directory (folder inventory, appendix).
- Verdict: `fix`
- Fix: Deliver the two SDC files with the specification, or change the text to say that they are produced with the RTL.
- Why: A named but absent file is a finding in itself because the reader cannot check the constraints.

### F-012 Area and power have no number and no activity assumption

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4844`
- Assessment: FACT: PPA-003 and PPA-004 are goals with no number, and area is deferred to synthesis. proxy: the CSR holds 3 802 control flip-flops at the default counts (9 endpoint, 8 channel, 4 DMA entries) and 6 868 at the maximum counts (regs_usb2.json, rw, rwi and w1c bits) plus a 4 KB RAM; the host channel registers duplicate the device endpoint registers, whereas REF-011 table 3-4 reuses the device registers as host registers to save area.
- Verdict: `fix`
- Fix: Record the proxy table (flip-flops, RAM bits, wide muxes) per configuration with its assumptions, state a power activity assumption, and evaluate sharing the device and host register banks.
- Why: A labelled proxy lets the integrator size the block before synthesis.

### F-013 The register model is custom, so no existing USB driver runs on it

- Severity: `High`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4688`
- Assessment: FACT: the CSR is a new 44-register map (REF-005); REF-011 is only a design reference. INFERENCE: Linux gadget and host stacks, TinyUSB and vendor HALs expect a known controller register model, so the firmware team must write and verify a driver, which the specification does not budget or describe.
- Verdict: `fix`
- Fix: Add a software integration section: driver scope, a register-level state-machine reference for EP0, a statement of compatibility, and an option to provide a compatibility view of a known controller.
- Why: A driver plan turns a hidden firmware cost into a scheduled one.

### F-014 The rule for a lost rwi load is stated but not defined per field

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4801`
- Assessment: FACT: section 11.3 says the IP repeats a lost load, 'a count-down update is re-applied in the next cycle'. INFERENCE: the repeated value depends on whether software wrote xsize or the hardware had counted, and the text does not say which wins.
- Verdict: `fix`
- Fix: Define per rwi field who wins and how the hardware reapplies, and add an assertion.
- Why: An explicit rule is needed for the verification to check.

### F-015 The over-current requirement gives one latency for two outputs in different clock domains

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:202`
- Assessment: FACT: REQ-FUNC-034 says o_vbus_pwr_en and o_utmi_drvvbus drop within 2 CLK-BUS cycles, but o_utmi_drvvbus is a CLK-PHY output reached through CDC-001 (WF-035 shows it later) and CLK-PHY can be stopped in suspend. ULPI has no DrvVbus pin.
- Verdict: `fix`
- Fix: Split the requirement: o_vbus_pwr_en within 2 CLK-BUS cycles, o_utmi_drvvbus within a stated number of CLK-PHY cycles or at the next clock restart, and a ULPI OTG control register write for ULPI builds.
- Why: Only the CLK-BUS output has a guaranteed latency; the other path must be stated separately.

### F-016 The ID source of the dual-role port is not stated for ULPI builds

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:72`
- Assessment: INFERENCE: the ULPI port list has no ID pin and the UTMI+ port list has i_utmi_iddig, so in a ULPI build the ID indication must come from the PHY status byte and the ID pull-up from a PHY register write; REQ-FUNC-023 and S05 do not say which register or bit.
- Verdict: `fix`
- Fix: State the ULPI register and RX CMD field for ID, and add the PHY register writes to the initialization flow.
- Why: Role selection in a ULPI build depends on this register access.

### F-017 The soft-error statement for the FIFO RAM is not correct

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:5053`
- Assessment: INFERENCE: section 18 says a RAM soft error is detected by the CRC of the next packet on the wire side. The CRC16 is generated over the bytes read from the RAM at transmit time, so a flipped bit produces a valid CRC and is not detected; a receive-side flip happens after the CRC check.
- Verdict: `fix`
- Fix: Correct the statement and decide TBD-010: add one parity bit per RAM word with an error flag and a fail-safe response for the drone product, or document the residual risk.
- Why: A parity bit detects a single flip at read time, before the CRC is generated.

```systemverilog
// 33-bit RAM word: parity written with the data and checked on read
assign w_par_wr = ^w_wdata;
assign w_par_err = (^w_rdata_full[31:0]) ^ w_rdata_full[32];
```

### F-018 DMA addresses are unrestricted software values

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4803`
- Assessment: FACT: the DMA address registers and u2_dma_hi are plain read-write fields and the only access protection of the CSR is PPROT[1] with i_protect_en (section 11.4). INFERENCE: any APB master that can write the CSR can point the DMA at any address of the AXI fabric.
- Verdict: `fix`
- Fix: Add an optional address window check (base and limit registers) that raises dma_err on a violation, or state that the SoC firewall owns it.
- Why: A window check contains a faulty descriptor before it reaches memory.

### F-019 Reset behavior with a stopped CLK-PHY is not stated

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:937`
- Assessment: FACT: section 7.3 gives reset sequencing for running clocks, but the PHY may stop CLK-PHY in ULPI low power mode (section 7.1) and the soft-reset pulse crosses through CDC-005 into CLK-PHY. INFERENCE: with the clock stopped a soft reset never completes, and S18 does not check phy_clk_ok.
- Verdict: `fix`
- Fix: State the stopped-clock behavior of i_rst_n_phy and the soft reset, require phy_clk_ok = 1 in S18, and add a timeout flag.
- Why: The software then never waits for a reset that cannot finish.

### F-020 Illegal parameters are undefined and the CSR bank counts are 19 separate parameters

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:219`
- Assessment: FACT: REQ-PARAM-001 and ASM-011 leave illegal values undefined, and section 11.1 requires the integrator to tie each generated PARA_U2_xx_COUNT (19 banks) to PARA_USB2_NUM_EP, NUM_HC or NUM_DMA_CH. INFERENCE: a mismatch between a bank count and the engines produces silent address or endpoint errors.
- Verdict: `fix`
- Fix: Derive all bank counts inside the core from three parameters and add a synthesizable-neutral elaboration check module reported by lint.
- Why: One source for each count removes the mismatch.

### F-021 The minimum FIFO depth rule does not cover high-bandwidth and double buffering

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:962`
- Assessment: INFERENCE: the rule requires only one maximum packet (256 words), while high-bandwidth isochronous is always present (ASM-005) with up to three 1 024-byte transactions per microframe (768 words) and dbuf doubles each region; CFG-MIN uses 256 words.
- Verdict: `fix`
- Fix: Define the minimum region size as a function of endpoint type, mult and dbuf, and make the check part of REQ-PARAM-001.
- Why: The check then rejects a configuration that cannot hold its traffic.

### F-022 Host scheduling cites an open assumption and omits the periodic bandwidth limits

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:183`
- Assessment: FACT: REQ-FUNC-015 has ASM-014 (open) as its source; REF-001 section 5.7.4 limits periodic transfers to 80 % of a high-speed microframe and 90 % of a full-speed or low-speed frame. The requirement does not state the limits or an admission check.
- Verdict: `fix`
- Fix: Add the limits as requirements, with a software-visible refusal or flag when a channel set exceeds them, and close ASM-014.
- Why: The limits come from the standard and bound what the scheduler may accept.

### F-023 The time-out requirement has no number

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:193`
- Assessment: FACT: REQ-FUNC-025 refers to the bus turn-around time and gives no value in bit times, while REF-001 section 8.7.2 defines the timer start and stop events.
- Verdict: `fix`
- Fix: Add the worst-case turn-around values per speed from REF-001 sections 7.1.18 and 7.1.19.
- Why: A number makes the timer testable.

### F-024 Test mode entry and exit commands are not specified

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:82`
- Assessment: FACT: REQ-FUNC-022 lists the four test modes and the pattern; ASM-017 leaves the entry through SetFeature(TEST_MODE) open. FACT: the user's USB package contains an ECN on the TEST_MODE selector values that the specification does not cite.
- Verdict: `fix`
- Fix: Convert the ECN, add the selector values and the exit action to REQ-FUNC-022, and close ASM-017.
- Why: Compliance testing relies on the exact selector values.

### F-025 Other ECNs of the USB 2.0 package are not cited

- Severity: `Low`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:138`
- Assessment: INFERENCE: the package lists ECNs on double isochronous IN, phase-locked SOFs, suspend current and DCR that may affect the high-bandwidth isochronous and suspend requirements; only the LPM ECN is referenced.
- Verdict: `fix`
- Fix: Read the ECNs and record each as applicable or not applicable.
- Why: A short applicability table closes the question.

### F-026 The plan has no interoperability or compliance test with real stacks

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4902`
- Assessment: FACT: section 15.1 lists an FPGA prototype after the RTL and section 2.3 states that certification is not claimed; TEST-001 to TEST-029 use a bus model. INFERENCE: no test runs a real host or device stack (for example Linux gadget or TinyUSB) or the USB-IF device test sequence.
- Verdict: `fix`
- Fix: Add interoperability tests (CDC-ACM, UVC, mass storage with a real stack) and a compliance pre-check plan, with entry and exit criteria.
- Why: Real stacks exercise orderings that a hand-written bus model does not.

### F-027 Several requirements take their source from open assumptions, and the open items have no owner or date

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:5171`
- Assessment: FACT: REQ-FUNC-015, 032, 034, 035 and 036 cite ASM-014, 021, 022, 023 and 020 as their source and those are open; section 20 has 41 open items in a table without owner or date columns.
- Verdict: `fix`
- Fix: Add owner and date columns, resolve or label each requirement 'proposed' until its assumption closes.
- Why: An age and an owner make the open list manageable.

### F-028 Millisecond timings have no simulation time scaling

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4916`
- Assessment: INFERENCE: REQ-FUNC-011 (50 ms reset, 3 160 000 CLK-PHY cycles at 60 MHz), REQ-FUNC-018 (3 ms idle) and REQ-FUNC-019 (5 ms) are exercised by TEST-007 and TEST-009, and the specification has no timer scaling or test-time register to keep regression time short.
- Verdict: `fix`
- Fix: Add a verification-only timer scale (parameter or CSR field in test mode) and require that the scaled and unscaled timings are both tested at least once.
- Why: Scaling keeps the regression short while the unscaled run proves the real value.

### F-029 No critical-path statement for the 60 MHz domain

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4889`
- Assessment: FACT: section 14.3 leaves the frontend, libraries and corners to the RTL stage, and section 13 gives the CLK-PHY target of 60 MHz without naming a path. INFERENCE: the CRC16 update per byte, the RAM arbitration with the 20-cycle budget and the token decode are the likely critical paths and no pipeline split is stated.
- Verdict: `fix`
- Fix: List the expected critical paths with a pipeline stage count each, and require a synthesis run of one reference configuration before RTL sign-off.
- Why: A named path and a stage count make the 60 MHz target checkable.

### F-030 The specification has no integration checklist

- Severity: `Medium`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:766`
- Assessment: FACT: the tie-offs (i_ovrcur_n, i_protect_en, i_slverr_en), the pad wrapper for the bidirectional ULPI bus, the four wrappers and the RAM macro wrapper are described in separate sections. INFERENCE: the integrator has to assemble the bring-up order (clock, reset, PHY reset, phy_clk_ok, soft reset) from sections 7 and 11.2.
- Verdict: `fix`
- Fix: Add one integration table: tie-offs, clock and reset sequence, macro and pad wrappers, and the checks at power-up.
- Why: One table is the checklist the SoC team signs.

### F-031 DFT ports and RAM test position are deferred to the SoC flow

- Severity: `Low`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:4971`
- Assessment: FACT: section 16 defers the scan ports to TBD-009 and the RAM bypass and MBIST to the SoC memory flow, with CLK-PHY stopped by the PHY replaced by the scan clock.
- Verdict: `fix`
- Fix: Name the scan clock mux ownership and the RAM bypass wrapper requirement before RTL.
- Why: The two decisions change the clock and RAM wrappers.

### F-032 Feature set is close to the DWC_otg and the reference SoCs, with deliberate omissions

- Severity: `Low`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:66`
- Assessment: FACT: compared with the sources of chapter 19, the specification adds an optional LPM and split, scatter-gather and double buffering, and omits HNP, SRP, ADP, battery charging detection, HSIC, a dedicated FIFO per IN endpoint and per-endpoint interrupts. These omissions follow user answers of 2026-11-20 and are recorded in section 20.
- Verdict: `none`

### F-033 Every requirement has a test

- Severity: `Low`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:5057`
- Assessment: FACT: the inventory reports 59 requirements, 29 tests, 15 properties and 0 requirements without a test; section 19 maps each requirement to a module, a test, a method and a configuration.
- Verdict: `none`

### F-034 The application numbers are the author's proposals

- Severity: `Low`
- Evidence: `../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md:94`
- Assessment: FACT: section 1.4 gives a measurable need per feature, and ASM-006 records that the drone values (MAVLink 921 600 baud, 6 endpoints, MJPEG 720p30) are proposals that the user has not confirmed.
- Verdict: `fix`
- Fix: Confirm the values with the product owner and mark them 'confirmed' with a date.
- Why: The sizing of endpoints, channels and FIFO depends on them.

## 3. Actions

| Action | Owner | Blocks sign-off |
|---|---|---|
| Define a held-data CSR crossing (F-001, F-002) | architect | yes |
| Official UTMI+, ULPI, AXI4 texts and the mode tables (F-004 to F-008) | spec owner | yes |
| RAM bandwidth, turnaround budget, PHY timing and SDC files (F-003, F-009 to F-011) | spec owner, SoC | RTL freeze |
| Software and integration plans (F-013, F-030) | SW lead | integration |

## 4. Limits

- No synthesis, simulation or RTL exists, so area, power and timing closure were not assessed.
- ULPI clauses were not read in depth; AXI4 text is absent; the USB 2.0 conversion was not inspected page by page.
- Findings were traced in depth for 11 of 34; the others are grouped by root cause and can be traced further on request.
