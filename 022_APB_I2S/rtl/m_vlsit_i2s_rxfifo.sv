/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Receive FIFO of all data lines. One library asynchronous Gray FIFO per line,
 *                written in the master clock domain (one word per line at each enabled slot) and
 *                read in the APB clock domain (one word per register read, in line order). The
 *                library FIFO exposes no occupancy, so this module counts the pushed slots (master
 *                domain, sent as a Gray-coded count through a synchronizer) and the popped words
 *                (APB domain): the level is the pushed words minus the popped words. After a flush
 *                the pop count is set to the synchronized push count, so the level is 0. A flush
 *                pulse of the master domain resets the pointers of all lines through the software
 *                reset of the library FIFO; o_flush_done pulses in the APB domain through an event
 *                synchronizer when the reset has finished. The read enable is one-hot, and the
 *                lines are written together, so the lines stay in lockstep.
 * Decisions    : DEC-002, DEC-008, DEC-014, DEC-015, ASM-015, REQ-FUNC-013, REQ-FUNC-030, MEM-002
 */
`timescale 1ns/1ps

module m_vlsit_i2s_rxfifo #(
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
  localparam logic [31:0] LPARA_WORD_W = 32'd32,
  localparam logic [31:0] LPARA_SYNC_TYPE = 32'd2
) (
  // Master clock domain: write side
  input  wire                                    i_clk_mclk,
  input  wire                                    i_rst_n_mclk,
  input  wire  [PARA_I2S_LINES-1:0]              i_wr_en,
  input  wire  [PARA_I2S_LINES*LPARA_WORD_W-1:0] i_wr_data,
  input  wire                                    i_flush,
  input  wire  [5:0]                             i_words_pf,
  output logic [PARA_I2S_LINES-1:0]              o_wr_full,
  output logic                                   o_wr_room,

  // APB clock domain: read side
  input  wire                                    i_clk_apb,
  input  wire                                    i_rst_n_apb,
  input  wire  [PARA_I2S_LINES-1:0]              i_rd_en,
  output logic [PARA_I2S_LINES*LPARA_WORD_W-1:0] o_rd_data,
  output logic [PARA_I2S_LINES-1:0]              o_rd_empty,
  output logic                                   o_flush_done,
  output logic [LPARA_CNT_W-1:0]                 o_level
);

  // Internal signal declarations
  logic reg_rst_n_sw;
  logic [PARA_I2S_LINES-1:0] w_busy;
  logic w_busy_any;
  logic reg_busy_d;
  logic w_busy_fall;
  logic [PARA_I2S_LINES-1:0] w_full_thr;
  logic [LPARA_PTR_W-1:0] w_full_thr_val;

  logic [LPARA_CNT_W-1:0] reg_pcnt;
  logic [LPARA_CNT_W-1:0] w_pcnt_nxt;
  logic [LPARA_CNT_W-1:0] reg_pgray;
  logic [LPARA_CNT_W-1:0] w_pgray_nxt;
  logic [LPARA_CNT_W-1:0] w_pgray_s;
  logic [LPARA_CNT_W-1:0] w_pbin_s;
  logic [LPARA_CNT_W-1:0] w_push_words;
  logic w_push_acc;

  logic [LPARA_CNT_W-1:0] reg_rcnt;
  logic [LPARA_CNT_W-1:0] w_rcnt_nxt;
  logic w_rd_acc;
  logic w_flush_done_apb;
  logic reg_flush_done_d;

  // Software reset of the line FIFOs: a registered active-low pulse, one cycle low per flush.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_rst_n_sw
    if (!i_rst_n_mclk)
      reg_rst_n_sw <= 1'b1;
    else
      reg_rst_n_sw <= ~i_flush;
  end

  // Flush busy of all lines (master domain) and its falling edge: the write pointers are
  // released when the busy flag falls.
  assign w_busy_any  = |w_busy;
  assign w_busy_fall = reg_busy_d & ~w_busy_any;

  // Busy delay flop for the falling-edge detector, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_busy_d
    if (!i_rst_n_mclk)
      reg_busy_d <= 1'b0;
    else
      reg_busy_d <= w_busy_any;
  end

  // Accepted slot push: every line is written and none is full (the deserializer checks this).
  assign w_push_acc = &(i_wr_en & ~o_wr_full);

  // Push count and its Gray code (master domain): one count per pushed slot of all lines.
  assign w_pcnt_nxt  = w_push_acc ? (reg_pcnt + 1'b1) : reg_pcnt;
  assign w_pgray_nxt = w_pcnt_nxt ^ (w_pcnt_nxt >> 1);

  // Push count flop: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_pcnt
    if (!i_rst_n_mclk)
      reg_pcnt <= '0;
    else
      reg_pcnt <= w_pcnt_nxt;
  end

  // Gray push count flop: launch register of the count crossing, changes one bit per push.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_pgray
    if (!i_rst_n_mclk)
      reg_pgray <= '0;
    else
      reg_pgray <= w_pgray_nxt;
  end

  // Crossing of the Gray push count to the APB domain, reset to the Gray value 0.
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

  // Gray to binary conversion of the synchronized push count: bit i is the XOR of Gray bits i up.
  always_comb begin : p_com_pbin_s
    w_pbin_s = '0;
    for (int idx = 0; idx < LPARA_CNT_W; idx++) begin
      w_pbin_s[idx] = ^(w_pgray_s >> idx);
    end
  end

  // Words pushed so far: the push count times the number of lines, truncated to the count width.
  assign w_push_words = LPARA_CNT_W'(PARA_I2S_LINES * w_pbin_s);

  // Accepted read: a line is read and it is not empty (the library empty flag includes the
  // software reset block). The read enable is one-hot.
  assign w_rd_acc = |(i_rd_en & ~o_rd_empty);

  // Next pop count: counts accepted reads; one APB cycle after the flush-done pulse it is set to
  // the pushed words, so the level is 0 (the push count is stable by then).
  always_comb begin : p_com_rcnt_nxt
    w_rcnt_nxt = reg_rcnt;
    if (reg_flush_done_d)
      w_rcnt_nxt = w_push_words;
    else if (w_rd_acc)
      w_rcnt_nxt = reg_rcnt + 1'b1;
  end

  // Pop count flop: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_rcnt
    if (!i_rst_n_apb)
      reg_rcnt <= '0;
    else
      reg_rcnt <= w_rcnt_nxt;
  end

  // Delayed flush-done pulse that triggers the re-baseline, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_flush_done_d
    if (!i_rst_n_apb)
      reg_flush_done_d <= 1'b0;
    else
      reg_flush_done_d <= w_flush_done_apb;
  end

  // Level in words: pushed words minus popped words.
  assign o_level = w_push_words - reg_rcnt;

  // Flush done pulse in the APB domain: it is sent one cycle later than the internal pulse so the
  // register logic sees the empty FIFO after the count is rebased.
  assign o_flush_done = reg_flush_done_d;

  // Event crossing of the flush-done pulse from the master domain to the APB domain.
  m_vlsit_event_sync #(
    .PARA_EVENT_SYNC_W         (32'd1),
    .PARA_EVENT_SYNC_CELL_TYPE (LPARA_SYNC_TYPE)
  ) u_event_done (
    .i_clk_src   (i_clk_mclk),
    .i_rst_n_src (i_rst_n_mclk),
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_event_src (w_busy_fall),
    .o_event_dst (w_flush_done_apb)
  );

  // Threshold of the room check: the occupancy of a line at or above depth - words_pf + 1 means
  // that a whole frame does not fit. A frame larger than the FIFO never has room.
  assign w_full_thr_val = ({26'd0, i_words_pf} > PARA_I2S_FIFO_DEPTH) ? '0 :
                          LPARA_PTR_W'(PARA_I2S_FIFO_DEPTH - {26'd0, i_words_pf} + 32'd1);

  // Room: no frame needed, or every line has room for a whole frame.
  assign o_wr_room = (i_words_pf == 6'd0) | ~(|w_full_thr);

  // One library FIFO per data line.
  for (genvar gen_line_idx = 0; gen_line_idx < PARA_I2S_LINES; gen_line_idx++) begin : gen_line
    m_vlsit_afifo_top #(
      .PARA_AFIFO_DEPTH        (PARA_I2S_FIFO_DEPTH),
      .PARA_AFIFO_DATA_W       (LPARA_WORD_W),
      .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH),
      .PARA_AFIFO_MEM_USE_MACRO(32'd0)
    ) u_afifo (
      .i_clk_wr      (i_clk_mclk),
      .i_rst_n_wr    (i_rst_n_mclk),
      .i_wr_en       (i_wr_en[gen_line_idx]),
      .i_wr_data     (i_wr_data[gen_line_idx*LPARA_WORD_W +: LPARA_WORD_W]),
      .i_full_thr    (w_full_thr_val),
      .o_full        (o_wr_full[gen_line_idx]),
      .o_full_thr    (w_full_thr[gen_line_idx]),
      .o_overflow    (),
      .i_rst_n_sw    (reg_rst_n_sw),
      .o_sw_rst_busy (w_busy[gen_line_idx]),
      .i_clk_rd      (i_clk_apb),
      .i_rst_n_rd    (i_rst_n_apb),
      .i_rd_en       (i_rd_en[gen_line_idx]),
      .i_empty_thr   ({LPARA_PTR_W{1'b0}}),
      .o_rd_data     (o_rd_data[gen_line_idx*LPARA_WORD_W +: LPARA_WORD_W]),
      .o_empty       (o_rd_empty[gen_line_idx]),
      .o_empty_thr   (),
      .o_underflow   ()
    );
  end

endmodule
