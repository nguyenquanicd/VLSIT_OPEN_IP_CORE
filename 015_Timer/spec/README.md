# 015_Timer Specification Index

## Purpose / Mục đích

This index points to the key specification files and explains the important artifacts and subdirectories. It is not a complete file inventory.

README này dẫn tới các tài liệu đặc tả chính và giải thích chức năng các tệp, thư mục quan trọng. Đây không phải danh sách toàn bộ tệp.

## Key specification documents / Tài liệu đặc tả chính

- [VLSIT_TIMER_HDS.md](VLSIT_TIMER_HDS.md) — Primary Hardware Design Specification (HDS) describing architecture, interfaces, registers, and behavior. / Đặc tả thiết kế phần cứng (HDS) chính, mô tả kiến trúc, giao tiếp, thanh ghi và hành vi.

## CSR and register artifacts / Tài liệu CSR và thanh ghi

- [m_timer_CSR_async_v0.19.xlsx](m_timer_CSR_async_v0.19.xlsx) — Editable CSR/register map workbook. / Workbook CSR/bản đồ thanh ghi có thể chỉnh sửa.
- [csr/CSR_GENERATED.md](csr/CSR_GENERATED.md) — CSR/register description or source artifact. / Mô tả hoặc tệp nguồn CSR/thanh ghi.

## Block diagrams and key figures / Sơ đồ khối và hình chính

- [figures/m_timer_4ch_block_diagram.drawio](figures/m_timer_4ch_block_diagram.drawio) — Editable block or architecture diagram. / Sơ đồ khối hoặc kiến trúc có thể chỉnh sửa.
- `figures/` contains 14 rendered SVG/PNG asset(s) and 16 waveform JSON/HTML source(s), when present. / `figures/` có 14 hình SVG/PNG đã render và 16 nguồn waveform JSON/HTML, nếu có.

## Other important directories / Thư mục quan trọng khác

- `csr/` — CSR artifacts, generated register descriptions, and related source files. / Tài liệu CSR, mô tả thanh ghi được tạo và các tệp nguồn liên quan.

## Figure location rule / Quy tắc vị trí hình

All specification diagrams, FSM diagrams, waveform sources, and their renderings belong under `spec/figures/`. Keep the editable draw.io source together with its related renderings and source data. This README describes only the key artifacts; it does not claim that a design or verification flow has passed.

Mọi sơ đồ đặc tả, sơ đồ FSM, nguồn waveform và hình đã render phải nằm dưới `spec/figures/`. Đặt file draw.io có thể chỉnh sửa cạnh hình render và dữ liệu nguồn liên quan. README này chỉ mô tả tài liệu chính, không xác nhận design hay verification đã PASS.
