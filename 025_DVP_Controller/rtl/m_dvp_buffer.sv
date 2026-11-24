/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Owns the continuous-mode AFIFO and gated-mode SFIFO, selects the APB read path,
 *                reports occupancy, joins events, and flushes the selected FIFO. Implements
 *                REQ-FUNC-009..010 and DEC-018, DEC-022, DEC-031..032.
 */
`timescale 1ns/1ps

module m_dvp_buffer #(
  // Parameter Description: number of entries in each mode-specific FIFO.
  // Parameter values: power of 2, minimum 2; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_DEPTH = 32'd8,
  // Parameter Description: width of each stored sensor sample.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32'd8,
  // Parameter Description: AFIFO Gray-pointer synchronizer cell selection.
  // Parameter values: 0 to 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AFIFO_CELL_TYPE = 32'd2,
  // Parameter Description: AFIFO memory selection.
  // Parameter values: 0 (RTL array) or 1 (SRAM wrapper); default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AFIFO_MEM_USE_MACRO = 32'd0,
  // Parameter Description: active logic level of the gated-mode VSYNC pulse.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_VSYNC_ACTIVE = 32'd1,
  localparam logic [31:0] LPARA_OCC_W = $clog2(PARA_FIFO_DEPTH + 32'd1),
  localparam logic [31:0] LPARA_EVT_CELL = 32'd2,
  localparam logic [31:0] LPARA_BUS_W = 32'd32
) (
  // APB clock and local reset
  input  wire                    i_clk_apb,
  input  wire                    i_rst_n_apb,

  // Sensor clock and local reset
  input  wire                    i_clk_dvp,
  input  wire                    i_rst_n_dvp,

  // Capture mode and source-side pixel paths
  input  wire                    i_capture_en,
  input  wire                    i_pclk_mode,
  input  wire                    i_dvp_vsync,
  input  wire                    i_cont_frame_active,
  input  wire                    i_cont_frame_start,
  input  wire                    i_afifo_wr_en,
  input  wire  [PARA_DATA_W-1:0] i_afifo_wr_data,
  input  wire                    i_pixel_toggle,
  input  wire  [PARA_DATA_W-1:0] i_gated_data,
  input  wire                    i_capture_quiescent,
  input  wire                    i_flush_req,

  // APB FIFO read control and selected FIFO outputs
  input  wire                    i_rd_en,
  output logic [PARA_DATA_W-1:0] o_rd_data,
  output logic                   o_empty,
  output logic                   o_full,
  output logic [31:0]            o_occupancy,
  output logic                   o_active,
  output logic                   o_overflow_event,
  output logic                   o_mode_change_safe,
  output logic                   o_frame_start,
  output logic                   o_flush_busy,
  output logic                   o_flush_done
);

  // Flush states: IDLE, WAIT_SAFE, WAIT_BUSY, WAIT_RELEASE, CLEAR_REQ, WAIT_SW_CLEAR.
  typedef enum logic [2:0] {
    ENUM_ST_IDLE            = 3'b000,
    ENUM_ST_WAIT_SAFE       = 3'b001,
    ENUM_ST_WAIT_BUSY       = 3'b010,
    ENUM_ST_WAIT_RELEASE    = 3'b011,
    ENUM_ST_CLEAR_REQ       = 3'b100,
    ENUM_ST_WAIT_SW_CLEAR   = 3'b101
  } flush_state_type_def;

  // Internal width constants, FIFO state and mode-specific status.
  logic [LPARA_OCC_W-1:0] w_sf_full_thr;
  logic [LPARA_OCC_W-1:0] w_sf_empty_thr;
  logic [LPARA_OCC_W-1:0] w_sf_occupancy_nxt;
  logic [LPARA_OCC_W-1:0] reg_sf_occupancy;
  logic [LPARA_OCC_W-1:0] w_afifo_occupancy;
  logic [PARA_DATA_W-1:0] w_afifo_data;
  logic [PARA_DATA_W-1:0] w_sfifo_data;
  logic w_afifo_full;
  logic w_afifo_full_flag;
  logic w_afifo_empty;
  logic w_afifo_empty_flag;
  logic w_afifo_overflow;
  logic w_sfifo_full;
  logic w_sfifo_full_flag;
  logic w_sfifo_full_thr;
  logic w_sfifo_sw_busy;
  logic w_sfifo_empty;
  logic w_sfifo_empty_flag;
  logic w_sfifo_empty_thr;
  logic w_sfifo_overflow;
  logic w_sfifo_wr_en;
  logic [PARA_DATA_W-1:0] w_sfifo_wr_data;
  logic w_gate_frame_active;
  logic w_both_empty;
  logic w_gate_quiescent;
  logic w_afifo_ovf_apb;
  logic w_afifo_frame_start_apb;
  logic w_gate_frame_start;
  logic w_afifo_flush_req_dvp;
  logic w_afifo_sw_busy;
  logic w_afifo_sw_busy_apb;
  logic w_flush_safe;
  logic w_flush_selected_busy;
  logic w_flush_req_active;
  logic w_flush_state_active;
  logic reg_cont_quiescent_meta;
  logic reg_cont_quiescent_sync;
  logic w_sf_wr_acc;
  logic w_sf_rd_acc;
  flush_state_type_def reg_fsm_flush_current_state;
  flush_state_type_def w_fsm_flush_nxt_state;

  // Use a full-capacity threshold for FIFO status; the empty threshold does not affect reads.
  assign w_sf_full_thr = PARA_FIFO_DEPTH[LPARA_OCC_W-1:0];
  assign w_sf_empty_thr = '0;
  assign w_sf_wr_acc = w_sfifo_wr_en & ~w_sfifo_full;
  assign w_sf_rd_acc = i_rd_en & ~w_sfifo_empty & ~o_flush_busy;

  // Track exact gated-FIFO occupancy from accepted writes and reads in CLK-APB.
  always_comb begin : p_com_sf_occ_nxt
    w_sf_occupancy_nxt = reg_sf_occupancy;
    case ({w_sf_wr_acc, w_sf_rd_acc})
      2'b10: w_sf_occupancy_nxt = reg_sf_occupancy + 1'b1;
      2'b01: w_sf_occupancy_nxt = reg_sf_occupancy - 1'b1;
      default: w_sf_occupancy_nxt = reg_sf_occupancy;
    endcase
  end

  // Register the gated-FIFO count; simultaneous accepted read/write holds occupancy constant.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_sf_occ
    if (!i_rst_n_apb)
      reg_sf_occupancy <= '0;
    else if (o_flush_done && i_pclk_mode)
      reg_sf_occupancy <= '0;
    else
      reg_sf_occupancy <= w_sf_occupancy_nxt;
  end

  // Select the safe source-quiescent condition before issuing a FIFO software reset.
  assign w_flush_safe = ~i_capture_en &
                        (i_pclk_mode ? w_gate_quiescent : reg_cont_quiescent_sync);
  // Combine the CSR request and FSM state to hold the external flush-busy indication.
  assign w_flush_state_active = (reg_fsm_flush_current_state != ENUM_ST_IDLE);
  assign o_flush_busy = i_flush_req | w_flush_state_active;
  assign o_flush_done = (reg_fsm_flush_current_state == ENUM_ST_CLEAR_REQ);
  assign w_flush_req_active = (reg_fsm_flush_current_state == ENUM_ST_WAIT_BUSY);
  assign w_flush_selected_busy = i_pclk_mode ? w_sfifo_sw_busy : w_afifo_sw_busy_apb;

  // Flush only the selected FIFO, wait for its reset handshake, then clear the CSR request.
  always_comb begin : p_com_flush_state
    w_fsm_flush_nxt_state = reg_fsm_flush_current_state;
    case (reg_fsm_flush_current_state)
      ENUM_ST_IDLE: begin
        if (i_flush_req)
          w_fsm_flush_nxt_state = ENUM_ST_WAIT_SAFE;
      end
      ENUM_ST_WAIT_SAFE: begin
        if (w_flush_safe)
          w_fsm_flush_nxt_state = ENUM_ST_WAIT_BUSY;
      end
      ENUM_ST_WAIT_BUSY: begin
        if (w_flush_selected_busy)
          w_fsm_flush_nxt_state = ENUM_ST_WAIT_RELEASE;
      end
      ENUM_ST_WAIT_RELEASE: begin
        if (!w_flush_selected_busy)
          w_fsm_flush_nxt_state = ENUM_ST_CLEAR_REQ;
      end
      ENUM_ST_CLEAR_REQ: w_fsm_flush_nxt_state = ENUM_ST_WAIT_SW_CLEAR;
      ENUM_ST_WAIT_SW_CLEAR: begin
        // Request still set: the CSR did not take the hardware clear, so issue done again.
        if (!i_flush_req)
          w_fsm_flush_nxt_state = ENUM_ST_IDLE;
        else
          w_fsm_flush_nxt_state = ENUM_ST_CLEAR_REQ;
      end
      default: w_fsm_flush_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Advance the APB-domain flush controller through its selected-FIFO reset handshake.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_flush_state
    if (!i_rst_n_apb)
      reg_fsm_flush_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_flush_current_state <= w_fsm_flush_nxt_state;
  end

  // Synchronize continuous capture-disable acknowledgement into CLK-APB for safe mode changes.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_quiescent_sync
    if (!i_rst_n_apb) begin
      reg_cont_quiescent_meta <= 1'b1;
      reg_cont_quiescent_sync <= 1'b1;
    end else begin
      reg_cont_quiescent_meta <= i_capture_quiescent;
      reg_cont_quiescent_sync <= reg_cont_quiescent_meta;
    end
  end

  // The AFIFO carries continuous-PCLK pixels from the sensor domain to the APB domain.
  m_dvp_afifo #(
    .PARA_FIFO_DEPTH    (PARA_FIFO_DEPTH),
    .PARA_DATA_W        (PARA_DATA_W),
    .PARA_CELL_TYPE     (PARA_AFIFO_CELL_TYPE),
    .PARA_MEM_USE_MACRO (PARA_AFIFO_MEM_USE_MACRO)
  ) u_dvp_afifo (
    .i_clk_wr     (i_clk_dvp),
    .i_rst_n_wr   (i_rst_n_dvp),
    .i_wr_en      (i_afifo_wr_en),
    .i_wr_data    (i_afifo_wr_data),
    .o_full       (w_afifo_full_flag),
    .o_overflow   (w_afifo_overflow),
    .i_rst_n_sw   (~w_afifo_flush_req_dvp),
    .o_sw_rst_busy(w_afifo_sw_busy),
    .i_clk_rd     (i_clk_apb),
    .i_rst_n_rd   (i_rst_n_apb),
    .i_rd_en      (i_rd_en & ~i_pclk_mode & ~o_flush_busy),
    .o_rd_data    (w_afifo_data),
    .o_empty      (w_afifo_empty_flag),
    .o_underflow  (),
    .o_occupancy  (w_afifo_occupancy)
  );

  // Combine full/empty diagnostics conservatively for mode selection and status.
  assign w_afifo_full = w_afifo_full_flag;
  assign w_afifo_empty = w_afifo_empty_flag;

  // Synchronize the reset request into the PCLK writer domain and busy back into APB.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W        (32'd1),
    .PARA_AFIFO_SYNC_RST_VAL  (32'd0),
    .PARA_AFIFO_CELL_TYPE     (PARA_AFIFO_CELL_TYPE)
  ) u_afifo_flush_req_sync (
    .i_clk_dst   (i_clk_dvp),
    .i_rst_n_dst (i_rst_n_dvp),
    .i_data      (w_flush_req_active & ~i_pclk_mode),
    .o_data      (w_afifo_flush_req_dvp)
  );

  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W        (32'd1),
    .PARA_AFIFO_SYNC_RST_VAL  (32'd0),
    .PARA_AFIFO_CELL_TYPE     (PARA_AFIFO_CELL_TYPE)
  ) u_afifo_flush_busy_sync (
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_data      (w_afifo_sw_busy),
    .o_data      (w_afifo_sw_busy_apb)
  );

  // Transfer continuous-mode overflow pulses through the common event synchronizer.
  m_vlsit_event_sync #(
    .PARA_EVENT_SYNC_W         (32'd1),
    .PARA_EVENT_SYNC_CELL_TYPE (LPARA_EVT_CELL)
  ) u_afifo_overflow_sync (
    .i_clk_src   (i_clk_dvp),
    .i_rst_n_src (i_rst_n_dvp),
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_event_src (w_afifo_overflow),
    .o_event_dst (w_afifo_ovf_apb)
  );

  // Count each accepted continuous-mode frame-start event once in the APB domain.
  m_vlsit_event_sync #(
    .PARA_EVENT_SYNC_W         (32'd1),
    .PARA_EVENT_SYNC_CELL_TYPE (LPARA_EVT_CELL)
  ) u_afifo_frame_start_sync (
    .i_clk_src   (i_clk_dvp),
    .i_rst_n_src (i_rst_n_dvp),
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_event_src (i_cont_frame_start),
    .o_event_dst (w_afifo_frame_start_apb)
  );

  // Synchronize gated VSYNC and toggle events, then qualify writes into the APB-clocked SFIFO.
  m_dvp_gate_bridge #(
    .PARA_DATA_W       (PARA_DATA_W),
    .PARA_VSYNC_ACTIVE (PARA_VSYNC_ACTIVE)
  ) u_dvp_gate_bridge (
    .i_clk_apb       (i_clk_apb),
    .i_rst_n_apb     (i_rst_n_apb),
    .i_dvp_vsync     (i_dvp_vsync),
    .i_pixel_data    (i_gated_data),
    .i_pixel_toggle  (i_pixel_toggle),
    .i_capture_en    (i_capture_en),
    .i_pclk_mode     (i_pclk_mode),
    .o_frame_active  (w_gate_frame_active),
    .o_frame_start   (w_gate_frame_start),
    .o_sfifo_wr_en   (w_sfifo_wr_en),
    .o_sfifo_wr_data (w_sfifo_wr_data),
    .o_path_quiescent(w_gate_quiescent)
  );

  // The SFIFO stores gated-mode samples entirely in CLK-APB.
  m_vlsit_sfifo_top #(
    .PARA_SFIFO_DEPTH      (PARA_FIFO_DEPTH),
    .PARA_SFIFO_DATA_W     (PARA_DATA_W),
    .PARA_SFIFO_PTR_RETIME (32'd0),
    .PARA_SFIFO_MEM_USE_MACRO (32'd0)
  ) u_dvp_sfifo (
    .i_clk_wr      (i_clk_apb),
    .i_rst_n_wr    (i_rst_n_apb),
    .i_wr_en       (w_sfifo_wr_en),
    .i_wr_data     (w_sfifo_wr_data),
    .i_full_thr    (w_sf_full_thr),
    .o_full        (w_sfifo_full_flag),
    .o_full_thr    (w_sfifo_full_thr),
    .o_overflow    (w_sfifo_overflow),
    .i_rst_n_sw    (~(w_flush_req_active & i_pclk_mode)),
    .o_sw_rst_busy (w_sfifo_sw_busy),
    .i_clk_rd      (i_clk_apb),
    .i_rst_n_rd    (i_rst_n_apb),
    .i_rd_en       (i_rd_en & i_pclk_mode & ~o_flush_busy),
    .i_empty_thr   (w_sf_empty_thr),
    .o_rd_data     (w_sfifo_data),
    .o_empty       (w_sfifo_empty_flag),
    .o_empty_thr   (w_sfifo_empty_thr),
    .o_underflow   ()
  );

  // Combine synchronous FIFO flags with its threshold and reset-busy outputs.
  assign w_sfifo_full = w_sfifo_full_flag | w_sfifo_full_thr | w_sfifo_sw_busy;
  assign w_sfifo_empty = w_sfifo_empty_flag | w_sfifo_empty_thr;

  // Select data and flags from the software-selected FIFO mode.
  always_comb begin : p_com_fifo_sel
    o_rd_data = '0;
    o_empty = 1'b1;
    o_full = 1'b0;
    o_occupancy = '0;
    case (i_pclk_mode)
      1'b0: begin
        o_rd_data = w_afifo_data;
        o_empty = w_afifo_empty;
        o_full = w_afifo_full;
        o_occupancy = {{(LPARA_BUS_W-LPARA_OCC_W){1'b0}}, w_afifo_occupancy};
      end
      1'b1: begin
        o_rd_data = w_sfifo_data;
        o_empty = w_sfifo_empty;
        o_full = w_sfifo_full;
        o_occupancy = {{(LPARA_BUS_W-LPARA_OCC_W){1'b0}}, reg_sf_occupancy};
      end
      default: begin
        o_rd_data = '0;
        o_empty = 1'b1;
        o_full = 1'b0;
        o_occupancy = '0;
      end
    endcase
    if (o_flush_busy) begin
      o_rd_data = '0;
      o_empty = 1'b1;
      o_full = 1'b1;
      o_occupancy = '0;
    end
  end

  // Report mode-selected activity, both-FIFO emptiness and the source-safe mode-change condition.
  assign o_active = i_capture_en &
                    (i_pclk_mode ? w_gate_frame_active : i_cont_frame_active);

  // Both FIFOs must be empty before software can change the selected mode.
  assign w_both_empty = w_afifo_empty & w_sfifo_empty;

  // Require the currently selected capture source to be quiescent before accepting mode changes.
  assign o_mode_change_safe = ~o_flush_busy & w_both_empty &
                              (i_pclk_mode ? w_gate_quiescent : reg_cont_quiescent_sync);

  // Select the APB-local gated frame event or the synchronized continuous-PCLK event.
  assign o_frame_start = i_pclk_mode ? w_gate_frame_start : w_afifo_frame_start_apb;

  // Join APB-synchronized AFIFO overflow and local gated-SFIFO overflow pulses.
  assign o_overflow_event = w_afifo_ovf_apb | w_sfifo_overflow;

endmodule
