/*
 * Project      : VLSIT Asynchronous 4-phase handshake
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-12
 * Description  : Source-side block of the asynchronous four-phase handshake. It captures the
 *                payload at launch, holds the request and payload until the acknowledge crosses
 *                back, reports completion on o_ack, and closes the four-phase cycle before
 *                accepting the next request. The control state is the two flags reg_req and
 *                reg_ack; there is no finite-state machine. The acknowledge crossing uses the
 *                library one-bit synchronizer wrapper. The bundled return payload is forwarded
 *                unchanged on o_ack_data; the source block adds no state to that path.
 * Decisions    : DEC-001, DEC-002, DEC-003, DEC-004, DEC-008, DEC-009.
 */
`timescale 1ns/1ps

module m_vlsit_ahs4_src #(
  // Parameter Description: width of the bundled payload and of both data ports.
  // Parameter values: 1 to 256; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AHS4_DATA_W = 32,
  // Parameter Description: synchronizer depth selection for the acknowledge crossing.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS4_SYNC_TYPE = 2
) (
  // Source clock and reset
  input  wire                         i_clk_src,
  input  wire                         i_rst_n_src,

  // Source request interface
  input  wire                         i_req,
  input  wire  [PARA_AHS4_DATA_W-1:0] i_data,

  // Destination acknowledge input of the crossing
  input  wire                         i_ack,
  input  wire  [PARA_AHS4_DATA_W-1:0] i_ack_data,

  // Source completion interface
  output logic                        o_ack,
  output logic [PARA_AHS4_DATA_W-1:0] o_ack_data,

  // Request and payload to the destination block
  output logic                        o_req,
  output logic [PARA_AHS4_DATA_W-1:0] o_data
);

  // Internal signal declarations
  logic                        reg_req;
  logic [PARA_AHS4_DATA_W-1:0] reg_data;
  logic                        reg_ack;
  logic                        w_ack_s;
  logic                        w_launch;

  // Output mapping: the request, payload and completion are the source flag registers.
  assign o_req  = reg_req;
  assign o_data = reg_data;
  assign o_ack  = reg_ack;

  // Return payload: the bundled acknowledge-direction payload passes through the source block
  // unchanged so that o_ack_data is valid while o_ack is high.
  assign o_ack_data = i_ack_data;

  // Launch pulse: one cycle wide, accepted only when no transaction is outstanding and the
  // synchronized acknowledge of the previous transaction has already fallen.
  assign w_launch = i_req && !reg_req && !reg_ack && !w_ack_s;

  // Request and payload registers: the payload is captured at the launch edge and held until
  // the four-phase cycle closes. The request clears when the acknowledge crosses back.
  always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin : p_ff_req_data
    if (!i_rst_n_src) begin
      reg_req  <= 1'b0;
      reg_data <= '0;
    end else if (w_launch) begin
      reg_req  <= 1'b1;
      reg_data <= i_data;
    end else if (w_ack_s) begin
      reg_req <= 1'b0;
    end
  end

  // Completion flag: set when the acknowledge of the launched request crosses back, and held
  // until the source user drops i_req.
  always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin : p_ff_ack
    if (!i_rst_n_src)
      reg_ack <= 1'b0;
    else if (reg_req && w_ack_s)
      reg_ack <= 1'b1;
    else if (!i_req)
      reg_ack <= 1'b0;
  end

  // Acknowledge crossing CDC-002: one-bit level synchronizer in the source clock domain,
  // reset to 0 and selected by PARA_AHS4_SYNC_TYPE.
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_AHS4_SYNC_TYPE)
  ) u_sync_ack (
    .i_clk_dst   (i_clk_src),
    .i_rst_n_dst (i_rst_n_src),
    .i_d         (i_ack),
    .o_q         (w_ack_s)
  );

endmodule
