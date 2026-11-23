/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Implements the APB FIFO_DATA read endpoint, empty timeout and exactly-once pop.
 *                Implements REQ-IF-002, REQ-IF-005, REQ-IF-006 and DEC-017.
 */
`timescale 1ns/1ps

module m_dvp_apb_data #(
  // Parameter Description: width of one pixel sample in the selected FIFO.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32'd8,
  localparam logic [31:0] LPARA_BUS_W = 32'd32
) (
  // APB clock and reset
  input  wire                    i_clk_apb,
  input  wire                    i_rst_n_apb,

  // FIFO_DATA APB access
  input  wire                    i_psel,
  input  wire                    i_penable,
  input  wire                    i_pwrite,
  input  wire                    i_fifo_aligned,
  input  wire  [31:0]            i_timeout_cycles,

  // Selected FIFO head/status and read-pop interface
  input  wire  [PARA_DATA_W-1:0] i_fifo_data,
  input  wire                    i_fifo_empty,
  output logic                   o_fifo_rd_en,

  // APB endpoint response
  output logic                   o_pready,
  output logic [31:0]            o_prdata,
  output logic                   o_pslverr
);

  // Access state and timeout counter for one APB FIFO_DATA transfer.
  logic [31:0] reg_timeout_count;
  logic reg_access_done;
  logic w_access_active;
  logic w_timeout_hit;
  logic w_completion_now;
  logic w_err_now;
  logic w_success_now;
  logic w_ready_condition;

  // The timeout is measured in active APB access cycles; available data wins at the boundary.
  assign w_access_active = i_psel & i_penable & i_rst_n_apb;
  assign w_timeout_hit = (i_timeout_cycles == 32'd0) ? 1'b1 :
                         (reg_timeout_count >= (i_timeout_cycles - 32'd1));
  // Determine whether the active transfer can complete in this access cycle.
  assign w_ready_condition = i_pwrite | ~i_fifo_aligned | ~i_fifo_empty | w_timeout_hit;
  assign w_completion_now = w_access_active & ~reg_access_done & w_ready_condition;
  assign w_err_now = w_access_active & ~reg_access_done &
                       (i_pwrite | ~i_fifo_aligned | (i_fifo_empty & w_timeout_hit));
  // Accept a read and pop one FIFO entry only on a successful completion.
  assign w_success_now = w_access_active & ~reg_access_done & ~i_pwrite &
                         i_fifo_aligned & ~i_fifo_empty;

  // Hold the APB response through completion without repeating a FIFO pop.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_access_state
    if (!i_rst_n_apb)
      reg_access_done <= 1'b0;
    else if (!i_psel | ~i_penable)
      reg_access_done <= 1'b0;
    else if (w_completion_now)
      reg_access_done <= 1'b1;
  end

  // Count only empty FIFO_DATA read access cycles and clear the count outside that wait.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_timeout_count
    if (!i_rst_n_apb)
      reg_timeout_count <= '0;
    else if (!w_access_active | reg_access_done | i_pwrite | ~i_fifo_aligned | ~i_fifo_empty)
      reg_timeout_count <= '0;
    else if (!w_timeout_hit)
      reg_timeout_count <= reg_timeout_count + 32'd1;
  end

  // Complete writes, misaligned accesses, successful reads or expired empty reads in APB access.
  assign o_pready = i_rst_n_apb & i_psel & i_penable &
                    (reg_access_done | w_ready_condition);
  // Report an error only in the cycle that completes this transfer.
  assign o_pslverr = w_err_now;
  // Pop the selected FIFO exactly once on a successful APB read.
  assign o_fifo_rd_en = w_success_now;

  // Zero-extend the selected FIFO head; error and wait cycles return zero.
  always_comb begin : p_com_rd_data
    o_prdata = '0;
    if (w_access_active & ~i_pwrite & i_fifo_aligned & ~i_fifo_empty)
      o_prdata = {{(LPARA_BUS_W-PARA_DATA_W){1'b0}}, i_fifo_data};
  end

endmodule
