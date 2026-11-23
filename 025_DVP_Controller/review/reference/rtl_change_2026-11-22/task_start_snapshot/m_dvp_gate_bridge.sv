/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Synchronizes gated-mode VSYNC and pixel-toggle events into CLK-APB and writes
 *                held pixel data into the APB-clocked FIFO. Implements DEC-018, DEC-027.
 */
`timescale 1ns/1ps

module m_dvp_gate_bridge #(
  // Parameter Description: pixel sample width passed through the bundled-data event path.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32'd8,
  // Parameter Description: active logic level of the sensor VSYNC frame pulse.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_VSYNC_ACTIVE = 32'd1
) (
  // APB clock and reset
  input  wire                    i_clk_apb,
  input  wire                    i_rst_n_apb,

  // Gated sensor signals and APB capture control
  input  wire                    i_dvp_vsync,
  input  wire  [PARA_DATA_W-1:0] i_pixel_data,
  input  wire                    i_pixel_toggle,
  input  wire                    i_capture_en,
  input  wire                    i_pclk_mode,

  // Gated-mode FIFO write and status
  output logic                   o_frame_active,
  output logic                   o_sfifo_wr_en,
  output logic [PARA_DATA_W-1:0] o_sfifo_wr_data,
  output logic                   o_path_quiescent
);

  // Two-stage level synchronizers and edge history for gated-mode CDC inputs.
  logic reg_vsync_meta;
  logic reg_vsync_sync;
  logic reg_vsync_active_dly;
  logic reg_toggle_meta;
  logic reg_toggle_sync;
  logic reg_toggle_seen;
  logic reg_frame_active;
  logic w_vsync_active;
  logic w_vsync_active_edge;
  logic w_pixel_event;

  // Convert the synchronized VSYNC level to the configured active polarity.
  assign w_vsync_active = (PARA_VSYNC_ACTIVE == 32'd1) ? reg_vsync_sync : ~reg_vsync_sync;
  assign w_vsync_active_edge = w_vsync_active & ~reg_vsync_active_dly;

  // Detect both transitions of the synchronized pixel toggle; data remains held at the source.
  assign w_pixel_event = reg_toggle_sync ^ reg_toggle_seen;
  assign o_path_quiescent = (reg_toggle_sync == reg_toggle_seen);

  // Synchronize sensor VSYNC into CLK-APB. The source pulse shall span at least four APB cycles.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_vsync_sync
    if (!i_rst_n_apb) begin
      reg_vsync_meta       <= (PARA_VSYNC_ACTIVE == 32'd0);
      reg_vsync_sync       <= (PARA_VSYNC_ACTIVE == 32'd0);
      reg_vsync_active_dly <= 1'b0;
    end else begin
      reg_vsync_meta       <= i_dvp_vsync;
      reg_vsync_sync       <= reg_vsync_meta;
      reg_vsync_active_dly <= w_vsync_active;
    end
  end

  // Synchronize the held pixel-valid toggle and continuously retire observed events while idle.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_toggle_sync
    if (!i_rst_n_apb) begin
      reg_toggle_meta <= 1'b0;
      reg_toggle_sync <= 1'b0;
      reg_toggle_seen <= 1'b0;
    end else begin
      reg_toggle_meta <= i_pixel_toggle;
      reg_toggle_sync <= reg_toggle_meta;
      reg_toggle_seen <= reg_toggle_sync;
    end
  end

  // Arm each gated-mode frame at one synchronized active VSYNC edge; capture disable disarms it.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_frame_active
    if (!i_rst_n_apb)
      reg_frame_active <= 1'b0;
    else if (!i_capture_en)
      reg_frame_active <= 1'b0;
    else if (w_vsync_active_edge)
      reg_frame_active <= 1'b1;
  end

  // A sensor sample is not stallable; the selected FIFO preserves old entries and flags overflow.
  // Output mapping: expose frame state and the FIFO write/data/event signals.
  assign o_frame_active   = reg_frame_active;
  assign o_sfifo_wr_en    = w_pixel_event & i_capture_en & i_pclk_mode & reg_frame_active;
  // Route the source-held payload directly to the synchronized FIFO write port.
  assign o_sfifo_wr_data  = i_pixel_data;
endmodule
