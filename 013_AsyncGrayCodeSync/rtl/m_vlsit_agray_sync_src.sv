/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-14
 * Description  : Source block of the asynchronous Gray-code synchronizer. It encodes the binary
 *                input to reflected binary Gray code (G = B ^ (B >> 1)), optionally after an input
 *                register, and captures the result in the Gray launch register that drives the
 *                crossing. The Gray value changes by at most one bit between consecutive launches
 *                because the source increments the input by at most one.
 * Decisions    : DEC-003, DEC-004, DEC-006.
 */
`timescale 1ns/1ps

module m_vlsit_agray_sync_src #(
  // Parameter Description: width of the synchronized value and of i_data and o_data; wider values
  // increase the Gray decode XOR-tree depth (log2 of the width), which affects timing.
  // Parameter values: 2 to 512; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AGRAY_DATA_W = 32,
  // Parameter Description: source input register; adds one source cycle before the Gray encoder.
  // Parameter values: 0 = disabled, 1 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AGRAY_SRC_REG = 0
) (
  // Source clock and reset
  input  wire                          i_clk_src,
  input  wire                          i_rst_n_src,

  // Source binary input
  input  wire  [PARA_AGRAY_DATA_W-1:0] i_data,

  // Gray code to the destination block
  output logic [PARA_AGRAY_DATA_W-1:0] o_gray
);

  // Internal signal declarations
  logic [PARA_AGRAY_DATA_W-1:0] reg_gray;
  logic [PARA_AGRAY_DATA_W-1:0] w_gray_nxt;

  // Output mapping: the Gray launch register is the crossing source.
  assign o_gray = reg_gray;

  // Gray encoding: the next Gray value is the binary input, or the registered input, XORed with
  // itself shifted right by one. Mode 0 feeds the encoder directly; mode 1 registers first.
  generate
    if (PARA_AGRAY_SRC_REG == 0) begin : gen_src_direct
      // Direct encoding: the binary input feeds the encoder.
      assign w_gray_nxt = i_data ^ (i_data >> 1);
    end else begin : gen_src_reg
      logic [PARA_AGRAY_DATA_W-1:0] reg_src;

      // Registered encoding: the registered input feeds the encoder.
      assign w_gray_nxt = reg_src ^ (reg_src >> 1);

      // Input register: captures the binary input one source cycle early.
      always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin : p_ff_src
        if (!i_rst_n_src)
          reg_src <= '0;
        else
          reg_src <= i_data;
      end
    end
  endgenerate

  // Gray launch register: the crossing source, reset to 0. It captures the encoded Gray value every
  // source edge and holds it until the next edge.
  always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin : p_ff_gray
    if (!i_rst_n_src)
      reg_gray <= '0;
    else
      reg_gray <= w_gray_nxt;
  end

endmodule
