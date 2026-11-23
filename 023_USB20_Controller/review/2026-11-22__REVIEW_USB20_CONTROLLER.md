# USB 2.0 Controller specification review / Đánh giá đặc tả USB 2.0 Controller

| Field / Trường | Value / Giá trị |
|---|---|
| Design | USB 2.0 Controller |
| Specification | [../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md](../spec/../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md), Draft 0.1 |
| Review date | 2026-11-22 |
| Source basis | Workspace contents over Git base `95a85f5`, including local HDS and RTL changes |
| Score and verdict | 2.10 / 5 · Conditional |
| Release gate | **FAIL** · 3 unwaived Blockers, 0 waivers |

## 1. Executive summary / Tóm tắt

**EN.** FACT — The design defines a configurable Universal Serial Bus (USB) 2.0 controller for a camera host and companion device. It includes Advanced Peripheral Bus (APB4) control, Advanced eXtensible Interface (AXI4) Direct Memory Access (DMA), and selectable PHY transports. INFERENCE — Continue engineering and prototype work. Integration approval depends on resolving the stale Control and Status Register (CSR) update path, binding the clock crossing constraints, and defining the restricted AXI4 Subordinate interface. Close those items before expanding the workload matrix. The retained test report records remaining coverage and interoperability gaps.

**VI.** FACT — Thiết kế là USB 2.0 Controller cấu hình được cho Host camera và Device companion, có APB4, AXI4 DMA và chọn giao diện PHY. INFERENCE — Có thể tiếp tục làm prototype. Cổng tích hợp chưa đạt vì đường cập nhật CSR cũ, constraint crossing chưa bind đúng và hợp đồng AXI4 Subordinate chưa chốt. Ưu tiên ba mục này trước khi mở rộng ma trận workload.

FACT — Scope derives from HDS §§1–20. It covers host/device protocol and PHY interoperability, APB4 and both AXI roles, reset and crossings, buffering and throughput, DMA/software, Application-Specific Integrated Circuit (ASIC) implementation and Design for Test (DFT), and verification evidence. A single current root HDS was identified. The older `rtl_gen/backup` HDS is historical.

## 2. Scorecard / Bảng điểm

**EN.** INFERENCE — Clock, reset and Clock-Domain Crossing (CDC) and Synopsys Design Constraints (SDC) are the lowest scoring areas. Interface Blocker F-003 applies to the claimed integration profile even though restricted AXI traffic has been exercised.

**VI.** INFERENCE — Clock/reset/CDC và SDC có điểm thấp nhất. F-003 chặn profile tích hợp dù đã mô phỏng traffic AXI trong phạm vi hẹp.

[Sourced scores and weighted result](reference/2026-11-22/scorecard.md).

## 3. Application fit / Phù hợp ứng dụng

**EN.** INFERENCE — Drone product operating point is still a proposal. Score 3/5.

**VI.** INFERENCE — Operating point của sản phẩm drone còn ở mức đề xuất. Điểm 3/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-014 | Major | §1.2–1.4 FEAT-012/016/021, §13 PERF-001 | INFERENCE — **Drone product operating point is still a proposal.** Host camera and Device companion use cases fit the proposed partition. Camera resolution, format, compression, frame-loss tolerance and AXI service assumptions require a product owner. A power-triggered loss of the camera link also needs defined system impact. | INFERENCE — **Operating point của sản phẩm drone còn ở mức đề xuất.** Cấu hình phù hợp hướng camera Host và companion Device. Cần chủ sản phẩm chốt resolution, format, nén, frame loss, điều kiện AXI và tác động khi mất link. | fix · Select a first release configuration and quantify camera traffic, acceptable dropped frames, CPU servicing load and over-current recovery. |

## 4. Features / Tính năng

**EN.** INFERENCE — Double buffering has incompatible software contracts. Score 2/5.

**VI.** INFERENCE — Double buffering có hai hợp đồng software mâu thuẫn. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-004 | Major | §3 REQ-FUNC-029, §8, §10.4, §15.2 TEST-023, §20 DEC-040 | FACT — **Double buffering has incompatible software contracts.** REQ-FUNC-029 and TEST-023 require an enable-controlled two-buffer swap and buf_cur. DEC-040 documents ordinary ring capacity and informational fields with no dedicated swap. A driver following either description can make a different ownership decision. | FACT — **Double buffering có hai hợp đồng software mâu thuẫn.** REQ-FUNC-029 và TEST-023 yêu cầu đổi hai buffer và cập nhật buf_cur. DEC-040 mô tả ring FIFO và các field mang tính thông tin. Driver có thể hiểu sai quyền sở hữu buffer. | fix · Make ring queue overlap the single contract or implement the explicitly controlled feature. For the ring contract, define packet enqueue, dequeue and credits and mark each legacy field reserved or informational in the workbook. |

