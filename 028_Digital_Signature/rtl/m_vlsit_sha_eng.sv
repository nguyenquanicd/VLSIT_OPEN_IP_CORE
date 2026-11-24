/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Block-level hash engine of the digital signature IP (DEC-020). It wraps the
 *                compression cores of the SHA2/SHA3 IP 019 (SHA-256, SHA-512 and Keccak-f[1600])
 *                without their bus interfaces: one start pulse runs one block through the core
 *                of the selected family and the done pulse returns the new state. Padding,
 *                chaining and squeezing are done by the stream sequencer m_vlsit_dsig_hseq.
 *                Unused families are removed by the enable parameters. Family codes: 0 SHA-256,
 *                1 SHA-512 (also SHA-384), 2 Keccak (SHA-3 and SHAKE). State words are as in the
 *                cores: SHA-2 word i in bits [32 i +: 32] (SHA-256) or [64 i +: 64] (SHA-512);
 *                Keccak lane (x, y) in bits [64 (x + 5 y) +: 64]. Requirements: REQ-FUNC-011 (no
 *                private hash core).
 */
`timescale 1ns/1ps

module m_vlsit_sha_eng #(
  // Parameter Description: build the SHA-256 core (needed by SHA-2 with 32-bit words).
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_S256 = 1,
  // Parameter Description: build the SHA-512 core (needed by SHA-384 and SHA-512).
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_S512 = 1,
  // Parameter Description: build the Keccak core (needed by SHA-3 and SHAKE).
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_KECCAK = 1,
  // Parameter Description: rounds of SHA-256 per clock cycle; divides 64.
  // Parameter values: 1, 2, 4, 8, 16 or 32; default is 1.
  // Parameter unit: round
  parameter logic [31:0] PARA_S256_UNR = 1,
  // Parameter Description: rounds of SHA-512 per clock cycle; divides 80.
  // Parameter values: 1, 2, 4, 5, 8 or 10; default is 1.
  // Parameter unit: round
  parameter logic [31:0] PARA_S512_UNR = 1,
  // Parameter Description: Keccak rounds per clock cycle; divides 24.
  // Parameter values: 1, 2, 3, 4, 6, 8 or 12; default is 1.
  // Parameter unit: round
  parameter logic [31:0] PARA_KEC_UNR = 1,
  localparam logic [31:0] LPARA_FAM_S256 = 0,
  localparam logic [31:0] LPARA_FAM_S512 = 1,
  localparam logic [31:0] LPARA_FAM_KEC = 2
) (
  // Clock and reset
  input  wire           i_clk_core,
  input  wire           i_rst_n_core,

  // Block request
  input  wire           i_start,
  input  wire           i_clr,
  input  wire  [1:0]    i_fam,
  input  wire  [1343:0] i_block,
  input  wire  [1599:0] i_state,

  // Result
  output logic          o_done,
  output logic [1599:0] o_result
);

  // Internal signal declarations
  logic          w_start_c256;
  logic          w_start_c512;
  logic          w_start_kec;
  logic          w_done_c256;
  logic          w_done_c512;
  logic          w_done_kec;
  logic [255:0]  w_res_c256;
  logic [511:0]  w_res_c512;
  logic [1599:0] w_res_kec;
  logic [1:0]    reg_fam;

  // Start routing: one core runs, chosen by the family code of the request.
  assign w_start_c256 = i_start & (i_fam == LPARA_FAM_S256[1:0]);
  assign w_start_c512 = i_start & (i_fam == LPARA_FAM_S512[1:0]);
  assign w_start_kec  = i_start & (i_fam == LPARA_FAM_KEC[1:0]);

  // SHA-256 core of the SHA2/SHA3 IP 019.
  if (PARA_EN_S256 != 32'd0) begin : gen_c256
    m_vlsit_sha_core256 #(
      .PARA_UNR (PARA_S256_UNR),
      .PARA_PAR (32'd0)
    ) u_core256 (
      .i_clk_core   (i_clk_core),
      .i_rst_n_core (i_rst_n_core),
      .i_start      (w_start_c256),
      .i_clr        (i_clr),
      .o_done       (w_done_c256),
      .i_block      (i_block[511:0]),
      .i_state      (i_state[255:0]),
      .o_result     (w_res_c256),
      .o_par_err    ()
    );
  end else begin : gen_no_c256
    assign w_done_c256 = 1'b0;
    assign w_res_c256  = 256'd0;
  end

  // SHA-512 core of the SHA2/SHA3 IP 019.
  if (PARA_EN_S512 != 32'd0) begin : gen_c512
    m_vlsit_sha_core512 #(
      .PARA_UNR (PARA_S512_UNR),
      .PARA_PAR (32'd0)
    ) u_core512 (
      .i_clk_core   (i_clk_core),
      .i_rst_n_core (i_rst_n_core),
      .i_start      (w_start_c512),
      .i_clr        (i_clr),
      .o_done       (w_done_c512),
      .i_block      (i_block[1023:0]),
      .i_state      (i_state[511:0]),
      .o_result     (w_res_c512),
      .o_par_err    ()
    );
  end else begin : gen_no_c512
    assign w_done_c512 = 1'b0;
    assign w_res_c512  = 512'd0;
  end

  // Keccak core of the SHA2/SHA3 IP 019.
  if (PARA_EN_KECCAK != 32'd0) begin : gen_kec
    m_vlsit_sha_keccak #(
      .PARA_UNR (PARA_KEC_UNR),
      .PARA_PAR (32'd0)
    ) u_keccak (
      .i_clk_core   (i_clk_core),
      .i_rst_n_core (i_rst_n_core),
      .i_start      (w_start_kec),
      .i_clr        (i_clr),
      .o_done       (w_done_kec),
      .i_block      (i_block),
      .i_state      (i_state),
      .o_result     (w_res_kec),
      .o_par_err    ()
    );
  end else begin : gen_no_kec
    assign w_done_kec = 1'b0;
    assign w_res_kec  = 1600'd0;
  end

  // Family of the running block, kept until the next start so that the result mux stays stable.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fam
    if (!i_rst_n_core)
      reg_fam <= 2'd0;
    else if (i_start)
      reg_fam <= i_fam;
  end

  // Result and done of the selected core only: the done level of a core that is not running stays
  // high until its next start.
  always_comb begin : p_com_res
    o_done   = 1'b0;
    o_result = 1600'd0;
    case (reg_fam)
      LPARA_FAM_S256[1:0]: begin o_done = w_done_c256; o_result = {1344'd0, w_res_c256}; end
      LPARA_FAM_S512[1:0]: begin o_done = w_done_c512; o_result = {1088'd0, w_res_c512}; end
      default:             begin o_done = w_done_kec;  o_result = w_res_kec; end
    endcase
  end

endmodule
