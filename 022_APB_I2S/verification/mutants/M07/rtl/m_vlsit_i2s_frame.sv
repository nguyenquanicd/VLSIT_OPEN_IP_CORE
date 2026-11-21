/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Frame engine of one unit, master clock domain (the top instantiates it once for
 *                transmit and once for receive). It holds the configuration snapshot, the bit clock
 *                (a divider in master mode; the synchronized pin or the other unit's clock in slave
 *                and shared-clock mode; the bit clock is never a flop clock), the launch and sample
 *                ticks, the slot and bit counters, the frame sync generation and checks, the hung
 *                clock timer and the run FSM frame (OFF, ARM, RUN, ERR, STOP). One launch tick is
 *                one bit time; all serial logic runs on the master clock with ticks. The frame sync
 *                leads the data by one bit for the early formats: the decision to continue is taken
 *                at the tick that launches the last bit of a frame. The module gives the serializer
 *                the launch description of the next bit, and the deserializer the sample context of
 *                the current bit. A master delays the sample tick and its context by the
 *                synchronizer depth to match the synchronized data inputs.
 * Decisions    : DEC-005, DEC-006, ASM-009, ASM-014, ASM-016, ASM-018, REQ-FUNC-002..REQ-FUNC-027,
 *                INV-001, INV-005, INV-007, OP-001..OP-010
 */
