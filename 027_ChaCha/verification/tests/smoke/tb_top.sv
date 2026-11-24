`timescale 1ns/1ps
module tb_top;
  parameter DW = 64; parameter SA = 0; parameter SP = 0; parameter string PFX = "enc64";
  parameter AADL = 12; parameter MSGL = 114; parameter DIR = 0; parameter NIN = 17; parameter NOUT = 17;
  parameter EXP_TAGERR = 0; parameter HOLD = 1; parameter AXI_HALF = 6; parameter APB_HALF = 8; parameter CORE_HALF = 5;
  parameter QN = 4; parameter RC = 1; parameter CN = 1; parameter PA = 1; parameter DMA = 0; parameter MSGMAX = 1280; parameter OUTD = 256; parameter WM = 4; parameter TAIL = 0; parameter PC = 0; parameter PP = 0; parameter PI = 0;
  localparam W = DW / 8;
  logic clk_core = 0, clk_axi = 0, clk_apb = 0, rst_n_core = 0, rst_n_axi = 0, rst_n_apb = 0;
  always #CORE_HALF clk_core = ~clk_core;
  always #AXI_HALF  clk_axi  = ~clk_axi;
  always #APB_HALF  clk_apb  = ~clk_apb;
  // APB
  logic [15:0] paddr; logic [31:0] pwdata; logic pwrite, penable, psel; logic [3:0] pstrb; logic [2:0] pprot;
  wire pready, pslverr; wire [31:0] prdata;
  // AXI
  logic [3:0] awid; logic [11:0] awaddr; logic [7:0] awlen; logic [2:0] awsize; logic [1:0] awburst; logic [2:0] awprot; logic awvalid; wire awready;
  logic [DW-1:0] wdata; logic [W-1:0] wstrb; logic wlast, wvalid; wire wready;
  wire [3:0] bid; wire [1:0] bresp; wire bvalid; logic bready;
  logic [3:0] arid; logic [11:0] araddr; logic [7:0] arlen; logic [2:0] arsize; logic [1:0] arburst; logic [2:0] arprot; logic arvalid; wire arready;
  wire [3:0] rid; wire [DW-1:0] rdata; wire [1:0] rresp; wire rlast, rvalid; logic rready;
  wire dma_req_wr, dma_req_rd; logic dma_ack_wr = 0, dma_ack_rd = 0;
  wire key_req; wire [3:0] key_slot; logic [255:0] key_data; logic key_vld = 0, key_err = 0; wire int_cha;
  m_chacha_top #(.PARA_QR_NUM(QN), .PARA_RND_CYC(RC), .PARA_CORE_NUM(CN), .PARA_POLY_ARCH(PA), .PARA_AXI_DW(DW), .PARA_FIFO_IN_DEPTH(16),
    .PARA_FIFO_OUT_DEPTH(OUTD), .PARA_HOLD_EN(HOLD), .PARA_MSG_MAX_B(MSGMAX), .PARA_NONCE_HW(0), .PARA_NONCE_CHK(1), .PARA_DMA_EN(1), .PARA_CG_EN(1), .PARA_PIPE_CHACHA(PC), .PARA_PIPE_POLY(PP), .PARA_PIPE_IO(PI),
    .PARA_SYNC_AXI_CORE(SA), .PARA_SYNC_APB_CORE(SP)) dut (
    .i_clk_apb(clk_apb), .i_rst_n_apb(rst_n_apb), .i_clk_axi(clk_axi), .i_rst_n_axi(rst_n_axi), .i_clk_core(clk_core), .i_rst_n_core(rst_n_core),
    .i_dft_test_en(1'b0), .i_dft_rst_n(1'b1),
    .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pwrite(pwrite), .i_apb_penable(penable), .i_apb_psel(psel), .i_apb_pstrb(pstrb), .i_apb_pprot(pprot),
    .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata), .i_protect_en(1'b0), .i_slverr_en(1'b1),
    .i_axi_awid(awid), .i_axi_awaddr(awaddr), .i_axi_awlen(awlen), .i_axi_awsize(awsize), .i_axi_awburst(awburst), .i_axi_awprot(awprot),
    .i_axi_awvalid(awvalid), .o_axi_awready(awready), .i_axi_wdata(wdata), .i_axi_wstrb(wstrb), .i_axi_wlast(wlast), .i_axi_wvalid(wvalid),
    .o_axi_wready(wready), .o_axi_bid(bid), .o_axi_bresp(bresp), .o_axi_bvalid(bvalid), .i_axi_bready(bready),
    .i_axi_arid(arid), .i_axi_araddr(araddr), .i_axi_arlen(arlen), .i_axi_arsize(arsize), .i_axi_arburst(arburst), .i_axi_arprot(arprot),
    .i_axi_arvalid(arvalid), .o_axi_arready(arready), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp), .o_axi_rlast(rlast),
    .o_axi_rvalid(rvalid), .i_axi_rready(rready), .o_dma_req_wr(dma_req_wr), .i_dma_ack_wr(dma_ack_wr), .o_dma_req_rd(dma_req_rd), .i_dma_ack_rd(dma_ack_rd),
    .o_key_req(key_req), .o_key_slot(key_slot), .i_key_data(key_data), .i_key_vld(key_vld), .i_key_err(key_err), .o_int_cha(int_cha));
  // key store
  always @(posedge clk_core) begin
    if (key_req && !key_vld) key_vld <= 1;
    if (!key_req) key_vld <= 0;
  end
  // APB tasks
  task apb_write(input [15:0] a, input [31:0] d);
    begin
      @(posedge clk_apb); #1 paddr = a; pwdata = d; pwrite = 1; psel = 1; penable = 0; pstrb = 4'hf;
      @(posedge clk_apb); #1 penable = 1;
      @(posedge clk_apb); while (!pready) @(posedge clk_apb);
      #1 psel = 0; penable = 0; pwrite = 0;
    end
  endtask
  task apb_read(input [15:0] a, output [31:0] d);
    begin
      @(posedge clk_apb); #1 paddr = a; pwrite = 0; psel = 1; penable = 0;
      @(posedge clk_apb); #1 penable = 1;
      @(posedge clk_apb); while (!pready) @(posedge clk_apb);
      d = prdata; #1 psel = 0; penable = 0;
    end
  endtask
  // AXI write burst of n beats starting at beat index from the array 'ibeats'
  logic [DW-1:0] ibeats [0:2047]; logic [DW-1:0] expb [0:2047]; logic [DW-1:0] obeats [0:2047];
  integer errs = 0; integer k;
  function [W-1:0] strobe_of(input integer b);
    integer nA_, nM_, nT_;
    begin
      nA_ = (AADL + W - 1) / W; nM_ = (MSGL + W - 1) / W; nT_ = (16 + W - 1) / W;
      strobe_of = {W{1'b1}};
      if (nA_ > 0 && b == nA_ - 1 && (AADL - (nA_ - 1) * W) < W) strobe_of = ((1 << (AADL - (nA_ - 1) * W)) - 1);
      if (nM_ > 0 && b == nA_ + nM_ - 1 && (MSGL - (nM_ - 1) * W) < W) strobe_of = ((1 << (MSGL - (nM_ - 1) * W)) - 1);
      if (DIR && b == nA_ + nM_ + nT_ - 1 && (16 - (nT_ - 1) * W) < W) strobe_of = ((1 << (16 - (nT_ - 1) * W)) - 1);
    end
  endfunction
  task axi_write(input integer first, input integer n, input integer lastbytes);
    integer j;
    begin
      @(posedge clk_axi); #1 awid = 1; awaddr = 12'h000; awlen = n - 1; awsize = $clog2(W); awburst = 1; awprot = 0; awvalid = 1;
      @(posedge clk_axi); while (!awready) @(posedge clk_axi);
      #1 awvalid = 0;
      for (j = 0; j < n; j++) begin
        #1 wdata = ibeats[first + j]; wlast = (j == n - 1); wvalid = 1;
        wstrb = strobe_of(first + j);
        @(posedge clk_axi); while (!wready) @(posedge clk_axi);
      end
      #1 wvalid = 0; wlast = 0; bready = 1;
      @(posedge clk_axi); while (!bvalid) @(posedge clk_axi);
      if (bresp !== 2'b00) begin errs++; $display("write burst BRESP=%b", bresp); end
      #1 bready = 0;
    end
  endtask
  integer rerr;
  task axi_read(input integer n);
    integer j;
    begin
      @(posedge clk_axi); #1 arid = 2; araddr = 12'h000; arlen = n - 1; arsize = $clog2(W); arburst = 1; arprot = 0; arvalid = 1;
      @(posedge clk_axi); while (!arready) @(posedge clk_axi);
      #1 arvalid = 0; rready = 1; j = 0; rerr = 0;
      while (j < n) begin
        @(posedge clk_axi); #0;
        if (rvalid && rready) begin obeats[j] = rdata; if (rresp !== 2'b00) rerr++; j++; end
      end
      #1 rready = 0;
    end
  endtask
  integer rd_done = 0; integer wr_done = 0;
  task dma_wr_proc;
    integer sent, n;
    begin
      sent = 0;
      while (sent < NIN) begin
        @(posedge clk_axi);
        if (dma_req_wr && !dma_ack_wr) begin
          #1 dma_ack_wr = 1;
          while (dma_req_wr) @(posedge clk_axi);
          n = (NIN - sent < WM) ? NIN - sent : WM;
          if (TAIL && (NIN - sent < WM)) n = 1;
          axi_write(sent, n, 0);
          sent = sent + n;
          @(posedge clk_axi); #1 dma_ack_wr = 0;
        end
      end
      wr_done = 1;
    end
  endtask
  task dma_rd_proc(input integer total);
    integer got, n, j;
    begin
      got = 0;
      while (got < total) begin
        @(posedge clk_axi);
        if (dma_req_rd && !dma_ack_rd) begin
          #1 dma_ack_rd = 1;
          while (dma_req_rd) @(posedge clk_axi);
          n = (total - got < WM) ? total - got : WM;
          if (TAIL && (total - got < WM)) n = 1;
          @(posedge clk_axi); #1 arid = 2; araddr = 12'h000; arlen = n - 1; arsize = $clog2(W); arburst = 1; arprot = 0; arvalid = 1;
          @(posedge clk_axi); while (!arready) @(posedge clk_axi);
          #1 arvalid = 0; rready = 1; j = 0;
          while (j < n) begin
            @(posedge clk_axi); #0;
            if (rvalid && rready) begin obeats[got + j] = rdata; if (rresp !== 2'b00) rerr = rerr + 1; j = j + 1; end
          end
          #1 rready = 0; got = got + n;
          @(posedge clk_axi); #1 dma_ack_rd = 0;
        end
      end
      rd_done = 1;
    end
  endtask
  integer cyc = 0; always @(posedge clk_core) cyc <= cyc + 1;
  logic [31:0] rd; integer t0, t1, nA, nM, nT, lastA, lastM, lastT, nout, ii;
  logic [DW-1:0] keyv [0:0]; logic [95:0] noncev [0:0];
  initial begin
    paddr = 0; pwdata = 0; pwrite = 0; penable = 0; psel = 0; pstrb = 4'hf; pprot = 0;
    awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0; wlast = 0; wstrb = 0; wdata = 0;
    $readmemh({PFX,"_in.hex"}, ibeats); $readmemh({PFX,"_out.hex"}, expb);
    begin : rdk logic [255:0] kk [0:0]; $readmemh("key.hex", kk); key_data = kk[0]; end
    begin : rdn logic [95:0] nn [0:0]; $readmemh("nonce.hex", nn); noncev[0] = nn[0]; end
    #50; rst_n_core = 1; rst_n_axi = 1; rst_n_apb = 1;
    repeat (20) @(posedge clk_apb);
    apb_read(16'h3c, rd); $display("cap=%h", rd);
    apb_write(16'h10, noncev[0][31:0]); apb_write(16'h14, noncev[0][63:32]); apb_write(16'h18, noncev[0][95:64]);
    apb_write(16'h08, {MSGL[15:0], AADL[15:0]});
    apb_write(16'h0c, {7'd0, WM[8:0], 7'd0, WM[8:0]});
    nA = (AADL + W - 1) / W; nM = (MSGL + W - 1) / W; nT = (16 + W - 1) / W;
    lastA = AADL - (nA - 1) * W; lastM = MSGL - (nM - 1) * W; lastT = 16 - (nT - 1) * W;
    apb_write(16'h30, 32'h3f);
    apb_write(16'h04, 32'h1 | (DIR << 2) | (3 << 6) | (DMA << 4) | (TAIL << 5));
    apb_write(16'h04, 32'h1 | 32'h2 | (DIR << 2) | (3 << 6) | (DMA << 4) | (TAIL << 5));
    t0 = cyc;
    nout = DIR ? nM : (nM + nT);
    rerr = 0;
    if (DMA) begin
      fork
        dma_wr_proc;
        dma_rd_proc(nout);
      join_none
    end else begin
      apb_read(16'h28, rd); // status read (busy expected)
      if (nA > 0) axi_write(0, nA, lastA);
      if (nM > 0) axi_write(nA, nM, lastM);
      if (DIR) axi_write(nA + nM, nT, lastT);
    end
    // wait for an event
    ii = 0; rd = 0;
    while (rd[1:0] == 0 && ii < 2000) begin apb_read(16'h2c, rd); ii++; end
    t1 = cyc;
    $display("irq_raw=%h int=%b slots key_slot=%0d", rd, int_cha, key_slot);
    if (EXP_TAGERR) begin
      if (rd[1:0] !== 2'b10) begin errs++; $display("expected tag_err only"); end
    end else begin
      if (rd[5:0] !== 6'b000001) begin errs++; $display("expected done only, irq_raw=%b", rd[5:0]); end
    end
    if (!EXP_TAGERR || !HOLD) begin
      if (DMA) begin
        ii = 0; while (!rd_done && ii < 4000) begin @(posedge clk_axi); ii++; end
        if (!rd_done || !wr_done) begin errs++; $display("DMA incomplete wr=%0d rd=%0d", wr_done, rd_done); end
      end else begin
        // let the output buffer settle, then read the result
        repeat (20) @(posedge clk_axi);
        axi_read(nout);
      end
      if (rerr != 0) begin errs++; $display("read errors: %0d", rerr); end
      for (k = 0; k < nout; k++) if (obeats[k] !== expb[k]) begin errs++; $display("beat %0d got %h exp %h", k, obeats[k], expb[k]); end
    end else begin
      // hold mode with a wrong tag: the buffer must stay invisible, a read gets SLVERR
      repeat (60) @(posedge clk_axi);
      axi_read(1);
      if (rerr != 1) begin errs++; $display("hold read returned data (rerr=%0d)", rerr); end
      // The error event of the refused read crosses two clock domains; wait before the clear.
      repeat (60) @(posedge clk_apb);
    end
    apb_write(16'h2c, 32'h3f);
    repeat (30) @(posedge clk_apb);
    apb_read(16'h28, rd);
    if (rd[0]) begin errs++; $display("busy after done"); end
    apb_read(16'h2c, rd); if (rd[5:0] !== 0) begin errs++; $display("irq_raw after clear=%h", rd); end
    $display("RESULT %s DW=%0d SA=%0d SP=%0d Q=%0d R=%0d N=%0d PA=%0d cycles=%0d errors=%0d", PFX, DW, SA, SP, QN, RC, CN, PA, t1 - t0, errs);
    $finish;
  end
  initial begin #3000000; $display("GLOBAL TIMEOUT"); $finish; end
endmodule
