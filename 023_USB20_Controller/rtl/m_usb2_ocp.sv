/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Port over-current protection in CLK-BUS (FEAT-021, REQ-FUNC-034, REQ-IF-010,
 *                CDC-006). The active-low flag is synchronized with the library synchronizer and
 *                filtered for PARA_USB2_OC_FILT cycles. A filtered flag latches the power-off
 *                state, drops o_pwr_en in the next cycle and pulses o_oc_evt. Power returns only
 *                after software cleared the ocur flag and wrote vbus_drv 0 then 1 (WF-035).
 */
`timescale 1ns/1ps

module m_usb2_ocp #(
  // Parameter Description: number of consecutive CLK-BUS cycles the flag must stay active.
  // Parameter values: 2 to 255; default is 16 (ASM-022).
  // Parameter unit: cycle
  parameter logic [31:0] PARA_USB2_OC_FILT = 16,
  localparam logic [31:0] LPARA_FILT_W   = 8,
  localparam logic [31:0] LPARA_SYNC_W   = 1,
  localparam logic [31:0] LPARA_SYNC_RV  = 1,
  localparam logic [31:0] LPARA_CELL_2FF = 2
) (
  // Clock and reset
  input  wire  i_clk_bus,
  input  wire  i_rst_n_bus,

  // External switch flag and software controls
  input  wire  i_ovrcur_n,
  input  wire  i_oc_en,
  input  wire  i_vbus_drv,
  input  wire  i_ocur_flag,

  // Power switch enable and status
  output logic o_pwr_en,
  output logic o_oc_evt,
  output logic o_oc_act
);

  // Internal signal declarations
  logic                    w_flag_sync;
  logic                    w_oc_in;
  logic [LPARA_FILT_W-1:0] reg_cnt;
  logic [LPARA_FILT_W-1:0] w_cnt_nxt;
  logic                    reg_act;
  logic                    w_act_nxt;
  logic                    reg_off;
  logic                    w_off_nxt;
  logic                    reg_pwr_en;
  logic                    w_pwr_en_nxt;

  // Library synchronizer of the asynchronous flag; the reset value is the inactive level.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_SYNC_W),
    .PARA_AFIFO_SYNC_RST_VAL (LPARA_SYNC_RV),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_flag (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (i_rst_n_bus),
    .i_data      (i_ovrcur_n),
    .o_data      (w_flag_sync)
  );

  // The flag counts only when protection is enabled.
  assign w_oc_in  = ~w_flag_sync & i_oc_en;
  assign o_pwr_en = reg_pwr_en;
  assign o_oc_act = reg_act;
  assign o_oc_evt = w_act_nxt & ~reg_act;

  // Filter: counts consecutive active cycles; the filtered flag is set when the count reaches
  // the filter length and cleared as soon as the input is inactive.
  always_comb begin : p_com_filter
    w_cnt_nxt = '0;
    w_act_nxt = 1'b0;
    if (w_oc_in) begin
      w_cnt_nxt = reg_cnt + 8'd1;
      w_act_nxt = reg_act;
      if (reg_cnt >= PARA_USB2_OC_FILT[LPARA_FILT_W-1:0] - 8'd1)
        w_act_nxt = 1'b1;
      if (reg_act)
        w_cnt_nxt = reg_cnt;
    end
  end

  // Power-off latch and output enable: held set while the filtered flag is active (level, so a
  // re-arm during a persistent over-current cannot restore power, BUG-003), cleared when the
  // ocur flag is cleared and vbus_drv is low; the enable follows vbus_drv while no latch is set.
  always_comb begin : p_com_power
    w_off_nxt = reg_off;
    if (w_act_nxt)
      w_off_nxt = 1'b1;
    else if (~i_ocur_flag & ~i_vbus_drv)
      w_off_nxt = 1'b0;
    w_pwr_en_nxt = i_vbus_drv & ~w_off_nxt;
  end

  // Control state of the over-current block, reset asynchronously to the safe state (power off).
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_ocp
    if (!i_rst_n_bus) begin
      reg_cnt    <= '0;
      reg_act    <= 1'b0;
      reg_off    <= 1'b0;
      reg_pwr_en <= 1'b0;
    end else begin
      reg_cnt    <= w_cnt_nxt;
      reg_act    <= w_act_nxt;
      reg_off    <= w_off_nxt;
      reg_pwr_en <= w_pwr_en_nxt;
    end
  end

endmodule