`timescale 1ns/1ps

module m_vlsit_i2s_frame #(
  // Parameter Description: synchronizer stages of the pin inputs; also the sample delay of a
  // master.
  // Parameter values: 2 or 3; default is 2.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_SYNC_DEPTH = 2,
  // Parameter Description: bit clock divider and master role built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_MASTER_EN = 1,
  // Parameter Description: formats other than Philips and more than 2 slots built in. With 0 the
  // format is the Philips frame with 2 slots.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_FMT_EXT_EN = 1,
  // Parameter Description: 16-bit packing built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_PACK_EN = 1,
  // Parameter Description: on-demand frame start built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_ONDEM_EN = 1,
  // Parameter Description: hung clock timer built in.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_HUNG_EN = 1,
  // Parameter Description: largest number of slots of a frame.
  // Parameter values: 2 to 32; default is 32.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_MAX_SLOTS = 32,
  localparam logic [31:0] LPARA_PIPE_W = PARA_I2S_SYNC_DEPTH,
  localparam logic [31:0] LPARA_CTX_W  = 32'd5,
  localparam logic [31:0] LPARA_CELL_RN = 32'd0,
  localparam logic [31:0] LPARA_FMT_CUSTOM = 32'd0,
  localparam logic [31:0] LPARA_FMT_I2S = 32'd1,
  localparam logic [31:0] LPARA_FMT_LJ = 32'd2,
  localparam logic [31:0] LPARA_FMT_PCMS = 32'd3,
  localparam logic [31:0] LPARA_FMT_PCML = 32'd4,
  localparam logic [31:0] LPARA_FMT_TDM = 32'd5,
  localparam logic [31:0] LPARA_NSLOT_I2S = 32'd2,
  localparam logic [31:0] LPARA_ONE_6 = 32'd1,
  localparam logic [31:0] LPARA_RST_SLOT_W = 32'd32,
  localparam logic [31:0] LPARA_RST_DIV = 32'd2
) (
  // Clock and reset
  input  wire         i_clk_mclk,
  input  wire         i_rst_n_mclk,

  // Snapshot and mask from the configuration crossing, and the take handshake
  input  wire         i_snap_valid,
  output logic        o_snap_take,
  input  wire         i_mask_valid,
  output logic        o_mask_take,
  input  wire         i_cfg_role,
  input  wire         i_cfg_shr,
  input  wire         i_cfg_ondem,
  input  wire         i_cfg_auto,
  input  wire         i_cfg_tri,
  input  wire  [2:0]  i_cfg_fmt,
  input  wire         i_cfg_align,
  input  wire         i_cfg_pack,
  input  wire  [5:0]  i_cfg_nslot,
  input  wire  [5:0]  i_cfg_slot_w,
  input  wire  [5:0]  i_cfg_data_w,
  input  wire  [5:0]  i_cfg_sync_w,
  input  wire         i_cfg_fsp,
  input  wire         i_cfg_fse,
  input  wire         i_cfg_bpol,
  input  wire  [15:0] i_cfg_div,
  input  wire  [15:0] i_cfg_tmo,
  input  wire  [31:0] i_cfg_mask,
  input  wire  [31:0] i_mask_data,

  // Run control from the register block (synchronized enable, flush and soft reset events)
  input  wire         i_en,
  input  wire         i_flush_ev,
  input  wire         i_srst_ev,

  // Pins: own bit clock and frame sync, and the clock of the other unit for the shared option
  input  wire         i_bclk_pin,
  input  wire         i_ws_pin,
  output logic        o_bclk,
  output logic        o_bclk_oe,
  output logic        o_ws,
  output logic        o_ws_oe,
  input  wire         i_oth_bclk,
  input  wire         i_oth_ws,
  output logic        o_eff_bclk,
  output logic        o_eff_ws,

  // FIFO coordination: ready check of a whole frame and the words per frame of each line
  input  wire         i_fifo_ok,
  output logic [5:0]  o_words_pf,

  // Error pulse from the serializer or the deserializer (underrun or overrun)
  input  wire         i_err,

  // Registered configuration for the serializer and the deserializer
  output logic [5:0]  o_data_w,
  output logic        o_align,
  output logic        o_pack,
  output logic        o_tri,
  output logic        o_on,

  // Launch description of the next bit (serializer): valid in the cycle of o_tick_l
  output logic        o_tick_l,
  output logic        o_nx_active,
  output logic        o_nx_slot_start,
  output logic        o_nx_slot_en,
  output logic        o_nx_bit_vld,
  output logic        o_nx_pack_hi,

  // Sample context of the current bit (deserializer): valid in the cycle of o_tick_s
  output logic        o_tick_s,
  output logic        o_smp_active,
  output logic        o_smp_slot_en,
  output logic        o_smp_bit_vld,
  output logic        o_smp_last,
  output logic        o_smp_pack_hi,

  // Events and status: sync error, hung clock, frame done (one-cycle pulses) and busy
  output logic        o_ev_sync,
  output logic        o_ev_hung,
  output logic        o_ev_frm,
  output logic        o_busy
);

  // FSM states of frame: OFF is stopped, ARM runs the clock and waits for a frame start, RUN
  // sends or receives a frame, ERR waits for a flush after an error with auto restart off, STOP
  // finishes the running frame after the enable was cleared. Encodings 5 to 7 are unused and
  // recover to ENUM_ST_OFF.
  typedef enum logic [2:0] {
    ENUM_ST_OFF  = 3'd0,
    ENUM_ST_ARM  = 3'd1,
    ENUM_ST_RUN  = 3'd2,
    ENUM_ST_ERR  = 3'd3,
    ENUM_ST_STOP = 3'd4
  } frame_state_type_def;

  // Internal signal declarations: state and snapshot
  frame_state_type_def reg_fsm_frame_current_state;
  frame_state_type_def w_fsm_frame_nxt_state;
  frame_state_type_def w_state_pre;
  logic reg_role, reg_shr, reg_ondem, reg_auto, reg_tri, reg_align, reg_pack, reg_fsp, reg_fse;
  logic reg_bpol;
  logic [2:0]  reg_fmt;
  logic [5:0]  reg_nslot, reg_slot_w, reg_data_w, reg_sync_w;
  logic [15:0] reg_div, reg_tmo;
  logic [31:0] reg_mask;
  logic [31:0] w_mask_nx;
  logic [31:0] w_mask_eff;

  // Internal signal declarations: derived configuration
  logic [2:0] w_fmt;
  logic [5:0] w_nslot;
  logic [5:0] w_last_slot_idx;
  logic [5:0] w_last_bit_idx;
  logic w_early;
  logic w_ws_lvl_act;
  logic w_pack;
  logic w_master;

  // Internal signal declarations: clock, ticks and pins
  logic [15:0] reg_div_cnt;
  logic [15:0] w_div_m1;
  logic w_master_run;
  logic w_toggle;
  logic reg_mbclk;
  logic w_mbclk_nxt;
  logic w_tick_l_m;
  logic w_tick_s_m;
  logic w_bclk_pin_s;
  logic w_ws_pin_s;
  logic w_src_bclk;
  logic w_src_ws;
  logic reg_src_bclk_d;
  logic w_bclk_edge;
  logic w_tick_l_s;
  logic w_tick_s_s;
  logic w_tick_l;
  logic w_tick_s_sel;
  logic reg_tick_l_d;
  logic [LPARA_PIPE_W-1:0] reg_tsmp_pipe;
  logic [LPARA_PIPE_W-1:0] reg_bclk_pipe;
  logic [LPARA_PIPE_W-1:0] reg_ws_pipe;
  logic [LPARA_PIPE_W*LPARA_CTX_W-1:0] reg_ctx_pipe;
  logic [LPARA_CTX_W-1:0] w_cur_ctx;
  logic [LPARA_CTX_W-1:0] w_smp_ctx;
  logic reg_ws;
  logic w_ws_nxt;
  logic reg_bclk_oe;
  logic reg_ws_oe;
  logic reg_busy;

  // Internal signal declarations: position, frame and checks
  logic [5:0] reg_slot, w_slot_nxt;
  logic [5:0] reg_bit, w_bit_nxt;
  logic reg_pre, w_pre_nxt;
  logic reg_commit, w_commit_nxt;
  logic reg_rec, w_rec_nxt;
  logic reg_pack_hi, w_pack_hi_nxt;
  logic reg_pack_par, w_pack_par_nxt;
  logic w_par_base;
  logic w_last_bit;
  logic w_last_slot;
  logic w_at_end;
  logic w_launch;
  logic w_run_like;
  logic w_started;
  logic w_wrapped;
  logic w_cont_ok;
  logic w_go_now;
  logic w_need_ready;
  logic w_ready_ok;
  logic w_start_m;
  logic w_start_s;
  logic w_late_s;
  logic w_mask_take_c;
  logic w_snap_take_c;
  logic w_cfg_load;
  logic [5:0] w_en_cnt;
  logic [5:0] w_words;

  logic reg_ws_lvl_d;
  logic w_ws_act_lvl;
  logic w_ws_edge;
  logic reg_ws_pend;
  logic reg_edge_q;
  logic reg_act_win;
  logic reg_act_win_d;
  logic reg_act_seen;
  logic reg_win_open_d;
  logic reg_start_d;
  logic w_win_open;
  logic w_nx_is_last;
  logic w_nx_is_first;
  logic w_miss;
  logic w_unexp;
  logic w_seen_eff;
  logic w_frm_ev_c;
  logic reg_ev_sync;
  logic reg_ev_hung;
  logic reg_ev_frm;

  logic [7:0] reg_tmo_pre;
  logic [15:0] reg_tmo_cnt;
  logic reg_hung_lat;
  logic w_hung_pulse;
  logic w_activity;
  logic [5:0] w_ws_slot;
  logic [5:0] w_ws_bit;
  logic w_ws_wrap;
  logic w_ws_in_act;
  logic w_err_run;

  // Derived configuration: forced Philips frame without the extended-format feature, slot count
  // limited to the build, early frame sync from the format, active level of the frame sync.
  assign w_fmt = (PARA_I2S_FMT_EXT_EN != 32'd0) ? reg_fmt : LPARA_FMT_I2S[2:0];
  assign w_nslot = (PARA_I2S_FMT_EXT_EN == 32'd0) ? LPARA_NSLOT_I2S[5:0] :
                   ({26'd0, reg_nslot} > PARA_I2S_MAX_SLOTS) ? PARA_I2S_MAX_SLOTS[5:0] : reg_nslot;
  // Index of the last slot and of the last bit of a slot.
  assign w_last_slot_idx = w_nslot - LPARA_ONE_6[5:0];
  assign w_last_bit_idx  = reg_slot_w - 6'd1;
  assign w_pack   = (PARA_I2S_PACK_EN != 32'd0) & reg_pack;
  assign w_master = (PARA_I2S_MASTER_EN != 32'd0) & reg_role & ~reg_shr;

  // Format decode: the early flag and the active level of the frame sync. Formats: 0 custom, 1
  // Philips, 2 left-justified, 3 PCM short, 4 PCM long, 5 TDM; reserved values act as Philips.
  always_comb begin : p_com_fmt
    w_early      = 1'b1;
    w_ws_lvl_act = 1'b0;
    case (w_fmt)
      LPARA_FMT_CUSTOM[2:0]: begin w_early = reg_fse; w_ws_lvl_act = ~reg_fsp; end
      LPARA_FMT_I2S[2:0]:    begin w_early = 1'b1;    w_ws_lvl_act = 1'b0;     end
      LPARA_FMT_LJ[2:0]:     begin w_early = 1'b0;    w_ws_lvl_act = 1'b0;     end
      LPARA_FMT_PCMS[2:0]:   begin w_early = 1'b1;    w_ws_lvl_act = 1'b1;     end
      LPARA_FMT_PCML[2:0]:   begin w_early = 1'b0;    w_ws_lvl_act = 1'b1;     end
      LPARA_FMT_TDM[2:0]:    begin w_early = 1'b1;    w_ws_lvl_act = 1'b1;     end
      default: begin w_early = 1'b1;    w_ws_lvl_act = 1'b0;     end
    endcase
  end

  // Position flags of the current bit.
  assign w_last_bit  = (reg_bit == w_last_bit_idx);
  assign w_last_slot = (reg_slot == w_last_slot_idx);
  assign w_at_end    = w_last_bit & w_last_slot;
  assign w_run_like  = (reg_fsm_frame_current_state == ENUM_ST_RUN) |
                       (reg_fsm_frame_current_state == ENUM_ST_STOP);

  // Mask of the next frame (a pending mask is taken at the frame boundary) and the number of
  // enabled slots in it; with packing two enabled slots share one word.
  assign w_mask_nx = i_mask_valid ? i_mask_data : reg_mask;

  // Count of the enabled slots of the next frame, in the range of the slot count.
  always_comb begin : p_com_words
    w_en_cnt = 6'd0;
    for (int idx = 0; idx < 32; idx++) begin
      if (w_mask_nx[idx] && (idx < w_nslot))
        w_en_cnt = w_en_cnt + 6'd1;
    end
    w_words = w_pack ? ((w_en_cnt + 6'd1) >> 1) : w_en_cnt;
  end

  // Words per line and frame, for the ready check of the FIFO.
  assign o_words_pf = w_words;

  // Pin synchronizers of the bit clock and the frame sync (slave and shared-clock inputs).
  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (LPARA_CELL_RN),
    .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH)
  ) u_sync_bclk (
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_dst (i_rst_n_mclk),
    .i_d         (i_bclk_pin),
    .o_q         (w_bclk_pin_s)
  );

  m_vlsit_afifo_cell_sync #(
    .PARA_AFIFO_CELL_RST_VAL (LPARA_CELL_RN),
    .PARA_AFIFO_CELL_TYPE    (PARA_I2S_SYNC_DEPTH)
  ) u_sync_ws (
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_dst (i_rst_n_mclk),
    .i_d         (i_ws_pin),
    .o_q         (w_ws_pin_s)
  );

  // Clock source of a slave or shared-clock unit: the synchronized pin or the other unit's clock.
  assign w_src_bclk = reg_shr ? i_oth_bclk : w_bclk_pin_s;
  assign w_src_ws   = reg_shr ? i_oth_ws   : w_ws_pin_s;

  // Bit clock divider of a master: counts master clock cycles per half period while running.
  assign w_div_m1 = reg_div;
  assign w_master_run = w_master & (reg_fsm_frame_current_state != ENUM_ST_OFF);
  assign w_toggle = w_master_run & (reg_div_cnt == w_div_m1);
  assign w_mbclk_nxt = ~reg_mbclk;

  // Ticks of a master: launch at the edge that changes the clock to the launch level (the bit
  // clock polarity), sample at the other edge.
  assign w_tick_l_m = w_toggle & (w_mbclk_nxt == reg_bpol);
  assign w_tick_s_m = w_toggle & (w_mbclk_nxt != reg_bpol);

  // Ticks of a slave or shared-clock unit: edges of the synchronized clock.
  assign w_bclk_edge = w_src_bclk ^ reg_src_bclk_d;
  assign w_tick_l_s  = w_bclk_edge & (w_src_bclk == reg_bpol);
  assign w_tick_s_s  = w_bclk_edge & (w_src_bclk != reg_bpol);

  // Selected ticks: a master delays the sample tick by the synchronizer depth.
  assign w_tick_l     = w_master ? w_tick_l_m : w_tick_l_s;
  assign w_tick_s_sel = w_master ? reg_tsmp_pipe[LPARA_PIPE_W-1] : w_tick_s_s;

  // Divider counter and the master bit clock: idle at the launch level while OFF.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_div
    if (!i_rst_n_mclk) begin
      reg_div_cnt <= 16'd0;
      reg_mbclk   <= 1'b0;
    end else if (!w_master_run) begin
      reg_div_cnt <= 16'd0;
      reg_mbclk   <= reg_bpol;
    end else begin
      reg_div_cnt <= w_toggle ? 16'd0 : (reg_div_cnt + 16'd1);
      reg_mbclk   <= w_toggle ? w_mbclk_nxt : reg_mbclk;
    end
  end

  // Clock history and delay pipelines (control state, reset to 0): the source clock for the edge
  // detector, the previous launch tick, and the delayed sample tick, bit clock and frame sync of
  // a master, aligned with the synchronized data inputs.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_pipe
    if (!i_rst_n_mclk) begin
      reg_src_bclk_d <= 1'b0;
      reg_tick_l_d   <= 1'b0;
      reg_tsmp_pipe  <= '0;
      reg_bclk_pipe  <= '0;
      reg_ws_pipe    <= '0;
      reg_ctx_pipe   <= '0;
    end else begin
      reg_src_bclk_d <= w_src_bclk;
      reg_tick_l_d   <= w_tick_l;
      reg_tsmp_pipe  <= {reg_tsmp_pipe[LPARA_PIPE_W-2:0], w_tick_s_m};
      reg_bclk_pipe  <= {reg_bclk_pipe[LPARA_PIPE_W-2:0], reg_mbclk};
      reg_ws_pipe    <= {reg_ws_pipe[LPARA_PIPE_W-2:0], reg_ws};
      reg_ctx_pipe   <= {reg_ctx_pipe[(LPARA_PIPE_W-1)*LPARA_CTX_W-1:0], w_cur_ctx};
    end
  end

  // Sample context of the current bit: active, slot enabled, bit inside the data width, last
  // data bit, packing half. A master takes the context that was current at the undelayed tick.
  assign w_cur_ctx = {w_run_like & ~reg_pre, reg_mask[reg_slot[4:0]], (reg_bit < reg_data_w),
                      (reg_bit == (reg_data_w - 6'd1)), reg_pack_hi};
  // Context of the sample tick: delayed for a master, direct for a slave.
  assign w_smp_ctx = w_master ? reg_ctx_pipe[(LPARA_PIPE_W-1)*LPARA_CTX_W +: LPARA_CTX_W]
                              : w_cur_ctx;

  // Output mapping of the sample context.
  assign {o_smp_active, o_smp_slot_en, o_smp_bit_vld, o_smp_last, o_smp_pack_hi} = w_smp_ctx;
  assign o_tick_s = w_tick_s_sel;

  // Frame sync level seen on the source (slave) and its active edge.
  assign w_ws_act_lvl = (w_src_ws == w_ws_lvl_act);
  assign w_ws_edge    = w_ws_act_lvl & ~reg_ws_lvl_d;

  // Frame sync position of the bit that is launched now: the frame sync leads the data by one bit
  // for the early formats; the position after the last bit of the last slot wraps to the next
  // frame, where the continue decision decides the level.
  always_comb begin : p_com_ws_pos
    w_ws_slot = w_slot_nxt;
    w_ws_bit  = w_bit_nxt;
    w_ws_wrap = 1'b0;
    if (w_early) begin
      if (w_bit_nxt != w_last_bit_idx) begin
        w_ws_bit = w_bit_nxt + 6'd1;
      end else if (w_slot_nxt != w_last_slot_idx) begin
        w_ws_slot = w_slot_nxt + 6'd1;
        w_ws_bit  = 6'd0;
      end else begin
        w_ws_slot = 6'd0;
        w_ws_bit  = 6'd0;
        w_ws_wrap = 1'b1;
      end
    end
  end

  // Frame sync shape: active inside the window of the format.
  always_comb begin : p_com_ws_shape
    w_ws_in_act = 1'b0;
    case (w_fmt)
      LPARA_FMT_CUSTOM[2:0]: w_ws_in_act = (w_ws_slot == 6'd0) & (w_ws_bit < reg_sync_w);
      LPARA_FMT_PCMS[2:0]:   w_ws_in_act = (w_ws_slot == 6'd0) & (w_ws_bit == 6'd0);
      LPARA_FMT_PCML[2:0]:   w_ws_in_act = (w_ws_slot == 6'd0);
      LPARA_FMT_TDM[2:0]:    w_ws_in_act = (w_ws_slot == 6'd0) & (w_ws_bit == 6'd0);
      default: w_ws_in_act = (w_ws_slot < (w_nslot >> 1));
    endcase
  end

  // Readiness of the FIFO for the next frame: needed after an error with auto restart and for the
  // on-demand start of a master. The decision to go for a frame needs the enable.
  assign w_need_ready = reg_rec | (w_master & reg_ondem & (PARA_I2S_ONDEM_EN != 32'd0));
  assign w_ready_ok   = ~w_need_ready | i_fifo_ok;
  assign w_go_now     = i_en & w_ready_ok;

  // Start of a frame: a master at a launch tick, a slave at the active edge of the frame sync
  // (with the launch tick of the same bit; one cycle of skew is tolerated).
  assign w_start_m = w_master & w_tick_l & w_go_now;
  assign w_start_s = ~w_master & i_en & w_ready_ok &
                     (reg_fsm_frame_current_state == ENUM_ST_ARM) &
                     ((w_ws_edge & (w_tick_l | reg_tick_l_d)) | (reg_ws_pend & w_tick_l));
  // A slave start by the frame sync edge alone, one cycle after its tick.
  assign w_late_s  = w_start_s & ~w_tick_l;

  // Launch event: a tick, or a slave start by the frame sync edge alone.
  assign w_launch = w_tick_l | w_late_s;

  // Continue decision at the end of a frame: a master follows the commit taken one bit earlier
  // (early formats) or the decision of this tick (late formats); a slave continues unless the
  // frame sync was missed.
  assign w_cont_ok = w_master ? (w_early ? reg_commit : w_go_now) : ~w_miss;

  // Frame sync window and checks of a slave: the active edge is expected in the bit that follows
  // the launch tick of the window position. A missing edge or an edge outside the window is a
  // sync error; an unexpected edge is ignored.
  assign w_nx_is_last  = (w_slot_nxt == w_last_slot_idx) & (w_bit_nxt == w_last_bit_idx);
  assign w_nx_is_first = (w_slot_nxt == 6'd0) & (w_bit_nxt == 6'd0);
  assign w_win_open    = w_launch & w_run_like & (w_early ? w_nx_is_last : w_nx_is_first);
  assign w_seen_eff = reg_act_seen | w_ws_edge;
  assign w_miss     = ~w_master & w_launch & reg_act_win & ~w_seen_eff & w_run_like;
  assign w_unexp    = ~w_master & reg_edge_q & ~reg_act_win_d & ~reg_win_open_d & ~w_win_open &
                      ~reg_start_d & w_run_like;

  // Position and state: next-value logic of the frame FSM and the counters.
  always_comb begin : p_com_frame
    w_state_pre = reg_fsm_frame_current_state;
    w_slot_nxt     = reg_slot;
    w_bit_nxt      = reg_bit;
    w_pre_nxt      = reg_pre;
    w_commit_nxt   = reg_commit;
    w_rec_nxt      = reg_rec;
    w_started      = 1'b0;
    w_wrapped      = 1'b0;
    w_snap_take_c  = 1'b0;
    w_cfg_load     = 1'b0;
    w_mask_take_c  = 1'b0;
    w_err_run      = 1'b0;
    case (reg_fsm_frame_current_state)
      ENUM_ST_OFF: begin
        if (i_snap_valid) begin
          w_snap_take_c = 1'b1;
          w_cfg_load    = 1'b1;
          w_state_pre = ENUM_ST_ARM;
        end
        w_mask_take_c = i_mask_valid;
      end
      ENUM_ST_ARM: begin
        w_mask_take_c = i_mask_valid;
        if (!i_en && (w_tick_l || !w_master)) begin
          w_state_pre = ENUM_ST_OFF;
          w_rec_nxt = 1'b0;
        end else if (w_start_m || w_start_s) begin
          w_state_pre = ENUM_ST_RUN;
          w_started    = 1'b1;
          w_rec_nxt    = 1'b0;
          w_pre_nxt    = w_early;
          w_commit_nxt = 1'b1;
          w_slot_nxt   = w_early ? w_last_slot_idx : 6'd0;
          w_bit_nxt    = w_early ? w_last_bit_idx : 6'd0;
          w_mask_take_c = i_mask_valid;
        end
      end
      ENUM_ST_RUN, ENUM_ST_STOP: begin
        if (w_launch) begin
          w_commit_nxt = w_go_now;
          if (reg_pre) begin
            w_pre_nxt  = 1'b0;
            w_slot_nxt = 6'd0;
            w_bit_nxt  = 6'd0;
          end else if (!w_at_end) begin
            if (!w_last_bit) begin
              w_bit_nxt = reg_bit + 6'd1;
            end else begin
              w_bit_nxt  = 6'd0;
              w_slot_nxt = reg_slot + 6'd1;
            end
          end else begin
            w_wrapped = 1'b1;
            if (reg_fsm_frame_current_state == ENUM_ST_STOP) begin
              w_state_pre = ENUM_ST_OFF;
            end else if (w_cont_ok && i_en) begin
              w_slot_nxt = 6'd0;
              w_bit_nxt  = 6'd0;
              w_mask_take_c = i_mask_valid;
            end else begin
              w_state_pre = ENUM_ST_ARM;
            end
          end
          if (w_miss)
            w_state_pre = ENUM_ST_ARM;
        end
        if (!i_en && (w_state_pre == ENUM_ST_RUN))
          w_state_pre = ENUM_ST_STOP;
        w_err_run = i_err & (reg_fsm_frame_current_state == ENUM_ST_RUN);
      end
      ENUM_ST_ERR: begin
        w_mask_take_c = i_mask_valid;
        if (!i_en && (w_tick_l || !w_master)) begin
          w_state_pre = ENUM_ST_OFF;
          w_rec_nxt = 1'b0;
        end else if (i_flush_ev) begin
          w_state_pre = ENUM_ST_ARM;
          w_rec_nxt = 1'b0;
        end
      end
      default: w_state_pre = ENUM_ST_OFF;
    endcase
    // Soft reset: back to ARM (or OFF when disabled) with the configuration kept.
    if (i_srst_ev) begin
      w_state_pre = i_en ? ENUM_ST_ARM : ENUM_ST_OFF;
      w_rec_nxt    = 1'b0;
      w_pre_nxt    = 1'b0;
      w_started    = 1'b0;
      w_wrapped    = 1'b0;
      w_err_run    = 1'b0;
    end
    // An underrun or overrun in a running frame stops it: restart at a frame boundary with auto
    // restart, wait for a flush otherwise. The error does not change the launch description of the
    // same tick, which keeps the serializer and the engine free of a combinational loop.
    w_fsm_frame_nxt_state = w_state_pre;
    if (w_err_run) begin
      w_fsm_frame_nxt_state = reg_auto ? ENUM_ST_ARM : ENUM_ST_ERR;
      w_rec_nxt = reg_auto;
    end
  end

  // Next launch description. The mask of the new frame applies at the frame boundary. Packing
  // phase: the first enabled slot of a frame uses the low half, then the halves alternate.
  assign o_nx_slot_start = (w_bit_nxt == 6'd0);
  assign o_nx_bit_vld    = (w_bit_nxt < reg_data_w);
  assign w_mask_eff      = w_mask_take_c ? i_mask_data : reg_mask;
  assign o_nx_slot_en    = w_mask_eff[w_slot_nxt[4:0]];
  assign o_nx_active     = w_launch & ((w_state_pre == ENUM_ST_RUN) |
                           (w_state_pre == ENUM_ST_STOP)) & ~w_pre_nxt;
  // Output mapping of the packing half of the next slot.
  assign o_nx_pack_hi    = w_pack_hi_nxt;

  // Packing phase: the first enabled slot of a frame uses the low half, then the halves alternate.
  always_comb begin : p_com_pack
    w_par_base     = (w_nx_is_first & w_launch) ? 1'b0 : reg_pack_par;
    w_pack_hi_nxt  = reg_pack_hi;
    w_pack_par_nxt = w_par_base;
    if (o_nx_active && o_nx_slot_start && o_nx_slot_en) begin
      w_pack_hi_nxt  = w_par_base;
      w_pack_par_nxt = ~w_par_base;
    end
  end

  // Frame sync to launch: active inside the window of the format, or the commit decision at the
  // wrap position; inactive when the engine is not running a frame.
  assign w_ws_nxt = (((w_state_pre == ENUM_ST_RUN) |
                      (w_state_pre == ENUM_ST_STOP)) &
                     (w_ws_wrap ? (w_pre_nxt | w_go_now) : w_ws_in_act));

  // Current state of the frame FSM: control state, asynchronously reset to OFF.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_fsm_frame
    if (!i_rst_n_mclk)
      reg_fsm_frame_current_state <= ENUM_ST_OFF;
    else
      reg_fsm_frame_current_state <= w_fsm_frame_nxt_state;
  end

  // Counters and frame flops: control state, asynchronously reset.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_frame
    if (!i_rst_n_mclk) begin
      reg_slot     <= 6'd0;
      reg_bit      <= 6'd0;
      reg_pre      <= 1'b0;
      reg_commit   <= 1'b0;
      reg_rec      <= 1'b0;
      reg_pack_hi  <= 1'b0;
      reg_pack_par <= 1'b0;
      reg_ws       <= 1'b0;
      reg_ws_lvl_d <= 1'b0;
    end else begin
      reg_slot     <= w_slot_nxt;
      reg_bit      <= w_bit_nxt;
      reg_pre      <= w_pre_nxt;
      reg_commit   <= w_commit_nxt;
      reg_rec      <= w_rec_nxt;
      reg_ws_lvl_d <= w_ws_act_lvl;
      if (w_launch) begin
        reg_pack_hi  <= w_pack_hi_nxt;
        reg_pack_par <= w_pack_par_nxt;
      end
      case (reg_fsm_frame_current_state)
        ENUM_ST_OFF:  reg_ws <= 1'b0;
        ENUM_ST_ARM:  reg_ws <= (w_started & w_ws_nxt) ? w_ws_lvl_act : ~w_ws_lvl_act;
        ENUM_ST_ERR:  reg_ws <= ~w_ws_lvl_act;
        default: begin
          if (w_launch)
            reg_ws <= w_ws_nxt ? w_ws_lvl_act : ~w_ws_lvl_act;
        end
      endcase
    end
  end

  // Configuration registers: loaded from the snapshot when the engine takes it. They keep their
  // values through a soft reset. Reset values are those of the default configuration.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_cfg
    if (!i_rst_n_mclk) begin
      reg_role    <= 1'b0;
      reg_shr     <= 1'b0;
      reg_ondem   <= 1'b0;
      reg_auto    <= 1'b0;
      reg_tri     <= 1'b0;
      reg_fmt     <= 3'd1;
      reg_align   <= 1'b0;
      reg_pack    <= 1'b0;
      reg_nslot   <= LPARA_NSLOT_I2S[5:0];
      reg_slot_w  <= LPARA_RST_SLOT_W[5:0];
      reg_data_w  <= LPARA_RST_SLOT_W[5:0];
      reg_sync_w  <= 6'd1;
      reg_fsp     <= 1'b0;
      reg_fse     <= 1'b1;
      reg_bpol    <= 1'b0;
      reg_div     <= LPARA_RST_DIV[15:0];
      reg_tmo     <= 16'd0;
    end else if (w_cfg_load) begin
      reg_role    <= i_cfg_role;
      reg_shr     <= i_cfg_shr;
      reg_ondem   <= i_cfg_ondem;
      reg_auto    <= i_cfg_auto;
      reg_tri     <= i_cfg_tri;
      reg_fmt     <= i_cfg_fmt;
      reg_align   <= i_cfg_align;
      reg_pack    <= i_cfg_pack;
      reg_nslot   <= i_cfg_nslot;
      reg_slot_w  <= i_cfg_slot_w;
      reg_data_w  <= i_cfg_data_w;
      reg_sync_w  <= i_cfg_sync_w;
      reg_fsp     <= i_cfg_fsp;
      reg_fse     <= i_cfg_fse;
      reg_bpol    <= i_cfg_bpol;
      reg_div     <= i_cfg_div;
      reg_tmo     <= i_cfg_tmo;
    end
  end

  // Applied slot mask: the snapshot mask at the start of the unit, a new mask at a frame boundary.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_mask
    if (!i_rst_n_mclk)
      reg_mask <= 32'hFFFFFFFF;
    else if (w_cfg_load)
      reg_mask <= i_cfg_mask;
    else if (w_mask_take_c)
      reg_mask <= i_mask_data;
  end

  // Take handshake outputs.
  assign o_snap_take = w_snap_take_c;
  assign o_mask_take = w_mask_take_c & ~w_cfg_load;

  // Frame sync check state of a slave (control state, reset to 0): pending edge for a start, the
  // delayed edge, the expected-edge window and whether the edge was seen in it.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_win
    if (!i_rst_n_mclk) begin
      reg_ws_pend   <= 1'b0;
      reg_edge_q    <= 1'b0;
      reg_act_win   <= 1'b0;
      reg_act_win_d <= 1'b0;
      reg_act_seen  <= 1'b0;
      reg_start_d   <= 1'b0;
      reg_win_open_d <= 1'b0;
    end else begin
      reg_edge_q    <= w_ws_edge;
      reg_act_win_d <= reg_act_win;
      reg_start_d   <= w_started;
      reg_win_open_d <= w_win_open;
      if (w_tick_l || (reg_fsm_frame_current_state != ENUM_ST_ARM))
        reg_ws_pend <= 1'b0;
      else if (w_ws_edge)
        reg_ws_pend <= 1'b1;
      if (w_started) begin
        reg_act_win  <= ~w_master;
        reg_act_seen <= 1'b1;
      end else if (!w_run_like) begin
        reg_act_win  <= 1'b0;
        reg_act_seen <= 1'b0;
      end else begin
        if (w_launch) begin
          reg_act_win  <= w_win_open;
          reg_act_seen <= w_win_open & (w_ws_edge | reg_edge_q);
        end else if (w_ws_edge) begin
          reg_act_seen <= 1'b1;
        end
      end
    end
  end

  // Hung clock timer: counts master clock cycles without a bit clock edge while the unit runs as
  // a slave; the unit of the timeout is 256 cycles; a zero timeout turns the detector off.
  assign w_activity   = w_master | w_bclk_edge | (reg_fsm_frame_current_state == ENUM_ST_OFF) |
                        (reg_tmo == 16'd0) | (PARA_I2S_HUNG_EN == 32'd0);
  // Pulse when the programmed time has passed without a bit clock edge.
  assign w_hung_pulse = ~w_activity & ~reg_hung_lat & (reg_tmo_pre == 8'hFF) &
                        ((reg_tmo_cnt + 16'd1) == reg_tmo);

  // Prescaler and timeout counter: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_tmo
    if (!i_rst_n_mclk) begin
      reg_tmo_pre  <= 8'd0;
      reg_tmo_cnt  <= 16'd0;
      reg_hung_lat <= 1'b0;
    end else if (w_activity) begin
      reg_tmo_pre  <= 8'd0;
      reg_tmo_cnt  <= 16'd0;
      reg_hung_lat <= 1'b0;
    end else begin
      reg_tmo_pre  <= reg_tmo_pre + 8'd1;
      reg_tmo_cnt  <= (reg_tmo_pre == 8'hFF) ? (reg_tmo_cnt + 16'd1) : reg_tmo_cnt;
      reg_hung_lat <= reg_hung_lat | w_hung_pulse;
    end
  end

  // Frame done: the last bit of a real frame (not the prelude) was finished at a wrap.
  assign w_frm_ev_c = w_wrapped & ~i_srst_ev;

  // Event flops: one-cycle pulses launched from flops (CDC-004).
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_ev
    if (!i_rst_n_mclk) begin
      reg_ev_sync <= 1'b0;
      reg_ev_hung <= 1'b0;
      reg_ev_frm  <= 1'b0;
    end else begin
      reg_ev_sync <= w_miss | w_unexp;
      reg_ev_hung <= w_hung_pulse;
      reg_ev_frm  <= w_frm_ev_c;
    end
  end

  // Pin enables, busy and outputs, registered (the busy flag is launched from a flop into the
  // synchronizer of the APB domain, CDC-004): a master drives the bit clock and the frame sync
  // while it runs or finishes a frame, and holds them at the idle level otherwise.
  always_ff @(posedge i_clk_mclk, negedge i_rst_n_mclk) begin : p_ff_oe
    if (!i_rst_n_mclk) begin
      reg_bclk_oe <= 1'b0;
      reg_ws_oe   <= 1'b0;
      reg_busy    <= 1'b0;
    end else begin
      reg_bclk_oe <= w_master & (reg_fsm_frame_current_state != ENUM_ST_OFF);
      reg_ws_oe   <= w_master & (reg_fsm_frame_current_state != ENUM_ST_OFF);
      reg_busy    <= (reg_fsm_frame_current_state != ENUM_ST_OFF);
    end
  end

  // Output mapping.
  assign o_bclk     = reg_mbclk & w_master;
  assign o_bclk_oe  = reg_bclk_oe;
  assign o_ws       = reg_ws & w_master;
  assign o_ws_oe    = reg_ws_oe;
  assign o_eff_bclk = w_master ? reg_bclk_pipe[LPARA_PIPE_W-1] : w_bclk_pin_s;
  assign o_eff_ws   = w_master ? reg_ws_pipe[LPARA_PIPE_W-1] : w_ws_pin_s;
  assign o_data_w   = reg_data_w;
  assign o_align    = reg_align;
  assign o_pack     = w_pack;
  assign o_tri      = reg_tri;
  assign o_on       = (reg_fsm_frame_current_state != ENUM_ST_OFF);
  assign o_tick_l   = w_launch;
  assign o_ev_sync  = reg_ev_sync;
  assign o_ev_hung  = reg_ev_hung;
  assign o_ev_frm   = reg_ev_frm;
  assign o_busy     = reg_busy;

endmodule
