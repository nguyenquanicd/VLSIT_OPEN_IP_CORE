# Generated CSR block

Do not edit these files by hand (rule R-073). Change the workbook and run `vlsit_csr_generate.py generate` again (R-074).

| Item | Value |
|---|---|
| Generator | C:\HQuan\102_MyGithub\APB-CSR-Generator\CSR_Generation.py |
| Generator commit | a8fb7d4 plus the local VLSIT_SYNTHESIS guard of the invalid-count checks (re-applied by script; the generator repository is now at a5ec92e, whose rwi priority differs, so it was not used) |
| Workbook | [Historical generation input name. Current workbook](../reference/VLSIT_USB20_CONTROLLER_CSR.xlsx) |
| Workbook SHA-256 | 57f945f0626bfb9c688c263145a62b9773bf7b06466b764b185db76c22d44cd6 |
| Sheet | CSR |
| Module | m_vlsit_csr_usb2 |
| Synchronizer module | m_vlsit_csr_sync (the generator calls it m_csr_sync; renamed for the m_vlsit_ prefix) |
| Generator version | 3.6 |
| PARA_ASYNCHRONOUS default | 0 (register clock = i_clk_apb) |
| Registers | 46 |
| Generated | 2026-11-25 (u2_hport.ext_vbus added, DEC-048) |
| Ports | 536 (checked against the workbook) |

| File | SHA-256 |
|---|---|
| m_vlsit_csr_usb2.sv | a5feb20b542c1b9f9e7c509107e1f1b9dac28eae8db00999fa2940a0d06bbf61 |
| m_vlsit_csr_sync.sv | 8c4f63018021272a597917fbf8cf718a14d1fd3aecab8a53122ece79e236531c |

Regeneration (2026-11-25): `python spec/csr/gen_csr.py` (from spec/csr) writes regs_usb2.json; `vlsit_csr_tool.py fill` writes the
workbook (then restore row 9 "Register Event Sideband" = 1 on the CSR and ASYNC_CSR sheets, which `fill` does not write);
`vlsit_csr_generate.py generate ... --generator <APB-CSR-Generator at a8fb7d4>/CSR_Generation.py`; then
`python spec/csr/csr_guard.py <generated m_vlsit_csr_usb2.sv> rtl/csr/m_vlsit_csr_usb2.sv` re-applies the VLSIT_SYNTHESIS guard
and keeps the delivered file header. With the workbook of 2026-11-21 this flow reproduced the delivered file byte for byte.
