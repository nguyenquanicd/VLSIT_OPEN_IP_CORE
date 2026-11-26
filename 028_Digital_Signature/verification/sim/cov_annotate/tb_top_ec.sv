//      // verilator_coverage annotation
        // tb_top_ec.sv - system test of the digital signature IP top (elliptic-curve algorithms): APB4 programming
        // as section 11.2, buffer load and result read through the AXI4 subordinate, key from the key registers
        // and from the key port, random bytes from the entropy port, verify-after-sign, secret clearing.
        // The vectors are those of gen_ec_vec.py (RFC 8032, RFC 6979 and rejection cases).
        // Plusargs: +VEC=<hex file> +NVEC=<count> +MAXCYC=<cycles per operation>.
        `timescale 1ns/1ps
        `ifndef TB_RNG_SRC
          `define TB_RNG_SRC 0
        `endif
        `ifndef TB_DPA_EC
          `define TB_DPA_EC 0
        `endif
        module tb_top_ec;
          localparam int BLK = 1024;
 79503061   reg clk = 0; always #5 clk = ~clk;
 000003   reg rst_n = 0;
          // APB
 000003   reg psel = 0, penable = 0, pwrite = 0; reg [15:0] paddr = 0; reg [31:0] pwdata = 0; reg [3:0] pstrb = 0; reg [2:0] pprot = 0;
          wire pready, pslverr; wire [31:0] prdata;
          // AXI4
 000003   reg awvalid = 0; wire awready; reg [3:0] awid = 0; reg [15:0] awaddr = 0; reg [7:0] awlen = 0; reg [2:0] awsize = 3; reg [1:0] awburst = 1;
 000003   reg wvalid = 0; wire wready; reg [63:0] wdata = 0; reg [7:0] wstrb = 0; reg wlast = 0;
 000003   wire bvalid; reg bready = 1; wire [3:0] bid; wire [1:0] bresp;
 000003   reg arvalid = 0; wire arready; reg [3:0] arid = 0; reg [15:0] araddr = 0; reg [7:0] arlen = 0; reg [2:0] arsize = 3; reg [1:0] arburst = 1;
 000003   wire rvalid; reg rready = 1; wire [3:0] rid; wire [63:0] rdata; wire [1:0] rresp; wire rlast;
          // key port and entropy
          wire key_req; wire [4:0] key_idx; wire ent_req; wire irq, alarm;
          wire dma_in_req, dma_out_req;
 000003   reg [543:0] key_vec = 0; reg [767:0] pool_vec = 0;
 000003   reg [4:0] ent_idx = 0;
        
          localparam logic [31:0] ALGMASK = 32'h0000_01FF;
          m_vlsit_dsig_top #(
            .PARA_EN_ED25519(1), .PARA_EN_ED25519CTX(1), .PARA_EN_ED25519PH(1), .PARA_EN_ED448(1), .PARA_EN_ED448PH(1), .PARA_EN_ECDSA_P256(1), .PARA_EN_ECDSA_P384(1), .PARA_EN_ECDSA_P521(1), .PARA_EN_ECDSA_K256(1),
            .PARA_OP_KGEN(ALGMASK), .PARA_OP_SIGN(ALGMASK), .PARA_OP_VRFY(ALGMASK),
            .PARA_EN_PURE(1), .PARA_EN_PREHASH(1), .PARA_BUF_BYTES(1024), .PARA_EN_AXI(1), .PARA_EN_DMA(1), .PARA_EN_WIN(1),
            .PARA_EN_KEYIF(1), .PARA_EN_KEYREG(1), .PARA_KEY_SRC(2), .PARA_ECDSA_NONCE(2), .PARA_EN_VAS(1), .PARA_EN_LOG(1),
            .PARA_CSR_ASYNC(0), .PARA_RNG_SRC(`TB_RNG_SRC), .PARA_EN_DPA_EC(`TB_DPA_EC)
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
 39751532   always @(posedge clk) if (!rst_n) ent_idx <= 0; else if (ent_req) ent_idx <= ent_idx + 1; else ent_idx <= 0;
        
          // Monitors of the features under test: scalar multiplications (blinded = scalar register R14, see ec_progs.smul_secret),
          // entropy words taken, distinct blinding values of the pool
 000003   integer n_smul_blind = 0, n_smul_plain = 0, n_ent_words = 0, n_r_change = 0;
 000003   reg [3:0] ec_st_q = 0; reg [47:0] r_prev = 0;
 39751532   always @(posedge clk) begin
 39751532     ec_st_q <= dut.g_ec.u_ec.reg_fsm_ec_current_state;
            // start of a SMUL instruction: entry into ENUM_ST_SMUL from ENUM_ST_EXEC in phase 0 (not the returns from DBL and ADD)
 39751279     if (dut.g_ec.u_ec.reg_fsm_ec_current_state == 4'd6 && ec_st_q == 4'd2 && dut.g_ec.u_ec.reg_sm_ph == 2'd0) begin
 000219       if (dut.g_ec.u_ec.reg_sm_k == 5'd14) n_smul_blind = n_smul_blind + 1; else n_smul_plain = n_smul_plain + 1;
            end
 39751484     if (ent_req) n_ent_words = n_ent_words + 1;
 39751513     if (dut.w_rng_done) begin
 000018       if (dut.w_pool[8*88 +: 48] != r_prev && dut.w_pool[8*88 +: 48] != 48'd0) n_r_change = n_r_change + 1;
 000019       r_prev <= dut.w_pool[8*88 +: 48];
            end
          end
        
          reg [7:0] vecmem [0:1048575];
          reg [7:0] bmem [0:1023];
 000003   integer nvec, maxcyc, i, j, nfail = 0, ok, vop, ex_err, ex_ok, rl, alg, hsh, lenm, cyc, n_ok_ops = 0;
          reg [31:0] rd, sts, errv;
          reg [8*200-1:0] vecpath;
          reg [63:0] w64;
          reg [7:0] eb;
        
 001315   task automatic apb_w(input [15:0] a, input [31:0] d);
 001315     begin
 001315       @(posedge clk); #1 psel = 1; penable = 0; pwrite = 1; paddr = a; pwdata = d; pstrb = 4'hF;
 001315       @(posedge clk); #1 penable = 1;
 001315       @(posedge clk); while (!pready) @(posedge clk);
 001315       #1 psel = 0; penable = 0; pwrite = 0;
            end
          endtask
 736089   task automatic apb_r(input [15:0] a, output [31:0] d);
 736089     begin
 736089       @(posedge clk); #1 psel = 1; penable = 0; pwrite = 0; paddr = a;
 736089       @(posedge clk); #1 penable = 1;
 736089       @(posedge clk); while (!pready) @(posedge clk);
 736089       d = prdata; #1 psel = 0; penable = 0;
            end
          endtask
        
          // AXI4 burst of nb 64-bit words from bmem to the buffer
 000096   task automatic axi_load(input integer nb);
 000096     integer b;
 000096     begin
 000096       @(posedge clk); #1 awvalid = 1; awaddr = 0; awlen = nb - 1; awsize = 3; awburst = 1;
~000096       @(posedge clk); while (!awready) @(posedge clk);
 000096       #1 awvalid = 0;
 012288       for (b = 0; b < nb; b = b + 1) begin
 012288         #1 wvalid = 1; wstrb = 8'hFF; wlast = (b == nb - 1);
 098304         for (j = 0; j < 8; j = j + 1) wdata[8*j +: 8] = bmem[8*b + j];
~012288         @(posedge clk); while (!wready) @(posedge clk);
              end
 000096       #1 wvalid = 0; wlast = 0;
 000192       while (!bvalid) @(posedge clk);
~000096       if (bresp != 2'b00) begin nfail = nfail + 1; $display("AXI load: bresp %0b", bresp); end
 000096       @(posedge clk);
            end
          endtask
          // AXI4 burst read of nb words into bmem (from byte address a)
 000046   task automatic axi_store(input integer a, input integer nb);
 000046     integer b;
 000046     begin
 000046       @(posedge clk); #1 arvalid = 1; araddr = a; arlen = nb - 1; arsize = 3; arburst = 1;
~000046       @(posedge clk); while (!arready) @(posedge clk);
 000046       #1 arvalid = 0;
 001104       for (b = 0; b < nb; b = b + 1) begin
 002208         @(posedge clk); while (!rvalid) @(posedge clk);
~001104         if (rresp != 2'b00) begin nfail = nfail + 1; $display("AXI store: rresp %0b", rresp); end
 008832         for (j = 0; j < 8; j = j + 1) bmem[a + 8*b + j] = rdata[8*j +: 8];
              end
 000046       @(posedge clk);
            end
          endtask
        
 000003   initial begin : main
~000003     if (!$value$plusargs("VEC=%s", vecpath)) vecpath = "ec_vec.hex";
~000003     if (!$value$plusargs("NVEC=%d", nvec)) nvec = 1;
~000003     if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 60000000;
 000003     $readmemh(vecpath, vecmem);
 000018     repeat (6) @(posedge clk); #1 rst_n = 1; repeat (4) @(posedge clk);
~000003     apb_r(16'h000, rd); if (rd != 32'h0001_0000) begin nfail = nfail + 1; $display("version register %08x", rd); end
 000003     apb_w(16'h040, 32'd1);                 // dsig_ctrl.en
 000003     apb_w(16'h044, ALGMASK);               // dsig_alg_en
 000003     apb_w(16'h0AC, 32'h0001_0001);         // tmo
 000104     for (i = 0; i < nvec; i = i + 1) begin
 000104       ok = 1;
 000104       alg = vecmem[i*BLK + 0]; vop = vecmem[i*BLK + 1]; hsh = vecmem[i*BLK + 2];
 000104       lenm = {vecmem[i*BLK + 7], vecmem[i*BLK + 6], vecmem[i*BLK + 5], vecmem[i*BLK + 4]};
 000104       ex_err = vecmem[i*BLK + 8] + (vecmem[i*BLK + 9] << 8); ex_ok = vecmem[i*BLK + 10]; rl = vecmem[i*BLK + 11];
              // curve and hash pairing of the control block (DEC-032): P-384 needs a digest of at least 48 bytes, P-521 of 64
 000096       if (vop != 0 && ((alg == 6 && (hsh % 3) == 0) || (alg == 7 && (hsh % 3) != 2))) ex_err = 4;
 000096       if (vop == 4) begin $display("VEC %0d SKIP", i); end
 000096       else begin
 098304         for (j = 0; j < 1024; j = j + 1) bmem[j] = 8'd0;
 019200         for (j = 0; j < 200; j = j + 1) bmem[j] = vecmem[i*BLK + 192 + j];
 013440         for (j = 0; j < 140; j = j + 1) bmem[256 + j] = vecmem[i*BLK + 400 + j];
 013440         for (j = 0; j < 140; j = j + 1) bmem[512 + j] = vecmem[i*BLK + 544 + j];
 006528         for (j = 0; j < 68; j = j + 1) key_vec[8*j +: 8] = vecmem[i*BLK + 16 + j];
 009216         for (j = 0; j < 96; j = j + 1) pool_vec[8*j +: 8] = vecmem[i*BLK + 84 + j];
 000096         axi_load(128);
 000096         apb_w(16'h050, (hsh << 24) | (vecmem[i*BLK + 12][0] << 20) | (((alg == 2 || alg == 4) ? 1 : 0) << 12) | ((vop == 3 ? 1 : vop) << 8) | alg);     // dsig_op: alg, op, form, nonce, hash
 000096         apb_w(16'h05C, vecmem[i*BLK + 3]);     // dsig_len_ctx
 000096         apb_w(16'h058, lenm); apb_w(16'h060, 0); apb_w(16'h064, 256); apb_w(16'h068, 512); apb_w(16'h06C, 768);
 000070         if ((vop == 0 || vop == 1 || vop == 3) && (i % 2 == 0))
 000442           for (j = 0; j < 17; j = j + 1) apb_w(16'h100 + 4*j, {key_vec[32*j+24 +: 8], key_vec[32*j+16 +: 8], key_vec[32*j+8 +: 8], key_vec[32*j +: 8]});
 000096         apb_w(16'h070, 32'd1);             // dsig_cmd.start
 000096         cyc = 0; sts = 32'd1;
 735698         while (sts[0] && cyc < maxcyc) begin
 36784900           repeat (50) @(posedge clk); cyc = cyc + 50;
 735698           apb_r(16'h074, sts);
                end
                // status settles one APB access after the last busy cycle
 000384         repeat (4) @(posedge clk);
 000096         apb_r(16'h074, sts); apb_r(16'h078, errv);
~000096         if (cyc >= maxcyc) begin ok = 0; $display("VEC %0d TIMEOUT", i); end
 000096         else begin
 000008           if (ex_err != 0) begin
~000008             if ((errv & ex_err) != ex_err) begin ok = 0; $display("VEC %0d: dsig_err %08x, expected bits %0h", i, errv, ex_err); end
~000008             if (sts[8]) begin ok = 0; $display("VEC %0d: result valid after an error", i); end
 000046           end else if (vop == 2) begin
~000042             if (errv != 0) begin ok = 0; $display("VEC %0d: dsig_err %08x on a verify", i, errv); end
~000042             if (!sts[8]) begin ok = 0; $display("VEC %0d: no result valid after verify", i); end
~000042             if (sts[9] != ex_ok[0]) begin ok = 0; $display("VEC %0d: sigok %0b, expected %0d", i, sts[9], ex_ok); end
 000046           end else begin
~000046             if (errv != 0) begin ok = 0; $display("VEC %0d: dsig_err %08x on sign or keygen", i, errv); end
~000046             if (!sts[8]) begin ok = 0; $display("VEC %0d: no result valid", i); end
 000046             axi_store(768, 24);
 003395             for (j = 0; j < rl; j = j + 1) begin
 003395               eb = vecmem[i*BLK + 688 + j];
~003395               if (bmem[768 + j] != eb) begin ok = 0; $display("VEC %0d: result byte %0d is %02x, expected %02x", i, j, bmem[768 + j], eb); j = rl; end
                    end
                  end
                end
                // secrets are gone after the operation
~000096         if (dut.w_key_store != 544'd0 || dut.w_pool != 768'd0) begin ok = 0; $display("VEC %0d: key store or pool not empty after the operation", i); end
 000096         apb_w(16'h070, 32'd4);             // dsig_cmd.clr
 000384         repeat (4) @(posedge clk);
 000096         apb_r(16'h078, errv); apb_r(16'h074, sts);
~000096         if (errv != 0 || sts[8]) begin ok = 0; $display("VEC %0d: dsig_cmd.clr did not clear err/result", i); end
~000096         if (!ok) nfail = nfail + 1; else n_ok_ops = n_ok_ops + 1;
 000096         $display("VEC %0d %s cycles=%0d", i, ok ? "PASS" : "FAIL", cyc);
              end
            end
 000003     apb_r(16'h09C, rd); $display("dsig_cnt_ops = %0d", rd);
 000003     $display("SMUL instructions: %0d on the blinded register R14, %0d on other registers; entropy words %0d; new blinding values %0d",
 000003              n_smul_blind, n_smul_plain, n_ent_words, n_r_change);
 000001     if (`TB_DPA_EC) begin
~000001       if (n_smul_blind == 0) begin nfail = nfail + 1; $display("FAIL: PARA_EN_DPA_EC 1 but no blinded scalar multiplication"); end
~000001       if (n_r_change < 2) begin nfail = nfail + 1; $display("FAIL: the blinding random does not change between operations"); end
~000002     end else if (n_smul_blind != 0) begin nfail = nfail + 1; $display("FAIL: blinded scalar multiplication without PARA_EN_DPA_EC"); end
 000002     if (`TB_RNG_SRC) begin
 000001       apb_r(16'h0A8, rd);
~000001       if (!rd[8]) begin nfail = nfail + 1; $display("FAIL: dsig_rng.ready is 0 with PARA_RNG_SRC 1"); end
~000001       if (n_ent_words != 24) begin nfail = nfail + 1; $display("FAIL: %0d entropy words with PARA_RNG_SRC 1 (one seed = 24)", n_ent_words); end
            end
 000003     $display("tb_top_ec: %0d vectors, %0d failed", nvec, nfail);
~000003     if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
 000003     $finish;
          end
        endmodule
        
