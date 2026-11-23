/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Requests one DMA service batch at the selected FIFO watermark and waits for
 *                occupancy to fall below the watermark before re-arming. Implements DEC-008.
 */
`timescale 1ns/1ps

module m_dvp_dma_req #(
  // Parameter Description: physical FIFO capacity used to reject unreachable watermark values.
  // Parameter values: power of 2, minimum 2; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_DEPTH = 32'd8
) (
  // APB clock and reset
  input  wire         i_clk_apb,
  input  wire         i_rst_n_apb,

  // FIFO occupancy and software watermark
  input  wire  [31:0] i_occupancy,
  input  wire  [31:0] i_watermark,
  input  wire         i_dma_ack,

  // DMA batch request
  output logic        o_dma_req
);

  // Moore states: wait for a watermark, hold REQ until ACK, then wait for occupancy to drop.
  typedef enum logic [1:0] {
    ENUM_ST_WAIT  = 2'b00,
    ENUM_ST_REQ   = 2'b01,
    ENUM_ST_DRAIN = 2'b10
  } dma_state_type_def;

  dma_state_type_def reg_fsm_dma_current_state;
  dma_state_type_def w_fsm_dma_nxt_state;

  // Advance the batch state machine only on the specified threshold and handshake conditions.
  always_comb begin : p_com_fsm_dma_nxt
    w_fsm_dma_nxt_state = reg_fsm_dma_current_state;
    case (reg_fsm_dma_current_state)
      ENUM_ST_WAIT: begin
        if ((i_watermark != 32'd0) && (i_watermark <= PARA_FIFO_DEPTH) &&
            (i_occupancy >= i_watermark))
          w_fsm_dma_nxt_state = ENUM_ST_REQ;
      end
      ENUM_ST_REQ: begin
        if (i_dma_ack)
          w_fsm_dma_nxt_state = ENUM_ST_DRAIN;
      end
      ENUM_ST_DRAIN: begin
        if ((i_watermark == 32'd0) || (i_watermark > PARA_FIFO_DEPTH) ||
            (i_occupancy < i_watermark))
          w_fsm_dma_nxt_state = ENUM_ST_WAIT;
      end
      default: w_fsm_dma_nxt_state = ENUM_ST_WAIT;
    endcase
  end

  // State register asynchronously resets with the APB-local reset.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_fsm_dma
    if (!i_rst_n_apb)
      reg_fsm_dma_current_state <= ENUM_ST_WAIT;
    else
      reg_fsm_dma_current_state <= w_fsm_dma_nxt_state;
  end

  // The request is a level throughout the request state and does not pop FIFO data.
  assign o_dma_req = (reg_fsm_dma_current_state == ENUM_ST_REQ);

endmodule
