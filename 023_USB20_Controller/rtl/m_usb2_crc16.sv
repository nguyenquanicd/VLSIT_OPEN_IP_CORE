/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : USB CRC16 update for one or two bytes per cycle: polynomial X^16+X^15+X^2+1,
 *                seed all ones, bits LSb first (REQ-FUNC-003, REF-001 8.3.5.2). The caller keeps
 *                the remainder in its own register, so a pipeline stage can be added around this
 *                module (PARA_USB2_PIPE_RX of the link). o_residual_ok is high when the
 *                remainder equals the residual 1000000000001101B after data and CRC bytes were
 *                processed. o_tx_lo and o_tx_hi are the two CRC bytes in the order and bit order
 *                sent.
 */
`timescale 1ns/1ps

module m_usb2_crc16 #(
  // Parameter Description: number of bytes processed per cycle (8-bit or 16-bit UTMI+ interface).
  // Parameter values: 1 or 2; default is 1.
  // Parameter unit: byte
  parameter logic [31:0] PARA_USB2_CRC_BYTES = 1,
  // Fixed CRC16 parameters of REF-001 section 8.3.5.2
  localparam logic [31:0] LPARA_CRC16_POLY    = 32'h00008005,
  localparam logic [31:0] LPARA_CRC16_RESIDUE = 32'h0000800D,
  localparam logic [31:0] LPARA_TWO_BYTES     = 32'd2
) (
  // Remainder in and data
  input  wire  [15:0] i_crc,
  input  wire  [15:0] i_data,
  input  wire         i_high_en,

  // Remainder out and checks
  output logic [15:0] o_crc_nxt,
  output logic        o_residual_ok,
  output logic [7:0]  o_tx_lo,
  output logic [7:0]  o_tx_hi
);

  // CRC16 update over one byte, LSb first; the feedback is the high bit of the remainder.
  function automatic logic [15:0] f_step8 (input logic [15:0] i_rem, input logic [7:0] i_byte);
    logic [15:0] w_rem;
    w_rem = i_rem;
    for (int idx = 0; idx < 8; idx++) begin
      if (w_rem[15] ^ i_byte[idx])
        w_rem = {w_rem[14:0], 1'b0} ^ LPARA_CRC16_POLY[15:0];
      else
        w_rem = {w_rem[14:0], 1'b0};
    end
    return w_rem;
  endfunction

  // Reverses the bit order of a byte: the CRC is sent MSb first inside LSb-first bytes.
  function automatic logic [7:0] f_rev8 (input logic [7:0] i_byte);
    logic [7:0] w_rev;
    for (int idx = 0; idx < 8; idx++) begin
      w_rev[idx] = i_byte[7 - idx];
    end
    return w_rev;
  endfunction

  logic [15:0] w_after_lo;

  // Remainder after the low byte.
  assign w_after_lo = f_step8(i_crc, i_data[7:0]);

  // Remainder update: the high byte follows only in 16-bit mode when it is valid.
  always_comb begin : p_com_nxt
    o_crc_nxt = w_after_lo;
    if (PARA_USB2_CRC_BYTES == LPARA_TWO_BYTES)
      if (i_high_en)
        o_crc_nxt = f_step8(w_after_lo, i_data[15:8]);
  end

  // Residual check and transmit bytes, taken from the current remainder.
  assign o_residual_ok = (i_crc == LPARA_CRC16_RESIDUE[15:0]) ? 1'b1 : 1'b0;
  assign o_tx_lo       = f_rev8(~i_crc[15:8]);
  assign o_tx_hi       = f_rev8(~i_crc[7:0]);

endmodule
