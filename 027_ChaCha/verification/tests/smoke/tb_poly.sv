`timescale 1ns/1ps
module tb_poly;
  parameter ARCH = 1;
  parameter NB = 10;
  parameter string PFX = "rfc";
  logic clk = 0; logic rst_n = 0;
  always #5 clk = ~clk;
  logic clr, otk_vld, blk_vld, fin; logic [255:0] otk; logic [127:0] blk;
  logic rdy, tag_vld, idle; logic [127:0] tag;
  logic [255:0] otk_m [0:0]; logic [127:0] blks [0:255]; logic [132:0] accs [0:255]; logic [127:0] tag_m [0:0];
  m_chacha_poly #(.PARA_POLY_ARCH(ARCH)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_otk_vld(otk_vld), .i_otk(otk),
    .i_blk_vld(blk_vld), .i_blk(blk), .o_blk_rdy(rdy), .i_fin(fin), .o_tag_vld(tag_vld), .o_tag(tag), .o_idle(idle));
  integer errs = 0; integer cyc = 0; integer t_first, t_second;
  always @(posedge clk) cyc <= cyc + 1;
  logic [130:0] a131; logic [131:0] a5; logic [130:0] ared;
  initial begin
    $readmemh({PFX,"_otk.hex"}, otk_m);
    $readmemh({PFX,"_blk.hex"}, blks);
    $readmemh({PFX,"_acc.hex"}, accs);
    $readmemh({PFX,"_tag.hex"}, tag_m);
    clr = 0; otk_vld = 0; blk_vld = 0; fin = 0; otk = 0; blk = 0;
    #25 rst_n = 1;
    @(posedge clk); #1 clr = 1; @(posedge clk); #1 clr = 0;
    otk = otk_m[0]; otk_vld = 1; @(posedge clk); #1 otk_vld = 0;
    for (int i = 0; i < NB; i++) begin
      blk = blks[i];
      blk_vld = 1;
      do @(posedge clk); while (!rdy);
      if (i == 0) t_first = cyc;
      if (i == 1) t_second = cyc;
      #1 blk_vld = 0;
      // wait for completion then compare the reduced accumulator
      @(posedge clk); while (!idle) @(posedge clk);
      #1;
      a131 = dut.gen_arch.u_pmac.o_acc;
      a5 = {1'b0, a131} + 132'd5;
      ared = (a5[131:130] != 0) ? {1'b0, a5[129:0]} : a131;
      if (ared !== accs[i][130:0]) begin errs++; $display("ACC MISMATCH block %0d got %h exp %h", i, ared, accs[i][130:0]); end
    end
    #1 fin = 1; @(posedge clk); #1 fin = 0;
    repeat (4) @(posedge clk);
    if (!tag_vld || tag !== tag_m[0]) begin errs++; $display("TAG MISMATCH got %h exp %h vld %b", tag, tag_m[0], tag_vld); end
    $display("RESULT ARCH=%0d %s blocks=%0d errors=%0d", ARCH, PFX, NB, errs);
    $finish;
  end
  // interval measurement: ready after the first block returns
  initial begin
    wait (tag_vld);
  end
endmodule
