/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Clock-gating module of the core datapath (rule CLK-03). It wraps the library
 *                integrated clock-gating cell VLSIT_CELL_ICG, which latches the enable while the
 *                clock is low. The test-enable input forces the gated clock on in scan mode.
 * Decisions    : DEC-026
 */
`timescale 1ns/1ps

module m_chacha_clk_gate (
  // Clock, enable and test enable
  input  wire  i_clk_core,
  input  wire  i_en,
  input  wire  i_dft_test_en,

  // Gated clock
  output logic o_clk_gated
);

  // Library clock-gating cell: Q = CK and the latched (E or TE).
  VLSIT_CELL_ICG u_dont_touch_icg (
    .CK (i_clk_core),
    .E  (i_en),
    .TE (i_dft_test_en),
    .Q  (o_clk_gated)
  );

endmodule
