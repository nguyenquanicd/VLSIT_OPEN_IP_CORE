/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-13
 * Description  : Source-side block of the asynchronous two-phase (toggle) handshake. It captures
 *                the request payload at the launch edge, toggles the request flag on every launch,
 *                holds both until the acknowledge toggle crosses back, and forwards the bundled
 *                return payload unchanged. The control state is the single toggle flop reg_req;
 *                there is no finite-state machine. The acknowledge crossing uses the library
 *                one-bit synchronizer wrapper.
 * Decisions    : DEC-001, DEC-004, DEC-005, DEC-010, DEC-011.
 */
`timescale 1ns/1ps

module m_vlsit_ahs2_src #(
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
  // Parameter Description: synchronizer depth for the acknowledge crossing.
  // Parameter values: 1, 2, 3, or 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AHS2_SYNC_TYPE = 2
) (
  // Source clock and reset
  input  wire                             i_clk_src,
  input  wire                             i_rst_n_src,

  // Source request interface
  input  wire                             i_req,
  input  wire  [PARA_AHS2_DATA_W-1:0]     i_data,

  // Acknowledge toggle and return payload from the destination block
  input  wire                             i_ack,
  input  wire  [PARA_AHS2_ACK_DATA_W-1:0] i_ack_data,

  // Request toggle and payload to the destination block
  output logic                            o_req,
  output logic [PARA_AHS2_DATA_W-1:0]     o_data,

  // Return payload to the source user
  output logic [PARA_AHS2_ACK_DATA_W-1:0] o_ack_data
);

  // Internal signal declarations
  logic                        reg_req;
  logic [PARA_AHS2_DATA_W-1:0] reg_data;
  logic                        w_ack_s;
  logic                        w_launch;

  // Output mapping: the request toggle and the payload are the source flag registers.
  assign o_req  = reg_req;
  assign o_data = reg_data;

  // Return payload: the bundled acknowledge-direction payload passes through the source block
  // unchanged. The mode selection and the held register live in the destination block.
  assign o_ack_data = i_ack_data;

  // Launch condition: a word is launched at a source edge where i_req is high and the last
  // acknowledge toggle has already been observed, that is reg_req equals w_ack_s.
  assign w_launch = i_req && (reg_req == w_ack_s);

  // Request and payload registers: the payload is captured at the launch edge and held until the
  // next launch; the request flag toggles on every launch and otherwise holds.
  always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin : p_ff_req_data
    if (!i_rst_n_src) begin
      reg_req  <= 1'b0;
      reg_data <= '0;
    end else begin
      reg_req <= reg_req ^ w_launch;
      if (w_launch)
        reg_data <= i_data;
    end
  end

  // Acknowledge crossing CDC-002: one-bit toggle synchronizer in the source clock domain,
  // reset to 0 and selected by PARA_AHS2_SYNC_TYPE.
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_AHS2_SYNC_TYPE)
  ) u_sync_ack (
    .i_clk_dst   (i_clk_src),
    .i_rst_n_dst (i_rst_n_src),
    .i_d         (i_ack),
    .o_q         (w_ack_s)
  );

endmodule
