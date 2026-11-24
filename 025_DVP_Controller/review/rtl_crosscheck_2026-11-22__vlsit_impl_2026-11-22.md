> **Historical report:** Static cross-check performed on 2026-11-22 against HDS v0.2. The current specification and later verification evidence are indexed in [REVIEW_STATUS_2026-11-23.md](REVIEW_STATUS_2026-11-23.md).

# DVP Controller — Independent Review Rebuttal and RTL Cross-check

| Item | Value |
|---|---|
| IP | DVP Controller |
| Review target | `025_DVP_Controller/review/REVIEW_DVP_Controller.md` and `025_DVP_Controller/review/reference/spec_review_2026-11-22/vlsit_spec_2026-11-22.md` |
| RTL/spec revision | RTL generation dated 2026-11-22; HDS v0.2, status Draft |
| Review date | 2026-11-22 |
| Scope | Independent static rebuttal of the 31 findings against the HDS, CSR artifacts, RTL and recorded verification evidence |
| Result | **Qualified / not sign-off** — several real integration and protocol risks remain; the 31 findings are not 31 demonstrated RTL bugs |

## 1. Executive summary / Tóm tắt điều hành

**EN.** The reviewed report is explicitly a specification review and says it did not compare the RTL. Its 31 findings therefore mix specification gaps, integration dependencies, optional product features, and a small number of genuine RTL-interface risks. Cross-checking the current source confirms the DMA request FSM can remain deasserted after ACK while occupancy stays at or above the watermark; the HDS defines that re-arm rule but does not define how a fixed-length DMA batch must drain the FIFO. The gated-pixel reset and bundled-data crossings also lack the required RDC/STA evidence, and an empty FIFO_DATA read can hold the shared APB for the programmed 32-bit timeout. The implementation report confirms that no behavioral testbench or simulation exists, so neither the original review nor this rebuttal can claim functional sign-off. Many recommendations—frame counters, interrupt, packing, runtime sensor profile, flush, ECC and commercial camera features—are useful roadmap choices but are not bugs in the user-approved scope.

**VI.** Báo cáo được review tự ghi là review đặc tả và không đối chiếu RTL. Vì vậy, 31 finding đang trộn lẫn thiếu sót của tài liệu, đầu việc tích hợp, tính năng mở rộng và một số rủi ro thật của giao thức/RTL; không thể gọi cả 31 là bug RTL. Đối chiếu source xác nhận FSM DMA có thể không phát lại `REQ` sau `ACK` nếu occupancy vẫn bằng hoặc cao hơn watermark; HDS có quy tắc re-arm này nhưng chưa quy định DMA phải drain theo cách nào. CDC reset và bundled-data của gated mode chưa có bằng chứng RDC/STA; lần đọc `FIFO_DATA` khi rỗng có thể giữ APB đến hết timeout 32-bit. Verification README cũng xác nhận không có testbench hay simulation, nên chưa thể sign-off chức năng. Các đề xuất frame counter, IRQ, packing, profile runtime, flush, ECC và tính năng kiểu camera thương mại là lựa chọn roadmap, không phải lỗi theo phạm vi đã duyệt.

**Three most important closure items / Ba việc cần đóng trước tiên:**

1. Define an end-to-end DMA service contract for ACK, burst termination and tail samples; update or retain the current watermark re-arm behavior by an explicit product decision. / Chốt hợp đồng DMA cho ACK, kết thúc burst và phần mẫu dư; chỉ đổi FSM sau khi có quyết định sản phẩm.
2. Close gated-mode reset recovery/removal, bundled-data max delay, clock uncertainty and metastability assumptions with CDC/RDC plus STA evidence. / Đóng timing reset, bundled-data, clock uncertainty và giả thiết metastability bằng CDC/RDC và STA.
3. Add and execute the planned behavioral regression for the current RTL, especially TEST-005, TEST-011, TEST-013, TEST-014 and TEST-015. / Tạo và chạy regression theo spec, ưu tiên TEST-005, TEST-011, TEST-013, TEST-014 và TEST-015.

