# Change plan: UTMI+ wake from suspend with CLK-PHY stopped (FND-015, option B)

Date: 2026-11-26. Status: **PLAN, waiting for approval. No RTL or specification change has been made.**
Selected by the user on 2026-11-26: option B (always-on wake detector in CLK-BUS), among A (integration rule only),
B and C (fully asynchronous wake).

## 1. Problem

| Item | Evidence |
|---|---|
| A UTMI+ PHY may stop CLK while SuspendM is low and restarts it only after SuspendM is negated: first CLK transition no later than 5.6 ms after SuspendM negation | UTMI 1.05 p. 21 and p. 48 ("internal oscillator and clocks of the transceiver are assumed to be powered down"); USB3500 DS00002103A Table 4-2 TSTART 2.25 to 3.5 ms, p. 29 |
| The link must negate SuspendM without the PHY clock: "SuspendM is combinatorially negated at time T0 by the SIE" when reset arrives during suspend | UTMI 1.05 p. 48 (also USB3500 p. 32 to 33) |
| In this IP every wake decision of a UTMI+ build is made by `m_usb2_spd` in CLK-PHY (`p_ff_fsm_dv`, `p_ff_fsm_hp`, `reg_suspend_n`); `m_usb2_phyif_utmi` passes `o_utmi_suspend_n = i_suspend_n` | `rtl/m_usb2_spd.sv` lines 332 to 339 and 905 to 913; `rtl/m_usb2_phyif_utmi.sv` line 153 |
| Result: a suspended device never sees the host resume K or a reset SE0; a suspended host never acts on `u2_hport.port_res` (the register command waits in the CLK-BUS to CLK-PHY FIFO) | `t_dir_clkstop` FAIL r2108 (device) and r2109 (host), harness clock-stop model `PCLKA` |
| The ULPI builds already solve the same problem with `m_usb2_ulpilp` in CLK-BUS (DEC-022, CDC-007, SVA-014) | `rtl/m_usb2_ulpilp.sv` |

## 2. Proposed design (option B)

### 2.1 New module `m_usb2_utmilp` (CLK-BUS, always on, reset `i_rst_n_bus`)

The UTMI+ twin of `m_usb2_ulpilp`, instantiated only in the UTMI+ branch of `m_usb2_core`.

| Port | Dir | Width | Domain | Meaning |
|---|---|---|---|---|
| `i_clk_bus`, `i_rst_n_bus` | in | 1 | CLK-BUS | clock and reset of the always-on logic |
| `i_utmi_linestate` | in | 2 | asynchronous | raw LineState pins (not the PIPE-registered copy, which stops with CLK-PHY) |
| `i_suspend_n_phy` | in | 1 | CLK-PHY flop | `reg_suspend_n` of `m_usb2_spd` (registered SuspendM request of the speed engine) |
| `i_wake_req` | in | 1 | CLK-BUS | existing `w_wake_csr`: device remote wake (`rmt_wake` and `rmt_wake_en`) or host `port_res` |
| `o_wake` | out | 1 | CLK-BUS flop | SuspendM release request, ORed into `o_utmi_suspend_n` |

Behaviour:

| Step | Condition (all signals in CLK-BUS after the library synchronizers) | Action |
|---|---|---|
| Arm | synchronized `i_suspend_n_phy` falls (the engine entered suspend or L1) | wait `LPARA_UTMILP_SETTLE` cycles, then store the synchronized LineState as the idle value (J of the port speed: 01b for full or high speed, 10b for low speed, so no speed information is needed) |
| Line wake | armed, and the synchronized LineState differs from the stored idle value for `LPARA_UTMILP_FLT` consecutive cycles (K = resume or remote wake, SE0 = reset or disconnect) | set `o_wake` |
| Software wake | armed, `i_wake_req` = 1, no software wake yet in this suspend period (`reg_woke`, as in `m_usb2_ulpilp`) | set `o_wake` |
| Hand-off | `o_wake` = 1 and the synchronized `i_suspend_n_phy` = 1 (CLK-PHY runs and the engine has left suspend) | clear `o_wake`; the engine now drives SuspendM alone |
| Spurious wake | `o_wake` = 1 from a line wake, the engine is still suspended and the line is back at the idle value for `LPARA_UTMILP_FLT` cycles | clear `o_wake` and re-arm: SuspendM falls again and the PHY may stop its clock |
| Not suspended | synchronized `i_suspend_n_phy` = 1 | disarmed, `o_wake` = 0 |

