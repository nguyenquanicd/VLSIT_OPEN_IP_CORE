// tb_mmul.sv - test of the Montgomery multiplier m_vlsit_dsig_mmul against Python integers (models/ec/gen_mmul_vec.py): result
// r = a b 2^(-w nd) mod m and the cycle count nd + 1 (start pulse to done pulse) for every vector. +VEC=<file>; the build
// sets the digit width with -DTB_W=<32|64|128>; vectors of another width are skipped.
`timescale 1ns/1ps
`ifndef TB_W
  `define TB_W 64
`endif
module tb_mmul;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0, start = 0;
  reg [575:0] a, b, m; reg [127:0] mp; reg [4:0] nd;
  wire done; wire [575:0] r;
  m_vlsit_dsig_mmul #(.PARA_MUL_W(`TB_W)) dut (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(1'b0), .i_start(start), .i_a(a), .i_b(b),
    .i_m(m), .i_mp(mp), .i_nd(nd), .o_done(done), .o_r(r));
  integer fd, rc, w, ndi, n = 0, nfail = 0, cyc;
  reg [575:0] er;
  reg [8*200-1:0] path;
  initial begin
    if (!$value$plusargs("VEC=%s", path)) path = "mmul_vec.txt";
    fd = $fopen(path, "r");
    repeat (3) @(posedge clk); #1 rst_n = 1;
    while (!$feof(fd)) begin
      rc = $fscanf(fd, "%d %d %h %h %h %h %h\n", w, ndi, m, mp, a, b, er);
      if (rc == 7 && w == `TB_W) begin
        nd = ndi[4:0];
        @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
        cyc = 1; #1; while (!done) begin @(posedge clk); #1; cyc = cyc + 1; end
        n = n + 1;
        if (r !== er || cyc != ndi + 1) begin
          nfail = nfail + 1;
          if (nfail < 5) $display("FAIL vector %0d: r %h expected %h, %0d cycles (expected %0d)", n, r[63:0], er[63:0], cyc, ndi + 1);
        end
      end
    end
    $display("tb_mmul: w %0d, %0d vectors, %0d failed", `TB_W, n, nfail);
    if (nfail == 0 && n > 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
