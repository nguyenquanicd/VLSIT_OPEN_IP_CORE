// tb_hfeed.sv - checks m_vlsit_dsig_hfeed with the arbiter and the stream sequencer against hashlib.
`timescale 1ns/1ps
module tb_hfeed;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg go; reg [3:0] mode; reg [15:0] outlen; reg [8*128-1:0] head; reg [8:0] hlen; reg [23:0] taddr, tlen, taddr2, tlen2; reg [8:0] midlen; reg [8*128-1:0] mid;
  wire [8*64-1:0] digest; wire done, busy;
  wire tr_en; wire [20:0] tr_addr; reg [63:0] tr_data; reg tr_valid;
  wire hs_req, hs_start, hs_in_valid, hs_in_last, hs_out_ready; wire [3:0] hs_mode, hs_in_nb; wire [15:0] hs_outlen; wire [63:0] hs_in_data;
  wire grant;
  wire s_job_start, s_in_valid, s_in_last, s_out_ready, s_in_ready, s_out_valid, s_out_last; wire [3:0] s_mode, s_in_nb, s_out_nb; wire [15:0] s_outlen; wire [63:0] s_in_data, s_out_data;
  wire [0:0] g, ir, ov, ol; wire [63:0] od; wire [3:0] onb;
  m_vlsit_dsig_hfeed #(.PARA_MID_BYTES(128)) dut (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(1'b0), .i_go(go), .i_mode(mode), .i_outlen(outlen), .i_head(head), .i_head_len(hlen),
    .i_tail_addr(taddr), .i_tail_len(tlen), .i_tail2_addr(taddr2), .i_tail2_len(tlen2), .i_mid(mid), .i_mid_len(midlen), .o_digest(digest), .o_done(done), .o_busy(busy), .o_tr_en(tr_en), .o_tr_addr(tr_addr), .i_tr_data(tr_data), .i_tr_valid(tr_valid),
    .o_hs_req(hs_req), .i_hs_grant(g[0]), .o_hs_start(hs_start), .o_hs_mode(hs_mode), .o_hs_outlen(hs_outlen), .o_hs_in_valid(hs_in_valid), .o_hs_in_data(hs_in_data),
    .o_hs_in_nb(hs_in_nb), .o_hs_in_last(hs_in_last), .i_hs_in_ready(ir[0]), .i_hs_out_valid(ov[0]), .i_hs_out_data(od), .i_hs_out_nb(onb), .i_hs_out_last(ol[0]), .o_hs_out_ready(hs_out_ready));
  m_vlsit_dsig_harb #(.PARA_NREQ(1)) arb (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_req(hs_req), .i_job_start(hs_start), .i_job_mode(hs_mode), .i_job_outlen(hs_outlen),
    .i_in_valid(hs_in_valid), .i_in_data(hs_in_data), .i_in_nb(hs_in_nb), .i_in_last(hs_in_last), .i_out_ready(hs_out_ready),
    .o_grant(g), .o_in_ready(ir), .o_out_valid(ov), .o_out_data(od), .o_out_nb(onb), .o_out_last(ol),
    .o_job_start(s_job_start), .o_job_mode(s_mode), .o_job_outlen(s_outlen), .o_in_valid(s_in_valid), .o_in_data(s_in_data), .o_in_nb(s_in_nb), .o_in_last(s_in_last),
    .i_in_ready(s_in_ready), .i_out_valid(s_out_valid), .i_out_data(s_out_data), .i_out_nb(s_out_nb), .i_out_last(s_out_last), .o_out_ready(s_out_ready));
  m_vlsit_dsig_hseq sq (.i_clk_core(clk), .i_rst_n_core(rst_n), .i_clr(1'b0), .i_job_start(s_job_start), .i_job_mode(s_mode), .i_job_outlen(s_outlen),
    .i_in_valid(s_in_valid), .i_in_data(s_in_data), .i_in_nb(s_in_nb), .i_in_last(s_in_last), .o_in_ready(s_in_ready),
    .o_out_valid(s_out_valid), .o_out_data(s_out_data), .o_out_nb(s_out_nb), .o_out_last(s_out_last), .i_out_ready(s_out_ready), .o_busy());

  // memory source: 64-bit words, one cycle latency
  function [7:0] mb(input integer i); begin mb = (i * 11 + 3) % 256; end endfunction
  integer q;
  always @(posedge clk) begin
    tr_valid <= tr_en;
    if (tr_en) for (q = 0; q < 8; q = q + 1) tr_data[8*q +: 8] <= mb(8 * tr_addr + q);
  end

  integer fd, rc, vml, n, vmode, vol, vhl, vta, vtl, vta2, vtl2, nfail, nvec, j, k, ok, hv, eb, gb, tmo;
  reg [8*600-1:0] vhex; reg [7:0] c;
  initial begin : main
    reg [8*200-1:0] vecpath;
    if (!$value$plusargs("VEC=%s", vecpath)) vecpath = "hfeed_vec.txt";
    go = 0; tr_valid = 0; tr_data = 0; head = 0; hlen = 0; taddr = 0; tlen = 0; taddr2 = 0; tlen2 = 0; midlen = 0; mid = 0; mode = 0; outlen = 0;
    repeat (4) @(posedge clk); #1 rst_n = 1;
    fd = $fopen(vecpath, "r"); nfail = 0; nvec = 0; 
    while (!$feof(fd)) begin
      rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %s\n", n, vmode, vol, vhl, vta, vtl, vta2, vtl2, vml, vhex);
      if (rc != 10) begin $display("fscanf rc=%0d", rc); $finish; end
      if (rc == 10) begin
        head = 0; for (j = 0; j < vhl; j = j + 1) head[8*j +: 8] = (j * 5 + n) % 256;
        @(posedge clk); #1; mode = vmode; outlen = vol; hlen = vhl; taddr = vta; tlen = vtl; taddr2 = vta2; tlen2 = vtl2; midlen = vml; mid = 0; for (j = 0; j < vml; j = j + 1) mid[8*j +: 8] = (j * 3 + n + 1) % 256; go = 1;
        @(posedge clk); #1 go = 0;
        tmo = 0;
        while (!done && tmo < 20000) begin @(posedge clk); tmo = tmo + 1; end
        ok = (tmo < 20000);
        for (j = 0; j < vol && j < 64; j = j + 1) begin
          c = vhex[8*(2*vol - 1 - 2*j) +: 8]; hv = (c >= "a") ? (c - "a" + 10) : (c - "0"); eb = hv * 16;
          c = vhex[8*(2*vol - 2 - 2*j) +: 8]; hv = (c >= "a") ? (c - "a" + 10) : (c - "0"); eb = eb + hv;
          gb = digest[8*j +: 8];
          if (eb != gb) ok = 0;
        end
        nvec = nvec + 1; 
        if (!ok) begin nfail = nfail + 1; if (nfail <= 6) $display("FAIL vec %0d mode %0d outlen %0d hl %0d ta %0d tl %0d ta2 %0d tl2 %0d", n, vmode, vol, vhl, vta, vtl, vta2, vtl2); end
        @(posedge clk);
      end
    end
    $display("hfeed: %0d vectors, %0d failed", nvec, nfail);
    if (nfail == 0 && nvec > 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
