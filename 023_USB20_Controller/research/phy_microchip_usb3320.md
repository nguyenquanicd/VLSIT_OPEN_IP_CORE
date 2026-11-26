# Microchip USB3320 (ULPI PHY): facts used

Source: Microchip USB3320 data sheet DS00001792E, https://ww1.microchip.com/downloads/en/DeviceDoc/00001792E.pdf (summary of
facts; the data sheet is not reproduced).

| Topic | Fact | Section |
|---|---|---|
| Interface | ULPI, 8-bit SDR link interface | 1 |
| Termination table | Table 5-1 "DP/DM termination vs. signaling mode"; Note 1 says it is the same as Table 40, section 4.4, of ULPI 1.1; Note 5-1: operation is not ensured in a combination that is not defined | 5.2.2 |
| Rows | see [phy_compat_sources.md](phy_compat_sources.md); no row uses OpMode 11b | Table 5-1 (5.2.2) |
| OpMode 11b | UTMI+ defines OpMode 11b (no SYNC and EOP generation in high speed); the data sheet calls it an option of the ULPI specification and does not implement it | 6.2.4.5 |
| AutoResume | Interface Control AutoResume bit, default 0 in this PHY; the data sheet recommends enabling it for host applications (host start-up of less than 1 ms) | 6.2.4.4 |
| Upstream hub port | not supported (Table 5-1 note 2, UTMI+ level 3 section) | 6.2.4.3 |
| Reference clock | two modes: 60 MHz ULPI clock driven into REFCLK (link-supplied clock), or the PHY generates the ULPI clock from a reference selected by REFSEL[2:0] (PHY-supplied clock, the mode this IP needs) | 5.4.1 |

Short quotation (6.2.4.5): "This is an option to the ULPI specification and not implemented in the USB3320."
