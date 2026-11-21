/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Host engine (section 10.1, FEAT-008 to FEAT-012, DEC-008). It sends the SOF
 *                token of every (micro)frame and schedules the channels: periodic channels first
 *                (when their interval is due), then non-periodic ones, lowest index first, and
 *                only when the (micro)frame has enough time left for the packet. OUT and SETUP
 *                send the token and the data of the host queue; IN sends the token, stores the
 *                data in the receive region and answers ACK. NAK delays the channel until the
 *                next (micro)frame, NYET starts the PING flow, STALL halts the channel, a
 *                missing answer counts as an error (three errors halt the channel). With split
 *                enabled the token is preceded by a SPLIT token (start or complete) and a NYET
 *                answer to a complete-split is retried in the next microframe. Isochronous
 *                transactions have no handshake. Of the OUT channels that share a host queue
 *                only the lowest armed one is served (DEC-008).
 */
`timescale 1ns/1ps

module m_usb2_host #(
  // Parameter Description: number of host channels.
  // Parameter values: 1 to 16; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NHC = 8,
  // Parameter Description: UTMI+ data width, which sets the bytes per RAM row (4 or 8).
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: index of the host non-periodic and periodic queues in the FIFO manager
  // (the periodic queue is the next one).
  // Parameter values: 1 to 18; default is 10.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_HQ_NP = 10,
  // Parameter Description: wait for the answer of the device, in CLK-PHY cycles.
  // Parameter values: 32 to 1023; default is 160.
  // Parameter unit: cycle
  parameter logic [31:0] PARA_USB2_RSP_TMO = 160,
  // Parameter Description: cycles between the start of the payload read and the data request.
  // Parameter values: 3 to 15; default is 4.
  // Parameter unit: cycle
  parameter logic [31:0] PARA_USB2_PREP_CYC = 4,
  // Parameter Description: bytes of token, handshake and gap overhead added to a packet when the
  // time left in the (micro)frame is checked.
  // Parameter values: 8 to 255; default is 48.
  // Parameter unit: byte
  parameter logic [31:0] PARA_USB2_HOST_OVH = 48,
  // Parameter Description: divider of the (micro)frame timer, for simulation only.
  // Parameter values: 1, 16, 256 or 4096; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_TSCALE = 1,
  localparam logic [31:0] LPARA_PID_OUT   = 32'h1,
  localparam logic [31:0] LPARA_PID_IN    = 32'h9,
  localparam logic [31:0] LPARA_PID_SETUP = 32'hD,
  localparam logic [31:0] LPARA_PID_SOF   = 32'h5,
  localparam logic [31:0] LPARA_PID_PING  = 32'h4,
  localparam logic [31:0] LPARA_PID_SPLIT = 32'h8,
  localparam logic [31:0] LPARA_PID_DATA0 = 32'h3,
  localparam logic [31:0] LPARA_PID_DATA1 = 32'hB,
  localparam logic [31:0] LPARA_PID_DATA2 = 32'h7,
  localparam logic [31:0] LPARA_PID_MDATA = 32'hF,
  localparam logic [31:0] LPARA_PID_ACK   = 32'h2,
  localparam logic [31:0] LPARA_PID_NAK   = 32'hA,
  localparam logic [31:0] LPARA_PID_STALL = 32'hE,
  localparam logic [31:0] LPARA_PID_NYET  = 32'h6,
  localparam logic [31:0] LPARA_KIND_HS    = 0,
  localparam logic [31:0] LPARA_KIND_TOK   = 1,
  localparam logic [31:0] LPARA_KIND_SPLIT = 2,
  localparam logic [31:0] LPARA_KIND_DATA  = 3,
  localparam logic [31:0] LPARA_TYPE_ISO  = 1,
  localparam logic [31:0] LPARA_TYPE_INT  = 3,
  localparam logic [31:0] LPARA_W16       = 16,
  localparam logic [31:0] LPARA_TMO_W     = 10,
  localparam logic [31:0] LPARA_UF_W      = 20,
  localparam logic [31:0] LPARA_ONE       = 1,
  localparam logic [31:0] LPARA_RES_NONE  = 0,
  localparam logic [31:0] LPARA_RES_ACK   = 1,
  localparam logic [31:0] LPARA_RES_NAK   = 2,
  localparam logic [31:0] LPARA_RES_NYET  = 3,
  localparam logic [31:0] LPARA_RES_STALL = 4,
  localparam logic [31:0] LPARA_RES_ERR   = 5,
  localparam logic [31:0] LPARA_RES_TOG   = 6
) (
  // Clock and reset
  input  wire                            i_clk_phy,
  input  wire                            i_rst_n_core,

  // Role and port state from the speed engine
  input  wire                            i_host_act,
  input  wire  [1:0]                     i_port_speed,

  // Receive events of the link
  input  wire                            i_hs_vld,
  input  wire  [3:0]                     i_hs_pid,
  input  wire                            i_dat_sop,
  input  wire  [3:0]                     i_dat_pid,
  input  wire  [1:0]                     i_dat_n,
  input  wire  [15:0]                    i_dat_b,
  input  wire                            i_dat_end,
  input  wire                            i_dat_ok,
  input  wire  [11:0]                    i_dat_len,

  // Transmit request to the link and its status
  output logic                           o_tx_req,
  output logic [2:0]                     o_tx_kind,
  output logic [3:0]                     o_tx_pid,
  output logic [18:0]                    o_tx_fld,
  output logic [11:0]                    o_tx_len,
  input  wire                            i_tx_done,
  input  wire                            i_tx_fail,

  // Packet port of the FIFO manager
  output logic                           o_rxw_sop,
  output logic [4:0]                     o_rxw_tag,
  output logic [1:0]                     o_rxw_n,
  output logic [15:0]                    o_rxw_b,
  output logic                           o_rxw_end,
  output logic                           o_rxw_ok,
  output logic [11:0]                    o_rxw_len,
  input  wire  [16:0]                    i_rx_free,
  input  wire                            i_plq_free,
  output logic                           o_txr_start,
  output logic [4:0]                     o_txr_q,
  output logic [11:0]                    o_txr_len,
  output logic                           o_txr_commit,
  output logic                           o_txr_cancel,
  input  wire  [33:0]                    i_q_cnt,

  // Shadow CSR words
  input  wire  [31:0]                    i_hport,
  input  wire  [31:0]                    i_sof_cfg,
  input  wire  [PARA_USB2_NHC-1:0][31:0] i_hc_ctrl,
  input  wire  [PARA_USB2_NHC-1:0][31:0] i_hc_split,
  input  wire  [PARA_USB2_NHC-1:0][31:0] i_hc_xfer,
  input  wire  [PARA_USB2_NHC-1:0][31:0] i_hc_int_en,
  input  wire  [PARA_USB2_NHC-1:0][31:0] i_hc_cfg,

  // Published words, event sets and command clears
  output logic [PARA_USB2_NHC-1:0][31:0] o_hc_xfer_pub,
  output logic [PARA_USB2_NHC-1:0][31:0] o_hc_cfg_pub,
  output logic [PARA_USB2_NHC-1:0][31:0] o_hc_int_set,
  output logic [PARA_USB2_NHC-1:0][31:0] o_hc_ctrl_clr,

  // Frame counter and events to the interrupt block
  output logic [13:0]                    o_frame,
  output logic                           o_evt_sof,
  output logic                           o_evt_xfer,
  output logic                           o_host_busy,
  output logic                           o_lpm_evt,
  output logic                           o_lpm_ack,
  output logic                           o_lpm_clr
);

  // FSM states of the host transaction handler.
  typedef enum logic [3:0] {
    ENUM_ST_IDLE    = 4'd0,
    ENUM_ST_SOF     = 4'd1,
    ENUM_ST_PREP    = 4'd2,
    ENUM_ST_SPLIT   = 4'd3,
    ENUM_ST_TOKEN   = 4'd4,
    ENUM_ST_DATA    = 4'd5,
    ENUM_ST_WAIT_HS = 4'd6,
    ENUM_ST_WAIT_IN = 4'd7,
    ENUM_ST_RSP     = 4'd8,
    ENUM_ST_DONE    = 4'd9,
    ENUM_ST_LPM_EXT = 4'd10,
    ENUM_ST_LPM_TOK = 4'd11,
    ENUM_ST_LPM_WT  = 4'd12
  } host_state_type_def;

  // Internal signal declarations
  host_state_type_def                       reg_fsm_host_current_state;
  host_state_type_def                       w_fsm_host_nxt_state;
  logic [PARA_USB2_NHC-1:0]                 reg_act;
  logic [PARA_USB2_NHC-1:0][18:0]           reg_xs;
  logic [PARA_USB2_NHC-1:0][9:0]            reg_pc;
  logic [PARA_USB2_NHC-1:0][1:0]            reg_pid;
  logic [PARA_USB2_NHC-1:0]                 reg_ping;
  logic [PARA_USB2_NHC-1:0][1:0]            reg_err;
  logic [PARA_USB2_NHC-1:0]                 reg_wait;
  logic [PARA_USB2_NHC-1:0][15:0]           reg_pcnt;
  logic [PARA_USB2_NHC-1:0]                 reg_csplit;
  logic [PARA_USB2_NHC-1:0]                 reg_buf;
  logic [PARA_USB2_NHC-1:0][31:0]           reg_cmd_seen;
  logic [LPARA_UF_W-1:0]                    reg_uf_cnt;
  logic [2:0]                               reg_uf_idx;
  logic [10:0]                              reg_frame;
  logic                                     reg_sof_pend;
  logic                                     reg_tick;
  logic [3:0]                               reg_ch;
  logic [11:0]                              reg_len;
  logic [3:0]                               reg_tok_pid;
  logic [3:0]                               reg_dat_pid;
  logic                                     reg_dir_in;
  logic                                     reg_iso;
  logic                                     reg_periodic;
  logic                                     reg_use_split;
  logic [10:0]                              reg_tok_fld;
  logic [18:0]                              reg_spl_fld;
  logic [2:0]                               reg_res;
  logic                                     reg_ping_tok;
  logic                                     reg_to;
  logic                                     reg_bab;
  logic                                     reg_lpm_seen;
  logic                                     reg_lpm_pend;
  logic                                     w_lpm_start;
  logic                                     reg_lpm_evt;
  logic                                     reg_lpm_ack;
  logic                                     reg_lpm_clr;
  logic [10:0]                              reg_mps;
  logic                                     w_bab;
  logic [PARA_USB2_NHC-1:0]                 w_blk;
  logic [PARA_USB2_NHC-1:0]                 reg_due;
  logic [PARA_USB2_NHC-1:0]                 reg_blkp;
  logic                                     reg_is_cs;
  logic [LPARA_TMO_W-1:0]                   reg_tmo;
  logic [3:0]                               reg_prep;
  logic                                     reg_rx_acc;
  logic                                     reg_tx_req;
  logic [2:0]                               reg_tx_kind;
  logic [3:0]                               reg_tx_pid;
  logic [18:0]                              reg_tx_fld;
  logic [11:0]                              reg_tx_len;
  logic                                     reg_txr_start;
  logic                                     reg_txr_commit;
  logic                                     reg_txr_cancel;
  logic                                     reg_evt_sof;
  logic                                     reg_done_p;
  logic [PARA_USB2_NHC-1:0]                 w_elig;
  logic [PARA_USB2_NHC-1:0]                 w_elig_p;
  logic                                     w_pick_vld;
  logic                                     w_pick_vld_c;
  logic                                     reg_pick_vld;
  logic                                     reg_done_d;
  logic                                     reg_done_d2;
  logic [PARA_USB2_NHC-1:0]                 reg_elig;
  logic [PARA_USB2_NHC-1:0]                 reg_elig_p;
  logic [3:0]                               reg_pick_ch;
  logic [3:0]                               w_pick_ch_c;
  logic [3:0]                               w_pick_ch;
  logic [PARA_USB2_NHC-1:0]                 w_head_np;
  logic [PARA_USB2_NHC-1:0]                 w_head_p;
  logic [PARA_USB2_NHC-1:0]                 w_is_p;
  logic [PARA_USB2_NHC-1:0]                 w_is_out;
  logic [PARA_USB2_NHC-1:0][11:0]           w_len_c;
  logic [PARA_USB2_NHC-1:0][16:0]           w_rows_c;
  logic [PARA_USB2_NHC-1:0][LPARA_UF_W-1:0] w_est;
  logic                                     w_hs_mode;
  logic [LPARA_UF_W-1:0]                    w_uf_len_nxt;
  logic [LPARA_UF_W-1:0]                    w_uf_reload;
  logic                                     w_uf_end;
  logic                                     w_sof_en;
  logic [2:0]                               w_res_nxt;
  logic [31:0]                              w_c_ctrl;
  logic [31:0]                              w_c_split;
  logic [31:0]                              w_c_cfg;
  logic [10:0]                              w_c_mps;
  logic [18:0]                              w_c_xs;
  logic [11:0]                              w_c_len;
  logic [3:0]                               w_c_dpid;
  logic [1:0]                               w_c_type;
  logic [16:0]                              w_c_rows;
  logic [2:0]                               w_bpr_sh;
  logic [PARA_USB2_NHC-1:0]                 w_upd_hit;
  logic [PARA_USB2_NHC-1:0]                 w_halt_hit;
  logic [PARA_USB2_NHC-1:0]                 w_xfer_hit;
  logic                                     w_data_ok;
  logic                                     w_pid_ok;
  logic [3:0]                               w_exp_pid;
  logic                                     w_ack_hs;
  logic                                     w_nak_hs;
  logic                                     w_nyet_hs;
  logic                                     w_stall_hs;
  logic                                     w_wait_end;
  logic [PARA_USB2_NHC-1:0]                 w_start_ok;

  // Bytes per RAM row (shift of 2 for 32-bit rows, 3 for 64-bit rows) and the port speed.
  assign w_bpr_sh = (PARA_USB2_UTMI_W == LPARA_W16) ? 3'd3 : 3'd2;
  assign w_hs_mode = (i_port_speed == 2'd0);
  assign w_sof_en  = i_host_act & i_hport[4];

  // (Micro)frame timer: the length is the CSR value (divided by TSCALE for simulation); a
  // full-speed frame is eight microframes long. SOF goes out at every end of the timer.
  assign w_uf_len_nxt = {4'd0, i_sof_cfg[15:0]} >> $clog2(PARA_USB2_TSCALE);
  assign w_uf_reload  = w_hs_mode ? w_uf_len_nxt : {w_uf_len_nxt[LPARA_UF_W-4:0], 3'b000};
  assign w_uf_end     = (reg_uf_cnt == '0) & w_sof_en;

  // Channel view of the transaction in preparation.
  assign w_c_ctrl  = i_hc_ctrl[w_pick_ch];
  assign w_c_split = i_hc_split[w_pick_ch];
  assign w_c_cfg   = i_hc_cfg[w_pick_ch];
  assign w_c_mps   = w_c_ctrl[10:0];
  assign w_c_type  = w_c_ctrl[17:16];
  assign w_c_xs    = reg_xs[w_pick_ch];
  assign w_c_len   = (w_c_xs > {8'd0, w_c_mps}) ? {1'b0, w_c_mps} : w_c_xs[11:0];
  assign w_c_rows  = ({6'd0, w_c_mps} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;
  assign w_c_dpid  = (reg_pid[w_pick_ch] == 2'd1) ? LPARA_PID_DATA1[3:0] :
                     (reg_pid[w_pick_ch] == 2'd2) ? LPARA_PID_DATA2[3:0] :
                     (reg_pid[w_pick_ch] == 2'd3) ? LPARA_PID_MDATA[3:0] : LPARA_PID_DATA0[3:0];

  // Scheduler: for each channel, class (periodic), direction, head-of-line of its OUT queue and
  // whether it can start now (armed, not waiting, due, data or space available, time left).
  always_comb begin : p_com_elig
    logic w_np_seen;
    logic w_p_seen;
    w_is_p     = '0;
    w_is_out   = '0;
    w_head_np  = '0;
    w_head_p   = '0;
    w_elig     = '0;
    w_elig_p   = '0;
    w_len_c    = '0;
    w_rows_c   = '0;
    w_est      = '0;
    w_blk      = '0;
    w_np_seen  = 1'b0;
    w_p_seen   = 1'b0;
    for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin
      w_is_p[idx]   = (i_hc_ctrl[idx][17:16] == LPARA_TYPE_ISO[1:0]) | (i_hc_ctrl[idx][17:16] == LPARA_TYPE_INT[1:0]);
      w_is_out[idx] = ~i_hc_ctrl[idx][15];
      if (reg_act[idx] & w_is_out[idx] & ~w_is_p[idx] & ~w_np_seen) begin
        w_head_np[idx] = 1'b1;
        w_np_seen      = 1'b1;
      end
      if (reg_act[idx] & w_is_out[idx] & w_is_p[idx] & ~w_p_seen) begin
        w_head_p[idx] = 1'b1;
        w_p_seen      = 1'b1;
      end
    end
    for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin
      w_elig[idx] = reg_act[idx] & ~reg_wait[idx] & ~i_hc_ctrl[idx][30] &
                    (~i_hc_cfg[idx][3] | (reg_pcnt[idx] == 16'd0) | ~w_is_p[idx]);
      w_len_c[idx] = (reg_xs[idx] > {8'd0, i_hc_ctrl[idx][10:0]}) ? {1'b0, i_hc_ctrl[idx][10:0]} : reg_xs[idx][11:0];
      w_rows_c[idx] = ({5'd0, w_len_c[idx]} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;
      w_est[idx] = ({8'd0, w_len_c[idx]} + PARA_USB2_HOST_OVH[19:0]);
      if (!w_hs_mode)
        w_est[idx] = (w_est[idx] << 5) + (w_est[idx] << 3);
      w_est[idx]  = w_est[idx] >> $clog2(PARA_USB2_TSCALE);
      w_blk[idx]  = w_elig[idx] & w_is_p[idx] & ~(reg_uf_cnt > w_est[idx]);
      w_elig[idx] = w_elig[idx] & (reg_uf_cnt > w_est[idx]);
      if (w_is_out[idx]) begin
        w_elig[idx] = w_elig[idx] & (w_is_p[idx] ? w_head_p[idx] : w_head_np[idx]) &
                      (reg_csplit[idx] | ((w_is_p[idx] ? i_q_cnt[33:17] : i_q_cnt[16:0]) >= w_rows_c[idx]));
      end
      w_elig_p[idx] = w_elig[idx] & w_is_p[idx];
    end
  end

  // Pick: the lowest periodic channel, else the lowest non-periodic one.
  always_comb begin : p_com_pick
    w_pick_vld_c = 1'b0;
    w_pick_ch_c  = 4'd0;
    for (int idx = PARA_USB2_NHC - 1; idx >= 0; idx--) begin
      if (reg_elig[idx] & ~w_is_p[idx]) begin
        w_pick_vld_c = 1'b1;
        w_pick_ch_c  = idx[3:0];
      end
    end
    for (int idx = PARA_USB2_NHC - 1; idx >= 0; idx--) begin
      if (reg_elig_p[idx]) begin
        w_pick_vld_c = 1'b1;
        w_pick_ch_c  = idx[3:0];
      end
    end
  end

  // The eligibility of every channel and the pick are registered (two scheduler pipeline
  // stages, DEC-030):
  // the channel logic that follows works on a value that is two cycles old. The pick is ignored
  // for two
  // cycles after a transaction ended, when the channel state is being updated.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_pick
    if (!i_rst_n_core) begin
      reg_pick_vld <= 1'b0;
      reg_pick_ch  <= 4'd0;
      reg_done_d   <= 1'b0;
      reg_done_d2  <= 1'b0;
      reg_elig     <= '0;
      reg_elig_p   <= '0;
    end else begin
      reg_elig     <= w_elig;
      reg_elig_p   <= w_elig_p;
      reg_done_d2  <= reg_done_d;
      reg_pick_vld <= w_pick_vld_c;
      reg_pick_ch  <= w_pick_ch_c;
      reg_done_d   <= reg_done_p;
    end
  end

  assign w_pick_vld = reg_pick_vld & ~reg_done_d & ~reg_done_d2;
  assign w_pick_ch  = reg_pick_ch;

  // Handshake classification of the answer of the device.
  assign w_ack_hs   = i_hs_vld & (i_hs_pid == LPARA_PID_ACK[3:0]);
  assign w_nak_hs   = i_hs_vld & (i_hs_pid == LPARA_PID_NAK[3:0]);
  assign w_nyet_hs  = i_hs_vld & (i_hs_pid == LPARA_PID_NYET[3:0]);
  assign w_stall_hs = i_hs_vld & (i_hs_pid == LPARA_PID_STALL[3:0]);
  assign w_wait_end = (reg_tmo == '0);
  assign w_exp_pid  = reg_dat_pid;
  assign w_pid_ok   = reg_iso ? 1'b1 : (i_dat_pid == w_exp_pid);
  assign w_data_ok  = i_dat_end & i_dat_ok & reg_rx_acc;
  assign w_lpm_start = reg_lpm_pend & i_host_act & ~reg_sof_pend;
  assign w_bab      = i_dat_end & (i_dat_len > {1'b0, reg_mps});

  // Part 1, sequential: the current state of the host handler.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_fsm_host
    if (!i_rst_n_core)
      reg_fsm_host_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_host_current_state <= w_fsm_host_nxt_state;
  end

  // Part 2, combinational: the next state.
  always_comb begin : p_com_fsm_nxt
    w_fsm_host_nxt_state = reg_fsm_host_current_state;
    case (reg_fsm_host_current_state)
      ENUM_ST_IDLE: begin
        casez ({reg_sof_pend & w_sof_en, w_lpm_start, w_pick_vld & ~reg_done_p & i_host_act & ~reg_sof_pend})
          3'b1??:  w_fsm_host_nxt_state = ENUM_ST_SOF;
          3'b01?:  w_fsm_host_nxt_state = ENUM_ST_LPM_EXT;
          3'b001:  w_fsm_host_nxt_state = ENUM_ST_PREP;
          default: w_fsm_host_nxt_state = ENUM_ST_IDLE;
        endcase
      end
      ENUM_ST_LPM_EXT: begin
        if (i_tx_done)
          w_fsm_host_nxt_state = ENUM_ST_LPM_TOK;
        else if (i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_LPM_TOK: begin
        if (i_tx_done)
          w_fsm_host_nxt_state = ENUM_ST_LPM_WT;
        else if (i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_LPM_WT: begin
        if (i_hs_vld | w_wait_end)
          w_fsm_host_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_SOF: begin
        if (i_tx_done | i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_PREP: begin
        if (reg_prep == 4'd0)
          w_fsm_host_nxt_state = reg_use_split ? ENUM_ST_SPLIT : ENUM_ST_TOKEN;
      end
      ENUM_ST_SPLIT: begin
        if (i_tx_done)
          w_fsm_host_nxt_state = ENUM_ST_TOKEN;
        else if (i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_TOKEN: begin
        if (i_tx_done)
          w_fsm_host_nxt_state = reg_dir_in ? ENUM_ST_WAIT_IN :
                                 ((reg_ping_tok | reg_is_cs) ? ENUM_ST_WAIT_HS : ENUM_ST_DATA);
        else if (i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_DATA: begin
        if (i_tx_done)
          w_fsm_host_nxt_state = reg_iso ? ENUM_ST_DONE : ENUM_ST_WAIT_HS;
        else if (i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_WAIT_HS: begin
        if (i_hs_vld | w_wait_end)
          w_fsm_host_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_WAIT_IN: begin
        casez ({i_dat_end, i_hs_vld, w_wait_end})
          3'b1??:  w_fsm_host_nxt_state = (w_data_ok & w_pid_ok & ~reg_iso) ? ENUM_ST_RSP : ENUM_ST_DONE;
          3'b01?:  w_fsm_host_nxt_state = ENUM_ST_DONE;
          3'b001:  w_fsm_host_nxt_state = ENUM_ST_DONE;
          default: w_fsm_host_nxt_state = ENUM_ST_WAIT_IN;
        endcase
      end
      ENUM_ST_RSP: begin
        if (i_tx_done | i_tx_fail)
          w_fsm_host_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_DONE: begin
        w_fsm_host_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_host_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Result of the transaction, taken when the state machine leaves the wait states.
  always_comb begin : p_com_res
    w_res_nxt = LPARA_RES_NONE[2:0];
    case (reg_fsm_host_current_state)
      ENUM_ST_WAIT_HS: begin
        casez ({w_ack_hs, w_nak_hs, w_nyet_hs, w_stall_hs, w_wait_end})
          5'b1????: w_res_nxt = LPARA_RES_ACK[2:0];
          5'b01???: w_res_nxt = LPARA_RES_NAK[2:0];
          5'b001??: w_res_nxt = LPARA_RES_NYET[2:0];
          5'b0001?: w_res_nxt = LPARA_RES_STALL[2:0];
          5'b00001: w_res_nxt = LPARA_RES_ERR[2:0];
          default:  w_res_nxt = LPARA_RES_NONE[2:0];
        endcase
      end
      ENUM_ST_WAIT_IN: begin
        casez ({i_dat_end, w_nak_hs, w_stall_hs, w_ack_hs | w_nyet_hs, w_wait_end})
          5'b1????: w_res_nxt = (~i_dat_ok | ~reg_rx_acc | w_bab) ? LPARA_RES_ERR[2:0] :
                                (w_pid_ok ? LPARA_RES_ACK[2:0] : LPARA_RES_TOG[2:0]);
          5'b01???: w_res_nxt = LPARA_RES_NAK[2:0];
          5'b001??: w_res_nxt = LPARA_RES_STALL[2:0];
          5'b0001?: w_res_nxt = reg_use_split ? (w_nyet_hs ? LPARA_RES_NYET[2:0] :
                                                 (reg_is_cs ? LPARA_RES_ERR[2:0] : LPARA_RES_ACK[2:0])) :
                                LPARA_RES_ERR[2:0];
          5'b00001: w_res_nxt = LPARA_RES_ERR[2:0];
          default:  w_res_nxt = LPARA_RES_NONE[2:0];
        endcase
      end
      default: begin
        w_res_nxt = reg_res;
      end
    endcase
  end

  // Receive gating: payload goes to the FIFO only for the accepted IN data packet.
  assign o_rxw_sop = i_dat_sop & (reg_fsm_host_current_state == ENUM_ST_WAIT_IN) & reg_rx_acc;
  assign o_rxw_tag = {1'b0, reg_ch};
  assign o_rxw_n   = ((reg_fsm_host_current_state == ENUM_ST_WAIT_IN) & reg_rx_acc) ? i_dat_n : 2'd0;
  assign o_rxw_b   = i_dat_b;
  assign o_rxw_end = i_dat_end & (reg_fsm_host_current_state == ENUM_ST_WAIT_IN) & reg_rx_acc;
  assign o_rxw_ok  = i_dat_ok & w_pid_ok;
  assign o_rxw_len = i_dat_len;

  // (Micro)frame timer, SOF request and the interval tick.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_timer
    if (!i_rst_n_core) begin
      reg_uf_cnt   <= '0;
      reg_uf_idx   <= 3'd0;
      reg_frame    <= 11'd0;
      reg_sof_pend <= 1'b0;
      reg_tick     <= 1'b0;
      reg_evt_sof  <= 1'b0;
    end else begin
      reg_tick    <= 1'b0;
      reg_evt_sof <= 1'b0;
      if (!w_sof_en) begin
        reg_uf_cnt   <= '0;
        reg_sof_pend <= 1'b0;
      end else if (w_uf_end) begin
        reg_uf_cnt   <= w_uf_reload;
        reg_sof_pend <= 1'b1;
        reg_tick     <= 1'b1;
        if (w_hs_mode) begin
          reg_uf_idx <= reg_uf_idx + 3'd1;
          if (reg_uf_idx == 3'd7)
            reg_frame <= reg_frame + 11'd1;
        end else begin
          reg_frame <= reg_frame + 11'd1;
        end
      end else begin
        reg_uf_cnt <= reg_uf_cnt - LPARA_ONE[LPARA_UF_W-1:0];
      end
      if ((reg_fsm_host_current_state == ENUM_ST_SOF) & i_tx_done) begin
        reg_sof_pend <= 1'b0;
        reg_evt_sof  <= 1'b1;
      end
    end
  end

  // Transaction registers: latched at the pick, timers and the request to the link.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_trans
    if (!i_rst_n_core) begin
      reg_ch        <= 4'd0;
      reg_len       <= 12'd0;
      reg_tok_pid   <= 4'h0;
      reg_dat_pid   <= 4'h0;
      reg_dir_in    <= 1'b0;
      reg_iso       <= 1'b0;
      reg_periodic  <= 1'b0;
      reg_use_split <= 1'b0;
      reg_tok_fld   <= 11'd0;
      reg_spl_fld   <= 19'd0;
      reg_res       <= LPARA_RES_NONE[2:0];
      reg_ping_tok  <= 1'b0;
      reg_to        <= 1'b0;
      reg_is_cs     <= 1'b0;
      reg_bab       <= 1'b0;
      reg_mps       <= 11'd0;
      reg_tmo       <= '0;
      reg_prep      <= 4'd0;
      reg_rx_acc    <= 1'b0;
      reg_tx_req    <= 1'b0;
      reg_tx_kind   <= 3'd0;
      reg_tx_pid    <= 4'h0;
      reg_tx_fld    <= 19'd0;
      reg_tx_len    <= 12'd0;
      reg_txr_start <= 1'b0;
      reg_txr_commit <= 1'b0;
      reg_txr_cancel <= 1'b0;
      reg_done_p    <= 1'b0;
    end else begin
      reg_tx_req     <= 1'b0;
      reg_txr_start  <= 1'b0;
      reg_txr_commit <= 1'b0;
      reg_txr_cancel <= 1'b0;
      reg_done_p     <= 1'b0;
      case (reg_fsm_host_current_state)
        ENUM_ST_IDLE: begin
          casez ({(w_lpm_start & ~(reg_sof_pend & w_sof_en)), (reg_sof_pend & w_sof_en),
                  (w_pick_vld & ~reg_done_p & i_host_act)})
            3'b1??: begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_TOK[2:0];
            reg_tx_pid  <= 4'h0;
            reg_tx_fld  <= {12'd0, i_hport[20:14]};
            reg_tx_len  <= 12'd0;
            reg_tmo     <= PARA_USB2_RSP_TMO[LPARA_TMO_W-1:0];
            end
            3'b01?: begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_TOK[2:0];
            reg_tx_pid  <= LPARA_PID_SOF[3:0];
            reg_tx_fld  <= {8'd0, reg_frame};
            reg_tx_len  <= 12'd0;
            end
            3'b001: begin
            reg_ch        <= w_pick_ch;
            reg_len       <= w_c_len;
            reg_dir_in    <= w_c_ctrl[15];
            reg_iso       <= (w_c_type == LPARA_TYPE_ISO[1:0]);
            reg_periodic  <= w_is_p[w_pick_ch];
            reg_use_split <= w_c_split[17];
            reg_ping_tok  <= reg_ping[w_pick_ch] & ~w_c_ctrl[15];
            reg_dat_pid   <= w_c_dpid;
            reg_tok_pid   <= w_c_ctrl[15] ? LPARA_PID_IN[3:0] :
                             (reg_ping[w_pick_ch] ? LPARA_PID_PING[3:0] :
                              (i_hc_xfer[w_pick_ch][31] ? LPARA_PID_SETUP[3:0] : LPARA_PID_OUT[3:0]));
            reg_tok_fld   <= {w_c_ctrl[14:11], w_c_ctrl[26:20]};
            reg_spl_fld   <= {w_c_type, 1'b0, (w_c_ctrl[19:18] == 2'd2), w_c_split[13:7],
                              reg_csplit[w_pick_ch], w_c_split[6:0]};
            reg_is_cs     <= reg_csplit[w_pick_ch];
            reg_to        <= 1'b0;
            reg_mps       <= w_c_mps;
            reg_bab       <= 1'b0;
            reg_prep      <= PARA_USB2_PREP_CYC[3:0];
            reg_rx_acc    <= w_c_ctrl[15] & (i_rx_free >= w_c_rows) & i_plq_free;
            reg_txr_start <= ~w_c_ctrl[15] & ~reg_ping[w_pick_ch] & ~reg_csplit[w_pick_ch];
            end
            default: begin
              reg_tmo <= reg_tmo;
            end
          endcase
        end
        ENUM_ST_LPM_EXT: begin
          if (i_tx_done) begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_TOK[2:0];
            reg_tx_pid  <= 4'h3;
            reg_tx_fld  <= {10'd0, i_hport[13], i_hport[12:9], 4'd1};
            reg_tx_len  <= 12'd0;
          end
        end
        ENUM_ST_LPM_TOK: begin
          reg_tmo <= PARA_USB2_RSP_TMO[LPARA_TMO_W-1:0];
        end
        ENUM_ST_LPM_WT: begin
          if (reg_tmo != '0)
            reg_tmo <= reg_tmo - LPARA_ONE[LPARA_TMO_W-1:0];
        end
        ENUM_ST_PREP: begin
          if (reg_prep != 4'd0)
            reg_prep <= reg_prep - 4'd1;
          if (reg_prep == 4'd1) begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= reg_use_split ? LPARA_KIND_SPLIT[2:0] : LPARA_KIND_TOK[2:0];
            reg_tx_pid  <= reg_use_split ? LPARA_PID_SPLIT[3:0] : reg_tok_pid;
            reg_tx_fld  <= reg_use_split ? reg_spl_fld : {8'd0, reg_tok_fld};
            reg_tx_len  <= 12'd0;
          end
        end
        ENUM_ST_SPLIT: begin
          if (i_tx_done) begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_TOK[2:0];
            reg_tx_pid  <= reg_tok_pid;
            reg_tx_fld  <= {8'd0, reg_tok_fld};
            reg_tx_len  <= 12'd0;
          end
        end
        ENUM_ST_TOKEN: begin
          reg_tmo <= PARA_USB2_RSP_TMO[LPARA_TMO_W-1:0];
          if (i_tx_done & ~reg_dir_in & ~reg_ping_tok & ~reg_is_cs) begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_DATA[2:0];
            reg_tx_pid  <= reg_dat_pid;
            reg_tx_len  <= reg_len;
          end
        end
        ENUM_ST_DATA: begin
          reg_tmo <= PARA_USB2_RSP_TMO[LPARA_TMO_W-1:0];
        end
        ENUM_ST_WAIT_HS, ENUM_ST_WAIT_IN: begin
          if (reg_tmo != '0)
            reg_tmo <= reg_tmo - LPARA_ONE[LPARA_TMO_W-1:0];
          if (reg_fsm_host_current_state == ENUM_ST_WAIT_IN) begin
            if (w_data_ok & w_pid_ok & ~reg_iso) begin
              reg_tx_req  <= 1'b1;
              reg_tx_kind <= LPARA_KIND_HS[2:0];
              reg_tx_pid  <= LPARA_PID_ACK[3:0];
              reg_tx_len  <= 12'd0;
            end
          end
          if (w_fsm_host_nxt_state == ENUM_ST_DONE) begin
            reg_res <= w_res_nxt;
            reg_to  <= w_wait_end & ~i_hs_vld & ~i_dat_end;
          end
        end
        ENUM_ST_RSP: begin
          reg_res <= reg_res;
        end
        ENUM_ST_DONE: begin
          reg_done_p <= 1'b1;
          if (~reg_dir_in & ~reg_ping_tok & ~reg_is_cs) begin
            reg_txr_commit <= (reg_res == LPARA_RES_ACK[2:0]) | (reg_res == LPARA_RES_NYET[2:0]);
            reg_txr_cancel <= (reg_res != LPARA_RES_ACK[2:0]) & (reg_res != LPARA_RES_NYET[2:0]);
          end
        end
        default: begin
          reg_res <= reg_res;
        end
      endcase
      if (reg_fsm_host_current_state == ENUM_ST_DATA) begin
        if (i_tx_done & reg_iso)
          reg_res <= LPARA_RES_ACK[2:0];
      end
      if ((reg_fsm_host_current_state == ENUM_ST_WAIT_IN) & i_dat_end) begin
        reg_res <= w_res_nxt;
        reg_len <= i_dat_len;
        reg_bab <= w_bab;
      end
      if ((reg_fsm_host_current_state == ENUM_ST_RSP) & (i_tx_done | i_tx_fail))
        reg_res <= reg_res;
    end
  end

  // LPM request: the seen flag follows the CSR bit; the result is an event, an ACK pulse for the
  // speed engine and the clear of the request bit.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_lpm
    if (!i_rst_n_core) begin
      reg_lpm_seen <= 1'b0;
      reg_lpm_pend <= 1'b0;
      reg_lpm_evt  <= 1'b0;
      reg_lpm_ack  <= 1'b0;
      reg_lpm_clr  <= 1'b0;
    end else begin
      reg_lpm_seen <= i_hport[8];
      reg_lpm_pend <= (reg_lpm_pend | (i_hport[8] & ~reg_lpm_seen)) & ~w_lpm_start;
      reg_lpm_evt  <= 1'b0;
      reg_lpm_ack  <= 1'b0;
      reg_lpm_clr  <= w_lpm_start;
      if ((reg_fsm_host_current_state == ENUM_ST_LPM_WT) & (i_hs_vld | w_wait_end)) begin
        reg_lpm_evt <= 1'b1;
        reg_lpm_ack <= w_ack_hs;
      end
    end
  end

  // Strobes of the finished transaction toward the per-channel state: the start phase of a split
  // transaction only moves the channel to its complete phase; ACK and NYET (without split) update
  // the transfer; STALL and the third error halt the channel.
  always_comb begin : p_com_hit
    w_start_ok = '0;
    w_upd_hit  = '0;
    w_halt_hit = '0;
    for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin
      w_start_ok[idx] = reg_done_p & (reg_ch == idx[3:0]) & reg_use_split & ~reg_is_cs &
                        (reg_res == LPARA_RES_ACK[2:0]);
      w_upd_hit[idx]  = reg_done_p & (reg_ch == idx[3:0]) & ~w_start_ok[idx] &
                        ((reg_res == LPARA_RES_ACK[2:0]) | ((reg_res == LPARA_RES_NYET[2:0]) & ~reg_use_split));
      w_halt_hit[idx] = reg_done_p & (reg_ch == idx[3:0]) &
                        ((reg_res == LPARA_RES_STALL[2:0]) | ((reg_res == LPARA_RES_ERR[2:0]) & ((reg_err[idx] == 2'd2) | reg_bab)));
    end
  end

  // Per-channel state: armed, remaining counts, toggle, ping, error counter, delay and interval.
  generate
    for (genvar gen_ch = 0; gen_ch < PARA_USB2_NHC; gen_ch++) begin : gen_ch_state
      logic [31:0] w_cc;
      logic [31:0] w_edge;
      logic [18:0] w_xs_nxt;
      logic        w_last;
      logic        w_set_done;
      logic        w_res_me;
      logic [31:0] w_clr;
      logic [15:0] w_ival;

      assign w_cc      = i_hc_ctrl[gen_ch];
      assign w_edge    = w_cc & ~reg_cmd_seen[gen_ch];
      assign w_xs_nxt  = (reg_xs[gen_ch] > {7'd0, reg_len}) ? (reg_xs[gen_ch] - {7'd0, reg_len}) : 19'd0;
      assign w_ival    = i_hc_cfg[gen_ch][20:5];
      assign w_last    = w_upd_hit[gen_ch] & ~reg_ping_tok &
                         ((reg_pc[gen_ch] == 10'd1) | (w_xs_nxt == 19'd0) |
                          (reg_dir_in & ({1'b0, reg_len} < {2'b00, w_cc[10:0]})));

      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_cmd
        if (!i_rst_n_core)
          reg_cmd_seen[gen_ch] <= 32'd0;
        else
          reg_cmd_seen[gen_ch] <= w_cc;
      end

      // Channel state registers.
      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_ch
        if (!i_rst_n_core) begin
          reg_act[gen_ch]    <= 1'b0;
          reg_xs[gen_ch]     <= 19'd0;
          reg_pc[gen_ch]     <= 10'd0;
          reg_pid[gen_ch]    <= 2'd0;
          reg_ping[gen_ch]   <= 1'b0;
          reg_err[gen_ch]    <= 2'd0;
          reg_wait[gen_ch]   <= 1'b0;
          reg_pcnt[gen_ch]   <= 16'd0;
          reg_csplit[gen_ch] <= 1'b0;
          reg_buf[gen_ch]    <= 1'b0;
        end else begin
          if (reg_tick) begin
            reg_wait[gen_ch] <= 1'b0;
            if (reg_pcnt[gen_ch] != 16'd0)
              reg_pcnt[gen_ch] <= reg_pcnt[gen_ch] - 16'd1;
          end
          if (w_edge[30])
            reg_act[gen_ch] <= 1'b0;
          if (w_edge[31]) begin
            reg_act[gen_ch]  <= 1'b1;
            reg_xs[gen_ch]   <= i_hc_xfer[gen_ch][18:0];
            reg_pc[gen_ch]   <= i_hc_xfer[gen_ch][28:19];
            reg_pid[gen_ch]  <= i_hc_xfer[gen_ch][30:29];
            reg_ping[gen_ch] <= 1'b0;
            reg_err[gen_ch]  <= 2'd0;
            reg_wait[gen_ch] <= 1'b0;
            reg_pcnt[gen_ch] <= 16'd0;
            reg_csplit[gen_ch] <= 1'b0;
          end
          if (w_start_ok[gen_ch]) begin
            reg_csplit[gen_ch] <= 1'b1;
            reg_wait[gen_ch]   <= 1'b1;
            reg_err[gen_ch]    <= 2'd0;
          end
          if (w_upd_hit[gen_ch]) begin
            reg_csplit[gen_ch] <= 1'b0;
            reg_err[gen_ch] <= 2'd0;
            if (reg_ping_tok) begin
              reg_ping[gen_ch] <= 1'b0;
            end else begin
              reg_xs[gen_ch]  <= w_xs_nxt;
              reg_pc[gen_ch]  <= (reg_pc[gen_ch] != 10'd0) ? (reg_pc[gen_ch] - 10'd1) : 10'd0;
              reg_pid[gen_ch] <= (reg_pid[gen_ch] == 2'd0) ? 2'd1 : 2'd0;
              reg_buf[gen_ch] <= ~reg_buf[gen_ch];
              if (reg_res == LPARA_RES_NYET[2:0])
                reg_ping[gen_ch] <= 1'b1;
              if (w_cc[17:16] == LPARA_TYPE_INT[1:0] | w_cc[17:16] == LPARA_TYPE_ISO[1:0])
                reg_pcnt[gen_ch] <= (i_hc_cfg[gen_ch][4]) ? w_ival : 16'd0;
            end
            if (w_last)
              reg_act[gen_ch] <= 1'b0;
          end
          if (reg_done_p & (reg_ch == gen_ch[3:0])) begin
            if (reg_res == LPARA_RES_NYET[2:0] & reg_use_split)
              reg_wait[gen_ch] <= 1'b1;
            if (reg_res == LPARA_RES_NAK[2:0]) begin
              reg_wait[gen_ch] <= 1'b1;
              if (w_is_p[gen_ch] & i_hc_cfg[gen_ch][3])
                reg_pcnt[gen_ch] <= w_ival;
              reg_err[gen_ch]  <= 2'd0;
              if (reg_ping_tok)
                reg_ping[gen_ch] <= 1'b1;
            end
            if (reg_res == LPARA_RES_ERR[2:0])
              reg_err[gen_ch] <= reg_err[gen_ch] + 2'd1;
            if (reg_res == LPARA_RES_TOG[2:0])
              reg_err[gen_ch] <= 2'd0;
            if (w_halt_hit[gen_ch])
              reg_act[gen_ch] <= 1'b0;
          end
        end
      end

      // Event sets of the channel: done, halt, timeout, NAK, NYET, STALL, ACK, error, toggle error.
      assign w_set_done = w_last;
      assign w_res_me   = reg_done_p & (reg_ch == gen_ch[3:0]);
      assign o_hc_int_set[gen_ch] = {19'd0, (w_res_me & (reg_res == LPARA_RES_ERR[2:0]) & reg_iso),
                                     (reg_tick & reg_due[gen_ch]), (reg_tick & reg_blkp[gen_ch]),
                                     (w_res_me & (reg_res == LPARA_RES_TOG[2:0])),
                                     (w_res_me & (reg_res == LPARA_RES_ERR[2:0]) & reg_bab),
                                     (w_res_me & (reg_res == LPARA_RES_ERR[2:0]) & ~reg_to & ~reg_bab & ~reg_iso),
                                     (w_res_me & (reg_res == LPARA_RES_ACK[2:0])),
                                     (w_res_me & (reg_res == LPARA_RES_STALL[2:0])),
                                     (w_res_me & (reg_res == LPARA_RES_NYET[2:0])),
                                     (w_res_me & (reg_res == LPARA_RES_NAK[2:0])),
                                     (w_res_me & (reg_res == LPARA_RES_ERR[2:0]) & reg_to & ~reg_iso),
                                     w_halt_hit[gen_ch], w_set_done};
      // Missed poll (due at the last tick and still unserved) and microframe overrun (a due
      // periodic
      // channel did not fit into the time that was left).
      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_miss
        if (!i_rst_n_core) begin
          reg_due[gen_ch]  <= 1'b0;
          reg_blkp[gen_ch] <= 1'b0;
        end else begin
          if (reg_tick) begin
            reg_due[gen_ch]  <= reg_act[gen_ch] & i_hc_cfg[gen_ch][3] & w_is_p[gen_ch] & (reg_pcnt[gen_ch] <= 16'd1);
            reg_blkp[gen_ch] <= 1'b0;
          end
          if (w_blk[gen_ch])
            reg_blkp[gen_ch] <= 1'b1;
          if (w_res_me) begin
            reg_due[gen_ch]  <= 1'b0;
            reg_blkp[gen_ch] <= 1'b0;
          end
        end
      end
      assign w_clr = {w_edge[31:30], 30'd0};
      assign o_hc_ctrl_clr[gen_ch] = w_clr;
      assign o_hc_xfer_pub[gen_ch] = {1'b0, reg_pid[gen_ch], reg_pc[gen_ch], reg_xs[gen_ch]};
      assign o_hc_cfg_pub[gen_ch]  = {10'd0, reg_buf[gen_ch], 21'd0};
      assign w_xfer_hit[gen_ch]    = |(o_hc_int_set[gen_ch] & i_hc_int_en[gen_ch]);
    end
  endgenerate

  // Outputs: transmit request, FIFO commands and events.
  assign o_tx_req     = reg_tx_req;
  assign o_tx_kind    = reg_tx_kind;
  assign o_tx_pid     = reg_tx_pid;
  assign o_tx_fld     = reg_tx_fld;
  assign o_tx_len     = reg_tx_len;
  assign o_txr_start  = reg_txr_start;
  assign o_txr_q      = reg_periodic ? (PARA_USB2_HQ_NP[4:0] + 5'd1) : PARA_USB2_HQ_NP[4:0];
  assign o_txr_len    = reg_len;
  assign o_txr_commit = reg_txr_commit;
  assign o_txr_cancel = reg_txr_cancel;
  assign o_frame      = {reg_uf_idx, reg_frame};
  assign o_evt_sof    = reg_evt_sof;
  assign o_evt_xfer   = |w_xfer_hit;
  assign o_host_busy  = (reg_fsm_host_current_state != ENUM_ST_IDLE);
  assign o_lpm_evt    = reg_lpm_evt;
  assign o_lpm_ack    = reg_lpm_ack;
  assign o_lpm_clr    = reg_lpm_clr;

endmodule
