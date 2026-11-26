# Commercial PHY compatibility: sources and findings (2026-11-25)

Research notes behind DEC-048 and section 14.5 of the specification. The vendor documents are copyrighted; this folder keeps
only the facts used (values, table rows, section numbers, at most one short quotation per note) and the link to the original.
The PDFs themselves are not part of the release. A local copy was taken on 2026-11-25 for review (hashes below).

| Note | Document | Source | SHA-256 of the local PDF |
|---|---|---|---|
| [phy_microchip_usb3320.md](phy_microchip_usb3320.md) | Microchip USB3320 Hi-Speed USB 2.0 ULPI transceiver, DS00001792E (71 pages) | https://ww1.microchip.com/downloads/en/DeviceDoc/00001792E.pdf | 3f0404ef4097969756ad0abfc800c8731c3602e7acf274c0223c88a939cfc0db |
| [phy_microchip_usb3500.md](phy_microchip_usb3500.md) | Microchip USB3500 Hi-Speed USB host/device/OTG PHY with UTMI+ interface, DS00002103A (45 pages) | https://ww1.microchip.com/downloads/en/DeviceDoc/00002103A.pdf | 29f957f9c4b56f554a5862a3e384d4fa8d4466f66c314df00d8ca4c0e056cb3b |
| [phy_ti_tusb1210.md](phy_ti_tusb1210.md) | TI TUSB1210 Stand-Alone USB Transceiver Chip Silicon, SLLSE09J (July 2021, 72 pages) | https://ti.com/lit/pdf/sllse09 | (read from the TI copy fetched on 2026-11-25) |
| [utmi_1_05_intel.md](utmi_1_05_intel.md) | USB 2.0 Transceiver Macrocell Interface (UTMI) Specification, Version 1.05, Intel, 3/29/2001 (67 pages) | https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb2-transceiver-macrocell-interface-specifications.pdf | a17a14406f4198a13f718243c0559c6ca2fb61486a5108223b91d4210a860652 |

Not obtained: the UTMI+ Specification Revision 1.0 and the ULPI Specification Revision 1.1. The official site www.ulpi.org is
now a parked domain and the Internet Archive was offline on 2026-11-25; third-party uploads were not used. The USB3320 data
sheet states that its Table 5-1 is the same as Table 40, section 4.4, of the ULPI 1.1 specification, so the row table below is
the standard one.

Also read: the Synopsys DWC_otg Databook 5.00b (REF-011, licensed document, local copy only): its `utmi_opmode` output uses
only 00b, 01b and 10b, so a widely used commercial host and device controller works without OpMode 11b.

## Defined PHY rows (ULPI 1.1 Table 40, via USB3320 Table 5-1; the USB3500 Table 5-1 has the same rows)

XcvrSelect / TermSelect / OpMode / DpPulldown, DmPulldown. A combination that is not listed is not ensured (USB3320 Note 5-1).

| Mode | Row | Mode | Row |
|---|---|---|---|
| Tri-state drivers | XX / X / 01 / X,X | Power-up or VBUS < VSessEnd | 01 / 0 / 00 / 1,1 |
| Host chirp | 00 / 0 / 10 / 1,1 | Peripheral chirp | 00 / 1 / 10 / 0,0 |
| Host high-speed | 00 / 0 / 00 / 1,1 | Peripheral high-speed | 00 / 0 / 00 / 0,0 |
| Host full-speed | X1 / 1 / 00 / 1,1 | Peripheral full-speed | 01 / 1 / 00 / 0,0 |
| Host HS/FS suspend | 01 / 1 / 00 / 1,1 | Peripheral HS/FS suspend | 01 / 1 / 00 / 0,0 |
| Host HS/FS resume | 01 / 1 / 10 / 1,1 | Peripheral HS/FS resume | 01 / 1 / 10 / 0,0 |
| Host low-speed, LS suspend | 10 / 1 / 00 / 1,1 | Peripheral low-speed, LS suspend | 10 / 1 / 00 / 0,0 |
| Host LS resume | 10 / 1 / 10 / 1,1 | Peripheral LS resume | 10 / 1 / 10 / 0,0 |
| Host Test_J/Test_K | 00 / 0 / 10 / 1,1 | | |

The high-speed termination (45 ohm on D+ and D-) is on in the host chirp, host high-speed and host test rows and in the
peripheral high-speed row. There is no separate "reset" row: a host drives the SE0 of a port reset with a high-speed-termination
row and no transmission (the 45 ohm terminations pull the device pull-up down to about 0.1 V).

## Findings against the RTL before DEC-048

| ID | IP state | Row before | Defined row | Fix |
|---|---|---|---|---|
| PHY-01 (TBD-017) | host port reset | 01 / 1 / 11 | none (OpMode 11b optional, not implemented by USB3320, USB3500, TUSB1210) | 00 / 0 / 00 |
| PHY-02 | host suspend, high-speed port | 00 / 0 / 00 | 01 / 1 / 00 | full-speed suspend row |
| PHY-03 | host resume, high-speed port | 00 / 0 / 10 | 01 / 1 / 10 | full-speed resume row |
| PHY-04 | device suspend after high speed | 00 / 0 / 00 | 01 / 1 / 00 | full-speed suspend row |
| PHY-05 | device soft-disconnected | 01 / 0 / 00 / 0,0 | tri-state 01 | OpMode 01b |
| PHY-06 | ULPI DrvVbusExternal | always 0 | needed by PHYs that switch VBUS through their own pin | CSR field u2_hport.ext_vbus |
| PHY-07 (TBD-018) | ULPI AutoResume | not written | default 1 (TUSB1210) or 0 with "enable for host" (USB3320) | open, verification item |
