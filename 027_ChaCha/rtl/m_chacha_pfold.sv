/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Reduction of a Poly1305 product modulo 2^130 - 5 (RFC 8439 section 2.5). Because
 *                2^130 is congruent to 5, a product P = H * 2^130 + L folds to L + 5 * H; the sum
 *                is folded once more with its bits above bit 129. The result is below 2^130 + 36
 *                for any 259-bit input and below 2^130 + 5 for the products of this IP (the
 *                multiplier r is clamped below 2^124); it is a partial reduction, completed only
 *                when the tag is formed. Purely combinational.
 * Decisions    : DEC-025
 */
`timescale 1ns/1ps

module m_chacha_pfold (
  // Product and folded accumulator
  input  wire  [258:0] i_prod,
  output logic [130:0] o_acc
);

  // Internal signal declarations
  logic [129:0] w_low;
  logic [128:0] w_high;
  logic [132:0] w_fold1;
  logic [129:0] w_low2;
  logic [2:0]   w_high2;
  logic [130:0] w_fold2;

  // First fold: L + 5 * H with 5 * H formed as 4 * H + H.
  assign w_low   = i_prod[129:0];
  assign w_high  = i_prod[258:130];
  assign w_fold1 = $bits(w_fold1)'($bits(w_fold1)'(w_low) + $bits(w_fold1)'({w_high, 2'b00}) +
                                   $bits(w_fold1)'(w_high));

  // Second fold: the three bits above bit 129 times 5 are added to the low 130 bits.
  assign w_low2  = w_fold1[129:0];
  assign w_high2 = w_fold1[132:130];
  assign w_fold2 = $bits(w_fold2)'($bits(w_fold2)'(w_low2) + $bits(w_fold2)'({w_high2, 2'b00}) +
                                   $bits(w_fold2)'(w_high2));

  // Output mapping of the folded accumulator.
  assign o_acc = w_fold2;

endmodule
