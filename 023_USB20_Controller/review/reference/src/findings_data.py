# Findings of the USB 2.0 controller specification review (2026-11-20).
# Each finding: id, area, severity (Blocker/Major/Minor/Observation), label, locator, evidence (file:line),
# root_cause, verdict ("fix HAS" | "fix RTL" | "none"), traced, EN title/statement/action, VI statement, why, snippet.
SPEC = "VLSIT_USB20_CONTROLLER_HDS.md"

F = []


def add(id, area, sev, label, loc, line, root, verdict, traced, title, en, vi, action, why, snippet=""):
    F.append(dict(id=id, area=area, severity=sev, label=label, locator=loc, evidence="%s:%s" % (SPEC, line), root_cause=root,
                  verdict=verdict, traced=traced, title=title, en=en, vi=vi, action=action, why=why, snippet=snippet))


add("F-001", "clock_reset_cdc", "Blocker", "FACT", "section 7.2 CDC-001, CDC-003, section 11.3 (u2_epi_*, u2_epo_*, u2_hc_* banks), section 11.2 S13 and S15", 930,
    "CSR multi-bit CDC structure", "fix HAS", True,
    "No approved crossing structure for the multi-bit endpoint and channel registers",
    "FACT: CDC-001 says the bundled values change only while the core is disabled, but S13, S15 and S17 of section 11.2 write ep_en, ch_en, set_nak, set_d0, stall and port_rst while core_en = 1, and section 11.3 routes the whole u2_epi_*, u2_epo_* and u2_hc_* banks (about 3 800 control flip-flops at the default counts, proxy from regs_usb2.json) through CDC-001 and CDC-003, which are a level synchronizer and a pulse synchronizer. No structure carries a 32-bit field such as u2_epi_dma.addr safely from CLK-BUS to CLK-PHY.",
    "FACT: CDC-001 nói các giá trị chỉ đổi khi core bị tắt, nhưng S13, S15 và S17 ở mục 11.2 ghi ep_en, ch_en, set_nak, set_d0, stall và port_rst khi core_en = 1, và mục 11.3 đưa toàn bộ bank u2_epi_*, u2_epo_*, u2_hc_* (khoảng 3 800 flip-flop điều khiển ở số lượng mặc định, proxy từ regs_usb2.json) qua CDC-001 và CDC-003, tức bộ đồng bộ level và pulse. Không có cấu trúc nào truyền an toàn trường 32 bit như u2_epi_dma.addr từ CLK-BUS sang CLK-PHY.",
    "Define a request and acknowledge handshake per bank entry (data held stable while the toggle crosses), or keep the endpoint and channel registers in CLK-PHY and write them from CLK-BUS through an asynchronous FIFO; update CDC-001 and CDC-003 and the CDC verification.",
    "A held-data handshake lets a multi-bit value cross while the sender keeps it constant until the receiver acknowledges, so no bit is sampled mid-change; the two-flop synchronizers of the current text are valid only for one-bit levels.",
    "// toggle handshake, sender side (CLK-BUS); data is held until ack_sync toggles\nalways_ff @(posedge i_clk_bus or negedge i_rst_n_bus)\n  if (!i_rst_n_bus) reg_req_tog <= 1'b0;\n  else if (w_wr_pulse && (reg_req_tog == w_ack_tog_sync)) begin\n    reg_data    <= w_wdata;   // stable until the next request\n    reg_req_tog <= ~reg_req_tog;\n  end")

add("F-002", "clock_reset_cdc", "Major", "FACT", "section 7.2 CDC-002, section 11.3 (xsize, pkt_cnt, addr are rwi), section 10.2 OP-007", 931,
    "CSR multi-bit CDC structure", "fix HAS", False,
    "Hardware-updated counters are read across CLK-PHY to CLK-BUS as levels",
    "FACT: xsize, pkt_cnt and the DMA address are counted down or advanced by hardware (section 11.3, rwi), and CDC-002 transfers status as synchronized levels. INFERENCE: a software read of a 19-bit counter that changes at packet rate can return a mixed value, and the rule that a software write wins over a hardware load can drop one decrement.",
    "FACT: xsize, pkt_cnt và địa chỉ DMA do hardware đếm xuống hoặc tăng (mục 11.3, rwi) và CDC-002 truyền status dạng level đồng bộ. INFERENCE: phần mềm đọc counter 19 bit đổi theo tốc độ gói có thể nhận giá trị lẫn bit, và quy tắc phần mềm ghi thắng hardware load có thể làm mất một lần giảm.",
    "Snapshot the counters in CLK-PHY and cross them with the same handshake as F-001, and state how a lost load is repeated.",
    "A snapshot taken while the source is stable gives software one consistent value per read.")

add("F-003", "performance", "Major", "INFERENCE", "section 10.4 (bandwidth check), section 7.1 (CLK-PHY 30 MHz), section 10.5 MEM-001", 4668,
    "FIFO RAM bandwidth", "fix HAS", True,
    "The single-port FIFO RAM has no bandwidth margin in the 16-bit UTMI+ configuration",
    "INFERENCE: section 10.4 shows 50 % use of 240 MB/s (32 bits at 60 MHz). With PARA_USB2_UTMI_W = 16 the RAM is in CLK-PHY at 30 MHz (section 7.1), so one port gives 120 MB/s while the packet engine needs 60 MB/s and the bus side up to 60 MB/s, which is 100 % use with no margin for arbitration or double buffering.",
    "INFERENCE: mục 10.4 cho thấy dùng 50 % của 240 MB/s (32 bit ở 60 MHz). Với PARA_USB2_UTMI_W = 16 RAM nằm ở CLK-PHY 30 MHz (mục 7.1), một cổng chỉ cho 120 MB/s trong khi packet engine cần 60 MB/s và phía bus tới 60 MB/s, tức 100 % và không còn dư cho arbitration hay double buffering.",
    "Add a bandwidth table per configuration, and either widen the RAM word to 64 bits when UTMI+ is 16 bits, run the RAM on a faster clock, or limit the 16-bit configuration to full-speed traffic.",
    "A wider word halves the access count per byte, so the same traffic uses about half of the RAM cycles at 30 MHz.")

