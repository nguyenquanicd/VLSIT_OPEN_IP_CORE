// tb_dsig_p1.sv - testbench of phase 1 of the digital signature IP: generated CSR, control block
// and buffer, with behavioral models of the blocks that are not written yet (engines, key, random
// and verify-after-sign blocks, secret zeroization).
//
// Derived from: specification VLSIT_DIGITAL_SIGNATURE_HDS.md (requirements, section 10.1, 10.2,
// 10.5, 11, 12, 15) and APB IHI 0024D. The RTL is read only for port names and widths (R-023).
//
// Build options (macros): CSR_ASYNC (default 1), VLSIT_SYNTHESIS (synthesis branch of the
// synchronizer wrapper). Plusargs: +SEED=<n> (random stream), +N=<n> (random operations),
// +AFIFO_MSYNC_SEED=<n> (metastability model of the library), +TAPB=<ns> (APB clock period),
// +WAVE=<name> (dump the VCD of one scenario), +NOWAVE.
`timescale 1ns/1ps

`ifndef CSR_ASYNC
`define CSR_ASYNC 1
`endif

module tb_dsig_p1;

  // ----------------------------------------------------------------------------------------
  // Build parameters (equal to the defaults of the wrapper; the reference model uses them)
  // ----------------------------------------------------------------------------------------
  localparam logic [31:0] P_CSR_ASYNC   = `CSR_ASYNC;
  localparam logic [31:0] P_CAP_ALG     = 32'h7FFF;
  localparam logic [31:0] P_CAP_KGEN    = 32'h0FFF;
  localparam logic [31:0] P_CAP_SIGN    = 32'h0FFF;
  localparam logic [31:0] P_CAP_VRFY    = 32'h7FFF;
  localparam logic [31:0] P_EN_PURE     = 1;
  localparam logic [31:0] P_EN_PREHASH  = 1;
  localparam logic [31:0] P_EN_LOCK     = 1;
  localparam logic [31:0] P_EN_LOG      = 1;
  localparam logic [31:0] P_EN_VAS      = 1;
  localparam logic [31:0] P_EN_HYBRID   = 1;
  localparam logic [31:0] P_EN_DPA_EC   = 0;
  localparam logic [31:0] P_EN_DPA_PQ   = 0;
  localparam logic [31:0] P_ECDSA_NONCE = 2;
  localparam logic [31:0] P_BUF_BYTES   = 1024;
  localparam logic [31:0] P_SLH_SETS    = 32'h001;
  localparam logic [31:0] P_LMS_SETS    = 32'h00001;
  localparam logic [31:0] P_LMOTS_SETS  = 32'h0001;
  localparam logic [31:0] P_XMSS_LO     = 32'h00000001;
  localparam logic [31:0] P_XMSS_HI     = 32'h000;

  // Register offsets (workbook VLSIT_DIGITAL_SIGNATURE_CSR.xlsx, section 11.1)
  localparam [15:0] A_VERSION = 16'h000, A_CAP_ALG = 16'h004, A_CAP_KGEN = 16'h008,
                    A_CAP_SIGN = 16'h00C, A_CAP_VRFY = 16'h010, A_CAP_SLH = 16'h014,
                    A_CAP_LMS = 16'h018, A_CAP_XMSS = 16'h01C, A_CAP_XMSSH = 16'h020,
                    A_CAP_FEAT = 16'h024, A_CAP_BUF = 16'h028, A_CAP_LMOTS = 16'h02C,
                    A_CTRL = 16'h040, A_ALG_EN = 16'h044, A_ALG_ACT = 16'h048, A_LOCK = 16'h04C,
                    A_OP = 16'h050, A_SET = 16'h054, A_LEN_MSG = 16'h058, A_LEN_CTX = 16'h05C,
                    A_OFF_MSG = 16'h060, A_OFF_SIG = 16'h064, A_OFF_PK = 16'h068,
                    A_OFF_RES = 16'h06C, A_CMD = 16'h070, A_STS = 16'h074, A_ERR = 16'h078,
                    A_IRQ_RAW = 16'h07C, A_IRQ_EN = 16'h080, A_IRQ_INJ = 16'h084,
                    A_IRQ_STS = 16'h088, A_ALARM = 16'h08C, A_WIN_ADDR = 16'h090,
                    A_WIN_WR = 16'h094, A_WIN_RD = 16'h098, A_CNT_OPS = 16'h09C,
                    A_CNT_FAIL = 16'h0A0, A_LOG_LOCK = 16'h0A4, A_RNG = 16'h0A8, A_TMO = 16'h0AC,
                    A_KEY0 = 16'h100;

  // Algorithm indices (field dsig_op.alg, bit order of dsig_alg_en)
  localparam [3:0] ALG_ED25519 = 0, ALG_ED25519CTX = 1, ALG_ED25519PH = 2, ALG_ED448 = 3,
                   ALG_ED448PH = 4, ALG_P256 = 5, ALG_P384 = 6, ALG_P521 = 7, ALG_K256 = 8,
                   ALG_MLDSA44 = 9, ALG_MLDSA65 = 10, ALG_MLDSA87 = 11, ALG_SLHDSA = 12,
                   ALG_LMS = 13, ALG_XMSS = 14, ALG_RSVD = 15;
  localparam [1:0] OP_KGEN = 0, OP_SIGN = 1, OP_VRFY = 2, OP_RSVD = 3;
  localparam [1:0] FORM_PURE = 0, FORM_PREHASH = 1;

  // Error flag bit numbers of dsig_err
  localparam integer E_ALGDIS = 0, E_OPUNS = 1, E_BADLEN = 2, E_BADKEY = 3, E_BADPT = 4,
                     E_BUFOVF = 5, E_BUSERR = 6, E_ENTTMO = 7, E_KEYTMO = 8, E_VASMIS = 9,
                     E_LOCKV = 10, E_BUSYCMD = 11;

  // ----------------------------------------------------------------------------------------
  // Clocks and resets
  // ----------------------------------------------------------------------------------------
  reg  clk_core;
  reg  clk_apb_a;
  wire clk_apb;
  reg  rst_n_core;
  reg  rst_n_apb;
  real t_core = 10.0;
  real t_apb  = 17.0;
  integer seed;
  integer n_rand;

  initial begin
    clk_core = 1'b0;
    forever #(t_core / 2.0) clk_core = ~clk_core;
  end
  initial begin
    clk_apb_a = 1'b0;
    #1.3;
    forever #(t_apb / 2.0) clk_apb_a = ~clk_apb_a;
  end
  assign clk_apb = (P_CSR_ASYNC == 32'd1) ? clk_apb_a : clk_core;

  // ----------------------------------------------------------------------------------------
  // DUT and its stimulus signals
  // ----------------------------------------------------------------------------------------
  reg         apb_psel, apb_penable, apb_pwrite;
  reg  [15:0] apb_paddr;
  reg  [31:0] apb_pwdata;
  reg  [3:0]  apb_pstrb;
  reg  [2:0]  apb_pprot;
  wire        apb_pready, apb_pslverr;
  wire [31:0] apb_prdata;
  reg         protect_en, slverr_en;

  reg         bus_wr_en, bus_rd_en;
  reg  [6:0]  bus_wr_addr, bus_rd_addr;
  reg  [63:0] bus_wr_data;
  reg  [7:0]  bus_wr_strb;
  wire        bus_wr_rej, bus_rd_valid, bus_rd_rej;
  wire [63:0] bus_rd_data;

  reg         eng_rd_en, eng_wr_en;
  reg  [6:0]  eng_rd_addr, eng_wr_addr;
  reg  [63:0] eng_wr_data;
  reg  [7:0]  eng_wr_strb;
  wire [63:0] eng_rd_data;
  wire        eng_rd_valid;

  wire [2:0]  eng_start;
  reg         eng_done, eng_err, eng_sigok;
  reg  [11:0] eng_err_flags;
  wire        key_start, rng_start, vas_start, zero_req;
  reg         key_done, key_tmo, rng_done, rng_tmo, vas_done, vas_ok;
  wire        zero_done;
  reg         rng_due, rng_ready, rng_reseed_clr;
  wire        rng_reseed;
  wire [15:0] tmo_key, tmo_ent;
  wire        irq, alarm;

  dsig_p1_wrap #(
    .PARA_CSR_ASYNC    (P_CSR_ASYNC),
    .PARA_CAP_ALG      (P_CAP_ALG),
    .PARA_CAP_KGEN     (P_CAP_KGEN),
    .PARA_CAP_SIGN     (P_CAP_SIGN),
    .PARA_CAP_VRFY     (P_CAP_VRFY),
    .PARA_EN_PURE      (P_EN_PURE),
    .PARA_EN_PREHASH   (P_EN_PREHASH),
    .PARA_EN_LOCK      (P_EN_LOCK),
    .PARA_EN_LOG       (P_EN_LOG),
    .PARA_EN_VAS       (P_EN_VAS),
    .PARA_EN_HYBRID    (P_EN_HYBRID),
    .PARA_EN_DPA_EC    (P_EN_DPA_EC),
    .PARA_EN_DPA_PQ    (P_EN_DPA_PQ),
    .PARA_ECDSA_NONCE  (P_ECDSA_NONCE),
    .PARA_BUF_BYTES    (P_BUF_BYTES),
    .PARA_AXI_DW       (32'd64),
    .PARA_SLHDSA_SETS  (P_SLH_SETS),
    .PARA_LMS_SETS     (P_LMS_SETS),
    .PARA_LMOTS_SETS   (P_LMOTS_SETS),
    .PARA_XMSS_SETS_LO (P_XMSS_LO),
    .PARA_XMSS_SETS_HI (P_XMSS_HI)
  ) dut (
    .i_clk_apb        (clk_apb),
    .i_rst_n_apb      (rst_n_apb),
    .i_clk_core       (clk_core),
    .i_rst_n_core     (rst_n_core),
    .i_apb_psel       (apb_psel),
    .i_apb_penable    (apb_penable),
    .i_apb_pwrite     (apb_pwrite),
    .i_apb_paddr      (apb_paddr),
    .i_apb_pwdata     (apb_pwdata),
    .i_apb_pstrb      (apb_pstrb),
    .i_apb_pprot      (apb_pprot),
    .o_apb_pready     (apb_pready),
    .o_apb_pslverr    (apb_pslverr),
    .o_apb_prdata     (apb_prdata),
    .i_protect_en     (protect_en),
    .i_slverr_en      (slverr_en),
    .i_axi_wr_en      (bus_wr_en),
    .i_axi_wr_addr    (bus_wr_addr),
    .i_axi_wr_data    (bus_wr_data),
    .i_axi_wr_strb    (bus_wr_strb),
    .o_axi_wr_rej     (bus_wr_rej),
    .i_axi_rd_en      (bus_rd_en),
    .i_axi_rd_addr    (bus_rd_addr),
    .o_axi_rd_data    (bus_rd_data),
    .o_axi_rd_valid   (bus_rd_valid),
    .o_axi_rd_rej     (bus_rd_rej),
    .i_eng_rd_en      (eng_rd_en),
    .i_eng_rd_addr    (eng_rd_addr),
    .o_eng_rd_data    (eng_rd_data),
    .o_eng_rd_valid   (eng_rd_valid),
    .i_eng_wr_en      (eng_wr_en),
    .i_eng_wr_addr    (eng_wr_addr),
    .i_eng_wr_data    (eng_wr_data),
    .i_eng_wr_strb    (eng_wr_strb),
    .o_eng_start      (eng_start),
    .i_eng_done       (eng_done),
    .i_eng_err        (eng_err),
    .i_eng_err_flags  (eng_err_flags),
    .i_eng_sigok      (eng_sigok),
    .o_key_start      (key_start),
    .i_key_done       (key_done),
    .i_key_tmo        (key_tmo),
    .o_rng_start      (rng_start),
    .i_rng_done       (rng_done),
    .i_rng_tmo        (rng_tmo),
    .o_vas_start      (vas_start),
    .i_vas_done       (vas_done),
    .i_vas_ok         (vas_ok),
    .o_zero           (zero_req),
    .i_zero_done      (zero_done),
    .i_rng_due        (rng_due),
    .i_rng_ready      (rng_ready),
    .i_rng_reseed_clr (rng_reseed_clr),
    .o_rng_reseed     (rng_reseed),
    .o_tmo_key        (tmo_key),
    .o_tmo_ent        (tmo_ent),
    .o_irq            (irq),
    .o_alarm          (alarm)
  );

  // Pieces of the TB
  `include "tb_tasks.svh"
  `include "tb_models.svh"
  `include "tb_ref.svh"
  `include "tb_tests.svh"
  `include "tb_checkers.svh"

endmodule
