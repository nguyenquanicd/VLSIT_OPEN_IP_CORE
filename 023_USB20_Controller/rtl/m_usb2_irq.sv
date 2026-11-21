/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Interrupt block in CLK-BUS (section 6.4, REQ-IF-008, REQ-ERR-001). Each cause
 *                has an event pulse, the raw flag, the enable and the injection bit of the CSR.
 *                The event pulse or the rising edge of the injection bit sets the raw flag
 *                through the hardware load of the CSR (w1c, hardware wins over software clear).
 *                o_sts is raw AND enable and o_int_usb is its OR.
 */
`timescale 1ns/1ps

module m_usb2_irq #(
  // Parameter Description: number of interrupt causes of u2_irq_raw.
  // Parameter values: 25 (section 6.4); default is 25.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_IRQ_N = 25
) (
  // Clock and reset
  input  wire                        i_clk_bus,
  input  wire                        i_rst_n_bus,

  // Event pulses and CSR fields
  input  wire  [PARA_USB2_IRQ_N-1:0] i_evt,
  input  wire  [PARA_USB2_IRQ_N-1:0] i_raw,
  input  wire  [PARA_USB2_IRQ_N-1:0] i_en,
  input  wire  [PARA_USB2_IRQ_N-1:0] i_inj,

  // Hardware load of the raw flags, masked status and interrupt output
  output logic [PARA_USB2_IRQ_N-1:0] o_set,
  output logic [PARA_USB2_IRQ_N-1:0] o_sts,
  output logic                       o_int_usb
);

  // Internal signal declarations
  logic [PARA_USB2_IRQ_N-1:0] reg_inj_d;
  logic [PARA_USB2_IRQ_N-1:0] w_sts;
  logic                       reg_int;

  // Set request: an event pulse or the rising edge of the injection bit.
  assign o_set = i_evt | (i_inj & ~reg_inj_d);

  // Masked status and the level interrupt output.
  assign w_sts     = i_raw & i_en;
  assign o_sts     = w_sts;
  assign o_int_usb = reg_int;

  // Registered interrupt output (REQ-IF-008, BUG-002) and previous injection value for edge
  // detection; reset to zero so an injection bit that is high after reset raises no event.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_inj
    if (!i_rst_n_bus) begin
      reg_inj_d <= '0;
      reg_int   <= 1'b0;
    end else begin
      reg_inj_d <= i_inj;
      reg_int   <= (w_sts != '0);
    end
  end

endmodule
