/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-14
 * Description  : Structural top of the asynchronous Gray-code synchronizer IP. It connects the
 *                source block (binary-to-Gray encoding) and the destination block (Gray
 *                synchronizer and Gray-to-binary decoding) and the two clock and reset domains,
 *                and contains no logic of its own. The Gray bus crosses from the source to the
 *                destination; the optional registers are selected by PARA_AGRAY_SRC_REG and
 *                PARA_AGRAY_DST_REG.
 * Decisions    : DEC-001, DEC-002, DEC-004, DEC-005.
 */
`timescale 1ns/1ps

module m_vlsit_agray_sync_top #(
  // Parameter Description: width of the synchronized value and of i_data and o_data; wider values
  // increase the Gray decode XOR-tree depth (log2 of the width), which affects timing.
  // Parameter values: 2 to 512; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AGRAY_DATA_W = 32,
  // Parameter Description: synchronizer depth for the Gray crossing.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AGRAY_SYNC_TYPE = 2,
  // Parameter Description: source input register; adds one source cycle before the Gray encoder.
  // Parameter values: 0 = disabled, 1 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AGRAY_SRC_REG = 0,
  // Parameter Description: destination output register; adds one destination cycle after decode.
  // Parameter values: 0 = disabled, 1 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AGRAY_DST_REG = 0
) (
  // Source clock and reset
  input  wire                          i_clk_src,
  input  wire                          i_rst_n_src,

  // Source binary input
  input  wire  [PARA_AGRAY_DATA_W-1:0] i_data,

  // Destination clock and reset
  input  wire                          i_clk_dst,
  input  wire                          i_rst_n_dst,

  // Synchronized binary value
  output logic [PARA_AGRAY_DATA_W-1:0] o_data
);

  // Internal signal declarations
  logic [PARA_AGRAY_DATA_W-1:0] w_gray;

  // Source block: binary-to-Gray encoding and the Gray launch register.
  m_vlsit_agray_sync_src #(
    .PARA_AGRAY_DATA_W  (PARA_AGRAY_DATA_W),
    .PARA_AGRAY_SRC_REG (PARA_AGRAY_SRC_REG)
  ) u_src (
    .i_clk_src   (i_clk_src),
    .i_rst_n_src (i_rst_n_src),
    .i_data      (i_data),
    .o_gray      (w_gray)
  );

  // Destination block: Gray synchronizer, Gray-to-binary decode, optional output register.
  m_vlsit_agray_sync_dst #(
    .PARA_AGRAY_DATA_W    (PARA_AGRAY_DATA_W),
    .PARA_AGRAY_SYNC_TYPE (PARA_AGRAY_SYNC_TYPE),
    .PARA_AGRAY_DST_REG   (PARA_AGRAY_DST_REG)
  ) u_dst (
    .i_clk_dst   (i_clk_dst),
    .i_rst_n_dst (i_rst_n_dst),
    .i_gray      (w_gray),
    .o_data      (o_data)
  );

endmodule
