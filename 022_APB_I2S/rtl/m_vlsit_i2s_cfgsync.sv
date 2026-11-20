/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Crossings between the APB clock domain and the master clock domain for one unit
 *                (the top instantiates it once for transmit and once for receive). APB to master:
 *                the configuration snapshot with the slot mask (library four-phase handshake, sent
 *                when the enable bit rises), the slot mask alone (four-phase handshake, sent when
 *                the mask register changes), the enable level (synchronizer), and the flush and
 *                soft reset requests (event synchronizer). Master to APB: the unit events (underrun
 *                or overrun, sync error, hung clock, frame done) through an event synchronizer, and
 *                the busy level through a synchronizer. It also drives the hardware-load ports of
 *                the sync and hung flags of the unit status register. The snapshot and the mask are
 *                held by the destination of the handshake until the frame engine takes them; the
 *                handshake is acknowledged only after the take.
 * Decisions    : DEC-006, DEC-008, DEC-015, DEC-018, ASM-017, REQ-CDC-002, REQ-CDC-003, INV-007,
 *                CDC-003..CDC-007
 */
`timescale 1ns/1ps

module m_vlsit_i2s_cfgsync #(
  // Parameter Description: synchronizer stages of the handshake and level crossings (cell type
  // of the library synchronizer).
  // Parameter values: 2 or 3; default is 2.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_SYNC_DEPTH = 2,
  localparam logic [31:0] LPARA_SNAP_W   = 32'd101,
  localparam logic [31:0] LPARA_MASK_W   = 32'd32,
  localparam logic [31:0] LPARA_EVT_W    = 32'd4,
  localparam logic [31:0] LPARA_REQ_EVT_W = 32'd2,
  localparam logic [31:0] LPARA_EVT_TYPE = 32'd2,
  localparam logic [31:0] LPARA_MASK_RST = 32'hFFFFFFFF
) (
  // APB clock domain: clock and reset
  input  wire         i_clk_apb,
  input  wire         i_rst_n_apb,

  // APB clock domain: configuration fields of the unit
  input  wire         i_en,
  input  wire         i_role,
  input  wire         i_shr,
  input  wire         i_shr_block,
  input  wire         i_ondem,
  input  wire         i_auto,
  input  wire         i_tri,
  input  wire  [2:0]  i_fmt,
  input  wire         i_align,
  input  wire         i_pack,
  input  wire  [5:0]  i_nslot,
  input  wire  [5:0]  i_slot_w,
  input  wire  [5:0]  i_data_w,
  input  wire  [5:0]  i_sync_w,
  input  wire         i_fsp,
  input  wire         i_fse,
  input  wire         i_bpol,
  input  wire  [15:0] i_div,
  input  wire  [15:0] i_tmo,
  input  wire  [31:0] i_mask,

  // APB clock domain: requests, flag clear, events and busy
  input  wire         i_flush_req,
  input  wire         i_srst_req,
  input  wire         i_flag_clr,
  output logic [1:0]  o_flag_we,
  output logic [1:0]  o_flag_wdata,
  output logic [3:0]  o_ev_apb,
  output logic        o_busy,

  // Master clock domain: clock and reset
  input  wire         i_clk_mclk,
  input  wire         i_rst_n_mclk,

  // Master clock domain: requests, level and snapshot handshake with the frame engine
  output logic        o_en_s,
  output logic        o_flush_ev,
  output logic        o_srst_ev,
  input  wire  [3:0]  i_ev_mclk,
  input  wire         i_busy_mclk,
  output logic        o_snap_valid,
  input  wire         i_snap_take,
  output logic        o_mask_valid,
  input  wire         i_mask_take,
  output logic        o_cfg_role,
  output logic        o_cfg_shr,
  output logic        o_cfg_ondem,
  output logic        o_cfg_auto,
  output logic        o_cfg_tri,
  output logic [2:0]  o_cfg_fmt,
  output logic        o_cfg_align,
  output logic        o_cfg_pack,
  output logic [5:0]  o_cfg_nslot,
  output logic [5:0]  o_cfg_slot_w,
  output logic [5:0]  o_cfg_data_w,
  output logic [5:0]  o_cfg_sync_w,
  output logic        o_cfg_fsp,
  output logic        o_cfg_fse,
  output logic        o_cfg_bpol,
  output logic [15:0] o_cfg_div,
  output logic [15:0] o_cfg_tmo,
  output logic [31:0] o_cfg_mask,
  output logic [31:0] o_mask_data
);

  // Internal signal declarations
  logic reg_en_d;
  logic w_shr_eff;
  logic w_en_rise;
  logic reg_snap_pend;
  logic reg_snap_again;
  logic w_snap_ack;
  logic w_snap_idle;
  logic w_snap_set;

  logic [LPARA_SNAP_W-1:0] w_snap_src_data;
  logic [LPARA_SNAP_W-1:0] w_snap_dst_data;
  logic w_snap_req_dst;
  logic reg_snap_taken;
  logic w_snap_ack_dst;

  logic [LPARA_MASK_W-1:0] reg_mask_sent;
  logic reg_mask_pend;
  logic w_mask_ack;
  logic w_mask_idle;
  logic w_mask_set;
  logic w_mask_req_dst;
  logic reg_mask_taken;
  logic w_mask_ack_dst;

  logic [1:0] w_req_ev_src;
  logic [1:0] w_req_ev_dst;
  logic [3:0] w_ev_apb;

  // Enable edge detector (APB domain): the snapshot is sent at the rising edge of the enable bit.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_en_d
    if (!i_rst_n_apb)
      reg_en_d <= 1'b0;
    else
      reg_en_d <= i_en;
  end

  // Rising edge of the enable bit.
  assign w_en_rise = i_en & ~reg_en_d;

  // Snapshot launch control. A request is sent when the handshake is idle: no request pending and
  // no acknowledge still high. An enable edge that comes while the handshake is busy is
  // remembered and sent afterwards, so the last configuration wins.
  assign w_snap_idle = ~reg_snap_pend & ~w_snap_ack;
  assign w_snap_set  = (w_en_rise | reg_snap_again) & w_snap_idle;

  // Pending and again flags: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_snap_pend
    if (!i_rst_n_apb) begin
      reg_snap_pend  <= 1'b0;
      reg_snap_again <= 1'b0;
    end else begin
      if (w_snap_set)
        reg_snap_pend <= 1'b1;
      else if (w_snap_ack)
        reg_snap_pend <= 1'b0;
      if (w_snap_set)
        reg_snap_again <= 1'b0;
      else if (w_en_rise)
        reg_snap_again <= 1'b1;
    end
  end

  // Shared clock: ignored when the other unit also asks for it (ERR-009, the transmitter follows
  // its own clock).
  assign w_shr_eff = i_shr & ~i_shr_block;

  // Snapshot payload, packed in the order: role, shr, ondem, auto, tri, fmt, align, pack, nslot,
  // slot_w, data_w, sync_w, fsp, fse, bpol, div, tmo, mask (least significant first).
  assign w_snap_src_data = {i_mask, i_tmo, i_div, i_bpol, i_fse, i_fsp, i_sync_w, i_data_w,
                            i_slot_w, i_nslot, i_pack, i_align, i_fmt, i_tri, i_auto, i_ondem,
                            w_shr_eff, i_role};

  // Four-phase handshake of the snapshot: source in the APB domain, destination (captured mode)
  // in the master domain.
  m_vlsit_ahs4_top #(
    .PARA_AHS4_DATA_W        (LPARA_SNAP_W),
    .PARA_AHS4_SYNC_TYPE     (PARA_I2S_SYNC_DEPTH),
    .PARA_AHS4_DST_MODE      (32'd1),
    .PARA_AHS4_ACK_DATA_MODE (32'd0)
  ) u_ahs4_snap (
    .i_clk_src   (i_clk_apb),
    .i_rst_n_src (i_rst_n_apb),
    .i_req       (reg_snap_pend),
    .i_data      (w_snap_src_data),
    .o_ack       (w_snap_ack),
    .o_ack_data  (),
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_dst (i_rst_n_mclk),
    .o_req       (w_snap_req_dst),
    .o_data      (w_snap_dst_data),
    .i_ack       (w_snap_ack_dst),
    .i_ack_data  ({LPARA_SNAP_W{1'b0}})
  );

  // Destination acknowledge: raised when the frame engine takes the snapshot and held until the
  // request falls, so the source sees one clean four-phase cycle.
  assign w_snap_ack_dst = w_snap_req_dst & (i_snap_take | reg_snap_taken);

  // Taken flag: control state of the master domain, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_snap_taken
    if (!i_rst_n_mclk)
      reg_snap_taken <= 1'b0;
    else
      reg_snap_taken <= w_snap_ack_dst;
  end

  // Output mapping of the snapshot: the valid flag and the unpacked fields.
  assign o_snap_valid = w_snap_req_dst & ~reg_snap_taken;
  assign {o_cfg_mask, o_cfg_tmo, o_cfg_div, o_cfg_bpol, o_cfg_fse, o_cfg_fsp, o_cfg_sync_w,
          o_cfg_data_w, o_cfg_slot_w, o_cfg_nslot, o_cfg_pack, o_cfg_align, o_cfg_fmt, o_cfg_tri,
          o_cfg_auto, o_cfg_ondem, o_cfg_shr, o_cfg_role} = w_snap_dst_data;

  // Mask launch control: a request is sent when the mask register differs from the last sent
  // value and the handshake is idle. The sent value is the payload.
  assign w_mask_idle = ~reg_mask_pend & ~w_mask_ack;
  assign w_mask_set  = w_mask_idle & (i_mask != reg_mask_sent);

  // Last sent mask and pending flag: control state, asynchronously reset to the register reset.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_mask_sent
    if (!i_rst_n_apb) begin
      reg_mask_sent <= LPARA_MASK_RST;
      reg_mask_pend <= 1'b0;
    end else begin
      if (w_mask_set)
        reg_mask_sent <= i_mask;
      if (w_mask_set)
        reg_mask_pend <= 1'b1;
      else if (w_mask_ack)
        reg_mask_pend <= 1'b0;
    end
  end

  // Four-phase handshake of the slot mask.
  m_vlsit_ahs4_top #(
    .PARA_AHS4_DATA_W        (LPARA_MASK_W),
    .PARA_AHS4_SYNC_TYPE     (PARA_I2S_SYNC_DEPTH),
    .PARA_AHS4_DST_MODE      (32'd1),
    .PARA_AHS4_ACK_DATA_MODE (32'd0)
  ) u_ahs4_mask (
    .i_clk_src   (i_clk_apb),
    .i_rst_n_src (i_rst_n_apb),
    .i_req       (reg_mask_pend),
    .i_data      (reg_mask_sent),
    .o_ack       (w_mask_ack),
    .o_ack_data  (),
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_dst (i_rst_n_mclk),
    .o_req       (w_mask_req_dst),
    .o_data      (o_mask_data),
    .i_ack       (w_mask_ack_dst),
    .i_ack_data  ({LPARA_MASK_W{1'b0}})
  );

  // Destination acknowledge of the mask: raised when the frame engine takes the mask at a frame
  // boundary and held until the request falls.
  assign w_mask_ack_dst = w_mask_req_dst & (i_mask_take | reg_mask_taken);

  // Taken flag of the mask: control state of the master domain, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_mask_taken
    if (!i_rst_n_mclk)
      reg_mask_taken <= 1'b0;
    else
      reg_mask_taken <= w_mask_ack_dst;
  end

  // The mask is offered to the frame engine until it is taken.
  assign o_mask_valid = w_mask_req_dst & ~reg_mask_taken;

  // Enable level to the master domain: library synchronizer, reset to 0.
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH)
  ) u_sync_en (
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_dst (i_rst_n_mclk),
    .i_d         (i_en),
    .o_q         (o_en_s)
  );

  // Busy level to the APB domain: library synchronizer, reset to 0.
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH)
  ) u_sync_busy (
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_d         (i_busy_mclk),
    .o_q         (o_busy)
  );

  // Flush and soft reset requests to the master domain: two event bits.
  assign w_req_ev_src = {i_srst_req, i_flush_req};

  m_vlsit_event_sync #(
    .PARA_EVENT_SYNC_W         (LPARA_REQ_EVT_W),
    .PARA_EVENT_SYNC_CELL_TYPE (LPARA_EVT_TYPE)
  ) u_event_req (
    .i_clk_src   (i_clk_apb),
    .i_rst_n_src (i_rst_n_apb),
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_dst (i_rst_n_mclk),
    .i_event_src (w_req_ev_src),
    .o_event_dst (w_req_ev_dst)
  );

  // Flush and soft reset events in the master domain.
  assign o_flush_ev = w_req_ev_dst[0];
  assign o_srst_ev  = w_req_ev_dst[1];

  // Unit events to the APB domain: underrun or overrun, sync error, hung clock, frame done.
  m_vlsit_event_sync #(
    .PARA_EVENT_SYNC_W         (LPARA_EVT_W),
    .PARA_EVENT_SYNC_CELL_TYPE (LPARA_EVT_TYPE)
  ) u_event_unit (
    .i_clk_src   (i_clk_mclk),
    .i_rst_n_src (i_rst_n_mclk),
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_dst (i_rst_n_apb),
    .i_event_src (i_ev_mclk),
    .o_event_dst (w_ev_apb)
  );

  // Output mapping of the unit events in the APB domain.
  assign o_ev_apb = w_ev_apb;

  // Hardware load of the sync and hung flags: an event sets the flag, the soft reset clears it.
  assign o_flag_we    = {w_ev_apb[2] | i_flag_clr, w_ev_apb[1] | i_flag_clr};
  assign o_flag_wdata = {w_ev_apb[2], w_ev_apb[1]};

endmodule
