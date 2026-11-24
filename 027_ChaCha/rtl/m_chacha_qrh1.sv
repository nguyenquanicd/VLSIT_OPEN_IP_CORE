/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : First half of a ChaCha quarter round (RFC 8439 section 2.1): steps 1 and 2,
 *                a += b; d ^= a; d <<<= 16; c += d; b ^= c; b <<<= 12. The four results are the
 *                operands of m_chacha_qrh2. Purely combinational; used when the round loop is cut
 *                in the middle of the quarter round (PARA_PIPE_CHACHA = 1).
 * Decisions    : DEC-036
 */
`timescale 1ns/1ps

module m_chacha_qrh1 (
  // Quarter-round operands
  input  wire  [31:0] i_a,
  input  wire  [31:0] i_b,
  input  wire  [31:0] i_c,
  input  wire  [31:0] i_d,

  // Operands of the second half
  output logic [31:0] o_a,
  output logic [31:0] o_b,
  output logic [31:0] o_c,
  output logic [31:0] o_d
);

  // Internal signal declarations
  logic [31:0] w_a1;
  logic [31:0] w_d1x;
  logic [31:0] w_d1;
  logic [31:0] w_c1;
  logic [31:0] w_b1x;
  logic [31:0] w_b1;

  // Step 1: a += b; d ^= a; d <<<= 16.
  assign w_a1  = $bits(w_a1)'(i_a + i_b);
  assign w_d1x = i_d ^ w_a1;
  assign w_d1  = {w_d1x[15:0], w_d1x[31:16]};

  // Step 2: c += d; b ^= c; b <<<= 12.
  assign w_c1  = $bits(w_c1)'(i_c + w_d1);
  assign w_b1x = i_b ^ w_c1;
  assign w_b1  = {w_b1x[19:0], w_b1x[31:20]};

  // Output mapping.
  assign o_a = w_a1;
  assign o_b = w_b1;
  assign o_c = w_c1;
  assign o_d = w_d1;

endmodule
