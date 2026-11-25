// tb_top_pq.sv - system test of the digital signature IP top for the post-quantum engines: ML-DSA (lattice engine) and
// SLH-DSA, LMS/HSS, XMSS (hash-based engine) through APB4, AXI4, the key registers and the hash arbiter, with the buffer
// images of gen_lat_vec.py or gen_hbs_vec.py. Plusargs: +DIR=<vector directory> +KIND=lat|hbs +NVEC +FIRST +MAXCYC.
`timescale 1ns/1ps
module tb_top_pq;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg psel = 0, penable = 0, pwrite = 0; reg [15:0] paddr = 0; reg [31:0] pwdata = 0; reg [3:0] pstrb = 0; reg [2:0] pprot = 0;
  wire pready, pslverr; wire [31:0] prdata;
  reg awvalid = 0; wire awready; reg [15:0] awaddr = 0; reg [7:0] awlen = 0;
  reg wvalid = 0; wire wready; reg [63:0] wdata = 0; reg [7:0] wstrb = 0; reg wlast = 0;
  wire bvalid; wire [3:0] bid; wire [1:0] bresp;
  reg arvalid = 0; wire arready; reg [15:0] araddr = 0; reg [7:0] arlen = 0;
  wire rvalid; wire [3:0] rid; wire [63:0] rdata; wire [1:0] rresp; wire rlast;
  wire key_req; wire [4:0] key_idx; wire ent_req; wire irq, alarm; wire dma_in_req, dma_out_req;
  reg [767:0] pool_vec = 0; reg [4:0] ent_idx = 0;

  localparam logic [31:0] ALGMASK = 32'h0000_0E00;
  m_vlsit_dsig_top #(
    .PARA_EN_MLDSA44(1), .PARA_EN_MLDSA65(1), .PARA_EN_MLDSA87(1), .PARA_EN_SLHDSA(1), .PARA_SLHDSA_SETS(32'hFFF), .PARA_EN_LMS(1),
    .PARA_LMS_SETS(32'hFFFFF), .PARA_LMOTS_SETS(32'hFFFF), .PARA_EN_XMSS(1), .PARA_XMSS_SETS_LO(32'hFFFFFFFF), .PARA_XMSS_SETS_HI(32'hFFF),
    .PARA_OP_KGEN(32'h0000_0E00), .PARA_OP_SIGN(32'h0000_0E00), .PARA_OP_VRFY(32'h0000_7E00),
    .PARA_EN_PURE(1), .PARA_EN_PREHASH(1), .PARA_BUF_BYTES(65536), .PARA_EN_AXI(1), .PARA_EN_DMA(0), .PARA_EN_WIN(1),
    .PARA_EN_KEYIF(0), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(1), .PARA_ECDSA_NONCE(0), .PARA_EN_VAS(1), .PARA_EN_LOG(1), .PARA_CSR_ASYNC(0)
  ) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clk_apb(clk), .i_rst_n_apb(rst_n),
    .i_apb_psel(psel), .i_apb_penable(penable), .i_apb_pwrite(pwrite), .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pstrb(pstrb), .i_apb_pprot(pprot),
    .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata), .i_protect_en(1'b0), .i_slverr_en(1'b0),
    .i_axi_awvalid(awvalid), .o_axi_awready(awready), .i_axi_awid(4'd0), .i_axi_awaddr(awaddr), .i_axi_awlen(awlen), .i_axi_awsize(3'd3), .i_axi_awburst(2'b01),
    .i_axi_wvalid(wvalid), .o_axi_wready(wready), .i_axi_wdata(wdata), .i_axi_wstrb(wstrb), .i_axi_wlast(wlast),
    .o_axi_bvalid(bvalid), .i_axi_bready(1'b1), .o_axi_bid(bid), .o_axi_bresp(bresp),
    .i_axi_arvalid(arvalid), .o_axi_arready(arready), .i_axi_arid(4'd0), .i_axi_araddr(araddr), .i_axi_arlen(arlen), .i_axi_arsize(3'd3), .i_axi_arburst(2'b01),
    .o_axi_rvalid(rvalid), .i_axi_rready(1'b1), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp), .o_axi_rlast(rlast),
    .o_dma_in_req(dma_in_req), .i_dma_in_ack(1'b0), .o_dma_out_req(dma_out_req), .i_dma_out_ack(1'b0),
    .o_key_req(key_req), .o_key_idx(key_idx), .i_key_valid(1'b0), .i_key_data(32'd0),
    .o_ent_req(ent_req), .i_ent_valid(ent_req), .i_ent_data(pool_vec[32*ent_idx +: 32]),
    .o_irq(irq), .o_alarm(alarm));
  always @(posedge clk) if (!rst_n) ent_idx <= 0; else if (ent_req) ent_idx <= ent_idx + 1; else ent_idx <= 0;

  reg [7:0] bmem [0:65535];
  reg [7:0] expb [0:8191];
  integer nvec, first, maxcyc, i, j, fd, rc, nfail = 0, ok, cyc, n_words;
  integer v_i, v_alg, v_op, v_hd, v_lm, v_lc, v_om, v_os, v_op2, v_or, v_ok, v_el, v_vas, v_nb;
  integer h_i, h_alg, h_slh, h_lt, h_lo, h_hl, h_x, h_lm, h_lc, h_om, h_os, h_op, h_ok, h_nb;
  reg [31:0] sts, errv, rd;
  reg [8*80-1:0] keyhex, poolhex;
  reg [8*200-1:0] dir, path, kind;
  integer klen, plen, is_lat;

  function [7:0] hexbyte(input [8*80-1:0] s, input integer pos, input integer len);
    reg [7:0] c1, c2; integer v1, v2;
    begin
      c1 = s[8*(len - 1 - 2*pos) +: 8]; c2 = s[8*(len - 2 - 2*pos) +: 8];
      v1 = (c1 >= "a") ? (c1 - "a" + 10) : (c1 - "0"); v2 = (c2 >= "a") ? (c2 - "a" + 10) : (c2 - "0");
      hexbyte = v1 * 16 + v2;
    end
  endfunction

  task automatic apb_w(input [15:0] a, input [31:0] d);
    begin
      @(posedge clk); #1 psel = 1; penable = 0; pwrite = 1; paddr = a; pwdata = d; pstrb = 4'hF;
      @(posedge clk); #1 penable = 1;
      @(posedge clk); while (!pready) @(posedge clk);
      #1 psel = 0; penable = 0; pwrite = 0;
    end
  endtask
  task automatic apb_r(input [15:0] a, output [31:0] d);
    begin
      @(posedge clk); #1 psel = 1; penable = 0; pwrite = 0; paddr = a;
      @(posedge clk); #1 penable = 1;
      @(posedge clk); while (!pready) @(posedge clk);
      d = prdata; #1 psel = 0; penable = 0;
    end
  endtask
  // burst of nb words from bmem[a...] to the buffer at byte address a (nb <= 256)
  task automatic axi_load(input integer a, input integer nb);
    integer b, k;
    begin
      @(posedge clk); #1 awvalid = 1; awaddr = a; awlen = nb - 1;
      @(posedge clk); while (!awready) @(posedge clk);
      #1 awvalid = 0;
      for (b = 0; b < nb; b = b + 1) begin
        #1 wvalid = 1; wstrb = 8'hFF; wlast = (b == nb - 1);
        for (k = 0; k < 8; k = k + 1) wdata[8*k +: 8] = bmem[a + 8*b + k];
        @(posedge clk); while (!wready) @(posedge clk);
      end
      #1 wvalid = 0; wlast = 0;
      while (!bvalid) @(posedge clk);
      if (bresp != 2'b00) begin nfail = nfail + 1; $display("AXI load: bresp %0b", bresp); end
      @(posedge clk);
    end
  endtask
  task automatic axi_read_res(input integer a, input integer nw, input integer dst);
    integer b, k;
    begin
      @(posedge clk); #1 arvalid = 1; araddr = a; arlen = nw - 1;
      @(posedge clk); while (!arready) @(posedge clk);
      #1 arvalid = 0;
      for (b = 0; b < nw; b = b + 1) begin
        @(posedge clk); while (!rvalid) @(posedge clk);
        for (k = 0; k < 8; k = k + 1) expb[dst + 8*b + k] = rdata[8*k +: 8];
      end
      @(posedge clk);
    end
  endtask

  reg [7:0] resb [0:8191];
  // +PROGRESS=<n>: print the states every n cycles (diagnostic)
  integer prog_n;
  initial begin
    if ($value$plusargs("PROGRESS=%d", prog_n))
      forever begin
        repeat (prog_n) @(posedge clk);
        $display("PROGRESS t=%0t ctl %0d lat %0d pc %0d vas %0b hs_req %b grant %b", $time, dut.u_ctl.reg_fsm_ctl_current_state,
                 dut.g_lat.u_lat.reg_fsm_lat_current_state, dut.g_lat.u_lat.reg_pc, dut.g_lat.u_lat.reg_vas,
                 dut.w_lat_hs_req, dut.w_hq_grant);
        $fflush;
      end
  end
  initial begin : main
    if (!$value$plusargs("DIR=%s", dir)) dir = "vec";
    if (!$value$plusargs("KIND=%s", kind)) kind = "lat";
    if (!$value$plusargs("NVEC=%d", nvec)) nvec = 1;
    if (!$value$plusargs("FIRST=%d", first)) first = 0;
    if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 200000000;
    is_lat = (kind == "lat");
    repeat (6) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
    // the lattice engine clears its RAM after reset only through the control block: run one clear (abort in idle) first
    apb_w(16'h040, 32'd1);
    apb_w(16'h044, 32'h0000_7E00);
    apb_w(16'h0AC, 32'h0001_0001);
    if (is_lat) $sformat(path, "%0s/lat_vecs.txt", dir); else $sformat(path, "%0s/hbs_vecs.txt", dir);
    fd = $fopen(path, "r");
    for (i = 0; i < nvec + first; i = i + 1) begin
      if (is_lat) begin
        rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %s %s\n", v_i, v_alg, v_op, v_hd, v_lm, v_lc, v_om, v_os, v_op2, v_or, v_ok, v_el, v_vas, v_nb, keyhex, poolhex);
        if (rc != 16) begin $display("vector list ended at %0d", i); $finish; end
      end else begin
        rc = $fscanf(fd, "%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", h_i, h_alg, h_slh, h_lt, h_lo, h_hl, h_x, h_lm, h_lc, h_om, h_os, h_op, h_ok, h_nb);
        if (rc != 14) begin $display("vector list ended at %0d", i); $finish; end
        v_i = h_i; v_alg = h_alg; v_op = 2; v_hd = 0; v_lm = h_lm; v_lc = h_lc; v_om = h_om; v_os = h_os; v_op2 = h_op; v_or = 16384; v_ok = h_ok;
        v_el = 0; v_vas = 0; v_nb = h_nb; keyhex = "00"; poolhex = "00";
      end
      if (i >= first) begin
        ok = 1;
        for (j = 0; j < 65536; j = j + 1) bmem[j] = 8'd0;
        if (is_lat) $sformat(path, "%0s/lat_v%0d.hex", dir, v_i); else $sformat(path, "%0s/hbs_v%0d.hex", dir, v_i);
        $readmemh(path, bmem);
        if (is_lat) begin $sformat(path, "%0s/lat_e%0d.hex", dir, v_i); $readmemh(path, resb); end
        klen = 0; while (klen < 80 && keyhex[8*klen +: 8] != 0) klen = klen + 1;
        plen = 0; while (plen < 80 && poolhex[8*plen +: 8] != 0) plen = plen + 1;
        pool_vec = 0;
        for (j = 0; j < plen / 2; j = j + 1) pool_vec[8*j +: 8] = hexbyte(poolhex, j, plen);
        // buffer image through AXI4 (2 KB bursts)
        n_words = (v_nb + 7) / 8;
        for (j = 0; j < n_words; j = j + 256) axi_load(8 * j, (n_words - j > 256) ? 256 : (n_words - j));
        // key into the write-only key registers (8 words of the seed)
        if (is_lat && (v_op == 0 || v_op == 1))
          for (j = 0; j < 8; j = j + 1) apb_w(16'h100 + 4*j, {hexbyte(keyhex, 4*j+3, klen), hexbyte(keyhex, 4*j+2, klen), hexbyte(keyhex, 4*j+1, klen), hexbyte(keyhex, 4*j, klen)});
        // mode field of the vector list: hedged | form << 1 | hash << 3 (lattice), slh | form << 4 | hash << 6 (hash-based)
        if (is_lat) apb_w(16'h050, (((v_hd >> 3) & 7) << 24) | ((v_hd & 1) << 16) | (((v_hd >> 1) & 3) << 12) | (v_op << 8) | v_alg);
        else apb_w(16'h050, (((h_slh >> 6) & 7) << 24) | (((h_slh >> 4) & 3) << 12) | (2 << 8) | v_alg);
        if (!is_lat) apb_w(16'h054, (h_x << 24) | (h_hl << 20) | (h_lo << 16) | (h_lt << 8) | (h_slh & 15));
        apb_w(16'h058, v_lm); apb_w(16'h05C, v_lc); apb_w(16'h060, v_om); apb_w(16'h064, v_os); apb_w(16'h068, v_op2); apb_w(16'h06C, v_or);
        apb_w(16'h070, 32'd1);             // dsig_cmd.start
        cyc = 0; sts = 32'd1;
        while (sts[0] && cyc < maxcyc) begin repeat (100) @(posedge clk); cyc = cyc + 100; apb_r(16'h074, sts); end
        repeat (4) @(posedge clk);
        apb_r(16'h074, sts); apb_r(16'h078, errv);
        if (cyc >= maxcyc) begin ok = 0; $display("VEC %0d TIMEOUT ctl %0d lat %0d pc %0d vas %0b", v_i, dut.u_ctl.reg_fsm_ctl_current_state, dut.g_lat.u_lat.reg_fsm_lat_current_state, dut.g_lat.u_lat.reg_pc, dut.g_lat.u_lat.reg_vas); end
        else begin
          if (errv != 0) begin ok = 0; $display("VEC %0d: dsig_err %08x", v_i, errv); end
          else if (!sts[8]) begin ok = 0; $display("VEC %0d: no result valid", v_i); end
          else if (v_op == 2) begin
            if (sts[9] != v_ok[0]) begin ok = 0; $display("VEC %0d: sigok %0b, expected %0d", v_i, sts[9], v_ok); end
          end else begin
            // AXI4 INCR bursts are at most 256 beats: read the result in pieces
            for (j = 0; j < (v_el + 7) / 8; j = j + 256)
              axi_read_res(16384 + 8 * j, ((v_el + 7) / 8 - j > 256) ? 256 : ((v_el + 7) / 8 - j), 8 * j);
            for (j = 0; j < v_el; j = j + 1)
              if (expb[j] != resb[j]) begin ok = 0; $display("VEC %0d: result byte %0d is %02x, expected %02x", v_i, j, expb[j], resb[j]); j = v_el; end
          end
        end
        apb_w(16'h070, 32'd4);             // dsig_cmd.clr
        repeat (40) @(posedge clk);
        // wait for the clearing of every block (the lattice RAM takes 32768 cycles)
        cyc = 0; sts = 32'd1;
        while (sts[0] && cyc < 200000) begin repeat (100) @(posedge clk); cyc = cyc + 100; apb_r(16'h074, sts); end
        if (sts[0]) begin ok = 0; $display("VEC %0d: busy after the clear command", v_i); end
        if (!ok) nfail = nfail + 1;
        $display("VEC %0d %s", v_i, ok ? "PASS" : "FAIL");
      end
    end
    $display("tb_top_pq: %0d vectors, %0d failed", nvec, nfail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
