# Specification review: USB 2.0 Controller / Đánh giá đặc tả: USB 2.0 Controller

| Field / Trường | Value / Giá trị |
|---|---|
| IP | USB 2.0 Controller (device, host, dual-role; UTMI+ or ULPI) |
| Specification reviewed | C:\HQuan\102_MyGithub\VLSIT_OPEN_IP_CORE\023_USB20_Controller\VLSIT_USB20_CONTROLLER_HDS.md |
| Revision and date | version 0.1 draft, 2026-11-20 |
| Reviewer | Claude (skill vlsit-ip-spec-review) |
| Review date | 2026-11-20 |
| Verdict / Kết luận | Conditional (weighted 2.95) |

Precedence: rule.md overrides SKILL.md, and SKILL.md overrides the files under reference/, when they differ. / Thứ tự ưu tiên: rule.md thắng SKILL.md, SKILL.md thắng các file trong reference/ khi khác nhau.

## 1. Executive summary / Tóm tắt điều hành

**EN.** FACT: the specification (version 0.1) defines a synthesizable USB 2.0 controller with device, host and dual-role operation, UTMI+ or ULPI PHY interfaces, an APB4 register block of 44 registers, AXI4 master DMA or AXI4 slave with DMA handshake, and 23 features; 59 requirements are each traced to a test. The review finds one Blocker, 12 Major findings, 16 Minor findings and 5 Observations. The Blocker is the missing safe clock-domain crossing for the multi-bit endpoint and channel registers (F-001). The three actions that matter most are: define a held-data crossing for the CSR banks (F-001, F-002), obtain official UTMI+, ULPI and AXI4 texts and finish the ULPI low power, split and UTMI+ mode tables (F-004 to F-008), and add the RAM bandwidth, turnaround budget and PHY timing numbers (F-003, F-009, F-010).

**VI.** FACT: spec (phiên bản 0.1) định nghĩa USB 2.0 controller synthesize được với device, host và dual-role, giao diện PHY UTMI+ hoặc ULPI, khối thanh ghi APB4 gồm 44 thanh ghi, DMA AXI4 master hoặc AXI4 slave với DMA handshake, và 23 feature; 59 yêu cầu đều được truy vết tới test. Review thấy một Blocker, 12 phát hiện Major, 16 phát hiện Minor và 5 Observation. Blocker là thiếu crossing clock-domain an toàn cho thanh ghi endpoint và channel nhiều bit (F-001). Ba việc quan trọng nhất: định nghĩa crossing giữ dữ liệu cho các bank CSR (F-001, F-002), lấy bản chính thức của UTMI+, ULPI và AXI4 rồi hoàn thiện bảng ULPI low power, split và chế độ UTMI+ (F-004 đến F-008), và bổ sung số băng thông RAM, ngân sách turnaround và timing PHY (F-003, F-009, F-010).

### 1.1 Top findings / Phát hiện quan trọng nhất

