/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Keystream generator: PARA_CORE_NUM ChaCha20 cores work on interleaved block
 *                counters (core j makes counters j, j+N, j+2N, ... for N cores) and a serializer
 *                presents the blocks in counter order, one block at a time. The block of counter 0
 *                is the Poly1305 one-time key block; the block of counter i + 1 encrypts chunk i of
 *                the message (RFC 8439 sections 2.6 and 2.8). A load starts every core with the
 *                number of blocks that belongs to it, so a message of m bytes needs
 *                1 + ceil(m / 64) blocks in total.
 *                With PARA_PIPE_CHACHA = 1 every core is m_chacha_block_p (two blocks in flight,
 *                DEC-036).
 * Decisions    : DEC-008, DEC-030, DEC-036
 */
`timescale 1ns/1ps

module m_chacha_cipher #(
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
  // Parameter Description: 1 splits the round loop of every core in two stages with two blocks in
  // flight.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_CHACHA = 32'd0,
  localparam logic [31:0] LPARA_CORE_LOG = $clog2(PARA_CORE_NUM)
) (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Message control: clear of the secret state, load with the number of blocks of the message
  input  wire          i_clr,
  input  wire          i_load,
  input  wire  [10:0]  i_total_blk,

  // Key and nonce words (word 0 in the low bits)
  input  wire  [255:0] i_key,
  input  wire  [95:0]  i_nonce,

  // Keystream block stream in counter order
  output logic         o_blk_vld,
  output logic [511:0] o_blk,
  input  wire          i_blk_take
);

  // Internal signal declarations
  logic [2:0]                   reg_sel;
  logic [PARA_CORE_NUM*512-1:0] w_blk_all;
  logic [PARA_CORE_NUM-1:0]     w_vld_all;
  logic [PARA_CORE_NUM-1:0]     w_take_all;
  logic [2:0]                   w_sel_nxt;
  logic                         w_take;

  // One free-running core per lane; core j starts at counter j with a step of N and makes the
  // blocks whose counter is j modulo N: ceil((total - j) / N) of them, zero when total <= j.
  for (genvar gen_idx = 0; gen_idx < PARA_CORE_NUM; gen_idx++) begin : gen_core
    logic [10:0] w_cnt;

    // Number of blocks of this core: shift right by log2(N) after adding N - 1 - j.
    assign w_cnt = (i_total_blk > 11'(gen_idx)) ?
                   11'((i_total_blk + 11'(PARA_CORE_NUM - 32'd1 - gen_idx)) >> LPARA_CORE_LOG) :
                   11'd0;

    if (PARA_PIPE_CHACHA == 32'd0) begin : gen_plain
      m_chacha_block #(
        .PARA_QR_NUM  (PARA_QR_NUM),
        .PARA_RND_CYC (PARA_RND_CYC)
      ) u_block (
        .i_clk_core   (i_clk_core),
        .i_rst_n_core (i_rst_n_core),
        .i_clr        (i_clr),
        .i_load       (i_load),
        .i_ctr0       (32'(gen_idx)),
        .i_ctr_step   (4'(PARA_CORE_NUM)),
        .i_blk_cnt    (w_cnt),
        .i_key        (i_key),
        .i_nonce      (i_nonce),
        .o_blk_vld    (w_vld_all[gen_idx]),
        .o_blk        (w_blk_all[512*gen_idx +: 512]),
        .i_take       (w_take_all[gen_idx])
      );
    end else begin : gen_pipe
      m_chacha_block_p #(
        .PARA_QR_NUM  (PARA_QR_NUM),
        .PARA_RND_CYC (PARA_RND_CYC)
      ) u_block (
        .i_clk_core   (i_clk_core),
        .i_rst_n_core (i_rst_n_core),
        .i_clr        (i_clr),
        .i_load       (i_load),
        .i_ctr0       (32'(gen_idx)),
        .i_ctr_step   (4'(PARA_CORE_NUM)),
        .i_blk_cnt    (w_cnt),
        .i_key        (i_key),
        .i_nonce      (i_nonce),
        .o_blk_vld    (w_vld_all[gen_idx]),
        .o_blk        (w_blk_all[512*gen_idx +: 512]),
        .i_take       (w_take_all[gen_idx])
      );
    end
  end

  // Serializer: the block of counter b comes from core b modulo N, so the pointer visits the
  // cores in order. The selected core presents its block and the take pulse goes to that core.
  always_comb begin : p_com_sel
    o_blk_vld  = 1'b0;
    o_blk      = '0;
    w_take_all = '0;
    for (int idx = 0; idx < PARA_CORE_NUM; idx++) begin
      if (reg_sel == 3'(idx)) begin
        o_blk_vld     = w_vld_all[idx];
        o_blk         = w_blk_all[512*idx +: 512];
        w_take_all[idx] = w_take;
      end
    end
  end

  // The consumer takes a block only when the selected core presents one.
  assign w_take = i_blk_take & o_blk_vld;

  // The pointer wraps after the last core.
  assign w_sel_nxt = (reg_sel == 3'(PARA_CORE_NUM - 32'd1)) ? 3'd0 : $bits(w_sel_nxt)'(reg_sel + 3'd1);

  // Pointer register: reset at power-up, restarted by a clear or a load, advanced by a take.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_sel
    if (!i_rst_n_core)
      reg_sel <= 3'd0;
    else if (i_clr | i_load)
      reg_sel <= 3'd0;
    else if (w_take)
      reg_sel <= w_sel_nxt;
  end

endmodule
