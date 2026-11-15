/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-14
 * Description  : Destination block of the asynchronous Gray-code synchronizer. It synchronizes the
 *                Gray bus with the reused vector synchronizer, decodes it back to binary, and
 *                optionally registers the result. The single-bit-change Gray property keeps the
 *                multi-bit crossing safe.
 * Decisions    : DEC-003, DEC-004, DEC-005, DEC-006.
 */
`timescale 1ns/1ps

module m_vlsit_agray_sync_dst #(
  // Parameter Description: width of the synchronized value and of i_data and o_data; wider values
  // increase the Gray decode XOR-tree depth (log2 of the width), which affects timing.
  // Parameter values: 2 to 512; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AGRAY_DATA_W = 32,
  // Parameter Description: synchronizer depth for the Gray crossing.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AGRAY_SYNC_TYPE = 2,
  // Parameter Description: destination output register; adds one destination cycle after decode.
  // Parameter values: 0 = disabled, 1 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AGRAY_DST_REG = 0
) (
  // Destination clock and reset
  input  wire                          i_clk_dst,
  input  wire                          i_rst_n_dst,

  // Gray code from the source block
  input  wire  [PARA_AGRAY_DATA_W-1:0] i_gray,

  // Synchronized binary value
  output logic [PARA_AGRAY_DATA_W-1:0] o_data
);

  // Internal signal declarations
  logic [PARA_AGRAY_DATA_W-1:0] w_gray_s;
  logic [PARA_AGRAY_DATA_W-1:0] w_bin;

  // Gray synchronizer CDC-001: one n-stage cell per Gray bit, reset to 0, selected by
  // PARA_AGRAY_SYNC_TYPE. The vector synchronizer is reused from the library.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (PARA_AGRAY_DATA_W),
    .PARA_AFIFO_SYNC_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_AGRAY_SYNC_TYPE)
  ) u_sync_gray (
    .i_clk_dst   (i_clk_dst),
    .i_rst_n_dst (i_rst_n_dst),
    .i_data      (i_gray),
    .o_data      (w_gray_s)
  );

  // Gray-to-binary decode: bit i is the parity of the Gray bits from i upward.
  always_comb begin : p_com_decode
    w_bin = '0;
    for (int idx = 0; idx < PARA_AGRAY_DATA_W; idx++)
      w_bin[idx] = ^(w_gray_s >> idx);
  end

  // Output path: mode 0 drives o_data with the decoded value directly; mode 1 registers it.
  generate
    if (PARA_AGRAY_DST_REG == 0) begin : gen_dst_direct
      // Direct output: the decoded value drives o_data.
      assign o_data = w_bin;
    end else begin : gen_dst_reg
      logic [PARA_AGRAY_DATA_W-1:0] reg_dst;

      // Registered output: the register drives o_data.
      assign o_data = reg_dst;

      // Output register: captures the decoded value one destination cycle late.
      always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ff_dst
        if (!i_rst_n_dst)
          reg_dst <= '0;
        else
          reg_dst <= w_bin;
      end
    end
  endgenerate

endmodule