| ID | Severity | Locator | Finding (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-001 | Blocker | section 7.2 CDC-001, CDC-003, section 11.3 (u2_epi_*, u2_epo_*, u2_hc_* banks), section 11.2 S13 and S15 | FACT: CDC-001 says the bundled values change only while the core is disabled, but S13, S15 and S17 of section 11.2 write ep_en, ch_en, set_nak, set_d0, stall and port_rst while core_en = 1, and section 11.3 routes the whole u2_epi_*, u2_epo_* and u2_hc_* banks (about 3 800 control flip-flops at the default counts, proxy from regs_usb2.json) through CDC-001 and CDC-003, which are a level synchronizer and a pulse synchronizer. No structure carries a 32-bit field such as u2_epi_dma.addr safely from CLK-BUS to CLK-PHY. | FACT: CDC-001 nói các giá trị chỉ đổi khi core bị tắt, nhưng S13, S15 và S17 ở mục 11.2 ghi ep_en, ch_en, set_nak, set_d0, stall và port_rst khi core_en = 1, và mục 11.3 đưa toàn bộ bank u2_epi_*, u2_epo_*, u2_hc_* (khoảng 3 800 flip-flop điều khiển ở số lượng mặc định, proxy từ regs_usb2.json) qua CDC-001 và CDC-003, tức bộ đồng bộ level và pulse. Không có cấu trúc nào truyền an toàn trường 32 bit như u2_epi_dma.addr từ CLK-BUS sang CLK-PHY. | Define a request and acknowledge handshake per bank entry (data held stable while the toggle crosses), or keep the endpoint and channel registers in CLK-PHY and write them from CLK-BUS through an asynchronous FIFO; update CDC-001 and CDC-003 and the CDC verification. |
| F-002 | Major | section 7.2 CDC-002, section 11.3 (xsize, pkt_cnt, addr are rwi), section 10.2 OP-007 | FACT: xsize, pkt_cnt and the DMA address are counted down or advanced by hardware (section 11.3, rwi), and CDC-002 transfers status as synchronized levels. INFERENCE: a software read of a 19-bit counter that changes at packet rate can return a mixed value, and the rule that a software write wins over a hardware load can drop one decrement. | FACT: xsize, pkt_cnt và địa chỉ DMA do hardware đếm xuống hoặc tăng (mục 11.3, rwi) và CDC-002 truyền status dạng level đồng bộ. INFERENCE: phần mềm đọc counter 19 bit đổi theo tốc độ gói có thể nhận giá trị lẫn bit, và quy tắc phần mềm ghi thắng hardware load có thể làm mất một lần giảm. | Snapshot the counters in CLK-PHY and cross them with the same handshake as F-001, and state how a lost load is repeated. |
| F-003 | Major | section 10.4 (bandwidth check), section 7.1 (CLK-PHY 30 MHz), section 10.5 MEM-001 | INFERENCE: section 10.4 shows 50 % use of 240 MB/s (32 bits at 60 MHz). With PARA_USB2_UTMI_W = 16 the RAM is in CLK-PHY at 30 MHz (section 7.1), so one port gives 120 MB/s while the packet engine needs 60 MB/s and the bus side up to 60 MB/s, which is 100 % use with no margin for arbitration or double buffering. | INFERENCE: mục 10.4 cho thấy dùng 50 % của 240 MB/s (32 bit ở 60 MHz). Với PARA_USB2_UTMI_W = 16 RAM nằm ở CLK-PHY 30 MHz (mục 7.1), một cổng chỉ cho 120 MB/s trong khi packet engine cần 60 MB/s và phía bus tới 60 MB/s, tức 100 % và không còn dư cho arbitration hay double buffering. | Add a bandwidth table per configuration, and either widen the RAM word to 64 bits when UTMI+ is 16 bits, run the RAM on a faster clock, or limit the 16-bit configuration to full-speed traffic. |
| F-004 | Major | TBD-005, section 7.4, section 10.1.7 (ulpi_if FSM), section 6.3 (ULPI register access) | FACT: TBD-005 leaves the ULPI low power mode open, section 7.4 says the PHY clock stops in suspend, and the ulpi_if FSM has no low-power, wake or reset state. INFERENCE: without them the link cannot enter suspend or L1 in a ULPI build, nor detect resume while CLK-PHY is stopped. | FACT: TBD-005 để mở ULPI low power mode, mục 7.4 nói clock PHY dừng khi suspend, và FSM ulpi_if không có state low-power, wake hay reset. INFERENCE: thiếu chúng thì build ULPI không vào được suspend hay L1 và không phát hiện được resume khi CLK-PHY dừng. | Read the low power sections of REF-007 (Figures 46 to 49, Table 15), add the states ENUM_ST_UL_LP and ENUM_ST_UL_WAKE and requirements for the stp and dir sequences and the clock restart wait. |
| F-005 | Major | section 6.2 (o_utmi_opmode, o_utmi_xcvrsel, o_utmi_termsel), REQ-IF-001, REF-006 section 2.1.1 | FACT: section 6.2 names OpMode, XcvrSelect and TermSelect but gives no table of the values for high-speed, full-speed, low-speed, preamble, chirp and suspend, and REF-006 section 2.1.1.4 requires TXReady during chirp data. The chirp, level 3 preamble and suspend sequences depend on these values. | FACT: mục 6.2 nêu OpMode, XcvrSelect và TermSelect nhưng không có bảng giá trị cho high-speed, full-speed, low-speed, preamble, chirp và suspend, trong khi REF-006 mục 2.1.1.4 yêu cầu TXReady cả khi gửi chirp. Các chuỗi chirp, preamble level 3 và suspend phụ thuộc các giá trị này. | Add a table from REF-006 and REF-007 that maps each state of the speed FSMs to XcvrSelect, TermSelect, OpMode, DpPulldown and DmPulldown. |

## 2. Scorecard / Bảng điểm

| Area | Weight | Score | Justification |
|---|---:|---:|---|
| application_fit | 1.0 | 4 | Named product, 23 features each with an application row, explicit excluded list; values are proposals (F-034). |
| features | 1.0 | 4 | Each feature maps to requirements and a test; some requirements rest on open assumptions (F-027). |
| functions | 1.5 | 2 | Two Major gaps (ULPI low power F-004, split F-008) and four Minor gaps in the cycle detail. |
| interfaces | 1.5 | 2 | Three Major findings: UTMI+ encodings (F-005), AXI4 profile against AXI3 text (F-006), unofficial sources (F-007). |
| clock_reset_cdc | 1.5 | 1 | A Blocker: no safe crossing structure for the multi-bit endpoint and channel registers (F-001). |
| parameters | 1.0 | 4 | Parameter table complete with ranges and dependencies; only Minor gaps in checking (F-020, F-021). |
| data_representation | 0.5 | 4 | Quantity table, PID values, descriptor format are defined; no finding. |
| asic_feasibility | 1.5 | 3 | No critical-path statement and the RAM bandwidth limit (F-029, F-003); the clocking itself is synthesizable in principle. |
| sdc_timing | 1.5 | 2 | Two Major findings: interface timing numbers missing (F-010) and the named SDC files absent (F-011). |
| area_power | 1.0 | 3 | Major: no area or power number; a flip-flop proxy is given in this review (F-012). |
| performance | 1.5 | 2 | Two Major findings: RAM bandwidth with 16-bit UTMI+ (F-003) and the underived 24-cycle budget (F-009). |
| software_ease | 1.0 | 3 | Major: custom register model with no driver plan (F-013); the register set, flows and interrupt hierarchy are otherwise workable. |
| dft | 1.0 | 4 | Scan, MBIST and clock-gate test enable are addressed; ports deferred (F-031). |
| security_ras | 1.0 | 4 | Stance is explicit; only Minor findings on RAM soft error and DMA windows (F-017, F-018). |
| verification_quality | 1.5 | 4 | Full requirement to test trace; Minor gaps in interoperability and time scaling (F-026, F-028). |
| documentation | 0.5 | 3 | Major: unofficial and unverified protocol sources (F-007); open items lack owner and date (F-027). |
| integration_effort | 1.0 | 4 | Wrappers, tie-offs and macros are described; no single checklist (F-030). |
| market_position | 1.0 | 3 | Feature set is close to the references, but no area or power evidence to compare (F-032, F-012). |
| **Weighted** | **20.5** | **2.95** | **Verdict: Conditional** |


**EN.** The two lowest scores are clock, reset and CDC (1) because of the Blocker F-001, and functions, interfaces, SDC and performance (2) because each has two or more Major findings. **VI.** Hai điểm thấp nhất là clock, reset và CDC (1) do Blocker F-001, và chức năng, giao diện, SDC và hiệu năng (2) vì mỗi mục có từ hai phát hiện Major trở lên.

## 3. Application fit / Phù hợp ứng dụng

**EN.** The specification targets a drone flight controller that is a USB device (CDC-ACM, DFU, mass storage) and a host for a UVC camera or LTE modem, and each of the 23 features has an application row with a number (section 1.4). The excluded list is explicit. The design serves this application; the values are still the author's proposals.

**VI.** Spec nhắm flight controller của drone vừa là USB device (CDC-ACM, DFU, mass storage) vừa là host cho camera UVC hoặc modem LTE, và mỗi trong 23 feature có dòng ứng dụng với số đo (mục 1.4). Danh sách loại trừ rõ ràng. Thiết kế phục vụ ứng dụng này; các giá trị vẫn là đề xuất của tác giả.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-034 | Observation | section 1.4, section 1.2, ASM-006 | FACT: section 1.4 gives a measurable need per feature, and ASM-006 records that the drone values (MAVLink 921 600 baud, 6 endpoints, MJPEG 720p30) are proposals that the user has not confirmed. | FACT: mục 1.4 đưa nhu cầu đo được cho mỗi feature, và ASM-006 ghi các giá trị drone (MAVLink 921 600 baud, 6 endpoint, MJPEG 720p30) là đề xuất người dùng chưa xác nhận. | Confirm the values with the product owner and mark them 'confirmed' with a date. |

**Score / Điểm:** application_fit = 4

## 4. Features / Tính năng

**EN.** Twenty-three features (FEAT-001 to FEAT-023) map to requirements, tests and configurations. Optional features have a parameter and a stated absent or tied-off behavior.

**VI.** Hai mươi ba feature (FEAT-001 đến FEAT-023) ánh xạ tới yêu cầu, test và cấu hình. Feature tùy chọn có tham số và hành vi absent hoặc tied-off được nêu.

No finding in this chapter. Score: 4. / Không có phát hiện trong chương này.

**Score / Điểm:** features = 4

## 5. Functions and cycle behaviour / Chức năng và hành vi theo chu kỳ

**EN.** Eight FSM tables and diagrams and 37 waveforms describe the device, host, link, ULPI and DMA behavior. The chirp, reset and suspend timings match REF-001. The gaps are the ULPI low power sequence, split timing, the scheduling limits and the numeric time-out and test-mode entry.

**VI.** Tám bảng FSM kèm sơ đồ và 37 waveform mô tả hành vi device, host, link, ULPI và DMA. Timing chirp, reset và suspend khớp REF-001. Khoảng trống là chuỗi ULPI low power, timing split, giới hạn lập lịch, time-out bằng số và cách vào test mode.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-004 | Major | TBD-005, section 7.4, section 10.1.7 (ulpi_if FSM), section 6.3 (ULPI register access) | FACT: TBD-005 leaves the ULPI low power mode open, section 7.4 says the PHY clock stops in suspend, and the ulpi_if FSM has no low-power, wake or reset state. INFERENCE: without them the link cannot enter suspend or L1 in a ULPI build, nor detect resume while CLK-PHY is stopped. | FACT: TBD-005 để mở ULPI low power mode, mục 7.4 nói clock PHY dừng khi suspend, và FSM ulpi_if không có state low-power, wake hay reset. INFERENCE: thiếu chúng thì build ULPI không vào được suspend hay L1 và không phát hiện được resume khi CLK-PHY dừng. | Read the low power sections of REF-007 (Figures 46 to 49, Table 15), add the states ENUM_ST_UL_LP and ENUM_ST_UL_WAKE and requirements for the stp and dir sequences and the clock restart wait. |
| F-008 | Major | REQ-FUNC-017, section 10.1.6 (host_xact), section 10.3 WF-013, REF-001 sections 11.17 to 11.21 | FACT: REQ-FUNC-017 gives the SPLIT PID and the NYET and ERR handshakes only. It has no rule for the earliest and latest complete-split microframe, no retry count, no handling of isochronous MDATA, and the host_xact FSM has one ENUM_ST_HX_SPLIT state; WF-013 is not to scale. | FACT: REQ-FUNC-017 chỉ cho PID SPLIT và handshake NYET, ERR. Không có quy tắc microframe sớm nhất và muộn nhất của complete-split, số lần retry, xử lý MDATA isochronous, và FSM host_xact chỉ có một state ENUM_ST_HX_SPLIT; WF-013 không theo tỷ lệ. | Derive requirements from REF-001 sections 11.17 to 11.21 for the start-split and complete-split scheduling, the TT buffering responses and the retry limit, and split ENUM_ST_HX_SPLIT into start and complete states. |
| F-015 | Minor | REQ-FUNC-034, section 7.2 CDC-001, section 10.3 WF-035 | FACT: REQ-FUNC-034 says o_vbus_pwr_en and o_utmi_drvvbus drop within 2 CLK-BUS cycles, but o_utmi_drvvbus is a CLK-PHY output reached through CDC-001 (WF-035 shows it later) and CLK-PHY can be stopped in suspend. ULPI has no DrvVbus pin. | FACT: REQ-FUNC-034 nói o_vbus_pwr_en và o_utmi_drvvbus hạ trong 2 chu kỳ CLK-BUS, nhưng o_utmi_drvvbus là ngõ ra CLK-PHY đi qua CDC-001 (WF-035 cho thấy nó trễ hơn) và CLK-PHY có thể dừng khi suspend. ULPI không có chân DrvVbus. | Split the requirement: o_vbus_pwr_en within 2 CLK-BUS cycles, o_utmi_drvvbus within a stated number of CLK-PHY cycles or at the next clock restart, and a ULPI OTG control register write for ULPI builds. |
| F-022 | Minor | REQ-FUNC-015, ASM-014, REF-001 section 5.7.4 | FACT: REQ-FUNC-015 has ASM-014 (open) as its source; REF-001 section 5.7.4 limits periodic transfers to 80 % of a high-speed microframe and 90 % of a full-speed or low-speed frame. The requirement does not state the limits or an admission check. | FACT: REQ-FUNC-015 lấy ASM-014 (đang mở) làm nguồn; REF-001 mục 5.7.4 giới hạn transfer periodic ở 80 % microframe high-speed và 90 % frame full-speed hoặc low-speed. Yêu cầu không nêu giới hạn hay kiểm admission. | Add the limits as requirements, with a software-visible refusal or flag when a channel set exceeds them, and close ASM-014. |
| F-023 | Minor | REQ-FUNC-025, REF-001 section 8.7.2 | FACT: REQ-FUNC-025 refers to the bus turn-around time and gives no value in bit times, while REF-001 section 8.7.2 defines the timer start and stop events. | FACT: REQ-FUNC-025 nhắc thời gian bus turn-around và không đưa giá trị theo bit time, trong khi REF-001 mục 8.7.2 định nghĩa sự kiện bắt đầu và dừng của timer. | Add the worst-case turn-around values per speed from REF-001 sections 7.1.18 and 7.1.19. |
| F-024 | Minor | REQ-FUNC-022 (section 3), ASM-017 (section 20), USB package file 'ECN for Core Spec TEST_MODE selector values.pdf' | FACT: REQ-FUNC-022 lists the four test modes and the pattern; ASM-017 leaves the entry through SetFeature(TEST_MODE) open. FACT: the user's USB package contains an ECN on the TEST_MODE selector values that the specification does not cite. | FACT: REQ-FUNC-022 liệt kê bốn test mode và pattern; ASM-017 để mở việc vào test mode bằng SetFeature(TEST_MODE). FACT: gói USB của bạn có một ECN về giá trị selector TEST_MODE mà spec không trích dẫn. | Convert the ECN, add the selector values and the exit action to REQ-FUNC-022, and close ASM-017. |

**Score / Điểm:** functions = 2

## 6. Interfaces and protocol / Giao diện và giao thức

**EN.** The port table of section 6.2 gives direction, width, clock domain, signal type, reset value and sampling for every port of the four wrappers. The compliance table below checks the statements against the clauses that were read.

**VI.** Bảng port mục 6.2 cho hướng, độ rộng, miền clock, loại tín hiệu, giá trị reset và lấy mẫu của mọi port trong bốn wrapper. Bảng tuân thủ bên dưới đối chiếu các phát biểu với các điều khoản đã đọc.

Compliance table (R-005) / Bảng tuân thủ:

| Requirement | Standard, revision, clause | Specification statement | Verdict |
|---|---|---|---|
| REQ-FUNC-002, REQ-FUNC-003 | USB 2.0 Rev 2.0 (REF-001), 8.3.1, 8.3.5.1, 8.3.5.2, Table 8-1 | PID check by complement; CRC5 residual 01100B; CRC16 residual 1000000000001101B | compliant |
| REQ-FUNC-004 | USB 2.0 Rev 2.0, 8.6.1 | SETUP data stage DATA0 with ACK, sequence bits equal afterwards | compliant |
| REQ-FUNC-006, REQ-FUNC-014 | USB 2.0 Rev 2.0, 7.1.18.1, 7.1.18.2 | 8 bit times minimum, 192 maximum (HS); 2 and 6.5 or 7.5 (FS, LS) | compliant |
| REQ-FUNC-010 | USB 2.0 Rev 2.0, 8.3.3, 8.4.3 | SOF 1 ms +/- 0.0005 ms (FS), 125 us +/- 0.0625 us (HS), 11-bit frame number | compliant |
| REQ-FUNC-011, 012, 013, 024 | USB 2.0 Rev 2.0, 7.1.7.5 | Reset 50 ms, chirp 1.0 to 7.0 ms, hub chirp 40 to 60 us | compliant |
| REQ-FUNC-018, 019, 020 | USB 2.0 Rev 2.0, 7.1.7.6, 7.1.7.7 | 3 ms idle, 5 ms before remote wake, 20 ms resume | compliant |
| REQ-FUNC-021 | USB 2.0 LPM ECN, 2.1, 2.2, 4.1 | EXT 0000B, SubPID 0011B, HIRD 50 us plus 75 us per step; L1 residency and exit timings not stated | not stated (partial) |
| REQ-FUNC-022 | USB 2.0 Rev 2.0, 7.1.20 | Four test modes and the test packet; entry command not stated (ASM-017) | deviation: entry not stated |
| REQ-FUNC-017 | USB 2.0 Rev 2.0, 8.4.2, 11.17 to 11.21 | SPLIT PID 1000B; scheduling and retry rules not stated | not stated (partial) |
| REQ-FUNC-015 | USB 2.0 Rev 2.0, 5.7.4 | Periodic limits of 80 % and 90 % not stated | not stated |
| REQ-FUNC-025 | USB 2.0 Rev 2.0, 8.7.2 | Time-out by turn-around time, no numbers | not stated |
| REQ-FUNC-034 | USB 2.0 Rev 2.0, 7.2.1.2.1 | Host over-current protection with a report to software | compliant |
| REQ-IF-001, REQ-IF-002 | UTMI+ Rev 1.0, 2, 2.1.1 (unofficial copy) | Levels 0 to 3, 8 and 16 bit, LineState filtering; encodings not stated | not stated (partial) |
| REQ-IF-003, REQ-IF-004 | ULPI Rev 1.1 (unofficial copy), Tables 6 to 10 listed, text not read in depth | TX CMD, RX CMD, register access, pipeline delays | not stated (not verified) |
| REQ-IF-005 | AMBA APB IHI 0024 Issue D, 3.1 to 3.4 | APB4 with PSTRB, PPROT, PSLVERR through the generator | compliant |
| REQ-IF-006, REQ-IF-007 | AMBA AXI IHI 0022 v1.0 text (AXI3 era); AXI4 Issue H.c not available | INCR bursts of at most 16 beats, 4 KB rule | unsupported (no AXI4 text) |

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-005 | Major | section 6.2 (o_utmi_opmode, o_utmi_xcvrsel, o_utmi_termsel), REQ-IF-001, REF-006 section 2.1.1 | FACT: section 6.2 names OpMode, XcvrSelect and TermSelect but gives no table of the values for high-speed, full-speed, low-speed, preamble, chirp and suspend, and REF-006 section 2.1.1.4 requires TXReady during chirp data. The chirp, level 3 preamble and suspend sequences depend on these values. | FACT: mục 6.2 nêu OpMode, XcvrSelect và TermSelect nhưng không có bảng giá trị cho high-speed, full-speed, low-speed, preamble, chirp và suspend, trong khi REF-006 mục 2.1.1.4 yêu cầu TXReady cả khi gửi chirp. Các chuỗi chirp, preamble level 3 và suspend phụ thuộc các giá trị này. | Add a table from REF-006 and REF-007 that maps each state of the speed FSMs to XcvrSelect, TermSelect, OpMode, DpPulldown and DmPulldown. |
| F-006 | Major | ASM-007, REQ-IF-006, REQ-IF-007, REF-010, section 2.3 | FACT: the only AXI text in md_doc is AXI v1.0 (AXI3 era); ASM-007 limits the profile to INCR bursts of at most 16 beats with no lock, QoS, region or user. INFERENCE: AXI4 behavior (for example awlen of 8 bits and the 4 KB rule wording) cannot be checked against a source. | FACT: văn bản AXI duy nhất trong md_doc là AXI v1.0 (thời AXI3); ASM-007 giới hạn profile ở burst INCR tối đa 16 beat, không lock, QoS, region, user. INFERENCE: hành vi AXI4 (ví dụ awlen 8 bit và cách viết luật 4 KB) không kiểm được với nguồn. | Add the AXI4 standard (IHI 0022 Issue H.c) to md_doc and recheck REQ-IF-006 and REQ-IF-007, or state the profile as AXI3-compatible only. |
| F-016 | Minor | REQ-FUNC-023, section 11.2 S05, section 6.2 ULPI ports | INFERENCE: the ULPI port list has no ID pin and the UTMI+ port list has i_utmi_iddig, so in a ULPI build the ID indication must come from the PHY status byte and the ID pull-up from a PHY register write; REQ-FUNC-023 and S05 do not say which register or bit. | INFERENCE: danh sách port ULPI không có chân ID trong khi UTMI+ có i_utmi_iddig, nên ở build ULPI chỉ báo ID phải đến từ byte status của PHY và pull-up ID từ ghi thanh ghi PHY; REQ-FUNC-023 và S05 không nói thanh ghi hay bit nào. | State the ULPI register and RX CMD field for ID, and add the PHY register writes to the initialization flow. |

**Score / Điểm:** interfaces = 2

## 7. Clock, reset and CDC / Clock, reset và CDC

**EN.** Two asynchronous domains (CLK-PHY, CLK-BUS), two resets and six crossings are listed with structures. The structures fit one-bit levels, pulses and the FIFO bus port, but not the multi-bit endpoint and channel registers that make most of the CSR.

**VI.** Hai miền bất đồng bộ (CLK-PHY, CLK-BUS), hai reset và sáu crossing được liệt kê kèm cấu trúc. Các cấu trúc phù hợp với level một bit, pulse và cổng FIFO bus, nhưng không phù hợp với thanh ghi endpoint và channel nhiều bit chiếm phần lớn CSR.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-001 | Blocker | section 7.2 CDC-001, CDC-003, section 11.3 (u2_epi_*, u2_epo_*, u2_hc_* banks), section 11.2 S13 and S15 | FACT: CDC-001 says the bundled values change only while the core is disabled, but S13, S15 and S17 of section 11.2 write ep_en, ch_en, set_nak, set_d0, stall and port_rst while core_en = 1, and section 11.3 routes the whole u2_epi_*, u2_epo_* and u2_hc_* banks (about 3 800 control flip-flops at the default counts, proxy from regs_usb2.json) through CDC-001 and CDC-003, which are a level synchronizer and a pulse synchronizer. No structure carries a 32-bit field such as u2_epi_dma.addr safely from CLK-BUS to CLK-PHY. | FACT: CDC-001 nói các giá trị chỉ đổi khi core bị tắt, nhưng S13, S15 và S17 ở mục 11.2 ghi ep_en, ch_en, set_nak, set_d0, stall và port_rst khi core_en = 1, và mục 11.3 đưa toàn bộ bank u2_epi_*, u2_epo_*, u2_hc_* (khoảng 3 800 flip-flop điều khiển ở số lượng mặc định, proxy từ regs_usb2.json) qua CDC-001 và CDC-003, tức bộ đồng bộ level và pulse. Không có cấu trúc nào truyền an toàn trường 32 bit như u2_epi_dma.addr từ CLK-BUS sang CLK-PHY. | Define a request and acknowledge handshake per bank entry (data held stable while the toggle crosses), or keep the endpoint and channel registers in CLK-PHY and write them from CLK-BUS through an asynchronous FIFO; update CDC-001 and CDC-003 and the CDC verification. |
| F-002 | Major | section 7.2 CDC-002, section 11.3 (xsize, pkt_cnt, addr are rwi), section 10.2 OP-007 | FACT: xsize, pkt_cnt and the DMA address are counted down or advanced by hardware (section 11.3, rwi), and CDC-002 transfers status as synchronized levels. INFERENCE: a software read of a 19-bit counter that changes at packet rate can return a mixed value, and the rule that a software write wins over a hardware load can drop one decrement. | FACT: xsize, pkt_cnt và địa chỉ DMA do hardware đếm xuống hoặc tăng (mục 11.3, rwi) và CDC-002 truyền status dạng level đồng bộ. INFERENCE: phần mềm đọc counter 19 bit đổi theo tốc độ gói có thể nhận giá trị lẫn bit, và quy tắc phần mềm ghi thắng hardware load có thể làm mất một lần giảm. | Snapshot the counters in CLK-PHY and cross them with the same handshake as F-001, and state how a lost load is repeated. |
| F-019 | Minor | section 7.3, section 11.2 S18, CDC-005, u2_sts.phy_clk_ok | FACT: section 7.3 gives reset sequencing for running clocks, but the PHY may stop CLK-PHY in ULPI low power mode (section 7.1) and the soft-reset pulse crosses through CDC-005 into CLK-PHY. INFERENCE: with the clock stopped a soft reset never completes, and S18 does not check phy_clk_ok. | FACT: mục 7.3 mô tả trình tự reset khi clock chạy, nhưng PHY có thể dừng CLK-PHY ở ULPI low power mode (mục 7.1) và xung soft-reset đi qua CDC-005 vào CLK-PHY. INFERENCE: khi clock dừng, soft reset không bao giờ xong, và S18 không kiểm phy_clk_ok. | State the stopped-clock behavior of i_rst_n_phy and the soft reset, require phy_clk_ok = 1 in S18, and add a timeout flag. |

**Score / Điểm:** clock_reset_cdc = 1

## 8. Parameters and data / Tham số và biểu diễn dữ liệu

**EN.** Fifteen parameters have defaults, ranges, dependencies and effects, and the quantity table and the descriptor format define widths and encodings. The gaps are the checking of illegal values and the FIFO size rule.

**VI.** Mười lăm tham số có mặc định, dải, phụ thuộc và tác động, và bảng đại lượng cùng định dạng descriptor xác định độ rộng và encoding. Khoảng trống là việc kiểm tra giá trị sai và quy tắc kích thước FIFO.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-020 | Minor | REQ-PARAM-001, ASM-011, section 11.1 (repeated register groups) | FACT: REQ-PARAM-001 and ASM-011 leave illegal values undefined, and section 11.1 requires the integrator to tie each generated PARA_U2_xx_COUNT (19 banks) to PARA_USB2_NUM_EP, NUM_HC or NUM_DMA_CH. INFERENCE: a mismatch between a bank count and the engines produces silent address or endpoint errors. | FACT: REQ-PARAM-001 và ASM-011 để giá trị sai không xác định, và mục 11.1 yêu cầu integrator gán từng PARA_U2_xx_COUNT (19 bank) bằng PARA_USB2_NUM_EP, NUM_HC hoặc NUM_DMA_CH. INFERENCE: lệch giữa số bank và engine gây lỗi địa chỉ hoặc endpoint im lặng. | Derive all bank counts inside the core from three parameters and add a synthesizable-neutral elaboration check module reported by lint. |
| F-021 | Minor | section 4 (illegal combinations), section 8 PARA_USB2_FIFO_DEPTH, ASM-005, CFG-MIN | INFERENCE: the rule requires only one maximum packet (256 words), while high-bandwidth isochronous is always present (ASM-005) with up to three 1 024-byte transactions per microframe (768 words) and dbuf doubles each region; CFG-MIN uses 256 words. | INFERENCE: quy tắc chỉ yêu cầu một gói tối đa (256 word), trong khi isochronous băng thông cao luôn có (ASM-005) với tối đa ba giao dịch 1 024 byte mỗi microframe (768 word) và dbuf nhân đôi mỗi vùng; CFG-MIN dùng 256 word. | Define the minimum region size as a function of endpoint type, mult and dbuf, and make the check part of REQ-PARAM-001. |

**Score / Điểm:** parameters = 4, data_representation = 4

## 9. ASIC feasibility / Khả thi ASIC

**EN.** Synthesizability: the structure follows the VLSIT rules, with one module per function and library cells for the RAM and synchronizers. Clock and reset architecture: two domains with synchronized release. CDC and RDC: see chapter 7. Timing path: not assessed in numbers because no synthesis input exists; the likely critical paths are listed in F-029.

**VI.** Synthesizability: cấu trúc theo rule VLSIT, mỗi module một chức năng và dùng library cell cho RAM và synchronizer. Kiến trúc clock và reset: hai miền với release đồng bộ. CDC và RDC: xem chương 7. Đường timing: chưa đánh giá bằng số vì chưa có đầu vào synthesis; các đường tới hạn có khả năng nằm ở F-029.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-029 | Minor | section 14.3, section 13, section 10.4 | FACT: section 14.3 leaves the frontend, libraries and corners to the RTL stage, and section 13 gives the CLK-PHY target of 60 MHz without naming a path. INFERENCE: the CRC16 update per byte, the RAM arbitration with the 20-cycle budget and the token decode are the likely critical paths and no pipeline split is stated. | FACT: mục 14.3 để frontend, library và corner cho giai đoạn RTL, và mục 13 đưa mục tiêu CLK-PHY 60 MHz mà không nêu đường nào. INFERENCE: cập nhật CRC16 mỗi byte, arbitration RAM trong ngân sách 20 chu kỳ và token decode là các đường tới hạn có khả năng và không có phân tầng pipeline nào được nêu. | List the expected critical paths with a pipeline stage count each, and require a synthesis run of one reference configuration before RTL sign-off. |

**Score / Điểm:** asic_feasibility = 3

## 10. SDC and timing / SDC và timing

**EN.** Clocks, the asynchronous clock groups and five exceptions are tabulated with their rationale. The interface input and output delays are open and the SDC files are not delivered.

**VI.** Clock, nhóm clock bất đồng bộ và năm exception được lập bảng kèm lý do. Input và output delay của giao diện còn mở và file SDC chưa được giao.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-010 | Major | section 17.1.2, TBD-007 | FACT: the rows of section 17.1.2 for the UTMI+ and ULPI pins say TBD-007 and name REF-007 Table 5 as the source to apply. Interface timing is the first path that fails at 60 MHz. | FACT: các hàng mục 17.1.2 cho chân UTMI+ và ULPI ghi TBD-007 và nêu Table 5 của REF-007 là nguồn cần áp dụng. Timing giao diện là đường đầu tiên hỏng ở 60 MHz. | Transcribe the input and output delay and clock jitter values of REF-007 Table 5 and the UTMI+ timing into the table, and derive the set_input_delay and set_output_delay values. |
| F-011 | Major | section 17.1.1 (sdc/usb2_clocks.sdc), section 17.1.2 (sdc/usb2_io.sdc), folder inventory | FACT: sections 17.1.1 and 17.1.2 name sdc/usb2_clocks.sdc and sdc/usb2_io.sdc as constraint sources, and the folder 023_USB20_Controller has no sdc or constraints directory (folder inventory, appendix). | FACT: mục 17.1.1 và 17.1.2 nêu sdc/usb2_clocks.sdc và sdc/usb2_io.sdc là nguồn constraint, và thư mục 023_USB20_Controller không có thư mục sdc hay constraints (kiểm kê thư mục, phụ lục). | Deliver the two SDC files with the specification, or change the text to say that they are produced with the RTL. |

**Score / Điểm:** sdc_timing = 2

## 11. Area and power / Diện tích và công suất

**EN.** Area and power have no stated number. The proxy table below is computed in this review from the CSR workbook JSON; it is a flip-flop and storage count, not a mapped area.

**VI.** Diện tích và công suất không có số. Bảng proxy bên dưới được tính trong review này từ JSON của workbook CSR; đó là số flip-flop và bộ nhớ, không phải diện tích đã map.

Proxy table (label: proxy, no mapped area; no library or corner) / Bảng proxy:

| Item | Default counts | Maximum counts | Basis |
|---|---|---|---|
| CSR control flip-flops (rw, rwi, w1c bits) | 3 802 | 6 868 | regs_usb2.json; banks 9 endpoint, 8 channel, 4 DMA (default) and 16 each (maximum) |
| CSR status inputs (ro bits, not flip-flops) | 291 | 355 | same source |
| FIFO RAM | 4 KB (1 024 x 32) | 128 KB (32 768 x 32) | PARA_USB2_FIFO_DEPTH default and maximum |
| Crossing FIFO MEM-002 | 2 x 8 x 36 = 576 bits | same | section 10.5 |

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-012 | Major | PPA-002, PPA-003, PPA-004, section 13 | FACT: PPA-003 and PPA-004 are goals with no number, and area is deferred to synthesis. proxy: the CSR holds 3 802 control flip-flops at the default counts (9 endpoint, 8 channel, 4 DMA entries) and 6 868 at the maximum counts (regs_usb2.json, rw, rwi and w1c bits) plus a 4 KB RAM; the host channel registers duplicate the device endpoint registers, whereas REF-011 table 3-4 reuses the device registers as host registers to save area. | FACT: PPA-003 và PPA-004 chỉ là mục tiêu không có số, diện tích để dành cho synthesis. proxy: CSR có 3 802 flip-flop điều khiển ở số lượng mặc định (9 endpoint, 8 channel, 4 DMA) và 6 868 ở số lượng tối đa (regs_usb2.json, các bit rw, rwi, w1c) cộng RAM 4 KB; thanh ghi host channel lặp lại thanh ghi endpoint thiết bị, trong khi REF-011 bảng 3-4 dùng lại thanh ghi thiết bị làm thanh ghi host để tiết kiệm diện tích. | Record the proxy table (flip-flops, RAM bits, wide muxes) per configuration with its assumptions, state a power activity assumption, and evaluate sharing the device and host register banks. |

**Score / Điểm:** area_power = 3

## 12. Performance and throughput / Hiệu năng và thông lượng

**EN.** The specification quantifies the isochronous goal (24.576 MB/s), the response limit (192 bit times, 20-cycle budget), the SOF period and the over-current response. The RAM bandwidth in the 16-bit configuration and the derivation of the turnaround budget are not shown.

**VI.** Spec định lượng mục tiêu isochronous (24,576 MB/s), giới hạn phản hồi (192 bit time, ngân sách 20 chu kỳ), chu kỳ SOF và thời gian đáp ứng over-current. Băng thông RAM ở cấu hình 16 bit và cách suy ra ngân sách turnaround chưa được trình bày.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-003 | Major | section 10.4 (bandwidth check), section 7.1 (CLK-PHY 30 MHz), section 10.5 MEM-001 | INFERENCE: section 10.4 shows 50 % use of 240 MB/s (32 bits at 60 MHz). With PARA_USB2_UTMI_W = 16 the RAM is in CLK-PHY at 30 MHz (section 7.1), so one port gives 120 MB/s while the packet engine needs 60 MB/s and the bus side up to 60 MB/s, which is 100 % use with no margin for arbitration or double buffering. | INFERENCE: mục 10.4 cho thấy dùng 50 % của 240 MB/s (32 bit ở 60 MHz). Với PARA_USB2_UTMI_W = 16 RAM nằm ở CLK-PHY 30 MHz (mục 7.1), một cổng chỉ cho 120 MB/s trong khi packet engine cần 60 MB/s và phía bus tới 60 MB/s, tức 100 % và không còn dư cho arbitration hay double buffering. | Add a bandwidth table per configuration, and either widen the RAM word to 64 bits when UTMI+ is 16 bits, run the RAM on a faster clock, or limit the 16-bit configuration to full-speed traffic. |
| F-009 | Major | PERF-002, section 6.3 (ULPI), REF-007 Tables 8 to 10, REQ-FUNC-006, REQ-FUNC-014 | FACT: PERF-002 gives an internal budget of 20 CLK-PHY cycles for a handshake start within 192 bit times (24 cycles) including the ULPI pipeline. INFERENCE: REF-007 Tables 8 to 10 (PHY pipeline delays, link decision times) are not applied, and the path token decode to first RAM byte to TXValid has no cycle count, so the figure is a claim. | FACT: PERF-002 cho ngân sách nội bộ 20 chu kỳ CLK-PHY để bắt đầu handshake trong 192 bit time (24 chu kỳ) gồm cả pipeline ULPI. INFERENCE: Table 8 đến 10 của REF-007 (trễ pipeline PHY, thời gian quyết định của link) chưa được áp dụng, và đường token decode đến byte RAM đầu tiên đến TXValid không có số chu kỳ, nên con số chỉ là khẳng định. | Add a cycle budget table per response path for UTMI+ 8-bit, UTMI+ 16-bit and ULPI, using the pipeline delays of REF-006 and REF-007. |

**Score / Điểm:** performance = 2

## 13. Software and application ease / Dễ lập trình và ứng dụng

**EN.** The register model (44 registers, banks, interrupt set with raw, enable, injection and status, summary registers) and the 19-step flow of section 11.2 are workable; initialization, error clearing and interrupt service are described. The model is new, so no existing driver applies.

**VI.** Mô hình thanh ghi (44 thanh ghi, bank, bộ ngắt raw, enable, injection, status, thanh ghi tóm tắt) và flow 19 bước ở mục 11.2 dùng được; khởi tạo, xóa lỗi và phục vụ ngắt đã mô tả. Mô hình là mới nên chưa có driver sẵn.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-013 | Major | section 11.1, REF-011, section 11.2 | FACT: the CSR is a new 44-register map (REF-005); REF-011 is only a design reference. INFERENCE: Linux gadget and host stacks, TinyUSB and vendor HALs expect a known controller register model, so the firmware team must write and verify a driver, which the specification does not budget or describe. | FACT: CSR là bản đồ 44 thanh ghi mới (REF-005); REF-011 chỉ là tham chiếu thiết kế. INFERENCE: stack Linux gadget và host, TinyUSB và HAL của hãng mong đợi mô hình thanh ghi controller đã biết, nên đội firmware phải viết và kiểm driver, điều spec không dự trù hay mô tả. | Add a software integration section: driver scope, a register-level state-machine reference for EP0, a statement of compatibility, and an option to provide a compatibility view of a known controller. |
| F-014 | Minor | section 11.3 closing paragraph | FACT: section 11.3 says the IP repeats a lost load, 'a count-down update is re-applied in the next cycle'. INFERENCE: the repeated value depends on whether software wrote xsize or the hardware had counted, and the text does not say which wins. | FACT: mục 11.3 nói IP lặp lại lần load bị mất, 'cập nhật giảm được áp dụng lại ở chu kỳ sau'. INFERENCE: giá trị lặp phụ thuộc phần mềm vừa ghi xsize hay hardware vừa đếm, và văn bản không nói bên nào thắng. | Define per rwi field who wins and how the hardware reapplies, and add an assertion. |

**Score / Điểm:** software_ease = 3

## 14. DFT / DFT

**EN.** Scan eligibility, the clock-gate test enable, MBIST position and ATPG exclusions are stated; the DFT ports are deferred to the SoC flow (TBD-009).

**VI.** Scan, test enable của clock gate, vị trí MBIST và loại trừ ATPG đã nêu; port DFT hoãn cho flow SoC (TBD-009).

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-031 | Observation | section 16, TBD-009 | FACT: section 16 defers the scan ports to TBD-009 and the RAM bypass and MBIST to the SoC memory flow, with CLK-PHY stopped by the PHY replaced by the scan clock. | FACT: mục 16 để các port scan cho TBD-009 và bypass RAM, MBIST cho memory flow của SoC, với CLK-PHY do PHY dừng được thay bằng scan clock. | Name the scan clock mux ownership and the RAM bypass wrapper requirement before RTL. |

**Score / Điểm:** dft = 4

## 15. Security and RAS / An toàn và độ tin cậy

**EN.** Stance: untrusted USB data, CSR privilege check, no key material, no ECC, no integrity level. Error containment is by flags, time-outs, flush and DMA stop.

**VI.** Lập trường: dữ liệu USB không tin cậy, kiểm quyền CSR, không có khóa, không ECC, không integrity level. Cô lập lỗi bằng cờ, time-out, flush và dừng DMA.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-017 | Minor | section 18 (ECC/parity row), TBD-010 | INFERENCE: section 18 says a RAM soft error is detected by the CRC of the next packet on the wire side. The CRC16 is generated over the bytes read from the RAM at transmit time, so a flipped bit produces a valid CRC and is not detected; a receive-side flip happens after the CRC check. | INFERENCE: mục 18 nói lỗi mềm RAM được phát hiện bởi CRC của gói kế tiếp phía wire. CRC16 được sinh trên byte đọc từ RAM lúc truyền, nên bit bị lật vẫn cho CRC hợp lệ và không bị phát hiện; lật ở phía nhận xảy ra sau khi kiểm CRC. | Correct the statement and decide TBD-010: add one parity bit per RAM word with an error flag and a fail-safe response for the drone product, or document the residual risk. |
| F-018 | Minor | section 11.4, u2_dma_cfg.axi_prot, u2_dma_hi, section 18 | FACT: the DMA address registers and u2_dma_hi are plain read-write fields and the only access protection of the CSR is PPROT[1] with i_protect_en (section 11.4). INFERENCE: any APB master that can write the CSR can point the DMA at any address of the AXI fabric. | FACT: thanh ghi địa chỉ DMA và u2_dma_hi là trường đọc-ghi thường và bảo vệ truy cập duy nhất của CSR là PPROT[1] với i_protect_en (mục 11.4). INFERENCE: master APB nào ghi được CSR đều trỏ được DMA tới địa chỉ bất kỳ của AXI fabric. | Add an optional address window check (base and limit registers) that raises dma_err on a violation, or state that the SoC firewall owns it. |

**Score / Điểm:** security_ras = 4

## 16. Verification quality / Chất lượng kiểm chứng

**EN.** Fifty-nine requirements are traced to 29 tests and 15 properties and covered by 4 coverage groups; no requirement lacks a test. Depth is limited: tests are grouped, there is no interoperability or time-scaling plan, and nothing has been simulated.

**VI.** Năm mươi chín yêu cầu được truy vết tới 29 test và 15 property và 4 nhóm coverage; không yêu cầu nào thiếu test. Độ sâu còn hạn chế: test được gộp, không có kế hoạch interoperability hay scale thời gian, và chưa có gì được mô phỏng.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-026 | Minor | section 15.1, section 2.3, TEST-001 to TEST-029 | FACT: section 15.1 lists an FPGA prototype after the RTL and section 2.3 states that certification is not claimed; TEST-001 to TEST-029 use a bus model. INFERENCE: no test runs a real host or device stack (for example Linux gadget or TinyUSB) or the USB-IF device test sequence. | FACT: mục 15.1 liệt kê FPGA prototype sau RTL và mục 2.3 nói không claim certification; TEST-001 đến TEST-029 dùng bus model. INFERENCE: không test nào chạy stack host hoặc device thật (ví dụ Linux gadget hoặc TinyUSB) hay chuỗi test thiết bị USB-IF. | Add interoperability tests (CDC-ACM, UVC, mass storage with a real stack) and a compliance pre-check plan, with entry and exit criteria. |
| F-028 | Minor | section 15.2 (TEST-007, TEST-009), REQ-FUNC-011, REQ-FUNC-018 | INFERENCE: REQ-FUNC-011 (50 ms reset, 3 160 000 CLK-PHY cycles at 60 MHz), REQ-FUNC-018 (3 ms idle) and REQ-FUNC-019 (5 ms) are exercised by TEST-007 and TEST-009, and the specification has no timer scaling or test-time register to keep regression time short. | INFERENCE: REQ-FUNC-011 (reset 50 ms, khoảng 3 triệu chu kỳ CLK-PHY ở 60 MHz), REQ-FUNC-018 (idle 3 ms) và REQ-FUNC-019 (5 ms) được thực hiện bởi TEST-007 và TEST-009, và spec không có hệ số scale timer hay thanh ghi test-time để giữ thời gian regression ngắn. | Add a verification-only timer scale (parameter or CSR field in test mode) and require that the scaled and unscaled timings are both tested at least once. |
| F-033 | Observation | section 19, inventory summary | FACT: the inventory reports 59 requirements, 29 tests, 15 properties and 0 requirements without a test; section 19 maps each requirement to a module, a test, a method and a configuration. | FACT: inventory báo 59 yêu cầu, 29 test, 15 property và 0 yêu cầu không có test; mục 19 ánh xạ mỗi yêu cầu tới module, test, phương pháp và cấu hình. | None. |

**Score / Điểm:** verification_quality = 4

## 17. Documentation and traceability / Tài liệu và truy vết

**EN.** Identifiers are stable and the 41 open items are listed in section 20. The standards texts are unofficial copies and the open items have no owner or date.

**VI.** Định danh ổn định và 41 mục mở được liệt kê ở mục 20. Văn bản chuẩn là bản sao không chính thức và mục mở không có owner hay ngày.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-007 | Major | ASM-001, REF-006, REF-007, REF-001 conversion CHECK | FACT: ASM-001 records that UTMI+ 1.0 (nxp.com mirror, 26 pages) and ULPI 1.1 (sparkfun.com mirror) are third-party copies, and the conversion check reported CHECK for every converted document with 114 pages of USB 2.0 differing by more than 5 %. The protocol statements of REQ-IF-001 to REQ-IF-004 and many REQ-FUNC lines cite them. | FACT: ASM-001 ghi UTMI+ 1.0 (bản sao nxp.com, 26 trang) và ULPI 1.1 (bản sao sparkfun.com) là bản bên thứ ba, và kiểm tra chuyển đổi báo CHECK cho mọi tài liệu với 114 trang USB 2.0 lệch hơn 5 %. Các phát biểu giao thức của REQ-IF-001 đến REQ-IF-004 và nhiều REQ-FUNC trích dẫn chúng. | Replace the copies by the official documents, inspect the pages that differ by more than 5 %, and record the result in section 2.1. |
| F-025 | Observation | section 2.1 (references), USB package ECN list | INFERENCE: the package lists ECNs on double isochronous IN, phase-locked SOFs, suspend current and DCR that may affect the high-bandwidth isochronous and suspend requirements; only the LPM ECN is referenced. | INFERENCE: gói liệt kê ECN về double isochronous IN, phase-locked SOF, suspend current và DCR có thể ảnh hưởng yêu cầu isochronous băng thông cao và suspend; chỉ ECN LPM được tham chiếu. | Read the ECNs and record each as applicable or not applicable. |
| F-027 | Minor | REQ-FUNC-015, REQ-FUNC-032, REQ-FUNC-034 to REQ-FUNC-036, section 20 | FACT: REQ-FUNC-015, 032, 034, 035 and 036 cite ASM-014, 021, 022, 023 and 020 as their source and those are open; section 20 has 41 open items in a table without owner or date columns. | FACT: REQ-FUNC-015, 032, 034, 035 và 036 trích ASM-014, 021, 022, 023 và 020 làm nguồn và chúng đang mở; mục 20 có 41 mục mở trong bảng không có cột owner hay ngày. | Add owner and date columns, resolve or label each requirement 'proposed' until its assumption closes. |

**Score / Điểm:** documentation = 3

## 18. Integration effort and bring-up / Công sức tích hợp và bring-up

**EN.** The integrator must choose a wrapper, supply a PHY, a RAM macro, a pad wrapper and optionally a DMA controller, tie off several ports and tie 19 bank counts. The bring-up flow is in section 11.2.

**VI.** Integrator phải chọn wrapper, cấp PHY, macro RAM, pad wrapper và tùy chọn DMA controller, tie-off nhiều port và gán 19 số bank. Flow bring-up nằm ở mục 11.2.

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-030 | Minor | section 6.2 (pad wrapper note), section 7.3, section 14.2 | FACT: the tie-offs (i_ovrcur_n, i_protect_en, i_slverr_en), the pad wrapper for the bidirectional ULPI bus, the four wrappers and the RAM macro wrapper are described in separate sections. INFERENCE: the integrator has to assemble the bring-up order (clock, reset, PHY reset, phy_clk_ok, soft reset) from sections 7 and 11.2. | FACT: tie-off (i_ovrcur_n, i_protect_en, i_slverr_en), pad wrapper cho bus ULPI hai chiều, bốn wrapper và wrapper macro RAM được mô tả ở các mục riêng. INFERENCE: integrator phải tự ghép thứ tự bring-up (clock, reset, PHY reset, phy_clk_ok, soft reset) từ mục 7 và 11.2. | Add one integration table: tie-offs, clock and reset sequence, macro and pad wrappers, and the checks at power-up. |

**Score / Điểm:** integration_effort = 4

## 19. Market position / Vị thế thị trường

**EN.** The specification is compared with the DWC_otg databook, vendor pages and three SoC manuals. It is competitive in features for a drone application; area, power and software support cannot be compared yet.

**VI.** Spec được so với databook DWC_otg, trang của hãng và ba manual SoC. Về tính năng, spec cạnh tranh được cho ứng dụng drone; diện tích, công suất và hỗ trợ phần mềm chưa so được.

| Product | Source and date | Facts | Comparison with this specification |
|---|---|---|---|
| Synopsys DWC_otg USB 2.0 HS OTG 5.00b | Databook DWC_otg_databook.pdf, July 2024, chapter 3 (user file); retrieved 2026-11-20 | Role modes with HNP, SRP and non-HNP, slave, internal and external DMA, descriptor DMA, dedicated TX FIFO per IN endpoint, LPM (+1.2K gates), HSIC, ADP, battery charger, point-to-point option, up to 15 endpoints and 16 host channels | Ours adds optional split, SG, double buffering; omits HNP, SRP, ADP, HSIC, BC and dedicated FIFOs |
| Synopsys DesignWare USB 2.0 HS OTG controller | synopsys.com/designware-ip/interface-ip/usb/usb-2-0-hs-otg.html, retrieved 2026-11-20 | Dual-role device, 480/12/1.5 Mbps, AHB, UTMI+ Level 3 PHY interface, buffer and descriptor pre-fetching, multiple power domains | Ours is AXI4 and APB4 and has no power-domain support (section 7.4 N/A) |
| Cadence USB 2.0 OTG controller | cadence.com brochure Design IP for USB 2.0 OTG Controller, retrieved 2026-11-20 | 8-bit UTMI+, host and device, AXI interfaces, scatter-gather DMA; LPM is listed for the PHY | Similar AXI and SG offer; ours adds ULPI and 16-bit UTMI+ |
| TI AM335x (Mentor MUSB) | TRM spruh73q, December 2019, section 16.0.4 (downloaded 2026-11-20) | HS/FS device, HS/FS/LS host, 16 TX and 16 RX endpoints, 32 KB FIFO, HNP and SRP, high-bandwidth isochronous, CPPI DMA, RNDIS and CDC modes; LPM and charger detection unsupported | Ours has LPM option and ZLP assistance; no RNDIS/CDC accelerator |
| Espressif ESP32-S3 (DWC2 core) | TRM v1.8, section 32.2, retrieved 2026-11-20 | FS and LS only, HNP and SRP, dynamic FIFO, scatter-gather, buffer DMA and slave modes, 6 extra endpoints, 8 host channels | Ours adds high-speed and more endpoints |
| Raspberry Pi RP2040 | Datasheet section 4.1.1.1, retrieved 2026-11-20 | FS device, host FS and LS, 32 endpoints, double buffering, 15 hardware-polled interrupt endpoints, 4 KB | Ours adopts double buffering and interval polling |

**Findings**

| ID | Severity | Locator | Statement (EN) | Phát hiện (VI) | Action |
|---|---|---|---|---|---|
| F-032 | Observation | section 1.3, REF-011 chapter 3, TI AM335x TRM section 16.0.4, ESP32-S3 TRM section 32.2, RP2040 datasheet section 4.1.1.1 | FACT: compared with the sources of chapter 19, the specification adds an optional LPM and split, scatter-gather and double buffering, and omits HNP, SRP, ADP, battery charging detection, HSIC, a dedicated FIFO per IN endpoint and per-endpoint interrupts. These omissions follow user answers of 2026-11-20 and are recorded in section 20. | FACT: so với các nguồn ở chương 19, spec thêm LPM và split tùy chọn, scatter-gather và double buffering, và bỏ HNP, SRP, ADP, phát hiện bộ sạc, HSIC, FIFO riêng cho từng endpoint IN và ngắt riêng từng endpoint. Các điểm bỏ này theo câu trả lời của người dùng ngày 2026-11-20 và có ghi ở mục 20. | None: keep the omissions recorded. |

**Score / Điểm:** market_position = 3

## 20. Actions / Hành động

**EN.** Fix in this order: P0 items block integration, P1 items block RTL freeze. **VI.** Sửa theo thứ tự: P0 chặn tích hợp, P1 chặn đóng băng RTL.

| Priority | Action | Owner | Evidence |
|---|---|---|---|
| P0 | Define a held-data CSR crossing and rework CDC-001 to CDC-003 | spec and RTL architect | F-001, F-002, F-014 |
| P0 | Replace unofficial UTMI+, ULPI copies, add AXI4 text, inspect pages that differ | spec owner | F-006, F-007, F-025 |
| P0 | Specify ULPI low power, clock restart, UTMI+ mode table, ID path, split rules | spec owner | F-004, F-005, F-008, F-016, F-019 |
| P1 | Add RAM bandwidth table, turnaround cycle budget, PHY I/O timing and the SDC files | spec owner, SoC | F-003, F-009, F-010, F-011, F-029 |
| P1 | Add area and power proxy table and evaluate shared register banks | spec owner | F-012 |
| P1 | Add driver plan and integration checklist | SW lead, integrator | F-013, F-030 |
| P2 | Close the minor requirement gaps and open-item owners and dates | spec owner | F-020 to F-024, F-027, F-028 |
| P2 | Decide RAM parity and DMA window | product owner | F-017, F-018 |

## 21. Evidence appendix / Phụ lục bằng chứng

**EN.** Inventory of the reviewed folder (rule R-001), gate result, audit sample and the limits of the review. **VI.** Kiểm kê thư mục được review (R-001), kết quả gate, mẫu kiểm tra và giới hạn của review.

- Folder inventory: VLSIT_USB20_CONTROLLER_HDS.md, the CSR workbook VLSIT_USB20_CONTROLLER_CSR.xlsx and csr/regs_usb2.json, figures/ (8 FSM, 1 block diagram, 37 waveform with sources, figures/src), research/reference_ip_log.md, review/. There is no rtl/, verification/, sanity/, sdc/ or constraints/ folder.

- File hashes (sha256, first 16 hex): spec 950c6c3796e82ebc, workbook 0d36ba678f6183af, regs_usb2.json 9eeb47a2b7d9452d.
- Requirements: 59 (FUNC 36, IF 10, CLK 2, RESET 2, PARAM 2, ERR 2, REG 1, PERF 1, RTL 1, VER 1, DFT 1); tests 29; properties 15; open items 41 (ASM, DEP, TBD without owner or date). Source: review/inventory.json.
- Gate: `RESULT: FAIL` (vlsit_review_gate.py metrics): 34 findings, Critical 1, High 12, Medium 16, Low 5; waiver usage 0/10 (budget 10); sampling 32 %; reason: 1 unwaived Critical finding(s): F-001. The gate stays FAIL until F-001 is fixed in the specification; no waiver was granted.

- Audit of the review: 4 of 34 findings sampled by vlsit_review_gate.py sample (F-009, F-003, F-010, F-019): tp 4, fp 0, fn 0 observed; false-positive rate 0 %; false-negative rate 0 % inside the sample (the sample cannot measure issues that were never reported, so the false-negative rate is a lower bound).


| Sampled finding | Severity | Judgement | Basis |
|---|---|---|---|
| sample F-009 | High | tp | PERF-002 (line 4847) states the 20-cycle budget; REF-007 Tables 8 to 10 are not applied in the specification. |
| sample F-003 | High | tp | Line 4668 uses 240 MB/s; section 7.1 gives CLK-PHY 30 MHz for 16-bit UTMI+, so the same traffic needs 100 % of 120 MB/s. |
| sample F-010 | High | tp | Line 5003 shows TBD-007 for the UTMI+ input delay; no number exists. |
| sample F-019 | Medium | tp | Section 7.3 has no stopped-clock rule, S18 (line 4774) does not check phy_clk_ok, and CDC-005 needs CLK-PHY. |

- Not assessed: mapped area and power (no synthesis input); timing closure (no RTL or SDC); ULPI clauses in depth (the converted text was listed, not read); the 650-page USB 2.0 conversion pages that differ by more than 5 %; the RTL, because none exists; the DWC_otg databook outside chapter 3 and the SoC manuals outside their feature lists; AXI4 behavior (no AXI4 text).
- Depth: findings were traced in depth for 11 of 34 findings; the rest are grouped by root cause (rule R-022); ask to go deeper.
- Sources: web search results for Synopsys and Cadence pages retrieved 2026-11-20; documents supplied by the user (DWC_otg databook, USB 2.0 package) and downloaded SoC manuals (soc_manuals folder).
