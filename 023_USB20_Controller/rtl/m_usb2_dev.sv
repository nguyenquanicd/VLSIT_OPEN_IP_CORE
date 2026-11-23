/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Device engine (section 10.1, FEAT-004, FEAT-005, DEC-007). It answers the
 *                tokens of the host: SOF (frame counter), SETUP and OUT (data into the receive
 *                region of the FIFO, ACK, NAK, NYET or STALL), IN (data from the transmit queue
 *                of the endpoint, wait for the host ACK, retry on a timeout), PING and the LPM
 *                extended token. Per endpoint state: armed, NAK status, data toggle, remaining
 *                bytes and packets. Commands in the shadow words (set_nak, clr_nak, set_d0,
 *                set_d1, ep_dis, ep_en) act on a rising edge and are cleared through the clear
 *                masks. Registers use the natural bit positions of the CSR words. Isochronous
 *                endpoints send DATA0 only (high-bandwidth PID sequences are not implemented,
 *                DEC-007).
 */
`timescale 1ns/1ps

module m_usb2_dev #(
  // Parameter Description: number of endpoint entries per direction (EP0 and NUM_EP others).
  // Parameter values: 2 to 16; default is 9.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NEP1 = 9,
  // Parameter Description: UTMI+ data width, which sets the bytes per RAM row (4 or 8).
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: cycles between the start of the payload read and the transmit
  // request, so that the first row is in the reader before the PID leaves.
  // Parameter values: 3 to 15; default is 4.
  // Parameter unit: cycle
  parameter logic [31:0] PARA_USB2_PREP_CYC = 4,
  localparam logic [31:0] LPARA_PID_OUT   = 32'h1,
  localparam logic [31:0] LPARA_PID_IN    = 32'h9,
  localparam logic [31:0] LPARA_PID_SETUP = 32'hD,
  localparam logic [31:0] LPARA_PID_SOF   = 32'h5,
  localparam logic [31:0] LPARA_PID_PING  = 32'h4,
  localparam logic [31:0] LPARA_PID_DATA0 = 32'h3,
  localparam logic [31:0] LPARA_PID_DATA1 = 32'hB,
  localparam logic [31:0] LPARA_PID_DATA2 = 32'h7,
  localparam logic [31:0] LPARA_PID_ACK   = 32'h2,
  localparam logic [31:0] LPARA_PID_NAK   = 32'hA,
  localparam logic [31:0] LPARA_PID_STALL = 32'hE,
  localparam logic [31:0] LPARA_PID_NYET  = 32'h6,
  localparam logic [31:0] LPARA_KIND_HS   = 0,
  localparam logic [31:0] LPARA_KIND_DATA = 3,
  localparam logic [31:0] LPARA_TYPE_ISO  = 1,
  localparam logic [31:0] LPARA_BPR_SH_8  = 2,
  localparam logic [31:0] LPARA_BPR_SH_16 = 3,
  localparam logic [31:0] LPARA_W16       = 16,
  localparam logic [31:0] LPARA_TMO_W     = 10,
  // Wait for the host ACK after a data packet in CLK-PHY cycles (REQ-FUNC-025, BUG-006):
  // high-speed 736 to 816 bit times (92 to 102 cycles at 60 MHz, 46 to 51 at 30 MHz);
  // full-speed 16 to 18 bit times (80 to 90 cycles at 60 MHz, 40 to 45 at 30 MHz).
  localparam logic [31:0] LPARA_TMO_HS    = (PARA_USB2_UTMI_W == 32'd16) ? 32'd48 : 32'd97,
  localparam logic [31:0] LPARA_TMO_FS    = (PARA_USB2_UTMI_W == 32'd16) ? 32'd42 : 32'd85,
  localparam logic [31:0] LPARA_ONE       = 1
) (
  // Clock and reset
  input  wire                             i_clk_phy,
  input  wire                             i_rst_n_core,

  // Role and speed from the speed engine
  input  wire                             i_dev_act,
  input  wire                             i_speed_hs,
  input  wire                             i_test_nak,

  // Receive events of the link
  input  wire                             i_tok_vld,
  input  wire                             i_tok_ext,
  input  wire  [10:0]                     i_tok_efld,
  input  wire  [3:0]                      i_tok_pid,
  input  wire  [10:0]                     i_tok_fld,
  input  wire                             i_hs_vld,
  input  wire  [3:0]                      i_hs_pid,
  input  wire                             i_dat_sop,
  input  wire  [3:0]                      i_dat_pid,
  input  wire  [1:0]                      i_dat_n,
  input  wire  [15:0]                     i_dat_b,
  input  wire                             i_dat_end,
  input  wire                             i_dat_ok,
  input  wire  [11:0]                     i_dat_len,

  // Transmit request to the link and its status
  output logic                            o_tx_req,
  output logic [2:0]                      o_tx_kind,
  output logic [3:0]                      o_tx_pid,
  output logic [11:0]                     o_tx_len,
  input  wire                             i_tx_done,
  input  wire                             i_tx_fail,

  // Packet port of the FIFO manager
  output logic                            o_rxw_sop,
  output logic [4:0]                      o_rxw_tag,
  output logic [1:0]                      o_rxw_n,
  output logic [15:0]                     o_rxw_b,
  output logic                            o_rxw_end,
  output logic                            o_rxw_ok,
  output logic [11:0]                     o_rxw_len,
  input  wire  [16:0]                     i_rx_free,
  input  wire                             i_plq_free,
  output logic                            o_txr_start,
  output logic [4:0]                      o_txr_q,
  output logic [11:0]                     o_txr_len,
  output logic                            o_txr_commit,
  output logic                            o_txr_cancel,
  input  wire  [PARA_USB2_NEP1*17-1:0]    i_ep_cnt,

  // Shadow CSR words
  input  wire  [31:0]                     i_dctrl,
  input  wire  [31:0]                     i_lpm_cfg,
  input  wire  [PARA_USB2_NEP1-1:0][31:0] i_epi_ctrl,
  input  wire  [PARA_USB2_NEP1-1:0][31:0] i_epi_xfer,
  input  wire  [PARA_USB2_NEP1-1:0][31:0] i_epi_int_en,
  input  wire  [PARA_USB2_NEP1-1:0][31:0] i_epo_ctrl,
  input  wire  [PARA_USB2_NEP1-1:0][31:0] i_epo_xfer,
  input  wire  [PARA_USB2_NEP1-1:0][31:0] i_epo_int_en,

  // Published words, event sets and command clears
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epi_ctrl_pub,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epi_xfer_pub,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epo_ctrl_pub,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epo_xfer_pub,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epi_int_set,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epo_int_set,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epi_ctrl_clr,
  output logic [PARA_USB2_NEP1-1:0][31:0] o_epo_ctrl_clr,

  // Frame counter, events to the interrupt block and the LPM request to the speed engine
  output logic [10:0]                     o_frame,
  output logic [2:0]                      o_uframe,
  output logic                            o_evt_sof,
  output logic                            o_evt_xfer,
  input  wire                             i_tx_starve,
  output logic                            o_evt_udf,
  output logic                            o_lpm_vld,
  output logic [3:0]                      o_lpm_hird,
  output logic                            o_lpm_rw
);

  // FSM states of the device transaction handler.
  typedef enum logic [3:0] {
    ENUM_ST_IDLE     = 4'd0,
    ENUM_ST_OUT_WAIT = 4'd1,
    ENUM_ST_OUT_RX   = 4'd2,
    ENUM_ST_RSP      = 4'd3,
    ENUM_ST_IN_PREP  = 4'd4,
    ENUM_ST_IN_TX    = 4'd5,
    ENUM_ST_IN_ACK   = 4'd6
  } dev_state_type_def;

  // Internal signal declarations
  dev_state_type_def                        reg_fsm_dev_current_state;
  dev_state_type_def                        w_fsm_dev_nxt_state;
  logic [PARA_USB2_NEP1-1:0]                reg_act_i;
  logic [PARA_USB2_NEP1-1:0]                reg_act_o;
  logic [PARA_USB2_NEP1-1:0]                reg_nak_i;
  logic [PARA_USB2_NEP1-1:0]                reg_nak_o;
  logic [PARA_USB2_NEP1-1:0]                reg_dpid_i;
  logic [PARA_USB2_NEP1-1:0]                reg_dpid_o;
  logic [PARA_USB2_NEP1-1:0]                reg_buf_i;
  logic [PARA_USB2_NEP1-1:0][1:0]           reg_txn_i;
  logic [1:0]                               w_mult;
  logic [1:0]                               w_rem;
  logic                                     w_hb;
  logic [3:0]                               w_hb_pid;
  logic [PARA_USB2_NEP1-1:0]                reg_buf_o;
  logic [PARA_USB2_NEP1-1:0][18:0]          reg_xs_i;
  logic [PARA_USB2_NEP1-1:0][18:0]          reg_xs_o;
  logic [PARA_USB2_NEP1-1:0][9:0]           reg_pc_i;
  logic [PARA_USB2_NEP1-1:0][9:0]           reg_pc_o;
  logic [PARA_USB2_NEP1-1:0][31:0]          reg_cmd_i_seen;
  logic [PARA_USB2_NEP1-1:0][31:0]          reg_cmd_o_seen;
  logic [3:0]                               reg_ep;
  logic                                     reg_is_setup;
  logic                                     reg_o_accept;
  logic                                     reg_o_stall;
  logic                                     reg_o_iso;
  logic                                     reg_o_ctrl_bulk;
  logic [10:0]                              reg_o_mps;
  logic [11:0]                              reg_in_len;
  logic [3:0]                               reg_in_pid;
  logic                                     reg_in_iso;
  logic [LPARA_TMO_W-1:0]                   reg_tmo;
  logic [3:0]                               reg_prep;
  logic [10:0]                              reg_frame;
  logic [2:0]                               reg_uframe;
  logic                                     reg_tx_req;
  logic [3:0]                               reg_tx_pid;
  logic [2:0]                               reg_tx_kind;
  logic [11:0]                              reg_tx_len;
  logic                                     reg_txr_start;
  logic                                     reg_txr_commit;
  logic                                     reg_txr_cancel;
  logic                                     reg_evt_sof;
  logic                                     reg_lpm_vld;
  logic [3:0]                               reg_lpm_hird;
  logic                                     reg_lpm_rw;
  logic                                     w_tk_match;
  logic [3:0]                               w_tk_ep;
  logic                                     w_tk_out;
  logic                                     w_tk_setup;
  logic                                     w_tk_in;
  logic                                     w_tk_ping;
  logic                                     w_tk_sof;
  logic                                     w_tk_lpm;
  logic                                     w_lpm_l1;
  logic                                     w_o_act;
  logic                                     w_o_nak;
  logic                                     w_o_stall;
  logic [1:0]                               w_o_type;
  logic [10:0]                              w_o_mps;
  logic                                     w_o_space;
  logic [16:0]                              w_o_rows;
  logic                                     w_i_act;
  logic                                     w_i_stall;
  logic [1:0]                               w_i_type;
  logic [10:0]                              w_i_mps;
  logic [18:0]                              w_i_xs;
  logic [11:0]                              w_i_len;
  logic [16:0]                              w_i_rows;
  logic                                     w_i_have;
  logic [PARA_USB2_NEP1-1:0]                reg_have_i;
  logic                                     w_pid_ok;
  logic                                     w_commit;
  logic                                     w_o_bab;
  logic [3:0]                               w_rsp_pid;
  logic                                     w_rsp_send;
  logic                                     w_o_done;
  logic [16:0]                              w_free_after;
  logic [16:0]                              w_rows_mps;
  logic                                     w_ack_rx;
  logic                                     w_i_iso;
  logic                                     w_wait_end;
  logic [2:0]                               w_bpr_sh;
  logic [LPARA_TMO_W-1:0]                   w_ack_tmo;
  logic [PARA_USB2_NEP1-1:0]                w_hit_o_commit;
  logic [PARA_USB2_NEP1-1:0]                w_hit_i_commit;
  logic [PARA_USB2_NEP1-1:0]                w_hit_o_nak;
  logic [PARA_USB2_NEP1-1:0]                w_hit_i_nak;
  logic [PARA_USB2_NEP1-1:0]                w_hit_o_stall;
  logic [PARA_USB2_NEP1-1:0]                w_hit_i_stall;
  logic [PARA_USB2_NEP1-1:0]                w_hit_setup;
  logic [PARA_USB2_NEP1-1:0]                w_hit_iso_i;
  logic [PARA_USB2_NEP1-1:0]                w_hit_iso_o;
  logic [PARA_USB2_NEP1-1:0]                w_hit_unf;
  logic [PARA_USB2_NEP1-1:0]                w_hit_ovf;
  logic [PARA_USB2_NEP1-1:0]                w_hit_timeout;
  logic [PARA_USB2_NEP1-1:0]                w_hit_nyet;
  logic [PARA_USB2_NEP1-1:0]                w_o_done_hit;
  logic [PARA_USB2_NEP1-1:0]                w_xfer_hit;

  // Bytes per RAM row (shift of 2 for 32-bit rows, 3 for 64-bit rows).
  assign w_bpr_sh = (PARA_USB2_UTMI_W == LPARA_W16) ? LPARA_BPR_SH_16[2:0] : LPARA_BPR_SH_8[2:0];
  assign w_ack_tmo = i_speed_hs ? LPARA_TMO_HS[LPARA_TMO_W-1:0] : LPARA_TMO_FS[LPARA_TMO_W-1:0];

  // Token decode: address match, endpoint and kind of the token. A token for an endpoint number
  // that this build does not have is ignored (REQ-FUNC-001, BUG-005).
  assign w_tk_ep    = i_tok_fld[10:7];
  assign w_tk_match = i_tok_vld & ~i_tok_ext & i_dev_act & (i_tok_fld[6:0] == i_dctrl[6:0]) &
                      ({28'd0, w_tk_ep} < PARA_USB2_NEP1);
  assign w_tk_out   = w_tk_match & (i_tok_pid == LPARA_PID_OUT[3:0]);
  assign w_tk_setup = w_tk_match & (i_tok_pid == LPARA_PID_SETUP[3:0]);
  assign w_tk_in    = w_tk_match & (i_tok_pid == LPARA_PID_IN[3:0]);
  assign w_tk_ping  = w_tk_match & (i_tok_pid == LPARA_PID_PING[3:0]);
  assign w_tk_sof   = i_tok_vld & ~i_tok_ext & (i_tok_pid == LPARA_PID_SOF[3:0]);
  // LPM token: the EXT token before it must carry this device address and endpoint 0, LPM must
  // be enabled at run time and the answer must not be "no response" (REQ-FUNC-021, BUG-017).
  assign w_tk_lpm   = i_tok_vld & i_tok_ext & i_dev_act & (i_tok_pid == 4'h3) & i_lpm_cfg[2] &
                      (i_tok_efld[6:0] == i_dctrl[6:0]) & (i_tok_efld[10:7] == 4'd0) &
                      (i_lpm_cfg[1:0] != 2'd3);
  // Only bLinkState = 0001b (L1) is supported; any other value is answered with STALL.
  assign w_lpm_l1   = (i_tok_fld[3:0] == 4'd1);

  // OUT endpoint view of the token: armed, NAK status, stall, type and the room for a packet.
  assign w_o_act   = reg_act_o[w_tk_ep];
  assign w_o_nak   = reg_nak_o[w_tk_ep];
  assign w_o_stall = i_epo_ctrl[w_tk_ep][13];
  assign w_o_type  = i_epo_ctrl[w_tk_ep][12:11];
  assign w_o_mps   = i_epo_ctrl[w_tk_ep][10:0];
  assign w_o_rows  = ({6'd0, w_o_mps} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;
  assign w_o_space = (i_rx_free >= w_o_rows) & i_plq_free;

  // IN endpoint view of the token: armed, stall, type, remaining bytes and the data to send.
  assign w_i_act   = reg_act_i[w_tk_ep];
  assign w_i_stall = i_epi_ctrl[w_tk_ep][13];
  assign w_i_type  = i_epi_ctrl[w_tk_ep][12:11];
  assign w_i_mps   = i_epi_ctrl[w_tk_ep][10:0];
  assign w_i_xs    = reg_xs_i[w_tk_ep];
  assign w_i_len   = (w_i_xs > {8'd0, w_i_mps}) ? {1'b0, w_i_mps} : w_i_xs[11:0];
  assign w_i_rows  = ({5'd0, w_i_len} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;
  assign w_i_iso   = (w_i_type == LPARA_TYPE_ISO[1:0]);
  assign w_hb      = w_i_iso & i_speed_hs;
  assign w_hb_pid  = (w_rem >= 2'd3) ? LPARA_PID_DATA2[3:0] : ((w_rem == 2'd2) ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0]);
  assign w_mult    = (i_epi_ctrl[w_tk_ep][24:23] == 2'd0) ? 2'd1 : i_epi_ctrl[w_tk_ep][24:23];
  assign w_rem     = w_mult - reg_txn_i[w_tk_ep];
  // Data available for the endpoint of the token: computed for every endpoint from its own
  // registers and
  // registered, so the token field only selects one bit (DEC-030); the flag is one cycle old.
  assign w_i_have  = reg_have_i[w_tk_ep];

  // Reception end: the data PID must match the toggle (SETUP always DATA0, isochronous any).
  assign w_pid_ok = reg_is_setup ? (i_dat_pid == LPARA_PID_DATA0[3:0]) :
                    reg_o_iso    ? 1'b1 :
                    (i_dat_pid == (reg_dpid_o[reg_ep] ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0]));
  // A data field longer than the maximum packet size is dropped and not answered (BUG-040).
  assign w_o_bab  = i_dat_end & ~reg_is_setup & ({1'b0, i_dat_len} > {1'b0, 1'b0, reg_o_mps});
  assign w_commit = i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & reg_o_accept &
                    i_dat_ok & w_pid_ok & ~w_o_bab;
  // The free rows reported by the FIFO manager already count the rows of the packet that just ended
  // (the rows are written while the bytes arrive), so no row count is subtracted again (DEC-026).
  assign w_free_after = i_rx_free;
  assign w_rows_mps   = ({6'd0, reg_o_mps} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;
  // A short packet ends the transfer only with short_end = 1 (REQ-FUNC-031, BUG-007).
  assign w_o_done     = w_commit & ~reg_is_setup &
                        ((reg_pc_o[reg_ep] == 10'd1) |
                         (i_epo_ctrl[reg_ep][26] & ({7'd0, i_dat_len} < {8'd0, reg_o_mps})) |
                         (reg_xs_o[reg_ep] <= {7'd0, i_dat_len}));

  // Handshake after the data packet of an OUT or SETUP transaction. Priority: bad CRC (no answer),
  // stalled endpoint, SETUP (ACK when accepted with DATA0), toggle error (ACK, data dropped),
  // accepted data (ACK or NYET), not accepted (NAK).
  always_comb begin : p_com_rsp
    w_rsp_pid  = LPARA_PID_NAK[3:0];
    w_rsp_send = 1'b0;
    if (i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & ~reg_o_iso) begin
      casez ({(~i_dat_ok | w_o_bab), (reg_o_stall & ~reg_is_setup), reg_is_setup, (~w_pid_ok & reg_o_accept),
              reg_o_accept})
        5'b1????: w_rsp_send = 1'b0;
        5'b01???: begin
          w_rsp_send = 1'b1;
          w_rsp_pid  = LPARA_PID_STALL[3:0];
        end
        5'b001??: begin
          w_rsp_send = reg_o_accept & w_pid_ok;
          w_rsp_pid  = LPARA_PID_ACK[3:0];
        end
        5'b0001?: begin
          w_rsp_send = 1'b1;
          w_rsp_pid  = LPARA_PID_ACK[3:0];
        end
        5'b00001: begin
          w_rsp_send = 1'b1;
          w_rsp_pid  = (i_speed_hs & reg_o_ctrl_bulk & (w_free_after < w_rows_mps)) ?
                       LPARA_PID_NYET[3:0] : LPARA_PID_ACK[3:0];
        end
        default: begin
          w_rsp_send = 1'b1;
          w_rsp_pid  = LPARA_PID_NAK[3:0];
        end
      endcase
    end
  end

  // Part 1, sequential: the current state of the transaction handler.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_fsm_dev
    if (!i_rst_n_core)
      reg_fsm_dev_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_dev_current_state <= w_fsm_dev_nxt_state;
  end

  // ACK of the host for the data packet of an IN transaction.
  assign w_ack_rx   = i_hs_vld & (i_hs_pid == LPARA_PID_ACK[3:0]) &
                      (reg_fsm_dev_current_state == ENUM_ST_IN_ACK);
  assign w_wait_end = (reg_tmo == '0);

  // Part 2, combinational: the next state. A new token restarts the handler while no packet of the
  // device is on the bus and no reception is in progress.
  always_comb begin : p_com_fsm_nxt
    w_fsm_dev_nxt_state = reg_fsm_dev_current_state;
    case (reg_fsm_dev_current_state)
      ENUM_ST_IDLE, ENUM_ST_OUT_WAIT, ENUM_ST_IN_ACK: begin
        casez ({(w_tk_setup | w_tk_out), w_tk_in, (w_tk_ping | w_tk_lpm), i_tok_vld,
                ((reg_fsm_dev_current_state == ENUM_ST_OUT_WAIT) & i_dat_sop),
                ((reg_fsm_dev_current_state == ENUM_ST_IN_ACK) & (w_ack_rx | w_wait_end | i_dat_sop))})
          6'b1?????: w_fsm_dev_nxt_state = ENUM_ST_OUT_WAIT;
          6'b01????: w_fsm_dev_nxt_state = (w_i_stall | ~w_i_have) ? ENUM_ST_RSP : ENUM_ST_IN_PREP;
          6'b001???: w_fsm_dev_nxt_state = ENUM_ST_RSP;
          6'b0001??: w_fsm_dev_nxt_state = ENUM_ST_IDLE;
          6'b00001?: w_fsm_dev_nxt_state = ENUM_ST_OUT_RX;
          6'b000001: w_fsm_dev_nxt_state = ENUM_ST_IDLE;
          default:   w_fsm_dev_nxt_state = reg_fsm_dev_current_state;
        endcase
      end
      ENUM_ST_OUT_RX: begin
        if (i_dat_end)
          w_fsm_dev_nxt_state = w_rsp_send ? ENUM_ST_RSP : ENUM_ST_IDLE;
      end
      ENUM_ST_RSP: begin
        if (i_tx_done | i_tx_fail)
          w_fsm_dev_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_IN_PREP: begin
        if (reg_prep == '0)
          w_fsm_dev_nxt_state = ENUM_ST_IN_TX;
      end
      ENUM_ST_IN_TX: begin
        if (i_tx_done)
          w_fsm_dev_nxt_state = reg_in_iso ? ENUM_ST_IDLE : ENUM_ST_IN_ACK;
        else if (i_tx_fail)
          w_fsm_dev_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_dev_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Packet port to the FIFO: the received payload passes through while the transaction accepts it.
  assign o_rxw_sop = i_dat_sop & (reg_fsm_dev_current_state == ENUM_ST_OUT_WAIT) & reg_o_accept;
  assign o_rxw_tag = {1'b0, reg_ep};
  assign o_rxw_n   = ((reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & reg_o_accept) ? i_dat_n : 2'd0;
  assign o_rxw_b   = i_dat_b;
  assign o_rxw_end = i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & reg_o_accept;
  assign o_rxw_ok  = i_dat_ok & w_pid_ok & ~w_o_bab;
  assign o_rxw_len = i_dat_len;

  // Transaction registers: endpoint, flags latched at the token, the timers, the request fields and
  // the frame counter.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_trans
    if (!i_rst_n_core) begin
      reg_ep          <= 4'd0;
      reg_is_setup    <= 1'b0;
      reg_o_accept    <= 1'b0;
      reg_o_stall     <= 1'b0;
      reg_o_iso       <= 1'b0;
      reg_o_ctrl_bulk <= 1'b0;
      reg_o_mps       <= 11'd0;
      reg_in_len      <= 12'd0;
      reg_in_pid      <= 4'h0;
      reg_in_iso      <= 1'b0;
      reg_tmo         <= '0;
      reg_prep        <= 4'd0;
      reg_frame       <= 11'd0;
      reg_uframe      <= 3'd0;
      reg_tx_req      <= 1'b0;
      reg_tx_pid      <= 4'h0;
      reg_tx_kind     <= 3'd0;
      reg_tx_len      <= 12'd0;
      reg_txr_start   <= 1'b0;
      reg_txr_commit  <= 1'b0;
      reg_txr_cancel  <= 1'b0;
      reg_evt_sof     <= 1'b0;
      reg_lpm_vld     <= 1'b0;
      reg_lpm_hird    <= 4'd0;
      reg_lpm_rw      <= 1'b0;
    end else begin
      reg_tx_req     <= 1'b0;
      reg_txr_start  <= 1'b0;
      reg_txr_commit <= 1'b0;
      reg_txr_cancel <= 1'b0;
      reg_evt_sof    <= 1'b0;
      reg_lpm_vld    <= 1'b0;
      if (w_tk_sof & i_dev_act) begin
        reg_evt_sof <= 1'b1;
        if (reg_frame == i_tok_fld) begin
          reg_uframe <= reg_uframe + 3'd1;
        end else begin
          reg_uframe <= 3'd0;
          reg_frame  <= i_tok_fld;
        end
      end
      if (w_tk_out | w_tk_setup | w_tk_in | w_tk_ping) begin
        reg_ep    <= w_tk_ep;
      end
      if (w_tk_out | w_tk_setup) begin
        reg_is_setup    <= w_tk_setup;
        reg_o_stall     <= w_o_stall;
        reg_o_iso       <= (w_o_type == LPARA_TYPE_ISO[1:0]);
        reg_o_ctrl_bulk <= (w_o_type != LPARA_TYPE_ISO[1:0]) & (w_o_type != 2'd3);
        reg_o_mps       <= w_o_mps;
        reg_o_accept    <= (w_tk_setup | (w_o_act & ~w_o_nak & ~w_o_stall)) & w_o_space;
      end
      if (w_tk_ping) begin
        reg_o_accept <= w_o_act & ~w_o_nak & w_o_space;
        reg_o_stall  <= w_o_stall;
      end
      if (w_tk_in) begin
        reg_in_len     <= w_i_len;
        reg_in_iso     <= (w_i_type == LPARA_TYPE_ISO[1:0]);
        reg_in_pid     <= w_hb ? w_hb_pid : (reg_dpid_i[w_tk_ep] ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0]);
        reg_prep       <= PARA_USB2_PREP_CYC[3:0];
        reg_txr_start  <= w_i_have & ~w_i_stall;
      end
      if (w_tk_lpm) begin
        reg_lpm_vld  <= (i_lpm_cfg[1:0] == 2'd0) & w_lpm_l1;
        reg_lpm_hird <= i_tok_fld[7:4];
        reg_lpm_rw   <= i_tok_fld[8];
      end
      if (reg_fsm_dev_current_state == ENUM_ST_IN_PREP) begin
        if (reg_prep != 4'd0)
          reg_prep <= reg_prep - 4'd1;
      end
      case (reg_fsm_dev_current_state)
        ENUM_ST_IN_PREP: begin
          if (reg_prep == 4'd1) begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_DATA[2:0];
            reg_tx_pid  <= reg_in_pid;
            reg_tx_len  <= reg_in_len;
          end
          reg_tmo <= w_ack_tmo;
        end
        ENUM_ST_IN_TX: begin
          reg_tmo <= w_ack_tmo;
          if (i_tx_done & reg_in_iso)
            reg_txr_commit <= 1'b1;
          else if (i_tx_fail)
            reg_txr_cancel <= 1'b1;
        end
        ENUM_ST_IN_ACK: begin
          if (reg_tmo != '0)
            reg_tmo <= reg_tmo - LPARA_ONE[LPARA_TMO_W-1:0];
          if (w_ack_rx)
            reg_txr_commit <= 1'b1;
          else if (w_wait_end)
            reg_txr_cancel <= 1'b1;
        end
        default: begin
          reg_tmo <= reg_tmo;
        end
      endcase
      if (w_rsp_send & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX)) begin
        reg_tx_req  <= 1'b1;
        reg_tx_kind <= LPARA_KIND_HS[2:0];
        reg_tx_pid  <= w_rsp_pid;
        reg_tx_len  <= 12'd0;
      end
      if (w_tk_in & (w_i_stall | ~w_i_have)) begin
        reg_tx_req  <= 1'b1;
        reg_tx_kind <= (w_i_iso & ~w_i_stall) ? LPARA_KIND_DATA[2:0] : LPARA_KIND_HS[2:0];
        reg_tx_pid  <= (w_i_iso & ~w_i_stall) ? LPARA_PID_DATA0[3:0] :
                       (w_i_stall ? LPARA_PID_STALL[3:0] : LPARA_PID_NAK[3:0]);
        reg_tx_len  <= 12'd0;
      end
      if (w_tk_ping) begin
        reg_tx_req  <= 1'b1;
        reg_tx_kind <= LPARA_KIND_HS[2:0];
        reg_tx_pid  <= w_o_stall ? LPARA_PID_STALL[3:0] :
                       ((w_o_act & ~w_o_nak & w_o_space) ? LPARA_PID_ACK[3:0] : LPARA_PID_NAK[3:0]);
        reg_tx_len  <= 12'd0;
      end
      if (w_tk_lpm) begin
        reg_tx_req  <= 1'b1;
        reg_tx_kind <= LPARA_KIND_HS[2:0];
        reg_tx_pid  <= (~w_lpm_l1 | (i_lpm_cfg[1:0] == 2'd2)) ? LPARA_PID_STALL[3:0] :
                       ((i_lpm_cfg[1:0] == 2'd1) ? LPARA_PID_NYET[3:0] : LPARA_PID_ACK[3:0]);
        reg_tx_len  <= 12'd0;
      end
    end
  end

  // Strobes of one transaction toward the per-endpoint state (decoded by endpoint index).
  always_comb begin : p_com_hit
    w_hit_o_commit = '0;
    w_hit_i_commit = '0;
    w_hit_o_nak    = '0;
    w_hit_i_nak    = '0;
    w_hit_o_stall  = '0;
    w_hit_i_stall  = '0;
    w_hit_setup    = '0;
    w_hit_iso_i    = '0;
    w_hit_iso_o    = '0;
    w_hit_unf      = '0;
    w_hit_ovf      = '0;
    w_hit_timeout  = '0;
    w_hit_nyet     = '0;
    w_o_done_hit   = '0;
    for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin
      if (reg_ep == idx[3:0]) begin
        w_hit_unf[idx]      = i_tx_starve;
        w_hit_o_commit[idx] = w_commit & ~reg_is_setup;
        w_hit_setup[idx]    = w_commit & reg_is_setup;
        w_hit_o_nak[idx]    = i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & i_dat_ok &
                              ~reg_o_accept & ~reg_o_stall & ~reg_o_iso;
        w_hit_o_stall[idx]  = i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & i_dat_ok &
                              reg_o_stall & ~reg_is_setup;
        w_hit_ovf[idx]      = i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & i_dat_ok &
                              ~reg_o_accept & reg_o_iso;
        w_hit_nyet[idx]     = w_rsp_send & (w_rsp_pid == LPARA_PID_NYET[3:0]);
        w_o_done_hit[idx]   = w_o_done;
        w_hit_i_commit[idx] = reg_txr_commit;
        w_hit_iso_o[idx]    = i_dat_end & (reg_fsm_dev_current_state == ENUM_ST_OUT_RX) & reg_o_iso &
                              ~(i_dat_ok & reg_o_accept);
      end
      // Hits of an IN token belong to the endpoint of the token, and the time-out to the endpoint
      // of the IN transaction in progress (BUG-010).
      if (w_tk_ep == idx[3:0]) begin
        w_hit_i_nak[idx]   = w_tk_in & ~w_i_stall & ~w_i_have & ~w_i_iso;
        w_hit_iso_i[idx]   = w_tk_in & ~w_i_stall & ~w_i_have & w_i_iso;
        w_hit_i_stall[idx] = w_tk_in & w_i_stall;
      end
      if (reg_ep == idx[3:0])
        w_hit_timeout[idx] = (reg_fsm_dev_current_state == ENUM_ST_IN_ACK) & w_wait_end & ~w_ack_rx;
    end
  end

  // Per-endpoint state: armed, NAK status, toggle, remaining counts and the command edges.
  generate
    for (genvar gen_ep = 0; gen_ep < PARA_USB2_NEP1; gen_ep++) begin : gen_ep_state
      logic [31:0] w_ci;
      logic [31:0] w_co;
      logic [31:0] w_edge_i;
      logic [31:0] w_edge_o;
      logic        w_i_done;
      logic [18:0] w_xs_i_nxt;
      logic [18:0] w_xs_o_nxt;
      logic [11:0] w_len_i;

      assign w_ci      = i_epi_ctrl[gen_ep];
      assign w_co      = i_epo_ctrl[gen_ep];
      assign w_edge_i  = w_ci & ~reg_cmd_i_seen[gen_ep];
      assign w_edge_o  = w_co & ~reg_cmd_o_seen[gen_ep];
      assign w_len_i   = reg_in_len;
      assign w_xs_i_nxt = (reg_xs_i[gen_ep] > {7'd0, w_len_i}) ? (reg_xs_i[gen_ep] - {7'd0, w_len_i}) : 19'd0;
      assign w_xs_o_nxt = (reg_xs_o[gen_ep] > {7'd0, i_dat_len}) ? (reg_xs_o[gen_ep] - {7'd0, i_dat_len}) : 19'd0;
      assign w_i_done   = w_hit_i_commit[gen_ep] &
                          ((reg_pc_i[gen_ep] == 10'd1) | ((w_xs_i_nxt == 19'd0) &
                           ~(w_ci[26] & (w_len_i == {1'b0, w_ci[10:0]}) & (w_len_i != 12'd0))));

      // Data available for this endpoint: armed, not NAK, not in test NAK, high-bandwidth
      // packets left in the
      // microframe, and the queue holds the rows of the next packet.
      logic [11:0] w_len_h;
      logic [16:0] w_rows_h;
      logic [1:0]  w_mult_h;
      logic        w_hb_h;
      logic        w_have_c;

      assign w_len_h  = (reg_xs_i[gen_ep] > {8'd0, w_ci[10:0]}) ? {1'b0, w_ci[10:0]} : reg_xs_i[gen_ep][11:0];
      assign w_rows_h = ({5'd0, w_len_h} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;
      assign w_mult_h = (w_ci[24:23] == 2'd0) ? 2'd1 : w_ci[24:23];
      assign w_hb_h   = (w_ci[12:11] == LPARA_TYPE_ISO[1:0]) & i_speed_hs;
      assign w_have_c = reg_act_i[gen_ep] & ~reg_nak_i[gen_ep] & ~i_test_nak &
                        ~(w_hb_h & (reg_txn_i[gen_ep] >= w_mult_h)) &
                        (i_ep_cnt[gen_ep*17 +: 17] >= w_rows_h);

      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_have
        if (!i_rst_n_core)
          reg_have_i[gen_ep] <= 1'b0;
        else
          reg_have_i[gen_ep] <= w_have_c;
      end

      // Command edges: the engine remembers the shadow bits and clears the commands in the CSR.
      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_cmd
        if (!i_rst_n_core) begin
          reg_cmd_i_seen[gen_ep] <= 32'd0;
          reg_cmd_o_seen[gen_ep] <= 32'd0;
        end else begin
          reg_cmd_i_seen[gen_ep] <= w_ci;
          reg_cmd_o_seen[gen_ep] <= w_co;
        end
      end

      // IN endpoint state.
      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_in
        if (!i_rst_n_core) begin
          reg_act_i[gen_ep]  <= 1'b0;
          reg_nak_i[gen_ep]  <= 1'b1;
          reg_dpid_i[gen_ep] <= 1'b0;
          reg_buf_i[gen_ep]  <= 1'b0;
          reg_txn_i[gen_ep]  <= 2'd0;
          reg_xs_i[gen_ep]   <= 19'd0;
          reg_pc_i[gen_ep]   <= 10'd0;
        end else begin
          if (w_edge_i[17])
            reg_nak_i[gen_ep] <= 1'b1;
          if (w_edge_i[18])
            reg_nak_i[gen_ep] <= 1'b0;
          if (w_edge_i[19])
            reg_dpid_i[gen_ep] <= 1'b0;
          if (w_edge_i[20])
            reg_dpid_i[gen_ep] <= 1'b1;
          if (w_edge_i[21])
            reg_act_i[gen_ep] <= 1'b0;
          if (w_edge_i[22]) begin
            reg_act_i[gen_ep] <= 1'b1;
            reg_nak_i[gen_ep] <= 1'b0;
            reg_xs_i[gen_ep]  <= i_epi_xfer[gen_ep][18:0];
            reg_pc_i[gen_ep]  <= i_epi_xfer[gen_ep][28:19];
          end
          if (w_hit_setup[gen_ep] & (gen_ep == 0)) begin
            reg_dpid_i[0] <= 1'b1;
            reg_nak_i[0]  <= 1'b0;
          end
          if (w_tk_sof & i_dev_act)
            reg_txn_i[gen_ep] <= 2'd0;
          if (w_hit_i_commit[gen_ep]) begin
            reg_txn_i[gen_ep]  <= reg_txn_i[gen_ep] + 2'd1;
            reg_xs_i[gen_ep]   <= w_xs_i_nxt;
            reg_pc_i[gen_ep]   <= (reg_pc_i[gen_ep] != 10'd0) ? (reg_pc_i[gen_ep] - 10'd1) : 10'd0;
            reg_dpid_i[gen_ep] <= ~reg_dpid_i[gen_ep];
            reg_buf_i[gen_ep]  <= ~reg_buf_i[gen_ep];
            if (w_i_done) begin
              reg_act_i[gen_ep] <= 1'b0;
              reg_nak_i[gen_ep] <= 1'b1;
            end
          end
        end
      end

      // OUT endpoint state.
      always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_out
        if (!i_rst_n_core) begin
          reg_act_o[gen_ep]  <= 1'b0;
          reg_nak_o[gen_ep]  <= 1'b1;
          reg_dpid_o[gen_ep] <= 1'b0;
          reg_buf_o[gen_ep]  <= 1'b0;
          reg_xs_o[gen_ep]   <= 19'd0;
          reg_pc_o[gen_ep]   <= 10'd0;
        end else begin
          if (w_edge_o[17])
            reg_nak_o[gen_ep] <= 1'b1;
          if (w_edge_o[18])
            reg_nak_o[gen_ep] <= 1'b0;
          if (w_edge_o[19])
            reg_dpid_o[gen_ep] <= 1'b0;
          if (w_edge_o[20])
            reg_dpid_o[gen_ep] <= 1'b1;
          if (w_edge_o[21])
            reg_act_o[gen_ep] <= 1'b0;
          if (w_edge_o[22]) begin
            reg_act_o[gen_ep] <= 1'b1;
            reg_nak_o[gen_ep] <= 1'b0;
            reg_xs_o[gen_ep]  <= i_epo_xfer[gen_ep][18:0];
            reg_pc_o[gen_ep]  <= i_epo_xfer[gen_ep][28:19];
          end
          if (w_hit_setup[gen_ep] & (gen_ep == 0)) begin
            reg_dpid_o[0] <= 1'b1;
            reg_nak_o[0]  <= 1'b0;
          end
          if (w_hit_o_commit[gen_ep]) begin
            reg_xs_o[gen_ep]   <= w_xs_o_nxt;
            reg_pc_o[gen_ep]   <= (reg_pc_o[gen_ep] != 10'd0) ? (reg_pc_o[gen_ep] - 10'd1) : 10'd0;
            reg_dpid_o[gen_ep] <= ~reg_dpid_o[gen_ep];
            reg_buf_o[gen_ep]  <= ~reg_buf_o[gen_ep];
            if (w_o_done_hit[gen_ep]) begin
              reg_act_o[gen_ep] <= 1'b0;
              reg_nak_o[gen_ep] <= 1'b1;
            end
          end
        end
      end

      // Published words (active, NAK status, toggle, buffer, remaining counts) and event sets.
      assign o_epi_ctrl_pub[gen_ep] = {4'd0, reg_buf_i[gen_ep], 10'd0, reg_dpid_i[gen_ep],
                                       reg_nak_i[gen_ep], reg_act_i[gen_ep], 14'd0};
      assign o_epo_ctrl_pub[gen_ep] = {4'd0, reg_buf_o[gen_ep], 10'd0, reg_dpid_o[gen_ep],
                                       reg_nak_o[gen_ep], reg_act_o[gen_ep], 14'd0};
      assign o_epi_xfer_pub[gen_ep] = {3'd0, reg_pc_i[gen_ep], reg_xs_i[gen_ep]};
      assign o_epo_xfer_pub[gen_ep] = {3'd0, reg_pc_o[gen_ep], reg_xs_o[gen_ep]};
      assign o_epi_int_set[gen_ep]  = {22'd0, w_hit_iso_i[gen_ep], 1'b0, w_hit_unf[gen_ep], 1'b0,
                                       w_hit_i_stall[gen_ep], 1'b0, w_hit_i_nak[gen_ep],
                                       w_hit_timeout[gen_ep], w_edge_i[21], w_i_done};
      assign o_epo_int_set[gen_ep]  = {22'd0, w_hit_iso_o[gen_ep], w_hit_setup[gen_ep], 1'b0, w_hit_ovf[gen_ep],
                                       w_hit_o_stall[gen_ep], w_hit_nyet[gen_ep] & w_hit_o_commit[gen_ep],
                                       w_hit_o_nak[gen_ep], 1'b0, w_edge_o[21], w_o_done_hit[gen_ep]};
      assign w_xfer_hit[gen_ep]     = (|(o_epi_int_set[gen_ep] & i_epi_int_en[gen_ep])) |
                                      (|(o_epo_int_set[gen_ep] & i_epo_int_en[gen_ep]));
      assign o_epi_ctrl_clr[gen_ep] = {9'd0, w_edge_i[22:17], 17'd0};
      assign o_epo_ctrl_clr[gen_ep] = {9'd0, w_edge_o[22:17], 17'd0};
    end
  endgenerate

  // Outputs of the engine: transmit request, FIFO commands and events.
  assign o_tx_req      = reg_tx_req;
  assign o_tx_kind     = reg_tx_kind;
  assign o_tx_pid      = reg_tx_pid;
  assign o_tx_len      = reg_tx_len;
  assign o_txr_start   = reg_txr_start;
  assign o_txr_q       = {1'b0, reg_ep} + 5'd1;
  assign o_txr_len     = reg_in_len;
  assign o_txr_commit  = reg_txr_commit;
  assign o_txr_cancel  = reg_txr_cancel;
  assign o_frame       = reg_frame;
  assign o_uframe      = reg_uframe;
  assign o_evt_sof     = reg_evt_sof;
  assign o_evt_xfer    = |w_xfer_hit;
  assign o_evt_udf     = i_tx_starve;
  assign o_lpm_vld     = reg_lpm_vld;
  assign o_lpm_hird    = reg_lpm_hird;
  assign o_lpm_rw      = reg_lpm_rw;

endmodule