### 1.1 What the source proves / Bằng chứng trực tiếp từ source

- `m_dvp_dma_req.sv:45-72` implements the HDS policy literally: `REQ` stays high until ACK; after ACK, `REQ` stays low until occupancy falls below the watermark. This is a liveness hazard for a DMA that performs a short fixed burst.
- `m_dvp_capture.sv:151-175` clocks the gated payload/toggle on the selected PCLK edge but uses `i_rst_n_gated`; `m_dvp_controller.sv:85-109` connects that reset to the APB-local reset. The RTL follows HDS DEC-029, but RDC/recovery-removal closure is still open.
- `m_dvp_gate_bridge.sv:40-102` uses two-stage VSYNC and toggle synchronizers and a held-data bus, without a source acknowledgement or a gated-overrun status. The four-APB-cycle rule is an integration assumption; no hardware check enforces it.
- `m_dvp_apb_data.sv:41-90` contains a 32-bit timeout counter and intentionally holds `PREADY` low while an empty FIFO read is waiting. The risk depends on software's programmed timeout and the SoC's APB topology.
- `verification/README.md` and `RTL_GENERATION_REPORT.md` state that behavioral simulation, CDC/RDC, STA and synthesis were not run. Waveforms in the HDS are examples, not captured RTL simulations.

## 2. Review method and limits / Phương pháp và giới hạn

**EN.** I read the supplied review summary, all 31 finding descriptions, the reviewed HDS v0.2, the CSR JSON/workbook status, relevant RTL modules, and the checked-in verification README/log summaries. I inspected source and recorded evidence only; I did not edit RTL or execute a simulation/regression. The review folder contains no executable verification source set, no SDC, and no CDC/RDC or synthesis report. Under the implementation-review workflow this prevents a complete behavioral/sign-off review; the result below is a source-grounded rebuttal and static cross-check only.

**VI.** Tôi đã đọc báo cáo review, đủ 31 finding, HDS v0.2, CSR artifacts, các RTL liên quan và README/log verification hiện có. Tôi chỉ đọc source và bằng chứng đã lưu; không sửa RTL, không chạy simulation/regression. Thư mục verification không có source testbench chạy được, không có SDC, báo cáo CDC/RDC hoặc synthesis. Vì vậy đây là phản biện dựa trên source và static cross-check, chưa phải review sign-off đầy đủ.

## 3. Finding-by-finding adjudication / Phản biện từng finding

`Keep` means the finding identifies a real requirement/integration issue; it does not automatically mean RTL is wrong. `Conditional` means it depends on an unstated system behavior or an out-of-contract sensor. `Scope` means it proposes an unrequested feature. `Overstated` means the claim or severity goes beyond the evidence.

