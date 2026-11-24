# 023 USB20 Controller

## IP overview and status

USB 2.0 controller supporting device and host profiles, PHY interfaces, and bus integration.

**Status:** The pre-reorganization inventory contained 28 RTL source files and approximately 30,001 verification files and artifacts. Active test sources, models, scripts, and documentation have been placed in the standard verification folders; historical run/build trees are preserved in verified archives. After the reorganization the verification flow was re-pointed to the new folders on 2026-11-24 (paths in `verification/env/scripts/vpaths.py`, builds in `verification/env/env/builds.json`) and rerun: all 21 builds, the smoke regression (formal, static checks, simulation) and the full regression, see `verification/docs/README.md`. Lint, CDC, RDC and synthesis flows were not rerun.

## Directory organization

- `spec/`: design specification, `spec/README.md` index, register definitions, and `spec/figures/` diagrams/waveforms.
- `rtl/`: active synthesizable RTL and the single master filelist `rtl/filelist.f`. It includes the wrapper profiles; select the desired top and profile defines when invoking tools.
- `lint/`, `cdc/`, `rdc/`, `sdc/`, and `syn/`: implementation and analysis collateral.
- `verification/docs/`: all verification plans, reports, and documentation, stored directly in this flat directory.
- `verification/tests/`: testcases and testcase generators.
- `verification/models/`: independent reference models.
- `verification/env/`: testbench, bus functional models, scripts, configuration, and formal setup.
- `verification/sim/`: simulation outputs and preserved historical run archives.
- `review/`: Markdown review reports and `review/reference/` evidence.
- `research/` and `archive/`: research sources and preserved historical collateral.

`verification/` has exactly five direct directory types: `docs`, `tests`, `models`, `env`, and `sim`. Keep its directory depth to two levels below `verification/`; keep `verification/docs/` flat. Apply the two-level limit to other IP-level categories as well, preserving deeper historical trees in archive bundles. Do not create a top-level `sim/` directory. `000_Common/` remains the shared-library exception and is not an IP package.

## Tổng quan IP và trạng thái

Bộ điều khiển USB 2.0 hỗ trợ các cấu hình device/host, giao tiếp PHY và tích hợp bus.

**Trạng thái:** Kiểm kê trước khi tổ chức lại có 28 tệp RTL và khoảng 30.001 tệp/evidence verification. Test source, model, script và tài liệu đang hoạt động được chuyển vào các thư mục verification chuẩn; cây chạy/build lịch sử được bảo toàn trong các archive đã kiểm tra. Ngày 2026-11-24 flow verification đã được trỏ lại theo thư mục mới (đường dẫn trong `verification/env/scripts/vpaths.py`, danh sách build trong `verification/env/env/builds.json`) và chạy lại: 21 build, regression smoke và full. Lint, CDC, RDC, synthesis chưa chạy lại.

## Cấu trúc thư mục

- `spec/`: đặc tả thiết kế, chỉ mục `spec/README.md`, định nghĩa thanh ghi và sơ đồ/waveform trong `spec/figures/`.
- `rtl/`: RTL tổng hợp được và filelist master duy nhất `rtl/filelist.f`; file này gồm các profile wrapper, chọn top và define khi gọi tool.
- `lint/`, `cdc/`, `rdc/`, `sdc/`, `syn/`: tài liệu triển khai và phân tích.
- `verification/docs/`: toàn bộ test plan, report và tài liệu verification, đặt trực tiếp trong một thư mục phẳng.
- `verification/tests/`: testcase và script tạo testcase.
- `verification/models/`: model tham chiếu độc lập.
- `verification/env/`: testbench, bus functional model, script, cấu hình và môi trường formal.
- `verification/sim/`: kết quả mô phỏng và archive run lịch sử.
- `review/`: báo cáo review Markdown và evidence trong `review/reference/`.
- `research/` và `archive/`: tài liệu nghiên cứu và collateral lịch sử.

`verification/` chỉ có đúng năm loại thư mục trực tiếp: `docs`, `tests`, `models`, `env`, `sim`. Độ sâu tối đa là hai cấp bên dưới `verification/`; `verification/docs/` không có thư mục con. Các thư mục IP khác cũng giới hạn hai cấp và lưu cây lịch sử sâu hơn trong archive. Không tạo `sim/` ở cấp IP. `000_Common/` là ngoại lệ thư viện dùng chung.


## Entry points / Điểm bắt đầu

- [Specification and register index / Đặc tả và thanh ghi](spec/README.md)
- [Canonical RTL filelist / Filelist RTL duy nhất](rtl/filelist.f)
- [Rule check report / Báo cáo rule check](lint/rtl_check_report.md)
- [Verification guide / Hướng dẫn kiểm chứng](verification/docs/README.md)
- [Specification review, 2026-11-22 / Review đặc tả](review/vlsit_spec_2026-11-22.md)
- [Historical source index / Chỉ mục source lịch sử](archive/README.md)

The production tops are `m_usb2_top_utmi_axim`, `m_usb2_top_utmi_axis`, `m_usb2_top_ulpi_axim`, and `m_usb2_top_ulpi_axis`. Resolve the canonical filelist from `rtl/` and select one top at invocation.

Chạy công cụ từ `rtl/` để dùng filelist theo đường dẫn tương đối. Chọn một trong bốn top trên khi gọi công cụ.
