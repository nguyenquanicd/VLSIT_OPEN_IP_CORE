//      // verilator_coverage annotation
        // tb_hseq.sv - checks the hash stream sequencer m_vlsit_dsig_hseq against digests made by hashlib
        // (models/hash/gen_hseq_vec.py). Message chunking and the valid and ready gaps are random.
        // Usage: vvp tb_hseq.vvp +VEC=<vector file> [+SEED=n]
        `timescale 1ns/1ps
        
        module tb_hseq;
          reg clk;
          reg rst_n;
          reg clr;
          reg job_start;
          reg [3:0] job_mode;
          reg [15:0] job_outlen;
          reg in_valid;
          reg [63:0] in_data;
          reg [3:0] in_nb;
          reg in_last;
          wire in_ready;
          wire out_valid;
          wire [63:0] out_data;
          wire [3:0] out_nb;
          wire out_last;
          reg out_ready;
          wire busy;
        
          m_vlsit_dsig_hseq dut (
            .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr),
            .i_job_start(job_start), .i_job_mode(job_mode), .i_job_outlen(job_outlen),
            .i_in_valid(in_valid), .i_in_data(in_data), .i_in_nb(in_nb), .i_in_last(in_last), .o_in_ready(in_ready),
            .o_out_valid(out_valid), .o_out_data(out_data), .o_out_nb(out_nb), .o_out_last(out_last), .i_out_ready(out_ready),
            .o_busy(busy)
          );
        
~126745   initial begin clk = 0; forever #5 clk = ~clk; end
        
          integer fd, rc, n_vec, n_fail, seed;
          integer v_n, v_mode, v_len, v_outlen;
          reg [8*2100-1:0] v_hex;
          reg [8*2100-1:0] got_hex;
          reg [7:0] exp_b;
          integer pos, nb, k, gotn, guard;
          reg [8*200-1:0] vecpath;
        
 095746   function [7:0] pat(input integer n, input integer i);
 095746     begin pat = (i * 7 + n * 13 + 5) % 256; end
          endfunction
        
 111348   function integer rnd(input integer m);
 111348     begin rnd = $unsigned($random(seed)) % m; end
          endfunction
        
 000493   task run_vec;
 000493     integer sent, chunk, d;
 000493     reg [63:0] w;
 000493     reg lastf;
 000493     begin
 000493       @(posedge clk); #1;
 000493       job_mode = v_mode; job_outlen = v_outlen; job_start = 1;
 000493       @(posedge clk); #1; job_start = 0;
 000493       sent = 0; gotn = 0; got_hex = 0; guard = 0;
              // The input and the output run together: the output appears only after the last input word
 060904       while (gotn < v_outlen && guard < 200000) begin
 060904         guard = guard + 1;
 060904         in_valid = 0; in_last = 0; in_nb = 0; in_data = 0;
 032122         if (sent <= v_len && !(sent == v_len + 1)) begin
 021662           if (rnd(4) != 0 && sent < v_len + 1) begin
 021662             chunk = 1 + rnd(8);
 021025             if (sent + chunk > v_len) chunk = v_len - sent;
 021662             lastf = (sent + chunk == v_len);
 021662             w = 0;
 095746             for (k = 0; k < chunk; k = k + 1) w[8*k +: 8] = pat(v_n, sent + k);
 021662             in_valid = 1; in_data = w; in_nb = chunk; in_last = lastf;
                  end
                end
 060904         out_ready = (rnd(4) != 0);
 060904         @(posedge clk);
                // sample before the edge effects: values seen at this edge
 046580         if (in_valid && in_ready) begin
 014324           sent = sent + in_nb;
 013831           if (in_last) sent = v_len + 1;   // message complete
                end
 054727         if (out_valid && out_ready) begin
 048459           for (k = 0; k < out_nb; k = k + 1) begin
 048459             got_hex = {got_hex[8*2100-9:0], out_data[8*k +: 8]};
                  end
 006177           gotn = gotn + out_nb;
                end
 060904         #1;
              end
 000493       in_valid = 0; out_ready = 0;
 001479       repeat (3) @(posedge clk);
            end
          endtask
        
          // Debug trace of the block that goes to the engine (+DBG)
          reg dbg;
 000001   initial dbg = $test$plusargs("DBG");
~063373   always @(posedge clk) if (dbg && dut.w_eng_start)
%000000     $display("%0t eng start fam=%0d state=%0d blk[127:0]=%032x blk[1023:896]=%032x state[63:0]=%016x", $time, dut.w_fam, dut.reg_fsm_hseq_current_state, dut.w_eng_block[127:0], dut.w_eng_block[1023:896], dut.w_eng_state[63:0]);
~063373   always @(posedge clk) if (dbg && dut.o_out_valid && dut.i_out_ready)
%000000     $display("%0t out word=%016x nb=%0d cnt=%0d state[63:0]=%016x fam=%0d", $time, dut.o_out_data, dut.o_out_nb, dut.reg_out_cnt, dut.reg_state[63:0], dut.w_fam);
~063373   always @(posedge clk) if (dbg && dut.w_eng_done && dut.reg_fsm_hseq_current_state != 4'd0)
%000000     $display("%0t eng done res[63:0]=%016x", $time, dut.w_eng_result[63:0]);
        
 000001   initial begin : main
 000001     reg [8*4200-1:0] line;
 000001     integer ok_n;
 000001     reg [8*2100-1:0] hx;
 000001     reg [7:0] c;
 000001     integer j, ok, eb, gb, hv;
 000001     seed = 7;
~000001     if (!$value$plusargs("SEED=%d", seed)) seed = 7;
~000001     if (!$value$plusargs("VEC=%s", vecpath)) vecpath = "hseq_vec.txt";
 000001     clr = 0; rst_n = 0; job_start = 0; job_mode = 0; job_outlen = 0; in_valid = 0; in_data = 0; in_nb = 0; in_last = 0; out_ready = 0;
 000004     repeat (4) @(posedge clk); #1; rst_n = 1;
 000001     fd = $fopen(vecpath, "r");
~000001     if (fd == 0) begin $display("RESULT: FAIL (no vector file)"); $finish; end
 000001     n_vec = 0; n_fail = 0;
 000493     while (!$feof(fd)) begin
 000493       rc = $fscanf(fd, "%d %d %d %d %s\n", v_n, v_mode, v_len, v_outlen, v_hex);
~000493       if (rc == 5) begin
 000493         run_vec;
                // v_hex is a string of 2*outlen hex characters, first character in the highest byte
 000493         ok = (gotn == v_outlen);
 048459         for (j = 0; j < v_outlen; j = j + 1) begin
 048459           c = v_hex[8*(2*v_outlen - 1 - 2*j) +: 8];
 048459           hv = (c >= "a") ? (c - "a" + 10) : (c - "0");
 048459           eb = hv * 16;
 048459           c = v_hex[8*(2*v_outlen - 2 - 2*j) +: 8];
 048459           hv = (c >= "a") ? (c - "a" + 10) : (c - "0");
 048459           eb = eb + hv;
 048459           gb = got_hex[8*(v_outlen - 1 - j) +: 8];
~048459           if (eb != gb) ok = 0;
                end
 000493         n_vec = n_vec + 1;
~000493         if (!ok) begin
%000000           n_fail = n_fail + 1;
%000000           if (n_fail <= 8) $display("FAIL vector %0d mode %0d len %0d outlen %0d (got %0d bytes)", v_n, v_mode, v_len, v_outlen, gotn);
%000000           if (n_fail <= 2) begin $display("  expected %0s", v_hex); $write("  got      "); for (j = 0; j < v_outlen; j = j + 1) $write("%02x", got_hex[8*(v_outlen - 1 - j) +: 8]); $display(""); end
                end
              end
            end
 000001     $display("hseq: %0d vectors, %0d failed", n_vec, n_fail);
~000001     if (n_fail == 0 && n_vec > 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
 000001     $finish;
          end
        endmodule
        
