/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Routes APB addresses to the generated CSR block or the custom FIFO_DATA endpoint.
 *                Implements REQ-IF-006 and DEC-016.
 */
`timescale 1ns/1ps

module m_dvp_apb_decode #(
  // Parameter Description: byte address of the FIFO_DATA word.
  // Parameter values: aligned 16-bit address outside the CSR map; default is 16'h0100.
  // Parameter unit: byte
  parameter logic [31:0] PARA_FIFO_DATA_ADDR = 32'h0000_0100
) (
  // APB request address
  input  wire         i_psel,
  input  wire  [15:0] i_paddr,

  // Endpoint selection and alignment
  output logic        o_csr_sel,
  output logic        o_fifo_sel,
  output logic        o_fifo_aligned
);

  logic w_fifo_word;

  // Decode the endpoint's containing four-byte word and exact aligned byte address.
  assign w_fifo_word = (i_paddr[15:2] == PARA_FIFO_DATA_ADDR[15:2]);
  assign o_fifo_aligned = (i_paddr == PARA_FIFO_DATA_ADDR[15:0]);
  assign o_fifo_sel = i_psel & w_fifo_word;
  assign o_csr_sel = i_psel & ~w_fifo_word;

endmodule
