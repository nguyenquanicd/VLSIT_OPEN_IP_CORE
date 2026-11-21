/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Reset controller (section 7.3, REQ-RESET-001). Each domain gets a reset with
 *                asynchronous assertion and synchronous release from the library synchronizer. A
 *                software reset request from CLK-BUS (u2_ctrl.soft_rst) crosses to CLK-PHY as a
 *                level, resets the protocol engines for four cycles and returns an acknowledge
 *                level; o_soft_clr tells the CSR that hardware finished. In test mode
 *                (i_dft_test_en) the raw resets pass through (RST-04). o_phy_rst_n drives the
 *                PHY.
 */
`timescale 1ns/1ps

module m_usb2_rst #(
  // Parameter Description: reset synchronizer depth option of the library cell wrapper.
  // Parameter values: 1 to 4 as defined by m_vlsit_rst_sync; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_RST_SYNC_TYPE = 2,
  // Parameter Description: number of CLK-PHY cycles the engines stay in reset after a soft reset.
  // Parameter values: 2 to 7; default is 4.
  // Parameter unit: cycle
  parameter logic [31:0] PARA_USB2_SOFT_CYCLES = 4,
  localparam logic [31:0] LPARA_CNT_W = 3,
  localparam logic [31:0] LPARA_SYNC_W = 1,
  localparam logic [31:0] LPARA_SYNC_RV = 0,
  localparam logic [31:0] LPARA_CELL_2FF = 2
) (
  // Clock and reset inputs
  input  wire  i_clk_phy,
  input  wire  i_rst_n_phy,
  input  wire  i_clk_bus,
  input  wire  i_rst_n_bus,

  // Test control
  input  wire  i_dft_test_en,

  // Software controls from the CSR (CLK-BUS)
  input  wire  i_soft_req,
  input  wire  i_phy_hold,
  output logic o_soft_busy,
  output logic o_soft_clr,

  // Resets to the design
  output logic o_rst_n_phy,
  output logic o_rst_n_core,
  output logic o_rst_n_bus,
  output logic o_phy_rst_n
);

  // Internal signal declarations
  logic                 w_rst_phy_sync;
  logic                 w_rst_bus_sync;
  logic                 w_req_phy;
  logic                 w_ack_bus;
  logic                 reg_req_bus;
  logic                 reg_ack_phy;
  logic                 reg_ack_bus_d;
  logic                 reg_core_rst_n;
  logic [LPARA_CNT_W-1:0] reg_soft_cnt;
  logic [LPARA_CNT_W-1:0] w_soft_cnt_nxt;
  logic                 w_soft_active;

  // Reset synchronizers of the two domains (library cells, asynchronous assertion).
  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (PARA_USB2_RST_SYNC_TYPE)
  ) u_rst_sync_phy (
    .i_clk_dst   (i_clk_phy),
    .i_rst_n_src (i_rst_n_phy),
    .o_rst_n_dst (w_rst_phy_sync)
  );

  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (PARA_USB2_RST_SYNC_TYPE)
  ) u_rst_sync_bus (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_src (i_rst_n_bus),
    .o_rst_n_dst (w_rst_bus_sync)
  );

  // Soft reset request level to CLK-PHY and acknowledge level back to CLK-BUS (CDC-005).
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W      (LPARA_SYNC_W),
    .PARA_AFIFO_SYNC_RST_VAL(LPARA_SYNC_RV),
    .PARA_AFIFO_CELL_TYPE   (LPARA_CELL_2FF)
  ) u_sync_req (
    .i_clk_dst   (i_clk_phy),
    .i_rst_n_dst (w_rst_phy_sync),
    .i_data      (reg_req_bus),
    .o_data      (w_req_phy)
  );

  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W      (LPARA_SYNC_W),
    .PARA_AFIFO_SYNC_RST_VAL(LPARA_SYNC_RV),
    .PARA_AFIFO_CELL_TYPE   (LPARA_CELL_2FF)
  ) u_sync_ack (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (w_rst_bus_sync),
    .i_data      (reg_ack_phy),
    .o_data      (w_ack_bus)
  );

  // Reset outputs: the test mode override sits here and not in the functional leaves.
  assign o_rst_n_phy  = i_dft_test_en ? i_rst_n_phy : w_rst_phy_sync;
  assign o_rst_n_bus  = i_dft_test_en ? i_rst_n_bus : w_rst_bus_sync;
  assign o_rst_n_core = i_dft_test_en ? i_rst_n_phy : (w_rst_phy_sync & reg_core_rst_n);
  assign o_phy_rst_n  = ~i_phy_hold & o_rst_n_bus;
  assign o_soft_busy  = reg_req_bus | w_ack_bus;
  assign o_soft_clr   = reg_ack_bus_d & ~w_ack_bus;

  // The soft reset is active while the request level is high and not yet acknowledged.
  assign w_soft_active = w_req_phy & ~reg_ack_phy;

  // Soft reset counter on CLK-PHY: counts the reset cycles while the soft reset is active.
  always_comb begin : p_com_cnt
    w_soft_cnt_nxt = '0;
    if (w_soft_active)
      w_soft_cnt_nxt = reg_soft_cnt + 3'd1;
  end

  // Soft reset state on CLK-PHY: the core reset is low while the counter runs and the
  // acknowledge level stays high until the request level falls.
  always_ff @(posedge i_clk_phy, negedge w_rst_phy_sync) begin : p_ff_phy
    if (!w_rst_phy_sync) begin
      reg_soft_cnt   <= '0;
      reg_ack_phy    <= 1'b0;
      reg_core_rst_n <= 1'b1;
    end else begin
      reg_soft_cnt   <= w_soft_cnt_nxt;
      reg_core_rst_n <= ~w_soft_active;
      if (~w_req_phy)
        reg_ack_phy <= 1'b0;
      else if (reg_soft_cnt == PARA_USB2_SOFT_CYCLES[LPARA_CNT_W-1:0])
        reg_ack_phy <= 1'b1;
    end
  end

  // Soft reset state on CLK-BUS: the request level is held until the acknowledge arrives and
  // released after it; the edge of the acknowledge tells the CSR to clear soft_rst.
  always_ff @(posedge i_clk_bus, negedge w_rst_bus_sync) begin : p_ff_bus
    if (!w_rst_bus_sync) begin
      reg_req_bus   <= 1'b0;
      reg_ack_bus_d <= 1'b0;
    end else begin
      reg_ack_bus_d <= w_ack_bus;
      if (i_soft_req)
        reg_req_bus <= 1'b1;
      else if (w_ack_bus)
        reg_req_bus <= 1'b0;
    end
  end

endmodule
