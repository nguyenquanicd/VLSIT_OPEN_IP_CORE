# Intel UTMI 1.05: facts used

Source: USB 2.0 Transceiver Macrocell Interface (UTMI) Specification, Version 1.05, Intel, 3/29/2001,
https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb2-transceiver-macrocell-interface-specifications.pdf
(summary of facts; the specification is not reproduced). UTMI 1.05 is the device-only base of UTMI+; it has no host rows.

| Topic | Fact | Section |
|---|---|---|
| OpMode | 0 normal operation, 1 non-driving, 2 disable bit stuffing and NRZI encoding, 3 reserved | 4.1 signal table (page 13) |
| Operational modes | three modes only; mode 1 tri-states the HS and FS transmitters and removes every termination (soft disconnect); mode 2 disables bit stuffing and NRZI so that chirps can be generated, without SYNC and EOP | 5.16 |
| OpMode changes | normally only while the transmitter and receiver are quiescent: OpMode is set first, then TXValid is asserted | 5.16 |
| Device resume | the device switches OpMode to "disable bit stuffing and NRZI", asserts TXValid and sends the resume data | 4.1.5 |

Use in the IP: the non-driving mode is the row of a soft-disconnected device (DEC-048 PHY-05); OpMode 3 is never driven.

Short quotation (signal table, OpMode): "3: Reserved".