| ID | Original severity | Disposition | Independent assessment / Đánh giá phản biện |
|---|---:|---|---|
| F-001 | High | Conditional; lower severity | A named workload is absent by user choice; Section 13 leaves depth sizing to integration. This is a product-fit/sign-off input, not proof that one-sample-per-word is defective. A workload table is useful, but should not silently replace the user's decision to supply the workload later. |
| F-002 | High | Scope; overstated | Frame-done, counters, snapshot and flush are not in the approved capture-only interface. They can simplify firmware, but their absence does not contradict the current requirements. “Every camera driver needs this” is not evidence of an RTL fault. |
| F-003 | Medium | Keep as compatibility boundary | Correctly observes that the broad research corpus is wider than the supported profile. The HDS deliberately excludes independent HSYNC and embedded-code parsing. Because the product goal is broad sensor compatibility, a sensor/mode support matrix is valuable; unsupported modes are not RTL bugs. |
| F-004 | High | Keep; real protocol liveness risk | The RTL matches REQ-IF-004 exactly, but a fixed DMA burst may ACK and stop while occupancy remains above watermark, leaving `REQ=0`. The suggested counter-based fix changes the approved contract and assumes the controller can observe every accepted APB pop and that burst length is fixed. First define batch completion/drain semantics; then choose a compatible fix. |
| F-005 | High | Conditional; service-contract gap | After ACK, a residual occupancy below watermark will not raise a new request. That is a real gap if DMA stops after a fixed burst; it is not “never delivered” if the DMA continues reading until below threshold or polls FIFO level. Adding frame-done/tail service requires new scope and frame semantics. |
| F-006 | High | Scope; severity overstated | No IRQ is an explicit minimal interface choice; DMA REQ and APB status exist. IRQ is a reasonable optional feature. The inability to poll while the same APB is held by an empty read belongs to F-007 and should not be counted again as an independent missing-IRQ bug. |
| F-007 | High | Keep as integration hazard | The empty read intentionally waits for software's 32-bit timeout. At 100 MHz, `0xFFFF_FFFF` cycles is about 42.95 seconds, enough to block a shared APB requester. This is not an APB logic mismatch, but integration must cap the programmed value or provide a bus-level timeout/isolated APB path. Narrowing the CSR is a product decision, not an automatic fix. |
| F-008 | Medium | Keep as documentation/interface gap | ACK, REQ and FIFO_DATA are described, but a DMA's batch length, stop condition and behavior after ACK are not. This is closely related to F-004/F-005 and should be consolidated under one DMA-contract root cause. |
| F-009 | High | Keep as RDC/sign-off risk; proposed fix incomplete | The cross-domain reset is real: APB-synchronized deassertion drives asynchronous reset pins on PCLK-clocked gated launch flops. HDS DEC-029 explicitly chose this to preserve the first pixel, so it is not an RTL-vs-HDS mismatch; it is an unresolved RDC/recovery-removal obligation. Removing reset can avoid that path, but the proposed unreset toggle needs a defined initialization/baseline protocol and proof that no phantom or lost first event occurs; the snippet alone is not a safe drop-in fix. |
| F-010 | High | Conditional robustness gap | No gated-overrun status exists. A sensor violating the four-cycle spacing/VSYNC contract can cause lost or misqualified samples without a dedicated flag. The HDS makes those timing conditions mandatory, so the absence of error handling for an out-of-contract sensor is not by itself a functional mismatch. Add an acknowledgement/overrun path only if runtime detection is required; otherwise prove and document the sensor/STA contract. |
| F-011 | High | Scope; disagree with severity | Width, PCLK edge and qualifier polarity are compile-time parameters by explicit user decision. Runtime programmability means additional clock/profile selection and DFT/STA complexity; it is not inherently a more efficient or correct design. |
| F-012 | Medium | Minor diagnosability improvement | A watermark greater than depth deliberately keeps REQ low (DEC-011); this behavior is specified, not undefined. An error/status flag could help firmware, but changing CSR width or adding PSLVERR is an optional software-contract change. The timeout maximum is already covered in F-007. |
| F-013 | Medium | Scope/performance trade-off | Bus-lane utilization calculation is directionally correct for one sample per 32-bit read. One-sample words were explicitly selected for a simple DMA contract. Packing is a possible next revision, with byte-lane order and partial-word/frame-tail behavior to specify; it is not a current RTL bug. |
| F-014 | Medium | Keep as implementation/DFT documentation | Falling-edge sampling and a stoppable input clock need explicit STA/DFT handling. However, prescribing an XOR clock or inversion/mux is not proven safer than the existing elaboration-time rising/falling flop branches. The clock implementation must follow the target library, reset strategy and DFT methodology. |
| F-015 | High | Keep as integration sign-off dependency | No SDC is delivered and numeric clocks/I/O budgets are intentionally SoC/sensor inputs. This blocks timing sign-off, not RTL generation. A reusable template may help, but must not invent sensor tCO/setup/hold or asynchronous exceptions. |
| F-016 | High | Keep; proposed numeric constraints unproven | The bundled-data path is a real critical crossing and its `T_margin` is not quantified in the HDS or SDC. Four-cycle spacing alone is not timing closure. The proposed `2*T_APB`/`1*T_APB` constraints are hypotheses; derive endpoints and budgets from the actual synchronizer/FIFO path and selected sensor, then validate with STA and CDC/RDC tools. |
| F-017 | High | PPA documentation gap; severity overstated | No library/workload means no mapped area or power result. A structural proxy is useful, but its absence is not a functional bug and should not be called High without a product area target. |
| F-018 | Medium | Valid cost observation; proposed architecture not established | Both FIFOs are instantiated, so storage is duplicated. This is the consequence of selecting between unrelated-clock AFIFO and APB-clocked SFIFO at runtime. Sharing storage would require a safe clock/port architecture or static build choice; an ordinary write-clock mux could create clock/CDC/DFT hazards. Treat as PPA trade-off, not defect. |
| F-019 | High | Conditional; overlaps F-001 | The f_APB/2 minimum for an ideal two-cycle APB transfer is a useful lower-bound calculation; real stalls lower throughput. VGA/720p figures are assumed workloads, not user requirements. Keep numerical throughput as an integration task and do not use assumed workloads to label RTL broken. |
| F-020 | High | Partly correct; recovery claim overstated | There is no FIFO flush CSR, but FIFO level is exposed and software can disable capture and drain entries. Overflow can still destroy frame alignment because no frame marker/count is provided; a flush/restart-at-VSYNC sequence would improve recovery. It is a feature gap, not true that reset or blind draining are the only options. |
| F-021 | Medium | Intentional behavior; optional usability change | Ignoring unsafe `PCLK_MODE` writes while returning OKAY is explicit in REQ-FUNC-004/DEC-018; firmware is instructed to read back. A sticky reject bit or PSLVERR could improve diagnosability but would change the approved bus behavior. |
| F-022 | High | Keep as DFT integration action; proposed details speculative | DFT is marked integration TBD, so scan eligibility is not closed for sign-off. The proposed universal scan clock/reset/mux policy cannot be imposed without the SoC DFT architecture; document the required interfaces and owner instead. |
| F-023 | Low | Agree / accepted waiver | PPROT is ignored and protection disabled by approved scope; SoC interconnect owns privilege isolation. Keep the stated SoC owner and invalidation condition. |
| F-024 | Medium | Optional RAS roadmap | More counters/flags can aid debug, but ECC/safety was not requested and the HDS makes no safety claim. Do not classify the lack of a drop counter or mode-reject bit as an RTL bug unless the product sets a diagnostic coverage target. |
| F-025 | High | Agree; verification/sign-off gap | The README says no testbench or behavioral simulation. This is factual and blocks behavioral sign-off, but it does not prove a functional failure. Existing WaveDrom is explanatory collateral, not simulation evidence. |
| F-026 | High | Agree in substance; partly traceability-only | Tests and properties are planned, not executable, and TEST-005 covers only ACK then drain-below-watermark, not a fixed short burst with occupancy still high. Missing SVA IDs alone is a traceability issue. The DMA/liveness and gated timing scenarios need implementation in a real regression. |
| F-027 | Medium | Agree; documentation defect | The normative HDS still contains template instructions and a bad section anchor (it points to section 21 although references are section 22). This is a document cleanup item, not RTL. |
| F-028 | Medium | Partly agree; rationale overstated | Baseline plus versioned update was deliberately chosen, so duplication itself is not a defect if README identifies the active file. `Draft` can correctly mean not integration/sign-off approved even if RTL-generation plan was approved. Clarify lifecycle/status and use repository-relative paths. |
| F-029 | High | Agree as integration qualification gap | No exact camera model, register mode, PCLK blanking behavior or electrical timing is qualified. This prevents claiming broad sensor support, especially for gated mode. It is an integration dependency, not a proven RTL mismatch. |
| F-030 | Medium | Useful integration documentation; severity overstated | A checklist would help, but the 15 gap-scan items are integration inputs, not 15 blocking RTL defects. Keep owners and closure stage in an integration checklist. |
| F-031 | High | Product roadmap; not an implementation finding | Frame automation, packing, crop and decimation are commercial feature comparisons outside the declared capture-only scope. The source review says it did not open vendor reference manuals, so this comparison cannot establish a technical RTL bug or justify High severity. |

