# DVP verification evidence

All simulation and lint in this update use the modified RTL. No baseline RTL test or lint run was performed, per the user's instruction.

## Modified-RTL results

| Check | Result | Evidence |
|---|---|---|
| VLSIT RTL rule checker | PASS, 12 SystemVerilog files, 0 errors, 21 warnings | [Rule output](static/rtl_rule_modified_final.log), [Markdown findings](static/rtl_rule_modified_final.md) |
| Verilator lint | FAIL under default strict exit policy: 26 source files, 24 warnings and no RTL diagnostic errors; Verilator exits 1 because warnings are fatal | [Verilator log](lint/modified_verilator_project_final.log) |
| Slang lint | PASS, 26 source files, 0 errors, 2 warnings | [Slang log](lint/modified_slang_final_2.log) |
| Parameter elaboration | PASS for 8/10/12-bit profiles and rising/falling PCLK edges | `lint/profiles/modified_w*_edge*_final.log` |
| HDS structure | PASS, 22 sections, 0 errors | [HDS check](static/hds_check_modified_final.log) |
| HDS gap scan | 0 blocking gaps, 15 integration information items | [Gap scan](static/hds_gaps_modified_final.log) |
| CSR JSON validation | PASS, 7 registers, 0 errors/warnings | [CSR validation](static/csr_modified_final.log) |
| Generated CSR source | PASS; generator confirms both CSR RTL files match the generated source | [Generator verify](static/csr_generated_modified_final.log) |
| WaveJSON | PASS, 21 files, 0 errors/warnings | [Waveform lint](static/wavejson_modified_final.log) |
| Icarus compile in the project directory | PASS, exit code 0 | [Compile log](runs/modified_2026-11-22/iverilog_compile_project_final.log) |
| Icarus simulation in the project directory | PASS, 27 directed check groups, 2 expected empty-read PSLVERR responses | [Latest simulation log](runs/modified_2026-11-22/simulation_modified_project_final.log), [VCD](runs/modified_2026-11-22/dvp_updates.vcd) |

The simulation covers the `0xFFFF_FFFF` timeout reset, a programmable three-cycle timeout, immediate zero timeout, continuous and gated frame counting, AFIFO and SFIFO flush, flush rejection while capture is enabled, selected-FIFO occupancy clearing, sticky-overflow retention, FIFO-full overflow, and common-reset recovery. The AFIFO flush test keeps PCLK running through the reset handshake. The testbench is [tb_dvp_updates.sv](tb_dvp_updates.sv).

## Reproduce the modified-only simulation

Run from the repository root in PowerShell. Icarus Verilog is installed under `C:\Tools\oss-cad-suite` in the current environment:

```powershell
$env:PATH = 'C:\Tools\oss-cad-suite\bin;C:\Tools\oss-cad-suite\lib;' + $env:PATH
$env:IVERILOG_ROOT = 'C:\Tools\oss-cad-suite'
Set-Location 025_DVP_Controller\rtl
iverilog.exe -g2012 -s tb_dvp_updates -o ..\verification\runs\modified_2026-11-22\dvp_updates_project_final.vvp -f filelist.f ..\verification\tb_dvp_updates.sv
Set-Location ..\verification\runs\modified_2026-11-22
vvp.exe .\dvp_updates_project_final.vvp +AFIFO_MSYNC_EN=0 +RSTSYNC_MSYNC_EN=0
```

The run writes `dvp_updates.vcd` in the run directory. Open it with GTKWave to inspect the APB responses, capture clocks, flush handshakes, frame counter and FIFO status.

## Warning and sign-off notes

Verilator reports 24 warnings and zero errors, but its default strict policy returns exit code 1. Warnings include intentionally open defensive underflow/status outputs, simulation-model blocking assignments, and unused parameters/signals in shared reset, synchronizer and FIFO logic. Slang reports two same-type casts in shared simulation models and exits successfully. The VLSIT RTL rule checker reports zero errors and 21 warnings.

The tests do not constitute CDC/RDC, STA, synthesis, DFT, sensor setup/hold, or SoC workload sign-off. Those require the selected camera mode, target library, clock constraints and integration workload.
