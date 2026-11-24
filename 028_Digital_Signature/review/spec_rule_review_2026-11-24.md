# Rule review of VLSIT_DIGITAL_SIGNATURE_HDS.md against the rules of vlsit-asic-ip-microspec

Date: 2026-11-24. Specification: `spec/VLSIT_DIGITAL_SIGNATURE_HDS.md`. Rules: `rule.md` of the skill, R-001 to R-074.
Result of `vlsit_spec_tool.py check`: `PASS: 0 error(s), 22 section(s)`. That script covers only part of the rules; the other rules were inspected by reading the specification and the files, as stated per rule. Nothing was simulated, no RTL exists.

## 1. Rules that failed or are only partly met

| Rule | Finding | What would fix it |
|---|---|---|
| R-007 | `verify` of the converted standards reports `OK` for RFC 8032, RFC 6979, FIPS 204, FIPS 205, SP 800-186, SEC 2 and SP 800-90A Rev. 1. It reports `CHECK` (word count differs by more than 5 percent on some pages) for FIPS 186-5 (pages 30, 54, 66), FIPS 180-4 (pages 8, 36), FIPS 202 (one page) and SP 800-208 (11 pages). | Compare those pages with the PDF before quoting them; no wording of these pages is used in the specification. |
| R-006 | Closed in part on 2026-11-24: section 11.4 was matched against `vlsit_apb_amba_apb_ihi0024d.md` sections 3.2, 3.4 and 3.5; two differences between the standard and the generated CSR are now stated in the specification: sparse writes with byte strobes are rejected (DEC-024) and `o_apb_pslverr` keeps its last value outside the last transfer cycle. Statements about the generator timing (one wait state) remain taken from the generator reference, not from the Arm file. | Run the CSR generator and a simulation to confirm the generator timing. |

Items that were open in the first version of this review and are now closed (2026-11-24, at the request of the user):

- **R-018, R-020, R-027 (block diagram):** the user chose to omit two secondary connections (DEC-022); the layout search found a placement with the stubs of AXI and DMA on the right side, and the last `vlsit_spec_diagram.py build` now prints `PASS: drawn, validated and rendered` with 0 findings (54 library cells, 14 crossings).
- **R-017 (waveform coverage):** WF-015 (APB4 write and read), WF-016 (APB4 non-secure access error), WF-017 (DMA request and acknowledge) and WF-018 (key input timeout) were added; each external interface now has a success and an error waveform. Total 18 waveforms; `vlsit_waveform_svg.py check` is OK for all 18.
- **R-010, R-011:** the user chose not to search public reference IP (DEC-023); no public IP is used as a design reference, so the rules do not apply.

## 2. Rules checked by a script (this run)

| Rules | Check | Result |
|---|---|---|
| R-013, R-014, R-015, R-017 (image exists), R-025, R-041, R-046 to R-048, R-054, R-055, R-024 (plan and files) | `vlsit_spec_tool.py check` | PASS, 0 errors |
| R-016, R-030, R-032 to R-034, R-037 to R-040, R-051, R-053, R-067 | `vlsit_csr_tool.py validate dsig_regs.json --auto-reserved` | PASS, 41 registers, 0 warnings |
| R-035 | `vlsit_csr_tool.py fill` produced the workbook | Done by the tool; the workbook was not opened in a spreadsheet program, so the look was not inspected |
| R-057, R-058, R-074 | `vlsit_waveform_svg.py check` on the 18 WaveJSON files | 18 of 18 OK, every label fits; sources `figures/wf_0*.json` exist beside the SVGs |
| R-068 to R-071 | `vlsit_fsm_diagram.py check` and `build` | PASS; layout `flow-lr-snake-4-g180`, 17 crossings, 0 label conflicts, text fit PASS, distribution PASS (4 x-centers, 7 y-centers) |
| R-018, R-019, R-020, R-027 | `vlsit_spec_diagram.py build` and `vlsit_library_symbols.py validate` | Block diagram: build PASS, 0 findings, 54 library cells; FSM diagram: 30 library cells, PASS |
| R-029 | `vlsit_spec_diagram.py check` | PASS: diagram interfaces and table agree |
| R-042 | Name `VLSIT_DIGITAL_SIGNATURE_HDS.md` | Matches the pattern |

## 3. Rules checked by inspection

| Rule | Evidence |
|---|---|
| R-001 | This file lists what failed and what was not checked. |
| R-002 | Only files created in this run were overwritten (the CSR workbook, regenerated with `--force`); 019 was not changed. |
| R-003, R-004, R-005 | Questions carried options, examples and an open choice; answers of "you decide" and extrapolations are assumptions ASM-001 to ASM-014 in section 20; the specification is in English. Some message bundles had sub-questions inside a question. |
| R-008, R-009 | Every download (RFC 8032, FIPS 180-4, 186-5, 202, 204, 205, SP 800-186, 800-208, 800-90A Rev. 1, SEC 2, RFC 6979) was approved by the user in chat before download; only Markdown was stored; the skill folder is not a git repository, so the `.gitignore` condition could not be checked. |
| R-012 | No reference code or text is copied; the research documents and standards are cited. |
| R-018 (two tabs), R-028 | The block diagram `.drawio` is built with `BLOCK_DIAGRAM` and `BLOCK_INFORMATION`; only the SVG of `BLOCK_DIAGRAM` is in section 5.2. |
| R-021, R-022, R-023 | Ad hoc generator scripts for the CSR JSON, the diagram and the waveforms were written in the IP folder without a prior proposal; only `openpyxl` and `PyMuPDF` were used in the skill scripts. |
| R-026, R-056 | The naming rule was asked and chosen (answer 1A); no forbidden name was reported by the checker. |
| R-031, R-049, R-050 | Section 11.3 and 11.4 state the generator behavior including `rwi`, `w1c`, `wo`; the set-only lock is decided as DEC-016 (confirmed by the user); no fixed wait-state count is promised for the asynchronous build. |
| R-043, R-060 to R-066 | Section 11.2 has a Mermaid flowchart with 17 nodes (S01 to S07, S10 to S19), each with an ID and `[M]` or `[O]`, and a table with exactly the six required columns and 17 rows; optional steps name their condition; register names come from the workbook. |
| R-044 | The Markdown is the only source; figures use relative links under `figures/`; the specification contains no equation. |
| R-045 | No DOCX or PDF was created, because the user declined the export. |
| R-073 | Every block and FSM figure is followed by a fenced `json` block; every one of the 18 waveform images in section 10.3.1 is followed by a fenced `wavedrom` block that equals its `.json` source. |
| R-024 | The plan was proposed with the question of the options A to D, then drawn after the user answered "follow the proposed order" (accepting the recommended option A); the four waveforms WF-015 to WF-018 were added after the user answered "thêm WF-015 đến WF-018" explicitly. |

## 4. Not checked

Simulation, synthesis, timing, CDC, lint of RTL (none exists); the generated CSR RTL; the visual quality of the workbook; the correctness of every algorithm detail against the standards beyond the clauses cited; the numbers of section 13 (none exists); the safety and certification aspects.