## 5. Functions and cycle behaviour / Hành vi theo chu kỳ

**EN.** INFERENCE — SOF phase cannot be guaranteed when its clock stops. Score 2/5.

**VI.** INFERENCE — Không bảo đảm pha SOF khi clock của bộ đếm dừng. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-005 | Major | §3 REQ-FUNC-037, §7.4, §15.2 TEST-034 | INFERENCE — **SOF phase cannot be guaranteed when its clock stops.** The HDS requires the Start of Frame (SOF) timebase to continue across host suspend/L1. It also permits PHY clock stop without stating a host exception. The RTL timer uses i_clk_phy. A legal stopped-clock scenario under the written contract cannot advance it. | INFERENCE — **Không bảo đảm pha SOF khi clock của bộ đếm dừng.** HDS yêu cầu timebase SOF chạy xuyên suspend/L1 của Host và cho phép dừng CLK-PHY mà chưa nêu ngoại lệ Host. RTL đếm theo i_clk_phy, nên không thể tiến khi clock dừng. | fix · Separate the free-running timebase from transmit eligibility. Keep an appropriate Host PHY clock running or move the phase to an always-on timebase with a defined resynchronization tolerance. |
| F-019 | Major | §12 ERR-003/005, §20 DEC-043/046 | INFERENCE — **Host data phase has no independent completion watchdog.** The response-start timeout is disabled once reception starts. Current next-state branches depend on packet end or a decoded handshake. If a PHY supplies a persistent active indication without a terminator, no bounded return to scheduling is established. This is a recovery issue distinct from the hub end-of-frame rule. | INFERENCE — **Host thiếu watchdog độc lập cho data phase.** Timeout chờ bắt đầu phản hồi dừng sau khi nhận dữ liệu. Nếu PHY giữ active mãi thì chưa có đường quay lại scheduler có giới hạn. Đây là vấn đề recovery riêng với yêu cầu hub. | fix · Add a separate receive-duration watchdog derived from speed, packet size and PHY tolerance. On expiry halt the affected channel, discard uncommitted rows and expose sticky diagnostics. |

## 6. Interfaces and protocol / Giao diện và giao thức

**EN.** INFERENCE — AXI3 reference cannot establish the AXI4 subordinate contract. Score 2/5.

**VI.** INFERENCE — Tham chiếu AXI3 chưa đủ để chốt AXI4 Subordinate. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-003 | Blocker | §2.1–2.3 REF-010, §6.2–6.3 REQ-IF-006/007 | FACT — **AXI3 reference cannot establish the AXI4 subordinate contract.** The HDS calls both interfaces AXI4 while citing AXI3 as its normative text. A Manager can limit what it issues to 16-beat INCR bursts. An interconnect can present valid AXI4 requests outside the FIFO window profile, so the Subordinate boundary needs a supported traffic contract and complete beat/response semantics. | FACT — **Tham chiếu AXI3 chưa đủ để chốt AXI4 Subordinate.** HDS gọi hai cổng là AXI4 nhưng dùng AXI3 làm chuẩn. Manager có thể giới hạn burst do mình phát. Subordinate cần quy định rõ traffic do fabric đưa tới, cách xử lý số beat và response ngoài profile FIFO. | fix · Pin Arm IHI 0022H AXI4 clauses. Declare the integration profile, excluded attributes, fabric restrictions and defined response/side-effect policy for unsupported legal requests. Add RTL support or integration restrictions where necessary. |

