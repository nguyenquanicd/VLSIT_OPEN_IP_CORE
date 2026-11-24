# 007_AXI2APB_Bridge Specification Index

## Purpose / Mục đích

This index points to the key specification files and explains the important artifacts and subdirectories. It is not a complete file inventory.

README này dẫn tới các tài liệu đặc tả chính và giải thích chức năng các tệp, thư mục quan trọng. Đây không phải danh sách toàn bộ tệp.

## Key specification documents / Tài liệu đặc tả chính

- [AXI2APB_Bridge_Design_Specification.md](AXI2APB_Bridge_Design_Specification.md) — Detailed design specification and behavioral requirements. / Đặc tả thiết kế chi tiết và yêu cầu hành vi.

## CSR and register artifacts / Tài liệu CSR và thanh ghi

- No separate CSR/register map artifact was identified. / Không tìm thấy tài liệu CSR/bản đồ thanh ghi riêng.

## Block diagrams and key figures / Sơ đồ khối và hình chính

- [figures/vlsit_block_diagram.drawio](figures/vlsit_block_diagram.drawio) — Editable block or architecture diagram. / Sơ đồ khối hoặc kiến trúc có thể chỉnh sửa.
- `figures/` contains 15 rendered SVG/PNG asset(s) and 14 waveform JSON/HTML source(s), when present. / `figures/` có 15 hình SVG/PNG đã render và 14 nguồn waveform JSON/HTML, nếu có.

## Other important directories / Thư mục quan trọng khác

- No additional specification subdirectories are currently present. / Hiện không có thư mục con đặc tả quan trọng khác.

## Figure location rule / Quy tắc vị trí hình

All specification diagrams, FSM diagrams, waveform sources, and their renderings belong under `spec/figures/`. Keep the editable draw.io source together with its related renderings and source data. This README describes only the key artifacts; it does not claim that a design or verification flow has passed.

Mọi sơ đồ đặc tả, sơ đồ FSM, nguồn waveform và hình đã render phải nằm dưới `spec/figures/`. Đặt file draw.io có thể chỉnh sửa cạnh hình render và dữ liệu nguồn liên quan. README này chỉ mô tả tài liệu chính, không xác nhận design hay verification đã PASS.