add("F-004", "functions", "Major", "FACT", "TBD-005, section 7.4, section 10.1.7 (ulpi_if FSM), section 6.3 (ULPI register access)", 160,
    "ULPI low power and clock stop", "fix HAS", True,
    "ULPI low power mode, clock restart and resume are not specified",
    "FACT: TBD-005 leaves the ULPI low power mode open, section 7.4 says the PHY clock stops in suspend, and the ulpi_if FSM has no low-power, wake or reset state. INFERENCE: without them the link cannot enter suspend or L1 in a ULPI build, nor detect resume while CLK-PHY is stopped.",
    "FACT: TBD-005 để mở ULPI low power mode, mục 7.4 nói clock PHY dừng khi suspend, và FSM ulpi_if không có state low-power, wake hay reset. INFERENCE: thiếu chúng thì build ULPI không vào được suspend hay L1 và không phát hiện được resume khi CLK-PHY dừng.",
    "Read the low power sections of REF-007 (Figures 46 to 49, Table 15), add the states ENUM_ST_UL_LP and ENUM_ST_UL_WAKE and requirements for the stp and dir sequences and the clock restart wait.",
    "The ULPI link must drive stp and wait for the PHY clock restart before sending data, so the sequence is part of the interface contract.")

add("F-005", "interfaces", "Major", "FACT", "section 6.2 (o_utmi_opmode, o_utmi_xcvrsel, o_utmi_termsel), REQ-IF-001, REF-006 section 2.1.1", 207,
    "UTMI+ control encodings", "fix HAS", False,
    "The UTMI+ mode signals have no value table per bus state",
    "FACT: section 6.2 names OpMode, XcvrSelect and TermSelect but gives no table of the values for high-speed, full-speed, low-speed, preamble, chirp and suspend, and REF-006 section 2.1.1.4 requires TXReady during chirp data. The chirp, level 3 preamble and suspend sequences depend on these values.",
    "FACT: mục 6.2 nêu OpMode, XcvrSelect và TermSelect nhưng không có bảng giá trị cho high-speed, full-speed, low-speed, preamble, chirp và suspend, trong khi REF-006 mục 2.1.1.4 yêu cầu TXReady cả khi gửi chirp. Các chuỗi chirp, preamble level 3 và suspend phụ thuộc các giá trị này.",
    "Add a table from REF-006 and REF-007 that maps each state of the speed FSMs to XcvrSelect, TermSelect, OpMode, DpPulldown and DmPulldown.",
    "The table makes the speed and port FSMs implementable without reading the PHY datasheet first.")

add("F-006", "interfaces", "Major", "FACT", "ASM-007, REQ-IF-006, REQ-IF-007, REF-010, section 2.3", 5184,
    "Protocol source evidence", "fix HAS", True,
    "The AXI4 profile is specified against AXI3 text",
    "FACT: the only AXI text in md_doc is AXI v1.0 (AXI3 era); ASM-007 limits the profile to INCR bursts of at most 16 beats with no lock, QoS, region or user. INFERENCE: AXI4 behavior (for example awlen of 8 bits and the 4 KB rule wording) cannot be checked against a source.",
    "FACT: văn bản AXI duy nhất trong md_doc là AXI v1.0 (thời AXI3); ASM-007 giới hạn profile ở burst INCR tối đa 16 beat, không lock, QoS, region, user. INFERENCE: hành vi AXI4 (ví dụ awlen 8 bit và cách viết luật 4 KB) không kiểm được với nguồn.",
    "Add the AXI4 standard (IHI 0022 Issue H.c) to md_doc and recheck REQ-IF-006 and REQ-IF-007, or state the profile as AXI3-compatible only.",
    "A requirement is checkable only against a text that was read.")

add("F-007", "documentation", "Major", "FACT", "ASM-001, REF-006, REF-007, REF-001 conversion CHECK", 5178,
    "Protocol source evidence", "fix HAS", True,
    "UTMI+ and ULPI statements rest on unofficial copies and unverified conversions",
    "FACT: ASM-001 records that UTMI+ 1.0 (nxp.com mirror, 26 pages) and ULPI 1.1 (sparkfun.com mirror) are third-party copies, and the conversion check reported CHECK for every converted document with 114 pages of USB 2.0 differing by more than 5 %. The protocol statements of REQ-IF-001 to REQ-IF-004 and many REQ-FUNC lines cite them.",
    "FACT: ASM-001 ghi UTMI+ 1.0 (bản sao nxp.com, 26 trang) và ULPI 1.1 (bản sao sparkfun.com) là bản bên thứ ba, và kiểm tra chuyển đổi báo CHECK cho mọi tài liệu với 114 trang USB 2.0 lệch hơn 5 %. Các phát biểu giao thức của REQ-IF-001 đến REQ-IF-004 và nhiều REQ-FUNC trích dẫn chúng.",
    "Replace the copies by the official documents, inspect the pages that differ by more than 5 %, and record the result in section 2.1.",
    "An authoritative text removes the risk that a table or a figure was lost in conversion.")

