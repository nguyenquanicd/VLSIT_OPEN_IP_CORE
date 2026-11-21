import re
p = '../rtl/m_usb2_spd.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


s = s.replace("reg_ch_data", "w_ch_data").replace("reg_ch_valid", "w_ch_valid")
rep("  logic [15:0]                 w_ch_data;\n  logic [1:0]                  w_ch_valid;\n", "  logic [15:0]                 w_ch_data;\n  logic [1:0]                  w_ch_valid;\n")
# parameter for the width
rep("  parameter logic [31:0] PARA_USB2_ROLE = 2,\n",
    "  parameter logic [31:0] PARA_USB2_ROLE = 2,\n"
    "  // Parameter Description: UTMI+ data width; sets the bytes per chunk of the test packet source.\n"
    "  // Parameter values: 8 or 16; default is 8.\n"
    "  // Parameter unit: bit\n"
    "  parameter logic [31:0] PARA_USB2_UTMI_W = 8,\n")
rep("  localparam logic [31:0] LPARA_PID_DATA0 = 32'h3\n", "  localparam logic [31:0] LPARA_PID_DATA0 = 32'h3,\n  localparam logic [31:0] LPARA_W16       = 16\n")
rep("          reg_tp_idx <= reg_tp_idx + 6'd1;\n        end", "          reg_tp_idx <= reg_tp_idx + ((PARA_USB2_UTMI_W == LPARA_W16) ? 6'd2 : 6'd1);\n        end") if "reg_tp_idx <= reg_tp_idx + 6'd1;\n        end" in s else None
s = s.replace("        if (i_tp_pop)\n          reg_tp_idx <= reg_tp_idx + 6'd1;",
              "        if (i_tp_pop)\n          reg_tp_idx <= reg_tp_idx + ((PARA_USB2_UTMI_W == LPARA_W16) ? 6'd2 : 6'd1);")
rep("  assign o_tp_dat       = {w_tp_byte1, w_tp_byte0};",
    "  assign o_tp_dat       = (PARA_USB2_UTMI_W == LPARA_W16) ? {w_tp_byte1, w_tp_byte0} : {8'h00, w_tp_byte0};")
# remove unused
for pat in [r"  logic\s+w_filt_done;\n", r"  logic\s+reg_role_pend;\n", r"  logic\s+reg_tp_run;\n", r"  logic\s+w_dsm_rst;\n"]:
    s, n = re.subn(pat, "", s)
    assert n == 1, pat
s = s.replace("    w_dsm_rst          = 1'b0;\n", "")
s = s.replace("      reg_role_pend  <= 1'b0;\n", "").replace("      reg_tp_run <= 1'b0;\n", "")
for port in ["i_avalid", "i_bvalid", "i_tx_ready"]:
    s, n = re.subn(r"  input  wire\s+" + port + r",\n", "", s)
    assert n == 1, port
# SE0 filter timer clear
rep("""      if (!w_ls_se0 | (reg_fsm_dv_current_state != ENUM_DV_FS && reg_fsm_dv_current_state != ENUM_DV_RST))
        reg_dtmr <= (reg_fsm_dv_current_state == ENUM_DV_FS) ? LPARA_T_RSTDET[LPARA_TMR_W-1:0] : reg_dtmr;""",
    """      if ((reg_fsm_dv_current_state == ENUM_DV_FS) & ~w_ls_se0)
        reg_dtmr <= LPARA_T_RSTDET[LPARA_TMR_W-1:0];""")
# disconnect by hostdisc
rep("""        ENUM_HP_EN: begin
          if (w_edge_psusp)
            w_fsm_hp_nxt_state = ENUM_HP_SUSP;""", """        ENUM_HP_EN: begin
          if (i_hostdisc & (reg_speed == 2'd0))
            w_fsm_hp_nxt_state = ENUM_HP_OFF;
          else if (w_edge_psusp)
            w_fsm_hp_nxt_state = ENUM_HP_SUSP;""")
open(p, 'w').write(s)
print('ok')