## 4. Deep rebuttal of the main technical claims / Phản biện sâu các điểm kỹ thuật chính

### 4.1 DMA REQ/ACK liveness — F-004, F-005, F-008

**EN.** This is the clearest real interface issue. In `m_dvp_dma_req.sv`, ACK moves the FSM from `REQ` to `DRAIN`; it returns to `WAIT` only when occupancy is below watermark. If the DMA treats ACK as “start a fixed burst” and stops while occupancy remains high, no new request is generated. If it keeps reading until occupancy is below threshold, the existing contract works. The spec does not select between these DMA behaviors, and TEST-005 only exercises the simple drain-below-threshold case. The review's `burst_left = watermark` proposal is not yet justified: watermark may not equal the occupancy at ACK; DMA may abort or read more/fewer entries; the controller must count *accepted* FIFO reads; and a second ACK/burst boundary must be defined. Close the contract first; either require DMA to drain below watermark or add an explicit batch-done/credit/count protocol.

**VI.** Đây là vấn đề giao diện thật rõ nhất. Trong `m_dvp_dma_req.sv`, sau ACK FSM vào `DRAIN`, chỉ quay lại `WAIT` khi occupancy xuống dưới watermark. Nếu DMA hiểu ACK là “bắt đầu một burst cố định” rồi dừng khi occupancy vẫn cao, sẽ không có request mới. Nếu DMA tiếp tục đọc đến khi xuống dưới watermark, thiết kế hiện tại hoạt động theo hợp đồng. HDS và TEST-005 chưa chốt rõ kiểu DMA nào. Ý tưởng `burst_left = watermark` chưa đủ căn cứ: occupancy lúc ACK có thể lớn hơn watermark; DMA có thể dừng sớm hoặc đọc nhiều hơn; controller phải đếm đúng các lần FIFO pop thành công. Cần chốt hợp đồng trước: yêu cầu DMA drain dưới watermark, hoặc thêm batch-done/đếm-credit rõ ràng.

