// tb_top_ec.sv - system test of the digital signature IP top (elliptic-curve algorithms): APB4 programming
// as section 11.2, buffer load and result read through the AXI4 subordinate, key from the key registers
// and from the key port, random bytes from the entropy port, verify-after-sign, secret clearing.
// The vectors are those of gen_ec_vec.py (RFC 8032, RFC 6979 and rejection cases).
// Plusargs: +VEC=<hex file> +NVEC=<count> +MAXCYC=<cycles per operation>.
`timescale 1ns/1ps
module tb_top_ec;
  localparam int BLK = 1024;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  // APB
  reg psel = 0, penable = 0, pwrite = 0; reg [15:0] paddr = 0; reg [31:0] pwdata = 0; reg [3:0] pstrb = 0; reg [2:0] pprot = 0;
  wire pready, pslverr; wire [31:0] prdata;
  // AXI4
  reg awvalid = 0; wire awready; reg [3:0] awid = 0; reg [15:0] awaddr = 0; reg [7:0] awlen = 0; reg [2:0] awsize = 3; reg [1:0] awburst = 1;
  reg wvalid = 0; wire wready; reg [63:0] wdata = 0; reg [7:0] wstrb = 0; reg wlast = 0;
  wire bvalid; reg bready = 1; wire [3:0] bid; wire [1:0] bresp;
  reg arvalid = 0; wire arready; reg [3:0] arid = 0; reg [15:0] araddr = 0; reg [7:0] arlen = 0; reg [2:0] arsize = 3; reg [1:0] arburst = 1;
  wire rvalid; reg rready = 1; wire [3:0] rid; wire [63:0] rdata; wire [1:0] rresp; wire rlast;
  // key port and entropy
  wire key_req; wire [4:0] key_idx; wire ent_req; wire irq, alarm;
  wire dma_in_req, dma_out_req;
  reg [543:0] key_vec = 0; reg [767:0] pool_vec = 0;
  reg [4:0] ent_idx = 0;

  localparam logic [31:0] ALGMASK = 32'h0000_01FF;
  m_vlsit_dsig_top #(
    .PARA_EN_ED25519(1), .PARA_EN_ED25519CTX(1), .PARA_EN_ED25519PH(1), .PARA_EN_ED448(1), .PARA_EN_ED448PH(1), .PARA_EN_ECDSA_P256(1), .PARA_EN_ECDSA_P384(1), .PARA_EN_ECDSA_P521(1), .PARA_EN_ECDSA_K256(1),
    .PARA_OP_KGEN(ALGMASK), .PARA_OP_SIGN(ALGMASK), .PARA_OP_VRFY(ALGMASK),
    .PARA_EN_PURE(1), .PARA_EN_PREHASH(1), .PARA_BUF_BYTES(1024), .PARA_EN_AXI(1), .PARA_EN_DMA(1), .PARA_EN_WIN(1),
    .PARA_EN_KEYIF(1), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(2), .PARA_ECDSA_NONCE(2), .PARA_EN_VAS(1), .PARA_EN_LOG(1),
    .PARA_CSR_ASYNC(0)
  ) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clk_apb(clk), .i_rst_n_apb(rst_n),
    .i_apb_psel(psel), .i_apb_penable(penable), .i_apb_pwrite(pwrite), .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pstrb(pstrb), .i_apb_pprot(pprot),
    .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata), .i_protect_en(1'b0), .i_slverr_en(1'b0),
    .i_axi_awvalid(awvalid), .o_axi_awready(awready), .i_axi_awid(awid), .i_axi_awaddr(awaddr), .i_axi_awlen(awlen), .i_axi_awsize(awsize), .i_axi_awburst(awburst),
    .i_axi_wvalid(wvalid), .o_axi_wready(wready), .i_axi_wdata(wdata), .i_axi_wstrb(wstrb), .i_axi_wlast(wlast),
    .o_axi_bvalid(bvalid), .i_axi_bready(bready), .o_axi_bid(bid), .o_axi_bresp(bresp),
    .i_axi_arvalid(arvalid), .o_axi_arready(arready), .i_axi_arid(arid), .i_axi_araddr(araddr), .i_axi_arlen(arlen), .i_axi_arsize(arsize), .i_axi_arburst(arburst),
    .o_axi_rvalid(rvalid), .i_axi_rready(rready), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp), .o_axi_rlast(rlast),
    .o_dma_in_req(dma_in_req), .i_dma_in_ack(1'b0), .o_dma_out_req(dma_out_req), .i_dma_out_ack(1'b0),
    .o_key_req(key_req), .o_key_idx(key_idx), .i_key_valid(key_req), .i_key_data(key_vec[32*key_idx +: 32]),
    .o_ent_req(ent_req), .i_ent_valid(ent_req), .i_ent_data(pool_vec[32*ent_idx +: 32]),
    .o_irq(irq), .o_alarm(alarm));

  // Entropy word counter: restarts when the request drops, advances with every word taken
  always @(posedge clk) if (!rst_n) ent_idx <= 0; else if (ent_req) ent_idx <= ent_idx + 1; else ent_idx <= 0;

  reg [7:0] vecmem [0:1048575];
  reg [7:0] bmem [0:1023];
  integer nvec, maxcyc, i, j, nfail = 0, ok, vop, ex_err, ex_ok, rl, alg, hsh, lenm, cyc, n_ok_ops = 0;
  reg [31:0] rd, sts, errv;
  reg [8*200-1:0] vecpath;
  reg [63:0] w64;
  reg [7:0] eb;

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

  // AXI4 burst of nb 64-bit words from bmem to the buffer
  task automatic axi_load(input integer nb);
    integer b;
    begin
      @(posedge clk); #1 awvalid = 1; awaddr = 0; awlen = nb - 1; awsize = 3; awburst = 1;
      @(posedge clk); while (!awready) @(posedge clk);
      #1 awvalid = 0;
      for (b = 0; b < nb; b = b + 1) begin
        #1 wvalid = 1; wstrb = 8'hFF; wlast = (b == nb - 1);
        for (j = 0; j < 8; j = j + 1) wdata[8*j +: 8] = bmem[8*b + j];
        @(posedge clk); while (!wready) @(posedge clk);
      end
      #1 wvalid = 0; wlast = 0;
      while (!bvalid) @(posedge clk);
      if (bresp != 2'b00) begin nfail = nfail + 1; $display("AXI load: bresp %0b", bresp); end
      @(posedge clk);
    end
  endtask
  // AXI4 burst read of nb words into bmem (from byte address a)
  task automatic axi_store(input integer a, input integer nb);
    integer b;
    begin
      @(posedge clk); #1 arvalid = 1; araddr = a; arlen = nb - 1; arsize = 3; arburst = 1;
      @(posedge clk); while (!arready) @(posedge clk);
      #1 arvalid = 0;
      for (b = 0; b < nb; b = b + 1) begin
        @(posedge clk); while (!rvalid) @(posedge clk);
        if (rresp != 2'b00) begin nfail = nfail + 1; $display("AXI store: rresp %0b", rresp); end
        for (j = 0; j < 8; j = j + 1) bmem[a + 8*b + j] = rdata[8*j +: 8];
      end
      @(posedge clk);
    end
  endtask

  initial begin : main
    if (!$value$plusargs("VEC=%s", vecpath)) vecpath = "ec_vec.hex";
    if (!$value$plusargs("NVEC=%d", nvec)) nvec = 1;
    if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 60000000;
    $readmemh(vecpath, vecmem);
    repeat (6) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
    apb_r(16'h000, rd); if (rd != 32'h0001_0000) begin nfail = nfail + 1; $display("version register %08x", rd); end
    apb_w(16'h040, 32'd1);                 // dsig_ctrl.en
    apb_w(16'h044, ALGMASK);               // dsig_alg_en
    apb_w(16'h0AC, 32'h0001_0001);         // tmo
    for (i = 0; i < nvec; i = i + 1) begin
      ok = 1;
      alg = vecmem[i*BLK + 0]; vop = vecmem[i*BLK + 1]; hsh = vecmem[i*BLK + 2];
      lenm = {vecmem[i*BLK + 7], vecmem[i*BLK + 6], vecmem[i*BLK + 5], vecmem[i*BLK + 4]};
      ex_err = vecmem[i*BLK + 8] + (vecmem[i*BLK + 9] << 8); ex_ok = vecmem[i*BLK + 10]; rl = vecmem[i*BLK + 11];
      if (vop == 4) begin $display("VEC %0d SKIP", i); end
      else begin
        for (j = 0; j < 1024; j = j + 1) bmem[j] = 8'd0;
        for (j = 0; j < 200; j = j + 1) bmem[j] = vecmem[i*BLK + 192 + j];
        for (j = 0; j < 140; j = j + 1) bmem[256 + j] = vecmem[i*BLK + 400 + j];
        for (j = 0; j < 140; j = j + 1) bmem[512 + j] = vecmem[i*BLK + 544 + j];
        for (j = 0; j < 68; j = j + 1) key_vec[8*j +: 8] = vecmem[i*BLK + 16 + j];
        for (j = 0; j < 96; j = j + 1) pool_vec[8*j +: 8] = vecmem[i*BLK + 84 + j];
        axi_load(128);
        apb_w(16'h050, (hsh << 24) | (vecmem[i*BLK + 12][0] << 20) | (((alg == 2 || alg == 4) ? 1 : 0) << 12) | ((vop == 3 ? 1 : vop) << 8) | alg);     // dsig_op: alg, op, form, nonce, hash
        apb_w(16'h05C, vecmem[i*BLK + 3]);     // dsig_len_ctx
        apb_w(16'h058, lenm); apb_w(16'h060, 0); apb_w(16'h064, 256); apb_w(16'h068, 512); apb_w(16'h06C, 768);
        if ((vop == 0 || vop == 1 || vop == 3) && (i % 2 == 0))
          for (j = 0; j < 17; j = j + 1) apb_w(16'h100 + 4*j, {key_vec[32*j+24 +: 8], key_vec[32*j+16 +: 8], key_vec[32*j+8 +: 8], key_vec[32*j +: 8]});
        apb_w(16'h070, 32'd1);             // dsig_cmd.start
        cyc = 0; sts = 32'd1;
        while (sts[0] && cyc < maxcyc) begin
          repeat (50) @(posedge clk); cyc = cyc + 50;
          apb_r(16'h074, sts);
        end
        // status settles one APB access after the last busy cycle
        repeat (4) @(posedge clk);
        apb_r(16'h074, sts); apb_r(16'h078, errv);
        if (cyc >= maxcyc) begin ok = 0; $display("VEC %0d TIMEOUT", i); end
        else begin
          if (ex_err != 0) begin
            if ((errv & ex_err) != ex_err) begin ok = 0; $display("VEC %0d: dsig_err %08x, expected bits %0h", i, errv, ex_err); end
            if (sts[8]) begin ok = 0; $display("VEC %0d: result valid after an error", i); end
          end else if (vop == 2) begin
            if (errv != 0) begin ok = 0; $display("VEC %0d: dsig_err %08x on a verify", i, errv); end
            if (!sts[8]) begin ok = 0; $display("VEC %0d: no result valid after verify", i); end
            if (sts[9] != ex_ok[0]) begin ok = 0; $display("VEC %0d: sigok %0b, expected %0d", i, sts[9], ex_ok); end
          end else begin
            if (errv != 0) begin ok = 0; $display("VEC %0d: dsig_err %08x on sign or keygen", i, errv); end
            if (!sts[8]) begin ok = 0; $display("VEC %0d: no result valid", i); end
            axi_store(768, 24);
            for (j = 0; j < rl; j = j + 1) begin
              eb = vecmem[i*BLK + 688 + j];
              if (bmem[768 + j] != eb) begin ok = 0; $display("VEC %0d: result byte %0d is %02x, expected %02x", i, j, bmem[768 + j], eb); j = rl; end
            end
          end
        end
        // secrets are gone after the operation
        if (dut.w_key_store != 544'd0 || dut.w_pool != 768'd0) begin ok = 0; $display("VEC %0d: key store or pool not empty after the operation", i); end
        apb_w(16'h070, 32'd4);             // dsig_cmd.clr
        repeat (4) @(posedge clk);
        apb_r(16'h078, errv); apb_r(16'h074, sts);
        if (errv != 0 || sts[8]) begin ok = 0; $display("VEC %0d: dsig_cmd.clr did not clear err/result", i); end
        if (!ok) nfail = nfail + 1; else n_ok_ops = n_ok_ops + 1;
        $display("VEC %0d %s cycles=%0d", i, ok ? "PASS" : "FAIL", cyc);
      end
    end
    apb_r(16'h09C, rd); $display("dsig_cnt_ops = %0d", rd);
    $display("tb_top_ec: %0d vectors, %0d failed", nvec, nfail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
