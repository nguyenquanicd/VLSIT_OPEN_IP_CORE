# Phản hồi review 2026-11-22: kiểm chứng, phản biện và cải tiến verification

Người viết: AI agent (Claude), 2026-11-22. Không phải quyết định của người; mọi mục "cần quyết định" chờ spec owner.
Đầu vào: [vlsit_spec_2026-11-22.md](../../vlsit_spec_2026-11-22.md), [reproduction scripts](../../../verification/env/review_2026-11-22/), local replay archive `verification/sim/review_2026-11-22_repro.tar`, [reproduction test sources](../../../verification/tests/review_2026-11-22/), [fix snapshot](../../../archive/review__reference__2026-11-22__fix_snapshot.tar).
Lưu ý: review được làm trên mã lúc 03:47–03:53, trước các sửa BUG-040..043 (03:50–05:35) của phiên verification; người review đã tự sửa F-021 và NEP1/NHC trong `rtl/` lúc 07:10.

## 1. Kết luận ngắn

- **Đồng ý, lỗi RTL thật (đã có test tái hiện):** F-021, NEP1/NHC=16 (người review đã sửa), F-001 (lộ ra BUG-044 khi viết test race; đã sửa), F-020 (BUG-045; đã sửa), F-005 (mở rộng thành FND-015: UTMI+ không thoát suspend khi PHY dừng clock; **chưa sửa, cần quyết định**).
- **Đồng ý, lỗi SDC:** F-002 (đã sửa binding; chưa chạy STA).
- **Đồng ý một phần / phản biện:** F-019 (host đã tự phục hồi khi RxActive nhả, có test; watchdog chỉ giúp chẩn đoán), F-006 (RTL đúng theo thiết kế một bank `u2_dma_hi`; thiếu câu điều kiện trong HDS), F-003 (RTL nhận mọi burst theo ngữ nghĩa FIFO; cần chốt hợp đồng).
- **Đồng ý, mức tài liệu/sản phẩm (không thuộc phạm vi simulation):** F-004, F-007, F-008, F-010..F-018.
- **Vì sao verification bỏ sót:** (1) mọi build mô phỏng dùng số endpoint/kênh mặc định; (2) không kịch bản nào phản ứng tức thì với cờ rồi đọc giá trị liên quan; (3) checker CDC chỉ kiểm có cấu trúc crossing, không kiểm nguồn của synchronizer; (4) testbench không bao giờ dừng CLK-PHY khi SuspendM=0; (5) SDC không có kiểm tra pattern khớp đối tượng; (6) bin `cg_gap_host` đã được đánh dấu khi chưa có oracle (BUG-043, phiên trước).

## 2. Từng phát hiện

| ID | Kết luận | Bằng chứng (run/test) | Hành động |
|---|---|---|---|
| F-001 | Đúng (spec tự mâu thuẫn: REQ-REG-003/CDC-002/SVA-013 đòi tag, DEC-002 nói không dùng tag). Test race tìm thêm 2 lỗi thứ tự thật: done tới trước xsize cuối; đọc được ep_en=0 và active=0 cùng lúc sau re-arm | `t_dev_xreg_race` FAIL r2091 → BUG-044; PASS r2092–r2095, host r2096; mutant M24 killed | Sửa `m_usb2_xreg` (event/clear chờ 7 chu kỳ). Cần quyết định: làm tag thật hay viết lại REQ-REG-003 thành luật thứ tự mà test đang kiểm |
| F-002 | Đúng: 4 pattern Gray không khớp đối tượng; `set_clock_groups` vô hiệu `set_max_delay` | `check_sdc_objects.py` (t_static_sdc_bind) | Sửa `sdc/usb2_clocks.sdc`: max_delay datapath_only 2 chiều, bind reg_wgray/reg_rgray/reg_pop_gray_phy → u_sync_*. **Chưa chạy STA** |
| F-003 | Đúng một phần: RTL bỏ qua AWLEN>16, AWBURST, AxSIZE, WSTRB (ngữ nghĩa FIFO, ghi đủ row) | đọc `m_usb2_axs.sv` | Cần quyết định: SLVERR cho size hẹp/WRAP/len>16 hay ghi hợp đồng FIFO |
| F-004 | Đúng (REQ-FUNC-029/TEST-023 mâu thuẫn DEC-040) | HDS | Spec owner sửa REQ-FUNC-029 theo ring queue |
| F-005 | Đúng và nặng hơn: build UTMI+ **không thoát suspend** nếu PHY dừng CLKOUT (device treo khi host resume; host không thấy port_susp_sts và không resume được) | `t_dir_clkstop` FAIL r2108 (dev), r2109 (host); mô hình TB `PCLKA` | FND-015, tier open. Cần quyết định: (a) bắt buộc PHY giữ clock khi suspend, hoặc (b) thêm đường wake bất đồng bộ cho UTMI+ như DEC-022 của ULPI |
| F-006 | Phản biện một phần: mọi địa chỉ dùng chung `u2_dma_hi`, so 32 bit thấp là đủ nếu `u2_dma_hi` không đổi khi DMA bận | `m_usb2_dma.sv` (BUG-008) | Thêm câu điều kiện vào REQ-IF-014; test đổi bank khi bận còn mở |
| F-007, F-017 | Đúng (đơn vị depth và RAM port chưa thống nhất) | HDS | Spec owner: bảng cấu hình hợp lệ duy nhất |
| F-008, F-011..F-014, F-018 | Đúng, mức sản phẩm/vật lý; ngoài phạm vi simulation | — | Không đổi |
| F-009 | Đúng một phần: số liệu đã cũ (nay 206/211 bin, 22/24 mutant) nhưng bin vẫn là marker, chưa đo FSM coverage | `sim/docs/verification_report.md` | Giữ nguyên nhận xét |
| F-010, F-015, F-016 | Đúng (hợp đồng driver, PHY bring-up, trạng thái bằng chứng) | HDS | Spec owner |
| F-019 | Phản biện: khi RxActive nhả, host không ACK, báo xact_err, retry và chỉ lưu gói tốt; khi RxActive kẹt mãi thì UTMI+ cấm mọi link phát, watchdog không khôi phục được traffic | `t_host_edge` rxhold PASS r2105 (lệnh TB `RXH`) | Watchdog chẩn đoán là tùy chọn |
| F-020 | Đúng | `check_sync_src.py`: 1 vi phạm trên mã cũ, 0/18 trên mã mới | BUG-045, Gray được chốt bằng register |
| F-021 + NEP1/NHC | Đúng (người review đã sửa) | `t_dir_param_max` r2097–r2100; `check_param_slice.py`: 14 vi phạm trên `fix_snapshot`, 0 hiện tại; mutant M21–M23 killed | Đã thêm build 16 endpoint/16 channel/16 window |

