# Specification review — DVP_Controller / Đánh giá đặc tả — DVP_Controller

| Field / Trường | Value / Giá trị |
|---|---|
| IP | DVP_Controller (top `m_dvp_controller`) |
| Specification reviewed | `025_DVP_Controller/spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md` (the approved HDS; the baseline `spec/VLSIT_DVP_CONTROLLER_HDS.md` was read for traceability only) |
| Revision and date | front matter version 0.2, status Draft; 22 November 2026 |
| Reviewer | Claude (skill vlsit-ip-spec-review) |
| Review date | 2026-11-22 |
| Verdict / Kết luận | **Conditional** (weighted score 2.76 of 5, no Blocker) |

Precedence: `rule.md` overrides `SKILL.md`, and `SKILL.md` overrides the files under `reference/`, when they differ. / Thứ tự ưu tiên: `rule.md` cao hơn `SKILL.md`, và `SKILL.md` cao hơn các file trong `reference/` khi chúng khác nhau.

Labels: `FACT` is read from the specification, a standard or a dated source; `INFERENCE` is the reviewer reasoning. Severity: Blocker, Major, Minor, Observation. / Nhãn: `FACT` là điều đọc được từ spec, chuẩn hoặc nguồn có ngày; `INFERENCE` là suy luận của reviewer.

## 1. Executive summary / Tóm tắt điều hành

**EN.** DVP_Controller captures a parallel camera port (8, 10 or 12-bit, PCLK, VSYNC, HREF) into a FIFO and hands samples to a system DMA through one APB4 completer, with a continuous-PCLK path (asynchronous Gray FIFO) and a gated-PCLK path (toggle and bundled data into an APB-clocked FIFO). The specification is organised, traceable (19 requirements, 15 tests, no requirement without a test) and honest about what is not done. The review found 31 findings (19 Major, 11 Minor, 1 Observation) in 17 root-cause groups and no Blocker, so the verdict is **Conditional** at a weighted score of 2.76. The design cannot be integrated yet for four reasons: the DMA request rule can stall and leaves the tail of every frame behind (F-004, F-005), the gated-mode reset contradicts the spec own reset rule (F-009), no behavioural simulation exists (F-025), and the contract of one sample per APB read is not backed by a workload (F-001, F-019). The three actions that matter most: replace the DMA re-arm rule with a counted burst and add a tail flush, remove the cross-domain reset of the gated launch registers, and run the TEST-001..015 plan with the missing stall and violation scenarios.

**VI.** DVP_Controller thu một cổng camera song song (8, 10 hoặc 12 bit, PCLK, VSYNC, HREF) vào FIFO và giao sample cho DMA hệ thống qua một APB4 completer, với đường continuous-PCLK (asynchronous Gray FIFO) và đường gated-PCLK (toggle và bundled data vào FIFO clock APB). Spec có tổ chức, truy vết được (19 requirement, 15 test, không requirement nào thiếu test) và trung thực về phần chưa làm. Review ghi nhận 31 finding (19 Major, 11 Minor, 1 Observation) trong 17 nhóm root cause và không có Blocker nên kết luận là **Conditional** với điểm có trọng số 2,76. IP chưa tích hợp được vì bốn lý do: quy tắc DMA request có thể treo và bỏ lại phần cuối mỗi frame (F-004, F-005), reset của gated mode mâu thuẫn với quy tắc reset của chính spec (F-009), chưa có mô phỏng hành vi (F-025) và hợp đồng một sample cho mỗi lần đọc APB chưa có workload đỡ lưng (F-001, F-019). Ba việc quan trọng nhất: thay quy tắc re-arm DMA bằng burst có đếm và thêm tail flush, bỏ reset xuyên miền của các register launch gated, và chạy kế hoạch TEST-001..015 cùng các kịch bản treo và vi phạm còn thiếu.

### 1.1 Top findings / Phát hiện quan trọng nhất

| ID | Severity | Area | Finding (EN) | Phát hiện (VI) | Locator |
|---|---|---|---|---|---|
| F-004 | Major | functions | INFERENCE: The DMA re-arm rule can leave the request low while the FIFO is above the watermark | INFERENCE: Quy tắc re-arm DMA có thể giữ request ở mức thấp trong khi FIFO vẫn trên watermark | REQ-IF-004 (line 125), §10.1 FSM (lines 552-560), figure 10-1 |
| F-009 | Major | clock_reset_cdc | FACT: The gated-mode launch registers are clocked by PCLK but reset from the CLK-APB reset | FACT: Các register launch của gated mode chạy theo PCLK nhưng reset từ reset của CLK-APB | §2.2 item 4 (line 99), §7.3 (lines 459-464), CDC-005 (line 452), DEC-029 (line 2210), REQ-RESET-001 (line 136) |
| F-025 | Major | verification_quality | FACT: No behavioural simulation has been run; the evidence is lint and static checks | FACT: Chưa chạy mô phỏng hành vi; bằng chứng chỉ là lint và kiểm tra tĩnh | verification/README.md, RTL_GENERATION_REPORT.md (Verification boundary), §15.1 (line 2034) |
| F-002 | Major | features | INFERENCE: No frame-done event, line or frame counter, flush, or snapshot mode | INFERENCE: Không có sự kiện frame-done, bộ đếm dòng/frame, flush hay snapshot mode | §6.3 DMA re-arm row (line 426), §10.1 (line 560), CSR dvp_fifo_sts (workbook) |
| F-001 | Major | application_fit | INFERENCE: No workload is fixed, and the one-sample-per-APB-read contract cannot be shown to serve a camera | INFERENCE: Không có workload cố định, và hợp đồng một sample cho mỗi lần đọc APB không chứng minh được là phục vụ được camera | §1.4 (line 74), §9 (line 497), §13 PERF-002 (line 1962), REQ-IF-001 (line 122) |

### 1.2 Gate / Cổng

`RESULT: PASS, 31 finding(s), written C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\025_DVP_Controller\review\gate_metrics.json`; audit sample 4 of 31 findings, false positive 0 of 4, false negative 0 of 4 (section 21). Review list confirmed by the user on 2026-11-22: all 18 chapters, approved HDS, web search for the market chapter.

## 2. Scorecard / Bảng điểm

**EN.** Eighteen areas are scored 0 to 5 against the schema; the weighted result is computed by `vlsit_scorecard.py`.

**VI.** Mười tám nhóm được chấm 0 đến 5 theo schema; kết quả có trọng số do `vlsit_scorecard.py` tính.

| Area | Weight | Score | Justification |
|---|---:|---:|---|
| application_fit | 1.0 | 3 | The application class is named and confirmed, but F-001 shows no workload budget and a throughput contract that cannot be shown to fit. |
| features | 1.0 | 3 | FEAT-001..004 each map to requirements; F-002 (no frame-done, counters or flush) is a Major gap and F-003 a Minor one. |
| functions | 1.5 | 2 | Two Major findings (F-004, F-005) in the DMA request function; the other functions have cycle tables and waveforms. |
| interfaces | 1.5 | 2 | APB behaviour matches IHI 0024 Issue D in the clauses read, but there is no interrupt (F-006) and the empty-read wait can block the bus (F-007). |
| clock_reset_cdc | 1.5 | 2 | Crossings are tabulated with structures, but F-009 breaks the spec own reset rule and F-010 leaves the gated-mode failure silent. |
| parameters | 1.0 | 3 | Every parameter has default, range and impact; F-011 (compile-time polarity and edge) is a Major limit and F-012 a Minor one. |
| data_representation | 0.5 | 4 | Width, zero-extension and ordering are defined; only the Minor packing question (F-013) remains. |
| asic_feasibility | 1.5 | 4 | Small synthesizable structure with local resets and synchronizers; only the clocking statement (F-014) is Minor. Timing and frequency could not be assessed (no library or period). |
| sdc_timing | 1.5 | 2 | No SDC, all budgets TBD (F-015) and the key bundled-data exception has no value (F-016). |
| area_power | 1.0 | 3 | No area or power basis (F-017 Major); proxy of about 320 flops derived here; storage doubling (F-018). |
| performance | 1.5 | 3 | Formulas exist and are correct (the 512-entry example checks out) but carry no values (F-019 Major). |
| software_ease | 1.0 | 3 | Small register model (6 registers) and a documented sequence, but no flush or recovery path (F-020) and a silent mode refusal (F-021). |
| dft | 1.0 | 3 | Section 16 is all TBD while the design has stoppable clock, edge option and reset crossing (F-022). |
| security_ras | 1.0 | 4 | The security stance is explicit and waived (F-023); the diagnostic thinness is Minor (F-024). |
| verification_quality | 1.5 | 2 | Full requirement trace, but no simulation (F-025) and no assertion IDs, formal or stall tests (F-026). |
| documentation | 0.5 | 4 | Stable IDs, a decision log and a gap scan; only template residue and version alignment (F-027, F-028) are Minor. |
| integration_effort | 1.0 | 3 | No sensor mode validated against mode 1 (F-029 Major); open items are inputs without a checklist (F-030). |
| market_position | 1.0 | 2 | Basic capture matches the compared parts but the frame-level services are missing (F-031), which changes the driver architecture. |
| **Weighted** | **20.5** | **2.76** | **Verdict: Conditional** |

The two lowest-scoring groups are functions, interfaces, clock/reset/CDC, SDC, verification and market position (all 2). The common thread is that the specification fixes the interface and the data format, but not the end-to-end behaviour a driver needs (frame end, flush, recovery), and nothing yet proves the rules by simulation. / Các nhóm điểm thấp nhất là function, interface, clock/reset/CDC, SDC, verification và market position (đều 2). Điểm chung: spec cố định interface và định dạng dữ liệu nhưng chưa cố định hành vi đầu-cuối mà driver cần (kết thúc frame, flush, phục hồi), và chưa có mô phỏng nào chứng minh các quy tắc.

