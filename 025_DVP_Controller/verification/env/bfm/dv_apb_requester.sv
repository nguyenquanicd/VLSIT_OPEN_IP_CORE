// dv_apb_requester.sv - project-local APB4 requester BFM (no qualified APB master VIP was found, plan section 5.2).
// AI-generated candidate (R-117). Drives only the public APB4 request pins on the clock edge with non-blocking
// assignments (race-free, R-123). Holds address and controls stable through wait states and drives PSTRB low on reads.
`timescale 1ns/1ps
module dv_apb_requester (
  input  wire         i_clk,
  input  wire         i_rst_n,
  output logic [15:0] o_paddr,
  output logic        o_psel,
  output logic        o_penable,
  output logic        o_pwrite,
  output logic [31:0] o_pwdata,
  output logic [3:0]  o_pstrb,
  output logic [2:0]  o_pprot,
  input  wire         i_pready,
  input  wire  [31:0] i_prdata,
  input  wire         i_pslverr
);
  initial begin
    o_paddr = 16'h0; o_psel = 1'b0; o_penable = 1'b0; o_pwrite = 1'b0; o_pwdata = 32'h0; o_pstrb = 4'h0; o_pprot = 3'h0;
  end

  task automatic idle(input int n);
    repeat (n) @(posedge i_clk);
  endtask

  // One APB transfer. cycles counts access cycles (setup excluded). A transfer that is still pending when reset
  // asserts keeps its signals for hold_after_reset cycles and then returns aborted=1 (reset-in-transfer test).
  task automatic xfer(input logic [15:0] a, input bit wr, input logic [31:0] wd, input logic [3:0] strb,
                      output logic [31:0] rd, output bit err, output int cycles, output bit aborted,
                      input int hold_after_reset);
    int rst_hold = 0;
    aborted = 0; cycles = 0; err = 0; rd = 32'h0;
    @(posedge i_clk);
    o_paddr <= a; o_pwrite <= wr; o_pwdata <= wd; o_pstrb <= wr ? strb : 4'h0; o_pprot <= 3'h0; o_psel <= 1'b1; o_penable <= 1'b0;
    @(posedge i_clk);
    o_penable <= 1'b1;
    forever begin
      @(posedge i_clk);
      cycles = cycles + 1;
      if (!i_rst_n) begin
        rst_hold = rst_hold + 1;
        if (rst_hold > hold_after_reset) begin aborted = 1; break; end
      end else if (i_pready) begin
        rd = i_prdata; err = i_pslverr; break;
      end
    end
    o_psel <= 1'b0; o_penable <= 1'b0; o_pwrite <= 1'b0; o_pstrb <= 4'h0;
  endtask

  task automatic write(input logic [15:0] a, input logic [31:0] d, output bit err);
    logic [31:0] unused; int cyc; bit ab;
    xfer(a, 1'b1, d, 4'hF, unused, err, cyc, ab, 0);
  endtask

  task automatic write_strb(input logic [15:0] a, input logic [31:0] d, input logic [3:0] strb, output bit err);
    logic [31:0] unused; int cyc; bit ab;
    xfer(a, 1'b1, d, strb, unused, err, cyc, ab, 0);
  endtask

  task automatic read(input logic [15:0] a, output logic [31:0] d, output bit err, output int cycles);
    bit ab;
    xfer(a, 1'b0, 32'h0, 4'h0, d, err, cycles, ab, 0);
  endtask

  task automatic read_in_reset(input logic [15:0] a, input int hold_after_reset, output bit aborted);
    logic [31:0] d; bit err; int cyc;
    xfer(a, 1'b0, 32'h0, 4'h0, d, err, cyc, aborted, hold_after_reset);
  endtask
endmodule
