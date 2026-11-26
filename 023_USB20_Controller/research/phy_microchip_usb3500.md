# Microchip USB3500 (UTMI+ PHY): facts used

Source: Microchip USB3500 data sheet DS00002103A, https://ww1.microchip.com/downloads/en/DeviceDoc/00002103A.pdf (summary of
facts; the data sheet is not reproduced).

| Topic | Fact | Section |
|---|---|---|
| Interface | UTMI+ (stand-alone host, device or OTG PHY), 56-pin QFN | 1 |
| OpMode pins | 00b normal, 01b non-driving (all terminations removed), 10b disable bit stuffing and NRZI, 11b reserved | Table 2-1 |
| OpMode use | OpMode changes only while the transmitter and receiver are quiescent (test mode entry, device resume); with 10b the SYNC and EOP patterns are not sent | 6.2 |
| Termination table | Table 5-1 "DP/DM termination vs. signaling mode": host chirp, host high-speed, host full-speed, host HS/FS suspend and resume, host low-speed rows and their resume, host Test_J/Test_K, peripheral rows; the same rows as ULPI 1.1 Table 40 (see [phy_compat_sources.md](phy_compat_sources.md)) | 5.4.2 |
| Resistors | two 1.5 kohm pull-ups (D+, D-), two 15 kohm pull-downs, 45 ohm high-speed terminations, all integrated and set by the operating mode | 5.4.2 |
| SE0 handling | full speed: idle is J, SE0 longer than 2.5 us is a reset; high speed: idle is SE0, so a high-speed device decides between suspend and reset after 3 ms of idle | 6.4 |
| Interface timing | setup 5 ns and hold 0 ns of TXVALID, OPMODE, XCVRSELECT, TERMSELECT and DATA to CLKOUT | Table 4-6 |

Short quotation (Table 2-1, OPMODE): "3: Reserved".
