# Automatic mutation run

Operator flips at 80 places of the control block and the buffer sampled by seed 20261124 (60 random operations per run, synthesis branch, one clock: CSR_ASYNC=0).

Caught 77, survived 3 (A05, A09, A62), compile errors 0 in the full run. A09 was caught in a rerun after the reset release of the testbench was corrected (see below), so the result is 78 caught, 2 survived (A05, A62: equivalent). A survivor is either an equivalent mutant (no change of behavior) or a hole of the tests; each survivor is analysed in TEST_REVIEW.md.

| ID | Result | File:line | Code | Flip | Failed checks | Assertion failures |
|---|---|---|---|---|---:|---:|
| A00 | CAUGHT | m_vlsit_dsig_buf.sv:137 | `assign w_win_wr_ev = i_reg_wr_en & (i_reg_wr_addr == PARA_WIN_WR_OFF[15:0]);` | ` / ` | 880 | 0 |
| A01 | CAUGHT | m_vlsit_dsig_buf.sv:137 | `assign w_win_wr_ev = i_reg_wr_en & (i_reg_wr_addr == PARA_WIN_WR_OFF[15:0]);` | `!=` | 807 | 0 |
| A02 | CAUGHT | m_vlsit_dsig_buf.sv:148 | `assign w_win_wr_ok = w_win_wr_ev & w_win_inr & ~i_busy;` | ` / ` | 947 | 5 |
| A03 | CAUGHT | m_vlsit_dsig_buf.sv:149 | `assign w_win_rd_ok = w_win_rd_ev & w_win_inr & ~i_busy;` | `remove` | 70 | 0 |
| A04 | CAUGHT | m_vlsit_dsig_buf.sv:170 | `assign w_sel_axi_wr = ~i_busy & i_axi_wr_en;` | ` / ` | 82 | 0 |
| A05 | SURVIVED | m_vlsit_dsig_buf.sv:176 | `w_wr_en   = 1'b0;` | `1'b1` | 0 | 0 |
| A06 | CAUGHT | m_vlsit_dsig_buf.sv:188 | `w_wr_en   = 1'b1;` | `1'b0` | 662 | 5 |
| A07 | CAUGHT | m_vlsit_dsig_buf.sv:233 | `.i_wr_en   (w_wr_en & w_wr_strb[gen_idx]),` | ` / ` | 332 | 0 |
| A08 | CAUGHT | m_vlsit_dsig_buf.sv:256 | `reg_axi_rd_rej  <= 1'b0;` | `1'b1` | 0 | 5 |
| A09 | SURVIVED in the full run, CAUGHT in the rerun | m_vlsit_dsig_buf.sv:263 | `reg_err_busy    <= 1'b0;` | `1'b1` | 0 | 0 |
| A10 | CAUGHT | m_vlsit_dsig_buf.sv:269 | `reg_axi_rd_rej <= i_busy & i_axi_rd_en;` | ` / ` | 486 | 0 |
| A11 | CAUGHT | m_vlsit_dsig_buf.sv:270 | `reg_axi_wr_rej <= i_busy & i_axi_wr_en;` | ` / ` | 470 | 5 |
| A12 | CAUGHT | m_vlsit_dsig_buf.sv:271 | `reg_win_sel    <= ~(w_sel_eng_rd / w_sel_axi_rd);` | `remove` | 95 | 0 |
| A13 | CAUGHT | m_vlsit_dsig_buf.sv:271 | `reg_win_sel    <= ~(w_sel_eng_rd / w_sel_axi_rd);` | ` & ` | 4 | 0 |
| A14 | CAUGHT | m_vlsit_dsig_buf.sv:274 | `reg_err_ovf    <= (w_win_wr_ev / w_win_rd_ev) & ~w_win_inr & ~i_busy;` | ` & ` | 5 | 0 |
| A15 | CAUGHT | m_vlsit_dsig_buf.sv:274 | `reg_err_ovf    <= (w_win_wr_ev / w_win_rd_ev) & ~w_win_inr & ~i_busy;` | `remove` | 174 | 0 |
| A16 | CAUGHT | m_vlsit_dsig_buf.sv:274 | `reg_err_ovf    <= (w_win_wr_ev / w_win_rd_ev) & ~w_win_inr & ~i_busy;` | `remove` | 5 | 0 |
| A17 | CAUGHT | m_vlsit_dsig_buf.sv:285 | `assign o_axi_rd_valid = reg_axi_rd_ok / reg_axi_rd_rej;` | ` & ` | 1526 | 5 |
| A18 | CAUGHT | m_vlsit_dsig_ctl.sv:369 | `assign w_start_ok = (reg_fsm_ctl_current_state == ENUM_ST_IDLE) & i_cmd_start;` | `!=` | 2722 | 0 |
| A19 | CAUGHT | m_vlsit_dsig_ctl.sv:382 | `assign w_is_ecdsa = (w_alg32 >= LPARA_ALG_P256) & (w_alg32 <= LPARA_ALG_K256);` | ` < ` | 115 | 0 |
| A20 | CAUGHT | m_vlsit_dsig_ctl.sv:382 | `assign w_is_ecdsa = (w_alg32 >= LPARA_ALG_P256) & (w_alg32 <= LPARA_ALG_K256);` | ` / ` | 37 | 0 |
| A21 | CAUGHT | m_vlsit_dsig_ctl.sv:385 | `assign w_is_sign  = (w_op32 == LPARA_OP_SIGN);` | `!=` | 507 | 15 |
| A22 | CAUGHT | m_vlsit_dsig_ctl.sv:418 | `w_set_bad = ({28'd0, reg_run_slh} >= LPARA_SLH_N) / ~PARA_SLHDSA_SETS[w_slh_idx5];` | ` & ` | 6 | 0 |
| A23 | CAUGHT | m_vlsit_dsig_ctl.sv:421 | `w_set_bad = ({27'd0, reg_run_lmstype} >= LPARA_LMS_N) / ~PARA_LMS_SETS[reg_run_lmstype] /` | ` < ` | 42 | 0 |
| A24 | CAUGHT | m_vlsit_dsig_ctl.sv:421 | `w_set_bad = ({27'd0, reg_run_lmstype} >= LPARA_LMS_N) / ~PARA_LMS_SETS[reg_run_lmstype] /` | `remove` | 53 | 0 |
| A25 | CAUGHT | m_vlsit_dsig_ctl.sv:447 | `LPARA_OP_KGEN: w_f_opuns = w_f_opuns / ~PARA_CAP_KGEN[w_alg_idx5];` | `remove` | 215 | 0 |
| A26 | CAUGHT | m_vlsit_dsig_ctl.sv:448 | `LPARA_OP_SIGN: w_f_opuns = w_f_opuns / ~PARA_CAP_SIGN[w_alg_idx5];` | ` & ` | 43 | 0 |
| A27 | CAUGHT | m_vlsit_dsig_ctl.sv:449 | `LPARA_OP_VRFY: w_f_opuns = w_f_opuns / ~PARA_CAP_VRFY[w_alg_idx5];` | ` & ` | 72 | 0 |
| A28 | CAUGHT | m_vlsit_dsig_ctl.sv:453 | `LPARA_FORM_PURE:    w_f_opuns = w_f_opuns / ~PARA_EN_PURE[0];` | ` & ` | 2968 | 0 |
| A29 | CAUGHT | m_vlsit_dsig_ctl.sv:454 | `LPARA_FORM_PREHASH: w_f_opuns = w_f_opuns / ~PARA_EN_PREHASH[0];` | `remove` | 252 | 0 |
| A30 | CAUGHT | m_vlsit_dsig_ctl.sv:457 | `if (w_is_ecdsa & w_is_sign & (PARA_ECDSA_NONCE == LPARA_NONCE_CSR) & reg_run_nonce[1])` | ` / ` | 294 | 0 |
| A31 | CAUGHT | m_vlsit_dsig_ctl.sv:459 | `if ((w_is_ecdsa / ({30'd0, reg_run_form} == LPARA_FORM_PREHASH)) & (reg_run_hash[2:1] == 2` | ` / ` | 829 | 0 |
| A32 | CAUGHT | m_vlsit_dsig_ctl.sv:461 | `if (PARA_EN_HYBRID[0] & w_is_vrfy & ((w_alg32 == LPARA_ALG_ED25519) / w_is_mldsa) &` | ` / ` | 1101 | 0 |
| A33 | CAUGHT | m_vlsit_dsig_ctl.sv:470 | `if (w_is_ecdsa & (w_dig_len < w_min_len))` | ` / ` | 589 | 0 |
| A34 | CAUGHT | m_vlsit_dsig_ctl.sv:470 | `if (w_is_ecdsa & (w_dig_len < w_min_len))` | ` >= ` | 621 | 0 |
| A35 | CAUGHT | m_vlsit_dsig_ctl.sv:471 | `w_f_badlen = 1'b1;` | `1'b0` | 43 | 0 |
| A36 | CAUGHT | m_vlsit_dsig_ctl.sv:472 | `if ((w_alg32 == LPARA_ALG_LMS) & ((reg_run_hsslvl == 4'd0) / ({28'd0, reg_run_hsslvl} > LP` | `!=` | 71 | 0 |
| A37 | CAUGHT | m_vlsit_dsig_ctl.sv:472 | `if ((w_alg32 == LPARA_ALG_LMS) & ((reg_run_hsslvl == 4'd0) / ({28'd0, reg_run_hsslvl} > LP` | ` / ` | 90 | 0 |
| A38 | CAUGHT | m_vlsit_dsig_ctl.sv:472 | `if ((w_alg32 == LPARA_ALG_LMS) & ((reg_run_hsslvl == 4'd0) / ({28'd0, reg_run_hsslvl} > LP` | `!=` | 45 | 0 |
| A39 | CAUGHT | m_vlsit_dsig_ctl.sv:474 | `if ({30'd0, reg_run_form} == LPARA_FORM_PREHASH) begin` | `!=` | 784 | 0 |
| A40 | CAUGHT | m_vlsit_dsig_ctl.sv:475 | `if ((w_is_ecdsa / w_is_mldsa) & (reg_run_len_msg != w_dig_len))` | ` / ` | 198 | 0 |
| A41 | CAUGHT | m_vlsit_dsig_ctl.sv:477 | `if (((w_alg32 == LPARA_ALG_ED25519PH) / (w_alg32 == LPARA_ALG_ED448PH)) &` | `!=` | 140 | 0 |
| A42 | CAUGHT | m_vlsit_dsig_ctl.sv:479 | `w_f_badlen = 1'b1;` | `1'b0` | 25 | 0 |
| A43 | CAUGHT | m_vlsit_dsig_ctl.sv:484 | `assign w_msg_end  = {2'b00, reg_run_len_msg} + {17'd0, reg_run_off_msg};` | ` - ` | 225 | 0 |
| A44 | CAUGHT | m_vlsit_dsig_ctl.sv:496 | `default: w_chk_ok = 1'b1;` | `1'b0` | 1688 | 5 |
| A45 | CAUGHT | m_vlsit_dsig_ctl.sv:503 | `assign w_needs_rng = (w_is_ecdsa & w_is_sign & ((PARA_ECDSA_NONCE == 32'd0) /` | ` / ` | 155 | 5 |
| A46 | CAUGHT | m_vlsit_dsig_ctl.sv:504 | `((PARA_ECDSA_NONCE == LPARA_NONCE_CSR) & ~reg_run_nonce[0]))) /` | `remove` | 27 | 0 |
| A47 | CAUGHT | m_vlsit_dsig_ctl.sv:597 | `w_state_bad         = 1'b1;` | `1'b0` | 9 | 0 |
| A48 | CAUGHT | m_vlsit_dsig_ctl.sv:605 | `o_key_start = 1'b0;` | `1'b1` | 4699 | 5 |
| A49 | CAUGHT | m_vlsit_dsig_ctl.sv:612 | `ENUM_ST_IDLE: o_busy = 1'b0;` | `1'b1` | 2875 | 10 |
| A50 | CAUGHT | m_vlsit_dsig_ctl.sv:613 | `ENUM_ST_CLEAR: o_zero = 1'b1;` | `1'b0` | 5045 | 10 |
| A51 | CAUGHT | m_vlsit_dsig_ctl.sv:616 | `if ((w_fsm_ctl_nxt_state == ENUM_ST_KEY) & (reg_fsm_ctl_current_state != ENUM_ST_KEY))` | `==` | 4630 | 0 |
| A52 | CAUGHT | m_vlsit_dsig_ctl.sv:618 | `if ((w_fsm_ctl_nxt_state == ENUM_ST_RNG) & (reg_fsm_ctl_current_state != ENUM_ST_RNG))` | `!=` | 277 | 5 |
| A53 | CAUGHT | m_vlsit_dsig_ctl.sv:620 | `if ((w_fsm_ctl_nxt_state == ENUM_ST_VAS) & (reg_fsm_ctl_current_state != ENUM_ST_VAS))` | `!=` | 296 | 5 |
| A54 | CAUGHT | m_vlsit_dsig_ctl.sv:621 | `o_vas_start = 1'b1;` | `1'b0` | 4477 | 0 |
| A55 | CAUGHT | m_vlsit_dsig_ctl.sv:622 | `if ((w_fsm_ctl_nxt_state == ENUM_ST_RUN) & (reg_fsm_ctl_current_state != ENUM_ST_RUN)) beg` | ` / ` | 451 | 30 |
| A56 | CAUGHT | m_vlsit_dsig_ctl.sv:641 | `assign w_lock_viol = reg_locked & (w_alg_cap != reg_alg_prev) & (w_alg_cap != reg_alg_act)` | ` / ` | 6 | 0 |
| A57 | CAUGHT | m_vlsit_dsig_ctl.sv:641 | `assign w_lock_viol = reg_locked & (w_alg_cap != reg_alg_prev) & (w_alg_cap != reg_alg_act)` | `==` | 5 | 0 |
| A58 | CAUGHT | m_vlsit_dsig_ctl.sv:641 | `assign w_lock_viol = reg_locked & (w_alg_cap != reg_alg_prev) & (w_alg_cap != reg_alg_act)` | ` / ` | 6 | 0 |
| A59 | CAUGHT | m_vlsit_dsig_ctl.sv:655 | `if (i_lock_req & PARA_EN_LOCK[0])` | ` / ` | 2195 | 0 |
| A60 | CAUGHT | m_vlsit_dsig_ctl.sv:708 | `assign w_ed_nxt    = (w_alg32 == LPARA_ALG_ED25519) ? reg_raw_ok : reg_edok;` | `!=` | 118 | 0 |
| A61 | CAUGHT | m_vlsit_dsig_ctl.sv:715 | `if (PARA_EN_HYBRID[0] & ((w_alg32 == LPARA_ALG_ED25519) / w_is_mldsa)) begin` | ` / ` | 40 | 0 |
| A62 | SURVIVED | m_vlsit_dsig_ctl.sv:720 | `default:        w_sigok_nxt = 1'b0;` | `1'b1` | 0 | 0 |
| A63 | CAUGHT | m_vlsit_dsig_ctl.sv:730 | `reg_resvld    <= 1'b0;` | `1'b1` | 3 | 0 |
| A64 | CAUGHT | m_vlsit_dsig_ctl.sv:732 | `reg_edok      <= 1'b0;` | `1'b1` | 3 | 0 |
| A65 | CAUGHT | m_vlsit_dsig_ctl.sv:739 | `if (w_fsm_ctl_nxt_state == ENUM_ST_ERR)` | `!=` | 183 | 5 |
| A66 | CAUGHT | m_vlsit_dsig_ctl.sv:743 | `casez ({(reg_fsm_ctl_current_state == ENUM_ST_IDLE) & i_cmd_clr,` | `!=` | 153 | 0 |
| A67 | CAUGHT | m_vlsit_dsig_ctl.sv:747 | `reg_resvld <= 1'b0;` | `1'b1` | 75 | 0 |
| A68 | CAUGHT | m_vlsit_dsig_ctl.sv:776 | `(((reg_fsm_ctl_current_state != ENUM_ST_IDLE) & i_cmd_start) ? LPARA_ERRF_BUSYCMD[11:0] : ` | `==` | 520 | 0 |
| A69 | CAUGHT | m_vlsit_dsig_ctl.sv:776 | `(((reg_fsm_ctl_current_state != ENUM_ST_IDLE) & i_cmd_start) ? LPARA_ERRF_BUSYCMD[11:0] : ` | ` / ` | 525 | 0 |
| A70 | CAUGHT | m_vlsit_dsig_ctl.sv:783 | `assign o_alarm_set = (((reg_fsm_ctl_current_state == ENUM_ST_ERR) & (reg_err_flags != 12'd` | ` / ` | 3 | 0 |
| A71 | CAUGHT | m_vlsit_dsig_ctl.sv:786 | `((reg_err_flags & LPARA_ERRF_ENTTMO[11:0]) != 12'd0)) ? LPARA_ALM_RNGFAIL[2:0] : 3'd0) /` | ` / ` | 5 | 0 |
| A72 | CAUGHT | m_vlsit_dsig_ctl.sv:793 | `assign w_err_ev  = ((w_err_pulse & ~LPARA_ERRF_LOCKV[11:0]) != 12'd0);` | ` / ` | 227 | 0 |
| A73 | CAUGHT | m_vlsit_dsig_ctl.sv:795 | `assign w_inj_rise = i_irq_inj & ~reg_inj_prev;` | ` / ` | 228 | 0 |
| A74 | CAUGHT | m_vlsit_dsig_ctl.sv:799 | `assign o_flags_clr   = (reg_fsm_ctl_current_state == ENUM_ST_IDLE) & i_cmd_clr;` | ` / ` | 486 | 0 |
| A75 | CAUGHT | m_vlsit_dsig_ctl.sv:816 | `reg_log_locked <= 1'b1;` | `1'b0` | 4 | 0 |
| A76 | CAUGHT | m_vlsit_dsig_ctl.sv:818 | `if ((reg_fsm_ctl_current_state == ENUM_ST_CHECK) & w_chk_ok & (reg_cnt_ops != 32'hFFFFFFFF` | ` / ` | 297 | 0 |
| A77 | CAUGHT | m_vlsit_dsig_ctl.sv:818 | `if ((reg_fsm_ctl_current_state == ENUM_ST_CHECK) & w_chk_ok & (reg_cnt_ops != 32'hFFFFFFFF` | ` / ` | 299 | 0 |
| A78 | CAUGHT | m_vlsit_dsig_ctl.sv:821 | `((reg_fsm_ctl_current_state == ENUM_ST_RESULT) & w_is_vrfy & ~reg_raw_ok)) &` | ` / ` | 223 | 0 |
| A79 | CAUGHT | m_vlsit_dsig_ctl.sv:823 | `reg_cnt_fail <= reg_cnt_fail + 32'd1;` | ` - ` | 132 | 0 |

A09: reset value 1 of the buffer error flop. The testbench of the one-clock build released the APB reset (which is the register reset of the CSR in that build) many cycles after the core reset, so the wrong reset value had settled before the CSR could see it. The reset release is now simultaneous in the one-clock build, assertion 35 also checks the buffer error outputs in reset, and the rerun of A09 and A13 in this build catches both (A13 needs the one-clock timing).
