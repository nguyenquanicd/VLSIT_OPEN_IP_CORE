# Asynchronous AXI Bridge RTL

## IP overview and status

Asynchronous Advanced eXtensible Interface 4 (AXI4) bridge with independently buffered channels and configurable AXI profiles.

**Status:** Inventory: 18 RTL source file(s), 2 specification/reference artifact(s), and 169 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

## Standard directory structure

~~~text
<IP>/
├── README.md             Overall IP description and current status
├── LICENSE               Usage terms and retained upstream notices
├── spec/
│   ├── README.md          Index of key specifications, registers, and figures
│   └── spec/figures/           Block diagrams, waveforms, and specification figures
├── rtl/                   Active synthesizable RTL; the sole filelist is filelist.f
├── lint/                  Lint setup and retained lint evidence
├── cdc/                   Clock-domain-crossing analysis and reports
├── rdc/                   Reset-domain-crossing analysis and reports
├── sdc/                   Timing constraints and timing collateral
├── syn/                   Synthesis setup and evidence
├── research/              Source research and external references
├── verification/          Exactly five direct categories
│   ├── docs/              Flat folder for plans, reports, and documentation
│   ├── tests/             Reusable testcase sources and generators
│   ├── models/            Independent reference models
│   ├── env/               Testbench, BFMs, scripts, and configuration
│   └── sim/               Isolated runs and preserved run archives
├── review/
│   ├── reference/         Supporting review evidence
│   └── *.md               One Markdown report per review step
└── archive/               Historical source snapshots and inactive collateral
~~~

000_Common is a shared-library exception and does not use this per-IP layout. Existing self-contained simulation workspaces remain atomic under verification/sim/ where moving their internal files would invalidate recorded run inputs or relative-path assumptions. formal/ is used when a standalone formal environment can be separated safely; otherwise formal collateral remains inside that self-contained verification package.

## Tổng quan IP và trạng thái

Asynchronous Advanced eXtensible Interface 4 (AXI4) bridge with independently buffered channels and configurable AXI profiles.

**Trạng thái:** Inventory: 18 RTL source file(s), 2 specification/reference artifact(s), and 169 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

## Cấu trúc thư mục chuẩn

~~~text
<IP>/
├── README.md             Mô tả IP và trạng thái có bằng chứng
├── LICENSE               Điều khoản sử dụng và thông báo nguồn
├── spec/
│   ├── README.md          Chỉ mục đặc tả, thanh ghi và hình vẽ chính
│   └── spec/figures/           Sơ đồ khối, waveform và hình của đặc tả
├── rtl/                   RTL tổng hợp được; filelist duy nhất là filelist.f
├── lint/                  Cấu hình lint và bằng chứng lint
├── cdc/                   Phân tích và báo cáo crossing clock domain
├── rdc/                   Phân tích và báo cáo crossing reset domain
├── sdc/                   Ràng buộc và tài liệu timing
├── syn/                   Cấu hình và bằng chứng synthesis
├── research/              Nghiên cứu nguồn và tài liệu tham khảo
├── verification/          Đúng năm loại thư mục trực tiếp
│   ├── docs/              Thư mục phẳng chứa plan, report và tài liệu
│   ├── tests/             Testcase và script sinh testcase
│   ├── models/            Reference model độc lập
│   ├── env/               Testbench, BFM, script và cấu hình
│   └── sim/               Run mô phỏng và archive được giữ lại
├── review/
│   ├── reference/         Bằng chứng hỗ trợ review
│   └── *.md               Mỗi bước review có một report Markdown
└── archive/               Snapshot RTL cũ và tài liệu không còn hoạt động
~~~


## English

This folder contains 18 SystemVerilog modules generated from the resolved specification. Each profile has one structural top, five channel wrappers, and its own synthesis filelist.

| Profile | Top module | Interface | Files and lint log |
|---|---|---|---|
| AXI4 base | `m_vlsit_async_axi4_bridge` | QOS and REGION; no USER or WID | [filelist](rtl/filelist.f), [default lint](lint/axi4_base/lint_verilator.log), [variant lint](lint/axi4_base/lint_variants.log) |
| AXI4 USER | `m_vlsit_async_user_axi4_bridge` | QOS, REGION, and five USER ports; each USER width defaults to 1 | [filelist](rtl/filelist.f), [default lint](lint/axi4_user/lint_verilator.log), [variant lint](lint/axi4_user/lint_variants.log) |
| AXI3 | `m_vlsit_async_axi3_bridge` | WID; no QOS, REGION, or USER | [filelist](rtl/filelist.f), [default lint](lint/axi3/lint_verilator.log), [variant lint](lint/axi3/lint_variants.log) |

