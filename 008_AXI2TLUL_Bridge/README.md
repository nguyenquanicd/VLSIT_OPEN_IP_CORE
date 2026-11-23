# 008_AXI2TLUL_Bridge

## IP overview and status

Bridge from AXI4 transactions to the TileLink-UL (TL-UL) protocol.

**Status:** Inventory: 10 RTL source file(s), 1 specification/reference artifact(s), and 125 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

Bridge from AXI4 transactions to the TileLink-UL (TL-UL) protocol.

**Trạng thái:** Inventory: 10 RTL source file(s), 1 specification/reference artifact(s), and 125 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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


Specification of a high-performance, low-latency bridge from AMBA AXI4 (Subordinate) to OpenTitan TL-UL (host), one clock, configurable data width, all outputs from flip-flops.

| Item | File |
|---|---|
| Design specification (22 sections, REQ-xxx, 19 waveforms) | `AXI2TLUL_Bridge_Design_Specification.md` |
| Block diagram (draw.io, SVG, diagram spec) | `figures/vlsit_block_diagram.*` |
| Waveforms (WaveJSON and SVG) | `figures/wf-001` to `figures/wf-018` |
| Reference IP research log and OpenTitan source files with checksums | `research/` |

**Status:** Inventory: 10 RTL source file(s), 1 specification/reference artifact(s), and 128 verification file(s) are present. Functional, lint, clock-domain crossing, reset-domain crossing, formal, and synthesis status was not rerun or re-certified by this directory reorganization.
