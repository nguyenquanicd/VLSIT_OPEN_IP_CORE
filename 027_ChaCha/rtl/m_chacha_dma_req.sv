/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : DMA request logic in CLK-AXI (section 6.3). It drives the write channel (the
 *                engine needs input data) and the read channel (finished data waits in the output
 *                buffer) with two instances of m_chacha_dma_ch, from the message parameters
 *                captured by m_chacha_msg_cap. With PARA_DMA_EN = 0 or dma_en = 0 both request
 *                outputs stay low. The polling status flags show room for a write watermark burst
 *                and a readable read watermark burst, or the last shorter burst of a finished
 *                message.
 * Decisions    : DEC-010, DEC-013, DEC-019, DEC-029, DEC-032
 */
`timescale 1ns/1ps

module m_chacha_dma_req #(
  // Parameter Description: 1 when the DMA request pairs exist, 0 when they are tied inactive.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_DMA_EN = 32'd1,
  // Parameter Description: depth of the input buffer in beats.
  // Parameter values: power of two from 4 to 4096; default is 16.
  // Parameter unit: beat
  parameter logic [31:0] PARA_FIFO_IN_DEPTH = 32'd16,
  // Parameter Description: depth of the output buffer in beats.
  // Parameter values: power of two from 4 to 16384; default is 256.
  // Parameter unit: beat
  parameter logic [31:0] PARA_FIFO_OUT_DEPTH = 32'd256,
  localparam logic [31:0] LPARA_IN_THR_W  = $clog2(PARA_FIFO_IN_DEPTH) + 32'd1,
  localparam logic [31:0] LPARA_OUT_THR_W = $clog2(PARA_FIFO_OUT_DEPTH) + 32'd1
) (
  // AXI clock and reset
  input  wire                        i_clk_axi,
  input  wire                        i_rst_n_axi,

  // Captured message parameters (m_chacha_msg_cap): start pulse, active level and values
  input  wire                        i_start,
  input  wire                        i_act,
  input  wire                        i_dma_en,
  input  wire  [8:0]                 i_wm_wr,
  input  wire  [8:0]                 i_wm_rd,
  input  wire                        i_tail_mode,
  input  wire  [16:0]                i_beats_wr,
  input  wire  [16:0]                i_beats_rd,

  // Input buffer threshold register and flag (write channel)
  output logic [LPARA_IN_THR_W-1:0]  o_in_full_thr,
  input  wire                        i_in_full_thr_flag,

  // Output buffer threshold register, threshold flag and empty flag (read channel)
  output logic [LPARA_OUT_THR_W-1:0] o_out_empty_thr,
  input  wire                        i_out_empty_thr_flag,
  input  wire                        i_out_empty,

  // DMA request and acknowledge pairs
  output logic                       o_dma_req_wr,
  input  wire                        i_dma_ack_wr,
  output logic                       o_dma_req_rd,
  input  wire                        i_dma_ack_rd,

  // Polling status in CLK-AXI
  output logic                       o_in_rdy,
  output logic                       o_out_rdy
);

  // Internal signal declarations
  logic w_en_wr;
  logic w_en_rd;
  logic w_busy_wr;
  logic w_busy_rd;
  logic reg_in_rdy;
  logic reg_out_rdy;

  // Channel enables: the write channel runs while the message is active; the read channel runs
  // until its beats are moved. Both need the build option and the dma_en bit of the message.
  assign w_en_wr = (PARA_DMA_EN == 32'd1) & i_dma_en & i_act;
  assign w_en_rd = (PARA_DMA_EN == 32'd1) & i_dma_en;

  // Write channel: the engine needs input data; the flag is o_full_thr of the input buffer.
  m_chacha_dma_ch #(
    .PARA_DIR   (32'd0),
    .PARA_DEPTH (PARA_FIFO_IN_DEPTH)
  ) u_ch_wr (
    .i_clk_axi     (i_clk_axi),
    .i_rst_n_axi   (i_rst_n_axi),
    .i_start       (i_start),
    .i_total_beats (i_beats_wr),
    .i_en          (w_en_wr),
    .i_wm          (i_wm_wr),
    .i_tail_mode   (i_tail_mode),
    .o_thr         (o_in_full_thr),
    .i_flag        (i_in_full_thr_flag),
    .o_req         (o_dma_req_wr),
    .i_ack         (i_dma_ack_wr),
    .o_busy        (w_busy_wr)
  );

  // Read channel: finished data waits in the output buffer; the flag is o_empty_thr.
  m_chacha_dma_ch #(
    .PARA_DIR   (32'd1),
    .PARA_DEPTH (PARA_FIFO_OUT_DEPTH)
  ) u_ch_rd (
    .i_clk_axi     (i_clk_axi),
    .i_rst_n_axi   (i_rst_n_axi),
    .i_start       (i_start),
    .i_total_beats (i_beats_rd),
    .i_en          (w_en_rd),
    .i_wm          (i_wm_rd),
    .i_tail_mode   (i_tail_mode),
    .o_thr         (o_out_empty_thr),
    .i_flag        (i_out_empty_thr_flag),
    .o_req         (o_dma_req_rd),
    .i_ack         (i_dma_ack_rd),
    .o_busy        (w_busy_rd)
  );

  // Polling status: room for a write watermark burst while the write channel is not working; a
  // readable read watermark burst, or the rest of a finished message.
  // The status levels are registered because they cross into CLK-CORE (rule CLK-01).
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_rdy
    if (!i_rst_n_axi) begin
      reg_in_rdy  <= 1'b0;
      reg_out_rdy <= 1'b0;
    end else begin
      reg_in_rdy  <= ~i_in_full_thr_flag & ~w_busy_wr;
      reg_out_rdy <= (~i_out_empty_thr_flag & ~w_busy_rd) | (~i_act & ~i_out_empty);
    end
  end
  assign o_in_rdy  = reg_in_rdy;
  assign o_out_rdy = reg_out_rdy;

endmodule
