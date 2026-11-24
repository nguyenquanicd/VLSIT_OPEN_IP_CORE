# 027_ChaCha Specification Index

## Purpose / Mục đích

This index points to the key specification files and explains the important artifacts and subdirectories. It is not a complete file inventory.

README này dẫn tới các tài liệu đặc tả chính và giải thích chức năng các tệp, thư mục quan trọng. Đây không phải danh sách toàn bộ tệp.

## Key specification documents / Tài liệu đặc tả chính

- [VLSIT_CHACHA_HDS.md](VLSIT_CHACHA_HDS.md) — Primary Hardware Design Specification (HDS) describing architecture, interfaces, registers, and behavior. / Đặc tả thiết kế phần cứng (HDS) chính, mô tả kiến trúc, giao tiếp, thanh ghi và hành vi.

## CSR and register artifacts / Tài liệu CSR và thanh ghi

- [VLSIT_CHACHA_CSR.xlsx](VLSIT_CHACHA_CSR.xlsx) — Editable CSR/register map workbook. / Workbook CSR/bản đồ thanh ghi có thể chỉnh sửa.
- [VLSIT_CHACHA_CSR.json](VLSIT_CHACHA_CSR.json) — Machine-readable CSR/register map or generator input. / Bản đồ CSR/thanh ghi dạng máy đọc được hoặc đầu vào cho bộ tạo.

## Block diagrams and key figures / Sơ đồ khối và hình chính

- [figures/chacha20_poly1305_architecture.drawio](figures/chacha20_poly1305_architecture.drawio) — Research figure only: a generic ChaCha20-Poly1305 engine drawn from vendor sheets (documented, inferred and unknown blocks). It is not the HDS block diagram: it has one page, does not use the VLSIT symbol library and lacks the BLOCK_DIAGRAM and BLOCK_INFORMATION tabs. / Chỉ là hình của phần nghiên cứu: động cơ ChaCha20-Poly1305 tổng quát vẽ từ tài liệu của hãng (khối có trong nguồn, suy luận và chưa biết). Đây không phải sơ đồ khối của HDS: chỉ có một trang, không dùng thư viện symbol VLSIT và không có hai tab BLOCK_DIAGRAM và BLOCK_INFORMATION.
- [figures/chacha_block_diagram.svg](figures/chacha_block_diagram.svg) with its editable source [figures/chacha_block_diagram.drawio](figures/chacha_block_diagram.drawio) and diagram specification [figures/chacha_block_diagram.json](figures/chacha_block_diagram.json) — the HDS block diagram of section 5.2 (top module `m_chacha_top`, six blocks, drawn by `vlsit_spec_diagram.py`; the draw.io has the tabs BLOCK_DIAGRAM and BLOCK_INFORMATION). Internal signal names beginning with `w_` are provisional until the RTL hierarchy is final. / Sơ đồ khối của HDS ở mục 5.2 (module top `m_chacha_top`, sáu khối, vẽ bằng `vlsit_spec_diagram.py`; file draw.io có hai tab BLOCK_DIAGRAM và BLOCK_INFORMATION). Tên tín hiệu nội bộ bắt đầu bằng `w_` là tên tạm cho đến khi phân cấp RTL được chốt.
- [figures/chacha_fsm_msg.svg](figures/chacha_fsm_msg.svg) with its editable source [figures/chacha_fsm_msg.drawio](figures/chacha_fsm_msg.drawio) and FSM specification [figures/chacha_fsm_msg.json](figures/chacha_fsm_msg.json) — state diagram of the message sequencer (section 10.1). / Sơ đồ trạng thái của bộ điều phối thông điệp (mục 10.1).
- [figures/wf_001_encrypt.svg](figures/wf_001_encrypt.svg) to [figures/wf_020_block_pair_base.svg](figures/wf_020_block_pair_base.svg) — the 20 waveforms of the waveform plan of section 10.3 (`wf_*.json` WaveJSON sources beside the SVG renderings). They are specification sketches of intended behavior, not simulation results. / 17 waveform của kế hoạch waveform ở mục 10.3 (nguồn WaveJSON `wf_*.json` cạnh bản SVG). Đây là hình minh họa hành vi mong muốn theo đặc tả, không phải kết quả mô phỏng.
- `figures/` contains 22 rendered SVG assets and 20 waveform JSON sources. / `figures/` có 22 hình SVG đã render và 20 nguồn waveform JSON.

## Other important directories / Thư mục quan trọng khác

- No additional specification subdirectories are currently present. / Hiện không có thư mục con đặc tả quan trọng khác.

## Figure location rule / Quy tắc vị trí hình

All specification diagrams, FSM diagrams, waveform sources, and their renderings belong under `spec/figures/`. Keep the editable draw.io source together with its related renderings and source data. This README describes only the key artifacts; it does not claim that a design or verification flow has passed.

Mọi sơ đồ đặc tả, sơ đồ FSM, nguồn waveform và hình đã render phải nằm dưới `spec/figures/`. Đặt file draw.io có thể chỉnh sửa cạnh hình render và dữ liệu nguồn liên quan. README này chỉ mô tả tài liệu chính, không xác nhận design hay verification đã PASS.
