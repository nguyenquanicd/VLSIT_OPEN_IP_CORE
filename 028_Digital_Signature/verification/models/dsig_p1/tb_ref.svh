// tb_ref.svh - reference model of the control block written from the specification only:
//   section 10.1 (order of the checks of ENUM_ST_CHECK) and DEC-038 (priority),
//   section 10.2 (DEC-031 random bytes, DEC-032 curve and hash pairing, DEC-030 hybrid policy),
//   section 12 (error table) and the field descriptions of the workbook (reserved codes, limits).
// Included inside module tb_dsig_p1.

  // Digest length in bytes of the hash select (workbook: dsig_op.hash); 0 for a reserved code
  function automatic integer f_dig_len(input [2:0] h);
    begin
      case (h)
        3'd0, 3'd3: f_dig_len = 32;
        3'd1, 3'd4: f_dig_len = 48;
        3'd2, 3'd5: f_dig_len = 64;
        default:    f_dig_len = 0;
      endcase
    end
  endfunction

  function automatic logic f_is_ecdsa(input [3:0] a);
    begin
      f_is_ecdsa = (a >= ALG_P256) & (a <= ALG_K256);
    end
  endfunction

  function automatic logic f_is_ec(input [3:0] a);
    begin
      f_is_ec = (a <= ALG_K256);
    end
  endfunction

  function automatic logic f_is_mldsa(input [3:0] a);
    begin
      f_is_mldsa = (a >= ALG_MLDSA44) & (a <= ALG_MLDSA87);
    end
  endfunction

  // Minimum digest length in bits for the curve (DEC-032)
  function automatic integer f_min_bits(input [3:0] a);
    begin
      case (a)
        ALG_P256, ALG_K256: f_min_bits = 256;
        ALG_P384:           f_min_bits = 384;
        ALG_P521:           f_min_bits = 512;
        default:            f_min_bits = 0;
      endcase
    end
  endfunction

  // Result of ENUM_ST_CHECK: -1 when every check passes, otherwise the number of the error flag
  // of the first failing check (section 10.1 order, DEC-038 priority).
  function automatic integer f_ref_err(
    input        ctrl_en,
    input [14:0] eff_en,
    input [3:0]  alg,
    input [1:0]  op,
    input [1:0]  form,
    input [1:0]  nonce,
    input [2:0]  hash,
    input [1:0]  hybpol,
    input [3:0]  slh,
    input [4:0]  lmst,
    input [3:0]  lmots,
    input [3:0]  hsslvl,
    input [5:0]  xm,
    input [31:0] len_msg,
    input [16:0] off_msg,
    input [7:0]  len_ctx
  );
    integer r;
    reg     bad;
    reg [63:0] end_pos;
    begin
      r = -1;
      // 1. IP enabled, algorithm built, effective enable bit
      if (!ctrl_en) r = E_ALGDIS;
      else if (alg <= ALG_XMSS) begin
        if (!P_CAP_ALG[alg] || !eff_en[alg]) r = E_ALGDIS;
      end
      // 2. operation, form, hash code, nonce code, parameter set built and not reserved
      if (r < 0) begin
        bad = 1'b0;
        if (alg == ALG_RSVD) bad = 1'b1;
        else begin
          if (op == OP_RSVD) bad = 1'b1;
          else if (op == OP_KGEN && !P_CAP_KGEN[alg]) bad = 1'b1;
          else if (op == OP_SIGN && !P_CAP_SIGN[alg]) bad = 1'b1;
          else if (op == OP_VRFY && !P_CAP_VRFY[alg]) bad = 1'b1;
          if (form > 2'd1) bad = 1'b1;
          if (form == FORM_PURE && !P_EN_PURE[0]) bad = 1'b1;
          if (form == FORM_PREHASH && !P_EN_PREHASH[0]) bad = 1'b1;
          if ((f_is_ecdsa(alg) || form == FORM_PREHASH) && hash > 3'd5) bad = 1'b1;
          if (f_is_ecdsa(alg) && op == OP_SIGN && P_ECDSA_NONCE == 2 && nonce >= 2'd2) bad = 1'b1;
          // ASM-024: the deterministic nonce (RFC 6979) is built for SHA-2 only
          if (f_is_ecdsa(alg) && op == OP_SIGN && hash > 3'd2 &&
              (P_ECDSA_NONCE == 1 || (P_ECDSA_NONCE == 2 && nonce == 2'd1))) bad = 1'b1;
          // ASM-023: Ed25519ph and Ed448ph take the digest PH(M): prehash form only
          if ((alg == ALG_ED25519PH || alg == ALG_ED448PH) && form != FORM_PREHASH) bad = 1'b1;
          if (P_EN_HYBRID[0] && op == OP_VRFY && (alg == ALG_ED25519 || f_is_mldsa(alg)) &&
              hybpol == 2'd3) bad = 1'b1;
          if (alg == ALG_SLHDSA && (slh >= 4'd12 || !P_SLH_SETS[slh])) bad = 1'b1;
          if (alg == ALG_LMS && (lmst >= 5'd20 || !P_LMS_SETS[lmst] || !P_LMOTS_SETS[lmots]))
            bad = 1'b1;
          if (alg == ALG_XMSS) begin
            if (xm >= 6'd44) bad = 1'b1;
            else if (xm < 6'd32) begin if (!P_XMSS_LO[xm]) bad = 1'b1; end
            else begin if (!P_XMSS_HI[xm - 6'd32]) bad = 1'b1; end
          end
        end
        if (bad) r = E_OPUNS;
      end
      // 3. lengths: curve and hash pairing, HSS level count, prehash digest length
      if (r < 0) begin
        bad = 1'b0;
        // DEC-032 and the digest length: signing and verification only (key generation uses no message)
        if (f_is_ecdsa(alg) && op != OP_KGEN && (f_dig_len(hash) * 8 < f_min_bits(alg))) bad = 1'b1;
        if (alg == ALG_LMS && (hsslvl < 4'd1 || hsslvl > 4'd8)) bad = 1'b1;
        if (form == FORM_PREHASH && op != OP_KGEN && (f_is_ecdsa(alg) || f_is_mldsa(alg) || alg == ALG_SLHDSA) &&
            (len_msg != f_dig_len(hash))) bad = 1'b1;
        // ASM-023: the digest of Ed25519ph and Ed448ph has 64 bytes whatever the hash code
        if (form == FORM_PREHASH && op != OP_KGEN && (alg == ALG_ED25519PH || alg == ALG_ED448PH) &&
            len_msg != 32'd64) bad = 1'b1;
        if (bad) r = E_BADLEN;
      end
      // 4. region inside the buffer
      if (r < 0) begin
        // ASM-020: the context of Ed25519ctx/ph, Ed448(ph), ML-DSA and SLH-DSA follows the message
        end_pos = {32'h0, len_msg} + {47'h0, off_msg} +
                  (((alg >= 4'd1 && alg <= 4'd4) || f_is_mldsa(alg) || alg == ALG_SLHDSA) ? {56'h0, len_ctx} : 64'h0);
        if (end_pos > {32'h0, P_BUF_BYTES}) r = E_BUFOVF;
      end
      f_ref_err = r;
    end
  endfunction

  // Random bytes needed by a signing operation (DEC-031)
  function automatic logic f_ref_rng(input [3:0] alg, input [1:0] op, input hedged, input [1:0] nonce);
    reg nrand;
    begin
      f_ref_rng = 1'b0;
      if (op == OP_SIGN) begin
        nrand = (P_ECDSA_NONCE == 0) || (P_ECDSA_NONCE == 2 && nonce == 2'd0);
        if (f_is_ecdsa(alg) && nrand) f_ref_rng = 1'b1;
        if (f_is_mldsa(alg) && hedged) f_ref_rng = 1'b1;
      end
      // DEC-031: a masked engine needs random bytes for every operation of its group
      if (f_is_ec(alg) && P_EN_DPA_EC[0]) f_ref_rng = 1'b1;
      if (f_is_mldsa(alg) && P_EN_DPA_PQ[0]) f_ref_rng = 1'b1;
    end
  endfunction

  // Engine group of an algorithm (section 14.2: elliptic-curve, lattice, hash-based engines)
  function automatic integer f_ref_grp(input [3:0] alg);
    begin
      if (alg <= ALG_K256) f_ref_grp = 0;
      else if (alg <= ALG_MLDSA87) f_ref_grp = 1;
      else f_ref_grp = 2;
    end
  endfunction

  // Hybrid state of the reference model (DEC-030): latched verification results
  reg ref_edok;
  reg ref_mlok;
  initial begin ref_edok = 1'b0; ref_mlok = 1'b0; end

  // sigok after a verification with the given result
  function automatic logic f_ref_sigok(input [3:0] alg, input [1:0] hybpol, input res,
                                       input edok_new, input mlok_new);
    begin
      f_ref_sigok = res;
      if (P_EN_HYBRID[0] && (alg == ALG_ED25519 || f_is_mldsa(alg))) begin
        case (hybpol)
          2'd0:    f_ref_sigok = edok_new & mlok_new;
          2'd1:    f_ref_sigok = edok_new;
          default: f_ref_sigok = mlok_new;
        endcase
      end
    end
  endfunction
