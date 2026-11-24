// tb_top_err.sv - time-outs of the key port and of the entropy port at the top (REQ-SEC-001, REQ-SEC-007, section 12), the
// abort command, the lock of the enable bits and the capability words of the CSR. Each check has its expected value from the
// specification: dsig_err.keytmo (bit 8), dsig_err.enttmo (bit 7), dsig_err.algdis (bit 0), the result flags and the clearing.
`timescale 1ns/1ps
module tb_top_err;
  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;
  reg psel = 0, penable = 0, pwrite = 0; reg [15:0] paddr = 0; reg [31:0] pwdata = 0;
  wire pready, pslverr; wire [31:0] prdata;
  wire key_req; wire [4:0] key_idx; wire ent_req; wire irq, alarm;
  reg key_ok = 0, ent_ok = 0;
  wire dma_in_req, dma_out_req;
  wire awready, wready, bvalid, arready, rvalid, rlast; wire [3:0] bid, rid; wire [1:0] bresp, rresp; wire [63:0] rdata;

  m_vlsit_dsig_top #(
    .PARA_EN_ECDSA_P256(1), .PARA_OP_KGEN(32'h20), .PARA_OP_SIGN(32'h20), .PARA_OP_VRFY(32'h20), .PARA_BUF_BYTES(1024), .PARA_EN_AXI(1),
    .PARA_EN_KEYIF(1), .PARA_EN_KEYREG(0), .PARA_ECDSA_NONCE(0), .PARA_EN_VAS(0), .PARA_EN_LOG(1), .PARA_EN_LOCK(1), .PARA_CSR_ASYNC(1)
  ) dut (
    .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clk_apb(clk), .i_rst_n_apb(rst_n),
    .i_apb_psel(psel), .i_apb_penable(penable), .i_apb_pwrite(pwrite), .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pstrb(4'hF), .i_apb_pprot(3'd0),
    .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata), .i_protect_en(1'b0), .i_slverr_en(1'b0),
    .i_axi_awvalid(1'b0), .o_axi_awready(awready), .i_axi_awid(4'd0), .i_axi_awaddr(16'd0), .i_axi_awlen(8'd0), .i_axi_awsize(3'd3), .i_axi_awburst(2'b01),
    .i_axi_wvalid(1'b0), .o_axi_wready(wready), .i_axi_wdata(64'd0), .i_axi_wstrb(8'd0), .i_axi_wlast(1'b0),
    .o_axi_bvalid(bvalid), .i_axi_bready(1'b1), .o_axi_bid(bid), .o_axi_bresp(bresp),
    .i_axi_arvalid(1'b0), .o_axi_arready(arready), .i_axi_arid(4'd0), .i_axi_araddr(16'd0), .i_axi_arlen(8'd0), .i_axi_arsize(3'd3), .i_axi_arburst(2'b01),
    .o_axi_rvalid(rvalid), .i_axi_rready(1'b1), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp), .o_axi_rlast(rlast),
    .o_dma_in_req(dma_in_req), .i_dma_in_ack(1'b0), .o_dma_out_req(dma_out_req), .i_dma_out_ack(1'b0),
    .o_key_req(key_req), .o_key_idx(key_idx), .i_key_valid(key_ok & key_req), .i_key_data(32'h0123_4567 + key_idx),
    .o_ent_req(ent_req), .i_ent_valid(ent_ok & ent_req), .i_ent_data(32'hA5A5_0000),
    .o_irq(irq), .o_alarm(alarm));

  integer nfail = 0, ncheck = 0, cyc;
  reg [31:0] sts, errv, rd;
  task automatic check(input integer cond, input [8*70-1:0] what);
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
  task automatic wait_idle(input integer maxc);
    begin
      cyc = 0; sts = 32'd1;
      while (sts[0] && cyc < maxc) begin repeat (20) @(posedge clk); cyc = cyc + 20; apb_r(16'h074, sts); end
      repeat (4) @(posedge clk);
    end
  endtask
  task automatic start_sign;
    begin
      apb_w(16'h050, (1 << 8) | 5);        // alg P-256, op sign, hash SHA-256
      apb_w(16'h058, 32'd4); apb_w(16'h060, 0); apb_w(16'h064, 256); apb_w(16'h068, 512); apb_w(16'h06C, 768);
      apb_w(16'h070, 32'd1);
    end
  endtask

  initial begin : main
    repeat (6) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
    apb_r(16'h000, rd); check(rd == 32'h0001_0000, "version 1.0");
    apb_r(16'h004, rd); check(rd == 32'h0000_0020, "capability of the algorithms: P-256 only");
    apb_r(16'h010, rd); check(rd == 32'h0000_0020, "capability of verification");
    apb_r(16'h024, rd); check(rd[2] && rd[5] && !rd[6], "capability: AXI4 and key port built, key registers not built");
    apb_w(16'h0AC, 32'h0001_0001);         // key and entropy time-out of one unit (1024 clocks)
    // 1. start while the IP is not enabled: algdis (bit 0), result flags clear
    apb_w(16'h044, 32'h20);
    start_sign;
    wait_idle(5000);
    apb_r(16'h078, errv); check(errv[0], "start with dsig_ctrl.en = 0: dsig_err.algdis");
    check(irq == 1'b0, "no interrupt while irq_en is 0");
    apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
    apb_r(16'h078, errv); check(errv == 0, "dsig_cmd.clr clears dsig_err");
    // 2. key time-out: no word arrives
    apb_w(16'h040, 32'd1);
    start_sign;
    wait_idle(20000);
    apb_r(16'h078, errv); check(errv[8], "key port without answer: dsig_err.keytmo");
    apb_r(16'h074, sts); check(!sts[8] && !sts[0], "no result and not busy after the key time-out");
    check(key_req === 1'b0, "key request dropped");
    apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
    // 3. entropy time-out: the key arrives, the entropy does not
    key_ok = 1;
    start_sign;
    wait_idle(30000);
    apb_r(16'h078, errv); check(errv[7] && !errv[8], "entropy port without answer: dsig_err.enttmo only");
    apb_r(16'h074, sts); check(!sts[8], "no result after the entropy time-out");
    check(dut.w_key_store == 544'd0 && dut.w_pool == 768'd0, "key store and pool empty after the error");
    apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
    apb_r(16'h078, errv); check(errv == 0, "flags cleared again");
    // 4. abort during the key intake
    key_ok = 0;
    start_sign;
    repeat (300) @(posedge clk);
    apb_r(16'h074, sts); check(sts[0], "busy while waiting for the key");
    apb_w(16'h070, 32'd2);                 // dsig_cmd.abort
    wait_idle(20000);
    apb_r(16'h074, sts); check(!sts[0] && !sts[8], "abort: idle without a result");
    apb_r(16'h078, errv); check(!errv[8], "abort before the time-out raises no key time-out");
    // 5. lock of the enable bits: a later change of dsig_alg_en sets dsig_err.lockv
    apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
    apb_w(16'h04C, 32'd1);
    repeat (50) @(posedge clk);
    apb_r(16'h04C, rd); check(rd[8], "dsig_lock.locked after the lock request");
    apb_w(16'h044, 32'h00);
    repeat (50) @(posedge clk);
    apb_r(16'h078, errv); check(errv[10], "change of the enables after the lock: dsig_err.lockv");
    apb_r(16'h048, rd); check(rd[5], "dsig_alg_act keeps the held value");
    $display("tb_top_err: %0d checks, %0d failed", ncheck, nfail);
    if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
    $finish;
  end
endmodule