| Interface and source | HDS locus | Assessment |
|---|---|---|
| [USB 2.0 Rev. 2.0 and ECNs](https://www.usb.org/document-library/usb-20-specification), §5.9.2 and §7.1.18.2 | §3 REQ-FUNC-006/009/014, §13 | FACT — HS turnaround at the connector and high bandwidth isochronous PID sequencing are specified. INFERENCE — contract aligned in scope. PHY delay and combinations of pipeline options still require measured validation. |
| [USB 2.0 bundle](https://www.usb.org/document-library/usb-20-specification), LPM ECN §§2.2.2, 4.1.1 | §3 REQ-FUNC-021, §20 DEC-016/TBD-014 | FACT — HDS defines the LPM token and initial outcomes. INFERENCE — retry for a corrupted/lost handshake within TL1TokenRetry and the detailed timing table are not fully stated in the requirement. Keep LPM qualification open. |
| USB 2.0 Phase-locked SOFs ECN, HDS-selected 2024-09-27 bundle | §3 REQ-FUNC-037, §7.4, TEST-034 | FACT — the HDS declares the ECN applicable. INFERENCE — the requirement and the allowed stopped-clock scenario cannot both be guaranteed by the documented PHY timer. Clause-by-clause comparison for this ECN remains open. |
| UTMI+ 1.0 §2.1.1.5, UTMI 1.05 §6.4, REF-006 local conversions | §6.2–6.3, §13 PERF-002 | FACT — the specified transport is 8/16-bit UTMI+ with mode and turnaround requirements. INFERENCE — PHY-specific electrical timing remains unsupported by the evidence. |
| ULPI 1.1 §§3.9.1–3.9.3 and Tables 5/10, REF-007 local conversion | REQ-IF-003/011, §17.1.2 | FACT — the HDS specifies PHY-clock mode and low-power operation. INFERENCE — digital profile is stated. Timing-table conversion and real PHY trace remain open. |
| Arm [IHI 0024D](https://developer.arm.com/documentation/ihi0024/d/) §§3.1–3.4, 4.1, Appendix A, APB4 signal set | REQ-IF-005, §11.4, DEC-030 | FACT — PSTRB masking and access phase are specified. INFERENCE — documented behavior aligns with selected clauses. Prove sparse-write side effects through CSR crossing and PREADY/PSLVERR at completion. |
| Arm [IHI 0022H](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf), §§A3.2–A3.4.1 | REQ-IF-006/007, §2.3 REF-010 | FACT — V/R rules and the 4 KiB boundary apply. AXI4 INCR supports a wider length range than AXI3. INFERENCE — correct the normative reference and scope qualification to a defined restricted Subordinate profile (F-003). |
| On-The-Go and Embedded Host Supplement Rev. 2.0 v1.1a, REF-002 | §2.1 and §2.3 | FACT — the HDS excludes HNP, SRP and ADP and describes ID-based role selection. INFERENCE — full OTG conformance remains unsupported by this restricted profile and the supplied evidence. |

**VI.** FACT — HDS có hợp đồng UTMI+/ULPI, APB4 và AXI, cùng cơ chế High-Speed turnaround. INFERENCE — Hợp đồng AXI4 Subordinate, LPM retry và timing PHY cần bằng chứng bổ sung. USB-IF đánh giá functional, electrical và interoperability trên sản phẩm với PHY thực. [USB-IF USB 2.0 compliance program](https://www.usb.org/usb2).

## 7. Clock, reset and CDC / Clock, reset và CDC

**EN.** INFERENCE — CSR stale update protection missing. Score 1/5.

**VI.** INFERENCE — Thiếu cơ chế chặn cập nhật CSR cũ. Điểm 1/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-001 | Blocker | §7.2 CDC-002, §11.3 REQ-REG-003 | FACT — **CSR stale update protection missing.** The HDS requires a per-register generation comparison. The return entry carries a scanner sequence that increments on update pushes. The receive interface discards its tag and the load path decodes enable, kind and slot only. INFERENCE — An earlier hardware update can overwrite a later software value or clear a newly issued command. | FACT — **Thiếu cơ chế chặn cập nhật CSR cũ.** HDS yêu cầu so sánh generation theo thanh ghi. Entry trả về mang sequence của scanner và đường load chỉ dùng enable, kind, slot. INFERENCE — Update cũ có thể ghi đè giá trị software mới hoặc xóa command vừa phát. | fix · Transport the accepted software generation per slot to the PHY and echo it on returned updates. Compare at conditional load, define simultaneous writes and W1C events separately, and prevent tag reuse until stale entries are impossible. |
| F-020 | Major | §7.2 CDC-001, §11.3 REQ-REG-002 | FACT — **Command credit Gray value crosses from a combinational encoder.** The command credit pop count is registered in CLK-PHY, converted combinationally to Gray and then synchronized. INFERENCE — Skew from simultaneously switching binary bits can glitch the encoded Gray vector. The FIFO full check adds protection against overfill while software-visible credits can still be disturbed. | FACT — **Gray của bộ đếm credit đi qua encoder tổ hợp.** Pop count được chốt trong CLK-PHY rồi mã hóa Gray tổ hợp trước synchronizer. INFERENCE — Các bit binary đổi cùng cạnh có thể tạo glitch. Cờ full chặn overfill nhưng giá trị credit software vẫn có thể bị nhiễu. | fix · Register Gray from the next binary value in CLK-PHY and constrain the registered crossing. Recheck credit behavior across independent clock ratios and soft reset. |

## 8. Parameters and data / Tham số và dữ liệu

**EN.** INFERENCE — RAM organization and legal width combinations conflict. Score 2/5 and 3/5.

**VI.** INFERENCE — Tổ chức RAM và tổ hợp width hợp lệ chưa đồng nhất. Điểm 2/5 và 3/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-007 | Major | §8, §10.4–10.5, §17.2, §20 DEC-006/010/041 | FACT — **RAM organization and legal width combinations conflict.** Sections 10.4, 10.5 and 17.2 require a single-port RAM, while DEC-006 selects 1W1R by default with single port optional. The independent AXI width rows do not expose the UTMI-to-AXI coupling in DEC-010. A separately valid width choice can yield an unsupported configuration. | FACT — **Tổ chức RAM và tổ hợp width hợp lệ chưa đồng nhất.** Mục 10.4, 10.5, 17.2 quy định RAM 1 port, DEC-006 chọn 1W1R mặc định. Bảng AXI width chưa phản ánh quan hệ cố định với UTMI width ở DEC-010. | fix · Publish one legal matrix including RAM ports, word units, clock, width coupling and profile parameters. Derive guards and memory manifests from that matrix. |
| F-017 | Major | §8, §9, §10.5 | FACT — **FIFO capacity alternates between 32-bit words and physical rows.** The parameter table says depth in 32-bit words while MEM-001 multiplies the depth by a 32- or 64-bit physical row width. The same numeric depth can mean 4 KiB or 8 KiB at 1024 depending on the interpretation. The workbook and driver need the same unit for region and threshold fields. | FACT — **Dung lượng FIFO đang dùng lẫn word 32 bit và row vật lý.** Bảng parameter dùng đơn vị word 32 bit, MEM-001 nhân với row 32/64 bit. Depth 1024 có thể được hiểu là 4 KiB hoặc 8 KiB. Workbook và driver cần thống nhất đơn vị. | fix · Publish the exact unit of each pointer, length, credit and threshold, and rounding rules for tail bytes and 64-bit packing. Derive legal region ends from physical depth. |
| F-021 | Major | §8 PARA_USB2_NUM_DMA_CH, §6.3 REQ-IF-007/009 | FACT — **The 16-channel AXI window build rejects every request.** The HDS permits 1 to 16 DMA channels. Both address checks compare a four-bit channel index with PARA_USB2_NUM_DMA_CH[3:0]. At 16 the sliced count becomes zero, so no channel is accepted for AXI reads or writes. | FACT — **Cấu hình 16 kênh AXI window từ chối mọi request.** HDS cho phép 1–16 kênh. Hai phép so sánh đọc/ghi cắt số lượng còn 4 bit. Giá trị 16 thành 0 nên mọi channel bị từ chối. | fix · Compare zero-extended channel indices against the full parameter and guard map indexing using the same bound. Enforce the legal channel range in the configuration check. |

## 9. ASIC feasibility / Khả thi ASIC

**EN.** INFERENCE — FreePDK45 estimate leaves macro and timing implementation open. Score 2/5.

**VI.** INFERENCE — Ước tính FreePDK45 chưa chốt macro và timing thực tế. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-011 | Major | §10.5 MEM-001, §14.3, §17.2, §20 DEC-034/035 | INFERENCE — **FreePDK45 estimate leaves macro and timing implementation open.** The existing typical-corner mapping is useful for logic sizing. The report excludes FIFO RAM, interconnect load, clock tree and I/O budgets. It leaves memory latency/collision behavior and product setup/hold feasibility open. | INFERENCE — **Ước tính FreePDK45 chưa chốt macro và timing thực tế.** Mapping typical corner dùng để ước tính logic. Báo cáo loại RAM FIFO, tải dây, clock tree và I/O. Cần chốt hành vi macro và setup/hold của sản phẩm. | fix · Qualify the actual SRAM model and macro views for selected widths, ports and collision behavior. Run target multi-corner static timing with I/O, reset recovery/removal and applicable clock modes. |

## 10. SDC and timing / SDC và timing

**EN.** INFERENCE — CDC constraints do not identify the actual Gray endpoints. Score 1/5.

**VI.** INFERENCE — SDC chưa trỏ đúng các điểm đầu cuối Gray. Điểm 1/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-002 | Blocker | §7.2 CDC-001/002/004/007, §17.1.3 EXC-001/002 | FACT — **CDC constraints do not identify the actual Gray endpoints.** Pointer selectors use gray_ptr and gray_sync patterns while the reused FIFO uses reg_rgray and u_sync_wr_gray. The clock group cuts both directions and the ULPI input exception needs to remain scoped to its asynchronous receivers. INFERENCE — STA may report clean timing while intended Gray constraints have no effective endpoints. | FACT — **SDC chưa trỏ đúng các điểm đầu cuối Gray.** Pattern gray_ptr/gray_sync không khớp tên RTL được truy vết. Clock group cắt hai chiều và ULPI vẫn có đường nhận đồng bộ. INFERENCE — Báo cáo STA có thể sạch trong khi constraint Gray không hữu hiệu. | fix · Bind actual registered launch Q and first synchronizer D pins, assert nonzero counts and expected bit widths, and use target-tool exception precedence and skew reporting. Keep functional ULPI pin timing active. |

## 11. Area and power / Diện tích và công suất

**EN.** INFERENCE — Storage and mapped logic are available but product power is open. Score 3/5.

**VI.** INFERENCE — Có số storage và mapped logic, công suất sản phẩm còn mở. Điểm 3/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-012 | Minor | §13 area/power, §20 DEC-034 | FACT — **Storage and mapped logic are available but product power is open.** At depth 1024, parity-enabled storage is 33,792 bits at 32-bit rows or 66,560 bits at 64-bit rows, assuming depth counts physical rows per MEM-001. Typical FreePDK45 logic mapping is 119,263 µm² for TOP-MIN-OPT0 and 315,036 µm² for TOP-DUAL-OPT0 excluding FIFO RAM. The HDS gives activity assumptions without a measured power budget. | FACT — **Có số storage và mapped logic, công suất sản phẩm còn mở.** Ở 1024 row, storage có parity là 33.792 hoặc 66.560 bit, giả sử depth tính theo row vật lý. Mapping typical FreePDK45 cho hai cấu hình là 119.263 và 315.036 µm², chưa tính RAM. HDS còn thiếu power budget đã đo. | fix · State the physical row unit and collect switching activity for sustained video, bulk, idle and suspend and include PHY, SRAM and clock tree in the budget. |

## 12. Performance and throughput / Hiệu năng và thông lượng

**EN.** INFERENCE — Throughput has a no-stall premise and no product margin. Score 2/5.

**VI.** INFERENCE — Thông lượng giả định không stall và chưa có margin sản phẩm. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-008 | Major | §13 PERF-001/002, §15.2 TEST-017, §20 DEC-025/032 | INFERENCE — **Throughput has a no-stall premise and no product margin.** Three 1024-byte transactions in 125 us yield 24.576 MB/s of protocol payload. TEST-017 targets this in a best-case interconnect. Raw PHY capacity of 60 MB/s and raw RAM capacity of 240 MB/s are structural ceilings. Service stalls, arbitration, packet overhead and optional stages need distinct acceptance budgets. | INFERENCE — **Thông lượng giả định không stall và chưa có margin sản phẩm.** Ba giao dịch 1024 byte mỗi 125 µs cho 24,576 MB/s payload. TEST-017 giả định interconnect lý tưởng. 60 MB/s PHY và 240 MB/s RAM chỉ là trần. Stall, arbitration, overhead và pipeline cần budget riêng. | fix · Specify camera bitrate/transport assumptions, worst supported AXI service gap, queue occupancy and lost-microframe limit. Verify the separate 4-cycle UTMI+ 16-bit response bound at worst enabled pipeline combinations. |

## 13. Software and application ease / Software và ứng dụng

**EN.** INFERENCE — Scatter-gather interrupt estimate exceeds the programmed feature set. Score 2/5.

**VI.** INFERENCE — Ước tính interrupt scatter-gather vượt hợp đồng hiện có. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-010 | Major | §1.4 FEAT-023, §9, §11.5, §20 DEC-013/039/042 | FACT — **Scatter-gather interrupt estimate exceeds the programmed feature set.** FEAT-023 estimates about 375 interrupts/s using a 64 KB list at 24.576 MB/s. The descriptor preserves last and ioc without interpreting them and endpoint/channel interrupt semantics remain. The list-level rate has no specified mechanism. Generated register comments also retain old window direction according to DEC-039. | FACT — **Ước tính interrupt scatter-gather vượt hợp đồng hiện có.** FEAT-023 dự tính 375 interrupt/s cho list 64 KB. Hardware không xử lý last/ioc. Cơ chế giảm interrupt chưa được quy định. DEC-039 ghi comment CSR đã sinh còn nghĩa direction cũ. | fix · Remove the list-level interrupt claim or implement coalescing/list termination with defined writeback order. Pin the CSR generator including its event sideband, regenerate, and publish a driver sequence for PSTRB, barriers, cache maintenance, re-arm and error recovery. |

## 14. DFT / Khả năng kiểm thử sản xuất

**EN.** INFERENCE — DFT responsibilities are named without insertion evidence. Score 3/5.

**VI.** INFERENCE — Đã phân trách nhiệm DFT, còn thiếu kết quả insertion. Điểm 3/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-013 | Minor | §16, §17.2, DEP-004 | FACT — **DFT responsibilities are named without insertion evidence.** The HDS assigns scan clocks and RAM memory built-in self-test to the System on Chip team and describes test reset override. The reviewed evidence does not provide a selected macro test interface, scan reset truth table or automatic test pattern generation results. | FACT — **Đã phân trách nhiệm DFT, còn thiếu kết quả insertion.** HDS giao scan clock và memory built-in self-test cho SoC và có reset override. Hồ sơ chưa có interface macro test, bảng reset trong scan hay kết quả ATPG. | fix · Confirm macro and scan test-pin handoff with a mode/reset truth table. Bind the bypass and reset overrides and require ATPG and memory test reports. |

## 15. Security and RAS / Bảo mật và độ tin cậy

**EN.** INFERENCE — DMA range comparison uses a low-word aperture. Score 2/5.

**VI.** INFERENCE — DMA kiểm tra vùng bằng phần địa chỉ thấp. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-006 | Major | §3 REQ-IF-014, §8, §18, TEST-035 | FACT — **DMA range comparison uses a low-word aperture.** The 40- and 64-bit Manager configurations assemble addresses using i_dma_hi, while range comparisons use low 32-bit values and lengths. The design can use a bank-local aperture if software locks the bank and the HDS says so. The current generic range wording leaves the high bits outside the stated policy. | FACT — **DMA kiểm tra vùng bằng phần địa chỉ thấp.** Profile 40/64-bit ghép địa chỉ với i_dma_hi nhưng kiểm tra 32 bit thấp và độ dài. Có thể dùng cửa sổ theo bank nếu khóa bank và ghi rõ. Cách viết hiện tại chưa mô tả giới hạn bit cao. | fix · Define a full-width aperture with overflow-safe arithmetic or document and enforce a locked high-address bank. Validate descriptor fetch, writeback and payload ranges including every enabled lane before issuing AXI. |

## 16. Verification quality / Chất lượng kiểm chứng

**EN.** INFERENCE — Traceability is present but closure is incomplete. Score 2/5.

**VI.** INFERENCE — Có traceability nhưng chưa đạt closure. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-009 | Major | §15.3–15.4, §19, REQ-VER-003 | FACT — **Traceability is present but closure is incomplete.** All 75 extracted requirements map to tests. The latest retained report gives 184/211 stimulus markers, no measured finite state machine coverage and 14/16 mutants killed. Its directed tests and bounded formal results support selected cases. The only ULPI Subordinate simulation covers Device in three scenarios. | FACT — **Có traceability nhưng chưa đạt closure.** 75 yêu cầu có test liên kết. Báo cáo giữ lại 184/211 stimulus marker, FSM coverage chưa đo và diệt 14/16 mutant. ULPI Subordinate mới có ba kịch bản Device. | fix · Require DUT-observed coverage for critical bins, pin source hashes for each build, reopen uncovered or waived cases explicitly and keep protocol, formal and certification evidence separate. |

## 17. Documentation and traceability / Tài liệu và truy vết

**EN.** INFERENCE — The release-status language mixes incompatible evidence. Score 3/5.

**VI.** INFERENCE — Trạng thái tài liệu trộn các mức bằng chứng. Điểm 3/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-016 | Major | Front matter, §15, §19, §20 TBD-016 | FACT — **The release-status language mixes incompatible evidence.** The root HDS remains Draft 0.1. TBD-016 says no ASIC library or formal tool was run and says every feature is implemented and simulated. Later mapped logic and bounded formal reports exist, while the verification report shows open closure. An integrator cannot infer a unique qualification baseline from these statements. | FACT — **Trạng thái tài liệu trộn các mức bằng chứng.** HDS vẫn Draft 0.1. TBD-016 nói chưa chạy ASIC library/formal và mọi feature đã mô phỏng. Hồ sơ có logic mapping và bounded formal sau đó, đồng thời còn gap closure. | fix · Create one versioned evidence ledger for accepted requirements, options, RTL hash, methods, results and approval state. Update historical decision notes with links to the superseding evidence. |

## 18. Integration effort and bring-up / Tích hợp và bring-up

**EN.** INFERENCE — PHY bring-up depends on unresolved vendor timing. Score 2/5.

**VI.** INFERENCE — Bring-up PHY còn phụ thuộc timing của vendor. Điểm 2/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-015 | Major | §6.3 REQ-IF-011, §7.3, §14.4, §20 DEC-025/TBD-007/TBD-015 | FACT — **PHY bring-up depends on unresolved vendor timing.** The host reset OpMode is selectable and defaults to 3. The HDS keeps UTMI+ I/O assumptions and flags converted ULPI timing as uncertain. phyclk_ok reflects reset release according to DEC-012, so it cannot by itself establish ongoing clock activity before a soft reset. | FACT — **Bring-up PHY còn phụ thuộc timing của vendor.** OpMode reset Host có tham số và mặc định 3. HDS dùng giả định timing UTMI+ và ghi bảng ULPI chuyển đổi còn bất định. phyclk_ok phản ánh release reset, chưa xác nhận clock còn chạy. | fix · Freeze PHY model, reset/pin timing and clock restart behavior. Require a live clock indicator or a software sequence that first restarts the PHY and then confirms a fresh acknowledgment. |

## 19. Market position / So sánh thương mại

**EN.** INFERENCE — Feature breadth is credible, integration effort is higher. Score 3/5.

**VI.** INFERENCE — Tính năng đủ rộng, cần đầu tư thêm cho tích hợp. Điểm 3/5.

| ID | Severity | Locator | Evidence and assessment (EN) | Bằng chứng và đánh giá (VI) | Verdict and action |
|---|---|---|---|---|---|
| F-018 | Observation | §1.3–1.4, §2.1 REF-011/012, §11.5 | INFERENCE — **Feature breadth is credible, integration effort is higher.** The proposed role options, endpoint sizing and integrated DMA have commercial analogues. Synopsys documents buffering and descriptor prefetch, and TI documents a software-supported dual-role USB subsystem. Equivalent software, interoperability and sustained performance evidence are required before claiming parity. | INFERENCE — **Tính năng đủ rộng, cần đầu tư thêm cho tích hợp.** Role option, endpoint sizing và DMA có đối chiếu thương mại. Synopsys có buffering và descriptor prefetch, TI có subsystem dual-role với software. Muốn nói tương đương cần bằng chứng driver, interop và thông lượng. | none · Use public benchmarks as planning references for driver bring-up, prefetch and USB interoperability. |

| Commercial comparison, primary source | Published feature | Review implication |
|---|---|---|
| [Synopsys USB 2.0 HS OTG Controller](https://www.synopsys.com/designware-ip/interface-ip/usb/usb-2-0-hs-otg.html), product page, accessed 2026-11-22 | FACT — Dual role, integrated DMA, selectable buffering, descriptor prefetch and UTMI+ Level 3. | INFERENCE — Similar host/device partition. This project needs performance and interop evidence for its own AXI/ULPI mix. |
| [Texas Instruments AM335x TRM SPRUH73Q](https://www.ti.com/lit/ug/spruh73q/spruh73q.pdf), Rev. Q, December 2019, §§16.2.9, 16.3 | FACT — Host and peripheral modes and CPPI 4.1 DMA. | INFERENCE — Compare DMA ownership and support effort using a reference that ships as a subsystem. |
| [TI AM335x Processor SDK MUSB driver](https://software-dl.ti.com/processor-sdk-linux/esd/docs/latest/linux/Foundational_Components/Kernel/Kernel_Drivers/USB/MUSB.html), accessed 2026-11-22 | FACT — TI documents host and peripheral software support with its DMA platform. | INFERENCE — The VLSIT custom CSR view needs its own controller layer or a compatibility contract. |

**VI.** FACT — Synopsys và TI công bố dual role và DMA. INFERENCE — Dùng các nguồn này để đối chiếu tính năng và chi phí tích hợp software. PPA cần so sánh cùng công nghệ và workload.

## 20. Actions / Hành động

**EN.** INFERENCE — P0 is the integration entry gate. Start P1 with the narrowed selected product profile and run P2 qualification against its exact revisions.

**VI.** INFERENCE — P0 là điều kiện vào tích hợp. P1 chốt profile sản phẩm. P2 kiểm chứng đúng revision đã chốt.

| Priority | Owner | Completion evidence |
|---|---|---|
| P0 F-001/F-018/F-020 | RTL and verification | Generation, same-edge write, cancellation/reset and Gray credit tests with independent clocks. |
| P0 F-002 | Physical design / SoC | Nonempty constrained endpoint collections, actual pointer delay/skew and active ULPI I/O paths. |
| P0 F-003 | Architecture and interconnect | AXI4 profile and exception behavior pinned against IHI 0022H. Adversarial-in-timing but legal traffic test matrix with complete responses. |
| P1 F-004–F-008/F-010/F-016/F-017/F-019/F-021 | Spec, RTL and software | Single FIFO and DMA/CSR contract, defined LPM/SOF behavior and measured product service budgets. |
| P2 F-009/F-011–F-015 | Verification, board and physical design | Close observed bins, real PHY and OS interoperability, target SRAM, sign-off timing and manufacturing test artifacts. |

## 21. Evidence appendix / Phụ lục bằng chứng

**EN.** FACT — The extractor found 63 headings, 56 tables, 75 requirement IDs, 37 test IDs, 19 property IDs, 77 numeric claims and 49 assumption/decision/open-item markers. The marker count includes resolved items. All requirements have a test reference. The [inventory](reference/2026-11-22/inventory.json) contains the extracted records.

**VI.** FACT — Có 75 requirement ID và 37 test ID. Tất cả requirement có tham chiếu tới test. 49 marker gồm cả các mục đã xử lý. Truy vết không thay cho bằng chứng chạy.

| Input | Evidence inspected and limit |
|---|---|
| Root HDS | Normative design, decisions and requirement matrix. SHA-256 `1f4ab7e3999c56b9ebea1221673b7fc176b095b28514ac11b50dbf4175ec33a6`. |
| CSR workbook and `csr/` | ASYNC_CSR, CSR and Register_Description sheets, corresponding generator definitions and selected generated metadata/RTL. Workbook SHA-256 `284e1d0297f49486c3965c342750218ded3da5cc472148a269f4a28feb8856f5`. |
| `figures/`, `research/`, `review/`, `rtl_gen/` | Figure and waveform references, research log, historical review and HDS backup inventoried. Figures were assessed through selected linked diagrams and inline HDS timing descriptions. Historical source scripts are supporting artifacts. |
| `rtl/`, `sdc/`, `syn/` | Four profile filelists and selected incident RTL paths were traced. Both SDC files, synthesis summaries and configurations were inspected. Retained reports are historical evidence. |
| `verification/`, `verification/sim/` | Directed benches, plan, test and coverage summaries, selected later reviews and sign-off state. Retained verification report SHA-256 `b82b1788f04765efff427808989cc5aa2150a020142c329e1fc33612a7b4a522`. Current revision simulation, clock/reset structural tool runs, synthesis and sign-off timing remain unverified by this review. |
| Standards | FACT — USB base clauses, LPM, UTMI, ULPI and APB were read from local conversions, with official bundle and AXI4 source checked separately. Conversion fidelity for ULPI Table 5 and the Phase-locked SOF ECN clause remain open. |

FACT — The 2026-11-20 review is preserved. Since that baseline the HDS adds explicit crossing FIFOs, ULPI sleep/wake, a turnaround timing budget, product integration steps and delivered SDC. F-001 and F-002 above supersede the blanket missing-structure and missing-file concerns with specific source mismatches. DEC-036/038/039 and DEC-044–046 record later contract decisions. The current review retains unresolved effects rather than reopening closed issues that have evidence.

INFERENCE — Remaining inputs with direct integration impact are the chosen PHY timing model (TBD-007/TBD-015), the detailed LPM timing baseline (TBD-014), actual SRAM and DFT views (DEP-004), and a synchronized current verification ledger (TBD-016). The setup hold, power, certification and independent verification claims remain open.

FACT — Rule precedence is `rule.md`, then `SKILL.md`, then files under `reference/`.
