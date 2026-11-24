/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Poly1305 multiply-accumulate, architecture 1 (PARA_POLY_ARCH = 1): a Karatsuba
 *                multiplier folded onto one 67 by 67 bit multiplier. With s = acc + n split at bit
 *                66 into a0 (66 bits) and a1 (65 bits) and r split into r0 (66 bits) and r1 (62
 *                bits), the product is a0*r0 + ((a0+a1)*(r0+r1) - a0*r0 - a1*r1) * 2^66 + a1*r1 *
 *                2^132. The three multiplications use the one multiplier in three cycles and the
 *                middle term, the assembly and the two reduction folds form the fifth cycle, so a
 *                block is accepted every 5 cycles. The sequence after the start cycle is MUL0,
 *                MUL1, MUL2 and RED. With PARA_PIPE_POLY = 1 the cycle RED forms the product into a
 *                register and a sixth cycle FLD folds it, so a block is accepted every 6 cycles
 *                (DEC-036). The accumulator is a secret datapath register without reset:
 *                the parent clears it with i_clr and reads it only after a block was accepted.
 * Decisions    : DEC-025, DEC-036
 */
`timescale 1ns/1ps

module m_chacha_pmac_kar #(
  // Parameter Description: 1 splits the reduction in two cycles (block interval 6).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_POLY = 32'd0
) (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Clear of the accumulator
  input  wire          i_clr,

  // Clamped multiplier r and one block
  input  wire  [127:0] i_r,
  input  wire          i_start,
  input  wire  [127:0] i_blk,

  // Status and accumulator
  output logic         o_rdy,
  output logic [130:0] o_acc
);

  // FSM states: IDLE accepts a block, MUL0 to MUL2 run the three multiplications and RED forms
  // the product and folds it; with PARA_PIPE_POLY = 1 RED only forms the product and FLD folds
  // it. The unused encodings recover to IDLE.
  typedef enum logic [2:0] {
    ENUM_ST_IDLE = 3'b000,
    ENUM_ST_MUL0 = 3'b001,
    ENUM_ST_MUL1 = 3'b010,
    ENUM_ST_MUL2 = 3'b011,
    ENUM_ST_RED  = 3'b100,
    ENUM_ST_FLD  = 3'b101
  } pmac_state_type_def;

  // Internal signal declarations
  pmac_state_type_def reg_fsm_pmac_current_state;
  pmac_state_type_def w_fsm_pmac_nxt_state;
  logic [130:0]       reg_acc;
  logic [130:0]       reg_s;
  logic [131:0]       reg_m0;
  logic [126:0]       reg_m1;
  logic [133:0]       reg_m2;
  logic [132:0]       reg_s01;
  logic [66:0]        w_a;
  logic [66:0]        w_b;
  logic [66:0]        w_a_sum;
  logic [66:0]        reg_a_sum;
  logic [66:0]        reg_b_sum;
  logic [66:0]        w_a_mid;
  logic [66:0]        w_b_mid;
  logic [66:0]        w_b_sum;
  logic [133:0]       w_prod;
  logic [130:0]       w_sum;
  logic [133:0]       w_mid;
  logic [258:0]       w_pfull;
  logic [258:0]       w_fold_in;
  logic [258:0]       reg_pf;
  logic [130:0]       w_fold;
  logic               w_go;

  // A block is accepted in IDLE only.
  assign o_rdy = (reg_fsm_pmac_current_state == ENUM_ST_IDLE);
  assign w_go  = i_start & o_rdy;

  // Sum of the accumulator and the block with its added bit 2^128.
  assign w_sum = $bits(w_sum)'(reg_acc + {3'b001, i_blk});

  // Operand sums of the middle product: (a0 + a1) and (r0 + r1), 67 bits each.
  assign w_a_sum = $bits(w_a_sum)'({1'b0, reg_s[65:0]} + {2'b00, reg_s[130:66]});
  assign w_b_sum = $bits(w_b_sum)'({1'b0, i_r[65:0]} + {5'b00000, i_r[127:66]});

  // With PARA_PIPE_POLY = 1 the operand sums are formed in the first multiply cycle and registered,
  // so the third multiplication does not start with a 67-bit addition.
  assign w_a_mid = (PARA_PIPE_POLY == 32'd1) ? reg_a_sum : w_a_sum;
  assign w_b_mid = (PARA_PIPE_POLY == 32'd1) ? reg_b_sum : w_b_sum;

  // Operand selection of the one multiplier: a0*r0, then a1*r1, then (a0+a1)*(r0+r1).
  always_comb begin : p_com_opnd
    w_a = {1'b0, reg_s[65:0]};
    w_b = {1'b0, i_r[65:0]};
    case (reg_fsm_pmac_current_state)
      ENUM_ST_MUL1: begin
        w_a = {2'b00, reg_s[130:66]};
        w_b = {5'b00000, i_r[127:66]};
      end
      ENUM_ST_MUL2: begin
        w_a = w_a_mid;
        w_b = w_b_mid;
      end
      default: begin
        w_a = {1'b0, reg_s[65:0]};
        w_b = {1'b0, i_r[65:0]};
      end
    endcase
  end

  // The shared 67 by 67 bit multiplier.
  assign w_prod = $bits(w_prod)'($bits(w_prod)'(w_a) * $bits(w_prod)'(w_b));

  // Middle term (a0+a1)*(r0+r1) - a0*r0 - a1*r1, then the full product: a1*r1 and a0*r0 side by
  // side (bits 132 and up, bits 131 to 0) plus the middle term shifted by 66 bits.
  assign w_mid   = $bits(w_mid)'(reg_m2 - reg_s01);
  assign w_pfull = $bits(w_pfull)'({reg_m1, reg_m0} + $bits(w_pfull)'({w_mid, 66'd0}));

  // Reduction of the product modulo 2^130 - 5.
  assign w_fold_in = (PARA_PIPE_POLY == 32'd1) ? reg_pf : w_pfull;

  m_chacha_pfold u_pfold (
    .i_prod (w_fold_in),
    .o_acc  (w_fold)
  );

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_pmac
    if (!i_rst_n_core)
      reg_fsm_pmac_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_pmac_current_state <= w_fsm_pmac_nxt_state;
  end

  // Part 2 of the FSM: IDLE goes to MUL0 when a block starts, then one state per cycle to RED and
  // back to IDLE; a clear returns to IDLE at once.
  always_comb begin : p_com_fsm_nxt
    w_fsm_pmac_nxt_state = reg_fsm_pmac_current_state;
    case (reg_fsm_pmac_current_state)
      ENUM_ST_IDLE: begin
        if (w_go)
          w_fsm_pmac_nxt_state = ENUM_ST_MUL0;
      end
      ENUM_ST_MUL0: w_fsm_pmac_nxt_state = ENUM_ST_MUL1;
      ENUM_ST_MUL1: w_fsm_pmac_nxt_state = ENUM_ST_MUL2;
      ENUM_ST_MUL2: w_fsm_pmac_nxt_state = ENUM_ST_RED;
      ENUM_ST_RED: begin
        if (PARA_PIPE_POLY == 32'd1)
          w_fsm_pmac_nxt_state = ENUM_ST_FLD;
        else
          w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_FLD:  w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
      default:      w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_pmac_nxt_state = ENUM_ST_IDLE;
  end

  // Secret datapath registers (no reset, qualified by the state): the sum of the start cycle, the
  // three products, the sum m0 + m1 formed in the third multiply cycle, and the accumulator that
  // takes the folded product in the RED cycle.
  always_ff @(posedge i_clk_core) begin : p_ff_data
    if (i_clr) begin
      reg_acc <= '0;
      reg_s   <= '0;
      reg_m0  <= '0;
      reg_m1  <= '0;
      reg_m2  <= '0;
      reg_s01 <= '0;
      reg_pf  <= '0;
      reg_a_sum <= '0;
      reg_b_sum <= '0;
    end else begin
      if (w_go)
        reg_s <= w_sum;
      if (reg_fsm_pmac_current_state == ENUM_ST_MUL0) begin
        reg_m0    <= w_prod[131:0];
        reg_a_sum <= w_a_sum;
        reg_b_sum <= w_b_sum;
      end
      if (reg_fsm_pmac_current_state == ENUM_ST_MUL1)
        reg_m1 <= w_prod[126:0];
      if (reg_fsm_pmac_current_state == ENUM_ST_MUL2) begin
        reg_m2  <= w_prod;
        reg_s01 <= $bits(reg_s01)'({1'b0, reg_m0} + {6'd0, reg_m1});
      end
      if (reg_fsm_pmac_current_state == ENUM_ST_RED) begin
        if (PARA_PIPE_POLY == 32'd1)
          reg_pf <= w_pfull;
        else
          reg_acc <= w_fold;
      end
      if (reg_fsm_pmac_current_state == ENUM_ST_FLD)
        reg_acc <= w_fold;
    end
  end

  // Output mapping of the accumulator.
  assign o_acc = reg_acc;

endmodule