Pin: `o_utmi_suspend_n = i_suspend_n | i_wake_aon` in `m_usb2_phyif_utmi` (new input `i_wake_aon`), as `o_ulpi_stp = reg_stp | i_stp_lp` in the ULPI adapter.
The OR of two flops cannot glitch, because `o_wake` falls only while the CLK-PHY flop is already 1 (hand-off) or while both requests are meant to be low (spurious wake). This is checked by the new assertion SVA-017.

Proposed constants (Q4): `LPARA_UTMILP_FLT = 4` and `LPARA_UTMILP_SETTLE = 4` CLK-BUS cycles. Worst-case added delay at the slowest CLK-BUS (30 MHz, section 7.1): 2 synchronizer + 4 filter + 1 output cycles = about 0.23 us. That is small next to the 5.6 ms PHY start time, but see the timing note in 3.2.

Size estimate (INFERENCE, before synthesis): 2 synchronizers of 2 and 1 bits (library `m_vlsit_afifo_sync`, R-032), 2-bit idle register, 3-bit filter counter, 3-bit settle counter, 3 state flags: about 18 flops.

### 2.2 What happens after the wake (no change needed in the device path)

When SuspendM rises, the PHY restarts CLK. `m_usb2_spd` is still in `DV_SUSP` with its state intact, sees the K (resume, at least 20 ms) or the SE0 (reset, at least 10 ms) on LineState, and leaves suspend by the existing transitions (`DV_RESM`, `DV_RST`). The register command of a host `port_res` drains from the CLK-BUS to CLK-PHY FIFO and starts `HP_RESM` by the existing `w_edge_pres`.

## 3. Related findings that the plan must decide (found while reading the RTL for this plan)

### 3.1 G-1: a suspended host port ignores the line (pre-existing, independent of the clock)

`ENUM_ST_HP_SUSP` leaves only on `w_edge_pres` (`rtl/m_usb2_spd.sv` lines 468 to 471). A K from a device doing remote wakeup (REQ-FUNC-019 on the device side, USB 2.0 7.1.7.7) and the SE0 of a disconnect during suspend are not detected, so:
- with the clock running: the remote wake is lost, no event reaches software, and the disconnect is not reported until the port is resumed;
- with option B alone: the line change wakes the PHY, the engine does nothing, the K ends, and the PHY goes back to suspend, so the result is the same.

No test covers host-side remote wakeup (`gen_host_susp_res.py`, `gen_host_l1.py` drive the resume from software only).

### 3.2 G-2: device reset from suspend may miss TUCHEND with a slow PHY (pre-existing)

The device chirp K lasts 1.6 ms (DEC-009, `LPARA_T_CHIRPK`). UTMI 1.05 allows the PHY 5.6 ms to restart CLK after SuspendM negation, and USB 2.0 requires the device chirp to end no later than 7.0 ms after the reset start (TUCHEND, UTMI 1.05 p. 49): 5.6 + 1.6 = 7.2 ms > 7.0 ms. UTMI 1.05 p. 48 sizes the example with a 1.0 ms chirp. With USB3500 (TSTART at most 3.5 ms) the total is 5.1 ms, which passes; with a PHY that uses the full 5.6 ms it fails. The 0.23 us added by option B does not change this conclusion.

## 4. Decisions needed