## 3. Application fit / Phù hợp ứng dụng

**EN.** The IP targets a smart-camera or embedded-vision SoC (user confirmed 2026-11-21, §1.2) with an external sensor, a system DMA acting as APB requester and an APB interconnect. The included and excluded lists are explicit (sensor configuration, DMA engine, HSYNC, BT.656 and image processing are excluded). The review list was derived from the stated features: pixel read through APB, empty-read timeout, gated mode, continuous mode, mode lock and reset, DMA request, overflow policy, and the TBD items for SDC, PPA and DFT. The application cannot be judged complete because no workload (resolution, frame rate, PCLK, APB clock) is fixed.

**VI.** IP nhắm tới SoC smart camera hoặc embedded vision (user xác nhận 2026-11-21, §1.2) với sensor ngoài, DMA hệ thống làm APB requester và APB interconnect. Danh sách included và excluded rõ ràng (cấu hình sensor, DMA engine, HSYNC, BT.656 và xử lý ảnh bị loại). Danh sách review được dựng từ các tính năng đã nêu: đọc pixel qua APB, timeout đọc rỗng, gated mode, continuous mode, khoá mode và reset, DMA request, chính sách overflow và các mục TBD của SDC, PPA, DFT. Chưa thể coi ứng dụng là đầy đủ vì không có workload (độ phân giải, frame rate, PCLK, clock APB) nào được cố định.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-001 | Major | §1.4 (line 74), §9 (line 497), §13 PERF-002 (line 1962), REQ-IF-001 (line 122) | INFERENCE: the HDS makes no product workload claim (§1.4) and bounds the drain to f_APB/2 samples per second (§9), one sample per 32-bit read. For the OV7670 VGA frame timing supplied with this review (tLINE = 784 tp, 640 tp active, 510 lines, 480 active) in YUV mode at 24 MHz PCLK, the active line delivers 24 Msample/s, so a zero-wait APB needs at least 48 MHz and a DMA path of four cycles per beat needs about 96 MHz; the default FIFO of 8 entries holds only 8/24 MHz = 333 ns of pixels. | INFERENCE: HDS không đưa ra workload sản phẩm (§1.4) và giới hạn tốc độ drain ở f_APB/2 sample/s, mỗi lần đọc 32-bit chỉ một sample (§9). Với timing khung VGA của OV7670 (tLINE = 784 tp, 640 tp active, 510 dòng, 480 dòng active) ở chế độ YUV, PCLK 24 MHz, đường active cấp 24 Msample/s nên APB zero-wait cần tối thiểu 48 MHz và đường DMA 4 chu kỳ mỗi beat cần khoảng 96 MHz; FIFO mặc định 8 entry chỉ chứa 8/24 MHz = 333 ns pixel. | Write the reference workload table and sizing result in §13 |


**Score / Điểm:** 3 of 5 for `application_fit`. The application class is named and confirmed, but F-001 shows no workload budget and a throughput contract that cannot be shown to fit.

## 4. Features / Tính năng

**EN.** FEAT-001..004 map to REQ-FUNC-001..008, REQ-PARAM-001, REQ-IF-001..006 and REQ-REG-001, so no feature is a marketing line. The gap is in what the features omit: frame-level events, counters, flush and snapshot capture, and some sensor modes of the research corpus.

**VI.** FEAT-001..004 ánh xạ tới REQ-FUNC-001..008, REQ-PARAM-001, REQ-IF-001..006 và REQ-REG-001 nên không có tính năng nào chỉ là dòng quảng cáo. Khoảng trống nằm ở những thứ tính năng bỏ qua: sự kiện mức frame, bộ đếm, flush và snapshot capture, cùng một số mode sensor trong corpus research.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-002 | Major | §6.3 DMA re-arm row (line 426), §10.1 (line 560), CSR dvp_fifo_sts (workbook) | INFERENCE: §6.3 states "no frame-end interrupt or implicit FIFO flush", the CSR has no frame or line counter (6 registers: dvp_version, dvp_ctrl, dvp_wmark, dvp_timeout, dvp_fifo_sts, dvp_fifo_level), and the sample stream carries no frame or line marker, so firmware cannot learn from the IP where a frame ends or whether pixels were dropped. | INFERENCE: §6.3 nêu rõ không có frame-end interrupt hay FIFO flush, CSR không có bộ đếm frame/dòng (6 register: dvp_version, dvp_ctrl, dvp_wmark, dvp_timeout, dvp_fifo_sts, dvp_fifo_level) và luồng sample không mang marker frame/dòng, nên firmware không biết từ IP frame kết thúc ở đâu hay pixel có bị rơi hay không. | Add frame/line counters, frame_done and snapshot to the CSR workbook and §10 |
| F-003 | Minor | §1.1 Excluded (line 54), ASM-001 (line 2180), research D03, D04, D07 | INFERENCE: ASM-001 sets the goal of maximum compatibility, yet HSYNC-pulse output (OV3640 HSYNC mode, OV7725 HREF-to-HSYNC mode), the onsemi XOR-style LINE_VALID options, BT.656 embedded codes are excluded (§1.1, DEC-005), and widths above 12 bits are outside DEC-001. The research report states that a fixed reading of the valid signals "can therefore be wrong for a selected mode". | INFERENCE: ASM-001 đặt mục tiêu tương thích tối đa, nhưng HSYNC dạng xung (OV3640 HSYNC mode, OV7725 HREF-to-HSYNC), tuỳ chọn LINE_VALID kiểu XOR của onsemi, BT.656 embedded code bị loại (§1.1, DEC-005) và độ rộng trên 12 bit nằm ngoài DEC-001. Research report ghi rằng cách đọc cố định các tín hiệu valid "có thể sai với một mode được chọn". | Add the supported sensor-mode table to §1 and §8 |


**Score / Điểm:** 3 of 5 for `features`. FEAT-001..004 each map to requirements; F-002 (no frame-done, counters or flush) is a Major gap and F-003 a Minor one.

## 5. Functions and cycle behaviour / Chức năng và hành vi theo chu kỳ

**EN.** The cycle behaviour is given by 18 waveforms (WF-001..WF-018), the DMA request FSM (figure 10-1), the D27 and D28 examples and the timeout tables of §11.4. The empty-read timeout rule (terminal-cycle priority, no pop on error) is precise and testable. The DMA request function is the weak spot: its re-arm and flush rules were found to stall or to leave data behind.

**VI.** Hành vi theo chu kỳ được cho bởi 18 waveform (WF-001..WF-018), FSM DMA request (hình 10-1), các ví dụ D27, D28 và bảng timeout ở §11.4. Quy tắc timeout đọc rỗng (ưu tiên ở chu kỳ cuối, không pop khi lỗi) chính xác và test được. Chức năng DMA request là điểm yếu: quy tắc re-arm và flush bị phát hiện có thể treo hoặc để sót dữ liệu.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-004 | Major | REQ-IF-004 (line 125), §10.1 FSM (lines 552-560), figure 10-1 | INFERENCE: after ACK the FSM leaves ENUM_ST_SERVICE_ACTIVE only when occupancy falls below the watermark, and a new request needs occupancy to cross the watermark again. A DMA that reads a fixed burst of W samples while PCLK keeps writing can finish with occupancy still at or above W (for example 7 entries at ACK, 4 read, 2 new arrivals leaves 5 with W = 4); no further request is raised, the FIFO fills, and the newest samples are dropped. | INFERENCE: sau ACK, FSM chỉ rời ENUM_ST_SERVICE_ACTIVE khi occupancy xuống dưới watermark và request mới cần occupancy vượt watermark lần nữa. DMA đọc burst cố định W sample trong khi PCLK vẫn ghi có thể kết thúc với occupancy vẫn không nhỏ hơn W (ví dụ 7 entry lúc ACK, đọc 4, thêm 2 sample mới còn 5 với W = 4); khi đó không có request nào nữa, FIFO đầy và sample mới nhất bị bỏ. | Change the DMA FSM to burst-counted service and update REQ-IF-004, DEC-008 |
| F-005 | Major | §6.3 DMA re-arm row (line 426), §10.1 (line 560) | FACT: §6.3 says the notification is "watermark-only; no frame-end interrupt or implicit FIFO flush" and §10.1 says a request "may assert during a partial frame; frame boundaries do not defer a batch request". When the sample count of a frame is not a multiple of the watermark, the remainder stays in the FIFO and is delivered together with the next frame. | FACT: §6.3 nêu thông báo chỉ theo watermark, không có frame-end interrupt hay FIFO flush; §10.1 nêu request có thể assert giữa frame và biên frame không làm trễ batch. Khi số sample của một frame không chia hết cho watermark, phần dư nằm lại trong FIFO và được giao cùng frame kế tiếp. | Define the end-of-frame flush request in §6.3 and §10.1 |


**Score / Điểm:** 2 of 5 for `functions`. Two Major findings (F-004, F-005) in the DMA request function; the other functions have cycle tables and waveforms.

## 6. Interfaces and protocol / Giao diện và giao thức

**EN.** Three interfaces are specified: the sensor DVP port (PCLK, data, VSYNC, HREF), APB4 (16-bit address, 32-bit data, PSTRB, PPROT, PSLVERR) and the DMA REQ/ACK sideband. The port table lists direction, width, clock domain, signal type and timing for every port and is complete. The APB behaviour matches IHI 0024 Issue D in the clauses read. Protocol compliance and interoperability findings: there is no interrupt output, the empty-read wait can hold the shared APB, and the DMA handshake is not mapped to a DMA engine.

