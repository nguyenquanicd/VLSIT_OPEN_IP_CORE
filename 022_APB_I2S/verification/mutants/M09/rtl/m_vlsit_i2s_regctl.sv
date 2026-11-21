/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Register control logic (APB clock domain). It turns the register events of the
 *                generated CSR into FIFO actions: a write event of the transmit data register
 *                pushes the word into the next line FIFO (one cycle later, when the CSR data field
 *                is loaded), and a read event of the receive data register pops the word of the
 *                next line FIFO in the same cycle, in which the CSR samples the head word. Lines
 *                are served in fixed order, line 0 first. It also runs the flush and soft reset of
 *                each unit and of both units: one request pulse, then it waits for the flush-done
 *                pulse of the FIFO and clears the self-clearing bits through the hardware-clear
 *                ports of the CSR. It builds the empty and full flags and the masked level of each
 *                unit.
 * Decisions    : DEC-002, ASM-005, ASM-019, REQ-FUNC-025, REQ-FUNC-030, REQ-IF-008, REQ-REG-006,
 *                OP-011, OP-015
 */
`timescale 1ns/1ps

module m_vlsit_i2s_regctl #(
  // Parameter Description: transmit unit present.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_TX_EN = 1,
  // Parameter Description: receive unit present.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_RX_EN = 1,
  // Parameter Description: transmit data lines.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_TX_LINES = 1,
  // Parameter Description: receive data lines.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_RX_LINES = 1,
  // Parameter Description: words of each line FIFO. Sets the capacity of the logical FIFO.
  // Parameter values: power of 2 from 2 to 256; default is 16.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_FIFO_DEPTH = 16,
  localparam logic [31:0] LPARA_ADDR_W      = 32'd16,
  localparam logic [31:0] LPARA_WORD_W      = 32'd32,
  localparam logic [31:0] LPARA_LVL_W       = 32'd12,
  localparam logic [31:0] LPARA_TX_DATA_OFF = 32'h11C,
  localparam logic [31:0] LPARA_RX_DATA_OFF = 32'h21C,
  localparam logic [31:0] LPARA_TX_CAP      = PARA_I2S_TX_LINES * PARA_I2S_FIFO_DEPTH,
  localparam logic [31:0] LPARA_RX_CAP      = PARA_I2S_RX_LINES * PARA_I2S_FIFO_DEPTH,
  localparam logic [31:0] LPARA_LINE_W      = 32'd2
) (
  // Clock and reset
  input  wire                                       i_clk_apb,
  input  wire                                       i_rst_n_apb,

  // Register events of the CSR
  input  wire                                       i_reg_wr_en,
  input  wire  [LPARA_ADDR_W-1:0]                   i_reg_wr_addr,
  input  wire                                       i_reg_rd_en,
  input  wire  [LPARA_ADDR_W-1:0]                   i_reg_rd_addr,

  // Watermarks, enables and synchronized busy flags of the two units
  input  wire  [LPARA_LVL_W-1:0]                    i_tx_wm,
  input  wire  [LPARA_LVL_W-1:0]                    i_rx_wm,
  input  wire                                       i_tx_en,
  input  wire                                       i_rx_en,
  input  wire                                       i_tx_busy_s,
  input  wire                                       i_rx_busy_s,
  output logic                                      o_tx_wm_cond,
  output logic                                      o_rx_wm_cond,
  output logic                                      o_tx_busy,
  output logic                                      o_rx_busy,

  // Self-clearing control bits of the CSR and their hardware clear
  input  wire                                       i_glob_srst,
  input  wire                                       i_tx_srst,
  input  wire                                       i_tx_flush,
  input  wire                                       i_rx_srst,
  input  wire                                       i_rx_flush,
  output logic                                      o_hw_clr_glob_srst,
  output logic                                      o_hw_clr_tx_srst,
  output logic                                      o_hw_clr_tx_flush,
  output logic                                      o_hw_clr_rx_srst,
  output logic                                      o_hw_clr_rx_flush,
  output logic                                      o_hw_clr_tx_data,

  // Transmit FIFO interface
  input  wire  [PARA_I2S_TX_LINES-1:0]              i_tx_full,
  input  wire  [LPARA_LVL_W-1:0]                    i_tx_level,
  input  wire                                       i_tx_flush_done,
  output logic [PARA_I2S_TX_LINES-1:0]              o_tx_wr_en,
  output logic                                      o_tx_flush_req,
  output logic                                      o_tx_srst_req,
  output logic                                      o_tx_flag_clr,
  output logic [LPARA_LVL_W-1:0]                    o_tx_level,
  output logic                                      o_tx_empty,
  output logic                                      o_tx_full,

  // Receive FIFO interface
  input  wire  [PARA_I2S_RX_LINES*LPARA_WORD_W-1:0] i_rx_rdata,
  input  wire  [PARA_I2S_RX_LINES-1:0]              i_rx_empty,
  input  wire  [LPARA_LVL_W-1:0]                    i_rx_level,
  input  wire                                       i_rx_flush_done,
  output logic [PARA_I2S_RX_LINES-1:0]              o_rx_rd_en,
  output logic [LPARA_WORD_W-1:0]                   o_rx_data,
  output logic                                      o_rx_flush_req,
  output logic                                      o_rx_srst_req,
  output logic                                      o_rx_flag_clr,
  output logic [LPARA_LVL_W-1:0]                    o_rx_level,
  output logic                                      o_rx_empty,
  output logic                                      o_rx_full
);

  // Internal signal declarations
  logic w_tx_wr_ev;
  logic w_rx_rd_ev;
  logic reg_tx_push;

  logic [LPARA_LINE_W-1:0] reg_tx_line;
  logic [LPARA_LINE_W-1:0] w_tx_line_nxt;
  logic [LPARA_LINE_W-1:0] reg_rx_line;
  logic [LPARA_LINE_W-1:0] w_rx_line_nxt;
  logic w_tx_acc;
  logic w_rx_acc;

  logic reg_tx_pend;
  logic reg_rx_pend;
  logic w_tx_glob;
  logic w_rx_glob;
  logic w_tx_req;
  logic w_rx_req;
  logic w_tx_issue;
  logic w_rx_issue;
  logic reg_glob_tx;
  logic reg_glob_rx;
  logic w_glob_tx_ok;
  logic w_glob_rx_ok;
  logic w_glob_done;

  // Event decode: a write event of the transmit data register and a read event of the receive data
  // register. Events of other addresses, and events of an absent unit, are ignored.
  assign w_tx_wr_ev = (PARA_I2S_TX_EN != 32'd0) & i_reg_wr_en &
                      (i_reg_wr_addr == LPARA_TX_DATA_OFF[LPARA_ADDR_W-1:0]);
  // Read event of the receive data register; reads are ignored while a flush is pending.
  assign w_rx_rd_ev = (PARA_I2S_RX_EN != 32'd0) & i_reg_rd_en &
                      (i_reg_rd_addr == LPARA_RX_DATA_OFF[LPARA_ADDR_W-1:0]) & ~reg_rx_pend;

  // Push strobe: the CSR data field is loaded one cycle after the write event, so the push is
  // taken in the cycle after the event (ASM-005). Control state, reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_tx_push
    if (!i_rst_n_apb)
      reg_tx_push <= 1'b0;
    else
      reg_tx_push <= w_tx_wr_ev;
  end

  // Hardware clear of the write-only data field after the push.
  assign o_hw_clr_tx_data = reg_tx_push;

  // Line enables: one-hot, the line that holds the next word in the fixed order.
  always_comb begin : p_com_tx_wr_en
    o_tx_wr_en = '0;
    for (int idx = 0; idx < PARA_I2S_TX_LINES; idx++) begin
      o_tx_wr_en[idx] = reg_tx_push & (reg_tx_line == LPARA_LINE_W'(idx));
    end
  end

  // Line enable of the receive pop: one-hot, in the same cycle as the read event.
  always_comb begin : p_com_rx_rd_en
    o_rx_rd_en = '0;
    for (int idx = 0; idx < PARA_I2S_RX_LINES; idx++) begin
      o_rx_rd_en[idx] = w_rx_rd_ev & (reg_rx_line == LPARA_LINE_W'(idx));
    end
  end

  // Head word of the receive FIFO: the word of the line that holds the next word, zero when that
  // line is empty or while a flush runs. The CSR samples it in the cycle of the read event.
  always_comb begin : p_com_rx_data
    o_rx_data = '0;
    for (int idx = 0; idx < PARA_I2S_RX_LINES; idx++) begin
      if (reg_rx_line == LPARA_LINE_W'(idx))
        o_rx_data = i_rx_rdata[idx*LPARA_WORD_W +: LPARA_WORD_W] &
                    {LPARA_WORD_W{~i_rx_empty[idx] & ~reg_rx_pend}};
    end
  end

  // Accepted push and pop: the addressed line is not full, respectively not empty.
  always_comb begin : p_com_acc
    w_tx_acc = 1'b0;
    w_rx_acc = 1'b0;
    for (int idx = 0; idx < PARA_I2S_TX_LINES; idx++) begin
      if (o_tx_wr_en[idx] && !i_tx_full[idx])
        w_tx_acc = 1'b1;
    end
    for (int idx = 0; idx < PARA_I2S_RX_LINES; idx++) begin
      if (o_rx_rd_en[idx] && !i_rx_empty[idx])
        w_rx_acc = 1'b1;
    end
  end

  // Next line pointers: rotate after an accepted word, restart at line 0 when a flush finishes.
  always_comb begin : p_com_line_nxt
    w_tx_line_nxt = reg_tx_line;
    w_rx_line_nxt = reg_rx_line;
    if (i_tx_flush_done)
      w_tx_line_nxt = '0;
    else if (w_tx_acc)
      w_tx_line_nxt = (reg_tx_line == LPARA_LINE_W'(PARA_I2S_TX_LINES - 32'd1)) ? '0 :
                      (reg_tx_line + 1'b1);
    if (i_rx_flush_done)
      w_rx_line_nxt = '0;
    else if (w_rx_acc)
      w_rx_line_nxt = (reg_rx_line == LPARA_LINE_W'(PARA_I2S_RX_LINES - 32'd1)) ? '0 :
                      (reg_rx_line + 1'b1);
  end

  // Line pointer flops: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_line
    if (!i_rst_n_apb) begin
      reg_tx_line <= '0;
      reg_rx_line <= '0;
    end else begin
      reg_tx_line <= w_tx_line_nxt;
      reg_rx_line <= w_rx_line_nxt;
    end
  end

  // Request of a unit: its own reset or flush bit, or the global reset. A request is issued once,
  // when no earlier request of the unit is pending.
  assign w_tx_glob  = i_glob_srst & ~reg_glob_tx;
  assign w_rx_glob  = i_glob_srst & ~reg_glob_rx;
  assign w_tx_req   = (PARA_I2S_TX_EN != 32'd0) & (i_tx_srst | i_tx_flush | w_tx_glob);
  assign w_rx_req   = (PARA_I2S_RX_EN != 32'd0) & (i_rx_srst | i_rx_flush | w_rx_glob);
  assign w_tx_issue = w_tx_req & ~reg_tx_pend;
  assign w_rx_issue = w_rx_req & ~reg_rx_pend;

  // Request pulses: the FIFO flush and the flush event of the unit; the soft reset adds the reset
  // event and clears the sticky flags of the unit.
  assign o_tx_flush_req = w_tx_issue;
  assign o_tx_srst_req  = w_tx_issue & (i_tx_srst | w_tx_glob);
  assign o_tx_flag_clr  = o_tx_srst_req;
  assign o_rx_flush_req = w_rx_issue;
  assign o_rx_srst_req  = w_rx_issue & (i_rx_srst | w_rx_glob);
  assign o_rx_flag_clr  = o_rx_srst_req;

  // Pending flags: set at the request, cleared by the flush-done pulse of the FIFO.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_pend
    if (!i_rst_n_apb) begin
      reg_tx_pend <= 1'b0;
      reg_rx_pend <= 1'b0;
    end else begin
      if (w_tx_issue)
        reg_tx_pend <= 1'b1;
      else if (i_tx_flush_done)
        reg_tx_pend <= 1'b0;
      if (w_rx_issue)
        reg_rx_pend <= 1'b1;
      else if (i_rx_flush_done)
        reg_rx_pend <= 1'b0;
    end
  end

  // Hardware clear of the self-clearing bits when the flush has finished.
  assign o_hw_clr_tx_srst  = reg_tx_pend & i_tx_flush_done;
  assign o_hw_clr_tx_flush = reg_tx_pend & i_tx_flush_done;
  assign o_hw_clr_rx_srst  = reg_rx_pend & i_rx_flush_done;
  assign o_hw_clr_rx_flush = reg_rx_pend & i_rx_flush_done;

  // Global reset: remember which units were reset because of it; the bit is cleared when every
  // present unit has finished.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_glob
    if (!i_rst_n_apb) begin
      reg_glob_tx <= 1'b0;
      reg_glob_rx <= 1'b0;
    end else if (w_glob_done) begin
      reg_glob_tx <= 1'b0;
      reg_glob_rx <= 1'b0;
    end else begin
      if (w_tx_issue & w_tx_glob)
        reg_glob_tx <= 1'b1;
      if (w_rx_issue & w_rx_glob)
        reg_glob_rx <= 1'b1;
    end
  end

  // A unit is done with the global reset when it was reset because of it and is not pending; an
  // absent unit is always done.
  assign w_glob_tx_ok = (PARA_I2S_TX_EN == 32'd0) | (reg_glob_tx & ~reg_tx_pend);
  assign w_glob_rx_ok = (PARA_I2S_RX_EN == 32'd0) | (reg_glob_rx & ~reg_rx_pend);
  assign w_glob_done        = i_glob_srst & w_glob_tx_ok & w_glob_rx_ok;
  assign o_hw_clr_glob_srst = w_glob_done;

  // Watermark conditions: the transmit cause is active while the level is at or below the
  // watermark, the receive cause while it is at or above it (REQ-FUNC-016). Busy is high from the
  // enable until the engine has stopped, and while a flush or soft reset is pending, so software
  // can poll it to know when the FIFO accepts words again (ASM-019).
  assign o_tx_wm_cond = (PARA_I2S_TX_EN != 32'd0) & (o_tx_level < i_tx_wm);
  assign o_rx_wm_cond = (PARA_I2S_RX_EN != 32'd0) & (o_rx_level >= i_rx_wm);
  assign o_tx_busy    = (PARA_I2S_TX_EN != 32'd0) & (i_tx_en | i_tx_busy_s | reg_tx_pend);
  assign o_rx_busy    = (PARA_I2S_RX_EN != 32'd0) & (i_rx_en | i_rx_busy_s | reg_rx_pend);

  // Level and flags of the logical FIFOs; the level reads 0 while a flush is pending.
  assign o_tx_level = reg_tx_pend ? '0 : i_tx_level;
  assign o_tx_empty = (o_tx_level == '0);
  assign o_tx_full  = (o_tx_level >= LPARA_TX_CAP[LPARA_LVL_W-1:0]);
  assign o_rx_level = reg_rx_pend ? '0 : i_rx_level;
  assign o_rx_empty = (o_rx_level == '0);
  assign o_rx_full  = (o_rx_level >= LPARA_RX_CAP[LPARA_LVL_W-1:0]);

endmodule
