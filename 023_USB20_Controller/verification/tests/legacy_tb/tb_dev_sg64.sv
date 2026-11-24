`timescale 1ns/1ps
// Scratch full-chip test: device role, UTMI+ 8-bit, AXI4 master DMA, behavioral host and memory.
module tb_dev_sg64;
  localparam int W = 16;
  logic clk_phy = 0, clk_bus = 0;
  always #16.667 clk_phy = ~clk_phy;
  always #5.0 clk_bus = ~clk_bus;
  logic rst_n = 0;

  // APB
  logic [15:0] paddr = 0; logic [31:0] pwdata = 0; logic pwrite = 0, penable = 0, psel = 0;
  logic [3:0] pstrb = 4'hF; logic [2:0] pprot = 0;
  logic pready, pslverr; logic [31:0] prdata;
  // UTMI
  logic [15:0] utmi_dataout; logic utmi_txvalid, utmi_txvalidh, utmi_txready = 1;
  logic [15:0] utmi_datain = 0; logic utmi_rxvalid = 0, utmi_rxvalidh = 0, utmi_rxactive = 0, utmi_rxerror = 0;
  logic [1:0] utmi_linestate = 2'b01;
  logic [1:0] opmode, xcvrsel; logic termsel, suspend_n, db16_8, bs_en, bs_en_h, dppd, dmpd, drvvbus, chrg, dischrg, idpu;
  // AXI master
  logic [3:0] awid; logic [31:0] awaddr; logic [7:0] awlen; logic [2:0] awsize; logic [1:0] awburst; logic [3:0] awcache; logic [2:0] awprot; logic awvalid, awready;
  logic [63:0] wdata; logic [7:0] wstrb; logic wlast, wvalid, wready; logic [3:0] bid = 0; logic [1:0] bresp = 0; logic bvalid = 0, bready;
  logic [3:0] arid; logic [31:0] araddr; logic [7:0] arlen; logic [2:0] arsize; logic [1:0] arburst; logic [3:0] arcache; logic [2:0] arprot; logic arvalid, arready;
  logic [3:0] rid = 0; logic [63:0] rdata = 0; logic [1:0] rresp = 0; logic rlast = 0, rvalid = 0, rready;
  logic int_usb, phy_rst_n, vbus_pwr_en;

  m_usb2_top_utmi_axim #(.PARA_USB2_ROLE(0), .PARA_USB2_NUM_EP(2), .PARA_USB2_NUM_HC(2), .PARA_USB2_FIFO_DEPTH(512), .PARA_USB2_UTMI_W(16), .PARA_USB2_AXI_DATA_W(64), .PARA_USB2_SG_EN(1)) dut (
    .i_clk_phy(clk_phy), .i_clk_bus(clk_bus), .i_rst_n_phy(rst_n), .i_rst_n_bus(rst_n), .o_phy_rst_n(phy_rst_n),
    .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pwrite(pwrite), .i_apb_penable(penable), .i_apb_psel(psel),
    .i_apb_pstrb(pstrb), .i_apb_pprot(pprot), .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata),
    .i_protect_en(1'b0), .i_slverr_en(1'b0), .i_ovrcur_n(1'b1), .o_vbus_pwr_en(vbus_pwr_en), .i_dft_test_en(1'b0),
    .i_dft_scan_en(1'b0), .o_int_usb(int_usb),
    .o_utmi_dataout(utmi_dataout), .o_utmi_txvalid(utmi_txvalid), .o_utmi_txvalidh(utmi_txvalidh), .i_utmi_txready(utmi_txready),
    .i_utmi_datain(utmi_datain), .i_utmi_rxvalid(utmi_rxvalid), .i_utmi_rxvalidh(utmi_rxvalidh), .i_utmi_rxactive(utmi_rxactive),
    .i_utmi_rxerror(utmi_rxerror), .i_utmi_linestate(utmi_linestate), .o_utmi_opmode(opmode), .o_utmi_xcvrsel(xcvrsel),
    .o_utmi_termsel(termsel), .o_utmi_suspend_n(suspend_n), .o_utmi_databus16_8(db16_8), .o_utmi_bitstuff_en(bs_en),
    .o_utmi_bitstuff_en_h(bs_en_h), .o_utmi_dppulldown(dppd), .o_utmi_dmpulldown(dmpd), .i_utmi_hostdisc(1'b0),
    .o_utmi_drvvbus(drvvbus), .o_utmi_chrgvbus(chrg), .o_utmi_dischrgvbus(dischrg), .o_utmi_idpullup(idpu),
    .i_utmi_iddig(1'b1), .i_utmi_avalid(1'b1), .i_utmi_bvalid(1'b1), .i_utmi_vbusvalid(1'b1), .i_utmi_sessend(1'b0),
    .o_axim_awid(awid), .o_axim_awaddr(awaddr), .o_axim_awlen(awlen), .o_axim_awsize(awsize), .o_axim_awburst(awburst),
    .o_axim_awcache(awcache), .o_axim_awprot(awprot), .o_axim_awvalid(awvalid), .i_axim_awready(awready),
    .o_axim_wdata(wdata), .o_axim_wstrb(wstrb), .o_axim_wlast(wlast), .o_axim_wvalid(wvalid), .i_axim_wready(wready),
    .i_axim_bid(bid), .i_axim_bresp(bresp), .i_axim_bvalid(bvalid), .o_axim_bready(bready),
    .o_axim_arid(arid), .o_axim_araddr(araddr), .o_axim_arlen(arlen), .o_axim_arsize(arsize), .o_axim_arburst(arburst),
    .o_axim_arcache(arcache), .o_axim_arprot(arprot), .o_axim_arvalid(arvalid), .i_axim_arready(arready),
    .i_axim_rid(rid), .i_axim_rdata(rdata), .i_axim_rresp(rresp), .i_axim_rlast(rlast), .i_axim_rvalid(rvalid),
    .o_axim_rready(rready));

  // ------------------------------------------------------------------ AXI memory model
  byte unsigned mem [0:65535];
  logic [15:0] w_addr_q; int w_cnt;
  typedef enum {WIDLE, WDATA, WRESP} wst_t;
  wst_t wst = WIDLE;
  assign awready = (wst == WIDLE);
  assign wready  = (wst == WDATA);
  always_ff @(posedge clk_bus) begin
    bvalid <= 1'b0;
    case (wst)
      WIDLE: if (awvalid) begin w_addr_q <= awaddr[15:0]; wst <= WDATA; end
      WDATA: if (wvalid) begin
        for (int b = 0; b < 8; b++) if (wstrb[b]) mem[w_addr_q + b] <= wdata[8*b +: 8];
        w_addr_q <= w_addr_q + 8;
        if (wlast) begin wst <= WRESP; end
      end
      WRESP: begin bvalid <= 1'b1; if (bvalid && bready) begin bvalid <= 1'b0; wst <= WIDLE; end end
    endcase
  end
  typedef enum {RIDLE, RDATA} rst_t;
  rst_t rstt = RIDLE; logic [15:0] r_addr_q; int r_left;
  assign arready = (rstt == RIDLE);
  always_ff @(posedge clk_bus) begin
    case (rstt)
      RIDLE: begin if (!rvalid || rready) rvalid <= 1'b0; if (arvalid) begin r_addr_q <= araddr[15:0]; r_left <= arlen + 1; rstt <= RDATA; end end
      RDATA: begin
        if (!rvalid || rready) begin
          rvalid <= 1'b1;
          rdata  <= {mem[r_addr_q+7], mem[r_addr_q+6], mem[r_addr_q+5], mem[r_addr_q+4], mem[r_addr_q+3], mem[r_addr_q+2], mem[r_addr_q+1], mem[r_addr_q]};
          rlast  <= (r_left == 1);
          if (rvalid && rready) begin
            // beat consumed this cycle, prepare next
          end
          r_addr_q <= r_addr_q + 8;
          r_left <= r_left - 1;
          if (r_left == 1) rstt <= RIDLE; // last beat presented now; rvalid stays until accepted
        end
      end
    endcase
    if (rstt == RIDLE && rvalid && rready) begin rvalid <= 1'b0; rlast <= 1'b0; end
  end

  // ------------------------------------------------------------------ APB tasks
  task automatic apb_wr(input [15:0] a, input [31:0] d);
    @(posedge clk_bus); paddr <= a; pwdata <= d; pwrite <= 1; psel <= 1; penable <= 0;
    @(posedge clk_bus); penable <= 1;
    do @(posedge clk_bus); while (!pready);
    psel <= 0; penable <= 0; pwrite <= 0;
  endtask
  task automatic apb_rd(input [15:0] a, output [31:0] d);
    @(posedge clk_bus); paddr <= a; pwrite <= 0; psel <= 1; penable <= 0;
    @(posedge clk_bus); penable <= 1;
    do @(posedge clk_bus); while (!pready);
    d = prdata; psel <= 0; penable <= 0;
  endtask

  // ------------------------------------------------------------------ host side packet helpers
  function automatic [4:0] crc5_f(input [10:0] d);
    logic [4:0] r; r = 5'h1F;
    for (int i = 0; i < 11; i++) begin
      if (r[4] ^ d[i]) r = {r[3:0], 1'b0} ^ 5'h05; else r = {r[3:0], 1'b0};
    end
    return ~r;
  endfunction
  function automatic [15:0] crc16_f(input byte unsigned data[], input int n);
    logic [15:0] r; r = 16'hFFFF;
    for (int k = 0; k < n; k++)
      for (int i = 0; i < 8; i++) begin
        if (r[15] ^ data[k][i]) r = {r[14:0], 1'b0} ^ 16'h8005; else r = {r[14:0], 1'b0};
      end
    return ~r;
  endfunction
  function automatic [7:0] rev8(input [7:0] x); for (int i = 0; i < 8; i++) rev8[i] = x[7-i]; endfunction
  function automatic [7:0] pidb(input [3:0] p); return {~p, p}; endfunction

  byte unsigned txp [0:2047]; int txp_n;
  task automatic utmi_bytes(input byte unsigned b[], input int n);
    @(posedge clk_phy);
    utmi_rxactive <= 1;
    for (int i = 0; i < n; i += 2) begin
      utmi_datain <= {(i + 1 < n) ? b[i+1] : 8'h00, b[i]}; utmi_rxvalid <= 1; utmi_rxvalidh <= (i + 1 < n); @(posedge clk_phy);
    end
    utmi_rxvalid <= 0; utmi_rxvalidh <= 0;
    @(posedge clk_phy); utmi_rxactive <= 0;
    repeat (2) @(posedge clk_phy);
  endtask
  task automatic send_token(input [3:0] pid, input [6:0] addr, input [3:0] ep);
    byte unsigned b[]; logic [10:0] f; logic [4:0] c;
    f = {ep, addr}; c = crc5_f(f);
    b = new[3]; b[0] = pidb(pid); b[1] = f[7:0]; b[2] = {c, f[10:8]};
    utmi_bytes(b, 3);
  endtask
  task automatic send_data(input [3:0] pid, input byte unsigned pay[], input int n);
    byte unsigned b[]; logic [15:0] c;
    c = crc16_f(pay, n);
    b = new[n + 3]; b[0] = pidb(pid);
    for (int i = 0; i < n; i++) b[1 + i] = pay[i];
    b[n + 1] = rev8(c[15:8]); b[n + 2] = rev8(c[7:0]);
    utmi_bytes(b, n + 3);
  endtask
  task automatic send_hs(input [3:0] pid);
    byte unsigned b[]; b = new[1]; b[0] = pidb(pid); utmi_bytes(b, 1);
  endtask

  // device transmit capture
  byte unsigned cap [0:2047]; int cap_n = 0; int cap_pkts = 0;
  logic cap_active = 0;
  always @(posedge clk_phy) begin
    if (utmi_txvalid && utmi_txready) begin
      cap[cap_n] = utmi_dataout[7:0]; cap_n = cap_n + 1; if (utmi_txvalidh) begin cap[cap_n] = utmi_dataout[15:8]; cap_n = cap_n + 1; end cap_active <= 1;
    end else if (cap_active) begin cap_active <= 0; cap_pkts <= cap_pkts + 1; end
  end
  task automatic wait_resp(output int n, input int tmo);
    int t; t = 0; cap_n = 0;
    while (cap_pkts == 0 && t < tmo) begin @(posedge clk_phy); t++; end
    repeat (4) @(posedge clk_phy);
    n = cap_n; cap_pkts = 0; cap_n = 0;
  endtask

  int npush = 0, nld = 0;
  always @(posedge clk_phy) if (dut.u_core.u_regs.u_xreg.w_upd_wr_en) begin npush++; if (npush < 6) $display("PUSH slot=%0d kind=%0d val=%08x", dut.u_core.u_regs.u_xreg.reg_scan, dut.u_core.u_regs.u_xreg.w_scan_kind, dut.u_core.u_regs.u_xreg.w_scan_val); end
  always @(posedge clk_bus) if (dut.u_core.u_regs.w_ld_en) begin nld++; if (nld < 6) $display("LD slot=%0d kind=%0d val=%08x", dut.u_core.u_regs.w_ld_slot, dut.u_core.u_regs.w_ld_kind, dut.u_core.u_regs.w_ld_val); end
  always @(posedge clk_phy) begin
    if (dut.u_core.w_tok_vld) $display("%t TOK pid=%h fld=%03x", $time, dut.u_core.w_tok_pid, dut.u_core.w_tok_fld);
    if (dut.u_core.w_dat_end) $display("%t DATEND ok=%b len=%0d pid=%h", $time, dut.u_core.w_dat_ok, dut.u_core.w_dat_len, dut.u_core.w_dat_pid);
    if (dut.u_core.w_err_crc | dut.u_core.w_err_pid | dut.u_core.w_err_stuf) $display("%t ERR crc=%b pid=%b stuf=%b", $time, dut.u_core.w_err_crc, dut.u_core.w_err_pid, dut.u_core.w_err_stuf);
    if (dut.u_core.w_hs_vld) $display("%t HS pid=%h", $time, dut.u_core.w_hs_pid);
    if (dut.u_core.w_dev_tx_req) $display("%t DEV TXREQ kind=%0d pid=%h len=%0d", $time, dut.u_core.w_dev_tx_kind, dut.u_core.w_dev_tx_pid, dut.u_core.w_dev_tx_len);
  end
  always @(posedge clk_bus) begin
    if (arvalid && arready) $display("%t AR addr=%08x len=%0d", $time, araddr, arlen);
    if (dut.u_core.gen_dma.u_dma.o_rq_vld && dut.u_core.gen_dma.u_dma.i_rq_rdy) $display("%t RQ op=%0d q=%0d data=%08x", $time, dut.u_core.w_rq_op, dut.u_core.w_rq_q, dut.u_core.w_rq_data);
  end
  int errors = 0, checks = 0;
  task automatic chk(input bit c, input string m); checks++; if (!c) begin errors++; $display("FAIL: %s", m); end endtask

  // main sequence
  logic [31:0] rd; int n;
  byte unsigned pay [];
  task automatic put32(input int a, input [31:0] v);
    mem[a] = v[7:0]; mem[a+1] = v[15:8]; mem[a+2] = v[23:16]; mem[a+3] = v[31:24];
  endtask
  function automatic [31:0] get32(input int a); return {mem[a+3], mem[a+2], mem[a+1], mem[a]}; endfunction
  int dma_err_n = 0;
  always @(posedge clk_bus) if (dut.u_core.gen_dma.u_dma.o_dma_err) dma_err_n++;
  initial begin
    for (int i = 0; i < 65536; i++) mem[i] = 0;
    // descriptor lists: receive list of EP1 at 0x0800, transmit list of EP1 at 0x0900
    put32(16'h0800, 32'h0000_0200); put32(16'h0804, 32'h0003_0040);   // rx desc0 (last, ioc): 64 bytes at 0x0200
    put32(16'h0808, 32'h0000_0300); put32(16'h080C, 32'h0000_0040);   // rx desc1: 64 bytes at 0x0300
    put32(16'h0810, 32'h0000_0380); put32(16'h0814, 32'h0000_0010);   // rx desc2: only 16 bytes at 0x0380
    put32(16'h0900, 32'h0000_0400); put32(16'h0904, 32'h0000_0028);   // tx desc0: 40 bytes at 0x0400
    put32(16'h0908, 32'h0000_0500); put32(16'h090C, 32'h0000_0018);   // tx desc1: 24 bytes at 0x0500
    for (int i = 0; i < 40; i++) mem[16'h0400 + i] = 8'(i + 100);
    for (int i = 0; i < 24; i++) mem[16'h0500 + i] = 8'(i + 200);
    repeat (8) @(posedge clk_bus); rst_n = 1; repeat (20) @(posedge clk_bus);
    apb_wr(16'h0040, {16'd128, 16'd0});        // fifo_rx: start 0, size 128 words
    apb_wr(16'h02C0, {16'd16, 16'd128});       // epi_fifo[0]: start 128, size 16
    apb_wr(16'h02C4, {16'd64, 16'd144});       // epi_fifo[1]: start 144, size 64
    apb_wr(16'h0020, 32'h0000_0085);           // dctrl: addr 5, soft_conn
    apb_wr(16'h0034, 32'h0000_0010);           // dma_cfg burst 16
    apb_wr(16'h002C, 32'h0010_0000);           // hsts.sg_mode = 1
    apb_wr(16'h0484, 32'h0000_0800);           // epo_dma[1] -> descriptor list
    apb_wr(16'h0284, 32'h0000_0900);           // epi_dma[1] -> descriptor list
    apb_wr(16'h0014, 32'h01FF_FFFF);           // irq enables
    apb_wr(16'h0004, 32'h0000_0061);           // ctrl: core_en, dma_en
    repeat (400) @(posedge clk_bus);
    apb_rd(16'h002C, rd); chk(rd[20] == 1'b1, $sformatf("sg_mode reads back, got %08x", rd));

    // T1: OUT EP1, two packets of 64 bytes, one descriptor each
    apb_wr(16'h0444, {3'd0, 10'd2, 19'd128});  // epo_xfer[1]
    apb_wr(16'h0404, 32'h0040_0000 | (2 << 11) | 64);  // epo_ctrl[1]: ep_en, bulk, mps 64
    repeat (400) @(posedge clk_phy);
    pay = new[64]; for (int i = 0; i < 64; i++) pay[i] = i * 3 + 1;
    send_token(4'h1, 7'd5, 4'd1);
    send_data(4'h3, pay, 64);
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'h2), $sformatf("OUT#1 answered ACK, n=%0d b=%02x", n, cap[0]));
    repeat (100) @(posedge clk_phy);
    for (int i = 0; i < 64; i++) pay[i] = i * 5 + 7;
    send_token(4'h1, 7'd5, 4'd1);
    send_data(4'hB, pay, 64);
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'h2), $sformatf("OUT#2 answered ACK, n=%0d b=%02x", n, cap[0]));
    repeat (2500) @(posedge clk_bus);
    for (int i = 0; i < 64; i++) chk(mem[16'h0200 + i] == 8'((i * 3 + 1) & 255), $sformatf("out1 byte %0d", i));
    for (int i = 0; i < 64; i++) chk(mem[16'h0300 + i] == 8'((i * 5 + 7) & 255), $sformatf("out2 byte %0d", i));
    chk(get32(16'h0804) == 32'h0103_0000, $sformatf("rx desc0 write-back %08x", get32(16'h0804)));
    chk(get32(16'h080C) == 32'h0100_0000, $sformatf("rx desc1 write-back %08x", get32(16'h080C)));
    chk(get32(16'h0800) == 32'h0000_0200 && get32(16'h0808) == 32'h0000_0300, "rx descriptor addresses kept");
    apb_rd(16'h0484, rd); chk(rd == 32'h0000_0810, $sformatf("epo_dma[1] advanced to the next descriptor, got %08x", rd));
    apb_rd(16'h04C4, rd); chk(rd[0] == 1'b1, $sformatf("epo_int[1].done, got %08x", rd));

    // T2: OUT EP1 packet of 64 bytes but the descriptor buffer is 16 bytes: not stored, flag, dma_err
    apb_wr(16'h0444, {3'd0, 10'd1, 19'd64});
    apb_wr(16'h0404, 32'h0040_0000 | (1 << 18) | (2 << 11) | 64);
    repeat (400) @(posedge clk_phy);
    for (int i = 0; i < 64; i++) pay[i] = 8'hA5;
    send_token(4'h1, 7'd5, 4'd1);
    send_data(4'h3, pay, 64);
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'h2), $sformatf("OUT#3 answered ACK, n=%0d b=%02x", n, cap[0]));
    repeat (2500) @(posedge clk_bus);
    chk(get32(16'h0814) == 32'h0300_0010, $sformatf("rx desc2 err flag and the bytes not transferred, got %08x", get32(16'h0814)));
    for (int i = 0; i < 16; i++) chk(mem[16'h0380 + i] == 8'h00, $sformatf("overflow packet not stored, byte %0d", i));
    chk(dma_err_n >= 1, $sformatf("dma_err pulse for the overflow, got %0d", dma_err_n));
    apb_rd(16'h0484, rd); chk(rd == 32'h0000_0818, $sformatf("epo_dma[1] after the overflow, got %08x", rd));

    // T3: IN EP1 not armed -> NAK
    send_token(4'h9, 7'd5, 4'd1);
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'hA), $sformatf("IN not armed answered NAK, n=%0d b=%02x", n, cap[0]));

    // T4: IN EP1 armed with 40 bytes, descriptor 0
    apb_wr(16'h0244, {3'd0, 10'd1, 19'd40});   // epi_xfer[1]
    apb_wr(16'h0204, 32'h0040_0000 | (2 << 11) | 64);   // epi_ctrl[1]
    repeat (3000) @(posedge clk_bus);
    send_token(4'h9, 7'd5, 4'd1);
    wait_resp(n, 600);
    chk(n == 43 && cap[0] == pidb(4'h3), $sformatf("IN answered DATA0 with 40 bytes, n=%0d b=%02x", n, cap[0]));
    for (int i = 0; i < 40; i++) chk(cap[1 + i] == 8'(i + 100), $sformatf("in byte %0d got %02x", i, cap[1 + i]));
    send_hs(4'h2);
    repeat (2000) @(posedge clk_bus);
    chk(get32(16'h0904) == 32'h0100_0000, $sformatf("tx desc0 write-back %08x", get32(16'h0904)));
    apb_rd(16'h0284, rd); chk(rd == 32'h0000_0908, $sformatf("epi_dma[1] advanced, got %08x", rd));
    apb_rd(16'h0304, rd); chk(rd[0] == 1'b1, $sformatf("epi_int[1].done, got %08x", rd));

    // T5: IN EP1 armed with 24 bytes, descriptor 1
    apb_wr(16'h0244, {3'd0, 10'd1, 19'd24});
    apb_wr(16'h0204, 32'h0040_0000 | (1 << 18) | (2 << 11) | 64);
    repeat (3000) @(posedge clk_bus);
    send_token(4'h9, 7'd5, 4'd1);
    wait_resp(n, 600);
    chk(n == 27 && cap[0] == pidb(4'hB), $sformatf("IN answered DATA1 with 24 bytes, n=%0d b=%02x", n, cap[0]));
    for (int i = 0; i < 24; i++) chk(cap[1 + i] == 8'(i + 200), $sformatf("in2 byte %0d got %02x", i, cap[1 + i]));
    send_hs(4'h2);
    repeat (2000) @(posedge clk_bus);
    chk(get32(16'h090C) == 32'h0100_0000, $sformatf("tx desc1 write-back %08x", get32(16'h090C)));
    apb_rd(16'h0284, rd); chk(rd == 32'h0000_0910, $sformatf("epi_dma[1] advanced again, got %08x", rd));

    $display("TB_DEV_SG64 checks=%0d errors=%0d", checks, errors);
    $finish;
  end
  initial begin #60000000; $display("TIMEOUT"); $finish; end
endmodule
