/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : DVP-local asynchronous FIFO top. Reuses the common Gray-pointer write,
 *                synchronizer and memory modules; the local read side exports occupancy.
 *                Implements REQ-FUNC-003, REQ-FUNC-010 and DEC-022, DEC-026, DEC-031, DEC-032.
 */
`timescale 1ns/1ps

module m_dvp_afifo #(
  // Parameter Description: number of FIFO entries; must be a power of two and at least 2.
  // Parameter values: power of 2, minimum 2; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_DEPTH = 32'd8,
  // Parameter Description: width of one stored pixel sample.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32'd8,
  // Parameter Description: common Gray-pointer synchronizer cell selection.
  // Parameter values: 0 to 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_CELL_TYPE = 32'd2,
  // Parameter Description: select RTL-array or SRAM-wrapper storage.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_MEM_USE_MACRO = 32'd0,
  localparam logic [31:0] LPARA_ADDR_W = $clog2(PARA_FIFO_DEPTH),
  localparam logic [31:0] LPARA_PTR_W = LPARA_ADDR_W + 32'd1,
  localparam logic [31:0] LPARA_OCC_W = $clog2(PARA_FIFO_DEPTH + 32'd1)
) (
  // Write clock and reset
  input  wire                    i_clk_wr,
  input  wire                    i_rst_n_wr,

  // Pixel write interface
  input  wire                    i_wr_en,
  input  wire  [PARA_DATA_W-1:0] i_wr_data,
  output logic                   o_full,
  output logic                   o_overflow,
  input  wire                    i_rst_n_sw,
  output logic                   o_sw_rst_busy,

  // Read clock and reset
  input  wire                    i_clk_rd,
  input  wire                    i_rst_n_rd,

  // APB read interface and occupancy estimate
  input  wire                    i_rd_en,
  output logic [PARA_DATA_W-1:0] o_rd_data,
  output logic                   o_empty,
  output logic                   o_underflow,
  output logic [LPARA_OCC_W-1:0] o_occupancy
);

  // Internal interconnects between the reusable FIFO children.
  logic [LPARA_PTR_W-1:0] w_wr_gray;
  logic [LPARA_PTR_W-1:0] w_rd_gray;
  logic [LPARA_PTR_W-1:0] w_full_thr;
  logic [LPARA_PTR_W-1:0] w_empty_thr;
  logic w_full_flag;
  logic w_full_thr_flag;
  logic w_empty_flag;
  logic w_empty_thr_flag;
  logic w_req_wr;
  logic w_ack_rd;
  logic w_mem_wr_en;
  logic [LPARA_ADDR_W-1:0] w_mem_wr_addr;
  logic [PARA_DATA_W-1:0] w_mem_wr_data;
  logic [LPARA_ADDR_W-1:0] w_mem_rd_addr;
  logic [PARA_DATA_W-1:0] w_mem_rd_data;

  // Set the full threshold to capacity and the empty threshold to zero for exact binary flags.
  assign w_full_thr = PARA_FIFO_DEPTH[LPARA_PTR_W-1:0];
  assign w_empty_thr = '0;

  // Common Gray-pointer write side in the sensor clock domain.
  m_vlsit_afifo_wr #(
    .PARA_AFIFO_DEPTH      (PARA_FIFO_DEPTH),
    .PARA_AFIFO_DATA_W     (PARA_DATA_W),
    .PARA_AFIFO_CELL_TYPE  (PARA_CELL_TYPE)
  ) u_afifo_wr (
    .i_clk_wr      (i_clk_wr),
    .i_rst_n_wr    (i_rst_n_wr),
    .i_wr_en       (i_wr_en),
    .i_wr_data     (i_wr_data),
    .i_full_thr    (w_full_thr),
    .i_rst_n_sw    (i_rst_n_sw),
    .i_rd_gray     (w_rd_gray),
    .i_ack_rd      (w_ack_rd),
    .o_full        (w_full_flag),
    .o_full_thr    (w_full_thr_flag),
    .o_overflow    (o_overflow),
    .o_sw_rst_busy (o_sw_rst_busy),
    .o_wr_gray     (w_wr_gray),
    .o_req_wr      (w_req_wr),
    .o_mem_wr_en   (w_mem_wr_en),
    .o_mem_wr_addr (w_mem_wr_addr),
    .o_mem_wr_data (w_mem_wr_data)
  );

  // Local read side exports the synchronized-pointer occupancy estimate.
  m_dvp_afifo_rd #(
    .PARA_AFIFO_DEPTH     (PARA_FIFO_DEPTH),
    .PARA_AFIFO_DATA_W    (PARA_DATA_W),
    .PARA_AFIFO_CELL_TYPE (PARA_CELL_TYPE)
  ) u_afifo_rd (
    .i_clk_rd      (i_clk_rd),
    .i_rst_n_rd    (i_rst_n_rd),
    .i_rd_en       (i_rd_en),
    .i_empty_thr   (w_empty_thr),
    .o_rd_data     (o_rd_data),
    .o_empty       (w_empty_flag),
    .o_empty_thr   (w_empty_thr_flag),
    .o_underflow   (o_underflow),
    .o_occupancy   (o_occupancy),
    .i_req_wr      (w_req_wr),
    .o_ack_rd      (w_ack_rd),
    .i_wr_gray     (w_wr_gray),
    .o_rd_gray     (w_rd_gray),
    .o_mem_rd_addr (w_mem_rd_addr),
    .i_mem_rd_data (w_mem_rd_data)
  );

  // Combine raw and threshold status; reset busy blocks new FIFO traffic.
  assign o_full = w_full_flag | w_full_thr_flag | o_sw_rst_busy | ~i_rst_n_sw;
  assign o_empty = w_empty_flag | w_empty_thr_flag;

  // Common dual-clock storage, with one write and one show-ahead read port.
  m_vlsit_afifo_mem #(
    .PARA_AFIFO_DEPTH         (PARA_FIFO_DEPTH),
    .PARA_AFIFO_DATA_W        (PARA_DATA_W),
    .PARA_AFIFO_MEM_USE_MACRO (PARA_MEM_USE_MACRO)
  ) u_afifo_mem (
    .i_clk_wr  (i_clk_wr),
    .i_wr_en   (w_mem_wr_en),
    .i_wr_addr (w_mem_wr_addr),
    .i_wr_data (w_mem_wr_data),
    .i_clk_rd  (i_clk_rd),
    .i_rd_addr (w_mem_rd_addr),
    .o_rd_data (w_mem_rd_data)
  );

endmodule
