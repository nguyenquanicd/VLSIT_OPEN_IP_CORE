/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : USB CRC5 of a token: polynomial X^5+X^2+1, seed 11111B, bits taken LSb first
 *                (REQ-FUNC-003, REF-001 8.3.5.1). o_crc is the inverted remainder, in the order
 *                that is sent on the bus (bit 4 first). The receiver compares o_crc with the
 *                received field instead of checking the residual 01100B; both are equivalent.
 */
`timescale 1ns/1ps

module m_usb2_crc5 #(
  // Parameter Description: number of data bits covered by the CRC (11 for a token, 19 for a
  // split token).
  // Parameter values: 11 or 19; default is 11.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_CRC5_W = 11,
  // Fixed CRC5 parameters of REF-001 section 8.3.5.1
  localparam logic [31:0] LPARA_CRC5_POLY = 32'h00000005,
  localparam logic [31:0] LPARA_CRC5_SEED = 32'h0000001F
) (
  // Token fields: 7-bit address and 4-bit endpoint, or the 11-bit frame number, or a split token
  input  wire  [PARA_USB2_CRC5_W-1:0] i_data,
  output logic [4:0]                  o_crc
);

  // Bit-serial LFSR unrolled over the data bits. The CRC field is the inverted remainder sent
  // high-order bit first (REF-001 section 8.3.5), so o_crc[0], the first bit sent after the
  // data, is the inverted high-order bit of the remainder (BUG-001).
  always_comb begin : p_com_crc5
    logic [4:0] w_rem;
    w_rem = LPARA_CRC5_SEED[4:0];
    for (int idx = 0; idx < PARA_USB2_CRC5_W; idx++) begin
      if (w_rem[4] ^ i_data[idx])
        w_rem = {w_rem[3:0], 1'b0} ^ LPARA_CRC5_POLY[4:0];
      else
        w_rem = {w_rem[3:0], 1'b0};
    end
    o_crc = ~{w_rem[0], w_rem[1], w_rem[2], w_rem[3], w_rem[4]};
  end

endmodule
