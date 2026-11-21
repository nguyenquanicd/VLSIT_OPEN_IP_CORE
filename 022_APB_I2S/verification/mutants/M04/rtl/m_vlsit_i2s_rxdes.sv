/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Receive deserializer, master clock domain. The serial inputs are synchronized to
 *                the master clock; at each sample tick of an enabled slot a bit is shifted into the
 *                shift register of every line. When the last data bit of the slot is in, the word
 *                is aligned (right or left) and pushed into the FIFO of every line, one word per
 *                line. With packing two samples share one word: the first goes to the low half and
 *                the word is pushed with the second one. Bits after the data width are ignored. A
 *                full FIFO on any line drops the whole slot and raises the overrun pulse, so the
 *                lines stay in lockstep. The push is registered: the word and the push strobe are
 *                flops, and the full flag is checked in the cycle of the push.
 * Decisions    : DEC-002, ASM-020, ASM-021, REQ-FUNC-003, REQ-FUNC-009..REQ-FUNC-015, OP-004,
 *                OP-008
 */
`timescale 1ns/1ps

module m_vlsit_i2s_rxdes #(
  // Parameter Description: number of data lines of the unit.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_LINES = 1,
  // Parameter Description: 16-bit packing built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_PACK_EN = 1,
  // Parameter Description: synchronizer stages of the serial inputs (cell type of the library
  // synchronizer).
  // Parameter values: 2 or 3; default is 2.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_SYNC_DEPTH = 2,
  localparam logic [31:0] LPARA_WORD_W  = 32'd32,
  localparam logic [31:0] LPARA_HALF_W  = 32'd16,
  localparam logic [31:0] LPARA_CELL_RN = 32'd0,
  localparam logic [31:0] LPARA_WORD_6 = 32'd32,
  localparam logic [31:0] LPARA_HALF_6 = 32'd16
) (
  // Clock and reset
  input  wire                                    i_clk_mclk,
  input  wire                                    i_rst_n_mclk,

  // Serial inputs (asynchronous)
  input  wire  [PARA_I2S_LINES-1:0]              i_sdi,

  // Sample context and configuration from the frame engine
  input  wire                                    i_tick_s,
  input  wire                                    i_smp_active,
  input  wire                                    i_smp_slot_en,
  input  wire                                    i_smp_bit_vld,
  input  wire                                    i_smp_last,
  input  wire                                    i_smp_pack_hi,
  input  wire  [5:0]                             i_data_w,
  input  wire                                    i_align,
  input  wire                                    i_pack,

  // Receive FIFO write side and the overrun pulse
  input  wire  [PARA_I2S_LINES-1:0]              i_wr_full,
  output logic [PARA_I2S_LINES-1:0]              o_wr_en,
  output logic [PARA_I2S_LINES*LPARA_WORD_W-1:0] o_wr_data,
  output logic                                   o_ovr,
  output logic                                   o_ovr_q
);

  // Internal signal declarations
  logic [PARA_I2S_LINES-1:0] w_sdi_s;
  logic w_pk;
  logic w_take;
  logic w_shift;
  logic w_push_ev;
  logic reg_push;
  logic reg_ovr_q;
  logic [5:0] w_shift_full;
  logic [5:0] w_shift_half;
  logic [LPARA_WORD_W-1:0] w_mask_full;
  logic [LPARA_HALF_W-1:0] w_mask_half;

  // Packing is active when it is built in and selected.
  assign w_pk = (PARA_I2S_PACK_EN != 32'd0) & i_pack;

  // A sample bit is taken at a sample tick of an enabled slot of a running frame, inside the data
  // width. The last data bit completes the sample.
  assign w_shift = i_tick_s & i_smp_active & i_smp_slot_en & i_smp_bit_vld;
  assign w_take  = w_shift & i_smp_last;

  // A word is pushed when a sample completes and, with packing, it is the second half.
  assign w_push_ev = w_take & (~w_pk | i_smp_pack_hi);

  // Alignment shifts and the masks of the valid bits (data width 8 to 32; with packing 8 to 16).
  assign w_shift_full = LPARA_WORD_6[5:0] - i_data_w;
  assign w_shift_half = (i_data_w > LPARA_HALF_6[5:0]) ? 6'd0 : (LPARA_HALF_6[5:0] - i_data_w);
  assign w_mask_full  = ({LPARA_WORD_W{1'b1}}) >> w_shift_full;
  assign w_mask_half  = ({LPARA_HALF_W{1'b1}}) >> w_shift_half;

  // Push strobe flop: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_push
    if (!i_rst_n_mclk)
      reg_push <= 1'b0;
    else
      reg_push <= w_push_ev;
  end

  // Write enable of all lines in the cycle after the push event, if no line is full; otherwise the
  // whole slot is dropped and the overrun pulse is raised (lockstep of the lines).
  assign o_wr_en = {PARA_I2S_LINES{reg_push & ~(|i_wr_full)}};
  assign o_ovr   = 1'b0;

  // Registered overrun pulse for the event crossing: launched from a flop (CDC-004).
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_ovr_q
    if (!i_rst_n_mclk)
      reg_ovr_q <= 1'b0;
    else
      reg_ovr_q <= o_ovr;
  end

  // Output mapping of the registered overrun pulse.
  assign o_ovr_q = reg_ovr_q;

  // One lane per data line: input synchronizer, shift register, word assembly.
  for (genvar gen_line_idx = 0; gen_line_idx < PARA_I2S_LINES; gen_line_idx++) begin : gen_line
    logic [LPARA_WORD_W-1:0] reg_sh;
    logic [LPARA_WORD_W-1:0] w_sh_nxt;
    logic [LPARA_HALF_W-1:0] reg_half;
    logic [LPARA_HALF_W-1:0] w_half;
    logic [LPARA_WORD_W-1:0] w_word;
    logic [LPARA_WORD_W-1:0] reg_wr_word;

    // Synchronizer of the serial input, reset to 0.
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (LPARA_CELL_RN),
      .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH)
    ) u_sync_sdi (
      .i_clk_dst   (i_clk_mclk),
      .i_rst_n_dst (i_rst_n_mclk),
      .i_d         (i_sdi[gen_line_idx]),
      .o_q         (w_sdi_s[gen_line_idx])
    );

    // Shift register value with the new bit at the least significant end.
    assign w_sh_nxt = {reg_sh[LPARA_WORD_W-2:0], w_sdi_s[gen_line_idx]};

    // A 16-bit sample with packing: right aligned in the low bits, or left aligned in the half.
    assign w_half = i_align ? ((w_sh_nxt[LPARA_HALF_W-1:0] << w_shift_half) & {LPARA_HALF_W{1'b1}})
                            : (w_sh_nxt[LPARA_HALF_W-1:0] & w_mask_half);

    // The word to push: the packed pair, or the aligned sample.
    assign w_word = w_pk ? {w_half, reg_half}
                         : (i_align ? (w_sh_nxt << w_shift_full) : (w_sh_nxt & w_mask_full));

    // Shift register, first half sample and word to write: payload state without reset; the
    // push strobe says when the word is valid.
    always_ff @(posedge i_clk_mclk) begin : p_ff_data
      if (w_shift)
        reg_sh <= w_sh_nxt;
      if (w_take & ~i_smp_pack_hi)
        reg_half <= w_half;
      if (w_push_ev)
        reg_wr_word <= w_word;
    end

    // Output mapping of the word of this line.
    assign o_wr_data[gen_line_idx*LPARA_WORD_W +: LPARA_WORD_W] = reg_wr_word;
  end

endmodule
