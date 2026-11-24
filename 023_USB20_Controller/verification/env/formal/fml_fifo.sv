// Formal harness of t_fml_fifo (REQ-FUNC-027, REQ-FUNC-029 at port level). AI-generated candidate (R-117).
// Properties use ports only (R-103): the committed row count of every queue never exceeds the size of its region and
// the free rows of the receive region never exceed the receive region (a_fifo_inv).
// Environment assumptions (each reviewed): the region map is constant, legal and does not overlap (section 11.3); the bus
// port follows the request protocol (a request stays unchanged until accepted; queue numbers exist; WR, COMMIT only on a
// transmit queue 1 or 2; RD and POP only on queue 0; the number of rows of a packet is at most the region);
// the packet port starts a packet only after a start and ends it once; flush is not used (queue flush is a software
// request that is verified in simulation).
module fml_fifo #(parameter int CHK = 0) (
  input logic        clk,
  input logic        rst_n,
  input logic        rxw_sop, rxw_end, rxw_ok,
  input logic [1:0]  rxw_n,
  input logic [15:0] rxw_b,
  input logic [11:0] rxw_len,
  input logic        txr_start, txr_commit, txr_cancel, src_pop,
  input logic [1:0]  txr_q_sel,
  input logic [11:0] txr_len,
  input logic        bp_vld,
  input logic [2:0]  bp_op,
  input logic [1:0]  bp_q,
  input logic [31:0] bp_data,
  input logic        ev_rdy
);
  localparam int NQ = 3;
  logic [NQ*16-1:0] q_base, q_size;
  assign q_base = {16'd96, 16'd64, 16'd0};         // words: receive 0..63, queue 1 64..95, queue 2 96..127
  assign q_size = {16'd32, 16'd32, 16'd64};
  logic [16:0] rx_free; logic plq_free; logic [15:0] src_dat; logic src_vld;
  logic [NQ*17-1:0] q_cnt; logic bp_rdy, bp_rsp_vld; logic [31:0] bp_rsp_data;
  logic ev_vld; logic [1:0] ev_type; logic [4:0] ev_q; logic [16:0] ev_val; logic ovf, par_err;
  wire [4:0] txr_q = {3'd0, txr_q_sel};
  wire [4:0] bpq   = {3'd0, bp_q};

  m_usb2_fifo #(.PARA_USB2_UTMI_W(8), .PARA_USB2_NQ(NQ), .PARA_USB2_FIFO_DEPTH(256), .PARA_USB2_RAM_PAR_EN(0)) dut (
    .i_clk_phy(clk), .i_rst_n_core(rst_n), .i_q_base(q_base), .i_q_size(q_size), .i_flush_vld(1'b0), .i_flush_q(5'd0),
    .i_rxw_sop(rxw_sop), .i_rxw_tag(5'd0), .i_rxw_n(rxw_n), .i_rxw_b(rxw_b), .i_rxw_end(rxw_end), .i_rxw_ok(rxw_ok),
    .i_rxw_len(rxw_len), .o_rx_free(rx_free), .o_plq_free(plq_free), .i_txr_start(txr_start), .i_txr_q(txr_q),
    .i_txr_len(txr_len), .i_txr_commit(txr_commit), .i_txr_cancel(txr_cancel), .i_src_pop(src_pop), .o_src_dat(src_dat),
    .o_src_vld(src_vld), .o_q_cnt(q_cnt), .i_bp_vld(bp_vld), .i_bp_op(bp_op), .i_bp_q(bpq), .i_bp_data(bp_data),
    .o_bp_rdy(bp_rdy), .o_bp_rsp_vld(bp_rsp_vld), .o_bp_rsp_data(bp_rsp_data), .o_ev_vld(ev_vld), .o_ev_type(ev_type),
    .o_ev_q(ev_q), .o_ev_val(ev_val), .i_ev_rdy(ev_rdy), .o_ovf(ovf), .o_par_err(par_err));

  logic [1:0] t; logic init, in_pkt, rxw_active; logic bp_vld_d, bp_rdy_d; logic [2:0] bp_op_d; logic [1:0] bp_q_d;
  logic [31:0] bp_data_d; logic tx_open; logic [3:0] gap; logic [5:0] wr1, wr2; logic [11:0] nbytes;
  initial begin gap = 4'd15; t = 2'd0; in_pkt = 1'b0; bp_vld_d = 1'b0; bp_rdy_d = 1'b1; tx_open = 1'b0; wr1 = 6'd0; wr2 = 6'd0; nbytes = 12'd0; end
  assign init = (t == 2'd3);
  always @(posedge clk) begin
    if (t != 2'd3) t <= t + 2'd1;
    assume (rst_n == (t >= 2'd2));
    assume (rst_n || (!rxw_sop && !rxw_end && rxw_n == 2'd0 && !bp_vld && !txr_start));   // no traffic while the reset is active
    bp_vld_d <= bp_vld; bp_rdy_d <= bp_rdy; bp_op_d <= bp_op; bp_q_d <= bp_q; bp_data_d <= bp_data;
    // packet port: a packet is bracketed by sop and end; no new sop inside a packet; bytes only inside a packet
    // inter-packet gap: the link never starts a packet within 8 cycles after the end of the previous one (USB 2.0 8.7.2: at least 8 bit times)
    if (rxw_end) gap <= 4'd0; else if (gap != 4'd15) gap <= gap + 4'd1;
    assume (!(rxw_sop && gap < 4'd8));
    if (rxw_sop) in_pkt <= 1'b1;
    if (rxw_end) in_pkt <= 1'b0;
    assume (!(rxw_sop && rxw_end));
    assume (!(rxw_sop && in_pkt));
    assume (!(rxw_end && !in_pkt && !rxw_sop));
    assume (rxw_sop || in_pkt || rxw_n == 2'd0);                  // bytes only inside a packet (the counterexample of r0646 delivered bytes outside one)
    assume (rxw_n <= 2'd1);                                        // the instance is the 8-bit build (PARA_USB2_UTMI_W = 8): one byte per chunk
    // the length reported at the end equals the bytes delivered in the chunks of the packet
    assume (!(rxw_sop && rxw_n != 2'd0));                          // the start cycle carries no bytes (m_usb2_dev drives n only in OUT_RX)
    if (rxw_sop) nbytes <= 12'd0;
    else if (in_pkt) nbytes <= nbytes + {10'd0, rxw_n};
    assume (!(rxw_end && in_pkt && rxw_ok && rxw_len != (nbytes + {10'd0, rxw_n})));
    assume (!(rxw_end && rxw_sop && rxw_ok && rxw_len != {10'd0, rxw_n}));
    assume (rxw_len <= 12'd64);
    // transmit read: start and the end of the transaction are exclusive and ordered
    if (txr_start) tx_open <= 1'b1;
    if (txr_commit || txr_cancel) tx_open <= 1'b0;
    assume (!(txr_start && (txr_commit || txr_cancel)));
    assume (!(txr_commit && txr_cancel));
    assume (!(txr_start && tx_open));
    assume (!((txr_commit || txr_cancel || src_pop) && !tx_open));
    assume (txr_q_sel != 2'd0 && txr_q_sel != 2'd3);
    assume (txr_len <= 12'd128);
    // the engines start a transmit read only when the queue holds the rows of the packet (REQ-FUNC-027)
    assume (!(txr_start && txr_q_sel == 2'd1 && ((txr_len + 12'd3) >> 2) > q_cnt[17 +: 17]));
    assume (!(txr_start && txr_q_sel == 2'd2 && ((txr_len + 12'd3) >> 2) > q_cnt[34 +: 17]));
    // bus port protocol
    assume (bp_q != 2'd3);
    assume (bp_op >= 3'd1 && bp_op <= 3'd4);
    assume ((bp_op == 3'd1 || bp_op == 3'd4) ? bp_q != 2'd0 : bp_q == 2'd0);
    // a commit follows at least one accepted write row of the same queue. The bus master is NOT assumed to respect the
    // free rows of the queue (until run r0332 the credit of the DMA was assumed; BUG-031 showed that this hid an overwrite):
    // the FIFO manager itself must hold a row write back while the region is full.
    if (bp_vld && bp_rdy && bp_op == 3'd1) begin if (bp_q == 2'd1) wr1 <= wr1 + 6'd1; if (bp_q == 2'd2) wr2 <= wr2 + 6'd1; end
    if (bp_vld && bp_rdy && bp_op == 3'd4) begin if (bp_q == 2'd1) wr1 <= 6'd0; if (bp_q == 2'd2) wr2 <= 6'd0; end
    assume (!(bp_op == 3'd4 && bp_q == 2'd1 && wr1 == 6'd0));
    assume (!(bp_op == 3'd4 && bp_q == 2'd2 && wr2 == 6'd0));
    // a pop releases a received packet: the receive queue holds rows (a zero-length packet cannot underflow the count)
    assume (!(bp_op == 3'd3 && q_cnt[0 +: 17] == 17'd0));
    assume (!(bp_op == 3'd2 && q_cnt[0 +: 17] == 17'd0));
    if (bp_vld_d && !bp_rdy_d) assume (bp_vld && bp_op == bp_op_d && bp_q == bp_q_d && bp_data == bp_data_d);
    if (init) begin
      // CHK = 0: transmit queues, CHK = 1: receive queue and its free rows (the packet-port model of the harness
      // is a guess of the chunk semantics, see sim/docs/bugs.md FND-008)
      if (CHK == 0) begin
        a_fifo_inv_q1:  assert (q_cnt[17 +: 17] <= 17'd32);
        a_fifo_inv_q2:  assert (q_cnt[34 +: 17] <= 17'd32);
      end else begin
        a_fifo_inv_rx:  assert (q_cnt[0 +: 17] <= 17'd64);
        a_fifo_inv_free: assert (rx_free <= 17'd64);
      end
      c_fifo_wrap:   cover (q_cnt[17 +: 17] >= 17'd4);
      c_fifo_full:   cover (q_cnt[0 +: 17] >= 17'd2);                  // two committed rows in the receive queue (8-bit build: one byte per cycle, 8-cycle gap, depth 28)
      c_fifo_empty:  cover (init && q_cnt == '0 && rx_free == 17'd64 && $past(q_cnt) != '0);
    end
  end
endmodule
