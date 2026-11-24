`timescale 1ns/1ps
// Scratch full-chip test: host role, ULPI 8-bit, AXI4 master DMA, behavioral full-speed device and memory.
// The ULPI PHY model decodes the TX CMD packets of the host and injects the answers of the device.
module tb_host_ulpi;
  logic clk_phy = 0, clk_bus = 0;
  logic clk_run = 1;
  always #8.333 if (clk_run) clk_phy = ~clk_phy;
  always #5.0 clk_bus = ~clk_bus;
  logic rst_n = 0;
  logic [15:0] paddr = 0; logic [31:0] pwdata = 0; logic pwrite = 0, penable = 0, psel = 0;
  logic pready, pslverr; logic [31:0] prdata;
  logic ulpi_dir = 0, rx_nxt = 0, tx_nxt = 0; wire ulpi_nxt = rx_nxt | tx_nxt;
  logic [7:0] ulpi_data_in = 0; logic ulpi_stp; logic [7:0] ulpi_data_out; logic ulpi_oe;
  logic [3:0] awid; logic [31:0] awaddr; logic [7:0] awlen; logic [2:0] awsize; logic [1:0] awburst; logic [3:0] awcache; logic [2:0] awprot; logic awvalid, awready;
  logic [31:0] wdata; logic [3:0] wstrb; logic wlast, wvalid, wready; logic [3:0] bid = 0; logic [1:0] bresp = 0; logic bvalid = 0, bready;
  logic [3:0] arid; logic [31:0] araddr; logic [7:0] arlen; logic [2:0] arsize; logic [1:0] arburst; logic [3:0] arcache; logic [2:0] arprot; logic arvalid, arready;
  logic [3:0] rid = 0; logic [31:0] rdata = 0; logic [1:0] rresp = 0; logic rlast = 0, rvalid = 0, rready;
  logic int_usb, phy_rst_n, vbus_pwr_en;

  m_usb2_top_ulpi_axim #(.PARA_USB2_ROLE(1), .PARA_USB2_NUM_EP(1), .PARA_USB2_NUM_HC(2), .PARA_USB2_FIFO_DEPTH(512), .PARA_USB2_TSCALE(256)) dut (
    .i_clk_phy(clk_phy), .i_clk_bus(clk_bus), .i_rst_n_phy(rst_n), .i_rst_n_bus(rst_n), .o_phy_rst_n(phy_rst_n),
    .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pwrite(pwrite), .i_apb_penable(penable), .i_apb_psel(psel),
    .i_apb_pstrb(4'hF), .i_apb_pprot(3'd0), .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata),
    .i_protect_en(1'b0), .i_slverr_en(1'b0), .i_ovrcur_n(1'b1), .o_vbus_pwr_en(vbus_pwr_en), .i_dft_test_en(1'b0),
    .i_dft_scan_en(1'b0), .o_int_usb(int_usb),
    .i_ulpi_dir(ulpi_dir), .i_ulpi_nxt(ulpi_nxt), .o_ulpi_stp(ulpi_stp), .i_ulpi_data(ulpi_data_in),
    .o_ulpi_data(ulpi_data_out), .o_ulpi_data_oe(ulpi_oe),
    .o_axim_awid(awid), .o_axim_awaddr(awaddr), .o_axim_awlen(awlen), .o_axim_awsize(awsize), .o_axim_awburst(awburst),
    .o_axim_awcache(awcache), .o_axim_awprot(awprot), .o_axim_awvalid(awvalid), .i_axim_awready(awready),
    .o_axim_wdata(wdata), .o_axim_wstrb(wstrb), .o_axim_wlast(wlast), .o_axim_wvalid(wvalid), .i_axim_wready(wready),
    .i_axim_bid(bid), .i_axim_bresp(bresp), .i_axim_bvalid(bvalid), .o_axim_bready(bready),
    .o_axim_arid(arid), .o_axim_araddr(araddr), .o_axim_arlen(arlen), .o_axim_arsize(arsize), .o_axim_arburst(arburst),
    .o_axim_arcache(arcache), .o_axim_arprot(arprot), .o_axim_arvalid(arvalid), .i_axim_arready(arready),
    .i_axim_rid(rid), .i_axim_rdata(rdata), .i_axim_rresp(rresp), .i_axim_rlast(rlast), .i_axim_rvalid(rvalid),
    .o_axim_rready(rready));

  // AXI memory
  byte unsigned mem [0:65535];
  logic [15:0] w_addr_q;
  typedef enum {WIDLE, WDATA, WRESP} wst_t; wst_t wst = WIDLE;
  assign awready = (wst == WIDLE); assign wready = (wst == WDATA);
  always_ff @(posedge clk_bus) begin
    bvalid <= 1'b0;
    case (wst)
      WIDLE: if (awvalid) begin w_addr_q <= awaddr[15:0]; wst <= WDATA; end
      WDATA: if (wvalid) begin
        for (int b = 0; b < 4; b++) if (wstrb[b]) mem[w_addr_q + b] <= wdata[8*b +: 8];
        w_addr_q <= w_addr_q + 4; if (wlast) wst <= WRESP; end
      WRESP: begin bvalid <= 1'b1; if (bvalid && bready) begin bvalid <= 1'b0; wst <= WIDLE; end end
    endcase
  end
  typedef enum {RIDLE, RDATA} rst_t; rst_t rstt = RIDLE; logic [15:0] r_addr_q; int r_left;
  assign arready = (rstt == RIDLE);
  always_ff @(posedge clk_bus) begin
    case (rstt)
      RIDLE: begin if (!rvalid || rready) rvalid <= 1'b0; if (arvalid) begin r_addr_q <= araddr[15:0]; r_left <= arlen + 1; rstt <= RDATA; end end
      RDATA: if (!rvalid || rready) begin
        rvalid <= 1'b1; rdata <= {mem[r_addr_q+3], mem[r_addr_q+2], mem[r_addr_q+1], mem[r_addr_q]};
        rlast <= (r_left == 1); r_addr_q <= r_addr_q + 4; r_left <= r_left - 1; if (r_left == 1) rstt <= RIDLE; end
    endcase
    if (rstt == RIDLE && rvalid && rready) begin rvalid <= 1'b0; rlast <= 1'b0; end
  end

  task automatic apb_wr(input [15:0] a, input [31:0] d);
    @(posedge clk_bus); paddr <= a; pwdata <= d; pwrite <= 1; psel <= 1; penable <= 0;
    @(posedge clk_bus); penable <= 1; do @(posedge clk_bus); while (!pready);
    psel <= 0; penable <= 0; pwrite <= 0;
  endtask
  task automatic apb_rd(input [15:0] a, output [31:0] d);
    @(posedge clk_bus); paddr <= a; pwrite <= 0; psel <= 1; penable <= 0;
    @(posedge clk_bus); penable <= 1; do @(posedge clk_bus); while (!pready);
    d = prdata; psel <= 0; penable <= 0;
  endtask

  function automatic [7:0] rev8(input [7:0] x); for (int i = 0; i < 8; i++) rev8[i] = x[7-i]; endfunction
  function automatic [7:0] pidb(input [3:0] p); return {~p, p}; endfunction
  function automatic [15:0] crc16_f(input byte unsigned data[], input int n);
    logic [15:0] r; r = 16'hFFFF;
    for (int k = 0; k < n; k++) for (int i = 0; i < 8; i++) begin
      if (r[15] ^ data[k][i]) r = {r[14:0], 1'b0} ^ 16'h8005; else r = {r[14:0], 1'b0}; end
    return ~r;
  endfunction
  // receive injection: dir and nxt rise together (turnaround), data bytes with nxt, an RX CMD with RxActive 0, dir falls
  task automatic ulpi_rx(input byte unsigned b[], input int n);
    @(posedge clk_phy); ulpi_dir <= 1; rx_nxt <= 1; ulpi_data_in <= 8'h00;
    for (int i = 0; i < n; i++) begin @(posedge clk_phy); ulpi_data_in <= b[i]; rx_nxt <= 1; end
    @(posedge clk_phy); rx_nxt <= 0; ulpi_data_in <= 8'h0D;
    @(posedge clk_phy); ulpi_dir <= 0; rx_nxt <= 0; ulpi_data_in <= 8'h00;
    repeat (3) @(posedge clk_phy);
  endtask
  task automatic rx_cmd(input [7:0] c);
    @(posedge clk_phy); ulpi_dir <= 1; rx_nxt <= 0; ulpi_data_in <= 8'h00;
    @(posedge clk_phy); ulpi_data_in <= c;
    @(posedge clk_phy); ulpi_data_in <= c;
    @(posedge clk_phy); ulpi_dir <= 0; ulpi_data_in <= 8'h00;
    repeat (2) @(posedge clk_phy);
  endtask
  task automatic dev_data(input [3:0] pid, input byte unsigned pay[], input int n);
    byte unsigned b[]; logic [15:0] c; c = crc16_f(pay, n);
    b = new[n + 3]; b[0] = pidb(pid); for (int i = 0; i < n; i++) b[1 + i] = pay[i];
    b[n + 1] = rev8(c[15:8]); b[n + 2] = rev8(c[7:0]); ulpi_rx(b, n + 3);
  endtask
  task automatic dev_hs(input [3:0] pid);
    byte unsigned b[]; b = new[1]; b[0] = pidb(pid); ulpi_rx(b, 1);
  endtask

  // PHY transmit side: TX CMD with PID, payload bytes while nxt is high, stp ends the packet;
  // register writes are accepted and counted
  byte unsigned cap [0:2047]; int cap_n = 0;
  byte unsigned pk [0:2047]; int pk_n; logic pk_ready = 0; logic ev_done = 0;
  typedef enum {PIDLE, PCMD, PFIRST, PDATA, PRCMD, PRDATA, PRD0, PRD1, PRD2, PRD3} pst_t; pst_t pst = PIDLE;
  int nreg = 0, nrd = 0; logic [7:0] last_reg_cmd = 0, d0 = 0, d1 = 0, rd_addr = 0;
  byte unsigned ph_reg [0:255];
  initial begin for (int i = 0; i < 256; i++) ph_reg[i] = 8'h00; ph_reg[0] = 8'h24; ph_reg[1] = 8'h04; end
  always @(posedge clk_phy) begin
    pk_ready <= 1'b0;
    if (ev_done) begin
      ev_done <= 1'b0; pk_n = cap_n; for (int i = 0; i < cap_n; i++) pk[i] = cap[i]; pk_ready <= 1'b1;
    end
    case (pst)
      PIDLE: begin
        tx_nxt <= 0;
        if (!ulpi_dir && ulpi_oe && ulpi_data_out[7:6] == 2'b01) begin
          cap[0] <= {~ulpi_data_out[3:0], ulpi_data_out[3:0]}; cap_n <= 1; pst <= PCMD;
        end else if (!ulpi_dir && ulpi_oe && ulpi_data_out[7:6] == 2'b10) begin last_reg_cmd <= ulpi_data_out; d0 <= 0; d1 <= 0; pst <= PRCMD; end
        else if (!ulpi_dir && ulpi_oe && ulpi_data_out[7:6] == 2'b11) begin rd_addr <= {2'b00, ulpi_data_out[5:0]}; pst <= PRD0; end
      end
      PCMD: begin tx_nxt <= 1; pst <= PFIRST; end
      PFIRST: begin pst <= PDATA; end
      PDATA: begin
        if (ulpi_stp) begin tx_nxt <= 0; ev_done <= 1'b1; pst <= PIDLE; end
        else if (ulpi_nxt) begin cap[cap_n] <= ulpi_data_out; cap_n <= cap_n + 1; end
      end
      PRCMD: begin tx_nxt <= 1; pst <= PRDATA; end
      PRDATA: begin
        if (ulpi_stp) begin tx_nxt <= 0; nreg <= nreg + 1; ph_reg[(last_reg_cmd == 8'hAF) ? d1 : {2'b00, last_reg_cmd[5:0]}] <= d0; pst <= PIDLE; end
        else begin d1 <= d0; d0 <= ulpi_data_out; end
      end
      PRD0: begin tx_nxt <= 1; pst <= PRD1; end
      PRD1: begin tx_nxt <= 0; ulpi_dir <= 1; pst <= PRD2; end
      PRD2: begin ulpi_data_in <= ph_reg[rd_addr]; pst <= PRD3; end
      PRD3: begin ulpi_dir <= 0; ulpi_data_in <= 8'h00; nrd <= nrd + 1; pst <= PIDLE; end
      default: pst <= PIDLE;
    endcase
  end

  int sof_n = 0, out_n = 0, in_n = 0, ack_n = 0;
  byte unsigned out_rx [0:255]; int out_rx_n = 0;
  byte unsigned in_data [0:7];
  logic last_was_out = 0; logic ext_seen = 0; int lpm_n = 0;
  // device reaction (full-speed device at address 3): respond to OUT data and IN tokens
  always @(posedge clk_phy) if (pk_ready) begin
    case (pk[0])
      8'hA5: sof_n++;
      8'hF0: begin ext_seen = 1; last_was_out = 0; end
      8'hE1: begin out_n++; last_was_out = 1; end
      8'h69: begin in_n++; last_was_out = 0; repeat (6) @(posedge clk_phy); dev_data(4'h3, in_data, 8); end
      8'hC3, 8'h4B: begin
        if (ext_seen && pk[0] == 8'hC3 && pk_n == 3) begin ext_seen = 0; lpm_n++; repeat (6) @(posedge clk_phy); dev_hs(4'h2); end else
        if (last_was_out) begin for (int i = 0; i < pk_n - 3; i++) out_rx[out_rx_n + i] = pk[1 + i]; out_rx_n += pk_n - 3; repeat (6) @(posedge clk_phy); dev_hs(4'h2); end
      end
      8'hD2: ack_n++;
      default: ;
    endcase
  end

  int errors = 0, checks = 0;
  task automatic chk(input bit c, input string m); checks++; if (!c) begin errors++; $display("FAIL: %s", m); end endtask
  logic [31:0] rd; int guard; logic [7:0] rb;
  task automatic phy_acc(input [31:0] w, output [7:0] rdat);
    logic [31:0] r; int g;
    apb_wr(16'h003C, w); g = 0; r = w;
    while (r[25] && g < 400) begin repeat (100) @(posedge clk_bus); apb_rd(16'h003C, r); g++; end
    rdat = r[23:16];
  endtask
  initial begin
    for (int i = 0; i < 65536; i++) mem[i] = 0;
    for (int i = 0; i < 8; i++) in_data[i] = 8'hA0 + i;
    for (int i = 0; i < 16; i++) mem[16'h0600 + i] = 8'h30 + i;
    repeat (8) @(posedge clk_bus); rst_n = 1; repeat (20) @(posedge clk_bus);
    // the PHY sends an RX CMD after reset: line state J (full-speed device attached), VBUS valid, ID grounded
    @(posedge clk_phy); ulpi_dir <= 1; rx_nxt <= 0; ulpi_data_in <= 8'h00;
    @(posedge clk_phy); ulpi_data_in <= 8'h0D;
    @(posedge clk_phy); ulpi_data_in <= 8'h0D;
    @(posedge clk_phy); ulpi_dir <= 0; ulpi_data_in <= 8'h00;
    repeat (20) @(posedge clk_phy);
    apb_wr(16'h0044, {16'd128, 16'd0});        // fifo_hnp start 0 size 128
    apb_wr(16'h0048, {16'd16, 16'd128});       // fifo_hpt start 128 size 16
    apb_wr(16'h0040, {16'd128, 16'd160});      // fifo_rx start 160 size 128
    apb_wr(16'h0034, 32'h10);
    apb_wr(16'h0030, 32'd7500);                // sof_cfg
    apb_wr(16'h0028, 32'h0000_0008);           // hport: vbus_drv
    apb_wr(16'h0004, 32'h0000_0061);           // ctrl: core_en dma_en
    apb_wr(16'h0014, 32'h01FF_FFFF);
    guard = 0; rd = 0;
    while (rd[0] == 1'b0 && guard < 400) begin repeat (200) @(posedge clk_bus); if (guard < 8) rx_cmd(8'h0D); apb_rd(16'h002C, rd); guard++; end
    chk(rd[0] == 1'b1, $sformatf("port connected hsts=%08x", rd));
    apb_wr(16'h0028, 32'h0000_0009);           // vbus_drv + prst
    guard = 0; rd = 0;
    while (rd[1] == 1'b0 && guard < 600) begin repeat (200) @(posedge clk_bus); apb_rd(16'h002C, rd); guard++; end
    chk(rd[1] == 1'b1, $sformatf("port enabled hsts=%08x", rd));
    chk(rd[3:2] == 2'd1, "port speed is full-speed");
    apb_wr(16'h0028, 32'h0000_0018);           // vbus_drv + sof_en
    repeat (4000) @(posedge clk_phy);
    chk(sof_n >= 1, $sformatf("SOF packets over ULPI, got %0d", sof_n));
    chk(nreg >= 1, $sformatf("ULPI register writes of the function control, got %0d", nreg));
    // PHY register access through u2_phy_acc: write a scratch register, read it back, read the vendor ID
    phy_acc((1 << 25) | (1 << 24) | (8'h5A << 8) | 8'h16, rb);
    chk(ph_reg[8'h16] == 8'h5A, $sformatf("PHY register 0x16 written, got %02x", ph_reg[8'h16]));
    phy_acc((1 << 25) | 8'h16, rb);
    chk(rb == 8'h5A, $sformatf("PHY register 0x16 read back, got %02x", rb));
    phy_acc((1 << 25) | 8'h00, rb);
    chk(rb == 8'h24, $sformatf("PHY vendor ID low read, got %02x", rb));
    chk(nrd >= 2, $sformatf("PHY register reads, got %0d", nrd));
    // channel 0: OUT bulk, dev 3, ep 1, mps 8: xsize 16 packets 2
    apb_wr(16'h0780, 32'h0);
    apb_wr(16'h06C0, 32'h0000_0600);
    apb_wr(16'h0680, {1'b0, 2'd0, 10'd2, 19'd16});
    apb_wr(16'h0600, 32'h8000_0000 | (3 << 20) | (1 << 18) | (2 << 16) | (0 << 15) | (1 << 11) | 8);
    repeat (60000) @(posedge clk_phy);
    chk(out_n == 2, $sformatf("two OUT tokens, got %0d", out_n));
    chk(out_rx_n == 16, $sformatf("16 data bytes received, got %0d", out_rx_n));
    for (int i = 0; i < 16; i++) chk(out_rx[i] == 8'(8'h30 + i), $sformatf("out byte %0d got %02x", i, out_rx[i]));
    apb_rd(16'h0700, rd); chk(rd[0] == 1'b1, $sformatf("hc_int[0].done, got %08x", rd));
    // channel 1: IN bulk, dev 3, ep 1, mps 8, xsize 8
    apb_wr(16'h06C4, 32'h0000_0700);
    apb_wr(16'h0684, {1'b0, 2'd0, 10'd1, 19'd8});
    apb_wr(16'h0604, 32'h8000_0000 | (3 << 20) | (1 << 18) | (2 << 16) | (1 << 15) | (1 << 11) | 8);
    repeat (60000) @(posedge clk_phy);
    chk(in_n >= 1, "IN token sent");
    chk(ack_n >= 1, "host ACK sent for the IN data");
    repeat (4000) @(posedge clk_bus);
    for (int i = 0; i < 8; i++) chk(mem[16'h0700 + i] == in_data[i], $sformatf("in byte %0d mem=%02x", i, mem[16'h0700 + i]));
    apb_rd(16'h0704, rd); chk(rd[0] == 1'b1, $sformatf("hc_int[1].done, got %08x", rd));
    // LPM request: EXT and LPM tokens, ACK, port goes to L1 suspend
    apb_wr(16'h0028, 32'h0000_0018 | (1 << 8) | (2 << 9) | (1 << 13) | (3 << 14));
    repeat (3000) @(posedge clk_phy);
    chk(lpm_n == 1, $sformatf("device saw the LPM transaction, lpm_n=%0d", lpm_n));
    apb_rd(16'h002C, rd); chk(rd[4] == 1'b1, $sformatf("port suspended in L1 after the ACK, hsts=%08x", rd));
    apb_rd(16'h0010, rd); chk(rd[17] == 1'b1, $sformatf("lpm_evt interrupt flag, irq_raw=%08x", rd));
    apb_rd(16'h0028, rd); chk(rd[8] == 1'b0, $sformatf("lpm_req cleared by hardware, hport=%08x", rd));
    // resume and then suspend by CSR
    apb_wr(16'h0028, 32'h0000_0018 | (1 << 2));
    repeat (8000) @(posedge clk_phy);
    apb_rd(16'h002C, rd); chk(rd[4] == 1'b0 && rd[1] == 1'b1, $sformatf("port resumed and enabled, hsts=%08x", rd));
    apb_wr(16'h0028, 32'h0000_0018 | (1 << 1));
    repeat (400) @(posedge clk_phy);
    apb_rd(16'h002C, rd); chk(rd[4] == 1'b1, $sformatf("port_susp_sts after port_susp, hsts=%08x", rd));
    apb_rd(16'h0010, rd); chk(rd[2] == 1'b1 && rd[3] == 1'b1, $sformatf("suspend and resume interrupt flags, irq_raw=%08x", rd));
    // ULPI low power: the link wrote SuspendM = 0, the PHY stops its clock, software resumes the port,
    // the always-on logic holds stp until the PHY has raised and dropped dir
    chk(ph_reg[8'h04][6] == 1'b0, $sformatf("SuspendM written to 0 for the suspended port, fc=%02x", ph_reg[8'h04]));
    repeat (10) @(posedge clk_phy);
    clk_run = 0;
    #200;
    apb_wr(16'h0028, 32'h0000_0018 | (1 << 2));
    guard = 0; while (!ulpi_stp && guard < 400) begin @(posedge clk_bus); guard++; end
    chk(ulpi_stp == 1'b1, "stp asserted while the PHY clock is stopped");
    clk_run = 1; rx_cmd(8'h0D);                  // the PHY restarts its clock and reports the line state with an RX CMD
    repeat (40) @(posedge clk_bus);
    chk(ulpi_stp == 1'b0, "stp released after dir fell");
    repeat (9000) @(posedge clk_phy);
    apb_rd(16'h002C, rd); chk(rd[4] == 1'b0 && rd[1] == 1'b1, $sformatf("port resumed after the wake, hsts=%08x", rd));
    chk(ph_reg[8'h04][6] == 1'b1, $sformatf("SuspendM written back to 1, fc=%02x", ph_reg[8'h04]));
    $display("TB_HOST_ULPI checks=%0d errors=%0d regwrites=%0d", checks, errors, nreg);
    $finish;
  end
  initial begin #60000000; $display("TIMEOUT"); $finish; end
endmodule