## 3. Cải tiến verification đã làm

| Lớp lỗi | Kiểm tra mới | Đã chứng minh bắt được |
|---|---|---|
| Cắt bit tham số `PARA_X[h:0]` | `scripts/check_param_slice.py` (tĩnh, smoke) | 14 vị trí trên mã cũ |
| Cấu hình biên | build `dev_utmi8_axim_epmax`, `host_utmi8_axim_hcmax_ts16`, `dev_utmi8_axis_ch16/ch15`; `gen_dir_last_index.py` kiểm hiệu ứng ở CLK-PHY, không chỉ readback APB | M21–M23 |
| Synchronizer có logic tổ hợp phía trước | `scripts/check_sync_src.py` (lần theo rename và output của instance con) | F-020 trên mã cũ |
| Pattern SDC rỗng, exception bị clock group nuốt | `scripts/check_sdc_objects.py` | 4 pattern của F-002 |
| Race thứ tự CDC thanh ghi | `gen_dev_xreg_race.py`, `gen_host_xreg_race.py` (32 vòng, 4 tần số CLK-BUS, pha scanner ngẫu nhiên; lệnh TB `RANY`) | BUG-044, M24 |
| PHY dừng clock khi suspend | lệnh TB `PCLKA`, `gen_dir_clkstop.py`, kiểm pha SOF (`SOFT`/`SOFQ`) | FND-015 |
| PHY giữ RxActive | lệnh TB `RXH`, `gen_host_edge.py rxhold` | hành vi phục hồi |
| Checker tĩnh vào regression | `run.py static`, kind `static` trong `testlist.csv` | 4 run smoke PASS |

## 4. Trạng thái sau cùng

- Regression đầy đủ `sim/runs/regress_full_11.log` (từ r2114): 188 run, 187 PASS; r2232 không sinh log (lỗi hạ tầng), chạy lại r2327 PASS.
- Mutation `sim/coverage/mutation_report.md`: 22/24 killed (M08, M09 sống như trước).
- vplan: 122 passing, 5 implemented; bins 206/211 (còn `cg_lpbk.bad` và 4 bin review).
- Rule check RTL PASS (0 ERROR; 1 dòng comment quá 100 ký tự trong phần sửa F-021 của người review đã được ngắt dòng, chỉ comment); lint 2 wrapper PASS (0 error).
- Chưa làm: STA cho SDC mới, quyết định FND-015/F-001/F-003, sửa HDS (F-004, F-006, F-007, F-017).

## 5. Đề nghị cho vòng review độc lập tiếp theo

Nên tập trung vào những chỗ verification hiện vẫn yếu: (1) các register được hardware publish khác (`hc_cfg`, `lpbk_sts`, `phy_acc`) dưới race; (2) cấu hình UTMI+ 16-bit và PIPE ở số kênh tối đa; (3) ULPI host với AXI-slave (chưa có build); (4) đổi `u2_dma_hi` khi DMA bận; (5) hành vi AXI4 ngoài profile.
