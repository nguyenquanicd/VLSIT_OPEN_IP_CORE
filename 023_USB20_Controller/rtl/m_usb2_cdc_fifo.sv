/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Crossing of the FIFO bus port (CDC-004, DEC-006). Three asynchronous FIFOs of
 *                the library with Gray pointers: the request FIFO (CLK-BUS to CLK-PHY) carries
 *                the bus operation, the queue and one RAM row; the response FIFO (CLK-PHY to
 *                CLK-BUS) carries the rows that were read; the event FIFO (CLK-PHY to CLK-BUS)
 *                carries packet and credit events. The bus side must keep at most
 *                PARA_USB2_CDC_DEPTH read requests outstanding, because the response FIFO has no
 *                back pressure.
 */
`timescale 1ns/1ps

module m_usb2_cdc_fifo #(
  // Parameter Description: RAM row width, 32 bits for 8-bit UTMI+ and 64 bits for 16-bit UTMI+.
  // Parameter values: 32 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_ROW_W = 32,
  // Parameter Description: depth of each crossing FIFO.
  // Parameter values: power of two, 4 or more; default is 8.
  // Parameter unit: entry
  parameter logic [31:0] PARA_USB2_CDC_DEPTH = 8,
  localparam logic [31:0] LPARA_RQ_W       = PARA_USB2_ROW_W + 32'd8,
  localparam logic [31:0] LPARA_EV_W       = 24,
  localparam logic [31:0] LPARA_PTR_W      = $clog2(PARA_USB2_CDC_DEPTH) + 32'd1,
  localparam logic [31:0] LPARA_CELL_2FF   = 2,
  localparam logic [31:0] LPARA_MEM_RTL    = 0
) (
  // CLK-BUS clock and reset
  input  wire                        i_clk_bus,
  input  wire                        i_rst_n_bus,

  // CLK-PHY clock and reset
  input  wire                        i_clk_phy,
  input  wire                        i_rst_n_phy,

  // Bus side request, response and event interfaces
  input  wire                        i_rq_vld,
  input  wire  [2:0]                 i_rq_op,
  input  wire  [4:0]                 i_rq_q,
  input  wire  [PARA_USB2_ROW_W-1:0] i_rq_data,
  output logic                       o_rq_rdy,
  output logic                       o_rs_vld,
  output logic [PARA_USB2_ROW_W-1:0] o_rs_data,
  input  wire                        i_rs_pop,
  output logic                       o_ev_vld,
  output logic [1:0]                 o_ev_type,
  output logic [4:0]                 o_ev_q,
  output logic [16:0]                o_ev_val,
  input  wire                        i_ev_pop,

  // PHY side bus port of m_usb2_fifo
  output logic                       o_bp_vld,
  output logic [2:0]                 o_bp_op,
  output logic [4:0]                 o_bp_q,
  output logic [PARA_USB2_ROW_W-1:0] o_bp_data,
  input  wire                        i_bp_rdy,
  input  wire                        i_bp_rsp_vld,
  input  wire  [PARA_USB2_ROW_W-1:0] i_bp_rsp_data,
  input  wire                        i_ev_vld,
  input  wire  [1:0]                 i_ev_type,
  input  wire  [4:0]                 i_ev_q,
  input  wire  [16:0]                i_ev_val,
  output logic                       o_ev_rdy
);

  // Internal signal declarations
  logic                       w_rq_full;
  logic                       w_rq_empty;
  logic [LPARA_RQ_W-1:0]      w_rq_data;
  logic                       w_rs_empty;
  logic                       w_rs_full;
  logic                       w_ev_empty;
  logic                       w_ev_full;
  logic [LPARA_EV_W-1:0]      w_ev_data;
  logic [LPARA_PTR_W-1:0]     w_zero_thr;

  assign w_zero_thr = '0;

  // Request FIFO: bus to PHY, entry {op, queue, row}.
  m_vlsit_afifo_top #(
    .PARA_AFIFO_DEPTH         (PARA_USB2_CDC_DEPTH),
    .PARA_AFIFO_DATA_W        (LPARA_RQ_W),
    .PARA_AFIFO_CELL_TYPE     (LPARA_CELL_2FF),
    .PARA_AFIFO_MEM_USE_MACRO (LPARA_MEM_RTL)
  ) u_rq_fifo (
    .i_clk_wr      (i_clk_bus),
    .i_rst_n_wr    (i_rst_n_bus),
    .i_wr_en       (i_rq_vld & ~w_rq_full),
    .i_wr_data     ({i_rq_op, i_rq_q, i_rq_data}),
    .i_full_thr    (w_zero_thr),
    .o_full        (w_rq_full),
    .o_full_thr    (),
    .o_overflow    (),
    .i_rst_n_sw    (i_rst_n_bus),
    .o_sw_rst_busy (),
    .i_clk_rd      (i_clk_phy),
    .i_rst_n_rd    (i_rst_n_phy),
    .i_rd_en       (~w_rq_empty & i_bp_rdy),
    .i_empty_thr   (w_zero_thr),
    .o_rd_data     (w_rq_data),
    .o_empty       (w_rq_empty),
    .o_empty_thr   (),
    .o_underflow   ()
  );

  assign o_rq_rdy  = ~w_rq_full;
  assign o_bp_vld  = ~w_rq_empty;
  assign o_bp_op   = w_rq_data[LPARA_RQ_W-1 -: 3];
  assign o_bp_q    = w_rq_data[PARA_USB2_ROW_W +: 5];
  assign o_bp_data = w_rq_data[PARA_USB2_ROW_W-1:0];

  // Response FIFO: PHY to bus, the rows that were read.
  m_vlsit_afifo_top #(
    .PARA_AFIFO_DEPTH         (PARA_USB2_CDC_DEPTH),
    .PARA_AFIFO_DATA_W        (PARA_USB2_ROW_W),
    .PARA_AFIFO_CELL_TYPE     (LPARA_CELL_2FF),
    .PARA_AFIFO_MEM_USE_MACRO (LPARA_MEM_RTL)
  ) u_rs_fifo (
    .i_clk_wr      (i_clk_phy),
    .i_rst_n_wr    (i_rst_n_phy),
    .i_wr_en       (i_bp_rsp_vld & ~w_rs_full),
    .i_wr_data     (i_bp_rsp_data),
    .i_full_thr    (w_zero_thr),
    .o_full        (w_rs_full),
    .o_full_thr    (),
    .o_overflow    (),
    .i_rst_n_sw    (i_rst_n_phy),
    .o_sw_rst_busy (),
    .i_clk_rd      (i_clk_bus),
    .i_rst_n_rd    (i_rst_n_bus),
    .i_rd_en       (~w_rs_empty & i_rs_pop),
    .i_empty_thr   (w_zero_thr),
    .o_rd_data     (o_rs_data),
    .o_empty       (w_rs_empty),
    .o_empty_thr   (),
    .o_underflow   ()
  );

  assign o_rs_vld = ~w_rs_empty;

  // Event FIFO: PHY to bus, entry {type, queue, value}.
  m_vlsit_afifo_top #(
    .PARA_AFIFO_DEPTH         (PARA_USB2_CDC_DEPTH),
    .PARA_AFIFO_DATA_W        (LPARA_EV_W),
    .PARA_AFIFO_CELL_TYPE     (LPARA_CELL_2FF),
    .PARA_AFIFO_MEM_USE_MACRO (LPARA_MEM_RTL)
  ) u_ev_fifo (
    .i_clk_wr      (i_clk_phy),
    .i_rst_n_wr    (i_rst_n_phy),
    .i_wr_en       (i_ev_vld & ~w_ev_full),
    .i_wr_data     ({i_ev_type, i_ev_q, i_ev_val}),
    .i_full_thr    (w_zero_thr),
    .o_full        (w_ev_full),
    .o_full_thr    (),
    .o_overflow    (),
    .i_rst_n_sw    (i_rst_n_phy),
    .o_sw_rst_busy (),
    .i_clk_rd      (i_clk_bus),
    .i_rst_n_rd    (i_rst_n_bus),
    .i_rd_en       (~w_ev_empty & i_ev_pop),
    .i_empty_thr   (w_zero_thr),
    .o_rd_data     (w_ev_data),
    .o_empty       (w_ev_empty),
    .o_empty_thr   (),
    .o_underflow   ()
  );

  assign o_ev_rdy  = ~w_ev_full;
  assign o_ev_vld  = ~w_ev_empty;
  assign o_ev_type = w_ev_data[23:22];
  assign o_ev_q    = w_ev_data[21:17];
  assign o_ev_val  = w_ev_data[16:0];

endmodule
