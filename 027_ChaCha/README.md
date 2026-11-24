# ChaCha20-Poly1305 IP

## Description and status

This folder contains architecture and feature research for a ChaCha20-Poly1305 authenticated-encryption block.

- Research and source material are under research/.
- The draft hardware design specification and CSR artifacts are under spec/.
- The editable architecture diagram is spec/figures/chacha20_poly1305_architecture.drawio.
- Synthesizable RTL is in rtl/ (top m_chacha_top, 27 modules, register block generated from the workbook in rtl/csr/, master filelist rtl/filelist.f). It passes the VLSIT rule checker and Verilator lint on several parameter configurations; it was exercised only by scratch simulations (RFC 8439 vectors, directed error and protocol cases), no verification environment exists. REQ-PERF-001 uses the relaxed formula of HDS section 13.2 (DEC-035): measured by scratch simulation, all three configurations meet it, CFG-HP at the limit after DEC-037. Three optional pipeline parameters (PARA_PIPE_CHACHA, PARA_PIPE_POLY, PARA_PIPE_IO, default 0, DEC-036) cut the longest paths; see review/pipeline_evaluation_2026-11-24.md.
- verification/models/ holds an RFC 8439 reference model (chacha20poly1305_ref.py, passes the RFC vectors) and a formula model of the message cycle counts (chacha_cycle_model.py); the other verification directories are structural placeholders.
- The specification was reviewed on 2026-11-24 (review/); the findings were fixed at specification level and recorded in review/closure_2026-11-24.md. The review scores describe the state before the fixes.

Do not treat the research proposal or draft HDS as implemented or verified behavior. See [spec/README.md](spec/README.md) for the key design and register artifacts.

## Standard directory map

| Directory | Purpose |
|---|---|
| README.md | IP overview and implementation status |
| LICENSE | Usage terms and retained upstream notices |
| spec/ | Draft HDS, CSR workbook/JSON, spec README, and spec/figures/ |
| spec/figures/ | Block diagrams and specification figures |
| rtl/ | Synthesizable RTL, generated register block (csr/) and sole filelist.f |
| sdc/ | Draft constraint skeleton chacha_top.sdc: every number is a Tcl variable set by the integrator, no value is measured |
| lint/ | Verilator lint log of the last run |
| cdc/, rdc/, syn/ | Flow-specific setup and evidence, currently placeholders |
| research/ | Feature research report and source manifest |
| research/vlsit_sources/ | Downloaded datasheets and scientific papers; third-party documents kept locally and excluded from version control by the root `.gitignore` (the manifest and report stay versioned) |
| verification/docs/ | Flat verification documentation and plans |
| verification/tests/ | Testcase sources and generators |
| verification/models/ | Independent reference models |
| verification/env/ | Testbench and reusable environment |
| verification/sim/ | Isolated run outputs and preserved evidence |
| review/ | Specification review report, run report and closure note |
| review/reference/ | Supporting review evidence |
| archive/ | Historical source snapshots, when present |

Verification has exactly five direct directory types: docs, tests, models, env, and sim. Keep documents flat in verification/docs/. Keep every .log outside rtl/ and in the directory for its producing flow. Empty required categories use .gitkeep markers; those markers do not imply RTL, tests, or verification evidence exist.
