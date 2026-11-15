/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-13
 * Description  : Structural top of the asynchronous two-phase (toggle) handshake IP. It connects
 *                the source block and the destination block and the two clock and reset domains,
 *                and contains no logic of its own. The request toggle and the bundled payload
 *                cross from the source to the destination; the acknowledge toggle and the bundled
 *                return payload cross back. The return payload mode and the ready path are
 *                selected by PARA_AHS2_ACK_DATA_MODE and PARA_AHS2_DST_MODE.
 * Decisions    : DEC-001, DEC-002, DEC-003, DEC-006, DEC-007, DEC-010.
 */
`timescale 1ns/1ps

module m_vlsit_ahs2_top #(
  // Parameter Description: width of the request payload and of i_data and o_data; widths above
  // 256 bits are harder for physical design, and a real design can split the channel into
  // several two-phase handshake clusters with payloads below 256 bits.
  // Parameter values: 1 to 1024; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AHS2_DATA_W = 32,
  // Parameter Description: width of the return payload and of i_ack_data and o_ack_data;
  // widths above 256 bits are harder for physical design, and a real design can split the
  // return channel into several two-phase handshake clusters with payloads below 256 bits.
  // Parameter values: 1 to 1024; default is PARA_AHS2_DATA_W.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AHS2_ACK_DATA_W = PARA_AHS2_DATA_W,
  // Parameter Description: synchronizer depth for the request and acknowledge crossings.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS2_SYNC_TYPE = 2,
  // Parameter Description: destination ready path; selects a direct or a registered accept.
  // Parameter values: 0 = direct, 1 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS2_DST_MODE = 0,
  // Parameter Description: acknowledge-direction payload mode.
  // Parameter values: 0 = disabled, 1 = transparent, 2 = registered; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS2_ACK_DATA_MODE = 0
) (
  // Source clock and reset
  input  wire                             i_clk_src,
  input  wire                             i_rst_n_src,

  // Source request interface
  input  wire                             i_req,
  input  wire  [PARA_AHS2_DATA_W-1:0]     i_data,

  // Source return payload
  output logic [PARA_AHS2_ACK_DATA_W-1:0] o_ack_data,

  // Destination clock and reset
  input  wire                             i_clk_dst,
  input  wire                             i_rst_n_dst,

  // Destination data interface
  output logic [PARA_AHS2_DATA_W-1:0]     o_data,

  // Destination accept level and return payload
  input  wire                             i_ack,
  input  wire  [PARA_AHS2_ACK_DATA_W-1:0] i_ack_data
);

  // Internal signal declarations
  logic                        w_req;
  logic [PARA_AHS2_DATA_W-1:0] w_data;
  logic                        w_ack;
  logic [PARA_AHS2_ACK_DATA_W-1:0] w_ack_data;

  // Source block: request toggle, payload register, acknowledge synchronizer, and the return
  // payload forwarding.
  m_vlsit_ahs2_src #(
    .PARA_AHS2_DATA_W     (PARA_AHS2_DATA_W),
    .PARA_AHS2_ACK_DATA_W (PARA_AHS2_ACK_DATA_W),
    .PARA_AHS2_SYNC_TYPE  (PARA_AHS2_SYNC_TYPE)
  ) u_src (
    .i_clk_src   (i_clk_src),
    .i_rst_n_src (i_rst_n_src),
    .i_req       (i_req),
    .i_data      (i_data),
    .i_ack       (w_ack),
    .i_ack_data  (w_ack_data),
    .o_req       (w_req),
    .o_data      (w_data),
    .o_ack_data  (o_ack_data)
  );

  // Destination block: request synchronizer, accept detection, payload capture, acknowledge
  // toggle, and the selected ready and return-payload paths.
  m_vlsit_ahs2_dst #(
    .PARA_AHS2_DATA_W        (PARA_AHS2_DATA_W),
    .PARA_AHS2_ACK_DATA_W    (PARA_AHS2_ACK_DATA_W),
    .PARA_AHS2_SYNC_TYPE     (PARA_AHS2_SYNC_TYPE),
    .PARA_AHS2_DST_MODE      (PARA_AHS2_DST_MODE),
    .PARA_AHS2_ACK_DATA_MODE (PARA_AHS2_ACK_DATA_MODE)
  ) u_dst (
    .i_clk_dst   (i_clk_dst),
    .i_rst_n_dst (i_rst_n_dst),
    .i_req       (w_req),
    .i_data      (w_data),
    .i_ack       (i_ack),
    .i_ack_data  (i_ack_data),
    .o_data      (o_data),
    .o_ack       (w_ack),
    .o_ack_data  (w_ack_data)
  );

endmodule
