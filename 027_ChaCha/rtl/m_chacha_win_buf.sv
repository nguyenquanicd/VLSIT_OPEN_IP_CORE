/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Window storage of the IP: the input buffer (written in CLK-AXI, read in CLK-
 *                CORE) and the output buffer (written in CLK-CORE, read in CLK-AXI). Both are
 *                library FIFOs: the asynchronous Gray-code FIFO m_vlsit_afifo_top when
 *                PARA_SYNC_AXI_CORE is 0 and the synchronous-clock FIFO m_vlsit_sfifo_top when it
 *                is 1. Each buffer has a flush machine on its write side that drives the software
 *                reset of the FIFO (DEC-027); the input buffer flush request crosses from CLK-
 *                CORE to CLK-AXI as a level handshake and its done pulse back through
 *                m_vlsit_event_sync. The hold gate (DEC-028) is a level of CLK-CORE synchronized
 *                into CLK-AXI: while it is low the read side of the output buffer reports an
 *                empty buffer, so held plaintext is invisible to the AXI read path. The threshold
 *                flags of the FIFOs are passed through for the DMA request logic.
 * Decisions    : DEC-026, DEC-027, DEC-028, DEC-029
 */
`timescale 1ns/1ps

module m_chacha_win_buf #(
  // Parameter Description: data width of one window beat.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  // Parameter Description: depth of the input buffer.
  // Parameter values: power of two from 4 to 4096; default is 16.
  // Parameter unit: beat
  parameter logic [31:0] PARA_FIFO_IN_DEPTH = 32'd16,
  // Parameter Description: depth of the output buffer.
  // Parameter values: power of two from 4 to 16384; default is 256.
  // Parameter unit: beat
  parameter logic [31:0] PARA_FIFO_OUT_DEPTH = 32'd256,
  // Parameter Description: 1 when the AXI clock and the core clock are the same net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_AXI_CORE = 32'd0,
  localparam logic [31:0] LPARA_IN_THR_W  = $clog2(PARA_FIFO_IN_DEPTH) + 32'd1,
  localparam logic [31:0] LPARA_OUT_THR_W = $clog2(PARA_FIFO_OUT_DEPTH) + 32'd1
) (
  // AXI clock and reset
  input  wire                        i_clk_axi,
  input  wire                        i_rst_n_axi,

  // Input buffer write port and its threshold flag (AXI side)
  input  wire                        i_in_wr_en,
  input  wire  [PARA_AXI_DW-1:0]     i_in_wr_data,
  output logic                       o_in_full,
  input  wire  [LPARA_IN_THR_W-1:0]  i_in_full_thr,
  output logic                       o_in_full_thr,

  // Output buffer read port and its threshold flag (AXI side, gated by the hold gate)
  input  wire                        i_out_rd_en,
  output logic [PARA_AXI_DW-1:0]     o_out_rd_data,
  output logic                       o_out_empty,
  input  wire  [LPARA_OUT_THR_W-1:0] i_out_empty_thr,
  output logic                       o_out_empty_thr,

  // Core clock and reset
  input  wire                        i_clk_core,
  input  wire                        i_rst_n_core,

  // Input buffer read port (core side)
  input  wire                        i_in_rd_en,
  output logic [PARA_AXI_DW-1:0]     o_in_rd_data,
  output logic                       o_in_empty,

  // Output buffer write port (core side)
  input  wire                        i_out_wr_en,
  input  wire  [PARA_AXI_DW-1:0]     i_out_wr_data,
  output logic                       o_out_full,

  // Flush requests and done pulses (core side) and the hold gate
  input  wire                        i_flush_in_req,
  input  wire                        i_flush_out_req,
  output logic                       o_flush_in_done,
  output logic                       o_flush_out_done,
  input  wire                        i_out_gate
);

  // Internal signal declarations
  logic w_in_sw_n;
  logic w_in_sw_busy;
  logic w_out_sw_n;
  logic w_out_sw_busy;
  logic w_gate_axi;
  logic w_out_empty_fifo;
  logic w_out_empty_thr_fifo;

  // Input buffer: written in CLK-AXI, read in CLK-CORE. The empty threshold flag and the
  // overflow and underflow flags are not used. The flush machine of the write side owns the
  // software reset.
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_in_async
    m_vlsit_afifo_top #(
      .PARA_AFIFO_DEPTH         (PARA_FIFO_IN_DEPTH),
      .PARA_AFIFO_DATA_W        (PARA_AXI_DW),
      .PARA_AFIFO_CELL_TYPE     (32'd2),
      .PARA_AFIFO_MEM_USE_MACRO (32'd0)
    ) u_fifo_in (
      .i_clk_wr      (i_clk_axi),
      .i_rst_n_wr    (i_rst_n_axi),
      .i_wr_en       (i_in_wr_en),
      .i_wr_data     (i_in_wr_data),
      .i_full_thr    (i_in_full_thr),
      .o_full        (o_in_full),
      .o_full_thr    (o_in_full_thr),
      .o_overflow    (),
      .i_rst_n_sw    (w_in_sw_n),
      .o_sw_rst_busy (w_in_sw_busy),
      .i_clk_rd      (i_clk_core),
      .i_rst_n_rd    (i_rst_n_core),
      .i_rd_en       (i_in_rd_en),
      .i_empty_thr   ({LPARA_IN_THR_W{1'b0}}),
      .o_rd_data     (o_in_rd_data),
      .o_empty       (o_in_empty),
      .o_empty_thr   (),
      .o_underflow   ()
    );
  end else begin : gen_in_sync
    m_vlsit_sfifo_top #(
      .PARA_SFIFO_DEPTH         (PARA_FIFO_IN_DEPTH),
      .PARA_SFIFO_DATA_W        (PARA_AXI_DW),
      .PARA_SFIFO_PTR_RETIME    (32'd0),
      .PARA_SFIFO_MEM_USE_MACRO (32'd0)
    ) u_fifo_in (
      .i_clk_wr      (i_clk_axi),
      .i_rst_n_wr    (i_rst_n_axi),
      .i_wr_en       (i_in_wr_en),
      .i_wr_data     (i_in_wr_data),
      .i_full_thr    (i_in_full_thr),
      .o_full        (o_in_full),
      .o_full_thr    (o_in_full_thr),
      .o_overflow    (),
      .i_rst_n_sw    (w_in_sw_n),
      .o_sw_rst_busy (w_in_sw_busy),
      .i_clk_rd      (i_clk_core),
      .i_rst_n_rd    (i_rst_n_core),
      .i_rd_en       (i_in_rd_en),
      .i_empty_thr   ({LPARA_IN_THR_W{1'b0}}),
      .o_rd_data     (o_in_rd_data),
      .o_empty       (o_in_empty),
      .o_empty_thr   (),
      .o_underflow   ()
    );
  end

  // Output buffer: written in CLK-CORE, read in CLK-AXI. The full threshold flag and the overflow
  // and underflow flags are not used.
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_out_async
    m_vlsit_afifo_top #(
      .PARA_AFIFO_DEPTH         (PARA_FIFO_OUT_DEPTH),
      .PARA_AFIFO_DATA_W        (PARA_AXI_DW),
      .PARA_AFIFO_CELL_TYPE     (32'd2),
      .PARA_AFIFO_MEM_USE_MACRO (32'd0)
    ) u_fifo_out (
      .i_clk_wr      (i_clk_core),
      .i_rst_n_wr    (i_rst_n_core),
      .i_wr_en       (i_out_wr_en),
      .i_wr_data     (i_out_wr_data),
      .i_full_thr    ({LPARA_OUT_THR_W{1'b0}}),
      .o_full        (o_out_full),
      .o_full_thr    (),
      .o_overflow    (),
      .i_rst_n_sw    (w_out_sw_n),
      .o_sw_rst_busy (w_out_sw_busy),
      .i_clk_rd      (i_clk_axi),
      .i_rst_n_rd    (i_rst_n_axi),
      .i_rd_en       (i_out_rd_en),
      .i_empty_thr   (i_out_empty_thr),
      .o_rd_data     (o_out_rd_data),
      .o_empty       (w_out_empty_fifo),
      .o_empty_thr   (w_out_empty_thr_fifo),
      .o_underflow   ()
    );
  end else begin : gen_out_sync
    m_vlsit_sfifo_top #(
      .PARA_SFIFO_DEPTH         (PARA_FIFO_OUT_DEPTH),
      .PARA_SFIFO_DATA_W        (PARA_AXI_DW),
      .PARA_SFIFO_PTR_RETIME    (32'd0),
      .PARA_SFIFO_MEM_USE_MACRO (32'd0)
    ) u_fifo_out (
      .i_clk_wr      (i_clk_core),
      .i_rst_n_wr    (i_rst_n_core),
      .i_wr_en       (i_out_wr_en),
      .i_wr_data     (i_out_wr_data),
      .i_full_thr    ({LPARA_OUT_THR_W{1'b0}}),
      .o_full        (o_out_full),
      .o_full_thr    (),
      .o_overflow    (),
      .i_rst_n_sw    (w_out_sw_n),
      .o_sw_rst_busy (w_out_sw_busy),
      .i_clk_rd      (i_clk_axi),
      .i_rst_n_rd    (i_rst_n_axi),
      .i_rd_en       (i_out_rd_en),
      .i_empty_thr   (i_out_empty_thr),
      .o_rd_data     (o_out_rd_data),
      .o_empty       (w_out_empty_fifo),
      .o_empty_thr   (w_out_empty_thr_fifo),
      .o_underflow   ()
    );
  end

  // Flush machine of the output buffer (write side, CLK-CORE).
  m_chacha_flush u_flush_out (
    .i_clk_wr      (i_clk_core),
    .i_rst_n_wr    (i_rst_n_core),
    .i_req         (i_flush_out_req),
    .o_done        (o_flush_out_done),
    .o_rst_n_sw    (w_out_sw_n),
    .i_swr_busy    (w_out_sw_busy)
  );

  // Flush of the input buffer: a four-phase level handshake from CLK-CORE to the flush machine
  // of the write side in CLK-AXI (DEC-027, DEC-033).
  m_chacha_flush_hs #(
    .PARA_SYNC_AXI_CORE (PARA_SYNC_AXI_CORE)
  ) u_flush_in (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (i_rst_n_core),
    .i_req        (i_flush_in_req),
    .o_done       (o_flush_in_done),
    .i_clk_axi    (i_clk_axi),
    .i_rst_n_axi  (i_rst_n_axi),
    .o_rst_n_sw   (w_in_sw_n),
    .i_swr_busy   (w_in_sw_busy)
  );

  // Crossing of the hold gate from CLK-CORE to CLK-AXI: a two-flop synchronizer cell, or a direct
  // connection with a common clock net.
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_cdc
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_gate (
      .i_clk_dst   (i_clk_axi),
      .i_rst_n_dst (i_rst_n_axi),
      .i_d         (i_out_gate),
      .o_q         (w_gate_axi)
    );
  end else begin : gen_direct
    assign w_gate_axi = i_out_gate;
  end

  // Hold gate on the read side of the output buffer: while the gate is low the buffer and its
  // threshold flag report empty, so no beat can be read.
  assign o_out_empty     = w_out_empty_fifo | ~w_gate_axi;
  assign o_out_empty_thr = w_out_empty_thr_fifo | ~w_gate_axi;

endmodule
