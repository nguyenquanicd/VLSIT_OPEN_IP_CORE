// tb_key_rng.sv - directed test of m_vlsit_dsig_key and m_vlsit_dsig_rng (specification: FEAT-015, OP-007,
// REQ-SEC-001, REQ-SEC-005, REQ-SEC-007). Self-checking; prints RESULT: PASS or RESULT: FAIL.
`timescale 1ns/1ps
module tb_key_rng;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg clr = 0;
  // key block
  reg k_start = 0; reg [3:0] k_alg = 0; reg [15:0] k_tmo = 1;
  wire k_done, k_tmo_o, k_req; wire [4:0] k_idx; reg k_valid = 0; reg [31:0] k_data = 0;
  reg [543:0] k_reg = 0; wire [543:0] k_key; wire k_cleared;
  m_vlsit_dsig_key #(.PARA_EN_KEYIF(1), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(2)) ukey (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(k_start), .i_run_alg(k_alg), .i_tmo_key(k_tmo),
    .o_done(k_done), .o_tmo(k_tmo_o), .o_key_req(k_req), .o_key_idx(k_idx), .i_key_valid(k_valid), .i_key_data(k_data),
    .i_key_reg(k_reg), .o_key(k_key), .o_cleared(k_cleared));
  // the fixed sources with both sources built (PARA_KEY_SRC 0: port, 1: registers; section 8, DEC-051), same inputs
  wire p_done, p_req; wire [4:0] p_idx; wire [543:0] p_key;
  wire g_done, g_req; wire [4:0] g_idx; wire [543:0] g_key;
  m_vlsit_dsig_key #(.PARA_EN_KEYIF(1), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(0)) ukey_p (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(k_start), .i_run_alg(k_alg), .i_tmo_key(k_tmo),
    .o_done(p_done), .o_tmo(), .o_key_req(p_req), .o_key_idx(p_idx), .i_key_valid(k_valid), .i_key_data(k_data),
    .i_key_reg(k_reg), .o_key(p_key), .o_cleared());
  m_vlsit_dsig_key #(.PARA_EN_KEYIF(1), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(1)) ukey_g (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(k_start), .i_run_alg(k_alg), .i_tmo_key(k_tmo),
    .o_done(g_done), .o_tmo(), .o_key_req(g_req), .o_key_idx(g_idx), .i_key_valid(k_valid), .i_key_data(k_data),
    .i_key_reg(k_reg), .o_key(g_key), .o_cleared());
  // random block
  reg r_start = 0; reg [15:0] r_tmo = 1; wire r_done, r_tmo_o, r_req; reg r_valid = 0; reg [31:0] r_data = 0; reg reseed = 0;
  wire reseed_clr, r_ready, r_due; wire [767:0] r_pool; wire r_cleared;
  m_vlsit_dsig_rng urng (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(r_start), .i_tmo_ent(r_tmo), .o_done(r_done), .o_tmo(r_tmo_o),
    .o_ent_req(r_req), .i_ent_valid(r_valid), .i_ent_data(r_data), .i_reseed(reseed), .o_reseed_clr(reseed_clr), .o_ready(r_ready), .o_due(r_due),
    .o_pool(r_pool), .o_cleared(r_cleared));

  integer nfail = 0, ncheck = 0, i, w, nw, pulses, t, idx_ok;
  task automatic check(input integer cond, input [8*60-1:0] what);
    begin ncheck = ncheck + 1; if (!cond) begin nfail = nfail + 1; $display("FAIL: %0s (time %0t)", what, $time); end end
  endtask
  function [31:0] word(input integer seed, input integer n); begin word = 32'h9E3779B9 * (seed + 1) + 32'h85EBCA6B * n + n; end endfunction

  // Run one key load from the port: the responder answers each request after "gap" cycles.
  task automatic key_port(input [3:0] alg, input integer words, input integer gap, input integer seed);
    begin
      k_alg = alg;
      @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
      pulses = 0; idx_ok = 1;
      for (w = 0; w < words; w = w + 1) begin
        t = 0;
        while (!k_req && t < 50) begin @(posedge clk); #1 t = t + 1; end
        if (k_idx != w) idx_ok = 0;
        repeat (gap) begin @(posedge clk); #1; end
        k_data = word(seed, w); k_valid = 1; @(posedge clk); #1 k_valid = 0;
      end
      t = 0;
      while (!k_done && t < 50) begin @(posedge clk); #1 t = t + 1; end
    end
  endtask

  task automatic rng_run(input integer gap, input integer seed);
    begin
      @(posedge clk); #1 r_start = 1; @(posedge clk); #1 r_start = 0;
      idx_ok = 1;
      for (w = 0; w < 24; w = w + 1) begin
        t = 0;
        while (!r_req && t < 50) begin @(posedge clk); #1 t = t + 1; end
        repeat (gap) begin @(posedge clk); #1; end
        r_data = word(seed, w); r_valid = 1; @(posedge clk); #1 r_valid = 0;
      end
      t = 0;
      while (!r_done && t < 50) begin @(posedge clk); #1 t = t + 1; end
    end
  endtask

  initial begin : main
    repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk); #1;
    check(k_cleared && r_cleared, "both stores empty after reset");
    // 1. key from the port, word counts per algorithm
    for (i = 0; i < 6; i = i + 1) begin
      case (i)
        0: begin nw = 8;  k_alg = 4'd0; end
        1: begin nw = 15; k_alg = 4'd3; end
        2: begin nw = 8;  k_alg = 4'd5; end
        3: begin nw = 12; k_alg = 4'd6; end
        4: begin nw = 17; k_alg = 4'd7; end
        default: begin nw = 8; k_alg = 4'd8; end
      endcase
      key_port(k_alg, nw, i % 3, i);
      check(k_done, "key port: o_done after the last word");
      check(idx_ok, "key port: word index follows 0..n-1");
      for (w = 0; w < 17; w = w + 1)
        check(k_key[32*w +: 32] == (w < nw ? word(i, w) : 32'd0), "key port: word value and zero above the needed words");
      check(!k_cleared, "key port: store not empty");
      pulse_clr;
      check(k_key == 544'd0 && k_cleared, "key store empty after i_clr");
    end
    // 2. key from the registers (any non-zero register word selects the registers)
    for (w = 0; w < 17; w = w + 1) k_reg[32*w +: 32] = word(77, w);
    k_alg = 4'd6;
    @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
    t = 0; while (!k_done && t < 20) begin @(posedge clk); #1 t = t + 1; end
    check(k_done, "key registers: o_done");
    check(!k_req, "key registers: no request on the port");
    for (w = 0; w < 17; w = w + 1)
      check(k_key[32*w +: 32] == (w < 12 ? word(77, w) : 32'd0), "key registers: P-384 takes 12 words, the rest is masked");
    pulse_clr; k_reg = 544'd0;
    // 3. key timeout: no answer at all, and an answer that stops half way
    k_tmo = 1; k_alg = 4'd0;
    @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
    pulses = 0;
    for (t = 0; t < 1200; t = t + 1) begin @(posedge clk); #1 if (k_tmo_o) pulses = pulses + 1; end
    check(pulses == 1, "key timeout: exactly one o_tmo pulse, no answer");
    check(!k_done, "key timeout: no o_done");
    check(k_cleared, "key timeout: store empty");
    @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
    for (w = 0; w < 4; w = w + 1) begin
      t = 0; while (!k_req && t < 20) begin @(posedge clk); #1 t = t + 1; end
      k_data = 32'hA5A5_0000 + w; k_valid = 1; @(posedge clk); #1 k_valid = 0;
    end
    check(!k_cleared, "key partial: words are in the store while loading");
    pulses = 0;
    for (t = 0; t < 1200; t = t + 1) begin @(posedge clk); #1 if (k_tmo_o) pulses = pulses + 1; end
    check(pulses == 1, "key partial: one o_tmo pulse");
    check(k_key == 544'd0, "key partial: store cleared by the timeout");
    // 4. random pool
    rng_run(0, 3);
    check(r_done, "rng: o_done after 24 words");
    for (w = 0; w < 24; w = w + 1) check(r_pool[32*w +: 32] == word(3, w), "rng: pool word");
    check(!r_cleared, "rng: pool not empty");
    pulse_clr;
    check(r_pool == 768'd0 && r_cleared, "rng: pool empty after i_clr");
    rng_run(2, 9);
    check(r_done, "rng slow source: o_done");
    for (w = 0; w < 24; w = w + 1) check(r_pool[32*w +: 32] == word(9, w), "rng slow source: pool word");
    pulse_clr;
    @(posedge clk); #1 r_start = 1; @(posedge clk); #1 r_start = 0;
    pulses = 0;
    for (t = 0; t < 1200; t = t + 1) begin @(posedge clk); #1 if (r_tmo_o) pulses = pulses + 1; end
    check(pulses == 1, "rng timeout: one o_tmo pulse");
    check(!r_done, "rng timeout: no o_done");
    check(r_cleared, "rng timeout: pool empty");
    // 5. reseed command is taken at once, the generator is always ready
    reseed = 1; #1; check(reseed_clr, "rng: reseed command cleared at once"); reseed = 0;
    check(r_ready && !r_due, "rng: ready and not due");
    // 6. clear in the middle of a load
    k_alg = 4'd0;
    @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
    for (w = 0; w < 3; w = w + 1) begin
      t = 0; while (!k_req && t < 20) begin @(posedge clk); #1 t = t + 1; end
      k_data = 32'h1234_0000 + w; k_valid = 1; @(posedge clk); #1 k_valid = 0;
    end
    pulse_clr;
    check(k_key == 544'd0 && !k_req && !k_done, "key: clear in the middle of a load stops it and empties the store");
    // 7. fixed source with both built: register words not zero; source 0 still asks the port, source 1 never does
    for (w = 0; w < 17; w = w + 1) k_reg[32*w +: 32] = word(55, w);
    k_alg = 4'd0;
    @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
    pulses = 0; idx_ok = 1;
    for (w = 0; w < 8; w = w + 1) begin
      t = 0; while (!p_req && t < 50) begin @(posedge clk); #1 if (g_req) pulses = pulses + 1; t = t + 1; end
      if (p_idx != w) idx_ok = 0;
      k_data = word(66, w); k_valid = 1; @(posedge clk); #1 k_valid = 0; if (g_req) pulses = pulses + 1;
    end
    t = 0; while (!p_done && t < 50) begin @(posedge clk); #1 t = t + 1; end
    check(idx_ok, "KEY_SRC 0: port asked for words 0..7, registers set");
    for (w = 0; w < 17; w = w + 1)
      check(p_key[32*w +: 32] == (w < 8 ? word(66, w) : 32'd0), "KEY_SRC 0: key from the port words");
    check(pulses == 0, "KEY_SRC 1: no request on the port");
    for (w = 0; w < 17; w = w + 1)
      check(g_key[32*w +: 32] == (w < 8 ? word(55, w) : 32'd0), "KEY_SRC 1: key from the register words");
    pulse_clr; k_reg = 544'd0;
    check(p_key == 544'd0 && g_key == 544'd0, "KEY_SRC 0 and 1: store empty after i_clr");
    $display("tb_key_rng: %0d checks, %0d failed", ncheck, nfail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end

  task automatic pulse_clr;
    begin @(posedge clk); #1 clr = 1; @(posedge clk); #1 clr = 0; @(posedge clk); #1; end
  endtask
endmodule
