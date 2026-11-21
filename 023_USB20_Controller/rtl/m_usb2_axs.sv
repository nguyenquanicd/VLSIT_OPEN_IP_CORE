/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : AXI4 slave windows with request and acknowledge handshake for an external DMA
 *                controller (section 10.6, FEAT-006, DEC-011). The window of channel c is the 4
 *                KB block of address bits [15:12] = c. A channel of u2_dmach_map writes into the
 *                transmit queue of its region (device IN endpoint, 30 = host non-periodic, 31 =
 *                host periodic): each AXI write beat is one RAM row and the last beat commits
 *                the packet. A read channel (dir_in = 0) reads the rows of the head packet whose
 *                tag equals the region and releases the packet when all its rows were read.
 *                o_dma_req[c] rises when the channel can move a packet (credit for a maximum
 *                packet of the region, or a packet of the region waiting) and falls on
 *                i_dma_ack[c] or when the transfer starts. One AXI beat is one RAM row
 *                (DEC-010); an access to a channel that is not enabled or has the wrong
 *                direction gets SLVERR.
 */
`timescale 1ns/1ps

module m_usb2_axs #(
  // Parameter Description: AXI data width, equal to the RAM row width.
  // Parameter values: 32 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_DATA_W = 32,
  // Parameter Description: AXI address width.
  // Parameter values: 32, 40 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_ADDR_W = 32,
  // Parameter Description: AXI ID width.
  // Parameter values: 1 to 8; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_ID_W = 4,
  // Parameter Description: number of external DMA handshake channels.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NUM_DMA_CH = 4,
  // Parameter Description: device endpoint entries per direction (EP0 and the others).
  // Parameter values: 2 to 16; default is 9.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NEP1 = 9,
  // Parameter Description: rows of the FIFO RAM in 32-bit rows; sizes the row counters.
  // Parameter values: 64 to 32768; default is 1024.
  // Parameter unit: row
  parameter logic [31:0] PARA_USB2_FIFO_DEPTH = 1024,
  // Parameter Description: register slice on the AXI read data channel (timing option).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_AXS = 0,
  localparam logic [31:0] LPARA_NQ        = PARA_USB2_NEP1 + 32'd3,
  localparam logic [31:0] LPARA_CW        = $clog2(PARA_USB2_FIFO_DEPTH >> ((PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd1 : 32'd0)) + 32'd1,
  localparam logic [31:0] LPARA_ROW_W     = PARA_USB2_AXI_DATA_W,
  localparam logic [31:0] LPARA_BYTES     = PARA_USB2_AXI_DATA_W / 32'd8,
  localparam logic [31:0] LPARA_BSH       = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd3 : 32'd2,
  localparam logic [31:0] LPARA_SH        = (PARA_USB2_AXI_DATA_W == 32'd64) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_OP_WR     = 1,
  localparam logic [31:0] LPARA_OP_RD     = 2,
  localparam logic [31:0] LPARA_OP_POP    = 3,
  localparam logic [31:0] LPARA_OP_COMMIT = 4,
  localparam logic [31:0] LPARA_EV_PKT    = 0,
  localparam logic [31:0] LPARA_EV_CRD    = 1,
  localparam logic [31:0] LPARA_EVQ_N     = 8,
  localparam logic [31:0] LPARA_EVQ_W     = 3,
  localparam logic [31:0] LPARA_REG_HNP   = 30,
  localparam logic [31:0] LPARA_REG_HPT   = 31,
  localparam logic [31:0] LPARA_ONE       = 1
) (
  // Clock and reset
  input  wire                                   i_clk_bus,
  input  wire                                   i_rst_n_bus,

  // Control from the CSR (bus domain)
  input  wire                                   i_core_en,
  input  wire                                   i_win_en,
  input  wire  [31:0]                           i_fifo_hnp,
  input  wire  [31:0]                           i_fifo_hpt,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]       i_epi_ctrl,
  input  wire  [PARA_USB2_NEP1-1:0][31:0]       i_epi_fifo,
  input  wire  [PARA_USB2_NUM_DMA_CH-1:0][31:0] i_dmach_map,

  // Handshake with the external DMA controller
  output logic [PARA_USB2_NUM_DMA_CH-1:0]       o_dma_req,
  input  wire  [PARA_USB2_NUM_DMA_CH-1:0]       i_dma_ack,

  // Bus port requests, responses and events (through m_usb2_cdc_fifo)
  output logic                                  o_rq_vld,
  output logic [2:0]                            o_rq_op,
  output logic [4:0]                            o_rq_q,
  output logic [LPARA_ROW_W-1:0]                o_rq_data,
  input  wire                                   i_rq_rdy,
  input  wire                                   i_rs_vld,
  input  wire  [LPARA_ROW_W-1:0]                i_rs_data,
  output logic                                  o_rs_pop,
  input  wire                                   i_ev_vld,
  input  wire  [1:0]                            i_ev_type,
  input  wire  [4:0]                            i_ev_q,
  input  wire  [16:0]                           i_ev_val,
  output logic                                  o_ev_pop,

  // AXI4 slave write channels
  input  wire  [PARA_USB2_AXI_ID_W-1:0]         i_axis_awid,
  input  wire  [PARA_USB2_AXI_ADDR_W-1:0]       i_axis_awaddr,
  input  wire  [7:0]                            i_axis_awlen,
  input  wire  [2:0]                            i_axis_awsize,
  input  wire  [1:0]                            i_axis_awburst,
  input  wire                                   i_axis_awvalid,
  output logic                                  o_axis_awready,
  input  wire  [PARA_USB2_AXI_DATA_W-1:0]       i_axis_wdata,
  input  wire  [PARA_USB2_AXI_DATA_W/8-1:0]     i_axis_wstrb,
  input  wire                                   i_axis_wlast,
  input  wire                                   i_axis_wvalid,
  output logic                                  o_axis_wready,
  output logic [PARA_USB2_AXI_ID_W-1:0]         o_axis_bid,
  output logic [1:0]                            o_axis_bresp,
  output logic                                  o_axis_bvalid,
  input  wire                                   i_axis_bready,

  // AXI4 slave read channels
  input  wire  [PARA_USB2_AXI_ID_W-1:0]         i_axis_arid,
  input  wire  [PARA_USB2_AXI_ADDR_W-1:0]       i_axis_araddr,
  input  wire  [7:0]                            i_axis_arlen,
  input  wire  [2:0]                            i_axis_arsize,
  input  wire  [1:0]                            i_axis_arburst,
  input  wire                                   i_axis_arvalid,
  output logic                                  o_axis_arready,
  output logic [PARA_USB2_AXI_ID_W-1:0]         o_axis_rid,
  output logic [PARA_USB2_AXI_DATA_W-1:0]       o_axis_rdata,
  output logic [1:0]                            o_axis_rresp,
  output logic                                  o_axis_rlast,
  output logic                                  o_axis_rvalid,
  input  wire                                   i_axis_rready
);

  // FSM states of the write channel.
  typedef enum logic [2:0] {
    ENUM_ST_W_IDLE = 3'd0,
    ENUM_ST_W_DATA = 3'd1,
    ENUM_ST_W_CM   = 3'd2,
    ENUM_ST_W_RESP = 3'd3
  } wr_state_type_def;

  // FSM states of the read channel.
  typedef enum logic [2:0] {
    ENUM_ST_R_IDLE = 3'd0,
    ENUM_ST_R_REQ  = 3'd1,
    ENUM_ST_R_DATA = 3'd2,
    ENUM_ST_R_POP  = 3'd3
  } rd_state_type_def;

  // Internal signal declarations
  wr_state_type_def                           reg_fsm_wr_current_state;
  wr_state_type_def                           w_fsm_wr_nxt_state;
  rd_state_type_def                           reg_fsm_rd_current_state;
  rd_state_type_def                           w_fsm_rd_nxt_state;
  logic [4:0]                                 reg_evq_tag [LPARA_EVQ_N];
  logic [11:0]                                reg_evq_len [LPARA_EVQ_N];
  logic [LPARA_EVQ_W-1:0]                     reg_evq_rd;
  logic [LPARA_EVQ_W-1:0]                     reg_evq_wr;
  logic [LPARA_EVQ_W:0]                       reg_evq_cnt;
  logic [LPARA_NQ-1:0][LPARA_CW-1:0]          reg_credit;
  logic [LPARA_NQ-1:0][LPARA_CW-1:0]          w_q_size;
  logic [PARA_USB2_AXI_ID_W-1:0]              reg_wid;
  logic [4:0]                                 reg_w_q;
  logic                                       reg_w_err;
  logic [PARA_USB2_AXI_ID_W-1:0]              reg_rid;
  logic [LPARA_CW-1:0]                        reg_r_left;
  logic [LPARA_CW-1:0]                        reg_r_rq_left;
  logic [7:0]                                 reg_r_beats;
  logic                                       reg_r_err;
  logic [LPARA_CW-1:0]                        reg_w_rows;
  logic [3:0]                                 w_w_ch;
  logic [3:0]                                 w_r_ch;
  logic [31:0]                                w_w_map;
  logic [31:0]                                w_r_map;
  logic [4:0]                                 w_w_q;
  logic                                       w_w_ok;
  logic                                       w_r_ok;
  logic [LPARA_CW-1:0]                        w_head_rows;
  logic [11:0]                                w_head_len;
  logic [4:0]                                 w_head_tag;
  logic                                       w_w_want;
  logic [2:0]                                 w_w_op;
  logic [2:0]                                 w_r_op;
  logic                                       w_r_want;
  logic                                       w_sel_w;
  logic                                       w_grant_w;
  logic                                       w_grant_r;
  logic [PARA_USB2_NUM_DMA_CH-1:0]            reg_req_msk;
  logic [PARA_USB2_NUM_DMA_CH-1:0]            w_req_cond;
  logic                                       w_rb_vld;
  logic                                       w_rb_rdy;
  logic                                       w_rb_last;
  logic [PARA_USB2_AXI_DATA_W-1:0]            w_rb_data;
  logic                                       reg_ro_vld;
  logic                                       reg_ro_last;
  logic                                       reg_ro_err;
  logic [PARA_USB2_AXI_ID_W-1:0]              reg_ro_id;
  logic [PARA_USB2_AXI_DATA_W-1:0]            reg_ro_data;

  // Events of the FIFO manager: packet events are queued, credit events add rows to the credit.
  assign o_ev_pop = i_ev_vld;
  assign w_head_len  = reg_evq_len[reg_evq_rd];
  assign w_head_tag  = reg_evq_tag[reg_evq_rd];
  assign w_head_rows = (LPARA_CW)'(({5'd0, w_head_len} + LPARA_BYTES[16:0] - 17'd1) >> LPARA_BSH);

  // Channel of an access: bits [15:12] of the address; its map decides the region and direction.
  assign w_w_ch  = i_axis_awaddr[15:12];
  assign w_r_ch  = i_axis_araddr[15:12];
  assign w_w_map = i_dmach_map[w_w_ch];
  assign w_r_map = i_dmach_map[w_r_ch];
  assign w_w_ok  = i_win_en & i_core_en & (w_w_ch < PARA_USB2_NUM_DMA_CH[3:0]) & w_w_map[6] & w_w_map[5];
  assign w_r_ok  = i_win_en & i_core_en & (w_r_ch < PARA_USB2_NUM_DMA_CH[3:0]) & w_r_map[6] & ~w_r_map[5];

  // Queue of a region: the device IN endpoint number, 30 for the host non-periodic queue and 31
  // for the host periodic queue.
  always_comb begin : p_com_wq
    w_w_q = {1'b0, w_w_map[3:0]} + 5'd1;
    if (w_w_map[4:0] == LPARA_REG_HNP[4:0])
      w_w_q = LPARA_NQ[4:0] - 5'd2;
    if (w_w_map[4:0] == LPARA_REG_HPT[4:0])
      w_w_q = LPARA_NQ[4:0] - 5'd1;
  end

  // Queue sizes in rows for the credit start values.
  always_comb begin : p_com_qsize
    w_q_size = '0;
    for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin
      w_q_size[idx + 1] = {1'b0, i_epi_fifo[idx][31:16]} >> LPARA_SH;
    end
    w_q_size[LPARA_NQ - 2] = {1'b0, i_fifo_hnp[31:16]} >> LPARA_SH;
    w_q_size[LPARA_NQ - 1] = {1'b0, i_fifo_hpt[31:16]} >> LPARA_SH;
  end

  // AXI write channel: the address is accepted in IDLE, each beat becomes a row write, the last
  // beat is followed by the commit and the write response.
  assign o_axis_awready = (reg_fsm_wr_current_state == ENUM_ST_W_IDLE);
  assign o_axis_wready  = (reg_fsm_wr_current_state == ENUM_ST_W_DATA) & (w_grant_w | reg_w_err);
  assign o_axis_bid     = reg_wid;
  assign o_axis_bresp   = reg_w_err ? 2'b10 : 2'b00;
  assign o_axis_bvalid  = (reg_fsm_wr_current_state == ENUM_ST_W_RESP);

  // Part 1, sequential: the state of the write channel.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_fsm_wr
    if (!i_rst_n_bus)
      reg_fsm_wr_current_state <= ENUM_ST_W_IDLE;
    else
      reg_fsm_wr_current_state <= w_fsm_wr_nxt_state;
  end

  // Part 2, combinational: next state of the write channel.
  always_comb begin : p_com_fsm_wr_nxt
    w_fsm_wr_nxt_state = reg_fsm_wr_current_state;
    case (reg_fsm_wr_current_state)
      ENUM_ST_W_IDLE: begin
        if (i_axis_awvalid)
          w_fsm_wr_nxt_state = ENUM_ST_W_DATA;
      end
      ENUM_ST_W_DATA: begin
        if (o_axis_wready & i_axis_wvalid & i_axis_wlast)
          w_fsm_wr_nxt_state = reg_w_err ? ENUM_ST_W_RESP : ENUM_ST_W_CM;
      end
      ENUM_ST_W_CM: begin
        if (w_grant_w)
          w_fsm_wr_nxt_state = ENUM_ST_W_RESP;
      end
      ENUM_ST_W_RESP: begin
        if (i_axis_bready)
          w_fsm_wr_nxt_state = ENUM_ST_W_IDLE;
      end
      default: w_fsm_wr_nxt_state = ENUM_ST_W_IDLE;
    endcase
  end

  // Write channel registers: the id, the queue and the error flag of the burst.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_wr
    if (!i_rst_n_bus) begin
      reg_wid    <= '0;
      reg_w_q    <= 5'd0;
      reg_w_err  <= 1'b0;
      reg_w_rows <= '0;
    end else begin
      if ((reg_fsm_wr_current_state == ENUM_ST_W_IDLE) & i_axis_awvalid) begin
        reg_wid    <= i_axis_awid;
        reg_w_q    <= w_w_q;
        reg_w_err  <= ~w_w_ok;
        reg_w_rows <= '0;
      end
      if (o_axis_wready & i_axis_wvalid & ~reg_w_err)
        reg_w_rows <= reg_w_rows + (LPARA_CW)'(32'd1);
    end
  end

  // AXI read channel: after the address the head packet of the region is read row by row.
  assign o_axis_arready = (reg_fsm_rd_current_state == ENUM_ST_R_IDLE);
  // w_rb_* is the read beat before the optional register slice (PARA_USB2_PIPE_AXS): with the
  // slice the beat is taken when the output register is empty or is read in this cycle.
  assign w_rb_vld       = (reg_fsm_rd_current_state == ENUM_ST_R_DATA) & (i_rs_vld | reg_r_err);
  assign w_rb_last      = (reg_r_beats == 8'd0);
  assign w_rb_data      = reg_r_err ? '0 : i_rs_data;
  assign w_rb_rdy       = (PARA_USB2_PIPE_AXS != 32'd0) ? (~reg_ro_vld | i_axis_rready) : i_axis_rready;
  assign o_axis_rid     = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_id : reg_rid;
  assign o_axis_rdata   = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_data : w_rb_data;
  assign o_axis_rresp   = ((PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_err : reg_r_err) ? 2'b10 : 2'b00;
  assign o_axis_rvalid  = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_vld : w_rb_vld;
  assign o_axis_rlast   = (PARA_USB2_PIPE_AXS != 32'd0) ? reg_ro_last : w_rb_last;
  assign o_rs_pop       = w_rb_vld & w_rb_rdy & ~reg_r_err;

  // Output register of the read data channel; it holds a beat until the manager takes it.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_ro
    if (!i_rst_n_bus) begin
      reg_ro_vld  <= 1'b0;
      reg_ro_last <= 1'b0;
      reg_ro_err  <= 1'b0;
      reg_ro_id   <= '0;
      reg_ro_data <= '0;
    end else if (PARA_USB2_PIPE_AXS != 32'd0) begin
      if (w_rb_rdy) begin
        reg_ro_vld <= w_rb_vld;
        if (w_rb_vld) begin
          reg_ro_last <= w_rb_last;
          reg_ro_err  <= reg_r_err;
          reg_ro_id   <= reg_rid;
          reg_ro_data <= w_rb_data;
        end
      end
    end
  end

  // Part 1, sequential: the state of the read channel.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_fsm_rd
    if (!i_rst_n_bus)
      reg_fsm_rd_current_state <= ENUM_ST_R_IDLE;
    else
      reg_fsm_rd_current_state <= w_fsm_rd_nxt_state;
  end

  // Part 2, combinational: next state of the read channel.
  always_comb begin : p_com_fsm_rd_nxt
    w_fsm_rd_nxt_state = reg_fsm_rd_current_state;
    case (reg_fsm_rd_current_state)
      ENUM_ST_R_IDLE: begin
        if (i_axis_arvalid)
          w_fsm_rd_nxt_state = ENUM_ST_R_REQ;
      end
      ENUM_ST_R_REQ: begin
        w_fsm_rd_nxt_state = ENUM_ST_R_DATA;
      end
      ENUM_ST_R_DATA: begin
        if (w_rb_vld & w_rb_rdy & w_rb_last)
          w_fsm_rd_nxt_state = reg_r_err ? ENUM_ST_R_IDLE : ENUM_ST_R_POP;
      end
      ENUM_ST_R_POP: begin
        if (w_grant_r | (reg_r_left != '0))
          w_fsm_rd_nxt_state = ENUM_ST_R_IDLE;
      end
      default: w_fsm_rd_nxt_state = ENUM_ST_R_IDLE;
    endcase
  end

  // Read channel registers: the id, the rows left in the head packet, the rows still to request.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_rd
    if (!i_rst_n_bus) begin
      reg_rid       <= '0;
      reg_r_left    <= '0;
      reg_r_rq_left <= '0;
      reg_r_beats   <= 8'd0;
      reg_r_err     <= 1'b0;
    end else begin
      if ((reg_fsm_rd_current_state == ENUM_ST_R_IDLE) & i_axis_arvalid) begin
        reg_rid     <= i_axis_arid;
        reg_r_beats <= i_axis_arlen;
        reg_r_err   <= ~w_r_ok | (reg_evq_cnt == '0) | (w_head_tag != w_r_map[4:0]);
        if (w_r_ok & (reg_evq_cnt != '0) & (w_head_tag == w_r_map[4:0])) begin
          reg_r_left    <= w_head_rows;
          reg_r_rq_left <= ({9'd0, i_axis_arlen} >= 17'(w_head_rows)) ? w_head_rows :
                           (LPARA_CW)'({9'd0, i_axis_arlen} + 17'd1);
        end
      end
      if (w_grant_r & (reg_fsm_rd_current_state == ENUM_ST_R_DATA))
        reg_r_rq_left <= reg_r_rq_left - (LPARA_CW)'(32'd1);
      if (o_rs_pop) begin
        reg_r_beats <= reg_r_beats - 8'd1;
        if (reg_r_left != '0)
          reg_r_left <= reg_r_left - (LPARA_CW)'(32'd1);
      end
      if (w_rb_vld & w_rb_rdy & reg_r_err)
        reg_r_beats <= reg_r_beats - 8'd1;
    end
  end

  // Bus port requests: the write channel writes rows and commits; the read channel reads rows of
  // the head packet and releases it. Reads and writes alternate when both ask.
  always_comb begin : p_com_rq
    w_w_want = 1'b0;
    w_w_op   = LPARA_OP_WR[2:0];
    w_r_want = 1'b0;
    w_r_op   = LPARA_OP_RD[2:0];
    if (reg_fsm_wr_current_state == ENUM_ST_W_CM) begin
      w_w_want = 1'b1;
      w_w_op   = LPARA_OP_COMMIT[2:0];
    end else if ((reg_fsm_wr_current_state == ENUM_ST_W_DATA) & i_axis_wvalid & ~reg_w_err) begin
      w_w_want = 1'b1;
    end
    if ((reg_fsm_rd_current_state == ENUM_ST_R_POP) & (reg_r_left == '0)) begin
      w_r_want = 1'b1;
      w_r_op   = LPARA_OP_POP[2:0];
    end else if ((reg_fsm_rd_current_state == ENUM_ST_R_DATA) & ~reg_r_err & (reg_r_rq_left != '0)) begin
      w_r_want = 1'b1;
    end
  end

  assign w_sel_w   = w_w_want;
  assign w_grant_w = w_sel_w & i_rq_rdy;
  assign w_grant_r = w_r_want & ~w_sel_w & i_rq_rdy;
  assign o_rq_vld  = w_sel_w | w_r_want;
  assign o_rq_op   = w_sel_w ? w_w_op : w_r_op;
  assign o_rq_q    = w_sel_w ? reg_w_q : 5'd0;
  assign o_rq_data = i_axis_wdata;

  // The queue of events and the credit counters.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_evq
    if (!i_rst_n_bus) begin
      reg_evq_rd  <= '0;
      reg_evq_wr  <= '0;
      reg_evq_cnt <= '0;
      reg_credit  <= '0;
      for (int idx = 0; idx < LPARA_EVQ_N; idx++) begin
        reg_evq_tag[idx] <= 5'd0;
        reg_evq_len[idx] <= 12'd0;
      end
    end else begin
      if (i_ev_vld & (i_ev_type == LPARA_EV_PKT[1:0])) begin
        reg_evq_tag[reg_evq_wr] <= i_ev_q;
        reg_evq_len[reg_evq_wr] <= i_ev_val[11:0];
        reg_evq_wr              <= reg_evq_wr + LPARA_ONE[LPARA_EVQ_W-1:0];
      end
      if ((reg_fsm_rd_current_state == ENUM_ST_R_POP) & w_grant_r & (reg_r_left == '0))
        reg_evq_rd <= reg_evq_rd + LPARA_ONE[LPARA_EVQ_W-1:0];
      case ({(i_ev_vld & (i_ev_type == LPARA_EV_PKT[1:0])),
             ((reg_fsm_rd_current_state == ENUM_ST_R_POP) & w_grant_r & (reg_r_left == '0))})
        2'b10:   reg_evq_cnt <= reg_evq_cnt + LPARA_ONE[LPARA_EVQ_W:0];
        2'b01:   reg_evq_cnt <= reg_evq_cnt - LPARA_ONE[LPARA_EVQ_W:0];
        default: reg_evq_cnt <= reg_evq_cnt;
      endcase
      for (int idx = 0; idx < LPARA_NQ; idx++) begin
        if (!i_core_en)
          reg_credit[idx] <= w_q_size[idx];
        else
          reg_credit[idx] <= reg_credit[idx] +
                             ((i_ev_vld & (i_ev_type == LPARA_EV_CRD[1:0]) & (i_ev_q == idx[4:0])) ?
                              (LPARA_CW)'(i_ev_val) : '0) -
                             ((w_grant_w & o_axis_wready & (reg_w_q == idx[4:0]) & ~reg_w_err) ? (LPARA_CW)'(32'd1) : '0);
      end
    end
  end

  // Request lines: a write channel asks when its queue has credit for a maximum packet (one row of
  // credit per row of the packet; the map region tells the queue), a read channel asks while the
  // head packet carries its tag. The request is withdrawn by the acknowledge until the condition
  // goes away and comes back.
  always_comb begin : p_com_cond
    w_req_cond = '0;
    for (int idx = 0; idx < PARA_USB2_NUM_DMA_CH; idx++) begin
      if (i_dmach_map[idx][6] & i_win_en & i_core_en) begin
        if (i_dmach_map[idx][5]) begin
          w_req_cond[idx] = (reg_credit[({1'b0, i_dmach_map[idx][3:0]} + 5'd1)] != '0);
        end else begin
          w_req_cond[idx] = (reg_evq_cnt != '0) & (reg_evq_tag[reg_evq_rd] == i_dmach_map[idx][4:0]);
        end
      end
    end
  end

  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_req
    if (!i_rst_n_bus) begin
      reg_req_msk <= '0;
    end else begin
      reg_req_msk <= (reg_req_msk | i_dma_ack) & w_req_cond;
    end
  end

  assign o_dma_req = w_req_cond & ~reg_req_msk;

endmodule
