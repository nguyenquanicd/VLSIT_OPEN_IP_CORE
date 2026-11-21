/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : ULPI low power wake detector in CLK-BUS (CDC-007, REQ-IF-006, TBD-005). It is
 *                always on, because the PHY may stop CLK-PHY in low power mode. dir is
 *                synchronized with the library synchronizer (the data bits are not used,
 *                DEC-004). When the PHY wakes the link by asserting dir, o_wake_evt pulses. When
 *                software or the speed engine requests a wake (i_wake_req), o_stp_lp is held at
 *                1 until dir has been seen high and has dropped again, as in REF-007 section
 *                3.9. i_wake_req is a level from the bus-side CSR (remote wake of a device,
 *                resume of a host port, DEC-022); one wake handshake is made for each low power
 *                period (reg_woke). o_stp_lp is ORed into o_ulpi_stp by the ULPI adapter; it is
 *                0 while low power mode is not active.
 */
`timescale 1ns/1ps

module m_usb2_ulpilp #(
  localparam logic [31:0] LPARA_SYNC_W   = 1,
  localparam logic [31:0] LPARA_SYNC_RV  = 0,
  localparam logic [31:0] LPARA_CELL_2FF = 2
) (
  // Clock and reset of the always-on logic
  input  wire  i_clk_bus,
  input  wire  i_rst_n_bus,

  // Asynchronous ULPI pins in low power mode
  input  wire  i_ulpi_dir,

  // Low power state and wake request
  input  wire  i_lp_active,
  input  wire  i_wake_req,

  // Wake outputs
  output logic o_stp_lp,
  output logic o_wake_evt,
  output logic o_lp_sync
);

  // Internal signal declarations
  logic w_dir_sync;
  logic w_lp_sync;
  logic reg_dir_d;
  logic reg_stp;
  logic reg_seen_dir;
  logic reg_woke;
  logic w_woke_nxt;
  logic w_stp_nxt;
  logic w_seen_nxt;

  // Library synchronizers of the asynchronous direction pin and the low power flag of CLK-PHY.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_SYNC_W),
    .PARA_AFIFO_SYNC_RST_VAL (LPARA_SYNC_RV),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_dir (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (i_rst_n_bus),
    .i_data      (i_ulpi_dir),
    .o_data      (w_dir_sync)
  );

  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_SYNC_W),
    .PARA_AFIFO_SYNC_RST_VAL (LPARA_SYNC_RV),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_lp (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (i_rst_n_bus),
    .i_data      (i_lp_active),
    .o_data      (w_lp_sync)
  );

  // Outputs: the wake pulse is the rising edge of dir while low power mode is active.
  assign o_lp_sync  = w_lp_sync;
  assign o_stp_lp   = reg_stp;
  assign o_wake_evt = w_dir_sync & ~reg_dir_d & w_lp_sync;

  // Wake handshake: set by the request while low power is active, cleared after dir rose and fell.
  always_comb begin : p_com_stp
    w_stp_nxt  = reg_stp;
    w_seen_nxt = reg_seen_dir;
    w_woke_nxt = reg_woke;
    if (!w_lp_sync) begin
      w_stp_nxt  = 1'b0;
      w_seen_nxt = 1'b0;
      w_woke_nxt = 1'b0;
    end else if (!reg_stp) begin
      w_stp_nxt  = i_wake_req & ~reg_woke;
      w_seen_nxt = 1'b0;
    end else begin
      if (w_dir_sync)
        w_seen_nxt = 1'b1;
      if (reg_seen_dir & ~w_dir_sync) begin
        w_stp_nxt  = 1'b0;
        w_woke_nxt = 1'b1;
      end
    end
  end

  // State flops of the wake handshake and the edge detector.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_lp
    if (!i_rst_n_bus) begin
      reg_dir_d    <= 1'b0;
      reg_stp      <= 1'b0;
      reg_seen_dir <= 1'b0;
      reg_woke     <= 1'b0;
    end else begin
      reg_dir_d    <= w_dir_sync;
      reg_stp      <= w_stp_nxt;
      reg_seen_dir <= w_seen_nxt;
      reg_woke     <= w_woke_nxt;
    end
  end

endmodule
