# CRC Implementations / Các cách triển khai CRC

## IP overview and status

Collection of independent cyclic redundancy check (CRC) engines with serial, parallel, and chunked datapath alternatives.

**Status:** Inventory: 8 RTL source file(s), 3 specification/reference artifact(s), and 263 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

Collection of independent cyclic redundancy check (CRC) engines with serial, parallel, and chunked datapath alternatives.

**Trạng thái:** Inventory: 8 RTL source file(s), 3 specification/reference artifact(s), and 263 verification file(s) are present. Functional, lint, CDC/RDC, formal, and synthesis status was not rerun or re-certified by this directory reorganization.

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

This directory contains five synthesizable CRC implementations. They share an MSB-first CRC recurrence but differ in input width, work per cycle, latency, and optional CRC features. The RTL is under `rtl/`; self-checking testbenches and their plan are under `verification/tests/`; sanity logs and reports are under `verification/tests/sanity/`.

### Implementation comparison

The values below use each module's default parameters. “Recurrence stages” describes how many input bits the CRC recurrence is expanded across in one cycle. State-bit counts include the sequential registers declared by the RTL; they are not cell-area measurements.

| Implementation | Default configuration | Result latency | Recurrence stages per cycle | State bits | Relative Fmax potential | Relative combinational logic trend |
|---|---|---:|---:|---:|---|---|
| `m_crc_serial` | CRC width 4; one input bit per cycle | Streaming, one bit/cycle | 1 | 5 | Highest | Lowest |
| `m_crc_initial_value` | CRC width 8; data width 16 | 16 processing cycles | 1 | 29 | High | Low |
| `m_crc_parallel_crcw` | CRC width 8; data width 32; chunk width 8 | 4 processing cycles | 8 | 51 | Medium | Medium |
| `m_crc_parallel` | CRC width 8; data width 16 | 1 processing cycle | 16 | 33 | Low | High |
| `m_crc_parallel_full` | CRC width 16; data width 32 | 1 processing cycle | 32 | 82 | Lowest | Highest |

These are structural estimates, not synthesized results. A deeper unrolled recurrence usually increases the register-to-register logic depth and combinational area. The full implementation also has input/output option logic; bit reflection itself is wiring, while option selection and XOR operations add logic. Synthesis optimization and the target cell library can change the ranking. The default widths differ, so the table is useful for a first architectural choice, not a width-normalized benchmark.

No MHz or ASIC gate-area numbers are reported: a target standard-cell library, PVT corner, clock constraints, and synthesis/STA results are not available here. State-bit counts are provided as a reproducible storage proxy only. For a fair implementation comparison, use the same CRC and data widths, library, PVT corner, constraints, and synthesis settings; compare mapped cell area and STA critical-path frequency.

### Selection guide

- Choose `m_crc_serial` for minimum datapath logic and low input throughput.
- Choose `m_crc_initial_value` when the initial state is carried in the input word and a multi-cycle result is acceptable.
- Choose `m_crc_parallel_crcw` to trade latency for a shorter recurrence path than full-word parallel processing.
- Choose `m_crc_parallel` for one-cycle word processing without reflection or initial/final XOR options.
- Choose `m_crc_parallel_full` when those CRC options and one-cycle word processing are required, with the largest default logic and state footprint.

### Verification

Run `make verify` from this directory. It runs the five timed self-checking simulations and a mutation check. Results are saved in `verification/tests/sanity/logs/`; see [`verification/tests/README.md`](verification/tests/README.md) for test scope and [`verification/tests/sanity/verification_report.md`](verification/tests/sanity/verification_report.md) for the recorded run.

The CRC bit order, polynomial convention, request/ready behavior, and reset behavior are described in the source project's [`crcCalculator README`](../../../crcCalculator/README.md).

---

## Tiếng Việt

Thư mục này có năm cách triển khai CRC có thể tổng hợp. Các module dùng chung phép cập nhật CRC MSB-first nhưng khác độ rộng đầu vào, số bit xử lý mỗi chu kỳ, độ trễ và các tùy chọn CRC. RTL nằm trong `rtl/`; testbench tự kiểm tra và kế hoạch test nằm trong `verification/tests/`; log và báo cáo sanity nằm trong `verification/tests/sanity/`.

