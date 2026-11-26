/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Speed, reset, chirp, suspend, resume, LPM and test-mode engine with the role
 *                selection (section 10.1, FEAT-013 to FEAT-019, DEC-009). Device side: attach as
 *                full-speed, detect bus reset (SE0), send the device chirp K, count the K and J
 *                pairs of the host, go high-speed or fall back to full-speed, suspend after 3 ms
 *                of idle, resume on a K and remote wake-up. Host side: debounced connect, port
 *                reset with the host chirp sequence, speed result, suspend, resume and
 *                disconnect. Chirp and test J and K are sent as a byte stream (K = 0x00, J =
 *                0xFF) with OpMode 2, the test packet as the 53-byte pattern of REF-001 7.1.20
 *                through the link. The SE0 drive of a host reset with OpMode 3 is an assumption
 *                to confirm with the PHY datasheet (TBD-015). All times are in microseconds,
 *                scaled by the CLK-PHY frequency and divided by PARA_USB2_TSCALE for simulation.
 */
`timescale 1ns/1ps

module m_usb2_spd #(
  // Parameter Description: CLK-PHY frequency in MHz; sets the cycle count of every time.
  // Parameter values: 30 or 60; default is 60.
  // Parameter unit: MHz
  parameter logic [31:0] PARA_USB2_CLK_MHZ = 60,
  // Parameter Description: divider of all timers for simulation (must be 1 in a netlist).
  // Parameter values: 1, 16, 256 or 4096; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_TSCALE = 1,
  // Parameter Description: role of the build: 0 device, 1 host, 2 dual-role by the ID pin.
  // Parameter values: 0, 1 or 2; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_ROLE = 2,
  // Parameter Description: UTMI+ data width; sets the bytes per chunk of the test packet source.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: 1 registers the PHY mode outputs (transceiver select, termination,
  // operation
  // mode, suspend, pull-downs); the outputs change one cycle later (timing option, DEC-025).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_MODE = 0,
  // Parameter Description: OpMode that the host drives for the SE0 of a port reset (TBD-015:
  // confirm with
  // the PHY datasheet).
  // Parameter values: 0 to 3; default is 3.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_RST_OPMODE = 3,
  localparam logic [31:0] LPARA_SH        = $clog2(PARA_USB2_TSCALE),
  localparam logic [31:0] LPARA_T_RSTDET  = (32'd3 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_FILT    = (32'd3 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_CHIRPK  = (32'd1600 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_CHWAIT  = (32'd2500 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_IDLE    = (32'd3000 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_RWAKE   = (32'd10000 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  // Line sampling 100 to 875 us after the reversion to full-speed (REQ-FUNC-018, BUG-014) and the
  // rest of the 5 ms of idle that a remote wakeup must wait for (REQ-FUNC-019, BUG-015).
  localparam logic [31:0] LPARA_T_REVERT  = (32'd400 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  // L1 entry of a device: 5 us after the accepted LPM token, so that the ACK has left the bus and
  // the limit of 10 us after the ACK holds (REQ-FUNC-021, BUG-016); not scaled by TSCALE.
  localparam logic [31:0] LPARA_T_L1      = 32'd5 * PARA_USB2_CLK_MHZ,
  localparam logic [31:0] LPARA_T_RWIDLE  = (32'd1800 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_HCHIRP  = (32'd50 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_HRSE0   = (32'd3000 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_HRST    = (32'd50000 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_HRSM    = (32'd20000 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_DBNC    = (32'd100000 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_T_TPKT    = (32'd100 * PARA_USB2_CLK_MHZ) >> LPARA_SH,
  localparam logic [31:0] LPARA_TMR_W     = 28,
  localparam logic [31:0] LPARA_ONE       = 1,
  localparam logic [31:0] LPARA_PAIRS     = 6,
  localparam logic [31:0] LPARA_TP_LEN    = 53,
  localparam logic [31:0] LPARA_PID_DATA0 = 32'h3,
  localparam logic [31:0] LPARA_W16       = 16
) (
  // Clock and reset
  input  wire         i_clk_phy,
  input  wire         i_rst_n_core,

  // PHY status
  input  wire  [1:0]  i_linestate,
  input  wire         i_vbusvalid,
  input  wire         i_iddig,
  input  wire         i_hostdisc,

  // CSR shadow words and the over-current state
  input  wire  [31:0] i_ctrl,
  input  wire  [31:0] i_dctrl,
  input  wire  [31:0] i_hport,
  input  wire         i_pwr_en,

  // Link activity and the transmit side (chirp and test streams, test packet request)
  input  wire         i_bus_act,
  input  wire         i_link_idle,
  output logic [15:0] o_ch_data,
  output logic [1:0]  o_ch_valid,
  output logic        o_ch_active,
  output logic        o_tp_req,
  output logic [3:0]  o_tp_pid,
  output logic [11:0] o_tp_len,
  output logic [15:0] o_tp_dat,
  input  wire         i_tp_pop,
  output logic        o_tp_vld,

  // Mode controls to the PHY interface
  output logic [1:0]  o_xcvr_sel,
  output logic        o_term_sel,
  output logic [1:0]  o_op_mode,
  output logic        o_suspend_n,
  output logic        o_dp_pd,
  output logic        o_dm_pd,
  output logic        o_drv_vbus,
  output logic        o_chrg_vbus,
  output logic        o_dischrg_vbus,
  output logic        o_id_pullup,

  // State to the engines and the CSR: role, speed, port state and events
  output logic        o_role_host,
  output logic        o_dev_act,
  output logic        o_test_nak,
  output logic        o_host_act,
  output logic        o_host_quiet,
  output logic [1:0]  o_speed,
  output logic        o_attached,
  output logic        o_suspended,
  output logic        o_l1_state,
  output logic        o_susp_det,
  output logic        o_port_en,
  output logic        o_evt_rst,
  output logic        o_evt_susp,
  output logic        o_evt_resume,
  output logic        o_evt_conn,
  output logic        o_evt_disc,
  output logic        o_evt_role,
  output logic        o_evt_enum,
  output logic        o_clr_rmt_wake,
  output logic        o_clr_port_rst,
  output logic        o_clr_port_susp,
  output logic        o_clr_port_res,
  input  wire         i_hlpm_ack,
  input  wire         i_lpm_vld,
  input  wire  [3:0]  i_lpm_hird,
  input  wire         i_lpm_rw,
  output logic [3:0]  o_lpm_hird,
  output logic        o_lpm_rw
);

  // FSM states of the device side.
  typedef enum logic [3:0] {
    ENUM_ST_DV_OFF   = 4'd0,
    ENUM_ST_DV_FS    = 4'd1,
    ENUM_ST_DV_RST   = 4'd2,
    ENUM_ST_DV_CHK   = 4'd3,
    ENUM_ST_DV_CHJ   = 4'd4,
    ENUM_ST_DV_HS    = 4'd5,
    ENUM_ST_DV_FSCHK = 4'd6,
    ENUM_ST_DV_SUSP  = 4'd7,
    ENUM_ST_DV_RWAKE = 4'd8,
    ENUM_ST_DV_RESM  = 4'd9
  } dev_state_type_def;

  // FSM states of the host side.
  typedef enum logic [3:0] {
    ENUM_ST_HP_OFF   = 4'd0,
    ENUM_ST_HP_DBNC  = 4'd1,
    ENUM_ST_HP_CONN  = 4'd2,
    ENUM_ST_HP_SE0   = 4'd3,
    ENUM_ST_HP_LISTK = 4'd4,
    ENUM_ST_HP_CHIRP = 4'd5,
    ENUM_ST_HP_RSTW  = 4'd6,
    ENUM_ST_HP_EN    = 4'd7,
    ENUM_ST_HP_SUSP  = 4'd8,
    ENUM_ST_HP_RESM  = 4'd9
  } host_state_type_def;

  // Internal signal declarations
  dev_state_type_def           reg_fsm_dv_current_state;
  dev_state_type_def           w_fsm_dv_nxt_state;
  host_state_type_def          reg_fsm_hp_current_state;
  host_state_type_def          w_fsm_hp_nxt_state;
  logic [LPARA_TMR_W-1:0]      reg_dtmr;
  logic [LPARA_TMR_W-1:0]      reg_htmr;
  logic [LPARA_TMR_W-1:0]      reg_atmr;
  logic [1:0]                  reg_ls_d;
  logic [3:0]                  reg_cnt_kj;
  logic [1:0]                  reg_last_kj;
  logic [LPARA_TMR_W-1:0]      reg_flt;
  logic                        reg_rw_pend;
  logic                        reg_rev_wait;
  logic                        reg_mode_rdy;
  logic                        reg_l1_go;
  logic                        reg_susp_j;
  logic                        reg_hs;
  logic                        reg_role_host;
  logic [1:0]                  reg_speed;
  logic                        reg_l1;
  logic [3:0]                  reg_hird;
  logic                        reg_rw;
  logic                        reg_evt_rst;
  logic                        reg_evt_susp;
  logic                        reg_evt_resume;
  logic                        reg_evt_conn;
  logic                        reg_evt_disc;
  logic                        reg_evt_role;
  logic                        reg_evt_enum;
  logic                        reg_clr_rw;
  logic                        reg_clr_prst;
  logic                        reg_clr_psusp;
  logic                        reg_clr_pres;
  logic [15:0]                 w_ch_data;
  logic [1:0]                  w_ch_valid;
  logic                        w_ch_act;
  logic                        w_mode_rdy;
  logic                        reg_hchirp_j;
  logic                        reg_port_en;
  logic                        reg_tp_req;
  logic [LPARA_TMR_W-1:0]      reg_tp_tmr;
  logic [5:0]                  reg_tp_idx;
  logic                        w_role_host;
  logic                        w_dev_conn;
  logic                        w_ls_se0;
  logic                        w_ls_j;
  logic                        w_ls_k;
  logic                        w_test_on;
  logic [2:0]                  w_test_mode;
  logic                        w_stream_on;
  logic                        w_stream_j;
  logic [7:0]                  w_tp_byte0;
  logic [7:0]                  w_tp_byte1;
  logic                        w_se0_det;
  logic                        w_idle_end;
  logic                        w_kj_ok;
  logic                        w_edge_prst;
  logic                        w_edge_psusp;
  logic                        w_edge_pres;
  logic                        w_edge_rwake;

  // Line state decode of the UTMI+ LineState (bit 0 = D+, bit 1 = D-).
  assign w_ls_se0 = (i_linestate == 2'b00);
  assign w_ls_j   = (i_linestate == 2'b01);
  assign w_ls_k   = (i_linestate == 2'b10);

  // Role: the CSR override, the ID pin in a dual-role build, or the fixed role of the build.
  assign w_role_host = (PARA_USB2_ROLE == 32'd1) ? 1'b1 :
                       (PARA_USB2_ROLE == 32'd0) ? 1'b0 :
                       (i_ctrl[3] ? i_ctrl[4] : ~i_iddig);

  // Test mode of the active role: the device field of u2_dctrl or the port field of u2_hport.
  assign w_test_mode = reg_role_host ? i_hport[7:5] : i_dctrl[12:10];
  // Reserved selector values (5 to 7 on a device, 6 and 7 on a host) leave normal operation
  // (BUG-020).
  assign w_test_on   = (w_test_mode != 3'd0) & i_ctrl[0] &
                       (w_test_mode <= (reg_role_host ? 3'd5 : 3'd4));
  assign w_stream_on = w_test_on & ((w_test_mode == 3'd1) | (w_test_mode == 3'd2));
  assign w_stream_j  = (w_test_mode == 3'd1);

  // Command edges of the CSR (the commands are rwi: they are cleared after the engine took them).
  assign w_edge_prst  = i_hport[0] & ~reg_clr_prst & reg_role_host;
  assign w_edge_psusp = (i_hport[1] & ~reg_clr_psusp & reg_role_host) | i_hlpm_ack;
  assign w_edge_pres  = i_hport[2] & ~reg_clr_pres & reg_role_host;
  assign w_edge_rwake = i_dctrl[8] & ~reg_clr_rw & ~reg_role_host;

  // Connection of the device: soft connect with a valid VBUS (B session) in a device role.
  assign w_dev_conn = i_dctrl[7] & i_vbusvalid & ~reg_role_host & i_ctrl[0];

  // The 53-byte payload of the test packet (REF-001 7.1.20): nine 00, eight AA, eight EE, FE,
  // eleven
  // FF and the 7F, BF, DF, EF, F7, FB, FD, FC, 7E, BF, DF, EF, F7, FB, FD, 7E tail.
  function automatic logic [7:0] f_tp_byte (input logic [5:0] i_idx);
    logic [7:0] w_b;
    w_b = 8'h00;
    case (i_idx)
      6'd0: w_b = 8'h00;
      6'd1: w_b = 8'h00;
      6'd2: w_b = 8'h00;
      6'd3: w_b = 8'h00;
      6'd4: w_b = 8'h00;
      6'd5: w_b = 8'h00;
      6'd6: w_b = 8'h00;
      6'd7: w_b = 8'h00;
      6'd8: w_b = 8'h00;
      6'd9: w_b = 8'hAA;
      6'd10: w_b = 8'hAA;
      6'd11: w_b = 8'hAA;
      6'd12: w_b = 8'hAA;
      6'd13: w_b = 8'hAA;
      6'd14: w_b = 8'hAA;
      6'd15: w_b = 8'hAA;
      6'd16: w_b = 8'hAA;
      6'd17: w_b = 8'hEE;
      6'd18: w_b = 8'hEE;
      6'd19: w_b = 8'hEE;
      6'd20: w_b = 8'hEE;
      6'd21: w_b = 8'hEE;
      6'd22: w_b = 8'hEE;
      6'd23: w_b = 8'hEE;
      6'd24: w_b = 8'hEE;
      6'd25: w_b = 8'hFE;
      6'd26: w_b = 8'hFF;
      6'd27: w_b = 8'hFF;
      6'd28: w_b = 8'hFF;
      6'd29: w_b = 8'hFF;
      6'd30: w_b = 8'hFF;
      6'd31: w_b = 8'hFF;
      6'd32: w_b = 8'hFF;
      6'd33: w_b = 8'hFF;
      6'd34: w_b = 8'hFF;
      6'd35: w_b = 8'hFF;
      6'd36: w_b = 8'hFF;
      6'd37: w_b = 8'h7F;
      6'd38: w_b = 8'hBF;
      6'd39: w_b = 8'hDF;
      6'd40: w_b = 8'hEF;
      6'd41: w_b = 8'hF7;
      6'd42: w_b = 8'hFB;
      6'd43: w_b = 8'hFD;
      6'd44: w_b = 8'hFC;
      6'd45: w_b = 8'h7E;
      6'd46: w_b = 8'hBF;
      6'd47: w_b = 8'hDF;
      6'd48: w_b = 8'hEF;
      6'd49: w_b = 8'hF7;
      6'd50: w_b = 8'hFB;
      6'd51: w_b = 8'hFD;
      6'd52: w_b = 8'h7E;
      default: w_b = 8'h00;
    endcase
    return w_b;
  endfunction

  // Part 1, sequential: the states of the two sides.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_fsm_dv
    if (!i_rst_n_core)
      reg_fsm_dv_current_state <= ENUM_ST_DV_OFF;
    else
      reg_fsm_dv_current_state <= w_fsm_dv_nxt_state;
  end

  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_fsm_hp
    if (!i_rst_n_core)
      reg_fsm_hp_current_state <= ENUM_ST_HP_OFF;
    else
      reg_fsm_hp_current_state <= w_fsm_hp_nxt_state;
  end

  // Part 2, combinational: next state of the device side.
  always_comb begin : p_com_dv_nxt
    w_fsm_dv_nxt_state = reg_fsm_dv_current_state;
    w_se0_det          = (reg_dtmr == '0);
    w_idle_end         = (reg_atmr == '0);
    w_kj_ok            = (reg_cnt_kj >= LPARA_PAIRS[3:0]);
    if (!w_dev_conn) begin
      w_fsm_dv_nxt_state = ENUM_ST_DV_OFF;
    end else begin
      case (reg_fsm_dv_current_state)
        ENUM_ST_DV_OFF: w_fsm_dv_nxt_state = ENUM_ST_DV_FS;
        ENUM_ST_DV_FS: begin
          if (w_ls_se0 & w_se0_det & ~reg_rev_wait)
            w_fsm_dv_nxt_state = ENUM_ST_DV_RST;
          else if (w_idle_end & w_ls_j)
            w_fsm_dv_nxt_state = ENUM_ST_DV_SUSP;
        end
        ENUM_ST_DV_RST: begin
          if (!w_ls_se0)
            w_fsm_dv_nxt_state = ENUM_ST_DV_FS;
          else if (~i_dctrl[13])
            w_fsm_dv_nxt_state = ENUM_ST_DV_CHK;
        end
        ENUM_ST_DV_CHK: begin
          if (reg_dtmr == '0)
            w_fsm_dv_nxt_state = ENUM_ST_DV_CHJ;
        end
        ENUM_ST_DV_CHJ: begin
          if (w_kj_ok)
            w_fsm_dv_nxt_state = ENUM_ST_DV_HS;
          else if (reg_dtmr == '0)
            w_fsm_dv_nxt_state = ENUM_ST_DV_FS;
        end
        // A test mode holds the high-speed state: no suspend or reset check until the next reset or
        // power cycle (REQ-FUNC-022, BUG-019).
        ENUM_ST_DV_HS: begin
          casez ({w_test_on, (reg_l1_go & (reg_htmr == '0)), w_idle_end})
            3'b1??:  w_fsm_dv_nxt_state = ENUM_ST_DV_HS;
            3'b01?:  w_fsm_dv_nxt_state = ENUM_ST_DV_SUSP;
            3'b001:  w_fsm_dv_nxt_state = ENUM_ST_DV_FSCHK;
            default: w_fsm_dv_nxt_state = ENUM_ST_DV_HS;
          endcase
        end
        ENUM_ST_DV_FSCHK: begin
          if (reg_dtmr == '0)
            w_fsm_dv_nxt_state = w_ls_se0 ? ENUM_ST_DV_RST : ENUM_ST_DV_SUSP;
        end
        // Suspend ends with a bus reset (SE0) or with resume signaling (K). The device stays in the
        // resume state until the host ends the resume, then goes back to its speed (BUG-013).
        ENUM_ST_DV_SUSP: begin
          casez ({((w_edge_rwake | reg_rw_pend) & i_dctrl[9] & (reg_dtmr == '0)), (reg_flt == '0), w_ls_se0, w_ls_k})
            4'b1???: w_fsm_dv_nxt_state = ENUM_ST_DV_RWAKE;
            4'b011?: w_fsm_dv_nxt_state = reg_susp_j ? ENUM_ST_DV_RST : ENUM_ST_DV_SUSP;
            4'b0101: w_fsm_dv_nxt_state = ENUM_ST_DV_RESM;
            default: w_fsm_dv_nxt_state = ENUM_ST_DV_SUSP;
          endcase
        end
        ENUM_ST_DV_RWAKE: begin
          if (reg_dtmr == '0)
            w_fsm_dv_nxt_state = ENUM_ST_DV_RESM;
        end
        ENUM_ST_DV_RESM: begin
          if (w_ls_se0)
            w_fsm_dv_nxt_state = reg_hs ? ENUM_ST_DV_HS : ENUM_ST_DV_FS;
        end
        default: w_fsm_dv_nxt_state = ENUM_ST_DV_OFF;
      endcase
    end
  end

  // Part 2, combinational: next state of the host side.
  always_comb begin : p_com_hp_nxt
    w_fsm_hp_nxt_state = reg_fsm_hp_current_state;
    if (!(reg_role_host & i_ctrl[0] & i_hport[3] & i_vbusvalid & i_pwr_en)) begin
      w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
    end else begin
      case (reg_fsm_hp_current_state)
        ENUM_ST_HP_OFF: begin
          if (!w_ls_se0)
            w_fsm_hp_nxt_state = ENUM_ST_HP_DBNC;
        end
        ENUM_ST_HP_DBNC: begin
          if (w_ls_se0)
            w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
          else if (reg_htmr == '0)
            w_fsm_hp_nxt_state = ENUM_ST_HP_CONN;
        end
        ENUM_ST_HP_CONN: begin
          if (w_edge_prst)
            w_fsm_hp_nxt_state = ENUM_ST_HP_SE0;
          else if (w_ls_se0 & (reg_flt == '0))
            w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
        end
        ENUM_ST_HP_SE0: begin
          if (reg_htmr == '0)
            // A low-speed device (K idle) never chirps: no listening (BUG-036).
            w_fsm_hp_nxt_state = (i_hport[21] | (reg_speed == 2'd2)) ? ENUM_ST_HP_RSTW : ENUM_ST_HP_LISTK;
        end
        ENUM_ST_HP_LISTK: begin
          // The listen window has its own timer (reg_htmr); reg_atmr keeps counting the 50 ms of
          // the whole reset (REQ-FUNC-011, BUG-047: the window reloaded reg_atmr, reset ~5 ms).
          if (w_ls_k & (reg_flt == '0))
            w_fsm_hp_nxt_state = ENUM_ST_HP_CHIRP;
          else if (reg_htmr == '0)
            w_fsm_hp_nxt_state = ENUM_ST_HP_RSTW;
        end
        ENUM_ST_HP_CHIRP: begin
          if ((reg_cnt_kj >= LPARA_PAIRS[3:0]) & reg_hchirp_j)
            w_fsm_hp_nxt_state = ENUM_ST_HP_RSTW;
        end
        ENUM_ST_HP_RSTW: begin
          if (reg_atmr == '0)
            w_fsm_hp_nxt_state = ENUM_ST_HP_EN;
        end
        ENUM_ST_HP_EN: begin
          casez ({(i_hostdisc & (reg_speed == 2'd0)), w_edge_psusp, w_edge_prst})
            3'b1??:  w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
            3'b01?:  w_fsm_hp_nxt_state = ENUM_ST_HP_SUSP;
            3'b001:  w_fsm_hp_nxt_state = ENUM_ST_HP_SE0;
            default: w_fsm_hp_nxt_state = ENUM_ST_HP_EN;
          endcase
        end
        ENUM_ST_HP_SUSP: begin
          if (w_edge_pres)
            w_fsm_hp_nxt_state = ENUM_ST_HP_RESM;
        end
        ENUM_ST_HP_RESM: begin
          if (reg_htmr == '0)
            w_fsm_hp_nxt_state = ENUM_ST_HP_EN;
        end
        default: w_fsm_hp_nxt_state = ENUM_ST_HP_OFF;
      endcase
    end
  end

  // Timers, filters and the chirp counters.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_timers
    if (!i_rst_n_core) begin
      reg_dtmr     <= '0;
      reg_htmr     <= '0;
      reg_atmr     <= '0;
      reg_flt      <= '0;
      reg_rw_pend  <= 1'b0;
      reg_rev_wait <= 1'b0;
      reg_l1_go    <= 1'b0;
      reg_susp_j   <= 1'b0;
      reg_ls_d     <= 2'b01;
      reg_cnt_kj   <= 4'd0;
      reg_last_kj  <= 2'd0;
      reg_hchirp_j <= 1'b0;
    end else begin
      reg_ls_d <= i_linestate;
      if (reg_dtmr != '0)
        reg_dtmr <= reg_dtmr - LPARA_ONE[LPARA_TMR_W-1:0];
      if (reg_htmr != '0)
        reg_htmr <= reg_htmr - LPARA_ONE[LPARA_TMR_W-1:0];
      if (reg_atmr != '0)
        reg_atmr <= reg_atmr - LPARA_ONE[LPARA_TMR_W-1:0];
      if (reg_flt != '0)
        reg_flt <= reg_flt - LPARA_ONE[LPARA_TMR_W-1:0];
      if (i_linestate != reg_ls_d)
        reg_flt <= LPARA_T_FILT[LPARA_TMR_W-1:0];
      // Device: SE0 filter, idle timer (restarted by bus activity), chirp times.
      if ((reg_fsm_dv_current_state == ENUM_ST_DV_FS) & ~w_ls_se0)
        reg_dtmr <= LPARA_T_RSTDET[LPARA_TMR_W-1:0];
      if (reg_fsm_dv_current_state != w_fsm_dv_nxt_state) begin
        case (w_fsm_dv_nxt_state)
          ENUM_ST_DV_CHK:   reg_dtmr <= LPARA_T_CHIRPK[LPARA_TMR_W-1:0];
          ENUM_ST_DV_CHJ:   begin
            reg_dtmr    <= LPARA_T_CHWAIT[LPARA_TMR_W-1:0];
            reg_cnt_kj  <= 4'd0;
            reg_last_kj <= 2'd0;
          end
          ENUM_ST_DV_RWAKE: reg_dtmr <= LPARA_T_RWAKE[LPARA_TMR_W-1:0];
          ENUM_ST_DV_FSCHK: reg_dtmr <= LPARA_T_REVERT[LPARA_TMR_W-1:0];
          ENUM_ST_DV_SUSP:  reg_dtmr <= LPARA_T_RWIDLE[LPARA_TMR_W-1:0];
          ENUM_ST_DV_FS:    reg_dtmr <= LPARA_T_RSTDET[LPARA_TMR_W-1:0];
          default:       reg_dtmr <= reg_dtmr;
        endcase
        reg_atmr <= LPARA_T_IDLE[LPARA_TMR_W-1:0];
      end
      // The idle time is measured only in the full-speed and high-speed active states; it restarts
      // in every other state so that it is full when the device becomes active again (BUG-013).
      // The host uses the same timer in its reset states, so this rule is for the device role only
      // (BUG-023: the first form of the BUG-013 fix reloaded the timer in host role as well).
      if (~reg_role_host & (i_bus_act | (!w_ls_j & (reg_fsm_dv_current_state == ENUM_ST_DV_FS)) |
          ((reg_fsm_dv_current_state != ENUM_ST_DV_FS) & (reg_fsm_dv_current_state != ENUM_ST_DV_HS))))
        reg_atmr <= LPARA_T_IDLE[LPARA_TMR_W-1:0];
      // L1 entry request of a device: set by the accepted LPM token, timed with the host timer
      // (unused in device role), cleared when the device leaves the active state.
      if (i_lpm_vld & ~reg_role_host) begin
        reg_l1_go <= 1'b1;
        reg_htmr  <= LPARA_T_L1[LPARA_TMR_W-1:0];
      end else if ((reg_fsm_dv_current_state != ENUM_ST_DV_HS) & (reg_fsm_dv_current_state != ENUM_ST_DV_FS)) begin
        reg_l1_go <= 1'b0;
      end
      // A bus reset in suspend is SE0 after J: the flag waits for J so that the SE0 seen while the
      // line settles after an L1 entry is not taken for a reset.
      if (reg_fsm_dv_current_state != ENUM_ST_DV_SUSP)
        reg_susp_j <= 1'b0;
      else if (w_ls_j)
        reg_susp_j <= 1'b1;
      // After the revert to full-speed (no chirp sequence, REF-001 7.1.7.5 b) the device waits for
      // the end of the reset: SE0 still on the bus does not start a new chirp (BUG-035).
      if ((reg_fsm_dv_current_state == ENUM_ST_DV_CHJ) & (w_fsm_dv_nxt_state == ENUM_ST_DV_FS))
        reg_rev_wait <= 1'b1;
      else if (!w_ls_se0)
        reg_rev_wait <= 1'b0;
      // A remote wakeup request written before the bus has been idle for 5 ms waits in suspend.
      if (reg_fsm_dv_current_state != ENUM_ST_DV_SUSP)
        reg_rw_pend <= 1'b0;
      else if (w_edge_rwake)
        reg_rw_pend <= 1'b1;
      // Chirp pair counter: a change between K and J after the filter time counts one half pair.
      if ((reg_fsm_dv_current_state == ENUM_ST_DV_CHJ) & (reg_flt == '0)) begin
        if (w_ls_k & (reg_last_kj != 2'd1)) begin
          reg_last_kj <= 2'd1;
          reg_cnt_kj  <= reg_cnt_kj + 4'd1;
        end else if (w_ls_j & (reg_last_kj != 2'd2)) begin
          reg_last_kj <= 2'd2;
          reg_cnt_kj  <= reg_cnt_kj + 4'd1;
        end
      end
      // Host: debounce, reset, listen window, chirp units, recovery.
      if (reg_fsm_hp_current_state != w_fsm_hp_nxt_state) begin
        case (w_fsm_hp_nxt_state)
          ENUM_ST_HP_DBNC:  reg_htmr <= LPARA_T_DBNC[LPARA_TMR_W-1:0];
          ENUM_ST_HP_SE0:   begin
            reg_htmr <= LPARA_T_HRSE0[LPARA_TMR_W-1:0];
            reg_atmr <= LPARA_T_HRST[LPARA_TMR_W-1:0];
          end
          ENUM_ST_HP_LISTK: reg_htmr <= LPARA_T_CHWAIT[LPARA_TMR_W-1:0];
          ENUM_ST_HP_CHIRP: begin
            reg_htmr     <= LPARA_T_HCHIRP[LPARA_TMR_W-1:0];
            reg_cnt_kj   <= 4'd0;
            reg_hchirp_j <= 1'b0;
          end
          ENUM_ST_HP_RESM:  reg_htmr <= LPARA_T_HRSM[LPARA_TMR_W-1:0];
          default:       reg_htmr <= reg_htmr;
        endcase
      end
      if ((reg_fsm_hp_current_state == ENUM_ST_HP_CHIRP) & (reg_htmr == '0)) begin
        reg_htmr     <= LPARA_T_HCHIRP[LPARA_TMR_W-1:0];
        reg_hchirp_j <= ~reg_hchirp_j;
        if (reg_hchirp_j)
          reg_cnt_kj <= reg_cnt_kj + 4'd1;
      end
    end
  end

  // Test packet: a request every 100 us while the test mode is the packet mode.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_tp
    if (!i_rst_n_core) begin
      reg_tp_req <= 1'b0;
      reg_tp_tmr <= '0;
      reg_tp_idx <= 6'd0;
    end else begin
      reg_tp_req <= 1'b0;
      if (w_test_on & (w_test_mode == 3'd4)) begin
        if (reg_tp_tmr != '0)
          reg_tp_tmr <= reg_tp_tmr - LPARA_ONE[LPARA_TMR_W-1:0];
        else if (i_link_idle) begin
          reg_tp_req <= 1'b1;
          reg_tp_tmr <= LPARA_T_TPKT[LPARA_TMR_W-1:0];
          reg_tp_idx <= 6'd0;
        end
        if (i_tp_pop)
          reg_tp_idx <= reg_tp_idx + ((PARA_USB2_UTMI_W == LPARA_W16) ? 6'd2 : 6'd1);
      end else begin
        reg_tp_idx <= 6'd0;
        reg_tp_tmr <= '0;
      end
    end
  end

  assign w_tp_byte0 = f_tp_byte(reg_tp_idx);
  assign w_tp_byte1 = f_tp_byte(reg_tp_idx + 6'd1);

  // Registered flags and events of both sides.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_state
    if (!i_rst_n_core) begin
      reg_hs         <= 1'b0;
      reg_role_host  <= 1'b0;
      reg_speed      <= 2'd1;
      reg_l1         <= 1'b0;
      reg_hird       <= 4'd0;
      reg_rw         <= 1'b0;
      reg_evt_rst    <= 1'b0;
      reg_evt_susp   <= 1'b0;
      reg_evt_resume <= 1'b0;
      reg_evt_conn   <= 1'b0;
      reg_evt_disc   <= 1'b0;
      reg_evt_role   <= 1'b0;
      reg_evt_enum   <= 1'b0;
      reg_clr_rw     <= 1'b0;
      reg_clr_prst   <= 1'b0;
      reg_clr_psusp  <= 1'b0;
      reg_clr_pres   <= 1'b0;
      reg_port_en    <= 1'b0;
    end else begin
      reg_evt_rst    <= 1'b0;
      reg_evt_susp   <= 1'b0;
      reg_evt_resume <= 1'b0;
      reg_evt_conn   <= 1'b0;
      reg_evt_disc   <= 1'b0;
      reg_evt_role   <= 1'b0;
      reg_evt_enum   <= 1'b0;
      reg_clr_rw     <= i_dctrl[8] & ~reg_role_host & (reg_clr_rw | w_edge_rwake);
      reg_clr_prst   <= i_hport[0] & (reg_clr_prst | w_edge_prst);
      reg_clr_psusp  <= i_hport[1] & (reg_clr_psusp | w_edge_psusp);
      reg_clr_pres   <= i_hport[2] & (reg_clr_pres | w_edge_pres);
      if (i_lpm_vld | i_hlpm_ack) begin
        reg_l1   <= 1'b1;
        reg_hird <= i_hlpm_ack ? i_hport[12:9] : i_lpm_hird;
        reg_rw   <= i_hlpm_ack ? i_hport[13] : i_lpm_rw;
      end
      // Role change only while detached.
      if (w_role_host != reg_role_host) begin
        if ((reg_fsm_dv_current_state == ENUM_ST_DV_OFF) & (reg_fsm_hp_current_state == ENUM_ST_HP_OFF)) begin
          reg_role_host <= w_role_host;
          reg_evt_role  <= 1'b1;
        end
      end
      // Device side events and speed.
      if (reg_fsm_dv_current_state != w_fsm_dv_nxt_state) begin
        case (w_fsm_dv_nxt_state)
          ENUM_ST_DV_RST:  reg_evt_rst <= 1'b1;
          ENUM_ST_DV_HS: begin
            reg_hs    <= 1'b1;
            reg_speed <= 2'd0;
            if (reg_fsm_dv_current_state == ENUM_ST_DV_CHJ)
              reg_evt_enum <= 1'b1;
            if (reg_fsm_dv_current_state == ENUM_ST_DV_RESM) begin
              reg_evt_resume <= 1'b1;
              reg_l1         <= 1'b0;
            end
          end
          ENUM_ST_DV_FS: begin
            reg_hs    <= 1'b0;
            reg_speed <= 2'd1;
            if (reg_fsm_dv_current_state == ENUM_ST_DV_OFF)
              reg_evt_conn <= 1'b1;
            if (reg_fsm_dv_current_state == ENUM_ST_DV_RESM) begin
              reg_evt_resume <= 1'b1;
              reg_l1         <= 1'b0;
            end
            if (reg_fsm_dv_current_state == ENUM_ST_DV_CHJ | reg_fsm_dv_current_state == ENUM_ST_DV_RST)
              reg_evt_enum <= 1'b1;
          end
          ENUM_ST_DV_SUSP:  reg_evt_susp <= 1'b1;
          ENUM_ST_DV_OFF:   reg_evt_disc <= (reg_fsm_dv_current_state != ENUM_ST_DV_OFF);
          default:       reg_hs <= reg_hs;
        endcase
      end
      // Host side events and speed.
      if (reg_fsm_hp_current_state != w_fsm_hp_nxt_state) begin
        case (w_fsm_hp_nxt_state)
          ENUM_ST_HP_CONN: begin
            reg_evt_conn <= 1'b1;
            reg_speed    <= w_ls_k ? 2'd2 : 2'd1;
          end
          ENUM_ST_HP_SE0:  reg_port_en <= 1'b0;
          ENUM_ST_HP_CHIRP: reg_speed <= 2'd0;
          ENUM_ST_HP_EN: begin
            reg_port_en <= 1'b1;
            reg_evt_rst <= 1'b1;
            if (reg_fsm_hp_current_state == ENUM_ST_HP_RSTW)
              reg_evt_enum <= 1'b1;
          end
          ENUM_ST_HP_SUSP: reg_evt_susp <= 1'b1;
          ENUM_ST_HP_OFF: begin
            reg_evt_disc <= (reg_fsm_hp_current_state != ENUM_ST_HP_OFF);
            reg_port_en  <= 1'b0;
          end
          default:      reg_port_en <= reg_port_en;
        endcase
        if ((reg_fsm_hp_current_state == ENUM_ST_HP_RSTW) & (w_fsm_hp_nxt_state == ENUM_ST_HP_EN) &
            (reg_cnt_kj < LPARA_PAIRS[3:0]))
          reg_speed <= (i_linestate == 2'b10) ? 2'd2 : 2'd1;
        if ((reg_fsm_hp_current_state == ENUM_ST_HP_RESM) & (w_fsm_hp_nxt_state == ENUM_ST_HP_EN))
          reg_evt_resume <= 1'b1;
      end
    end
  end

  logic [1:0]              w_xcvr_sel;
  logic                    w_term_sel;
  logic [1:0]              w_op_mode;
  logic                    w_suspend_n;
  logic                    w_dp_pd;
  logic                    w_dm_pd;
  logic                    w_id_pullup;
  logic [1:0]              reg_xcvr_sel;
  logic                    reg_term_sel;
  logic [1:0]              reg_op_mode;
  logic                    reg_suspend_n;
  logic                    reg_dp_pd;
  logic                    reg_dm_pd;
  logic                    reg_id_pullup;

  // Stream to the PHY for chirp, resume K and the test J and K: all bytes 0x00 (K) or 0xFF (J).
  always_comb begin : p_com_stream
    w_ch_act = 1'b0;
    w_ch_data = 16'h0000;
    w_ch_valid = 2'b00;
    case (reg_fsm_dv_current_state)
      ENUM_ST_DV_CHK, ENUM_ST_DV_RWAKE: begin
        w_ch_act  = 1'b1;
        w_ch_data  = 16'h0000;
        w_ch_valid = 2'b11;
      end
      default: begin
        w_ch_act = 1'b0;
      end
    endcase
    if (reg_fsm_hp_current_state == ENUM_ST_HP_CHIRP) begin
      w_ch_act  = 1'b1;
      w_ch_data  = reg_hchirp_j ? 16'hFFFF : 16'h0000;
      w_ch_valid = 2'b11;
    end
    if (reg_fsm_hp_current_state == ENUM_ST_HP_RESM) begin
      w_ch_act  = 1'b1;
      w_ch_data  = 16'h0000;
      w_ch_valid = 2'b11;
    end
    if (w_stream_on) begin
      w_ch_act  = 1'b1;
      w_ch_data  = w_stream_j ? 16'hFFFF : 16'h0000;
      w_ch_valid = 2'b11;
    end
  end

  // Mode controls: device and host settings by state, the PHY power controls from the CSR.
  always_comb begin : p_com_mode
    w_xcvr_sel     = 2'b01;
    w_term_sel     = 1'b0;
    w_op_mode      = 2'b00;
    w_suspend_n    = 1'b1;
    w_dp_pd        = reg_role_host;
    w_dm_pd        = reg_role_host;
    w_id_pullup    = (PARA_USB2_ROLE == 32'd2);
    if (!reg_role_host) begin
      case (reg_fsm_dv_current_state)
        ENUM_ST_DV_FS, ENUM_ST_DV_RST, ENUM_ST_DV_FSCHK, ENUM_ST_DV_RESM: begin
          w_xcvr_sel = 2'b01;
          w_term_sel = 1'b1;
        end
        // Device chirp and wait for the hub chirps: high-speed transceiver with the full-speed
        // termination kept; TermSelect goes to high-speed only after K-J-K-J-K-J (BUG-004).
        ENUM_ST_DV_CHK: begin
          w_xcvr_sel = 2'b00;
          w_term_sel = 1'b1;
          w_op_mode  = 2'b10;
        end
        ENUM_ST_DV_CHJ: begin
          w_xcvr_sel = 2'b00;
          w_term_sel = 1'b1;
          w_op_mode  = 2'b10;
        end
        ENUM_ST_DV_HS: begin
          w_xcvr_sel = 2'b00;
          w_term_sel = 1'b0;
        end
        ENUM_ST_DV_SUSP: begin
          w_xcvr_sel  = reg_hs ? 2'b00 : 2'b01;
          w_term_sel  = ~reg_hs;
          w_suspend_n = 1'b0;
        end
        ENUM_ST_DV_RWAKE: begin
          w_xcvr_sel = 2'b01;
          w_term_sel = 1'b1;
          w_op_mode  = 2'b10;
        end
        default: begin
          w_xcvr_sel = 2'b01;
        end
      endcase
    end else begin
      case (reg_fsm_hp_current_state)
        ENUM_ST_HP_OFF, ENUM_ST_HP_DBNC, ENUM_ST_HP_CONN: begin
          w_xcvr_sel = 2'b01;
          w_term_sel = 1'b1;
        end
        ENUM_ST_HP_SE0: begin
          w_xcvr_sel = 2'b01;
          w_term_sel = 1'b1;
          w_op_mode  = PARA_USB2_RST_OPMODE[1:0];
        end
        ENUM_ST_HP_LISTK, ENUM_ST_HP_CHIRP: begin
          w_xcvr_sel = 2'b00;
          w_term_sel = 1'b0;
          w_op_mode  = 2'b10;
        end
        ENUM_ST_HP_RSTW: begin
          // Rest of the 50 ms reset: a high-speed port keeps the high-speed idle (SE0 under the
          // high-speed terminations); a full- or low-speed port keeps driving SE0, otherwise the
          // bus returned to idle when the listen window ended (REQ-FUNC-011, BUG-047).
          w_xcvr_sel = (reg_speed == 2'd0) ? 2'b00 : 2'b01;
          w_term_sel = (reg_speed != 2'd0);
          w_op_mode  = (reg_speed == 2'd0) ? 2'b00 : PARA_USB2_RST_OPMODE[1:0];
        end
        ENUM_ST_HP_EN: begin
          w_xcvr_sel = (reg_speed == 2'd0) ? 2'b00 : ((reg_speed == 2'd2) ? 2'b10 : 2'b01);
          w_term_sel = (reg_speed != 2'd0);
        end
        ENUM_ST_HP_SUSP: begin
          w_xcvr_sel  = (reg_speed == 2'd0) ? 2'b00 : ((reg_speed == 2'd2) ? 2'b10 : 2'b01);
          w_term_sel  = (reg_speed != 2'd0);
          w_suspend_n = 1'b0;
        end
        ENUM_ST_HP_RESM: begin
          w_xcvr_sel = (reg_speed == 2'd0) ? 2'b00 : ((reg_speed == 2'd2) ? 2'b10 : 2'b01);
          w_term_sel = (reg_speed != 2'd0);
          w_op_mode  = 2'b10;
        end
        default: begin
          w_xcvr_sel = 2'b01;
        end
      endcase
    end
    if (w_stream_on)
      w_op_mode = 2'b10;
    // Link loopback (u2_ctrl.lpbk, section 6.3): full-speed transceiver with non-driving OpMode.
    if (i_ctrl[7]) begin
      w_xcvr_sel = 2'b01;
      w_term_sel = 1'b1;
      w_op_mode  = 2'b01;
    end
  end

  // The stream gate: OpMode was 10b on the pins in the previous cycle.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_mode_rdy
    if (!i_rst_n_core)
      reg_mode_rdy <= 1'b0;
    else
      reg_mode_rdy <= (o_op_mode == 2'b10);
  end

  // Optional register stage on the mode outputs (PARA_USB2_PIPE_MODE).
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_mode
    if (!i_rst_n_core) begin
      reg_xcvr_sel  <= 2'b01;
      reg_term_sel  <= 1'b0;
      reg_op_mode   <= 2'b00;
      reg_suspend_n <= 1'b1;
      reg_dp_pd     <= 1'b0;
      reg_dm_pd     <= 1'b0;
      reg_id_pullup <= 1'b0;
    end else begin
      reg_xcvr_sel  <= w_xcvr_sel;
      reg_term_sel  <= w_term_sel;
      reg_op_mode   <= w_op_mode;
      reg_suspend_n <= w_suspend_n;
      reg_dp_pd     <= w_dp_pd;
      reg_dm_pd     <= w_dm_pd;
      reg_id_pullup <= w_id_pullup;
    end
  end

  assign o_xcvr_sel  = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_xcvr_sel : w_xcvr_sel;
  assign o_term_sel  = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_term_sel : w_term_sel;
  assign o_op_mode   = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_op_mode : w_op_mode;
  assign o_suspend_n = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_suspend_n : w_suspend_n;
  assign o_dp_pd     = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_dp_pd : w_dp_pd;
  assign o_dm_pd     = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_dm_pd : w_dm_pd;
  assign o_id_pullup = (PARA_USB2_PIPE_MODE != 32'd0) ? reg_id_pullup : w_id_pullup;

  // Outputs.
  // DrvVbus follows the port power state of the over-current block, including the latched
  // power-off state after the input has returned (REQ-FUNC-041, BUG-024).
  assign o_drv_vbus     = reg_role_host & i_hport[3] & i_pwr_en;
  assign o_chrg_vbus    = 1'b0;
  assign o_dischrg_vbus = ~(reg_role_host & i_hport[3]);
  assign o_role_host    = reg_role_host;
  assign o_test_nak     = w_test_on & (w_test_mode == 3'd3) & ~reg_role_host;
  assign o_dev_act      = ~reg_role_host & (reg_fsm_dv_current_state != ENUM_ST_DV_OFF) &
                          (reg_fsm_dv_current_state != ENUM_ST_DV_CHK) &
                          (reg_fsm_dv_current_state != ENUM_ST_DV_CHJ) &
                          (~w_test_on | (w_test_mode == 3'd3));
  assign o_host_act     = reg_role_host & reg_port_en & ~w_test_on;
  // The host port sends nothing while it is suspended (also L1) or drives the resume K; the
  // frame timer keeps counting (o_host_act), so SOF restarts in phase (REQ-FUNC-020, 021, 037,
  // BUG-048).
  assign o_host_quiet   = reg_role_host & ((reg_fsm_hp_current_state == ENUM_ST_HP_SUSP) |
                                           (reg_fsm_hp_current_state == ENUM_ST_HP_RESM));
  assign o_speed        = reg_speed;
  assign o_attached     = reg_role_host ? (reg_fsm_hp_current_state != ENUM_ST_HP_OFF) &
                                          (reg_fsm_hp_current_state != ENUM_ST_HP_DBNC) :
                          (reg_fsm_dv_current_state != ENUM_ST_DV_OFF);
  assign o_suspended    = reg_role_host ? (reg_fsm_hp_current_state == ENUM_ST_HP_SUSP) :
                          (reg_fsm_dv_current_state == ENUM_ST_DV_SUSP);
  assign o_l1_state     = reg_l1 & o_suspended;
  assign o_susp_det     = (reg_fsm_dv_current_state == ENUM_ST_DV_SUSP);
  assign o_port_en      = reg_port_en;
  assign o_evt_rst      = reg_evt_rst;
  assign o_evt_susp     = reg_evt_susp;
  assign o_evt_resume   = reg_evt_resume;
  assign o_evt_conn     = reg_evt_conn;
  assign o_evt_disc     = reg_evt_disc;
  assign o_evt_role     = reg_evt_role;
  assign o_evt_enum     = reg_evt_enum;
  assign o_clr_rmt_wake = w_edge_rwake;
  assign o_clr_port_rst = w_edge_prst;
  assign o_clr_port_susp = w_edge_psusp;
  assign o_clr_port_res = w_edge_pres;
  assign o_lpm_hird     = reg_hird;
  assign o_lpm_rw       = reg_rw;
  assign o_ch_data      = w_ch_data;
  // The chirp, resume and test streams start only when the OpMode pin has shown 10b for one cycle,
  // so TXValid never leads the mode pins (BUG-021; BUG-034: without the mode register stage and,
  // with it, the registered pin and TXValid used to rise in the same cycle).
  assign w_mode_rdy  = reg_mode_rdy;
  assign o_ch_valid  = w_mode_rdy ? w_ch_valid : 2'b00;
  assign o_ch_active = w_ch_act & w_mode_rdy;
  assign o_tp_req       = reg_tp_req;
  assign o_tp_pid       = LPARA_PID_DATA0[3:0];
  assign o_tp_len       = LPARA_TP_LEN[11:0];
  assign o_tp_dat       = (PARA_USB2_UTMI_W == LPARA_W16) ? {w_tp_byte1, w_tp_byte0} : {8'h00, w_tp_byte0};
  assign o_tp_vld       = w_test_on & (w_test_mode == 3'd4);

endmodule
