`timescale 1ns/1ps
// Scratch full-chip test: device role, UTMI+ 8-bit, AXI4 master DMA, behavioral host and memory.
module tb_dev_axis;
  localparam int W = 8;
  parameter int PIPE = 0;   // 1: all pipeline options on and a throttled RREADY
  logic clk_phy = 0, clk_bus = 0;
  always #8.333 clk_phy = ~clk_phy;
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
  // AXI slave port driven by the external DMA model
  logic [3:0] s_awid = 0; logic [31:0] s_awaddr = 0; logic [7:0] s_awlen = 0; logic [2:0] s_awsize = 3'd2; logic [1:0] s_awburst = 2'b01; logic s_awvalid = 0, s_awready;
  logic [31:0] s_wdata = 0; logic [3:0] s_wstrb = 4'hF; logic s_wlast = 0, s_wvalid = 0, s_wready;
  logic [3:0] s_bid; logic [1:0] s_bresp; logic s_bvalid, s_bready = 1;
  logic [3:0] s_arid = 0; logic [31:0] s_araddr = 0; logic [7:0] s_arlen = 0; logic [2:0] s_arsize = 3'd2; logic [1:0] s_arburst = 2'b01; logic s_arvalid = 0, s_arready;
  logic [3:0] s_rid; logic [31:0] s_rdata; logic [1:0] s_rresp; logic s_rlast, s_rvalid, s_rready = 1;
  logic [1:0] dma_req; logic [1:0] dma_ack = 0;
  logic int_usb, phy_rst_n, vbus_pwr_en;

  m_usb2_top_utmi_axis #(.PARA_USB2_ROLE(0), .PARA_USB2_NUM_EP(2), .PARA_USB2_NUM_HC(2), .PARA_USB2_FIFO_DEPTH(512), .PARA_USB2_NUM_DMA_CH(2), .PARA_USB2_PIPE_PHY_IN(PIPE), .PARA_USB2_PIPE_RX(PIPE), .PARA_USB2_PIPE_CRC(PIPE), .PARA_USB2_PIPE_XREG(PIPE), .PARA_USB2_PIPE_MODE(PIPE), .PARA_USB2_PIPE_AXS(PIPE)) dut (
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
    .i_axis_awid(s_awid), .i_axis_awaddr(s_awaddr), .i_axis_awlen(s_awlen), .i_axis_awsize(s_awsize), .i_axis_awburst(s_awburst),
    .i_axis_awvalid(s_awvalid), .o_axis_awready(s_awready), .i_axis_wdata(s_wdata), .i_axis_wstrb(s_wstrb), .i_axis_wlast(s_wlast),
    .i_axis_wvalid(s_wvalid), .o_axis_wready(s_wready), .o_axis_bid(s_bid), .o_axis_bresp(s_bresp), .o_axis_bvalid(s_bvalid), .i_axis_bready(s_bready),
    .i_axis_arid(s_arid), .i_axis_araddr(s_araddr), .i_axis_arlen(s_arlen), .i_axis_arsize(s_arsize), .i_axis_arburst(s_arburst),
    .i_axis_arvalid(s_arvalid), .o_axis_arready(s_arready), .o_axis_rid(s_rid), .o_axis_rdata(s_rdata), .o_axis_rresp(s_rresp),
    .o_axis_rlast(s_rlast), .o_axis_rvalid(s_rvalid), .i_axis_rready(s_rready), .o_dma_req(dma_req), .i_dma_ack(dma_ack));

  // ------------------------------------------------------------------ external DMA model
  byte unsigned mem [0:65535];
  int rl_err = 0;
  logic [15:0] lfsr = 16'hACE1;
  always @(posedge clk_bus) begin
    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    s_rready <= (PIPE == 0) | lfsr[0] | lfsr[3];
  end
  task automatic axi_read(input [31:0] a, input int beats, output logic [31:0] d[]);
    d = new[beats];
    @(posedge clk_bus); s_araddr <= a; s_arlen <= beats - 1; s_arvalid <= 1;
    do @(posedge clk_bus); while (!s_arready); s_arvalid <= 0;
    for (int i = 0; i < beats; i++) begin
      do @(posedge clk_bus); while (!(s_rvalid && s_rready));
      d[i] = s_rdata;
      if (s_rlast !== (i == beats - 1)) begin $display("FAIL: RLAST wrong at beat %0d", i); rl_err++; end
    end
  endtask
  task automatic axi_write(input [31:0] a, input int beats, input logic [31:0] d[]);
    @(posedge clk_bus); s_awaddr <= a; s_awlen <= beats - 1; s_awvalid <= 1;
    do @(posedge clk_bus); while (!s_awready); s_awvalid <= 0;
    for (int i = 0; i < beats; i++) begin
      s_wdata <= d[i]; s_wlast <= (i == beats - 1); s_wvalid <= 1;
      do @(posedge clk_bus); while (!s_wready);
    end
    s_wvalid <= 0; s_wlast <= 0;
    while (!s_bvalid) @(posedge clk_bus);
    @(posedge clk_bus);
  endtask

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
    for (int i = 0; i < n; i++) begin
      utmi_datain <= {8'h00, b[i]}; utmi_rxvalid <= 1; @(posedge clk_phy);
    end
    utmi_rxvalid <= 0;
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
      cap[cap_n] <= utmi_dataout[7:0]; cap_n <= cap_n + 1; cap_active <= 1;
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
  int errors = 0, checks = 0;
  task automatic chk(input bit c, input string m); checks++; if (!c) begin errors++; $display("FAIL: %s", m); end endtask

  // main sequence
  logic [31:0] rd; int n;
  byte unsigned pay [];
  initial begin
    for (int i = 0; i < 65536; i++) mem[i] = 0;
    repeat (8) @(posedge clk_bus); rst_n = 1; repeat (20) @(posedge clk_bus);
    // configure
    apb_wr(16'h0040, {16'd128, 16'd0});        // fifo_rx: start 0, size 128 words
    apb_wr(16'h02C0, {16'd16, 16'd128});       // epi_fifo[0]: start 128, size 16
    apb_wr(16'h02C4, {16'd64, 16'd144});       // epi_fifo[1]: start 144, size 64
    apb_wr(16'h0020, 32'h0000_0085);           // dctrl: addr 5, soft_conn
    apb_wr(16'h0034, 32'h0000_0010);           // dma_cfg burst 16
    apb_wr(16'h0480, 32'h0000_0100);           // epo_dma[0]
    apb_wr(16'h0484, 32'h0000_0200);           // epo_dma[1]
    apb_wr(16'h0284, 32'h0000_0400);           // epi_dma[1]
    apb_wr(16'h0014, 32'h01FF_FFFF);           // irq enables
    apb_wr(16'h0004, 32'h0000_0061);           // ctrl: core_en, dma_en, ahb_err_stop
    repeat (400) @(posedge clk_bus);
    $display("shadow ctrl=%08x dctrl=%08x rst_core=%b rst_phy=%b spd_dv_state=%0d dev_act=%b role_host=%b linestate=%b vbus=%b",
      dut.u_core.w_ph_ctrl, dut.u_core.w_ph_dctrl, dut.u_core.w_rst_n_core, dut.u_core.w_rst_n_phy,
      dut.u_core.u_spd.reg_fsm_dv_current_state, dut.u_core.w_dev_act, dut.u_core.w_role_host, dut.u_core.w_linestate, dut.u_core.w_vbusvalid);
    $display("xreg: cmd_empty=%b upd_empty=%b scan=%0d NS=%0d NA=%0d pub_sts=%08x", dut.u_core.u_regs.u_xreg.w_cmd_empty, dut.u_core.u_regs.u_xreg.w_upd_empty,
      dut.u_core.u_regs.u_xreg.reg_scan, dut.u_core.u_regs.LPARA_NS, dut.u_core.u_regs.LPARA_NA, dut.u_core.w_pub_sts);
    apb_rd(16'h0008, rd); $display("sts = %08x", rd);
    apb_rd(16'h0004, rd); $display("ctrl = %08x", rd);

    // map the DMA channels and enable the windows
    apb_wr(16'h0100, 32'h0000_0041);           // dmach_map[0]: read channel, region (tag) 1
    apb_wr(16'h0104, 32'h0000_0061);           // dmach_map[1]: write channel, IN endpoint 1
    apb_wr(16'h002C, 32'h0020_0000);           // hsts.win_en
    repeat (200) @(posedge clk_bus);
    // OUT EP1: arm and send 64 bytes, the external DMA reads them from window 0
    apb_wr(16'h0444, {3'd0, 10'd1, 19'd64});
    apb_wr(16'h0404, 32'h0040_0000 | (2 << 11) | 64);
    repeat (400) @(posedge clk_phy);
    pay = new[64]; for (int i = 0; i < 64; i++) pay[i] = i * 3 + 1;
    send_token(4'h1, 7'd5, 4'd1);
    send_data(4'h3, pay, 64);
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'h2), $sformatf("OUT answered ACK, n=%0d b=%02x", n, cap[0]));
    begin
      int t; t = 0; while (!dma_req[0] && t < 4000) begin @(posedge clk_bus); t++; end
      chk(dma_req[0], "o_dma_req[0] raised for the packet");
      dma_ack <= 2'b01; @(posedge clk_bus); dma_ack <= 2'b00;
      begin
        logic [31:0] d[];
        axi_read(32'h0000_0000, 16, d);
        for (int i = 0; i < 16; i++) for (int b = 0; b < 4; b++)
          chk(d[i][8*b +: 8] == 8'(((i * 4 + b) * 3 + 1) & 255), $sformatf("window read word %0d byte %0d got %02x", i, b, d[i][8*b +: 8]));
      end
    end
    repeat (400) @(posedge clk_bus);
    apb_rd(16'h04C4, rd); chk(rd[0] == 1'b1, $sformatf("epo_int[1].done, got %08x", rd));
    // IN EP1: arm, the external DMA writes 40 bytes into window 1, the host reads them
    apb_wr(16'h0244, {3'd0, 10'd1, 19'd40});
    apb_wr(16'h0204, 32'h0040_0000 | (2 << 11) | 64);
    begin
      int t; t = 0; while (!dma_req[1] && t < 4000) begin @(posedge clk_bus); t++; end
      chk(dma_req[1], "o_dma_req[1] raised for the IN endpoint");
      dma_ack <= 2'b10; @(posedge clk_bus); dma_ack <= 2'b00;
      begin
        logic [31:0] d[];
        d = new[10]; for (int i = 0; i < 10; i++) d[i] = {8'(i*4+103), 8'(i*4+102), 8'(i*4+101), 8'(i*4+100)};
        axi_write(32'h0000_1000, 10, d);
      end
    end
    repeat (400) @(posedge clk_phy);
    send_token(4'h9, 7'd5, 4'd1);
    wait_resp(n, 600);
    chk(n == 43 && cap[0] == pidb(4'h3), $sformatf("IN answered DATA0 with 40 bytes, n=%0d b=%02x", n, cap[0]));
    for (int i = 0; i < 40; i++) chk(cap[1 + i] == 8'(i + 100), $sformatf("in byte %0d got %02x", i, cap[1 + i]));
    send_hs(4'h2);
    repeat (2000) @(posedge clk_bus);
    apb_rd(16'h0304, rd); chk(rd[0] == 1'b1, $sformatf("epi_int[1].done, got %08x", rd));
    $display("TB_DEV_AXIS PIPE=%0d checks=%0d errors=%0d", PIPE, checks, errors + rl_err);
    $finish;
  end
  initial begin #20000000; $display("TIMEOUT"); $finish; end
endmodule