add("F-008", "functions", "Major", "FACT", "REQ-FUNC-017, section 10.1.6 (host_xact), section 10.3 WF-013, REF-001 sections 11.17 to 11.21", 185,
    "Split transaction detail", "fix HAS", False,
    "Split transactions have a token format but no timing or retry rules",
    "FACT: REQ-FUNC-017 gives the SPLIT PID and the NYET and ERR handshakes only. It has no rule for the earliest and latest complete-split microframe, no retry count, no handling of isochronous MDATA, and the host_xact FSM has one ENUM_ST_HX_SPLIT state; WF-013 is not to scale.",
    "FACT: REQ-FUNC-017 chỉ cho PID SPLIT và handshake NYET, ERR. Không có quy tắc microframe sớm nhất và muộn nhất của complete-split, số lần retry, xử lý MDATA isochronous, và FSM host_xact chỉ có một state ENUM_ST_HX_SPLIT; WF-013 không theo tỷ lệ.",
    "Derive requirements from REF-001 sections 11.17 to 11.21 for the start-split and complete-split scheduling, the TT buffering responses and the retry limit, and split ENUM_ST_HX_SPLIT into start and complete states.",
    "These rules decide whether a full-speed device behind a hub works at all, and software cannot add them.")

add("F-009", "performance", "Major", "FACT", "PERF-002, section 6.3 (ULPI), REF-007 Tables 8 to 10, REQ-FUNC-006, REQ-FUNC-014", 4847,
    "Turnaround latency budget", "fix HAS", True,
    "The 192 bit-time turnaround budget is stated but not derived",
    "FACT: PERF-002 gives an internal budget of 20 CLK-PHY cycles for a handshake start within 192 bit times (24 cycles) including the ULPI pipeline. INFERENCE: REF-007 Tables 8 to 10 (PHY pipeline delays, link decision times) are not applied, and the path token decode to first RAM byte to TXValid has no cycle count, so the figure is a claim.",
    "FACT: PERF-002 cho ngân sách nội bộ 20 chu kỳ CLK-PHY để bắt đầu handshake trong 192 bit time (24 chu kỳ) gồm cả pipeline ULPI. INFERENCE: Table 8 đến 10 của REF-007 (trễ pipeline PHY, thời gian quyết định của link) chưa được áp dụng, và đường token decode đến byte RAM đầu tiên đến TXValid không có số chu kỳ, nên con số chỉ là khẳng định.",
    "Add a cycle budget table per response path for UTMI+ 8-bit, UTMI+ 16-bit and ULPI, using the pipeline delays of REF-006 and REF-007.",
    "A table of stage delays shows whether the 24-cycle limit has margin before RTL exists.")

add("F-010", "sdc_timing", "Major", "FACT", "section 17.1.2, TBD-007", 5003,
    "Timing numbers missing", "fix HAS", False,
    "The UTMI+ and ULPI interface timing budgets have no numbers",
    "FACT: the rows of section 17.1.2 for the UTMI+ and ULPI pins say TBD-007 and name REF-007 Table 5 as the source to apply. Interface timing is the first path that fails at 60 MHz.",
    "FACT: các hàng mục 17.1.2 cho chân UTMI+ và ULPI ghi TBD-007 và nêu Table 5 của REF-007 là nguồn cần áp dụng. Timing giao diện là đường đầu tiên hỏng ở 60 MHz.",
    "Transcribe the input and output delay and clock jitter values of REF-007 Table 5 and the UTMI+ timing into the table, and derive the set_input_delay and set_output_delay values.",
    "The constraints are the contract the integrator closes timing against.")

add("F-011", "sdc_timing", "Major", "FACT", "section 17.1.1 (sdc/usb2_clocks.sdc), section 17.1.2 (sdc/usb2_io.sdc), folder inventory", 4985,
    "Timing numbers missing", "fix HAS", False,
    "The SDC files named by the specification do not exist",
    "FACT: sections 17.1.1 and 17.1.2 name sdc/usb2_clocks.sdc and sdc/usb2_io.sdc as constraint sources, and the folder 023_USB20_Controller has no sdc or constraints directory (folder inventory, appendix).",
    "FACT: mục 17.1.1 và 17.1.2 nêu sdc/usb2_clocks.sdc và sdc/usb2_io.sdc là nguồn constraint, và thư mục 023_USB20_Controller không có thư mục sdc hay constraints (kiểm kê thư mục, phụ lục).",
    "Deliver the two SDC files with the specification, or change the text to say that they are produced with the RTL.",
    "A named but absent file is a finding in itself because the reader cannot check the constraints.")

add("F-012", "area_power", "Major", "FACT", "PPA-002, PPA-003, PPA-004, section 13", 4844,
    "Area and power not quantified", "fix HAS", True,
    "Area and power have no number and no activity assumption",
    "FACT: PPA-003 and PPA-004 are goals with no number, and area is deferred to synthesis. proxy: the CSR holds 3 802 control flip-flops at the default counts (9 endpoint, 8 channel, 4 DMA entries) and 6 868 at the maximum counts (regs_usb2.json, rw, rwi and w1c bits) plus a 4 KB RAM; the host channel registers duplicate the device endpoint registers, whereas REF-011 table 3-4 reuses the device registers as host registers to save area.",
    "FACT: PPA-003 và PPA-004 chỉ là mục tiêu không có số, diện tích để dành cho synthesis. proxy: CSR có 3 802 flip-flop điều khiển ở số lượng mặc định (9 endpoint, 8 channel, 4 DMA) và 6 868 ở số lượng tối đa (regs_usb2.json, các bit rw, rwi, w1c) cộng RAM 4 KB; thanh ghi host channel lặp lại thanh ghi endpoint thiết bị, trong khi REF-011 bảng 3-4 dùng lại thanh ghi thiết bị làm thanh ghi host để tiết kiệm diện tích.",
    "Record the proxy table (flip-flops, RAM bits, wide muxes) per configuration with its assumptions, state a power activity assumption, and evaluate sharing the device and host register banks.",
    "A labelled proxy lets the integrator size the block before synthesis.")

