# DVP Controller

## IP overview and status

Digital Video Port (DVP) camera capture controller with an Advanced Peripheral Bus 4 (APB4) programming/data interface, two selectable pixel-clock capture paths, first-in-first-out (FIFO) buffering, and direct-memory-access (DMA) batch request/acknowledge signals.

The normative design package is HDS v0.3 and CSR v1.1. See [spec/README.md](spec/README.md) for the key HDS, CSR workbook/JSON, block diagrams, and waveform assets. The consolidated review status is [REVIEW_STATUS_2026-11-23.md](review/REVIEW_STATUS_2026-11-23.md); older reports remain dated evidence for the revisions they reviewed.

## Directory organization

- spec/ contains the HDS, CSR sources, spec README, validation evidence, and spec/figures/.
- rtl/ contains active synthesizable RTL and the sole RTL filelist, rtl/filelist.f.
- lint/, cdc/, rdc/, sdc/, and syn/ hold flow-specific setup and evidence.
- verification/ has exactly five direct directories: docs/, tests/, models/, env/, and sim/. All verification documents and reports are flat in verification/docs/.
- verification/env/ contains the BFMs, the checker with its reference model, the testbenches, the single driver script `scripts/dvp_regress.py` and the resource budget. verification/tests/regression/ holds the test list; verification/docs/ holds the plan, architecture, qualification record, decisions and the verification report.
- verification/sim/final/ is the single retained result set (flat logs, summary, manifest). There is no top-level sim/ directory and no other run history: the verification package was consolidated into one final version on 2026-11-24.
- review/ contains Markdown review reports directly and supporting evidence in review/reference/.

No .log file belongs in rtl/. New lint logs go to lint/, specification checks to spec/validation_logs/, and simulation outputs to verification/sim/<run>/.

## Capture and software behavior

- DVP_CTRL.PCLK_MODE=0 selects continuous PCLK capture into the asynchronous FIFO.
- DVP_CTRL.PCLK_MODE=1 selects valid-pixel gated PCLK capture through the data/toggle bridge and APB-clocked FIFO. Integration must provide at least four APB cycles between sampled pixels and a VSYNC pulse lasting at least four APB cycles.
- Capture starts at the next active VSYNC after enable. Clearing capture enable stops new samples after control crosses into the sensor-clock domain and preserves queued FIFO pixels.
- FIFO full drops the new pixel and sets sticky OVERFLOW; software clears it with write-one-to-clear (W1C).
- FIFO flush is accepted only while capture is disabled and DMA reads are stopped. In continuous mode, PCLK must run while the reset handshake completes.
- DVP_FRAME_COUNT increments for each accepted active VSYNC frame start and wraps modulo 2^32. FIFO flush does not clear it.
- DVP_TIMEOUT resets to 0xFFFF_FFFF APB cycles; software can program a shorter empty-read timeout. Zero requests an immediate empty-read error.
- Pixel width, PCLK sample edge, VSYNC/HREF active levels, FIFO depth, and FIFO_DATA address are elaboration parameters. Defaults are 8-bit, rising-edge, active-high qualifiers, and FIFO depth 8. FIFO depth must be a power of two and at least 2.

## Build, lint, and verification

Run from the repository root with GNU make under MSYS2 or Git Bash:

~~~sh
make -C 025_DVP_Controller help
make -C 025_DVP_Controller lint
make -C 025_DVP_Controller spec-check
make -C 025_DVP_Controller wavejson-check
make -C 025_DVP_Controller regress RUN=<new-name>   # Verilator regression; writes verification/sim/<new-name>/, never overwrites
~~~

`regress` runs checker qualification (synthetic traffic with injected faults), parameter legality, a static scope review and the regression matrix (13 simulation tests over several widths, edges, polarities, FIFO depths and seeds, with the passive checker and the synchronizer latency models enabled). Tool paths are at the top of `verification/env/scripts/dvp_regress.py`.

Results, their limits and the open findings are in [verification/docs/verification_report.md](verification/docs/verification_report.md). Formal (13/13 tasks), mutation (43 of 44 mutants killed) and code coverage (DVP-owned: line 93.3%, branch 96.3%, toggle 76.5%) have been run; one mutant survives (M10) and the toggle target is unmet; finding F-003 (stuck flush request) was found and fixed; no closure or sign-off is claimed.
