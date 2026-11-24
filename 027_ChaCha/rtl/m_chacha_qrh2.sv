/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Second half of a ChaCha quarter round (RFC 8439 section 2.1): steps 3 and 4,
 *                a += b; d ^= a; d <<<= 8; c += d; b ^= c; b <<<= 7, on the results of
 *                m_chacha_qrh1. Purely combinational; used when the round loop is cut in the
 *                middle of the quarter round (PARA_PIPE_CHACHA = 1).
 * Decisions    : DEC-036
 */
`timescale 1ns/1ps

module m_chacha_qrh2 (
  // Results of the first half
  input  wire  [31:0] i_a,
  input  wire  [31:0] i_b,
  input  wire  [31:0] i_c,
  input  wire  [31:0] i_d,

  // Quarter-round results
  output logic [31:0] o_a,
  output logic [31:0] o_b,
  output logic [31:0] o_c,
  output logic [31:0] o_d
);

  // Internal signal declarations
  logic [31:0] w_a2;
  logic [31:0] w_d2x;
  logic [31:0] w_d2;
  logic [31:0] w_c2;
  logic [31:0] w_b2x;
  logic [31:0] w_b2;

  // Step 3: a += b; d ^= a; d <<<= 8.
  assign w_a2  = $bits(w_a2)'(i_a + i_b);
  assign w_d2x = i_d ^ w_a2;
  assign w_d2  = {w_d2x[23:0], w_d2x[31:24]};

  // Step 4: c += d; b ^= c; b <<<= 7.
  assign w_c2  = $bits(w_c2)'(i_c + w_d2);
  assign w_b2x = i_b ^ w_c2;
  assign w_b2  = {w_b2x[24:0], w_b2x[31:25]};

  // Output mapping.
  assign o_a = w_a2;
  assign o_b = w_b2;
  assign o_c = w_c2;
  assign o_d = w_d2;

endmodule