**VI.** Có ba giao diện: cổng DVP của sensor (PCLK, data, VSYNC, HREF), APB4 (địa chỉ 16 bit, dữ liệu 32 bit, PSTRB, PPROT, PSLVERR) và sideband DMA REQ/ACK. Bảng port nêu direction, width, clock domain, signal type và timing cho mọi port và đầy đủ. Hành vi APB khớp IHI 0024 Issue D ở các điều khoản đã đọc. Finding về tuân thủ và interoperability: không có ngõ ra interrupt, lần đọc chờ FIFO rỗng có thể giữ APB dùng chung và handshake DMA chưa ánh xạ tới DMA engine nào.

### Standards compliance (APB) / Tuân thủ chuẩn

| Item | Standard, revision, clause | Specification statement | Verdict |
|---|---|---|---|
| PREADY wait states | IHI 0024 Issue D, 3.1 and 3.3 (figures 3-2, 3-5) | REQ-IF-002 holds PREADY low while the FIFO is empty | compliant; no maximum stated in the clauses read (F-007) |
| PSTRB low on reads | IHI 0024 Issue D, 3.2 | §11.4 keeps PSTRB low for reads | compliant |
| Sparse writes | IHI 0024 Issue D, 3.2 (PSTRB optional, the completer documents it) | CSR partial strobe gives PSLVERR (§11.4) | compliant, documented |
| PSLVERR valid in the last cycle only | IHI 0024 Issue D, 3.4 | §11.4 and INV-006 say the same | compliant |
| Signals stable while PREADY is low | IHI 0024 Issue D, 3.1 and Appendix A | INV-006 | compliant |
| PRDATA on an error read | IHI 0024 Issue D, 3.4 (invalid data allowed) | not stated for the timeout error | not stated (F-007) |
| PPROT | APB4 signal set, chapter 2 | ignored by decision, i_protect_en tied low | compliant, stated |
| Sensor DVP profile | no universal DVP standard (research_report.md section 3) | REF-006 sensor-specific, mode unselected | not stated for any sensor mode (F-029) |

Source of the clauses: the converted APB specification in the micro-spec skill (`vlsit_apb_amba_apb_ihi0024d.md`), read at lines 17-20, 960, 1020 and 1251. / Nguồn điều khoản: bản APB đã chuyển đổi trong skill micro-spec, đã đọc ở các dòng 17-20, 960, 1020 và 1251.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-006 | Major | §6.4 (line 432), §1.1 (line 50) | FACT: §6.4 states "No interrupt output is in scope". Overflow (dvp_fifo_sts.ovf), read timeout and frame state can only be found by polling the CSR, and an APB read that waits on an empty FIFO also blocks the poll (F-007). | FACT: §6.4 nêu không có ngõ ra interrupt. Overflow (dvp_fifo_sts.ovf), timeout đọc và trạng thái frame chỉ biết được bằng polling CSR, và một lần đọc APB đang chờ FIFO rỗng cũng chặn luôn việc polling (F-007). | Add the interrupt output and registers (spec, CSR workbook, RTL) |
| F-007 | Major | REQ-IF-002 (line 123), REQ-IF-005 (line 126), CSR dvp_timeout.cycles [31:0], §11.4 (line 1937) | INFERENCE: PREADY stays low while the FIFO is empty for the programmed cycles, the field is 32 bits wide with no stated maximum, and IHI 0024 Issue D 3.1 allows PREADY wait states without setting a limit in the sections read. A DMA read issued before capture_en is set, with a large timeout, blocks the APB bridge, so the CPU write that would enable capture waits behind it. | INFERENCE: PREADY giữ thấp khi FIFO rỗng trong số chu kỳ đã lập trình, trường rộng 32 bit và không có giá trị tối đa, còn IHI 0024 Issue D 3.1 cho phép wait state qua PREADY mà phần đã đọc không đặt giới hạn. Một lần DMA đọc trước khi capture_en được set, với timeout lớn, chặn APB bridge, nên lệnh ghi của CPU để bật capture phải đợi sau nó. | Bound dvp_timeout, define PRDATA on error, add rd_to flag |
| F-008 | Minor | IF-003 (line 387), DEC-008 (line 2189), §6.2 (lines 411-412) | INFERENCE: the sideband is one level REQ and a one-cycle ACK in CLK-APB. The HDS does not say which DMA engine protocol it maps to, whether a single or a burst request is meant, or what happens if ACK arrives while REQ is low. | INFERENCE: sideband gồm một REQ mức và một ACK 1 chu kỳ trong CLK-APB. HDS không nêu ánh xạ sang giao thức DMA engine nào, đó là request single hay burst, và điều gì xảy ra khi ACK đến lúc REQ đang thấp. | Write the DMA contract table |


**Score / Điểm:** 2 of 5 for `interfaces`. APB behaviour matches IHI 0024 Issue D in the clauses read, but there is no interrupt (F-006) and the empty-read wait can block the bus (F-007).

## 7. Clock, reset and CDC / Clock, reset và CDC

**EN.** Two clocks are asynchronous (CLK-APB from the SoC and CLK-DVP from the sensor, which may stop in gated mode). The CDC table names a structure for each of the six crossings, and the reset table separates the common asynchronous assertion from the local synchronous releases. Two findings concern the design own rules: the reset of the gated launch registers and the silent failure of the gated spacing contract.

**VI.** Hai clock bất đồng bộ (CLK-APB từ SoC và CLK-DVP từ sensor, có thể dừng ở gated mode). Bảng CDC nêu cấu trúc cho từng trong sáu crossing, và bảng reset tách assertion bất đồng bộ chung với các release đồng bộ cục bộ. Hai finding liên quan quy tắc của chính thiết kế: reset của các register launch gated và việc hợp đồng khoảng cách gated hỏng một cách âm thầm.

### Crossing review / Rà soát crossing

| Crossing | Structure in the HDS | Assessment |
|---|---|---|
| CDC-001, CDC-002 (continuous FIFO) | Gray pointers, two-flop synchronizers, payload through the memory | sound; the occupancy is an estimate that lags (documented, §9) |
| CDC-003 (gated toggle and bundled data) | two-flop toggle, held data, both-edge detect | valid only under the 4-cycle rule; failure silent (F-010); constraint unquantified (F-016) |
| CDC-004 (VSYNC in gated mode) | two-flop and edge detect in CLK-APB | sound given the 4-cycle pulse width; width not checked in hardware (F-010) |
| CDC-005 (reset) | local release in each domain; gated launch registers use the APB reset | breaks the stated reset rule (F-009) |
| CDC-006 (DMA REQ/ACK) | same clock, CLK-APB | sound; integration check only |

Not assessed: a CDC tool run, because no CDC or RDC report exists in the folder (stated in `verification/README.md`). / Chưa đánh giá: lần chạy công cụ CDC vì thư mục không có báo cáo CDC hay RDC.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-009 | Major | §2.2 item 4 (line 99), §7.3 (lines 459-464), CDC-005 (line 452), DEC-029 (line 2210), REQ-RESET-001 (line 136) | FACT: DEC-029 resets the gated held-data and toggle registers from the APB-local synchronized reset, and §7.3 asks STA/RDC to "check reset removal at the first selected PCLK edge". §2.2 item 4 says REF-003 is the mandatory baseline and "do not create a local RTL exception", and §7.3 lists RST-DVP-LOCAL as the reset of the capture and FIFO write side. | FACT: DEC-029 reset các register held-data và toggle của gated mode từ reset đã đồng bộ của APB, và §7.3 yêu cầu STA/RDC kiểm tra reset removal tại cạnh PCLK đầu tiên. §2.2 mục 4 nói REF-003 là baseline bắt buộc và không tạo ngoại lệ RTL cục bộ, còn §7.3 liệt kê RST-DVP-LOCAL là reset của phía capture và FIFO write. | Re-implement DEC-029 without a cross-domain reset |
| F-010 | Major | §10.6 (line 1834), REQ-FUNC-007 (line 132), REQ-PERF-001 (line 135), CDC-003 and CDC-004 (lines 450-451) | FACT: §10.6 says that if the 4-APB-cycle spacing is violated "the APB toggle synchronizer can miss an event or sample a newer value", and the gated profile is then outside the no-pixel-loss contract. No status bit, counter or interrupt reports it, and FIFO overflow is a different event. | FACT: §10.6 nêu nếu vi phạm khoảng cách 4 chu kỳ APB thì bộ đồng bộ toggle có thể bỏ lỡ sự kiện hoặc lấy mẫu giá trị mới hơn, và profile gated khi đó nằm ngoài hợp đồng không mất pixel. Không có bit trạng thái, bộ đếm hay interrupt nào báo, và FIFO overflow là sự kiện khác. | Add the gated-mode overrun detector and flag |


**Score / Điểm:** 2 of 5 for `clock_reset_cdc`. Crossings are tabulated with structures, but F-009 breaks the spec own reset rule and F-010 leaves the gated-mode failure silent.

## 8. Parameters and data / Tham số và biểu diễn dữ liệu

**EN.** Every parameter has a default, a legal range and an impact, and the elaboration check ERR-006 and TEST-001 cover the legality. The width of the CSR fields is wider than the values the hardware accepts, and the profile (edge and polarity) is frozen at elaboration. The data representation is simple and fully defined; the open question is packing.

**VI.** Mọi tham số đều có default, dải hợp lệ và tác động; ERR-006 và TEST-001 phủ việc kiểm tra tính hợp lệ lúc elaboration. Độ rộng field CSR lớn hơn giá trị phần cứng chấp nhận, và profile (cạnh, cực tính) bị cố định lúc elaboration. Biểu diễn dữ liệu đơn giản và định nghĩa đầy đủ; câu hỏi còn mở là packing.

### Parameter review / Rà soát tham số

