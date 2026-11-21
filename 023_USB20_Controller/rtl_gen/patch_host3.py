import re
p = '../rtl/m_usb2_host.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


# declarations
rep("  logic                                     reg_to;\n",
    "  logic                                     reg_to;\n  logic                                     reg_bab;\n  logic [10:0]                              reg_mps;\n  logic                                     w_bab;\n"
    "  logic [PARA_USB2_NHC-1:0]                 w_blk;\n  logic [PARA_USB2_NHC-1:0]                 reg_due;\n  logic [PARA_USB2_NHC-1:0]                 reg_blkp;\n")
# blocked-by-time vector
rep("      w_elig[idx] = w_elig[idx] & (reg_uf_cnt > w_est[idx]);",
    "      w_blk[idx]  = w_elig[idx] & w_is_p[idx] & ~(reg_uf_cnt > w_est[idx]);\n      w_elig[idx] = w_elig[idx] & (reg_uf_cnt > w_est[idx]);")
rep("    w_est      = '0;\n", "    w_est      = '0;\n    w_blk      = '0;\n")
# babble detect and result
rep("  assign w_data_ok  = i_dat_end & i_dat_ok & reg_rx_acc;",
    "  assign w_data_ok  = i_dat_end & i_dat_ok & reg_rx_acc;\n  assign w_bab      = i_dat_end & (i_dat_len > {1'b0, reg_mps});")
rep("          5'b1????: w_res_nxt = (~i_dat_ok | ~reg_rx_acc) ? LPARA_RES_ERR[2:0] :",
    "          5'b1????: w_res_nxt = (~i_dat_ok | ~reg_rx_acc | w_bab) ? LPARA_RES_ERR[2:0] :")
# latch mps and clear babble flag at the pick
rep("            reg_to        <= 1'b0;\n", "            reg_to        <= 1'b0;\n            reg_mps       <= w_c_mps;\n            reg_bab       <= 1'b0;\n")
rep("      reg_to        <= 1'b0;\n      reg_is_cs     <= 1'b0;\n", "      reg_to        <= 1'b0;\n      reg_is_cs     <= 1'b0;\n      reg_bab       <= 1'b0;\n      reg_mps       <= 11'd0;\n")
rep("        reg_res <= w_res_nxt;\n        reg_len <= i_dat_len;\n", "        reg_res <= w_res_nxt;\n        reg_len <= i_dat_len;\n        reg_bab <= w_bab;\n")
# halt on babble
rep("((reg_res == LPARA_RES_STALL[2:0]) | ((reg_res == LPARA_RES_ERR[2:0]) & (reg_err[idx] == 2'd2)));",
    "((reg_res == LPARA_RES_STALL[2:0]) | ((reg_res == LPARA_RES_ERR[2:0]) & ((reg_err[idx] == 2'd2) | reg_bab)));")
# event bits
a = s.index("      assign o_hc_int_set[gen_ch] = {19'd0, 3'b000,")
b = s.index("      assign w_clr = {w_edge[31:30], 30'd0};")
new = """      assign o_hc_int_set[gen_ch] = {19'd0, (w_res_me & (reg_res == LPARA_RES_ERR[2:0]) & reg_iso),
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
      // Missed poll (due at the last tick and still unserved) and microframe overrun (a due periodic
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
"""
s = s[:a] + new + s[b:]
open(p, 'w').write(s)
print('ok')
