# 019 SHA2 SHA3 Hash

## IP overview and status

SHA-2/SHA-3 cryptographic hash engine with optional bus, register, and DMA interfaces.

**Status:** Inventory: 18 RTL source file(s), 3 specification/reference artifact(s), and 1335 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

**Flow repair (2026-11-24):** `rtl/filelist.f` now lists `m_vlsit_rst_sync` and uses `//` comments; `make lint` and `make rule` pass (68 lint warnings, 0 errors); `make verify` runs the Verilator regression through `verification/env/run_regress_ws.py` in a temporary workspace, because the scripts in `verification/env/legacy_scripts` expect the folder layout from before the reorganization. Five suites (main64, dma64, fault_dup64, mask_reg64, perf_u1) reproduce the earlier scoreboard and cycle counts exactly. The RTL itself was not changed; the other suites and the CDC, RDC and synthesis status were not rerun.

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

SHA-2/SHA-3 cryptographic hash engine with optional bus, register, and DMA interfaces.

**Trạng thái:** Inventory: 18 RTL source file(s), 3 specification/reference artifact(s), and 1335 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

**Sửa luồng kiểm tra (2026-11-24):** `rtl/filelist.f` nay có `m_vlsit_rst_sync` và dùng chú thích `//`; `make lint` và `make rule` qua (68 cảnh báo lint, 0 lỗi); `make verify` chạy hồi quy Verilator qua `verification/env/run_regress_ws.py` trong một workspace tạm, vì script trong `verification/env/legacy_scripts` cần cấu trúc thư mục trước khi sắp xếp lại. Năm bộ (main64, dma64, fault_dup64, mask_reg64, perf_u1) cho kết quả scoreboard và số chu kỳ giống hệt lần trước. RTL không bị sửa; các bộ còn lại, CDC, RDC và tổng hợp chưa chạy lại.

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

