import re
p = '../rtl/m_usb2_host.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


# result codes into the parameter port list
a = s.index("  // Result codes of a transaction.")
b = s.index("  // Internal signal declarations")
s = s[:a] + s[b:]
rep("  localparam logic [31:0] LPARA_FS_MUL    = 40\n",
    "  localparam logic [31:0] LPARA_FS_MUL    = 40,\n"
    "  localparam logic [31:0] LPARA_RES_NONE  = 0,\n"
    "  localparam logic [31:0] LPARA_RES_ACK   = 1,\n"
    "  localparam logic [31:0] LPARA_RES_NAK   = 2,\n"
    "  localparam logic [31:0] LPARA_RES_NYET  = 3,\n"
    "  localparam logic [31:0] LPARA_RES_STALL = 4,\n"
    "  localparam logic [31:0] LPARA_RES_ERR   = 5,\n"
    "  localparam logic [31:0] LPARA_RES_TOG   = 6\n")
s = re.sub(r"(w_res_nxt = )(LPARA_RES_[A-Z]+)(;)", r"\1\2[2:0]\3", s)
s = re.sub(r"(w_res_nxt = \(~i_dat_ok \| ~reg_rx_acc\) \? )(LPARA_RES_ERR)( :)", r"\1\2[2:0]\3", s)
s = s.replace("(w_pid_ok ? LPARA_RES_ACK : LPARA_RES_TOG);", "(w_pid_ok ? LPARA_RES_ACK[2:0] : LPARA_RES_TOG[2:0]);")
s = s.replace("w_res_nxt = LPARA_RES_NONE;\n    case", "w_res_nxt = LPARA_RES_NONE[2:0];\n    case")
s = s.replace("reg_res       <= LPARA_RES_NONE;", "reg_res       <= LPARA_RES_NONE[2:0];")
s = s.replace("          reg_res <= LPARA_RES_ACK;\n", "          reg_res <= LPARA_RES_ACK[2:0];\n")
# queue counts of the host queues
s = re.sub(r"  input  wire\s+\[34:0\]\s+i_q_cnt,", "  input  wire  [33:0]                       i_q_cnt,", s)
# eligibility: time left and queue data
rep("      if (w_is_out[idx]) begin\n        w_elig[idx] = w_elig[idx] & (w_is_p[idx] ? w_head_p[idx] : w_head_np[idx]);\n      end",
    "      w_len_c[idx] = (reg_xs[idx] > {8'd0, i_hc_ctrl[idx][10:0]}) ? {1'b0, i_hc_ctrl[idx][10:0]} : reg_xs[idx][11:0];\n"
    "      w_rows_c[idx] = ({5'd0, w_len_c[idx]} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;\n"
    "      w_est[idx] = ({8'd0, w_len_c[idx]} + PARA_USB2_HOST_OVH[19:0]);\n"
    "      if (!w_hs_mode)\n"
    "        w_est[idx] = (w_est[idx] << 5) + (w_est[idx] << 3);\n"
    "      w_elig[idx] = w_elig[idx] & (reg_uf_cnt > w_est[idx]);\n"
    "      if (w_is_out[idx]) begin\n"
    "        w_elig[idx] = w_elig[idx] & (w_is_p[idx] ? w_head_p[idx] : w_head_np[idx]) &\n"
    "                      ((w_is_p[idx] ? i_q_cnt[33:17] : i_q_cnt[16:0]) >= w_rows_c[idx]);\n"
    "      end")
rep("  logic [PARA_USB2_NHC-1:0]                 w_is_out;\n",
    "  logic [PARA_USB2_NHC-1:0]                 w_is_out;\n"
    "  logic [PARA_USB2_NHC-1:0][11:0]           w_len_c;\n"
    "  logic [PARA_USB2_NHC-1:0][16:0]           w_rows_c;\n"
    "  logic [PARA_USB2_NHC-1:0][LPARA_UF_W-1:0] w_est;\n")
rep("    w_elig_p   = '0;\n", "    w_elig_p   = '0;\n    w_len_c    = '0;\n    w_rows_c   = '0;\n    w_est      = '0;\n")
s = s.replace("  logic [LPARA_UF_W-1:0]                    reg_uf_len;\n", "")
s = s.replace("      reg_uf_len   <= '0;\n", "")
s = s.replace("        reg_uf_len   <= w_uf_reload;\n", "")
s = s.replace("{1'b0, w_cc[10:0]})));", "{2'b00, w_cc[10:0]})));")
s = s.replace("(reg_dir_in & ({1'b0, reg_len} < {1'b0, w_cc[10:0]})))", "(reg_dir_in & ({1'b0, reg_len} < {2'b00, w_cc[10:0]}) & 1'b1))")
open(p, 'w').write(s)
print('ok')
