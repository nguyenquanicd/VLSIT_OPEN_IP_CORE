`timescale 1ns/1ps
// Review testbench (not part of the project): checks the statements of the FTEL GPIO HDS v2.4 against the RTL.
module tb_gpio;
  logic pclk = 0, osc = 0, prst_n = 0, orst_n = 0;
  always #5 pclk = ~pclk;           // 100 MHz
  always #10 osc = ~osc;            // 50 MHz (asynchronous to pclk in the spec; here a simple 2:1)
  logic [15:0] paddr = 0; logic psel = 0, penable = 0, pwrite = 0; logic [31:0] pwdata = 0; logic [3:0] pstrb = 0;
  logic [31:0] prdata; logic pready, pslverr;
  logic [7:0] pad_in = 0; logic [7:0] pad_out, pad_oe; logic gint, gwake;
  int fails = 0;

  m_fpt_gpio_wrap dut (
    .i_gpio_osc_clk(osc), .i_gpio_osc_clk_rst_n(orst_n), .i_gpio_pclk(pclk), .i_gpio_pclk_rst_n(prst_n),
    .i_gpio_apb_paddr(paddr), .i_gpio_apb_penable(penable), .i_gpio_apb_pprot(3'b000), .i_gpio_apb_psel(psel),
    .i_gpio_apb_pstrb(pstrb), .i_gpio_apb_pwdata(pwdata), .i_gpio_apb_pwrite(pwrite), .o_gpio_apb_prdata(prdata),
    .o_gpio_apb_pready(pready), .o_gpio_apb_pslverr(pslverr), .i_gpio_pad_in(pad_in), .o_gpio_pad_oe(pad_oe),
    .o_gpio_pad_out(pad_out), .o_gpio_int(gint), .o_gpio_wake_int(gwake));

  task automatic chk(input string n, input logic [31:0] got, input logic [31:0] exp);
    if (got !== exp) begin $display("FAIL %s: got %h expected %h", n, got, exp); fails++; end
    else $display("ok   %s = %h", n, got);
  endtask

  int wait_cycles;
  task automatic apb(input logic wr, input logic [15:0] a, input logic [31:0] d, input logic [3:0] s, output logic [31:0] rd);
    @(posedge pclk); #1; psel = 1; penable = 0; pwrite = wr; paddr = a; pwdata = d; pstrb = s;
    @(posedge pclk); #1; penable = 1; wait_cycles = 0;
    while (1) begin
      @(posedge pclk);
      if (pready) break;
      wait_cycles++;
      #1;
    end
    rd = prdata; #1; psel = 0; penable = 0; pwrite = 0;
  endtask
  task automatic wr(input logic [15:0] a, input logic [31:0] d); logic [31:0] r; apb(1, a, d, 4'hF, r); endtask
  task automatic rd(input logic [15:0] a, output logic [31:0] r); apb(0, a, 0, 4'h0, r); endtask

  logic [31:0] r;
  int lat;
  initial begin
    // ---- T2 first: the pad is already high when the reset is released
    pad_in = 8'h01;
    repeat (4) @(posedge pclk);
    prst_n = 1; orst_n = 1;
    repeat (20) @(posedge pclk);
    rd(16'h020, r); chk("T2 RAW_INT after reset with pad high (rising mode default)", r, 32'h1);
    rd(16'h024, r); chk("T2 INT_STA (INT_EN=0)", r, 32'h0);
    chk("T2 o_gpio_int (INT_EN=0)", {31'b0, gint}, 0);
    wr(16'h020, 32'h1); rd(16'h020, r); chk("T2 RAW_INT after W1C", r, 32'h0);
    pad_in = 8'h00; repeat (20) @(posedge pclk);

    // ---- T1: version, APB wait states, OE/OUT
    rd(16'h000, r); chk("T1 VERSION", r, 32'h0001_0000);
    $display("T1 wait cycles with PREADY=0 in the access phase: %0d", wait_cycles);
    wr(16'h014, 32'hA5); wr(16'h010, 32'hFF);
    chk("T1 pad_out", {24'b0, pad_out}, 32'hA5); chk("T1 pad_oe", {24'b0, pad_oe}, 32'hFF);
    rd(16'h014, r); chk("T1 OUT read", r, 32'hA5);
    rd(16'h012, r); chk("T1 unaligned read", r, 0);
    rd(16'h03C, r); chk("T1 unmapped 0x03C read", r, 0);
    apb(1, 16'h014, 32'h0000_5A00, 4'b0010, r); rd(16'h014, r); chk("T1 partial strobe lane 1 write must not change [7:0]", r, 32'hA5);
    apb(1, 16'h014, 32'h0000_005A, 4'b0001, r); rd(16'h014, r); chk("T1 partial strobe lane 0", r, 32'h5A);

    // ---- T3: filter, count rising edges on pin 1 with pulses of N osc cycles
    wr(16'h034, 32'h2);                           // CNT_EN pin1
    repeat (10) @(posedge pclk);
    for (int n = 1; n <= 4; n++) begin
      wr(16'h104, 32'hFFFF_FFFF); repeat (6) @(posedge pclk);
      pad_in[1] = 1; repeat (n * 2) @(posedge pclk);   // n osc periods (osc = 2 pclk)
      pad_in[1] = 0; repeat (40) @(posedge pclk);
      rd(16'h104, r); $display("T3 pulse of %0d osc cycles (%0d ns) -> count %0d", n, n * 20, r);
    end
    // pulse that is one pclk long, not related to osc
    wr(16'h104, 32'hFFFF_FFFF); repeat (6) @(posedge pclk);
    pad_in[1] = 1; @(posedge pclk); pad_in[1] = 0; repeat (40) @(posedge pclk);
    rd(16'h104, r); $display("T3 pulse of 1 pclk (10 ns) -> count %0d", r);

    // ---- T7: latency pad -> o_gpio_int (pin 2, rising, INT_EN)
    wr(16'h028, 32'h4); repeat (5) @(posedge pclk);
    @(negedge pclk); pad_in[2] = 1; lat = 0;
    while (!gint && lat < 100) begin @(posedge pclk); lat++; end
    $display("T7 pad rising -> o_gpio_int after %0d pclk cycles (spec: about 4 osc + 3 pclk + 1)", lat);
    // level mode high on pin 2, clear while the pad is still high
    wr(16'h030, 32'h0020);                         // mode 10 on pin 2
    repeat (10) @(posedge pclk);
    wr(16'h020, 32'h4); rd(16'h020, r); chk("T4 RAW_INT stays set while level is active", r & 32'h4, 32'h4);
    pad_in[2] = 0; repeat (20) @(posedge pclk);
    wr(16'h020, 32'h4); rd(16'h020, r); chk("T4 RAW_INT clears after the level is removed", r & 32'h4, 32'h0);

    // ---- T8: injection
    wr(16'h02C, 32'h8); repeat (4) @(posedge pclk);
    rd(16'h020, r); chk("T8 RAW_INT[3] set by INT_INJ", r & 32'h8, 32'h8);
    wr(16'h020, 32'h8); rd(16'h020, r); chk("T8 clear RAW while INJ=1 is lost", r & 32'h8, 32'h8);
    wr(16'h02C, 32'h0); wr(16'h020, 32'h8); rd(16'h020, r); chk("T8 clear after INJ=0", r & 32'h8, 32'h0);

    // ---- T9: SYNC_EN latency of GPIO_IN (pin 5)
    wr(16'h01C, 32'h0); @(negedge pclk); pad_in[5] = 1; lat = 0;
    while (!dut.w_gpio_in[5] && lat < 20) begin @(posedge pclk); lat++; end
    $display("T9 SYNC_EN=0: GPIO_IN[5] follows the pad after %0d pclk", lat);
    pad_in[5] = 0; repeat (6) @(posedge pclk);
    wr(16'h01C, 32'h20); repeat (3) @(posedge pclk); @(negedge pclk); pad_in[5] = 1; lat = 0;
    while (!dut.w_gpio_in[5] && lat < 20) begin @(posedge pclk); lat++; end
    $display("T9 SYNC_EN=1: GPIO_IN[5] follows the pad after %0d pclk", lat);


    // ---- T10: reset of the OSC domain only (pad steady high, pin 6 counts rising and pin 7 counts falling)
    pad_in[6] = 1; pad_in[7] = 1; wr(16'h038, 32'h80); wr(16'h034, 32'hC0); repeat (30) @(posedge pclk);
    wr(16'h118, 32'hFFFF_FFFF); wr(16'h11C, 32'hFFFF_FFFF); repeat (6) @(posedge pclk);
    rd(16'h118, r); $display("T10 before: count pin6(rising) %0d", r); rd(16'h11C, r); $display("T10 before: count pin7(falling) %0d", r);
    orst_n = 0; repeat (3) @(posedge pclk); orst_n = 1; repeat (40) @(posedge pclk);
    rd(16'h118, r); $display("T10 after an OSC-only reset with a steady pad: rising count pin6 = %0d", r);
    rd(16'h11C, r); $display("T10 after an OSC-only reset with a steady pad: falling count pin7 = %0d", r);
    pad_in[6] = 0; pad_in[7] = 0; wr(16'h034, 32'h0); repeat (10) @(posedge pclk);

    // ---- T11: software clear while events are flowing (pin 1 toggles, counting rising edges)
    wr(16'h034, 32'h2);
    fork
      begin : gen
        forever begin pad_in[1] = 1; repeat (7) @(posedge pclk); pad_in[1] = 0; repeat (7) @(posedge pclk); end
      end
      begin : clr
        int lost; lost = 0;
        repeat (400) begin
          logic [31:0] before_v, after_v;
          rd(16'h104, before_v);
          wr(16'h104, 32'hFFFF_FFFF);
          rd(16'h104, after_v);
          if (after_v > 32'd3 && after_v >= before_v) lost++;
        end
        $display("T11 clears that did not clear (value after >= value before, and > 3): %0d of 400", lost);
        disable gen;
      end
    join

    $display("TB done, %0d failures", fails);
    $finish;
  end
endmodule
