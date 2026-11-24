`timescale 1ns/1ps
// Reproduction of the finding "same class as F-021" in m_usb2_regs.sv:1290-1306: the write decode compares the 4-bit bank index
// w_reg_wr_addr[5:2] with PARA_USB2_NEP1[3:0] and PARA_USB2_NHC[3:0]. PARA_USB2_NEP1 may be 16 (HDS: NUM_EP 1 to 15, so NEP1 up to
// 16) and PARA_USB2_NHC may be 16 (HDS: NUM_HC 1 to 16). Then the 4-bit slice is 0, the index is never "< 0", and the write of every
// register of those banks is declared not valid, so its command is not sent to CLK-PHY.
// Build and run: sh build_run.sh tb_repro_nep1 "..." (see run_repro.sh). Macro NEP1 and NHC set the parameters.
// Expected by the specification: every register of a bank with index < count is forwarded to CLK-PHY (w_dec_vld = 1).
// Observation point: the decode result at the cycle of the accepted write (hierarchical read of dut.w_reg_wr_en and dut.w_dec_vld).
`ifndef NEP1
`define NEP1 9
`endif
`ifndef NHC
`define NHC 8
`endif
module tb_repro_nep1;
  localparam int NEP1 = `NEP1;
  localparam int NHC  = `NHC;
  logic clk = 0, clk_phy = 0, rst_n = 0;
  always #5 clk = ~clk;
  always #8 clk_phy = ~clk_phy;

  logic        psel = 0, penable = 0, pwrite = 0;
  logic [15:0] paddr = 0;
  logic [31:0] pwdata = 0;
  wire         pready, pslverr;
  wire  [31:0] prdata;

  m_usb2_regs #(.PARA_USB2_NEP1(NEP1), .PARA_USB2_NHC(NHC)) dut (
    .i_clk_bus(clk), .i_rst_n_bus(rst_n), .i_clk_phy(clk_phy), .i_rst_n_phy(rst_n),
    .i_apb_psel(psel), .i_apb_penable(penable), .i_apb_pwrite(pwrite), .i_apb_paddr(paddr), .i_apb_pwdata(pwdata),
    .i_apb_pstrb(4'hF), .i_apb_pprot(3'd0), .o_apb_pready(pready), .o_apb_pslverr(pslverr), .o_apb_prdata(prdata));

  bit seen_en;
  bit seen_vld;
  always @(posedge clk) if (dut.w_reg_wr_en) begin seen_en <= 1'b1; seen_vld <= dut.w_dec_vld; end

  task automatic apb_write(input logic [15:0] addr, input logic [31:0] data);
    seen_en = 0; seen_vld = 0;
    @(negedge clk); psel = 1; pwrite = 1; paddr = addr; pwdata = data; penable = 0;
    @(negedge clk); penable = 1;
    do @(negedge clk); while (!pready);
    psel = 0; penable = 0; pwrite = 0;
    repeat (3) @(negedge clk);
  endtask

  int errors = 0;
  // bank base byte addresses of the decode (m_usb2_regs.sv p_com_dec: [15:6] = pattern, [5:2] = index)
  task automatic chk(input string name, input logic [15:0] base, input int idx, input int count);
    apb_write(base + 16'(idx * 4), 32'h0000_0001);
    $display("%-9s index %2d of count %2d : write seen=%0d  forwarded to CLK-PHY (w_dec_vld)=%0d  %s", name, idx, count, seen_en, seen_vld,
             (seen_en && seen_vld) ? "ok" : "NOT FORWARDED");
    if (!(seen_en && seen_vld)) errors++;
  endtask

  initial begin
    rst_n = 0; repeat (6) @(negedge clk); rst_n = 1; repeat (4) @(negedge clk);
    chk("EPI_IEN", 16'h0340, 0, NEP1);
    chk("EPI_IEN", 16'h0340, NEP1 - 1, NEP1);
    chk("HC_IEN",  16'h0740, 0, NHC);
    chk("HC_IEN",  16'h0740, NHC - 1, NHC);
    if (errors == 0) $display("RESULT NEP1=%0d NHC=%0d: PASS", NEP1, NHC);
    else             $display("RESULT NEP1=%0d NHC=%0d: FAIL (%0d writes not forwarded)", NEP1, NHC, errors);
    $finish;
  end
  initial begin #200000; $display("TIMEOUT"); $finish; end
endmodule