add("F-013", "software_ease", "Major", "FACT", "section 11.1, REF-011, section 11.2", 4720,
    "Software stack compatibility", "fix HAS", True,
    "The register model is custom, so no existing USB driver runs on it",
    "FACT: the CSR is a new 44-register map (REF-005); REF-011 is only a design reference. INFERENCE: Linux gadget and host stacks, TinyUSB and vendor HALs expect a known controller register model, so the firmware team must write and verify a driver, which the specification does not budget or describe.",
    "FACT: CSR là bản đồ 44 thanh ghi mới (REF-005); REF-011 chỉ là tham chiếu thiết kế. INFERENCE: stack Linux gadget và host, TinyUSB và HAL của hãng mong đợi mô hình thanh ghi controller đã biết, nên đội firmware phải viết và kiểm driver, điều spec không dự trù hay mô tả.",
    "Add a software integration section: driver scope, a register-level state-machine reference for EP0, a statement of compatibility, and an option to provide a compatibility view of a known controller.",
    "A driver plan turns a hidden firmware cost into a scheduled one.")

add("F-014", "software_ease", "Minor", "FACT", "section 11.3 closing paragraph", 4090,
    "CSR multi-bit CDC structure", "fix HAS", False,
    "The rule for a lost rwi load is stated but not defined per field",
    "FACT: section 11.3 says the IP repeats a lost load, 'a count-down update is re-applied in the next cycle'. INFERENCE: the repeated value depends on whether software wrote xsize or the hardware had counted, and the text does not say which wins.",
    "FACT: mục 11.3 nói IP lặp lại lần load bị mất, 'cập nhật giảm được áp dụng lại ở chu kỳ sau'. INFERENCE: giá trị lặp phụ thuộc phần mềm vừa ghi xsize hay hardware vừa đếm, và văn bản không nói bên nào thắng.",
    "Define per rwi field who wins and how the hardware reapplies, and add an assertion.",
    "An explicit rule is needed for the verification to check.")

add("F-015", "functions", "Minor", "FACT", "REQ-FUNC-034, section 7.2 CDC-001, section 10.3 WF-035", 202,
    "Over-current timing", "fix HAS", True,
    "The over-current requirement gives one latency for two outputs in different clock domains",
    "FACT: REQ-FUNC-034 says o_vbus_pwr_en and o_utmi_drvvbus drop within 2 CLK-BUS cycles, but o_utmi_drvvbus is a CLK-PHY output reached through CDC-001 (WF-035 shows it later) and CLK-PHY can be stopped in suspend. ULPI has no DrvVbus pin.",
    "FACT: REQ-FUNC-034 nói o_vbus_pwr_en và o_utmi_drvvbus hạ trong 2 chu kỳ CLK-BUS, nhưng o_utmi_drvvbus là ngõ ra CLK-PHY đi qua CDC-001 (WF-035 cho thấy nó trễ hơn) và CLK-PHY có thể dừng khi suspend. ULPI không có chân DrvVbus.",
    "Split the requirement: o_vbus_pwr_en within 2 CLK-BUS cycles, o_utmi_drvvbus within a stated number of CLK-PHY cycles or at the next clock restart, and a ULPI OTG control register write for ULPI builds.",
    "Only the CLK-BUS output has a guaranteed latency; the other path must be stated separately.")

add("F-016", "interfaces", "Minor", "INFERENCE", "REQ-FUNC-023, section 11.2 S05, section 6.2 ULPI ports", 191,
    "ULPI low power and clock stop", "fix HAS", False,
    "The ID source of the dual-role port is not stated for ULPI builds",
    "INFERENCE: the ULPI port list has no ID pin and the UTMI+ port list has i_utmi_iddig, so in a ULPI build the ID indication must come from the PHY status byte and the ID pull-up from a PHY register write; REQ-FUNC-023 and S05 do not say which register or bit.",
    "INFERENCE: danh sách port ULPI không có chân ID trong khi UTMI+ có i_utmi_iddig, nên ở build ULPI chỉ báo ID phải đến từ byte status của PHY và pull-up ID từ ghi thanh ghi PHY; REQ-FUNC-023 và S05 không nói thanh ghi hay bit nào.",
    "State the ULPI register and RX CMD field for ID, and add the PHY register writes to the initialization flow.",
    "Role selection in a ULPI build depends on this register access.")

