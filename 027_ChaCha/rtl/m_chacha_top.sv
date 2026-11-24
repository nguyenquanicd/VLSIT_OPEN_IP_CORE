/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Structural top of the ChaCha20-Poly1305 IP (AEAD_CHACHA20_POLY1305 of RFC 8439):
 *                one APB4 configuration port, one AXI4 subordinate data window, two DMA request
 *                and acknowledge pairs, a key-store port, an interrupt output and a test reset.
 *                It holds interconnect and instances only: the reset wrapper, the generated
 *                register block, the engine, the interrupt logic, the message parameter capture,
 *                the DMA request logic, the AXI4 window, the window buffers and the crossings of
 *                the status and event signals between CLK-CORE and CLK-AXI. The relation of the
 *                AXI clock and of the APB clock to the core clock is selected by
 *                PARA_SYNC_AXI_CORE and PARA_SYNC_APB_CORE (section 8); an illegal parameter
 *                combination stops elaboration.
 * Decisions    : DEC-007, DEC-011, DEC-026, DEC-032
 */
`timescale 1ns/1ps

module m_chacha_top #(
  // Parameter Description: number of quarter-round units that work in parallel in one core.
  // Parameter values: 1, 2 or 4; default is 4. PARA_RND_CYC = 2 requires 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_QR_NUM = 32'd4,
  // Parameter Description: rounds executed in one clock cycle by one core.
  // Parameter values: 1 or 2; default is 1. The value 2 requires PARA_QR_NUM = 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_RND_CYC = 32'd1,
  // Parameter Description: number of cores that work on different block counters of one message.
  // Parameter values: 1, 2, 4 or 8; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_CORE_NUM = 32'd1,
  // Parameter Description: Poly1305 architecture: 0 product scanning (22 cycles per block),
  // 1 Karatsuba folded onto one multiplier (5 cycles), 2 one multiplier (1 cycle).
  // Parameter values: 0, 1 or 2; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_POLY_ARCH = 32'd1,
  // Parameter Description: data width of the AXI4 data window.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  // Parameter Description: address width of the AXI4 data window.
  // Parameter values: 12 to 32; default is 12.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_AW = 32'd12,
  // Parameter Description: identifier width of the AXI4 data window.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_IDW = 32'd4,
  // Parameter Description: depth of the input window buffer in beats of PARA_AXI_DW bits.
  // Parameter values: power of two from 4 to 4096; default is 16.
  // Parameter unit: beat
  parameter logic [31:0] PARA_FIFO_IN_DEPTH = 32'd16,
  // Parameter Description: depth of the output window buffer in beats of PARA_AXI_DW bits; with
  // PARA_HOLD_EN = 1 its capacity in bytes shall be at least PARA_MSG_MAX_B.
  // Parameter values: power of two from 4 to 16384; default is 256.
  // Parameter unit: beat
  parameter logic [31:0] PARA_FIFO_OUT_DEPTH = 32'd256,
  // Parameter Description: 0 releases decrypted data as produced, 1 holds it until the tag matched.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_HOLD_EN = 32'd1,
  // Parameter Description: longest message accepted, in bytes; a longer message sets len_err.
  // Parameter values: 64 to 65535; default is 1280.
  // Parameter unit: byte
  parameter logic [31:0] PARA_MSG_MAX_B = 32'd1280,
  // Parameter Description: 0 software nonce, 1 hardware nonce counter for encryption.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_NONCE_HW = 32'd0,
  // Parameter Description: 1 refuses a software nonce equal to the previous one of the key slot.
  // Parameter values: 0 or 1; default is 1. No effect when PARA_NONCE_HW = 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_NONCE_CHK = 32'd1,
  // Parameter Description: 1 when the DMA request and acknowledge pairs exist, 0 when they are
  // tied inactive.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_DMA_EN = 32'd1,
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
  parameter logic [31:0] PARA_PIPE_IO = 32'd0,
  // Parameter Description: 1 when the AXI clock and the core clock are the same clock net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_AXI_CORE = 32'd0,
  // Parameter Description: 1 when the APB clock and the core clock are the same clock net.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_SYNC_APB_CORE = 32'd0,
  localparam logic [31:0] LPARA_IN_THR_W = $clog2(PARA_FIFO_IN_DEPTH) + 32'd1,
  localparam logic [31:0] LPARA_OUT_THR_W = $clog2(PARA_FIFO_OUT_DEPTH) + 32'd1,
  localparam logic [31:0] LPARA_DW_CODE = $clog2(PARA_AXI_DW / 32'd32),
  localparam logic [31:0] LPARA_CORE_LOG = $clog2(PARA_CORE_NUM)
) (
  // Clocks and resets
  input  wire                      i_clk_apb,
  input  wire                      i_rst_n_apb,
  input  wire                      i_clk_axi,
  input  wire                      i_rst_n_axi,
  input  wire                      i_clk_core,
  input  wire                      i_rst_n_core,

  // Test: scan mode enable and test reset
  input  wire                      i_dft_test_en,
  input  wire                      i_dft_rst_n,

  // APB4 configuration interface
  input  wire  [15:0]              i_apb_paddr,
  input  wire  [31:0]              i_apb_pwdata,
  input  wire                      i_apb_pwrite,
  input  wire                      i_apb_penable,
  input  wire                      i_apb_psel,
  input  wire  [3:0]               i_apb_pstrb,
  input  wire  [2:0]               i_apb_pprot,
  output logic                     o_apb_pready,
  output logic                     o_apb_pslverr,
  output logic [31:0]              o_apb_prdata,

  // Protection and error-check enables (static)
  input  wire                      i_protect_en,
  input  wire                      i_slverr_en,

  // AXI4 data window: write address, write data, write response
  input  wire  [PARA_AXI_IDW-1:0]  i_axi_awid,
  input  wire  [PARA_AXI_AW-1:0]   i_axi_awaddr,
  input  wire  [7:0]               i_axi_awlen,
  input  wire  [2:0]               i_axi_awsize,
  input  wire  [1:0]               i_axi_awburst,
  input  wire  [2:0]               i_axi_awprot,
  input  wire                      i_axi_awvalid,
  output logic                     o_axi_awready,
  input  wire  [PARA_AXI_DW-1:0]   i_axi_wdata,
  input  wire  [PARA_AXI_DW/8-1:0] i_axi_wstrb,
  input  wire                      i_axi_wlast,
  input  wire                      i_axi_wvalid,
  output logic                     o_axi_wready,
  output logic [PARA_AXI_IDW-1:0]  o_axi_bid,
  output logic [1:0]               o_axi_bresp,
  output logic                     o_axi_bvalid,
  input  wire                      i_axi_bready,

  // AXI4 data window: read address and read data
  input  wire  [PARA_AXI_IDW-1:0]  i_axi_arid,
  input  wire  [PARA_AXI_AW-1:0]   i_axi_araddr,
  input  wire  [7:0]               i_axi_arlen,
  input  wire  [2:0]               i_axi_arsize,
  input  wire  [1:0]               i_axi_arburst,
  input  wire  [2:0]               i_axi_arprot,
  input  wire                      i_axi_arvalid,
  output logic                     o_axi_arready,
  output logic [PARA_AXI_IDW-1:0]  o_axi_rid,
  output logic [PARA_AXI_DW-1:0]   o_axi_rdata,
  output logic [1:0]               o_axi_rresp,
  output logic                     o_axi_rlast,
  output logic                     o_axi_rvalid,
  input  wire                      i_axi_rready,

  // DMA request and acknowledge pairs
  output logic                     o_dma_req_wr,
  input  wire                      i_dma_ack_wr,
  output logic                     o_dma_req_rd,
  input  wire                      i_dma_ack_rd,

  // Key-store port
  output logic                     o_key_req,
  output logic [3:0]               o_key_slot,
  input  wire  [255:0]             i_key_data,
  input  wire                      i_key_vld,
  input  wire                      i_key_err,

  // Interrupt output
  output logic                     o_int_cha
);

  // Interconnect declarations: resets and constants
  logic                       w_rst_n_apb;
  logic                       w_rst_n_axi;
  logic                       w_rst_n_core;
  logic                       w_axi_rstd_evt;
  logic                       w_zero;
  logic                       w_one;
  logic [15:0]                w_ver_major;
  logic [15:0]                w_ver_minor;
  logic                       w_cap_nonce_hw;
  logic                       w_cap_hold_en;
  logic                       w_cap_dma_en;
  logic [1:0]                 w_cap_dw_code;
  logic [2:0]                 w_cap_core_log;
  // Register block fields and hardware loads
  logic                       w_cha_ctrl_en;
  logic                       w_cha_ctrl_start;
  logic                       w_cha_ctrl_dir;
  logic                       w_cha_ctrl_abort;
  logic                       w_cha_ctrl_dma_en;
  logic                       w_cha_ctrl_tail_mode;
  logic [3:0]                 w_cha_ctrl_key_slot;
  logic [15:0]                w_cha_len_aad_len;
  logic [15:0]                w_cha_len_msg_len;
  logic [8:0]                 w_cha_wm_wm_wr;
  logic [8:0]                 w_cha_wm_wm_rd;
  logic [31:0]                w_cha_nonce0_nonce_w;
  logic [31:0]                w_cha_nonce1_nonce_w;
  logic [31:0]                w_cha_nonce2_nonce_w;
  logic [31:0]                w_cha_salt_salt;
  logic [31:0]                w_cha_ctr_lo_ctr;
  logic [31:0]                w_cha_ctr_hi_ctr;
  logic                       w_hw_we_start;
  logic                       w_hw_we_abort;
  logic [31:0]                w_hw_ctr_lo;
  logic                       w_hw_we_ctr_lo;
  logic [31:0]                w_hw_ctr_hi;
  logic                       w_hw_we_ctr_hi;
  // Events, interrupt bits and status
  logic [5:0]                 w_ev;
  logic [5:0]                 w_irq_raw;
  logic [5:0]                 w_irq_en;
  logic [5:0]                 w_irq_inj;
  logic [5:0]                 w_irq_sts;
  logic [5:0]                 w_irq_load;
  logic                       w_sts_busy;
  logic                       w_sts_ctr_vld;
  logic                       w_sts_in_rdy;
  logic                       w_sts_out_rdy;
  logic                       w_in_rdy_axi;
  logic                       w_out_rdy_axi;
  // Engine to buffer and crossing signals
  logic                       w_axi_err_axi;
  logic                       w_axi_err_core;
  logic                       w_in_rd_en;
  logic [PARA_AXI_DW-1:0]     w_in_rd_data;
  logic                       w_in_empty;
  logic                       w_out_wr_en;
  logic [PARA_AXI_DW-1:0]     w_out_wr_data;
  logic                       w_out_full;
  logic                       w_flush_in_req;
  logic                       w_flush_out_req;
  logic                       w_flush_in_done;
  logic                       w_flush_out_done;
  logic                       w_out_gate;
  // Message parameters from the core and their copy in CLK-AXI
  logic [8:0]                 w_dma_wm_wr;
  logic [8:0]                 w_dma_wm_rd;
  logic                       w_dma_tail_mode;
  logic                       w_dma_en;
  logic [16:0]                w_dma_beats_wr;
  logic [16:0]                w_dma_beats_rd;
  logic                       w_dma_msg_act;
  logic [15:0]                w_msg_aad_len;
  logic [15:0]                w_msg_msg_len;
  logic                       w_msg_dir;
  logic                       w_cap_start;
  logic                       w_cap_act;
  logic                       w_cap_dma_en_axi;
  logic [8:0]                 w_cap_wm_wr;
  logic [8:0]                 w_cap_wm_rd;
  logic                       w_cap_tail;
  logic [16:0]                w_cap_beats_wr;
  logic [16:0]                w_cap_beats_rd;
  logic [15:0]                w_cap_aad_len;
  logic [15:0]                w_cap_msg_len;
  logic                       w_cap_dir;
  // Window buffer flags and thresholds
  logic                       w_in_full;
  logic [LPARA_IN_THR_W-1:0]  w_in_full_thr_val;
  logic                       w_in_full_thr_flag;
  logic [PARA_AXI_DW-1:0]     w_out_rd_data;
  logic                       w_out_rd_en;
  logic                       w_out_empty;
  logic [LPARA_OUT_THR_W-1:0] w_out_empty_thr_val;
  logic                       w_out_empty_thr_flag;
  logic                       w_in_wr_en;
  logic [PARA_AXI_DW-1:0]     w_in_wr_data;

  // Elaboration checks (REQ-PARAM-001): an illegal combination instantiates a module that does
  // not exist, so elaboration stops with the name of the violated rule (no system task is used,
  // rule P14). Illegal: two rounds per cycle without four quarter-round units, a data width that
  // is not a multiple of 32, a FIFO depth that is not a power of two, and hold mode with an
  // output capacity below PARA_MSG_MAX_B.
  if ((PARA_RND_CYC == 32'd2) & (PARA_QR_NUM != 32'd4)) begin : gen_chk_rnd
    m_chacha_illegal_para_rnd_needs_qr4 u_illegal ();
  end
  if ((PARA_AXI_DW % 32'd32) != 32'd0) begin : gen_chk_dw
    m_chacha_illegal_para_dw_not_x32 u_illegal ();
  end
  if (((PARA_FIFO_IN_DEPTH & (PARA_FIFO_IN_DEPTH - 32'd1)) != 32'd0) |
      ((PARA_FIFO_OUT_DEPTH & (PARA_FIFO_OUT_DEPTH - 32'd1)) != 32'd0)) begin : gen_chk_depth
    m_chacha_illegal_para_depth_pow2 u_illegal ();
  end
  if ((PARA_HOLD_EN == 32'd1) & (PARA_FIFO_OUT_DEPTH * (PARA_AXI_DW / 32'd8) < PARA_MSG_MAX_B)) begin : gen_chk_hold
    m_chacha_illegal_para_hold_buf u_illegal ();
  end

  // Constants of the register block: the version (major 1, minor 0), the capability fields and
  // the constant levels for hardware loads.
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd1),  .PARA_TIE_VALUE (32'd0)) u_tie_zero (.o_tie (w_zero));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd1),  .PARA_TIE_VALUE (32'd1)) u_tie_one (.o_tie (w_one));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd16), .PARA_TIE_VALUE (32'd1)) u_tie_major (.o_tie (w_ver_major));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd16), .PARA_TIE_VALUE (32'd0)) u_tie_minor (.o_tie (w_ver_minor));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd1),  .PARA_TIE_VALUE (PARA_NONCE_HW)) u_tie_nonce_hw (.o_tie (w_cap_nonce_hw));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd1),  .PARA_TIE_VALUE (PARA_HOLD_EN)) u_tie_hold_en (.o_tie (w_cap_hold_en));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd1),  .PARA_TIE_VALUE (PARA_DMA_EN)) u_tie_dma_en (.o_tie (w_cap_dma_en));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd2),  .PARA_TIE_VALUE (LPARA_DW_CODE)) u_tie_dw_code (.o_tie (w_cap_dw_code));
  m_vlsit_tie #(.PARA_TIE_WIDTH (32'd3),  .PARA_TIE_VALUE (LPARA_CORE_LOG)) u_tie_core_log (.o_tie (w_cap_core_log));

  // Reset wrapper: synchronized resets with the test override, and the AXI reset indication.
  m_chacha_rst_ctrl #(
    .PARA_SYNC_AXI_CORE (PARA_SYNC_AXI_CORE)
  ) u_rst (
    .i_clk_apb      (i_clk_apb),
    .i_clk_axi      (i_clk_axi),
    .i_clk_core     (i_clk_core),
    .i_rst_n_apb    (i_rst_n_apb),
    .i_rst_n_axi    (i_rst_n_axi),
    .i_rst_n_core   (i_rst_n_core),
    .i_dft_test_en  (i_dft_test_en),
    .i_dft_rst_n    (i_dft_rst_n),
    .o_rst_n_apb    (w_rst_n_apb),
    .o_rst_n_axi    (w_rst_n_axi),
    .o_rst_n_core   (w_rst_n_core),
    .o_axi_rstd_evt (w_axi_rstd_evt)
  );

  // Register block generated from the workbook. The register clock is the core clock with the
  // asynchronous adapter, or the APB clock with a common clock net (rule R-083).
  if (PARA_SYNC_APB_CORE == 32'd0) begin : gen_csr_async
    m_vlsit_csr_chacha #(
      .PARA_ASYNCHRONOUS (32'd1)
    ) u_csr (
      .i_clk_reg                      (i_clk_core),
      .i_rst_n_reg                    (w_rst_n_core),
      .i_clk_apb                      (i_clk_apb),
      .i_rst_n_apb                    (w_rst_n_apb),
      .i_apb_psel                     (i_apb_psel),
      .i_apb_penable                  (i_apb_penable),
      .i_apb_pwrite                   (i_apb_pwrite),
      .i_apb_paddr                    (i_apb_paddr),
      .i_apb_pwdata                   (i_apb_pwdata),
      .i_apb_pstrb                    (i_apb_pstrb),
      .i_apb_pprot                    (i_apb_pprot),
      .o_apb_pready                   (o_apb_pready),
      .o_apb_pslverr                  (o_apb_pslverr),
      .o_apb_prdata                   (o_apb_prdata),
      .i_protect_en                   (i_protect_en),
      .i_slverr_en                    (i_slverr_en),
      .i_cha_version_major            (w_ver_major),
      .i_cha_version_minor            (w_ver_minor),
      .o_cha_ctrl_key_slot            (w_cha_ctrl_key_slot),
      .o_cha_ctrl_tail_mode           (w_cha_ctrl_tail_mode),
      .o_cha_ctrl_dma_en              (w_cha_ctrl_dma_en),
      .o_cha_ctrl_abort               (w_cha_ctrl_abort),
      .i_hw_wdata_cha_ctrl_abort      (w_zero),
      .i_hw_we_cha_ctrl_abort         (w_hw_we_abort),
      .o_cha_ctrl_dir                 (w_cha_ctrl_dir),
      .o_cha_ctrl_start               (w_cha_ctrl_start),
      .i_hw_wdata_cha_ctrl_start      (w_zero),
      .i_hw_we_cha_ctrl_start         (w_hw_we_start),
      .o_cha_ctrl_en                  (w_cha_ctrl_en),
      .o_cha_len_msg_len              (w_cha_len_msg_len),
      .o_cha_len_aad_len              (w_cha_len_aad_len),
      .o_cha_wm_wm_rd                 (w_cha_wm_wm_rd),
      .o_cha_wm_wm_wr                 (w_cha_wm_wm_wr),
      .o_cha_nonce0_nonce_w           (w_cha_nonce0_nonce_w),
      .o_cha_nonce1_nonce_w           (w_cha_nonce1_nonce_w),
      .o_cha_nonce2_nonce_w           (w_cha_nonce2_nonce_w),
      .o_cha_salt_salt                (w_cha_salt_salt),
      .o_cha_ctr_lo_ctr               (w_cha_ctr_lo_ctr),
      .i_hw_wdata_cha_ctr_lo_ctr      (w_hw_ctr_lo),
      .i_hw_we_cha_ctr_lo_ctr         (w_hw_we_ctr_lo),
      .o_cha_ctr_hi_ctr               (w_cha_ctr_hi_ctr),
      .i_hw_wdata_cha_ctr_hi_ctr      (w_hw_ctr_hi),
      .i_hw_we_cha_ctr_hi_ctr         (w_hw_we_ctr_hi),
      .i_cha_sts_ctr_vld              (w_sts_ctr_vld),
      .i_cha_sts_out_rdy              (w_sts_out_rdy),
      .i_cha_sts_in_rdy               (w_sts_in_rdy),
      .i_cha_sts_busy                 (w_sts_busy),
      .o_cha_irq_raw_key_err          (w_irq_raw[5]),
      .i_hw_wdata_cha_irq_raw_key_err (w_one),
      .i_hw_we_cha_irq_raw_key_err    (w_irq_load[5]),
      .o_cha_irq_raw_ctr_err          (w_irq_raw[4]),
      .i_hw_wdata_cha_irq_raw_ctr_err (w_one),
      .i_hw_we_cha_irq_raw_ctr_err    (w_irq_load[4]),
      .o_cha_irq_raw_axi_err          (w_irq_raw[3]),
      .i_hw_wdata_cha_irq_raw_axi_err (w_one),
      .i_hw_we_cha_irq_raw_axi_err    (w_irq_load[3]),
      .o_cha_irq_raw_len_err          (w_irq_raw[2]),
      .i_hw_wdata_cha_irq_raw_len_err (w_one),
      .i_hw_we_cha_irq_raw_len_err    (w_irq_load[2]),
      .o_cha_irq_raw_tag_err          (w_irq_raw[1]),
      .i_hw_wdata_cha_irq_raw_tag_err (w_one),
      .i_hw_we_cha_irq_raw_tag_err    (w_irq_load[1]),
      .o_cha_irq_raw_done             (w_irq_raw[0]),
      .i_hw_wdata_cha_irq_raw_done    (w_one),
      .i_hw_we_cha_irq_raw_done       (w_irq_load[0]),
      .o_cha_irq_en_key_err           (w_irq_en[5]),
      .o_cha_irq_en_ctr_err           (w_irq_en[4]),
      .o_cha_irq_en_axi_err           (w_irq_en[3]),
      .o_cha_irq_en_len_err           (w_irq_en[2]),
      .o_cha_irq_en_tag_err           (w_irq_en[1]),
      .o_cha_irq_en_done              (w_irq_en[0]),
      .o_cha_irq_inj_key_err          (w_irq_inj[5]),
      .o_cha_irq_inj_ctr_err          (w_irq_inj[4]),
      .o_cha_irq_inj_axi_err          (w_irq_inj[3]),
      .o_cha_irq_inj_len_err          (w_irq_inj[2]),
      .o_cha_irq_inj_tag_err          (w_irq_inj[1]),
      .o_cha_irq_inj_done             (w_irq_inj[0]),
      .i_cha_irq_sts_key_err          (w_irq_sts[5]),
      .i_cha_irq_sts_ctr_err          (w_irq_sts[4]),
      .i_cha_irq_sts_axi_err          (w_irq_sts[3]),
      .i_cha_irq_sts_len_err          (w_irq_sts[2]),
      .i_cha_irq_sts_tag_err          (w_irq_sts[1]),
      .i_cha_irq_sts_done             (w_irq_sts[0]),
      .i_cha_cap_core_log             (w_cap_core_log),
      .i_cha_cap_dw_code              (w_cap_dw_code),
      .i_cha_cap_dma_en               (w_cap_dma_en),
      .i_cha_cap_hold_en              (w_cap_hold_en),
      .i_cha_cap_nonce_hw             (w_cap_nonce_hw)
    );
  end else begin : gen_csr_sync
    m_vlsit_csr_chacha #(
      .PARA_ASYNCHRONOUS (32'd0)
    ) u_csr (
      .i_clk_reg                      (i_clk_apb),
      .i_rst_n_reg                    (w_rst_n_apb),
      .i_clk_apb                      (i_clk_apb),
      .i_rst_n_apb                    (w_rst_n_apb),
      .i_apb_psel                     (i_apb_psel),
      .i_apb_penable                  (i_apb_penable),
      .i_apb_pwrite                   (i_apb_pwrite),
      .i_apb_paddr                    (i_apb_paddr),
      .i_apb_pwdata                   (i_apb_pwdata),
      .i_apb_pstrb                    (i_apb_pstrb),
      .i_apb_pprot                    (i_apb_pprot),
      .o_apb_pready                   (o_apb_pready),
      .o_apb_pslverr                  (o_apb_pslverr),
      .o_apb_prdata                   (o_apb_prdata),
      .i_protect_en                   (i_protect_en),
      .i_slverr_en                    (i_slverr_en),
      .i_cha_version_major            (w_ver_major),
      .i_cha_version_minor            (w_ver_minor),
      .o_cha_ctrl_key_slot            (w_cha_ctrl_key_slot),
      .o_cha_ctrl_tail_mode           (w_cha_ctrl_tail_mode),
      .o_cha_ctrl_dma_en              (w_cha_ctrl_dma_en),
      .o_cha_ctrl_abort               (w_cha_ctrl_abort),
      .i_hw_wdata_cha_ctrl_abort      (w_zero),
      .i_hw_we_cha_ctrl_abort         (w_hw_we_abort),
      .o_cha_ctrl_dir                 (w_cha_ctrl_dir),
      .o_cha_ctrl_start               (w_cha_ctrl_start),
      .i_hw_wdata_cha_ctrl_start      (w_zero),
      .i_hw_we_cha_ctrl_start         (w_hw_we_start),
      .o_cha_ctrl_en                  (w_cha_ctrl_en),
      .o_cha_len_msg_len              (w_cha_len_msg_len),
      .o_cha_len_aad_len              (w_cha_len_aad_len),
      .o_cha_wm_wm_rd                 (w_cha_wm_wm_rd),
      .o_cha_wm_wm_wr                 (w_cha_wm_wm_wr),
      .o_cha_nonce0_nonce_w           (w_cha_nonce0_nonce_w),
      .o_cha_nonce1_nonce_w           (w_cha_nonce1_nonce_w),
      .o_cha_nonce2_nonce_w           (w_cha_nonce2_nonce_w),
      .o_cha_salt_salt                (w_cha_salt_salt),
      .o_cha_ctr_lo_ctr               (w_cha_ctr_lo_ctr),
      .i_hw_wdata_cha_ctr_lo_ctr      (w_hw_ctr_lo),
      .i_hw_we_cha_ctr_lo_ctr         (w_hw_we_ctr_lo),
      .o_cha_ctr_hi_ctr               (w_cha_ctr_hi_ctr),
      .i_hw_wdata_cha_ctr_hi_ctr      (w_hw_ctr_hi),
      .i_hw_we_cha_ctr_hi_ctr         (w_hw_we_ctr_hi),
      .i_cha_sts_ctr_vld              (w_sts_ctr_vld),
      .i_cha_sts_out_rdy              (w_sts_out_rdy),
      .i_cha_sts_in_rdy               (w_sts_in_rdy),
      .i_cha_sts_busy                 (w_sts_busy),
      .o_cha_irq_raw_key_err          (w_irq_raw[5]),
      .i_hw_wdata_cha_irq_raw_key_err (w_one),
      .i_hw_we_cha_irq_raw_key_err    (w_irq_load[5]),
      .o_cha_irq_raw_ctr_err          (w_irq_raw[4]),
      .i_hw_wdata_cha_irq_raw_ctr_err (w_one),
      .i_hw_we_cha_irq_raw_ctr_err    (w_irq_load[4]),
      .o_cha_irq_raw_axi_err          (w_irq_raw[3]),
      .i_hw_wdata_cha_irq_raw_axi_err (w_one),
      .i_hw_we_cha_irq_raw_axi_err    (w_irq_load[3]),
      .o_cha_irq_raw_len_err          (w_irq_raw[2]),
      .i_hw_wdata_cha_irq_raw_len_err (w_one),
      .i_hw_we_cha_irq_raw_len_err    (w_irq_load[2]),
      .o_cha_irq_raw_tag_err          (w_irq_raw[1]),
      .i_hw_wdata_cha_irq_raw_tag_err (w_one),
      .i_hw_we_cha_irq_raw_tag_err    (w_irq_load[1]),
      .o_cha_irq_raw_done             (w_irq_raw[0]),
      .i_hw_wdata_cha_irq_raw_done    (w_one),
      .i_hw_we_cha_irq_raw_done       (w_irq_load[0]),
      .o_cha_irq_en_key_err           (w_irq_en[5]),
      .o_cha_irq_en_ctr_err           (w_irq_en[4]),
      .o_cha_irq_en_axi_err           (w_irq_en[3]),
      .o_cha_irq_en_len_err           (w_irq_en[2]),
      .o_cha_irq_en_tag_err           (w_irq_en[1]),
      .o_cha_irq_en_done              (w_irq_en[0]),
      .o_cha_irq_inj_key_err          (w_irq_inj[5]),
      .o_cha_irq_inj_ctr_err          (w_irq_inj[4]),
      .o_cha_irq_inj_axi_err          (w_irq_inj[3]),
      .o_cha_irq_inj_len_err          (w_irq_inj[2]),
      .o_cha_irq_inj_tag_err          (w_irq_inj[1]),
      .o_cha_irq_inj_done             (w_irq_inj[0]),
      .i_cha_irq_sts_key_err          (w_irq_sts[5]),
      .i_cha_irq_sts_ctr_err          (w_irq_sts[4]),
      .i_cha_irq_sts_axi_err          (w_irq_sts[3]),
      .i_cha_irq_sts_len_err          (w_irq_sts[2]),
      .i_cha_irq_sts_tag_err          (w_irq_sts[1]),
      .i_cha_irq_sts_done             (w_irq_sts[0]),
      .i_cha_cap_core_log             (w_cap_core_log),
      .i_cha_cap_dw_code              (w_cap_dw_code),
      .i_cha_cap_dma_en               (w_cap_dma_en),
      .i_cha_cap_hold_en              (w_cap_hold_en),
      .i_cha_cap_nonce_hw             (w_cap_nonce_hw)
    );
  end

  // Engine: sequencer, key capture, stream adapters, cipher and Poly1305 in CLK-CORE.
  m_chacha_core #(
    .PARA_QR_NUM         (PARA_QR_NUM),
    .PARA_RND_CYC        (PARA_RND_CYC),
    .PARA_CORE_NUM       (PARA_CORE_NUM),
    .PARA_POLY_ARCH      (PARA_POLY_ARCH),
    .PARA_AXI_DW         (PARA_AXI_DW),
    .PARA_FIFO_IN_DEPTH  (PARA_FIFO_IN_DEPTH),
    .PARA_FIFO_OUT_DEPTH (PARA_FIFO_OUT_DEPTH),
    .PARA_MSG_MAX_B      (PARA_MSG_MAX_B),
    .PARA_HOLD_EN        (PARA_HOLD_EN),
    .PARA_NONCE_HW       (PARA_NONCE_HW),
    .PARA_NONCE_CHK      (PARA_NONCE_CHK),
    .PARA_CG_EN          (PARA_CG_EN),
    .PARA_PIPE_CHACHA    (PARA_PIPE_CHACHA),
    .PARA_PIPE_POLY      (PARA_PIPE_POLY),
    .PARA_PIPE_IO        (PARA_PIPE_IO)
  ) u_core (
    .i_clk_core           (i_clk_core),
    .i_rst_n_core         (w_rst_n_core),
    .i_dft_test_en        (i_dft_test_en),
    .i_cha_ctrl_en        (w_cha_ctrl_en),
    .i_cha_ctrl_start     (w_cha_ctrl_start),
    .i_cha_ctrl_dir       (w_cha_ctrl_dir),
    .i_cha_ctrl_abort     (w_cha_ctrl_abort),
    .i_cha_ctrl_dma_en    (w_cha_ctrl_dma_en),
    .i_cha_ctrl_tail_mode (w_cha_ctrl_tail_mode),
    .i_cha_ctrl_key_slot  (w_cha_ctrl_key_slot),
    .i_cha_len_aad_len    (w_cha_len_aad_len),
    .i_cha_len_msg_len    (w_cha_len_msg_len),
    .i_cha_wm_wm_wr       (w_cha_wm_wm_wr),
    .i_cha_wm_wm_rd       (w_cha_wm_wm_rd),
    .i_cha_nonce0_nonce_w (w_cha_nonce0_nonce_w),
    .i_cha_nonce1_nonce_w (w_cha_nonce1_nonce_w),
    .i_cha_nonce2_nonce_w (w_cha_nonce2_nonce_w),
    .i_cha_salt_salt      (w_cha_salt_salt),
    .i_cha_ctr_lo_ctr     (w_cha_ctr_lo_ctr),
    .i_cha_ctr_hi_ctr     (w_cha_ctr_hi_ctr),
    .o_hw_we_start        (w_hw_we_start),
    .o_hw_we_abort        (w_hw_we_abort),
    .o_hw_ctr_lo          (w_hw_ctr_lo),
    .o_hw_we_ctr_lo       (w_hw_we_ctr_lo),
    .o_hw_ctr_hi          (w_hw_ctr_hi),
    .o_hw_we_ctr_hi       (w_hw_we_ctr_hi),
    .o_ev_done            (w_ev[0]),
    .o_ev_tag_err         (w_ev[1]),
    .o_ev_len_err         (w_ev[2]),
    .o_ev_axi_err         (w_ev[3]),
    .o_ev_ctr_err         (w_ev[4]),
    .o_ev_key_err         (w_ev[5]),
    .o_sts_busy           (w_sts_busy),
    .o_sts_ctr_vld        (w_sts_ctr_vld),
    .i_axi_err_evt        (w_axi_err_core),
    .i_axi_rstd_evt       (w_axi_rstd_evt),
    .o_key_req            (o_key_req),
    .o_key_slot           (o_key_slot),
    .i_key_data           (i_key_data),
    .i_key_vld            (i_key_vld),
    .i_key_err            (i_key_err),
    .o_in_rd_en           (w_in_rd_en),
    .i_in_data            (w_in_rd_data),
    .i_in_empty           (w_in_empty),
    .o_out_wr_en          (w_out_wr_en),
    .o_out_wr_data        (w_out_wr_data),
    .i_out_full           (w_out_full),
    .o_flush_in_req       (w_flush_in_req),
    .o_flush_out_req      (w_flush_out_req),
    .i_flush_in_done      (w_flush_in_done),
    .i_flush_out_done     (w_flush_out_done),
    .o_out_gate           (w_out_gate),
    .o_dma_wm_wr          (w_dma_wm_wr),
    .o_dma_wm_rd          (w_dma_wm_rd),
    .o_dma_tail_mode      (w_dma_tail_mode),
    .o_dma_en             (w_dma_en),
    .o_dma_beats_wr       (w_dma_beats_wr),
    .o_dma_beats_rd       (w_dma_beats_rd),
    .o_dma_msg_act        (w_dma_msg_act),
    .o_msg_aad_len        (w_msg_aad_len),
    .o_msg_msg_len        (w_msg_msg_len),
    .o_msg_dir            (w_msg_dir)
  );

  // Interrupt logic: loading events with the injection edge, masked status, interrupt output.
  m_chacha_int #(
    .PARA_SYNC_APB_CORE (PARA_SYNC_APB_CORE)
  ) u_int (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (w_rst_n_core),
    .i_ev         (w_ev),
    .i_irq_inj    (w_irq_inj),
    .i_irq_raw    (w_irq_raw),
    .i_irq_en     (w_irq_en),
    .o_irq_load   (w_irq_load),
    .o_irq_sts    (w_irq_sts),
    .i_clk_apb    (i_clk_apb),
    .i_rst_n_apb  (w_rst_n_apb),
    .o_int_cha    (o_int_cha)
  );

  // Message parameter capture in CLK-AXI.
  m_chacha_msg_cap #(
    .PARA_SYNC_AXI_CORE (PARA_SYNC_AXI_CORE)
  ) u_msg_cap (
    .i_clk_axi    (i_clk_axi),
    .i_rst_n_axi  (w_rst_n_axi),
    .i_msg_act    (w_dma_msg_act),
    .i_dma_en     (w_dma_en),
    .i_wm_wr      (w_dma_wm_wr),
    .i_wm_rd      (w_dma_wm_rd),
    .i_tail_mode  (w_dma_tail_mode),
    .i_beats_wr   (w_dma_beats_wr),
    .i_beats_rd   (w_dma_beats_rd),
    .i_aad_len    (w_msg_aad_len),
    .i_msg_len    (w_msg_msg_len),
    .i_dir        (w_msg_dir),
    .o_start      (w_cap_start),
    .o_act        (w_cap_act),
    .o_dma_en     (w_cap_dma_en_axi),
    .o_wm_wr      (w_cap_wm_wr),
    .o_wm_rd      (w_cap_wm_rd),
    .o_tail_mode  (w_cap_tail),
    .o_beats_wr   (w_cap_beats_wr),
    .o_beats_rd   (w_cap_beats_rd),
    .o_aad_len    (w_cap_aad_len),
    .o_msg_len    (w_cap_msg_len),
    .o_dir        (w_cap_dir)
  );

  // DMA request logic in CLK-AXI.
  m_chacha_dma_req #(
    .PARA_DMA_EN         (PARA_DMA_EN),
    .PARA_FIFO_IN_DEPTH  (PARA_FIFO_IN_DEPTH),
    .PARA_FIFO_OUT_DEPTH (PARA_FIFO_OUT_DEPTH)
  ) u_dma_req (
    .i_clk_axi            (i_clk_axi),
    .i_rst_n_axi          (w_rst_n_axi),
    .i_start              (w_cap_start),
    .i_act                (w_cap_act),
    .i_dma_en             (w_cap_dma_en_axi),
    .i_wm_wr              (w_cap_wm_wr),
    .i_wm_rd              (w_cap_wm_rd),
    .i_tail_mode          (w_cap_tail),
    .i_beats_wr           (w_cap_beats_wr),
    .i_beats_rd           (w_cap_beats_rd),
    .o_in_full_thr        (w_in_full_thr_val),
    .i_in_full_thr_flag   (w_in_full_thr_flag),
    .o_out_empty_thr      (w_out_empty_thr_val),
    .i_out_empty_thr_flag (w_out_empty_thr_flag),
    .i_out_empty          (w_out_empty),
    .o_dma_req_wr         (o_dma_req_wr),
    .i_dma_ack_wr         (i_dma_ack_wr),
    .o_dma_req_rd         (o_dma_req_rd),
    .i_dma_ack_rd         (i_dma_ack_rd),
    .o_in_rdy             (w_in_rdy_axi),
    .o_out_rdy            (w_out_rdy_axi)
  );

  // AXI4 data window.
  m_chacha_axi_win #(
    .PARA_AXI_DW  (PARA_AXI_DW),
    .PARA_AXI_AW  (PARA_AXI_AW),
    .PARA_AXI_IDW (PARA_AXI_IDW),
    .PARA_PIPE_IO (PARA_PIPE_IO)
  ) u_axi_win (
    .i_clk_axi      (i_clk_axi),
    .i_rst_n_axi    (w_rst_n_axi),
    .i_axi_awid     (i_axi_awid),
    .i_axi_awaddr   (i_axi_awaddr),
    .i_axi_awlen    (i_axi_awlen),
    .i_axi_awsize   (i_axi_awsize),
    .i_axi_awburst  (i_axi_awburst),
    .i_axi_awprot   (i_axi_awprot),
    .i_axi_awvalid  (i_axi_awvalid),
    .o_axi_awready  (o_axi_awready),
    .i_axi_wdata    (i_axi_wdata),
    .i_axi_wstrb    (i_axi_wstrb),
    .i_axi_wlast    (i_axi_wlast),
    .i_axi_wvalid   (i_axi_wvalid),
    .o_axi_wready   (o_axi_wready),
    .o_axi_bid      (o_axi_bid),
    .o_axi_bresp    (o_axi_bresp),
    .o_axi_bvalid   (o_axi_bvalid),
    .i_axi_bready   (i_axi_bready),
    .i_axi_arid     (i_axi_arid),
    .i_axi_araddr   (i_axi_araddr),
    .i_axi_arlen    (i_axi_arlen),
    .i_axi_arsize   (i_axi_arsize),
    .i_axi_arburst  (i_axi_arburst),
    .i_axi_arprot   (i_axi_arprot),
    .i_axi_arvalid  (i_axi_arvalid),
    .o_axi_arready  (o_axi_arready),
    .o_axi_rid      (o_axi_rid),
    .o_axi_rdata    (o_axi_rdata),
    .o_axi_rresp    (o_axi_rresp),
    .o_axi_rlast    (o_axi_rlast),
    .o_axi_rvalid   (o_axi_rvalid),
    .i_axi_rready   (i_axi_rready),
    .i_protect_en   (i_protect_en),
    .i_start        (w_cap_start),
    .i_act          (w_cap_act),
    .i_aad_len      (w_cap_aad_len),
    .i_msg_len      (w_cap_msg_len),
    .i_dir          (w_cap_dir),
    .o_in_wr_en     (w_in_wr_en),
    .o_in_wr_data   (w_in_wr_data),
    .i_in_full      (w_in_full),
    .o_out_rd_en    (w_out_rd_en),
    .i_out_rd_data  (w_out_rd_data),
    .i_out_empty    (w_out_empty),
    .o_err_evt      (w_axi_err_axi)
  );

  // Window buffers: input buffer (AXI to core) and output buffer (core to AXI) with the flush
  // machines and the hold gate.
  m_chacha_win_buf #(
    .PARA_AXI_DW         (PARA_AXI_DW),
    .PARA_FIFO_IN_DEPTH  (PARA_FIFO_IN_DEPTH),
    .PARA_FIFO_OUT_DEPTH (PARA_FIFO_OUT_DEPTH),
    .PARA_SYNC_AXI_CORE  (PARA_SYNC_AXI_CORE)
  ) u_win_buf (
    .i_clk_axi        (i_clk_axi),
    .i_rst_n_axi      (w_rst_n_axi),
    .i_in_wr_en       (w_in_wr_en),
    .i_in_wr_data     (w_in_wr_data),
    .o_in_full        (w_in_full),
    .i_in_full_thr    (w_in_full_thr_val),
    .o_in_full_thr    (w_in_full_thr_flag),
    .i_out_rd_en      (w_out_rd_en),
    .o_out_rd_data    (w_out_rd_data),
    .o_out_empty      (w_out_empty),
    .i_out_empty_thr  (w_out_empty_thr_val),
    .o_out_empty_thr  (w_out_empty_thr_flag),
    .i_clk_core       (i_clk_core),
    .i_rst_n_core     (w_rst_n_core),
    .i_in_rd_en       (w_in_rd_en),
    .o_in_rd_data     (w_in_rd_data),
    .o_in_empty       (w_in_empty),
    .i_out_wr_en      (w_out_wr_en),
    .i_out_wr_data    (w_out_wr_data),
    .o_out_full       (w_out_full),
    .i_flush_in_req   (w_flush_in_req),
    .i_flush_out_req  (w_flush_out_req),
    .o_flush_in_done  (w_flush_in_done),
    .o_flush_out_done (w_flush_out_done),
    .i_out_gate       (w_out_gate)
  );

  // Crossings of the data window error event and of the polling status from CLK-AXI to CLK-CORE.
  if (PARA_SYNC_AXI_CORE == 32'd0) begin : gen_cdc
    m_vlsit_event_sync #(
      .PARA_EVENT_SYNC_W         (32'd1),
      .PARA_EVENT_SYNC_CELL_TYPE (32'd2)
    ) u_sync_axi_err (
      .i_clk_src   (i_clk_axi),
      .i_rst_n_src (w_rst_n_axi),
      .i_clk_dst   (i_clk_core),
      .i_rst_n_dst (w_rst_n_core),
      .i_event_src (w_axi_err_axi),
      .o_event_dst (w_axi_err_core)
    );
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_in_rdy (
      .i_clk_dst   (i_clk_core),
      .i_rst_n_dst (w_rst_n_core),
      .i_d         (w_in_rdy_axi),
      .o_q         (w_sts_in_rdy)
    );
    m_vlsit_afifo_cell_sync #(
      .PARA_AFIFO_CELL_RST_VAL (32'd0),
      .PARA_AFIFO_CELL_TYPE    (32'd2)
    ) u_sync_out_rdy (
      .i_clk_dst   (i_clk_core),
      .i_rst_n_dst (w_rst_n_core),
      .i_d         (w_out_rdy_axi),
      .o_q         (w_sts_out_rdy)
    );
  end else begin : gen_direct
    assign w_axi_err_core = w_axi_err_axi;
    assign w_sts_in_rdy   = w_in_rdy_axi;
    assign w_sts_out_rdy  = w_out_rdy_axi;
  end

endmodule
