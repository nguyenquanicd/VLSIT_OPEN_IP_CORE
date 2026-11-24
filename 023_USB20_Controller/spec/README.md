# 023_USB20_Controller Specification Index

## Purpose / Mục đích

This index points to the key specification files and explains the important artifacts and subdirectories. It is not a complete file inventory.

README này dẫn tới các tài liệu đặc tả chính và giải thích chức năng các tệp, thư mục quan trọng. Đây không phải danh sách toàn bộ tệp.

## Key specification documents / Tài liệu đặc tả chính

- [VLSIT_USB20_CONTROLLER_HDS.md](VLSIT_USB20_CONTROLLER_HDS.md) — Primary Hardware Design Specification (HDS) describing architecture, interfaces, registers, and behavior. / Đặc tả thiết kế phần cứng (HDS) chính, mô tả kiến trúc, giao tiếp, thanh ghi và hành vi.

## CSR and register artifacts / Tài liệu CSR và thanh ghi

- [reference/VLSIT_USB20_CONTROLLER_CSR.xlsx](reference/VLSIT_USB20_CONTROLLER_CSR.xlsx) — Editable CSR/register map workbook. / Workbook CSR/bản đồ thanh ghi có thể chỉnh sửa.
- [csr/regs_usb2.json](csr/regs_usb2.json) — Machine-readable CSR/register map or generator input. / Bản đồ CSR/thanh ghi dạng máy đọc được hoặc đầu vào cho bộ tạo.

## Block diagrams and key figures / Sơ đồ khối và hình chính

- [figures/m_usb2_top_block_diagram.drawio](figures/m_usb2_top_block_diagram.drawio) — Editable block or architecture diagram. / Sơ đồ khối hoặc kiến trúc có thể chỉnh sửa.
- [figures/usb2_fsm_dev_link.drawio](figures/usb2_fsm_dev_link.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- [figures/usb2_fsm_dev_xact.drawio](figures/usb2_fsm_dev_xact.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- [figures/usb2_fsm_dma_axi.drawio](figures/usb2_fsm_dma_axi.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- [figures/usb2_fsm_host_port.drawio](figures/usb2_fsm_host_port.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- [figures/usb2_fsm_host_xact.drawio](figures/usb2_fsm_host_xact.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- [figures/usb2_fsm_pkt_rx.drawio](figures/usb2_fsm_pkt_rx.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- [figures/usb2_fsm_pkt_tx.drawio](figures/usb2_fsm_pkt_tx.drawio) — Editable finite-state-machine diagram. / Sơ đồ máy trạng thái hữu hạn có thể chỉnh sửa.
- 1 additional draw.io diagram(s) are available under `figures/`. / Còn 1 sơ đồ draw.io khác trong `figures/`.
- `figures/` contains 46 rendered SVG/PNG asset(s) and 37 waveform JSON/HTML source(s), when present. / `figures/` có 46 hình SVG/PNG đã render và 37 nguồn waveform JSON/HTML, nếu có.

## Other important directories / Thư mục quan trọng khác

- `csr/` — CSR artifacts, generated register descriptions, and related source files. / Tài liệu CSR, mô tả thanh ghi được tạo và các tệp nguồn liên quan.
- `reference/` — Reference material used while preparing the specification. / Tài liệu tham khảo dùng khi chuẩn bị đặc tả.

## Figure location rule / Quy tắc vị trí hình

All specification diagrams, FSM diagrams, waveform sources, and their renderings belong under `spec/figures/`. Keep the editable draw.io source together with its related renderings and source data. This README describes only the key artifacts; it does not claim that a design or verification flow has passed.

Mọi sơ đồ đặc tả, sơ đồ FSM, nguồn waveform và hình đã render phải nằm dưới `spec/figures/`. Đặt file draw.io có thể chỉnh sửa cạnh hình render và dữ liệu nguồn liên quan. README này chỉ mô tả tài liệu chính, không xác nhận design hay verification đã PASS.
