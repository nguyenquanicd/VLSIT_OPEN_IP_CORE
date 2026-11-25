// tb_hbs.sv - RTL test of m_vlsit_dsig_hbs with the real hash arbiter, sequencer and cores and a behavioral buffer
// of 64 KB. The vectors are made by gen_hbs_vec.py (SLH-DSA signatures from OpenSSL, LMS/HSS and XMSS from the
// reference signers, corrupted inputs). Plusargs: +DIR=<vector directory> +NVEC=<count> +FIRST=<first index>
// +MAXCYC=<cycles per operation>.
`timescale 1ns/1ps
module tb_hbs;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg clr = 0, start = 0;
  reg [3:0] alg = 0, slh = 0, lmots = 0, hsslvl = 0; reg [4:0] lmstype = 0; reg [5:0] xmss = 0; reg [1:0] form = 0; reg [2:0] hsh = 0;
  reg [31:0] len_msg = 0; reg [7:0] len_ctx = 0; reg [16:0] off_msg = 0, off_sig = 0, off_pk = 0;
  wire busy, done, err, sigok, cleared; wire [11:0] err_flags;
  wire rd_en; wire [12:0] rd_addr; reg [63:0] rd_data = 0; reg rd_valid = 0;
  wire hs_req, hs_start, hs_in_valid, hs_in_last, hs_out_ready; wire [3:0] hs_mode, hs_in_nb; wire [15:0] hs_outlen; wire [63:0] hs_in_data;
  wire [0:0] g, ir, ov, ol; wire [63:0] od; wire [3:0] onb;
  wire s_job_start, s_in_valid, s_in_last, s_out_ready, s_in_ready, s_out_valid, s_out_last; wire [3:0] s_mode, s_in_nb, s_out_nb; wire [15:0] s_outlen; wire [63:0] s_in_data, s_out_data;

  m_vlsit_dsig_hbs #(.PARA_WA(13)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(start), .i_run_alg(alg), .i_run_form(form), .i_run_hash(hsh), .i_run_slh(slh),
    .i_run_lmstype(lmstype), .i_run_lmots(lmots), .i_run_hsslvl(hsslvl), .i_run_xmss(xmss), .i_run_len_msg(len_msg), .i_run_len_ctx(len_ctx),
    .i_run_off_msg(off_msg), .i_run_off_sig(off_sig), .i_run_off_pk(off_pk),
    .o_busy(busy), .o_done(done), .o_err(err), .o_err_flags(err_flags), .o_sigok(sigok), .o_cleared(cleared),
    .o_rd_en(rd_en), .o_rd_addr(rd_addr), .i_rd_data(rd_data), .i_rd_valid(rd_valid),
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

  // Behavioral buffer: 64 KB, read data one cycle after the request
  reg [7:0] bmem [0:65535];
  integer q;
  always @(posedge clk) begin
    rd_valid <= rd_en;
    if (rd_en) for (q = 0; q < 8; q = q + 1) rd_data[8*q +: 8] <= bmem[8 * rd_addr + q];
  end

  integer proto_fail = 0;
  always @(posedge clk) if (rst_n) begin
    if (done && err) begin proto_fail = proto_fail + 1; $display("PROTO: done and err together"); end
    if ((done || err) && !busy) begin proto_fail = proto_fail + 1; $display("PROTO: result pulse while idle"); end
  end

  integer nvec, first, maxcyc, i, fd, rc, nfail, cyc, ok, tot, zf;
  integer v_i, v_alg, v_slh, v_lt, v_lo, v_hl, v_x, v_lm, v_lc, v_om, v_os, v_op, v_ok, v_nb;
  reg [8*200-1:0] dir, path;

  initial begin : main
    if (!$value$plusargs("DIR=%s", dir)) dir = "vec";
    if (!$value$plusargs("NVEC=%d", nvec)) nvec = 1;
    if (!$value$plusargs("FIRST=%d", first)) first = 0;
    if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 40000000;
    nfail = 0;
    repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk);
    $sformat(path, "%0s/hbs_vecs.txt", dir);
    fd = $fopen(path, "r");
    for (i = 0; i < nvec + first; i = i + 1) begin
      rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", v_i, v_alg, v_slh, v_lt, v_lo, v_hl, v_x, v_lm, v_lc, v_om, v_os, v_op, v_ok, v_nb);
      if (rc != 14) begin $display("vector list ended at %0d", i); $finish; end
      if (i >= first) begin
        ok = 1;
        $sformat(path, "%0s/hbs_v%0d.hex", dir, v_i);
        $readmemh(path, bmem);
        alg = v_alg; slh = v_slh[3:0]; lmstype = v_lt; lmots = v_lo; hsslvl = v_hl; xmss = v_x; len_msg = v_lm; len_ctx = v_lc;
        off_msg = v_om; off_sig = v_os; off_pk = v_op; form = v_slh[5:4]; hsh = v_slh[8:6];
        @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
        cyc = 0;
        while (!(done || err) && cyc < maxcyc) begin @(posedge clk); #1 cyc = cyc + 1; end
        if (cyc >= maxcyc) begin ok = 0; $display("VEC %0d TIMEOUT", v_i); end
        else begin
          if (err) begin ok = 0; $display("VEC %0d: error flags %0h", v_i, err_flags); end
          else if (sigok != v_ok[0]) begin ok = 0; $display("VEC %0d: sigok %0b, expected %0d", v_i, sigok, v_ok); end
        end
        // clear and the zeroization check
        @(posedge clk); #1 clr = 1; @(posedge clk); #1 clr = 0; @(posedge clk); #1;
        zf = 0;
        for (q = 0; q < 32; q = q + 1) if (dut.reg_rf[q] != 64'd0) zf = zf + 1;
        if (dut.reg_head != 2048'd0) zf = zf + 1;
        if (zf != 0 || !cleared || busy) begin ok = 0; $display("VEC %0d: not zeroized after clear (%0d)", v_i, zf); end
        if (!ok) nfail = nfail + 1;
        $display("VEC %0d %s cycles=%0d", v_i, ok ? "PASS" : "FAIL", cyc);
      end
    end
    if (proto_fail != 0) nfail = nfail + 1;
    $display("tb_hbs: %0d vectors, %0d failed, %0d protocol failures", nvec, nfail, proto_fail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
