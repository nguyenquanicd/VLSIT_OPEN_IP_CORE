// tb_ec.sv - RTL test of m_vlsit_dsig_ec with the real hash arbiter, sequencer and cores and a behavioral
// buffer. The vectors come from gen_ec_vec.py (RFC 8032 and RFC 6979 vectors, rejections of corrupted
// inputs, textbook group law). Plusargs: +VEC=<hex file> +NVEC=<count> +MAXCYC=<cycles per operation>.
`timescale 1ns/1ps
module tb_ec;
  localparam int BLK = 1024;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg clr, start, vas_start;
  reg [3:0] alg; reg [1:0] op_op; reg [2:0] hsh; reg [31:0] len_msg; reg [7:0] len_ctx;
  reg [543:0] key; reg [767:0] pool;
  wire busy, done, err, sigok, vas_done, vas_ok, cleared; wire [11:0] err_flags;
  wire rd_en, wr_en; wire [6:0] rd_addr, wr_addr; reg [63:0] rd_data; reg rd_valid; wire [63:0] wr_data; wire [7:0] wr_strb;
  wire hs_req, hs_start, hs_in_valid, hs_in_last, hs_out_ready; wire [3:0] hs_mode, hs_in_nb; wire [15:0] hs_outlen; wire [63:0] hs_in_data;
  wire [0:0] g, ir, ov, ol; wire [63:0] od; wire [3:0] onb;
  wire s_job_start, s_in_valid, s_in_last, s_out_ready, s_in_ready, s_out_valid, s_out_last; wire [3:0] s_mode, s_in_nb, s_out_nb; wire [15:0] s_outlen; wire [63:0] s_in_data, s_out_data;

  m_vlsit_dsig_ec #(.PARA_WA(7)) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(clr), .i_start(start), .i_vas_start(vas_start),
    .i_run_alg(alg), .i_run_op(op_op), .i_run_hash(hsh), .i_run_len_msg(len_msg), .i_run_len_ctx(len_ctx),
    .i_run_off_msg(17'd0), .i_run_off_sig(17'd256), .i_run_off_pk(17'd512), .i_run_off_res(17'd768),
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

  // Behavioral buffer: 1024 bytes of 64-bit words, read data one cycle after the request.
  reg [7:0] bmem [0:1023];
  integer q;
  always @(posedge clk) begin
    rd_valid <= rd_en;
    if (rd_en) for (q = 0; q < 8; q = q + 1) rd_data[8*q +: 8] <= bmem[8 * rd_addr + q];
    if (wr_en) for (q = 0; q < 8; q = q + 1) if (wr_strb[q]) bmem[8 * wr_addr + q] <= wr_data[8*q +: 8];
  end

  // Protocol checks on the engine outputs
  integer proto_fail = 0;
  always @(posedge clk) if (rst_n) begin
    if (done && err) begin proto_fail = proto_fail + 1; $display("PROTO: o_done and o_err together"); end
    if (done && vas_done) begin proto_fail = proto_fail + 1; $display("PROTO: o_done and o_vas_done together"); end
    if (rd_en && wr_en) begin proto_fail = proto_fail + 1; $display("PROTO: read and write of the buffer in one cycle"); end
    if ((done || err || vas_done) && !busy) begin proto_fail = proto_fail + 1; $display("PROTO: result pulse while idle"); end
  end

  reg [7:0] vecmem [0:1048575];
  reg [7:0] snap [0:1023];
  integer nvec, maxcyc, i, j, nfail, cyc, ok, rl, ex_ok, ex_err, vop, tot_cycles, zf;
  reg [8*200-1:0] vecpath;
  reg [7:0] eb;

  task automatic pulse_clr;
    begin
      @(posedge clk); #1 clr = 1; @(posedge clk); #1 clr = 0; @(posedge clk); #1;
    end
  endtask

  // Wait for a result pulse; returns the number of cycles waited (-1 on timeout) in cyc.
  task automatic wait_result;
    begin
      cyc = 0;
      while (!(done || err || vas_done) && cyc < maxcyc) begin @(posedge clk); #1 cyc = cyc + 1; end
      if (cyc >= maxcyc) cyc = -1;
    end
  endtask

  initial begin : main
    if (!$value$plusargs("VEC=%s", vecpath)) vecpath = "ec_vec.hex";
    if (!$value$plusargs("NVEC=%d", nvec)) nvec = 1;
    if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 40000000;
    $readmemh(vecpath, vecmem);
    clr = 0; start = 0; vas_start = 0; alg = 0; op_op = 0; hsh = 0; len_msg = 0; len_ctx = 0; key = 0; pool = 0; rd_data = 0; rd_valid = 0;
    nfail = 0; tot_cycles = 0;
    repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk);
    for (i = 0; i < nvec; i = i + 1) begin
      ok = 1;
      for (j = 0; j < 1024; j = j + 1) bmem[j] = 8'd0;
      rl = vecmem[i*BLK + 4] + (vecmem[i*BLK + 5] << 8);
      for (j = 0; j < 200; j = j + 1) bmem[j] = vecmem[i*BLK + 192 + j];
      for (j = 0; j < 140; j = j + 1) bmem[256 + j] = vecmem[i*BLK + 400 + j];
      for (j = 0; j < 140; j = j + 1) bmem[512 + j] = vecmem[i*BLK + 544 + j];
      for (j = 0; j < 1024; j = j + 1) snap[j] = bmem[j];
      for (j = 0; j < 68; j = j + 1) key[8*j +: 8] = vecmem[i*BLK + 16 + j];
      for (j = 0; j < 96; j = j + 1) pool[8*j +: 8] = vecmem[i*BLK + 84 + j];
      alg = vecmem[i*BLK + 0]; vop = vecmem[i*BLK + 1]; hsh = vecmem[i*BLK + 2];
      len_msg = {vecmem[i*BLK + 7], vecmem[i*BLK + 6], vecmem[i*BLK + 5], vecmem[i*BLK + 4]};
      len_ctx = vecmem[i*BLK + 3];
      ex_err = vecmem[i*BLK + 8] + (vecmem[i*BLK + 9] << 8);
      ex_ok = vecmem[i*BLK + 10]; rl = vecmem[i*BLK + 11];
      op_op = (vop == 0) ? 2'd0 : ((vop == 2) ? 2'd2 : 2'd1);
      @(posedge clk); #1 start = 1; @(posedge clk); #1 start = 0;
      wait_result;
      if (cyc < 0) begin ok = 0; $display("VEC %0d TIMEOUT", i); end
      else begin
        tot_cycles = tot_cycles + cyc;
        if (ex_err != 0) begin
          if (!err || err_flags != ex_err[11:0]) begin ok = 0; $display("VEC %0d: expected error flags %0h, got err=%0b flags=%0h", i, ex_err, err, err_flags); end
        end else begin
          if (!done) begin ok = 0; $display("VEC %0d: expected done, got err=%0b flags=%0h", i, err, err_flags); end
          if (vop == 2) begin
            if (sigok != ex_ok[0]) begin ok = 0; $display("VEC %0d: verify result %0b, expected %0d", i, sigok, ex_ok); end
          end else begin
            if (!sigok) begin ok = 0; $display("VEC %0d: o_sigok low after sign or keygen", i); end
            for (j = 0; j < rl; j = j + 1) begin
              eb = vecmem[i*BLK + 688 + j];
              if (bmem[768 + j] != eb) begin ok = 0; if (j < 400) $display("VEC %0d: result byte %0d is %02x, expected %02x", i, j, bmem[768 + j], eb); j = rl; end
            end
            if (rl != 0) for (j = rl; j < rl + 16; j = j + 1) if (bmem[768 + j] != 8'd0) begin ok = 0; $display("VEC %0d: byte %0d after the result was written (%02x)", i, j, bmem[768 + j]); end
          end
          for (j = 0; j < 768; j = j + 1) if (bmem[j] != snap[j]) begin ok = 0; $display("VEC %0d: input byte %0d changed", i, j); j = 768; end
          if (vop == 3 || vop == 4) begin
            if (vop == 4) bmem[768 + 5] = bmem[768 + 5] ^ 8'h01;
            @(posedge clk); #1 vas_start = 1; @(posedge clk); #1 vas_start = 0;
            wait_result;
            if (cyc < 0) begin ok = 0; $display("VEC %0d VAS TIMEOUT", i); end
            else begin
              tot_cycles = tot_cycles + cyc;
              if (!vas_done) begin ok = 0; $display("VEC %0d: VAS did not end with o_vas_done", i); end
              if (vas_ok != ex_ok[0]) begin ok = 0; $display("VEC %0d: vas ok %0b, expected %0d", i, vas_ok, ex_ok); end
            end
          end
        end
      end
      // Zeroization: after i_clr every register of the engine that can hold a secret reads zero.
      pulse_clr;
      zf = 0;
      for (j = 0; j < 32; j = j + 1) if (dut.reg_rf[j] != 576'd0) zf = zf + 1;
      if (dut.reg_head != 1024'd0 || dut.reg_mid != 1024'd0 || dut.reg_acc != 576'd0 || dut.reg_ma != 576'd0 || dut.reg_mb != 576'd0 || dut.reg_pw_acc != 576'd0) zf = zf + 1;
      if (zf != 0 || !cleared || busy) begin ok = 0; $display("VEC %0d: not zeroized after clear (%0d)", i, zf); end
      if (!ok) nfail = nfail + 1;
      $display("VEC %0d %s cycles=%0d", i, ok ? "PASS" : "FAIL", tot_cycles);
      tot_cycles = 0;
    end
    if (proto_fail != 0) nfail = nfail + 1;
    $display("tb_ec: %0d vectors, %0d failed, %0d protocol failures", nvec, nfail, proto_fail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
