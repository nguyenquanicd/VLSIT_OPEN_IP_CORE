`timescale 1ns/1ps
module tb_err;
  parameter PC = 0; parameter PP = 0; parameter PI = 0;
  parameter DW = 64; parameter SA = 0; parameter SP = 0; parameter PROT = 0; parameter CH = 5; parameter AH = 6; parameter PH = 8;
  localparam W = DW / 8;
  logic clk_core = 0, clk_axi = 0, clk_apb = 0, rst_n_core = 0, rst_n_axi = 0, rst_n_apb = 0;
  always #CH clk_core = ~clk_core; always #AH clk_axi = ~clk_axi; always #PH clk_apb = ~clk_apb;
  logic [15:0] paddr; logic [31:0] pwdata; logic pwrite, penable, psel;
  wire pready, pslverr; wire [31:0] prdata;
  logic [3:0] awid; logic [11:0] awaddr; logic [7:0] awlen; logic [2:0] awsize; logic [1:0] awburst; logic [2:0] awprot; logic awvalid; wire awready;
  logic [DW-1:0] wdata; logic [W-1:0] wstrb; logic wlast, wvalid; wire wready;
  wire [3:0] bid; wire [1:0] bresp; wire bvalid; logic bready;
  logic [3:0] arid; logic [11:0] araddr; logic [7:0] arlen; logic [2:0] arsize; logic [1:0] arburst; logic [2:0] arprot; logic arvalid; wire arready;
  wire [3:0] rid; wire [DW-1:0] rdata; wire [1:0] rresp; wire rlast, rvalid; logic rready;
  wire key_req; wire [3:0] key_slot; logic [255:0] key_data; logic key_vld = 0; logic key_err = 0; logic key_deny = 0; wire int_cha;
  m_chacha_top #(.PARA_PIPE_CHACHA(PC), .PARA_PIPE_POLY(PP), .PARA_PIPE_IO(PI), .PARA_AXI_DW(DW), .PARA_FIFO_OUT_DEPTH(256), .PARA_SYNC_AXI_CORE(SA), .PARA_SYNC_APB_CORE(SP)) dut (
    .i_clk_apb(clk_apb), .i_rst_n_apb(rst_n_apb), .i_clk_axi(clk_axi), .i_rst_n_axi(rst_n_axi), .i_clk_core(clk_core), .i_rst_n_core(rst_n_core),
    .i_dft_test_en(1'b0), .i_dft_rst_n(1'b1),
    .i_apb_paddr(paddr), .i_apb_pwdata(pwdata), .i_apb_pwrite(pwrite), .i_apb_penable(penable), .i_apb_psel(psel), .i_apb_pstrb(4'hf), .i_apb_pprot(3'd0),
    .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata), .i_protect_en(PROT[0]), .i_slverr_en(1'b1),
    .i_axi_awid(awid), .i_axi_awaddr(awaddr), .i_axi_awlen(awlen), .i_axi_awsize(awsize), .i_axi_awburst(awburst), .i_axi_awprot(awprot),
    .i_axi_awvalid(awvalid), .o_axi_awready(awready), .i_axi_wdata(wdata), .i_axi_wstrb(wstrb), .i_axi_wlast(wlast), .i_axi_wvalid(wvalid),
    .o_axi_wready(wready), .o_axi_bid(bid), .o_axi_bresp(bresp), .o_axi_bvalid(bvalid), .i_axi_bready(bready),
    .i_axi_arid(arid), .i_axi_araddr(araddr), .i_axi_arlen(arlen), .i_axi_arsize(arsize), .i_axi_arburst(arburst), .i_axi_arprot(arprot),
    .i_axi_arvalid(arvalid), .o_axi_arready(arready), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp), .o_axi_rlast(rlast),
    .o_axi_rvalid(rvalid), .i_axi_rready(rready), .o_dma_req_wr(), .i_dma_ack_wr(1'b0), .o_dma_req_rd(), .i_dma_ack_rd(1'b0),
    .o_key_req(key_req), .o_key_slot(key_slot), .i_key_data(key_data), .i_key_vld(key_vld), .i_key_err(key_err), .o_int_cha(int_cha));
  always @(posedge clk_core) begin
    key_vld <= key_req & ~key_deny;
    key_err <= key_req & key_deny;
    if (!key_req) begin key_vld <= 0; key_err <= 0; end
  end
  task apb_write(input [15:0] a, input [31:0] d);
    begin @(posedge clk_apb); #1 paddr = a; pwdata = d; pwrite = 1; psel = 1; penable = 0; @(posedge clk_apb); #1 penable = 1;
      @(posedge clk_apb); while (!pready) @(posedge clk_apb); #1 psel = 0; penable = 0; pwrite = 0; end
  endtask
  task apb_read(input [15:0] a, output [31:0] d);
    begin @(posedge clk_apb); #1 paddr = a; pwrite = 0; psel = 1; penable = 0; @(posedge clk_apb); #1 penable = 1;
      @(posedge clk_apb); while (!pready) @(posedge clk_apb); d = prdata; #1 psel = 0; penable = 0; end
  endtask
  logic [DW-1:0] ibeats [0:2047]; logic [DW-1:0] expb [0:2047]; logic [DW-1:0] obeats [0:2047];
  integer errs = 0; integer tests = 0;
  // generic write burst: n beats, size code, burst type, address, prot, strobe override (-1 = auto), wait for response
  logic [1:0] last_bresp; integer last_rerr;
  task axi_wr(input integer first, input integer n, input integer size, input integer burst, input integer addr, input integer prot, input integer badbeat, input integer auto_nA, input integer auto_nM, input integer lastA, input integer lastM);
    integer j;
    begin
      @(posedge clk_axi); #1 awid = 1; awaddr = addr; awlen = n - 1; awsize = size; awburst = burst; awprot = prot; awvalid = 1;
      @(posedge clk_axi); while (!awready) @(posedge clk_axi);
      #1 awvalid = 0;
      for (j = 0; j < n; j++) begin
        #1 wdata = ibeats[first + j]; wlast = (j == n - 1); wvalid = 1; wstrb = {W{1'b1}};
        if (first + j == auto_nA - 1 && lastA < W) wstrb = (1 << lastA) - 1;
        if (first + j == auto_nA + auto_nM - 1 && lastM < W) wstrb = (1 << lastM) - 1;
        if (j == badbeat) wstrb = 8'h55;
        @(posedge clk_axi); while (!wready) @(posedge clk_axi);
      end
      #1 wvalid = 0; wlast = 0; bready = 1;
      @(posedge clk_axi); while (!bvalid) @(posedge clk_axi);
      last_bresp = bresp; #1 bready = 0;
    end
  endtask
  task axi_rd(input integer n, input integer size, input integer burst, input integer prot);
    integer j;
    begin
      @(posedge clk_axi); #1 arid = 2; araddr = 0; arlen = n - 1; arsize = size; arburst = burst; arprot = prot; arvalid = 1;
      @(posedge clk_axi); while (!arready) @(posedge clk_axi);
      #1 arvalid = 0; rready = 1; j = 0; last_rerr = 0;
      while (j < n) begin @(posedge clk_axi); #0; if (rvalid && rready) begin obeats[j] = rdata; if (rresp !== 2'b00) last_rerr++; j++; end end
      #1 rready = 0;
    end
  endtask
  task check(input integer cond, input [255:0] name);
    begin tests++; if (!cond) begin errs++; $display("FAIL: %0s", name); end else $display("pass: %0s", name); end
  endtask
  logic [31:0] rd; logic [95:0] noncev; logic [255:0] kk [0:0]; integer i, nA, nM, lastA, lastM;
  task start_msg(input integer dir, input integer slot, input integer n0);
    begin
      apb_write(16'h10, noncev[31:0] + n0); apb_write(16'h14, noncev[63:32]); apb_write(16'h18, noncev[95:64]);
      apb_write(16'h04, 32'h1 | (dir << 2) | (slot << 6));
      apb_write(16'h04, 32'h3 | (dir << 2) | (slot << 6));
      apb_read(16'h28, rd); apb_read(16'h28, rd);
    end
  endtask
  task wait_irq(output [31:0] v);
    integer c; begin c = 0; v = 0; while (v[5:0] == 0 && c < 1500) begin apb_read(16'h2c, v); c++; end end
  endtask
  task wait_done(output [31:0] v);
    integer c; begin c = 0; v = 0; while (v[1:0] == 0 && c < 1500) begin apb_read(16'h2c, v); c++; end end
  endtask
  task clear_irq; begin apb_write(16'h2c, 32'h3f); repeat (8) @(posedge clk_apb); end endtask
  task good_message(input integer slot, input integer n0, input [255:0] name);
    begin
      start_msg(0, slot, n0);
      axi_wr(0, nA, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM);
      check(last_bresp == 0, "good aad burst");
      axi_wr(nA, nM, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM);
      check(last_bresp == 0, "good msg burst");
      wait_done(rd);
      check(rd[5:0] == 6'b000001, name);
      repeat (20) @(posedge clk_axi);
      axi_rd(nM + 2, $clog2(W), 1, 0);
      check(last_rerr == 0, "read results");
      for (i = 0; i < nM + 2; i++) if (obeats[i] !== expb[i]) begin errs++; $display("beat %0d mismatch", i); end
      clear_irq;
    end
  endtask
  always @(posedge clk_core) begin
    if (dut.w_ev != 0 || dut.w_axi_rstd_evt || dut.u_core.u_ctrl.w_enter_abort) $display("t=%0t ev=%b rstd=%b enter_abort=%b state=%0d", $time, dut.w_ev, dut.w_axi_rstd_evt, dut.u_core.u_ctrl.w_enter_abort, dut.u_core.u_ctrl.reg_fsm_msg_current_state);
  end
  initial begin
    paddr = 0; pwdata = 0; pwrite = 0; penable = 0; psel = 0; awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0; wlast = 0; wstrb = 0; wdata = 0; awprot = 0; arprot = 0;
    $readmemh("enc64_in.hex", ibeats); $readmemh("enc64_out.hex", expb);
    $readmemh("key.hex", kk); key_data = kk[0]; begin : rdn logic [95:0] nn [0:0]; $readmemh("nonce.hex", nn); noncev = nn[0]; end
    nA = 2; nM = 15; lastA = 4; lastM = 2;
    #50; rst_n_core = 1; rst_n_axi = 1; rst_n_apb = 1; repeat (20) @(posedge clk_apb);
    apb_write(16'h08, {16'd114, 16'd12}); apb_write(16'h0c, 32'h0001_0001); apb_write(16'h30, 32'h3f);
    // T1: normal message
    good_message(3, 0, "T1 done");
    // T2: nonce guard: same nonce, same slot -> ctr_err; other slot -> accepted
    start_msg(0, 3, 0); wait_irq(rd); check(rd[4] == 1 && rd[0] == 0, "T2 ctr_err on repeated nonce"); clear_irq;
    apb_read(16'h28, rd); check(rd[0] == 0, "T2 not busy after refused start");
    // T3: len_err
    apb_write(16'h08, {16'd1281, 16'd12}); start_msg(0, 11, 0); wait_irq(rd); check(rd[2] == 1, "T3 len_err"); clear_irq;
    apb_write(16'h08, {16'd114, 16'd12});
    // T4: key error then recovery
    key_deny = 1; start_msg(0, 4, 0); wait_irq(rd); check(rd[5] == 1 && rd[0] == 0, "T4 key_err"); clear_irq;
    repeat (80) @(posedge clk_apb); apb_read(16'h28, rd); check(rd[0] == 0, "T4 busy cleared after flush");
    key_deny = 0;
    good_message(5, 0, "T4b message after key error");
    // T5: abort after partial data, then recovery
    start_msg(0, 6, 0);
    axi_wr(0, nA, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM);
    apb_write(16'h04, 32'h1 | (1 << 3) | (6 << 6));
    repeat (120) @(posedge clk_apb); apb_read(16'h28, rd); check(rd[0] == 0, "T5 busy cleared after abort");
    apb_read(16'h04, rd); check(rd[3] == 0, "T5 abort bit cleared");
    apb_read(16'h2c, rd); check(rd[0] == 0 && rd[1] == 0, "T5 no done/tag_err after abort"); clear_irq;
    good_message(7, 0, "T5b message after abort");
    // T6: AXI protocol checks on an idle engine (writes are refused without an active message)
    axi_wr(0, 2, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM); check(last_bresp == 2, "T6 write with no message -> SLVERR");
    repeat (12) @(posedge clk_apb); apb_read(16'h2c, rd); check(rd[3] == 1, "T6 axi_err set"); clear_irq;
    axi_rd(2, $clog2(W), 1, 0); check(last_rerr == 2, "T6 read of empty buffer -> SLVERR both transfers");
    clear_irq;
    // T7: bad transfer attributes during an active message
    start_msg(0, 8, 0);
    axi_wr(0, 2, $clog2(W) - 1, 1, 0, 0, -1, nA, nM, lastA, lastM); check(last_bresp == 2, "T7 narrow transfer -> SLVERR");
    axi_wr(0, 2, $clog2(W), 0, 0, 0, -1, nA, nM, lastA, lastM); check(last_bresp == 2, "T7 FIXED burst -> SLVERR");
    axi_wr(0, 2, $clog2(W), 1, 12'hff8, 0, -1, nA, nM, lastA, lastM); check(last_bresp == 2, "T7 4KB crossing -> SLVERR");
    axi_wr(0, nA, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM); check(last_bresp == 0, "T7 good aad after refusals");
    axi_wr(nA, nM, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM); check(last_bresp == 0, "T7 good msg");
    wait_done(rd); check(rd[0] == 1 && rd[3] == 1, "T7 done with axi_err pulses"); clear_irq;
    axi_rd(nM + 2, $clog2(W), 1, 0);
    for (i = 0; i < nM + 2; i++) if (obeats[i] !== expb[i]) begin errs++; $display("T7 beat %0d mismatch", i); end
    clear_irq;
    // T7b: wrong strobes in the second beat of a burst: SLVERR, the stream is corrupted, software aborts
    start_msg(0, 12, 0);
    axi_wr(0, 2, $clog2(W), 1, 0, 0, 1, nA, nM, lastA, lastM); check(last_bresp == 2, "T7b wrong strobes -> SLVERR");
    apb_write(16'h04, 32'h1 | (1 << 3) | (12 << 6)); repeat (120) @(posedge clk_apb);
    apb_read(16'h28, rd); check(rd[0] == 0, "T7b busy cleared after abort"); clear_irq;
    // T8: disabled engine: start is cleared without effect
    apb_write(16'h04, 32'h0); apb_write(16'h04, 32'h2); repeat (20) @(posedge clk_apb); apb_read(16'h04, rd); check(rd[1] == 0, "T8 start cleared when disabled");
    apb_read(16'h28, rd); check(rd[0] == 0, "T8 not busy"); apb_read(16'h2c, rd); check(rd[5:0] == 0, "T8 no event");
    // T9: AXI reset while busy
    apb_write(16'h04, 32'h1); start_msg(0, 9, 0);
    axi_wr(0, nA, $clog2(W), 1, 0, 0, -1, nA, nM, lastA, lastM);
    #1 rst_n_axi = 0; #40 rst_n_axi = 1;
    repeat (150) @(posedge clk_apb); apb_read(16'h28, rd); check(rd[0] == 0, "T9 busy cleared after AXI reset");
    apb_read(16'h2c, rd); check(rd[3] == 1 && rd[0] == 0, "T9 axi_err after AXI reset"); clear_irq;
    $display("after T9: in_empty=%b in_full=%b out_empty=%b out_full=%b", dut.w_in_empty, dut.w_in_full, dut.w_out_empty, dut.w_out_full);
    good_message(10, 0, "T9b message after AXI reset");
    $display("RESULT tb_err DW=%0d SA=%0d SP=%0d PROT=%0d checks=%0d errors=%0d", DW, SA, SP, PROT, tests, errs);
    $finish;
  end
  initial begin #6000000; $display("GLOBAL TIMEOUT errors=%0d", errs);
    $display("state=%0d in_empty=%b in_full=%b w_open=%b w_bad=%b wp_vld=%b wp_rem=%0d wp_kind=%0d act=%b wvalid=%b wready=%b fl_in_pend=%b fl_out_pend=%b",
      dut.u_core.u_ctrl.reg_fsm_msg_current_state, dut.w_in_empty, dut.w_in_full, dut.u_axi_win.reg_w_open, dut.u_axi_win.reg_w_bad, dut.u_axi_win.reg_wp_vld,
      dut.u_axi_win.reg_wp_rem, dut.u_axi_win.reg_wp_kind, dut.w_cap_act, wvalid, wready, dut.u_core.u_ctrl.reg_fl_in_pend, dut.u_core.u_ctrl.reg_fl_out_pend);
    $finish; end
endmodule