add("F-017", "security_ras", "Minor", "INFERENCE", "section 18 (ECC/parity row), TBD-010", 5053,
    "RAM soft error", "fix HAS", True,
    "The soft-error statement for the FIFO RAM is not correct",
    "INFERENCE: section 18 says a RAM soft error is detected by the CRC of the next packet on the wire side. The CRC16 is generated over the bytes read from the RAM at transmit time, so a flipped bit produces a valid CRC and is not detected; a receive-side flip happens after the CRC check.",
    "INFERENCE: mục 18 nói lỗi mềm RAM được phát hiện bởi CRC của gói kế tiếp phía wire. CRC16 được sinh trên byte đọc từ RAM lúc truyền, nên bit bị lật vẫn cho CRC hợp lệ và không bị phát hiện; lật ở phía nhận xảy ra sau khi kiểm CRC.",
    "Correct the statement and decide TBD-010: add one parity bit per RAM word with an error flag and a fail-safe response for the drone product, or document the residual risk.",
    "A parity bit detects a single flip at read time, before the CRC is generated.",
    "// 33-bit RAM word: parity written with the data and checked on read\nassign w_par_wr = ^w_wdata;\nassign w_par_err = (^w_rdata_full[31:0]) ^ w_rdata_full[32];")

add("F-018", "security_ras", "Minor", "FACT", "section 11.4, u2_dma_cfg.axi_prot, u2_dma_hi, section 18", 4095,
    "DMA access protection", "fix HAS", False,
    "DMA addresses are unrestricted software values",
    "FACT: the DMA address registers and u2_dma_hi are plain read-write fields and the only access protection of the CSR is PPROT[1] with i_protect_en (section 11.4). INFERENCE: any APB master that can write the CSR can point the DMA at any address of the AXI fabric.",
    "FACT: thanh ghi địa chỉ DMA và u2_dma_hi là trường đọc-ghi thường và bảo vệ truy cập duy nhất của CSR là PPROT[1] với i_protect_en (mục 11.4). INFERENCE: master APB nào ghi được CSR đều trỏ được DMA tới địa chỉ bất kỳ của AXI fabric.",
    "Add an optional address window check (base and limit registers) that raises dma_err on a violation, or state that the SoC firewall owns it.",
    "A window check contains a faulty descriptor before it reaches memory.")

add("F-019", "clock_reset_cdc", "Minor", "FACT", "section 7.3, section 11.2 S18, CDC-005, u2_sts.phy_clk_ok", 941,
    "ULPI low power and clock stop", "fix HAS", False,
    "Reset behavior with a stopped CLK-PHY is not stated",
    "FACT: section 7.3 gives reset sequencing for running clocks, but the PHY may stop CLK-PHY in ULPI low power mode (section 7.1) and the soft-reset pulse crosses through CDC-005 into CLK-PHY. INFERENCE: with the clock stopped a soft reset never completes, and S18 does not check phy_clk_ok.",
    "FACT: mục 7.3 mô tả trình tự reset khi clock chạy, nhưng PHY có thể dừng CLK-PHY ở ULPI low power mode (mục 7.1) và xung soft-reset đi qua CDC-005 vào CLK-PHY. INFERENCE: khi clock dừng, soft reset không bao giờ xong, và S18 không kiểm phy_clk_ok.",
    "State the stopped-clock behavior of i_rst_n_phy and the soft reset, require phy_clk_ok = 1 in S18, and add a timeout flag.",
    "The software then never waits for a reset that cannot finish.")

add("F-020", "parameters", "Minor", "FACT", "REQ-PARAM-001, ASM-011, section 11.1 (repeated register groups)", 219,
    "Parameter checking", "fix HAS", False,
    "Illegal parameters are undefined and the CSR bank counts are 19 separate parameters",
    "FACT: REQ-PARAM-001 and ASM-011 leave illegal values undefined, and section 11.1 requires the integrator to tie each generated PARA_U2_xx_COUNT (19 banks) to PARA_USB2_NUM_EP, NUM_HC or NUM_DMA_CH. INFERENCE: a mismatch between a bank count and the engines produces silent address or endpoint errors.",
    "FACT: REQ-PARAM-001 và ASM-011 để giá trị sai không xác định, và mục 11.1 yêu cầu integrator gán từng PARA_U2_xx_COUNT (19 bank) bằng PARA_USB2_NUM_EP, NUM_HC hoặc NUM_DMA_CH. INFERENCE: lệch giữa số bank và engine gây lỗi địa chỉ hoặc endpoint im lặng.",
    "Derive all bank counts inside the core from three parameters and add a synthesizable-neutral elaboration check module reported by lint.",
    "One source for each count removes the mismatch.")

add("F-021", "parameters", "Minor", "INFERENCE", "section 4 (illegal combinations), section 8 PARA_USB2_FIFO_DEPTH, ASM-005, CFG-MIN", 962,
    "FIFO sizing rule", "fix HAS", False,
    "The minimum FIFO depth rule does not cover high-bandwidth and double buffering",
    "INFERENCE: the rule requires only one maximum packet (256 words), while high-bandwidth isochronous is always present (ASM-005) with up to three 1 024-byte transactions per microframe (768 words) and dbuf doubles each region; CFG-MIN uses 256 words.",
    "INFERENCE: quy tắc chỉ yêu cầu một gói tối đa (256 word), trong khi isochronous băng thông cao luôn có (ASM-005) với tối đa ba giao dịch 1 024 byte mỗi microframe (768 word) và dbuf nhân đôi mỗi vùng; CFG-MIN dùng 256 word.",
    "Define the minimum region size as a function of endpoint type, mult and dbuf, and make the check part of REQ-PARAM-001.",
    "The check then rejects a configuration that cannot hold its traffic.")

