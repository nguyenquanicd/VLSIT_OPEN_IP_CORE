// tb_dvp_controller.sv - block harness for m_dvp_controller (verification/sim/v2). G1-approved architecture, G3 approved 2026-11-24.
// AI-generated candidate (R-117). One harness: clock/reset control, local APB requester and DVP source BFMs, passive
// checker (dv_dvp_checker) on the public pins. No internal DUT signal is read or forced (R-258).
// Test selection: +TEST=<name>, +SEED=<n>, +MODE=<0 continuous | 1 gated> (random test), +PCLK_NS=<period>.
// Every test keeps the passive checker enabled (R-241); tests add known-answer self checks (tb_expect) derived from the
// values the sensor BFM was told to send, which are independent of the checker model.
`timescale 1ns/1ps
module tb_dvp_controller;
  parameter int P_W = 8;
  parameter int P_EDGE = 0;
  parameter int P_VS = 1;
  parameter int P_HR = 1;
  parameter int P_DEPTH = 8;
  parameter logic [15:0] P_FADDR = 16'h0100;
  localparam real T_APB = 10.26;
  localparam real T_DVP = 13.71;

  logic clk_apb = 1'b0;
  logic rst_n = 1'b1;   // starts high so that the first assertion is a real falling edge (async-reset flops of a 2-state simulator are otherwise never initialised)
  always #(T_APB / 2.0) clk_apb = ~clk_apb;

  // DVP source
  logic              dvp_clk;
  logic [P_W-1:0]    dvp_data;
  logic              dvp_vsync, dvp_href;
  // APB
  logic [15:0] paddr; logic psel, penable, pwrite; logic [31:0] pwdata; logic [3:0] pstrb; logic [2:0] pprot;
  logic pready; logic [31:0] prdata; logic pslverr;
  // DMA
  logic dma_ack = 1'b0;
  logic dma_req;

  m_dvp_controller #(
    .PARA_DVP_DATA_W       (32'(P_W)),
    .PARA_DVP_SAMPLE_EDGE  (32'(P_EDGE)),
    .PARA_DVP_VSYNC_ACTIVE (32'(P_VS)),
    .PARA_DVP_HREF_ACTIVE  (32'(P_HR)),
    .PARA_FIFO_DEPTH       (32'(P_DEPTH)),
    .PARA_FIFO_DATA_ADDR   ({16'h0, P_FADDR})
  ) u_dut (
    .i_clk_apb (clk_apb), .i_rst_n_sys (rst_n), .i_clk_dvp (dvp_clk),
    .i_dvp_data (dvp_data), .i_dvp_vsync (dvp_vsync), .i_dvp_href (dvp_href),
    .i_paddr (paddr), .i_psel (psel), .i_penable (penable), .i_pwrite (pwrite), .i_pwdata (pwdata),
    .i_pstrb (pstrb), .i_pprot (pprot), .o_pready (pready), .o_prdata (prdata), .o_pslverr (pslverr),
    .i_dma_ack (dma_ack), .o_dma_req (dma_req)
  );

  dv_dvp_source #(.W(P_W), .EDGE(P_EDGE), .VS_ACT(P_VS), .HR_ACT(P_HR), .T_APB_NS(T_APB)) u_src (
    .o_clk (dvp_clk), .o_data (dvp_data), .o_vsync (dvp_vsync), .o_href (dvp_href)
  );

  dv_apb_requester u_apb (
    .i_clk (clk_apb), .i_rst_n (rst_n),
    .o_paddr (paddr), .o_psel (psel), .o_penable (penable), .o_pwrite (pwrite), .o_pwdata (pwdata),
    .o_pstrb (pstrb), .o_pprot (pprot), .i_pready (pready), .i_prdata (prdata), .i_pslverr (pslverr)
  );

  dv_dvp_checker #(
    .W (P_W), .EDGE (P_EDGE), .VS_ACT (P_VS), .HR_ACT (P_HR), .DEPTH (P_DEPTH), .FIFO_ADDR (P_FADDR),
    .T_APB_NS (T_APB), .T_DVP_NS (T_DVP)
  ) u_chk (
    .i_clk_apb (clk_apb), .i_rst_n (rst_n), .i_clk_dvp (dvp_clk), .i_data (dvp_data), .i_vsync (dvp_vsync), .i_href (dvp_href),
    .i_paddr (paddr), .i_psel (psel), .i_penable (penable), .i_pwrite (pwrite), .i_pwdata (pwdata), .i_pstrb (pstrb),
    .i_pprot (pprot), .i_pready (pready), .i_prdata (prdata), .i_pslverr (pslverr), .i_dma_req (dma_req), .i_dma_ack (dma_ack)
  );

  // ---------------------------------------------------------------- helpers
  string test_name = "envcheck";
  int    seed = 1;
  int    timeout_ns = 2000000;

  task automatic do_reset(input int cycles);
    rst_n = 1'b0;
    repeat (cycles) @(posedge clk_apb);
    #1 rst_n = 1'b1;
    repeat (8) @(posedge clk_apb);
  endtask

  task automatic csr_w(input logic [15:0] a, input logic [31:0] d);
    bit e; u_apb.write(a, d, e);
  endtask
  task automatic csr_r(input logic [15:0] a, output logic [31:0] d);
    bit e; int c; u_apb.read(a, d, e, c);
  endtask

  task automatic finish_test(input string name);
    repeat (6) @(posedge clk_apb);
    u_chk.drain_check();
    u_chk.report();
    $display("DV_TEST name=%s config=W%0d_E%0d_VS%0d_HR%0d_D%0d seed=%0d result=%s",
             name, P_W, P_EDGE, P_VS, P_HR, P_DEPTH, seed, (u_chk.errors() == 0 && u_chk.checks() > 0) ? "PASS" : "FAIL");
    $finish;
  endtask

  // watchdog (R-109: every test has a finite timeout)
  initial begin
    #(timeout_ns * 1.0);
    $display("DV_ERROR tb_watchdog t=%0t test %s exceeded its timeout", $time, test_name);
    $display("DV_TEST name=%s result=TIMEOUT", test_name);
    $finish;
  end

  // ---------------------------------------------------------------- helpers for the campaign
  localparam logic [15:0] A_VER = 16'h0000, A_CTRL = 16'h0004, A_WM = 16'h0008, A_TO = 16'h000C, A_STS = 16'h0010, A_LVL = 16'h0014, A_FC = 16'h0018;
  localparam int unsigned DMASK = (32'd1 << P_W) - 32'd1;
  localparam int TO_LIST [5] = '{0, 1, 2, 3, 7};
  int mode_arg = 0;
  real pclk_ns = T_DVP;
  int unsigned rng = 32'h1;

  function automatic int unsigned rnd(input int unsigned n);
    rng = rng ^ (rng << 13); rng = rng ^ (rng >> 17); rng = rng ^ (rng << 5);
    return (n == 0) ? 0 : (rng % n);
  endfunction
  function automatic logic [P_W-1:0] wv(input int v); return P_W'(v); endfunction

  task automatic idle(input int n); repeat (n) @(posedge clk_apb); endtask
  task automatic fifo_rd(output logic [31:0] d, output bit e, output int c);
    u_apb.read(P_FADDR, d, e, c);
  endtask
  // known-answer self check of the test itself (independent of the checker model), reported through the checker counters
  task automatic expect_eq(input string what, input longint got, input longint exp);
    u_chk.chk(got == exp, "tb_expect", $sformatf("%s: got %0d expected %0d", what, got, exp));
  endtask
  // mode first, then capture enable (HDS REQ-FUNC-004: the mode is accepted only while capture is disabled, so it cannot change in the same write)
  task automatic set_ctrl(input bit gated, input bit en);
    csr_w(A_CTRL, {29'h0, 1'b0, gated, 1'b0});
    idle(30);                                   // longer than the checker CDC window (16 APB + 8 PCLK cycles) so the model is certain
    if (en) csr_w(A_CTRL, {29'h0, 1'b0, gated, 1'b1});
    idle(32);
    begin logic [31:0] cr; csr_r(A_CTRL, cr); expect_eq("ctrl readback mode", cr[1], gated); expect_eq("ctrl readback capture_en", cr[0], en); end
  endtask
  // finite empty-read timeout so that a test never hangs on the reset value 0xFFFFFFFF (R-109)
  task automatic safe_to(); csr_w(A_TO, 32'd40); endtask
  task automatic sensor_clock(input bit run);
    if (run) u_src.start_clk(pclk_ns); else u_src.stop_clk();
  endtask
  // drain: lower the empty timeout and read until an empty read errors; returns the number of samples read
  task automatic drain(input int maxn, output int n);
    logic [31:0] d; bit e; int c;
    csr_w(A_TO, 3); n = 0;
    for (int i = 0; i < maxn; i++) begin
      fifo_rd(d, e, c);
      if (e) break;
      n++;
    end
  endtask
  // read lines*pix samples and compare each with the value the sensor BFM was told to send (known answer); skip the first samples
  task automatic read_expect(input int lines, input int pix, input int pat, input int sd, input int skip);
    logic [31:0] d; bit e; int c; int k;
    k = 0;
    for (int l = 0; l < lines; l++) for (int p = 0; p < pix; p++) begin
      if (k >= skip) begin
        fifo_rd(d, e, c);
        expect_eq($sformatf("sample l%0d p%0d error", l, p), e, 0);
        expect_eq($sformatf("sample l%0d p%0d", l, p), d, u_src.pixel(l, p, pat, sd + l) & DMASK);
      end
      k++;
    end
  endtask
  task automatic emit_frame(input bit gated, input int lines, input int pix, input int pat, input int sd, input int hb);
    u_src.frame(gated, lines, pix, pat, sd, hb);
  endtask
  // frame start without pixels: VSYNC pulse with the sensor idle
  task automatic vsync_only(input bit gated);
    if (gated) begin u_src.set_vsync(1); #(T_APB * 8); u_src.set_vsync(0); #(T_APB * 8); end
    else begin repeat (4) u_src.cont_cycle('0, 0, 1); repeat (6) u_src.cont_cycle('0, 0, 0); end
  endtask
  task automatic one_pixel(input bit gated, input logic [P_W-1:0] v);
    if (gated) u_src.gated_pixel(v); else u_src.cont_cycle(v, 1, 0);
  endtask
  // DMA responder: acknowledges every request after dma_lat APB cycles with a one-cycle pulse when dma_auto is set
  bit dma_auto = 0;
  int dma_lat = 3;
  initial forever begin
    @(posedge dma_req);
    if (dma_auto) begin
      repeat (dma_lat) @(posedge clk_apb);
      dma_ack <= 1'b1; @(posedge clk_apb); dma_ack <= 1'b0;
    end
  end
  task automatic dma_ack_pulse();
    @(posedge clk_apb); dma_ack <= 1'b1; @(posedge clk_apb); dma_ack <= 1'b0;
  endtask

  // ---------------------------------------------------------------- tests
  // t_dvp_continuous_e2e: qualified continuous-PCLK samples cross the AFIFO, raise the watermark request, are read once in order.
  task automatic t_continuous_e2e();
    int n; logic [31:0] r; bit e; int c; logic [31:0] d;
    sensor_clock(1); dma_auto = 1;
    safe_to(); csr_w(A_WM, 3); set_ctrl(0, 1);
    emit_frame(0, 2, 4, 0, 11, 2); idle(80);
    csr_r(A_LVL, r); expect_eq("level after 8 samples", r, 8);
    csr_r(A_STS, r);
    read_expect(2, 4, 0, 11, 0);
    csr_r(A_LVL, r); expect_eq("level after drain", r, 0);
    csr_w(A_TO, 6); fifo_rd(d, e, c); expect_eq("empty read error", e, 1); expect_eq("empty read cycles", c, 6);
    csr_w(A_TO, 4);
    fork
      emit_frame(0, 3, 5, 3, 21, 1);
      begin
        int got; logic [31:0] dd; bit ee; int cc;
        got = 0;
        for (int i = 0; i < 60 && got < 15; i++) begin
          csr_r(A_LVL, dd);
          if (dd != 0) begin fifo_rd(dd, ee, cc); if (!ee) got++; end else idle(2);
        end
      end
    join
    drain(16, n);
    csr_r(A_FC, r); expect_eq("frame count", r, 2);
    dma_auto = 0;
  endtask

  // t_dvp_gated_e2e: multi-cycle VSYNC arms the frame, then stopped/gated PCLK pixels cross by toggle into the APB SFIFO.
  task automatic t_gated_e2e();
    int n; logic [31:0] r; bit e; int c; logic [31:0] d;
    sensor_clock(0); dma_auto = 1;
    safe_to(); csr_w(A_WM, 4); set_ctrl(1, 1);
    emit_frame(1, 2, 4, 0, 31, 1); idle(40);
    csr_r(A_LVL, r); expect_eq("gated level after 8 samples", r, 8);
    read_expect(2, 4, 0, 31, 0);
    csr_w(A_TO, 5); fifo_rd(d, e, c); expect_eq("empty read error", e, 1); expect_eq("empty read cycles", c, 5);
    fork
      emit_frame(1, 2, 3, 4, 41, 2);
      begin
        int got; logic [31:0] dd; bit ee; int cc;
        got = 0;
        for (int i = 0; i < 400 && got < 6; i++) begin
          csr_r(A_LVL, dd);
          if (dd != 0) begin fifo_rd(dd, ee, cc); if (!ee) got++; end
        end
      end
    join
    drain(8, n);
    csr_r(A_FC, r); expect_eq("gated frame count", r, 2);
    dma_auto = 0;
  endtask

  // t_dvp_apb_protocol: CSR and FIFO_DATA traffic observed by the passive APB4 checker.
  task automatic t_apb_protocol();
    logic [31:0] r; bit e; int c; logic [31:0] d; bit ab;
    // reset values of every register, read before any write (HDS section 11)
    csr_r(A_VER, r);  expect_eq("reset value version", r, 32'h0001_0001);
    csr_r(A_CTRL, r); expect_eq("reset value ctrl", r, 0);
    csr_r(A_WM, r);   expect_eq("reset value watermark", r, 0);
    csr_r(A_TO, r);   expect_eq("reset value timeout", r, 32'hFFFF_FFFF);
    csr_r(A_STS, r);  expect_eq("reset value status (empty only)", r, 2);
    csr_r(A_LVL, r);  expect_eq("reset value level", r, 0);
    csr_r(A_FC, r);   expect_eq("reset value frame count", r, 0);
    for (int a = 0; a <= 6; a++) csr_r(16'(a * 4), r);
    csr_w(A_WM, 32'h0000_0005); csr_r(A_WM, r); expect_eq("wmark readback", r, 5);
    csr_w(A_WM, 32'hFFFF_FFFF); csr_r(A_WM, r);
    csr_w(A_WM, 0); csr_r(A_WM, r);
    csr_w(A_TO, 32'h1); csr_r(A_TO, r); expect_eq("timeout readback", r, 1);
    csr_w(A_TO, 32'h0000_0000); csr_r(A_TO, r);
    csr_w(A_TO, 32'hFFFF_FFFF); csr_r(A_TO, r); expect_eq("timeout write FFFFFFFF readback", r, 32'hFFFF_FFFF);
    csr_w(A_VER, 32'hFFFF_FFFF); csr_r(A_VER, r); expect_eq("version read-only", r, 32'h0001_0001);
    csr_w(A_CTRL, 32'hFFFF_FFF8); csr_r(A_CTRL, r);
    csr_w(A_FC, 32'hFFFF_FFFF); csr_r(A_FC, r); expect_eq("frame count read-only", r, 0);
    csr_w(A_STS, 32'h0000_0008); csr_r(A_STS, r); expect_eq("status reset value", r, 2);
    csr_w(A_LVL, 32'h1); csr_r(A_LVL, r);
    for (int a = 7; a < 12; a++) csr_r(16'(a * 4), r);
    csr_r(16'h0FFC, r); csr_r(16'hFFFC, r); csr_w(16'h0040, 32'h1234);
    u_apb.write_strb(A_WM, 32'h3, 4'h3, e);
    u_apb.write_strb(A_WM, 32'h3, 4'h0, e);
    u_apb.xfer(16'h0006, 1'b0, 32'h0, 4'h0, d, e, c, ab, 0);
    u_apb.xfer(16'h0006, 1'b1, 32'h1, 4'hF, d, e, c, ab, 0);
    csr_w(A_TO, 2); fifo_rd(d, e, c); expect_eq("empty read errors", e, 1);
    for (int i = 0; i < 6; i++) begin csr_r(A_STS, r); csr_r(A_LVL, r); end
  endtask

  // t_dvp_timeout_boundary: sample-arrival race around the terminal empty-read decision, zero and positive timeouts.
  task automatic t_timeout_boundary(input bit gated);
    logic [31:0] d; bit e; int c; int n; logic [31:0] r;
    sensor_clock(!gated);
    foreach (TO_LIST[i]) begin
      csr_w(A_TO, TO_LIST[i]);
      fifo_rd(d, e, c);
      expect_eq($sformatf("timeout %0d error", TO_LIST[i]), e, 1);
      expect_eq($sformatf("timeout %0d cycles", TO_LIST[i]), c, (TO_LIST[i] <= 1) ? 1 : TO_LIST[i]);
    end
    csr_w(A_WM, 0); set_ctrl(gated, 1);
    vsync_only(gated);
    if (gated) u_src.set_href(1);
    for (int off = 0; off < 24; off++) begin
      csr_w(A_TO, 8);
      fork
        begin fifo_rd(d, e, c); end
        begin
          #(T_APB * off);
          one_pixel(gated, wv(8'hA0 + off));
          if (!gated) u_src.cont_cycle('0, 0, 0);          // HREF must drop after exactly one sample
        end
      join
      $display("DV_TB race off=%0d err=%0d cycles=%0d data=0x%0h", off, e, c, d);
      if (!e) expect_eq("race read data", d, (32'hA0 + off) & DMASK);
      idle(40);
      drain(4, n);
    end
    set_ctrl(gated, 0);
  endtask

  // t_dvp_endpoint_errors: write, misaligned and unmapped accesses must neither change the FIFO nor consume a sample.
  task automatic t_endpoint_errors(input bit gated);
    logic [31:0] d, r; bit e; int c;
    sensor_clock(!gated); safe_to(); csr_w(A_WM, 0); set_ctrl(gated, 1);
    emit_frame(gated, 1, 3, 0, 51, 1); idle(80);
    csr_r(A_LVL, r); expect_eq("level before error accesses", r, 3);
    u_apb.write(P_FADDR, 32'hDEAD_BEEF, e); expect_eq("FIFO_DATA write error", e, 1);
    u_apb.write_strb(P_FADDR, 32'h1, 4'h1, e); expect_eq("FIFO_DATA strobed write error", e, 1);
    for (int o = 1; o < 4; o++) begin u_apb.read(P_FADDR + 16'(o), d, e, c); expect_eq($sformatf("misaligned FIFO read +%0d error", o), e, 1); end
    u_apb.read(P_FADDR + 16'h4, d, e, c); expect_eq("aligned unmapped read OKAY", e, 0); expect_eq("aligned unmapped read zero", d, 0);
    u_apb.read(P_FADDR - 16'h4, d, e, c); expect_eq("aligned unmapped read below OKAY", e, 0);
    csr_r(A_LVL, r); expect_eq("level after error accesses", r, 3);
    read_expect(1, 3, 0, 51, 0);
    csr_r(A_LVL, r); expect_eq("level after legal reads", r, 0);
    set_ctrl(gated, 0);
  endtask

  // t_dvp_overflow: fill beyond depth, newest dropped, W1C race set-dominant
  task automatic t_overflow_mode(input bit gated);
    logic [31:0] r; int n;
    sensor_clock(!gated); safe_to(); csr_w(A_WM, 0); set_ctrl(gated, 1);
    emit_frame(gated, (P_DEPTH + 7) / 4, 4, 0, 61, 1); idle(100);          // at least DEPTH+4 samples
    csr_r(A_STS, r); expect_eq("status after overflow (active,full,ovf)", r & 32'hE, 32'hC);
    csr_r(A_LVL, r); expect_eq("level at full", r, P_DEPTH);
    csr_w(A_STS, 32'h8); idle(24); csr_r(A_STS, r);
    for (int off = 0; off < 6; off++) begin
      fork
        begin idle(off); csr_w(A_STS, 32'h8); end
        begin
          if (gated) begin u_src.set_href(1); u_src.gated_pixel(wv(8'h70 + off)); u_src.set_href(0); end
          else begin u_src.cont_cycle(wv(8'h70 + off), 1, 0); u_src.cont_cycle('0, 0, 0); end
        end
      join
      idle(60); csr_r(A_STS, r);
    end
    drain(P_DEPTH + 4, n); expect_eq("retained samples drained", n, P_DEPTH);
    csr_w(A_STS, 32'h8); idle(24); csr_r(A_STS, r);
    set_ctrl(gated, 0);
  endtask

  // t_dvp_flush_handshake: handshake, blocked reads while pending, frame count and overflow retained
  task automatic t_flush_mode(input bit gated);
    logic [31:0] r, d; bit e; int c; int polls;
    sensor_clock(!gated); csr_w(A_WM, 0); set_ctrl(gated, 1);
    emit_frame(gated, (P_DEPTH + 7) / 4, 4, 0, 71, 1); idle(100);
    csr_w(A_CTRL, {29'h0, 1'b1, gated, 1'b1}); idle(24);
    csr_r(A_CTRL, r);
    set_ctrl(gated, 0);
    csr_w(A_CTRL, {29'h0, 1'b1, gated, 1'b0});
    csr_w(A_TO, 0);
    fifo_rd(d, e, c);
    csr_r(A_LVL, r);
    polls = 0; r = 32'h4;
    while (r[2] && polls < 200) begin csr_r(A_CTRL, r); polls++; end
    expect_eq("flush completed", r[2], 0);
    csr_r(A_LVL, r); expect_eq("level after flush", r, 0);
    csr_r(A_STS, r); expect_eq("empty and ovf retained", r & 32'hA, 32'hA);
    csr_r(A_FC, r); expect_eq("frame count retained", r, 1);
    csr_w(A_STS, 32'h8); idle(24); csr_r(A_STS, r);
    fifo_rd(d, e, c); expect_eq("read after flush is an empty-read error", e, 1);
    // continuous mode: capture disabled and a flush requested while samples are still in flight; the flush must wait for the source path
    if (!gated) begin
      for (int g = 0; g < 12; g++) begin
        set_ctrl(0, 1); vsync_only(0);
        fork
          begin repeat (60) u_src.cont_cycle(wv(8'hC0 + g), 1, 0); u_src.cont_cycle('0, 0, 0); end
          begin idle(10 + g); csr_w(A_CTRL, 32'h0); csr_w(A_CTRL, 32'h4); end
        join
        polls = 0; r = 32'h4;
        while (r[2] && polls < 200) begin csr_r(A_CTRL, r); polls++; end
        expect_eq("flush with samples in flight completed", r[2], 0);
        idle(120);
        csr_r(A_LVL, r); expect_eq("no stale sample after a flush with samples in flight", r, 0);
      end
    end
  endtask

  // t_dvp_flush_race: a CTRL write issued while a flush is pending (ignored by ERR-007) at every offset around the hardware done pulse
  task automatic t_flush_race(input bit gated);
    logic [31:0] r; int polls;
    for (int k = 0; k < 40; k++) begin
      do_reset(6);
      sensor_clock(!gated); csr_w(A_WM, 0); set_ctrl(gated, 1);
      emit_frame(gated, 2, 4, 0, 90, 1); idle(60);
      csr_w(A_CTRL, {29'h0, 1'b0, gated, 1'b0}); idle(40);
      csr_w(A_CTRL, {29'h0, 1'b1, gated, 1'b0});
      idle(k); csr_w(A_CTRL, {29'h0, 1'b0, gated, 1'b0});
      polls = 0; r = 32'h4;
      while (r[2] && polls < 200) begin csr_r(A_CTRL, r); polls++; end
      expect_eq($sformatf("flush clears (gated=%0d, CTRL write %0d cycles after the request)", gated, k), r[2], 0);
    end
  endtask

  // t_dvp_dma_rearm (watermark 0 / above-depth re-arm step: decision Q-DMA-1)
  bit dma_wm_change = 1;   // decision Q-DMA-1: the watermark 0 / above-depth re-arm step is part of the default test
  task automatic t_dma_mode(input bit gated);
    logic [31:0] d, r; bit e; int c; int n;
    sensor_clock(!gated); dma_auto = 0; csr_w(A_TO, 4);
    csr_w(A_WM, 4); set_ctrl(gated, 1);
    vsync_only(gated);
    if (gated) u_src.set_href(1);
    for (int i = 0; i < 4; i++) one_pixel(gated, wv(8'h10 + i));
    if (!gated) u_src.cont_cycle('0, 0, 0);
    idle(60); expect_eq("request at watermark", dma_req, 1);
    idle(20); expect_eq("request holds without ack", dma_req, 1);
    dma_ack_pulse(); idle(4); expect_eq("request drops after ack", dma_req, 0);
    for (int i = 4; i < 6; i++) one_pixel(gated, wv(8'h10 + i));
    if (!gated) u_src.cont_cycle('0, 0, 0);
    idle(60); expect_eq("no re-request while still above", dma_req, 0);
    fifo_rd(d, e, c); fifo_rd(d, e, c); fifo_rd(d, e, c); idle(60);
    expect_eq("no request below watermark", dma_req, 0);
    for (int i = 6; i < 8; i++) one_pixel(gated, wv(8'h10 + i));
    if (!gated) u_src.cont_cycle('0, 0, 0);
    idle(60); expect_eq("re-armed request after re-crossing", dma_req, 1);
    dma_ack_pulse(); idle(8);
    $display("DV_TB step zero watermark (t=%0t)", $time);
    csr_w(A_WM, 0); idle(40); expect_eq("zero watermark keeps request low", dma_req, 0);
    if (!dma_wm_change) begin drain(16, n); set_ctrl(gated, 0); return; end
    $display("DV_TB step watermark changes while occupancy is above (t=%0t)", $time);
    csr_w(A_WM, 3); idle(60); csr_w(A_WM, 9); idle(60);
    csr_w(A_WM, 1); idle(60);
    drain(16, n);
    set_ctrl(gated, 0);
  endtask

  // t_dvp_frame_counter
  task automatic t_frame_counter_mode(input bit gated);
    logic [31:0] r; int n;
    sensor_clock(!gated); safe_to(); csr_w(A_WM, 0);
    vsync_only(gated);
    idle(40); csr_r(A_FC, r); expect_eq("frame count while disabled", r, 0);
    set_ctrl(gated, 1);
    for (int f = 1; f <= 3; f++) begin
      emit_frame(gated, 1, 2, 0, 80 + f, 1); idle(60);
      csr_r(A_FC, r); expect_eq($sformatf("frame count after frame %0d", f), r, f);
    end
    drain(8, n);
    csr_r(A_FC, r); expect_eq("frame count independent of draining", r, 3);
    set_ctrl(gated, 0);
    vsync_only(gated);
    idle(40); csr_r(A_FC, r); expect_eq("disabled vsync not counted", r, 3);
    csr_w(A_CTRL, {29'h0, 1'b1, gated, 1'b0}); idle(60);
    csr_r(A_FC, r); expect_eq("frame count retained across flush", r, 3);
    csr_r(A_CTRL, r);                                      // observe the completed flush handshake (flush bit clear)
    // frame qualifier: capture enabled in the middle of an active VSYNC must not start a frame (the next active edge does)
    csr_w(A_CTRL, {29'h0, 1'b0, gated, 1'b0}); idle(8);
    fork
      begin
        if (gated) begin u_src.set_vsync(1); #(T_APB * 140); u_src.set_vsync(0); #(T_APB * 8); end
        else begin repeat (100) u_src.cont_cycle('0, 0, 1); repeat (6) u_src.cont_cycle('0, 0, 0); end
      end
      begin idle(20); csr_w(A_CTRL, {29'h0, 1'b0, gated, 1'b1}); end
    join
    idle(40);
    for (int p = 0; p < 3; p++) begin
      if (gated) begin u_src.set_href(1); u_src.gated_pixel(wv(8'h40 + p)); u_src.set_href(0); end
      else u_src.cont_cycle(wv(8'h40 + p), 1, 0);
    end
    if (!gated) u_src.cont_cycle('0, 0, 0);
    idle(60);
    csr_r(A_LVL, r); expect_eq("no frame starts when capture is enabled inside an active VSYNC", r, 0);
    csr_r(A_FC, r); expect_eq("frame count unchanged by the missed VSYNC", r, 3);
    // a normal frame is captured, then capture is disabled and enabled again without a new VSYNC: nothing is captured
    emit_frame(gated, 1, 2, 0, 95, 1); idle(60);
    csr_r(A_FC, r); expect_eq("frame count after the next VSYNC", r, 4);
    drain(8, n);
    set_ctrl(gated, 0);
    set_ctrl(gated, 1);
    for (int p = 0; p < 3; p++) begin
      if (gated) begin u_src.set_href(1); u_src.gated_pixel(wv(8'h50 + p)); u_src.set_href(0); end
      else u_src.cont_cycle(wv(8'h50 + p), 1, 0);
    end
    if (!gated) u_src.cont_cycle('0, 0, 0);
    idle(60);
    csr_r(A_LVL, r); expect_eq("no capture after re-enable without a new VSYNC", r, 0);
    csr_r(A_FC, r); expect_eq("frame count unchanged without a new VSYNC", r, 4);
  endtask

  // t_dvp_mode_guard
  task automatic t_mode_guard();
    logic [31:0] r;
    sensor_clock(1); safe_to();
    set_ctrl(0, 1);
    csr_w(A_CTRL, 32'h3); idle(24); csr_r(A_CTRL, r); expect_eq("mode unchanged while enabled", r[1], 0);
    // mode change that also disables capture in the same write, capture enabled when the write is issued: the mode must not change
    csr_w(A_CTRL, 32'h2); idle(24); csr_r(A_CTRL, r);
    expect_eq("mode unchanged by a write that also disables capture", r[1], 0); expect_eq("capture disabled by that write", r[0], 0);
    set_ctrl(0, 1);
    csr_w(A_CTRL, 32'h1); csr_w(A_CTRL, 32'h2); idle(24); csr_r(A_CTRL, r);          // capture enabled one write earlier, before the sensor path reacts
    expect_eq("mode unchanged right after capture was enabled", r[1], 0);
    set_ctrl(0, 1);
    emit_frame(0, 1, 3, 0, 91, 1); idle(80);
    set_ctrl(0, 0);
    csr_w(A_CTRL, 32'h2); idle(24); csr_r(A_CTRL, r); expect_eq("mode unchanged with queued data", r[1], 0);
    read_expect(1, 3, 0, 91, 0); idle(60);
    sensor_clock(0); idle(4);                              // the gated profile has no free-running PCLK
    csr_w(A_CTRL, 32'h2); idle(24); csr_r(A_CTRL, r); expect_eq("mode accepted when safe", r[1], 1);
    set_ctrl(1, 1);
    csr_w(A_CTRL, 32'h1); idle(24); csr_r(A_CTRL, r); expect_eq("mode unchanged back to continuous while enabled", r[1], 1);
    set_ctrl(1, 1);
    csr_w(A_CTRL, 32'h0); idle(24); csr_r(A_CTRL, r);                                  // gated: mode back plus capture off in one write while enabled
    expect_eq("gated mode unchanged by a write that also disables capture", r[1], 1); expect_eq("gated capture disabled by that write", r[0], 0);
    set_ctrl(1, 1);
    emit_frame(1, 1, 3, 0, 92, 1); idle(40);
    set_ctrl(1, 0);
    csr_w(A_CTRL, 32'h0); idle(24); csr_r(A_CTRL, r); expect_eq("gated mode unchanged with queued data", r[1], 1);
    read_expect(1, 3, 0, 92, 0); idle(40);
    csr_w(A_CTRL, 32'h0); idle(40); csr_r(A_CTRL, r); expect_eq("mode back to continuous when safe", r[1], 0);
    sensor_clock(1); idle(10);
    set_ctrl(0, 1);
    emit_frame(0, 1, 2, 0, 93, 1); idle(60);
    read_expect(1, 2, 0, 93, 0);
  endtask

  // t_dvp_reset_recovery
  task automatic t_reset_recovery(input bit gated);
    logic [31:0] r, d; bit e; int c; bit ab;
    sensor_clock(!gated); csr_w(A_WM, 0); set_ctrl(gated, 1);
    vsync_only(gated);
    if (gated) u_src.set_href(1);
    csr_w(A_TO, 32'hFFFF_FFFF);
    fork
      begin u_apb.read_in_reset(P_FADDR, 3, ab); expect_eq("pending read aborted", ab, 1); end
      begin
        idle(10);
        rst_n = 1'b0; idle(2);
        one_pixel(gated, wv(8'h5A));                         // sensor activity while reset is asserted: must not be replayed afterwards
        if (!gated) u_src.cont_cycle('0, 0, 0);
        idle(2); sensor_clock(0); #1 rst_n = 1'b1; idle(12);
      end
    join
    idle(20);
    for (int a = 0; a <= 6; a++) csr_r(16'(a * 4), r);
    csr_r(A_LVL, r); expect_eq("level after reset", r, 0);
    sensor_clock(!gated); idle(5);
    set_ctrl(gated, 1);
    emit_frame(gated, 1, 3, 0, 101, 1); idle(80);
    csr_r(A_LVL, r); expect_eq("only post-reset samples", r, 3);
    read_expect(1, 3, 0, 101, 0);
    sensor_clock(0); rst_n = 1'b0; idle(6); #1 rst_n = 1'b1; idle(30);
    csr_w(A_TO, 3); fifo_rd(d, e, c); expect_eq("empty read after reset", e, 1);
  endtask

  // t_dvp_performance_characterization: seeded legal traffic with random producer bursts and consumer stalls
  // the source records every sample it drives (u_src.sent_q); overflow can only drop the newest samples, so the values read must be an
  // in-order subsequence of that list
  int perf_j = 0;
  task automatic perf_check(input logic [31:0] v);
    bit found; found = 0;
    for (int k = perf_j; k < u_src.sent_q.size(); k++) if (32'(u_src.sent_q[k]) == v) begin found = 1; perf_j = k + 1; break; end
    expect_eq("random test: a value read is the next expected sample in order", found, 1);
  endtask
  task automatic t_perf_random(input bit gated);
    logic [31:0] r, d; bit e; int c; int n; int unsigned lines, pix, hb, pat; int sd; int rd_ok;
    u_src.sent_q.delete(); perf_j = 0; rd_ok = 0;
    pclk_ns = 8.0 + 1.0 * rnd(25);
    sensor_clock(!gated); csr_w(A_WM, 1 + rnd(P_DEPTH)); dma_auto = 1; dma_lat = 1 + rnd(8);
    set_ctrl(gated, 1);
    csr_w(A_TO, 2 + rnd(6));
    for (int f = 0; f < 4; f++) begin
      lines = 1 + rnd(3); pix = 1 + rnd(6); hb = rnd(4); pat = rnd(6); sd = 1000 + rnd(50);
      fork
        emit_frame(gated, lines, pix, pat, sd, hb);
        begin
          int idle_n; logic [31:0] dd; bit ee; int cc; logic [31:0] rr;
          for (int i = 0; i < 40; i++) begin
            idle_n = rnd(20); idle(idle_n);
            csr_r(A_LVL, rr);
            if (rr != 0) begin fifo_rd(dd, ee, cc); if (!ee) begin perf_check(dd); rd_ok++; end end
            if (rnd(8) == 0) csr_r(A_STS, rr);
          end
        end
      join
      idle(60);
      if (rnd(3) == 0) csr_w(A_STS, 32'h8);
    end
    csr_w(A_TO, 3);
    for (int i = 0; i < 80; i++) begin fifo_rd(d, e, c); if (e) break; perf_check(d); rd_ok++; end
    csr_r(A_FC, r); expect_eq("random test: one frame count per frame", r, 4);
    csr_r(A_LVL, r); expect_eq("random test: empty at the end", r, 0);
    expect_eq("random test: samples were read", rd_ok > 0, 1);
    dma_auto = 0;
  endtask

  // t_dvp_profiles: width / edge / polarity of the elaborated build; both modes, qualifier-inactive samples carry data too
  task automatic t_profiles();
    logic [31:0] r; int n; bit gated;
    for (int m = 0; m < 2; m++) begin
      gated = m[0];
      sensor_clock(!gated); safe_to(); csr_w(A_WM, 0);
      set_ctrl(gated, 1);
      for (int pt = 2; pt <= 4; pt++) begin
        emit_frame(gated, 1, 4, pt, 111 + pt, 1); idle(60);
        csr_r(A_LVL, r); expect_eq($sformatf("profile level mode %0d pattern %0d", m, pt), r, 4);
        read_expect(1, 4, pt, 111 + pt, 0);
      end
      if (!gated) begin
        repeat (4) u_src.cont_cycle('0, 0, 1); repeat (6) u_src.cont_cycle('0, 0, 0);
        for (int i = 0; i < 6; i++) u_src.cont_cycle(wv(8'h3C + i), 0, 0);
        u_src.cont_cycle(wv(8'h55), 1, 0); u_src.cont_cycle(wv(8'h66), 0, 0); u_src.cont_cycle(wv(8'h77), 1, 0); u_src.cont_cycle('0, 0, 0);
        idle(60); csr_r(A_LVL, r); expect_eq("only HREF-qualified samples", r, 2);
      end
      drain(8, n);
      // pixels that arrive while VSYNC is still active: the frame is armed by the active edge of VSYNC, not by the end of the pulse;
      // capture is switched off and on first so that no frame is armed by the earlier frames of this test
      set_ctrl(gated, 0); set_ctrl(gated, 1);
      begin
        logic [31:0] dv; bit ev; int cv;
        if (!gated) begin
          repeat (3) u_src.cont_cycle('0, 0, 1);
          for (int i = 0; i < 4; i++) u_src.cont_cycle(wv(8'h21 + i), 1, 1);
          repeat (3) u_src.cont_cycle('0, 0, 1);
          repeat (6) u_src.cont_cycle('0, 0, 0);
        end else begin
          u_src.set_vsync(1); #(T_APB * 14); u_src.set_href(1);
          for (int i = 0; i < 4; i++) u_src.gated_pixel(wv(8'h21 + i));
          u_src.set_href(0); u_src.set_vsync(0); #(T_APB * 8);
        end
        idle(60); csr_r(A_LVL, r); expect_eq($sformatf("pixels inside an active VSYNC pulse are captured (mode %0d)", m), r, 4);
        for (int i = 0; i < 4; i++) begin
          fifo_rd(dv, ev, cv); expect_eq($sformatf("VSYNC-window sample %0d error", i), ev, 0);
          expect_eq($sformatf("VSYNC-window sample %0d", i), dv, (32'h21 + i) & DMASK);
        end
      end
      drain(8, n);
      set_ctrl(gated, 0);
    end
  endtask

  // ---------------------------------------------------------------- test dispatcher
  logic [31:0] rr0;
  initial begin
    if ($value$plusargs("TEST=%s", test_name)) ;
    if ($value$plusargs("SEED=%d", seed)) ;
    if ($value$plusargs("TIMEOUT_NS=%d", timeout_ns)) ;
    if ($value$plusargs("MODE=%d", mode_arg)) ;
    if ($test$plusargs("DMA_NO_WM_CHANGE")) dma_wm_change = 0;
    if ($value$plusargs("PCLK_NS=%f", pclk_ns)) ;
    rng = 32'h9E37_79B9 ^ (32'(seed) * 32'd2654435761);
    if (rng == 0) rng = 32'h1;
    #3;
    do_reset(10);
    case (test_name)
      "envcheck": begin
        for (int a = 0; a <= 6; a++) csr_r(16'(a * 4), rr0);
        csr_r(16'h001C, rr0);
        finish_test("envcheck");
      end
      "t_dvp_continuous_e2e":    begin t_continuous_e2e(); finish_test(test_name); end
      "t_dvp_gated_e2e":         begin t_gated_e2e(); finish_test(test_name); end
      "t_dvp_apb_protocol":      begin t_apb_protocol(); finish_test(test_name); end
      "t_dvp_timeout_boundary":  begin t_timeout_boundary(0); do_reset(6); t_timeout_boundary(1); finish_test(test_name); end
      "t_dvp_endpoint_errors":   begin t_endpoint_errors(0); do_reset(6); t_endpoint_errors(1); finish_test(test_name); end
      "t_dvp_overflow":          begin t_overflow_mode(0); do_reset(6); t_overflow_mode(1); finish_test(test_name); end
      "t_dvp_flush_race":        begin t_flush_race(0); t_flush_race(1); finish_test(test_name); end
      "t_dvp_flush_handshake":   begin t_flush_mode(0); do_reset(6); t_flush_mode(1); finish_test(test_name); end
      "t_dvp_dma_rearm":         begin t_dma_mode(0); do_reset(6); t_dma_mode(1); finish_test(test_name); end
      "t_dvp_frame_counter":     begin t_frame_counter_mode(0); do_reset(6); t_frame_counter_mode(1); finish_test(test_name); end
      "t_dvp_mode_guard":        begin t_mode_guard(); finish_test(test_name); end
      "t_dvp_reset_recovery":    begin t_reset_recovery(0); do_reset(6); t_reset_recovery(1); finish_test(test_name); end
      "t_dvp_performance_characterization": begin t_perf_random(mode_arg[0]); finish_test(test_name); end
      "t_dvp_profiles":          begin t_profiles(); finish_test(test_name); end
      "diag_mode_after_reset": begin
        // diagnostic only (not a campaign test): is the mode write accepted after reset with a stopped / running PCLK?
        logic [31:0] cr;
        csr_w(A_TO, 40);
        csr_w(A_CTRL, 32'h2); idle(30); csr_r(A_CTRL, cr); $display("DV_TB diag A no-pclk ctrl=0x%0h", cr);
        csr_w(A_CTRL, 32'h0); idle(30);
        sensor_clock(1); idle(40);
        csr_w(A_CTRL, 32'h2); idle(30); csr_r(A_CTRL, cr); $display("DV_TB diag B pclk-running ctrl=0x%0h", cr);
        csr_w(A_CTRL, 32'h0); idle(30);
        sensor_clock(0); idle(40);
        csr_w(A_CTRL, 32'h2); idle(30); csr_r(A_CTRL, cr); $display("DV_TB diag C pclk-stopped-again ctrl=0x%0h", cr);
        finish_test(test_name);
      end
      default: begin
        $display("DV_ERROR tb_dvp_controller unknown test %s", test_name);
        $display("DV_TEST name=%s result=NOT_IMPLEMENTED", test_name);
        $finish;
      end
    endcase
  end
endmodule
