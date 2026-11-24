/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Reset wrapper (section 7.3, rule RST-04). Each of the three active-low resets
 *                passes through m_vlsit_rst_sync (asynchronous assertion, synchronous release in
 *                its own clock domain). With i_dft_test_en high the test reset i_dft_rst_n
 *                replaces the synchronized resets of all three domains (REQ-DFT-001); the
 *                override multiplexers live here and not in a functional block. The AXI-domain
 *                reset indication of CDC-009 is the synchronized AXI reset itself: it is low
 *                while the reset is asserted and for two AXI cycles after its release; it crosses
 *                into CLK-CORE through a two-flop synchronizer cell and its falling edge becomes
 *                a one-cycle pulse in CLK-CORE.
 * Decisions    : DEC-026, DEC-027, ASM-012
 */
`timescale 1ns/1ps

module m_chacha_rst_ctrl #(
  // Parameter Description: 1 when the AXI clock and the core clock are the same net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_AXI_CORE = 32'd0
) (
  // Clocks
  input  wire  i_clk_apb,
  input  wire  i_clk_axi,
  input  wire  i_clk_core,

  // Functional resets from the SoC
  input  wire  i_rst_n_apb,
  input  wire  i_rst_n_axi,
  input  wire  i_rst_n_core,

  // Test mode: enable and test reset
  input  wire  i_dft_test_en,
  input  wire  i_dft_rst_n,

  // Resets for the three domains
  output logic o_rst_n_apb,
  output logic o_rst_n_axi,
  output logic o_rst_n_core,

  // AXI-domain reset indication in CLK-CORE (one-cycle pulse on its falling edge)
  output logic o_axi_rstd_evt
);

  // Internal signal declarations
  logic w_sync_apb;
  logic w_sync_axi;
  logic w_sync_core;
  logic w_alive_core;
  logic reg_alive_d;

  // Reset synchronizers: asynchronous assertion, synchronous release per domain.
  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (32'd2)
  ) u_rst_sync_apb (
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_src (i_rst_n_apb),
    .o_rst_n_dst (w_sync_apb)
  );
  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (32'd2)
  ) u_rst_sync_axi (
    .i_clk_dst   (i_clk_axi),
    .i_rst_n_src (i_rst_n_axi),
    .o_rst_n_dst (w_sync_axi)
  );
  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (32'd2)
  ) u_rst_sync_core (
    .i_clk_dst   (i_clk_core),
    .i_rst_n_src (i_rst_n_core),
    .o_rst_n_dst (w_sync_core)
  );

  // Test override: in test mode every domain takes the test reset directly (RST-04).
  assign o_rst_n_apb  = i_dft_test_en ? i_dft_rst_n : w_sync_apb;
  assign o_rst_n_axi  = i_dft_test_en ? i_dft_rst_n : w_sync_axi;
  assign o_rst_n_core = i_dft_test_en ? i_dft_rst_n : w_sync_core;

  // The AXI reset indication crosses into CLK-CORE as a level (it sets to 1 after a core reset, so
  // the core reset itself gives no pulse).
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_cdc
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd1),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_alive (
      .i_clk_dst   (i_clk_core),
      .i_rst_n_dst (o_rst_n_core),
      .i_d         (w_sync_axi),
      .o_q         (w_alive_core)
    );
  end else begin : gen_direct
    assign w_alive_core = w_sync_axi;
  end

  // Falling-edge detector in CLK-CORE: the previous level is a control flop set to 1 by reset.
  always_ff @(posedge i_clk_core, negedge o_rst_n_core) begin : p_ff_alive
    if (!o_rst_n_core)
      reg_alive_d <= 1'b1;
    else
      reg_alive_d <= w_alive_core;
  end

  // Output mapping of the indication pulse.
  assign o_axi_rstd_evt = reg_alive_d & ~w_alive_core;

endmodule
