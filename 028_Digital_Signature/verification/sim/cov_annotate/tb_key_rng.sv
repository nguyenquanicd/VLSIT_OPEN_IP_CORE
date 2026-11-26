//      // verilator_coverage annotation
        // tb_key_rng.sv - directed test of m_vlsit_dsig_key and m_vlsit_dsig_rng (specification: FEAT-015, OP-007,
        // REQ-SEC-001, REQ-SEC-005, REQ-SEC-007). Self-checking; prints RESULT: PASS or RESULT: FAIL.
        `timescale 1ns/1ps
        module tb_key_rng;
 007821   reg clk = 0; always #5 clk = ~clk;
 000001   reg rst_n = 0;
 000001   reg clr = 0;
          // key block
 000001   reg k_start = 0; reg [3:0] k_alg = 0; reg [15:0] k_tmo = 1;
 000001   wire k_done, k_tmo_o, k_req; wire [4:0] k_idx; reg k_valid = 0; reg [31:0] k_data = 0;
 000001   reg [543:0] k_reg = 0; wire [543:0] k_key; wire k_cleared;
          m_vlsit_dsig_key #(.PARA_EN_KEYIF(1), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(2)) ukey (
            .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(k_start), .i_run_alg(k_alg), .i_tmo_key(k_tmo),
            .o_done(k_done), .o_tmo(k_tmo_o), .o_key_req(k_req), .o_key_idx(k_idx), .i_key_valid(k_valid), .i_key_data(k_data),
            .i_key_reg(k_reg), .o_key(k_key), .o_cleared(k_cleared));
          // the fixed sources with both sources built (PARA_KEY_SRC 0: port, 1: registers; section 8, ASM-028), same inputs
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
 000001   reg r_start = 0; reg [15:0] r_tmo = 1; wire r_done, r_tmo_o, r_req; reg r_valid = 0; reg [31:0] r_data = 0; reg reseed = 0;
          wire reseed_clr, r_ready, r_due; wire [767:0] r_pool; wire r_cleared;
          m_vlsit_dsig_rng urng (
            .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(r_start), .i_tmo_ent(r_tmo), .o_done(r_done), .o_tmo(r_tmo_o),
            .o_ent_req(r_req), .i_ent_valid(r_valid), .i_ent_data(r_data), .i_reseed(reseed), .o_reseed_clr(reseed_clr), .o_ready(r_ready), .o_due(r_due),
            .o_pool(r_pool), .o_cleared(r_cleared));
        
 000001   integer nfail = 0, ncheck = 0, i, w, nw, pulses, t, idx_ok;
 000247   task automatic check(input integer cond, input [8*60-1:0] what);
~000247     begin ncheck = ncheck + 1; if (!cond) begin nfail = nfail + 1; $display("FAIL: %0s (time %0t)", what, $time); end end
          endtask
 000302   function [31:0] word(input integer seed, input integer n); begin word = 32'h9E3779B9 * (seed + 1) + 32'h85EBCA6B * n + n; end endfunction
        
          // Run one key load from the port: the responder answers each request after "gap" cycles.
 000006   task automatic key_port(input [3:0] alg, input integer words, input integer gap, input integer seed);
 000006     begin
 000006       k_alg = alg;
 000006       @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
 000006       pulses = 0; idx_ok = 1;
 000068       for (w = 0; w < words; w = w + 1) begin
 000068         t = 0;
%000000         while (!k_req && t < 50) begin @(posedge clk); #1 t = t + 1; end
~000068         if (k_idx != w) idx_ok = 0;
 000068         repeat (gap) begin @(posedge clk); #1; end
 000068         k_data = word(seed, w); k_valid = 1; @(posedge clk); #1 k_valid = 0;
              end
 000006       t = 0;
%000000       while (!k_done && t < 50) begin @(posedge clk); #1 t = t + 1; end
            end
          endtask
        
 000002   task automatic rng_run(input integer gap, input integer seed);
 000002     begin
 000002       @(posedge clk); #1 r_start = 1; @(posedge clk); #1 r_start = 0;
 000002       idx_ok = 1;
 000048       for (w = 0; w < 24; w = w + 1) begin
 000048         t = 0;
%000000         while (!r_req && t < 50) begin @(posedge clk); #1 t = t + 1; end
 000048         repeat (gap) begin @(posedge clk); #1; end
 000048         r_data = word(seed, w); r_valid = 1; @(posedge clk); #1 r_valid = 0;
              end
 000002       t = 0;
%000000       while (!r_done && t < 50) begin @(posedge clk); #1 t = t + 1; end
            end
          endtask
        
 000001   initial begin : main
 000004     repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk); #1;
 000001     check(k_cleared && r_cleared, "both stores empty after reset");
            // 1. key from the port, word counts per algorithm
 000006     for (i = 0; i < 6; i = i + 1) begin
 000006       case (i)
 000001         0: begin nw = 8;  k_alg = 4'd0; end
 000001         1: begin nw = 15; k_alg = 4'd3; end
 000001         2: begin nw = 8;  k_alg = 4'd5; end
 000001         3: begin nw = 12; k_alg = 4'd6; end
 000001         4: begin nw = 17; k_alg = 4'd7; end
 000001         default: begin nw = 8; k_alg = 4'd8; end
              endcase
 000006       key_port(k_alg, nw, i % 3, i);
 000006       check(k_done, "key port: o_done after the last word");
 000006       check(idx_ok, "key port: word index follows 0..n-1");
 000102       for (w = 0; w < 17; w = w + 1)
 000102         check(k_key[32*w +: 32] == (w < nw ? word(i, w) : 32'd0), "key port: word value and zero above the needed words");
 000006       check(!k_cleared, "key port: store not empty");
 000006       pulse_clr;
 000006       check(k_key == 544'd0 && k_cleared, "key store empty after i_clr");
            end
            // 2. key from the registers (any non-zero register word selects the registers)
 000017     for (w = 0; w < 17; w = w + 1) k_reg[32*w +: 32] = word(77, w);
 000001     k_alg = 4'd6;
 000001     @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
 000001     t = 0; while (!k_done && t < 20) begin @(posedge clk); #1 t = t + 1; end
 000001     check(k_done, "key registers: o_done");
 000001     check(!k_req, "key registers: no request on the port");
 000017     for (w = 0; w < 17; w = w + 1)
 000017       check(k_key[32*w +: 32] == (w < 12 ? word(77, w) : 32'd0), "key registers: P-384 takes 12 words, the rest is masked");
 000001     pulse_clr; k_reg = 544'd0;
            // 3. key timeout: no answer at all, and an answer that stops half way
 000001     k_tmo = 1; k_alg = 4'd0;
 000001     @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
 000001     pulses = 0;
 001200     for (t = 0; t < 1200; t = t + 1) begin @(posedge clk); #1 if (k_tmo_o) pulses = pulses + 1; end
 000001     check(pulses == 1, "key timeout: exactly one o_tmo pulse, no answer");
 000001     check(!k_done, "key timeout: no o_done");
 000001     check(k_cleared, "key timeout: store empty");
 000001     @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
 000004     for (w = 0; w < 4; w = w + 1) begin
~000004       t = 0; while (!k_req && t < 20) begin @(posedge clk); #1 t = t + 1; end
 000004       k_data = 32'hA5A5_0000 + w; k_valid = 1; @(posedge clk); #1 k_valid = 0;
            end
 000001     check(!k_cleared, "key partial: words are in the store while loading");
 000001     pulses = 0;
 001200     for (t = 0; t < 1200; t = t + 1) begin @(posedge clk); #1 if (k_tmo_o) pulses = pulses + 1; end
 000001     check(pulses == 1, "key partial: one o_tmo pulse");
 000001     check(k_key == 544'd0, "key partial: store cleared by the timeout");
            // 4. random pool
 000001     rng_run(0, 3);
 000001     check(r_done, "rng: o_done after 24 words");
 000024     for (w = 0; w < 24; w = w + 1) check(r_pool[32*w +: 32] == word(3, w), "rng: pool word");
 000001     check(!r_cleared, "rng: pool not empty");
 000001     pulse_clr;
 000001     check(r_pool == 768'd0 && r_cleared, "rng: pool empty after i_clr");
 000001     rng_run(2, 9);
 000001     check(r_done, "rng slow source: o_done");
 000024     for (w = 0; w < 24; w = w + 1) check(r_pool[32*w +: 32] == word(9, w), "rng slow source: pool word");
 000001     pulse_clr;
 000001     @(posedge clk); #1 r_start = 1; @(posedge clk); #1 r_start = 0;
 000001     pulses = 0;
 001200     for (t = 0; t < 1200; t = t + 1) begin @(posedge clk); #1 if (r_tmo_o) pulses = pulses + 1; end
 000001     check(pulses == 1, "rng timeout: one o_tmo pulse");
 000001     check(!r_done, "rng timeout: no o_done");
 000001     check(r_cleared, "rng timeout: pool empty");
            // 5. reseed command is taken at once, the generator is always ready
 000001     reseed = 1; #1; check(reseed_clr, "rng: reseed command cleared at once"); reseed = 0;
 000001     check(r_ready && !r_due, "rng: ready and not due");
            // 6. clear in the middle of a load
 000001     k_alg = 4'd0;
 000001     @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
 000003     for (w = 0; w < 3; w = w + 1) begin
~000003       t = 0; while (!k_req && t < 20) begin @(posedge clk); #1 t = t + 1; end
 000003       k_data = 32'h1234_0000 + w; k_valid = 1; @(posedge clk); #1 k_valid = 0;
            end
 000001     pulse_clr;
 000001     check(k_key == 544'd0 && !k_req && !k_done, "key: clear in the middle of a load stops it and empties the store");
            // 7. fixed source with both built: register words not zero; source 0 still asks the port, source 1 never does
 000017     for (w = 0; w < 17; w = w + 1) k_reg[32*w +: 32] = word(55, w);
 000001     k_alg = 4'd0;
 000001     @(posedge clk); #1 k_start = 1; @(posedge clk); #1 k_start = 0;
 000001     pulses = 0; idx_ok = 1;
 000008     for (w = 0; w < 8; w = w + 1) begin
~000008       t = 0; while (!p_req && t < 50) begin @(posedge clk); #1 if (g_req) pulses = pulses + 1; t = t + 1; end
~000008       if (p_idx != w) idx_ok = 0;
~000008       k_data = word(66, w); k_valid = 1; @(posedge clk); #1 k_valid = 0; if (g_req) pulses = pulses + 1;
            end
~000001     t = 0; while (!p_done && t < 50) begin @(posedge clk); #1 t = t + 1; end
 000001     check(idx_ok, "KEY_SRC 0: port asked for words 0..7, registers set");
 000017     for (w = 0; w < 17; w = w + 1)
 000017       check(p_key[32*w +: 32] == (w < 8 ? word(66, w) : 32'd0), "KEY_SRC 0: key from the port words");
 000001     check(pulses == 0, "KEY_SRC 1: no request on the port");
 000017     for (w = 0; w < 17; w = w + 1)
 000017       check(g_key[32*w +: 32] == (w < 8 ? word(55, w) : 32'd0), "KEY_SRC 1: key from the register words");
 000001     pulse_clr; k_reg = 544'd0;
 000001     check(p_key == 544'd0 && g_key == 544'd0, "KEY_SRC 0 and 1: store empty after i_clr");
 000001     $display("tb_key_rng: %0d checks, %0d failed", ncheck, nfail);
~000001     if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
 000001     $finish;
          end
        
 000011   task automatic pulse_clr;
 000011     begin @(posedge clk); #1 clr = 1; @(posedge clk); #1 clr = 0; @(posedge clk); #1; end
          endtask
        endmodule
        
