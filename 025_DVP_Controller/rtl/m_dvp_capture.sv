/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Samples the selected sensor PCLK edge for continuous and gated-valid-pixel
 *                profiles. Implements REQ-FUNC-001, REQ-FUNC-002, REQ-FUNC-009 and DEC-018,
 *                DEC-027, DEC-029, DEC-031.
 */
`timescale 1ns/1ps

module m_dvp_capture #(
  // Parameter Description: sensor pixel sample bus width.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32'd8,
  // Parameter Description: selected PCLK sample edge; 0 is rising and 1 is falling.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SAMPLE_EDGE = 32'd0,
  // Parameter Description: active logic level of the sensor VSYNC frame pulse.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_VSYNC_ACTIVE = 32'd1,
  // Parameter Description: active logic level of the sensor HREF line qualifier.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_HREF_ACTIVE = 32'd1
) (
  // Sensor clock and local reset
  input  wire                    i_clk_dvp,
  input  wire                    i_rst_n_dvp,
  input  wire                    i_rst_n_gated,

  // Sensor pixel and qualifiers
  input  wire  [PARA_DATA_W-1:0] i_dvp_data,
  input  wire                    i_dvp_vsync,
  input  wire                    i_dvp_href,

  // APB controls, synchronized to the sensor domain for continuous capture
  input  wire                    i_capture_en,
  input  wire                    i_pclk_mode,

  // Continuous AFIFO write path and gated held-data/toggle path
  output logic                   o_afifo_wr_en,
  output logic [PARA_DATA_W-1:0] o_afifo_wr_data,
  output logic [PARA_DATA_W-1:0] o_gated_data,
  output logic                   o_valid_toggle,
  output logic                   o_cont_frame_active,
  output logic                   o_cont_frame_start,
  output logic                   o_capture_quiescent
);

  // The continuous-mode control synchronizers and their local readiness state.
  logic reg_capture_meta;
  logic reg_capture_sync;
  logic reg_mode_meta;
  logic reg_mode_sync;
  logic [1:0] reg_ready_pipe;
  logic reg_vsync_active_dly;
  logic reg_frame_active;
  logic reg_cont_frame_start;
  logic reg_capture_quiescent;
  logic w_vsync_active;
  logic w_vsync_active_edge;
  logic w_href_active;
  logic w_afifo_sample;
  logic w_path_ready;
  logic reg_afifo_wr_en;
  logic [PARA_DATA_W-1:0] reg_afifo_wr_data;
  logic [PARA_DATA_W-1:0] reg_gated_data;
  logic reg_valid_toggle;

  // Convert the configured sensor qualifiers to active-high internal levels.
  assign w_vsync_active = (PARA_VSYNC_ACTIVE == 32'd1) ? i_dvp_vsync : ~i_dvp_vsync;
  assign w_vsync_active_edge = w_vsync_active & ~reg_vsync_active_dly;
  assign w_href_active = (PARA_HREF_ACTIVE == 32'd1) ? i_dvp_href : ~i_dvp_href;
  assign w_afifo_sample = w_path_ready & reg_capture_sync & ~reg_mode_sync &
                          reg_frame_active & w_href_active;
  // Map internal registered payload/control state to the module outputs.
  assign o_afifo_wr_en = reg_afifo_wr_en;
  assign o_afifo_wr_data = reg_afifo_wr_data;
  assign o_gated_data = reg_gated_data;
  assign o_valid_toggle = reg_valid_toggle;
  assign w_path_ready = &reg_ready_pipe;
  assign o_cont_frame_active = reg_frame_active;
  assign o_cont_frame_start = reg_cont_frame_start;
  assign o_capture_quiescent = reg_capture_quiescent;

  // Keep continuous-mode controls and reset-release readiness in the PCLK domain.
  always_ff @(posedge i_clk_dvp, negedge i_rst_n_dvp) begin : p_ff_ctrl_sync
    if (!i_rst_n_dvp) begin
      reg_capture_meta <= 1'b0;
      reg_capture_sync <= 1'b0;
      reg_mode_meta    <= 1'b0;
      reg_mode_sync    <= 1'b0;
      reg_ready_pipe   <= '0;
    end else begin
      reg_capture_meta <= i_capture_en;
      reg_capture_sync <= reg_capture_meta;
      reg_mode_meta    <= i_pclk_mode;
      reg_mode_sync    <= reg_mode_meta;
      reg_ready_pipe   <= {reg_ready_pipe[0], 1'b1};
    end
  end

  // Sample continuous-mode pixels on the selected edge after a VSYNC frame boundary.
  generate
    if (PARA_SAMPLE_EDGE == 32'd0) begin : gen_rise_sample
      // Posedge sample implementation for the selected rising-edge profile.
      always_ff @(posedge i_clk_dvp, negedge i_rst_n_dvp) begin : p_ff_rise_capture
        if (!i_rst_n_dvp) begin
          reg_vsync_active_dly <= 1'b0;
          reg_frame_active     <= 1'b0;
          reg_cont_frame_start <= 1'b0;
          reg_capture_quiescent <= 1'b1;
          reg_afifo_wr_en      <= 1'b0;
          reg_afifo_wr_data    <= '0;
        end else begin
          reg_vsync_active_dly <= w_vsync_active;
          reg_cont_frame_start <= w_path_ready & reg_capture_sync & ~reg_mode_sync &
                                  w_vsync_active_edge;
          if (!w_path_ready || !reg_capture_sync || reg_mode_sync)
            reg_frame_active <= 1'b0;
          else if (w_vsync_active_edge)
            reg_frame_active <= 1'b1;
          reg_capture_quiescent <= ~reg_capture_sync & ~reg_afifo_wr_en;
          reg_afifo_wr_en <= w_afifo_sample;
          if (w_afifo_sample)
            reg_afifo_wr_data <= i_dvp_data;
        end
      end
    end else begin : gen_fall_sample
      // Negedge sample implementation for the selected falling-edge profile.
      always_ff @(negedge i_clk_dvp, negedge i_rst_n_dvp) begin : p_ff_fall_capture
        if (!i_rst_n_dvp) begin
          reg_vsync_active_dly <= 1'b0;
          reg_frame_active     <= 1'b0;
          reg_cont_frame_start <= 1'b0;
          reg_capture_quiescent <= 1'b1;
          reg_afifo_wr_en      <= 1'b0;
          reg_afifo_wr_data    <= '0;
        end else begin
          reg_vsync_active_dly <= w_vsync_active;
          reg_cont_frame_start <= w_path_ready & reg_capture_sync & ~reg_mode_sync &
                                  w_vsync_active_edge;
          if (!w_path_ready || !reg_capture_sync || reg_mode_sync)
            reg_frame_active <= 1'b0;
          else if (w_vsync_active_edge)
            reg_frame_active <= 1'b1;
          reg_capture_quiescent <= ~reg_capture_sync & ~reg_afifo_wr_en;
          reg_afifo_wr_en <= w_afifo_sample;
          if (w_afifo_sample)
            reg_afifo_wr_data <= i_dvp_data;
        end
      end
    end
  endgenerate

  // Gated mode has no PCLK during VSYNC, so the source payload/toggle reset releases in CLK-APB.
  // The specified multi-cycle VSYNC interval provides reset-settling time before the first pixel.
  generate
    if (PARA_SAMPLE_EDGE == 32'd0) begin : gen_rise_toggle
      // Capture a gated pixel and toggle its event on the rising edge.
      always_ff @(posedge i_clk_dvp, negedge i_rst_n_gated) begin : p_ff_rise_toggle
        if (!i_rst_n_gated) begin
          reg_gated_data   <= '0;
          reg_valid_toggle <= 1'b0;
        end else if (w_href_active) begin
          reg_gated_data   <= i_dvp_data;
          reg_valid_toggle <= ~reg_valid_toggle;
        end
      end
    end else begin : gen_fall_toggle
      // Capture a gated pixel and toggle its event on the falling edge.
      always_ff @(negedge i_clk_dvp, negedge i_rst_n_gated) begin : p_ff_fall_toggle
        if (!i_rst_n_gated) begin
          reg_gated_data   <= '0;
          reg_valid_toggle <= 1'b0;
        end else if (w_href_active) begin
          reg_gated_data   <= i_dvp_data;
          reg_valid_toggle <= ~reg_valid_toggle;
        end
      end
    end
  endgenerate

endmodule
