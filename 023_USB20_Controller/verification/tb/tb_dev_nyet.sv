`timescale 1ns/1ps
// Scratch full-chip test: device role, UTMI+ 8-bit, AXI4 master DMA, behavioral host and memory.
module tb_dev_nyet;
  parameter int PIPE = 0;
  localparam int W = 8;
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
  // AXI master
  logic [3:0] awid; logic [31:0] awaddr; logic [7:0] awlen; logic [2:0] awsize; logic [1:0] awburst; logic [3:0] awcache; logic [2:0] awprot; logic awvalid, awready;
  logic [31:0] wdata; logic [3:0] wstrb; logic wlast, wvalid, wready; logic [3:0] bid = 0; logic [1:0] bresp = 0; logic bvalid = 0, bready;
  logic [3:0] arid; logic [31:0] araddr; logic [7:0] arlen; logic [2:0] arsize; logic [1:0] arburst; logic [3:0] arcache; logic [2:0] arprot; logic arvalid, arready;
  logic [3:0] rid = 0; logic [31:0] rdata = 0; logic [1:0] rresp = 0; logic rlast = 0, rvalid = 0, rready;
  logic int_usb, phy_rst_n, vbus_pwr_en;

  m_usb2_top_utmi_axim #(.PARA_USB2_ROLE(0), .PARA_USB2_NUM_EP(2), .PARA_USB2_NUM_HC(2), .PARA_USB2_FIFO_DEPTH(512), .PARA_USB2_TSCALE(256), .PARA_USB2_PIPE_PHY_IN(PIPE), .PARA_USB2_PIPE_RX(PIPE), .PARA_USB2_PIPE_CRC(PIPE), .PARA_USB2_PIPE_XREG(PIPE), .PARA_USB2_RAM_1P(PIPE)) dut (
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
        for (int b = 0; b < 4; b++) if (wstrb[b]) mem[w_addr_q + b] <= wdata[8*b +: 8];
        w_addr_q <= w_addr_q + 4;
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
          rdata  <= {mem[r_addr_q+3], mem[r_addr_q+2], mem[r_addr_q+1], mem[r_addr_q]};
          rlast  <= (r_left == 1);
          if (rvalid && rready) begin
            // beat consumed this cycle, prepare next
          end
          r_addr_q <= r_addr_q + 4;
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
    int t; t = 0;   // the capture is cleared before the token is sent (the answer can start within 5 cycles)
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
  realtime t_rx_end = 0; int turn_max = 0, turn_n = 0; logic txv_d = 0, rxa_d = 0;
  always @(posedge clk_phy) begin
    rxa_d <= utmi_rxactive; txv_d <= utmi_txvalid;
    if (rxa_d && !utmi_rxactive) t_rx_end = $realtime;
    if (utmi_txvalid && !txv_d && t_rx_end > 0) begin
      turn_n++; if (int'(($realtime - t_rx_end) / 16.666) > turn_max) turn_max = int'(($realtime - t_rx_end) / 16.666);
      t_rx_end = 0;
    end
  end
  int errors = 0, checks = 0;
  task automatic chk(input bit c, input string m); checks++; if (!c) begin errors++; $display("FAIL: %s", m); end endtask

  // A high-speed bus carries a SOF every microframe; without it the idle timer sends the device back to the reset check.
  task automatic idle_sof(input int cycles);
    for (int k = 0; k < cycles / 300; k++) begin send_token(4'h5, 7'(k), 4'd0); repeat (250) @(posedge clk_phy); end
  endtask
  // main sequence
  logic [31:0] rd; int n;
  byte unsigned pay [];
  initial begin
    for (int i = 0; i < 65536; i++) mem[i] = 0;
    repeat (8) @(posedge clk_bus); rst_n = 1; repeat (20) @(posedge clk_bus);
    // configure
    apb_wr(16'h0040, {16'd24, 16'd0});         // fifo_rx: start 0, size 24 words: room for one 64-byte packet only
    apb_wr(16'h02C0, {16'd16, 16'd128});       // epi_fifo[0]: start 128, size 16
    apb_wr(16'h02C4, {16'd64, 16'd144});       // epi_fifo[1]: start 144, size 64
    apb_wr(16'h0020, 32'h0000_0085);           // dctrl: addr 5, soft_conn
    apb_wr(16'h0034, 32'h0000_0010);           // dma_cfg burst 16
    apb_wr(16'h0480, 32'h0000_0100);           // epo_dma[0]
    apb_wr(16'h0484, 32'h0000_0200);           // epo_dma[1]
    apb_wr(16'h0284, 32'h0000_0400);           // epi_dma[1]
    apb_wr(16'h0014, 32'h01FF_FFFF);           // irq enables
    apb_wr(16'h0004, 32'h0000_0001);           // ctrl: core_en only, the DMA stays off so that packets stay in the FIFO
    repeat (400) @(posedge clk_bus);
    $display("shadow ctrl=%08x dctrl=%08x rst_core=%b rst_phy=%b spd_dv_state=%0d dev_act=%b role_host=%b linestate=%b vbus=%b",
      dut.u_core.w_ph_ctrl, dut.u_core.w_ph_dctrl, dut.u_core.w_rst_n_core, dut.u_core.w_rst_n_phy,
      dut.u_core.u_spd.reg_fsm_dv_current_state, dut.u_core.w_dev_act, dut.u_core.w_role_host, dut.u_core.w_linestate, dut.u_core.w_vbusvalid);
    $display("xreg: cmd_empty=%b upd_empty=%b scan=%0d NS=%0d NA=%0d pub_sts=%08x", dut.u_core.u_regs.u_xreg.w_cmd_empty, dut.u_core.u_regs.u_xreg.w_upd_empty,
      dut.u_core.u_regs.u_xreg.reg_scan, dut.u_core.u_regs.LPARA_NS, dut.u_core.u_regs.LPARA_NA, dut.u_core.w_pub_sts);
    apb_rd(16'h0008, rd); $display("sts = %08x", rd);
    apb_rd(16'h0004, rd); $display("ctrl = %08x", rd);

    // bus reset: SE0 on the line; the device must chirp K, then the host chirps KJKJKJ; the device goes to high-speed
    $display("start state=%0d (1 = full-speed idle)", dut.u_core.u_spd.reg_fsm_dv_current_state);
    chk(dut.u_core.u_spd.reg_fsm_dv_current_state == 1, "device in full-speed idle");
    utmi_linestate = 2'b00;
    repeat (200) @(posedge clk_phy);
    $display("after SE0 state=%0d (3 = chirp K)", dut.u_core.u_spd.reg_fsm_dv_current_state);
    chk(dut.u_core.u_spd.reg_fsm_dv_current_state == 3 || dut.u_core.u_spd.reg_fsm_dv_current_state == 4, "chirp K sent after the reset detect");
    chk(xcvrsel == 2'b00 && termsel == 1'b0 && opmode == 2'b10, $sformatf("PHY in chirp mode: xcvr=%b term=%b op=%b", xcvrsel, termsel, opmode));
    while (dut.u_core.u_spd.reg_fsm_dv_current_state == 3) @(posedge clk_phy);
    chk(dut.u_core.u_spd.reg_fsm_dv_current_state == 4, "listening for the host chirps");
    for (int k = 0; k < 4; k++) begin utmi_linestate = 2'b10; repeat (30) @(posedge clk_phy); utmi_linestate = 2'b01; repeat (30) @(posedge clk_phy); end
    repeat (20) @(posedge clk_phy);
    $display("after chirps state=%0d (5 = high-speed) speed=%0d", dut.u_core.u_spd.reg_fsm_dv_current_state, dut.u_core.w_speed);
    chk(dut.u_core.u_spd.reg_fsm_dv_current_state == 5, "high-speed reached after the host chirps");
    chk(dut.u_core.w_speed == 2'd0, "speed is high-speed");
    chk(xcvrsel == 2'b00 && termsel == 1'b0 && opmode == 2'b00, $sformatf("PHY in high-speed mode: xcvr=%b term=%b op=%b", xcvrsel, termsel, opmode));
    utmi_linestate = 2'b00;
    repeat (50) @(posedge clk_bus);
    apb_rd(16'h0008, rd); chk(rd[2:1] == 2'd0, $sformatf("u2_sts.speed = high-speed, sts=%08x", rd));
    apb_rd(16'h0010, rd); $display("irq_raw=%08x (rst bit1, enum bit7)", rd); chk(rd[1] == 1'b1 && rd[7] == 1'b1, "rst and enum interrupt flags");
    // ------------------------------------------------------------ high-speed bulk OUT: NYET, PING, NAK, ACK
    apb_wr(16'h0444, {3'd0, 10'd4, 19'd256});  // epo_xfer[1]: 256 bytes, 4 packets
    apb_wr(16'h0404, 32'h0040_0000 | (2 << 11) | 64);   // epo_ctrl[1]: ep_en, bulk, mps 64
    repeat (400) @(posedge clk_phy);
    pay = new[64]; for (int i = 0; i < 64; i++) pay[i] = i * 3 + 1;
    cap_n = 0; cap_pkts = 0;
    send_token(4'h1, 7'd5, 4'd1);
    send_data(4'h3, pay, 64);
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'h6), $sformatf("OUT#1 answered NYET (no room for another packet), n=%0d b=%02x", n, cap[0]));
    repeat (100) @(posedge clk_phy);
    cap_n = 0; cap_pkts = 0;
    send_token(4'h4, 7'd5, 4'd1);              // PING
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'hA), $sformatf("PING answered NAK while the FIFO is full, n=%0d b=%02x", n, cap[0]));
    apb_wr(16'h0004, 32'h0000_0061);           // dma_en: the packet is drained to memory
    idle_sof(2000);
    for (int i = 0; i < 64; i++) chk(mem[16'h0200 + i] == 8'((i * 3 + 1) & 255), $sformatf("drained byte %0d", i));
    cap_n = 0; cap_pkts = 0;
    send_token(4'h4, 7'd5, 4'd1);              // PING again
    wait_resp(n, 400);
    chk(n == 1 && cap[0] == pidb(4'h2), $sformatf("PING answered ACK after the room is back, n=%0d b=%02x", n, cap[0]));
    for (int i = 0; i < 64; i++) pay[i] = i * 5 + 7;
    cap_n = 0; cap_pkts = 0;
    send_token(4'h1, 7'd5, 4'd1);
    send_data(4'hB, pay, 64);
    wait_resp(n, 400);
    chk(n == 1 && (cap[0] == pidb(4'h6) || cap[0] == pidb(4'h2)), $sformatf("OUT#2 answered NYET or ACK, n=%0d b=%02x", n, cap[0]));
    idle_sof(2000);
    for (int i = 0; i < 64; i++) chk(mem[16'h0240 + i] == 8'((i * 5 + 7) & 255), $sformatf("second packet byte %0d", i));
    $display("TB_DEV_NYET PIPE=%0d checks=%0d errors=%0d turnaround max=%0d cycles over %0d responses", PIPE, checks, errors, turn_max, turn_n);
    $finish;
  end
  initial begin #20000000; $display("TIMEOUT"); $finish; end
endmodule
