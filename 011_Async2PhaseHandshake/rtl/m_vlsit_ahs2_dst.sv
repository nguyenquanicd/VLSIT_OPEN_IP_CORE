/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-13
 * Description  : Destination-side block of the asynchronous two-phase (toggle) handshake. It
 *                synchronizes the request toggle into the destination clock domain, detects the
 *                accept edge, captures the request payload, toggles the acknowledge flag, and
 *                selects the ready path and the return payload. The control state is the single
 *                toggle flop reg_ack; there is no finite-state machine. The request crossing
 *                uses the library one-bit synchronizer wrapper.
 * Decisions    : DEC-001, DEC-005, DEC-008, DEC-009, DEC-010, DEC-011.
 */
`timescale 1ns/1ps

module m_vlsit_ahs2_dst #(
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
  // Parameter Description: synchronizer depth for the request crossing.
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
  // Destination clock and reset
  input  wire                             i_clk_dst,
  input  wire                             i_rst_n_dst,

  // Request toggle and payload from the source block
  input  wire                             i_req,
  input  wire  [PARA_AHS2_DATA_W-1:0]     i_data,

  // Destination accept level and return payload from the destination user
  input  wire                             i_ack,
  input  wire  [PARA_AHS2_ACK_DATA_W-1:0] i_ack_data,

  // Destination data interface
  output logic [PARA_AHS2_DATA_W-1:0]     o_data,

  // Acknowledge toggle returned to the source block
  output logic                            o_ack,

  // Return payload to the source block
  output logic [PARA_AHS2_ACK_DATA_W-1:0] o_ack_data
);

  // Internal signal declarations
  logic                        w_req_s;
  logic                        w_ready;
  logic                        w_accept;
  logic                        reg_ack;
  logic [PARA_AHS2_DATA_W-1:0] reg_data;

  // Ready path: mode 0 uses i_ack directly in the accept condition; mode 1 registers i_ack into
  // reg_ready and uses it one destination cycle later.
  generate
    if (PARA_AHS2_DST_MODE == 0) begin : gen_ready_direct
      // Direct ready path: the destination accept level gates the accept directly.
      assign w_ready = i_ack;
    end else begin : gen_ready_reg
      logic reg_ready;

      // Registered ready path: the registered accept level gates the accept.
      assign w_ready = reg_ready;

      // Ready register: the accept condition is evaluated one destination cycle later.
      always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ff_ready
        if (!i_rst_n_dst)
          reg_ready <= 1'b0;
        else
          reg_ready <= i_ack;
      end
    end
  endgenerate

  // Accept condition: a pending word is accepted when the synchronized request toggle differs
  // from the acknowledge toggle and the destination user is ready.
  assign w_accept = (w_req_s != reg_ack) && w_ready;

  // Output mapping: the accepted payload and the acknowledge toggle are the destination registers.
  assign o_data = reg_data;
  assign o_ack  = reg_ack;

  // Accept capture: at the accept edge the acknowledge flag toggles and the request payload is
  // captured. Both registers hold until the next accept edge.
  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ff_accept
    if (!i_rst_n_dst) begin
      reg_ack  <= 1'b0;
      reg_data <= '0;
    end else if (w_accept) begin
      reg_ack  <= ~reg_ack;
      reg_data <= i_data;
    end
  end

  // Return payload of the acknowledge direction. Mode 0 disables the channel and drives zeros.
  // Mode 1 passes the destination user payload through unchanged. Mode 2 captures it at the
  // accept edge and holds it until the next accept, so the return value is the one present when
  // the destination accepted.
  generate
    if (PARA_AHS2_ACK_DATA_MODE == 0) begin : gen_ack_data_zero
      // Disabled channel: the return payload is held at zero. The AND with zero keeps every
      // port referenced in this configuration and folds to a constant in synthesis.
      assign o_ack_data = i_ack_data & {PARA_AHS2_ACK_DATA_W{1'b0}};
    end else if (PARA_AHS2_ACK_DATA_MODE == 1) begin : gen_ack_data_transparent
      // Transparent return payload
      assign o_ack_data = i_ack_data;
    end else begin : gen_ack_data_held
      logic [PARA_AHS2_ACK_DATA_W-1:0] reg_ack_data;

      // Output mapping of the held return payload.
      assign o_ack_data = reg_ack_data;

      // Return payload capture: the value present at the accept edge is held through the
      // acknowledge window and is reset to 0 in the destination domain.
      always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ff_ret_capture
        if (!i_rst_n_dst)
          reg_ack_data <= '0;
        else if (w_accept)
          reg_ack_data <= i_ack_data;
      end
    end
  endgenerate

  // Request crossing CDC-001: one-bit toggle synchronizer in the destination clock domain,
  // reset to 0 and selected by PARA_AHS2_SYNC_TYPE.
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_AHS2_SYNC_TYPE)
  ) u_sync_req (
    .i_clk_dst   (i_clk_dst),
    .i_rst_n_dst (i_rst_n_dst),
    .i_d         (i_req),
    .o_q         (w_req_s)
  );

endmodule
