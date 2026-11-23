# DVP Controller RTL-generation specification

This versioned package records the DVP controller decisions confirmed through 2026-11-22 and the approved specification used to generate the RTL. The baseline specification remains available beside this directory.

## Contents

- `VLSIT_DVP_CONTROLLER_HDS.md` — hardware design specification, requirements, ports, architecture, timing contracts, module hierarchy, and verification plan.
- `VLSIT_DVP_CONTROLLER_CSR.json` and `.xlsx` — CSR source and generated workbook.
- `figures/` — block diagram, FSM, and 18 static SVG waveforms with WaveJSON sources. Offline interactive WaveDrom viewers are included for rising-edge and falling-edge sampling, gated-mode toggle/SFIFO timing, and safe PCLK-mode switching.
- `RTL_GENERATION_REPORT.md` — generated module inventory, rule-check and lint evidence, and known integration limits.

## Validation

Run from the repository root with Python 3:

```powershell
python C:\Users\PC\.agents\skills\vlsit-asic-ip-microspec\scripts\vlsit_spec_tool.py check 025_DVP_Controller\spec\rtl_generation_2026-11-22\VLSIT_DVP_CONTROLLER_HDS.md
python C:\Users\PC\.agents\skills\vlsit-rtl-generator\scripts\vlsit_spec_gaps.py gaps 025_DVP_Controller\spec\rtl_generation_2026-11-22\VLSIT_DVP_CONTROLLER_HDS.md
python C:\Users\PC\.agents\skills\vlsit-asic-ip-microspec\scripts\vlsit_csr_tool.py validate 025_DVP_Controller\spec\rtl_generation_2026-11-22\VLSIT_DVP_CONTROLLER_CSR.json
Get-ChildItem -Recurse 025_DVP_Controller\spec\rtl_generation_2026-11-22\figures\waveforms -Filter *.json | ForEach-Object { python C:\Users\PC\.agents\skills\vlsit-wavedrom-waveform\scripts\vlsit_wavedrom_waveform.py lint $_.FullName }
```

The remaining informational items are SoC, sensor-mode, library, DFT, and STA/SDC integration inputs. RTL and verification evidence are in sibling `rtl/` and `verification/` directories.
