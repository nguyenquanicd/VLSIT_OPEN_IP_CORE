# Change plan: compatibility with commercial UTMI+/ULPI PHYs (TBD-017 and related)

Date: 2026-11-25. Status: PROPOSED, waiting for the designer's approval (no RTL changed yet).

## 1. Reference used

ULPI 1.1 Table 40 "DP/DM termination vs. signaling mode", as reproduced in the Microchip USB3320 data sheet DS00001792E
Table 5-1 (its Note 1: "This is the same as Table 40, Section 4.4 of the ULPI 1.1 specification"; Note 5-1: operation is not
ensured in a combination that is not defined). The Microchip USB3500 UTMI+ PHY data sheet DS00002103A Table 5-1 gives the same
rows for UTMI+. Both mark OpMode 11b as reserved / optional and not implemented (USB3320 section 6.2.4.5); so do the TI TUSB1210
(SLLSE09J 7.5.5) and the Intel UTMI 1.05 specification (OpMode 3 reserved).

Defined rows (XcvrSelect / TermSelect / OpMode / DpPulldown, DmPulldown):

| Mode | Row | Mode | Row |
|---|---|---|---|
| Host chirp | 00 / 0 / 10 / 1,1 (HS terminations on) | Peripheral chirp | 00 / 1 / 10 / 0,0 |
| Host high-speed | 00 / 0 / 00 / 1,1 (HS terminations on) | Peripheral high-speed | 00 / 0 / 00 / 0,0 |
| Host full-speed | X1 / 1 / 00 / 1,1 | Peripheral full-speed | 01 / 1 / 00 / 0,0 |
| Host HS/FS suspend | 01 / 1 / 00 / 1,1 | Peripheral HS/FS suspend | 01 / 1 / 00 / 0,0 |
| Host HS/FS resume | 01 / 1 / 10 / 1,1 | Peripheral HS/FS resume | 01 / 1 / 10 / 0,0 |
| Host low-speed, LS suspend | 10 / 1 / 00 / 1,1 | Peripheral LS (not used by the IP) | 10 / 1 / 00 / 0,0 |
| Host LS resume | 10 / 1 / 10 / 1,1 | Tri-state drivers | XX / X / 01 / X |
| Host Test_J/Test_K | 00 / 0 / 10 / 1,1 | Power-up or VBUS < VSessEnd | 01 / 0 / 00 / 1,1 |

## 2. Findings (RTL `m_usb2_spd.sv`, process `p_com_mode`, against the table)

| ID | State of the IP | Row driven now | Defined row | Effect on a real bus | Spec 6.3 |
|---|---|---|---|---|---|
| PHY-01 (TBD-017) | Host port reset SE0 (`HP_SE0`) and the rest of the reset of a full- or low-speed port (`HP_RSTW`) | 01 / 1 / 11 | none; SE0 is obtained with the HS terminations: 00 / 0 / 00 (host high-speed row, no transmit) | OpMode 11b is not implemented by common PHYs; with OpMode 11b and no transmit the line stays J (device pull-up), so no reset: no device can be enumerated | row "Host reset (SE0) and chirp" is ambiguous |
| PHY-02 | Host port suspended at high speed (`HP_SUSP`, speed HS) | 00 / 0 / 00, SuspendM 0 | 01 / 1 / 00 | the 45 ohm terminations keep the line at SE0 while the device expects J; a suspended HS device sees SE0 for more than 3 ms and resets (USB 2.0 7.1.7.6) | no host suspend row |
| PHY-03 | Host resume of a high-speed port (`HP_RESM`, speed HS) | 00 / 0 / 10 | 01 / 1 / 10 | resume K is full-speed signaling (USB 2.0 7.1.7.7); K driven by the HS transmitter into HS terminations is not the specified signal | no host resume row |
| PHY-04 | Device suspended after high-speed operation (`DV_SUSP` with reg_hs = 1, also L1) | 00 / 0 / 00, SuspendM 0 | 01 / 1 / 00 | the D+ pull-up is removed in suspend: the hub sees a disconnect (USB 2.0 7.1.7.6 requires the device to revert to full-speed terminations) | violates the spec row "Device suspend 01b / 1 / 00b, TermSelect stays FS" |
| PHY-05 | Device not connected (`DV_OFF`, soft_conn = 0) | 01 / 0 / 00 / 0,0 | tri-state 01 / 0 / 01 (non-driving, UTMI 1.05 mode 1 "soft disconnect") | combination not defined: operation not ensured | no row |
| PHY-06 | ULPI OTG Control written by the IP | DrvVbusExternal = 0 always | PHYs that switch VBUS through their CPEN pin need DrvVbusExternal = 1 with DrvVbus (TUSB1210 7.5.11) | CPEN never drives; `o_vbus_pwr_en` must be used instead | section 14.5.6 |
| PHY-07 (TBD-018) | ULPI Interface Control AutoResume | never written (PHY default) | TUSB1210 default 1; USB3320 default 0, "should be enabled for Host applications" | host resume behavior differs between PHYs; not verified | section 14.5.6 |

