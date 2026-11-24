`timescale 1ns/1ps
// Trace of m_chacha_block_p for the waveforms of the block pairs (scratch).
// CNT blocks, the consumer takes a block from cycle TAKE_FROM on (one per cycle while one is valid).
module tb_pair;
  parameter QN = 4;
  parameter RC = 2;
  parameter CNT = 3;
  parameter TAKE_FROM = 0;
  parameter NCYC = 70;
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;
  logic clr = 0, load = 0, take = 0;
  wire vld;
  wire [511:0] blk;
  logic [255:0] key = 256'h0123456789abcdef_0011223344556677_8899aabbccddeeff_fedcba9876543210;
  logic [95:0] nonce = 96'h000102030405060708090a0b;
  m_chacha_block_p #(.PARA_QR_NUM(QN), .PARA_RND_CYC(RC)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_load(load), .i_ctr0(32'd0), .i_ctr_step(4'd1),
    .i_blk_cnt(11'(CNT)), .i_key(key), .i_nonce(nonce), .o_blk_vld(vld), .o_blk(blk), .i_take(take));
  integer cyc = 0;
  integer c;
  initial begin
    #23 rst_n = 1;
    @(posedge clk);
    for (c = 0; c < NCYC; c++) begin
      #1 load = (c == 0);
      take = (c >= TAKE_FROM) && dut.reg_q0_v;
      #4;
      $display("S c=%0d load=%b st=%0d ph=%b left=%0d dlv=%b stall=%b q0v=%b q1v=%b ctr0=%0d vld=%b take=%b",
        c, load, dut.reg_fsm_blk_current_state, dut.reg_ph, dut.reg_left, dut.w_dlv, dut.w_stall,
        dut.reg_q0_v, dut.reg_q1_v, dut.reg_q0_ctr, vld, take);
      @(posedge clk);
    end
    $finish;
  end
endmodule
