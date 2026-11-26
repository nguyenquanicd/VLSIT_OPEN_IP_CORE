//      // verilator_coverage annotation
        /*
         * Project      : VLSIT Common RTL library
         * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
         * AI Flow      : VLSIT RTL Generator AI Automation Flow
         * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
         * Date         : 2026-11-24
         * Description  : Control block of the digital signature IP. It takes the command, operation,
         *                parameter-set, length and offset fields of the CSR, checks them, runs the nine-
         *                state FSM of section 10.1 (IDLE, CHECK, KEY, RNG, RUN, VAS, RESULT, CLEAR,
         *                ERROR), starts the engine of the algorithm, the key block, the random block and
         *                the verify-after-sign check through handshakes, and reports status, error flags,
         *                alarm flags, interrupt events, hybrid results and the log counters to the CSR.
         *                The three-process FSM follows the Mealy example of the RTL generator. The enable
         *                bits of the algorithms follow the CSR until the lock request freezes them.
         *                Interfaces of the key block, the random block and the engines are handshakes:
         *                a start pulse, a done pulse, and error or timeout pulses. i_zero_done is a level
         *                that is high while the secret registers are zero.
         *                Defensive choice (assumption ASM-015): an engine error pulse with all error flags
         *                zero is reported as the invalid-point-or-format error.
         *                Deviation from HIE-02 (SHOULD): this module is a function block, not a design top.
         *                Decisions: DEC-002, DEC-010, DEC-016, DEC-030 to DEC-035.
         *                Requirements: REQ-FUNC-009, REQ-FUNC-012, REQ-REG-001, REQ-REG-002, REQ-ERR-001,
         *                REQ-SEC-005, REQ-SEC-006.
         */
        `timescale 1ns/1ps
        
        module m_vlsit_dsig_ctl #(
          // Parameter Description: mask of the algorithms that are built, bit n for algorithm index n.
          // Parameter values: bits 14:0 used; default is 0x7FFF (all algorithms).
          // Parameter unit: none
          parameter logic [31:0] PARA_CAP_ALG = 32'h7FFF,
          // Parameter Description: mask of the algorithms with key generation built.
          // Parameter values: bits 14:0 used and a subset of PARA_CAP_ALG; default is 0x0FFF.
          // Parameter unit: none
          parameter logic [31:0] PARA_CAP_KGEN = 32'h0FFF,
          // Parameter Description: mask of the algorithms with signing built.
          // Parameter values: bits 14:0 used and a subset of PARA_CAP_ALG; default is 0x0FFF.
          // Parameter unit: none
          parameter logic [31:0] PARA_CAP_SIGN = 32'h0FFF,
          // Parameter Description: mask of the algorithms with verification built.
          // Parameter values: bits 14:0 used and a subset of PARA_CAP_ALG; default is 0x7FFF.
          // Parameter unit: none
          parameter logic [31:0] PARA_CAP_VRFY = 32'h7FFF,
          // Parameter Description: pure message form built (message in the buffer).
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_PURE = 1,
          // Parameter Description: prehash message form built (digest in the buffer).
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_PREHASH = 1,
          // Parameter Description: lock of the algorithm enable bits built.
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_LOCK = 1,
          // Parameter Description: operation counters and their lock built.
          // Parameter values: 0 or 1; default is 1.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_LOG = 1,
          // Parameter Description: verify-after-sign built; a signature is checked before it is released.
          // Parameter values: 0 or 1; default is 0.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_VAS = 0,
          // Parameter Description: hybrid verification policy built (latched Ed25519 and ML-DSA results).
          // Parameter values: 0 or 1; default is 0.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_HYBRID = 0,
          // Parameter Description: masking of the elliptic-curve engine built (needs random bytes).
          // Parameter values: 0 or 1; default is 0.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_DPA_EC = 0,
          // Parameter Description: masking of the lattice engine built (needs random bytes).
          // Parameter values: 0 or 1; default is 0.
          // Parameter unit: none
          parameter logic [31:0] PARA_EN_DPA_PQ = 0,
          // Parameter Description: ECDSA nonce mode of the build.
          // Parameter values: 0 random, 1 deterministic, 2 selected by dsig_op.nonce; default is 0.
          // Parameter unit: none
          parameter logic [31:0] PARA_ECDSA_NONCE = 0,
          // Parameter Description: size of the message buffer, used to check the message region.
          // Parameter values: 64 to 65536; default is 1024.
          // Parameter unit: byte
          parameter logic [31:0] PARA_BUF_BYTES = 1024,
          // Parameter Description: mask of the SLH-DSA parameter sets that are built.
          // Parameter values: bits 11:0 used; default is 0x001.
          // Parameter unit: none
          parameter logic [31:0] PARA_SLHDSA_SETS = 32'h001,
          // Parameter Description: mask of the LMS tree types that are built.
          // Parameter values: bits 19:0 used; default is 0x00001.
          // Parameter unit: none
          parameter logic [31:0] PARA_LMS_SETS = 32'h00001,
          // Parameter Description: mask of the LM-OTS types that are built.
          // Parameter values: bits 15:0 used; default is 0x0001.
          // Parameter unit: none
          parameter logic [31:0] PARA_LMOTS_SETS = 32'h0001,
          // Parameter Description: mask of the XMSS and XMSS^MT sets 0 to 31 that are built.
          // Parameter values: 32-bit mask; default is 0x00000001.
          // Parameter unit: none
          parameter logic [31:0] PARA_XMSS_SETS_LO = 32'h00000001,
          // Parameter Description: mask of the XMSS and XMSS^MT sets 32 to 43 that are built.
          // Parameter values: bits 11:0 used; default is 0x000.
          // Parameter unit: none
          parameter logic [31:0] PARA_XMSS_SETS_HI = 32'h000,
          // Algorithm indices of dsig_op.alg (section 10.2 and the CSR workbook)
          localparam logic [31:0] LPARA_ALG_ED25519 = 0,
          localparam logic [31:0] LPARA_ALG_ED25519CTX = 1,
          localparam logic [31:0] LPARA_ALG_ED25519PH = 2,
          localparam logic [31:0] LPARA_ALG_ED448PH = 4,
          localparam logic [31:0] LPARA_ALG_P256 = 5,
          localparam logic [31:0] LPARA_ALG_P384 = 6,
          localparam logic [31:0] LPARA_ALG_P521 = 7,
          localparam logic [31:0] LPARA_ALG_K256 = 8,
          localparam logic [31:0] LPARA_ALG_MLDSA44 = 9,
          localparam logic [31:0] LPARA_ALG_MLDSA87 = 11,
          localparam logic [31:0] LPARA_ALG_SLHDSA = 12,
          localparam logic [31:0] LPARA_ALG_LMS = 13,
          localparam logic [31:0] LPARA_ALG_XMSS = 14,
          localparam logic [31:0] LPARA_ALG_RSVD = 15,
          // Operation codes of dsig_op.op
          localparam logic [31:0] LPARA_OP_KGEN = 0,
          localparam logic [31:0] LPARA_OP_SIGN = 1,
          localparam logic [31:0] LPARA_OP_VRFY = 2,
          // Error flag masks of dsig_err, one bit for each flag (section 12)
          localparam logic [31:0] LPARA_ERRF_ALGDIS = 1,
          localparam logic [31:0] LPARA_ERRF_OPUNS = 2,
          localparam logic [31:0] LPARA_ERRF_BADLEN = 4,
          localparam logic [31:0] LPARA_ERRF_BADPT = 16,
          localparam logic [31:0] LPARA_ERRF_BUFOVF = 32,
          localparam logic [31:0] LPARA_ERRF_ENTTMO = 128,
          localparam logic [31:0] LPARA_ERRF_KEYTMO = 256,
          localparam logic [31:0] LPARA_ERRF_VASMIS = 512,
          localparam logic [31:0] LPARA_ERRF_LOCKV = 1024,
          localparam logic [31:0] LPARA_ERRF_BUSYCMD = 2048,
          // Alarm flag masks of dsig_alarm and event masks of dsig_irq_raw
          localparam logic [31:0] LPARA_ALM_FAULT = 1,
          localparam logic [31:0] LPARA_ALM_LOCKV = 2,
          localparam logic [31:0] LPARA_ALM_RNGFAIL = 4,
          // Digest lengths of the hash selections and group limits
          localparam logic [31:0] LPARA_DIG_32 = 32,
          localparam logic [31:0] LPARA_DIG_48 = 48,
          localparam logic [31:0] LPARA_DIG_64 = 64,
          localparam logic [31:0] LPARA_HSS_MAX = 8,
          // Codes of dsig_op.nonce, dsig_op.hash and dsig_op.hybpol, and the ECDSA nonce mode of the build
          localparam logic [31:0] LPARA_NONCE_CSR = 2,
          localparam logic [31:0] LPARA_HASH_SHA256 = 0,
          localparam logic [31:0] LPARA_HASH_SHA384 = 1,
          localparam logic [31:0] LPARA_HASH_SHA512 = 2,
          localparam logic [31:0] LPARA_HASH_SHA3_256 = 3,
          localparam logic [31:0] LPARA_HASH_SHA3_384 = 4,
          localparam logic [31:0] LPARA_HASH_SHA3_512 = 5,
          localparam logic [31:0] LPARA_POL_BOTH = 0,
          localparam logic [31:0] LPARA_POL_ED = 1,
          localparam logic [31:0] LPARA_POL_ML = 2,
          localparam logic [31:0] LPARA_POL_RSVD = 3,
          localparam logic [31:0] LPARA_FORM_PURE = 0,
          localparam logic [31:0] LPARA_FORM_PREHASH = 1,
          localparam logic [31:0] LPARA_SLH_N = 12,
          localparam logic [31:0] LPARA_LMS_N = 20,
          localparam logic [31:0] LPARA_XMSS_N = 44
        ) (
          // Clock and reset
          input  wire         i_clk_core,
          input  wire         i_rst_n_core,
        
          // CSR control inputs: IP enable, algorithm enables and lock
          input  wire         i_ctrl_en,
          input  wire  [14:0] i_alg_en,
          input  wire         i_lock_req,
          output logic        o_lock_req_clr,
        
          // CSR control inputs: operation, parameter sets, lengths and offsets
          input  wire  [3:0]  i_op_alg,
          input  wire  [1:0]  i_op_op,
          input  wire  [1:0]  i_op_form,
          input  wire         i_op_hedged,
          input  wire  [1:0]  i_op_nonce,
          input  wire  [2:0]  i_op_hash,
          input  wire  [1:0]  i_op_hybpol,
          input  wire  [3:0]  i_set_slh,
          input  wire  [4:0]  i_set_lmstype,
          input  wire  [3:0]  i_set_lmots,
          input  wire  [3:0]  i_set_hsslvl,
          input  wire  [5:0]  i_set_xmss,
          input  wire  [31:0] i_len_msg,
          input  wire  [7:0]  i_len_ctx,
          input  wire  [16:0] i_off_msg,
          input  wire  [16:0] i_off_sig,
          input  wire  [16:0] i_off_pk,
          input  wire  [16:0] i_off_res,
        
          // CSR commands and their hardware clear
          input  wire         i_cmd_start,
          input  wire         i_cmd_abort,
          input  wire         i_cmd_clr,
          output logic        o_cmd_start_clr,
          output logic        o_cmd_abort_clr,
          output logic        o_cmd_clr_clr,
        
          // CSR status outputs
          output logic        o_sts_busy,
          output logic        o_sts_resvld,
          output logic        o_sts_sigok,
          output logic        o_sts_edok,
          output logic        o_sts_mlok,
          output logic [14:0] o_alg_act,
          output logic        o_locked,
        
          // CSR error and alarm flags, set pulses
          output logic [11:0] o_err_set,
          output logic [2:0]  o_alarm_set,
          input  wire  [2:0]  i_alarm_flags,
        
          // CSR interrupt registers
          input  wire  [2:0]  i_irq_raw,
          input  wire  [2:0]  i_irq_en,
          input  wire  [2:0]  i_irq_inj,
          output logic [2:0]  o_irq_raw_set,
          output logic        o_flags_clr,
          output logic [2:0]  o_irq_sts,
        
          // CSR log counters and lock
          input  wire         i_log_lock_req,
          output logic        o_log_lock_clr,
          output logic        o_log_locked,
          output logic [31:0] o_cnt_ops,
          output logic [31:0] o_cnt_fail,
        
          // Interrupt and alarm outputs
          output logic        o_irq,
          output logic        o_alarm,
        
          // Engine start and the snapshot of the operation that the engines use
          output logic [2:0]  o_eng_start,
          output logic [3:0]  o_run_alg,
          output logic [1:0]  o_run_op,
          output logic [1:0]  o_run_form,
          output logic        o_run_hedged,
          output logic [1:0]  o_run_nonce,
          output logic [2:0]  o_run_hash,
          output logic [3:0]  o_run_slh,
          output logic [4:0]  o_run_lmstype,
          output logic [3:0]  o_run_lmots,
          output logic [3:0]  o_run_hsslvl,
          output logic [5:0]  o_run_xmss,
          output logic [31:0] o_run_len_msg,
          output logic [7:0]  o_run_len_ctx,
          output logic [16:0] o_run_off_msg,
          output logic [16:0] o_run_off_sig,
          output logic [16:0] o_run_off_pk,
          output logic [16:0] o_run_off_res,
        
          // Engine feedback
          input  wire         i_eng_done,
          input  wire         i_eng_err,
          input  wire  [11:0] i_eng_err_flags,
          input  wire         i_eng_sigok,
        
          // Key block, random block and verify-after-sign handshakes
          output logic        o_key_start,
          input  wire         i_key_done,
          input  wire         i_key_tmo,
          output logic        o_rng_start,
          input  wire         i_rng_done,
          input  wire         i_rng_tmo,
          output logic        o_vas_start,
          input  wire         i_vas_done,
          input  wire         i_vas_ok,
        
          // Secret clearing
          output logic        o_zero,
          input  wire         i_zero_done,
        
          // Buffer
          output logic        o_busy,
          input  wire         i_buf_err_ovf,
          input  wire         i_buf_err_busy
        );
        
          // FSM states of the control block (section 10.1). The 4-bit encoding is binary; the unused
          // encodings 9 to 15 recover to ENUM_ST_CLEAR and raise the fault alarm (DEC-035).
          typedef enum logic [3:0] {
            ENUM_ST_IDLE   = 4'd0,
            ENUM_ST_CHECK  = 4'd1,
            ENUM_ST_KEY    = 4'd2,
            ENUM_ST_RNG    = 4'd3,
            ENUM_ST_RUN    = 4'd4,
            ENUM_ST_VAS    = 4'd5,
            ENUM_ST_RESULT = 4'd6,
            ENUM_ST_CLEAR  = 4'd7,
            ENUM_ST_ERR  = 4'd8
          } ctl_state_type_def;
        
          // Internal signal declarations
          ctl_state_type_def reg_fsm_ctl_current_state;
          ctl_state_type_def w_fsm_ctl_nxt_state;
          logic              w_state_bad;
          logic [31:0]       w_alg32;
          logic [31:0]       w_op32;
        
          logic              w_start_ok;
          logic [14:0]       w_alg_cap;
          logic              w_lock_viol;
          logic              w_alg_valid;
          logic              w_ec_group;
          logic [15:0]       w_alg_act16;
          logic [4:0]        w_alg_idx5;
          logic [4:0]        w_slh_idx5;
          logic [4:0]        w_lmots_idx5;
          logic              w_is_ecdsa;
          logic              w_is_mldsa;
          logic              w_is_vrfy;
          logic              w_is_sign;
          logic              w_f_algdis;
          logic              w_f_opuns;
          logic              w_f_badlen;
          logic              w_f_bufovf;
          logic              w_set_bad;
          logic              w_chk_ok;
          logic [11:0]       w_chk_flag;
          logic [31:0]       w_dig_len;
          logic [31:0]       w_min_len;
          logic [33:0]       w_msg_end;
          logic              w_uses_ctx;
          logic              w_det;
          logic              w_needs_key;
          logic              w_needs_rng;
          logic              w_vas_en;
          logic [11:0]       w_err_nxt;
          logic              w_sigok_nxt;
          logic              w_ed_nxt;
          logic              w_ml_nxt;
          logic [2:0]        w_inj_rise;
          logic              w_done_ev;
          logic              w_err_ev;
          logic              w_sec_ev;
          logic [11:0]       w_err_pulse;
        
          logic [14:0]       reg_alg_act;
          logic [14:0]       reg_alg_prev;
          logic              reg_locked;
          logic              reg_log_locked;
          logic [3:0]        reg_run_alg;
          logic [1:0]        reg_run_op;
          logic [1:0]        reg_run_form;
          logic              reg_run_hedged;
          logic [1:0]        reg_run_nonce;
          logic [2:0]        reg_run_hash;
          logic [1:0]        reg_run_hybpol;
          logic [3:0]        reg_run_slh;
          logic [4:0]        reg_run_lmstype;
          logic [3:0]        reg_run_lmots;
          logic [3:0]        reg_run_hsslvl;
          logic [5:0]        reg_run_xmss;
          logic [31:0]       reg_run_len_msg;
          logic [7:0]        reg_run_len_ctx;
          logic [16:0]       reg_run_off_msg;
          logic [16:0]       reg_run_off_sig;
          logic [16:0]       reg_run_off_pk;
          logic [16:0]       reg_run_off_res;
          logic [11:0]       reg_err_flags;
          logic              reg_raw_ok;
          logic              reg_resvld;
          logic              reg_sigok;
          logic              reg_edok;
          logic              reg_mlok;
          logic [2:0]        reg_inj_prev;
          logic [31:0]       reg_cnt_ops;
          logic [31:0]       reg_cnt_fail;
        
          // Start acceptance: a start command is taken in IDLE; a disabled IP fails the first check of
          // ENUM_ST_CHECK like any other failing check (section 10.1, designer decision of 2026-11-24).
          assign w_start_ok = (reg_fsm_ctl_current_state == ENUM_ST_IDLE) & i_cmd_start;
        
          // Zero-extended copies of the snapshot codes, so that comparisons with the 32-bit LPARA
          // constants have equal widths.
          assign w_alg32 = {28'd0, reg_run_alg};
          assign w_alg_idx5   = {1'b0, reg_run_alg};
          assign w_slh_idx5   = {1'b0, reg_run_slh};
          assign w_lmots_idx5 = {1'b0, reg_run_lmots};
          assign w_op32  = {30'd0, reg_run_op};
        
          // Algorithm classes of the snapshot: group of the engine, ECDSA, ML-DSA, operation.
          assign w_ec_group = (w_alg32 <= LPARA_ALG_K256);
          assign w_alg_act16 = {1'b0, reg_alg_act};
          assign w_is_ecdsa = (w_alg32 >= LPARA_ALG_P256) & (w_alg32 <= LPARA_ALG_K256);
          assign w_is_mldsa = (w_alg32 >= LPARA_ALG_MLDSA44) & (w_alg32 <= LPARA_ALG_MLDSA87);
          assign w_is_vrfy  = (w_op32 == LPARA_OP_VRFY);
          assign w_is_sign  = (w_op32 == LPARA_OP_SIGN);
          assign w_alg_valid = (w_alg32 != LPARA_ALG_RSVD);
        
          // Digest length selected by dsig_op.hash and the minimum length of the curve (DEC-032).
 69687478   always_comb begin : p_com_dig_len
 69687478     w_dig_len = 32'd0;
 69687478     case ({29'd0, reg_run_hash})
 62690287       LPARA_HASH_SHA256:   w_dig_len = LPARA_DIG_32;
~7165129       LPARA_HASH_SHA384:   w_dig_len = LPARA_DIG_48;
~11743404       LPARA_HASH_SHA512:   w_dig_len = LPARA_DIG_64;
~10115106       LPARA_HASH_SHA3_256: w_dig_len = LPARA_DIG_32;
~1008531       LPARA_HASH_SHA3_384: w_dig_len = LPARA_DIG_48;
~2843648       LPARA_HASH_SHA3_512: w_dig_len = LPARA_DIG_64;
%000000       default:             w_dig_len = 32'd0;
            endcase
          end
        
          // Minimum digest length of the ECDSA curve: P-256 and secp256k1 32 bytes, P-384 48, P-521 64.
 69687478   always_comb begin : p_com_min_len
 69687478     w_min_len = LPARA_DIG_32;
 69687478     case (w_alg32)
~4762561       LPARA_ALG_P384:        w_min_len = LPARA_DIG_48;
~4451533       LPARA_ALG_P521:        w_min_len = LPARA_DIG_64;
 69687478       default:               w_min_len = LPARA_DIG_32;
            endcase
          end
        
          // Parameter-set validity of the hash-based algorithms: the code must be below the number of
          // sets and its bit must be set in the mask of the build.
 69687478   always_comb begin : p_com_set_bad
 69687478     w_set_bad = 1'b0;
 69687478     case (w_alg32)
~21498760       LPARA_ALG_SLHDSA: begin
~21498760         w_set_bad = ({28'd0, reg_run_slh} >= LPARA_SLH_N) | ~PARA_SLHDSA_SETS[w_slh_idx5];
              end
~6414856       LPARA_ALG_LMS: begin
~6414856         w_set_bad = ({27'd0, reg_run_lmstype} >= LPARA_LMS_N) | ~PARA_LMS_SETS[reg_run_lmstype] |
                            ~PARA_LMOTS_SETS[w_lmots_idx5];
              end
~13321189       LPARA_ALG_XMSS: begin
%000000         if ({26'd0, reg_run_xmss} >= LPARA_XMSS_N)
%000000           w_set_bad = 1'b1;
~13321189         else if (reg_run_xmss[5] == 1'b0)
~13321189           w_set_bad = ~PARA_XMSS_SETS_LO[reg_run_xmss[4:0]];
                else
%000000           w_set_bad = ~PARA_XMSS_SETS_HI[reg_run_xmss[4:0]];
              end
 62690287       default: w_set_bad = 1'b0;
            endcase
          end
        
          // Check 1, IP disabled or algorithm disabled (section 12): the IP enable is 0, or the algorithm
          // is not built or its effective enable bit is 0. A reserved algorithm code is reported as
          // unsupported operation instead (unless the IP is disabled).
          assign w_f_algdis = ~i_ctrl_en |
                              (w_alg_valid & ~(PARA_CAP_ALG[w_alg_idx5] & w_alg_act16[reg_run_alg]));
        
          // Check 2, unsupported operation: reserved codes, operations and forms that are not built,
          // and parameter sets that are not built.
 69687478   always_comb begin : p_com_f_opuns
 69687478     w_f_opuns = ~w_alg_valid | w_set_bad;
 69687478     case (w_op32)
 3181313       LPARA_OP_KGEN: w_f_opuns = w_f_opuns | ~PARA_CAP_KGEN[w_alg_idx5];
 44901366       LPARA_OP_SIGN: w_f_opuns = w_f_opuns | ~PARA_CAP_SIGN[w_alg_idx5];
~49473860       LPARA_OP_VRFY: w_f_opuns = w_f_opuns | ~PARA_CAP_VRFY[w_alg_idx5];
%000000       default:       w_f_opuns = 1'b1;
            endcase
 69687478     case ({30'd0, reg_run_form})
 62690287       LPARA_FORM_PURE:    w_f_opuns = w_f_opuns | ~PARA_EN_PURE[0];
~36456179       LPARA_FORM_PREHASH: w_f_opuns = w_f_opuns | ~PARA_EN_PREHASH[0];
%000000       default: w_f_opuns = 1'b1;
            endcase
~69687478     if (w_is_ecdsa & w_is_sign & (PARA_ECDSA_NONCE == LPARA_NONCE_CSR) & reg_run_nonce[1])
~000519       w_f_opuns = 1'b1;
~69687478     if ((w_is_ecdsa | ({30'd0, reg_run_form} == LPARA_FORM_PREHASH)) & (reg_run_hash[2:1] == 2'b11))
%000000       w_f_opuns = 1'b1;
~69687478     if (PARA_EN_HYBRID[0] & w_is_vrfy & ((w_alg32 == LPARA_ALG_ED25519) | w_is_mldsa) &
                ({30'd0, reg_run_hybpol} == LPARA_POL_RSVD))
%000000       w_f_opuns = 1'b1;
            // The deterministic ECDSA nonce (RFC 6979) is built for the SHA-2 hashes only.
~69687478     if (w_is_ecdsa & w_is_sign & w_det & (reg_run_hash > 3'd2))
~000157       w_f_opuns = 1'b1;
            // Ed25519ph and Ed448ph take the digest PH(M) as the message: only the prehash form exists.
~69687478     if (((w_alg32 == LPARA_ALG_ED25519PH) | (w_alg32 == LPARA_ALG_ED448PH)) & ({30'd0, reg_run_form} != LPARA_FORM_PREHASH))
~000175       w_f_opuns = 1'b1;
          end
        
          // Check 3, bad length: hash shorter than the curve needs, HSS level count outside 1 to 8, and
          // a prehash digest whose length does not match the hash.
 69687478   always_comb begin : p_com_f_badlen
 69687478     w_f_badlen = 1'b0;
~69687478     if (w_is_ecdsa & (w_is_sign | w_is_vrfy) & (w_dig_len < w_min_len))
~002316       w_f_badlen = 1'b1;
~69687478     if ((w_alg32 == LPARA_ALG_LMS) & ((reg_run_hsslvl == 4'd0) | ({28'd0, reg_run_hsslvl} > LPARA_HSS_MAX)))
%000000       w_f_badlen = 1'b1;
            // Key generation has no message: only signing and verification check the digest length.
~62690287     if (({30'd0, reg_run_form} == LPARA_FORM_PREHASH) & (w_is_sign | w_is_vrfy)) begin
~36456179       if ((w_is_ecdsa | w_is_mldsa | (w_alg32 == LPARA_ALG_SLHDSA)) & (reg_run_len_msg != w_dig_len))
%000000         w_f_badlen = 1'b1;
~36456179       if (((w_alg32 == LPARA_ALG_ED25519PH) | (w_alg32 == LPARA_ALG_ED448PH)) &
                  (reg_run_len_msg != LPARA_DIG_64))
~000175         w_f_badlen = 1'b1;
            end
          end
        
          // Check 4, buffer overflow: the message or digest region must lie inside the buffer.
          // The context of the algorithms that use one lies right after the message (ASM-020).
          assign w_uses_ctx = ((w_alg32 >= LPARA_ALG_ED25519CTX) & (w_alg32 <= LPARA_ALG_ED448PH)) | w_is_mldsa | (w_alg32 == LPARA_ALG_SLHDSA);
          assign w_msg_end  = {2'b00, reg_run_len_msg} + {17'd0, reg_run_off_msg} + (w_uses_ctx ? {26'd0, reg_run_len_ctx} : 34'd0);
          assign w_f_bufovf = (w_msg_end > {2'b00, PARA_BUF_BYTES});
        
          // Check result: the first failing check gives its flag; the order is the order of section 10.1.
 69687478   always_comb begin : p_com_chk
 69687478     w_chk_ok   = 1'b0;
 69687478     w_chk_flag = 12'd0;
 69687478     casez ({w_f_algdis, w_f_opuns, w_f_badlen, w_f_bufovf})
 004294       4'b1???: w_chk_flag = LPARA_ERRF_ALGDIS[11:0];
~000851       4'b01??: w_chk_flag = LPARA_ERRF_OPUNS[11:0];
~002316       4'b001?: w_chk_flag = LPARA_ERRF_BADLEN[11:0];
%000000       4'b0001: w_chk_flag = LPARA_ERRF_BUFOVF[11:0];
 69683184       default: w_chk_ok = 1'b1;
            endcase
          end
        
          // Needs of the operation (DEC-031): the key for signing and key generation; random bytes for
          // a random ECDSA nonce, hedged ML-DSA signing and masked engines.
          assign w_needs_key = (w_op32 == LPARA_OP_KGEN) | w_is_sign;
          assign w_needs_rng = (w_is_ecdsa & w_is_sign & ((PARA_ECDSA_NONCE == 32'd0) |
                                ((PARA_ECDSA_NONCE == LPARA_NONCE_CSR) & ~reg_run_nonce[0]))) |
                               (w_is_mldsa & w_is_sign & reg_run_hedged) |
                               (PARA_EN_DPA_EC[0] & w_ec_group) | (PARA_EN_DPA_PQ[0] & w_is_mldsa);
          // Deterministic ECDSA nonce: PARA_ECDSA_NONCE 1, or 2 with dsig_op.nonce bit 0.
          assign w_det = (PARA_ECDSA_NONCE == 32'd1) | ((PARA_ECDSA_NONCE == LPARA_NONCE_CSR) & reg_run_nonce[0]);
          // Verify-after-sign runs only after a signing operation, and only when it is built.
          assign w_vas_en    = PARA_EN_VAS[0] & w_is_sign;
        
          // Error flags of the transition into ENUM_ST_ERR; the engine flags are forwarded, with the
          // invalid-point flag when the engine gives none (ASM-015).
 69687478   always_comb begin : p_com_err_nxt
 69687478     w_err_nxt = 12'd0;
 69687478     case (reg_fsm_ctl_current_state)
 000070       ENUM_ST_CHECK: w_err_nxt = w_chk_flag;
 001367       ENUM_ST_KEY:   w_err_nxt = LPARA_ERRF_KEYTMO[11:0];
~010301       ENUM_ST_RNG:   w_err_nxt = LPARA_ERRF_ENTTMO[11:0];
~10442060       ENUM_ST_VAS:   w_err_nxt = LPARA_ERRF_VASMIS[11:0];
~65769562       ENUM_ST_RUN:   w_err_nxt = (i_eng_err_flags == 12'd0) ? LPARA_ERRF_BADPT[11:0] : i_eng_err_flags;
 866695       default:       w_err_nxt = 12'd0;
            endcase
          end
        
          // Part 1, sequential: the current state of the control FSM.
 69687475   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_ctl
 69687457     if (!i_rst_n_core)
 000018       reg_fsm_ctl_current_state <= ENUM_ST_IDLE;
            else
 69687457       reg_fsm_ctl_current_state <= w_fsm_ctl_nxt_state;
          end
        
          // Part 2, combinational: next state. An abort command has priority in KEY, RNG, RUN and VAS. A
          // clear command in ENUM_ST_IDLE enters ENUM_ST_CLEAR so that the secret state is cleared (10.1).
          // ENUM_ST_CHECK, ENUM_ST_RESULT and ENUM_ST_ERR last one cycle. An unused encoding goes to
          // ENUM_ST_CLEAR.
 69687478   always_comb begin : p_com_fsm_nxt
 69687478     w_fsm_ctl_nxt_state = reg_fsm_ctl_current_state;
 69687478     w_state_bad         = 1'b0;
 69687478     case (reg_fsm_ctl_current_state)
 089347       ENUM_ST_IDLE: begin
 089347         casez ({w_start_ok, i_cmd_clr})
 000070           2'b1?:   w_fsm_ctl_nxt_state = ENUM_ST_CHECK;
 000070           2'b01:   w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
 089253           default: w_fsm_ctl_nxt_state = ENUM_ST_IDLE;
                endcase
              end
 000070       ENUM_ST_CHECK: begin
 000070         casez ({w_chk_ok, w_needs_key, w_needs_rng})
~000008           3'b0??:  w_fsm_ctl_nxt_state = ENUM_ST_ERR;
 000028           3'b11?:  w_fsm_ctl_nxt_state = ENUM_ST_KEY;
~000017           3'b101:  w_fsm_ctl_nxt_state = ENUM_ST_RNG;
~000042           default: w_fsm_ctl_nxt_state = ENUM_ST_RUN;
                endcase
              end
 001367       ENUM_ST_KEY: begin
 001367         casez ({i_cmd_abort, i_key_tmo, i_key_done, w_needs_rng})
~000001           4'b1???: w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
~000001           4'b01??: w_fsm_ctl_nxt_state = ENUM_ST_ERR;
~000018           4'b0011: w_fsm_ctl_nxt_state = ENUM_ST_RNG;
~000027           4'b0010: w_fsm_ctl_nxt_state = ENUM_ST_RUN;
 001364           default: w_fsm_ctl_nxt_state = ENUM_ST_KEY;
                endcase
              end
~010301       ENUM_ST_RNG: begin
~010301         casez ({i_cmd_abort, i_rng_tmo, i_rng_done})
%000000           3'b1??:  w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
~000001           3'b01?:  w_fsm_ctl_nxt_state = ENUM_ST_ERR;
~000025           3'b001:  w_fsm_ctl_nxt_state = ENUM_ST_RUN;
~010283           default: w_fsm_ctl_nxt_state = ENUM_ST_RNG;
                endcase
              end
~65769562       ENUM_ST_RUN: begin
~65769562         casez ({i_cmd_abort, i_eng_err, i_eng_done, w_vas_en})
%000000           4'b1???: w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
%000000           4'b01??: w_fsm_ctl_nxt_state = ENUM_ST_ERR;
~000019           4'b0011: w_fsm_ctl_nxt_state = ENUM_ST_VAS;
~000051           4'b0010: w_fsm_ctl_nxt_state = ENUM_ST_RESULT;
~65769515           default: w_fsm_ctl_nxt_state = ENUM_ST_RUN;
                endcase
              end
~10442060       ENUM_ST_VAS: begin
~10442060         casez ({i_cmd_abort, i_vas_done, i_vas_ok})
%000000           3'b1??:  w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
~000019           3'b011:  w_fsm_ctl_nxt_state = ENUM_ST_RESULT;
%000000           3'b010:  w_fsm_ctl_nxt_state = ENUM_ST_ERR;
~10442044           default: w_fsm_ctl_nxt_state = ENUM_ST_VAS;
                endcase
              end
~000070       ENUM_ST_RESULT: w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
~000008       ENUM_ST_ERR:  w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
 819275       ENUM_ST_CLEAR: begin
 819225         if (i_zero_done)
 000140           w_fsm_ctl_nxt_state = ENUM_ST_IDLE;
              end
%000000       default: begin
%000000         w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;
%000000         w_state_bad         = 1'b1;
              end
            endcase
          end
        
          // Part 3, combinational: handshake outputs. Each start pulse is the entry into its state; the
          // clearing request and the busy level follow the current state.
 69687478   always_comb begin : p_com_fsm_out
 69687478     o_key_start = 1'b0;
 69687478     o_rng_start = 1'b0;
 69687478     o_vas_start = 1'b0;
 69687478     o_eng_start = 3'd0;
 69687478     o_zero      = 1'b0;
 69687478     o_busy      = 1'b1;
 69687478     case (reg_fsm_ctl_current_state)
 089347       ENUM_ST_IDLE: o_busy = 1'b0;
 819275       ENUM_ST_CLEAR: o_zero = 1'b1;
 69008166       default: o_busy = 1'b1;
            endcase
 69687473     if ((w_fsm_ctl_nxt_state == ENUM_ST_KEY) & (reg_fsm_ctl_current_state != ENUM_ST_KEY))
 000028       o_key_start = 1'b1;
~69687478     if ((w_fsm_ctl_nxt_state == ENUM_ST_RNG) & (reg_fsm_ctl_current_state != ENUM_ST_RNG))
~000025       o_rng_start = 1'b1;
~69687473     if ((w_fsm_ctl_nxt_state == ENUM_ST_VAS) & (reg_fsm_ctl_current_state != ENUM_ST_VAS))
~000019       o_vas_start = 1'b1;
~69687431     if ((w_fsm_ctl_nxt_state == ENUM_ST_RUN) & (reg_fsm_ctl_current_state != ENUM_ST_RUN)) begin
~000070       o_eng_start[0] = w_ec_group;
~000070       o_eng_start[1] = w_is_mldsa;
~000070       o_eng_start[2] = (w_alg32 >= LPARA_ALG_SLHDSA) & (w_alg32 <= LPARA_ALG_XMSS);
            end
          end
        
          // Command consumption: each command bit is cleared by hardware in the cycle in which the
          // control block sees it, so the FSM sees a one-cycle pulse.
          assign o_cmd_start_clr = i_cmd_start;
          assign o_cmd_abort_clr = i_cmd_abort;
          assign o_cmd_clr_clr   = i_cmd_clr;
          assign o_lock_req_clr  = i_lock_req;
          assign o_log_lock_clr  = i_log_lock_req;
        
          // Algorithm enable follow-up and lock: the effective enables follow the CSR bits, masked by the
          // built algorithms, until the lock request is seen; then they are held (DEC-034). The lock
          // violation is a change of the CSR bits after the lock that differs from the held value.
          assign w_alg_cap   = i_alg_en & PARA_CAP_ALG[14:0];
          assign w_lock_viol = reg_locked & (w_alg_cap != reg_alg_prev) & (w_alg_cap != reg_alg_act);
        
          // Held enables and lock: the effective enables follow the CSR until the lock request sets the
          // lock flag; the previous value feeds the violation detector. All state is reset to zero.
 69687475   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_lock
 69687457     if (!i_rst_n_core) begin
 000018       reg_alg_act  <= 15'd0;
 000018       reg_alg_prev <= 15'd0;
 000018       reg_locked   <= 1'b0;
            end
 69687457     else begin
 69687457       reg_alg_prev <= w_alg_cap;
~69687457       if (~reg_locked)
 69687457         reg_alg_act <= w_alg_cap;
~69687457       if (i_lock_req & PARA_EN_LOCK[0])
~000001         reg_locked <= 1'b1;
            end
          end
        
          // Snapshot of the operation: the fields are copied when the start command is accepted, so that
          // a later change of the CSR has no effect on the running operation.
 69687475   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_run
 000018     if (!i_rst_n_core) begin
 000018       reg_run_alg     <= 4'd0;
 000018       reg_run_op      <= 2'd0;
 000018       reg_run_form    <= 2'd0;
 000018       reg_run_hedged  <= 1'b0;
 000018       reg_run_nonce   <= 2'd0;
 000018       reg_run_hash    <= 3'd0;
 000018       reg_run_hybpol  <= 2'd0;
 000018       reg_run_slh     <= 4'd0;
 000018       reg_run_lmstype <= 5'd0;
 000018       reg_run_lmots   <= 4'd0;
 000018       reg_run_hsslvl  <= 4'd0;
 000018       reg_run_xmss    <= 6'd0;
 000018       reg_run_len_msg <= 32'd0;
 000018       reg_run_len_ctx <= 8'd0;
 000018       reg_run_off_msg <= 17'd0;
 000018       reg_run_off_sig <= 17'd0;
 000018       reg_run_off_pk  <= 17'd0;
 000018       reg_run_off_res <= 17'd0;
            end
 69687410     else if (w_start_ok) begin
 000070       reg_run_alg     <= i_op_alg;
 000070       reg_run_op      <= i_op_op;
 000070       reg_run_form    <= i_op_form;
 000070       reg_run_hedged  <= i_op_hedged;
 000070       reg_run_nonce   <= i_op_nonce;
 000070       reg_run_hash    <= i_op_hash;
 000070       reg_run_hybpol  <= i_op_hybpol;
 000070       reg_run_slh     <= i_set_slh;
 000070       reg_run_lmstype <= i_set_lmstype;
 000070       reg_run_lmots   <= i_set_lmots;
 000070       reg_run_hsslvl  <= i_set_hsslvl;
 000070       reg_run_xmss    <= i_set_xmss;
 000070       reg_run_len_msg <= i_len_msg;
 000070       reg_run_len_ctx <= i_len_ctx;
 000070       reg_run_off_msg <= i_off_msg;
 000070       reg_run_off_sig <= i_off_sig;
 000070       reg_run_off_pk  <= i_off_pk;
 000070       reg_run_off_res <= i_off_res;
            end
          end
        
          // Hybrid policy (DEC-030): the result of the Ed25519 or ML-DSA verification that just ended
          // replaces its latched flag; sigok is then the policy of both flags. Other verifications and
          // builds without hybrid return the raw result.
 69683184   assign w_ed_nxt    = (w_alg32 == LPARA_ALG_ED25519) ? reg_raw_ok : reg_edok;
~62689157   assign w_ml_nxt    = w_is_mldsa ? reg_raw_ok : reg_mlok;
        
          // Policy result: the raw verification result, or the policy of the latched flags in a hybrid
          // build for Ed25519 and ML-DSA verifications.
 2324322   always_comb begin : p_com_sigok
 2324322     w_sigok_nxt = reg_raw_ok;
~2324322     if (PARA_EN_HYBRID[0] & ((w_alg32 == LPARA_ALG_ED25519) | w_is_mldsa)) begin
~2324322       case ({30'd0, reg_run_hybpol})
~1503601         LPARA_POL_BOTH: w_sigok_nxt = w_ed_nxt & w_ml_nxt;
~175081         LPARA_POL_ED:   w_sigok_nxt = w_ed_nxt;
~645640         LPARA_POL_ML:   w_sigok_nxt = w_ml_nxt;
%000000         default:        w_sigok_nxt = 1'b0;
              endcase
            end
          end
        
          // Result registers: the raw engine result is latched when the engine is done; the result flags
          // are set in ENUM_ST_RESULT and cleared at a new start or by the clear command in IDLE.
 69687475   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_res
 69687457     if (!i_rst_n_core) begin
 000018       reg_raw_ok    <= 1'b0;
 000018       reg_resvld    <= 1'b0;
 000018       reg_sigok     <= 1'b0;
 000018       reg_edok      <= 1'b0;
 000018       reg_mlok      <= 1'b0;
 000018       reg_err_flags <= 12'd0;
            end
 69687457     else begin
~69687410       if (i_eng_done)
~000070         reg_raw_ok <= i_eng_sigok;
~69687457       if (w_fsm_ctl_nxt_state == ENUM_ST_ERR)
~000008         reg_err_flags <= w_err_nxt;
              else
 69687457         reg_err_flags <= 12'd0;
 69687457       casez ({(reg_fsm_ctl_current_state == ENUM_ST_IDLE) & i_cmd_clr,
 69687457               (reg_fsm_ctl_current_state == ENUM_ST_CHECK) & w_chk_ok,
 69687457               (reg_fsm_ctl_current_state == ENUM_ST_RESULT)})
 000070         3'b1??: begin
 000070           reg_resvld <= 1'b0;
 000070           reg_sigok  <= 1'b0;
 000070           reg_edok   <= 1'b0;
 000070           reg_mlok   <= 1'b0;
                end
 000070         3'b01?: begin
 000070           reg_resvld <= 1'b0;
 000070           reg_sigok  <= 1'b0;
                end
~000070         3'b001: begin
~000070           reg_resvld <= 1'b1;
~000042           if (w_is_vrfy) begin
~000042             reg_sigok <= w_sigok_nxt;
~000042             if (PARA_EN_HYBRID[0]) begin
~000005               reg_edok <= w_ed_nxt;
~000005               reg_mlok <= w_ml_nxt;
                    end
                  end
                end
 69687316         default: begin
 69687316           reg_resvld <= reg_resvld;
                end
              endcase
            end
          end
        
          // Error and alarm pulses of the cycle: the flags of the error state, the immediate errors
          // (start while busy, buffer errors, lock violation).
          assign w_err_pulse = (((reg_fsm_ctl_current_state == ENUM_ST_ERR) ? reg_err_flags : 12'd0) |
                                (((reg_fsm_ctl_current_state != ENUM_ST_IDLE) & i_cmd_start) ? LPARA_ERRF_BUSYCMD[11:0] : 12'd0) |
                                (i_buf_err_busy ? LPARA_ERRF_BUSYCMD[11:0] : 12'd0) |
                                (i_buf_err_ovf ? LPARA_ERRF_BUFOVF[11:0] : 12'd0) |
                                (w_lock_viol ? LPARA_ERRF_LOCKV[11:0] : 12'd0));
          // Error and alarm outputs: set pulses to the sticky flags of the CSR. The alarm flags follow
          // the verify-after-sign mismatch, the entropy timeout, an unused state encoding and the lock.
          assign o_err_set = w_err_pulse;
          assign o_alarm_set = (((reg_fsm_ctl_current_state == ENUM_ST_ERR) & (reg_err_flags != 12'd0) &
                                 ((reg_err_flags & LPARA_ERRF_VASMIS[11:0]) != 12'd0)) ? LPARA_ALM_FAULT[2:0] : 3'd0) |
                               (((reg_fsm_ctl_current_state == ENUM_ST_ERR) &
                                 ((reg_err_flags & LPARA_ERRF_ENTTMO[11:0]) != 12'd0)) ? LPARA_ALM_RNGFAIL[2:0] : 3'd0) |
                               (w_state_bad ? LPARA_ALM_FAULT[2:0] : 3'd0) |
                               (w_lock_viol ? LPARA_ALM_LOCKV[2:0] : 3'd0);
        
          // Interrupt events: done after a result or an error, error for any error flag except the lock
          // violation, security for alarm flags. Injection raises the event on the rising edge.
          assign w_done_ev = (reg_fsm_ctl_current_state == ENUM_ST_RESULT) | (reg_fsm_ctl_current_state == ENUM_ST_ERR);
          assign w_err_ev  = ((w_err_pulse & ~LPARA_ERRF_LOCKV[11:0]) != 12'd0);
          assign w_sec_ev  = (o_alarm_set != 3'd0);
          assign w_inj_rise = i_irq_inj & ~reg_inj_prev;
          assign o_irq_raw_set = {w_sec_ev, w_err_ev, w_done_ev} | w_inj_rise;
          assign o_irq_sts     = i_irq_raw & i_irq_en;
          // Clear command in IDLE: the CSR also clears the error flags and the done and error events.
          assign o_flags_clr   = (reg_fsm_ctl_current_state == ENUM_ST_IDLE) & i_cmd_clr;
          assign o_irq         = (o_irq_sts != 3'd0);
          assign o_alarm       = (i_alarm_flags != 3'd0);
        
          // Injection edge detector and the log counters. The counters saturate at all ones and stop at
          // the log lock; they exist only when the log is built.
 69687475   always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_log
 69687457     if (!i_rst_n_core) begin
 000018       reg_inj_prev   <= 3'd0;
 000018       reg_log_locked <= 1'b0;
 000018       reg_cnt_ops    <= 32'd0;
 000018       reg_cnt_fail   <= 32'd0;
            end
 69687457     else begin
 69687457       reg_inj_prev <= i_irq_inj;
~69687457       if (PARA_EN_LOG[0]) begin
~69687457         if (i_log_lock_req)
%000000           reg_log_locked <= 1'b1;
~69687457         if (~reg_log_locked) begin
 69687410           if ((reg_fsm_ctl_current_state == ENUM_ST_CHECK) & w_chk_ok & (reg_cnt_ops != 32'hFFFFFFFF))
 000070             reg_cnt_ops <= reg_cnt_ops + 32'd1;
 69687429           if (((reg_fsm_ctl_current_state == ENUM_ST_ERR) |
                       ((reg_fsm_ctl_current_state == ENUM_ST_RESULT) & w_is_vrfy & ~reg_raw_ok)) &
                      (reg_cnt_fail != 32'hFFFFFFFF))
 000032             reg_cnt_fail <= reg_cnt_fail + 32'd1;
                end
              end
            end
          end
        
          // Output mapping: status, held enables, counters and the snapshot for the engines.
          assign o_sts_busy    = o_busy;
          assign o_sts_resvld  = reg_resvld;
          assign o_sts_sigok   = reg_sigok;
          assign o_sts_edok    = reg_edok;
          assign o_sts_mlok    = reg_mlok;
          assign o_alg_act     = reg_alg_act;
          assign o_locked      = reg_locked;
          assign o_log_locked  = reg_log_locked;
          assign o_cnt_ops     = reg_cnt_ops;
          assign o_cnt_fail    = reg_cnt_fail;
          assign o_run_alg     = reg_run_alg;
          assign o_run_op      = reg_run_op;
          assign o_run_form    = reg_run_form;
          assign o_run_hedged  = reg_run_hedged;
          assign o_run_nonce   = reg_run_nonce;
          assign o_run_hash    = reg_run_hash;
          assign o_run_slh     = reg_run_slh;
          assign o_run_lmstype = reg_run_lmstype;
          assign o_run_lmots   = reg_run_lmots;
          assign o_run_hsslvl  = reg_run_hsslvl;
          assign o_run_xmss    = reg_run_xmss;
          assign o_run_len_msg = reg_run_len_msg;
          assign o_run_len_ctx = reg_run_len_ctx;
          assign o_run_off_msg = reg_run_off_msg;
          assign o_run_off_sig = reg_run_off_sig;
          assign o_run_off_pk  = reg_run_off_pk;
          assign o_run_off_res = reg_run_off_res;
        
        endmodule
        
