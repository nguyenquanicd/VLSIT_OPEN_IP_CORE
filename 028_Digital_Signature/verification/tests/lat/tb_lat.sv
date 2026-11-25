// tb_lat.sv - RTL test of m_vlsit_dsig_lat with the real hash arbiter, sequencer and cores and a behavioral buffer of 64 KB.
// Vectors from gen_lat_vec.py (OpenSSL 3.5 or later: public keys, deterministic signatures, valid signatures; the reference model for
// the hedged signature). Plusargs: +DIR=<vector directory> +NVEC=<count> +FIRST=<first index> +MAXCYC=<cycles per operation>.
`timescale 1ns/1ps
module tb_lat;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg clr = 0, start = 0, vas_start = 0;
  reg [3:0] alg = 0; reg [1:0] op_op = 0, form = 0; reg hedged = 0; reg [2:0] hsh = 0;
  reg [31:0] len_msg = 0; reg [7:0] len_ctx = 0; reg [16:0] off_msg = 0, off_sig = 0, off_pk = 0, off_res = 0;
  reg [543:0] key = 0; reg [767:0] pool = 0;
  wire busy, done, err, sigok, vas_done, vas_ok, cleared; wire [11:0] err_flags;
  wire rd_en, wr_en; wire [12:0] rd_addr, wr_addr; reg [63:0] rd_data = 0; reg rd_valid = 0; wire [63:0] wr_data; wire [7:0] wr_strb;
  wire hs_req, hs_start, hs_in_valid, hs_in_last, hs_out_ready; wire [3:0] hs_mode, hs_in_nb; wire [15:0] hs_outlen; wire [63:0] hs_in_data;
  wire [0:0] g, ir, ov, ol; wire [63:0] od; wire [3:0] onb;
  wire s_job_start, s_in_valid, s_in_last, s_out_ready, s_in_ready, s_out_valid, s_out_last; wire [3:0] s_mode, s_in_nb, s_out_nb; wire [15:0] s_outlen; wire [63:0] s_in_data, s_out_data;

  m_vlsit_dsig_lat #(.PARA_WA(13)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(start), .i_vas_start(vas_start), .i_run_alg(alg), .i_run_op(op_op),
    .i_run_form(form), .i_run_hedged(hedged), .i_run_hash(hsh), .i_run_len_msg(len_msg), .i_run_len_ctx(len_ctx),
    .i_run_off_msg(off_msg), .i_run_off_sig(off_sig), .i_run_off_pk(off_pk), .i_run_off_res(off_res),
    .o_busy(busy), .o_done(done), .o_err(err), .o_err_flags(err_flags), .o_sigok(sigok), .o_vas_done(vas_done), .o_vas_ok(vas_ok), .o_cleared(cleared),
    .i_key(key), .i_pool(pool),
    .o_rd_en(rd_en), .o_rd_addr(rd_addr), .i_rd_data(rd_data), .i_rd_valid(rd_valid),
    .o_wr_en(wr_en), .o_wr_addr(wr_addr), .o_wr_data(wr_data), .o_wr_strb(wr_strb),
    .o_hs_req(hs_req), .i_hs_grant(g[0]), .o_hs_start(hs_start), .o_hs_mode(hs_mode), .o_hs_outlen(hs_outlen),
    .o_hs_in_valid(hs_in_valid), .o_hs_in_data(hs_in_data), .o_hs_in_nb(hs_in_nb), .o_hs_in_last(hs_in_last),
    .i_hs_in_ready(ir[0]), .i_hs_out_valid(ov[0]), .i_hs_out_data(od), .i_hs_out_nb(onb), .i_hs_out_last(ol[0]), .o_hs_out_ready(hs_out_ready));
  m_vlsit_dsig_harb #(.PARA_NREQ(1)) arb (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_req(hs_req), .i_job_start(hs_start), .i_job_mode(hs_mode), .i_job_outlen(hs_outlen),
    .i_in_valid(hs_in_valid), .i_in_data(hs_in_data), .i_in_nb(hs_in_nb), .i_in_last(hs_in_last), .i_out_ready(hs_out_ready),
    .o_grant(g), .o_in_ready(ir), .o_out_valid(ov), .o_out_data(od), .o_out_nb(onb), .o_out_last(ol),
    .o_job_start(s_job_start), .o_job_mode(s_mode), .o_job_outlen(s_outlen), .o_in_valid(s_in_valid), .o_in_data(s_in_data), .o_in_nb(s_in_nb), .o_in_last(s_in_last),
    .i_in_ready(s_in_ready), .i_out_valid(s_out_valid), .i_out_data(s_out_data), .i_out_nb(s_out_nb), .i_out_last(s_out_last), .o_out_ready(s_out_ready));
  m_vlsit_dsig_hseq sq (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_job_start(s_job_start), .i_job_mode(s_mode), .i_job_outlen(s_outlen),
    .i_in_valid(s_in_valid), .i_in_data(s_in_data), .i_in_nb(s_in_nb), .i_in_last(s_in_last), .o_in_ready(s_in_ready),
    .o_out_valid(s_out_valid), .o_out_data(s_out_data), .o_out_nb(s_out_nb), .o_out_last(s_out_last), .i_out_ready(s_out_ready), .o_busy());

  // Behavioral buffer: 64 KB, read data one cycle after the request, byte-lane writes
  reg [7:0] bmem [0:65535];
  integer q;
  always @(posedge clk) begin
    rd_valid <= rd_en;
    if (rd_en) for (q = 0; q < 8; q = q + 1) rd_data[8*q +: 8] <= bmem[8 * rd_addr + q];
    if (wr_en) for (q = 0; q < 8; q = q + 1) if (wr_strb[q]) bmem[8 * wr_addr + q] <= wr_data[8*q +: 8];
  end

  integer proto_fail = 0;
  always @(posedge clk) if (rst_n) begin
    if (done && err) begin proto_fail = proto_fail + 1; $display("PROTO: done and err together"); end
    if ((done || err || vas_done) && !busy) begin proto_fail = proto_fail + 1; $display("PROTO: result pulse while idle"); end
    if (rd_en && wr_en) begin proto_fail = proto_fail + 1; $display("PROTO: read and write in one cycle"); end
  end

  reg [7:0] expb [0:8191];
  integer nvec, first, maxcyc, i, j, fd, rc, nfail, cyc, ok, zf, wait_clr;
  integer v_i, v_alg, v_op, v_hd, v_lm, v_lc, v_om, v_os, v_op2, v_or, v_ok, v_el, v_vas, v_nb;
  reg [8*80-1:0] keyhex, poolhex;
  reg [8*200-1:0] dir, path;
  reg [7:0] hb;

  function [7:0] hexbyte(input [8*80-1:0] s, input integer pos, input integer len);
    // character pos (0-based from the left) of a string of len characters held right-aligned
    reg [7:0] c1, c2; integer v1, v2;
    begin
      c1 = s[8*(len - 1 - 2*pos) +: 8]; c2 = s[8*(len - 2 - 2*pos) +: 8];
      v1 = (c1 >= "a") ? (c1 - "a" + 10) : (c1 - "0"); v2 = (c2 >= "a") ? (c2 - "a" + 10) : (c2 - "0");
      hexbyte = v1 * 16 + v2;
    end
  endfunction

  task automatic wait_result;
    begin
      cyc = 0;
      while (!(done || err || vas_done) && cyc < maxcyc) begin @(posedge clk); #1 cyc = cyc + 1; end
      if (cyc >= maxcyc) cyc = -1;
    end
  endtask

  integer klen, plen;
  initial begin : main
    if (!$value$plusargs("DIR=%s", dir)) dir = "vec";
    if (!$value$plusargs("NVEC=%d", nvec)) nvec = 1;
    if (!$value$plusargs("FIRST=%d", first)) first = 0;
    if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 120000000;
    nfail = 0;
    repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk);
    // the word RAM is empty at power-up only after a clear: the control block clears at the end of every operation
    #1 clr = 1; wait_clr = 0; while (!cleared && wait_clr < 100000) begin @(posedge clk); #1 wait_clr = wait_clr + 1; end
    clr = 0; repeat (3) @(posedge clk); #1;
    if (!cleared || wait_clr > 40000) begin nfail = nfail + 1; $display("initial clear did not finish (%0d cycles)", wait_clr); end
    $sformat(path, "%0s/lat_vecs.txt", dir);
    fd = $fopen(path, "r");
    for (i = 0; i < nvec + first; i = i + 1) begin
      rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %s %s\n", v_i, v_alg, v_op, v_hd, v_lm, v_lc, v_om, v_os, v_op2, v_or, v_ok, v_el, v_vas, v_nb, keyhex, poolhex);
      if (rc != 16) begin $display("vector list ended at %0d (rc %0d)", i, rc); $finish; end
      if (i >= first) begin
        ok = 1;
        $sformat(path, "%0s/lat_v%0d.hex", dir, v_i);
        $readmemh(path, bmem);
        $sformat(path, "%0s/lat_e%0d.hex", dir, v_i);
        $readmemh(path, expb);
        for (j = 16384; j < 16384 + 5000; j = j + 1) bmem[j] = 8'd0;
        // key and pool bytes from the hex strings
        klen = 0; while (klen < 80 && keyhex[8*klen +: 8] != 0) klen = klen + 1;
        plen = 0; while (plen < 80 && poolhex[8*plen +: 8] != 0) plen = plen + 1;
        key = 0; pool = 0;
        for (j = 0; j < klen / 2; j = j + 1) key[8*j +: 8] = hexbyte(keyhex, j, klen);
        for (j = 0; j < plen / 2; j = j + 1) pool[8*j +: 8] = hexbyte(poolhex, j, plen);
        alg = v_alg; op_op = v_op[1:0]; hedged = v_hd[0]; len_msg = v_lm; len_ctx = v_lc;
        off_msg = v_om; off_sig = v_os; off_pk = v_op2; off_res = v_or; form = v_hd[2:1]; hsh = v_hd[5:3];
        @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
        wait_result;
        if (cyc < 0) begin ok = 0; $display("VEC %0d TIMEOUT", v_i); end
        else begin
          if (err) begin ok = 0; $display("VEC %0d: error flags %0h", v_i, err_flags); end
          else if (v_op == 2) begin
            if (sigok != v_ok[0]) begin ok = 0; $display("VEC %0d: sigok %0b, expected %0d", v_i, sigok, v_ok); end
          end else begin
            for (j = 0; j < v_el; j = j + 1) begin
              if (bmem[off_res + j] != expb[j]) begin ok = 0; $display("VEC %0d: result byte %0d is %02x, expected %02x", v_i, j, bmem[off_res + j], expb[j]); j = v_el; end
            end
            if (v_vas) begin
              @(posedge clk); #1 vas_start = 1; @(posedge clk); #1 vas_start = 0;
              wait_result;
              if (cyc < 0) begin ok = 0; $display("VEC %0d VAS TIMEOUT", v_i); end
              else if (!vas_done || !vas_ok) begin ok = 0; $display("VEC %0d: verify-after-sign vas_done %0b vas_ok %0b", v_i, vas_done, vas_ok); end
              else begin
                // the same data with one signature byte flipped must fail
                bmem[off_res + 100] = bmem[off_res + 100] ^ 8'h01;
                @(posedge clk); #1 vas_start = 1; @(posedge clk); #1 vas_start = 0;
                wait_result;
                if (cyc < 0) begin ok = 0; $display("VEC %0d VAS2 TIMEOUT", v_i); end
                else if (!vas_done || vas_ok) begin ok = 0; $display("VEC %0d: verify-after-sign accepts a corrupted signature", v_i); end
              end
            end
          end
        end
        // clear, wait for the empty flag, and check the word RAM
        @(posedge clk); #1 clr = 1; wait_clr = 0;
        while (!cleared && wait_clr < 100000) begin @(posedge clk); #1 wait_clr = wait_clr + 1; end
        clr = 0; repeat (3) @(posedge clk); #1;
        zf = 0;
        for (j = 0; j < 32768; j = j + 1) if (dut.reg_wram[j] != 32'd0) zf = zf + 1;
        for (j = 0; j < 32; j = j + 1) if (dut.reg_rf[j] != 32'd0) zf = zf + 1;
        if (zf != 0 || !cleared || busy) begin ok = 0; $display("VEC %0d: not zeroized after clear (%0d, flag %0b)", v_i, zf, cleared); end
        if (!ok) nfail = nfail + 1;
        $display("VEC %0d %s cycles=%0d clear=%0d", v_i, ok ? "PASS" : "FAIL", cyc, wait_clr);
      end
    end
    if (proto_fail != 0) nfail = nfail + 1;
    $display("tb_lat: %0d vectors, %0d failed, %0d protocol failures", nvec, nfail, proto_fail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