| Parameter | Default | Legal values | Assessment |
|---|---|---|---|
| PARA_DVP_DATA_W | 8 | 8, 10, 12 | bounded; widths above 12 out of scope |
| PARA_DVP_SAMPLE_EDGE | 0 | 0, 1 | compile-time only (F-011) |
| PARA_DVP_VSYNC_ACTIVE, PARA_DVP_HREF_ACTIVE | 1 | 0, 1 | compile-time only (F-011) |
| PARA_FIFO_DEPTH | 8 | power of two, minimum 2 | bounded; applies to both FIFOs (F-018) |
| PARA_AFIFO_CELL_TYPE, PARA_AFIFO_MEM_USE_MACRO | 2, 0 | per the common FIFO | cell mapping left to integration |
| PARA_FIFO_DATA_ADDR | 16'h0100 | word aligned, outside the CSR | bounded |

Data representation: one unsigned sample, zero-extended to 32 bits, same in both modes; the occupancy is 0..PARA_FIFO_DEPTH. / Biểu diễn dữ liệu: một sample không dấu, zero-extend tới 32 bit, giống nhau ở hai mode; occupancy là 0..PARA_FIFO_DEPTH.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-011 | Major | §8 (lines 475-478), REQ-FUNC-002 (line 119), DEC-001 (line 2182) | INFERENCE: REQ-FUNC-002 forbids changing these settings at run time, so the polarity and edge are frozen in silicon. The research report notes that clock-to-data phase and polarity vary between sensors and between register-selected modes, and ST AN5020 (Rev 4, December 2024, web summary) describes the DCMI pixel clock edge as configurable. | INFERENCE: REQ-FUNC-002 cấm đổi các thiết lập này lúc chạy nên cực tính và cạnh bị đóng cứng trong silicon. Research report ghi pha clock-data và cực tính khác nhau giữa các sensor và giữa các mode chọn bằng register, và ST AN5020 (Rev 4, tháng 12-2024, tóm tắt web) mô tả cạnh pixel clock của DCMI là cấu hình được. | Decide runtime polarity and edge selection (HAS decision, then RTL) |
| F-012 | Minor | §9 (line 495), CSR dvp_wmark.level [31:0], dvp_timeout.cycles [31:0] | INFERENCE: dvp_wmark.level has 32 bits while only 0..PARA_FIFO_DEPTH is meaningful, and "values above depth are unreachable and leave REQ low" (§9). A software error therefore stops the DMA without any indication, and the extra field bits cost flops. | INFERENCE: dvp_wmark.level rộng 32 bit trong khi chỉ 0..PARA_FIFO_DEPTH có nghĩa, và giá trị lớn hơn depth không đạt được và giữ REQ thấp (§9). Lỗi phần mềm làm DMA dừng mà không có dấu hiệu nào, và các bit field thừa tốn flop. | Bound the CSR field widths and add the range check |
| F-013 | Minor | §9 (line 493), REQ-FUNC-008 (line 133), DEC-014 (line 2196) | INFERENCE: REQ-FUNC-008 returns one zero-extended sample per read, so an 8-bit sample uses 25 percent of the word and a 12-bit sample 37.5 percent. ST AN5020 (web summary) describes the DCMI assembling a 32-bit word from four pixel clock cycles for 8-bit input, which cuts the bus operations by four. | INFERENCE: REQ-FUNC-008 trả một sample zero-extend cho mỗi lần đọc, nên sample 8 bit dùng 25 phần trăm word và sample 12 bit dùng 37,5 phần trăm. ST AN5020 (tóm tắt web) mô tả DCMI ghép word 32 bit từ bốn chu kỳ pixel clock với đầu vào 8 bit, giảm số thao tác bus bốn lần. | Specify the packed read mode and lane order |


**Score / Điểm:** 3 of 5 for `parameters`. Every parameter has default, range and impact; F-011 (compile-time polarity and edge) is a Major limit and F-012 a Minor one.

**Score / Điểm:** 4 of 5 for `data_representation`. Width, zero-extension and ordering are defined; only the Minor packing question (F-013) remains.

## 9. ASIC feasibility / Khả thi ASIC

**EN.** Synthesizability: the structure is small and standard (registered logic, FSMs, FIFOs, two-flop synchronizers) and follows REF-003, so latch and loop risks are low; the rule check and lint results in `verification/` support this (0 errors) but are not a synthesis run. Clock and reset architecture: two domains with local resets, except the gated launch registers (F-009). CDC and RDC structure: tabulated, no tool report. Timing path created by the design: the synchronized-toggle detect to FIFO write at the APB clock and the bundled payload (F-016). Not assessed: any frequency or slack, because no library, corner or period is given.

**VI.** Tổng hợp: cấu trúc nhỏ và chuẩn (logic có register, FSM, FIFO, synchronizer hai flop) và theo REF-003 nên rủi ro latch và vòng lặp thấp; kết quả rule check và lint trong `verification/` ủng hộ điều này (0 lỗi) nhưng không phải lần chạy tổng hợp. Kiến trúc clock và reset: hai miền với reset cục bộ, trừ các register launch gated (F-009). Cấu trúc CDC và RDC: có bảng, không có báo cáo công cụ. Đường timing do thiết kế tạo ra: detect toggle đã đồng bộ tới ghi FIFO ở clock APB và payload bundled (F-016). Chưa đánh giá: tần số hay slack, vì chưa có library, corner hay chu kỳ.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-014 | Minor | §8 PARA_DVP_SAMPLE_EDGE (line 476), §10.6 (lines 1822-1824), §14.3 (lines 2018-2028) | INFERENCE: the design is a small synthesizable RTL set with registered outputs, local resets and two-flop synchronizers, so synthesis, latch and loop risks are low. The structures to settle are the falling-edge sample (negedge flops or an inverted clock), the PCLK that stops in gated mode, and the bundled data crossing, none of which §14.3 addresses. No timing path or frequency could be assessed because no library, corner or clock period is given. | INFERENCE: thiết kế là tập RTL nhỏ tổng hợp được với output có register, reset cục bộ và synchronizer hai flop nên rủi ro tổng hợp, latch và vòng lặp thấp. Các cấu trúc cần chốt là lấy mẫu cạnh xuống (flop negedge hoặc clock đảo), PCLK dừng trong gated mode và crossing bundled data, §14.3 chưa nêu cái nào. Không đánh giá được đường timing hay tần số vì chưa có library, corner hay chu kỳ clock. | Document the clocking structure in §14.3 |


**Score / Điểm:** 4 of 5 for `asic_feasibility`. Small synthesizable structure with local resets and synchronizers; only the clocking statement (F-014) is Minor. Timing and frequency could not be assessed (no library or period).

## 10. SDC and timing / SDC và timing

**EN.** The HDS lists two clocks, the interface budget groups and three exceptions (EXC-001..003) and forbids broad false paths, which is the right stance. Everything numeric is TBD and no SDC file exists. The one exception that carries the correctness of mode 1 (EXC-003) has no value; a derivation and a command are proposed.

**VI.** HDS liệt kê hai clock, các nhóm budget interface và ba exception (EXC-001..003) và cấm false path rộng, đây là lập trường đúng. Mọi giá trị số đều TBD và không có file SDC. Exception mang tính đúng đắn của mode 1 (EXC-003) không có giá trị; đã đề xuất cách suy ra và lệnh.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-015 | Major | §17.1 (lines 2094-2120), CLK-APB and CLK-DVP rows (lines 2100-2101) | FACT: §17.1.1 gives "TBD" for the period, latency and uncertainty of both clocks, §17.1.2 gives TBD for the sensor and APB delays, and no SDC file exists in the folder. The HDS correctly forbids a blanket false path, but names no command or value. | FACT: §17.1.1 ghi TBD cho chu kỳ, latency và uncertainty của cả hai clock, §17.1.2 ghi TBD cho delay của sensor và APB, và không có file SDC trong thư mục. HDS cấm đúng việc false path toàn bộ nhưng không nêu lệnh hay giá trị. | Deliver the SDC template with parameterised clock and I/O budgets |
| F-016 | Major | EXC-003 (line 2118), REQ-PERF-001 (line 135), §10.6 (lines 1830-1836) | INFERENCE: §10.6 says the write completes within three APB edges of the source sample in the worst phase and that four-cycle spacing leaves one cycle of margin "in addition to" setup, hold and uncertainty; EXC-003 asks to constrain the payload but gives no value. At f_APB = 100 MHz the one-cycle margin is 10 ns before setup, hold and clock uncertainty, and f_APB >= 4 x f_pixel is necessary but not sufficient. | INFERENCE: §10.6 nêu việc ghi hoàn tất trong ba cạnh APB sau sample nguồn ở pha xấu nhất và khoảng cách bốn chu kỳ để lại một chu kỳ margin ngoài setup, hold và uncertainty; EXC-003 yêu cầu constrain payload nhưng không có giá trị. Ở f_APB = 100 MHz margin một chu kỳ là 10 ns trước setup, hold và clock uncertainty, và f_APB >= 4 x f_pixel là điều kiện cần chứ chưa đủ. | Quantify EXC-003 and the margin rule |


**Score / Điểm:** 2 of 5 for `sdc_timing`. No SDC, all budgets TBD (F-015) and the key bundled-data exception has no value (F-016).

## 11. Area and power / Diện tích và công suất

**EN.** The HDS gives no area or power basis (PPA-002, PPA-003: "No target supplied"). A structural proxy is derived here and labelled as such; it is not a synthesis result. Mapped area was not produced because no Liberty library is available in this review.

**VI.** HDS không đưa cơ sở diện tích hay công suất (PPA-002, PPA-003: chưa có target). Một proxy cấu trúc được suy ra ở đây và gắn nhãn proxy; đây không phải kết quả tổng hợp. Không có diện tích mapped vì review này không có library Liberty.

### Area proxy / Proxy diện tích (label: proxy, not mapped)

Assumptions: default build (8-bit, depth 8), RTL array memory, flops counted from §5.1, §14.2 and the CSR workbook; no library, so no gate or micron figure. / Giả định: bản mặc định, memory dạng RTL array, đếm flop theo §5.1, §14.2 và workbook CSR; không có library nên không có số gate hay micron.

