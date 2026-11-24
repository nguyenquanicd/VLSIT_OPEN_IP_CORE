/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Flush machine of one window FIFO (section 10.6, DEC-027). A request pulse makes
 *                it hold the software-reset input i_rst_n_sw of the library FIFO low for exactly
 *                one clock cycle; it then waits until o_sw_rst_busy of the FIFO has risen and
 *                fallen and reports done with a one-cycle pulse. A one-cycle low level starts the
 *                library reset handshake, which then completes by itself (001_AsyncGrayFIFO section
 *                10.7). A request that arrives while a flush is running is remembered and the flush
 *                runs once more before the done pulse. The machine lives in the write clock domain
 *                of its FIFO.
 * Decisions    : DEC-027
 */
`timescale 1ns/1ps

module m_chacha_flush (
  // Write clock and reset of the FIFO
  input  wire  i_clk_wr,
  input  wire  i_rst_n_wr,

  // Flush request and done pulses
  input  wire  i_req,
  output logic o_done,

  // Software reset handshake with the library FIFO
  output logic o_rst_n_sw,
  input  wire  i_swr_busy
);

  // FSM states: IDLE waits for a request, PULSE holds i_rst_n_sw low for one cycle, UP waits for
  // o_sw_rst_busy to rise, DN waits for it to fall. All four encodings are used.
  typedef enum logic [1:0] {
    ENUM_ST_IDLE  = 2'b00,
    ENUM_ST_PULSE = 2'b01,
    ENUM_ST_UP    = 2'b10,
    ENUM_ST_DN    = 2'b11
  } flush_state_type_def;

  // Internal signal declarations
  flush_state_type_def reg_fsm_fl_current_state;
  flush_state_type_def w_fsm_fl_nxt_state;
  logic                reg_again;
  logic                w_end;

  // The flush ends when the busy flag of the FIFO has fallen again after having risen.
  assign w_end = (reg_fsm_fl_current_state == ENUM_ST_DN) & ~i_swr_busy;

  // Output mapping: the software reset is active (low) in the PULSE state only; done is a pulse
  // when the last flush ends and no further request is stored.
  assign o_rst_n_sw = (reg_fsm_fl_current_state != ENUM_ST_PULSE);
  assign o_done     = w_end & ~reg_again;

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_wr, negedge i_rst_n_wr) begin : p_ff_fsm_fl
    if (!i_rst_n_wr)
      reg_fsm_fl_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_fl_current_state <= w_fsm_fl_nxt_state;
  end

  // Part 2 of the FSM: a request starts the pulse; after the pulse the machine waits for the busy
  // flag to rise and to fall; a stored request restarts the pulse after the end.
  always_comb begin : p_com_fsm_nxt
    w_fsm_fl_nxt_state = reg_fsm_fl_current_state;
    case (reg_fsm_fl_current_state)
      ENUM_ST_IDLE: begin
        if (i_req)
          w_fsm_fl_nxt_state = ENUM_ST_PULSE;
      end
      ENUM_ST_PULSE: w_fsm_fl_nxt_state = ENUM_ST_UP;
      ENUM_ST_UP: begin
        if (i_swr_busy)
          w_fsm_fl_nxt_state = ENUM_ST_DN;
      end
      ENUM_ST_DN: begin
        if (w_end & reg_again)
          w_fsm_fl_nxt_state = ENUM_ST_PULSE;
        else if (w_end)
          w_fsm_fl_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_fl_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Stored request: set by a request while a flush runs, cleared when the flush restarts.
  always_ff @(posedge i_clk_wr, negedge i_rst_n_wr) begin : p_ff_again
    if (!i_rst_n_wr)
      reg_again <= 1'b0;
    else if (i_req & (reg_fsm_fl_current_state != ENUM_ST_IDLE))
      reg_again <= 1'b1;
    else if (w_end)
      reg_again <= 1'b0;
  end

endmodule
