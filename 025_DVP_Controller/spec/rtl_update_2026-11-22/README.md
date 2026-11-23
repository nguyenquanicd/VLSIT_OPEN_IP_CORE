# DVP Controller RTL update package

This addendum records the approved DVP RTL update from 2026-11-22. It keeps the original generation package unchanged and specifies the three approved changes: the programmable FIFO-empty timeout reset value, an accepted-frame counter, and a software flush for the selected FIFO.

## Files

- `VLSIT_DVP_CONTROLLER_HDS.md` — updated HDS v0.3, including behavior, reset/CDC sequencing, APB software operations, verification requirements and integration assumptions.
- `VLSIT_DVP_CONTROLLER_CSR.json` and `.xlsx` — CSR v1.1 source. `DVP_TIMEOUT` resets to `0xFFFF_FFFF`; `DVP_CTRL[2]` is the self-clearing FIFO flush request; `DVP_FRAME_COUNT` is read-only at `0x18`.
- `figures/waveforms/` — WaveJSON and rendered SVG for the three new behaviors: WF-019 AFIFO flush, WF-020 SFIFO flush and WF-021 frame counting. Existing DVP profile/basic waveforms are copied into this versioned package for a self-contained spec.
- [Implementation report](../../review/rtl_change_2026-11-22__rtl_ip_report.md) — the single RTL change report, with Level 2 hierarchy, approved plan, implementation metrics, verification results and remaining integration risks.

## Validation

From the repository root in PowerShell:

```powershell
python C:\Users\PC\.agents\skills\vlsit-asic-ip-microspec\scripts\vlsit_spec_tool.py check 025_DVP_Controller\spec\rtl_update_2026-11-22\VLSIT_DVP_CONTROLLER_HDS.md --naming default
python C:\Users\PC\.agents\skills\vlsit-rtl-generator\scripts\vlsit_spec_gaps.py gaps 025_DVP_Controller\spec\rtl_update_2026-11-22\VLSIT_DVP_CONTROLLER_HDS.md
python C:\Users\PC\.agents\skills\vlsit-asic-ip-microspec\scripts\vlsit_csr_tool.py validate 025_DVP_Controller\spec\rtl_update_2026-11-22\VLSIT_DVP_CONTROLLER_CSR.json
Get-ChildItem -Recurse 025_DVP_Controller\spec\rtl_update_2026-11-22\figures\waveforms -Filter *.json | ForEach-Object { python C:\Users\PC\.agents\skills\vlsit-wavedrom-waveform\scripts\vlsit_wavedrom_waveform.py lint $_.FullName }
```

Validation output is captured under `verification/static/`; modified-RTL simulation and lint evidence is under `verification/`.