| Block | Proxy (flops) | Basis |
|---|---:|---|
| AFIFO storage | 64 | 8 entries x 8 bits |
| SFIFO storage | 64 | 8 entries x 8 bits |
| AFIFO pointers, Gray, synchronizers | 32 | 4-bit binary and Gray pointers on both sides, two-flop synchronizers |
| SFIFO pointers and occupancy | 12 | 4-bit pointers and counter |
| CSR (ctrl 2, wmark 32, timeout 32, ovf 1) and APB state | 70 | workbook |
| Empty-read counter and state | 34 | 32-bit timeout counter |
| DMA request FSM | 3 | three states |
| Capture, gate bridge, reset and event synchronizers | about 40 | data hold 8, toggle, frame state, two-flop chains |
| **Total (proxy)** | **about 320** | plus or minus 25 percent |

At the depth the HDS example recommends (512 entries, 12-bit) the storage alone is 12,288 bits for two FIFOs (F-018). Power: no clock gating, no power intent (§7.4); dynamic power follows the sample rate; no number can be given without activity and a library. / Với depth mà ví dụ HDS khuyến nghị (512 entry, 12 bit) riêng bộ nhớ đã là 12.288 bit cho hai FIFO (F-018). Công suất: không có clock gating, không có power intent (§7.4); công suất động theo tốc độ sample; không thể nêu số nếu thiếu activity và library.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-017 | Major | PPA-002 and PPA-003 (lines 1965-1966), §13 (line 1969) | FACT: PPA-002 and PPA-003 read "No target supplied" and no flop count, memory size or activity assumption appears. INFERENCE (proxy, not mapped): the default build (8-bit, depth 8) holds 2 x 8 x 8 = 128 storage bits, about 70 CSR and APB flops, a 32-bit empty-read counter, Gray pointers with synchronizers and the capture and bridge state, so roughly 320 flops (plus or minus 25 percent); the two 32-bit CSR fields and the 32-bit counter are about 30 percent of it. | FACT: PPA-002 và PPA-003 ghi không có target và không có số flop, kích thước bộ nhớ hay giả định activity. INFERENCE (proxy, không phải mapped): bản mặc định (8 bit, depth 8) có 2 x 8 x 8 = 128 bit lưu trữ, khoảng 70 flop CSR và APB, bộ đếm empty-read 32 bit, Gray pointer cùng synchronizer và trạng thái capture, bridge, tổng khoảng 320 flop (sai số cộng trừ 25 phần trăm); hai field CSR 32 bit và bộ đếm 32 bit chiếm khoảng 30 phần trăm. | Add the area proxy and power statement to §13 |
| F-018 | Minor | REQ-PARAM-001 (line 121), §5.1 (lines 159-163), §13 (line 1969) | INFERENCE: REQ-PARAM-001 applies PARA_FIFO_DEPTH to both the AFIFO and the SFIFO, and §5.1 instantiates both. The HDS depth example (25 MHz x 10 us gives 512 entries) would then hold 2 x 512 x 12 = 12,288 storage bits for a 12-bit profile, twice the 6,144 bits one active FIFO needs, with the RTL array as the delivered memory (PARA_AFIFO_MEM_USE_MACRO = 0). | INFERENCE: REQ-PARAM-001 áp PARA_FIFO_DEPTH cho cả AFIFO và SFIFO, và §5.1 instance hoá cả hai. Ví dụ depth của HDS (25 MHz x 10 us ra 512 entry) khi đó chứa 2 x 512 x 12 = 12.288 bit lưu trữ cho profile 12 bit, gấp đôi 6.144 bit mà một FIFO hoạt động cần, với RTL array là bộ nhớ giao kèm (PARA_AFIFO_MEM_USE_MACRO = 0). | Decide shared FIFO array or single-path build |


**Score / Điểm:** 3 of 5 for `area_power`. No area or power basis (F-017 Major); proxy of about 320 flops derived here; storage doubling (F-018).

## 12. Performance and throughput / Hiệu năng và thông lượng

**EN.** The throughput contract is clear (one sample per read, at most f_APB/2) and the formulas are right, but no metric has a value for a named workload. Using the OV7670 timing supplied with this review the required APB clock is 48 MHz (continuous) or 96 MHz (gated) at zero wait, and the default FIFO rides through 333 ns, which shows that depth and clock must be chosen from a workload, not left open.

**VI.** Hợp đồng thông lượng rõ ràng (một sample mỗi lần đọc, tối đa f_APB/2) và các công thức đúng, nhưng không metric nào có giá trị cho workload có tên. Với timing OV7670 kèm theo review này, clock APB cần 48 MHz (continuous) hoặc 96 MHz (gated) khi zero-wait, và FIFO mặc định chịu được 333 ns, cho thấy depth và clock phải chọn từ workload chứ không để mở.

### Quantified demand / Nhu cầu được định lượng (derived, INFERENCE)

| Case | Peak sample rate | Minimum f_APB, continuous mode (2 cycles per read) | Minimum f_APB, gated mode (4 x f_pixel) | Basis |
|---|---:|---:|---:|---|
| OV7670 VGA YUV, 30 fps | 24 Msample/s (PCLK 24 MHz) | 48 MHz | 96 MHz plus margin | tLINE = 784 tp, tp = 2 PCLK, 510 lines: 799,680 PCLK per frame |
| Same, average over a frame | 18.4 Msample/s | 36.9 MHz | not applicable (peak rule) | active fraction 640 x 480 / (784 x 510) = 76.8 percent |
| 720p30 YUV422 (assumed workload) | 55.3 Msample/s | 110.6 MHz | 221 MHz | 1280 x 720 x 30 x 2 samples |
| FIFO ride-through at depth 8 | 8 entries / 24 MHz = 333 ns | | | default depth |

Metrics of the HDS: PERF-001 (no value), PERF-002 (f_APB/2 as a bound), PERF-003 (formula only), PERF-004 (2 APB cycles per read, quantified), PPA-001 (no value) are listed as unquantified except PERF-004. The depth example (25 MHz x 10 us = 250, plus 16 gives 266, rounded to 512) was checked and is correct. / Các metric của HDS: PERF-001 (không có giá trị), PERF-002 (f_APB/2 là cận), PERF-003 (chỉ công thức), PERF-004 (2 chu kỳ APB mỗi lần đọc, có số), PPA-001 (không có giá trị) được liệt kê là chưa định lượng trừ PERF-004. Ví dụ depth (25 MHz x 10 us = 250, cộng 16 ra 266, làm tròn 512) đã kiểm tra và đúng.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-019 | Major | PERF-001..003 (lines 1961-1963), §13 sizing (line 1969), REQ-PERF-001 (line 135) | INFERENCE: PERF-001, PERF-002, PERF-003 and PPA-001 carry no number ("pending" or "mode-specific contract"); only PERF-004 (two APB cycles per read) and the 4 x f_pixel rule are quantified. Derived from the OV7670 figure: peak 24 Msample/s and average 24 x 0.768 = 18.4 Msample/s (active fraction 640 x 480 / 784 x 510 = 76.8 percent); continuous mode needs f_APB >= 48 MHz at zero wait and gated mode needs f_APB >= 96 MHz plus margin; a 720p30 YUV422 stream (55.3 Msample/s, assumed workload) needs 110.6 MHz and 221 MHz. | INFERENCE: PERF-001, PERF-002, PERF-003 và PPA-001 không có số (ghi pending hoặc mode-specific contract); chỉ PERF-004 (hai chu kỳ APB mỗi lần đọc) và quy tắc 4 x f_pixel có số. Suy ra từ hình OV7670: đỉnh 24 Msample/s và trung bình 24 x 0,768 = 18,4 Msample/s (tỷ lệ active 640 x 480 / 784 x 510 = 76,8 phần trăm); continuous mode cần f_APB >= 48 MHz zero-wait, gated mode cần f_APB >= 96 MHz cộng margin; luồng 720p30 YUV422 (55,3 Msample/s, workload giả định) cần 110,6 MHz và 221 MHz. | Quantify PERF-001..003 and the supported workload range |


**Score / Điểm:** 3 of 5 for `performance`. Formulas exist and are correct (the 512-entry example checks out) but carry no values (F-019 Major).

## 13. Software and application ease / Dễ lập trình và ứng dụng

**EN.** The register model is small (6 registers plus FIFO_DATA) and the software sequence is documented. The effort lands on the driver where the hardware gives no support: no frame boundary (F-002), no recovery from overflow (F-020) and a refused mode write that reports nothing (F-021).

**VI.** Mô hình register nhỏ (6 register cộng FIFO_DATA) và trình tự phần mềm đã được tài liệu hoá. Công sức dồn vào driver ở những chỗ phần cứng không hỗ trợ: không có biên frame (F-002), không phục hồi được sau overflow (F-020) và lệnh ghi mode bị từ chối mà không báo gì (F-021).

### Programming model / Mô hình lập trình

