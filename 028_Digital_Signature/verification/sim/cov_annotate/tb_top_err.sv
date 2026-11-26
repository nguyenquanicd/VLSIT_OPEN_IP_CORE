//      // verilator_coverage annotation
        // tb_top_err.sv - time-outs of the key port and of the entropy port at the top (REQ-SEC-001, REQ-SEC-007, section 12), the
        // abort command, the lock of the enable bits and the capability words of the CSR. Each check has its expected value from the
        // specification: dsig_err.keytmo (bit 8), dsig_err.enttmo (bit 7), dsig_err.algdis (bit 0), the result flags and the clearing.
        `timescale 1ns/1ps
        module tb_top_err;
 009432   reg clk = 0; always #5 clk = ~clk;
 006737   reg clk_apb = 0; always #7 clk_apb = ~clk_apb;       // the APB clock is asynchronous to the core clock (PARA_CSR_ASYNC = 1)
 000001   reg rst_n = 0;
 000001   reg rst_apb_n = 1;        // separate APB reset for the reset-domain-crossing check (section 7.3, RST-APB)
 000001   reg psel = 0, penable = 0, pwrite = 0; reg [15:0] paddr = 0; reg [31:0] pwdata = 0;
          wire pready, pslverr; wire [31:0] prdata;
          wire key_req; wire [4:0] key_idx; wire ent_req; wire irq, alarm;
 000001   reg key_ok = 0, ent_ok = 0;
          wire dma_in_req, dma_out_req;
          wire awready, wready, bvalid, arready, rvalid, rlast; wire [3:0] bid, rid; wire [1:0] bresp, rresp; wire [63:0] rdata;
        
          m_vlsit_dsig_top #(
            .PARA_EN_ED25519(1), .PARA_EN_ED25519PH(1), .PARA_EN_ECDSA_P256(1), .PARA_OP_KGEN(32'h20), .PARA_OP_SIGN(32'h24), .PARA_OP_VRFY(32'h24), .PARA_BUF_BYTES(1024), .PARA_EN_AXI(1),
            .PARA_EN_KEYIF(1), .PARA_EN_KEYREG(0), .PARA_ECDSA_NONCE(2), .PARA_EN_VAS(0), .PARA_EN_LOG(1), .PARA_EN_LOCK(1), .PARA_CSR_ASYNC(1)
          ) dut (
            .i_clk_core(clk), .i_rst_n_core(rst_n), .i_clk_apb(clk_apb), .i_rst_n_apb(rst_n & rst_apb_n),
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
        
 000001   integer nfail = 0, ncheck = 0, cyc;
          reg [31:0] sts, errv, rd;
 000027   task automatic check(input integer cond, input [8*70-1:0] what);
~000027     begin ncheck = ncheck + 1; if (!cond) begin nfail = nfail + 1; $display("FAIL: %0s (time %0t)", what, $time); end end
          endtask
 000061   task automatic apb_w(input [15:0] a, input [31:0] d);
 000061     begin
 000061       @(posedge clk_apb); #1 psel = 1; penable = 0; pwrite = 1; paddr = a; pwdata = d;
 000061       @(posedge clk_apb); #1 penable = 1;
 000580       @(posedge clk_apb); while (!pready) @(posedge clk_apb);
 000061       #1 psel = 0; penable = 0; pwrite = 0;
            end
          endtask
 000091   task automatic apb_r(input [15:0] a, output [31:0] d);
 000091     begin
 000091       @(posedge clk_apb); #1 psel = 1; penable = 0; pwrite = 0; paddr = a;
 000091       @(posedge clk_apb); #1 penable = 1;
 000798       @(posedge clk_apb); while (!pready) @(posedge clk_apb);
 000091       d = prdata; #1 psel = 0; penable = 0;
            end
          endtask
 000008   task automatic wait_idle(input integer maxc);
 000008     begin
 000008       cyc = 0; sts = 32'd1;
 001320       while (sts[0] && cyc < maxc) begin repeat (20) @(posedge clk); cyc = cyc + 20; apb_r(16'h074, sts); end
 000032       repeat (4) @(posedge clk);
            end
          endtask
 000004   task automatic start_sign;
 000004     begin
 000004       apb_w(16'h050, (1 << 8) | 5);        // alg P-256, op sign, hash SHA-256
 000004       apb_w(16'h058, 32'd4); apb_w(16'h060, 0); apb_w(16'h064, 256); apb_w(16'h068, 512); apb_w(16'h06C, 768);
 000004       apb_w(16'h070, 32'd1);
            end
          endtask
        
 000001   initial begin : main
 000006     repeat (6) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
 000001     apb_r(16'h000, rd); check(rd == 32'h0001_0000, "version 1.0");
 000001     apb_r(16'h004, rd); check(rd == 32'h0000_0025, "capability of the algorithms: Ed25519, Ed25519ph and P-256");
 000001     apb_r(16'h010, rd); check(rd == 32'h0000_0024, "capability of verification: operation mask and built algorithms");
 000001     apb_r(16'h024, rd); check(rd[2] && rd[5] && !rd[6], "capability: AXI4 and key port built, key registers not built");
 000001     apb_w(16'h0AC, 32'h0001_0001);         // key and entropy time-out of one unit (1024 clocks)
            // 1. start while the IP is not enabled: algdis (bit 0), result flags clear
 000001     apb_w(16'h044, 32'h20);
 000001     start_sign;
 000001     wait_idle(5000);
 000001     apb_r(16'h078, errv); check(errv[0], "start with dsig_ctrl.en = 0: dsig_err.algdis");
 000001     check(irq == 1'b0, "no interrupt while irq_en is 0");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
 000001     apb_r(16'h078, errv); check(errv == 0, "dsig_cmd.clr clears dsig_err");
            // 2. key time-out: no word arrives
 000001     apb_w(16'h040, 32'd1);
 000001     start_sign;
 000001     wait_idle(20000);
 000001     apb_r(16'h078, errv); check(errv[8], "key port without answer: dsig_err.keytmo");
 000001     apb_r(16'h074, sts); check(!sts[8] && !sts[0], "no result and not busy after the key time-out");
 000001     check(key_req === 1'b0, "key request dropped");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
            // 3. entropy time-out: the key arrives, the entropy does not
 000001     key_ok = 1;
 000001     start_sign;
 000001     wait_idle(30000);
 000001     apb_r(16'h078, errv); check(errv[7] && !errv[8], "entropy port without answer: dsig_err.enttmo only");
 000001     apb_r(16'h074, sts); check(!sts[8], "no result after the entropy time-out");
 000001     check(dut.w_key_store == 544'd0 && dut.w_pool == 768'd0, "key store and pool empty after the error");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
 000001     apb_r(16'h078, errv); check(errv == 0, "flags cleared again");
            // 4. abort during the key intake
 000001     key_ok = 0;
 000001     start_sign;
 000300     repeat (300) @(posedge clk);
 000001     apb_r(16'h074, sts); check(sts[0], "busy while waiting for the key");
 000001     apb_w(16'h070, 32'd2);                 // dsig_cmd.abort
 000001     wait_idle(20000);
 000001     apb_r(16'h074, sts); check(!sts[0] && !sts[8], "abort: idle without a result");
 000001     apb_r(16'h078, errv); check(!errv[8], "abort before the time-out raises no key time-out");
            // 4b. Ed25519ph takes the digest as the message: the pure form is rejected, the prehash form is accepted by the check
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
 000001     apb_w(16'h044, 32'h24);
 000001     apb_w(16'h050, (1 << 8) | 2);          // alg Ed25519ph, op sign, form pure
 000001     apb_w(16'h058, 32'd64); apb_w(16'h060, 0); apb_w(16'h064, 256); apb_w(16'h068, 512); apb_w(16'h06C, 768);
 000001     apb_w(16'h070, 32'd1);
 000001     wait_idle(5000);
 000001     apb_r(16'h078, errv); check(errv[1] && !errv[8], "Ed25519ph in the pure form: dsig_err.opuns");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
 000001     apb_w(16'h050, (1 << 12) | (1 << 8) | 2);   // form prehash
 000001     apb_w(16'h058, 32'd63);
 000001     apb_w(16'h070, 32'd1);
 000001     wait_idle(5000);
 000001     apb_r(16'h078, errv); check(errv[2] && !errv[1], "Ed25519ph with a digest of 63 bytes: dsig_err.badlen");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
            // 4c. deterministic ECDSA nonce: built for SHA-2 only, so SHA3-256 with dsig_op.nonce = 1 is unsupported; the reserved
            //     nonce code 2 is unsupported as well
 000001     apb_w(16'h050, (3 << 24) | (1 << 20) | (1 << 8) | 5);   // P-256, sign, deterministic nonce, SHA3-256
 000001     apb_w(16'h058, 32'd4);
 000001     apb_w(16'h070, 32'd1);
 000001     wait_idle(5000);
 000001     apb_r(16'h078, errv); check(errv[1], "deterministic nonce with SHA3-256: dsig_err.opuns");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
 000001     apb_w(16'h050, (2 << 20) | (1 << 8) | 5);               // reserved nonce code
 000001     apb_w(16'h070, 32'd1);
 000001     wait_idle(5000);
 000001     apb_r(16'h078, errv); check(errv[1], "reserved dsig_op.nonce code: dsig_err.opuns");
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
            // 5. lock of the enable bits: a later change of dsig_alg_en sets dsig_err.lockv
 000050     apb_w(16'h070, 32'd4); repeat (50) @(posedge clk);
 000001     apb_w(16'h04C, 32'd1);
 000050     repeat (50) @(posedge clk);
 000001     apb_r(16'h04C, rd); check(rd[8], "dsig_lock.locked after the lock request");
 000001     apb_w(16'h044, 32'h00);
 000050     repeat (50) @(posedge clk);
 000001     apb_r(16'h078, errv); check(errv[10], "change of the enables after the lock: dsig_err.lockv");
 000001     apb_r(16'h048, rd); check(rd[5], "dsig_alg_act keeps the held value");
            // 6. reset-domain crossing of the CSR (RST-APB alone, section 7.3): a reset of the APB side in the middle of a write of
            //    dsig_tmo leaves dsig_tmo at its old or its new value (the register domain writes only on the rising edge of the
            //    synchronized request) and leaves the other registers unchanged
 000001     apb_w(16'h0AC, 32'h0003_0003);
 000001     apb_r(16'h048, rd);
 000001     begin : rdc
 000001       reg [31:0] act_before, tmo_after, act_after;
 000001       act_before = rd;
 000001       @(posedge clk_apb); #1 psel = 1; penable = 0; pwrite = 1; paddr = 16'h0AC; pwdata = 32'h0005_0005;
 000001       @(posedge clk_apb); #1 penable = 1;
 000001       @(posedge clk_apb); @(posedge clk_apb);
 000001       #1 rst_apb_n = 0; psel = 0; penable = 0; pwrite = 0;
 000003       repeat (3) @(posedge clk_apb); #1 rst_apb_n = 1;
 000020       repeat (20) @(posedge clk);
 000001       apb_r(16'h0AC, tmo_after);
 000001       check(tmo_after == 32'h0003_0003 || tmo_after == 32'h0005_0005, "RST-APB in a write: dsig_tmo keeps the old or the new value");
 000001       apb_r(16'h048, act_after);
 000001       check(act_after == act_before, "RST-APB in a write: dsig_alg_act unchanged");
 000001       apb_w(16'h0AC, 32'h0007_0007); apb_r(16'h0AC, rd);
 000001       check(rd == 32'h0007_0007, "after RST-APB the CSR handshake works again");
            end
 000001     $display("tb_top_err: %0d checks, %0d failed", ncheck, nfail);
~000001     if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
 000001     $finish;
          end
        endmodule
        