add("F-022", "functions", "Minor", "FACT", "REQ-FUNC-015, ASM-014, REF-001 section 5.7.4", 183,
    "Host scheduling rules", "fix HAS", False,
    "Host scheduling cites an open assumption and omits the periodic bandwidth limits",
    "FACT: REQ-FUNC-015 has ASM-014 (open) as its source; REF-001 section 5.7.4 limits periodic transfers to 80 % of a high-speed microframe and 90 % of a full-speed or low-speed frame. The requirement does not state the limits or an admission check.",
    "FACT: REQ-FUNC-015 lấy ASM-014 (đang mở) làm nguồn; REF-001 mục 5.7.4 giới hạn transfer periodic ở 80 % microframe high-speed và 90 % frame full-speed hoặc low-speed. Yêu cầu không nêu giới hạn hay kiểm admission.",
    "Add the limits as requirements, with a software-visible refusal or flag when a channel set exceeds them, and close ASM-014.",
    "The limits come from the standard and bound what the scheduler may accept.")

add("F-023", "functions", "Minor", "FACT", "REQ-FUNC-025, REF-001 section 8.7.2", 193,
    "Unquantified timing", "fix HAS", False,
    "The time-out requirement has no number",
    "FACT: REQ-FUNC-025 refers to the bus turn-around time and gives no value in bit times, while REF-001 section 8.7.2 defines the timer start and stop events.",
    "FACT: REQ-FUNC-025 nhắc thời gian bus turn-around và không đưa giá trị theo bit time, trong khi REF-001 mục 8.7.2 định nghĩa sự kiện bắt đầu và dừng của timer.",
    "Add the worst-case turn-around values per speed from REF-001 sections 7.1.18 and 7.1.19.",
    "A number makes the timer testable.")

add("F-024", "functions", "Minor", "FACT", "REQ-FUNC-022 (section 3), ASM-017 (section 20), USB package file 'ECN for Core Spec TEST_MODE selector values.pdf'", 190,
    "Test mode entry", "fix HAS", False,
    "Test mode entry and exit commands are not specified",
    "FACT: REQ-FUNC-022 lists the four test modes and the pattern; ASM-017 leaves the entry through SetFeature(TEST_MODE) open. FACT: the user's USB package contains an ECN on the TEST_MODE selector values that the specification does not cite.",
    "FACT: REQ-FUNC-022 liệt kê bốn test mode và pattern; ASM-017 để mở việc vào test mode bằng SetFeature(TEST_MODE). FACT: gói USB của bạn có một ECN về giá trị selector TEST_MODE mà spec không trích dẫn.",
    "Convert the ECN, add the selector values and the exit action to REQ-FUNC-022, and close ASM-017.",
    "Compliance testing relies on the exact selector values.")

add("F-025", "documentation", "Observation", "INFERENCE", "section 2.1 (references), USB package ECN list", 124,
    "Protocol source evidence", "fix HAS", False,
    "Other ECNs of the USB 2.0 package are not cited",
    "INFERENCE: the package lists ECNs on double isochronous IN, phase-locked SOFs, suspend current and DCR that may affect the high-bandwidth isochronous and suspend requirements; only the LPM ECN is referenced.",
    "INFERENCE: gói liệt kê ECN về double isochronous IN, phase-locked SOF, suspend current và DCR có thể ảnh hưởng yêu cầu isochronous băng thông cao và suspend; chỉ ECN LPM được tham chiếu.",
    "Read the ECNs and record each as applicable or not applicable.",
    "A short applicability table closes the question.")

add("F-026", "verification_quality", "Minor", "FACT", "section 15.1, section 2.3, TEST-001 to TEST-029", 4902,
    "Verification coverage", "fix HAS", True,
    "The plan has no interoperability or compliance test with real stacks",
    "FACT: section 15.1 lists an FPGA prototype after the RTL and section 2.3 states that certification is not claimed; TEST-001 to TEST-029 use a bus model. INFERENCE: no test runs a real host or device stack (for example Linux gadget or TinyUSB) or the USB-IF device test sequence.",
    "FACT: mục 15.1 liệt kê FPGA prototype sau RTL và mục 2.3 nói không claim certification; TEST-001 đến TEST-029 dùng bus model. INFERENCE: không test nào chạy stack host hoặc device thật (ví dụ Linux gadget hoặc TinyUSB) hay chuỗi test thiết bị USB-IF.",
    "Add interoperability tests (CDC-ACM, UVC, mass storage with a real stack) and a compliance pre-check plan, with entry and exit criteria.",
    "Real stacks exercise orderings that a hand-written bus model does not.")

add("F-027", "documentation", "Minor", "FACT", "REQ-FUNC-015, REQ-FUNC-032, REQ-FUNC-034 to REQ-FUNC-036, section 20", 5176,
    "Open items", "fix HAS", False,
    "Several requirements take their source from open assumptions, and the open items have no owner or date",
    "FACT: REQ-FUNC-015, 032, 034, 035 and 036 cite ASM-014, 021, 022, 023 and 020 as their source and those are open; section 20 has 41 open items in a table without owner or date columns.",
    "FACT: REQ-FUNC-015, 032, 034, 035 và 036 trích ASM-014, 021, 022, 023 và 020 làm nguồn và chúng đang mở; mục 20 có 41 mục mở trong bảng không có cột owner hay ngày.",
    "Add owner and date columns, resolve or label each requirement 'proposed' until its assumption closes.",
    "An age and an owner make the open list manageable.")

