`timescale 1ns/1ps
// Scratch test of m_usb2_fifo: receive packets in, bus-port reads out; bus-port writes in, packet-port reads out.
module tb_fifo;
  parameter int W = 8;
  localparam int RW = W*4;
  localparam int BPR = RW/8;
  localparam int NQ = 4;
  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;
  logic [NQ*16-1:0] q_base, q_size;
  logic flush_vld = 0; logic [4:0] flush_q = 0;
  logic rxw_sop = 0, rxw_end = 0, rxw_ok = 0; logic [4:0] rxw_tag = 0; logic [1:0] rxw_n = 0; logic [15:0] rxw_b = 0; logic [11:0] rxw_len = 0;
  logic [16:0] rx_free; logic plq_free;
  logic txr_start = 0, txr_commit = 0, txr_cancel = 0; logic [4:0] txr_q = 0; logic [11:0] txr_len = 0;
  logic pop_en = 0; logic src_pop; logic [15:0] src_dat; logic src_vld; logic [NQ*17-1:0] q_cnt;
  logic bp_vld = 0; logic [2:0] bp_op = 0; logic [4:0] bp_q = 0; logic [RW-1:0] bp_data = 0; logic bp_rdy, bp_rsp_vld; logic [RW-1:0] bp_rsp_data;
  logic ev_vld; logic [1:0] ev_type; logic [4:0] ev_q; logic [16:0] ev_val; logic ev_rdy = 1; logic ovf, par_err;

  m_usb2_fifo #(.PARA_USB2_UTMI_W(W), .PARA_USB2_NQ(NQ), .PARA_USB2_FIFO_DEPTH(256), .PARA_USB2_RAM_PAR_EN(1), .PARA_USB2_RAM_1P(P1)) dut (
    .i_clk_phy(clk), .i_rst_n_core(rst_n), .i_q_base(q_base), .i_q_size(q_size), .i_flush_vld(flush_vld), .i_flush_q(flush_q),
    .i_rxw_sop(rxw_sop), .i_rxw_tag(rxw_tag), .i_rxw_n(rxw_n), .i_rxw_b(rxw_b), .i_rxw_end(rxw_end), .i_rxw_ok(rxw_ok), .i_rxw_len(rxw_len),
    .o_rx_free(rx_free), .o_plq_free(plq_free),
    .i_txr_start(txr_start), .i_txr_q(txr_q), .i_txr_len(txr_len), .i_txr_commit(txr_commit), .i_txr_cancel(txr_cancel),
    .i_src_pop(src_pop), .o_src_dat(src_dat), .o_src_vld(src_vld), .o_q_cnt(q_cnt),
    .i_bp_vld(bp_vld), .i_bp_op(bp_op), .i_bp_q(bp_q), .i_bp_data(bp_data), .o_bp_rdy(bp_rdy), .o_bp_rsp_vld(bp_rsp_vld), .o_bp_rsp_data(bp_rsp_data),
    .o_ev_vld(ev_vld), .o_ev_type(ev_type), .o_ev_q(ev_q), .o_ev_val(ev_val), .i_ev_rdy(ev_rdy), .o_ovf(ovf), .o_par_err(par_err));
  parameter int P1 = 0;
  assign src_pop = pop_en & src_vld;
  int got [32]; int ng = 0;
  always_ff @(posedge clk) if (src_pop) begin if (W == 16) begin got[ng] <= src_dat[7:0]; got[ng+1] <= src_dat[15:8]; ng <= ng + 2; end else begin got[ng] <= src_dat[7:0]; ng <= ng + 1; end end

  int errors = 0, checks = 0;
  task automatic chk(input bit c, input string m); checks++; if (!c) begin errors++; $display("FAIL: %s", m); end endtask
  // event log
  int nev; logic [1:0] evt_t [16]; logic [4:0] evt_q [16]; logic [16:0] evt_v [16];
  always_ff @(posedge clk) if (ev_vld && ev_rdy) begin evt_t[nev] <= ev_type; evt_q[nev] <= ev_q; evt_v[nev] <= ev_val; nev <= nev + 1; end
  // bus rsp log
  logic [RW-1:0] rsp [16]; int nrsp;
  always_ff @(posedge clk) if (bp_rsp_vld) begin rsp[nrsp] <= bp_rsp_data; nrsp <= nrsp + 1; end

  task automatic bus_op(input logic [2:0] op, input logic [4:0] q, input logic [RW-1:0] d);
    @(posedge clk); bp_vld <= 1; bp_op <= op; bp_q <= q; bp_data <= d;
    do @(posedge clk); while (!bp_rdy);   // sampled after edge: rdy was for this cycle
    bp_vld <= 0;
  endtask

  task automatic rx_packet(input int len, input logic [4:0] tag, input bit ok, input int seed);
    int i;
    @(posedge clk); rxw_sop <= 1; rxw_tag <= tag; @(posedge clk); rxw_sop <= 0;
    i = 0;
    while (i < len) begin
      int n; n = (W == 16 && len - i >= 2 && (i % 3 != 1)) ? 2 : 1;
      rxw_n <= n; rxw_b <= {8'(i*5+seed+1), 8'(i*5+seed)};
      if (n == 2) rxw_b <= {8'((i+1)*5+seed), 8'(i*5+seed)};
      else rxw_b <= {8'h00, 8'(i*5+seed)};
      i += n; @(posedge clk);
    end
    rxw_n <= 0; rxw_end <= 1; rxw_ok <= ok; rxw_len <= len; @(posedge clk); rxw_end <= 0;
    repeat (6) @(posedge clk);
  endtask

  initial begin
    nev = 0; nrsp = 0;
    q_base = '0; q_size = '0;
    q_base[0*16 +: 16] = 0;   q_size[0*16 +: 16] = 64;
    q_base[1*16 +: 16] = 64;  q_size[1*16 +: 16] = 32;
    q_base[2*16 +: 16] = 96;  q_size[2*16 +: 16] = 32;
    q_base[3*16 +: 16] = 128; q_size[3*16 +: 16] = 32;
    repeat (4) @(posedge clk); rst_n = 1; repeat (3) @(posedge clk);
    // 1. receive a 10-byte good packet, tag 3
    rx_packet(10, 5'd3, 1, 10);
    chk(nev == 1 && evt_t[0] == 0 && evt_q[0] == 3 && evt_v[0] == 10, $sformatf("PKT event n=%0d t=%0d q=%0d v=%0d", nev, evt_t[0], evt_q[0], evt_v[0]));
    // read 3 rows of the packet (BPR bytes each depends on W)
    begin
      int rows; rows = (10 + BPR - 1) / BPR;
      for (int r = 0; r < rows; r++) bus_op(2, 0, 0);
      repeat (4) @(posedge clk);
      chk(nrsp == rows, $sformatf("rsp count %0d vs %0d", nrsp, rows));
      for (int i = 0; i < 10; i++) chk(rsp[i/BPR][8*(i%BPR) +: 8] == 8'(i*5+10), $sformatf("rx byte %0d got %02x exp %02x", i, rsp[i/BPR][8*(i%BPR) +: 8], 8'(i*5+10)));
      bus_op(3, 0, 0);
      repeat (3) @(posedge clk);
      chk(q_cnt[0 +: 17] == 0, $sformatf("rx cnt after pop %0d", q_cnt[0 +: 17]));
    end
    // 2. a bad packet is rolled back
    rx_packet(7, 5'd4, 0, 50);
    chk(nev == 1, "no event for bad packet");
    chk(q_cnt[0 +: 17] == 0, "rx cnt unchanged after bad packet");
    // 3. a second good packet after the bad one starts at the committed pointer
    rx_packet(5, 5'd6, 1, 70);
    chk(nev == 2 && evt_q[1] == 6 && evt_v[1] == 5, "second PKT event");
    nrsp = 0;
    for (int r = 0; r < (5 + BPR - 1) / BPR; r++) bus_op(2, 0, 0);
    repeat (4) @(posedge clk);
    chk(nrsp == (5 + BPR - 1) / BPR, "rsp count 2");
    for (int i = 0; i < 5; i++) chk(rsp[i/BPR][8*(i%BPR) +: 8] == 8'(i*5+70), $sformatf("rx2 byte %0d got %02x exp %02x", i, rsp[i/BPR][8*(i%BPR) +: 8], 8'(i*5+70)));
    bus_op(3, 0, 0);
    // 4. transmit queue 1: bus writes rows, packet reads
    begin
      int rows; logic [RW-1:0] d; rows = (13 + BPR - 1) / BPR;
      for (int r = 0; r < rows; r++) begin
        for (int b = 0; b < BPR; b++) d[8*b +: 8] = 8'(r*BPR + b + 1);
        bus_op(1, 1, d);
      end
      bus_op(4, 1, 0);
      repeat (4) @(posedge clk);
      chk(q_cnt[1*17 +: 17] == rows, $sformatf("tx cnt %0d vs %0d", q_cnt[1*17 +: 17], rows));
      @(posedge clk); txr_start <= 1; txr_q <= 1; txr_len <= 13; @(posedge clk); txr_start <= 0;
      repeat (3) @(posedge clk);
      ng = 0; pop_en <= 1;
      while (ng < 13) @(posedge clk);
      pop_en <= 0; @(posedge clk);
      for (int i = 0; i < 13; i++) chk(got[i] == i + 1, $sformatf("tx byte %0d got %0d", i, got[i]));
      @(posedge clk); txr_commit <= 1; @(posedge clk); txr_commit <= 0;
      repeat (6) @(posedge clk);
      chk(q_cnt[1*17 +: 17] == 0, "tx cnt after commit");
      chk(nev == 3 && evt_t[2] == 1 && evt_q[2] == 1 && evt_v[2] == rows, $sformatf("credit event n=%0d t=%0d q=%0d v=%0d", nev, evt_t[2], evt_q[2], evt_v[2]));
    end
    chk(!par_err, "no parity error");
    $display("TB_FIFO W=%0d P1=%0d checks=%0d errors=%0d ovf=%b", W, P1, checks, errors, ovf);
    $finish;
  end
  initial begin #3000000; $display("TIMEOUT"); $finish; end
endmodule