### 4.2 Gated PCLK reset and bundled data — F-009, F-010, F-016

**EN.** The source makes the reset topology concrete: `w_rst_n_apb` is generated by the APB reset synchronizer and drives asynchronous reset pins on `reg_gated_data`/`reg_valid_toggle`, which are clocked by rising or falling PCLK. HDS DEC-029 acknowledges this and requires checking reset removal at the first selected PCLK edge. Therefore F-009 is a real RDC/timing closure item, not a spec contradiction. The review's resetless snippet is not a complete remedy until the source toggle's power-up state, APB baseline acquisition, reset re-entry, mode changes, and first-pixel ordering are specified and proved. Separately, the 2-FF toggle detector and held-data bus depend on `T_PIX,min >= 4*T_APB + T_margin`; there is no SDC or STA evidence. The suggested max-delay numbers in the review should be treated as proposed constraints, not accepted values. If the sensor violates the required spacing, current RTL has no dedicated gated-overrun diagnostic; that matters only if operation outside the integration contract must be detected.

**VI.** Source xác nhận đường reset cụ thể: `w_rst_n_apb` được đồng bộ theo APB nhưng nối vào chân reset bất đồng bộ của `reg_gated_data`/`reg_valid_toggle`, trong khi các flop này chạy theo cạnh PCLK lên hoặc xuống. DEC-029 đã ghi nhận và yêu cầu kiểm tra recovery/removal ở cạnh PCLK đầu tiên. Do đó F-009 là việc RDC/timing cần đóng, không phải sai khác giữa RTL và HDS. Đoạn đề xuất bỏ reset chưa phải cách sửa hoàn chỉnh nếu chưa quy định trạng thái khởi động toggle, cách APB lấy baseline, reset lặp, đổi mode và thứ tự pixel đầu. Bundled-data cũng chưa được chứng minh vì thiếu SDC/STA cho điều kiện `T_PIX,min >= 4*T_APB + T_margin`. Các con số delay mà review đề xuất chỉ là giả thuyết cho đến khi tính từ endpoint thật. Nếu sensor vi phạm khoảng cách yêu cầu, RTL hiện không có cờ gated-overrun riêng; điều đó chỉ là lỗi sản phẩm nếu cần phát hiện vận hành ngoài hợp đồng tích hợp.

