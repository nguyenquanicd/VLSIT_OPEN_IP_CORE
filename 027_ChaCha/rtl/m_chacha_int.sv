/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Interrupt logic (section 6.4). In CLK-CORE it forms the events that load the raw
 *                bits of the register block: the six hardware events or the rising edge of the
 *                matching injection bit (REQ-REG-003), and the masked status, the bitwise AND of
 *                the raw bits and their enables. The interrupt output is the level "any masked
 *                bit set", synchronized into CLK-APB through a two-flop synchronizer cell (a
 *                direct connection when the APB clock and the core clock are the same net). The
 *                source bits are sticky register bits that change only through an event or a
 *                software write, so no single-cycle pulse crosses. The module spans CLK-CORE and
 *                CLK-APB.
 * Decisions    : DEC-026
 */
`timescale 1ns/1ps

module m_chacha_int #(
  // Parameter Description: 1 when the APB clock and the core clock are the same net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_APB_CORE = 32'd0
) (
  // Core clock and reset
  input  wire        i_clk_core,
  input  wire        i_rst_n_core,

  // Hardware events, injection bits, raw bits and enables from the register block (CLK-CORE)
  input  wire  [5:0] i_ev,
  input  wire  [5:0] i_irq_inj,
  input  wire  [5:0] i_irq_raw,
  input  wire  [5:0] i_irq_en,

  // Events that load the raw bits, and the masked status back to the register block (CLK-CORE)
  output logic [5:0] o_irq_load,
  output logic [5:0] o_irq_sts,

  // APB clock and reset, interrupt output (CLK-APB)
  input  wire        i_clk_apb,
  input  wire        i_rst_n_apb,
  output logic       o_int_cha
);

  // Internal signal declarations
  logic [5:0] reg_inj_d;
  logic [5:0] w_inj_rise;
  logic       w_any;
  logic       reg_any;

  // Injection edge: the previous value of each injection bit is a control flop reset to 0.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_inj
    if (!i_rst_n_core)
      reg_inj_d <= 6'd0;
    else
      reg_inj_d <= i_irq_inj;
  end

  // Loading events, masked status and the any-pending level.
  assign w_inj_rise = i_irq_inj & ~reg_inj_d;
  assign o_irq_load = i_ev | w_inj_rise;
  assign o_irq_sts  = i_irq_raw & i_irq_en;
  assign w_any      = (o_irq_sts != 6'd0);

  // The any-pending level is registered before it crosses into CLK-APB (rule CLK-01).
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_any
    if (!i_rst_n_core)
      reg_any <= 1'b0;
    else
      reg_any <= w_any;
  end

  // Interrupt output in CLK-APB.
  if (PARA_SYNC_APB_CORE == 32'd0) begin : gen_cdc
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_int (
      .i_clk_dst   (i_clk_apb),
      .i_rst_n_dst (i_rst_n_apb),
      .i_d         (reg_any),
      .o_q         (o_int_cha)
    );
  end else begin : gen_direct
    assign o_int_cha = reg_any;
  end

endmodule
