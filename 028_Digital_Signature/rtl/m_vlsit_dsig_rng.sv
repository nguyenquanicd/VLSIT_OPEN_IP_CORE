/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Random source of the digital signature IP (OP-007, REQ-SEC-007), entropy-port
 *                form. At the start pulse of the control block (ENUM_ST_RNG) it collects a pool
 *                of 96 random bytes (768 bits, byte i in bits [8 i +: 8]) from the entropy port:
 *                o_ent_req stays high and one 32-bit word is taken at each cycle with
 *                i_ent_valid. A word that does not arrive within i_tmo_ent units of 1024 clocks
 *                gives a one-cycle o_tmo pulse and clears the pool. o_done is a one-cycle pulse
 *                when the pool is full. The pool is for one operation: the engines read it while
 *                the operation runs and the clear input empties it. 96 bytes cover the largest
 *                request of this IP (a P-521 nonce with 64 extra bits and the 32-byte hedging
 *                value of ML-DSA). The entropy input is the output of a full-entropy source
 *                (ASM-018). The internal hash-based generator of DEC-014 is not built in this
 *                revision: PARA_RNG_SRC shall be 0. The reseed command of the CSR is taken and
 *                cleared at once; the generator is always ready and never due. Requirements:
 *                REQ-SEC-007, OP-007, DEC-014.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_rng #(
  // Parameter Description: source of the random bytes; only the entropy port (0) is built.
  // Parameter values: 0; default is 0.
  // Parameter unit: code
  parameter logic [31:0] PARA_RNG_SRC = 0
) (
  // Clock, reset and clearing
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,
  input  wire          i_clr,

  // Handshake with the control block
  input  wire          i_start,
  input  wire  [15:0]  i_tmo_ent,
  output logic         o_done,
  output logic         o_tmo,

  // Entropy port
  output logic         o_ent_req,
  input  wire          i_ent_valid,
  input  wire  [31:0]  i_ent_data,

  // CSR: reseed command (taken at once) and status
  input  wire          i_reseed,
  output logic         o_reseed_clr,
  output logic         o_ready,
  output logic         o_due,

  // Pool for the engines
  output logic [767:0] o_pool,
  output logic         o_cleared
);

  // States
  typedef enum logic [2:0] {
    ENUM_ST_IDLE = 3'd0,
    ENUM_ST_REQ  = 3'd1,
    ENUM_ST_DONE = 3'd2,
    ENUM_ST_TMO  = 3'd3
  } rng_state_type_def;

  // Internal signal declarations
  rng_state_type_def reg_fsm_rng_current_state;
  rng_state_type_def w_fsm_rng_nxt_state;
  logic [767:0]  reg_pool;
  logic [4:0]    reg_cnt;
  logic [25:0]   reg_tmo_cnt;
  logic [25:0]   w_tmo_lim;
  logic          w_tmo_hit;

  assign w_tmo_lim = {((i_tmo_ent == 16'd0) ? 16'd1 : i_tmo_ent), 10'd0};
  assign w_tmo_hit = (reg_tmo_cnt >= w_tmo_lim);

  assign o_ent_req    = (reg_fsm_rng_current_state == ENUM_ST_REQ);
  assign o_done       = (reg_fsm_rng_current_state == ENUM_ST_DONE);
  assign o_tmo        = (reg_fsm_rng_current_state == ENUM_ST_TMO);
  assign o_reseed_clr = i_reseed;
  assign o_ready      = 1'b1;
  assign o_due        = 1'b0;
  assign o_pool       = reg_pool;
  assign o_cleared    = ~(|reg_pool);

  // Part 1 of the FSM: state register.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_rng
    if (!i_rst_n_core)
      reg_fsm_rng_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_rng_current_state <= w_fsm_rng_nxt_state;
  end

  // Part 2 of the FSM: next state.
  always_comb begin : p_com_fsm_nxt
    w_fsm_rng_nxt_state = reg_fsm_rng_current_state;
    case (reg_fsm_rng_current_state)
      ENUM_ST_IDLE: begin
        if (i_start)
          w_fsm_rng_nxt_state = ENUM_ST_REQ;
      end
      ENUM_ST_REQ: begin
        if (w_tmo_hit)
          w_fsm_rng_nxt_state = ENUM_ST_TMO;
        else if (i_ent_valid & (reg_cnt == 5'd23))
          w_fsm_rng_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_DONE: w_fsm_rng_nxt_state = ENUM_ST_IDLE;
      ENUM_ST_TMO:  w_fsm_rng_nxt_state = ENUM_ST_IDLE;
      default:      w_fsm_rng_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_rng_nxt_state = ENUM_ST_IDLE;
  end

  // Data registers: pool, word counter and timeout counter.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
    if (!i_rst_n_core) begin
      reg_pool    <= 768'd0;
      reg_cnt     <= 5'd0;
      reg_tmo_cnt <= 26'd0;
    end
    else if (i_clr) begin
      reg_pool    <= 768'd0;
      reg_cnt     <= 5'd0;
      reg_tmo_cnt <= 26'd0;
    end
    else begin
      case (reg_fsm_rng_current_state)
        ENUM_ST_IDLE: begin
          reg_cnt     <= 5'd0;
          reg_tmo_cnt <= 26'd0;
        end
        ENUM_ST_REQ: begin
          if (i_ent_valid) begin
            reg_pool[32 * reg_cnt +: 32] <= i_ent_data;
            reg_cnt     <= reg_cnt + 5'd1;
            reg_tmo_cnt <= 26'd0;
          end else begin
            reg_tmo_cnt <= reg_tmo_cnt + 26'd1;
          end
        end
        ENUM_ST_TMO: begin
          reg_pool <= 768'd0;
        end
        default: begin
          reg_cnt <= 5'd0;
        end
      endcase
    end
  end

endmodule