Registers (workbook `VLSIT_DVP_CONTROLLER_CSR.json`): `dvp_version` 0x0, `dvp_ctrl` 0x4 (capture_en, pclk_mode), `dvp_wmark` 0x8 (level), `dvp_timeout` 0xC (cycles), `dvp_fifo_sts` 0x10 (active, empty, full, ovf W1C), `dvp_fifo_level` 0x14 (count); the data endpoint FIFO_DATA at 0x100. Flows: S01..S11 of §11.2 (configure sensor, program watermark and timeout, clear overflow, enable capture, serve DMA requests, drain, handle timeout or overflow, disable). Error reporting: PSLVERR on timeout, endpoint write and misaligned access; sticky ovf. Compatibility: the model has no frame event or interrupt, so a driver must poll and count pixels. / Các register (workbook `VLSIT_DVP_CONTROLLER_CSR.json`): `dvp_version` 0x0, `dvp_ctrl` 0x4 (capture_en, pclk_mode), `dvp_wmark` 0x8 (level), `dvp_timeout` 0xC (cycles), `dvp_fifo_sts` 0x10 (active, empty, full, ovf W1C), `dvp_fifo_level` 0x14 (count); endpoint dữ liệu FIFO_DATA tại 0x100. Luồng: S01..S11 ở §11.2 (cấu hình sensor, lập trình watermark và timeout, xoá overflow, bật capture, phục vụ DMA request, xả, xử lý timeout hoặc overflow, tắt). Báo lỗi: PSLVERR khi timeout, ghi endpoint và truy cập lệch; ovf sticky. Tương thích: mô hình không có sự kiện frame hay interrupt nên driver phải polling và đếm pixel.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-020 | Major | §12 (line 1955), DEC-025 (line 2206), RST-SW (line 462), §7.3 (line 464) | INFERENCE: ERR-001 drops the newest sample and sets a sticky flag; §7.3 states "No software FIFO flush is implemented" and DEC-025 keeps the queued samples when capture stops. A dropped pixel shifts every later pixel of the frame and, because the stream has no frame marker (F-002), of later frames until the FIFO has been drained by reads of unknown count. | INFERENCE: ERR-001 bỏ sample mới nhất và set cờ sticky; §7.3 nêu không có software FIFO flush và DEC-025 giữ các sample đang xếp hàng khi dừng capture. Một pixel bị rơi làm lệch mọi pixel sau đó trong frame và, vì luồng không có marker frame (F-002), cả các frame sau cho tới khi FIFO được xả bằng số lần đọc không biết trước. | Add fifo_clr and the overflow recovery sequence to §11.2 |
| F-021 | Minor | REQ-FUNC-004 (line 129), DEC-018 (line 2199), §10.6 (line 1817), D28 (line 1828) | FACT: the mode bit keeps its old value when capture is enabled, either FIFO is nonempty or the source is not quiescent, "while the APB write completes with OKAY" and software "shall read back the field". The other bits of the same word are written. | FACT: bit mode giữ giá trị cũ khi capture đang bật, một trong hai FIFO còn dữ liệu hoặc nguồn chưa quiescent, trong khi lệnh ghi APB vẫn hoàn tất OKAY và phần mềm phải đọc lại field. Các bit khác của cùng word vẫn được ghi. | Flag a refused mode write |


**Score / Điểm:** 3 of 5 for `software_ease`. Small register model (6 registers) and a documented sequence, but no flush or recovery path (F-020) and a silent mode refusal (F-021).

## 14. DFT / DFT

**EN.** Section 16 defers scan, test clocks, test reset and ATPG constraints to the SoC and leaves them TBD. The design has structures that decide the answer, so deferral is not an acceptable "N/A".

**VI.** Mục 16 đẩy scan, test clock, test reset và ràng buộc ATPG cho SoC và để TBD. Thiết kế có những cấu trúc quyết định câu trả lời nên việc trì hoãn không phải N/A chấp nhận được.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-022 | Major | §16 (lines 2079-2088), G-004..G-006 of the gap scan | INFERENCE: §16 is a table of "Integration TBD" and "TBD" entries. The design has a PCLK that stops in mode 1 (a scan shift clock cannot depend on it), a falling-edge sample option, a reset crossing between domains (F-009) and a bundled-data crossing that scan capture can corrupt. None is analysed, and "N/A" is not argued. | INFERENCE: §16 là bảng các mục Integration TBD và TBD. Thiết kế có PCLK dừng ở mode 1 (xung scan shift không thể phụ thuộc vào nó), tuỳ chọn lấy mẫu cạnh xuống, crossing reset giữa các miền (F-009) và crossing bundled-data mà scan capture có thể làm hỏng. Không cái nào được phân tích và N/A không được lập luận. | Write the DFT statement for both clocks and the reset |


**Score / Điểm:** 3 of 5 for `dft`. Section 16 is all TBD while the design has stoppable clock, edge option and reset crossing (F-022).

## 15. Security and RAS / An toàn và độ tin cậy

**EN.** The security stance is explicit: APB is the only access path, PPROT is ignored, no secret is held and pixel privacy is left to the SoC; this is a recorded decision and is waived (F-023). Reliability: no ECC or parity on the FIFO, no safety class, and only one sticky fault flag.

**VI.** Lập trường bảo mật rõ ràng: APB là đường truy cập duy nhất, PPROT bị bỏ qua, không giữ bí mật và quyền riêng tư pixel dành cho SoC; đây là quyết định đã ghi và được waive (F-023). Độ tin cậy: không ECC hay parity cho FIFO, không có safety class và chỉ một cờ lỗi sticky.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-023 | Observation | §1.2 (line 62), §18 (lines 2139-2142) | FACT: i_protect_en is tied low, PPROT does not filter access, and §18 says camera pixels "may be privacy-sensitive at SoC level". This is a recorded decision ("a claim of no security decision is a decision"), so any APB requester that can reach FIFO_DATA can read the video. | FACT: i_protect_en nối mức thấp, PPROT không lọc truy cập và §18 nêu pixel camera có thể nhạy cảm về riêng tư ở mức SoC. Đây là quyết định đã ghi lại, nên mọi APB requester truy cập được FIFO_DATA đều đọc được video. | Record the waiver in the integration guide |
| F-024 | Minor | §18 ECC and diagnostics rows (lines 2143-2145), ERR-001..006 (lines 1946-1953) | INFERENCE: ECC or parity for the FIFO storage is "None selected", the safety goal is "TBD", the only fault record is dvp_fifo_sts.ovf, and there is no drop counter, no timeout flag and no gated-overrun flag. A drone or vehicle camera use case may be safety related, which the HDS does not rule out. | INFERENCE: ECC hoặc parity cho bộ nhớ FIFO là không chọn, safety goal là TBD, bản ghi lỗi duy nhất là dvp_fifo_sts.ovf, và không có bộ đếm drop, cờ timeout hay cờ gated-overrun. Ứng dụng camera trên drone hoặc xe có thể liên quan an toàn, HDS không loại trừ điều này. | Add drop counter and diagnostic flags; record the safety stance |


**Score / Điểm:** 4 of 5 for `security_ras`. The security stance is explicit and waived (F-023); the diagnostic thinness is Minor (F-024).

## 16. Verification quality / Chất lượng kiểm chứng

**EN.** Every requirement traces to a test and the plan covers widths, edges, polarities, both modes, timeouts, mode lock, reset and DMA. The boundary of the evidence is stated honestly: static checks only. The plan lacks assertion IDs, a formal property set and the cases that matter most (DMA stall, tail, gated violation, long timeout).

**VI.** Mọi requirement đều truy vết tới một test và kế hoạch phủ độ rộng, cạnh, cực tính, hai mode, timeout, khoá mode, reset và DMA. Ranh giới bằng chứng được nêu trung thực: chỉ kiểm tra tĩnh. Kế hoạch thiếu assertion ID, bộ property formal và các tình huống quan trọng nhất (DMA treo, phần dư, vi phạm gated, timeout dài).

### Traceability and evidence / Truy vết và bằng chứng

| Item | Value | Source |
|---|---|---|
| Requirements | 19 (`REQ-*`) | inventory.json |
| Tests | 15 (TEST-001..015) | HDS section 15.2 |
| Assertion IDs | 0 | inventory.json |
| Requirements without a test | 0 | inventory.json |
| Rule check | PASS, 12 files, 0 errors, 21 warnings | verification/README.md |
| Verilator / Slang | PASS, 0 errors, 24 / 2 warnings | verification/lint |
| Simulation | not run | RTL_GENERATION_REPORT.md |
| Formal, CDC, RDC | pending / required before sign-off | HDS section 15.4 |

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-025 | Major | verification/README.md, RTL_GENERATION_REPORT.md (Verification boundary), §15.1 (line 2034) | FACT: the generation report says "No behavioral testbench or simulation regression was executed", and verification/README.md lists rule check (12 files, 0 errors, 21 warnings), Verilator (26 files, 0 errors, 24 warnings), Slang (0 errors, 2 warnings), profile elaboration, and static structure checks only. TEST-001..015 are "future stimuli", which the HDS states itself. | FACT: báo cáo generation nêu không chạy testbench hay regression mô phỏng, và verification/README.md chỉ liệt kê rule check (12 file, 0 lỗi, 21 cảnh báo), Verilator (26 file, 0 lỗi, 24 cảnh báo), Slang (0 lỗi, 2 cảnh báo), elaboration theo profile và kiểm tra cấu trúc tĩnh. TEST-001..015 là kích thích tương lai, HDS cũng nói như vậy. | Run the directed and random simulation for TEST-001..015 |
| F-026 | Major | §15.3 (lines 2056-2067), §15.4 (lines 2069-2075), TEST-005 (line 2045) | INFERENCE: the inventory finds 0 property IDs; §15.3 lists intents in prose and §15.4 says "Property set pending". Traceability is complete (0 requirements without a test), but no test covers the DMA stall of F-004, the tail of F-005, a gated spacing violation (F-010), a long timeout blocking the APB (F-007) or a real sensor timing model (the OV7670 and onsemi corpus is not used as stimulus). | INFERENCE: bước inventory không tìm thấy property ID nào; §15.3 liệt kê ý định bằng văn xuôi và §15.4 ghi property set đang chờ. Truy vết đầy đủ (0 requirement thiếu test), nhưng không test nào phủ treo DMA của F-004, phần dư của F-005, vi phạm khoảng cách gated (F-010), timeout dài chặn APB (F-007) hay timing sensor thực (corpus OV7670 và onsemi chưa dùng làm stimulus). | Add SVA IDs, the missing tests and the formal property list |


