import re
p = '../rtl/m_usb2_host.sv'
s = open(p).read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b)


s, n = re.subn(r"  input  wire\s+i_rx_err,\n", "", s)
assert n == 1
rep("  logic [PARA_USB2_NHC-1:0]                 reg_miss;\n", "")
rep("  logic                                     reg_ping_tok;\n",
    "  logic                                     reg_ping_tok;\n  logic                                     reg_to;\n  logic                                     reg_is_cs;\n")
rep("  logic                                     w_end_cmd;\n", "  logic [PARA_USB2_NHC-1:0]                 w_start_ok;\n")
rep("  logic [PARA_USB2_NHC-1:0]                 w_done_hit;\n", "")
rep("    w_done_hit = '0;\n", "    w_start_ok = '0;\n")
rep("  assign w_uf_len_nxt = i_sof_cfg[15:0] / PARA_USB2_TSCALE[LPARA_UF_W-1:0];",
    "  assign w_uf_len_nxt = {4'd0, i_sof_cfg[15:0]} >> $clog2(PARA_USB2_TSCALE);")
rep("  assign w_c_rows  = ({5'd0, w_c_len} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;",
    "  assign w_c_rows  = ({6'd0, w_c_mps} + (17'd1 << w_bpr_sh) - 17'd1) >> w_bpr_sh;")
rep("""            reg_spl_fld   <= {2'b00, w_c_split[16], 1'b0, w_c_split[13:7], w_c_split[17] & ~w_c_split[16],
                              w_c_split[6:0]};""",
    """            reg_spl_fld   <= {w_c_type, 1'b0, (w_c_ctrl[19:18] == 2'd2), w_c_split[13:7],
                              reg_csplit[w_pick_ch], w_c_split[6:0]};
            reg_is_cs     <= reg_csplit[w_pick_ch];
            reg_to        <= 1'b0;""")
rep("      reg_ping_tok  <= 1'b0;\n      reg_tmo       <= '0;",
    "      reg_ping_tok  <= 1'b0;\n      reg_to        <= 1'b0;\n      reg_is_cs     <= 1'b0;\n      reg_tmo       <= '0;")
rep("          w_fsm_host_nxt_state = (reg_dir_in | reg_ping_tok) ? ENUM_ST_WAIT_IN : ENUM_ST_DATA;",
    "          w_fsm_host_nxt_state = reg_dir_in ? ENUM_ST_WAIT_IN :\n                                 ((reg_ping_tok | reg_is_cs) ? ENUM_ST_WAIT_HS : ENUM_ST_DATA);")
rep("          if (i_tx_done & ~reg_dir_in & ~reg_ping_tok) begin\n            reg_tx_req  <= 1'b1;\n            reg_tx_kind <= LPARA_KIND_DATA[2:0];",
    "          if (i_tx_done & ~reg_dir_in & ~reg_ping_tok & ~reg_is_cs) begin\n            reg_tx_req  <= 1'b1;\n            reg_tx_kind <= LPARA_KIND_DATA[2:0];")
rep("          5'b0001?: w_res_nxt = reg_ping_tok ? LPARA_RES_ACK : LPARA_RES_ERR;",
    "          5'b0001?: w_res_nxt = LPARA_RES_ERR;")
rep("          if (w_fsm_host_nxt_state == ENUM_ST_DONE)\n            reg_res <= w_res_nxt;",
    "          if (w_fsm_host_nxt_state == ENUM_ST_DONE) begin\n            reg_res <= w_res_nxt;\n            reg_to  <= w_wait_end & ~i_hs_vld & ~i_dat_end;\n          end")
rep("      if ((reg_fsm_host_current_state == ENUM_ST_WAIT_IN) & i_dat_end)\n        reg_res <= w_res_nxt;",
    "      if ((reg_fsm_host_current_state == ENUM_ST_WAIT_IN) & i_dat_end) begin\n        reg_res <= w_res_nxt;\n        reg_len <= i_dat_len;\n      end")

a = s.index("        ENUM_ST_DONE: begin\n          reg_done_p <= 1'b1;")
b = s.index("        default: begin\n          reg_res <= reg_res;\n        end\n      endcase\n      if (reg_fsm_host_current_state == ENUM_ST_DATA) begin")
new = """        ENUM_ST_DONE: begin
          reg_done_p <= 1'b1;
          if (~reg_dir_in & ~reg_ping_tok & ~reg_is_cs) begin
            reg_txr_commit <= (reg_res == LPARA_RES_ACK) | (reg_res == LPARA_RES_NYET);
            reg_txr_cancel <= (reg_res != LPARA_RES_ACK) & (reg_res != LPARA_RES_NYET);
          end
        end
"""
s = s[:a] + new + s[b:]

