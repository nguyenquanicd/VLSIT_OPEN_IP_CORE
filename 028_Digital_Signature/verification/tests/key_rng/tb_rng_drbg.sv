// tb_rng_drbg.sv - RTL test of m_vlsit_dsig_rng with PARA_RNG_SRC = 1 (Hash_DRBG m_vlsit_dsig_drbg, SHA-512) and the real hash
// arbiter, stream sequencer and cores. The expected pools come from models/rng/gen_drbg_vec.py, a Hash_DRBG written from
// NIST SP 800-90A Rev. 1. Checks per request: the entropy port is read exactly when the plan says (instantiate, reseed by the
// counter, reseed by the CSR command), the 96 pool bytes equal the reference, dsig_rng.ready and dsig_rng.due follow the
// generator state, and the clear input empties the pool. Plusarg: +VEC=<file>.
`timescale 1ns/1ps
module tb_rng_drbg;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg clr = 0, start = 0, reseed = 0;
  wire done, tmo, ent_req, reseed_clr, ready, due, cleared;
  reg ent_valid = 0; reg [31:0] ent_data = 0;
  wire [767:0] pool;
  wire hs_req, hs_start, hs_in_valid, hs_in_last, hs_out_ready; wire [3:0] hs_mode, hs_in_nb; wire [15:0] hs_outlen; wire [63:0] hs_in_data;
  wire [0:0] g, ir, ov, ol; wire [63:0] od; wire [3:0] onb;
  wire s_job_start, s_in_valid, s_in_last, s_out_ready, s_in_ready, s_out_valid, s_out_last; wire [3:0] s_mode, s_in_nb, s_out_nb;
  wire [15:0] s_outlen; wire [63:0] s_in_data, s_out_data;

  m_vlsit_dsig_rng #(.PARA_RNG_SRC(1), .PARA_RESEED_INT(3)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(start), .i_tmo_ent(16'd4), .o_done(done), .o_tmo(tmo),
    .o_ent_req(ent_req), .i_ent_valid(ent_valid), .i_ent_data(ent_data), .i_reseed(reseed), .o_reseed_clr(reseed_clr),
    .o_ready(ready), .o_due(due), .o_pool(pool), .o_cleared(cleared),
    .o_hs_req(hs_req), .i_hs_grant(g[0]), .o_hs_start(hs_start), .o_hs_mode(hs_mode), .o_hs_outlen(hs_outlen),
    .o_hs_in_valid(hs_in_valid), .o_hs_in_data(hs_in_data), .o_hs_in_nb(hs_in_nb), .o_hs_in_last(hs_in_last),
    .i_hs_in_ready(ir[0]), .i_hs_out_valid(ov[0]), .i_hs_out_data(od), .i_hs_out_nb(onb), .i_hs_out_last(ol[0]), .o_hs_out_ready(hs_out_ready));
  m_vlsit_dsig_harb #(.PARA_NREQ(1)) arb (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_req(hs_req), .i_job_start(hs_start), .i_job_mode(hs_mode),
    .i_job_outlen(hs_outlen), .i_in_valid(hs_in_valid), .i_in_data(hs_in_data), .i_in_nb(hs_in_nb), .i_in_last(hs_in_last), .i_out_ready(hs_out_ready),
    .o_grant(g), .o_in_ready(ir), .o_out_valid(ov), .o_out_data(od), .o_out_nb(onb), .o_out_last(ol),
    .o_job_start(s_job_start), .o_job_mode(s_mode), .o_job_outlen(s_outlen), .o_in_valid(s_in_valid), .o_in_data(s_in_data), .o_in_nb(s_in_nb),
    .o_in_last(s_in_last), .i_in_ready(s_in_ready), .i_out_valid(s_out_valid), .i_out_data(s_out_data), .i_out_nb(s_out_nb), .i_out_last(s_out_last),
    .o_out_ready(s_out_ready));
  m_vlsit_dsig_hseq sq (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(1'b0), .i_job_start(s_job_start), .i_job_mode(s_mode), .i_job_outlen(s_outlen),
    .i_in_valid(s_in_valid), .i_in_data(s_in_data), .i_in_nb(s_in_nb), .i_in_last(s_in_last), .o_in_ready(s_in_ready),
    .o_out_valid(s_out_valid), .o_out_data(s_out_data), .o_out_nb(s_out_nb), .o_out_last(s_out_last), .i_out_ready(s_out_ready), .o_busy());

  // entropy source: delivers the words of the current entropy set while o_ent_req is high
  reg [767:0] ent_set; integer ent_i = 0, ent_words = 0;
  always @(posedge clk) begin
    // the word on the port is taken at this edge when valid: move to the next word first
    if (ent_req & ent_valid) begin ent_i = ent_i + 1; ent_words = ent_words + 1; end
    if (ent_req) begin
      ent_valid <= 1'b1; ent_data <= ent_set[32*ent_i +: 32];
    end else ent_valid <= 1'b0;
  end

  function [7:0] hexb(input [8*200-1:0] s, input integer pos, input integer len);
    reg [7:0] c1, c2; integer v1, v2;
    begin
      c1 = s[8*(len - 1 - 2*pos) +: 8]; c2 = s[8*(len - 2 - 2*pos) +: 8];
      v1 = (c1 >= "a") ? (c1 - "a" + 10) : (c1 - "0"); v2 = (c2 >= "a") ? (c2 - "a" + 10) : (c2 - "0");
      hexb = v1 * 16 + v2;
    end
  endfunction

  // commands to the Hash_DRBG (health test: 2 seeds and 2 generates before the first real seed)
  integer n_seed = 0, n_gen = 0;
  always @(posedge clk) begin
    if (dut.g_drbg.u_drbg.i_seed) n_seed = n_seed + 1;
    if (dut.g_drbg.u_drbg.i_gen) n_gen = n_gen + 1;
  end

  integer fd, rc, req, seedx, j, nfail = 0, ncheck = 0, cyc;
  reg [8*200-1:0] ehex, phex; reg [767:0] exp_pool;
  task automatic check(input integer cond, input [8*64-1:0] what);
    begin ncheck = ncheck + 1; if (!cond) begin nfail = nfail + 1; $display("FAIL: request %0d: %0s", req, what); end end
  endtask

  initial begin : main
    reg [8*200-1:0] path;
    if (!$value$plusargs("VEC=%s", path)) path = "drbg_vec.txt";
    fd = $fopen(path, "r");
    repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk);
    check(!ready, "not ready before the first seed");
    if ($test$plusargs("KATFAIL")) begin
      // SP 800-90A 11.3.1: a known-answer test that fails puts the generator in an error state; the digest of every hash
      // of the health test is forced to 0, so the expected answer cannot be met
      force dut.g_drbg.u_drbg.w_dig = 512'd0;
      ent_i = 0; ent_words = 0;
      @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
      cyc = 0; while (!done && !tmo && cyc < 200000) begin @(posedge clk); cyc = cyc + 1; end
      req = 0;
      check(tmo && !done, "failed health test: the request ends with o_tmo (dsig_err.enttmo, dsig_alarm.rngfail)");
      release dut.g_drbg.u_drbg.w_dig;
      @(posedge clk); check(!ready, "failed health test: dsig_rng.ready stays 0");
      check(ent_words == 0, "failed health test: the entropy port is not read");
      check(n_seed == 2 && n_gen == 2, "the health test ran instantiate, generate, reseed, generate");
      req = 1; ent_i = 0;
      @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
      cyc = 0; while (!done && !tmo && cyc < 200000) begin @(posedge clk); cyc = cyc + 1; end
      check(tmo && !done && ent_words == 0, "error state kept: the next request fails at once");
      $display("tb_rng_drbg: %0d checks, %0d failed", ncheck, nfail);
      if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
      $finish;
    end
    for (req = 0; req < 6; req = req + 1) begin
      rc = $fscanf(fd, "%d %s %s\n", seedx, ehex, phex);
      if (rc != 3) begin $display("vector file ended"); $finish; end
      if (seedx) for (j = 0; j < 96; j = j + 1) ent_set[8*j +: 8] = hexb(ehex, j, 192);
      for (j = 0; j < 96; j = j + 1) exp_pool[8*j +: 8] = hexb(phex, j, 192);
      if (req == 3) check(due, "dsig_rng.due set when the reseed counter exceeds the interval");
      if (req == 5) begin
        @(posedge clk); #1 reseed = 1; @(posedge clk); #1 reseed = 0;
        @(posedge clk); check(due, "dsig_rng.due set by the reseed command");
      end
      ent_i = 0; ent_words = 0;
      @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
      cyc = 0; while (!done && !tmo && cyc < 200000) begin @(posedge clk); cyc = cyc + 1; end
      check(done, "done pulse");
      @(posedge clk);
      check(ent_words == (seedx ? 24 : 0), "entropy read exactly when the generator is seeded");
      if (req == 0) check(n_seed == 3 && n_gen == 3, "first request: health test (2 seeds, 2 generates), then seed and generate");
      check(pool == exp_pool, "pool equal to the SP 800-90A reference");
      if (pool != exp_pool) $display("  got %h\n  exp %h", pool[127:0], exp_pool[127:0]);
      check(ready, "ready after a seed");
      if (req == 3 || req == 5) check(!due, "due cleared by the reseed");
      $display("request %0d (%0s) %0d cycles", req, seedx ? "seed + generate" : "generate", cyc);
      @(posedge clk); #1 clr = 1; @(posedge clk); #1 clr = 0; @(posedge clk);
      check(pool == 768'd0 && cleared, "clear empties the pool");
    end
    $display("tb_rng_drbg: %0d checks, %0d failed", ncheck, nfail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
