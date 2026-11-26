// tb_top_sys.sv - combined system test of m_vlsit_dsig_top with the real Ed25519 and ML-DSA-44 engines. One run covers the
// functions that the other top tests do not exercise with real engines; every check names its source in the specification:
//   hybrid verification (REQ-FUNC-012, DEC-030 numbered example 2), interrupt and its clear (REQ-IF-003, section 6.4),
//   DMA request lines (REQ-IF-004, ASM-019), CSR data window and AXI4 on the same buffer (REQ-IF-005), operation and failure
//   counters (REQ-SEC-006), reset during a signing (REQ-RESET-001, REQ-RESET-002, REQ-SEC-005).
// The images come from models/top/gen_sys_vec.py (RFC 8032 vector, OpenSSL ML-DSA-44 signature). Plusarg: +DIR=<dir>.
`timescale 1ns/1ps
module tb_top_sys;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg psel = 0, penable = 0, pwrite = 0; reg [15:0] paddr = 0; reg [31:0] pwdata = 0;
  wire pready, pslverr; wire [31:0] prdata;
  reg awvalid = 0; wire awready; reg [15:0] awaddr = 0; reg [7:0] awlen = 0;
  reg wvalid = 0; wire wready; reg [63:0] wdata = 0; reg wlast = 0;
  wire bvalid; wire [3:0] bid; wire [1:0] bresp;
  reg arvalid = 0; wire arready; reg [15:0] araddr = 0; reg [7:0] arlen = 0;
  wire rvalid; wire [3:0] rid; wire [63:0] rdata; wire [1:0] rresp; wire rlast;
  wire key_req; wire [4:0] key_idx; wire ent_req; wire irq, alarm; wire dma_in_req, dma_out_req;
  reg dma_in_ack = 0, dma_out_ack = 0;

  m_vlsit_dsig_top #(
    .PARA_EN_ED25519(1), .PARA_EN_MLDSA44(1), .PARA_OP_KGEN(32'h0000_0001), .PARA_OP_SIGN(32'h0000_0001), .PARA_OP_VRFY(32'h0000_0201),
    .PARA_EN_PURE(1), .PARA_EN_PREHASH(1), .PARA_BUF_BYTES(16384), .PARA_EN_AXI(1), .PARA_EN_DMA(1), .PARA_EN_WIN(1),
    .PARA_EN_KEYIF(0), .PARA_EN_KEYREG(1), .PARA_EN_VAS(1), .PARA_EN_HYBRID(1), .PARA_EN_LOG(1), .PARA_EN_LOCK(1), .PARA_CSR_ASYNC(0)
  ) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clk_apb(clk), .i_rst_n_apb(rst_n),
    .i_apb_psel(psel), .i_apb_penable(penable), .i_apb_pwrite(pwrite), .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pstrb(4'hF),
    .i_apb_pprot(3'd0), .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata), .i_protect_en(1'b0), .i_slverr_en(1'b0),
    .i_axi_awvalid(awvalid), .o_axi_awready(awready), .i_axi_awid(4'd0), .i_axi_awaddr(awaddr), .i_axi_awlen(awlen), .i_axi_awsize(3'd3),
    .i_axi_awburst(2'b01), .i_axi_wvalid(wvalid), .o_axi_wready(wready), .i_axi_wdata(wdata), .i_axi_wstrb(8'hFF), .i_axi_wlast(wlast),
    .o_axi_bvalid(bvalid), .i_axi_bready(1'b1), .o_axi_bid(bid), .o_axi_bresp(bresp),
    .i_axi_arvalid(arvalid), .o_axi_arready(arready), .i_axi_arid(4'd0), .i_axi_araddr(araddr), .i_axi_arlen(arlen), .i_axi_arsize(3'd3),
    .i_axi_arburst(2'b01), .o_axi_rvalid(rvalid), .i_axi_rready(1'b1), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp),
    .o_axi_rlast(rlast), .o_dma_in_req(dma_in_req), .i_dma_in_ack(dma_in_ack), .o_dma_out_req(dma_out_req), .i_dma_out_ack(dma_out_ack),
    .o_key_req(key_req), .o_key_idx(key_idx), .i_key_valid(1'b0), .i_key_data(32'd0),
    .o_ent_req(ent_req), .i_ent_valid(ent_req), .i_ent_data(32'h1234_5678), .o_irq(irq), .o_alarm(alarm));

  reg [7:0] img [0:16383];
  reg [7:0] edkey [0:31];
  integer nfail = 0, ncheck = 0, cyc, j, lmsg_ed, lmsg_ml, nimg, ops0, fail0;
  reg [31:0] sts, errv, rd;
  reg [8*200-1:0] dir, path;

  task automatic check(input integer cond, input [8*90-1:0] what);
    begin ncheck = ncheck + 1; if (!cond) begin nfail = nfail + 1; $display("FAIL: %0s (time %0t)", what, $time); end end
  endtask
  task automatic apb_w(input [15:0] a, input [31:0] d);
    begin
      @(posedge clk); #1 psel = 1; penable = 0; pwrite = 1; paddr = a; pwdata = d;
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
  task automatic axi_load(input integer a, input integer nb);
    integer b, k;
    begin
      @(posedge clk); #1 awvalid = 1; awaddr = a; awlen = nb - 1;
      @(posedge clk); while (!awready) @(posedge clk);
      #1 awvalid = 0;
      for (b = 0; b < nb; b = b + 1) begin
        #1 wvalid = 1; wlast = (b == nb - 1);
        for (k = 0; k < 8; k = k + 1) wdata[8*k +: 8] = img[a + 8*b + k];
        @(posedge clk); while (!wready) @(posedge clk);
      end
      #1 wvalid = 0; wlast = 0;
      while (!bvalid) @(posedge clk);
      check(bresp == 2'b00, "AXI4 write burst answered OKAY");
      @(posedge clk);
    end
  endtask
  task automatic load_image(input integer nbytes);
    integer w;
    begin
      for (w = 0; w < (nbytes + 7) / 8; w = w + 256) axi_load(8 * w, ((nbytes + 7) / 8 - w > 256) ? 256 : ((nbytes + 7) / 8 - w));
    end
  endtask
  task automatic axi_read1(input integer a, output [63:0] d);
    begin
      @(posedge clk); #1 arvalid = 1; araddr = a; arlen = 0;
      @(posedge clk); while (!arready) @(posedge clk);
      #1 arvalid = 0;
      @(posedge clk); while (!rvalid) @(posedge clk);
      d = rdata; @(posedge clk);
    end
  endtask
  task automatic run_op(input [31:0] op, input [31:0] lenm, input [31:0] offs, input [31:0] offp, input integer maxc);
    begin
      apb_w(16'h050, op);
      apb_w(16'h058, lenm); apb_w(16'h05C, 0); apb_w(16'h060, 0); apb_w(16'h064, offs); apb_w(16'h068, offp); apb_w(16'h06C, 12288);
      apb_w(16'h070, 32'd1);
      cyc = 0; sts = 32'd1;
      while (sts[0] && cyc < maxc) begin repeat (100) @(posedge clk); cyc = cyc + 100; apb_r(16'h074, sts); end
      repeat (4) @(posedge clk);
      apb_r(16'h074, sts); apb_r(16'h078, errv);
      check(cyc < maxc, "operation ends");
    end
  endtask

  // dsig_cmd.clr and wait until the clearing ends (the lattice word RAM takes 32768 cycles; the buffer answers SLVERR while
  // the IP is busy, REQ-IF-002)
  task automatic do_clr;
    begin
      apb_w(16'h070, 32'd4); repeat (40) @(posedge clk);
      cyc = 0; sts = 32'd1;
      while (sts[0] && cyc < 100000) begin repeat (100) @(posedge clk); cyc = cyc + 100; apb_r(16'h074, sts); end
      check(!sts[0], "clearing ends");
    end
  endtask

  // Ed25519 verification (alg 0, op 2) and ML-DSA-44 verification (alg 9, op 2) with the hybrid policy p
  task automatic ed_verify(input [1:0] p);
    begin
      for (j = 0; j < 16384; j = j + 1) img[j] = 8'd0;
      $sformat(path, "%0s/sys_ed.hex", dir); $readmemh(path, img);
      load_image(1024);
      run_op({2'b00, p, 4'd0, 8'd0, 4'd0, 2'b00, 2'b10, 8'd0}, lmsg_ed, 256, 512, 20000000);
    end
  endtask
  task automatic ml_verify(input [1:0] p, input integer bad);
    begin
      for (j = 0; j < 16384; j = j + 1) img[j] = 8'd0;
      if (bad) $sformat(path, "%0s/sys_mlbad.hex", dir); else $sformat(path, "%0s/sys_ml.hex", dir);
      $readmemh(path, img);
      load_image(nimg);
      run_op({2'b00, p, 4'd0, 8'd0, 4'd0, 2'b00, 2'b10, 8'd9}, lmsg_ml, 8192, 4096, 20000000);
    end
  endtask

  initial begin : main
    reg [63:0] d64;
    if (!$value$plusargs("DIR=%s", dir)) dir = ".";
    $sformat(path, "%0s/sys_len.txt", dir);
    j = $fopen(path, "r"); cyc = $fscanf(j, "%d %d %d\n", lmsg_ed, lmsg_ml, nimg); $fclose(j);
    $sformat(path, "%0s/sys_ed_key.hex", dir); $readmemh(path, edkey);
    repeat (6) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
    // REQ-RESET-001 and ASM-019: after reset the IP is disabled, idle; no DMA request while disabled
    apb_r(16'h074, sts); check(sts == 32'd0, "dsig_sts is 0 after reset (idle, no result, edok and mlok 0)");
    check(!irq && !alarm, "o_irq and o_alarm low after reset");
    check(!dma_in_req && !dma_out_req, "no DMA request while the IP is disabled");
    apb_w(16'h040, 32'd1); apb_w(16'h044, 32'h0000_0201);
    repeat (4) @(posedge clk);
    // ASM-019: the input request rises when enabled, idle, no result; it stays until the acknowledge
    check(dma_in_req, "o_dma_in_req rises when the IP is enabled, idle and has no result");
    repeat (20) @(posedge clk); check(dma_in_req, "o_dma_in_req stays high until the acknowledge");
    @(posedge clk); #1 dma_in_ack = 1; @(posedge clk); #1 dma_in_ack = 0; repeat (2) @(posedge clk);
    check(!dma_in_req, "o_dma_in_req drops after i_dma_in_ack");
    // REQ-IF-005: a word written through the CSR window is read back through AXI4 (same buffer)
    apb_w(16'h090, 32'h3F00); apb_w(16'h094, 32'hCAFE_0123);
    axi_read1(16'h3F00, d64); check(d64[31:0] == 32'hCAFE_0123, "window write at 0x3F00 seen by an AXI4 read of the same word");
    apb_w(16'h090, 32'h3F00); apb_r(16'h098, rd); check(rd == 32'hCAFE_0123, "window read at 0x3F00 returns the written word");
    apb_r(16'h09C, rd); ops0 = rd; apb_r(16'h0A0, rd); fail0 = rd;
    apb_w(16'h080, 32'h1);                                  // dsig_irq_en.done
    // DEC-030 numbered example 2 with real engines
    do_clr;                                                 // (1) dsig_cmd.clr
    apb_r(16'h074, sts); check(!sts[10] && !sts[11], "example 2 (1): clr gives edok 0 and mlok 0");
    ed_verify(2'd0);                                        // (2) Ed25519 valid, policy 0 (both)
    check(errv == 0, "example 2 (2): no error");
    check(sts[8] && sts[10] && !sts[11] && !sts[9], "example 2 (2): resvld, edok 1, mlok 0, sigok 0 (ML-DSA part missing)");
    check(irq, "REQ-IF-003: o_irq high after the done event with dsig_irq_en.done");
    check(dma_out_req, "ASM-019: o_dma_out_req high while a result is valid");
    @(posedge clk); #1 dma_out_ack = 1; @(posedge clk); #1 dma_out_ack = 0; repeat (2) @(posedge clk);
    check(!dma_out_req, "o_dma_out_req drops after i_dma_out_ack");
    apb_w(16'h07C, 32'h1); repeat (4) @(posedge clk);
    check(!irq, "writing 1 to dsig_irq_raw.done clears o_irq");
    ml_verify(2'd0, 0);                                     // (3) ML-DSA valid
    check(errv == 0 && sts[8] && sts[10] && sts[11] && sts[9], "example 2 (3): mlok 1, edok kept, sigok 1");
    ml_verify(2'd0, 1);                                     // (4) ML-DSA corrupted
    check(errv == 0 && sts[8] && sts[10] && !sts[11] && !sts[9], "example 2 (4): mlok 0, sigok 0, no error flag (REQ-ERR-002)");
    ed_verify(2'd1);                                        // (5) policy 1 (Ed25519 valid)
    check(errv == 0 && sts[10] && !sts[11] && sts[9], "example 2 (5): policy 1 and a valid Ed25519 give sigok 1");
    ml_verify(2'd2, 1);                                     // policy 2 (ML-DSA valid) with an invalid ML-DSA signature
    check(errv == 0 && !sts[9] && sts[10], "policy 2 with an invalid ML-DSA signature gives sigok 0");
    // REQ-SEC-006: 5 accepted operations, 2 invalid verifications
    apb_r(16'h09C, rd); check(rd == ops0 + 5, "dsig_cnt_ops counts the 5 operations");
    apb_r(16'h0A0, rd); check(rd == fail0 + 2, "dsig_cnt_fail counts the 2 invalid verifications");
    // REQ-RESET-002: reset of i_rst_n_core during an Ed25519 signing clears the secrets and gives no result
    do_clr;
    for (j = 0; j < 8; j = j + 1) apb_w(16'h100 + 4*j, {edkey[4*j+3], edkey[4*j+2], edkey[4*j+1], edkey[4*j]});
    apb_w(16'h050, 32'h0000_0100); apb_w(16'h058, lmsg_ed); apb_w(16'h06C, 12288);
    apb_w(16'h070, 32'd1);
    repeat (3000) @(posedge clk);
    apb_r(16'h074, sts); check(sts[0], "the signing is running when the reset comes");
    check(dut.w_key_store != 544'd0, "the key store holds the key during the signing");
    #1 rst_n = 0; repeat (3) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
    check(dut.w_key_store == 544'd0, "key store cleared by the reset");
    begin : rf_zero
      integer z; z = 0;
      for (j = 0; j < 32; j = j + 1) if (dut.g_ec.u_ec.reg_rf[j] != 576'd0) z = z + 1;
      check(z == 0 && dut.g_ec.u_ec.reg_sm_sh == 2304'd0 && dut.g_ec.u_ec.reg_head == 1024'd0, "engine registers cleared by the reset");
    end
    apb_r(16'h074, sts); check(sts == 32'd0, "after the reset: idle, no result, edok and mlok 0 (REQ-RESET-001)");
    apb_r(16'h040, rd); check(rd[0] == 1'b0, "after the reset the IP enable is 0");
    apb_r(16'h09C, rd); check(rd == 0, "operation counter reset to 0");
    $display("tb_top_sys: %0d checks, %0d failed", ncheck, nfail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
