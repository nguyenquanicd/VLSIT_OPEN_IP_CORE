/*
 * Project      : VLSIT Asynchronous 4-phase handshake
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-12
 * Description  : Destination-side block of the asynchronous four-phase handshake. It synchronizes
 *                the request level into the destination clock domain. In transparent mode it
 *                passes the bundled payload and the destination acknowledge through. In capture
 *                mode it registers the request and payload and generates a registered
 *                acknowledge, which adds one destination clock of request latency and one of
 *                acknowledge latency. The mode is selected by PARA_AHS4_DST_MODE.
 * Decisions    : DEC-001, DEC-002, DEC-004, DEC-008, DEC-010.
 */
`timescale 1ns/1ps

module m_vlsit_ahs4_dst #(
  // Parameter Description: width of the bundled payload and of both data ports.
  // Parameter values: 1 to 256; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AHS4_DATA_W = 32,
  // Parameter Description: synchronizer depth selection for the request crossing.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_SYNC_TYPE = 2,
  // Parameter Description: destination data-presentation mode; selects option A or option B.
  // Parameter values: 0 = transparent (option A), 1 = captured (option B); default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_DST_MODE = 0
) (
  // Destination clock and reset
  input  wire                         i_clk_dst,
  input  wire                         i_rst_n_dst,

  // Request and payload from the source block
  input  wire                         i_req,
  input  wire  [PARA_AHS4_DATA_W-1:0] i_data,

  // Destination acknowledge input from the destination user
  input  wire                         i_ack,

  // Destination request interface
  output logic                        o_req,
  output logic [PARA_AHS4_DATA_W-1:0] o_data,

  // Acknowledge returned to the source block
  output logic                        o_ack
);

  // Internal signal declarations
  logic w_req_s;

  // Option A (PARA_AHS4_DST_MODE = 0): the synchronized request drives o_req, the bundled
  // payload passes through, and the destination acknowledge passes through unchanged.
  // Option B (PARA_AHS4_DST_MODE = 1): the request and payload are registered and the
  // acknowledge is registered and gated by the registered request.
  generate
    if (PARA_AHS4_DST_MODE == 0) begin : gen_dst_transparent
      // Transparent-path output mapping
      assign o_req  = w_req_s;
      assign o_data = i_data;
      assign o_ack  = i_ack;
    end else begin : gen_dst_capture
      // Capture-path registers
      logic                        reg_req;
      logic [PARA_AHS4_DATA_W-1:0] reg_data;
      logic                        reg_ack;

      // Output mapping of the capture path
      assign o_req  = reg_req;
      assign o_data = reg_data;
      assign o_ack  = reg_ack;

      // Request and payload capture: o_data is aligned with the registered o_req edge.
      always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ff_req_data
        if (!i_rst_n_dst) begin
          reg_req  <= 1'b0;
          reg_data <= '0;
        end else begin
          reg_req <= w_req_s;
          if (w_req_s && !reg_req)
            reg_data <= i_data;
        end
      end

      // Registered acknowledge: it rises only after the registered request is high and the
      // destination user has accepted the payload, and it falls when the request falls.
      always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ff_ack
        if (!i_rst_n_dst)
          reg_ack <= 1'b0;
        else
          reg_ack <= reg_req && i_ack;
      end
    end
  endgenerate

  // Request crossing CDC-001: one-bit level synchronizer in the destination clock domain, reset
  // to 0 and selected by PARA_AHS4_SYNC_TYPE.
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_AHS4_SYNC_TYPE)
  ) u_sync_req (
    .i_clk_dst   (i_clk_dst),
    .i_rst_n_dst (i_rst_n_dst),
    .i_d         (i_req),
    .o_q         (w_req_s)
  );

endmodule