add("F-028", "verification_quality", "Minor", "INFERENCE", "section 15.2 (TEST-007, TEST-009), REQ-FUNC-011, REQ-FUNC-018", 4912,
    "Verification coverage", "fix HAS", False,
    "Millisecond timings have no simulation time scaling",
    "INFERENCE: REQ-FUNC-011 (50 ms reset, 3 160 000 CLK-PHY cycles at 60 MHz), REQ-FUNC-018 (3 ms idle) and REQ-FUNC-019 (5 ms) are exercised by TEST-007 and TEST-009, and the specification has no timer scaling or test-time register to keep regression time short.",
    "INFERENCE: REQ-FUNC-011 (reset 50 ms, khoảng 3 triệu chu kỳ CLK-PHY ở 60 MHz), REQ-FUNC-018 (idle 3 ms) và REQ-FUNC-019 (5 ms) được thực hiện bởi TEST-007 và TEST-009, và spec không có hệ số scale timer hay thanh ghi test-time để giữ thời gian regression ngắn.",
    "Add a verification-only timer scale (parameter or CSR field in test mode) and require that the scaled and unscaled timings are both tested at least once.",
    "Scaling keeps the regression short while the unscaled run proves the real value.")

add("F-029", "asic_feasibility", "Minor", "FACT", "section 14.3, section 13, section 10.4", 4943,
    "Critical path statement", "fix HAS", False,
    "No critical-path statement for the 60 MHz domain",
    "FACT: section 14.3 leaves the frontend, libraries and corners to the RTL stage, and section 13 gives the CLK-PHY target of 60 MHz without naming a path. INFERENCE: the CRC16 update per byte, the RAM arbitration with the 20-cycle budget and the token decode are the likely critical paths and no pipeline split is stated.",
    "FACT: mục 14.3 để frontend, library và corner cho giai đoạn RTL, và mục 13 đưa mục tiêu CLK-PHY 60 MHz mà không nêu đường nào. INFERENCE: cập nhật CRC16 mỗi byte, arbitration RAM trong ngân sách 20 chu kỳ và token decode là các đường tới hạn có khả năng và không có phân tầng pipeline nào được nêu.",
    "List the expected critical paths with a pipeline stage count each, and require a synthesis run of one reference configuration before RTL sign-off.",
    "A named path and a stage count make the 60 MHz target checkable.")

add("F-030", "integration_effort", "Minor", "FACT", "section 6.2 (pad wrapper note), section 7.3, section 14.2", 780,
    "Integration guide", "fix HAS", False,
    "The specification has no integration checklist",
    "FACT: the tie-offs (i_ovrcur_n, i_protect_en, i_slverr_en), the pad wrapper for the bidirectional ULPI bus, the four wrappers and the RAM macro wrapper are described in separate sections. INFERENCE: the integrator has to assemble the bring-up order (clock, reset, PHY reset, phy_clk_ok, soft reset) from sections 7 and 11.2.",
    "FACT: tie-off (i_ovrcur_n, i_protect_en, i_slverr_en), pad wrapper cho bus ULPI hai chiều, bốn wrapper và wrapper macro RAM được mô tả ở các mục riêng. INFERENCE: integrator phải tự ghép thứ tự bring-up (clock, reset, PHY reset, phy_clk_ok, soft reset) từ mục 7 và 11.2.",
    "Add one integration table: tie-offs, clock and reset sequence, macro and pad wrappers, and the checks at power-up.",
    "One table is the checklist the SoC team signs.")

add("F-031", "dft", "Observation", "FACT", "section 16, TBD-009", 4975,
    "DFT detail", "fix HAS", False,
    "DFT ports and RAM test position are deferred to the SoC flow",
    "FACT: section 16 defers the scan ports to TBD-009 and the RAM bypass and MBIST to the SoC memory flow, with CLK-PHY stopped by the PHY replaced by the scan clock.",
    "FACT: mục 16 để các port scan cho TBD-009 và bypass RAM, MBIST cho memory flow của SoC, với CLK-PHY do PHY dừng được thay bằng scan clock.",
    "Name the scan clock mux ownership and the RAM bypass wrapper requirement before RTL.",
    "The two decisions change the clock and RAM wrappers.")

add("F-032", "market_position", "Observation", "FACT", "section 1.3, REF-011 chapter 3, TI AM335x TRM section 16.0.4, ESP32-S3 TRM section 32.2, RP2040 datasheet section 4.1.1.1", 66,
    "Market comparison", "none", False,
    "Feature set is close to the DWC_otg and the reference SoCs, with deliberate omissions",
    "FACT: compared with the sources of chapter 19, the specification adds an optional LPM and split, scatter-gather and double buffering, and omits HNP, SRP, ADP, battery charging detection, HSIC, a dedicated FIFO per IN endpoint and per-endpoint interrupts. These omissions follow user answers of 2026-11-20 and are recorded in section 20.",
    "FACT: so với các nguồn ở chương 19, spec thêm LPM và split tùy chọn, scatter-gather và double buffering, và bỏ HNP, SRP, ADP, phát hiện bộ sạc, HSIC, FIFO riêng cho từng endpoint IN và ngắt riêng từng endpoint. Các điểm bỏ này theo câu trả lời của người dùng ngày 2026-11-20 và có ghi ở mục 20.",
    "None: keep the omissions recorded.",
    "The omissions are decisions, not defects.")

add("F-033", "verification_quality", "Observation", "FACT", "section 19, inventory summary", 5100,
    "Traceability", "none", False,
    "Every requirement has a test",
    "FACT: the inventory reports 59 requirements, 29 tests, 15 properties and 0 requirements without a test; section 19 maps each requirement to a module, a test, a method and a configuration.",
    "FACT: inventory báo 59 yêu cầu, 29 test, 15 property và 0 yêu cầu không có test; mục 19 ánh xạ mỗi yêu cầu tới module, test, phương pháp và cấu hình.",
    "None.",
    "The matrix is complete; its depth is addressed by F-026 and F-028.")

