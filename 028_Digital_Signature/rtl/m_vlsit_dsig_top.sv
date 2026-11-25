/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-25
 * Description  : Structural top of the digital signature IP (section 14.2): the generated CSR,
 *                the control block, the buffer with the AXI4 block, the key block, the random
 *                block, the engines (elliptic curve, lattice, hash-based), the hash arbiter and
 *                the stream sequencer. The top holds the ports, the parameters, the interconnect
 *                and the named instances only. The engines share the buffer port (only the
 *                engine of the running operation drives it) and the hash sequencer through the
 *                arbiter (requester 0 elliptic curve, 1 lattice, 2 hash-based). The control
 *                block requests the clearing of every block that can hold a secret with w_zero
 *                and waits until all of them report that they are empty. Deviations from the
 *                specification, recorded in section 14.2.1: the ports of an absent interface
 *                (AXI4, DMA, key port) are always present and inactive (SystemVerilog has no
 *                conditional ports); the buffer word of the engines is 64 bits (PARA_AXI_DW 64
 *                is the only supported value); the data window of the CSR is always built.
 *                Requirements: section 14.2, REQ-PARAM-001.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_top #(
  // Parameter Description: build Ed25519.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ED25519 = 0,
  // Parameter Description: build Ed25519ctx (needs PARA_EN_ED25519 = 1).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ED25519CTX = 0,
  // Parameter Description: build Ed25519ph (needs PARA_EN_ED25519; prehash form).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ED25519PH = 0,
  // Parameter Description: build Ed448.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ED448 = 0,
  // Parameter Description: build Ed448ph (needs PARA_EN_ED448; prehash form).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ED448PH = 0,
  // Parameter Description: build ECDSA P-256.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ECDSA_P256 = 0,
  // Parameter Description: build ECDSA P-384.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ECDSA_P384 = 0,
  // Parameter Description: build ECDSA P-521.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ECDSA_P521 = 0,
  // Parameter Description: build ECDSA secp256k1.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_ECDSA_K256 = 0,
  // Parameter Description: build ML-DSA-44.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_MLDSA44 = 0,
  // Parameter Description: build ML-DSA-65.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_MLDSA65 = 0,
  // Parameter Description: build ML-DSA-87.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_MLDSA87 = 0,
  // Parameter Description: build SLH-DSA verification.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_SLHDSA = 0,
  // Parameter Description: mask of the SLH-DSA parameter sets built (section 10.2.1).
  // Parameter values: 12-bit mask, nonzero when PARA_EN_SLHDSA is 1; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_SLHDSA_SETS = 0,
  // Parameter Description: build LMS/HSS verification.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_LMS = 0,
  // Parameter Description: mask of the LMS tree types built (section 10.2.2).
  // Parameter values: 20-bit mask, nonzero when PARA_EN_LMS is 1; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_LMS_SETS = 0,
  // Parameter Description: mask of the LM-OTS types built (section 10.2.2).
  // Parameter values: 16-bit mask, nonzero when PARA_EN_LMS is 1; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_LMOTS_SETS = 0,
  // Parameter Description: build XMSS and XMSS^MT verification.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_XMSS = 0,
  // Parameter Description: mask of the XMSS sets 0 to 31 built (section 10.2.3).
  // Parameter values: 32-bit mask; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_XMSS_SETS_LO = 0,
  // Parameter Description: mask of the XMSS sets 32 to 43 built (section 10.2.3).
  // Parameter values: 12-bit mask; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_XMSS_SETS_HI = 0,
  // Parameter Description: algorithms with key generation built, indexed by the algorithm code.
  // Parameter values: 15-bit mask, only built algorithms, not bits 12 to 14; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_OP_KGEN = 0,
  // Parameter Description: algorithms with signing built, indexed by the algorithm code.
  // Parameter values: 15-bit mask, only built algorithms, not bits 12 to 14; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_OP_SIGN = 0,
  // Parameter Description: algorithms with verification built, indexed by the algorithm code.
  // Parameter values: 15-bit mask, only built algorithms; default is 0.
  // Parameter unit: mask
  parameter logic [31:0] PARA_OP_VRFY = 0,
  // Parameter Description: pure message form.
  // Parameter values: 0 or 1, at least one of PARA_EN_PURE and PARA_EN_PREHASH is 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_PURE = 1,
  // Parameter Description: prehash message form.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_PREHASH = 1,
  // Parameter Description: size of the message buffer.
  // Parameter values: 64 to 65536, a multiple of 8; default is 1024.
  // Parameter unit: byte
  parameter logic [31:0] PARA_BUF_BYTES = 1024,
  // Parameter Description: build the AXI4 subordinate port.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_AXI = 0,
  // Parameter Description: AXI4 data width and width of the buffer word; only 64 is supported.
  // Parameter values: 64; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 64,
  // Parameter Description: AXI4 address width.
  // Parameter values: 12 to 32; default is 16.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_AW = 16,
  // Parameter Description: AXI4 id width.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_IDW = 4,
  // Parameter Description: build the DMA request and acknowledge lines.
  // Parameter values: 0 or 1, needs PARA_EN_AXI = 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_DMA = 0,
  // Parameter Description: build the CSR data window (capability bit; the logic is always built).
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_WIN = 1,
  // Parameter Description: build the key input port.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_KEYIF = 0,
  // Parameter Description: build the write-only key registers.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_KEYREG = 0,
  // Parameter Description: source of the key when both sources are built.
  // Parameter values: 0 port, 1 registers, 2 registers if loaded else the port; default is 2.
  // Parameter unit: code
  parameter logic [31:0] PARA_KEY_SRC = 2,
  // Parameter Description: random source; only the entropy port (0) is built.
  // Parameter values: 0; default is 0.
  // Parameter unit: code
  parameter logic [31:0] PARA_RNG_SRC = 0,
  // Parameter Description: ECDSA nonce mode (deterministic: RFC 6979 with SHA-2 hashes).
  // Parameter values: 0 random, 1 deterministic, 2 selected by dsig_op.nonce; default is 0.
  // Parameter unit: code
  parameter logic [31:0] PARA_ECDSA_NONCE = 0,
  // Parameter Description: verify-after-sign.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_VAS = 0,
  // Parameter Description: masking of the elliptic-curve operations (not built, keep 0).
  // Parameter values: 0; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_DPA_EC = 0,
  // Parameter Description: masking of lattice and hash-based operations (not built, keep 0).
  // Parameter values: 0; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_DPA_PQ = 0,
  // Parameter Description: hybrid verification.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_HYBRID = 0,
  // Parameter Description: operation counters and log lock.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_LOG = 0,
  // Parameter Description: lock of the enable bits.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_LOCK = 0,
  // Parameter Description: the CSR clock is asynchronous to the core clock.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_CSR_ASYNC = 0,
  // Parameter Description: digit width of the multiplier; only the capability code (bit-serial).
  // Parameter values: 32, 64 or 128; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_MUL_W = 64,
  // Parameter Description: rounds per cycle of the SHA-256 core.
  // Parameter values: divisors of 64; default is 1.
  // Parameter unit: round
  parameter logic [31:0] PARA_S256_UNR = 1,
  // Parameter Description: rounds per cycle of the SHA-512 core.
  // Parameter values: divisors of 80; default is 1.
  // Parameter unit: round
  parameter logic [31:0] PARA_S512_UNR = 1,
  // Parameter Description: rounds per cycle of the Keccak core.
  // Parameter values: divisors of 24; default is 1.
  // Parameter unit: round
  parameter logic [31:0] PARA_KEC_UNR = 1,
  localparam logic [31:0] LPARA_CAP_ALG = {17'd0, PARA_EN_XMSS[0], PARA_EN_LMS[0], PARA_EN_SLHDSA[0],
                                           PARA_EN_MLDSA87[0], PARA_EN_MLDSA65[0], PARA_EN_MLDSA44[0],
                                           PARA_EN_ECDSA_K256[0], PARA_EN_ECDSA_P521[0],
                                           PARA_EN_ECDSA_P384[0], PARA_EN_ECDSA_P256[0],
                                           PARA_EN_ED448PH[0], PARA_EN_ED448[0], PARA_EN_ED25519PH[0],
                                           PARA_EN_ED25519CTX[0], PARA_EN_ED25519[0]},
  localparam logic [31:0] LPARA_CAP_KGEN = PARA_OP_KGEN & LPARA_CAP_ALG & 32'h0000_0FFF,
  localparam logic [31:0] LPARA_CAP_SIGN = PARA_OP_SIGN & LPARA_CAP_ALG & 32'h0000_0FFF,
  localparam logic [31:0] LPARA_CAP_VRFY = PARA_OP_VRFY & LPARA_CAP_ALG,
  localparam logic [31:0] LPARA_HAS_EC = {31'd0, |LPARA_CAP_ALG[8:0]},
  localparam logic [31:0] LPARA_HAS_LAT = {31'd0, |LPARA_CAP_ALG[11:9]},
  localparam logic [31:0] LPARA_HAS_HBS = {31'd0, |LPARA_CAP_ALG[14:12]},
  localparam logic [31:0] LPARA_WA = $clog2(PARA_BUF_BYTES / 8),
  localparam logic [31:0] LPARA_MULW_CODE = (PARA_MUL_W == 32'd128) ? 32'd2 : ((PARA_MUL_W == 32'd64) ? 32'd1 : 32'd0)
) (
  // Clocks and resets
  input  wire                      i_clk_core,
  input  wire                      i_rst_n_core,
  input  wire                      i_clk_apb,
  input  wire                      i_rst_n_apb,

  // APB4 completer port of the CSR
  input  wire                      i_apb_psel,
  input  wire                      i_apb_penable,
  input  wire                      i_apb_pwrite,
  input  wire  [15:0]              i_apb_paddr,
  input  wire  [31:0]              i_apb_pwdata,
  input  wire  [3:0]               i_apb_pstrb,
  input  wire  [2:0]               i_apb_pprot,
  output logic                     o_apb_pready,
  output logic                     o_apb_pslverr,
  output logic [31:0]              o_apb_prdata,
  input  wire                      i_protect_en,
  input  wire                      i_slverr_en,

  // AXI4 subordinate port
  input  wire                      i_axi_awvalid,
  output logic                     o_axi_awready,
  input  wire  [PARA_AXI_IDW-1:0]  i_axi_awid,
  input  wire  [PARA_AXI_AW-1:0]   i_axi_awaddr,
  input  wire  [7:0]               i_axi_awlen,
  input  wire  [2:0]               i_axi_awsize,
  input  wire  [1:0]               i_axi_awburst,
  input  wire                      i_axi_wvalid,
  output logic                     o_axi_wready,
  input  wire  [PARA_AXI_DW-1:0]   i_axi_wdata,
  input  wire  [PARA_AXI_DW/8-1:0] i_axi_wstrb,
  input  wire                      i_axi_wlast,
  output logic                     o_axi_bvalid,
  input  wire                      i_axi_bready,
  output logic [PARA_AXI_IDW-1:0]  o_axi_bid,
  output logic [1:0]               o_axi_bresp,
  input  wire                      i_axi_arvalid,
  output logic                     o_axi_arready,
  input  wire  [PARA_AXI_IDW-1:0]  i_axi_arid,
  input  wire  [PARA_AXI_AW-1:0]   i_axi_araddr,
  input  wire  [7:0]               i_axi_arlen,
  input  wire  [2:0]               i_axi_arsize,
  input  wire  [1:0]               i_axi_arburst,
  output logic                     o_axi_rvalid,
  input  wire                      i_axi_rready,
  output logic [PARA_AXI_IDW-1:0]  o_axi_rid,
  output logic [PARA_AXI_DW-1:0]   o_axi_rdata,
  output logic [1:0]               o_axi_rresp,
  output logic                     o_axi_rlast,

  // DMA handshake
  output logic                     o_dma_in_req,
  input  wire                      i_dma_in_ack,
  output logic                     o_dma_out_req,
  input  wire                      i_dma_out_ack,

  // Key input port
  output logic                     o_key_req,
  output logic [4:0]               o_key_idx,
  input  wire                      i_key_valid,
  input  wire  [31:0]              i_key_data,

  // Entropy input
  output logic                     o_ent_req,
  input  wire                      i_ent_valid,
  input  wire  [31:0]              i_ent_data,

  // Interrupt and alarm
  output logic                     o_irq,
  output logic                     o_alarm
);

  // Elaboration checks of the parameters (REQ-PARAM-001): an illegal combination stops elaboration.
  generate
    if (PARA_AXI_DW != 32'd64) begin : g_chk_axi_dw
      m_vlsit_dsig_top_error_PARA_AXI_DW_shall_be_64 u_err ();
    end
    if ((PARA_EN_PURE[0] | PARA_EN_PREHASH[0]) == 1'b0) begin : g_chk_form
      m_vlsit_dsig_top_error_one_of_PARA_EN_PURE_and_PARA_EN_PREHASH_shall_be_1 u_err ();
    end
    if (PARA_EN_DMA[0] & ~PARA_EN_AXI[0]) begin : g_chk_dma
      m_vlsit_dsig_top_error_PARA_EN_DMA_needs_PARA_EN_AXI u_err ();
    end
    if (PARA_EN_SLHDSA[0] & (PARA_SLHDSA_SETS == 32'd0)) begin : g_chk_slh
      m_vlsit_dsig_top_error_PARA_EN_SLHDSA_needs_a_nonzero_PARA_SLHDSA_SETS u_err ();
    end
    if (PARA_EN_LMS[0] & ((PARA_LMS_SETS == 32'd0) | (PARA_LMOTS_SETS == 32'd0))) begin : g_chk_lms
      m_vlsit_dsig_top_error_PARA_EN_LMS_needs_nonzero_PARA_LMS_SETS_and_PARA_LMOTS_SETS u_err ();
    end
    if (PARA_EN_XMSS[0] & (PARA_XMSS_SETS_LO == 32'd0) & (PARA_XMSS_SETS_HI == 32'd0)) begin : g_chk_xmss
      m_vlsit_dsig_top_error_PARA_EN_XMSS_needs_nonzero_PARA_XMSS_SETS u_err ();
    end
    if ((PARA_EN_ED25519CTX[0] | PARA_EN_ED25519PH[0]) & ~PARA_EN_ED25519[0]) begin : g_chk_ed25519var
      m_vlsit_dsig_top_error_Ed25519ctx_and_Ed25519ph_need_PARA_EN_ED25519 u_err ();
    end
    if (PARA_EN_ED448PH[0] & ~PARA_EN_ED448[0]) begin : g_chk_ed448var
      m_vlsit_dsig_top_error_Ed448ph_needs_PARA_EN_ED448 u_err ();
    end
    if (PARA_EN_DPA_EC[0] | PARA_EN_DPA_PQ[0]) begin : g_chk_dpa
      m_vlsit_dsig_top_error_PARA_EN_DPA_EC_and_PARA_EN_DPA_PQ_are_not_built u_err ();
    end
    if (PARA_ECDSA_NONCE > 32'd2) begin : g_chk_nonce
      m_vlsit_dsig_top_error_PARA_ECDSA_NONCE_must_be_0_1_or_2 u_err ();
    end
    if (PARA_RNG_SRC != 32'd0) begin : g_chk_rng
      m_vlsit_dsig_top_error_PARA_RNG_SRC_shall_be_0 u_err ();
    end
    if ((PARA_EN_KEYIF[0] | PARA_EN_KEYREG[0]) == 1'b0) begin : g_chk_key
      if ((LPARA_CAP_KGEN | LPARA_CAP_SIGN) != 32'd0) begin : g_chk_key_needed
        m_vlsit_dsig_top_error_signing_or_key_generation_needs_PARA_EN_KEYIF_or_PARA_EN_KEYREG u_err ();
      end
    end
  endgenerate

  // Signals between the blocks
  logic         w_ctrl_en;
  logic [14:0]  w_alg_en;
  logic [14:0]  w_alg_act;
  logic         w_lock_req;
  logic         w_lock_req_clr;
  logic         w_locked;
  logic [3:0]   w_op_alg;
  logic [1:0]   w_op_op;
  logic [1:0]   w_op_form;
  logic         w_op_hedged;
  logic [1:0]   w_op_nonce;
  logic [2:0]   w_op_hash;
  logic [1:0]   w_op_hybpol;
  logic [3:0]   w_set_slh;
  logic [4:0]   w_set_lmstype;
  logic [3:0]   w_set_lmots;
  logic [3:0]   w_set_hsslvl;
  logic [5:0]   w_set_xmss;
  logic [31:0]  w_len_msg;
  logic [7:0]   w_len_ctx;
  logic [16:0]  w_off_msg;
  logic [16:0]  w_off_sig;
  logic [16:0]  w_off_pk;
  logic [16:0]  w_off_res;
  logic         w_cmd_start;
  logic         w_cmd_abort;
  logic         w_cmd_clr;
  logic         w_cmd_start_clr;
  logic         w_cmd_abort_clr;
  logic         w_cmd_clr_clr;
  logic         w_sts_busy;
  logic         w_sts_resvld;
  logic         w_sts_sigok;
  logic         w_sts_edok;
  logic         w_sts_mlok;
  logic [11:0]  w_err_set;
  logic [2:0]   w_alarm_set;
  logic [2:0]   w_alarm_flags;
  logic [2:0]   w_irq_raw;
  logic [2:0]   w_irq_en;
  logic [2:0]   w_irq_inj;
  logic [2:0]   w_irq_raw_set;
  logic         w_flags_clr;
  logic [2:0]   w_irq_sts;
  logic         w_log_lock_req;
  logic         w_log_lock_clr;
  logic         w_log_locked;
  logic [31:0]  w_cnt_ops;
  logic [31:0]  w_cnt_fail;
  logic         w_busy;
  logic         w_buf_err_ovf;
  logic         w_buf_err_busy;
  logic         w_reg_rd_en;
  logic [15:0]  w_reg_rd_addr;
  logic         w_reg_wr_en;
  logic [15:0]  w_reg_wr_addr;
  logic [31:0]  w_win_wr_data;
  logic [16:0]  w_win_addr;
  logic         w_win_addr_we;
  logic [16:0]  w_win_addr_wdata;
  logic [31:0]  w_win_rd_data;
  logic [31:0]  w_key [16:0];
  logic [543:0] w_key_reg;
  logic [543:0] w_key_store;
  logic [767:0] w_pool;
  logic [15:0]  w_tmo_key;
  logic [15:0]  w_tmo_ent;
  logic         w_rng_due;
  logic         w_rng_ready;
  logic         w_rng_reseed;
  logic         w_rng_reseed_clr;
  logic         w_axi_err;
  logic         w_dma_in_req;
  logic         w_dma_out_req;
  logic         w_zero;
  logic         w_zero_done;

  // Run snapshot of the control block
  logic [2:0]   w_eng_start;
  logic [3:0]   w_run_alg;
  logic [1:0]   w_run_op;
  logic [1:0]   w_run_form;
  logic         w_run_hedged;
  logic [1:0]   w_run_nonce;
  logic         w_run_det;
  logic [2:0]   w_run_hash;
  logic [3:0]   w_run_slh;
  logic [4:0]   w_run_lmstype;
  logic [3:0]   w_run_lmots;
  logic [3:0]   w_run_hsslvl;
  logic [5:0]   w_run_xmss;
  logic [31:0]  w_run_len_msg;
  logic [7:0]   w_run_len_ctx;
  logic [16:0]  w_run_off_msg;
  logic [16:0]  w_run_off_sig;
  logic [16:0]  w_run_off_pk;
  logic [16:0]  w_run_off_res;

  // Handshakes of the control block with the key, random block and engines
  logic         w_key_start;
  logic         w_key_done;
  logic         w_key_tmo;
  logic         w_key_cleared;
  logic         w_rng_start;
  logic         w_rng_done;
  logic         w_rng_tmo;
  logic         w_rng_cleared;
  logic         w_vas_start;
  logic         w_vas_done;
  logic         w_vas_ok;
  logic         w_eng_done;
  logic         w_eng_err;
  logic [11:0]  w_eng_err_flags;
  logic         w_eng_sigok;

  // Buffer, engine side
  logic         w_eng_rd_en;
  logic [LPARA_WA-1:0] w_eng_rd_addr;
  logic [63:0]  w_eng_rd_data;
  logic         w_eng_rd_valid;
  logic         w_eng_wr_en;
  logic [LPARA_WA-1:0] w_eng_wr_addr;
  logic [63:0]  w_eng_wr_data;
  logic [7:0]   w_eng_wr_strb;

  // Buffer, AXI4 side
  logic         w_axb_wr_en;
  logic [LPARA_WA-1:0] w_axb_wr_addr;
  logic [63:0]  w_axb_wr_data;
  logic [7:0]   w_axb_wr_strb;
  logic         w_axb_wr_rej;
  logic         w_axb_rd_en;
  logic [LPARA_WA-1:0] w_axb_rd_addr;
  logic [63:0]  w_axb_rd_data;
  logic         w_axb_rd_valid;
  logic         w_axb_rd_rej;

  // Elliptic-curve engine
  logic         w_ec_start;
  logic         w_ec_vas_start;
  logic         w_ec_busy;
  logic         w_ec_done;
  logic         w_ec_err;
  logic [11:0]  w_ec_err_flags;
  logic         w_ec_sigok;
  logic         w_ec_vas_done;
  logic         w_ec_vas_ok;
  logic         w_ec_cleared;
  logic         w_ec_rd_en;
  logic [LPARA_WA-1:0] w_ec_rd_addr;
  logic         w_ec_wr_en;
  logic [LPARA_WA-1:0] w_ec_wr_addr;
  logic [63:0]  w_ec_wr_data;
  logic [7:0]   w_ec_wr_strb;

  // Lattice engine
  logic         w_lat_start;
  logic         w_lat_vas_start;
  logic         w_lat_busy;
  logic         w_lat_done;
  logic         w_lat_err;
  logic [11:0]  w_lat_err_flags;
  logic         w_lat_sigok;
  logic         w_lat_vas_done;
  logic         w_lat_vas_ok;
  logic         w_lat_cleared;
  logic         w_lat_rd_en;
  logic [LPARA_WA-1:0] w_lat_rd_addr;
  logic         w_lat_wr_en;
  logic [LPARA_WA-1:0] w_lat_wr_addr;
  logic [63:0]  w_lat_wr_data;
  logic [7:0]   w_lat_wr_strb;

  // Hash-based engine
  logic         w_hbs_start;
  logic         w_hbs_busy;
  logic         w_hbs_done;
  logic         w_hbs_err;
  logic [11:0]  w_hbs_err_flags;
  logic         w_hbs_sigok;
  logic         w_hbs_cleared;
  logic         w_hbs_rd_en;
  logic [LPARA_WA-1:0] w_hbs_rd_addr;

  // Hash requesters, packed in the order of the arbiter: 0 elliptic curve, 1 lattice, 2 hash-based
  logic [2:0]   w_hq_req;
  logic [2:0]   w_hq_start;
  logic [11:0]  w_hq_mode;
  logic [47:0]  w_hq_outlen;
  logic [2:0]   w_hq_in_valid;
  logic [191:0] w_hq_in_data;
  logic [11:0]  w_hq_in_nb;
  logic [2:0]   w_hq_in_last;
  logic [2:0]   w_hq_out_ready;
  logic [2:0]   w_hq_grant;
  logic [2:0]   w_hq_in_ready;
  logic [2:0]   w_hq_out_valid;
  logic [191:0] w_hq_out_data;
  logic [11:0]  w_hq_out_nb;
  logic [2:0]   w_hq_out_last;

  // Hash sequencer side of the arbiter
  logic         w_hs_job_start;
  logic [3:0]   w_hs_job_mode;
  logic [15:0]  w_hs_job_outlen;
  logic         w_hs_in_valid;
  logic [63:0]  w_hs_in_data;
  logic [3:0]   w_hs_in_nb;
  logic         w_hs_in_last;
  logic         w_hs_in_ready;
  logic         w_hs_out_valid;
  logic [63:0]  w_hs_out_data;
  logic [3:0]   w_hs_out_nb;
  logic         w_hs_out_last;
  logic         w_hs_out_ready;

  // The key registers of the CSR as one vector (key byte i in bits [8 i +: 8]).
  assign w_key_reg = {w_key[16], w_key[15], w_key[14], w_key[13], w_key[12], w_key[11], w_key[10],
                      w_key[9], w_key[8], w_key[7], w_key[6], w_key[5], w_key[4], w_key[3], w_key[2],
                      w_key[1], w_key[0]};

  // Generated CSR (clock of the registers is the core clock)
  m_vlsit_csr_dsig #(
    .PARA_ASYNCHRONOUS (PARA_CSR_ASYNC)
  ) u_csr (
    .i_clk_apb         (i_clk_apb),
    .i_rst_n_apb       (i_rst_n_apb),
    .i_clk_reg         (i_clk_core),
    .i_rst_n_reg       (i_rst_n_core),
    .i_apb_psel        (i_apb_psel),
    .i_apb_penable     (i_apb_penable),
    .i_apb_pwrite      (i_apb_pwrite),
    .i_apb_paddr       (i_apb_paddr),
    .i_apb_pwdata      (i_apb_pwdata),
    .i_apb_pstrb       (i_apb_pstrb),
    .i_apb_pprot       (i_apb_pprot),
    .o_apb_pready      (o_apb_pready),
    .o_apb_pslverr     (o_apb_pslverr),
    .o_apb_prdata      (o_apb_prdata),
    .i_protect_en      (i_protect_en),
    .i_slverr_en       (i_slverr_en),
    .o_reg_rd_en       (w_reg_rd_en),
    .o_reg_rd_addr     (w_reg_rd_addr),
    .o_reg_wr_en       (w_reg_wr_en),
    .o_reg_wr_addr     (w_reg_wr_addr),
    .i_dsig_version_major (16'd1),
    .i_dsig_version_minor (16'd0),
    // Capability of algorithms: index order ed25519, ed25519ctx, ed25519ph, ed448, ed448ph,
    // p256, p384, p521, k256, mldsa44, mldsa65, mldsa87, slhdsa, lms, xmss
    .i_dsig_cap_alg_ed25519    (LPARA_CAP_ALG[0]),
    .i_dsig_cap_alg_ed25519ctx (LPARA_CAP_ALG[1]),
    .i_dsig_cap_alg_ed25519ph  (LPARA_CAP_ALG[2]),
    .i_dsig_cap_alg_ed448      (LPARA_CAP_ALG[3]),
    .i_dsig_cap_alg_ed448ph    (LPARA_CAP_ALG[4]),
    .i_dsig_cap_alg_p256       (LPARA_CAP_ALG[5]),
    .i_dsig_cap_alg_p384       (LPARA_CAP_ALG[6]),
    .i_dsig_cap_alg_p521       (LPARA_CAP_ALG[7]),
    .i_dsig_cap_alg_k256       (LPARA_CAP_ALG[8]),
    .i_dsig_cap_alg_mldsa44    (LPARA_CAP_ALG[9]),
    .i_dsig_cap_alg_mldsa65    (LPARA_CAP_ALG[10]),
    .i_dsig_cap_alg_mldsa87    (LPARA_CAP_ALG[11]),
    .i_dsig_cap_alg_slhdsa     (LPARA_CAP_ALG[12]),
    .i_dsig_cap_alg_lms        (LPARA_CAP_ALG[13]),
    .i_dsig_cap_alg_xmss       (LPARA_CAP_ALG[14]),
    .i_dsig_cap_kgen_ed25519    (LPARA_CAP_KGEN[0]),
    .i_dsig_cap_kgen_ed25519ctx (LPARA_CAP_KGEN[1]),
    .i_dsig_cap_kgen_ed25519ph  (LPARA_CAP_KGEN[2]),
    .i_dsig_cap_kgen_ed448      (LPARA_CAP_KGEN[3]),
    .i_dsig_cap_kgen_ed448ph    (LPARA_CAP_KGEN[4]),
    .i_dsig_cap_kgen_p256       (LPARA_CAP_KGEN[5]),
    .i_dsig_cap_kgen_p384       (LPARA_CAP_KGEN[6]),
    .i_dsig_cap_kgen_p521       (LPARA_CAP_KGEN[7]),
    .i_dsig_cap_kgen_k256       (LPARA_CAP_KGEN[8]),
    .i_dsig_cap_kgen_mldsa44    (LPARA_CAP_KGEN[9]),
    .i_dsig_cap_kgen_mldsa65    (LPARA_CAP_KGEN[10]),
    .i_dsig_cap_kgen_mldsa87    (LPARA_CAP_KGEN[11]),
    .i_dsig_cap_kgen_slhdsa     (LPARA_CAP_KGEN[12]),
    .i_dsig_cap_kgen_lms        (LPARA_CAP_KGEN[13]),
    .i_dsig_cap_kgen_xmss       (LPARA_CAP_KGEN[14]),
    .i_dsig_cap_sign_ed25519    (LPARA_CAP_SIGN[0]),
    .i_dsig_cap_sign_ed25519ctx (LPARA_CAP_SIGN[1]),
    .i_dsig_cap_sign_ed25519ph  (LPARA_CAP_SIGN[2]),
    .i_dsig_cap_sign_ed448      (LPARA_CAP_SIGN[3]),
    .i_dsig_cap_sign_ed448ph    (LPARA_CAP_SIGN[4]),
    .i_dsig_cap_sign_p256       (LPARA_CAP_SIGN[5]),
    .i_dsig_cap_sign_p384       (LPARA_CAP_SIGN[6]),
    .i_dsig_cap_sign_p521       (LPARA_CAP_SIGN[7]),
    .i_dsig_cap_sign_k256       (LPARA_CAP_SIGN[8]),
    .i_dsig_cap_sign_mldsa44    (LPARA_CAP_SIGN[9]),
    .i_dsig_cap_sign_mldsa65    (LPARA_CAP_SIGN[10]),
    .i_dsig_cap_sign_mldsa87    (LPARA_CAP_SIGN[11]),
    .i_dsig_cap_sign_slhdsa     (LPARA_CAP_SIGN[12]),
    .i_dsig_cap_sign_lms        (LPARA_CAP_SIGN[13]),
    .i_dsig_cap_sign_xmss       (LPARA_CAP_SIGN[14]),
    .i_dsig_cap_vrfy_ed25519    (LPARA_CAP_VRFY[0]),
    .i_dsig_cap_vrfy_ed25519ctx (LPARA_CAP_VRFY[1]),
    .i_dsig_cap_vrfy_ed25519ph  (LPARA_CAP_VRFY[2]),
    .i_dsig_cap_vrfy_ed448      (LPARA_CAP_VRFY[3]),
    .i_dsig_cap_vrfy_ed448ph    (LPARA_CAP_VRFY[4]),
    .i_dsig_cap_vrfy_p256       (LPARA_CAP_VRFY[5]),
    .i_dsig_cap_vrfy_p384       (LPARA_CAP_VRFY[6]),
    .i_dsig_cap_vrfy_p521       (LPARA_CAP_VRFY[7]),
    .i_dsig_cap_vrfy_k256       (LPARA_CAP_VRFY[8]),
    .i_dsig_cap_vrfy_mldsa44    (LPARA_CAP_VRFY[9]),
    .i_dsig_cap_vrfy_mldsa65    (LPARA_CAP_VRFY[10]),
    .i_dsig_cap_vrfy_mldsa87    (LPARA_CAP_VRFY[11]),
    .i_dsig_cap_vrfy_slhdsa     (LPARA_CAP_VRFY[12]),
    .i_dsig_cap_vrfy_lms        (LPARA_CAP_VRFY[13]),
    .i_dsig_cap_vrfy_xmss       (LPARA_CAP_VRFY[14]),
    .i_dsig_cap_slh_sets   (PARA_SLHDSA_SETS[11:0]),
    .i_dsig_cap_lms_lms    (PARA_LMS_SETS[19:0]),
    .i_dsig_cap_xmss_sets  (PARA_XMSS_SETS_LO),
    .i_dsig_cap_xmssh_sets (PARA_XMSS_SETS_HI[11:0]),
    .i_dsig_cap_lmots_lmots (PARA_LMOTS_SETS[15:0]),
    .i_dsig_cap_feat_pure      (PARA_EN_PURE[0]),
    .i_dsig_cap_feat_prehash   (PARA_EN_PREHASH[0]),
    .i_dsig_cap_feat_axi       (PARA_EN_AXI[0]),
    .i_dsig_cap_feat_dma       (PARA_EN_DMA[0]),
    .i_dsig_cap_feat_win       (PARA_EN_WIN[0]),
    .i_dsig_cap_feat_keyif     (PARA_EN_KEYIF[0]),
    .i_dsig_cap_feat_keyreg    (PARA_EN_KEYREG[0]),
    .i_dsig_cap_feat_vas       (PARA_EN_VAS[0]),
    .i_dsig_cap_feat_dpa_ec    (PARA_EN_DPA_EC[0]),
    .i_dsig_cap_feat_dpa_pq    (PARA_EN_DPA_PQ[0]),
    .i_dsig_cap_feat_hybrid    (PARA_EN_HYBRID[0]),
    .i_dsig_cap_feat_log       (PARA_EN_LOG[0]),
    .i_dsig_cap_feat_lock      (PARA_EN_LOCK[0]),
    .i_dsig_cap_feat_rngsrc    (PARA_RNG_SRC[0]),
    .i_dsig_cap_feat_csrasync  (PARA_CSR_ASYNC[0]),
    .i_dsig_cap_buf_buf        (PARA_BUF_BYTES[16:0]),
    .i_dsig_cap_buf_mulw       (LPARA_MULW_CODE[1:0]),
    .o_dsig_ctrl_en            (w_ctrl_en),
    .o_dsig_alg_en_ed25519     (w_alg_en[0]),
    .o_dsig_alg_en_ed25519ctx  (w_alg_en[1]),
    .o_dsig_alg_en_ed25519ph   (w_alg_en[2]),
    .o_dsig_alg_en_ed448       (w_alg_en[3]),
    .o_dsig_alg_en_ed448ph     (w_alg_en[4]),
    .o_dsig_alg_en_p256        (w_alg_en[5]),
    .o_dsig_alg_en_p384        (w_alg_en[6]),
    .o_dsig_alg_en_p521        (w_alg_en[7]),
    .o_dsig_alg_en_k256        (w_alg_en[8]),
    .o_dsig_alg_en_mldsa44     (w_alg_en[9]),
    .o_dsig_alg_en_mldsa65     (w_alg_en[10]),
    .o_dsig_alg_en_mldsa87     (w_alg_en[11]),
    .o_dsig_alg_en_slhdsa      (w_alg_en[12]),
    .o_dsig_alg_en_lms         (w_alg_en[13]),
    .o_dsig_alg_en_xmss        (w_alg_en[14]),
    .i_dsig_alg_act_ed25519    (w_alg_act[0]),
    .i_dsig_alg_act_ed25519ctx (w_alg_act[1]),
    .i_dsig_alg_act_ed25519ph  (w_alg_act[2]),
    .i_dsig_alg_act_ed448      (w_alg_act[3]),
    .i_dsig_alg_act_ed448ph    (w_alg_act[4]),
    .i_dsig_alg_act_p256       (w_alg_act[5]),
    .i_dsig_alg_act_p384       (w_alg_act[6]),
    .i_dsig_alg_act_p521       (w_alg_act[7]),
    .i_dsig_alg_act_k256       (w_alg_act[8]),
    .i_dsig_alg_act_mldsa44    (w_alg_act[9]),
    .i_dsig_alg_act_mldsa65    (w_alg_act[10]),
    .i_dsig_alg_act_mldsa87    (w_alg_act[11]),
    .i_dsig_alg_act_slhdsa     (w_alg_act[12]),
    .i_dsig_alg_act_lms        (w_alg_act[13]),
    .i_dsig_alg_act_xmss       (w_alg_act[14]),
    .i_dsig_lock_locked        (w_locked),
    .o_dsig_lock_req           (w_lock_req),
    .i_hw_clr_dsig_lock_req    (w_lock_req_clr),
    .o_dsig_op_hybpol          (w_op_hybpol),
    .o_dsig_op_hash            (w_op_hash),
    .o_dsig_op_nonce           (w_op_nonce),
    .o_dsig_op_hedged          (w_op_hedged),
    .o_dsig_op_form            (w_op_form),
    .o_dsig_op_op              (w_op_op),
    .o_dsig_op_alg             (w_op_alg),
    .o_dsig_set_xmss           (w_set_xmss),
    .o_dsig_set_hsslvl         (w_set_hsslvl),
    .o_dsig_set_lmots          (w_set_lmots),
    .o_dsig_set_lmstype        (w_set_lmstype),
    .o_dsig_set_slh            (w_set_slh),
    .o_dsig_len_msg_len        (w_len_msg),
    .o_dsig_len_ctx_len        (w_len_ctx),
    .o_dsig_off_msg_off        (w_off_msg),
    .o_dsig_off_sig_off        (w_off_sig),
    .o_dsig_off_pk_off         (w_off_pk),
    .o_dsig_off_res_off        (w_off_res),
    .o_dsig_cmd_clr            (w_cmd_clr),
    .i_hw_clr_dsig_cmd_clr     (w_cmd_clr_clr),
    .o_dsig_cmd_abort          (w_cmd_abort),
    .i_hw_clr_dsig_cmd_abort   (w_cmd_abort_clr),
    .o_dsig_cmd_start          (w_cmd_start),
    .i_hw_clr_dsig_cmd_start   (w_cmd_start_clr),
    .i_dsig_sts_mlok           (w_sts_mlok),
    .i_dsig_sts_edok           (w_sts_edok),
    .i_dsig_sts_sigok          (w_sts_sigok),
    .i_dsig_sts_resvld         (w_sts_resvld),
    .i_dsig_sts_busy           (w_sts_busy),
    // Error flags: bit n of the set vector of the control block is bit n of dsig_err
    .o_dsig_err_busycmd        (),
    .i_hw_wdata_dsig_err_busycmd (w_err_set[11]),
    .i_hw_we_dsig_err_busycmd  (w_err_set[11] | w_flags_clr),
    .o_dsig_err_lockv          (),
    .i_hw_wdata_dsig_err_lockv (w_err_set[10]),
    .i_hw_we_dsig_err_lockv    (w_err_set[10] | w_flags_clr),
    .o_dsig_err_vasmis         (),
    .i_hw_wdata_dsig_err_vasmis (w_err_set[9]),
    .i_hw_we_dsig_err_vasmis   (w_err_set[9] | w_flags_clr),
    .o_dsig_err_keytmo         (),
    .i_hw_wdata_dsig_err_keytmo (w_err_set[8]),
    .i_hw_we_dsig_err_keytmo   (w_err_set[8] | w_flags_clr),
    .o_dsig_err_enttmo         (),
    .i_hw_wdata_dsig_err_enttmo (w_err_set[7]),
    .i_hw_we_dsig_err_enttmo   (w_err_set[7] | w_flags_clr),
    .o_dsig_err_buserr         (),
    .i_hw_wdata_dsig_err_buserr (w_err_set[6] | w_axi_err),
    .i_hw_we_dsig_err_buserr   (w_err_set[6] | w_axi_err | w_flags_clr),
    .o_dsig_err_bufovf         (),
    .i_hw_wdata_dsig_err_bufovf (w_err_set[5]),
    .i_hw_we_dsig_err_bufovf   (w_err_set[5] | w_flags_clr),
    .o_dsig_err_badpt          (),
    .i_hw_wdata_dsig_err_badpt (w_err_set[4]),
    .i_hw_we_dsig_err_badpt    (w_err_set[4] | w_flags_clr),
    .o_dsig_err_badkey         (),
    .i_hw_wdata_dsig_err_badkey (w_err_set[3]),
    .i_hw_we_dsig_err_badkey   (w_err_set[3] | w_flags_clr),
    .o_dsig_err_badlen         (),
    .i_hw_wdata_dsig_err_badlen (w_err_set[2]),
    .i_hw_we_dsig_err_badlen   (w_err_set[2] | w_flags_clr),
    .o_dsig_err_opuns          (),
    .i_hw_wdata_dsig_err_opuns (w_err_set[1]),
    .i_hw_we_dsig_err_opuns    (w_err_set[1] | w_flags_clr),
    .o_dsig_err_algdis         (),
    .i_hw_wdata_dsig_err_algdis (w_err_set[0]),
    .i_hw_we_dsig_err_algdis   (w_err_set[0] | w_flags_clr),
    // Interrupt raw events: done [0], err [1], sec [2]
    .o_dsig_irq_raw_sec        (w_irq_raw[2]),
    .i_hw_wdata_dsig_irq_raw_sec (1'b1),
    .i_hw_we_dsig_irq_raw_sec  (w_irq_raw_set[2]),
    .o_dsig_irq_raw_err        (w_irq_raw[1]),
    .i_hw_wdata_dsig_irq_raw_err (w_irq_raw_set[1]),
    .i_hw_we_dsig_irq_raw_err  (w_irq_raw_set[1] | w_flags_clr),
    .o_dsig_irq_raw_done       (w_irq_raw[0]),
    .i_hw_wdata_dsig_irq_raw_done (w_irq_raw_set[0]),
    .i_hw_we_dsig_irq_raw_done (w_irq_raw_set[0] | w_flags_clr),
    .o_dsig_irq_en_sec         (w_irq_en[2]),
    .o_dsig_irq_en_err         (w_irq_en[1]),
    .o_dsig_irq_en_done        (w_irq_en[0]),
    .o_dsig_irq_inj_sec        (w_irq_inj[2]),
    .o_dsig_irq_inj_err        (w_irq_inj[1]),
    .o_dsig_irq_inj_done       (w_irq_inj[0]),
    .i_dsig_irq_sts_sec        (w_irq_sts[2]),
    .i_dsig_irq_sts_err        (w_irq_sts[1]),
    .i_dsig_irq_sts_done       (w_irq_sts[0]),
    // Alarm flags: fault [0], lockv [1], rngfail [2]
    .o_dsig_alarm_rngfail      (w_alarm_flags[2]),
    .i_hw_wdata_dsig_alarm_rngfail (1'b1),
    .i_hw_we_dsig_alarm_rngfail (w_alarm_set[2]),
    .o_dsig_alarm_lockv        (w_alarm_flags[1]),
    .i_hw_wdata_dsig_alarm_lockv (1'b1),
    .i_hw_we_dsig_alarm_lockv  (w_alarm_set[1]),
    .o_dsig_alarm_fault        (w_alarm_flags[0]),
    .i_hw_wdata_dsig_alarm_fault (1'b1),
    .i_hw_we_dsig_alarm_fault  (w_alarm_set[0]),
    .o_dsig_win_addr_addr      (w_win_addr),
    .i_hw_wdata_dsig_win_addr_addr (w_win_addr_wdata),
    .i_hw_we_dsig_win_addr_addr (w_win_addr_we),
    .o_dsig_win_wr_data        (w_win_wr_data),
    .i_hw_clr_dsig_win_wr_data (1'b0),
    .i_dsig_win_rd_data        (w_win_rd_data),
    .i_dsig_cnt_ops_cnt        (w_cnt_ops),
    .i_dsig_cnt_fail_cnt       (w_cnt_fail),
    .i_dsig_log_lock_locked    (w_log_locked),
    .o_dsig_log_lock_req       (w_log_lock_req),
    .i_hw_clr_dsig_log_lock_req (w_log_lock_clr),
    .i_dsig_rng_due            (w_rng_due),
    .i_dsig_rng_ready          (w_rng_ready),
    .o_dsig_rng_reseed         (w_rng_reseed),
    .i_hw_clr_dsig_rng_reseed  (w_rng_reseed_clr),
    .o_dsig_tmo_key            (w_tmo_key),
    .o_dsig_tmo_ent            (w_tmo_ent),
    .o_dsig_key_0_data         (w_key[0]),
    .i_hw_clr_dsig_key_0_data  (w_zero),
    .o_dsig_key_1_data         (w_key[1]),
    .i_hw_clr_dsig_key_1_data  (w_zero),
    .o_dsig_key_2_data         (w_key[2]),
    .i_hw_clr_dsig_key_2_data  (w_zero),
    .o_dsig_key_3_data         (w_key[3]),
    .i_hw_clr_dsig_key_3_data  (w_zero),
    .o_dsig_key_4_data         (w_key[4]),
    .i_hw_clr_dsig_key_4_data  (w_zero),
    .o_dsig_key_5_data         (w_key[5]),
    .i_hw_clr_dsig_key_5_data  (w_zero),
    .o_dsig_key_6_data         (w_key[6]),
    .i_hw_clr_dsig_key_6_data  (w_zero),
    .o_dsig_key_7_data         (w_key[7]),
    .i_hw_clr_dsig_key_7_data  (w_zero),
    .o_dsig_key_8_data         (w_key[8]),
    .i_hw_clr_dsig_key_8_data  (w_zero),
    .o_dsig_key_9_data         (w_key[9]),
    .i_hw_clr_dsig_key_9_data  (w_zero),
    .o_dsig_key_10_data        (w_key[10]),
    .i_hw_clr_dsig_key_10_data (w_zero),
    .o_dsig_key_11_data        (w_key[11]),
    .i_hw_clr_dsig_key_11_data (w_zero),
    .o_dsig_key_12_data        (w_key[12]),
    .i_hw_clr_dsig_key_12_data (w_zero),
    .o_dsig_key_13_data        (w_key[13]),
    .i_hw_clr_dsig_key_13_data (w_zero),
    .o_dsig_key_14_data        (w_key[14]),
    .i_hw_clr_dsig_key_14_data (w_zero),
    .o_dsig_key_15_data        (w_key[15]),
    .i_hw_clr_dsig_key_15_data (w_zero),
    .o_dsig_key_16_data        (w_key[16]),
    .i_hw_clr_dsig_key_16_data (w_zero)
  );

  // Hash request signals of the three engines
  logic         w_ec_hs_req;
  logic         w_ec_hs_start;
  logic [3:0]   w_ec_hs_mode;
  logic [15:0]  w_ec_hs_outlen;
  logic         w_ec_hs_in_valid;
  logic [63:0]  w_ec_hs_in_data;
  logic [3:0]   w_ec_hs_in_nb;
  logic         w_ec_hs_in_last;
  logic         w_ec_hs_out_ready;
  logic         w_lat_hs_req;
  logic         w_lat_hs_start;
  logic [3:0]   w_lat_hs_mode;
  logic [15:0]  w_lat_hs_outlen;
  logic         w_lat_hs_in_valid;
  logic [63:0]  w_lat_hs_in_data;
  logic [3:0]   w_lat_hs_in_nb;
  logic         w_lat_hs_in_last;
  logic         w_lat_hs_out_ready;
  logic         w_hbs_hs_req;
  logic         w_hbs_hs_start;
  logic [3:0]   w_hbs_hs_mode;
  logic [15:0]  w_hbs_hs_outlen;
  logic         w_hbs_hs_in_valid;
  logic [63:0]  w_hbs_hs_in_data;
  logic [3:0]   w_hbs_hs_in_nb;
  logic         w_hbs_hs_in_last;
  logic         w_hbs_hs_out_ready;

  // Control block
  m_vlsit_dsig_ctl #(
    .PARA_CAP_ALG      (LPARA_CAP_ALG),
    .PARA_CAP_KGEN     (LPARA_CAP_KGEN),
    .PARA_CAP_SIGN     (LPARA_CAP_SIGN),
    .PARA_CAP_VRFY     (LPARA_CAP_VRFY),
    .PARA_EN_PURE      (PARA_EN_PURE),
    .PARA_EN_PREHASH   (PARA_EN_PREHASH),
    .PARA_EN_LOCK      (PARA_EN_LOCK),
    .PARA_EN_LOG       (PARA_EN_LOG),
    .PARA_EN_VAS       (PARA_EN_VAS),
    .PARA_EN_HYBRID    (PARA_EN_HYBRID),
    .PARA_EN_DPA_EC    (PARA_EN_DPA_EC),
    .PARA_EN_DPA_PQ    (PARA_EN_DPA_PQ),
    .PARA_ECDSA_NONCE  (PARA_ECDSA_NONCE),
    .PARA_BUF_BYTES    (PARA_BUF_BYTES),
    .PARA_SLHDSA_SETS  (PARA_SLHDSA_SETS),
    .PARA_LMS_SETS     (PARA_LMS_SETS),
    .PARA_LMOTS_SETS   (PARA_LMOTS_SETS),
    .PARA_XMSS_SETS_LO (PARA_XMSS_SETS_LO),
    .PARA_XMSS_SETS_HI (PARA_XMSS_SETS_HI)
  ) u_ctl (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_ctrl_en         (w_ctrl_en),
    .i_alg_en          (w_alg_en),
    .i_lock_req        (w_lock_req),
    .o_lock_req_clr    (w_lock_req_clr),
    .i_op_alg          (w_op_alg),
    .i_op_op           (w_op_op),
    .i_op_form         (w_op_form),
    .i_op_hedged       (w_op_hedged),
    .i_op_nonce        (w_op_nonce),
    .i_op_hash         (w_op_hash),
    .i_op_hybpol       (w_op_hybpol),
    .i_set_slh         (w_set_slh),
    .i_set_lmstype     (w_set_lmstype),
    .i_set_lmots       (w_set_lmots),
    .i_set_hsslvl      (w_set_hsslvl),
    .i_set_xmss        (w_set_xmss),
    .i_len_msg         (w_len_msg),
    .i_len_ctx         (w_len_ctx),
    .i_off_msg         (w_off_msg),
    .i_off_sig         (w_off_sig),
    .i_off_pk          (w_off_pk),
    .i_off_res         (w_off_res),
    .i_cmd_start       (w_cmd_start),
    .i_cmd_abort       (w_cmd_abort),
    .i_cmd_clr         (w_cmd_clr),
    .o_cmd_start_clr   (w_cmd_start_clr),
    .o_cmd_abort_clr   (w_cmd_abort_clr),
    .o_cmd_clr_clr     (w_cmd_clr_clr),
    .o_sts_busy        (w_sts_busy),
    .o_sts_resvld      (w_sts_resvld),
    .o_sts_sigok       (w_sts_sigok),
    .o_sts_edok        (w_sts_edok),
    .o_sts_mlok        (w_sts_mlok),
    .o_alg_act         (w_alg_act),
    .o_locked          (w_locked),
    .o_err_set         (w_err_set),
    .o_alarm_set       (w_alarm_set),
    .i_alarm_flags     (w_alarm_flags),
    .i_irq_raw         (w_irq_raw),
    .i_irq_en          (w_irq_en),
    .i_irq_inj         (w_irq_inj),
    .o_irq_raw_set     (w_irq_raw_set),
    .o_flags_clr       (w_flags_clr),
    .o_irq_sts         (w_irq_sts),
    .i_log_lock_req    (w_log_lock_req),
    .o_log_lock_clr    (w_log_lock_clr),
    .o_log_locked      (w_log_locked),
    .o_cnt_ops         (w_cnt_ops),
    .o_cnt_fail        (w_cnt_fail),
    .o_irq             (o_irq),
    .o_alarm           (o_alarm),
    .o_eng_start       (w_eng_start),
    .o_run_alg         (w_run_alg),
    .o_run_op          (w_run_op),
    .o_run_form        (w_run_form),
    .o_run_hedged      (w_run_hedged),
    .o_run_nonce       (w_run_nonce),
    .o_run_hash        (w_run_hash),
    .o_run_slh         (w_run_slh),
    .o_run_lmstype     (w_run_lmstype),
    .o_run_lmots       (w_run_lmots),
    .o_run_hsslvl      (w_run_hsslvl),
    .o_run_xmss        (w_run_xmss),
    .o_run_len_msg     (w_run_len_msg),
    .o_run_len_ctx     (w_run_len_ctx),
    .o_run_off_msg     (w_run_off_msg),
    .o_run_off_sig     (w_run_off_sig),
    .o_run_off_pk      (w_run_off_pk),
    .o_run_off_res     (w_run_off_res),
    .i_eng_done        (w_eng_done),
    .i_eng_err         (w_eng_err),
    .i_eng_err_flags   (w_eng_err_flags),
    .i_eng_sigok       (w_eng_sigok),
    .o_key_start       (w_key_start),
    .i_key_done        (w_key_done),
    .i_key_tmo         (w_key_tmo),
    .o_rng_start       (w_rng_start),
    .i_rng_done        (w_rng_done),
    .i_rng_tmo         (w_rng_tmo),
    .o_vas_start       (w_vas_start),
    .i_vas_done        (w_vas_done),
    .i_vas_ok          (w_vas_ok),
    .o_zero            (w_zero),
    .i_zero_done       (w_zero_done),
    .o_busy            (w_busy),
    .i_buf_err_ovf     (w_buf_err_ovf),
    .i_buf_err_busy    (w_buf_err_busy)
  );

  // Buffer with the CSR window; the engines use the engine port, the AXI4 block the bus port
  m_vlsit_dsig_buf #(
    .PARA_BUF_BYTES    (PARA_BUF_BYTES),
    .PARA_AXI_DW       (PARA_AXI_DW)
  ) u_buf (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_axi_wr_en       (w_axb_wr_en),
    .i_axi_wr_addr     (w_axb_wr_addr),
    .i_axi_wr_data     (w_axb_wr_data),
    .i_axi_wr_strb     (w_axb_wr_strb),
    .o_axi_wr_rej      (w_axb_wr_rej),
    .i_axi_rd_en       (w_axb_rd_en),
    .i_axi_rd_addr     (w_axb_rd_addr),
    .o_axi_rd_data     (w_axb_rd_data),
    .o_axi_rd_valid    (w_axb_rd_valid),
    .o_axi_rd_rej      (w_axb_rd_rej),
    .i_reg_wr_en       (w_reg_wr_en),
    .i_reg_wr_addr     (w_reg_wr_addr),
    .i_reg_rd_en       (w_reg_rd_en),
    .i_reg_rd_addr     (w_reg_rd_addr),
    .i_win_wr_data     (w_win_wr_data),
    .i_win_addr        (w_win_addr),
    .o_win_addr_we     (w_win_addr_we),
    .o_win_addr_wdata  (w_win_addr_wdata),
    .o_win_rd_data     (w_win_rd_data),
    .i_eng_rd_en       (w_eng_rd_en),
    .i_eng_rd_addr     (w_eng_rd_addr),
    .o_eng_rd_data     (w_eng_rd_data),
    .o_eng_rd_valid    (w_eng_rd_valid),
    .i_eng_wr_en       (w_eng_wr_en),
    .i_eng_wr_addr     (w_eng_wr_addr),
    .i_eng_wr_data     (w_eng_wr_data),
    .i_eng_wr_strb     (w_eng_wr_strb),
    .i_busy            (w_busy),
    .o_err_ovf         (w_buf_err_ovf),
    .o_err_busy        (w_buf_err_busy)
  );

  // Engine port of the buffer: only the engine of the running operation drives its request.
  assign w_eng_rd_en   = w_ec_rd_en | w_lat_rd_en | w_hbs_rd_en;
  assign w_eng_rd_addr = (w_ec_rd_en ? w_ec_rd_addr : {LPARA_WA{1'b0}}) |
                         (w_lat_rd_en ? w_lat_rd_addr : {LPARA_WA{1'b0}}) |
                         (w_hbs_rd_en ? w_hbs_rd_addr : {LPARA_WA{1'b0}});
  assign w_eng_wr_en   = w_ec_wr_en | w_lat_wr_en;
  assign w_eng_wr_addr = (w_ec_wr_en ? w_ec_wr_addr : {LPARA_WA{1'b0}}) |
                         (w_lat_wr_en ? w_lat_wr_addr : {LPARA_WA{1'b0}});
  assign w_eng_wr_data = (w_ec_wr_en ? w_ec_wr_data : 64'd0) | (w_lat_wr_en ? w_lat_wr_data : 64'd0);
  assign w_eng_wr_strb = (w_ec_wr_en ? w_ec_wr_strb : 8'd0) | (w_lat_wr_en ? w_lat_wr_strb : 8'd0);

  // AXI4 block; the address and data channels are masked when the port is not built
  logic         w_axi_awready;
  logic         w_axi_wready;
  logic         w_axi_arready;

  m_vlsit_dsig_axi #(
    .PARA_BUF_BYTES    (PARA_BUF_BYTES),
    .PARA_AXI_DW       (PARA_AXI_DW),
    .PARA_AXI_IDW      (PARA_AXI_IDW),
    .PARA_AXI_AW       (PARA_AXI_AW)
  ) u_axi (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_axi_awvalid     (i_axi_awvalid & PARA_EN_AXI[0]),
    .o_axi_awready     (w_axi_awready),
    .i_axi_awid        (i_axi_awid),
    .i_axi_awaddr      (i_axi_awaddr),
    .i_axi_awlen       (i_axi_awlen),
    .i_axi_awsize      (i_axi_awsize),
    .i_axi_awburst     (i_axi_awburst),
    .i_axi_wvalid      (i_axi_wvalid & PARA_EN_AXI[0]),
    .o_axi_wready      (w_axi_wready),
    .i_axi_wdata       (i_axi_wdata),
    .i_axi_wstrb       (i_axi_wstrb),
    .i_axi_wlast       (i_axi_wlast),
    .o_axi_bvalid      (o_axi_bvalid),
    .i_axi_bready      (i_axi_bready),
    .o_axi_bid         (o_axi_bid),
    .o_axi_bresp       (o_axi_bresp),
    .i_axi_arvalid     (i_axi_arvalid & PARA_EN_AXI[0]),
    .o_axi_arready     (w_axi_arready),
    .i_axi_arid        (i_axi_arid),
    .i_axi_araddr      (i_axi_araddr),
    .i_axi_arlen       (i_axi_arlen),
    .i_axi_arsize      (i_axi_arsize),
    .i_axi_arburst     (i_axi_arburst),
    .o_axi_rvalid      (o_axi_rvalid),
    .i_axi_rready      (i_axi_rready),
    .o_axi_rid         (o_axi_rid),
    .o_axi_rdata       (o_axi_rdata),
    .o_axi_rresp       (o_axi_rresp),
    .o_axi_rlast       (o_axi_rlast),
    .o_buf_wr_en       (w_axb_wr_en),
    .o_buf_wr_addr     (w_axb_wr_addr),
    .o_buf_wr_data     (w_axb_wr_data),
    .o_buf_wr_strb     (w_axb_wr_strb),
    .i_buf_wr_rej      (w_axb_wr_rej),
    .o_buf_rd_en       (w_axb_rd_en),
    .o_buf_rd_addr     (w_axb_rd_addr),
    .i_buf_rd_data     (w_axb_rd_data),
    .i_buf_rd_valid    (w_axb_rd_valid),
    .i_buf_rd_rej      (w_axb_rd_rej),
    .i_busy            (w_busy),
    .i_ctrl_en         (w_ctrl_en),
    .i_resvld          (w_sts_resvld),
    .o_dma_in_req      (w_dma_in_req),
    .i_dma_in_ack      (i_dma_in_ack),
    .o_dma_out_req     (w_dma_out_req),
    .i_dma_out_ack     (i_dma_out_ack),
    .o_err_buserr      (w_axi_err)
  );

  assign o_axi_awready = w_axi_awready & PARA_EN_AXI[0];
  assign o_axi_wready  = w_axi_wready & PARA_EN_AXI[0];
  assign o_axi_arready = w_axi_arready & PARA_EN_AXI[0];
  assign o_dma_in_req  = w_dma_in_req & PARA_EN_DMA[0];
  assign o_dma_out_req = w_dma_out_req & PARA_EN_DMA[0];

  // Key block and random block
  m_vlsit_dsig_key #(
    .PARA_EN_KEYIF     (PARA_EN_KEYIF),
    .PARA_EN_KEYREG    (PARA_EN_KEYREG),
    .PARA_KEY_SRC      (PARA_KEY_SRC)
  ) u_key (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_clr             (w_zero),
    .i_start           (w_key_start),
    .i_run_alg         (w_run_alg),
    .i_tmo_key         (w_tmo_key),
    .o_done            (w_key_done),
    .o_tmo             (w_key_tmo),
    .o_key_req         (o_key_req),
    .o_key_idx         (o_key_idx),
    .i_key_valid       (i_key_valid),
    .i_key_data        (i_key_data),
    .i_key_reg         (w_key_reg),
    .o_key             (w_key_store),
    .o_cleared         (w_key_cleared)
  );

  m_vlsit_dsig_rng #(
    .PARA_RNG_SRC      (PARA_RNG_SRC)
  ) u_rng (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_clr             (w_zero),
    .i_start           (w_rng_start),
    .i_tmo_ent         (w_tmo_ent),
    .o_done            (w_rng_done),
    .o_tmo             (w_rng_tmo),
    .o_ent_req         (o_ent_req),
    .i_ent_valid       (i_ent_valid),
    .i_ent_data        (i_ent_data),
    .i_reseed          (w_rng_reseed),
    .o_reseed_clr      (w_rng_reseed_clr),
    .o_ready           (w_rng_ready),
    .o_due             (w_rng_due),
    .o_pool            (w_pool),
    .o_cleared         (w_rng_cleared)
  );

  // Engine feedback to the control block: only the engine that reports drives each field.
  assign w_eng_done      = w_ec_done | w_lat_done | w_hbs_done;
  assign w_eng_err       = w_ec_err | w_lat_err | w_hbs_err;
  assign w_eng_err_flags = (w_ec_err ? w_ec_err_flags : 12'd0) | (w_lat_err ? w_lat_err_flags : 12'd0) |
                           (w_hbs_err ? w_hbs_err_flags : 12'd0);
  assign w_eng_sigok     = (w_ec_done & w_ec_sigok) | (w_lat_done & w_lat_sigok) | (w_hbs_done & w_hbs_sigok);
  assign w_vas_done      = w_ec_vas_done | w_lat_vas_done;
  assign w_vas_ok        = (w_ec_vas_done & w_ec_vas_ok) | (w_lat_vas_done & w_lat_vas_ok);
  assign w_zero_done     = w_key_cleared & w_rng_cleared & w_ec_cleared & w_lat_cleared & w_hbs_cleared;

  // Start pulses of the engines: the control block gives one pulse for the group of the algorithm.
  // Deterministic ECDSA nonce selected for the running operation
  assign w_run_det       = (PARA_ECDSA_NONCE == 32'd1) | ((PARA_ECDSA_NONCE == 32'd2) & w_run_nonce[0]);
  assign w_ec_start      = w_eng_start[0];
  assign w_lat_start     = w_eng_start[1];
  assign w_hbs_start     = w_eng_start[2];
  assign w_ec_vas_start  = w_vas_start & (w_run_alg <= 4'd8);
  assign w_lat_vas_start = w_vas_start & (w_run_alg >= 4'd9) & (w_run_alg <= 4'd11);

  // Elliptic-curve engine
  generate
    if (LPARA_HAS_EC != 32'd0) begin : g_ec
      m_vlsit_dsig_ec #(
        .PARA_WA           (LPARA_WA)
      ) u_ec (
        .i_clk_core        (i_clk_core),
        .i_rst_n_core      (i_rst_n_core),
        .i_clr             (w_zero),
        .i_start           (w_ec_start),
        .i_vas_start       (w_ec_vas_start),
        .i_run_alg         (w_run_alg),
        .i_run_op          (w_run_op),
        .i_run_hash        (w_run_hash),
        .i_run_len_msg     (w_run_len_msg),
        .i_run_len_ctx     (w_run_len_ctx),
        .i_run_det         (w_run_det),
        .i_run_off_msg     (w_run_off_msg),
        .i_run_off_sig     (w_run_off_sig),
        .i_run_off_pk      (w_run_off_pk),
        .i_run_off_res     (w_run_off_res),
        .o_busy            (w_ec_busy),
        .o_done            (w_ec_done),
        .o_err             (w_ec_err),
        .o_err_flags       (w_ec_err_flags),
        .o_sigok           (w_ec_sigok),
        .o_vas_done        (w_ec_vas_done),
        .o_vas_ok          (w_ec_vas_ok),
        .o_cleared         (w_ec_cleared),
        .i_key             (w_key_store),
        .i_pool            (w_pool),
        .o_rd_en           (w_ec_rd_en),
        .o_rd_addr         (w_ec_rd_addr),
        .i_rd_data         (w_eng_rd_data),
        .i_rd_valid        (w_eng_rd_valid),
        .o_wr_en           (w_ec_wr_en),
        .o_wr_addr         (w_ec_wr_addr),
        .o_wr_data         (w_ec_wr_data),
        .o_wr_strb         (w_ec_wr_strb),
        .o_hs_req          (w_ec_hs_req),
        .i_hs_grant        (w_hq_grant[0]),
        .o_hs_start        (w_ec_hs_start),
        .o_hs_mode         (w_ec_hs_mode),
        .o_hs_outlen       (w_ec_hs_outlen),
        .o_hs_in_valid     (w_ec_hs_in_valid),
        .o_hs_in_data      (w_ec_hs_in_data),
        .o_hs_in_nb        (w_ec_hs_in_nb),
        .o_hs_in_last      (w_ec_hs_in_last),
        .i_hs_in_ready     (w_hq_in_ready[0]),
        .i_hs_out_valid    (w_hq_out_valid[0]),
        .i_hs_out_data     (w_hq_out_data[63:0]),
        .i_hs_out_nb       (w_hq_out_nb[3:0]),
        .i_hs_out_last     (w_hq_out_last[0]),
        .o_hs_out_ready    (w_ec_hs_out_ready)
      );
    end else begin : g_noec
      assign w_ec_busy         = 1'b0;
      assign w_ec_done         = 1'b0;
      assign w_ec_err          = 1'b0;
      assign w_ec_err_flags    = 12'd0;
      assign w_ec_sigok        = 1'b0;
      assign w_ec_vas_done     = 1'b0;
      assign w_ec_vas_ok       = 1'b0;
      assign w_ec_cleared      = 1'b1;
      assign w_ec_rd_en        = 1'b0;
      assign w_ec_rd_addr      = {LPARA_WA{1'b0}};
      assign w_ec_wr_en        = 1'b0;
      assign w_ec_wr_addr      = {LPARA_WA{1'b0}};
      assign w_ec_wr_data      = 64'd0;
      assign w_ec_wr_strb      = 8'd0;
      assign w_ec_hs_req       = 1'b0;
      assign w_ec_hs_start     = 1'b0;
      assign w_ec_hs_mode      = 4'd0;
      assign w_ec_hs_outlen    = 16'd0;
      assign w_ec_hs_in_valid  = 1'b0;
      assign w_ec_hs_in_data   = 64'd0;
      assign w_ec_hs_in_nb     = 4'd0;
      assign w_ec_hs_in_last   = 1'b0;
      assign w_ec_hs_out_ready = 1'b0;
    end
  endgenerate

  // Lattice engine
  generate
    if (LPARA_HAS_LAT != 32'd0) begin : g_lat
      m_vlsit_dsig_lat #(
        .PARA_WA           (LPARA_WA)
      ) u_lat (
        .i_clk_core        (i_clk_core),
        .i_rst_n_core      (i_rst_n_core),
        .i_clr             (w_zero),
        .i_start           (w_lat_start),
        .i_vas_start       (w_lat_vas_start),
        .i_run_alg         (w_run_alg),
        .i_run_op          (w_run_op),
        .i_run_form        (w_run_form),
        .i_run_hedged      (w_run_hedged),
        .i_run_hash        (w_run_hash),
        .i_run_len_msg     (w_run_len_msg),
        .i_run_len_ctx     (w_run_len_ctx),
        .i_run_off_msg     (w_run_off_msg),
        .i_run_off_sig     (w_run_off_sig),
        .i_run_off_pk      (w_run_off_pk),
        .i_run_off_res     (w_run_off_res),
        .o_busy            (w_lat_busy),
        .o_done            (w_lat_done),
        .o_err             (w_lat_err),
        .o_err_flags       (w_lat_err_flags),
        .o_sigok           (w_lat_sigok),
        .o_vas_done        (w_lat_vas_done),
        .o_vas_ok          (w_lat_vas_ok),
        .o_cleared         (w_lat_cleared),
        .i_key             (w_key_store),
        .i_pool            (w_pool),
        .o_rd_en           (w_lat_rd_en),
        .o_rd_addr         (w_lat_rd_addr),
        .i_rd_data         (w_eng_rd_data),
        .i_rd_valid        (w_eng_rd_valid),
        .o_wr_en           (w_lat_wr_en),
        .o_wr_addr         (w_lat_wr_addr),
        .o_wr_data         (w_lat_wr_data),
        .o_wr_strb         (w_lat_wr_strb),
        .o_hs_req          (w_lat_hs_req),
        .i_hs_grant        (w_hq_grant[1]),
        .o_hs_start        (w_lat_hs_start),
        .o_hs_mode         (w_lat_hs_mode),
        .o_hs_outlen       (w_lat_hs_outlen),
        .o_hs_in_valid     (w_lat_hs_in_valid),
        .o_hs_in_data      (w_lat_hs_in_data),
        .o_hs_in_nb        (w_lat_hs_in_nb),
        .o_hs_in_last      (w_lat_hs_in_last),
        .i_hs_in_ready     (w_hq_in_ready[1]),
        .i_hs_out_valid    (w_hq_out_valid[1]),
        .i_hs_out_data     (w_hq_out_data[127:64]),
        .i_hs_out_nb       (w_hq_out_nb[7:4]),
        .i_hs_out_last     (w_hq_out_last[1]),
        .o_hs_out_ready    (w_lat_hs_out_ready)
      );
    end else begin : g_nolat
      assign w_lat_busy         = 1'b0;
      assign w_lat_done         = 1'b0;
      assign w_lat_err          = 1'b0;
      assign w_lat_err_flags    = 12'd0;
      assign w_lat_sigok        = 1'b0;
      assign w_lat_vas_done     = 1'b0;
      assign w_lat_vas_ok       = 1'b0;
      assign w_lat_cleared      = 1'b1;
      assign w_lat_rd_en        = 1'b0;
      assign w_lat_rd_addr      = {LPARA_WA{1'b0}};
      assign w_lat_wr_en        = 1'b0;
      assign w_lat_wr_addr      = {LPARA_WA{1'b0}};
      assign w_lat_wr_data      = 64'd0;
      assign w_lat_wr_strb      = 8'd0;
      assign w_lat_hs_req       = 1'b0;
      assign w_lat_hs_start     = 1'b0;
      assign w_lat_hs_mode      = 4'd0;
      assign w_lat_hs_outlen    = 16'd0;
      assign w_lat_hs_in_valid  = 1'b0;
      assign w_lat_hs_in_data   = 64'd0;
      assign w_lat_hs_in_nb     = 4'd0;
      assign w_lat_hs_in_last   = 1'b0;
      assign w_lat_hs_out_ready = 1'b0;
    end
  endgenerate

  // Hash-based verification engine
  generate
    if (LPARA_HAS_HBS != 32'd0) begin : g_hbs
      m_vlsit_dsig_hbs #(
        .PARA_WA           (LPARA_WA),
        .PARA_EN_SLHDSA    (PARA_EN_SLHDSA),
        .PARA_EN_LMS       (PARA_EN_LMS),
        .PARA_EN_XMSS      (PARA_EN_XMSS)
      ) u_hbs (
        .i_clk_core        (i_clk_core),
        .i_rst_n_core      (i_rst_n_core),
        .i_clr             (w_zero),
        .i_start           (w_hbs_start),
        .i_run_alg         (w_run_alg),
        .i_run_form        (w_run_form),
        .i_run_slh         (w_run_slh),
        .i_run_lmstype     (w_run_lmstype),
        .i_run_lmots       (w_run_lmots),
        .i_run_hsslvl      (w_run_hsslvl),
        .i_run_xmss        (w_run_xmss),
        .i_run_len_msg     (w_run_len_msg),
        .i_run_len_ctx     (w_run_len_ctx),
        .i_run_hash        (w_run_hash),
        .i_run_off_msg     (w_run_off_msg),
        .i_run_off_sig     (w_run_off_sig),
        .i_run_off_pk      (w_run_off_pk),
        .o_busy            (w_hbs_busy),
        .o_done            (w_hbs_done),
        .o_err             (w_hbs_err),
        .o_err_flags       (w_hbs_err_flags),
        .o_sigok           (w_hbs_sigok),
        .o_cleared         (w_hbs_cleared),
        .o_rd_en           (w_hbs_rd_en),
        .o_rd_addr         (w_hbs_rd_addr),
        .i_rd_data         (w_eng_rd_data),
        .i_rd_valid        (w_eng_rd_valid),
        .o_hs_req          (w_hbs_hs_req),
        .i_hs_grant        (w_hq_grant[2]),
        .o_hs_start        (w_hbs_hs_start),
        .o_hs_mode         (w_hbs_hs_mode),
        .o_hs_outlen       (w_hbs_hs_outlen),
        .o_hs_in_valid     (w_hbs_hs_in_valid),
        .o_hs_in_data      (w_hbs_hs_in_data),
        .o_hs_in_nb        (w_hbs_hs_in_nb),
        .o_hs_in_last      (w_hbs_hs_in_last),
        .i_hs_in_ready     (w_hq_in_ready[2]),
        .i_hs_out_valid    (w_hq_out_valid[2]),
        .i_hs_out_data     (w_hq_out_data[191:128]),
        .i_hs_out_nb       (w_hq_out_nb[11:8]),
        .i_hs_out_last     (w_hq_out_last[2]),
        .o_hs_out_ready    (w_hbs_hs_out_ready)
      );
    end else begin : g_nohbs
      assign w_hbs_busy         = 1'b0;
      assign w_hbs_done         = 1'b0;
      assign w_hbs_err          = 1'b0;
      assign w_hbs_err_flags    = 12'd0;
      assign w_hbs_sigok        = 1'b0;
      assign w_hbs_cleared      = 1'b1;
      assign w_hbs_rd_en        = 1'b0;
      assign w_hbs_rd_addr      = {LPARA_WA{1'b0}};
      assign w_hbs_hs_req       = 1'b0;
      assign w_hbs_hs_start     = 1'b0;
      assign w_hbs_hs_mode      = 4'd0;
      assign w_hbs_hs_outlen    = 16'd0;
      assign w_hbs_hs_in_valid  = 1'b0;
      assign w_hbs_hs_in_data   = 64'd0;
      assign w_hbs_hs_in_nb     = 4'd0;
      assign w_hbs_hs_in_last   = 1'b0;
      assign w_hbs_hs_out_ready = 1'b0;
    end
  endgenerate

  // Hash arbiter and stream sequencer
  assign w_hq_req       = {w_hbs_hs_req, w_lat_hs_req, w_ec_hs_req};
  assign w_hq_start     = {w_hbs_hs_start, w_lat_hs_start, w_ec_hs_start};
  assign w_hq_mode      = {w_hbs_hs_mode, w_lat_hs_mode, w_ec_hs_mode};
  assign w_hq_outlen    = {w_hbs_hs_outlen, w_lat_hs_outlen, w_ec_hs_outlen};
  assign w_hq_in_valid  = {w_hbs_hs_in_valid, w_lat_hs_in_valid, w_ec_hs_in_valid};
  assign w_hq_in_data   = {w_hbs_hs_in_data, w_lat_hs_in_data, w_ec_hs_in_data};
  assign w_hq_in_nb     = {w_hbs_hs_in_nb, w_lat_hs_in_nb, w_ec_hs_in_nb};
  assign w_hq_in_last   = {w_hbs_hs_in_last, w_lat_hs_in_last, w_ec_hs_in_last};
  assign w_hq_out_ready = {w_hbs_hs_out_ready, w_lat_hs_out_ready, w_ec_hs_out_ready};

  m_vlsit_dsig_harb #(
    .PARA_NREQ         (3)
  ) u_harb (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_req             (w_hq_req),
    .i_job_start       (w_hq_start),
    .i_job_mode        (w_hq_mode),
    .i_job_outlen      (w_hq_outlen),
    .i_in_valid        (w_hq_in_valid),
    .i_in_data         (w_hq_in_data),
    .i_in_nb           (w_hq_in_nb),
    .i_in_last         (w_hq_in_last),
    .i_out_ready       (w_hq_out_ready),
    .o_grant           (w_hq_grant),
    .o_in_ready        (w_hq_in_ready),
    .o_out_valid       (w_hq_out_valid),
    .o_out_data        (w_hq_out_data),
    .o_out_nb          (w_hq_out_nb),
    .o_out_last        (w_hq_out_last),
    .o_job_start       (w_hs_job_start),
    .o_job_mode        (w_hs_job_mode),
    .o_job_outlen      (w_hs_job_outlen),
    .o_in_valid        (w_hs_in_valid),
    .o_in_data         (w_hs_in_data),
    .o_in_nb           (w_hs_in_nb),
    .o_in_last         (w_hs_in_last),
    .i_in_ready        (w_hs_in_ready),
    .i_out_valid       (w_hs_out_valid),
    .i_out_data        (w_hs_out_data),
    .i_out_nb          (w_hs_out_nb),
    .i_out_last        (w_hs_out_last),
    .o_out_ready       (w_hs_out_ready)
  );

  m_vlsit_dsig_hseq #(
    .PARA_EN_S256      (1),
    .PARA_EN_S512      (1),
    .PARA_EN_KECCAK    (1),
    .PARA_S256_UNR     (PARA_S256_UNR),
    .PARA_S512_UNR     (PARA_S512_UNR),
    .PARA_KEC_UNR      (PARA_KEC_UNR)
  ) u_hseq (
    .i_clk_core        (i_clk_core),
    .i_rst_n_core      (i_rst_n_core),
    .i_clr             (w_zero),
    .i_job_start       (w_hs_job_start),
    .i_job_mode        (w_hs_job_mode),
    .i_job_outlen      (w_hs_job_outlen),
    .i_in_valid        (w_hs_in_valid),
    .i_in_data         (w_hs_in_data),
    .i_in_nb           (w_hs_in_nb),
    .i_in_last         (w_hs_in_last),
    .o_in_ready        (w_hs_in_ready),
    .o_out_valid       (w_hs_out_valid),
    .o_out_data        (w_hs_out_data),
    .o_out_nb          (w_hs_out_nb),
    .o_out_last        (w_hs_out_last),
    .i_out_ready       (w_hs_out_ready),
    .o_busy            ()
  );

endmodule
