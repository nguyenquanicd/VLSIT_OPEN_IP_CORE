/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Engine wrapper of the ChaCha20-Poly1305 IP (section 14.2). It connects the message
 *                sequencer, the key capture, the input and output stream adapters, the keystream
 *                cipher and the Poly1305 block, and the clock-gating module that gates the clock of
 *                the cipher and Poly1305 datapath while no message is active (PARA_CG_EN = 1). With
 *                PARA_CG_EN = 0 the gating enable is held on. All state is in the child modules.
 * Decisions    : DEC-008, DEC-025, DEC-026, DEC-030
 */
`timescale 1ns/1ps

module m_chacha_core #(
  // Parameter Description: number of quarter-round units that work in parallel in one core.
  // Parameter values: 1, 2 or 4; default is 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_QR_NUM = 32'd4,
  // Parameter Description: rounds executed in one clock cycle by one core.
  // Parameter values: 1 or 2; default is 1. The value 2 requires PARA_QR_NUM = 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_RND_CYC = 32'd1,
  // Parameter Description: number of cores that work on different block counters.
  // Parameter values: 1, 2, 4 or 8; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_CORE_NUM = 32'd1,
  // Parameter Description: Poly1305 architecture, 0 product scanning, 1 Karatsuba folded, 2 single
  // cycle multiplier.
  // Parameter values: 0, 1 or 2; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_POLY_ARCH = 32'd1,
  // Parameter Description: data width of the window beat.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  // Parameter Description: depth of the input buffer in beats.
  // Parameter values: power of two from 4 to 4096; default is 16.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_IN_DEPTH = 32'd16,
  // Parameter Description: depth of the output buffer in beats.
  // Parameter values: power of two from 4 to 16384; default is 256.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_OUT_DEPTH = 32'd256,
  // Parameter Description: longest message accepted, in bytes.
  // Parameter values: 64 to 65535; default is 1280.
  // Parameter unit: byte
  parameter logic [31:0] PARA_MSG_MAX_B = 32'd1280,
  // Parameter Description: 1 holds the plaintext of a decryption until the tag matched.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_HOLD_EN = 32'd1,
  // Parameter Description: 0 software nonce, 1 hardware nonce counter for encryption.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_NONCE_HW = 32'd0,
  // Parameter Description: 1 refuses a software nonce equal to the previous one of the key slot.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_NONCE_CHK = 32'd1,
  // Parameter Description: 1 gates the clock of the cipher and Poly1305 datapath while idle.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_CG_EN = 32'd1,
  // Parameter Description: 1 splits the ChaCha20 round loop in two stages with two blocks in
  // flight in each core.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_CHACHA = 32'd0,
  // Parameter Description: 1 splits the Poly1305 multiply-accumulate in two cycles.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_POLY = 32'd0,
  // Parameter Description: 1 registers look-ahead flags in the input stream adapter and the
  // window logic.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_IO = 32'd0
) (
  // Clock, reset and test enable
  input  wire                    i_clk_core,
  input  wire                    i_rst_n_core,
  input  wire                    i_dft_test_en,

  // Register block fields: control, lengths, watermarks, nonce words, salt and nonce counter
  input  wire                    i_cha_ctrl_en,
  input  wire                    i_cha_ctrl_start,
  input  wire                    i_cha_ctrl_dir,
  input  wire                    i_cha_ctrl_abort,
  input  wire                    i_cha_ctrl_dma_en,
  input  wire                    i_cha_ctrl_tail_mode,
  input  wire  [3:0]             i_cha_ctrl_key_slot,
  input  wire  [15:0]            i_cha_len_aad_len,
  input  wire  [15:0]            i_cha_len_msg_len,
  input  wire  [8:0]             i_cha_wm_wm_wr,
  input  wire  [8:0]             i_cha_wm_wm_rd,
  input  wire  [31:0]            i_cha_nonce0_nonce_w,
  input  wire  [31:0]            i_cha_nonce1_nonce_w,
  input  wire  [31:0]            i_cha_nonce2_nonce_w,
  input  wire  [31:0]            i_cha_salt_salt,
  input  wire  [31:0]            i_cha_ctr_lo_ctr,
  input  wire  [31:0]            i_cha_ctr_hi_ctr,

  // Register block hardware loads, events and status
  output logic                   o_hw_we_start,
  output logic                   o_hw_we_abort,
  output logic [31:0]            o_hw_ctr_lo,
  output logic                   o_hw_we_ctr_lo,
  output logic [31:0]            o_hw_ctr_hi,
  output logic                   o_hw_we_ctr_hi,
  output logic                   o_ev_done,
  output logic                   o_ev_tag_err,
  output logic                   o_ev_len_err,
  output logic                   o_ev_axi_err,
  output logic                   o_ev_ctr_err,
  output logic                   o_ev_key_err,
  output logic                   o_sts_busy,
  output logic                   o_sts_ctr_vld,

  // Events from the AXI domain: window error and reset indication
  input  wire                    i_axi_err_evt,
  input  wire                    i_axi_rstd_evt,

  // Key-store port
  output logic                   o_key_req,
  output logic [3:0]             o_key_slot,
  input  wire  [255:0]           i_key_data,
  input  wire                    i_key_vld,
  input  wire                    i_key_err,

  // Input buffer read port and output buffer write port
  output logic                   o_in_rd_en,
  input  wire  [PARA_AXI_DW-1:0] i_in_data,
  input  wire                    i_in_empty,
  output logic                   o_out_wr_en,
  output logic [PARA_AXI_DW-1:0] o_out_wr_data,
  input  wire                    i_out_full,

  // Window buffer flush requests and done pulses
  output logic                   o_flush_in_req,
  output logic                   o_flush_out_req,
  input  wire                    i_flush_in_done,
  input  wire                    i_flush_out_done,

  // Hold gate and message parameters for the DMA request logic
  output logic                   o_out_gate,
  output logic [8:0]             o_dma_wm_wr,
  output logic [8:0]             o_dma_wm_rd,
  output logic                   o_dma_tail_mode,
  output logic                   o_dma_en,
  output logic [16:0]            o_dma_beats_wr,
  output logic [16:0]            o_dma_beats_rd,
  output logic                   o_dma_msg_act,
  output logic [15:0]            o_msg_aad_len,
  output logic [15:0]            o_msg_msg_len,
  output logic                   o_msg_dir
);

  // Interconnect declarations
  logic         w_clk_dp;
  logic         w_cg_en;
  logic         w_dp_clr;
  logic         w_key_req_start;
  logic [3:0]   w_key_slot_cfg;
  logic         w_key_got;
  logic         w_key_err_evt;
  logic [255:0] w_key;
  logic         w_ks_load;
  logic [10:0]  w_ks_total;
  logic [95:0]  w_nonce;
  logic         w_ks_vld;
  logic [511:0] w_ks_blk;
  logic         w_ks_take;
  logic         w_otk_vld;
  logic [255:0] w_otk;
  logic         w_pl_blk_vld;
  logic [127:0] w_pl_blk;
  logic         w_pl_blk_rdy;
  logic         w_pl_fin;
  logic         w_pl_tag_vld;
  logic [127:0] w_pl_tag;
  logic         w_pl_idle;
  logic         w_in_run;
  logic [15:0]  w_in_aad_len;
  logic [15:0]  w_in_msg_len;
  logic         w_in_dir;
  logic         w_chk_vld;
  logic [511:0] w_chk_data;
  logic [6:0]   w_chk_bytes;
  logic [1:0]   w_chk_kind;
  logic         w_chk_last;
  logic         w_chk_take;
  logic         w_eg_vld;
  logic [511:0] w_eg_data;
  logic [6:0]   w_eg_bytes;
  logic         w_eg_rdy;
  logic         w_eg_idle;

  // Message sequencer: owns the state of the message, the events and the control of the datapath.
  m_chacha_ctrl #(
    .PARA_AXI_DW         (PARA_AXI_DW),
    .PARA_FIFO_IN_DEPTH  (PARA_FIFO_IN_DEPTH),
    .PARA_FIFO_OUT_DEPTH (PARA_FIFO_OUT_DEPTH),
    .PARA_MSG_MAX_B      (PARA_MSG_MAX_B),
    .PARA_HOLD_EN        (PARA_HOLD_EN),
    .PARA_NONCE_HW       (PARA_NONCE_HW),
    .PARA_NONCE_CHK      (PARA_NONCE_CHK)
  ) u_ctrl (
    .i_clk_core           (i_clk_core),
    .i_rst_n_core         (i_rst_n_core),
    .i_cha_ctrl_en        (i_cha_ctrl_en),
    .i_cha_ctrl_start     (i_cha_ctrl_start),
    .i_cha_ctrl_dir       (i_cha_ctrl_dir),
    .i_cha_ctrl_abort     (i_cha_ctrl_abort),
    .i_cha_ctrl_dma_en    (i_cha_ctrl_dma_en),
    .i_cha_ctrl_tail_mode (i_cha_ctrl_tail_mode),
    .i_cha_ctrl_key_slot  (i_cha_ctrl_key_slot),
    .i_cha_len_aad_len    (i_cha_len_aad_len),
    .i_cha_len_msg_len    (i_cha_len_msg_len),
    .i_cha_wm_wm_wr       (i_cha_wm_wm_wr),
    .i_cha_wm_wm_rd       (i_cha_wm_wm_rd),
    .i_cha_nonce0_nonce_w (i_cha_nonce0_nonce_w),
    .i_cha_nonce1_nonce_w (i_cha_nonce1_nonce_w),
    .i_cha_nonce2_nonce_w (i_cha_nonce2_nonce_w),
    .i_cha_salt_salt      (i_cha_salt_salt),
    .i_cha_ctr_lo_ctr     (i_cha_ctr_lo_ctr),
    .i_cha_ctr_hi_ctr     (i_cha_ctr_hi_ctr),
    .o_hw_we_start        (o_hw_we_start),
    .o_hw_we_abort        (o_hw_we_abort),
    .o_hw_ctr_lo          (o_hw_ctr_lo),
    .o_hw_we_ctr_lo       (o_hw_we_ctr_lo),
    .o_hw_ctr_hi          (o_hw_ctr_hi),
    .o_hw_we_ctr_hi       (o_hw_we_ctr_hi),
    .o_ev_done            (o_ev_done),
    .o_ev_tag_err         (o_ev_tag_err),
    .o_ev_len_err         (o_ev_len_err),
    .o_ev_axi_err         (o_ev_axi_err),
    .o_ev_ctr_err         (o_ev_ctr_err),
    .o_ev_key_err         (o_ev_key_err),
    .o_sts_busy           (o_sts_busy),
    .o_sts_ctr_vld        (o_sts_ctr_vld),
    .i_axi_err_evt        (i_axi_err_evt),
    .i_axi_rstd_evt       (i_axi_rstd_evt),
    .o_key_req_start      (w_key_req_start),
    .o_key_slot_cfg       (w_key_slot_cfg),
    .i_key_got            (w_key_got),
    .i_key_err_evt        (w_key_err_evt),
    .o_ks_load            (w_ks_load),
    .o_ks_total           (w_ks_total),
    .o_nonce              (w_nonce),
    .i_ks_vld             (w_ks_vld),
    .i_ks_blk             (w_ks_blk),
    .o_ks_take            (w_ks_take),
    .o_otk_vld            (w_otk_vld),
    .o_otk                (w_otk),
    .o_pl_blk_vld         (w_pl_blk_vld),
    .o_pl_blk             (w_pl_blk),
    .i_pl_blk_rdy         (w_pl_blk_rdy),
    .o_pl_fin             (w_pl_fin),
    .i_pl_tag_vld         (w_pl_tag_vld),
    .i_pl_tag             (w_pl_tag),
    .i_pl_idle            (w_pl_idle),
    .o_in_run             (w_in_run),
    .o_in_aad_len         (w_in_aad_len),
    .o_in_msg_len         (w_in_msg_len),
    .o_in_dir             (w_in_dir),
    .i_chk_vld            (w_chk_vld),
    .i_chk_data           (w_chk_data),
    .i_chk_bytes          (w_chk_bytes),
    .i_chk_kind           (w_chk_kind),
    .i_chk_last           (w_chk_last),
    .o_chk_take           (w_chk_take),
    .o_eg_vld             (w_eg_vld),
    .o_eg_data            (w_eg_data),
    .o_eg_bytes           (w_eg_bytes),
    .i_eg_rdy             (w_eg_rdy),
    .i_eg_idle            (w_eg_idle),
    .o_flush_in_req       (o_flush_in_req),
    .o_flush_out_req      (o_flush_out_req),
    .i_flush_in_done      (i_flush_in_done),
    .i_flush_out_done     (i_flush_out_done),
    .o_dp_clr             (w_dp_clr),
    .o_out_gate           (o_out_gate),
    .o_cg_en              (w_cg_en),
    .o_dma_wm_wr          (o_dma_wm_wr),
    .o_dma_wm_rd          (o_dma_wm_rd),
    .o_dma_tail_mode      (o_dma_tail_mode),
    .o_dma_en             (o_dma_en),
    .o_dma_beats_wr       (o_dma_beats_wr),
    .o_dma_beats_rd       (o_dma_beats_rd),
    .o_dma_msg_act        (o_dma_msg_act),
    .o_msg_aad_len        (o_msg_aad_len),
    .o_msg_msg_len        (o_msg_msg_len),
    .o_msg_dir            (o_msg_dir)
  );

  // Key capture: the key-store handshake and the key register.
  m_chacha_key u_key (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (w_dp_clr),
    .i_req_start  (w_key_req_start),
    .i_slot       (w_key_slot_cfg),
    .o_key_req    (o_key_req),
    .o_key_slot   (o_key_slot),
    .i_key_data   (i_key_data),
    .i_key_vld    (i_key_vld),
    .i_key_err    (i_key_err),
    .o_key        (w_key),
    .o_got        (w_key_got),
    .o_err        (w_key_err_evt)
  );

  // Input stream adapter: window beats to chunks of up to 64 bytes.
  m_chacha_ingest #(
    .PARA_AXI_DW  (PARA_AXI_DW),
    .PARA_PIPE_IO (PARA_PIPE_IO)
  ) u_ingest (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (w_dp_clr),
    .i_run        (w_in_run),
    .i_aad_len    (w_in_aad_len),
    .i_msg_len    (w_in_msg_len),
    .i_dir        (w_in_dir),
    .o_in_rd_en   (o_in_rd_en),
    .i_in_data    (i_in_data),
    .i_in_empty   (i_in_empty),
    .o_chk_vld    (w_chk_vld),
    .o_chk_data   (w_chk_data),
    .o_chk_bytes  (w_chk_bytes),
    .o_chk_kind   (w_chk_kind),
    .o_chk_last   (w_chk_last),
    .i_chk_take   (w_chk_take),
    .o_idle       ()
  );

  // Output stream adapter: result chunks and the tag to window beats.
  m_chacha_egress #(
    .PARA_AXI_DW (PARA_AXI_DW)
  ) u_egress (
    .i_clk_core    (i_clk_core),
    .i_rst_n_core  (i_rst_n_core),
    .i_clr         (w_dp_clr),
    .i_chk_vld     (w_eg_vld),
    .i_chk_data    (w_eg_data),
    .i_chk_bytes   (w_eg_bytes),
    .o_chk_rdy     (w_eg_rdy),
    .o_out_wr_en   (o_out_wr_en),
    .o_out_wr_data (o_out_wr_data),
    .i_out_full    (i_out_full),
    .o_idle        (w_eg_idle)
  );

  // Clock-gating module of the datapath. With PARA_CG_EN = 0 the enable is held on.
  m_chacha_clk_gate u_clk_gate (
    .i_clk_core    (i_clk_core),
    .i_en          (w_cg_en | (PARA_CG_EN == 32'd0)),
    .i_dft_test_en (i_dft_test_en),
    .o_clk_gated   (w_clk_dp)
  );

  // Keystream cipher on the gated clock.
  m_chacha_cipher #(
    .PARA_QR_NUM   (PARA_QR_NUM),
    .PARA_RND_CYC  (PARA_RND_CYC),
    .PARA_CORE_NUM (PARA_CORE_NUM),
    .PARA_PIPE_CHACHA (PARA_PIPE_CHACHA)
  ) u_cipher (
    .i_clk_core   (w_clk_dp),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (w_dp_clr),
    .i_load       (w_ks_load),
    .i_total_blk  (w_ks_total),
    .i_key        (w_key),
    .i_nonce      (w_nonce),
    .o_blk_vld    (w_ks_vld),
    .o_blk        (w_ks_blk),
    .i_blk_take   (w_ks_take)
  );

  // Poly1305 authenticator on the gated clock.
  m_chacha_poly #(
    .PARA_POLY_ARCH (PARA_POLY_ARCH),
    .PARA_PIPE_POLY (PARA_PIPE_POLY)
  ) u_poly (
    .i_clk_core   (w_clk_dp),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (w_dp_clr),
    .i_otk_vld    (w_otk_vld),
    .i_otk        (w_otk),
    .i_blk_vld    (w_pl_blk_vld),
    .i_blk        (w_pl_blk),
    .o_blk_rdy    (w_pl_blk_rdy),
    .i_fin        (w_pl_fin),
    .o_tag_vld    (w_pl_tag_vld),
    .o_tag        (w_pl_tag),
    .o_idle       (w_pl_idle)
  );

endmodule
