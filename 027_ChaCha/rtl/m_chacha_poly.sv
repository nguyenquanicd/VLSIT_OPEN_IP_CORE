/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Poly1305 authenticator (RFC 8439 section 2.5). It loads the one-time key (r from
 *                the low 16 bytes, clamped, and s from the high 16 bytes, both little-endian),
 *                accepts the 16-byte blocks of the padded AEAD message one at a time through a
 *                multiply-accumulate unit selected by PARA_POLY_ARCH (0 product scanning, 22
 *                cycles per block; 1 Karatsuba folded onto one multiplier, 5 cycles; 2 one
 *                multiplier, 1 cycle), and forms the tag after a finalize request: the accumulator
 *                is reduced completely modulo 2^130 - 5, s is added and the low 128 bits are the
 *                tag. A finalize request waits for the last block to finish.
 * Decisions    : DEC-025, DEC-036, DEC-037
 */
`timescale 1ns/1ps

module m_chacha_poly #(
  // Parameter Description: multiply-accumulate architecture: 0 product scanning with a 32 by 32
  // multiplier (22 cycles per block), 1 Karatsuba folded onto one 67 by 67 multiplier (5 cycles),
  // 2 one 131 by 128 multiplier (1 cycle).
  // Parameter values: 0, 1 or 2; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_POLY_ARCH = 32'd1,
  // Parameter Description: 1 splits the multiply-accumulate in two cycles (the interval between
  // two blocks is one cycle longer); the position of the cut depends on PARA_POLY_ARCH.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_POLY = 32'd0,
  localparam logic [31:0] LPARA_R_MASK_0 = 32'h0fffffff,
  localparam logic [31:0] LPARA_R_MASK_1 = 32'h0ffffffc,
  localparam logic [31:0] LPARA_R_MASK_2 = 32'h0ffffffc,
  localparam logic [31:0] LPARA_R_MASK_3 = 32'h0ffffffc
) (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Clear of the secret state at the end of a message
  input  wire          i_clr,

  // One-time key load: r (clamped here) in the low 128 bits, s in the high 128 bits
  input  wire          i_otk_vld,
  input  wire  [255:0] i_otk,

  // Block input
  input  wire          i_blk_vld,
  input  wire  [127:0] i_blk,
  output logic         o_blk_rdy,

  // Finalize request and tag
  input  wire          i_fin,
  output logic         o_tag_vld,
  output logic [127:0] o_tag,

  // Status: no block in process
  output logic         o_idle
);

  // Internal signal declarations
  logic [127:0] reg_r;
  logic [127:0] reg_s;
  logic [127:0] reg_tag;
  logic         reg_otk_vld;
  logic         reg_fin_pend;
  logic         reg_tag_vld;
  logic         w_rdy;
  logic         w_start;
  logic         w_clr_mac;
  logic         w_tag_now;
  logic         w_fin_req;
  logic [130:0] w_acc;
  logic [131:0] w_acc_p5;
  logic [130:0] w_acc_red;
  logic [127:0] w_r_mask;
  logic [127:0] w_tag_nxt;

  // Clamp mask of r (RFC 8439 section 2.5.1): the top four bits of every word and the two low
  // bits of words 1 to 3 are cleared.
  assign w_r_mask = {LPARA_R_MASK_3, LPARA_R_MASK_2, LPARA_R_MASK_1, LPARA_R_MASK_0};

  // A block is accepted when the key is loaded, the unit is ready and no finalize is pending.
  assign o_blk_rdy = reg_otk_vld & w_rdy & ~reg_fin_pend & ~reg_tag_vld;
  assign w_start   = i_blk_vld & o_blk_rdy;

  // The accumulator is cleared together with the secret state and when a new key is loaded.
  assign w_clr_mac = i_clr | i_otk_vld;

  // Multiply-accumulate unit of the selected architecture.
  if (PARA_POLY_ARCH == 32'd0) begin : gen_arch
    m_chacha_pmac_s32 #(
      .PARA_PIPE_POLY (PARA_PIPE_POLY)
    ) u_pmac (
      .i_clk_core   (i_clk_core),
      .i_rst_n_core (i_rst_n_core),
      .i_clr        (w_clr_mac),
      .i_r          (reg_r),
      .i_start      (w_start),
      .i_blk        (i_blk),
      .o_rdy        (w_rdy),
      .o_acc        (w_acc)
    );
  end else if (PARA_POLY_ARCH == 32'd1) begin : gen_arch
    m_chacha_pmac_kar #(
      .PARA_PIPE_POLY (PARA_PIPE_POLY)
    ) u_pmac (
      .i_clk_core   (i_clk_core),
      .i_rst_n_core (i_rst_n_core),
      .i_clr        (w_clr_mac),
      .i_r          (reg_r),
      .i_start      (w_start),
      .i_blk        (i_blk),
      .o_rdy        (w_rdy),
      .o_acc        (w_acc)
    );
  end else begin : gen_arch
    m_chacha_pmac_par #(
      .PARA_PIPE_POLY (PARA_PIPE_POLY)
    ) u_pmac (
      .i_clk_core   (i_clk_core),
      .i_rst_n_core (i_rst_n_core),
      .i_clr        (w_clr_mac),
      .i_r          (reg_r),
      .i_start      (w_start),
      .i_blk        (i_blk),
      .o_rdy        (w_rdy),
      .o_acc        (w_acc)
    );
  end

  // Complete reduction: the partially reduced accumulator is below 2^130 + 36, so at most one
  // subtraction of the prime 2^130 - 5 gives the residue. acc >= 2^130 - 5 exactly when acc + 5
  // reaches 2^130, and then acc - p is the low 130 bits of acc + 5. The tag is the low 128 bits of
  // the residue plus s.
  assign w_acc_p5  = $bits(w_acc_p5)'({1'b0, w_acc} + 132'd5);
  assign w_acc_red = (w_acc_p5[131:130] != 2'b00) ? {1'b0, w_acc_p5[129:0]} : w_acc;
  assign w_tag_nxt = $bits(w_tag_nxt)'(w_acc_red[127:0] + reg_s);

  // The tag is formed when a finalize request is present, in its own cycle or pending, and the
  // unit is idle (DEC-037).
  assign w_fin_req = i_fin | reg_fin_pend;
  assign w_tag_now = w_fin_req & w_rdy;

  // Flags: key valid, finalize pending and tag valid are control state and are reset.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
    if (!i_rst_n_core) begin
      reg_otk_vld  <= 1'b0;
      reg_fin_pend <= 1'b0;
      reg_tag_vld  <= 1'b0;
    end else if (i_clr) begin
      reg_otk_vld  <= 1'b0;
      reg_fin_pend <= 1'b0;
      reg_tag_vld  <= 1'b0;
    end else begin
      if (i_otk_vld) begin
        reg_otk_vld <= 1'b1;
        reg_tag_vld <= 1'b0;
      end
      if (w_fin_req & ~w_rdy)
        reg_fin_pend <= 1'b1;
      else if (w_tag_now)
        reg_fin_pend <= 1'b0;
      if (w_tag_now)
        reg_tag_vld <= 1'b1;
    end
  end

  // Secret registers without reset, qualified by the key flag and the tag flag: the clamped r, the
  // key part s and the tag.
  always_ff @(posedge i_clk_core) begin : p_ff_data
    if (i_clr) begin
      reg_r   <= '0;
      reg_s   <= '0;
      reg_tag <= '0;
    end else begin
      if (i_otk_vld) begin
        reg_r <= i_otk[127:0] & w_r_mask;
        reg_s <= i_otk[255:128];
      end
      if (w_tag_now)
        reg_tag <= w_tag_nxt;
    end
  end

  // Output mapping of the tag and the idle status.
  assign o_tag     = reg_tag;
  assign o_tag_vld = reg_tag_vld;
  assign o_idle    = w_rdy;

endmodule