add("F-034", "application_fit", "Observation", "FACT", "section 1.4, section 1.2, ASM-006", 70,
    "Application evidence", "fix HAS", False,
    "The application numbers are the author's proposals",
    "FACT: section 1.4 gives a measurable need per feature, and ASM-006 records that the drone values (MAVLink 921 600 baud, 6 endpoints, MJPEG 720p30) are proposals that the user has not confirmed.",
    "FACT: mục 1.4 đưa nhu cầu đo được cho mỗi feature, và ASM-006 ghi các giá trị drone (MAVLink 921 600 baud, 6 endpoint, MJPEG 720p30) là đề xuất người dùng chưa xác nhận.",
    "Confirm the values with the product owner and mark them 'confirmed' with a date.",
    "The sizing of endpoints, channels and FIFO depends on them.")

# area justifications and chapter text -------------------------------------------------------------
AREAS = {
 "application_fit": (4, "Named product, 23 features each with an application row, explicit excluded list; values are proposals (F-034).",
                     "Sản phẩm rõ, 23 feature đều có dòng ứng dụng, danh sách loại trừ rõ; các giá trị là đề xuất (F-034)."),
 "features": (4, "Each feature maps to requirements and a test; some requirements rest on open assumptions (F-027).",
              "Mỗi feature ánh xạ tới yêu cầu và test; một số yêu cầu dựa trên giả định mở (F-027)."),
 "functions": (2, "Two Major gaps (ULPI low power F-004, split F-008) and four Minor gaps in the cycle detail.",
               "Hai khoảng trống Major (ULPI low power F-004, split F-008) và bốn khoảng trống Minor về chi tiết theo chu kỳ."),
 "interfaces": (2, "Three Major findings: UTMI+ encodings (F-005), AXI4 profile against AXI3 text (F-006), unofficial sources (F-007).",
                "Ba phát hiện Major: encoding UTMI+ (F-005), profile AXI4 so với text AXI3 (F-006), nguồn không chính thức (F-007)."),
 "clock_reset_cdc": (1, "A Blocker: no safe crossing structure for the multi-bit endpoint and channel registers (F-001).",
                     "Một Blocker: không có cấu trúc crossing an toàn cho thanh ghi endpoint và channel nhiều bit (F-001)."),
 "parameters": (4, "Parameter table complete with ranges and dependencies; only Minor gaps in checking (F-020, F-021).",
                "Bảng tham số đầy đủ với dải giá trị và phụ thuộc; chỉ có khoảng trống Minor về kiểm tra (F-020, F-021)."),
 "data_representation": (4, "Quantity table, PID values, descriptor format are defined; no finding.",
                         "Bảng đại lượng, giá trị PID, định dạng descriptor đã xác định; không có phát hiện."),
 "asic_feasibility": (3, "No critical-path statement and the RAM bandwidth limit (F-029, F-003); the clocking itself is synthesizable in principle.",
                      "Không có phát biểu đường tới hạn và giới hạn băng thông RAM (F-029, F-003); phần clocking về nguyên tắc synthesize được."),
 "sdc_timing": (2, "Two Major findings: interface timing numbers missing (F-010) and the named SDC files absent (F-011).",
                "Hai phát hiện Major: thiếu số timing giao diện (F-010) và các file SDC được nêu không tồn tại (F-011)."),
 "area_power": (3, "Major: no area or power number; a flip-flop proxy is given in this review (F-012).",
                "Major: không có số diện tích hay công suất; review này đưa proxy flip-flop (F-012)."),
 "performance": (2, "Two Major findings: RAM bandwidth with 16-bit UTMI+ (F-003) and the underived 24-cycle budget (F-009).",
                 "Hai phát hiện Major: băng thông RAM với UTMI+ 16 bit (F-003) và ngân sách 24 chu kỳ chưa suy ra (F-009)."),
 "software_ease": (3, "Major: custom register model with no driver plan (F-013); the register set, flows and interrupt hierarchy are otherwise workable.",
                   "Major: mô hình thanh ghi riêng không có kế hoạch driver (F-013); bộ thanh ghi, flow và phân cấp ngắt còn lại dùng được."),
 "dft": (4, "Scan, MBIST and clock-gate test enable are addressed; ports deferred (F-031).",
         "Scan, MBIST và test enable của clock gate đã nêu; các port bị hoãn (F-031)."),
 "security_ras": (4, "Stance is explicit; only Minor findings on RAM soft error and DMA windows (F-017, F-018).",
                  "Lập trường rõ ràng; chỉ có phát hiện Minor về lỗi mềm RAM và cửa sổ DMA (F-017, F-018)."),
 "verification_quality": (4, "Full requirement to test trace; Minor gaps in interoperability and time scaling (F-026, F-028).",
                          "Truy vết yêu cầu tới test đầy đủ; khoảng trống Minor về interoperability và scale thời gian (F-026, F-028)."),
 "documentation": (3, "Major: unofficial and unverified protocol sources (F-007); open items lack owner and date (F-027).",
                   "Major: nguồn giao thức không chính thức và chưa kiểm (F-007); mục mở thiếu owner và ngày (F-027)."),
 "integration_effort": (4, "Wrappers, tie-offs and macros are described; no single checklist (F-030).",
                        "Wrapper, tie-off và macro đã mô tả; thiếu một checklist duy nhất (F-030)."),
 "market_position": (3, "Feature set is close to the references, but no area or power evidence to compare (F-032, F-012).",
                     "Bộ tính năng gần các tham chiếu, nhưng không có bằng chứng diện tích hay công suất để so sánh (F-032, F-012)."),
}
