/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : One ChaCha quarter round (RFC 8439 section 2.1): four 32-bit additions, four
 *                exclusive-ORs and the rotations by 16, 12, 8 and 7 bits. Purely combinational.
 * Decisions    : DEC-008, DEC-030
 */
`timescale 1ns/1ps

module m_chacha_qr (
  // Quarter-round operands
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
  logic [31:0] w_a1;
  logic [31:0] w_d1x;
  logic [31:0] w_d1;
  logic [31:0] w_c1;
  logic [31:0] w_b1x;
  logic [31:0] w_b1;
  logic [31:0] w_a2;
  logic [31:0] w_d2x;
  logic [31:0] w_d2;
  logic [31:0] w_c2;
  logic [31:0] w_b2x;
  logic [31:0] w_b2;

  // Step 1 of RFC 8439 section 2.1: a += b; d ^= a; d <<<= 16. The rotation left by n bits is
  // written as a concatenation of the low (32 - n) bits above the high n bits.
  assign w_a1  = $bits(w_a1)'(i_a + i_b);
  assign w_d1x = i_d ^ w_a1;
  assign w_d1  = {w_d1x[15:0], w_d1x[31:16]};

  // Step 2: c += d; b ^= c; b <<<= 12.
  assign w_c1  = $bits(w_c1)'(i_c + w_d1);
  assign w_b1x = i_b ^ w_c1;
  assign w_b1  = {w_b1x[19:0], w_b1x[31:20]};

  // Step 3: a += b; d ^= a; d <<<= 8.
  assign w_a2  = $bits(w_a2)'(w_a1 + w_b1);
  assign w_d2x = w_d1 ^ w_a2;
  assign w_d2  = {w_d2x[23:0], w_d2x[31:24]};

  // Step 4: c += d; b ^= c; b <<<= 7.
  assign w_c2  = $bits(w_c2)'(w_c1 + w_d2);
  assign w_b2x = w_b1 ^ w_c2;
  assign w_b2  = {w_b2x[24:0], w_b2x[31:25]};

  // Output mapping of the four updated words.
  assign o_a = w_a2;
  assign o_b = w_b2;
  assign o_c = w_c2;
  assign o_d = w_d2;

endmodule
