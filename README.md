# VLSIT Common RTL

See the [reorganization report](REORGANIZATION_REPORT.md) for the current migration status and validation limits.

## Standard IP organization and directory rules

Each numbered directory is one IP. Keep the IP-level categories below; do not add a separate top-level `sim/` directory. `000_Common/` remains the special shared-library directory and is exempt from this IP template.

~~~text
<NNN_IP_NAME>/
├── README.md                 Overall IP description and current evidence-based status
├── LICENSE                   Usage terms and retained upstream notices
├── spec/                     Specification, CSR/register documents, and spec README
│   ├── README.md             Index of key specifications, registers, and figures
│   └── figures/              Block diagrams, waveforms, and specification figures
├── rtl/                      Active synthesizable RTL and the sole filelist.f
├── lint/                     Lint setup and retained lint evidence
├── cdc/                      Clock-domain-crossing analysis
├── rdc/                      Reset-domain-crossing analysis
├── sdc/                      Timing constraints
├── syn/                      Synthesis setup and evidence
├── research/                 Source research and external references
├── verification/             Exactly five direct directory types
│   ├── docs/                 Flat folder for plans, reports, and documentation
│   ├── tests/                Retained testcase sources and generators
│   ├── models/               Independent reference models
│   ├── env/                  Testbench, BFMs, scripts, configs, and formal setup
│   └── sim/                  Simulation outputs and preserved run archives
├── review/                   Reports in review/*.md; supporting evidence in reference/
└── archive/                  Historical source snapshots and inactive collateral
~~~

### Mandatory layout limits

- `verification/` has exactly five direct directory types: `docs`, `tests`, `models`, `env`, and `sim`. Do not add a sixth type. Keep every verification document, plan, report, and README directly in the single flat folder `verification/docs/`; do not create subfolders under `docs/` or separate `plan/`, `reports/`, `logs/`, `waveforms/`, or `formal/` directories under `verification/`. Empty required categories use a `.gitkeep` marker; the marker is structural and does not imply that testcases, models, or simulation evidence exist.
- Keep every testcase and generator. Place active testcase source under `verification/tests/`. If an old workspace is too deeply nested, preserve its complete relative tree in a readable archive under the appropriate verification category and keep the active testcase source accessible under `tests/`.
- Under `verification/`, directory depth is limited to two levels below `verification/`: `verification/<type>/<suite>/file` is allowed, but no directory may be created below `<suite>`. Keep `verification/docs/` flat. Apply a maximum of two directory levels below every other IP-level category as well; retain deeper historical trees in verified archive bundles rather than deleting them.
- All simulation material belongs under `verification/sim/`. Keep each run at `verification/sim/<run>/` or as an archive directly in `verification/sim/`; do not create a top-level IP `sim/` or a third directory level under `verification/`.
- Each IP has exactly one filelist inside the RTL tree: `rtl/filelist.f`. It must list all active synthesizable RTL sources for that IP, including profile sources. Select the elaboration top and required defines at the tool invocation. Keep editor backups and inactive historical RTL outside `rtl/` under `archive/`. Never store tool `.log` output in `rtl/`; place lint logs in `lint/` and other tool logs in the directory for the flow that produced them.
- Keep all specification diagrams, figures, and waveform assets under `spec/figures/`; do not create a top-level `figures/` directory. Each `spec/README.md` must describe key HDS/specification files, CSR/register files, and block diagrams without trying to inventory every file. Keep review evidence under `review/reference/`.

Each per-IP LICENSE includes the full Apache-2.0 text, preserves upstream source notices, and records the author's request to be contacted before tapeout at `nguyenquan.icd@gmail.com`. The contact request is not an additional Apache-2.0 condition; mandatory notification requires a separately reviewed custom license or agreement.

### IP index

| IP | Overall function |
|---|---|
| [001_AsyncGrayFIFO](001_AsyncGrayFIFO/README.md) | Asynchronous first-in, first-out (FIFO) buffer with Gray-pointer clock-domain crossing (CDC), coordinated reset, thresholds, and optional memory macro. |
| [002_SyncFIFO](002_SyncFIFO/README.md) | Synchronous FIFO with configurable depth, status thresholds, optional pointer retiming, and memory-macro support. |
| [003_AsyncAXI4Bridge](003_AsyncAXI4Bridge/README.md) | Asynchronous Advanced eXtensible Interface 4 (AXI4) bridge with independently buffered channels and configurable AXI profiles. |
| [004_CRC](004_CRC/README.md) | Collection of independent cyclic redundancy check (CRC) engines with serial, parallel, and chunked datapath alternatives. |
| [005_AsyncAPBBridge](005_AsyncAPBBridge/README.md) | Asynchronous Advanced Peripheral Bus (APB) bridge supporting two-phase or four-phase handshakes and multiple APB revisions. |
| [006_AHB2AXI_Bridge](006_AHB2AXI_Bridge/README.md) | Bridge from Advanced High-performance Bus (AHB) transactions to AXI transactions. |
| [007_AXI2APB_Bridge](007_AXI2APB_Bridge/README.md) | Bridge from an AXI4 subordinate interface to an APB4 manager interface. |
| [008_AXI2TLUL_Bridge](008_AXI2TLUL_Bridge/README.md) | Bridge from AXI4 transactions to the TileLink-UL (TL-UL) protocol. |
| [009_APB2TLUL_Bridge](009_APB2TLUL_Bridge/README.md) | Bridge from an APB4 completer interface to a TL-UL manager interface. |
| [010_Async4PhaseHandshake](010_Async4PhaseHandshake/README.md) | Four-phase asynchronous request/acknowledge handshake for safe clock-domain crossings. |
| [011_Async2PhaseHandshake](011_Async2PhaseHandshake/README.md) | Two-phase asynchronous request/acknowledge handshake for safe clock-domain crossings. |
| [012_HyperRAM_Controller](012_HyperRAM_Controller/README.md) | HyperBus/HyperRAM controller with AXI4 access, configuration registers, and verification collateral. |
| [013_AsyncGrayCodeSync](013_AsyncGrayCodeSync/README.md) | Gray-code synchronizer for transferring encoded counters across asynchronous clock domains. |
| [014_AXI4_Upsizer](014_AXI4_Upsizer/README.md) | AXI3/AXI4 data-width upsizer supporting multiple bus-width profiles. |
| [015_Timer](015_Timer/README.md) | Configurable timer IP with capture, compare, pulse-width modulation, one-pulse, APB, and direct-memory-access request/acknowledge functions. |
| [016_CAN_Controller](016_CAN_Controller/README.md) | Controller for Controller Area Network (CAN) communications, including verification and model collateral. |
| [017_QSPI_Controller](017_QSPI_Controller/README.md) | Quad Serial Peripheral Interface (QSPI) controller/target IP with design specification, register map, RTL, and historical source packages. |
| [018_MKV_Block_Cipher](018_MKV_Block_Cipher/README.md) | Block-cipher IP supporting the repository's MKV design profiles and verification collateral. |
| [019_SHA2_SHA3_Hash](019_SHA2_SHA3_Hash/README.md) | SHA-2/SHA-3 cryptographic hash engine with optional bus, register, and DMA interfaces. |
| [020_WDT](020_WDT/README.md) | Watchdog timer RTL IP and design specification. |
| [021_UART](021_UART/README.md) | Universal Asynchronous Receiver/Transmitter (UART) RTL IP with simulator-dependent verification collateral. |
| [022_APB_I2S](022_APB_I2S/README.md) | APB-controlled Inter-IC Sound (I2S) audio interface IP with register, RTL, and simulation collateral. |
| [023_USB20_Controller](023_USB20_Controller/README.md) | USB 2.0 controller supporting device/host profiles, PHY interfaces, bus integration, and preserved simulation archives. |
| [024_GPIO](024_GPIO/README.md) | General-purpose input/output (GPIO) IP with asynchronous capture, interrupts, DMA, simulation, and bounded formal collateral. |
| [025_DVP_Controller](025_DVP_Controller/README.md) | Digital Video Port (DVP) capture controller with APB4, continuous/gated PCLK capture, specification, verification, research, and review collateral. |
| [026_I2C_Controller](026_I2C_Controller/README.md) | Inter-Integrated Circuit (I2C) controller with APB control, master/slave logic, DMA crossing, RTL, and verification collateral. |
| [027_ChaCha](027_ChaCha/README.md) | ChaCha20-Poly1305 authenticated-encryption IP: feature research, draft hardware design specification and CSR workbook; synthesizable RTL (lint clean, scratch-simulated against RFC 8439 vectors); no verification environment yet. |

## Quy tắc tổ chức thư mục IP

Xem [báo cáo tổ chức lại](REORGANIZATION_REPORT.md) để biết tiến độ chuyển đổi và giới hạn kiểm tra.

Mỗi thư mục đánh số là một IP; `000_Common/` là thư mục thư viện dùng chung và được miễn cấu trúc mẫu IP. Trong mỗi IP, giữ các thư mục chức năng chuẩn: `spec` (gồm README và `spec/figures/`), `rtl`, `lint`, `cdc`, `rdc`, `sdc`, `syn`, `research`, `verification`, `review` và `archive`. Không tạo `figures/` hoặc `sim/` ở cấp IP; mọi mô phỏng nằm trong `verification/sim/`.

`verification/` chỉ có đúng năm loại thư mục trực tiếp: `docs`, `tests`, `models`, `env`, `sim`; không thêm loại thứ sáu. Mọi tài liệu, test plan, report và README verification phải nằm trực tiếp trong một thư mục phẳng `verification/docs/`, không tạo thư mục con ở đây. Loại thư mục bắt buộc nhưng chưa có nội dung dùng file `.gitkeep` để giữ cấu trúc; file đánh dấu này không khẳng định đã có testcase, model hay bằng chứng mô phỏng. Giữ testcase/generator trong `verification/tests/`. Độ sâu bên dưới `verification/` tối đa hai cấp: `verification/<type>/<suite>/file` được phép, không tạo thêm thư mục bên dưới `<suite>`. Các thư mục chức năng khác cũng tối đa hai cấp con; cây lịch sử sâu hơn phải được lưu trong archive đã kiểm tra, không xóa.

Mọi mô phỏng nằm trong `verification/sim/`; mỗi IP chỉ có một `rtl/filelist.f` liệt kê toàn bộ RTL đang hoạt động. Chọn top và define lúc gọi tool. File backup/editor và RTL lịch sử không hoạt động phải chuyển ra `archive/`. Không lưu file log `.log` trong `rtl/`; log lint đặt trong `lint/` và log của flow khác đặt trong thư mục tương ứng với flow đó. Đặt hình, sơ đồ và waveform của đặc tả trong `spec/figures/`; evidence review trong `review/reference/`.

Mỗi LICENSE của IP chứa toàn văn Apache-2.0, giữ thông báo nguồn gốc và ghi đề nghị liên hệ tác giả trước tapeout qua `nguyenquan.icd@gmail.com`. Đây không phải điều kiện bổ sung của Apache-2.0; nếu cần bắt buộc thông báo thì phải có license hoặc thỏa thuận riêng được rà soát pháp lý.


## English

This directory contains reusable ASIC RTL blocks, example cell models, and design collateral. The FIFO and CRC folders contain separate design alternatives; their modules are not combined into one system.

### Directory map

| Directory | Contents |
|---|---|
| [`000_Common`](000_Common/README.md) | Shared wrappers for reset synchronization, tie-offs, and FIFO memory macros; 52 general example cells plus 8 synchronizer-cell models and 1 SRAM model in `rtl_cells`. |
| [`001_AsyncGrayFIFO`](001_AsyncGrayFIFO/spec/AsyncGrayFIFO_Design_Specification.md) | Asynchronous FIFO for unrelated write and read clocks; Gray-pointer CDC, software-reset handshake, thresholds, and optional SRAM macro. |
| [`002_SyncFIFO`](002_SyncFIFO/spec/SyncFIFO_Design_Specification.md) | FIFO for related synchronous clocks; optional pointer retiming and SRAM macro; supports non-power-of-two depths; specification, RTL, lint, self-checking testbench and a 264-run simulation sweep. |
| [`003_AsyncAXI4Bridge`](003_AsyncAXI4Bridge/spec/AsyncAXI4Bridge_Design_Specification.md) | Asynchronous AXI4 bridge (five channels, one asynchronous FIFO each, optional user signals and AXI3): specification, RTL, verification and waveforms. |
| [`004_CRC`](004_CRC/rtl/filelist.f) | Five independent CRC implementations with different data rates, latency, and feature sets. See the comparison below. |
| [`005_AsyncAPBBridge`](005_AsyncAPBBridge/spec/AsyncAPBBridge_Design_Specification.md) | Asynchronous APB bridge (two-phase or four-phase handshake, APB4/APB5): specification, RTL, constraints, verification and waveforms. |
| [`006_AHB2AXI_Bridge`](006_AHB2AXI_Bridge/README.md) | AHB-to-AXI bridge: specification, protocol references, RTL and verification. |
| [`007_AXI2APB_Bridge`](007_AXI2APB_Bridge/README.md) | AXI4 Subordinate to APB4 Manager bridge; `rtl/` is the rule-compliant source set. The earlier `rtl/` baseline is retained for comparison. |
| [`008_AXI2TLUL_Bridge`](008_AXI2TLUL_Bridge/spec/AXI2TLUL_Bridge_Design_Specification.md) | AXI4-to-TL-UL bridge: specification, reference-IP research, RTL, lint, constraints and verification. |
| [`009_APB2TLUL_Bridge`](009_APB2TLUL_Bridge/README.md) | APB4 Completer to TL-UL Manager bridge specification, synthesizable RTL, and self-checking verification. |
| [`010_Async4PhaseHandshake`](010_Async4PhaseHandshake/spec/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md) | Four-phase asynchronous request/acknowledge handshake CDC IP and RTL. |
| [`011_Async2PhaseHandshake`](011_Async2PhaseHandshake/spec/VLSIT_ASYNC_2_PHASE_HANDSHAKE_HDS.md) | Two-phase asynchronous request/acknowledge handshake CDC IP and RTL. |
| [`012_HyperRAM_Controller`](012_HyperRAM_Controller/README.md) | AXI4 subordinate HyperRAM controller: specification, CSR workbook, controller RTL, and smoke/coverage tests. |
| [`013_AsyncGrayCodeSync`](013_AsyncGrayCodeSync/spec/VLSIT_ASYNC_GRAY_SYNC_HDS.md) | Gray-code synchronizer for asynchronous clock-domain crossings, with RTL and a self-checking testbench. |
| [`014_AXI4_Upsizer`](014_AXI4_Upsizer/README.md) | AXI4/AXI3 data-width upsizer: design specification, RTL profiles, constraints, waveforms, and verification. |
| [`015_Timer`](015_Timer/README.md) | Configurable Timer with capture, compare, PWM, one-pulse, APB and DMA request/ack functions. |
| [`016_CAN_Controller`](016_CAN_Controller/README.md) | Controller Area Network (CAN) controller and verification collateral. |
| [`017_QSPI_Controller`](017_QSPI_Controller/README.md) | SPI controller/target and controller-only Dual/Quad/QPI IP: VLSIT HDS, CSR workbook, generated RTL, diagrams, waveforms, lint and research collateral. |
| [`018_MKV_Block_Cipher`](018_MKV_Block_Cipher/README.md) | Block-cipher IP supporting the repository's MKV design profiles and verification collateral. |
| [`019_SHA2_SHA3_Hash`](019_SHA2_SHA3_Hash/spec/VLSIT_SHA2_SHA3_HASH_HDS.md) | SHA-2/SHA-3 hashing RTL with APB/AXI interfaces, CSR and DMA options, and a full regression suite. |
| [`020_WDT`](020_WDT/spec/VLSIT_WDT_HDS.md) | Watchdog timer RTL and design specification. |
| [`021_UART`](021_UART/rtl/filelist.f) | UART RTL and its simulator-specific verification flow. |
| [`022_APB_I2S`](022_APB_I2S/README.md) | APB-controlled Inter-IC Sound (I2S) audio interface IP. |
| [`023_USB20_Controller`](023_USB20_Controller/README.md) | USB 2.0 controller supporting device/host profiles, PHY interfaces, and preserved verification archives. |
| [`024_GPIO`](024_GPIO/README.md) | General-purpose input/output (GPIO) IP with interrupt, DMA, simulation, and formal collateral. |
| [`025_DVP_Controller`](025_DVP_Controller/README.md) | Digital Video Port (DVP) capture controller with APB4, two selectable capture paths, FIFO buffering, DMA requests, and a documented verification flow. |
| [`026_I2C_Controller`](026_I2C_Controller/README.md) | Inter-Integrated Circuit (I2C) controller with APB control and master/slave logic. |
| [`027_ChaCha`](027_ChaCha/README.md) | ChaCha20-Poly1305 authenticated-encryption IP: feature research, draft hardware design specification and CSR workbook; synthesizable RTL (lint clean, scratch-simulated against RFC 8439 vectors); no verification environment yet. |

The block diagram in section 5.2 of each specification is a draw.io diagram (`spec/figures/*.drawio`, VLSIT symbol library) with an SVG rendering, made by `vlsit_spec_diagram.py` of the skill `vlsit-asic-ip-microspec` from the JSON diagram spec beside it.

Use the single canonical filelist `rtl/filelist.f` in each IP. It lists active RTL profiles and shared dependencies; select the required top module and profile defines at tool invocation. CRC modules are alternatives, so choose the intended CRC module as the elaboration top.

### Run lint and regressions

From the repository root, use GNU make (MSYS2 or Git Bash on Windows):

```sh
make lint        # lint configured IPs 001–021 (not all 27 repository IPs)
make regression  # run the available self-checking regressions
make all         # run RTL rule checks, lint, and available regressions
```

The root Makefile currently includes IPs 001–021; IPs 022–026 are organized in the repository but are not yet integrated into those aggregate targets. The Makefile supplies configurable OSS CAD Suite and VLSIT RTL-rule script paths; override `PY`, `PYTHON`, `SKILL`, or `OSSCAD` for local tool installations. Regressions are included only where a testbench or runner exists. The UART flow requires Synopsys VCS; the aggregate target reports a skip when VCS is unavailable.

### Historical verification snapshot (2026-11-15)

This table records the verification status reported on 2026-11-15, before the directory reorganization. Its path names describe the layout at that time and are retained as historical evidence; use the current IP index and per-IP README files above for today's directory locations. The results below have not been rerun as part of the reorganization.

| Design | Specification and RTL | Lint and constraints | Verification |
|---|---|---|---|
| `000_Common` | wrappers, cell models, `cell_tests`, `lib_tests` | - | tests of the cells and wrappers |
| `001_AsyncGrayFIFO` | specification, RTL, lint logs, waveforms | - | no verification folder |
| `002_SyncFIFO` | specification, RTL, lint logs, waveforms | - | `verification/`: testbench and simulation sweep |
| `003_AsyncAXI4Bridge` | specification, RTL in three profiles (18 modules), waveforms | lint logs in each profile folder | `verification/`: testbench, `simulation_report.md` |
| `004_CRC` | specification, five RTL modules | - | `tests/`, `sanity/` |
| `005_AsyncAPBBridge` | specification, RTL, waveforms | `lint/`; `sdc/` (SDC) | `verification/`, `sanity/` |
| `006_AHB2AXI_Bridge` | specification, RTL | - | `verification/` |
| `007_AXI2APB_Bridge` | specification; active RTL `rtl/` passes the VLSIT rule checker; legacy `rtl/` has four R-036 findings | - | no verification folder |
| `008_AXI2TLUL_Bridge` | specification, RTL | `lint/`; `sdc/` | `verification/` |
| `009_APB2TLUL_Bridge` | specification, RTL | - | `verification/`, `sanity/` |
| `010_Async4PhaseHandshake` | HDS, RTL and delivery/rule reports | `make lint`; rule check | no testbench |
| `011_Async2PhaseHandshake` | HDS, RTL and self-checking testbench | `make lint` | `make verify` |
| `012_HyperRAM_Controller` | refreshed controller/CSR set `rtl/` uses generator v3.3; retained `rtl/` CSR is v2.4 | `make lint`; rule check | `verification/run_smoke.sh` (x8/x16); coverage runner |
| `013_AsyncGrayCodeSync` | HDS, RTL and self-checking testbench | `make lint` | `make verify` |
| `014_AXI4_Upsizer` | specification, AXI4/AXI3 RTL profiles, waveforms | `lint/` | `verification/` |
| `015_Timer` | refreshed `rtl/` (12 files) uses generator v3.3; retained earlier RTL | `make lint`; rule check | `verification/Makefile` DMA request/ack regression |
| `017_QSPI_Controller` | VLSIT HDS, CSR workbook, generated RTL, diagrams, waveforms, research and archive | `make lint`; rule check | no simulation testbench |
| `019_SHA2_SHA3_Hash` | HDS, RTL and extensive vector/assertion/coverage collateral | `make lint` | `verification/scripts/run_all.py` |
| `020_WDT` | HDS and RTL | `make lint` | no testbench |
| `021_UART` | RTL and VCS-based verification collateral | `make lint` | requires Synopsys VCS |

### Verification review notes (2026-11-15)

All 19 IP lint targets passed. The functional regressions passed for the common cells, SyncFIFO, AsyncAPB, AXI2TLUL, APB2TLUL, the two-phase handshake, HyperRAM, Gray-code synchronizer, AXI upsizer, Timer DMA, CRC, Async AXI evidence, and SHA-2/SHA-3. The AHB2AXI regression still fails WF-003, WF-004, and WF-006. UART was skipped because Synopsys VCS is unavailable.

### Shared RTL and example cells

`000_Common/rtl_lib` contains the reusable functional wrappers:

| Module | Function |
|---|---|
| `m_vlsit_rst_sync` | Active-low reset synchronizer with asynchronous assertion and synchronous de-assertion. The selected synchronizer depth is configurable. |
| `m_vlsit_tie` | Width- and value-configurable tie-high/tie-low output. |
| `m_vlsit_afifo_cell_sync` | One-bit wrapper selecting a synchronizer cell for the asynchronous FIFO; the non-synthesis branch includes a simulation metastability model. |
| `m_vlsit_afifo_ram_macro` | Wrapper around the asynchronous FIFO's one-write/one-read SRAM macro. |
| `m_vlsit_sfifo_ram_macro` | Wrapper around the synchronous FIFO's one-write/one-read SRAM macro. |

`000_Common/rtl_cells` contains **61** synthesizable stand-in models: 52 general logic, sequential, clock, and tie cells; 8 synchronizer cells; and 1 SRAM model. These models support lint, simulation, and generic elaboration. ASIC implementation must map wrappers to the target library cells and memory macros; the example models are not a substitute for those views.

### FIFO architecture comparison

Both FIFO tops provide write/read requests, show-ahead read data, full/empty and threshold flags, overflow/underflow reporting, and a software-reset sequence. Their clock assumptions differ, so choose by clock relationship.

| Design | Clock relationship and structure | Latency | Default storage / rough area estimate | Advantages | Limits |
|---|---|---|---|---|---|
| `001_AsyncGrayFIFO/m_vlsit_afifo_top` | Independent, unrelated write/read clocks. Gray pointers cross through synchronizers; top instantiates write control, read control, and dual-clock storage. | Default pointer synchronizer is 2 stages. A new word becomes visible in the read domain after the write-pointer crossing; read storage has 1 read-clock-cycle latency and show-ahead data. Exact time varies with clock phase. | Default depth 8 × width 32 = **256 storage bits** in the RTL-array branch, plus pointer, synchronizer, reset-FSM, and flag state. **Relative estimate: medium, storage-dominated, with more control state than SyncFIFO.** SRAM macro area is library-dependent. | Supports unrelated clocks and includes a coordinated software reset. | More control and synchronizer state; default depth must be a power of two (minimum 2). Requires proper CDC constraints and library synchronizer/memory mapping for production. |
| `002_SyncFIFO/m_vlsit_sfifo_top` | Related synchronous clocks. Separate write/read control and storage; no asynchronous pointer synchronizer. `PARA_SFIFO_PTR_RETIME` optionally adds a destination-side pointer register. | Read storage latency is 1 read-clock cycle. A write into empty becomes visible after the first later read edge with `PTR_RETIME=0`, or the second with `PTR_RETIME=1`; full release follows the same 1/2-edge choice. | Default depth 8 × width 32 = **256 storage bits** in the RTL-array branch, plus pointer, optional retiming, reset-FSM, and flag state. **Relative estimate: medium, storage-dominated, with less CDC state than AsyncGrayFIFO.** SRAM macro area is library-dependent. | Lower CDC overhead; supports non-power-of-two depths; retiming trades one edge of flag latency for a shorter pointer path. | Do not use as an asynchronous FIFO. Clocks must have a known synchronous relationship. Gap-free streaming is guaranteed only for depth ≥ `4 + 2 × PTR_RETIME`. |

The 256-bit figure is the payload capacity, not total area. With the default RTL-array branch, synthesis may implement storage with registers and read-selection logic. With the macro branch, the memory compiler/library determines the macro area. The detailed specs define the legal parameter ranges, reset behavior, and flag semantics.

### CRC implementation comparison

All five modules implement an MSB-first CRC recurrence, but their interfaces and CRC profiles differ. A CRC standard match also depends on polynomial, initial value, bit order/reflection, final XOR, and exact message bits; module selection alone does not establish standard conformance. The relative area classes below compare the listed defaults only; they combine declared state and recurrence logic and are not library-mapped area.

| Module | Default configuration | Behavior and latency from accepted request | Declared state bits* | Rough area class* | Logic-size proxy | Advantages / trade-offs |
|---|---|---|---:|---|---|---|
| `m_crc_serial` | Fixed CRC width 4 | Consumes 1 input bit per enabled clock. Disabling `i_ctrl_en` clears the CRC state at the next edge; optional residue check samples an idle edge. | 5 | Extra small | One 4-bit serial recurrence per cycle; smallest CRC datapath. | Lowest logic footprint and continuous bit streaming; fixed width, one bit/cycle, synchronous active-low reset. |
| `m_crc_initial_value` | CRC 8, data 16 | Loads the upper 8 bits as initial CRC, then processes payload plus appended zeros serially. Result after **16 processing clocks**. | 29 | Small | One 8-bit recurrence per cycle plus counter/control. | Supports input-provided initial state with a small recurrence datapath; highest latency among the transaction variants. |
| `m_crc_parallel` | CRC 8, data 16 | Processes the full word combinationally and registers the result **1 clock after acceptance**. No reflection or init/final XOR options. | 33 | Medium | `DATA_W × CRC_W` = **128** unrolled recurrence bit-steps per result. | Short latency; larger combinational path than the serial/chunked variants. |
| `m_crc_parallel_crcw` | CRC 8, data 32, chunk 8 | Processes one chunk per clock; default `32/8 = 4` chunks, so result after **4 processing clocks**. | 51 | Medium | `CAL_W × CRC_W` = **64** recurrence bit-steps per processing cycle; trades cycles for a shorter path. | Middle point between area/timing and latency; requires `CAL_W = CRC_W` and data width divisible by chunk width. |
| `m_crc_parallel_full` | CRC 16, data 32 | One-cycle parallel result; supports input byte reflection, initial XOR, output reflection, and final XOR. Options are captured with the request. | 82 | Large | `DATA_W × CRC_W` = **512** unrolled recurrence bit-steps, plus option/reflection/XOR logic. | Most configurable CRC interface and one-cycle latency; largest default combinational datapath. |

\*Declared state bits are summed from the RTL register declarations at the stated defaults, before synthesis optimization. “Extra small/Small/Medium/Large” is a rough relative class for these default configurations, based on state and recurrence structure. The recurrence-step count indicates structural work in the RTL; it is not a mapped gate count.

All transaction CRC modules accept a request when `i_ctrl_en` and `o_crc_ready` are both high at the sampling edge. A request presented only while busy is ignored; holding `i_ctrl_en` high lets the module accept it when ready returns. `m_crc_serial` is a bit-stream interface rather than a ready/valid transaction interface. The serial reset is synchronous; the other four CRC resets assert asynchronously.

### Area-estimate limits

This repository does not include a target standard-cell Liberty file, memory compiler area, process corner, timing constraints, or a completed technology-mapped synthesis report. Therefore this README does **not** claim µm² or a precise NAND2-equivalent count. The tables give reproducible RTL-level proxies: FIFO payload bits, declared CRC state bits, and CRC recurrence-step counts. For implementation area, synthesize with the target library and the intended macro configuration, then report mapped cell area and memory-macro area separately.

The CRC RTL in `004_CRC` passes the VLSIT rule checker and Verilator lint (five tops, zero lint errors/warnings each). Its regression flow also passed simulation, synthesis, mutation checks, waveform evidence checks, and report generation. The CRC source README remains the behavioral reference for the converted modules; no independent approved CRC specification is present in this folder.

## Tiếng Việt

Thư mục này chứa các khối RTL ASIC dùng chung, mô hình cell ví dụ và tài liệu thiết kế. Các thư mục FIFO và CRC chứa nhiều phương án RTL độc lập; các module này không ghép thành một system duy nhất.

### Cấu trúc thư mục

| Thư mục | Nội dung |
|---|---|
| [`000_Common`](000_Common/README.md) | Wrapper dùng chung cho reset synchronizer, tie-off và FIFO memory macro; `rtl_cells` có 52 cell logic/sequential/clock/tie, 8 mô hình synchronizer và 1 mô hình SRAM. |
| [`001_AsyncGrayFIFO`](001_AsyncGrayFIFO/spec/AsyncGrayFIFO_Design_Specification.md) | FIFO bất đồng bộ cho write/read clock độc lập; CDC bằng Gray pointer, software-reset handshake, threshold và tùy chọn SRAM macro. |
| [`002_SyncFIFO`](002_SyncFIFO/spec/SyncFIFO_Design_Specification.md) | FIFO cho các clock đồng bộ có quan hệ thời gian; tùy chọn retime pointer và SRAM macro; hỗ trợ depth không phải lũy thừa của 2; có đặc tả, RTL, lint, testbench tự kiểm và bộ mô phỏng 264 lượt. |
| [`003_AsyncAXI4Bridge`](003_AsyncAXI4Bridge/spec/AsyncAXI4Bridge_Design_Specification.md) | Bridge AXI4 bất đồng bộ (năm kênh, mỗi kênh một FIFO bất đồng bộ, tùy chọn user signal và AXI3): đặc tả, RTL, verification và waveform. |
| [`004_CRC`](004_CRC/rtl/filelist.f) | Năm cách hiện thực CRC độc lập, khác nhau về tốc độ xử lý dữ liệu, latency và tính năng. Xem bảng so sánh bên dưới. |
| [`005_AsyncAPBBridge`](005_AsyncAPBBridge/spec/AsyncAPBBridge_Design_Specification.md) | Bridge APB bất đồng bộ (handshake hai pha hoặc bốn pha, APB4/APB5): đặc tả, RTL, constraint, verification và waveform. |
| [`006_AHB2AXI_Bridge`](006_AHB2AXI_Bridge/README.md) | Bridge AHB sang AXI: đặc tả, tài liệu chuẩn giao thức, RTL và verification. |
| [`007_AXI2APB_Bridge`](007_AXI2APB_Bridge/README.md) | Bridge AXI4 Subordinate sang APB4 Manager; `rtl/` là bộ RTL theo rule, `rtl/` cũ được giữ để đối chiếu. |
| [`008_AXI2TLUL_Bridge`](008_AXI2TLUL_Bridge/spec/AXI2TLUL_Bridge_Design_Specification.md) | Bridge AXI4 sang TL-UL: đặc tả, nghiên cứu IP tham khảo, RTL, lint, constraint và verification. |
| [`009_APB2TLUL_Bridge`](009_APB2TLUL_Bridge/README.md) | Đặc tả, RTL tổng hợp được và verification tự kiểm cho bridge APB4 Completer sang TL-UL Manager. |
| [`010_Async4PhaseHandshake`](010_Async4PhaseHandshake/spec/VLSIT_ASYNC_4_PHASE_HANDSHAKE_HDS.md) | IP CDC handshake bất đồng bộ request/acknowledge bốn pha và RTL. |
| [`011_Async2PhaseHandshake`](011_Async2PhaseHandshake/spec/VLSIT_ASYNC_2_PHASE_HANDSHAKE_HDS.md) | IP CDC handshake bất đồng bộ request/acknowledge hai pha và RTL. |
| [`012_HyperRAM_Controller`](012_HyperRAM_Controller/README.md) | Bộ điều khiển HyperRAM AXI4 subordinate: đặc tả, workbook CSR, RTL controller, smoke test và coverage. |
| [`013_AsyncGrayCodeSync`](013_AsyncGrayCodeSync/spec/VLSIT_ASYNC_GRAY_SYNC_HDS.md) | Bộ đồng bộ Gray-code cho CDC giữa các clock bất đồng bộ, có RTL và testbench tự kiểm. |
| [`014_AXI4_Upsizer`](014_AXI4_Upsizer/README.md) | Bộ tăng độ rộng dữ liệu AXI4/AXI3: đặc tả thiết kế, các profile RTL, constraint, waveform và verification. |
| [`015_Timer`](015_Timer/README.md) | Timer hỗ trợ capture, compare, PWM, one-pulse, APB và DMA req/ack. |
| [`017_QSPI_Controller`](017_QSPI_Controller/README.md) | IP SPI controller/target và Dual/Quad/QPI chỉ ở controller: HDS VLSIT, workbook CSR, RTL, sơ đồ, waveform, lint và tài liệu nghiên cứu. |
| [`019_SHA2_SHA3_Hash`](019_SHA2_SHA3_Hash/spec/VLSIT_SHA2_SHA3_HASH_HDS.md) | RTL SHA-2/SHA-3 với giao tiếp APB/AXI, tùy chọn CSR/DMA và regression toàn diện. |
| [`020_WDT`](020_WDT/spec/VLSIT_WDT_HDS.md) | RTL watchdog timer và đặc tả thiết kế. |
| [`021_UART`](021_UART/rtl/filelist.f) | RTL UART và flow verification phụ thuộc simulator. |
| [`027_ChaCha`](027_ChaCha/README.md) | IP mã hóa xác thực ChaCha20-Poly1305: nghiên cứu tính năng, bản nháp đặc tả thiết kế phần cứng và workbook CSR; RTL tổng hợp được (lint sạch, mô phỏng thử với vector RFC 8439); chưa có môi trường verification. |

Sơ đồ khối ở mục 5.2 của mỗi đặc tả là sơ đồ draw.io (`spec/figures/*.drawio`, thư viện symbol VLSIT) kèm bản SVG, do `vlsit_spec_diagram.py` của skill `vlsit-asic-ip-microspec` tạo từ file JSON mô tả sơ đồ nằm cạnh.

Dùng filelist chuẩn duy nhất `rtl/filelist.f` của mỗi IP. File này liệt kê các profile RTL đang hoạt động và các phụ thuộc dùng chung; chọn top cùng define profile cần thiết khi gọi tool. Các module CRC là phương án thay thế nhau nên phải chọn top phù hợp khi elaborate.

### Chạy lint và regression

Từ thư mục gốc repository, dùng GNU make (MSYS2 hoặc Git Bash trên Windows):

```sh
make lint        # lint các IP 001–021 đã khai báo (không phải toàn bộ 27 IP)
make regression  # chạy các regression tự kiểm hiện có
make all         # chạy kiểm tra rule RTL, lint và regression hiện có
```

Makefile gốc hiện khai báo IP 001–021; các IP 022–026 đã có cấu trúc trong repository nhưng chưa được tích hợp vào các mục tiêu tổng này. Đường dẫn OSS CAD Suite và script VLSIT RTL rule có thể cấu hình qua `PY`, `PYTHON`, `SKILL` hoặc `OSSCAD`. Regression chỉ gồm thiết kế có testbench hoặc runner. Flow UART cần Synopsys VCS; mục tiêu tổng sẽ báo skip nếu không tìm thấy VCS.

### Ảnh chụp lịch sử trạng thái verification (2026-11-15)

Bảng này ghi lại trạng thái verification đã báo cáo ngày 2026-11-15, trước khi tổ chức lại thư mục. Tên đường dẫn trong bảng phản ánh cấu trúc tại thời điểm đó và được giữ làm bằng chứng lịch sử; xem chỉ mục IP cùng README của từng IP phía trên để biết đường dẫn hiện tại. Các kết quả bên dưới chưa được chạy lại trong đợt tổ chức này.

| Thiết kế | Đặc tả và RTL | Lint và constraint | Verification |
|---|---|---|---|
| `000_Common` | wrapper, cell model, `cell_tests`, `lib_tests` | - | test của cell và wrapper |
| `001_AsyncGrayFIFO` | đặc tả, RTL, log lint, waveform | - | không có thư mục verification |
| `002_SyncFIFO` | đặc tả, RTL, log lint, waveform | - | `verification/`: testbench và bộ mô phỏng |
| `003_AsyncAXI4Bridge` | đặc tả, RTL ba profile (18 module), waveform | log lint trong thư mục từng profile | `verification/`: testbench, `simulation_report.md` |
| `004_CRC` | đặc tả, năm module RTL | - | `tests/`, `sanity/` |
| `005_AsyncAPBBridge` | đặc tả, RTL, waveform | `lint/`; `sdc/` (SDC) | `verification/`, `sanity/` |
| `006_AHB2AXI_Bridge` | đặc tả, RTL | - | `verification/` |
| `007_AXI2APB_Bridge` | đặc tả; RTL đang dùng `rtl/` PASS rule checker; `rtl/` cũ có 4 lỗi R-036 | - | không có thư mục verification |
| `008_AXI2TLUL_Bridge` | đặc tả, RTL | `lint/`; `sdc/` | `verification/` |
| `009_APB2TLUL_Bridge` | đặc tả, RTL | - | `verification/`, `sanity/` |
| `010_Async4PhaseHandshake` | HDS, RTL và delivery/rule report | `make lint`; rule check | chưa có testbench |
| `011_Async2PhaseHandshake` | HDS, RTL và testbench tự kiểm | `make lint` | `make verify` |
| `012_HyperRAM_Controller` | `rtl/` tái sinh CSR bằng generator v3.3; bộ RTL trước đó được lưu để đối chiếu | `make lint`; rule check | `verification/run_smoke.sh` (x8/x16); runner coverage |
| `013_AsyncGrayCodeSync` | HDS, RTL và testbench tự kiểm | `make lint` | `make verify` |
| `014_AXI4_Upsizer` | đặc tả, các profile RTL AXI4/AXI3, waveform | `lint/` | `verification/` |
| `015_Timer` | bộ RTL mới gồm 12 file, CSR dùng generator v3.3; lưu bộ cũ để đối chiếu | `make lint`; rule check | regression req/ack DMA trong `verification/Makefile` |
| `017_QSPI_Controller` | HDS VLSIT, workbook CSR, RTL, sơ đồ, waveform, nghiên cứu và lưu trữ bản cũ | `make lint`; rule check | chưa có testbench mô phỏng |
| `019_SHA2_SHA3_Hash` | HDS, RTL và vector/assertion/coverage collateral | `make lint` | `verification/scripts/run_all.py` |
| `020_WDT` | HDS và RTL | `make lint` | chưa có testbench |
| `021_UART` | RTL và collateral verification dùng VCS | `make lint` | cần Synopsys VCS |

### Ghi chú rà soát verification (2026-11-15)

Toàn bộ 19 mục lint của IP đều pass. Các regression chức năng của common cells, SyncFIFO, AsyncAPB, AXI2TLUL, APB2TLUL, handshake hai pha, HyperRAM, Gray-code synchronizer, AXI upsizer, Timer DMA, CRC, bằng chứng Async AXI và SHA-2/SHA-3 đều pass. Regression AHB2AXI vẫn fail tại WF-003, WF-004 và WF-006. UART được bỏ qua do không có Synopsys VCS.

### RTL dùng chung và mô hình cell

`000_Common/rtl_lib` chứa các functional wrapper dùng lại:

| Module | Chức năng |
|---|---|
| `m_vlsit_rst_sync` | Reset synchronizer active-low, assertion bất đồng bộ và de-assertion đồng bộ. Số tầng synchronizer cấu hình được. |
| `m_vlsit_tie` | Ngõ ra tie-high/tie-low với độ rộng và giá trị cấu hình được. |
| `m_vlsit_afifo_cell_sync` | Wrapper một bit để chọn synchronizer cell cho FIFO bất đồng bộ; nhánh mô phỏng có mô hình metastability. |
| `m_vlsit_afifo_ram_macro` | Wrapper cho SRAM macro một cổng ghi, một cổng đọc của asynchronous FIFO. |
| `m_vlsit_sfifo_ram_macro` | Wrapper cho SRAM macro một cổng ghi, một cổng đọc của synchronous FIFO. |

`000_Common/rtl_cells` có **61** mô hình stand-in có thể tổng hợp: 52 cell logic, tuần tự, clock và tie; 8 synchronizer cell; 1 mô hình SRAM. Các mô hình này phục vụ lint, mô phỏng và elaborate tổng quát. Khi triển khai ASIC, phải ánh xạ wrapper sang cell và memory macro của thư viện đích; mô hình ví dụ không thay thế view của thư viện thật.

### So sánh kiến trúc FIFO

Cả hai FIFO top đều có request ghi/đọc, dữ liệu đọc show-ahead, cờ full/empty và threshold, báo overflow/underflow, cùng trình tự software reset. Điều kiện clock khác nhau nên cần chọn theo quan hệ clock.

| Design | Quan hệ clock và cấu trúc | Latency | Storage mặc định / ước lượng diện tích tương đối | Ưu điểm | Giới hạn |
|---|---|---|---|---|---|
| `001_AsyncGrayFIFO/m_vlsit_afifo_top` | Write/read clock độc lập, không đồng bộ. Gray pointer đi qua synchronizer; top ghép khối điều khiển ghi, đọc và storage hai clock. | Synchronizer pointer mặc định 2 tầng. Word mới xuất hiện ở read domain sau khi write pointer đi qua CDC; storage đọc có latency 1 read-clock-cycle và dữ liệu show-ahead. Thời gian thực tế phụ thuộc pha hai clock. | Mặc định depth 8 × width 32 = **256 bit dữ liệu** ở nhánh RTL array, cộng pointer, synchronizer, reset FSM và flag. **Ước lượng tương đối: trung bình, chủ yếu do storage, thêm nhiều điều khiển hơn SyncFIFO.** Diện tích SRAM macro phụ thuộc thư viện. | Dùng được với clock độc lập và có software-reset phối hợp hai miền. | Nhiều trạng thái điều khiển/synchronizer hơn; depth mặc định phải là lũy thừa của 2 (tối thiểu 2). Cần CDC constraint và ánh xạ synchronizer/memory macro đúng cho sản phẩm. |
| `002_SyncFIFO/m_vlsit_sfifo_top` | Các clock đồng bộ có quan hệ thời gian. Điều khiển ghi/đọc và storage tách riêng; không có asynchronous pointer synchronizer. `PARA_SFIFO_PTR_RETIME` tùy chọn thêm register ở miền nhận pointer. | Storage đọc có latency 1 read-clock-cycle. Word ghi vào FIFO rỗng xuất hiện sau cạnh đọc kế tiếp thứ nhất khi `PTR_RETIME=0`, hoặc thứ hai khi `PTR_RETIME=1`; full giảm theo cùng lựa chọn 1/2 cạnh. | Mặc định depth 8 × width 32 = **256 bit dữ liệu** ở nhánh RTL array, cộng pointer, retiming tùy chọn, reset FSM và flag. **Ước lượng tương đối: trung bình, chủ yếu do storage, ít trạng thái CDC hơn AsyncGrayFIFO.** Diện tích SRAM macro phụ thuộc thư viện. | Ít overhead CDC hơn; hỗ trợ depth không phải lũy thừa của 2; retime đổi thêm một cạnh flag lấy đường pointer ngắn hơn. | Không dùng thay asynchronous FIFO. Hai clock phải có quan hệ đồng bộ đã biết. Chỉ đảm bảo streaming không gián đoạn khi depth ≥ `4 + 2 × PTR_RETIME`. |

Con số 256 bit là dung lượng payload, không phải tổng diện tích. Ở nhánh RTL array mặc định, synthesis có thể ánh xạ storage thành register và logic chọn dữ liệu đọc. Ở nhánh macro, diện tích do memory compiler/thư viện quyết định. Spec chi tiết định nghĩa miền parameter hợp lệ, reset và ý nghĩa các flag.

### So sánh các phương án CRC

Cả năm module dùng recurrence CRC MSB-first, nhưng interface và profile CRC khác nhau. Muốn khớp một chuẩn CRC còn cần polynomial, initial value, bit order/reflection, final XOR và chính xác các bit message; chỉ chọn module không chứng minh tương thích chuẩn.

| Module | Cấu hình mặc định | Chức năng và latency từ lúc nhận request | Số bit state khai báo* | Ước lượng diện tích tương đối* | Proxy độ lớn logic | Ưu điểm / đánh đổi |
|---|---|---|---:|---|---|---|
| `m_crc_serial` | CRC width cố định 4 | Nhận 1 bit mỗi clock được enable. Khi tắt `i_ctrl_en`, CRC state bị xóa ở cạnh kế tiếp; residue checker tùy chọn lấy mẫu ở cạnh idle. | 5 | Rất nhỏ | Một recurrence serial 4 bit mỗi chu kỳ; datapath CRC nhỏ nhất. | Logic ít nhất, nhận luồng bit liên tục; width cố định, 1 bit/chu kỳ, reset active-low đồng bộ. |
| `m_crc_initial_value` | CRC 8, data 16 | Nạp 8 bit trên làm initial CRC, sau đó xử lý tuần tự payload và bit 0 nối thêm. Kết quả sau **16 processing clock**. | 29 | Nhỏ | Một recurrence 8 bit mỗi chu kỳ, thêm counter/control. | Nhận initial state từ input với datapath nhỏ; latency lớn nhất trong nhóm transaction. |
| `m_crc_parallel` | CRC 8, data 16 | Xử lý toàn bộ word bằng logic tổ hợp và đăng ký kết quả **1 clock sau khi nhận**. Không có tùy chọn reflection hoặc init/final XOR. | 33 | Trung bình | `DATA_W × CRC_W` = **128** bước recurrence bit được unroll cho một kết quả. | Latency thấp; đường tổ hợp lớn hơn phương án serial/chunked. |
| `m_crc_parallel_crcw` | CRC 8, data 32, chunk 8 | Xử lý một chunk mỗi clock; mặc định `32/8 = 4` chunk, kết quả sau **4 processing clock**. | 51 | Trung bình | `CAL_W × CRC_W` = **64** bước recurrence bit mỗi chu kỳ xử lý; đổi thêm chu kỳ lấy đường logic ngắn hơn. | Cân bằng giữa diện tích/timing và latency; cần `CAL_W = CRC_W` và data width chia hết cho chunk width. |
| `m_crc_parallel_full` | CRC 16, data 32 | Kết quả song song sau 1 chu kỳ; hỗ trợ đảo bit từng byte đầu vào, initial XOR, đảo bit đầu ra và final XOR. Các option được chốt khi nhận request. | 82 | Lớn | `DATA_W × CRC_W` = **512** bước recurrence bit unroll, cộng logic option/reflection/XOR. | Interface CRC đầy đủ nhất và latency 1 chu kỳ; datapath tổ hợp mặc định lớn nhất. |

\*Số bit state khai báo được cộng từ các register trong RTL tại cấu hình mặc định nêu trên, trước tối ưu synthesis. “Rất nhỏ/Nhỏ/Trung bình/Lớn” là phân hạng tương đối cho các cấu hình mặc định này, dựa trên state và cấu trúc recurrence. Số bước recurrence biểu thị cấu trúc logic trong RTL, không phải số cổng sau mapping.

Các CRC dạng transaction nhận request khi `i_ctrl_en` và `o_crc_ready` cùng bằng 1 tại cạnh lấy mẫu. Request chỉ xuất hiện lúc module bận sẽ bị bỏ qua; giữ `i_ctrl_en` mức 1 sẽ cho phép nhận khi ready trở lại. `m_crc_serial` là giao diện luồng bit, không phải giao diện transaction ready/valid. Reset của module serial là đồng bộ; bốn module còn lại assertion bất đồng bộ.

### Giới hạn của ước lượng diện tích

Repository không có file Liberty của standard cell đích, diện tích memory compiler, process corner, timing constraint hoặc báo cáo synthesis đã map theo công nghệ. Vì vậy README này **không đưa ra** diện tích µm² hay con số NAND2-equivalent chính xác. Bảng dùng proxy có thể kiểm chứng ở mức RTL: số bit payload FIFO, số bit state CRC khai báo và số bước recurrence CRC. Muốn biết diện tích triển khai, cần synthesis theo thư viện đích và cấu hình macro dự kiến, rồi báo cáo riêng diện tích cell đã map và diện tích memory macro.

CRC RTL trong `004_CRC` đã pass VLSIT rule checker và Verilator lint (5 top, mỗi top 0 lỗi/0 cảnh báo). Regression cũng pass mô phỏng, synthesis, mutation check, kiểm tra waveform evidence và tạo báo cáo. README CRC nguồn vẫn là tài liệu tham chiếu hành vi; thư mục chưa có CRC specification độc lập được duyệt.

