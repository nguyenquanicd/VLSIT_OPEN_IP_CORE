# Báo cáo lần chạy: rà soát spec ChaCha20-Poly1305

Ngày chạy: 2026-11-24. Spec được rà soát: `spec/VLSIT_CHACHA_HDS.md` (bản nháp 0.1).

## Đầu vào và phạm vi

- Đã đọc cả thư mục IP: spec, workbook CSR (xlsx và json), 14 hình SVG và 12 nguồn WaveJSON, báo cáo research và manifest, các thư mục placeholder (`rtl`, `verification`, `sdc`, `lint`, `cdc`, `rdc`, `syn`).
- Danh sách rà soát do người dùng xác nhận với phương án 1B (rút gọn, bỏ mục DFT riêng khỏi danh sách đề xuất ban đầu nhưng vẫn chấm vì checker bắt buộc chương DFT), nguồn so sánh 2A (bộ nguồn research cộng web), nơi lưu 3A (`review/`).
- Inventory: 60 mục, 45 bảng, 39 requirement, 24 test, 18 thuộc tính (SVA và COV), 38 mục mở, 0 requirement thiếu test.

## Kết quả

- 30 finding: 0 Blocker, 16 Major, 8 Minor, 6 Observation (thang cổng kiểm: Critical 0, High 16, Medium 8, Low 6).
- Điểm có trọng số 3,00 trên 5, kết luận **Conditional**. Ba khu vực thấp nhất (điểm 2): interfaces, sdc_timing, dft, security_ras (bốn khu vực cùng điểm 2).
- Cổng kiểm: `RESULT: PASS, 30 finding(s)`; hai waiver (F-003 và F-024) trong ngân sách 10; closure rate 93 phần trăm; sampling 57 phần trăm.
- Mẫu kiểm toán 3 trên 30 (F-009, F-003, F-010): cả ba là `tp`; không tìm thấy false negative trong mẫu, nhưng đó chỉ là cận dưới vì người rà soát là tác giả của spec.

## Kiểm tra đã chạy

| Lệnh | Kết quả |
|---|---|
| `vlsit_spec_inventory.py` | 39 requirement, 24 test, 18 thuộc tính, 38 mục mở |
| `vlsit_scorecard.py` | PASS, 3,00, Conditional |
| `vlsit_report_check.py REVIEW_CHACHA.md` | PASS, 21 chương, 36 dòng finding (30 finding, 6 dòng lặp ở bảng top) |
| `vlsit_review_report.py check vlsit_spec_2026-11-24.md` | PASS, fix 28, waive 2 |
| `vlsit_review_gate.py metrics, sample, group` | PASS, mẫu 3 finding, 10 nhóm nguyên nhân gốc |

## Chưa đánh giá được

- RTL, SDC, mô phỏng, diện tích mapped, công suất và tần số: chưa tồn tại.
- So sánh thương mại: chỉ dùng nguồn của báo cáo research (7 trên 10 họ sản phẩm, 3 trên 10 bài báo, lưu ngày 2026-11-22); không tìm web mới; datasheet Rambus CH-7xx không có.
- AXI4: bản chuyển đổi từ PDF của người dùng có 53 trang lệch hơn 5 phần trăm số từ; chỉ dùng câu trong văn bản thường.
- Độc lập: người rà soát và tác giả spec là cùng một người, nên cần một rà soát độc lập trước khi chốt.

## Cách xử lý khoảng trống

- Số liệu thương mại không có nguồn được gắn nhãn INFERENCE; không có số đối thủ nào được nêu mà thiếu nguồn và ngày.
- Mọi finding có locator, nhãn FACT hoặc INFERENCE, mức nghiêm trọng và verdict.
- Theo luật R-022, 17 finding được truy vết sâu (tối đa mười mỗi nhóm), 13 finding còn lại gộp theo nguyên nhân gốc; chưa phân tích sâu thêm khi chưa hỏi người dùng.

## File

- `REVIEW_CHACHA.md`: báo cáo song ngữ, 21 chương.
- `vlsit_spec_2026-11-24.md`: báo cáo cuối có assessment, verdict và đề xuất sửa cho từng finding, cổng kiểm và mẫu kiểm toán.
- `reference/`: `inventory.json`, `scorecard.json`, `scorecard.md`, `findings.json`, `gate_findings.json`, `gate_metrics.json`, `gate_audit.json`, `gate_groups.json`.

## Cập nhật sau khi xử lý finding

- Các finding đã được xử lý ở mức đặc tả ngày 2026-11-24; bảng đối chiếu từng finding nằm trong `closure_2026-11-24.md`. Điểm số và kết quả cổng kiểm ở trên mô tả trạng thái trước khi sửa và chưa được tính lại; vẫn cần một rà soát độc lập.