**Score / Điểm:** 2 of 5 for `verification_quality`. Full requirement trace, but no simulation (F-025) and no assertion IDs, formal or stall tests (F-026).

## 17. Documentation and traceability / Tài liệu và truy vết

**EN.** Identifiers are stable (REQ, DEC, TEST, WF, CDC, EXC), 29 decisions are logged and the gap scan reports 0 BLOCK gaps. The residue is template text, a broken anchor, two HDS files of the same name and a decision order that is not sorted.

**VI.** Các định danh ổn định (REQ, DEC, TEST, WF, CDC, EXC), 29 decision được ghi lại và gap scan báo 0 gap BLOCK. Phần tồn đọng là văn bản template, một anchor hỏng, hai file HDS cùng tên và thứ tự decision chưa sắp xếp.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-027 | Minor | Purpose block (line 17), §22 (lines 2230-2243), link at line 2232 | FACT: line 17 still says "Replace every angle-bracket placeholder", §22 is titled "References used to shape this template" and lists Arm and Synopsys pages unrelated to the DVP design, and its link to #21-normative-references points to a section that does not exist (the normative references are §2.1, §21 is the glossary). | FACT: dòng 17 vẫn ghi hãy thay mọi placeholder, §22 có tiêu đề các tham chiếu định hình template và liệt kê các trang Arm, Synopsys không liên quan thiết kế DVP, và link tới #21-normative-references trỏ tới mục không tồn tại (tham chiếu chuẩn là §2.1, §21 là glossary). | Remove template residue from the HDS |
| F-028 | Minor | Front matter (lines 1-11), IP README, §20 DEC order (lines 2188-2196), REF-003 (line 90) | FACT: the front matter says version 0.2 and status Draft while the IP README calls this package the "approved" HDS, a baseline HDS of the same name remains in spec/ with different content, DEC-017 appears before DEC-014, and REF-003 and the naming rule cite C:\Users\PC\.codex paths. | FACT: front matter ghi version 0.2 và status Draft trong khi README của IP gọi gói này là HDS approved, một HDS baseline cùng tên vẫn nằm trong spec/ với nội dung khác, DEC-017 đứng trước DEC-014, và REF-003 cùng naming rule dẫn tới đường dẫn C:\Users\PC\.codex. | Align front matter, archive the baseline, sort DEC |


**Score / Điểm:** 4 of 5 for `documentation`. Stable IDs, a decision log and a gap scan; only template residue and version alignment (F-027, F-028) are Minor.

## 18. Integration effort and bring-up / Công sức tích hợp và bring-up

**EN.** The integrator must supply the clock relationship, sensor profile (at elaboration), APB and DMA hookup, SDC numbers, library and DFT flow (15 open INFO items). The largest risk is that mode 1 depends on sensor and board behaviour that the HDS does not tie to any datasheet.

**VI.** Integrator phải cung cấp quan hệ clock, profile sensor (lúc elaboration), kết nối APB và DMA, số SDC, library và luồng DFT (15 mục INFO còn mở). Rủi ro lớn nhất là mode 1 phụ thuộc vào hành vi sensor và board mà HDS không gắn với datasheet nào.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-029 | Major | REF-006 (line 93), DEC-006 (line 2187), §2.3 (line 111), research D01 D04 D08 | INFERENCE: REF-006 and DEC-006 leave the sensor revision and mode unselected and call it an external dependency. Mode 1 requires no PCLK edge during active VSYNC or an HREF-high gap, and a VSYNC pulse of at least four APB cycles. The research report documents free-running or gated PCLK as a register option for OV7670 and OV7725 and a continuous PIXCLK through blanking for MT9V024, but the HDS does not map either mode to a datasheet condition. | INFERENCE: REF-006 và DEC-006 để trống revision và mode sensor và coi là phụ thuộc bên ngoài. Mode 1 yêu cầu không có cạnh PCLK trong lúc VSYNC active hay trong khoảng HREF cao không có pixel, và xung VSYNC tối thiểu bốn chu kỳ APB. Research report ghi PCLK free-running hoặc gated là tuỳ chọn register của OV7670 và OV7725 và PIXCLK liên tục qua blanking của MT9V024, nhưng HDS không ánh xạ mode nào sang điều kiện datasheet. | Validate mode 0 and mode 1 against two real sensor modes |
| F-030 | Minor | verification/static/hds_gaps.log (G-001..G-015), §20 ASM-001, ASM-002 | FACT: the gap scan reports 0 BLOCK gaps and 15 INFO items (SoC, library, clocks, DFT, STA/SDC, corners, safety class), all created on 2026-11-21 or 2026-11-22 (age one day). The folder holds no integration guide, no example hookup and no constraint file. | FACT: gap scan báo 0 gap BLOCK và 15 mục INFO (SoC, library, clock, DFT, STA/SDC, corner, safety class), đều tạo ngày 2026-11-21 hoặc 2026-11-22 (tuổi một ngày). Thư mục không có integration guide, ví dụ kết nối hay file constraint. | Write the integration checklist |


**Score / Điểm:** 3 of 5 for `integration_effort`. No sensor mode validated against mode 1 (F-029 Major); open items are inputs without a checklist (F-030).

## 19. Market position / Vị thế thị trường

**EN.** Compared with the camera interfaces of ST, NXP and Espressif, DVP_Controller matches the basic capture and DMA notification and adds a gated PCLK path and an explicit overflow policy, but it has no packing, no frame event, no crop and compile-time polarity. The four features that close most of the gap are listed in F-031.

**VI.** So với giao diện camera của ST, NXP và Espressif, DVP_Controller ngang bằng ở capture cơ bản và thông báo DMA, có thêm đường gated PCLK và chính sách overflow rõ ràng, nhưng không có packing, không có sự kiện frame, không crop và cực tính cố định lúc compile. Bốn tính năng thu hẹp phần lớn khoảng cách được nêu ở F-031.

### Comparison table / Bảng so sánh (sources are web search summaries dated 2026-11-22; no reference manual was opened)

| Expectation | DVP_Controller | ST STM32 DCMI | NXP MCUXpresso CSI | Espressif ESP32-S3 LCD_CAM | Verdict |
|---|---|---|---|---|---|
| Data packing | one sample per 32-bit word | 32-bit word from four 8-bit pixel clocks (ST AN5020 Rev 4, Dec 2024, web 2026-11-22) | not confirmed in the sources | not confirmed in the sources | missing |
| Polarity and edge | compile-time | pixel clock edge configurable (ST AN5020, web 2026-11-22) | not confirmed | not confirmed | missing (INFERENCE that DCMI sets them at run time) |
| Frame-end event | none | capture ends at the frame end after disable (ST AN5020) | end-of-frame interrupt (NXP MCUXpresso API reference, web 2026-11-22) | GDMA end-of-frame on VSYNC or byte count (Espressif esp-hal docs, web 2026-11-22) | missing |
| Crop and decimation | none | crop window and odd or even line capture (ST AN5020) | not confirmed | not confirmed | missing |
| FIFO and DMA request | watermark REQ and ACK | not confirmed | RX and statistics FIFOs with a FIFO DMA request (NXP MCUXpresso API reference) | GDMA (Espressif docs) | matched in principle |
| Gated PCLK path | yes, mode 1 | not confirmed | not confirmed | not confirmed | exceeded or unique, not confirmable |
| Maximum data width | 12 bits | 8 to 14 bits (ST AN5020) | not confirmed | 8 or 16 lines (Espressif forum and docs) | narrower |

Sources: ST AN5020, Rev 4 (December 2024), `st.com`; NXP MCUXpresso SDK API reference and application note AN12686, `nxp.com`; Espressif documentation and esp-hal docs, `docs.espressif.com`, all read as search summaries on 2026-11-22. A cell marked "not confirmed" means the search summary did not state it, not that the feature is absent. / Một ô ghi not confirmed nghĩa là tóm tắt tìm kiếm không nêu, không có nghĩa là tính năng không tồn tại.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-031 | Major | §1.3 (lines 66-71), §6.4 (line 432), §9 (line 493); sources in section 19 of this report | INFERENCE (sources dated 2026-11-22, summaries only): ST AN5020 Rev 4 describes a 32-bit packing of four 8-bit samples, a crop window, odd or even line decimation and a capture that ends at the frame end; NXP MCUXpresso documents an end-of-frame interrupt, RX and statistics FIFOs with a DMA request and a frame-buffer queue; Espressif documents GDMA end-of-frame on VSYNC or byte count. DVP_Controller matches the basic capture, gated PCLK and overflow flag, but has none of the frame-level services. | INFERENCE (nguồn ngày 2026-11-22, chỉ là tóm tắt): ST AN5020 Rev 4 mô tả ghép 32 bit từ bốn sample 8 bit, cửa sổ crop, decimation dòng chẵn hoặc lẻ và capture kết thúc ở cuối frame; NXP MCUXpresso ghi end-of-frame interrupt, RX FIFO và statistics FIFO có DMA request cùng hàng đợi frame buffer; Espressif ghi GDMA end-of-frame theo VSYNC hoặc số byte. DVP_Controller có capture cơ bản, gated PCLK và cờ overflow nhưng không có dịch vụ nào ở mức frame. | Adopt the four priority features for release 1 |


**Score / Điểm:** 2 of 5 for `market_position`. Basic capture matches the compared parts but the frame-level services are missing (F-031), which changes the driver architecture.

## 20. Actions / Hành động

**EN.** Ordered by priority: P0 items block integration, P1 items block sign-off, P2 and P3 can follow. The three P0 groups are the DMA request rule with its tail flush, the gated-mode reset and the simulation.

**VI.** Sắp theo ưu tiên: P0 chặn tích hợp, P1 chặn sign-off, P2 và P3 có thể làm sau. Ba nhóm P0 là quy tắc DMA request cùng tail flush, reset của gated mode và mô phỏng.

