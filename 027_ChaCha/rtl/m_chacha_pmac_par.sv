/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Poly1305 multiply-accumulate, architecture 2 (PARA_POLY_ARCH = 2): one 131 by 128
 *                bit multiplier and the two reduction folds in a single cycle, so a block can be
 *                started every cycle. acc = ((acc + n) * r) mod (2^130 - 5), partially reduced,
 *                with n the 16-byte block plus the added bit 2^128 (RFC 8439 section 2.5). The
 *                accumulator is a secret datapath register without reset: the one-time-key load of
 *                the parent clears it, and it is read only after the first block is accepted.
 *                With PARA_PIPE_POLY = 1 the loop is cut in two cycles: the first cycle forms the
 *                sum and four partial products of the sum with the four 32-bit slices of r, the
 *                second cycle adds the partial products and folds the result into the accumulator,
 *                so a block can be started every second cycle (DEC-036).
 * Decisions    : DEC-025, DEC-036
 */
`timescale 1ns/1ps

module m_chacha_pmac_par #(
  // Parameter Description: 1 splits the multiply-accumulate in two cycles (block interval 2).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_POLY = 32'd0
) (
  // Clock, reset and clear
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,
  input  wire          i_clr,

  // Clamped multiplier r and one block
  input  wire  [127:0] i_r,
  input  wire          i_start,
  input  wire  [127:0] i_blk,

  // Status and accumulator
  output logic         o_rdy,
  output logic [130:0] o_acc
);

  // Internal signal declarations
  logic [130:0] reg_acc;
  logic [130:0] w_sum;
  logic [258:0] w_prod;
  logic [130:0] w_fold;

  // Sum of the accumulator and the block with its added bit.
  assign w_sum = $bits(w_sum)'(reg_acc + {3'b001, i_blk});

  // Output mapping of the accumulator.
  assign o_acc = reg_acc;

  if (PARA_PIPE_POLY == 32'd0) begin : gen_single
    // The block is ready every cycle in this variant.
    assign o_rdy = 1'b1;

    // Full product of the sum and r, then the reduction modulo 2^130 - 5.
    assign w_prod = $bits(w_prod)'($bits(w_prod)'(w_sum) * $bits(w_prod)'(i_r));

    m_chacha_pfold u_pfold (
      .i_prod (w_prod),
      .o_acc  (w_fold)
    );

    // Accumulator register: cleared by i_clr, loaded with the folded product when a block starts.
    always_ff @(posedge i_clk_core) begin : p_ff_acc
      if (i_clr)
        reg_acc <= '0;
      else if (i_start)
        reg_acc <= w_fold;
    end
  end else begin : gen_pipe
    logic         reg_busy;
    logic         w_go;
    logic [162:0] reg_pp0;
    logic [162:0] reg_pp1;
    logic [162:0] reg_pp2;
    logic [162:0] reg_pp3;

    // A block is accepted when the second cycle of the previous block is over.
    assign o_rdy = ~reg_busy;
    assign w_go  = i_start & o_rdy;

    // Second cycle: the partial products side by side at bit 0, 32, 64 and 96, then the reduction.
    assign w_prod = $bits(w_prod)'($bits(w_prod)'(reg_pp0) + ($bits(w_prod)'(reg_pp1) << 32) +
                                   ($bits(w_prod)'(reg_pp2) << 64) + ($bits(w_prod)'(reg_pp3) << 96));

    m_chacha_pfold u_pfold (
      .i_prod (w_prod),
      .o_acc  (w_fold)
    );

    // Busy flag: control state with reset; it is high in the second cycle of a block.
    always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_busy
      if (!i_rst_n_core)
        reg_busy <= 1'b0;
      else if (i_clr)
        reg_busy <= 1'b0;
      else
        reg_busy <= w_go;
    end

    // Secret datapath registers without reset, qualified by the busy flag: the four partial
    // products of the first cycle and the accumulator that takes the folded sum in the second.
    always_ff @(posedge i_clk_core) begin : p_ff_data
      if (i_clr) begin
        reg_acc <= '0;
        reg_pp0 <= '0;
        reg_pp1 <= '0;
        reg_pp2 <= '0;
        reg_pp3 <= '0;
      end else begin
        if (w_go) begin
          reg_pp0 <= $bits(reg_pp0)'($bits(reg_pp0)'(w_sum) * $bits(reg_pp0)'(i_r[31:0]));
          reg_pp1 <= $bits(reg_pp1)'($bits(reg_pp1)'(w_sum) * $bits(reg_pp1)'(i_r[63:32]));
          reg_pp2 <= $bits(reg_pp2)'($bits(reg_pp2)'(w_sum) * $bits(reg_pp2)'(i_r[95:64]));
          reg_pp3 <= $bits(reg_pp3)'($bits(reg_pp3)'(w_sum) * $bits(reg_pp3)'(i_r[127:96]));
        end
        if (reg_busy)
          reg_acc <= w_fold;
      end
    end
  end

endmodule
