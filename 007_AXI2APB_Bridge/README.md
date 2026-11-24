# AXI2APB Bridge / Cầu nối AXI4 sang APB4

## IP overview and status

Bridge from an AXI4 subordinate interface to an APB4 manager interface.

**Status:** Inventory: 4 RTL source file(s), 2 specification/reference artifact(s), and 0 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

Bridge from an AXI4 subordinate interface to an APB4 manager interface.

**Trạng thái:** Inventory: 4 RTL source file(s), 2 specification/reference artifact(s), and 0 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

This folder contains a microarchitecture specification and synthesizable RTL for a 32-bit AXI4 Subordinate to APB4 Manager bridge. It uses one shared clock, one APB port and one active AXI transaction. The bridge has no internal clock/reset synchronizer; the SoC supplies an active-low reset synchronous to the shared clock. The external APB fabric supplies address decoding and a default error Completer.

The spec defines FIXED, INCR and WRAP conversion, subword lanes, ID echo, PPROT mapping, error handling, reset and verification requirements. It includes 14 user-approved waveform examples with WaveJSON sources. Use `rtl/`; it contains the structural top, read sequencer, write sequencer, combined arbiter/APB controller and filelist. The earlier `rtl/` baseline remains for comparison and fails VLSIT rule R-036 in four FSM processes. `rtl/` passes the VLSIT rule checker with zero warnings. Verilator reports zero errors and one intentional unused `i_axi_wlast` warning because malformed AXI traffic is outside the profile. A testbench has not been requested or generated.

## Tiếng Việt

Thư mục này chứa đặc tả vi kiến trúc và RTL có thể tổng hợp cho bridge AXI4 Subordinate sang APB4 Manager 32 bit. Thiết kế dùng chung một clock, một cổng APB và tối đa một giao dịch AXI đang hoạt động. Bridge không có clock/reset synchronizer nội bộ; SoC cấp reset active-low đã đồng bộ với clock chung. Fabric APB bên ngoài đảm nhiệm giải mã địa chỉ và Completer lỗi mặc định.

Đặc tả quy định chuyển đổi FIXED, INCR, WRAP, lane dữ liệu nhỏ hơn word, phản hồi ID, ánh xạ PPROT, xử lý lỗi, reset và yêu cầu verification. Tài liệu có 14 waveform đã được người dùng duyệt cùng file nguồn WaveJSON. Dùng `rtl/`, gồm top cấu trúc, read sequencer, write sequencer, controller gộp arbitration/APB và filelist. Bản `rtl/` trước đó được giữ để đối chiếu và đang lỗi rule R-036 tại bốn process FSM. `rtl/` PASS rule checker, không có warning. Verilator báo không có lỗi và một warning `i_axi_wlast` không dùng có chủ đích vì traffic AXI sai chuẩn nằm ngoài profile. Chưa tạo testbench vì chưa có yêu cầu.

## Files / Tệp

- [Design specification](spec/AXI2APB_Bridge_Design_Specification.md) / Đặc tả thiết kế
- [RTL hierarchy block diagram (SVG)](spec/figures/vlsit_block_diagram.svg) / Sơ đồ khối hierarchy RTL (SVG)
- [Waveform index and sources](spec/AXI2APB_Bridge_Design_Specification.md#103-cycle-level-behavior) / Danh sách waveform và file nguồn
- [Active RTL source set and filelist](rtl/filelist.f) / Bộ RTL đang dùng và filelist
- [Reference IP research](research/vlsit_reference_ip_log.md) / Nghiên cứu IP tham chiếu
- [Decision and QA log](spec/vlsit_qa_log.md) / Nhật ký quyết định và QA

Run the VLSIT rule checker and lint with `rtl/filelist.f` and top `m_axi2apb_bridge`. / Chạy VLSIT rule checker và lint với `rtl/filelist.f`, top `m_axi2apb_bridge`.

The Arm protocol specifications are licensed references kept outside this folder. Do not copy or redistribute them. / Tài liệu giao thức Arm có giấy phép được giữ ngoài thư mục này; không sao chép hoặc phân phối lại.