### 4.3 APB timeout and recovery — F-007, F-020

**EN.** The endpoint's wait-on-empty behavior is intentional and has a programmable timeout. A large timeout can monopolize a single-outstanding APB path; this is a serious integration hazard but not an accidental wait-state bug. SoC integration should program a bounded value and, where needed, put a shorter bridge/watchdog timeout around the transaction. The FIFO level CSR also means software can observe and drain remaining entries; therefore “reset or blind drain only” is too strong. A flush CSR and frame marker would make post-overflow recovery easier, but both are new features.

**VI.** Endpoint được thiết kế chờ FIFO có dữ liệu và có timeout lập trình được. Timeout lớn có thể chiếm APB chỉ có một giao dịch đang chờ; đây là rủi ro tích hợp nghiêm trọng nhưng không phải wait-state ngoài ý muốn. SoC cần giới hạn giá trị firmware ghi và có thể đặt timeout ngắn hơn ở bridge/watchdog. CSR FIFO level cho phép software quan sát và drain dữ liệu, nên nhận định “chỉ reset hoặc drain mù” là quá mạnh. FIFO flush và frame marker sẽ giúp khôi phục sau overflow, nhưng là tính năng mới.

## 5. Requirement-to-RTL evidence matrix / Ma trận requirement–RTL–bằng chứng

**EN.** `not verified` means source appears to implement the requirement, but there is no executable behavioral test or sign-off analysis in the supplied package. Existing lint/elaboration and CSR checks are static evidence only.

**VI.** `not verified` nghĩa là source có vẻ triển khai yêu cầu, nhưng gói hiện tại không có test chức năng chạy được hoặc báo cáo sign-off. Lint/elaboration/CSR check là bằng chứng tĩnh, không thay simulation.