Why the regression did not see PHY-01 to PHY-05: the PHY models of the testbench do not derive the line state from the
termination rows, and the checks mask the mode pins in these states (device suspend: `WP` mask = SuspendM only; host suspend
and resume: no mode-pin check; host reset: the scenario itself drives SE0 after checking OpMode 11b). This is the same class
of weak oracle as INTEGRITY_HOLD and is reported in verification/docs/bugs.md when the plan is executed.

## 3. Proposed changes

RTL (`rtl/m_usb2_spd.sv`, plus parameter plumbing in `m_usb2_core.sv`, the four wrappers and `m_usb2_cfgchk.sv`):

1. PHY-01: `HP_SE0` and `HP_RSTW` (all speeds) drive 00 / 0 / 00 (host high-speed row). Remove `PARA_USB2_RST_OPMODE`
   (decision D1 below).
2. PHY-02: `HP_SUSP` drives 01 / 1 / 00 for a high- or full-speed port, 10 / 1 / 00 for a low-speed port.
3. PHY-03: `HP_RESM` drives 01 / 1 / 10 for a high- or full-speed port, 10 / 1 / 10 for a low-speed port; after the resume a
   high-speed port returns to 00 / 0 / 00 (existing `HP_EN` row).
4. PHY-04: `DV_SUSP` drives 01 / 1 / 00 for every speed; `reg_hs` stays to return to high speed after the resume.
5. PHY-05: `DV_OFF` drives the tri-state row 01 / 0 / 01 (decision D3).
6. PHY-06: decision D2.
7. PHY-07: no RTL change; verification item (TBD-018).

Verification:

1. PHY models (`tb_usb2_utmi_axim.sv` checker and `ulpi_phy_bfm.sv`): assertion `a_phy_row` that every mode combination
   on the pins (UTMI+) or written to Function Control and OTG Control (ULPI) is a defined row of Table 40 for the role;
   ULPI BFM option to reject OpMode 11b writes.
2. Line-state model: in host reset the model drives SE0 only when the HS terminations are on (00 / 0 / x) instead of the
   scenario forcing SE0; same for device suspend (J only with TermSelect 1).
3. Scenario checks with full masks: host reset row 00 / 0 / 00, host suspend 01 / 1 / 00 and resume 01 / 1 / 10, device
   suspend 01 / 1 / 00, device soft-disconnect tri-state row; new checkpoint IDs in the headers.
4. Mutants M28 to M32 re-inserting each old row; each must be killed.
5. Rebuild, full regression, run_builds, oracle audit of the changed generators, testcase review, priority waveforms.

Specification:

1. Section 6.3 table replaced by the full Table 40 row set with the IP state of each row; REQ-IF-012 cites ULPI 1.1 Table 40.
2. DEC-048 (new) records PHY-01 to PHY-05; TBD-015 superseded, TBD-017 closed; DEC-009 text corrected (host reset SE0).
3. Section 14.5 updated (host role no longer blocked; PHY-06 and PHY-07 guidance); section 14.4 and parameter table 8.
4. REF-014 (USB3320 DS00001792E), REF-015 (USB3500 DS00002103A), REF-016 (Intel UTMI 1.05) added.

Research notes for the release (`research/`): one Markdown note per document with the facts used (tables of values, section
numbers, short quotations) and the source link. The vendor data sheets themselves are copyrighted and are not copied into the
repository; the PDFs stay in `C:\HQuan\007_Document\USB\utmi_ulpi` (local).

## 4. Decisions for the designer

- D1, `PARA_USB2_RST_OPMODE`: (A, recommended) remove it, the reset row becomes fixed; (B) keep it as a legacy option that
  selects the old row for a PHY that implements OpMode 11b.
- D2, DrvVbusExternal: (A, recommended) build parameter `PARA_USB2_ULPI_EXT_VBUS` (default 0) that writes DrvVbusExternal =
  DrvVbus, so a PHY can drive its CPEN pin; (B) a new CSR bit (needs the CSR workbook and the generator); (C) no change,
  document `o_vbus_pwr_en` only.
- D3, device soft-disconnect row: (A, recommended) tri-state row (OpMode 01); (B) keep the current row.
