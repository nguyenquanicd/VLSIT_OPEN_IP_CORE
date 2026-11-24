/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Flush of the input buffer across the clock domains (section 10.6, DEC-027). The
 *                request starts in CLK-CORE as a pulse and the flush machine m_chacha_flush of
 *                the buffer runs in CLK-AXI, so the pulse is turned into a four-phase level
 *                handshake: the core holds a request level until the done level of CLK-AXI is
 *                seen, drops it, and waits for the done level to fall; the AXI side starts the
 *                machine when it sees the request level while its done level is low, raises the
 *                done level when the machine ends and keeps it until the request level falls.
 *                Both levels cross through two-flop synchronizer cells (direct with a common
 *                clock net). Levels, not toggle events, are used because a reset of the AXI
 *                domain alone would otherwise create a false done event: after such a reset the
 *                AXI side sees the request level still high and runs the flush again (DEC-033).
 * Decisions    : DEC-027, DEC-033
 */
`timescale 1ns/1ps

module m_chacha_flush_hs #(
  // Parameter Description: 1 when the AXI clock and the core clock are the same net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_AXI_CORE = 32'd0
) (
  // Core clock and reset: request pulse and done pulse
  input  wire  i_clk_core,
  input  wire  i_rst_n_core,
  input  wire  i_req,
  output logic o_done,

  // AXI clock and reset: software reset handshake with the input buffer
  input  wire  i_clk_axi,
  input  wire  i_rst_n_axi,
  output logic o_rst_n_sw,
  input  wire  i_swr_busy
);

  // Core-side FSM states: IDLE, REQ holds the request level until the done level is seen, ACK
  // holds the request low until the done level falls. The encoding 2'b11 recovers to IDLE.
  typedef enum logic [1:0] {
    ENUM_ST_IDLE = 2'b00,
    ENUM_ST_REQ  = 2'b01,
    ENUM_ST_ACK  = 2'b10
  } hs_state_type_def;

  // Internal signal declarations
  hs_state_type_def reg_fsm_hs_current_state;
  hs_state_type_def w_fsm_hs_nxt_state;
  logic             w_req_s;
  logic             w_done_s;
  logic             w_done_axi;
  logic             reg_done_lvl;
  logic             reg_run;
  logic             w_start;
  logic             reg_req_lvl;

  // The done pulse is the cycle in which REQ sees the done level.
  assign o_done = reg_req_lvl & w_done_s;

  // Request level: a flop that is high exactly in the REQ state, so the level that crosses into
  // CLK-AXI is registered (rule CLK-01).
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_req_lvl
    if (!i_rst_n_core)
      reg_req_lvl <= 1'b0;
    else
      reg_req_lvl <= (w_fsm_hs_nxt_state == ENUM_ST_REQ);
  end

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_hs
    if (!i_rst_n_core)
      reg_fsm_hs_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_hs_current_state <= w_fsm_hs_nxt_state;
  end

  // Part 2 of the FSM: a request pulse in IDLE raises the level; the done level moves REQ to ACK;
  // the falling done level returns to IDLE.
  always_comb begin : p_com_fsm_nxt
    w_fsm_hs_nxt_state = reg_fsm_hs_current_state;
    case (reg_fsm_hs_current_state)
      ENUM_ST_IDLE: begin
        if (i_req)
          w_fsm_hs_nxt_state = ENUM_ST_REQ;
      end
      ENUM_ST_REQ: begin
        if (w_done_s)
          w_fsm_hs_nxt_state = ENUM_ST_ACK;
      end
      ENUM_ST_ACK: begin
        if (~w_done_s)
          w_fsm_hs_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_hs_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Crossings of the two levels.
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_cdc
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_req (
      .i_clk_dst   (i_clk_axi),
      .i_rst_n_dst (i_rst_n_axi),
      .i_d         (reg_req_lvl),
      .o_q         (w_req_s)
    );
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_done (
      .i_clk_dst   (i_clk_core),
      .i_rst_n_dst (i_rst_n_core),
      .i_d         (reg_done_lvl),
      .o_q         (w_done_s)
    );
  end else begin : gen_direct
    assign w_req_s  = reg_req_lvl;
    assign w_done_s = reg_done_lvl;
  end

  // AXI side: the machine starts when the request level is seen, the done level is low and no flush
  // is running; the done level is raised at the end of the flush and cleared when the request
  // falls.
  assign w_start = w_req_s & ~reg_done_lvl & ~reg_run;

  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_axi
    if (!i_rst_n_axi) begin
      reg_run      <= 1'b0;
      reg_done_lvl <= 1'b0;
    end else begin
      if (w_start)
        reg_run <= 1'b1;
      else if (w_done_axi)
        reg_run <= 1'b0;
      if (w_done_axi)
        reg_done_lvl <= 1'b1;
      else if (~w_req_s)
        reg_done_lvl <= 1'b0;
    end
  end

  // Flush machine of the input buffer in CLK-AXI.
  m_chacha_flush u_flush (
    .i_clk_wr    (i_clk_axi),
    .i_rst_n_wr  (i_rst_n_axi),
    .i_req       (w_start),
    .o_done      (w_done_axi),
    .o_rst_n_sw  (o_rst_n_sw),
    .i_swr_busy  (i_swr_busy)
  );

endmodule
