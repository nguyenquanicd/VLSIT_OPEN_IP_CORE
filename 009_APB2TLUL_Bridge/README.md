# APB4-to-TL-UL Bridge

## IP overview and status

Bridge from an APB4 completer interface to a TL-UL manager interface.

**Status:** Inventory: 3 RTL source file(s), 3 specification/reference artifact(s), and 20 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

Bridge from an APB4 completer interface to a TL-UL manager interface.

**Trạng thái:** Inventory: 3 RTL source file(s), 3 specification/reference artifact(s), and 20 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

This folder contains the APB4 Completer to TL-UL Manager bridge specification, synthesizable RTL, and self-checking verification environment. The bridge uses one clock domain and converts APB requests into TL-UL transactions.

| Path | Contents |
|---|---|
| `APB2TLUL_Bridge_Design_Specification.md` | Architecture, interfaces, behavior, and verification requirements |
| `rtl/` | RTL modules and compile-order `filelist.f` |
| `verification/` | Testbench, protocol assertions, and verification notes |
| `spec/figures/` | Block diagram and protocol waveform sources/renderings |
| `research/` | Reference-IP research record |
| `verification/tests/sanity/` | Check, lint, and simulation reports copied from the example project |
| `Makefile` | Commands for rule checks, lint, and simulation |
| `design_process_log.md` | Design decisions and development history |

Run `make help` for available commands and `make all` to run the rule check, lint, and both simulation configurations. Generated binaries go to `build/` and are excluded by `.gitignore`.

The RTL rule-check/lint scripts and protocol reference text are kept in the sibling `VLSIT_CODEX_CLAUDE_SKILLS` repository and are referenced with relative paths; they are not duplicated here. Keep both repositories side by side for the supplied Makefile and reference links to resolve.

## Tiếng Việt

Thư mục này chứa đặc tả, RTL có thể tổng hợp và môi trường verification tự kiểm cho cầu nối APB4 Completer sang TL-UL Manager. Thiết kế dùng một miền clock và chuyển request APB thành giao dịch TL-UL.

| Đường dẫn | Nội dung |
|---|---|
| `APB2TLUL_Bridge_Design_Specification.md` | Kiến trúc, interface, chức năng và yêu cầu verification |
| `rtl/` | Các module RTL và `filelist.f` theo thứ tự biên dịch |
| `verification/` | Testbench, protocol assertion và hướng dẫn verification |
| `spec/figures/` | Sơ đồ khối và waveform giao thức cùng file nguồn |
| `research/` | Nhật ký nghiên cứu IP tham khảo |
| `verification/tests/sanity/` | Báo cáo check, lint và mô phỏng được chép từ project ví dụ |
| `Makefile` | Lệnh kiểm tra rule, lint và mô phỏng |
| `design_process_log.md` | Nhật ký quyết định và quá trình phát triển |

Chạy `make help` để xem lệnh. `make all` chạy rule check, lint và hai cấu hình mô phỏng. Binary được tạo trong `build/` và loại khỏi Git bằng `.gitignore`.

Script rule-check/lint và tài liệu protocol nằm trong repository bên cạnh `VLSIT_CODEX_CLAUDE_SKILLS`; thư mục này tham chiếu chúng bằng đường dẫn tương đối, không sao chép trùng. Để Makefile và liên kết tài liệu hoạt động, giữ hai repository cạnh nhau.
