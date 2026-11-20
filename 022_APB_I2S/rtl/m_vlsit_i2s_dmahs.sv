/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : DMA handshake of one direction (APB clock domain); the top instantiates it once
 *                for transmit and once for receive. FSM dmahs: IDLE samples the watermark
 *                condition, REQ holds the request high until the acknowledge (even if the level
 *                changes), WAIT holds the request low until the acknowledge falls. The request
 *                falls in the cycle after the acknowledge rises (INV-006). The single output is
 *                high while one word can be moved and the DMA is enabled, and low while the
 *                acknowledge is high; it returns when the acknowledge falls if the condition holds.
 * Decisions    : DEC-018, REQ-FUNC-028, REQ-FUNC-029, OP-012, OP-013
 */
`timescale 1ns/1ps

module m_vlsit_i2s_dmahs (
  // Clock and reset
  input  wire  i_clk_apb,
  input  wire  i_rst_n_apb,

  // Enable and conditions from the register fields and the FIFO level
  input  wire  i_dma_en,
  input  wire  i_wm_cond,
  input  wire  i_one_cond,

  // Handshake with the DMA controller
  input  wire  i_dma_ack,
  output logic o_dma_req,
  output logic o_dma_single
);

  // FSM states: IDLE has the request low and waits for the watermark condition with DMA enabled,
  // REQ holds the request until the acknowledge rises, WAIT holds the request low until the
  // acknowledge falls. Encoding 3 is unused and recovers to ENUM_ST_IDLE.
  typedef enum logic [1:0] {
    ENUM_ST_IDLE = 2'b00,
    ENUM_ST_REQ  = 2'b01,
    ENUM_ST_WAIT = 2'b10
  } dmahs_state_type_def;

  // Internal signal declarations
  dmahs_state_type_def reg_fsm_dmahs_current_state;
  dmahs_state_type_def w_fsm_dmahs_nxt_state;
  logic reg_dma_req;
  logic reg_dma_single;
  logic w_dma_single_nxt;

  // Next-state logic. IDLE goes to REQ when DMA is enabled and the condition holds. REQ goes to
  // WAIT when the acknowledge is high, and back to IDLE when DMA is disabled. WAIT goes to IDLE
  // when the acknowledge is low.
  always_comb begin : p_com_fsm_dmahs
    w_fsm_dmahs_nxt_state = reg_fsm_dmahs_current_state;
    case (reg_fsm_dmahs_current_state)
      ENUM_ST_IDLE: begin
        if (i_dma_en && i_wm_cond && !i_dma_ack)
          w_fsm_dmahs_nxt_state = ENUM_ST_REQ;
      end
      ENUM_ST_REQ: begin
        if (i_dma_ack)
          w_fsm_dmahs_nxt_state = ENUM_ST_WAIT;
        else if (!i_dma_en)
          w_fsm_dmahs_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_WAIT: begin
        if (!i_dma_ack)
          w_fsm_dmahs_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_dmahs_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Current state: control state, asynchronously reset to IDLE.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_fsm_dmahs
    if (!i_rst_n_apb)
      reg_fsm_dmahs_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_dmahs_current_state <= w_fsm_dmahs_nxt_state;
  end

  // Request flop decoded from the next state, so it changes at the same edge as the state.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_dma_req
    if (!i_rst_n_apb)
      reg_dma_req <= 1'b0;
    else
      reg_dma_req <= (w_fsm_dmahs_nxt_state == ENUM_ST_REQ);
  end

  // Single indication: one word can be moved and the DMA is enabled; cleared while the
  // acknowledge is high (REQ-FUNC-029).
  assign w_dma_single_nxt = i_dma_en & i_one_cond & ~i_dma_ack;

  // Single flop, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_dma_single
    if (!i_rst_n_apb)
      reg_dma_single <= 1'b0;
    else
      reg_dma_single <= w_dma_single_nxt;
  end

  // Output mapping.
  assign o_dma_req    = reg_dma_req;
  assign o_dma_single = reg_dma_single;

endmodule