a = s.index("  // Strobes of the finished transaction toward the per-channel state.")
b = s.index("  // Per-channel state: armed, remaining counts")
new = """  // Strobes of the finished transaction toward the per-channel state: the start phase of a split
  // transaction only moves the channel to its complete phase; ACK and NYET (without split) update
  // the transfer; STALL and the third error halt the channel.
  always_comb begin : p_com_hit
    w_start_ok = '0;
    w_upd_hit  = '0;
    w_halt_hit = '0;
    for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin
      w_start_ok[idx] = reg_done_p & (reg_ch == idx[3:0]) & reg_use_split & ~reg_is_cs &
                        (reg_res == LPARA_RES_ACK);
      w_upd_hit[idx]  = reg_done_p & (reg_ch == idx[3:0]) & ~w_start_ok[idx] &
                        ((reg_res == LPARA_RES_ACK) | ((reg_res == LPARA_RES_NYET) & ~reg_use_split));
      w_halt_hit[idx] = reg_done_p & (reg_ch == idx[3:0]) &
                        ((reg_res == LPARA_RES_STALL) | ((reg_res == LPARA_RES_ERR) & (reg_err[idx] == 2'd2)));
    end
  end

"""
s = s[:a] + new + s[b:]

rep("""      assign w_last    = w_upd_hit[gen_ch] & ~reg_ping_tok &
                         ((reg_pc[gen_ch] == 10'd1) | (w_xs_nxt == 19'd0) |
                          (i_hc_cfg[gen_ch][2] & ~reg_dir_in & 1'b0));""",
    """      assign w_last    = w_upd_hit[gen_ch] & ~reg_ping_tok &
                         ((reg_pc[gen_ch] == 10'd1) | (w_xs_nxt == 19'd0) |
                          (reg_dir_in & ({1'b0, reg_len} < {1'b0, w_cc[10:0]})));""")
rep("      logic        w_set_done;\n      logic [11:0] w_set_bits;\n", "      logic        w_set_done;\n      logic        w_res_me;\n")
rep("          reg_csplit[gen_ch] <= 1'b0;\n          reg_buf[gen_ch]    <= 1'b0;\n          reg_miss[gen_ch]   <= 1'b0;",
    "          reg_csplit[gen_ch] <= 1'b0;\n          reg_buf[gen_ch]    <= 1'b0;")
rep("            reg_wait[gen_ch] <= 1'b0;\n            reg_pcnt[gen_ch] <= 16'd0;\n          end",
    "            reg_wait[gen_ch] <= 1'b0;\n            reg_pcnt[gen_ch] <= 16'd0;\n            reg_csplit[gen_ch] <= 1'b0;\n          end")
rep("          if (w_upd_hit[gen_ch]) begin\n            reg_err[gen_ch] <= 2'd0;",
    "          if (w_start_ok[gen_ch]) begin\n            reg_csplit[gen_ch] <= 1'b1;\n            reg_wait[gen_ch]   <= 1'b1;\n            reg_err[gen_ch]    <= 2'd0;\n          end\n          if (w_upd_hit[gen_ch]) begin\n            reg_csplit[gen_ch] <= 1'b0;\n            reg_err[gen_ch] <= 2'd0;")
rep("          if (reg_done_p & (reg_ch == gen_ch[3:0])) begin\n            if (reg_res == LPARA_RES_NAK) begin",
    "          if (reg_done_p & (reg_ch == gen_ch[3:0])) begin\n            if (reg_res == LPARA_RES_NYET & reg_use_split)\n              reg_wait[gen_ch] <= 1'b1;\n            if (reg_res == LPARA_RES_NAK) begin")
rep("          if (w_set_done)\n            reg_act[gen_ch] <= reg_act[gen_ch];\n", "")

a = s.index("      // Event sets of the channel: done, halt")
b = s.index("      assign w_clr = {w_edge[31:30], 30'd0};")
new = """      // Event sets of the channel: done, halt, timeout, NAK, NYET, STALL, ACK, error, toggle error.
      assign w_set_done = w_last;
      assign w_res_me   = reg_done_p & (reg_ch == gen_ch[3:0]);
      assign o_hc_int_set[gen_ch] = {19'd0, 3'b000, (w_res_me & (reg_res == LPARA_RES_TOG)), 1'b0,
                                     (w_res_me & (reg_res == LPARA_RES_ERR) & ~reg_to),
                                     (w_res_me & (reg_res == LPARA_RES_ACK)),
                                     (w_res_me & (reg_res == LPARA_RES_STALL)),
                                     (w_res_me & (reg_res == LPARA_RES_NYET)),
                                     (w_res_me & (reg_res == LPARA_RES_NAK)),
                                     (w_res_me & (reg_res == LPARA_RES_ERR) & reg_to),
                                     w_halt_hit[gen_ch], w_set_done};
"""
s = s[:a] + new + s[b:]
rep("            if (reg_res == LPARA_RES_NAK) begin\n              reg_wait[gen_ch] <= 1'b1;",
    "            if (reg_res == LPARA_RES_NAK) begin\n              reg_wait[gen_ch] <= 1'b1;\n              if (w_is_p[gen_ch] & i_hc_cfg[gen_ch][3])\n                reg_pcnt[gen_ch] <= w_ival;")
open(p, 'w').write(s)
print('ok')
