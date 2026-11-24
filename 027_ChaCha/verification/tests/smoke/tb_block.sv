`timescale 1ns/1ps
module tb_block;
  parameter QN = 4;
  parameter RC = 1;
  logic clk = 0; logic rst_n = 0;
  always #5 clk = ~clk;
  logic load, clr, take; logic [31:0] ctr0; logic [3:0] step; logic [10:0] cnt;
  logic vld; logic [511:0] blk;
  logic [511:0] expv [0:2];
  logic [255:0] key; logic [95:0] nonce;
  m_chacha_block #(.PARA_QR_NUM(QN), .PARA_RND_CYC(RC)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_load(load), .i_ctr0(ctr0),
    .i_ctr_step(step), .i_blk_cnt(cnt), .i_key(key), .i_nonce(nonce),
    .o_blk_vld(vld), .o_blk(blk), .i_take(take));
  integer errs = 0; integer got = 0; integer t0; integer cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;
  initial begin
    $readmemh("block_exp.hex", expv);
    for (int i = 0; i < 32; i++) key[8*i +: 8] = i;
    nonce = 96'h000000000000004a00000009;
    // words: nonce0 = 00000009, nonce1 = 0000004a, nonce2 = 0
    nonce = {32'h00000000, 32'h4a000000, 32'h09000000};
    load = 0; clr = 0; take = 0; ctr0 = 1; step = 1; cnt = 3;
    #25 rst_n = 1;
    @(posedge clk); #1 load = 1;
    @(posedge clk); #1 load = 0; t0 = cyc;
    // consume with delay to exercise the wait state
    while (got < 3) begin
      @(posedge clk); #1;
      take = 0;
      if (vld && (got != 1 || cyc > t0 + 200)) begin
        if (blk !== expv[got]) begin errs++; $display("MISMATCH block %0d got %h exp %h", got, blk, expv[got]); end
        else $display("block %0d ok at cycle %0d", got, cyc - t0);
        take = 1; got++;
      end
      if (cyc > t0 + 2000) begin $display("TIMEOUT"); errs++; got = 99; end
    end
    @(posedge clk); #1 take = 0;
    $display("RESULT Q=%0d R=%0d errors=%0d", QN, RC, errs);
    $finish;
  end
endmodule
