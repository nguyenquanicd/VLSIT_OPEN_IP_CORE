# Run report — review đặc tả DVP_Controller (2026-11-22)

## Đã review gì

- Đầu vào user nêu: thư mục `025_DVP_Controller/spec`. Thư mục có hai HDS cùng tên (baseline 21/11, 112 KB; bản approved `rtl_generation_2026-11-22`, 146 KB). User chọn bản approved; README gốc của IP cũng gọi bản này là approved. Baseline chỉ đọc để đối chiếu.
- Danh sách review (18 chương) dựng từ tính năng của spec và đã được user xác nhận, gồm cả web search cho phần thị trường.
- Đọc toàn bộ HDS approved, workbook CSR (JSON), README của IP và của gói spec, báo cáo generation, `verification/README.md`, log gap scan, `research/research_report.md` (đầu và bảng sensor), và bản APB đã chuyển đổi của skill micro-spec để xác minh điều khoản IHI 0024 Issue D.
- Chạy `vlsit_spec_inventory.py`, `vlsit_scorecard.py`, `vlsit_report_check.py`, `vlsit_review_report.py check`, `vlsit_review_gate.py metrics, sample, group`.

## Kết quả

- Verdict **Conditional**, điểm có trọng số 2,76 trên 5, không có Blocker.
- 31 finding (19 Major, 11 Minor, 1 Observation) trong 17 nhóm root cause; 30 finding là `fix`, 1 là `waive` (F-023).
- Gate PASS; checker của báo cáo song ngữ PASS; checker của báo cáo `vlsit_spec_2026-11-22.md` PASS.
- Audit 4 trên 31 finding (F-009, F-003, F-010, F-019): 4 tp, 0 fp, 0 fn ở vùng lân cận. Chỉ một reviewer làm audit nên con số fn chưa độc lập.

## Phần không làm được và cách xử lý

| Khoảng trống | Xử lý |
|---|---|
| RTL chưa chạy mô phỏng (theo chính `verification/README.md`) | Không kết luận RTL đúng; spec review chỉ dựa trên văn bản. Finding F-025 ghi nhận. |
| Không có thư viện Liberty và Yosys | Diện tích là proxy cấu trúc (khoảng 320 flop, bản mặc định) và gắn nhãn proxy. |
| Dữ liệu IP thương mại chỉ là tóm tắt web (ST AN5020 Rev 4, NXP MCUXpresso, Espressif docs), không mở reference manual | Bảng so sánh có nguồn và ngày; ô không xác nhận được ghi `not confirmed`. |
| Không đọc PDF datasheet trong `research/sources/` | Dựa vào research report; timing OV7670 lấy từ hình user cung cấp trong cuộc trò chuyện này. |
| Không đối chiếu RTL với spec | Việc đó thuộc skill `vlsit-ip-impl-review`. |

## Hạn chế của chính các script

- `vlsit_report_check.py` in lỗi chứa ký tự tiếng Việt thì lỗi mã hoá trên console cp1252 nếu chạy với `-I`; phải thêm `-X utf8`. Chưa sửa script của skill.
- `vlsit_review_report.py build --out` nhận một thư mục, không phải tên file.

## File

Tất cả nằm trong `025_DVP_Controller/review/`: `REVIEW_DVP_Controller.md` (báo cáo song ngữ), `vlsit_spec_2026-11-22.md` (finding kèm verdict và fix), `scorecard.json`, `scorecard.md`, `findings.json`, `gate_metrics.json`, `audit_sample.json`, `root_cause_groups.json`, `inventory.json`, `findings_checked.json`, `run_report.md`.
