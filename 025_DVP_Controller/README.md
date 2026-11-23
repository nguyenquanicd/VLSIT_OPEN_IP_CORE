# DVP Controller

## IP overview and status

Digital Video Port (DVP) capture controller with register, RTL, specification, and verification collateral.

**Status:** Inventory: 12 RTL source file(s), 14 specification/reference artifact(s), and 39 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

## Standard directory structure

~~~text
<IP>/
├── README.md             Overview, current status, and usage notes
├── LICENSE               Apache-2.0 pointer and author notice
├── spec/                 Detailed design specification and CSR definitions
├── figures/              Figures and diagrams referenced by the specification
├── rtl/                  Active synthesizable RTL and source filelists
├── lint/                 Lint setup and retained lint evidence
├── cdc/                  Clock-domain-crossing analysis and reports
├── rdc/                  Reset-domain-crossing analysis and reports
├── sdc/                  Synopsys Design Constraints and timing collateral
├── syn/                  Synthesis setup and retained synthesis evidence
├── verification/
│   ├── plan/             Detailed test plan extracted from the specification
│   ├── tests/            Reusable testcases and testcase generators
│   ├── models/           Independent Python/C/C++/SystemVerilog models
│   └── ...               Testbench, environment, scripts, logs, and evidence
├── review/
│   ├── reference/        Review images, source snapshots, and supporting evidence
│   └── *.md              One Markdown report per review step
├── research/             Source research and external references
├── sim/                  Isolated simulation run outputs (tool/config/run ID)
├── formal/               Optional formal-verification environment
└── archive/              Optional preserved historical/source packages
~~~

000_Common is a shared-library exception and does not use this per-IP layout. Existing self-contained simulation workspaces remain atomic under verification/sim/ where moving their internal files would invalidate recorded run inputs or relative-path assumptions. formal/ is used when a standalone formal environment can be separated safely; otherwise formal collateral remains inside that self-contained verification package.

## Tổng quan IP và trạng thái

Digital Video Port (DVP) capture controller with register, RTL, specification, and verification collateral.

**Trạng thái:** Inventory: 12 RTL source file(s), 14 specification/reference artifact(s), and 39 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

## Cấu trúc thư mục chuẩn

~~~text
<IP>/
├── README.md             Overview, current status, and usage notes
├── LICENSE               Apache-2.0 pointer and author notice
├── spec/                 Detailed design specification and CSR definitions
├── figures/              Figures and diagrams referenced by the specification
├── rtl/                  Active synthesizable RTL and source filelists
├── lint/                 Lint setup and retained lint evidence
├── cdc/                  Clock-domain-crossing analysis and reports
├── rdc/                  Reset-domain-crossing analysis and reports
├── sdc/                  Synopsys Design Constraints and timing collateral
├── syn/                  Synthesis setup and retained synthesis evidence
├── verification/
│   ├── plan/             Detailed test plan extracted from the specification
│   ├── tests/            Reusable testcases and testcase generators
│   ├── models/           Independent Python/C/C++/SystemVerilog models
│   └── ...               Testbench, environment, scripts, logs, and evidence
├── review/
│   ├── reference/        Review images, source snapshots, and supporting evidence
│   └── *.md              One Markdown report per review step
├── research/             Source research and external references
├── sim/                  Isolated simulation run outputs (tool/config/run ID)
├── formal/               Optional formal-verification environment
└── archive/              Optional preserved historical/source packages
~~~


The DVP protocol research is in [research/README.md](research/README.md). The original RTL-generation package remains in [spec/rtl_generation_2026-11-22/README.md](spec/rtl_generation_2026-11-22/README.md). The updated timeout, frame-counter, and FIFO-flush HDS/CSR package is [spec/rtl_update_2026-11-22/README.md](spec/rtl_update_2026-11-22/README.md).

The synthesizable top is `m_dvp_controller` in `rtl/`. It provides one APB4 completer for control/status and pixel reads through `FIFO_DATA`, plus batch `dma_req`/`dma_ack` sideband signals.

## Capture modes

- `DVP_CTRL.PCLK_MODE=0`: continuous PCLK sampling into a dual-clock Gray-pointer FIFO.
- `DVP_CTRL.PCLK_MODE=1`: valid-pixel gated PCLK sampling into a synchronized data/toggle bridge and APB-clocked FIFO. It requires at least four APB clock cycles between sampled pixels and a VSYNC active pulse spanning at least four APB clock cycles.
- `DVP_CTRL.FIFO_FLUSH`: write one with capture disabled and DMA reads stopped; the selected FIFO resets through its software-reset handshake, then hardware clears the bit. Keep PCLK running for a continuous-mode flush. Frame count and sticky overflow are retained.
- `DVP_FRAME_COUNT`: read-only modulo-2^32 count of accepted active VSYNC frame starts; common reset clears it, FIFO flush does not.
- `DVP_TIMEOUT` resets to `0xFFFF_FFFF` APB cycles; software may program a shorter timeout, including zero for immediate empty-read error.
- Both modes sample rising PCLK by default. Width, edge, VSYNC polarity, HREF polarity, FIFO depth and the FIFO_DATA address are elaboration parameters.
- The default FIFO depth is eight pixels. It must be a power of two and at least two. Integrators select the depth from the peak pixel arrival rate and maximum DMA service gap, then confirm it against the APB service rate and sensor timing.

## RTL and specification

- `rtl/m_dvp_controller.sv`: top-level wrapper.
- `rtl/csr/`: generated DVP CSR module and generator evidence.
- `spec/rtl_update_2026-11-22/`: updated HDS, CSR workbook/JSON, flush/frame-count waveforms, and implementation report; the original spec remains alongside it.
- `spec/rtl_generation_2026-11-22/`: original HDS, CSR workbook/JSON, figures, waveforms, and RTL generation report.
- `verification/`: static rule/lint reports, profile elaboration logs, and modified-RTL regression collateral/results.
- Common RTL dependencies are listed in `rtl/filelist.f`; common library sources are reused from `000_Common`, `001_AsyncGrayFIFO`, and `002_SyncFIFO`.

## Rule check and lint

From the repository root in PowerShell:

```powershell
python C:\Users\PC\.agents\skills\vlsit-rtl-generator\scripts\vlsit_rtl_check.py check 025_DVP_Controller\rtl
python C:\Users\PC\.agents\skills\vlsit-rtl-generator\scripts\vlsit_lint_rtl.py lint 025_DVP_Controller\rtl\filelist.f --top m_dvp_controller --tool verilator --log 025_DVP_Controller\verification\lint\verilator_final.log
```

The generated filelist compiles the DVP RTL with the referenced common FIFO, reset, tie, event-sync and SRAM model sources. Sensor timing limits and clock relationships are integration-level STA/SDC obligations; RTL intentionally does not impose a maximum PCLK or APB frequency.

See `verification/README.md` for current run commands, simulation results, and warning classification.
