// tb_tests.svh - operation helper, directed tests (focused group, then integrated flows), the
// constrained-random test and the main sequence. Included inside module tb_dsig_p1.
// Every test names the TEST-ID and the requirement IDs of section 15 of the specification.

  // ----------------------------------------------------------------------------------------
  // Operation descriptor and state of the reference model
  // ----------------------------------------------------------------------------------------
  reg [3:0]  o_alg;
  reg [1:0]  o_op, o_form, o_nonce, o_hybpol;
  reg        o_hedged;
  reg [2:0]  o_hash;
  reg [3:0]  o_slh, o_lmots, o_hsslvl;
  reg [4:0]  o_lmst;
  reg [5:0]  o_xm;
  reg [31:0] o_len;
  reg [7:0]  o_ctx;
  reg [16:0] o_offm, o_offs, o_offp, o_offr;
  reg        t_ctrl_en;           // IP enable as programmed
  reg [14:0] t_eff_en;            // effective algorithm enables as programmed (no lock)
  reg        o_clr_before;        // issue dsig_cmd.clr before the operation

  // Outcome of the last operation
  reg [31:0] r_err, r_alarm, r_irq_raw, r_sts, r_cnt_ops, r_cnt_fail;
  integer    exp_ee;              // expected error flag number of the last operation, -1 none
  reg [31:0] c0_ops, c0_fail;

  task set_default_op;
    begin
      o_alg = ALG_ED25519; o_op = OP_VRFY; o_form = FORM_PURE; o_nonce = 2'd0; o_hybpol = 2'd1;
      o_hedged = 1'b0; o_hash = 3'd0; o_slh = 4'd0; o_lmots = 4'd0; o_hsslvl = 4'd1;
      o_lmst = 5'd0; o_xm = 6'd0; o_len = 32'd32; o_ctx = 8'd0;
      o_offm = 17'd0; o_offs = 17'd64; o_offp = 17'd128; o_offr = 17'd256;
      o_clr_before = 1'b1;
    end
  endtask

  task program_op;
    begin
      prog_op(o_alg, o_op, o_form, o_hedged, o_nonce, o_hash, o_hybpol);
      prog_set(o_slh, o_lmst, o_lmots, o_hsslvl, o_xm);
      prog_len(o_len, o_ctx, o_offm, o_offs, o_offp, o_offr);
    end
  endtask

  task read_outcome;
    begin
      apb_r(A_ERR, r_err);
      apb_r(A_ALARM, r_alarm);
      apb_r(A_IRQ_RAW, r_irq_raw);
      apb_r(A_STS, r_sts);
      apb_r(A_CNT_OPS, r_cnt_ops);
      apb_r(A_CNT_FAIL, r_cnt_fail);
    end
  endtask

  // Enable the IP and a set of algorithms (no lock)
  task enable_ip;
    input [14:0] m;
    begin
      t_ctrl_en = 1'b1;
      t_eff_en  = m;
      prog_alg_en(m);
      apb_w(A_CTRL, 32'h1);
      cyc(8);
    end
  endtask

  task clr_all;
    begin
      cmd_clr;
      ref_edok = 1'b0;
      ref_mlok = 1'b0;
    end
  endtask

  // Run one operation from the descriptor and check everything the specification fixes.
  // The engine, key, random and verify-after-sign models follow the knobs of tb_models.svh;
  // this task expects the normal path (no timeout, no engine error, valid verify-after-sign).
  reg  chk_verbose;
  integer n_fail_before;
  reg [63:0] rd_pat;
  task run_op;
    reg        res;
    reg        e_key, e_rng, e_vas;
    reg        ed_new, ml_new;
    reg        sg;
    integer    grp, i;
    reg [63:0] bd;
    reg        rj;
    reg [63:0] pat;
    begin
      if (o_clr_before) clr_all;
      clear_flags;
      apb_r(A_CNT_OPS, c0_ops);
      apb_r(A_CNT_FAIL, c0_fail);
      program_op;
      clear_counters;
      m_rd_got = 1'b0;
      rd_pat = {32'hD15EA5E0, 15'h0, o_offm};
      if (o_offm < 17'd1024) bus_write(o_offm[9:3], rd_pat, 8'hFF);
      exp_ee = f_ref_err(t_ctrl_en, t_eff_en, o_alg, o_op, o_form, o_nonce, o_hash, o_hybpol,
                         o_slh, o_lmst, o_lmots, o_hsslvl, o_xm, o_len, o_offm, o_ctx);
      n_fail_before = n_fail;
      cmd_start;
      wait_op_done;
      ck(wait_timeout === 1'b0, "operation did not complete (timeout)");
      read_outcome;
      if (exp_ee >= 0) begin
        // Failing check: exactly one flag, no engine, no key, no random, secrets cleared
        ck32("err flags of a failing check (ERR table, DEC-038)", r_err, 32'h1 << exp_ee);
        ck((exp_ee == E_LOCKV) || (r_irq_raw[1] === 1'b1), "irq_raw.err set by an error (ERR table)");
        ck(r_irq_raw[0] === 1'b1, "irq_raw.done set when an operation ends in an error (workbook irq_raw.done: with or without an error)");
        ck((o_clr_before === 1'b0) || (r_sts[8] === 1'b0), "resvld stays 0 after a failing check");
        ck(r_sts[0] === 1'b0, "busy is 0 after the operation");
        ck(n_eng_start0 + n_eng_start1 + n_eng_start2 == 0, "no engine start after a failing check (SVA-004)");
        ck(n_key_start + n_rng_start + n_vas_start == 0, "no key, random or VAS start after a failing check");
        ck(n_zero_req >= 1, "secrets cleared after an error, also for a start while the IP is disabled (REQ-SEC-005, section 12)");
        if (P_EN_LOG[0]) begin
          ck32("cnt_ops unchanged by a failing check (DEC-033)", r_cnt_ops, c0_ops);
          ck32("cnt_fail counts the failed operation, also for a start while the IP is disabled (DEC-033)", r_cnt_fail, c0_fail + 1);
        end
      end else begin
        res    = (o_op == OP_VRFY) ? k_eng_sigok : 1'b1;
        e_key  = (o_op != OP_VRFY);
        e_rng  = f_ref_rng(o_alg, o_op, o_hedged, o_nonce);
        e_vas  = (o_op == OP_SIGN) & P_EN_VAS[0];
        grp    = f_ref_grp(o_alg);
        ck32("no error flag on a passing operation", r_err, 32'h0);
        ck32("no alarm flag on a passing operation", r_alarm, 32'h0);
        ck(r_irq_raw[0] === 1'b1, "irq_raw.done set at the end of a result (ENUM_ST_RESULT)");
        ck(r_irq_raw[1] === 1'b0, "irq_raw.err stays 0 on a passing operation");
        ck(r_sts[8] === 1'b1, "resvld set after a result (ENUM_ST_RESULT)");
        ck(r_sts[0] === 1'b0, "busy is 0 after the operation");
        ck32("engine group 0 start count", n_eng_start0, (grp == 0) ? 1 : 0);
        ck32("engine group 1 start count", n_eng_start1, (grp == 1) ? 1 : 0);
        ck32("engine group 2 start count", n_eng_start2, (grp == 2) ? 1 : 0);
        ck32("key block start count (ENUM_ST_KEY for sign and key generation)", n_key_start, e_key ? 1 : 0);
        if (o_op != OP_KGEN)
          ck32("random block start count (DEC-031)", n_rng_start, e_rng ? 1 : 0);
        ck32("verify-after-sign start count (ENUM_ST_VAS)", n_vas_start, e_vas ? 1 : 0);
        ck(n_zero_req >= 1, "secrets cleared after the result (ENUM_ST_CLEAR)");
        if (o_op == OP_VRFY) begin
          ed_new = ref_edok; ml_new = ref_mlok;
          if (o_alg == ALG_ED25519)  ed_new = res;
          if (f_is_mldsa(o_alg))     ml_new = res;
          if (P_EN_HYBRID[0]) begin
            ref_edok = ed_new; ref_mlok = ml_new;
            ck32("sts.edok (DEC-030)", r_sts[10], {31'h0, ed_new});
            ck32("sts.mlok (DEC-030)", r_sts[11], {31'h0, ml_new});
          end
          sg = f_ref_sigok(o_alg, o_hybpol, res, ed_new, ml_new);
          ck32("sts.sigok of a verification (OP-004, DEC-030)", r_sts[9], {31'h0, sg});
          if (o_offm < 17'd1024) begin
            ck(m_rd_got === 1'b1, "the engine read the message word through the buffer engine port");
            ck(m_rd_cap === rd_pat, "the data that the engine read equal the message word written to the buffer (REQ-IF-002)");
          end
        end else begin
          for (i = 0; i < k_eng_words; i = i + 1) begin
            pat = {16'hA55A, 12'h0, o_alg, 14'h0, o_op, 16'(i)};
            bus_read((o_offr[9:3] + i), bd, rj);
            ck(bd === pat, "result word in the buffer at dsig_off_res (OP-002, OP-003)");
          end
        end
        if (P_EN_LOG[0]) begin
          ck32("cnt_ops counts the accepted start (DEC-033)", r_cnt_ops, c0_ops + 1);
          ck32("cnt_fail counts an invalid verification (DEC-033)", r_cnt_fail,
               c0_fail + ((o_op == OP_VRFY && !res) ? 1 : 0));
        end
      end
    end
      if (n_fail != n_fail_before)
        $display("  case: en=%0d eff=0x%04h alg=%0d op=%0d form=%0d hash=%0d nonce=%0d hybpol=%0d hedged=%0d slh=%0d lmst=%0d lmots=%0d hss=%0d xm=%0d len=%0d offm=%0d expected_flag=%0d got_err=0x%03h sts=0x%03h",
                 t_ctrl_en, t_eff_en, o_alg, o_op, o_form, o_hash, o_nonce, o_hybpol, o_hedged, o_slh, o_lmst,
                 o_lmots, o_hsslvl, o_xm, o_len, o_offm, exp_ee, r_err[11:0], r_sts[11:0]);
  endtask

  // ----------------------------------------------------------------------------------------
  // T01: reset values, version and capability words (TEST-015, REQ-REG-001, REQ-REG-003)
  // ----------------------------------------------------------------------------------------
  task t_reset_regs;
    reg [31:0] d;
    integer i;
    begin
      test_begin("TEST-015 REQ-REG-001 REQ-REG-003 reset values, version, capability");
      apb_expect("dsig_version is 0x00010000 (REQ-REG-003)", A_VERSION, 32'h0001_0000);
      apb_expect("dsig_cap_alg equals PARA_CAP_ALG", A_CAP_ALG, {17'h0, P_CAP_ALG[14:0]});
      apb_expect("dsig_cap_kgen equals PARA_CAP_KGEN", A_CAP_KGEN, {17'h0, P_CAP_KGEN[14:0]});
      apb_expect("dsig_cap_sign equals PARA_CAP_SIGN", A_CAP_SIGN, {17'h0, P_CAP_SIGN[14:0]});
      apb_expect("dsig_cap_vrfy equals PARA_CAP_VRFY", A_CAP_VRFY, {17'h0, P_CAP_VRFY[14:0]});
      apb_expect("dsig_cap_slh equals PARA_SLHDSA_SETS", A_CAP_SLH, {20'h0, P_SLH_SETS[11:0]});
      apb_expect("dsig_cap_lms equals PARA_LMS_SETS", A_CAP_LMS, {12'h0, P_LMS_SETS[19:0]});
      apb_expect("dsig_cap_xmss equals PARA_XMSS_SETS_LO", A_CAP_XMSS, P_XMSS_LO);
      apb_expect("dsig_cap_xmssh equals PARA_XMSS_SETS_HI", A_CAP_XMSSH, {20'h0, P_XMSS_HI[11:0]});
      apb_expect("dsig_cap_lmots equals PARA_LMOTS_SETS", A_CAP_LMOTS, {16'h0, P_LMOTS_SETS[15:0]});
      csr_field_check("dsig_cap_buf.buf equals PARA_BUF_BYTES", A_CAP_BUF, 0, 17, P_BUF_BYTES);
      csr_field_check("cap_feat.pure", A_CAP_FEAT, 0, 1, P_EN_PURE);
      csr_field_check("cap_feat.prehash", A_CAP_FEAT, 1, 1, P_EN_PREHASH);
      csr_field_check("cap_feat.vas", A_CAP_FEAT, 7, 1, P_EN_VAS);
      csr_field_check("cap_feat.hybrid", A_CAP_FEAT, 10, 1, P_EN_HYBRID);
      csr_field_check("cap_feat.log", A_CAP_FEAT, 11, 1, P_EN_LOG);
      csr_field_check("cap_feat.lock", A_CAP_FEAT, 12, 1, P_EN_LOCK);
      csr_field_check("cap_feat.csrasync", A_CAP_FEAT, 14, 1, P_CSR_ASYNC);
      apb_expect("dsig_ctrl.en resets to 0", A_CTRL, 32'h0);
      apb_expect("dsig_alg_en resets to 0 (REQ-REG-001)", A_ALG_EN, 32'h0);
      apb_expect("dsig_alg_act resets to 0 (REQ-REG-001)", A_ALG_ACT, 32'h0);
      apb_expect("dsig_lock resets to 0", A_LOCK, 32'h0);
      apb_expect("dsig_op resets to verification, algorithm 0", A_OP, 32'h0000_0200);
      apb_expect("dsig_set resets to hsslvl 1", A_SET, 32'h0010_0000);
      apb_expect("dsig_len_msg resets to 0", A_LEN_MSG, 32'h0);
      apb_expect("dsig_off_res resets to 0", A_OFF_RES, 32'h0);
      apb_expect("dsig_sts resets to 0", A_STS, 32'h0);
      apb_expect("dsig_err resets to 0", A_ERR, 32'h0);
      apb_expect("dsig_irq_raw resets to 0", A_IRQ_RAW, 32'h0);
      apb_expect("dsig_irq_en resets to 0", A_IRQ_EN, 32'h0);
      apb_expect("dsig_irq_sts resets to 0", A_IRQ_STS, 32'h0);
      apb_expect("dsig_alarm resets to 0", A_ALARM, 32'h0);
      apb_expect("dsig_win_addr resets to 0", A_WIN_ADDR, 32'h0);
      apb_expect("dsig_cnt_ops resets to 0", A_CNT_OPS, 32'h0);
      apb_expect("dsig_cnt_fail resets to 0", A_CNT_FAIL, 32'h0);
      apb_expect("dsig_tmo resets to 0xFFFF each", A_TMO, 32'hFFFF_FFFF);
      ck(irq === 1'b0, "o_irq is 0 after reset (section 6.4)");
      ck(alarm === 1'b0, "o_alarm is 0 after reset (section 6.4)");
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T02: read and write of the registers (REQ-IF-001, section 11.1)
  // ----------------------------------------------------------------------------------------
  task t_rw_regs;
    reg [31:0] d;
    integer i;
    begin
      test_begin("TEST-016 REQ-IF-001 register read and write, reserved bits, ro and wo fields");
      apb_w(A_ALG_EN, 32'hFFFF_FFFF);
      apb_expect("dsig_alg_en keeps 15 bits, reserved bit 15 and above read 0", A_ALG_EN, 32'h0000_7FFF);
      apb_w(A_ALG_EN, 32'h0000_0000);
      apb_w(A_OP, 32'hFFFF_FFFF);
      apb_expect("dsig_op writable fields only", A_OP, 32'h3731_330F);
      apb_w(A_SET, 32'hFFFF_FFFF);
      apb_expect("dsig_set writable fields only", A_SET, 32'h3FFF_1F0F);
      apb_w(A_LEN_MSG, 32'hA5A5_5A5A);
      apb_expect("dsig_len_msg 32 bits", A_LEN_MSG, 32'hA5A5_5A5A);
      apb_w(A_LEN_CTX, 32'hFFFF_FFFF);
      apb_expect("dsig_len_ctx 8 bits", A_LEN_CTX, 32'h0000_00FF);
      apb_w(A_OFF_MSG, 32'hFFFF_FFFF);
      apb_expect("dsig_off_msg 17 bits", A_OFF_MSG, 32'h0001_FFFF);
      apb_w(A_OFF_SIG, 32'h0001_5555);
      apb_expect("dsig_off_sig 17 bits", A_OFF_SIG, 32'h0001_5555);
      apb_w(A_OFF_PK, 32'h0000_AAAA);
      apb_expect("dsig_off_pk 17 bits", A_OFF_PK, 32'h0000_AAAA);
      apb_w(A_OFF_RES, 32'h0001_2345);
      apb_expect("dsig_off_res 17 bits", A_OFF_RES, 32'h0001_2345);
      apb_w(A_TMO, 32'h1234_5678);
      apb_expect("dsig_tmo ent and key", A_TMO, 32'h1234_5678);
      apb_w(A_IRQ_EN, 32'hFFFF_FFFF);
      apb_expect("dsig_irq_en 3 bits", A_IRQ_EN, 32'h0000_0007);
      apb_w(A_IRQ_EN, 32'h0);
      apb_w(A_CTRL, 32'hFFFF_FFFF);
      apb_expect("dsig_ctrl.en only", A_CTRL, 32'h0000_0001);
      apb_w(A_CTRL, 32'h0);
      // Restore the reset values that later tests rely on
      apb_w(A_OP, 32'h0000_0200);
      apb_w(A_SET, 32'h0010_0000);
      apb_w(A_LEN_MSG, 32'h0);
      apb_w(A_LEN_CTX, 32'h0);
      apb_w(A_OFF_MSG, 32'h0);
      apb_w(A_OFF_SIG, 32'h0);
      apb_w(A_OFF_PK, 32'h0);
      apb_w(A_OFF_RES, 32'h0);
      apb_w(A_TMO, 32'h0000_0001);
      // Read-only registers ignore writes
      apb_w(A_VERSION, 32'hFFFF_FFFF);
      apb_expect("dsig_version ignores a write", A_VERSION, 32'h0001_0000);
      apb_w(A_CAP_ALG, 32'h0);
      apb_expect("dsig_cap_alg ignores a write", A_CAP_ALG, {17'h0, P_CAP_ALG[14:0]});
      apb_w(A_ALG_ACT, 32'hFFFF_FFFF);
      apb_expect("dsig_alg_act ignores a write", A_ALG_ACT, 32'h0);
      apb_w(A_STS, 32'hFFFF_FFFF);
      apb_expect("dsig_sts ignores a write", A_STS, 32'h0);
      apb_w(A_IRQ_STS, 32'hFFFF_FFFF);
      apb_expect("dsig_irq_sts ignores a write", A_IRQ_STS, 32'h0);
      // Write-only registers read 0 (REQ-SEC-001)
      apb_w(A_WIN_ADDR, 32'h0);
      for (i = 0; i < 17; i = i + 1) apb_w(A_KEY0 + 4 * i, 32'hC3A5_0000 + i);
      for (i = 0; i < 17; i = i + 1) begin
        apb_r(A_KEY0 + 4 * i, d);
        ck32("a key word never returns on a read (REQ-SEC-001)", d, 32'h0);
      end
      apb_expect("dsig_cmd reads 0", A_CMD, 32'h0);
      apb_expect("dsig_win_wr reads 0", A_WIN_WR, 32'h0);
      // Clear the key words again through the zeroization path
      cmd_clr;
      cyc(20);
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T03: APB4 access behavior of the CSR (TEST-016, section 11.4, IHI 0024D)
  // ----------------------------------------------------------------------------------------
  task t_apb_proto;
    reg [31:0] d, d2;
    reg        er;
    integer    i;
    begin
      test_begin("TEST-016 REQ-IF-001 APB4 access cases of section 11.4");
      // Wait states
      apb_r(A_VERSION, d);
      if (P_CSR_ASYNC == 32'd0) ck(apb_last_wait == 1, "one wait state with the register clock equal to PCLK (11.4)");
      else ck(apb_last_wait >= 0 && apb_last_wait < 64, "bounded wait states with an asynchronous register clock (11.4)");
      // Back-to-back transfers: PSEL stays high between transfers (IHI0024D 4.1)
      apb_keep = 1'b1;
      apb_xfer(1'b1, A_ALG_EN, 32'h0000_0123, 4'hF, 3'b000, 0, d, er);
      apb_xfer(1'b0, A_ALG_EN, 32'h0, 4'h0, 3'b000, 0, d, er);
      ck32("back-to-back write then read returns the written value", d, 32'h0000_0123);
      apb_keep = 1'b0;
      apb_xfer(1'b0, A_VERSION, 32'h0, 4'h0, 3'b000, 0, d, er);
      ck32("last read of a back-to-back sequence", d, 32'h0001_0000);
      apb_w(A_ALG_EN, 32'h0);
      // Non-secure access with protect enabled: PSLVERR and no change (WF-016)
      apb_xfer(1'b1, A_ALG_EN, 32'h0000_0001, 4'hF, 3'b010, 0, d, er);
      ck(er === 1'b1, "non-secure write gives PSLVERR with i_protect_en (11.4, IHI0024D 3.5)");
      apb_expect("non-secure write changed nothing (WF-016)", A_ALG_EN, 32'h0);
      apb_r(A_VERSION, d);
      apb_xfer(1'b0, A_ALG_EN, 32'h0, 4'h0, 3'b010, 0, d2, er);
      ck(er === 1'b1, "non-secure read gives PSLVERR with i_protect_en (11.4)");
      ck32("a failing read returns the last read data (11.4)", d2, 32'h0001_0000);
      protect_en = 1'b0;
      apb_xfer(1'b1, A_ALG_EN, 32'h0000_0001, 4'hF, 3'b010, 0, d, er);
      ck(er === 1'b0, "non-secure write is accepted without i_protect_en (11.4)");
      apb_expect("non-secure write took effect without protect", A_ALG_EN, 32'h0000_0001);
      protect_en = 1'b1;
      apb_w(A_ALG_EN, 32'h0);
      // Unaligned address
      apb_xfer(1'b1, A_ALG_EN + 16'd1, 32'h0000_0001, 4'hF, 3'b000, 0, d, er);
      ck(er === 1'b1, "unaligned write gives PSLVERR (11.4)");
      apb_expect("unaligned write changed nothing", A_ALG_EN, 32'h0);
      apb_xfer(1'b0, A_VERSION + 16'd2, 32'h0, 4'h0, 3'b000, 0, d, er);
      ck(er === 1'b1, "unaligned read gives PSLVERR (11.4)");
      // Partial strobes: PSLVERR and no change (DEC-024)
      apb_xfer(1'b1, A_ALG_EN, 32'h0000_00FF, 4'h3, 3'b000, 0, d, er);
      ck(er === 1'b1, "write with PSTRB 0x3 gives PSLVERR (11.4, DEC-024)");
      apb_xfer(1'b1, A_ALG_EN, 32'h0000_00FF, 4'h0, 3'b000, 0, d, er);
      ck(er === 1'b1, "write with PSTRB 0x0 gives PSLVERR (11.4, DEC-024)");
      apb_expect("partial strobe write changed nothing", A_ALG_EN, 32'h0);
      // Responses disabled by i_slverr_en: whole-word write
      slverr_en = 1'b0;
      apb_xfer(1'b1, A_ALG_EN, 32'h0000_0055, 4'h3, 3'b000, 0, d, er);
      ck(er === 1'b0, "no PSLVERR when i_slverr_en is 0 (11.4)");
      apb_expect("whole-word write when i_slverr_en is 0 (11.4)", A_ALG_EN, 32'h0000_0055);
      apb_xfer(1'b0, A_VERSION + 16'd1, 32'h0, 4'h0, 3'b000, 0, d, er);
      ck(er === 1'b0, "no PSLVERR on an unaligned read when i_slverr_en is 0");
      slverr_en = 1'b1;
      apb_w(A_ALG_EN, 32'h0);
      // Aligned address that is not a register: OKAY, read 0, write ignored
      apb_expect("read of an aligned non-register returns 0 (11.4)", 16'h200, 32'h0);
      apb_expect("read of a hole between registers returns 0 (11.4)", 16'h0B0, 32'h0);
      apb_expect("read of a hole after the capability words returns 0 (11.4)", 16'h030, 32'h0);
      apb_w(16'h0B0, 32'hFFFF_FFFF);
      apb_w(16'h1F0, 32'hFFFF_FFFF);
      // Reads of write-only registers return 0
      apb_expect("read of dsig_cmd returns 0 (11.4)", A_CMD, 32'h0);
      apb_expect("read of dsig_win_wr returns 0 (11.4)", A_WIN_WR, 32'h0);
      apb_expect("read of dsig_key_16 returns 0 (11.4)", A_KEY0 + 16'd64, 32'h0);
      // A read request with a non-zero PSTRB breaks a requester rule (IHI0024D 3.2); mask that assertion
      apb_mask[10] = 1'b1;
      apb_xfer(1'b0, A_VERSION, 32'h0, 4'hF, 3'b000, 0, d, er);
      apb_mask[10] = 1'b0;
      ck32("a read with PSTRB driven still returns the register", d, 32'h0001_0000);
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T04: enable bits and start (TEST-013, REQ-REG-001, ERR-001)
  // ----------------------------------------------------------------------------------------
  task t_enable_start;
    begin
      test_begin("TEST-013 REQ-REG-001 ERR-001 start with IP and algorithm enable bits");
      set_default_op;
      o_alg = ALG_ED25519; o_op = OP_VRFY; o_hybpol = 2'd1;
      // IP disabled, algorithm enabled: algdis
      t_ctrl_en = 1'b0; t_eff_en = 15'h7FFF;
      prog_alg_en(15'h7FFF);
      apb_w(A_CTRL, 32'h0);
      cyc(8);
      k_eng_sigok = 1'b1;
      run_op;
      cmd_clr;
      apb_r(A_ERR, r_err);
      ck32("dsig_cmd.clr clears the error flags (workbook dsig_cmd.clr, TBD-014 option A)", r_err, 32'h0);
      apb_expect("dsig_cmd.clr clears the done and error events (workbook dsig_cmd.clr)", A_IRQ_RAW, 32'h0);
      // IP enabled, algorithm disabled: algdis
      t_ctrl_en = 1'b1; t_eff_en = 15'h0000;
      prog_alg_en(15'h0000);
      apb_w(A_CTRL, 32'h1);
      cyc(8);
      apb_expect("dsig_alg_act follows the disabled algorithm", A_ALG_ACT, 32'h0);
      run_op;
      // The next algorithm enabled, the selected one is not
      t_eff_en = 15'h0002;
      prog_alg_en(15'h0002);
      cyc(8);
      apb_expect("dsig_alg_act follows dsig_alg_en (REQ-REG-001)", A_ALG_ACT, 32'h0000_0002);
      run_op;
      // Both enabled: success
      t_eff_en = 15'h7FFF;
      prog_alg_en(15'h7FFF);
      cyc(8);
      apb_expect("dsig_alg_act follows dsig_alg_en (all)", A_ALG_ACT, 32'h0000_7FFF);
      run_op;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T05: errors of ENUM_ST_CHECK (TEST-009, TEST-010, TEST-023, ERR-001 to ERR-006, DEC-032, DEC-038)
  // ----------------------------------------------------------------------------------------
  task cs;   // one case: change the descriptor fields and run the operation
    input [3:0] alg;
    input [1:0] op;
    input [1:0] form;
    input [2:0] hash;
    input [31:0] len;
    input [16:0] offm;
    begin
      set_default_op;
      o_alg = alg; o_op = op; o_form = form; o_hash = hash; o_len = len; o_offm = offm;
      o_hybpol = (alg == ALG_MLDSA44) ? 2'd2 : 2'd1;
      run_op;
    end
  endtask

  task t_errors;
    begin
      test_begin("TEST-009 TEST-010 TEST-023 REQ-FUNC-009 REQ-FUNC-010 REQ-ERR-001 errors of the check");
      k_eng_sigok = 1'b1; k_vas_ok = 1'b1;
      enable_ip(15'h7FFF);
      // ERR-002: reserved codes and operations that are not built
      cs(ALG_RSVD, OP_VRFY, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_ED25519, OP_RSVD, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_SLHDSA, OP_SIGN, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_SLHDSA, OP_KGEN, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_LMS, OP_SIGN, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_XMSS, OP_SIGN, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_XMSS, OP_KGEN, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_ED25519, OP_VRFY, 2'd2, 3'd0, 32'd32, 17'd0);
      cs(ALG_ED25519, OP_VRFY, 2'd3, 3'd0, 32'd32, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd6, 32'd32, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd7, 32'd32, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd6, 32'd32, 17'd0);
      // ERR-002: parameter sets
      set_default_op; o_alg = ALG_SLHDSA; o_slh = 4'd12; run_op;
      set_default_op; o_alg = ALG_SLHDSA; o_slh = 4'd15; run_op;
      set_default_op; o_alg = ALG_SLHDSA; o_slh = 4'd1; run_op;
      set_default_op; o_alg = ALG_SLHDSA; o_slh = 4'd0; run_op;
      set_default_op; o_alg = ALG_LMS; o_lmst = 5'd20; run_op;
      set_default_op; o_alg = ALG_LMS; o_lmst = 5'd31; run_op;
      set_default_op; o_alg = ALG_LMS; o_lmst = 5'd1; run_op;
      set_default_op; o_alg = ALG_LMS; o_lmots = 4'd1; run_op;
      set_default_op; o_alg = ALG_LMS; o_lmst = 5'd0; o_lmots = 4'd0; o_hsslvl = 4'd1; run_op;
      set_default_op; o_alg = ALG_XMSS; o_xm = 6'd44; run_op;
      set_default_op; o_alg = ALG_XMSS; o_xm = 6'd63; run_op;
      set_default_op; o_alg = ALG_XMSS; o_xm = 6'd1; run_op;
      set_default_op; o_alg = ALG_XMSS; o_xm = 6'd33; run_op;
      set_default_op; o_alg = ALG_XMSS; o_xm = 6'd0; run_op;
      // ERR-002: ECDSA nonce reserved code, hybrid policy reserved code
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd2; run_op;
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd3; run_op;
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd1; run_op;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; o_hybpol = 2'd3; run_op;
      // ERR-003: curve and hash pairing (DEC-032)
      cs(ALG_P384, OP_VRFY, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_P384, OP_VRFY, FORM_PURE, 3'd3, 32'd32, 17'd0);
      cs(ALG_P384, OP_VRFY, FORM_PURE, 3'd1, 32'd32, 17'd0);
      cs(ALG_P384, OP_VRFY, FORM_PURE, 3'd4, 32'd32, 17'd0);
      cs(ALG_P384, OP_VRFY, FORM_PURE, 3'd2, 32'd32, 17'd0);
      cs(ALG_P521, OP_VRFY, FORM_PURE, 3'd1, 32'd32, 17'd0);
      cs(ALG_P521, OP_VRFY, FORM_PURE, 3'd4, 32'd32, 17'd0);
      cs(ALG_P521, OP_VRFY, FORM_PURE, 3'd2, 32'd32, 17'd0);
      cs(ALG_P521, OP_VRFY, FORM_PURE, 3'd5, 32'd32, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd2, 32'd32, 17'd0);
      cs(ALG_K256, OP_VRFY, FORM_PURE, 3'd3, 32'd32, 17'd0);
      cs(ALG_K256, OP_VRFY, FORM_PURE, 3'd5, 32'd32, 17'd0);
      // ERR-003: HSS level count, prehash digest length
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd0; run_op;
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd9; run_op;
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd15; run_op;
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd8; run_op;
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd1; run_op;
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd0, 32'd33, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd0, 32'd31, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd0, 32'd32, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd1, 32'd48, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd2, 32'd64, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd3, 32'd32, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd4, 32'd48, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd5, 32'd64, 17'd0);
      cs(ALG_MLDSA44, OP_VRFY, FORM_PREHASH, 3'd5, 32'd48, 17'd0);
      // ERR-003: prehash digest of Ed25519ph and Ed448ph with SHA-512 (64 bytes; unambiguous for every reading of TBD-015)
      cs(ALG_ED25519PH, OP_VRFY, FORM_PREHASH, 3'd2, 32'd63, 17'd0);
      cs(ALG_ED25519PH, OP_VRFY, FORM_PREHASH, 3'd2, 32'd64, 17'd0);
      cs(ALG_ED25519PH, OP_VRFY, FORM_PREHASH, 3'd2, 32'd65, 17'd0);
      cs(ALG_ED448PH, OP_VRFY, FORM_PREHASH, 3'd2, 32'd32, 17'd0);
      cs(ALG_ED448PH, OP_SIGN, FORM_PREHASH, 3'd2, 32'd64, 17'd0);
      // ERR-006: region does not fit the buffer
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd100, 17'd1000);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'hFFFF_FFFF, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd1025, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd1024, 17'd0);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd1, 17'd1023);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd2, 17'd1023);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd0, 17'd1024);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd1, 17'd1024);
      cs(ALG_P256, OP_VRFY, FORM_PURE, 3'd0, 32'd10, 17'h1FFFF);
      // ASM-023: Ed25519ph and Ed448ph only in the prehash form; 64-byte digest whatever the hash code; key generation
      // has no message, so no length check
      cs(ALG_ED25519PH, OP_SIGN, FORM_PURE, 3'd2, 32'd64, 17'd0);
      cs(ALG_ED448PH, OP_VRFY, FORM_PURE, 3'd2, 32'd64, 17'd0);
      cs(ALG_ED25519PH, OP_VRFY, FORM_PREHASH, 3'd0, 32'd64, 17'd0);
      cs(ALG_ED25519PH, OP_VRFY, FORM_PREHASH, 3'd0, 32'd32, 17'd0);
      cs(ALG_ED448PH, OP_KGEN, FORM_PREHASH, 3'd2, 32'd0, 17'd0);
      // ASM-024: deterministic ECDSA nonce (dsig_op.nonce = 1 with PARA_ECDSA_NONCE 2) with SHA-2 only
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd1; o_hash = 3'd3; run_op;
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd1; o_hash = 3'd5; run_op;
      set_default_op; o_alg = ALG_P521; o_op = OP_SIGN; o_nonce = 2'd1; o_hash = 3'd2; run_op;
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd0; o_hash = 3'd5; run_op;
      // DEC-032 for signing and verification only: key generation of P-384 and P-521 with a short hash code is accepted
      cs(ALG_P384, OP_KGEN, FORM_PURE, 3'd0, 32'd32, 17'd0);
      cs(ALG_P521, OP_KGEN, FORM_PURE, 3'd1, 32'd32, 17'd0);
      cs(ALG_P521, OP_SIGN, FORM_PURE, 3'd1, 32'd32, 17'd0);
      // ASM-025: HashSLH-DSA digest length equal to the hash
      cs(ALG_SLHDSA, OP_VRFY, FORM_PREHASH, 3'd0, 32'd33, 17'd0);
      cs(ALG_SLHDSA, OP_VRFY, FORM_PREHASH, 3'd4, 32'd48, 17'd0);
      // ASM-020: the context after the message is part of the region (Ed448, ML-DSA, SLH-DSA), not for ECDSA
      set_default_op; o_alg = ALG_ED448; o_len = 32'd1000; o_ctx = 8'd30; run_op;
      set_default_op; o_alg = ALG_ED448; o_len = 32'd1000; o_ctx = 8'd24; run_op;
      set_default_op; o_alg = ALG_MLDSA44; o_hybpol = 2'd2; o_len = 32'd1000; o_ctx = 8'd25; run_op;
      set_default_op; o_alg = ALG_P256; o_len = 32'd1000; o_ctx = 8'd200; run_op;
      // Priority of the checks (DEC-038): disabled > unsupported > length > buffer
      t_eff_en = 15'h7FFD; prog_alg_en(15'h7FFD); cyc(8);
      cs(ALG_ED25519CTX, OP_RSVD, FORM_PURE, 3'd0, 32'hFFFF_FFFF, 17'd0);
      t_eff_en = 15'h7FFF; prog_alg_en(15'h7FFF); cyc(8);
      cs(ALG_SLHDSA, OP_SIGN, FORM_PURE, 3'd0, 32'hFFFF_FFFF, 17'd0);
      set_default_op; o_alg = ALG_P384; o_hash = 3'd0; o_len = 32'hFFFF_FFFF; run_op;
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd0; o_lmst = 5'd20; run_op;
      set_default_op; o_alg = ALG_LMS; o_hsslvl = 4'd0; o_offm = 17'd1020; o_len = 32'd32; run_op;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T06: complete flows of every operation (OP-002 to OP-004, ENUM_ST_KEY, RNG, RUN, VAS, RESULT)
  // ----------------------------------------------------------------------------------------
  task t_flows;
    integer a, h;
    begin
      test_begin("TEST-023 REQ-FUNC-001 to 008 OP-002 OP-003 OP-004 flows of the control block");
      enable_ip(15'h7FFF);
      k_vas_ok = 1'b1;
      // Verification of every algorithm, valid then invalid signature
      for (a = 0; a <= 14; a = a + 1) begin
        set_default_op; o_alg = a[3:0]; o_op = OP_VRFY;
        o_hybpol = (a == 9) ? 2'd2 : 2'd1;
        if (a == 5 || a == 6 || a == 7 || a == 8) o_hash = 3'd5;
        if (a == 2 || a == 4) begin o_form = FORM_PREHASH; o_hash = 3'd2; o_len = 32'd64; end
        k_eng_sigok = 1'b1; run_op;
        k_eng_sigok = 1'b0; run_op;
      end
      k_eng_sigok = 1'b1;
      // Signing and key generation of every algorithm that supports them
      for (a = 0; a <= 11; a = a + 1) begin
        set_default_op; o_alg = a[3:0]; o_op = OP_SIGN;
        if (a == 5 || a == 6 || a == 7 || a == 8) o_hash = 3'd2;
        if (a == 2 || a == 4) begin o_form = FORM_PREHASH; o_hash = 3'd2; o_len = 32'd64; end
        o_nonce = 2'd0; o_hedged = 1'b0; run_op;
        o_nonce = 2'd1; o_hedged = 1'b1; run_op;
        o_op = OP_KGEN; run_op;
      end
      // ECDSA hash selections with the sufficient pairings, prehash forms of ML-DSA
      for (h = 0; h <= 5; h = h + 1) begin
        set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_hash = h[2:0]; o_nonce = 2'd0; run_op;
        set_default_op; o_alg = ALG_MLDSA65; o_op = OP_SIGN; o_form = FORM_PREHASH; o_hash = h[2:0];
        o_len = f_dig_len(h[2:0]); o_hedged = 1'b1; run_op;
        set_default_op; o_alg = ALG_MLDSA65; o_op = OP_VRFY; o_form = FORM_PREHASH; o_hash = h[2:0];
        o_len = f_dig_len(h[2:0]); run_op;
      end
      // Engine result of different lengths and latencies
      k_eng_words = 1; k_eng_lat = 0; set_default_op; o_alg = ALG_ED448; o_op = OP_SIGN; run_op;
      k_eng_words = 8; k_eng_lat = 40; set_default_op; o_alg = ALG_ED448PH; o_op = OP_SIGN; o_form = FORM_PREHASH;
      o_hash = 3'd2; o_len = 32'd64; run_op;
      k_eng_words = 4; k_eng_lat = 12;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T07: hybrid verification (TEST-012, REQ-FUNC-012, DEC-030, numbered example 2)
  // ----------------------------------------------------------------------------------------
  task hyb_run;   // one verification of the hybrid pair, no clear before it
    input [3:0] alg;
    input [1:0] pol;
    input       valid;
    begin
      set_default_op; o_alg = alg; o_op = OP_VRFY; o_hybpol = pol; o_clr_before = 1'b0;
      k_eng_sigok = valid;
      run_op;
    end
  endtask

  task t_hybrid;
    integer pol, e, m, ord;
    begin
      test_begin("TEST-012 REQ-FUNC-012 DEC-030 hybrid verification, numbered example 2");
      enable_ip(15'h7FFF);
      // Numbered example 2 of section 10.2 (policy 0x0, both valid)
      clr_all;
      hyb_run(ALG_ED25519, 2'd0, 1'b1);     // edok 1, mlok 0, sigok 0
      hyb_run(ALG_MLDSA44, 2'd0, 1'b1);     // mlok 1, sigok 1
      hyb_run(ALG_MLDSA44, 2'd0, 1'b0);     // mlok 0, sigok 0
      hyb_run(ALG_ED25519, 2'd1, 1'b1);     // policy 0x1, ed valid: sigok 1
      // Every policy, every combination of valid and invalid, both orders
      for (pol = 0; pol <= 2; pol = pol + 1)
        for (e = 0; e <= 1; e = e + 1)
          for (m = 0; m <= 1; m = m + 1)
            for (ord = 0; ord <= 1; ord = ord + 1) begin
              clr_all;
              if (ord == 0) begin
                hyb_run(ALG_ED25519, pol[1:0], e[0]);
                hyb_run(ALG_MLDSA44, pol[1:0], m[0]);
              end else begin
                hyb_run(ALG_MLDSA44, pol[1:0], m[0]);
                hyb_run(ALG_ED25519, pol[1:0], e[0]);
              end
            end
      // The clear command removes the latched results
      clr_all;
      apb_expect("sts after dsig_cmd.clr: edok, mlok, resvld and sigok are 0", A_STS, 32'h0);
      // Other algorithms return their own result under any policy
      hyb_run(ALG_P256, 2'd0, 1'b1);
      hyb_run(ALG_P256, 2'd0, 1'b0);
      hyb_run(ALG_ED25519CTX, 2'd0, 1'b1);
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Helper: run an operation that is expected to fail after the check, read the outcome only
  // ----------------------------------------------------------------------------------------
  task run_raw;
    begin
      if (o_clr_before) clr_all;
      clear_flags;
      apb_r(A_CNT_OPS, c0_ops);
      apb_r(A_CNT_FAIL, c0_fail);
      program_op;
      clear_counters;
      cmd_start;
      wait_op_done;
      ck(wait_timeout === 1'b0, "operation did not complete (timeout)");
      read_outcome;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T08: verify-after-sign mismatch (TEST-026, ERR-010, REQ-SEC-003, WF-009)
  // ----------------------------------------------------------------------------------------
  task t_vas;
    reg [31:0] d;
    begin
      test_begin("TEST-026 REQ-SEC-003 ERR-010 verify-after-sign mismatch");
      enable_ip(15'h7FFF);
      k_vas_ok = 1'b0;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; run_raw;
      ck32("only vasmis is set (ERR-010)", r_err, 32'h1 << E_VASMIS);
      ck32("alarm.fault is set (ERR-010)", r_alarm, 32'h1);
      ck(r_irq_raw[1] === 1'b1, "irq_raw.err set (ERR-010)");
      ck(r_irq_raw[2] === 1'b1, "irq_raw.sec set (ERR-010)");
      ck(r_sts[8] === 1'b0, "the signature is suppressed: resvld stays 0 (ENUM_ST_VAS)");
      ck(alarm === 1'b1, "o_alarm is high (ERR-010, section 6.4)");
      ck32("one VAS start", n_vas_start, 1);
      ck(n_zero_req >= 1, "secrets cleared after a mismatch (section 12 recovery)");
      if (P_EN_LOG[0]) ck32("cnt_fail counts the failed signing (DEC-033)", r_cnt_fail, c0_fail + 1);
      // dsig_cmd.clr clears the error flag and the done and error events, not the alarm and the security event
      cmd_clr;
      apb_expect("clr cleared the vasmis flag", A_ERR, 32'h0);
      apb_expect("clr keeps alarm.fault", A_ALARM, 32'h1);
      apb_expect("clr keeps only the security event in irq_raw", A_IRQ_RAW, 32'h4);
      // o_alarm is not maskable and stays until software clears the flag
      apb_expect("irq_en is 0, o_alarm still high", A_IRQ_EN, 32'h0);
      ck(alarm === 1'b1, "o_alarm is not maskable (section 6.4)");
      apb_w(A_ALARM, 32'h1);
      cyc(8);
      ck(alarm === 1'b0, "o_alarm falls when software clears the fault flag");
      // The same signing with a matching check succeeds
      k_vas_ok = 1'b1;
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_hash = 3'd2; run_op;
      // A verification has no VAS
      set_default_op; o_alg = ALG_P256; o_op = OP_VRFY; o_hash = 3'd2; run_op;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T09: key and entropy timeouts, engine errors (ERR-004, ERR-005, ERR-008, ERR-009, WF-018)
  // ----------------------------------------------------------------------------------------
  task t_timeouts;
    begin
      test_begin("TEST-030 REQ-SEC-007 ERR-008 ERR-009 key and entropy timeouts");
      enable_ip(15'h7FFF);
      apb_w(A_TMO, 32'h0001_0001);       // 1 x 1024 core clocks for both
      // Key timeout
      k_key_hang = 1'b1;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; run_raw;
      ck32("only keytmo is set (ERR-009)", r_err, 32'h1 << E_KEYTMO);
      ck(r_irq_raw[1] === 1'b1, "irq_raw.err set (ERR-009)");
      ck32("no alarm for a key timeout (ERR-009)", r_alarm, 32'h0);
      ck(r_sts[8] === 1'b0, "no result after a key timeout");
      ck32("no engine start after a key timeout", n_eng_start0 + n_eng_start1 + n_eng_start2, 0);
      ck(n_zero_req >= 1, "secrets cleared after a key timeout (ERR-009)");
      k_key_hang = 1'b0;
      // Entropy timeout: ECDSA with a random nonce needs the random block (DEC-031)
      k_rng_hang = 1'b1;
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd0; o_hash = 3'd2; run_raw;
      ck32("only enttmo is set (ERR-008)", r_err, 32'h1 << E_ENTTMO);
      ck32("alarm.rngfail is set (ERR-008)", r_alarm, 32'h4);
      ck(r_irq_raw[1] === 1'b1, "irq_raw.err set (ERR-008)");
      ck(r_irq_raw[2] === 1'b1, "irq_raw.sec set (ERR-008)");
      ck32("no engine start after an entropy timeout", n_eng_start0 + n_eng_start1 + n_eng_start2, 0);
      ck32("one random request", n_rng_start, 1);
      ck(n_zero_req >= 1, "secrets cleared after an entropy timeout (ERR-008)");
      k_rng_hang = 1'b0;
      // The next operation works after both errors
      set_default_op; o_alg = ALG_P256; o_op = OP_SIGN; o_nonce = 2'd0; o_hash = 3'd2; run_op;
      apb_w(A_TMO, 32'h0000_0001);
      test_end;
    end
  endtask

  task t_eng_err;
    begin
      test_begin("TEST-023 REQ-ERR-001 ERR-004 ERR-005 engine errors");
      enable_ip(15'h7FFF);
      k_eng_err = 1'b1;
      // Engine reports an invalid key
      k_eng_err_flags = 12'h1 << E_BADKEY;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; run_raw;
      ck32("badkey reported by the engine (ERR-004)", r_err, 32'h1 << E_BADKEY);
      ck(r_irq_raw[1] === 1'b1, "irq_raw.err set (ERR-004)");
      ck(r_sts[8] === 1'b0, "no result after an engine error");
      ck(n_zero_req >= 1, "secrets cleared after an engine error (ERR-004)");
      if (P_EN_LOG[0]) ck32("cnt_fail counts the failed operation (DEC-033)", r_cnt_fail, c0_fail + 1);
      // Engine reports an invalid point
      k_eng_err_flags = 12'h1 << E_BADPT;
      set_default_op; o_alg = ALG_P256; o_op = OP_VRFY; o_hash = 3'd2; run_raw;
      ck32("badpt reported by the engine (ERR-005)", r_err, 32'h1 << E_BADPT);
      ck(r_sts[8] === 1'b0, "no result after an invalid point");
      // Engine reports an invalid signature format on a verification
      k_eng_err_flags = 12'h1 << E_BADPT;
      set_default_op; o_alg = ALG_MLDSA44; o_op = OP_VRFY; run_raw;
      ck32("badpt reported by a lattice engine (ERR-005)", r_err, 32'h1 << E_BADPT);
      k_eng_err = 1'b0; k_eng_err_flags = 12'h0;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; run_op;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T10: abort (S19, WF-007, REQ-SEC-005) and reset during an operation (REQ-RESET-002)
  // ----------------------------------------------------------------------------------------
  function automatic logic f_keys_zero(input integer dummy);
    begin
      f_keys_zero = ~w_keys_nz;
    end
  endfunction

  task write_keys;
    integer i;
    begin
      for (i = 0; i < 17; i = i + 1) apb_w(A_KEY0 + 4 * i, 32'hC3A5_0000 + i);
    end
  endtask

  task t_abort;
    reg [31:0] d;
    begin
      test_begin("TEST-028 REQ-SEC-005 S19 abort and reset during an operation");
      enable_ip(15'h7FFF);
      k_eng_lat = 300;
      write_keys;
      cyc(4);
      ck(w_keys_nz === 1'b1, "the key words are loaded before the operation");
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN;
      clr_all; clear_flags; clear_counters; program_op;
      write_keys;
      cmd_start;
      cyc(60);
      apb_r(A_STS, d);
      ck(d[0] === 1'b1, "busy during the operation");
      cmd_abort;
      cyc(150);
      apb_r(A_STS, d);
      ck32("after an abort: busy 0 and no result (section 12)", d, 32'h0);
      apb_r(A_IRQ_RAW, d);
      ck32("an abort raises neither done nor error", d, 32'h0);
      apb_expect("an abort sets no error flag", A_ERR, 32'h0);
      ck(w_keys_nz === 1'b0, "the key words are cleared by an abort (REQ-SEC-005)");
      ck(n_zero_req >= 1, "zeroization requested after an abort");
      ck32("the engine was started once", n_eng_start0, 1);
      k_eng_lat = 12;
      // An abort with the IP idle has no effect
      cmd_abort;
      cyc(40);
      apb_expect("sts after an abort of an idle IP", A_STS, 32'h0);
      apb_expect("err after an abort of an idle IP", A_ERR, 32'h0);
      // The IP works after an abort
      set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; run_op;
      // Reset during an operation: no result, secrets cleared, registers at reset values (REQ-RESET-002)
      k_eng_lat = 300;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN;
      clr_all; clear_flags; program_op; write_keys;
      cmd_start;
      cyc(60);
      do_reset(6);
      k_eng_lat = 12;
      cyc(20);
      ck(w_keys_nz === 1'b0, "the key words are zero after a reset (REQ-RESET-002)");
      apb_expect("sts after a reset in the middle of an operation", A_STS, 32'h0);
      apb_expect("err after a reset", A_ERR, 32'h0);
      apb_expect("irq_raw after a reset", A_IRQ_RAW, 32'h0);
      apb_expect("dsig_ctrl.en after a reset", A_CTRL, 32'h0);
      apb_expect("dsig_alg_act after a reset", A_ALG_ACT, 32'h0);
      enable_ip(15'h7FFF);
      set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; run_op;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T11: start or window write while an operation runs (ERR-012, REQ-IF-002, REQ-IF-005)
  // ----------------------------------------------------------------------------------------
  task t_busy;
    reg [31:0] d;
    reg [63:0] bd;
    reg        rj;
    begin
      test_begin("TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 ERR-012 commands and writes while busy");
      enable_ip(15'h7FFF);
      k_eng_lat = 700; k_eng_words = 2;
      // Known buffer content before the operation
      bus_write(7'd20, 64'h1111_2222_3333_4444, 8'hFF);
      bus_write(7'd21, 64'h5555_6666_7777_8888, 8'hFF);
      set_default_op; o_alg = ALG_P256; o_op = OP_VRFY; o_hash = 3'd2; o_offr = 17'd512;
      clr_all; clear_flags; clear_counters; program_op;
      apb_r(A_CNT_OPS, c0_ops);
      cmd_start;
      cyc(40);
      apb_r(A_STS, d);
      ck(d[0] === 1'b1, "busy while the engine runs");
      // A second start while busy: busycmd, the running operation is not affected
      cmd_start;
      cyc(20);
      apb_r(A_ERR, d);
      ck32("a start while busy sets busycmd (ERR-012)", d, 32'h1 << E_BUSYCMD);
      // The buffer accepts no bus write while an operation runs
      bus_write(7'd20, 64'hDEAD_BEEF_DEAD_BEEF, 8'hFF);
      ck(bus_rej_seen === 1'b1, "a bus write while busy is rejected (section 10.5, REQ-IF-002)");
      // A window write while busy is ignored and sets busycmd
      apb_w(A_ERR, 32'h1 << E_BUSYCMD);
      apb_r(A_ERR, d);
      ck32("busycmd cleared by software", d, 32'h0);
      apb_w(A_WIN_ADDR, 32'd168);
      apb_w(A_WIN_WR, 32'hCAFE_F00D);
      cyc(12);
      apb_r(A_STS, d);
      ck(d[0] === 1'b1, "the operation is still running during the window accesses (test premise)");
      apb_r(A_ERR, d);
      ck32("a window write while busy sets busycmd (ERR-012)", d, 32'h1 << E_BUSYCMD);
      apb_r(A_WIN_RD, d);
      ck32("the window read data are 0 while busy (section 10.5)", d, 32'h0);
      wait_op_done;
      ck(wait_timeout === 1'b0, "the running operation completes");
      apb_r(A_STS, d);
      ck(d[8] === 1'b1, "the running operation was not affected: result valid (ERR-012)");
      ck32("the engine ran once", n_eng_start0, 1);
      apb_r(A_CNT_OPS, d);
      if (P_EN_LOG[0]) ck32("only the accepted start is counted", d, c0_ops + 1);
      // After the operation the buffer holds the old content (nothing was written while busy)
      bus_read(7'd20, bd, rj);
      ck(bd === 64'h1111_2222_3333_4444, "bus write while busy changed nothing");
      bus_read(7'd21, bd, rj);
      ck(bd === 64'h5555_6666_7777_8888, "window write while busy changed nothing");
      // After the operation the window write works again
      apb_w(A_ERR, 32'hFFFF_FFFF);
      apb_w(A_WIN_ADDR, 32'd168);
      apb_w(A_WIN_WR, 32'hCAFE_F00D);
      cyc(12);
      apb_expect("window address advanced by 4 after the window write", A_WIN_ADDR, 32'd172);
      apb_expect("no error after an idle window write", A_ERR, 32'h0);
      bus_read(7'd21, bd, rj);
      ck(bd[31:0] === 32'hCAFE_F00D, "window write at byte 168 lands in word 21, low half");
      k_eng_lat = 12; k_eng_words = 4;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T12: algorithm enable lock (TEST-014, REQ-REG-002, ERR-011, DEC-034)
  // ----------------------------------------------------------------------------------------
  task t_lock;
    reg [31:0] d;
    begin
      test_begin("TEST-014 REQ-REG-002 ERR-011 DEC-034 lock of the algorithm enables");
      enable_ip(15'h7FFF);
      clear_flags;
      apb_expect("not locked before the request", A_LOCK, 32'h0);
      apb_w(A_ALG_EN, 32'h0000_00F1);
      t_eff_en = 15'h00F1;
      cyc(8);
      apb_w(A_LOCK, 32'h1);
      cyc(10);
      apb_expect("dsig_lock.locked is 1 and req reads 0", A_LOCK, 32'h0000_0100);
      apb_expect("dsig_alg_act keeps the held value at the lock", A_ALG_ACT, 32'h0000_00F1);
      // A write of the held value is no violation
      apb_w(A_ALG_EN, 32'h0000_00F1);
      cyc(10);
      apb_expect("no lock violation for the held value", A_ERR, 32'h0);
      // A write of another value: violation, held value stays
      apb_w(A_ALG_EN, 32'h0000_7FFF);
      cyc(10);
      apb_expect("dsig_alg_act stays at the held value (ERR-011)", A_ALG_ACT, 32'h0000_00F1);
      apb_expect("lockv error set (ERR-011)", A_ERR, 32'h1 << E_LOCKV);
      apb_expect("alarm.lockv set (ERR-011)", A_ALARM, 32'h2);
      csr_field_check("irq_raw.sec set (ERR-011)", A_IRQ_RAW, 2, 1, 1);
      csr_field_check("irq_raw.err not set by a lock violation (ERR-011)", A_IRQ_RAW, 1, 1, 0);
      ck(alarm === 1'b1, "o_alarm high for a lock violation (section 6.4)");
      // The enabled algorithms still run; the algorithm that is not held is disabled
      apb_w(A_ERR, 32'hFFFF_FFFF); apb_w(A_ALARM, 32'hFFFF_FFFF); apb_w(A_IRQ_RAW, 32'hFFFF_FFFF);
      t_eff_en = 15'h00F1;
      set_default_op; o_alg = ALG_ED448; o_op = OP_VRFY; o_hybpol = 2'd1; run_op;
      set_default_op; o_alg = ALG_P256; o_op = OP_VRFY; o_hash = 3'd2; run_op;
      set_default_op; o_alg = ALG_P384; o_op = OP_VRFY; o_hash = 3'd2; run_op;   // bit 6 is outside 0xF1
      // The clear command does not remove the lock
      cmd_clr;
      apb_expect("dsig_cmd.clr does not remove the lock", A_LOCK, 32'h0000_0100);
      // Only a reset removes the lock
      do_reset(6);
      apb_expect("the lock is removed by a reset", A_LOCK, 32'h0);
      apb_expect("alg_act is 0 after the reset", A_ALG_ACT, 32'h0);
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T13: operation counters and the log lock (TEST-029, REQ-SEC-006, DEC-033)
  // ----------------------------------------------------------------------------------------
  task t_log;
    reg [31:0] d, ops0, fail0;
    begin
      test_begin("TEST-029 REQ-SEC-006 DEC-033 operation counters and log lock");
      enable_ip(15'h7FFF);
      k_vas_ok = 1'b1;
      apb_r(A_CNT_OPS, ops0); apb_r(A_CNT_FAIL, fail0);
      k_eng_sigok = 1'b1;
      set_default_op; o_alg = ALG_ED448; o_op = OP_VRFY; run_op;
      k_eng_sigok = 1'b0;
      set_default_op; o_alg = ALG_ED448; o_op = OP_VRFY; run_op;
      k_eng_sigok = 1'b1;
      apb_expect("two accepted starts counted", A_CNT_OPS, ops0 + 2);
      apb_expect("one invalid verification counted", A_CNT_FAIL, fail0 + 1);
      // Log lock: the counters stop
      apb_w(A_LOG_LOCK, 32'h1);
      cyc(10);
      apb_expect("dsig_log_lock.locked is 1 and req reads 0", A_LOG_LOCK, 32'h0000_0100);
      apb_r(A_CNT_OPS, ops0); apb_r(A_CNT_FAIL, fail0);
      k_eng_sigok = 1'b0;
      set_default_op; o_alg = ALG_ED448; o_op = OP_VRFY;
      o_clr_before = 1'b1; clr_all; clear_flags; program_op; cmd_start; wait_op_done;
      k_eng_sigok = 1'b1;
      set_default_op; o_alg = ALG_ED448; o_op = OP_RSVD; clear_flags; program_op; cmd_start; wait_op_done;
      apb_expect("cnt_ops frozen after the log lock", A_CNT_OPS, ops0);
      apb_expect("cnt_fail frozen after the log lock", A_CNT_FAIL, fail0);
      cmd_clr;
      apb_expect("dsig_cmd.clr does not unlock the log", A_LOG_LOCK, 32'h0000_0100);
      do_reset(6);
      apb_expect("the log lock is removed by a reset", A_LOG_LOCK, 32'h0);
      apb_expect("cnt_ops is 0 after a reset", A_CNT_OPS, 32'h0);
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T14: interrupt and alarm outputs (TEST-018, REQ-IF-003, section 6.4)
  // ----------------------------------------------------------------------------------------
  task t_irq;
    reg [31:0] d;
    begin
      test_begin("TEST-018 REQ-IF-003 interrupt mask, injection, clear, alarm");
      enable_ip(15'h7FFF);
      clear_flags;
      apb_w(A_IRQ_EN, 32'h0);
      set_default_op; o_alg = ALG_ED448; o_op = OP_VRFY; o_hybpol = 2'd1;
      o_clr_before = 1'b0; run_op;
      ck(irq === 1'b0, "o_irq low while the done event is masked (section 6.4)");
      apb_expect("irq_raw.done set although masked", A_IRQ_RAW, 32'h1);
      apb_expect("irq_sts is 0 while masked", A_IRQ_STS, 32'h0);
      apb_w(A_IRQ_EN, 32'h1);
      cyc(10);
      ck(irq === 1'b1, "o_irq high when the done event is enabled");
      apb_expect("irq_sts.done set", A_IRQ_STS, 32'h1);
      apb_w(A_IRQ_RAW, 32'h1);
      cyc(10);
      ck(irq === 1'b0, "o_irq low after software clears the done event");
      apb_expect("irq_raw cleared", A_IRQ_RAW, 32'h0);
      // Error event
      apb_w(A_IRQ_EN, 32'h2);
      set_default_op; o_alg = ALG_ED448; o_op = OP_RSVD; o_clr_before = 1'b1; run_op;
      cyc(10);
      ck(irq === 1'b1, "o_irq high for an enabled error event");
      apb_expect("irq_sts.err set", A_IRQ_STS, 32'h2);
      apb_w(A_ERR, 32'hFFFF_FFFF); apb_w(A_IRQ_RAW, 32'hFFFF_FFFF);
      cyc(10);
      ck(irq === 1'b0, "o_irq low after the error event is cleared");
      // Injection raises the raw event on the rising edge of the bit
      apb_w(A_IRQ_EN, 32'h7);
      apb_w(A_IRQ_INJ, 32'h4);
      cyc(10);
      apb_expect("injection raises irq_raw.sec", A_IRQ_RAW, 32'h4);
      ck(irq === 1'b1, "o_irq high for an injected enabled event");
      apb_w(A_IRQ_RAW, 32'h4);
      cyc(10);
      apb_expect("the injection bit held at 1 does not raise the event again", A_IRQ_RAW, 32'h0);
      ck(irq === 1'b0, "o_irq low after clearing a held injection");
      apb_w(A_IRQ_INJ, 32'h0);
      cyc(6);
      apb_w(A_IRQ_INJ, 32'h4);
      cyc(10);
      apb_expect("a new rising edge raises the event again", A_IRQ_RAW, 32'h4);
      apb_w(A_IRQ_INJ, 32'h0);
      apb_w(A_IRQ_RAW, 32'h4);
      apb_w(A_IRQ_EN, 32'h0);
      cyc(6);
      // The alarm output does not depend on the interrupt mask
      apb_w(A_IRQ_INJ, 32'h0);
      k_vas_ok = 1'b0;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; run_op_noerr_check;
      k_vas_ok = 1'b1;
      test_end;
    end
  endtask

  task run_op_noerr_check;
    begin
      run_raw;
      ck(alarm === 1'b1, "o_alarm high with every interrupt masked (section 6.4)");
      apb_w(A_ERR, 32'hFFFF_FFFF); apb_w(A_ALARM, 32'hFFFF_FFFF); apb_w(A_IRQ_RAW, 32'hFFFF_FFFF);
      cyc(8);
      ck(alarm === 1'b0, "o_alarm low after the alarm is cleared");
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T15: buffer (TEST-033, TEST-017, TEST-020, REQ-IF-002, REQ-IF-005, section 10.5, DEC-027)
  // ----------------------------------------------------------------------------------------
  reg [7:0] rmem [0:1023];      // reference content of the buffer (written by the checks below)
  integer   rseed;

  function automatic integer rnd(input integer n);
    begin
      rnd = $unsigned($random(rseed)) % n;
    end
  endfunction

  task rm_write64;
    input [6:0]  wa;
    input [63:0] d;
    input [7:0]  s;
    integer l;
    begin
      for (l = 0; l < 8; l = l + 1)
        if (s[l]) rmem[wa * 8 + l] = d[8 * l +: 8];
    end
  endtask

  task bus_w_ref;                 // bus write that also updates the reference
    input [6:0]  wa;
    input [63:0] d;
    input [7:0]  s;
    begin
      bus_write(wa, d, s);
      ck(bus_rej_seen === 1'b0, "an idle bus write is accepted");
      rm_write64(wa, d, s);
    end
  endtask

  task bus_r_ref;                 // bus read that is compared with the reference
    input [6:0] ra;
    reg [63:0] bd, ex;
    reg        rj;
    integer    l;
    begin
      bus_read(ra, bd, rj);
      for (l = 0; l < 8; l = l + 1) ex[8 * l +: 8] = rmem[ra * 8 + l];
      ck(rj === 1'b0, "an idle bus read is not rejected");
      ck(bd === ex, "bus read equals the reference content");
    end
  endtask

  task win_w_ref;                 // window write at a byte address (aligned to 4)
    input [16:0] ba;
    input [31:0] d;
    integer l;
    reg [31:0] e;
    begin
      apb_w(A_WIN_ADDR, {15'h0, ba});
      apb_w(A_WIN_WR, d);
      cyc(10);
      if (ba + 3 < P_BUF_BYTES) begin
        for (l = 0; l < 4; l = l + 1) rmem[ba + l] = d[8 * l +: 8];
        apb_r(A_ERR, e);
        ck32("no error for a window write inside the buffer", e, 32'h0);
        apb_expect("the window address advances by 4 after the write (10.5)", A_WIN_ADDR, ba + 4);
      end else begin
        apb_r(A_ERR, e);
        ck32("window write outside the buffer sets bufovf (section 10.5)", e, 32'h1 << E_BUFOVF);
        apb_w(A_ERR, 32'hFFFF_FFFF);
      end
    end
  endtask

  task win_r_ref;                 // window read at a byte address (aligned to 4)
    input [16:0] ba;
    reg [31:0] d, e, ex;
    integer l;
    begin
      apb_w(A_WIN_ADDR, {15'h0, ba});
      apb_r(A_WIN_RD, d);
      cyc(10);
      if (ba + 3 < P_BUF_BYTES) begin
        for (l = 0; l < 4; l = l + 1) ex[8 * l +: 8] = rmem[ba + l];
        ck32("window read equals the reference content", d, ex);
        apb_expect("the window address advances by 4 after the read (10.5)", A_WIN_ADDR, ba + 4);
        apb_r(A_ERR, e);
        ck32("no error for a window read inside the buffer", e, 32'h0);
      end else begin
        ck32("window read outside the buffer returns 0 (section 10.5)", d, 32'h0);
        apb_r(A_ERR, e);
        ck32("window read outside the buffer sets bufovf (section 10.5)", e, 32'h1 << E_BUFOVF);
        apb_w(A_ERR, 32'hFFFF_FFFF);
      end
    end
  endtask

  task t_buffer;
    integer i, j, k;
    reg [63:0] bd;
    reg        rj;
    reg [31:0] d;
    begin
      test_begin("TEST-033 TEST-017 TEST-020 REQ-IF-002 REQ-IF-005 buffer, numbered example 1");
      enable_ip(15'h7FFF);
      clear_flags;
      for (i = 0; i < 1024; i = i + 1) rmem[i] = 8'h00;
      // Fill the buffer with a known pattern
      for (i = 0; i < 128; i = i + 1) bus_w_ref(i[6:0], {8{i[7:0]}} ^ 64'hA5C3_96F0_1E2D_4B78, 8'hFF);
      for (i = 0; i < 128; i = i + 1) bus_r_ref(i[6:0]);
      // Numbered example 1 of section 10.5 (PARA_AXI_DW 64, PARA_BUF_BYTES 1024)
      bus_w_ref(7'd3, 64'hDEAD_BEEF_CAFE_F00D, 8'hFF);          // pre-load word 3
      bus_w_ref(7'd3, 64'h1122_3344_5566_7788, 8'h0F);          // (1) strobe 0x0F
      bus_r_ref(7'd3);
      bus_read(7'd3, bd, rj);
      ck(bd === 64'hDEAD_BEEF_5566_7788, "example 1 step 1: bytes 24 to 27 are 88 77 66 55, bytes 28 to 31 unchanged");
      apb_w(A_WIN_ADDR, 32'h1C);
      apb_w(A_WIN_WR, 32'hAABB_CCDD);                           // (2) window write at 0x1C
      cyc(10);
      for (i = 0; i < 4; i = i + 1) rmem[28 + i] = (32'hAABB_CCDD >> (8 * i));
      bus_read(7'd3, bd, rj);
      ck(bd === 64'hAABB_CCDD_5566_7788, "example 1 step 2: bytes 28 to 31 are DD CC BB AA");
      apb_expect("example 1: window address is 0x20 after the write", A_WIN_ADDR, 32'h20);
      apb_w(A_WIN_ADDR, 32'h18);                                // (3) read at 0x18
      apb_r(A_WIN_RD, d);
      ck32("example 1 step 3: window read at 0x18 returns 0x55667788", d, 32'h5566_7788);
      apb_expect("example 1 step 3: window address becomes 0x1C", A_WIN_ADDR, 32'h1C);
      apb_r(A_WIN_RD, d);                                       // (4) next read
      ck32("example 1 step 4: window read at 0x1C returns 0xAABBCCDD", d, 32'hAABB_CCDD);
      apb_expect("example 1 step 4: window address becomes 0x20", A_WIN_ADDR, 32'h20);
      apb_w(A_WIN_ADDR, 32'h400);                               // (5) outside the buffer
      apb_r(A_WIN_RD, d);
      ck32("example 1 step 5: window read at 0x400 returns 0", d, 32'h0);
      apb_expect("example 1 step 5: bufovf set", A_ERR, 32'h1 << E_BUFOVF);
      apb_w(A_ERR, 32'hFFFF_FFFF);
      // Byte lanes: every strobe value of a bus write
      for (i = 0; i < 256; i = i + 1) begin
        bus_w_ref(7'd9, {8{i[7:0]}} ^ 64'h0123_4567_89AB_CDEF, i[7:0]);
        bus_r_ref(7'd9);
      end
      // Window writes with auto-increment: words land in order
      apb_w(A_WIN_ADDR, 32'd256);
      for (i = 0; i < 8; i = i + 1) begin
        apb_w(A_WIN_WR, 32'hC000_0000 + i);
        for (j = 0; j < 4; j = j + 1) rmem[256 + 4 * i + j] = (32'hC000_0000 + i) >> (8 * j);
      end
      cyc(10);
      apb_expect("window address after 8 writes", A_WIN_ADDR, 32'd288);
      for (i = 0; i < 4; i = i + 1) bus_r_ref(7'd32 + i[6:0]);
      apb_w(A_WIN_ADDR, 32'd256);
      for (i = 0; i < 8; i = i + 1) begin
        apb_r(A_WIN_RD, d);
        ck32("sequential window read equals the written word", d, 32'hC000_0000 + i);
      end
      // Window access at and above the end
      win_w_ref(17'd1020, 32'h1357_9BDF);
      win_r_ref(17'd1020);
      win_w_ref(17'd1024, 32'hFFFF_FFFF);
      win_r_ref(17'd1024);
      win_w_ref(17'h1FFFC, 32'hFFFF_FFFF);
      win_r_ref(17'h1FFFC);
      bus_r_ref(7'd127);
      // A window read at the same time as a bus read of another word returns the data of the window address
      for (i = 0; i < 24; i = i + 1) begin
        j = 4 * (8 + i);
        win_w_ref(j, 32'hC0DE_0000 + i);
        apb_w(A_WIN_ADDR, j);
        cyc(6);
        fork
          bus_r_ref(7'd100 + i[6:0]);
          begin
            cyc(i % 7);
            apb_r(A_WIN_RD, d);
          end
        join
        ck32("window read concurrent with a bus read returns the window data (section 10.5)", d, 32'hC0DE_0000 + i);
      end
      // Random mix of bus writes, window writes, bus reads and window reads
      for (i = 0; i < 300; i = i + 1) begin
        k = rnd(4);
        if (k == 0) bus_w_ref(rnd(128), {$random(rseed), $random(rseed)}, rnd(256));
        else if (k == 1) win_w_ref(4 * rnd(256), $random(rseed));
        else if (k == 2) bus_r_ref(rnd(128));
        else win_r_ref(4 * rnd(256));
      end
      // The engine port writes while busy (checked in the flows); here: read what the engine sees
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T16: clearing of the secret state (TEST-028, REQ-SEC-005, OP-006, WF-012)
  // ----------------------------------------------------------------------------------------
  task t_clearing;
    integer i;
    begin
      test_begin("TEST-028 REQ-SEC-005 OP-006 clearing of the secret state");
      enable_ip(15'h7FFF);
      k_vas_ok = 1'b1;
      // After a result
      write_keys; cyc(4);
      ck(w_keys_nz === 1'b1, "key words loaded");
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; o_clr_before = 1'b1;
      clr_all; clear_flags; program_op; write_keys; cmd_start; wait_op_done;
      ck(w_keys_nz === 1'b0, "key words are zero after a result (REQ-SEC-005)");
      // After an error of the check
      write_keys; cyc(4);
      set_default_op; o_alg = ALG_ED25519; o_op = OP_RSVD; clear_flags; program_op; cmd_start; wait_op_done;
      ck(w_keys_nz === 1'b0, "key words are zero after a failing check (REQ-SEC-005)");
      // After an engine error
      write_keys; cyc(4);
      k_eng_err = 1'b1; k_eng_err_flags = 12'h1 << E_BADKEY;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; clear_flags; program_op; write_keys; cmd_start; wait_op_done;
      ck(w_keys_nz === 1'b0, "key words are zero after an engine error (REQ-SEC-005)");
      k_eng_err = 1'b0; k_eng_err_flags = 12'h0;
      // The clear command clears the key words that software wrote (S18)
      write_keys; cyc(4);
      ck(w_keys_nz === 1'b1, "key words loaded again");
      cmd_clr;
      cyc(110);
      ck(w_keys_nz === 1'b0, "dsig_cmd.clr clears the key words within 100 clocks (S18, OP-006)");
      // A slow zeroization model (50 clocks) still ends in IDLE
      k_zero_lat = 50;
      write_keys; cyc(4);
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; clr_all; clear_flags; program_op; write_keys; cmd_start; wait_op_done;
      ck(w_keys_nz === 1'b0, "key words zero with a slow zeroization (50 clocks)");
      k_zero_lat = 8;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T17: corrupted state encoding (DEC-035, section 10.1 encoding recovery)
  // ----------------------------------------------------------------------------------------
  // Fault injection: write an unused code into the state register through bit forces. The value stays
  // after the release until the next clock edge of the control block loads the next state.
  task corrupt_state;
    input [3:0] v;
    begin
      force dut.u_ctl.reg_fsm_ctl_current_state[3] = v[3];
      force dut.u_ctl.reg_fsm_ctl_current_state[2] = v[2];
      force dut.u_ctl.reg_fsm_ctl_current_state[1] = v[1];
      force dut.u_ctl.reg_fsm_ctl_current_state[0] = v[0];
      #1;
      release dut.u_ctl.reg_fsm_ctl_current_state[3];
      release dut.u_ctl.reg_fsm_ctl_current_state[2];
      release dut.u_ctl.reg_fsm_ctl_current_state[1];
      release dut.u_ctl.reg_fsm_ctl_current_state[0];
    end
  endtask

  task t_recovery;
    reg [31:0] d;
    integer k;
    begin
      test_begin("TEST-023 DEC-035 recovery of an unused state encoding");
      enable_ip(15'h7FFF);
      clear_flags;
      k_eng_lat = 200;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN; clr_all; program_op;
      cmd_start;
      cyc(30);
      // Force an unused encoding (4-bit binary state register, nine states used) for a moment;
      // only FSM-02 stays active in the window (the corruption breaks the premise of the others)
      core_mask = ~64'h4;
      @(posedge clk_core); #1;
      corrupt_state(4'd13);
      cyc(60);
      apb_r(A_ALARM, d);
      ck32("alarm.fault set by an unused state encoding (DEC-035)", d, 32'h1);
      ck(alarm === 1'b1, "o_alarm high after a state corruption");
      apb_r(A_STS, d);
      ck(d[0] === 1'b0, "the IP is idle again after the recovery (DEC-035)");
      ck(dut.u_ctl.reg_fsm_ctl_current_state == 4'd0, "state is ENUM_ST_IDLE after the recovery");
      apb_w(A_ALARM, 32'hFFFF_FFFF); apb_w(A_ERR, 32'hFFFF_FFFF); apb_w(A_IRQ_RAW, 32'hFFFF_FFFF);
      k_eng_lat = 12;
      // Every unused encoding 9 to 15
      for (k = 9; k <= 15; k = k + 1) begin
        @(posedge clk_core); #1;
        corrupt_state(k[3:0]);
        cyc(40);
        apb_r(A_ALARM, d);
        ck32("alarm.fault for every unused encoding", d, 32'h1);
        apb_w(A_ALARM, 32'hFFFF_FFFF);
        ck(dut.u_ctl.reg_fsm_ctl_current_state == 4'd0, "idle after recovery of encoding");
      end
      core_mask = 64'h0;
      set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; run_op;
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // T18: constrained-random operations checked by the reference model of the specification
  // ----------------------------------------------------------------------------------------
  integer rc_ee [0:11];
  integer rc_pass;

  task t_random;
    integer n, a, m, j;
    reg [14:0] mask;
    begin
      test_begin("TEST-023 integrated flows: constrained-random operations against the reference model");
      for (j = 0; j < 12; j = j + 1) rc_ee[j] = 0;
      rc_pass = 0;
      k_vas_ok = 1'b1;
      for (n = 0; n < n_rand; n = n + 1) begin
        set_default_op;
        o_alg = rnd(16);
        m = rnd(100);
        o_op = (m < 35) ? OP_SIGN : (m < 75) ? OP_VRFY : (m < 95) ? OP_KGEN : OP_RSVD;
        if (o_op == OP_VRFY && (o_alg == 1 || o_alg == 2))
          o_alg = ALG_P256;
        m = rnd(100);
        o_form = (m < 70) ? FORM_PURE : (m < 95) ? FORM_PREHASH : 2'd2 + rnd(2);
        o_hash = (rnd(20) == 0) ? (3'd6 + rnd(2)) : rnd(6);
        o_nonce = (rnd(12) == 0) ? (2'd2 + rnd(2)) : rnd(2);
        o_hedged = rnd(2);
        o_hybpol = (o_alg == 0 || o_alg == 9) ? ((rnd(25) == 0) ? 2'd3 : rnd(3)) : rnd(3);
        o_slh = (rnd(3) == 0) ? rnd(16) : 4'd0;
        o_lmst = (rnd(3) == 0) ? rnd(32) : 5'd0;
        o_lmots = (rnd(4) == 0) ? rnd(16) : 4'd0;
        o_hsslvl = (rnd(3) == 0) ? rnd(16) : (1 + rnd(8));
        o_xm = (rnd(3) == 0) ? rnd(64) : 6'd0;
        if (o_alg == ALG_ED25519PH || o_alg == ALG_ED448PH) o_hash = 3'd2;   // digest of the ph algorithms: SHA-512, 64 bytes (TBD-015)
        else if (o_alg <= ALG_ED448 || o_alg >= ALG_SLHDSA) o_form = (o_form == FORM_PREHASH) ? FORM_PURE : o_form;
        if (o_form == FORM_PREHASH) o_len = (rnd(5) == 0) ? rnd(70) : f_dig_len(o_hash);
        else o_len = (rnd(12) == 0) ? (900 + rnd(200)) : (1 + rnd(200));
        o_offm = (rnd(10) == 0) ? rnd(1100) : rnd(300);
        o_clr_before = (rnd(3) != 0);
        k_eng_sigok = rnd(2);
        k_eng_lat = rnd(30);
        k_eng_words = 1 + rnd(4);
        mask = 15'h7FFF;
        for (a = 0; a < 15; a = a + 1) if (rnd(12) == 0) mask[a] = 1'b0;
        t_ctrl_en = (rnd(20) != 0);
        t_eff_en = mask;
        apb_w(A_CTRL, {31'h0, t_ctrl_en});
        prog_alg_en(mask);
        cyc(10);
        run_op;
        if (exp_ee >= 0) rc_ee[exp_ee] = rc_ee[exp_ee] + 1; else rc_pass = rc_pass + 1;
      end
      $display("RANDOM: %0d operations, passing=%0d algdis=%0d opuns=%0d badlen=%0d bufovf=%0d",
               n_rand, rc_pass, rc_ee[E_ALGDIS], rc_ee[E_OPUNS], rc_ee[E_BADLEN], rc_ee[E_BUFOVF]);
      test_end;
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Waveform scenarios of the specification plan (section 10.3, WF-003 to WF-016). Each one runs
  // alone (+WAVE=<n> +DUMP=<file>), builds the stimulus of the figure from the specification and
  // dumps the signals of the figure to a VCD file; vcd_compare.py compares it with the figure.
  // ----------------------------------------------------------------------------------------
  reg [8*200-1:0] dump_path;
  task wf_dump_start;
    begin
      $dumpfile(dump_path);
      $dumpvars(0, u_wf);
    end
  endtask

  task wf_scenario;
    input integer id;
    reg [31:0] d;
    reg        er;
    begin
      case (id)
        3: begin   // WF-003 verification, start to done
          enable_ip(15'h7FFF); apb_w(A_IRQ_EN, 32'h1);
          set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; o_hybpol = 2'd1;
          clr_all; clear_flags; program_op; k_eng_lat = 6; k_eng_sigok = 1'b1;
          wf_dump_start; cmd_start; wait_op_done; cyc(20);
        end
        5: begin   // WF-005 start for an algorithm whose enable bit is 0
          enable_ip(15'h0000); apb_w(A_IRQ_EN, 32'h2);
          set_default_op; clr_all; clear_flags; program_op;
          wf_dump_start; cmd_start; wait_op_done; cyc(20);
        end
        7: begin   // WF-007 abort during a running operation
          enable_ip(15'h7FFF); k_eng_lat = 300;
          set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN;
          clr_all; clear_flags; program_op; write_keys;
          wf_dump_start; cmd_start; cyc(60); cmd_abort; cyc(60);
        end
        8: begin   // WF-008 window write and read
          enable_ip(15'h7FFF);
          wf_dump_start;
          apb_w(A_WIN_ADDR, 32'h0); apb_w(A_WIN_WR, 32'h1111_1111); apb_w(A_WIN_WR, 32'h2222_2222);
          apb_w(A_WIN_ADDR, 32'h0); apb_r(A_WIN_RD, d); apb_r(A_WIN_RD, d); cyc(10);
        end
        9: begin   // WF-009 verify-after-sign mismatch
          enable_ip(15'h7FFF); k_vas_ok = 1'b0; k_eng_lat = 6;
          set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN;
          clr_all; clear_flags; program_op;
          wf_dump_start; cmd_start; wait_op_done; cyc(20);
        end
        11: begin  // WF-011 hybrid verification: Ed25519 then ML-DSA-65, policy both valid
          enable_ip(15'h7FFF); k_eng_lat = 4;
          clr_all; clear_flags;
          set_default_op; o_alg = ALG_ED25519; o_op = OP_VRFY; o_hybpol = 2'd0; o_clr_before = 1'b0;
          program_op;
          wait_tail = 3;
          wf_dump_start; cmd_start; wait_op_done;
          prog_op(ALG_MLDSA65, OP_VRFY, FORM_PURE, 1'b0, 2'd0, 3'd0, 2'd0); cmd_start; wait_op_done; cyc(20);
        end
        12: begin  // WF-012 secret clearing after completion
          enable_ip(15'h7FFF); k_eng_lat = 6;
          set_default_op; o_alg = ALG_ED25519; o_op = OP_SIGN;
          clr_all; clear_flags; program_op; write_keys;
          wf_dump_start; cmd_start; wait_op_done; cyc(20);
        end
        15: begin  // WF-015 APB write then read
          enable_ip(15'h7FFF);
          wf_dump_start;
          cyc_apb(4);
          apb_xfer(1'b1, A_ALG_EN, 32'h1, 4'hF, 3'b000, 0, d, er);
          apb_xfer(1'b0, A_STS, 32'h0, 4'h0, 3'b000, 0, d, er);
          cyc_apb(6);
        end
        16: begin  // WF-016 non-secure access with protection on
          enable_ip(15'h0000);
          wf_dump_start;
          cyc_apb(4);
          apb_xfer(1'b1, A_ALG_EN, 32'h1, 4'hF, 3'b010, 0, d, er);
          cyc_apb(8);
        end
        default: $display("no scenario %0d", id);
      endcase
      cyc(30);
    end
  endtask

  // ----------------------------------------------------------------------------------------
  // Main sequence: focused tests of each function first, then the integrated flows (R-048)
  // ----------------------------------------------------------------------------------------
  integer a_fail, a_never, a_f2, a_n2, a_f3, a_n3, sel, wave_id;

  initial begin : main
    seed = 1; n_rand = 200;
    if (!$value$plusargs("SEED=%d", seed)) seed = 1;
    if (!$value$plusargs("N=%d", n_rand)) n_rand = 200;
    if (!$value$plusargs("TAPB=%f", t_apb)) t_apb = 17.0;
    rseed = seed;
`ifdef VLSIT_SYNTHESIS
    $display("SIM-BRANCH: synthesis");
`else
    begin : seed_print
      integer ms;
      if (!$value$plusargs("AFIFO_MSYNC_SEED=%d", ms)) ms = 1;
      $display("SIM-BRANCH: metastable seed=%0d", ms);
    end
`endif
    $display("CONFIG: CSR_ASYNC=%0d random seed=%0d n=%0d t_apb=%0f", P_CSR_ASYNC, seed, n_rand, t_apb);
    protect_en = 1'b1; slverr_en = 1'b1;
    t_ctrl_en = 1'b0; t_eff_en = 15'h0; chk_verbose = 1'b0; exp_ee = -1;
    set_default_op;
    do_reset(6);

    if ($value$plusargs("WAVE=%d", wave_id)) begin
      if (!$value$plusargs("DUMP=%s", dump_path)) dump_path = "scenario.vcd";
      wf_scenario(wave_id);
      $display("WAVE scenario %0d done", wave_id);
      $finish;
    end
    if (!$value$plusargs("ONLY=%d", sel)) sel = 0;
    // Focused group
    if (sel == 0 || sel == 1)  t_reset_regs;
    if (sel == 0 || sel == 2)  t_rw_regs;
    if (sel == 0 || sel == 3)  t_apb_proto;
    if (sel == 0 || sel == 4)  t_enable_start;
    if (sel == 0 || sel == 5)  t_errors;
    if (sel == 0 || sel == 6)  t_buffer;
    if (sel == 0 || sel == 7)  t_clearing;
    if (sel == 0 || sel == 8)  t_vas;
    if (sel == 0 || sel == 9)  t_timeouts;
    if (sel == 0 || sel == 10) t_eng_err;
    if (sel == 0 || sel == 11) t_abort;
    if (sel == 0 || sel == 12) t_busy;
    if (sel == 0 || sel == 13) t_irq;
    if (sel == 0 || sel == 14) t_lock;
    if (sel == 0 || sel == 15) t_log;
    if (sel == 0 || sel == 16) t_recovery;
    // Integrated flows
    if (sel == 0 || sel == 17) t_flows;
    if (sel == 0 || sel == 18) t_hybrid;
    if (sel == 0 || sel == 19) t_random;

    cyc(20);
    u_apb_chk.as_report("APB4", a_fail, a_never);
    u_core_chk.as_report("CORE", a_f2, a_n2);
    a_f3 = 0; a_n3 = 0;
    for (cs_i = 0; cs_i < cs_n; cs_i = cs_i + 1)
      $display("CHECKSTAT exec=%0d fail=%0d msg=%0s", cs_exec[cs_i], cs_bad[cs_i], cs_msg[cs_i]);
    $display("SUMMARY: tests=%0d failed tests=%0d checks=%0d failed checks=%0d", n_test, n_test_fail,
             n_chk, n_fail);
    $display("assertion failures: %0d, assertions never exercised: %0d", a_fail + a_f2 + a_f3,
             a_never + a_n2 + a_n3);
    if (n_fail == 0 && a_fail + a_f2 == 0 && a_never + a_n2 == 0) $display("RESULT: PASS");
    else $display("RESULT: FAIL");
    $finish;
  end
