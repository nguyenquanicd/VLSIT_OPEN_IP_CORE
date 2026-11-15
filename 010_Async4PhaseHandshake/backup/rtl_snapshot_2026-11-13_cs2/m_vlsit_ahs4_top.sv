/*
 * Project      : VLSIT Asynchronous 4-phase handshake
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-12
 * Description  : Structural top of the asynchronous four-phase handshake IP. It connects the
 *                source block, the destination block, and the two clock and reset domains, and
 *                contains no logic of its own. The destination acknowledge always returns to the
 *                source through the destination block so that PARA_AHS4_DST_MODE can select the
 *                transparent or the capture acknowledge path. The optional return payload of
 *                the acknowledge direction is carried on i_ack_data and o_ack_data and is
 *                selected by PARA_AHS4_ACK_DATA_MODE.
 * Decisions    : DEC-001, DEC-002, DEC-004, DEC-005, DEC-006, DEC-008, DEC-010.
 */
`timescale 1ns/1ps

module m_vlsit_ahs4_top #(
  // Parameter Description: width of the bundled payload and of both data ports.
  // Parameter values: 1 to 256; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AHS4_DATA_W = 32,
  // Parameter Description: synchronizer depth for the request and acknowledge crossings.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_SYNC_TYPE = 2,
  // Parameter Description: destination data-presentation mode; selects option A or option B.
  // Parameter values: 0 = transparent (option A), 1 = captured (option B); default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_DST_MODE = 0,
  // Parameter Description: return-direction payload mode on the acknowledge channel.
  // Parameter values: 0 = disabled, 1 = transparent, 2 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_ACK_DATA_MODE = 0
) (
  // Source clock and reset
  input  wire                         i_clk_src,
  input  wire                         i_rst_n_src,

  // Source request interface
  input  wire                         i_req,
  input  wire  [PARA_AHS4_DATA_W-1:0] i_data,

  // Source completion interface
  output logic                        o_ack,
  output logic [PARA_AHS4_DATA_W-1:0] o_ack_data,

  // Destination clock and reset
  input  wire                         i_clk_dst,
  input  wire                         i_rst_n_dst,

  // Destination request interface
  output logic                        o_req,
  output logic [PARA_AHS4_DATA_W-1:0] o_data,

  // Destination acknowledge input
  input  wire                         i_ack,
  input  wire  [PARA_AHS4_DATA_W-1:0] i_ack_data
);

  // Internal signal declarations
  logic                        w_req;
  logic [PARA_AHS4_DATA_W-1:0] w_data;
  logic                        w_ack;
  logic [PARA_AHS4_DATA_W-1:0] w_ack_data;

  // Source block: request and payload flags and acknowledge synchronizer.
  m_vlsit_ahs4_src #(
    .PARA_AHS4_DATA_W    (PARA_AHS4_DATA_W),
    .PARA_AHS4_SYNC_TYPE (PARA_AHS4_SYNC_TYPE)
  ) u_src (
    .i_clk_src   (i_clk_src),
    .i_rst_n_src (i_rst_n_src),
    .i_req       (i_req),
    .i_data      (i_data),
    .i_ack       (w_ack),
    .i_ack_data  (w_ack_data),
    .o_ack       (o_ack),
    .o_ack_data  (o_ack_data),
    .o_req       (w_req),
    .o_data      (w_data)
  );

  // Destination block: request synchronizer and the selected data and acknowledge path.
  m_vlsit_ahs4_dst #(
    .PARA_AHS4_DATA_W        (PARA_AHS4_DATA_W),
    .PARA_AHS4_SYNC_TYPE     (PARA_AHS4_SYNC_TYPE),
    .PARA_AHS4_DST_MODE      (PARA_AHS4_DST_MODE),
    .PARA_AHS4_ACK_DATA_MODE (PARA_AHS4_ACK_DATA_MODE)
  ) u_dst (
    .i_clk_dst   (i_clk_dst),
    .i_rst_n_dst (i_rst_n_dst),
    .i_req       (w_req),
    .i_data      (w_data),
    .i_ack       (i_ack),
    .i_ack_data  (i_ack_data),
    .o_req       (o_req),
    .o_data      (o_data),
    .o_ack       (w_ack),
    .o_ack_data  (w_ack_data)
  );

endmodule
