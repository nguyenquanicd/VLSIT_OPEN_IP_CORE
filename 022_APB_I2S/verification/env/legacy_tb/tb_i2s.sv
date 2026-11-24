`timescale 1ns/1ps
// Testbench of m_vlsit_apb_i2s_top (verification only; not part of filelist.f).
// Derived from VLSIT_APB_I2S_HDS.md (requirements, section 10.3, 11.4, 15), IHI0024D (APB4) and the
// Philips I2S bus specification. The RTL is read only for port names, widths and parameters (R-023).
// Plusargs: +TEST=<name|ALL> +SEED=<n> +N=<random iterations> +APB_PS=<apb period in ps>
//           +WF=<n> (waveform scenario, writes waveforms_sim/<stem>.vcd) +PROTECT=<0|1>
module tb_i2s #(
  parameter int LINES = 1,
  parameter int DEPTH = 16,
  parameter int TX_EN = 1,
  parameter int RX_EN = 1,
  parameter int MASTER_EN = 1,
  parameter int ONDEM_EN = 1,
  parameter int TRI_EN = 1,
  parameter int HUNG_EN = 1,
  parameter int DMA_EN = 1,
  parameter int PACK_EN = 1,
  parameter int FMT_EXT_EN = 1,
  parameter int MAX_SLOTS = 32,
  parameter int SYNC_DEPTH = 2
);
  localparam int TM_PS = 10000;
  `include "i2s_defs.svh"

  // ---------------------------------------------------------------- clocks, resets, pins
  logic clk_apb = 0, clk_mclk = 0, rst_n_apb = 0, rst_n_mclk = 0;
  int apb_ps = 13000;
  initial begin
    if ($value$plusargs("APB_PS=%d", apb_ps)) ;
    forever #(apb_ps * 0.5ps) clk_apb = ~clk_apb;
  end
  always #(TM_PS * 0.5ps) clk_mclk = ~clk_mclk;

  logic psel = 0, penable = 0, pwrite = 0;
  logic [15:0] paddr = 0;
  logic [31:0] pwdata = 0;
  logic [3:0] pstrb = 4'h0;
  logic [2:0] pprot = 3'b000;
  wire pready, pslverr;
  wire [31:0] prdata;
  logic protect_en = 0, slverr_en = 1;

  wire bclk_tx, bclk_tx_oe, ws_tx, ws_tx_oe, sdo0, sdo1, sdo2, sdo3, sdo_oe;
  wire bclk_rx, bclk_rx_oe, ws_rx, ws_rx_oe;
  wire dma_tx_req, dma_tx_single, dma_rx_req, dma_rx_single, irq;
  logic dma_tx_ack = 0, dma_rx_ack = 0;
  wire dev_tx_bclk, dev_tx_ws, dev_rx_bclk, dev_rx_ws;
  wire [3:0] dev_rx_sd;
  bit rx_follow_tx = 0;       // the receive device follows the pins of the transmit unit (shared clock)

  m_vlsit_apb_i2s_top #(
    .PARA_I2S_TX_EN(TX_EN), .PARA_I2S_RX_EN(RX_EN), .PARA_I2S_TX_LINES(LINES), .PARA_I2S_RX_LINES(LINES),
    .PARA_I2S_FIFO_DEPTH(DEPTH), .PARA_I2S_MAX_SLOTS(MAX_SLOTS), .PARA_I2S_FMT_EXT_EN(FMT_EXT_EN),
    .PARA_I2S_PACK_EN(PACK_EN), .PARA_I2S_MASTER_EN(MASTER_EN), .PARA_I2S_ONDEM_EN(ONDEM_EN),
    .PARA_I2S_TRI_EN(TRI_EN), .PARA_I2S_HUNG_EN(HUNG_EN), .PARA_I2S_DMA_EN(DMA_EN),
    .PARA_I2S_SYNC_DEPTH(SYNC_DEPTH)
  ) dut (
    .i_clk_apb(clk_apb), .i_rst_n_apb(rst_n_apb), .i_clk_mclk(clk_mclk), .i_rst_n_mclk(rst_n_mclk),
    .i_apb_psel(psel), .i_apb_penable(penable), .i_apb_pwrite(pwrite), .i_apb_paddr(paddr),
    .i_apb_pwdata(pwdata), .i_apb_pstrb(pstrb), .i_apb_pprot(pprot),
    .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata),
    .i_protect_en(protect_en), .i_slverr_en(slverr_en),
    .o_bclk_tx(bclk_tx), .o_bclk_tx_oe(bclk_tx_oe), .i_bclk_tx(dev_tx_bclk),
    .o_ws_tx(ws_tx), .o_ws_tx_oe(ws_tx_oe), .i_ws_tx(dev_tx_ws),
    .o_sdo_0(sdo0), .o_sdo_1(sdo1), .o_sdo_2(sdo2), .o_sdo_3(sdo3), .o_sdo_oe(sdo_oe),
    .o_bclk_rx(bclk_rx), .o_bclk_rx_oe(bclk_rx_oe), .i_bclk_rx(dev_rx_bclk),
    .o_ws_rx(ws_rx), .o_ws_rx_oe(ws_rx_oe), .i_ws_rx(dev_rx_ws),
    .i_sdi_0(dev_rx_sd[0]), .i_sdi_1(dev_rx_sd[1]), .i_sdi_2(dev_rx_sd[2]), .i_sdi_3(dev_rx_sd[3]),
    .o_dma_tx_req(dma_tx_req), .i_dma_tx_ack(dma_tx_ack), .o_dma_tx_single(dma_tx_single),
    .o_dma_rx_req(dma_rx_req), .i_dma_rx_ack(dma_rx_ack), .o_dma_rx_single(dma_rx_single),
    .o_int_i2s(irq)
  );

  // device on the transmit pins (captures the data lines) and device on the receive pins (drives them)
  i2s_dev #(.LINES(LINES), .TM_PS(TM_PS)) dtx (
    .clk_m(clk_mclk), .dut_sd({sdo3, sdo2, sdo1, sdo0}), .dut_sd_oe(sdo_oe),
    .dut_bclk(bclk_tx), .dut_bclk_oe(bclk_tx_oe), .dut_ws(ws_tx), .dut_ws_oe(ws_tx_oe),
    .bclk_out(dev_tx_bclk), .ws_out(dev_tx_ws), .sd_out()
  );
  wire rbclk = rx_follow_tx ? bclk_tx : bclk_rx;
  wire rbclk_oe = rx_follow_tx ? bclk_tx_oe : bclk_rx_oe;
  wire rws = rx_follow_tx ? ws_tx : ws_rx;
  wire rws_oe = rx_follow_tx ? ws_tx_oe : ws_rx_oe;
  i2s_dev #(.LINES(LINES), .TM_PS(TM_PS)) drx (
    .clk_m(clk_mclk), .dut_sd(4'h0), .dut_sd_oe(1'b0),
    .dut_bclk(rbclk), .dut_bclk_oe(rbclk_oe), .dut_ws(rws), .dut_ws_oe(rws_oe),
    .bclk_out(dev_rx_bclk), .ws_out(dev_rx_ws), .sd_out(dev_rx_sd)
  );

  i2s_apb_chk apbchk (
    .clk(clk_apb), .rst_n(rst_n_apb), .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr),
    .pwdata(pwdata), .pstrb(pstrb), .pprot(pprot), .pready(pready), .pslverr(pslverr), .prdata(prdata),
    .protect_en(protect_en), .slverr_en(slverr_en)
  );

  // ---------------------------------------------------------------- results bookkeeping
  int n_checks = 0, n_fail = 0;
  string cur_test = "";
  int    test_fail0;
  string t_names [$];
  string t_reqs [$];
  int    t_res [$];     // 0 pass, 1 fail
  int    t_chk [$];
  int    chk0;
  task automatic begin_test(input string name, input string reqs);
    begin
      cur_test = name; test_fail0 = n_fail; chk0 = n_checks;
      t_names.push_back(name); t_reqs.push_back(reqs);
      $display("---- %s (%s)", name, reqs);
    end
  endtask
  task automatic end_test();
    begin
      t_res.push_back(n_fail != test_fail0);
      t_chk.push_back(n_checks - chk0);
      $display("---- %s: %s (%0d checks)", cur_test, (n_fail != test_fail0) ? "FAIL" : "PASS", n_checks - chk0);
    end
  endtask
  task automatic check(input logic ok, input string msg);
    begin
      n_checks++;
      if (!ok) begin n_fail++; $display("  CHECK FAIL @%0t [%s]: %s", $time, cur_test, msg); end
    end
  endtask

  // scoreboard-style assertion counters for checks that are not cycle based
  int sb_hit [1:12];
  int sb_bad [1:12];
  string sb_nm [1:12];
  initial begin
    for (int i = 1; i <= 12; i++) begin sb_hit[i] = 0; sb_bad[i] = 0; end
    sb_nm[1]  = "SB-01 words in and out of a logical FIFO keep the fixed order (INV-001, SVA-009)";
    sb_nm[2]  = "SB-02 error write: register unchanged (REQ-IF-003, 11.4)";
    sb_nm[3]  = "SB-03 reserved and self-clearing bits read 0 (REQ-IF-005, REQ-REG-006)";
    sb_nm[4]  = "SB-04 masked status equals raw AND enable, pin equals OR (REQ-IF-010, SVA-010)";
    sb_nm[5]  = "SB-05 injection sets the raw bit (REQ-IF-010)";
    sb_nm[6]  = "SB-06 write to a full FIFO: dropped, level kept, cause set (INV-002, REQ-FUNC-030)";
    sb_nm[7]  = "SB-07 read of an empty receive FIFO returns 0 (REQ-FUNC-030)";
    sb_nm[8]  = "SB-08 configuration of a running unit does not change the stream (INV-005, SVA-007)";
    sb_nm[9]  = "SB-09 DMA order: request, acknowledge, request low, acknowledge low (SVA-006)";
    sb_nm[10] = "SB-10 register reset values (REQ-REG-008)";
    sb_nm[11] = "SB-11 watermark causes follow the level (REQ-FUNC-016)";
    sb_nm[12] = "SB-12 underrun or overrun recovery as specified (REQ-FUNC-014, REQ-FUNC-015)";
  end
  task automatic sb(input int id, input logic ante, input logic cons, input string msg);
    begin
      if (ante === 1'b1) begin
        sb_hit[id]++;
        check(cons === 1'b1, msg);
        if (cons !== 1'b1) sb_bad[id]++;
      end
    end
  endtask

  // ---------------------------------------------------------------- random numbers
  longint rstate = 64'h1234_5678_9ABC_DEF1;
  int seed = 1;
  function automatic int rnd(input int n);   // 0 .. n-1
    begin
      rstate ^= rstate << 13; rstate ^= rstate >> 7; rstate ^= rstate << 17;
      rnd = int'(((rstate >> 8) & 64'h7FFFFFFF) % n);
    end
  endfunction
  function automatic logic [31:0] rnd32();
    int hi, lo;
    begin hi = rnd(65536); lo = rnd(65536); rnd32 = {hi[15:0], lo[15:0]}; end
  endfunction

  // ---------------------------------------------------------------- APB requester (IHI0024D)
  bit    apb_hold = 0;      // a transfer follows without an idle cycle
  bit    apb_chain = 0;     // the previous transfer left PSEL high
  int    apb_timeouts = 0;
  task automatic apb_xfer(input bit wr, input [15:0] a, input [31:0] d, input [3:0] strb, input [2:0] prot,
                          output logic [31:0] rdv, output bit err);
    int cnt;
    begin
      if (!apb_chain) @(posedge clk_apb);
      #1;
      psel = 1; pwrite = wr; paddr = a; pwdata = wr ? d : rnd32(); pstrb = wr ? strb : 4'h0; pprot = prot;
      penable = 0;
      @(posedge clk_apb); #1;
      penable = 1;
      cnt = 0;
      @(posedge clk_apb);
      while (!pready && cnt < 40) begin @(posedge clk_apb); cnt++; end
      if (cnt >= 40) begin apb_timeouts++; check(1'b0, "APB transfer did not complete"); end
      rdv = prdata; err = pslverr;
      #1;
      if (apb_hold) begin apb_chain = 1; penable = 0; end
      else begin apb_chain = 0; psel = 0; penable = 0; pwrite = 0; end
    end
  endtask
  logic [31:0] rv_;
  bit          ev_;
  task automatic wr32(input [15:0] a, input [31:0] d);
    begin apb_xfer(1, a, d, 4'hF, 3'b000, rv_, ev_); end
  endtask
  task automatic rd32(input [15:0] a, output logic [31:0] d);
    begin apb_xfer(0, a, 0, 4'h0, 3'b000, d, ev_); end
  endtask
  function automatic logic [31:0] RD(input [15:0] a);   // not used in time-consuming context
    return 0;
  endfunction
  logic [31:0] r_;
  task automatic wait_apb(input int n);
    begin repeat (n) @(posedge clk_apb); end
  endtask
  task automatic wait_m(input int n);
    begin repeat (n) @(posedge clk_mclk); end
  endtask

  // ---------------------------------------------------------------- software helpers
  function automatic [15:0] U(input int u, input [15:0] off);
    return (u == 0 ? TX_BASE : RX_BASE) + off;
  endfunction
  task automatic hw_reset();
    begin
      dtx.run = 0; drx.run = 0;
      wait_m(2);
      rst_n_apb = 0; rst_n_mclk = 0;
      wait_apb(6); wait_m(6);
      @(posedge clk_apb); #1 rst_n_apb = 1; @(posedge clk_mclk); #1 rst_n_mclk = 1;
      wait_apb(8); wait_m(12);
      dtx.reset_tracker(); drx.reset_tracker(); dtx.clear_results(); drx.clear_results();
      rx_follow_tx = 0; dma_tx_ack = 0; dma_rx_ack = 0;
    end
  endtask
  // unit configuration (frame, sync, clock, mask, watermark); control bits are written by the caller
  task automatic cfg_unit(input int u, input int fmt, input int nslot, input int slot_w, input int data_w,
                          input int align, input int pack, input logic [31:0] mask, input int div,
                          input int bpol, input int sync_w, input int fsp, input int fse, input int wm);
    begin
      wr32(U(u, R_FRAME), fmt | (align << 3) | (pack << 4) | (nslot << 8) | (slot_w << 16) | (data_w << 24));
      wr32(U(u, R_SYNC), sync_w | (fsp << 8) | (fse << 9) | (bpol << 12));
      wr32(U(u, R_CLK), div);
      wr32(U(u, R_MASK), mask);
      wr32(U(u, R_FIFO), wm);
    end
  endtask
  task automatic unit_en(input int u, input int bits);   // ctrl bits other than en, plus en
    begin wr32(U(u, R_CTRL), bits | 32'h1); end
  endtask
  task automatic unit_dis(input int u);
    int t;
    logic [31:0] s;
    begin
      wr32(U(u, R_CTRL), 32'h0);
      t = 0; s = 32'h1;
      while (s[0] && t < 400) begin wait_m(100); rd32(U(u, R_STS), s); t++; end
      check(!s[0], "unit busy fell after the enable was cleared (REQ-FUNC-026, REQ-FUNC-027)");
    end
  endtask
  task automatic wait_busy(input int u, input bit v);
    int t; logic [31:0] s;
    begin
      t = 0; s = v ? 32'h0 : 32'h1;
      while (s[0] != v && t < 400) begin wait_apb(20); rd32(U(u, R_STS), s); t++; end
    end
  endtask
  task automatic soft_reset_all();
    int t; logic [31:0] s;
    begin
      wr32(R_GCTRL, 32'h1);
      t = 0; s = 32'h3;
      while (s[1:0] != 0 && t < 400) begin wait_apb(10); rd32(R_GSTS, s); t++; end
    end
  endtask
  task automatic flush_unit(input int u, input int keep = 0);
    int t; logic [31:0] s;
    begin
      wr32(U(u, R_CTRL), 32'h4 | keep);   // flush bit with the bits that the caller wants kept
      t = 0; s = 32'h1;
      while (s[0] && t < 400) begin wait_apb(10); rd32(U(u, R_STS), s); t++; end
    end
  endtask

  // expected sample of a transmitted word (REQ-FUNC-009, REQ-FUNC-010)
  function automatic logic [31:0] exp_tx(input logic [31:0] w, input int align, input int pack, input int hi, input int dw);
    logic [31:0] dm; logic [15:0] h;
    begin
      dm = (dw >= 32) ? 32'hFFFFFFFF : ((32'h1 << dw) - 1);
      if (pack != 0) begin
        h = hi ? w[31:16] : w[15:0];
        exp_tx = align ? ((h >> (16 - dw)) & dm) : (h & dm);
      end else exp_tx = align ? ((w >> (32 - dw)) & dm) : (w & dm);
    end
  endfunction
  // expected FIFO word of received samples (REQ-FUNC-009, REQ-FUNC-010)
  function automatic logic [31:0] exp_rx(input logic [31:0] s0, input logic [31:0] s1, input int align, input int pack, input int dw);
    logic [15:0] h0, h1;
    begin
      if (pack != 0) begin
        h0 = align ? (s0[15:0] << (16 - dw)) : s0[15:0];
        h1 = align ? (s1[15:0] << (16 - dw)) : s1[15:0];
        exp_rx = {h1, h0};
      end else exp_rx = align ? (s0 << (32 - dw)) : s0;
    end
  endfunction
  function automatic int popc(input logic [31:0] m, input int n);
    int c;
    begin c = 0; for (int i = 0; i < n; i++) if (m[i]) c++; popc = c; end
  endfunction
  function automatic logic [31:0] dmk(input int dw);
    return (dw >= 32) ? 32'hFFFFFFFF : ((32'h1 << dw) - 1);
  endfunction

  string test_sel = "ALL";
  int n_rand = 20;
  int wf_sel = 0;
  logic dma_en_tx = 0, dma_en_rx = 0;       // shadow of the DMA enable bits written by the tests
  `include "i2s_tests.svh"

  // ---------------------------------------------------------------- DMA protocol checks (SVA-006)
  int dma_hit [1:6];
  int dma_bad [1:6];
  string dma_nm [1:6];
  initial begin
    for (int i = 1; i <= 6; i++) begin dma_hit[i] = 0; dma_bad[i] = 0; end
    dma_nm[1] = "DMA-01 request falls in the cycle after the acknowledge rises (INV-006, REQ-FUNC-028)";
    dma_nm[2] = "DMA-02 request held high until the acknowledge (REQ-FUNC-028)";
    dma_nm[3] = "DMA-03 single is low while the acknowledge is high (REQ-FUNC-029)";
    dma_nm[4] = "DMA-04 request low while the acknowledge is high after the first cycle (REQ-FUNC-028)";
    dma_nm[5] = "DMA-05 request and single not X after reset (REQ-IF-012)";
    dma_nm[6] = "DMA-06 no request without the DMA enable bit (REQ-FUNC-028)";
  end
  task automatic dchk(input int id, input logic ante, input logic cons);
    begin
      if (ante === 1'b1) begin
        dma_hit[id]++;
        if (cons !== 1'b1) begin dma_bad[id]++; if (dma_bad[id] <= 3) $display("ASSERT FAIL @%0t: %s [txreq=%b ack=%b single=%b en=%b rxreq=%b rxack=%b cnt=%0d]", $time, dma_nm[id], dma_tx_req, dma_tx_ack, dma_tx_single, dma_en_tx, dma_rx_req, dma_rx_ack, tcnt); end
      end
    end
  endtask
  logic ta1 = 0, ta2 = 0, tr1 = 0, ra1 = 0, ra2 = 0, rr1 = 0;
  int   tcnt = 0, rcnt = 0;               // cycles since the DMA enable shadow changed
  logic tp = 0, rp = 0;
  always @(posedge clk_apb) begin
    tcnt = (dma_en_tx !== tp) ? 0 : tcnt + 1; tp = dma_en_tx;
    rcnt = (dma_en_rx !== rp) ? 0 : rcnt + 1; rp = dma_en_rx;
    if (rst_n_apb) begin
      dchk(1, ta1 & !ta2 & tr1 & (tcnt > 8) & dma_en_tx, !dma_tx_req);
      dchk(1, ra1 & !ra2 & rr1 & (rcnt > 8) & dma_en_rx, !dma_rx_req);
      dchk(2, tr1 & !ta1 & !dma_tx_ack & (tcnt > 8) & dma_en_tx, dma_tx_req);
      dchk(2, rr1 & !ra1 & !dma_rx_ack & (rcnt > 8) & dma_en_rx, dma_rx_req);
      dchk(3, ta1 & dma_tx_ack, !dma_tx_single);
      dchk(3, ra1 & dma_rx_ack, !dma_rx_single);
      dchk(4, ta1 & dma_tx_ack, !dma_tx_req);
      dchk(4, ra1 & dma_rx_ack, !dma_rx_req);
      dchk(5, 1'b1, !$isunknown(dma_tx_req) & !$isunknown(dma_tx_single) & !$isunknown(dma_rx_req) & !$isunknown(dma_rx_single));
      dchk(6, !dma_en_tx & (tcnt > 8), !dma_tx_req);
      dchk(6, !dma_en_rx & (rcnt > 8), !dma_rx_req);
    end
    ta2 <= ta1; ta1 <= dma_tx_ack; tr1 <= dma_tx_req;
    ra2 <= ra1; ra1 <= dma_rx_ack; rr1 <= dma_rx_req;
  end

  // ---------------------------------------------------------------- main
  initial begin
    int a_total, a_failed, a_never, d_total, d_failed, d_never, s_total, s_failed, s_never;
    int fails;
    if ($value$plusargs("TEST=%s", test_sel)) ;
    if ($value$plusargs("SEED=%d", seed)) ;
    if ($value$plusargs("N=%d", n_rand)) ;
    if ($value$plusargs("WF=%d", wf_sel)) ;
    if ($test$plusargs("DBG")) begin dtx.dbg = 1; drx.dbg = 1; end
    if ($value$plusargs("PROTECT=%d", protect_en)) ;
    rstate = 64'h1234_5678_9ABC_DEF1 ^ (64'(seed) * 64'h9E3779B97F4A7C15);
    repeat (5) rnd(2);
`ifdef VLSIT_SYNTHESIS
    $display("SIM-BRANCH: synthesis");
`else
    begin
      int ms;
      if (!$value$plusargs("AFIFO_MSYNC_SEED=%d", ms)) ms = 1;
      $display("SIM-BRANCH: metastable seed=%0d", ms);
    end
`endif
    $display("CONFIG: LINES=%0d DEPTH=%0d TX_EN=%0d RX_EN=%0d MASTER_EN=%0d ONDEM_EN=%0d TRI_EN=%0d HUNG_EN=%0d DMA_EN=%0d PACK_EN=%0d FMT_EXT_EN=%0d MAX_SLOTS=%0d SYNC_DEPTH=%0d test=%s seed=%0d apb_ps=%0d",
             LINES, DEPTH, TX_EN, RX_EN, MASTER_EN, ONDEM_EN, TRI_EN, HUNG_EN, DMA_EN, PACK_EN, FMT_EXT_EN, MAX_SLOTS, SYNC_DEPTH, test_sel, seed, apb_ps);
    wait_m(4);
    hw_reset();
    run_all(test_sel, wf_sel);
    // ---- report
    $display("==== assertion table");
    apbchk.report(a_total, a_failed, a_never);
    dtx.report(d_total, d_failed, d_never);
    $display("---- (receive-side device)");
    s_total = 0;
    for (int i = 1; i <= 12; i++) begin
      s_total++;
      $display("  %-92s hits=%0d fails=%0d", sb_nm[i], sb_hit[i], sb_bad[i]);
    end
    for (int i = 1; i <= 6; i++) $display("  %-92s hits=%0d fails=%0d", dma_nm[i], dma_hit[i], dma_bad[i]);
    fails = a_failed + d_failed;
    for (int i = 1; i <= 12; i++) if (sb_bad[i] != 0) fails++;
    for (int i = 1; i <= 6; i++) if (dma_bad[i] != 0) fails++;
    // assertions that this run could not reach are named, not hidden
    s_never = a_never;
    for (int i = 1; i <= 8; i++) if (dtx.hit[i] == 0 && !ser_na(i)) s_never++;
    for (int i = 1; i <= 12; i++) if (sb_hit[i] == 0 && !sb_na(i)) s_never++;
    for (int i = 1; i <= 6; i++) if (dma_hit[i] == 0 && !dma_na(i)) s_never++;
    $display("==== tests");
    for (int i = 0; i < t_names.size(); i++)
      $display("  %-36s %-44s %s (%0d checks)", t_names[i], t_reqs[i], t_res[i] ? "FAIL" : "PASS", t_chk[i]);
    if (wf_sel != 0) begin s_never = 0; $display("waveform scenario WF-%03d: the assertion hit counts of a single scenario are not a coverage statement", wf_sel); end
    $display("checks: %0d, failed checks: %0d, APB timeouts: %0d", n_checks, n_fail, apb_timeouts);
    $display("assertion failures: %0d, assertions never exercised: %0d", fails + n_fail, s_never);
    if (fails + n_fail == 0 && s_never == 0) $display("RESULT: PASS");
    else $display("RESULT: FAIL");
    $finish;
  end
  initial begin
    #2000000000;   // 2 ms of simulated time at most
    $display("TIMEOUT");
    $display("RESULT: FAIL");
    $finish;
  end
endmodule
