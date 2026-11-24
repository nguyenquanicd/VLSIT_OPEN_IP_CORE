# Nhật ký review USB 2.0 Controller

- **Ngày** 2026-11-22. **Input** HDS Draft 0.1 ở thư mục gốc, nguồn làm việc trên Git base `95a85f5`.
- **Phạm vi** Host/Device, UTMI+/ULPI, APB4, AXI4 Manager/Subordinate, FIFO/DMA, reset và crossing, ASIC/DFT, driver, performance và verification.
- **Kết quả** 2,10/5 (Conditional). Gate tích hợp FAIL với ba Blocker và 0 waiver. Có 21 phát hiện trong 20 nhóm nguyên nhân. Báo cáo ngày 20/11 được giữ trong thư mục cha.
- **Bằng chứng** HDS, CSR workbook và metadata, SDC, RTL ở các điểm truy vết, báo cáo mapping và verification hiện có. [Phụ lục của bản review đầy đủ](../../REVIEW_USB20_CONTROLLER_2026-11-22.md#21-evidence-appendix--phụ-lục-bằng-chứng).
- **Giới hạn** Bản review chưa đo lại RTL, coverage, timing hoặc công suất. Độ chính xác của bảng ULPI chuyển đổi và đối chiếu clause-level của Phase-locked SOF ECN còn mở. Không dùng kết quả mapping typical của FreePDK45 để ký duyệt target công nghệ.
- **Kiểm tra tài liệu** Inventory, scorecard, kiểm tra cấu trúc song ngữ, kiểm tra báo cáo theo ngày, metrics, sample và group. Mẫu 3/21 được cùng người review đối chiếu lượt hai. Tỷ lệ false-negative chưa đo.