| Requirement | RTL and locator | Planned evidence | Status / note |
|---|---|---|---|
| REQ-FUNC-001 | `rtl/m_dvp_controller.sv:12-44`; `rtl/m_dvp_capture.sv:12-28` | TEST-001; profile elaboration logs | not verified behavior; width elaboration recorded |
| REQ-FUNC-002 | `rtl/m_dvp_capture.sv:104-149`; top parameters `rtl/m_dvp_controller.sv:16-28` | TEST-001/002 | not verified behavior; compile-time parameterization is present |
| REQ-FUNC-003 | `rtl/m_dvp_buffer.sv:101-110,180-195`; generated CSR overflow `rtl/csr/m_vlsit_csr_dvp.sv:411-425` | TEST-002/006 | not verified; overflow/full and set-dominant clear need simulation |
| REQ-PARAM-001 | `rtl/m_dvp_controller.sv:32-44`; `rtl/m_dvp_buffer.sv:16-34` | TEST-001/006 | not verified for illegal depths/boundaries; default is 8 |
| REQ-IF-001 | `rtl/m_dvp_apb_data.sv:60-96`; `rtl/m_dvp_apb_service.sv:241-260` | TEST-003 | not verified; no APB BFM/scoreboard source |
| REQ-IF-002 | `rtl/m_dvp_apb_data.sv:51-90` | TEST-004 | not verified; no wait/pop regression |
| REQ-IF-003 | `rtl/m_dvp_controller.sv:47-70` | TEST-008; top inventory | match at port/static level; no runtime proof needed for port scope |
| REQ-IF-004 | `rtl/m_dvp_dma_req.sv:45-72` | TEST-005 | not verified; HDS contract matches FSM but short-burst liveness is unspecified |
| REQ-IF-005 | `rtl/m_dvp_apb_data.sv:51-90` | TEST-011 | not verified; timeout boundary priority requires simulation |
| REQ-REG-001 | `rtl/csr/m_vlsit_csr_dvp.sv`; `spec/VLSIT_DVP_CONTROLLER_CSR.json` | TEST-007; CSR static validation | not verified APB behavior; workbook/JSON static check recorded PASS |
| REQ-SCOPE-001 | `rtl/m_dvp_controller.sv:47-70` | TEST-008; hierarchy/ports | match at interface scope |
| REQ-FUNC-004 | `rtl/m_dvp_apb_service.sv:115-124`; `rtl/m_dvp_buffer.sv:250-270` | TEST-014 | not verified; mode gating/source-quiescence needs APB simulation |
| REQ-FUNC-005 | `rtl/m_dvp_capture.sv:104-149`; `rtl/m_dvp_buffer.sv:119-151` | TEST-012 | not verified; continuous AFIFO ordering needs unrelated-clock simulation |
| REQ-FUNC-006 | `rtl/m_dvp_capture.sv:151-175`; `rtl/m_dvp_gate_bridge.sv:52-102` | TEST-013 | not verified; toggle/VSYNC/frame qualification needs simulation |
| REQ-FUNC-007 | `rtl/m_dvp_gate_bridge.sv:60-102` | TEST-013; STA/SDC | not verified; four-cycle rule is external and not enforced in hardware |
| REQ-FUNC-008 | `rtl/m_dvp_apb_data.sv:92-96` | TEST-003 | not verified; zero-extension is visible in RTL |
| REQ-IF-006 | `rtl/m_dvp_apb_decode.sv`; `rtl/m_dvp_apb_data.sv:56-90` | TEST-003/008 | not verified; decode/error/pop behavior requires APB simulation |
| REQ-PERF-001 | `rtl/m_dvp_gate_bridge.sv:56-102` | TEST-013; STA/SDC | not verified; no numeric timing constraints or STA report |
| REQ-RESET-001 | `rtl/m_dvp_controller.sv:85-109`; `rtl/m_dvp_capture.sv:151-175` | TEST-009/015; RDC | not verified; cross-domain reset path needs RDC and first-edge recovery/removal proof |

## 6. Review-artifact quality / Chất lượng artifacts của review

**EN.** The original `run_report.md` correctly labels the exercise as a specification review and says no RTL cross-check was done; the 31 finding IDs should not be presented as confirmed implementation bugs. The same run report says the audit sample was adjudicated 4/4 true positives, but `audit_sample.json` still has empty `verdict` and `result` fields for all four rows, so that claim cannot be independently reproduced from the saved artifact. `gate_metrics.json` reports 30 findings as “fixed” because each disposition starts with `fix`; the narrative, however, presents them as proposed fixes and does not show that the RTL/spec was changed. Treat `closure_rate=0.968` as a disposition metric from this script, not as 96.8% implementation closure. The original findings also leave `owner` blank, which weakens action tracking.

**VI.** `run_report.md` ghi đúng đây là specification review và không cross-check RTL; không nên trình bày 31 finding như 31 bug đã xác nhận. Báo cáo nói audit sample đạt 4/4 true positive, nhưng cả bốn dòng trong `audit_sample.json` vẫn để trống `verdict` và `result`, nên không thể kiểm chứng độc lập kết quả đó từ artifacts. `gate_metrics.json` tính 30 finding là “fixed” vì disposition bắt đầu bằng `fix`, trong khi phần nội dung mới đưa ra đề xuất chứ không chứng minh đã sửa RTL/spec. Vì vậy `closure_rate=0.968` là cách đếm disposition của script, không phải tỷ lệ đóng bug implementation. Trường `owner` cũng đang để trống, làm yếu theo dõi hành động.

## 7. Recommended action order / Thứ tự xử lý đề xuất

