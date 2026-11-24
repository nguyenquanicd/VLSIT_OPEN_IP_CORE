import re
p = '../rtl/m_usb2_dev.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


# port for Test_SE0_NAK
s = re.sub(r"(  input  wire\s+i_speed_hs,\n)", r"\1  input  wire                               i_test_nak,\n", s, count=1)
# declarations
rep("  logic [PARA_USB2_NEP1-1:0]                reg_buf_i;\n",
    "  logic [PARA_USB2_NEP1-1:0]                reg_buf_i;\n  logic [PARA_USB2_NEP1-1:0][1:0]           reg_txn_i;\n"
    "  logic [1:0]                               w_mult;\n  logic [1:0]                               w_rem;\n  logic                                     w_hb;\n  logic [3:0]                               w_hb_pid;\n")
# high-bandwidth view
rep("  assign w_i_iso   = (w_i_type == LPARA_TYPE_ISO[1:0]);",
    """  assign w_i_iso   = (w_i_type == LPARA_TYPE_ISO[1:0]);
  assign w_hb      = w_i_iso & i_speed_hs;
  assign w_mult    = (i_epi_ctrl[w_tk_ep][24:23] == 2'd0) ? 2'd1 : i_epi_ctrl[w_tk_ep][24:23];
  assign w_rem     = w_mult - reg_txn_i[w_tk_ep];""")
rep("  assign w_i_have  = w_i_act & ~reg_nak_i[w_tk_ep] &",
    "  assign w_i_have  = w_i_act & ~reg_nak_i[w_tk_ep] & ~i_test_nak & ~(w_hb & (reg_txn_i[w_tk_ep] >= w_mult)) &")
# PID of the data packet: DATA2, DATA1, DATA0 by the packets left in the microframe
a = s.index("        reg_in_pid     <= reg_dpid_i[w_tk_ep] ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0];")
s = s.replace("        reg_in_pid     <= reg_dpid_i[w_tk_ep] ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0];",
              "        reg_in_pid     <= w_hb ? w_hb_pid : (reg_dpid_i[w_tk_ep] ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0]);")
rep("  assign w_hb      = w_i_iso & i_speed_hs;",
    "  assign w_hb      = w_i_iso & i_speed_hs;\n  assign w_hb_pid  = (w_rem >= 2'd3) ? LPARA_PID_DATA2[3:0] : ((w_rem == 2'd2) ? LPARA_PID_DATA1[3:0] : LPARA_PID_DATA0[3:0]);")
rep("  localparam logic [31:0] LPARA_PID_DATA1 = 32'hB,", "  localparam logic [31:0] LPARA_PID_DATA1 = 32'hB,\n  localparam logic [31:0] LPARA_PID_DATA2 = 32'h7,")
# transaction counter per endpoint
rep("          reg_buf_i[gen_ep]  <= 1'b0;\n          reg_xs_i[gen_ep]   <= 19'd0;",
    "          reg_buf_i[gen_ep]  <= 1'b0;\n          reg_txn_i[gen_ep]  <= 2'd0;\n          reg_xs_i[gen_ep]   <= 19'd0;")
rep("          if (w_hit_i_commit[gen_ep]) begin\n",
    "          if (w_tk_sof & i_dev_act)\n            reg_txn_i[gen_ep] <= 2'd0;\n          if (w_hit_i_commit[gen_ep]) begin\n            reg_txn_i[gen_ep]  <= reg_txn_i[gen_ep] + 2'd1;\n")
open(p, 'w').write(s)

# spd: Test_SE0_NAK keeps the device active
q = open('../rtl/m_usb2_spd.sv').read()
q = q.replace("  output logic        o_dev_act,", "  output logic        o_dev_act,\n  output logic        o_test_nak,")
q = q.replace("                          (reg_fsm_dv_current_state != ENUM_ST_DV_CHJ) & ~w_test_on;",
              "                          (reg_fsm_dv_current_state != ENUM_ST_DV_CHJ) &\n                          (~w_test_on | (w_test_mode == 3'd3));")
q = q.replace("  assign o_role_host    = reg_role_host;", "  assign o_role_host    = reg_role_host;\n  assign o_test_nak     = w_test_on & (w_test_mode == 3'd3) & ~reg_role_host;")
open('../rtl/m_usb2_spd.sv', 'w').write(q)
# core generator wiring
c = open('core_body2.py').read()
c = c.replace("    e('    .o_dev_act       (w_dev_act),')", "    e('    .o_dev_act       (w_dev_act),')\n    e('    .o_test_nak      (w_test_nak),')")
c = c.replace("    e('        .i_speed_hs      (w_speed == 2\\'d0),')", "    e('        .i_speed_hs      (w_speed == 2\\'d0),')\n    e('        .i_test_nak      (w_test_nak),')")
open('core_body2.py', 'w').write(c)
b = open('core_body.py').read()
b = b.replace("('w_role_host', ''), ('w_dev_act', ''),", "('w_role_host', ''), ('w_test_nak', ''), ('w_dev_act', ''),")
open('core_body.py', 'w').write(b)
print('ok')
