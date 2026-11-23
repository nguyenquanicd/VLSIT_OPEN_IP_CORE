# DVP Controller RTL Generation Report

**Date:** 2026-11-22  
**Author:** Nguyen Quan and Codex  
**Top:** `m_dvp_controller`  
**Specification:** `VLSIT_DVP_CONTROLLER_HDS.md`, versioned in this package.

## Generated implementation

Generated 10 DVP RTL modules plus the two CSR-generator modules. The top integrates APB4 control/status and FIFO_DATA access, continuous-PCLK capture through a dual-clock Gray FIFO, gated-valid-pixel capture through a two-stage VSYNC/toggle synchronizer and APB-clocked FIFO, mode-safe write masking, FIFO occupancy and overflow reporting, timeout-on-empty, and the watermark-based DMA REQ/ACK state machine.

The gated path samples the selected PCLK edge into a held-data/toggle pair. It requires a VSYNC pulse of at least four APB cycles before the first pixel and at least four APB cycles between sampled pixels, plus the STA/SDC setup/hold and bundled-data margin in the HDS. The default profile is 8-bit, rising PCLK, active-high VSYNC/HREF, with FIFO depth 8. Width, edge, qualifier polarity, FIFO depth and FIFO_DATA address are elaboration parameters. `PCLK_MODE` is CSR `DVP_CTRL[1]` and is ignored on writes while capture is enabled or the source/FIFO is not safe to switch.

The gated FIFO uses the shared synchronous FIFO. The continuous FIFO uses DVP-local read/occupancy RTL and shared AFIFO write, memory, synchronizer, reset, tie, and event-sync helpers. Shared source files were not modified.

## Validation evidence

- VLSIT RTL rule checker: PASS, 12 files, 0 errors, 21 warnings.
- Verilator: PASS, 26 files, 0 errors, 24 warnings.
- Slang: PASS, 26 files, 0 errors, 2 warnings.
- Parameter elaboration lint: PASS for 8-, 10-, and 12-bit profiles at rising and falling sample edges.
- HDS validation: PASS, 22 sections, 0 errors; gap scan reports 0 blocking gaps and 15 informational integration items.
- CSR JSON validation: PASS, 6 registers, 0 warnings.
- WaveDrom asset checksum: READY; all 18 WaveJSON files pass lint.

The remaining warnings are documented in `../../verification/README.md`. The VLSIT checker warnings are generated-CSR comment/magic-number notices and advisory hierarchy warnings for modules that intentionally combine logic with instances. Lint warnings are defensive open underflow/readback pins, common reset/synchronizer model coding, unused generated protection bits, and unused common-FIFO arithmetic bits.

## Verification boundary

No behavioral testbench or simulation regression was executed in this RTL-generation pass. The TEST identifiers and waveforms in the HDS are verification plans/collateral, not claims of simulation. Synthesis, CDC/RDC signoff, STA, DFT and sensor/SoC integration remain outstanding because they require the target library, clock constraints, sensor timing profile and workload selected by the integrator.
