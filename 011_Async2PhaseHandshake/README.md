# 011 Async2PhaseHandshake

## IP overview and status

Two-phase asynchronous request/acknowledge handshake for safe clock-domain crossings.

**Status:** Inventory: 3 RTL source file(s), 1 specification/reference artifact(s), and 30 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

Two-phase asynchronous request/acknowledge handshake for safe clock-domain crossings.

**Trạng thái:** Inventory: 3 RTL source file(s), 1 specification/reference artifact(s), and 30 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