### So sánh các cách triển khai

Các số dưới đây dùng parameter mặc định của từng module. “Số tầng recurrence” là số bit đầu vào được mở rộng qua phép cập nhật CRC trong một chu kỳ. Số bit trạng thái đếm các thanh ghi tuần tự trong RTL; đây không phải số đo diện tích cell.

| Cách triển khai | Cấu hình mặc định | Độ trễ kết quả | Tầng recurrence mỗi chu kỳ | Số bit trạng thái | Tiềm năng Fmax tương đối | Xu hướng logic tổ hợp tương đối |
|---|---|---:|---:|---:|---|---|
| `m_crc_serial` | CRC rộng 4 bit; 1 bit dữ liệu/chu kỳ | Liên tục, 1 bit/chu kỳ | 1 | 5 | Cao nhất | Thấp nhất |
| `m_crc_initial_value` | CRC rộng 8 bit; dữ liệu rộng 16 bit | 16 chu kỳ xử lý | 1 | 29 | Cao | Thấp |
| `m_crc_parallel_crcw` | CRC rộng 8 bit; dữ liệu rộng 32 bit; khối rộng 8 bit | 4 chu kỳ xử lý | 8 | 51 | Trung bình | Trung bình |
| `m_crc_parallel` | CRC rộng 8 bit; dữ liệu rộng 16 bit | 1 chu kỳ xử lý | 16 | 33 | Thấp | Cao |
| `m_crc_parallel_full` | CRC rộng 16 bit; dữ liệu rộng 32 bit | 1 chu kỳ xử lý | 32 | 82 | Thấp nhất | Cao nhất |

Đây là ước lượng theo cấu trúc, không phải kết quả tổng hợp. Recurrence được mở rộng nhiều tầng thường làm tăng độ sâu logic giữa các thanh ghi và diện tích logic tổ hợp. Module full còn có logic tùy chọn đầu vào/đầu ra; đảo bit chỉ là nối dây, còn chọn chế độ và XOR cần thêm logic. Tối ưu của synthesis và thư viện cell có thể làm thay đổi thứ hạng. Độ rộng mặc định của các module khác nhau, vì vậy bảng phù hợp để chọn kiến trúc ban đầu, không phải benchmark đã chuẩn hóa theo độ rộng.

Không đưa số MHz hoặc diện tích cổng ASIC vì chưa có thư viện standard cell, corner PVT, ràng buộc clock và kết quả synthesis/STA. Số bit trạng thái chỉ là chỉ báo lưu trữ có thể tái lập. Để so sánh công bằng, cần dùng cùng độ rộng CRC và dữ liệu, thư viện, corner PVT, ràng buộc và thiết lập synthesis; sau đó so sánh diện tích cell đã ánh xạ và tần số critical path từ STA.

### Gợi ý chọn module

- Chọn `m_crc_serial` khi cần datapath nhỏ và thông lượng đầu vào thấp.
- Chọn `m_crc_initial_value` khi trạng thái khởi tạo được chứa trong từ đầu vào và có thể chấp nhận độ trễ nhiều chu kỳ.
- Chọn `m_crc_parallel_crcw` để đổi độ trễ lấy đường recurrence ngắn hơn xử lý song song toàn từ.
- Chọn `m_crc_parallel` để xử lý từ trong một chu kỳ, không cần đảo bit hoặc XOR khởi tạo/kết thúc.
- Chọn `m_crc_parallel_full` khi cần các tùy chọn CRC đó và kết quả trong một chu kỳ; mặc định dùng nhiều logic và trạng thái nhất.

### Verification

Chạy `make verify` tại thư mục này. Lệnh chạy năm mô phỏng timing tự kiểm tra và mutation check. Kết quả được lưu trong `verification/tests/sanity/logs/`; xem [`verification/tests/README.md`](verification/tests/README.md) để biết phạm vi test và [`verification/tests/sanity/verification_report.md`](verification/tests/sanity/verification_report.md) để xem kết quả đã ghi nhận.

Thứ tự bit CRC, quy ước polynomial, request/ready và reset được mô tả trong [`README của dự án crcCalculator`](../../../crcCalculator/README.md).
