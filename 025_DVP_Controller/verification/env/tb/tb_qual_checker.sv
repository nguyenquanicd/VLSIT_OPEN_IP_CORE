// tb_qual_checker.sv - qualification of dv_dvp_checker with SYNTHETIC traffic (no DUT, R-125, R-128, R-263, plan section 5.2).
// AI-generated candidate (R-117). A scripted "DUT" drives o_pready/o_prdata/o_pslverr/o_dma_req. Known-answer cases must
// pass with zero checker errors; every injected fault must make the checker report at least one error.
// The expected values below are derived from the HDS v0.3 / CSR v1.1 text (REQ-IF-001/002/004/005, REQ-FUNC-003/004/008/009/010,
// REQ-REG-002, APB4 clauses), never from the RTL. This is model/checker qualification, not DUT evidence.
`timescale 1ns/1ps
module tb_qual_checker;
  localparam int W = 8;
  localparam int DEPTH = 4;
  localparam logic [15:0] FA = 16'h0100;
  logic clk_apb = 0, rst_n = 1, dvp_clk = 0;
  logic [W-1:0] dvp_data = '0;
  logic dvp_vsync = 0, dvp_href = 0;
  logic [15:0] paddr = 0; logic psel = 0, penable = 0, pwrite = 0; logic [31:0] pwdata = 0; logic [3:0] pstrb = 0; logic [2:0] pprot = 0;
  logic pready = 0; logic [31:0] prdata = 0; logic pslverr = 0; logic dma_req = 0, dma_ack = 0;
  always #5.13 clk_apb = ~clk_apb;

  dv_dvp_checker #(.W(W), .EDGE(0), .VS_ACT(1), .HR_ACT(1), .DEPTH(DEPTH), .FIFO_ADDR(FA)) u_chk (
    .i_clk_apb (clk_apb), .i_rst_n (rst_n), .i_clk_dvp (dvp_clk), .i_data (dvp_data), .i_vsync (dvp_vsync), .i_href (dvp_href),
    .i_paddr (paddr), .i_psel (psel), .i_penable (penable), .i_pwrite (pwrite), .i_pwdata (pwdata), .i_pstrb (pstrb), .i_pprot (pprot),
    .i_pready (pready), .i_prdata (prdata), .i_pslverr (pslverr), .i_dma_req (dma_req), .i_dma_ack (dma_ack));

  int cases = 0, ok = 0, bad = 0;

  // ---- scripted DUT/APB transfer: completes in access cycle ncyc ----
  task automatic xfer(input logic [15:0] a, input bit wr, input logic [31:0] wd, input logic [3:0] st, input int ncyc,
                      input logic [31:0] rd, input bit err, input bit corrupt_addr_in_wait, input logic [3:0] rd_strb);
    @(posedge clk_apb);
    psel <= 1; penable <= 0; paddr <= a; pwrite <= wr; pwdata <= wd; pstrb <= wr ? st : rd_strb; pprot <= 0; pready <= 0; pslverr <= 0;
    @(posedge clk_apb);
    penable <= 1; pready <= (ncyc == 1); prdata <= rd; pslverr <= (ncyc == 1) ? err : 1'b0;
    for (int i = 2; i <= ncyc; i++) begin
      @(posedge clk_apb);
      if (corrupt_addr_in_wait && i == 2) paddr <= a ^ 16'h0004;
      pready <= (i == ncyc); pslverr <= (i == ncyc) ? err : 1'b0;
    end
    @(posedge clk_apb);
    psel <= 0; penable <= 0; pready <= 0; pslverr <= 0; pwrite <= 0; pstrb <= 0;
  endtask
  task automatic wr_csr(input logic [15:0] a, input logic [31:0] d);   xfer(a, 1, d, 4'hF, 2, 0, 0, 0, 0); endtask
  task automatic rd_csr(input logic [15:0] a, input logic [31:0] v);   xfer(a, 0, 0, 0, 2, v, 0, 0, 0); endtask
  task automatic rd_fifo(input logic [31:0] v);                         xfer(FA, 0, 0, 0, 1, v, 0, 0, 0); endtask
  task automatic rd_fifo_err(input int ncyc);                           xfer(FA, 0, 0, 0, ncyc, 0, 1, 0, 0); endtask
  task automatic settle(input int ns);                                  #(ns); endtask

  // ---- sensor events: one selected (rising) PCLK edge per pixel, values set before the edge ----
  task automatic pix(input logic [W-1:0] d, input bit hr);
    dvp_data = d; dvp_href = hr; #4; dvp_clk = 1; #4; dvp_clk = 0; #4;
  endtask
  task automatic vs_pulse();
    dvp_vsync = 1; #60; dvp_vsync = 0; #60;
  endtask
  task automatic reset_checker();
    rst_n = 0; dma_req = 0; dma_ack = 0;   // a real DUT drops o_dma_req in reset; the scripted DUT does the same
    repeat (4) @(posedge clk_apb); #1 rst_n = 1; repeat (4) @(posedge clk_apb);
  endtask
  task automatic enable_and_frame(input logic [W-1:0] a0, input logic [W-1:0] a1, input logic [W-1:0] a2, input logic [W-1:0] a3);
    wr_csr(16'h0004, 32'h1);        // capture_en
    settle(400);
    vs_pulse();
    settle(100);
    pix(a0, 1); pix(a1, 1); pix(8'h77, 0); pix(a2, 1); pix(a3, 1);   // one non-qualified sample (HREF inactive)
    settle(400);
  endtask

  // ---- case bookkeeping ----
  int e_before;
  task automatic begin_case(input string name); cases++; e_before = u_chk.errors(); $display("QUAL begin %s", name); endtask
  task automatic end_case(input string name, input bit expect_detect);
    int d;
    bit detected;
    repeat (3) @(posedge clk_apb);   // let the monitor process the last transfer before the verdict (race with the TB's last edge)
    #1;
    d = u_chk.errors() - e_before;
    detected = (d > 0);
    if (detected == expect_detect) begin ok++; $display("QUAL case=%s expect=%s observed_errors=%0d result=OK", name, expect_detect ? "DETECT" : "PASS", d); end
    else begin bad++; $display("QUAL case=%s expect=%s observed_errors=%0d result=BAD", name, expect_detect ? "DETECT" : "PASS", d); end
    reset_checker();
  endtask

  initial begin
    settle(50);
    reset_checker();

    // K1 known answers: ordered, zero-extended, exact values, status and level consistent
    begin_case("K1_known_answer_order_data");
    enable_and_frame(8'h12, 8'h34, 8'hFF, 8'h00);
    rd_csr(16'h0014, 4);                                            // level 4 = DEPTH, all four accepted pixels
    rd_fifo(32'h12); rd_fifo(32'h34); rd_fifo(32'hFF); rd_fifo(32'h00);
    rd_csr(16'h0014, 0); rd_csr(16'h0010, 32'h0000_0003);           // sts: active=1 empty=1 full=0 ovf=0
    end_case("K1_known_answer_order_data", 0);

    begin_case("F1_wrong_data");      enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    rd_fifo(32'h12); rd_fifo(32'h35); rd_fifo(32'h56); rd_fifo(32'h78);     end_case("F1_wrong_data", 1);
    begin_case("F2_reordered");       enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    rd_fifo(32'h34); rd_fifo(32'h12); rd_fifo(32'h56); rd_fifo(32'h78);     end_case("F2_reordered", 1);
    begin_case("F3_dropped_sample");  enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    rd_fifo(32'h12); rd_fifo(32'h56); rd_fifo(32'h78);                      end_case("F3_dropped_sample", 1);
    begin_case("F4_duplicated");      enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    rd_fifo(32'h12); rd_fifo(32'h12); rd_fifo(32'h34); rd_fifo(32'h56);     end_case("F4_duplicated", 1);
    begin_case("F5_extra_pop_phantom");enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    rd_fifo(32'h12); rd_fifo(32'h34); rd_fifo(32'h56); rd_fifo(32'h78); rd_fifo(32'h99); end_case("F5_extra_pop_phantom", 1);
    begin_case("F6_upper_bits");      enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    rd_fifo(32'h0000_0112); rd_fifo(32'h34); rd_fifo(32'h56); rd_fifo(32'h78); end_case("F6_upper_bits", 1);

    // K2 timeout known answers (Q-ENV-1): N=0 -> cycle 1, N=1 -> cycle 1, N=3 -> cycle 3
    begin_case("K2_timeout_exact");
    wr_csr(16'h000C, 0); rd_fifo_err(1);
    wr_csr(16'h000C, 1); rd_fifo_err(1);
    wr_csr(16'h000C, 3); rd_fifo_err(3);
    rd_csr(16'h000C, 3);
    end_case("K2_timeout_exact", 0);
    begin_case("F7a_timeout_late");   wr_csr(16'h000C, 3); rd_fifo_err(4);  end_case("F7a_timeout_late", 1);
    begin_case("F7b_timeout_early");  wr_csr(16'h000C, 3); rd_fifo_err(2);  end_case("F7b_timeout_early", 1);
    begin_case("F7c_timeout0_late");  wr_csr(16'h000C, 0); rd_fifo_err(2);  end_case("F7c_timeout0_late", 1);
    begin_case("F7d_error_with_data");enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78); wr_csr(16'h000C, 0); rd_fifo_err(1); end_case("F7d_error_with_data", 1);
    begin_case("K3_reset_default_timeout"); rd_csr(16'h000C, 32'hFFFF_FFFF); rd_csr(16'h0000, 32'h0001_0001); end_case("K3_reset_default_timeout", 0);
    begin_case("F8_version_wrong");   rd_csr(16'h0000, 32'h0001_0000);       end_case("F8_version_wrong", 1);

    // APB protocol checker
    begin_case("F9a_addr_changes_in_wait"); xfer(16'h0008, 0, 0, 0, 4, 0, 0, 1, 0); end_case("F9a_addr_changes_in_wait", 1);
    begin_case("F9b_pstrb_on_read");        xfer(16'h0008, 0, 0, 0, 2, 0, 0, 0, 4'h1); end_case("F9b_pstrb_on_read", 1);
    begin_case("K4_wait_states_clean");     xfer(16'h0008, 0, 0, 0, 5, 0, 0, 0, 0); end_case("K4_wait_states_clean", 0);

    // decode policy (REQ-IF-006, ERR-003, ERR-004)
    begin_case("K5_decode_errors");
    xfer(FA, 1, 32'h1, 4'hF, 1, 0, 1, 0, 0);              // FIFO_DATA write errors
    xfer(FA + 16'h4 - 16'h4 + 16'h2, 0, 0, 0, 1, 0, 1, 0, 0);   // misaligned FIFO word read errors
    xfer(16'h0006, 0, 0, 0, 2, 0, 1, 0, 0);               // unaligned CSR read errors
    xfer(16'h0008, 1, 32'h3, 4'h3, 2, 0, 1, 0, 0);        // partial-strobe CSR write errors
    xfer(16'h0040, 0, 0, 0, 2, 0, 0, 0, 0);               // aligned unmapped CSR read: zero, OKAY
    end_case("K5_decode_errors", 0);
    begin_case("F10a_fifo_write_ok");     xfer(FA, 1, 32'h1, 4'hF, 1, 0, 0, 0, 0); end_case("F10a_fifo_write_ok", 1);
    begin_case("F10b_unaligned_ok");      xfer(16'h0006, 0, 0, 0, 2, 0, 0, 0, 0);  end_case("F10b_unaligned_ok", 1);
    begin_case("F10c_partial_strb_ok");   xfer(16'h0008, 1, 32'h3, 4'h3, 2, 0, 0, 0, 0); end_case("F10c_partial_strb_ok", 1);
    begin_case("F10d_unmapped_nonzero");  xfer(16'h0040, 0, 0, 0, 2, 32'h5, 0, 0, 0); end_case("F10d_unmapped_nonzero", 1);

    // overflow (REQ-FUNC-003, ERR-001): depth 4, six pixels, no reads: oldest four retained, ovf sticky, W1C clears
    begin_case("F11c_status_value_wrong");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    for (int i = 0; i < 6; i++) pix(W'(8'h20 + i), 1);
    settle(400);
    rd_csr(16'h0010, 32'h0000_000F);                         // active, empty=0 (bit1=0) -> expect bits: active=1, empty=0, full=1, ovf=1 = 0b1101
    end_case("F11c_status_value_wrong", 1);     // the status value above is intentionally wrong (qualifies the status check)
    begin_case("K6b_overflow_known_answer");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    for (int i = 0; i < 6; i++) pix(W'(8'h20 + i), 1);
    settle(400);
    rd_csr(16'h0010, 32'h0000_000D);
    rd_fifo(32'h20); rd_fifo(32'h21); rd_fifo(32'h22); rd_fifo(32'h23);
    xfer(16'h0010, 1, 32'h8, 4'hF, 2, 0, 0, 0, 0); settle(400); rd_csr(16'h0010, 32'h0000_0003);
    end_case("K6b_overflow_known_answer", 0);
    begin_case("F11a_overwrite_oldest");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    for (int i = 0; i < 6; i++) pix(W'(8'h20 + i), 1);
    settle(400);
    rd_fifo(32'h22); rd_fifo(32'h23); rd_fifo(32'h24); rd_fifo(32'h25);
    end_case("F11a_overwrite_oldest", 1);
    begin_case("F11b_ovf_not_set");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    for (int i = 0; i < 6; i++) pix(W'(8'h20 + i), 1);
    settle(400);
    rd_csr(16'h0010, 32'h0000_0005);
    end_case("F11b_ovf_not_set", 1);

    // CDC-window tolerance (triage TR-C-001/002/003): behaviours the HDS allows inside the window must not be errors, outside they must be
    begin_case("K12_w1c_race_inside_window");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    for (int i = 0; i < 6; i++) pix(W'(8'h20 + i), 1);
    wr_csr(16'h0010, 32'h8); settle(400);                       // W1C lands within the window of the last drop: the late event may set ovf again
    rd_csr(16'h0010, 32'h0000_000D);
    end_case("K12_w1c_race_inside_window", 0);
    begin_case("F18_ovf_set_without_event_after_w1c");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    for (int i = 0; i < 6; i++) pix(W'(8'h20 + i), 1);
    settle(400); wr_csr(16'h0010, 32'h8); settle(400);          // the drops are older than the window: the clear is certain
    rd_csr(16'h0010, 32'h0000_000D);                            // ovf still set although no new event happened
    end_case("F18_ovf_set_without_event_after_w1c", 1);
    begin_case("K13_stale_full_drop_inside_window");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h10, 1); pix(8'h11, 1); pix(8'h12, 1); pix(8'h13, 1); settle(400);
    rd_fifo(32'h10);
    pix(8'h14, 1); pix(8'h15, 1);                               // sample 0x14 may be dropped by a lagging full flag; 0x15 is then accepted
    settle(400);
    rd_fifo(32'h11); rd_fifo(32'h12); rd_fifo(32'h13); rd_fifo(32'h15);
    end_case("K13_stale_full_drop_inside_window", 0);
    begin_case("F19_certain_entry_lost");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h10, 1); pix(8'h11, 1); pix(8'h12, 1); settle(400);   // all three are older than the window: none may disappear
    rd_fifo(32'h10); rd_fifo(32'h12);
    end_case("F19_certain_entry_lost", 1);

    // gated mode full FIFO (triage TR-C-004): a pop inside the write window may make room for the newest sample
    begin_case("K15_gated_pop_window_accept");
    wr_csr(16'h0004, 32'h2); settle(400); wr_csr(16'h0004, 32'h3); settle(400); vs_pulse(); settle(100);
    pix(8'h31, 1); settle(60); pix(8'h32, 1); settle(60); pix(8'h33, 1); settle(60); pix(8'h34, 1); settle(400);
    rd_fifo(32'h31);
    pix(8'h35, 1); settle(400);                                   // pushed right after a pop: the DUT may have accepted it
    rd_fifo(32'h32); rd_fifo(32'h33); rd_fifo(32'h34); rd_fifo(32'h35);
    end_case("K15_gated_pop_window_accept", 0);
    begin_case("F20_gated_full_without_pop_accepted");
    wr_csr(16'h0004, 32'h2); settle(400); wr_csr(16'h0004, 32'h3); settle(400); vs_pulse(); settle(100);
    pix(8'h31, 1); settle(60); pix(8'h32, 1); settle(60); pix(8'h33, 1); settle(60); pix(8'h34, 1); settle(400);
    pix(8'h35, 1); settle(400);                                   // no pop inside the window: this sample must be dropped
    rd_fifo(32'h31); rd_fifo(32'h32); rd_fifo(32'h33); rd_fifo(32'h34); rd_fifo(32'h35);
    end_case("F20_gated_full_without_pop_accepted", 1);

    // DMA request (REQ-IF-004): watermark 2
    begin_case("K14_wm_zero_rearms");
    wr_csr(16'h0008, 2); wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h01, 1); pix(8'h02, 1);
    dma_req = 1; settle(300);
    @(posedge clk_apb); dma_ack <= 1; @(posedge clk_apb); dma_ack <= 0; dma_req <= 0; settle(100);
    wr_csr(16'h0008, 0); settle(100); wr_csr(16'h0008, 2);       // zero watermark resets the re-arm state: the request may rise at once
    dma_req = 1; settle(100);
    end_case("K14_wm_zero_rearms", 0);
    begin_case("K7_dma_known_answer");
    wr_csr(16'h0008, 2); wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h01, 1); pix(8'h02, 1);
    dma_req = 1; settle(60);                                     // request raised inside the CDC window after the crossing
    @(posedge clk_apb); dma_ack <= 1; @(posedge clk_apb); dma_ack <= 0; dma_req <= 0; settle(100);
    rd_fifo(32'h01); settle(400);                                // occupancy 1 < 2: below seen
    pix(8'h03, 1);                                               // back to 2: re-crossing
    dma_req = 1; settle(60);
    end_case("K7_dma_known_answer", 0);
    begin_case("F12a_req_missing");
    wr_csr(16'h0008, 2); wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h01, 1); pix(8'h02, 1); settle(600);
    end_case("F12a_req_missing", 1);
    begin_case("F12b_req_drops_without_ack");
    wr_csr(16'h0008, 2); wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h01, 1); pix(8'h02, 1);
    dma_req = 1; settle(60); dma_req = 0; settle(100);
    end_case("F12b_req_drops_without_ack", 1);
    begin_case("F12c_rearm_without_crossing");
    wr_csr(16'h0008, 2); wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100);
    pix(8'h01, 1); pix(8'h02, 1);
    dma_req = 1; settle(300);                                    // both entries are now older than the CDC window: occupancy cannot be below the watermark
    @(posedge clk_apb); dma_ack <= 1; @(posedge clk_apb); dma_ack <= 0; dma_req <= 0; settle(100);
    dma_req = 1; settle(100);                                    // re-requests with occupancy never below the watermark
    end_case("F12c_rearm_without_crossing", 1);
    begin_case("F12d_zero_watermark_req");
    wr_csr(16'h0008, 0); dma_req = 1; settle(600);
    end_case("F12d_zero_watermark_req", 1);

    // reset cancels a pending read (REQ-RESET-001)
    begin_case("K8_reset_cancels_read");
    @(posedge clk_apb); psel <= 1; penable <= 0; paddr <= FA; pwrite <= 0; pstrb <= 0;
    @(posedge clk_apb); penable <= 1; pready <= 0;
    rst_n = 0; repeat (6) @(posedge clk_apb); #1 rst_n = 1; psel <= 0; penable <= 0; repeat (3) @(posedge clk_apb);
    end_case("K8_reset_cancels_read", 0);
    begin_case("F13_complete_during_reset");
    @(posedge clk_apb); psel <= 1; penable <= 0; paddr <= FA; pwrite <= 0; pstrb <= 0;
    @(posedge clk_apb); penable <= 1; pready <= 0;
    rst_n = 0; repeat (5) @(posedge clk_apb); pready <= 1; pslverr <= 1; repeat (2) @(posedge clk_apb);
    pready <= 0; pslverr <= 0; #1 rst_n = 1; psel <= 0; penable <= 0; repeat (3) @(posedge clk_apb);
    end_case("F13_complete_during_reset", 1);

    // frame counter (REQ-FUNC-009)
    begin_case("K9_frame_count");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100); vs_pulse(); settle(400);
    rd_csr(16'h0018, 2);
    end_case("K9_frame_count", 0);
    begin_case("F14a_frame_count_wrong");
    wr_csr(16'h0004, 32'h1); settle(400); vs_pulse(); settle(100); vs_pulse(); settle(400);
    rd_csr(16'h0018, 3);
    end_case("F14a_frame_count_wrong", 1);
    begin_case("K9b_disabled_vsync_not_counted");
    vs_pulse(); settle(400); rd_csr(16'h0018, 0);
    end_case("K9b_disabled_vsync_not_counted", 0);
    begin_case("F14b_disabled_vsync_counted");
    vs_pulse(); settle(400); rd_csr(16'h0018, 1);
    end_case("F14b_disabled_vsync_counted", 1);

    // mode guard (REQ-FUNC-004)
    begin_case("K10_mode_rejected_while_enabled");
    wr_csr(16'h0004, 32'h1); settle(400); wr_csr(16'h0004, 32'h3); settle(100); rd_csr(16'h0004, 32'h1);
    end_case("K10_mode_rejected_while_enabled", 0);
    begin_case("F15_mode_accepted_while_enabled");
    wr_csr(16'h0004, 32'h1); settle(400); wr_csr(16'h0004, 32'h3); settle(100); rd_csr(16'h0004, 32'h3);
    end_case("F15_mode_accepted_while_enabled", 1);
    begin_case("K10b_mode_accepted_when_safe");
    settle(400); wr_csr(16'h0004, 32'h2); settle(400); rd_csr(16'h0004, 32'h2);
    end_case("K10b_mode_accepted_when_safe", 0);

    // flush (REQ-FUNC-010)
    begin_case("K11_flush_clears_fifo");
    enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    wr_csr(16'h0004, 32'h0); settle(400); wr_csr(16'h0004, 32'h4); settle(400);
    rd_csr(16'h0004, 32'h0); rd_csr(16'h0014, 0); rd_csr(16'h0010, 32'h0000_0002);
    end_case("K11_flush_clears_fifo", 0);
    begin_case("F16_flush_keeps_data");
    enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    wr_csr(16'h0004, 32'h0); settle(400); wr_csr(16'h0004, 32'h4); settle(400);
    rd_csr(16'h0004, 32'h0); rd_csr(16'h0014, 4);
    end_case("F16_flush_keeps_data", 1);
    begin_case("F17_flush_pending_stuck");
    enable_and_frame(8'h12, 8'h34, 8'h56, 8'h78);
    wr_csr(16'h0004, 32'h0); settle(400); wr_csr(16'h0004, 32'h4); settle(400);
    rd_csr(16'h0014, 0); rd_fifo(32'h12);                        // a pop succeeds although the flush emptied the queue
    end_case("F17_flush_pending_stuck", 1);

    u_chk.report();
    $display("QUAL_RESULT cases=%0d ok=%0d bad=%0d checks=%0d", cases, ok, bad, u_chk.checks());
    $display("QUAL_VERDICT %s", (bad == 0) ? "ALL_CASES_AS_EXPECTED" : "UNEXPECTED_CASES");
    $finish;
  end
  initial begin #20000000; $display("QUAL_VERDICT TIMEOUT"); $finish; end
endmodule