| ID | Question | Options | Recommendation and reason |
|---|---|---|---|
| Q1 | Wake output to the SoC power controller (option D) | A. none now; B. add `o_wake_irq` (CLK-BUS level, "line or software wake while suspended") for a later CLK-BUS gating | **A**: spec 7.4 keeps CLK-BUS running, ASM-016 leaves power gating to the SoC; B can be added later without touching the wake logic |
| Q2 | G-1 host suspended port and line events | A. hardware: K in `HP_SUSP` starts `HP_RESM` (the host drives resume for 20 ms, then `evt_resume`); SE0 longer than 2.5 us gives `HP_OFF` and `evt_disc`; B. event only: a new `irq_raw` bit "remote wake detected", software sets `port_res`; C. out of scope (spec note only) | **A**: the root port answers within the 1 ms that a hub has (USB 2.0 7.1.7.7, TURSM) with no software latency, as EHCI ports do; no CSR change. B needs a workbook change and depends on interrupt latency. C leaves remote wakeup unusable on the host side |
| Q3 | G-2 device chirp length | A. `LPARA_T_CHIRPK` 1.6 ms to 1.2 ms in every case (TUCH at least 1.0 ms, 0.2 ms margin; 5.6 + 1.2 = 6.8 ms); B. 1.2 ms only for a reset that starts in suspend; C. keep 1.6 ms and add the integration rule "PHY clock start at most 5.4 ms" | **A**: one value, no new state, compliant with any UTMI+ PHY. B adds a state for no gain. C excludes compliant PHYs |
| Q4 | Filter and settle lengths | A. fixed `LPARA_` 4 and 4 CLK-BUS cycles; B. a new `PARA_` | **A**: the speed engine filters again after the clock restarts (reset needs 2.5 us of SE0), so this filter only rejects glitches; a parameter adds a configuration with no use case (R-045) |

## 5. File-by-file changes (after approval)

| File | Change |
|---|---|
| `rtl/m_usb2_utmilp.sv` (new) | module of 2.1, header with DEC-049, CDC-008, BUG-052 |
| `rtl/m_usb2_phyif_utmi.sv` | input `i_wake_aon`; `o_utmi_suspend_n = i_suspend_n \| i_wake_aon`; header |
| `rtl/m_usb2_core.sv` | UTMI+ branch: instance `u_utmilp` (raw `i_utmi_linestate`, `reg_suspend_n` through a new output `o_suspend_n_reg` of `m_usb2_spd`, `w_wake_csr`); connect `i_wake_aon`. `o_suspend_n` of `m_usb2_spd` is combinational outside `PARA_USB2_PIPE_MODE` (line 923), and a synchronizer source must be a flop (BUG-045, `check_sync_src.py`), so the detector reads `reg_suspend_n` |
| `rtl/m_usb2_spd.sv` | new output `o_suspend_n_reg` (= `reg_suspend_n`); Q2-A: `HP_SUSP` exits (filtered K to `HP_RESM`, SE0 longer than 2.5 us to `HP_OFF`); Q3-A: `LPARA_T_CHIRPK` 1200 us; header |
| `rtl/filelist.f`, verification filelists and `env/scripts/build.py` source lists | add `m_usb2_utmilp.sv` |
| `sdc/usb2_clocks.sdc` | false path to the LineState and SuspendM synchronizers of `u_utmilp`; `o_utmi_suspend_n` output from a CLK-BUS flop (same treatment as `o_ulpi_stp`, CDC-007); `check_sdc_objects.py` patterns |
| No CSR change | Q2-A uses existing events; Q2-B would need the workbook and the a8fb7d4 generator flow |

## 6. Specification updates (detailed, as for DEC-048)

| Section | Update |
|---|---|
| 5 (module table, hierarchy, block diagram) | new block `m_usb2_utmilp`, always on in CLK-BUS; draw.io diagram and SVG regenerated |
| 6.3 | SuspendM paragraph: released by the speed engine or by the always-on wake detector; truth table of 2.1 |
| 7.4 | clock-stop sequence for UTMI+ (wake detector, hand-off, spurious wake), same level of detail as the ULPI paragraph |
| 9 (CDC table) | CDC-008: asynchronous LineState and CLK-PHY SuspendM request to CLK-BUS; CLK-BUS wake flop to the `o_utmi_suspend_n` pin |
| 4 (requirements) | REQ-IF-015: a UTMI+ build shall negate SuspendM on a line change or a software wake while CLK-PHY is stopped (UTMI 1.05 p. 48); Q2-A: host remote-wake and disconnect rows in REQ-FUNC-020 / REQ-FUNC-012; Q3-A: REQ-FUNC-016 chirp length |
| 10 (timing, waveforms) | new waveform: device resume and reset from suspend with CLK-PHY stopped (SuspendM, CLK-PHY, LineState, `o_wake`); new waveform: host remote wake (Q2-A); DEC-009 chirp value |
| 20 | DEC-049 (this design and Q1 to Q4 answers), BUG-052 (FND-015 defect record), SVA-017, TEST-039; FND-015 closed; DEC-009 amended |
| Traceability | REQ-IF-015 and the changed requirements to `m_usb2_utmilp`, `m_usb2_spd`, TEST-039 |

