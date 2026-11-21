import re
p = '../rtl/m_usb2_host.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


# states
rep("    ENUM_ST_DONE    = 4'd9\n", "    ENUM_ST_DONE    = 4'd9,\n    ENUM_ST_LPM_EXT = 4'd10,\n    ENUM_ST_LPM_TOK = 4'd11,\n    ENUM_ST_LPM_WT  = 4'd12\n")
# ports
_m = re.search(r"  output logic +o_host_busy\n", s)
assert _m
_pad = _m.group(0).split('o_host_busy')[0]
s = s.replace(_m.group(0), _pad + "o_host_busy,\n" + _pad + "o_lpm_evt,\n" + _pad + "o_lpm_ack,\n" + _pad + "o_lpm_clr\n")
# declarations
rep("  logic                                     reg_bab;\n",
    "  logic                                     reg_bab;\n  logic                                     reg_lpm_seen;\n  logic                                     w_lpm_start;\n"
    "  logic                                     reg_lpm_evt;\n  logic                                     reg_lpm_ack;\n  logic                                     reg_lpm_clr;\n")
# start condition
rep("  assign w_data_ok  = i_dat_end & i_dat_ok & reg_rx_acc;",
    "  assign w_data_ok  = i_dat_end & i_dat_ok & reg_rx_acc;\n"
    "  assign w_lpm_start = i_hport[8] & ~reg_lpm_seen & i_host_act & ~reg_sof_pend;")
# FSM next state
rep("""        casez ({reg_sof_pend & w_sof_en, w_pick_vld & ~reg_done_p & i_host_act & ~reg_sof_pend})
          2'b1?:   w_fsm_host_nxt_state = ENUM_ST_SOF;
          2'b01:   w_fsm_host_nxt_state = ENUM_ST_PREP;
          default: w_fsm_host_nxt_state = ENUM_ST_IDLE;
        endcase
      end""",
    """        casez ({reg_sof_pend & w_sof_en, w_lpm_start, w_pick_vld & ~reg_done_p & i_host_act & ~reg_sof_pend})
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
      end""")
# datapath: request of the EXT token at the start, the LPM token after it, timeout, result
rep("        ENUM_ST_IDLE: begin\n          if (reg_sof_pend & w_sof_en) begin",
    """        ENUM_ST_IDLE: begin
          if (w_lpm_start & ~(reg_sof_pend & w_sof_en)) begin
            reg_tx_req  <= 1'b1;
            reg_tx_kind <= LPARA_KIND_TOK[2:0];
            reg_tx_pid  <= 4'h0;
            reg_tx_fld  <= {12'd0, i_hport[20:14]};
            reg_tx_len  <= 12'd0;
            reg_tmo     <= PARA_USB2_RSP_TMO[LPARA_TMO_W-1:0];
          end else if (reg_sof_pend & w_sof_en) begin""")
rep("        ENUM_ST_PREP: begin\n          if (reg_prep != 4'd0)",
    """        ENUM_ST_LPM_EXT: begin
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
          if (reg_prep != 4'd0)""")
# LPM result flops
rep("  // Strobes of the finished transaction toward the per-channel state:",
    """  // LPM request: the seen flag follows the CSR bit; the result is an event, an ACK pulse for the
  // speed engine and the clear of the request bit.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_lpm
    if (!i_rst_n_core) begin
      reg_lpm_seen <= 1'b0;
      reg_lpm_evt  <= 1'b0;
      reg_lpm_ack  <= 1'b0;
      reg_lpm_clr  <= 1'b0;
    end else begin
      reg_lpm_seen <= i_hport[8];
      reg_lpm_evt  <= 1'b0;
      reg_lpm_ack  <= 1'b0;
      reg_lpm_clr  <= w_lpm_start;
      if ((reg_fsm_host_current_state == ENUM_ST_LPM_WT) & (i_hs_vld | w_wait_end)) begin
        reg_lpm_evt <= 1'b1;
        reg_lpm_ack <= w_ack_hs;
      end
    end
  end

  // Strobes of the finished transaction toward the per-channel state:""")
rep("  assign o_host_busy  = (reg_fsm_host_current_state != ENUM_ST_IDLE);",
    "  assign o_host_busy  = (reg_fsm_host_current_state != ENUM_ST_IDLE);\n  assign o_lpm_evt    = reg_lpm_evt;\n  assign o_lpm_ack    = reg_lpm_ack;\n  assign o_lpm_clr    = reg_lpm_clr;")
open(p, 'w').write(s)

# spd: host LPM ACK enters L1 suspend
q = open('../rtl/m_usb2_spd.sv').read()
q = q.replace("  input  wire         i_lpm_vld,", "  input  wire         i_hlpm_ack,\n  input  wire         i_lpm_vld,")
q = q.replace("assign w_edge_psusp = i_hport[1] & ~reg_clr_psusp & reg_role_host;",
              "assign w_edge_psusp = (i_hport[1] & ~reg_clr_psusp & reg_role_host) | i_hlpm_ack;")
q = q.replace("      if (i_lpm_vld) begin", "      if (i_lpm_vld | i_hlpm_ack) begin")
q = q.replace("        reg_hird <= i_lpm_hird;\n        reg_rw   <= i_lpm_rw;", "        reg_hird <= i_hlpm_ack ? i_hport[12:9] : i_lpm_hird;\n        reg_rw   <= i_hlpm_ack ? i_hport[13] : i_lpm_rw;")
open('../rtl/m_usb2_spd.sv', 'w').write(q)

# core generator: wiring, events and the clear of lpm_req
c = open('core_body2.py').read()
c = c.replace("    e('        .o_host_busy     (w_host_busy)')", "    e('        .o_host_busy     (w_host_busy),')\n    e('        .o_lpm_evt       (w_host_lpm_evt),')\n    e('        .o_lpm_ack       (w_host_lpm_ack),')\n    e('        .o_lpm_clr       (w_host_lpm_clr)')")
c = c.replace("('frame', \"14'd0\"), ('busy', \"1'b0\"))", "('frame', \"14'd0\"), ('busy', \"1'b0\"), ('lpm_evt', \"1'b0\"), ('lpm_ack', \"1'b0\"), ('lpm_clr', \"1'b0\"))")
c = c.replace("    e('    .i_lpm_vld       (w_dev_lpm_vld),')", "    e('    .i_hlpm_ack      (w_host_lpm_ack),')\n    e('    .i_lpm_vld       (w_dev_lpm_vld),')")
c = c.replace("w_dev_lpm_vld, 1'b0, 1'b0, 1'b0, w_fifo_ovf,", "(w_dev_lpm_vld | w_host_lpm_evt), 1'b0, 1'b0, 1'b0, w_fifo_ovf,")
c = c.replace("{29'd0, w_clr_port_res, w_clr_port_susp, w_clr_port_rst}", "{23'd0, w_host_lpm_clr, 5'd0, w_clr_port_res, w_clr_port_susp, w_clr_port_rst}")
open('core_body2.py', 'w').write(c)
b = open('core_body.py').read()
b = b.replace("('host_frame', '[13:0]'), ('host_busy', '')", "('host_frame', '[13:0]'), ('host_busy', ''), ('host_lpm_evt', ''), ('host_lpm_ack', ''), ('host_lpm_clr', '')") if False else b
b = b.replace("('w_host_frame', '[13:0]'), ('w_host_busy', '')", "('w_host_frame', '[13:0]'), ('w_host_busy', ''), ('w_host_lpm_evt', ''), ('w_host_lpm_ack', ''), ('w_host_lpm_clr', '')")
open('core_body.py', 'w').write(b)
print('ok')
