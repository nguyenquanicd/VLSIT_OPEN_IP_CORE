# TI TUSB1210 (ULPI PHY): facts used

Source: TI TUSB1210 data sheet SLLSE09J (November 2009, revised July 2021), https://ti.com/lit/pdf/sllse09 (summary of facts;
the data sheet is not reproduced). Used for section 14.5 of the specification.

| Topic | Fact | Section |
|---|---|---|
| Interface | 12-pin ULPI SDR, 1.8 V I/O (VDDIO), input clock and output clock modes | 1, 7.1 |
| Clock | output clock mode: square-wave reference on REFCLK (3.0 V to 3.6 V), 19.2 MHz with CFG at GND or 26 MHz with CFG at VDDIO; CLOCK becomes an output after the PHY sees REFCLK edges; no crystal | 6.13, 7.3.1.1 |
| Reset | RESETB low resets the PHY logic and tri-states the ULPI bus; at least 0.2 us, or 8 CLOCK cycles while CLOCK runs | 6.7, 7.3.1.1.5 |
| Start-up | CS to supplies OK 2.84 ms to 4.10 ms; RESETB to PLL locked and DIR falling 0.54 ms to 0.647 ms; PLL lock 300 us | Table 6-1 |
| ULPI timing, output clock mode | link-to-PHY setup 6.0 ns, hold 0.0 ns; PHY output delay 1.2 ns to 5.0 ns | 6.14 |
| Pins at power-up | STP has an internal pull-up in every mode; with the PLL on and STP high, DIR is driven high | 7.4.1 |
| Suspend | in low power mode DIR is high, DATA0/DATA1 carry LineState and DATA3 the interrupt | Table 7-2 |
| Register map | Function Control 04h, Interface Control 07h, OTG Control 0Ah (each with SET and CLR aliases), vendor registers up to 87h (above 3Fh: extended register access); product ID 1507h | 7.5 |
| Function Control | SuspendM bit 6 (set back to 1 by the PHY on low power exit), Reset bit 5, OpMode bits 4:3 with 11b reserved ("No SYNC and EOP generation feature not supported"), TermSelect bit 2, XcvrSelect bits 1:0 | 7.5.5 |
| Interface Control | AutoResume bit 4, default 1 | 7.5.8 |
| OTG Control | UseExternalVbusIndicator bit 7, DrvVbusExternal bit 6, DrvVbus bit 5, ChrgVbus 4, DischrgVbus 3, DmPulldown 2 and DpPulldown 1 (default 1), IdPullup 0; the CPEN pin is driven only when DrvVbus and DrvVbusExternal are both 1 | 7.5.11 |
| VBUS | no internal VBUS supply; CPEN controls an external 5 V switch; VBUS pin protected from -2 V to 20 V; no over-current input pin | 1, 5, 7.5.11 |

Short quotation (7.5.11): "Both DRVVBUS and DRVVBUSEXTERNAL bits must be set to 1 in order to to set Pin17 (CPEN)."
