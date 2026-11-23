# 014_AXI4_Upsizer

## IP overview and status

AXI3/AXI4 data-width upsizer supporting multiple bus-width profiles.

**Status:** Inventory: 12 RTL source file(s), 2 specification/reference artifact(s), and 43 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

AXI3/AXI4 data-width upsizer supporting multiple bus-width profiles.

**Trạng thái:** Inventory: 12 RTL source file(s), 2 specification/reference artifact(s), and 43 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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


## English

Design specification of an AXI upsizer: an AXI subordinate of data width S (narrow side) that drives an AXI manager of data width M > S (wide side), with the ratio set by two parameters (power of 2, 2 to 128), AXI4 and AXI3 profile tops, one clock, a register slice on every channel. Modifiable INCR and WRAP bursts of full S width are packed into wide beats; every other transaction keeps its shape and moves its beats to the right byte lane.

Status (2026-11-01): RTL for both AXI4 and AXI3 is present under `rtl/`. The Upsizer-specific single-clock FIFO is local at `rtl/common/m_vlsit_sfifo_1clk.sv`; tie-off cells remain shared from `000_Common`. `verification/vlsit_run_sim.py regress --seeds 1,2,3` passes all 8 configurations across 3 seeds (24 runs). `vlsit_spec_tool.py check` passes (0 errors, 22 sections). Thirteen waveforms and the draw.io block diagram are delivered. The algorithm of section 10.2, including the AXI3 write data interleave (WID contexts, DEC-019), was checked on a Python cycle model and is exercised by the RTL regression. Open item: TBD-001 (frequency, area, power targets), left as TBD by the user's request. The combinational circuit is specified in an optimized implementation form (section 10.2, REQ-RTL-004, DEC-021). The AXI3 interleave rules were checked against the Arm AXI Protocol Specification v1.0, IHI 0022B, sections 8.4 and 8.5, converted into the `md_doc` of the specification skill (issue F was not read); see `research/axi3_write_interleave_source.md`. ASM-002, ASM-003 and DEP-004 are confirmed by the user.

| Path | Content |
|---|---|
| [spec/AXI4_Upsizer_Design_Specification.md](spec/AXI4_Upsizer_Design_Specification.md) | The specification (22 sections of the VLSIT template) |
| `rtl/` | AXI4 and AXI3 tops and shared Upsizer RTL; local queue module at `rtl/common/m_vlsit_sfifo_1clk.sv` |
| `verification/` | Verilator testbench, assertions, 8-configuration regression runner, and mutation runner |
| `figures/` | Block diagram (`axi_upsizer_block_diagram.drawio`, `.svg`, `.png`, diagram spec JSON) and the 13 waveforms (`upsizer_wf001_...` to `upsizer_wf013_...`, WaveJSON source and SVG) |
| `verification/models/` | Reference cycle model of the specification (`ups_cycle_model.py`), the waveform generator (`gen_waveforms.py`) and the byte-level checks (`check_model.py`, `check_interleave.py` for the AXI3 write interleave) and the equivalence check of the optimized combinational forms (`check_equivalence.py`); not RTL |
| `sdc/m_vlsit_axi_upsizer.sdc` | Clock definition and the statement that the IP owns no exception (variable `T_CLK_AXI` set by the SoC) |
| `research/reference_ip_log.md` | Reference IP research log (ideas only, nothing copied) |
| `research/axi3_write_interleave_source.md` | Source and paraphrased rules of the AXI3 write data interleaving (Arm IHI 0022B 8.4, 8.5) |
| `research/source_docs/` | Local copy of the Arm PDF (licensed, ignored by git, never committed) |
| `qa_log.md` | Questions and answers with the user that fixed the decisions DEC-001 to DEC-022 |

Run the model check from `verification/models/`:

```bash
python check_model.py 200 1
python check_interleave.py 200 1 2
python check_equivalence.py
```

Environment variables `UPS_S` and `UPS_M` (bits) select other widths, for example `UPS_S=8 UPS_M=1024`. The waveform files are regenerated with `python gen_waveforms.py <dir>` and rendered with `vlsit_waveform_svg.py render <file> --out <file>.svg --cell 54`.

## Tiếng Việt

Đặc tả của bộ upsizer AXI: subordinate AXI độ rộng dữ liệu S (phía hẹp) điều khiển manager AXI độ rộng M > S (phía rộng), tỷ lệ đặt bằng hai tham số (lũy thừa 2, từ 2 đến 128), hai top AXI4 và AXI3, một clock, register slice trên mọi kênh. Burst INCR và WRAP Modifiable có đúng độ rộng S được gép (pack) thành beat rộng; các giao dịch còn lại giữ nguyên hình dạng và chỉ chuyển beat sang đúng byte lane.

Trạng thái (2026-11-01): đã có RTL cho cả AXI4 và AXI3 trong `rtl/`. FIFO một clock chỉ dùng bởi Upsizer được đặt tại `rtl/common/m_vlsit_sfifo_1clk.sv`; các tie-off cell vẫn dùng chung từ `000_Common`. Lệnh `verification/vlsit_run_sim.py regress --seeds 1,2,3` pass cả 8 cấu hình với 3 seed (24 lượt). `vlsit_spec_tool.py check` pass (0 lỗi, 22 mục). Đã có 13 waveform và sơ đồ khối draw.io. Thuật toán ở mục 10.2, gồm cả interleave write data của AXI3 (ngữ cảnh theo WID, DEC-019), đã được kiểm trên mô hình chu kỳ Python và được chạy trong RTL regression. Việc còn mở: TBD-001 (mục tiêu tần số, diện tích, công suất), để TBD theo yêu cầu của người dùng. Mạch tổ hợp được đặc tả theo dạng tối ưu (mục 10.2, REQ-RTL-004, DEC-021). Quy tắc interleave AXI3 đã đối chiếu với Arm AXI Protocol Specification v1.0, IHI 0022B, mục 8.4 và 8.5, đã chuyển vào md_doc của skill (chưa đọc issue F); xem `research/axi3_write_interleave_source.md`. ASM-002, ASM-003 và DEP-004 đã được người dùng xác nhận.

Các file như bảng tiếng Anh ở trên. Chạy kiểm tra mô hình từ thư mục `verification/models/` bằng lệnh `python check_model.py 200 1`.