`vlsit_spec_tool.py check` must pass after the edit.

## 7. Verification plan

| Item | What it proves |
|---|---|
| `t_dir_clkstop` (dev, host) moved from the "open" tier into the regression; checkpoints DCS-DSUSP, DCS-DWAKE, DCS-DRES, DCS-HSUSP, DCS-HWAKE, DCS-HRESK, DCS-HSOF already written | device resume and host `port_res` with CLK-PHY stopped |
| New scenarios in `gen_dir_clkstop.py`: reset from suspend with the clock stopped (chirp ends within 7.0 ms with the model's clock restart set to 5.6 ms); spurious K shorter than the filter (no wake, clock stays stopped); K longer than the filter that ends before the engine reacts (wake, then back to suspend) | hand-off, spurious-wake path, G-2 timing |
| Q2-A: new host scenarios: device remote wake K while the port is suspended (clock running and clock stopped), disconnect during suspend | G-1 |
| Assertion SVA-017 `a_susp_handoff` in the UTMI+ testbenches (regenerated with `gen_axis_tb.py`): `o_wake` falls only when the synchronized engine request is 1 or after a spurious wake, and `o_utmi_suspend_n` has no pulse shorter than one CLK-BUS cycle | glitch-free hand-off |
| Mutants: M35 wake detector output tied to 0; M36 filter removed (`LPARA_UTMILP_FLT` = 0); M37 hand-off clears `o_wake` without waiting for the engine; M38 (Q2-A) `HP_SUSP` K exit removed; M39 (Q3-A) chirp back to 1.6 ms | each check kills its fault |
| Rule check, lint of the four tops, `t_static_lint_classes`, `check_cdc_struct.py` and `check_sync_src.py` (new synchronizers use the library cell), `check_sdc_objects.py` | rule, CDC structure and SDC binding |
| Full regression (one job at a time, R-277), header_check, testcase review, report, vplan, 10 priority waveforms | no regression elsewhere |

Harness gap to close first: the wait operations of the interpreter (`WP`, `WSOF`, polls) count CLK-PHY cycles or bus accesses, which do not measure time while the clock is stopped, and no wait in nanoseconds exists (`env/tb/tb_usb2_utmi_axim.sv`). Add one operation `WN <ns>` to the UTMI+ testbenches (and the generated variants) before writing the spurious-K scenario.

## 8. Risks and limits

- The ULPI path is not changed. Its device-side wake on a host resume relies on the PHY leaving low power by itself (DEC-004, `m_usb2_ulpilp` uses only `dir`), and the ULPI model does not stop the clock in that case; that is outside this plan and stays as it is.
- CLK-BUS must run during suspend (spec 7.4 already states it). If the SoC later gates CLK-BUS, Q1-B or option C is needed.
- Q3-A changes a timing that every high-speed device test checks. The expected values in the scenarios (DBR-CHIRP windows) change with it; that is a planned change, not a weakened check.
- Option C (fully asynchronous) stays rejected: no glitch filter, a combinational pin-to-pin path through the PHY and harder STA, CDC and DFT sign-off.

## 9. Rollback

Before the first edit, copies of every changed file go to `archive/rtl_backups/before_utmi_wake/`, as for DEC-048.

## 10. Approval

Please answer Q1 to Q4 (or "recommended"). After approval: RTL, rule check and lint, specification, verification items of section 7, full regression, mutation, report. Nothing is committed unless you ask.