Use the filelist in the selected profile folder. The lists include the FIFO and common-cell dependencies and define `VLSIT_SYNTHESIS`. Example, from `axi4_base`:

```powershell
python "C:\Users\PC\.codex\skills\vlsit-rtl-generator\scripts\vlsit_lint_rtl.py" lint filelist.f --top m_vlsit_async_axi4_bridge --tool verilator
```

Verilator lint completed on all three default tops with 0 errors. Representative legal parameter variants also linted with 0 errors: maximum AXI4 widths plus SRAM/cell options, custom widths for all five USER fields, and minimum AXI3 widths/depth. Each run reports 25 `PINCONNECTEMPTY` warnings because the specification leaves unused FIFO status outputs unconnected. The RTL rule checker currently flags untyped inputs as `FIL-05/TYP-02`; these declarations follow the designer-confirmed rule. Details and manual audit results are in [generation_report.md](generation_notes/generation_report.md). The raw checker output is in [rtl_rule_report.md](generation_notes/rtl_rule_report.md).

The resolved input is [AsyncAXI4Bridge_Resolved_Design_Specification.md](generation_notes/AsyncAXI4Bridge_Resolved_Design_Specification.md). Shared dependencies are the [asynchronous FIFO](../001_AsyncGrayFIFO/rtl) and [common cells](../000_Common/rtl_cells). No simulation or testbench is included.

## Tiếng Việt

Thư mục này có 18 module SystemVerilog sinh từ bản đặc tả đã giải quyết. Mỗi profile gồm một top cấu trúc, năm module channel và một filelist tổng hợp riêng.

| Profile | Top module | Giao tiếp | Filelist và log lint |
|---|---|---|---|
| AXI4 base | `m_vlsit_async_axi4_bridge` | Có QOS, REGION; không có USER hoặc WID | [filelist](rtl/filelist.f), [lint mặc định](lint/axi4_base/lint_verilator.log), [lint cấu hình](lint/axi4_base/lint_variants.log) |
| AXI4 USER | `m_vlsit_async_user_axi4_bridge` | Có QOS, REGION và đủ năm USER; độ rộng mặc định mỗi USER là 1 | [filelist](rtl/filelist.f), [lint mặc định](lint/axi4_user/lint_verilator.log), [lint cấu hình](lint/axi4_user/lint_variants.log) |
| AXI3 | `m_vlsit_async_axi3_bridge` | Có WID; không có QOS, REGION hoặc USER | [filelist](rtl/filelist.f), [lint mặc định](lint/axi3/lint_verilator.log), [lint cấu hình](lint/axi3/lint_variants.log) |

Chọn filelist trong thư mục profile tương ứng. Filelist bao gồm FIFO, common-cell dependencies và define `VLSIT_SYNTHESIS`. Có thể chạy Verilator từ thư mục profile theo lệnh ví dụ phía trên.

Lint Verilator đã chạy trên ba top với tham số mặc định: 0 lỗi. Các cấu hình hợp lệ đại diện cũng lint không lỗi: AXI4 với độ rộng lớn nhất và tùy chọn SRAM/cell; AXI4 USER với năm độ rộng USER tùy chỉnh; AXI3 với độ rộng và độ sâu FIFO nhỏ nhất. Mỗi profile có 25 cảnh báo `PINCONNECTEMPTY` vì đặc tả yêu cầu để hở các ngõ trạng thái FIFO không dùng. RTL rule checker hiện báo `FIL-05/TYP-02` với input không ghi kiểu; RTL tuân theo rule đã được xác nhận. Xem [generation_report.md](generation_notes/generation_report.md) để biết chi tiết và kết quả rà soát thủ công. [rtl_rule_report.md](generation_notes/rtl_rule_report.md) lưu kết quả checker nguyên bản.

Bản đầu vào đã giải quyết là [AsyncAXI4Bridge_Resolved_Design_Specification.md](generation_notes/AsyncAXI4Bridge_Resolved_Design_Specification.md). Dependencies dùng chung là [asynchronous FIFO](../001_AsyncGrayFIFO/rtl) và [common cells](../000_Common/rtl_cells). Không tạo mô phỏng hoặc testbench.
