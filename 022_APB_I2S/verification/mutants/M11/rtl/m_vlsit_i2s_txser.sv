/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Transmit serializer, master clock domain. At the launch tick of the first bit of
 *                an enabled slot it takes one word per line from the FIFO (all lines together),
 *                aligns it, and shifts it out MSB first, one bit per launch tick. With packing the
 *                high half of the same word is used for the next enabled slot without a new pop.
 *                The bits after the data width, masked slots, and the time without a frame are
 *                zeros; a masked slot releases the data lines when the tri-state option is on. An
 *                empty FIFO at a slot start sends zeros for the slot and raises the underrun pulse,
 *                and no word is taken. The serial outputs and the output enable are flops that
 *                change at the launch tick.
 * Decisions    : DEC-002, ASM-020, ASM-021, ASM-022, REQ-FUNC-003, REQ-FUNC-009..REQ-FUNC-014,
 *                INV-004, OP-003, OP-007
 */
`timescale 1ns/1ps

module m_vlsit_i2s_txser #(
  // Parameter Description: number of data lines of the unit.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_LINES = 1,
  // Parameter Description: 16-bit packing built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_PACK_EN = 1,
  // Parameter Description: release of masked slots (tri-state) built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_TRI_EN = 1,
  localparam logic [31:0] LPARA_WORD_W = 32'd32,
  localparam logic [31:0] LPARA_HALF_W = 32'd16,
  localparam logic [31:0] LPARA_WORD_6 = 32'd32,
  localparam logic [31:0] LPARA_HALF_6 = 32'd16
) (
  // Clock and reset
  input  wire                                    i_clk_mclk,
  input  wire                                    i_rst_n_mclk,

  // Launch description and configuration from the frame engine
  input  wire                                    i_tick_l,
  input  wire                                    i_nx_active,
  input  wire                                    i_nx_slot_start,
  input  wire                                    i_nx_slot_en,
  input  wire                                    i_nx_bit_vld,
  input  wire                                    i_nx_pack_hi,
  input  wire                                    i_on,
  input  wire  [5:0]                             i_data_w,
  input  wire                                    i_align,
  input  wire                                    i_pack,
  input  wire                                    i_tri,

  // Transmit FIFO read side
  input  wire  [PARA_I2S_LINES*LPARA_WORD_W-1:0] i_rd_data,
  input  wire  [PARA_I2S_LINES-1:0]              i_rd_empty,
  output logic [PARA_I2S_LINES-1:0]              o_rd_en,
  output logic                                   o_pop_slot,

  // Serial outputs, output enable and the underrun pulse
  output logic [PARA_I2S_LINES-1:0]              o_sdo,
  output logic                                   o_sdo_oe,
  output logic                                   o_und,
  output logic                                   o_und_q
);

  // Internal signal declarations
  logic [PARA_I2S_LINES-1:0] reg_sdo;
  logic [PARA_I2S_LINES-1:0] w_sdo_nxt;
  logic reg_oe;
  logic reg_und_q;
  logic w_oe_nxt;
  logic w_pk;
  logic w_hi;
  logic w_need_word;
  logic w_und;
  logic w_pop;
  logic w_slot_ok;
  logic [5:0] w_shift_full;
  logic [5:0] w_shift_half;

  // Packing is active when it is built in and selected; its second half uses the held word and no
  // new word is taken.
  assign w_pk = (PARA_I2S_PACK_EN != 32'd0) & i_pack;
  assign w_hi = w_pk & i_nx_pack_hi;

  // A word is needed at the first bit of an enabled slot that carries data, unless it is the
  // second half of a packed word. An empty line, even a single one, is an underrun and the slot
  // sends zeros; no line is popped, so the lines stay in lockstep.
  assign w_need_word = i_tick_l & i_nx_active & i_nx_slot_start & i_nx_slot_en & ~w_hi;
  assign w_und       = w_need_word & (|i_rd_empty);
  assign w_pop       = w_need_word & ~(|i_rd_empty);
  assign w_slot_ok   = ~(w_need_word & (|i_rd_empty));

  // Output mapping of the underrun, pop and read enables.
  assign o_und      = w_und;
  assign o_pop_slot = w_pop;
  assign o_rd_en    = {PARA_I2S_LINES{w_pop}};

  // Left shift that puts the first data bit at bit 31: a right aligned sample is moved up by the
  // unused bits; with packing the sample sits in a 16-bit half.
  assign w_shift_full = LPARA_WORD_6[5:0] - i_data_w;
  assign w_shift_half = (i_data_w > LPARA_HALF_6[5:0]) ? 6'd0 : (LPARA_HALF_6[5:0] - i_data_w);

  // Output enable: high while the unit is on, low in a masked slot when tri-state is selected.
  assign w_oe_nxt = i_on & ~((PARA_I2S_TRI_EN != 32'd0) & i_tri & i_nx_active & ~i_nx_slot_en);

  // One lane per data line: word source, aligned load value, shift register and next bit.
  for (genvar gen_line_idx = 0; gen_line_idx < PARA_I2S_LINES; gen_line_idx++) begin : gen_line
    logic [LPARA_WORD_W-1:0] reg_sh;
    logic [LPARA_WORD_W-1:0] reg_word;
    logic [LPARA_WORD_W-1:0] w_src;
    logic [LPARA_HALF_W-1:0] w_half;
    logic [LPARA_WORD_W-1:0] w_ld;
    logic [LPARA_WORD_W-1:0] w_cur;

    // Word source: the FIFO head, or the held word for the second half of a packed word.
    assign w_src  = w_hi ? reg_word : i_rd_data[gen_line_idx*LPARA_WORD_W +: LPARA_WORD_W];
    assign w_half = i_nx_pack_hi ? w_src[LPARA_HALF_W-1:0] : w_src[LPARA_WORD_W-1 -: LPARA_HALF_W];

    // Aligned load value: the first data bit at bit 31.
    assign w_ld = w_pk ? (i_align ? {w_half, 16'd0} : ({w_half, 16'd0} << w_shift_half))
                       : (i_align ? w_src : (w_src << w_shift_full));

    // Current word: loaded at the first bit of a slot, the shift register otherwise.
    assign w_cur = i_nx_slot_start ? w_ld : reg_sh;

    // Next serial bit: zero after the data width, in masked slots, in an underrun slot and when
    // no frame runs.
    assign w_sdo_nxt[gen_line_idx] = i_nx_active & i_nx_slot_en & i_nx_bit_vld & w_slot_ok &
                                     w_cur[LPARA_WORD_W-1];

    // Shift register and held word: payload state without reset, used only after a slot start
    // has loaded it.
    always_ff @(posedge i_clk_mclk) begin : p_ff_shift
      if (i_tick_l)
        reg_sh <= w_cur << 1;
      if (w_pop)
        reg_word <= i_rd_data[gen_line_idx*LPARA_WORD_W +: LPARA_WORD_W];
    end
  end

  // Serial output and enable flops: control outputs, asynchronously reset to 0. They change at the
  // launch tick and are cleared while the unit is off.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_sdo
    if (!i_rst_n_mclk) begin
      reg_sdo <= '0;
      reg_oe  <= 1'b0;
    end else if (!i_on) begin
      reg_sdo <= '0;
      reg_oe  <= 1'b0;
    end else if (i_tick_l) begin
      reg_sdo <= w_sdo_nxt;
      reg_oe  <= w_oe_nxt;
    end
  end

  // Registered underrun pulse for the event crossing: launched from a flop (CDC-004).
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_und_q
    if (!i_rst_n_mclk)
      reg_und_q <= 1'b0;
    else
      reg_und_q <= w_und;
  end

  // Output mapping.
  assign o_und_q  = reg_und_q;
  assign o_sdo    = reg_sdo;
  assign o_sdo_oe = reg_oe;

endmodule
