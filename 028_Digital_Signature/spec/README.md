# Specification index

Key files:

| File | Content |
|---|---|
| `VLSIT_DIGITAL_SIGNATURE_HDS.md` | Hardware design specification (22 sections), the authoritative source. |
| `VLSIT_DIGITAL_SIGNATURE_CSR.xlsx` | CSR workbook (41 registers, prefix `dsig`), built from `csr/dsig_regs.json` by `csr/gen_dsig_csr_json.py`. |
| `csr/dsig_ports.txt` | Ports of the CSR module that APB-CSR-Generator builds from the workbook. |

Figures (`figures/`): the block diagram (`block_diagram.*`, spec `dsig_diagram_spec.json`), the control FSM diagram (`dsig_ctl_fsm.*`), the 18 waveforms `wf_001` to `wf_018` (WaveJSON and SVG), and `signature_engine_architecture.drawio` (a composite research figure, not a design). Research input: `../research/digital_signature_feature_research_report.md`. The proposal for the 019 hash engine is in `../review/019_sha_eng_change_proposal.md`.
