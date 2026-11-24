/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Message parameter capture in CLK-AXI. The core holds the message parameters
 *                (lengths, direction, watermarks, tail mode, DMA enable, beat counts) stable from
 *                the cycle in which it raises the level i_msg_act. The level crosses into CLK-AXI
 *                through a two-flop synchronizer cell (a direct connection with a common clock
 *                net); when the synchronized level rises the parameters are copied into registers
 *                of CLK-AXI, and one cycle later o_start pulses, so the users of the copy see the
 *                new values at the same time as the pulse. The parameters are not read at any
 *                other time, which makes the multi-bit copy safe: it is qualified by a
 *                synchronized control level and the source is quiet for at least the synchronizer
 *                latency before the copy.
 * Decisions    : DEC-019, DEC-029, DEC-032
 */
`timescale 1ns/1ps

module m_chacha_msg_cap #(
  // Parameter Description: 1 when the AXI clock and the core clock are the same net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_AXI_CORE = 32'd0
) (
  // AXI clock and reset
  input  wire         i_clk_axi,
  input  wire         i_rst_n_axi,

  // Message parameters from the core (quasi-static while i_msg_act is high)
  input  wire         i_msg_act,
  input  wire         i_dma_en,
  input  wire  [8:0]  i_wm_wr,
  input  wire  [8:0]  i_wm_rd,
  input  wire         i_tail_mode,
  input  wire  [16:0] i_beats_wr,
  input  wire  [16:0] i_beats_rd,
  input  wire  [15:0] i_aad_len,
  input  wire  [15:0] i_msg_len,
  input  wire         i_dir,

  // Captured parameters in CLK-AXI with the start pulse and the active level
  output logic        o_start,
  output logic        o_act,
  output logic        o_dma_en,
  output logic [8:0]  o_wm_wr,
  output logic [8:0]  o_wm_rd,
  output logic        o_tail_mode,
  output logic [16:0] o_beats_wr,
  output logic [16:0] o_beats_rd,
  output logic [15:0] o_aad_len,
  output logic [15:0] o_msg_len,
  output logic        o_dir
);

  // Internal signal declarations
  logic        w_act_s;
  logic        reg_act_d;
  logic        reg_start;
  logic        reg_dma_en;
  logic [8:0]  reg_wm_wr;
  logic [8:0]  reg_wm_rd;
  logic        reg_tail;
  logic [16:0] reg_beats_wr;
  logic [16:0] reg_beats_rd;
  logic [15:0] reg_aad_len;
  logic [15:0] reg_msg_len;
  logic        reg_dir;
  logic        w_start_raw;

  // Synchronization of the message-active level.
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_cdc
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_act (
      .i_clk_dst   (i_clk_axi),
      .i_rst_n_dst (i_rst_n_axi),
      .i_d         (i_msg_act),
      .o_q         (w_act_s)
    );
  end else begin : gen_direct
    assign w_act_s = i_msg_act;
  end

  // The raw start is the rising edge of the synchronized level.
  assign w_start_raw = w_act_s & ~reg_act_d;

  // Edge and start registers are control state (reset); the captured parameters are quasi-static
  // copies taken at the raw start and used only after the start pulse.
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_cap
    if (!i_rst_n_axi) begin
      reg_act_d    <= 1'b0;
      reg_start    <= 1'b0;
      reg_dma_en   <= 1'b0;
      reg_wm_wr    <= 9'd1;
      reg_wm_rd    <= 9'd1;
      reg_tail     <= 1'b0;
      reg_beats_wr <= 17'd0;
      reg_beats_rd <= 17'd0;
      reg_aad_len  <= 16'd0;
      reg_msg_len  <= 16'd0;
      reg_dir      <= 1'b0;
    end else begin
      reg_act_d <= w_act_s;
      reg_start <= w_start_raw;
      if (w_start_raw) begin
        reg_dma_en   <= i_dma_en;
        reg_wm_wr    <= i_wm_wr;
        reg_wm_rd    <= i_wm_rd;
        reg_tail     <= i_tail_mode;
        reg_beats_wr <= i_beats_wr;
        reg_beats_rd <= i_beats_rd;
        reg_aad_len  <= i_aad_len;
        reg_msg_len  <= i_msg_len;
        reg_dir      <= i_dir;
      end
    end
  end

  // Output mapping of the copies, the start pulse and the active level.
  assign o_start     = reg_start;
  assign o_act       = w_act_s;
  assign o_dma_en    = reg_dma_en;
  assign o_wm_wr     = reg_wm_wr;
  assign o_wm_rd     = reg_wm_rd;
  assign o_tail_mode = reg_tail;
  assign o_beats_wr  = reg_beats_wr;
  assign o_beats_rd  = reg_beats_rd;
  assign o_aad_len   = reg_aad_len;
  assign o_msg_len   = reg_msg_len;
  assign o_dir       = reg_dir;

endmodule