| Priority | Action | Owner | Reason |
|---|---|---|---|
| P0 | Specify DMA ACK meaning, stop/drain condition, burst length and behavior for residual occupancy below watermark; extend TEST-005 with fixed-burst and re-request cases. | Spec + SoC DMA + RTL/verification | Resolves F-004/F-005/F-008 at the interface boundary before changing the FSM. |
| P0 | Produce gated-mode CDC/RDC review and SDC/STA derivation for APB-synchronized reset release and bundled data; specifically verify reset release to both rising- and falling-edge capture variants and first-pixel capture. | CDC/RDC + STA/SoC integration | Resolves F-009/F-016 and supports F-010/F-029. |
| P0 | Implement and run the HDS-directed behavioral testbench for APB, FIFO, watermark, both capture modes, reset, and gated timing; record exact source lists, tool versions and results. | Verification | Closes the evidence gap F-025/F-026; current lint is not behavioral proof. |
| P1 | Set an integration maximum for `dvp_timeout.cycles` and document APB blocking behavior; add a system bridge timeout if required. | SoC/firmware | Bounds F-007 without changing the 32-bit CSR before product need is known. |
| P1 | Select at least one exact camera and register mode; verify PCLK behavior, VSYNC/HREF semantics, voltage/timing and gated-mode rate. | Sensor/SoC integration | Defines the compatibility claim and closes the F-003/F-029 uncertainty. |
| P2 | Clean HDS template residue, fix anchor, clarify Draft versus RTL-generation approval, and add an owner-based integration checklist. | Specification owner | Resolves F-027/F-028/F-030. |
| Roadmap | Decide separately whether frame counters/IRQ/flush/packing/overrun diagnostics/runtime profile/ECC are product requirements. | Product/architecture | Avoids adding unapproved hardware just to close scope findings F-002/F-006/F-011/F-013/F-020/F-021/F-024/F-031. |

## 8. Final conclusion / Kết luận cuối

**EN.** The original review is useful as a product/specification gap review, particularly on DMA service liveness, gated-mode integration proof, APB blocking, sensor qualification, and missing simulation. Its headline of “many bugs” overstates the evidence: most findings are optional features or integration deliverables that were consciously left outside RTL scope. I found no deterministic APB/CSR functional mismatch from static inspection alone, but behavioral correctness remains unverified. Do not apply the review's proposed RTL changes wholesale: first resolve the DMA contract and reset/CDC architecture with tests and STA/RDC evidence. No RTL was changed and no simulation was run for this rebuttal.

**VI.** Review gốc có ích như một review về product/spec gap, đặc biệt ở liveness DMA, chứng minh gated-mode, nguy cơ APB bị giữ, chọn sensor và thiếu simulation. Tuy vậy, cách gọi chung là “nhiều bug” vượt quá bằng chứng: phần lớn là tính năng tùy chọn hoặc đầu việc tích hợp đã được để ngoài phạm vi RTL. Static inspection chưa xác nhận sai lệch chức năng APB/CSR cụ thể, nhưng chức năng vẫn chưa được kiểm chứng bằng simulation. Không nên áp dụng nguyên trạng mọi RTL change trong review; trước hết cần chốt hợp đồng DMA và kiến trúc reset/CDC, rồi kiểm tra bằng regression và STA/RDC. Bản phản biện này không sửa RTL và không chạy simulation.

## Evidence files / Tệp bằng chứng

- Original review: `025_DVP_Controller/review/REVIEW_DVP_Controller.md`, `025_DVP_Controller/review/reference/spec_review_2026-11-22/vlsit_spec_2026-11-22.md`, `findings.json`, `audit_sample.json`, `gate_metrics.json`, `run_report.md`.
- Normative HDS: `025_DVP_Controller/spec/rtl_generation_2026-11-22/VLSIT_DVP_CONTROLLER_HDS.md`.
- Key RTL: `025_DVP_Controller/rtl/m_dvp_dma_req.sv`, `m_dvp_capture.sv`, `m_dvp_gate_bridge.sv`, `m_dvp_apb_data.sv`, `m_dvp_apb_service.sv`, `m_dvp_buffer.sv`, `m_dvp_controller.sv`, `rtl/csr/m_vlsit_csr_dvp.sv`.
- Verification boundary: `025_DVP_Controller/verification/README.md` and `spec/rtl_generation_2026-11-22/RTL_GENERATION_REPORT.md`.