| Priority | Action | Owner | Blocks sign-off |
|---|---|---|---|
| P0 | Change the DMA FSM to burst-counted service and update REQ-IF-004, DEC-008 (F-004) | Spec, RTL | yes |
| P0 | Define the end-of-frame flush request in §6.3 and §10.1 (F-005) | Spec, RTL | yes |
| P0 | Re-implement DEC-029 without a cross-domain reset (F-009) | Spec, RTL | yes |
| P0 | Run the directed and random simulation for TEST-001..015 (F-025) | Verification | yes |
| P1 | Write the reference workload table and sizing result in §13 (F-001) | Spec | yes |
| P1 | Add frame/line counters, frame_done and snapshot to the CSR workbook and §10 (F-002) | Spec, RTL | yes |
| P1 | Add the interrupt output and registers (spec, CSR workbook, RTL) (F-006) | Spec, RTL | yes |
| P1 | Bound dvp_timeout, define PRDATA on error, add rd_to flag (F-007) | Spec, RTL, SoC | yes |
| P1 | Add the gated-mode overrun detector and flag (F-010) | Spec, RTL | yes |
| P1 | Decide runtime polarity and edge selection (HAS decision, then RTL) (F-011) | Spec, RTL, DFT | yes |
| P1 | Deliver the SDC template with parameterised clock and I/O budgets (F-015) | SDC, SoC | yes |
| P1 | Quantify EXC-003 and the margin rule (F-016) | SDC | yes |
| P1 | Quantify PERF-001..003 and the supported workload range (F-019) | Spec | yes |
| P1 | Add fifo_clr and the overflow recovery sequence to §11.2 (F-020) | Spec, RTL | yes |
| P1 | Add SVA IDs, the missing tests and the formal property list (F-026) | Verification, Spec | yes |
| P1 | Validate mode 0 and mode 1 against two real sensor modes (F-029) | Integration, Spec | yes |
| P1 | Adopt the four priority features for release 1 (F-031) | Spec | yes |
| P2 | Add the supported sensor-mode table to §1 and §8 (F-003) | Spec | no |
| P2 | Write the DMA contract table (F-008) | Spec | no |
| P2 | Bound the CSR field widths and add the range check (F-012) | Spec, RTL | no |
| P2 | Specify the packed read mode and lane order (F-013) | Spec, RTL | no |
| P2 | Document the clocking structure in §14.3 (F-014) | Spec | no |
| P2 | Add the area proxy and power statement to §13 (F-017) | Spec | no |
| P2 | Decide shared FIFO array or single-path build (F-018) | Spec, RTL | no |
| P2 | Flag a refused mode write (F-021) | Spec, RTL | no |
| P2 | Write the DFT statement for both clocks and the reset (F-022) | DFT, Spec | no |
| P2 | Add drop counter and diagnostic flags; record the safety stance (F-024) | Spec, RTL | no |
| P2 | Write the integration checklist (F-030) | Spec, Integration | no |
| P3 | Record the waiver in the integration guide (F-023) | SoC architect | no |
| P3 | Remove template residue from the HDS (F-027) | Spec | no |
| P3 | Align front matter, archive the baseline, sort DEC (F-028) | Spec | no |

## 21. Evidence appendix / Phụ lục bằng chứng

**EN.** Files reviewed, gate results, the audit of the review, what could not be assessed and why. The report was produced from reading; no RTL was simulated, no synthesis, CDC or STA tool was run, and the RTL was not cross-checked against the specification (that is the implementation review, skill vlsit-ip-impl-review).

**VI.** Các file đã review, kết quả gate, audit của chính review, phần không đánh giá được và lý do. Báo cáo được tạo từ việc đọc; không mô phỏng RTL, không chạy công cụ tổng hợp, CDC hay STA, và RTL không được đối chiếu với spec (đó là review triển khai, skill vlsit-ip-impl-review).

### 21.1 Files reviewed / File đã đọc (SHA-256, first 16 hex)

| File (under 025_DVP_Controller) | Role | SHA-256 |
|---|---|---|
| `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md` | approved HDS (reviewed) | `94967f2cc5f1a3d3` |
| `spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_CSR.json` | CSR source | `af38380b707e2651` |
| `spec/VLSIT_DVP_CONTROLLER_HDS.md` | baseline HDS (traceability only) | `19c90c2972beb344` |
| `README.md` | IP README | `182ffe749daec801` |
| `research/research_report.md` | DVP research | `4622364824f3fb46` |
| `spec/rtl_generation_2026-11-22/RTL_GENERATION_REPORT.md` | generation report | `ea8fee57bdb19b3f` |
| `verification/README.md` | verification evidence | `b577ebdf9fd57960` |
| `verification/static/hds_gaps.log` | gap scan | `f23fb77160e45c9c` |
| `verification/lint/verilator_final.log` | lint log | `79d0759f3471ec06` |
| `rtl/m_dvp_gate_bridge.sv` | searched for an overrun detector (F-010 audit) | `cd07a0ca161eb968` |

Also read: the folder tree (all files listed), `spec/rtl_generation_2026-11-22/README.md`, the CSR workbook JSON, the 18 waveform plan rows, and the converted APB specification of the micro-spec skill. Not opened: the PDF datasheets and papers under `research/sources/` (the research report was relied on), and the draw.io and SVG figure sources.

### 21.2 Requirement and open-item extraction / Trích xuất

`inventory.json` (same folder): 62 sections, 43 tables, 19 requirements (FUNC 8, IF 6, PARAM 1, PERF 1, REG 1, RESET 1, SCOPE 1), 15 tests, 0 property IDs, 0 requirements without a test, open items ASM-001 and ASM-002 (both resolved by decisions on 2026-11-21 and 2026-11-22) and 15 INFO items of the gap scan (age one day). Quantified claims: 7.

### 21.3 Gate / Cổng

- `RESULT: PASS, 31 finding(s), written C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\025_DVP_Controller\review\gate_metrics.json`
- `RESULT: 31 finding(s) in 17 group(s), written C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\025_DVP_Controller\review\root_cause_groups.json`
- Waiver usage: 1 of 10 (F-023; owner SoC architect; invalidation condition recorded in `vlsit_spec_2026-11-22.md`).
- Deep analysis: 31 of 31 findings traced against the cited text, at most 4 per root-cause group (limit 10), none aggregated, so no further analysis needs the user approval of rule R-022.

### 21.4 Root-cause groups / Nhóm root cause

| Group | Root cause | Findings | Members |
|---|---|---:|---|
| G-01 | RC-APBWAIT | 1 | F-007 |
| G-02 | RC-AREA | 2 | F-017, F-018 |
| G-03 | RC-COMPAT | 1 | F-003 |
| G-04 | RC-COMPILE-TIME | 1 | F-011 |
| G-05 | RC-DFT-CLK | 2 | F-014, F-022 |
| G-06 | RC-DMA | 2 | F-004, F-005 |
| G-07 | RC-DMAIF | 1 | F-008 |
| G-08 | RC-DOC | 2 | F-027, F-028 |
| G-09 | RC-FRAME | 4 | F-002, F-006, F-020, F-031 |
| G-10 | RC-GATED-SILENT | 1 | F-010 |
| G-11 | RC-RESET | 1 | F-009 |
| G-12 | RC-SDC | 3 | F-015, F-016, F-030 |
| G-13 | RC-SECURITY | 1 | F-023 |
| G-14 | RC-SENSOR | 1 | F-029 |
| G-15 | RC-SW-SILENT | 3 | F-012, F-021, F-024 |
| G-16 | RC-THROUGHPUT | 3 | F-001, F-013, F-019 |
| G-17 | RC-VERIF | 2 | F-025, F-026 |

### 21.5 Audit of the review / Audit review (R-021)

Deterministic sample of 4 of 31 findings (hash of the ID). The same reviewer re-read the cited lines; a second reviewer was not available, so the false-negative figure covers only the neighbourhood of the sampled findings.

| No. | Finding | Severity | Root cause | Judgement | Basis |
|---|---|---|---|---|---|
| 1 | F-009 | High | RC-RESET | tp | DEC-029 (line 2210), section 2.2 item 4 (line 99) and RST-DVP-LOCAL (line 461) re-read: the gated registers are reset from the APB-local reset while the table assigns the capture side to a PCLK-local reset. |
| 2 | F-003 | Medium | RC-COMPAT | tp | ASM-001 (line 2180) and research_report.md rows D03, D04 and D07 re-read: HSYNC-pulse and XOR line-valid modes exist and are outside the supported profile. |
| 3 | F-010 | High | RC-GATED-SILENT | tp | Section 10.6 (line 1834) re-read and the HDS and m_dvp_gate_bridge.sv searched for an overrun or miss detector: none found, so the failure is silent. |
| 4 | F-019 | High | RC-THROUGHPUT | tp | PERF-001..003 and PPA-001 (lines 1961-1964) re-read: no numeric value; the derived figures were recomputed (24 x 0.768 = 18.4; 2 x 24 = 48; 4 x 24 = 96). |

False positives: 0 of 4. False negatives found in the neighbourhood: 0 of 4. / Dương tính giả: 0 trên 4. Âm tính giả tìm thấy ở vùng lân cận: 0 trên 4.

### 21.6 Not assessed / Chưa đánh giá

1. Mapped area, power and any frequency: no Liberty library, corner or clock period.
2. Behaviour of the RTL: not simulated (`verification/README.md`); no cross-check of RTL against the HDS.
3. CDC, RDC, formal and STA results: none exist in the folder.
4. Commercial IP details beyond search summaries: no reference manual was opened; the table of §19 marks unconfirmed cells.
5. Requirements of the ISO or any camera-interface standard: none applies (no universal DVP standard); sensor datasheets were relied on through the research report.
6. The baseline HDS was not reviewed in depth; it is a superseded revision.
