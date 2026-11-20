/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Transmit FIFO of all data lines. One library asynchronous Gray FIFO per line,
 *                written in the APB clock domain and read in the master clock domain. The words of
 *                one slot are popped from all lines at once, so the lines stay in lockstep. The
 *                library FIFO exposes no occupancy, so this module counts the accepted writes (APB
 *                domain) and the popped slots (master domain, sent as a Gray-coded count through a
 *                synchronizer): the level is the writes minus the pops times the lines. After a
 *                flush the write count is set to the synchronized pop count, so the level is 0. A
 *                flush pulse resets the pointers of all lines through the software reset of the
 *                library FIFO; o_flush_done pulses when the reset has finished. The write enable of
 *                the lines is one-hot.
 * Decisions    : DEC-002, DEC-008, DEC-014, DEC-015, ASM-015, REQ-FUNC-013, REQ-FUNC-030, MEM-001
 */
`timescale 1ns/1ps

module m_vlsit_i2s_txfifo #(
  // Parameter Description: number of data lines of the unit, one FIFO per line.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_LINES = 1,
  // Parameter Description: words of each line FIFO.
  // Parameter values: power of 2 from 2 to 256; default is 16.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_FIFO_DEPTH = 16,
  // Parameter Description: synchronizer stages of the pointer and count crossings.
  // Parameter values: 2 or 3; default is 2.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_SYNC_DEPTH = 2,
  localparam logic [31:0] LPARA_PTR_W = $clog2(PARA_I2S_FIFO_DEPTH) + 32'd1,
  localparam logic [31:0] LPARA_CNT_W = 32'd12,
  localparam logic [31:0] LPARA_WORD_W = 32'd32
) (
  // APB clock domain: write side
  input  wire                                    i_clk_apb,
  input  wire                                    i_rst_n_apb,
  input  wire  [PARA_I2S_LINES-1:0]              i_wr_en,
  input  wire  [LPARA_WORD_W-1:0]                i_wr_data,
  output logic [PARA_I2S_LINES-1:0]              o_full,
  output logic                                   o_overflow,
  input  wire                                    i_flush,
  output logic                                   o_flush_done,
  output logic [LPARA_CNT_W-1:0]                 o_level,

  // Master clock domain: read side
  input  wire                                    i_clk_mclk,
  input  wire                                    i_rst_n_mclk,
  input  wire  [PARA_I2S_LINES-1:0]              i_rd_en,
  input  wire                                    i_pop_slot,
  input  wire  [5:0]                             i_words_pf,
  output logic [PARA_I2S_LINES*LPARA_WORD_W-1:0] o_rd_data,
  output logic [PARA_I2S_LINES-1:0]              o_rd_empty,
  output logic                                   o_rd_ready
);

  // Internal signal declarations
  logic reg_rst_n_sw;
  logic [PARA_I2S_LINES-1:0] w_busy;
  logic w_busy_any;
  logic reg_busy_d;
  logic w_busy_fall;
  logic [PARA_I2S_LINES-1:0] w_ovf;
  logic [PARA_I2S_LINES-1:0] w_empty_thr;
  logic [LPARA_PTR_W-1:0] w_empty_thr_val;

  logic [LPARA_CNT_W-1:0] reg_wcnt;
  logic [LPARA_CNT_W-1:0] w_wcnt_nxt;
  logic w_wr_acc;

  logic [LPARA_CNT_W-1:0] reg_pcnt;
  logic [LPARA_CNT_W-1:0] w_pcnt_nxt;
  logic [LPARA_CNT_W-1:0] reg_pgray;
  logic [LPARA_CNT_W-1:0] w_pgray_nxt;
  logic [LPARA_CNT_W-1:0] w_pgray_s;
  logic [LPARA_CNT_W-1:0] w_pbin_s;
  logic [LPARA_CNT_W-1:0] w_pop_words;

  // Software reset of the line FIFOs: a registered active-low pulse, one cycle low per flush.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_rst_n_sw
    if (!i_rst_n_apb)
      reg_rst_n_sw <= 1'b1;
    else
      reg_rst_n_sw <= ~i_flush;
  end

  // Flush busy of all lines: high while any line FIFO is in its software reset. The done pulse is
  // the falling edge of the busy flag, so the write pointers are released when it pulses.
  assign w_busy_any = |w_busy;
  assign w_busy_fall = reg_busy_d & ~w_busy_any;

  // Busy delay flop for the falling-edge detector, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_busy_d
    if (!i_rst_n_apb)
      reg_busy_d <= 1'b0;
    else
      reg_busy_d <= w_busy_any;
  end

  // Accepted write: a line is written and it is not full (the library full flag includes the
  // software reset block). The write enable is one-hot.
  assign w_wr_acc = |(i_wr_en & ~o_full);

  // Gray to binary conversion of the synchronized pop count: bit i is the XOR of Gray bits i up.
  always_comb begin : p_com_pbin_s
    w_pbin_s = '0;
    for (int idx = 0; idx < LPARA_CNT_W; idx++) begin
      w_pbin_s[idx] = ^(w_pgray_s >> idx);
    end
  end

  // Words popped so far: the pop count times the number of lines, truncated to the count width.
  assign w_pop_words = LPARA_CNT_W'(PARA_I2S_LINES * w_pbin_s);

  // Next write count: counts accepted writes; after a flush it is set to the popped words, so the
  // level is 0 (the pop count is stable when the flush has finished).
  always_comb begin : p_com_wcnt_nxt
    w_wcnt_nxt = reg_wcnt;
    if (w_busy_fall)
      w_wcnt_nxt = w_pop_words;
    else if (w_wr_acc)
      w_wcnt_nxt = reg_wcnt + 1'b1;
  end

  // Write count flop: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_wcnt
    if (!i_rst_n_apb)
      reg_wcnt <= '0;
    else
      reg_wcnt <= w_wcnt_nxt;
  end

  // Level in words: writes minus popped words; 0 while a flush is running.
  assign o_level = w_busy_any ? '0 : (reg_wcnt - w_pop_words);

  // Pop count and its Gray code in the master domain: one count per popped slot (all lines).
  assign w_pcnt_nxt  = i_pop_slot ? (reg_pcnt + 1'b1) : reg_pcnt;
  assign w_pgray_nxt = w_pcnt_nxt ^ (w_pcnt_nxt >> 1);

  // Pop count flop: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_pcnt
    if (!i_rst_n_mclk)
      reg_pcnt <= '0;
    else
      reg_pcnt <= w_pcnt_nxt;
  end

  // Gray pop count flop: launch register of the count crossing, changes one bit per pop.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_pgray
    if (!i_rst_n_mclk)
      reg_pgray <= '0;
    else
      reg_pgray <= w_pgray_nxt;
  end

  // Crossing of the Gray pop count to the APB domain, reset to the Gray value 0.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_CNT_W),
    .PARA_AFIFO_SYNC_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH)
  ) u_sync_pgray (
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_data      (reg_pgray),
    .o_data      (w_pgray_s)
  );

  // Threshold of the whole-frame check: occupancy of a line at or below words_pf - 1 means that a
  // whole frame is not there. A frame larger than the FIFO never becomes ready.
  assign w_empty_thr_val = ({26'd0, i_words_pf} > PARA_I2S_FIFO_DEPTH) ? {LPARA_PTR_W{1'b1}} :
                           (i_words_pf == 6'd0) ? '0 : LPARA_PTR_W'(i_words_pf - 6'd1);

  // Ready: no frame needed, or every line holds at least a whole frame.
  assign o_rd_ready = (i_words_pf == 6'd0) | ~(|w_empty_thr);

  // Output mapping of the overflow pulse: any line dropped a word.
  assign o_overflow = |w_ovf;

  // One library FIFO per data line.
  for (genvar gen_line_idx = 0; gen_line_idx < PARA_I2S_LINES; gen_line_idx++) begin : gen_line
    m_vlsit_afifo_top #(
      .PARA_AFIFO_DEPTH        (PARA_I2S_FIFO_DEPTH),
      .PARA_AFIFO_DATA_W       (LPARA_WORD_W),
      .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH),
      .PARA_AFIFO_MEM_USE_MACRO(32'd0)
    ) u_afifo (
      .i_clk_wr      (i_clk_apb),
      .i_rst_n_wr    (i_rst_n_apb),
      .i_wr_en       (i_wr_en[gen_line_idx]),
      .i_wr_data     (i_wr_data),
      .i_full_thr    ({LPARA_PTR_W{1'b0}}),
      .o_full        (o_full[gen_line_idx]),
      .o_full_thr    (),
      .o_overflow    (w_ovf[gen_line_idx]),
      .i_rst_n_sw    (reg_rst_n_sw),
      .o_sw_rst_busy (w_busy[gen_line_idx]),
      .i_clk_rd      (i_clk_mclk),
      .i_rst_n_rd    (i_rst_n_mclk),
      .i_rd_en       (i_rd_en[gen_line_idx]),
      .i_empty_thr   (w_empty_thr_val),
      .o_rd_data     (o_rd_data[gen_line_idx*LPARA_WORD_W +: LPARA_WORD_W]),
      .o_empty       (o_rd_empty[gen_line_idx]),
      .o_empty_thr   (w_empty_thr[gen_line_idx]),
      .o_underflow   ()
    );
  end

  // Flush done pulse: the busy flag fell, so the FIFOs are empty and writes are accepted again.
  assign o_flush_done = w_busy_fall;

endmodule
