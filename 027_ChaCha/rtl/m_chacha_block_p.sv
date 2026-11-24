/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : One ChaCha20 core with the round loop cut in two stages (PARA_PIPE_CHACHA = 1),
 *                same ports and same block stream as m_chacha_block. The loop is a ring of two
 *                registers: stage 1 turns R0 into R1 and stage 2 turns R1 into R0. With one round
 *                per cycle the cut is in the middle of the quarter round (m_chacha_qrh1 and
 *                m_chacha_qrh2); with two rounds per cycle it is between the two rounds. Two
 *                blocks A and B (counters c and c + step) are in flight, B one cycle behind A, so
 *                one iteration of a block takes two cycles and a pair of blocks needs 2 * ITER + 1
 *                cycles, ITER being the iterations of one block of m_chacha_block. A pair is
 *                delivered to a queue of two entries in the cycle in which A has finished and the
 *                next state of B is on the stage 2 output; the next pair starts in the same edge. A
 *                last block without a partner runs alone and takes the time of a pair. The queue
 *                presents the blocks in counter order; the block output is the finished state plus
 *                the initial state, formed on the way out. The ring freezes while the queue cannot
 *                take the pair. The key and the nonce inputs shall stay stable while blocks are
 *                produced.
 * Decisions    : DEC-008, DEC-030, DEC-036
 */
`timescale 1ns/1ps

module m_chacha_block_p #(
  // Parameter Description: number of quarter-round units that work in parallel in one core.
  // Parameter values: 1, 2 or 4; default is 4. A value of 2 for PARA_RND_CYC requires 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_QR_NUM = 32'd4,
  // Parameter Description: rounds executed in one clock cycle.
  // Parameter values: 1 or 2; default is 1. The value 2 requires PARA_QR_NUM = 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_RND_CYC = 32'd1,
  localparam logic [31:0] LPARA_STEPS = 32'd4 / PARA_QR_NUM,
  localparam logic [31:0] LPARA_ITER = (32'd20 / PARA_RND_CYC) * LPARA_STEPS,
  localparam logic [31:0] LPARA_SIGMA0 = 32'h61707865,
  localparam logic [31:0] LPARA_SIGMA1 = 32'h3320646e,
  localparam logic [31:0] LPARA_SIGMA2 = 32'h79622d32,
  localparam logic [31:0] LPARA_SIGMA3 = 32'h6b206574
) (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Clear of the secret state at the end of a message
  input  wire          i_clr,

  // Load: first counter, counter step, number of blocks to produce
  input  wire          i_load,
  input  wire  [31:0]  i_ctr0,
  input  wire  [3:0]   i_ctr_step,
  input  wire  [10:0]  i_blk_cnt,

  // Key and nonce words (word 0 in the low bits)
  input  wire  [255:0] i_key,
  input  wire  [95:0]  i_nonce,

  // Keystream block output
  output logic         o_blk_vld,
  output logic [511:0] o_blk,
  input  wire          i_take
);

  // FSM states: IDLE waits for a load, LDB is the cycle in which block B enters the ring, RUN
  // executes the iterations of a pair. The encoding 2'b11 recovers to IDLE.
  typedef enum logic [1:0] {
    ENUM_ST_IDLE = 2'b00,
    ENUM_ST_LDB  = 2'b01,
    ENUM_ST_RUN  = 2'b10
  } blk_state_type_def;

  // Internal signal declarations
  blk_state_type_def reg_fsm_blk_current_state;
  blk_state_type_def w_fsm_blk_nxt_state;
  logic [511:0]      reg_r0;
  logic [511:0]      reg_r1;
  logic [31:0]       reg_ctr_a;
  logic [3:0]        reg_step;
  logic [10:0]       reg_rem;
  logic              reg_b_vld;
  logic              reg_ph;
  logic [6:0]        reg_left;
  logic [1:0]        reg_sub;
  logic              reg_par;
  logic              reg_q0_v;
  logic [511:0]      reg_q0_st;
  logic [31:0]       reg_q0_ctr;
  logic              reg_q1_v;
  logic [511:0]      reg_q1_st;
  logic [31:0]       reg_q1_ctr;
  logic [511:0]      w_f1;
  logic [511:0]      w_s_nxt;
  logic [511:0]      w_init_head;
  logic [511:0]      w_init_a_new;
  logic [511:0]      w_init_b;
  logic [511:0]      w_init_ld;
  logic [31:0]       w_ctr_b;
  logic [31:0]       w_ctr_a_nxt;
  logic [10:0]       w_rem_after;
  logic              w_more;
  logic              w_last;
  logic              w_last_sub;
  logic              w_run;
  logic              w_end_cyc;
  logic              w_dlv;
  logic              w_stall;
  logic              w_tog;
  logic              w_it;
  logic              w_load_new;
  logic              w_ldb;
  logic              w_take;
  logic              w_q_ok;
  logic              w_v0t;
  logic              w_v1t;
  logic [511:0]      w_st0t;
  logic [31:0]       w_ctr0t;
  logic [511:0]      w_st1t;
  logic [31:0]       w_ctr1t;

  // Initial state of one block (RFC 8439 section 2.3): four constants, eight key words, the block
  // counter and three nonce words, word 0 in the low 32 bits.
  function automatic logic [511:0] f_init (
    input logic [255:0] a_key,
    input logic [31:0]  a_ctr,
    input logic [95:0]  a_nonce
  );
    f_init = {a_nonce, a_ctr, a_key, LPARA_SIGMA3, LPARA_SIGMA2, LPARA_SIGMA1, LPARA_SIGMA0};
  endfunction

  // Diagonalization: row 1 rotates left by one word, row 2 by two and row 3 by three.
  function automatic logic [511:0] f_diag (input logic [511:0] a_st);
    logic [511:0] v_res;
    v_res = a_st;
    for (int idx = 0; idx < 4; idx++) begin
      v_res[32*(4+idx) +: 32]  = a_st[32*(4+((idx+1)%4)) +: 32];
      v_res[32*(8+idx) +: 32]  = a_st[32*(8+((idx+2)%4)) +: 32];
      v_res[32*(12+idx) +: 32] = a_st[32*(12+((idx+3)%4)) +: 32];
    end
    f_diag = v_res;
  endfunction

  // Inverse of f_diag.
  function automatic logic [511:0] f_undiag (input logic [511:0] a_st);
    logic [511:0] v_res;
    v_res = a_st;
    for (int idx = 0; idx < 4; idx++) begin
      v_res[32*(4+idx) +: 32]  = a_st[32*(4+((idx+3)%4)) +: 32];
      v_res[32*(8+idx) +: 32]  = a_st[32*(8+((idx+2)%4)) +: 32];
      v_res[32*(12+idx) +: 32] = a_st[32*(12+((idx+1)%4)) +: 32];
    end
    f_undiag = v_res;
  endfunction

  // Column rotation: column j of the result is column (j + Q) mod 4 of the input.
  function automatic logic [511:0] f_rotcol (input logic [511:0] a_st);
    logic [511:0] v_res;
    v_res = a_st;
    for (int idx = 0; idx < 4; idx++) begin
      for (int row = 0; row < 4; row++) begin
        v_res[32*(4*row+idx) +: 32] = a_st[32*(4*row+((idx+PARA_QR_NUM)%4)) +: 32];
      end
    end
    f_rotcol = v_res;
  endfunction

  // Ring logic. Two rounds per cycle: stage 1 is the column round followed by the diagonalization,
  // stage 2 the diagonal round followed by the inverse. One round per cycle: stage 1 is the first
  // half of the quarter round on the head columns, stage 2 the second half, the column rotation
  // and, at the last sub-step of a round, the diagonalization or its inverse.
  if (PARA_RND_CYC == 32'd2) begin : gen_r2
    logic [511:0] w_x1;
    logic [511:0] w_x2;
    for (genvar gen_idx = 0; gen_idx < 4; gen_idx++) begin : gen_col
      m_chacha_qr u_qr1 (
        .i_a (reg_r0[32*gen_idx +: 32]),
        .i_b (reg_r0[32*(4+gen_idx) +: 32]),
        .i_c (reg_r0[32*(8+gen_idx) +: 32]),
        .i_d (reg_r0[32*(12+gen_idx) +: 32]),
        .o_a (w_x1[32*gen_idx +: 32]),
        .o_b (w_x1[32*(4+gen_idx) +: 32]),
        .o_c (w_x1[32*(8+gen_idx) +: 32]),
        .o_d (w_x1[32*(12+gen_idx) +: 32])
      );
      m_chacha_qr u_qr2 (
        .i_a (reg_r1[32*gen_idx +: 32]),
        .i_b (reg_r1[32*(4+gen_idx) +: 32]),
        .i_c (reg_r1[32*(8+gen_idx) +: 32]),
        .i_d (reg_r1[32*(12+gen_idx) +: 32]),
        .o_a (w_x2[32*gen_idx +: 32]),
        .o_b (w_x2[32*(4+gen_idx) +: 32]),
        .o_c (w_x2[32*(8+gen_idx) +: 32]),
        .o_d (w_x2[32*(12+gen_idx) +: 32])
      );
    end
    assign w_f1    = f_diag(w_x1);
    assign w_s_nxt = f_undiag(w_x2);
  end else begin : gen_r1
    logic [511:0] w_xh;
    logic [511:0] w_xf;
    logic [511:0] w_y;
    for (genvar gen_idx = 0; gen_idx < 4; gen_idx++) begin : gen_col
      if (gen_idx < PARA_QR_NUM) begin : gen_qr
        m_chacha_qrh1 u_qr1 (
          .i_a (reg_r0[32*gen_idx +: 32]),
          .i_b (reg_r0[32*(4+gen_idx) +: 32]),
          .i_c (reg_r0[32*(8+gen_idx) +: 32]),
          .i_d (reg_r0[32*(12+gen_idx) +: 32]),
          .o_a (w_xh[32*gen_idx +: 32]),
          .o_b (w_xh[32*(4+gen_idx) +: 32]),
          .o_c (w_xh[32*(8+gen_idx) +: 32]),
          .o_d (w_xh[32*(12+gen_idx) +: 32])
        );
        m_chacha_qrh2 u_qr2 (
          .i_a (reg_r1[32*gen_idx +: 32]),
          .i_b (reg_r1[32*(4+gen_idx) +: 32]),
          .i_c (reg_r1[32*(8+gen_idx) +: 32]),
          .i_d (reg_r1[32*(12+gen_idx) +: 32]),
          .o_a (w_xf[32*gen_idx +: 32]),
          .o_b (w_xf[32*(4+gen_idx) +: 32]),
          .o_c (w_xf[32*(8+gen_idx) +: 32]),
          .o_d (w_xf[32*(12+gen_idx) +: 32])
        );
      end else begin : gen_pass
        assign w_xh[32*gen_idx +: 32]      = reg_r0[32*gen_idx +: 32];
        assign w_xh[32*(4+gen_idx) +: 32]  = reg_r0[32*(4+gen_idx) +: 32];
        assign w_xh[32*(8+gen_idx) +: 32]  = reg_r0[32*(8+gen_idx) +: 32];
        assign w_xh[32*(12+gen_idx) +: 32] = reg_r0[32*(12+gen_idx) +: 32];
        assign w_xf[32*gen_idx +: 32]      = reg_r1[32*gen_idx +: 32];
        assign w_xf[32*(4+gen_idx) +: 32]  = reg_r1[32*(4+gen_idx) +: 32];
        assign w_xf[32*(8+gen_idx) +: 32]  = reg_r1[32*(8+gen_idx) +: 32];
        assign w_xf[32*(12+gen_idx) +: 32] = reg_r1[32*(12+gen_idx) +: 32];
      end
    end
    assign w_f1 = w_xh;
    assign w_y  = f_rotcol(w_xf);
    always_comb begin : p_com_s_nxt
      w_s_nxt = w_y;
      if (w_last_sub) begin
        if (reg_par)
          w_s_nxt = f_undiag(w_y);
        else
          w_s_nxt = f_diag(w_y);
      end
    end
  end

  // Iteration bookkeeping of stage 2: the last sub-step of a round, the last iteration of a block.
  assign w_last_sub = (reg_sub == 2'(LPARA_STEPS - 32'd1));
  assign w_last     = (reg_left == 7'd0);

  // Events. RUN with the phase bit high is the cycle in which stage 2 works on block B; in the last
  // iteration it is the delivery cycle of the pair, which freezes the ring when the queue is full.
  assign w_run      = (reg_fsm_blk_current_state == ENUM_ST_RUN);
  assign w_ldb      = (reg_fsm_blk_current_state == ENUM_ST_LDB);
  assign w_end_cyc  = w_run & reg_ph & w_last;
  assign w_dlv      = w_end_cyc & w_q_ok;
  assign w_stall    = w_end_cyc & ~w_q_ok;
  assign w_tog      = w_run & ~w_end_cyc;
  assign w_it       = w_run & reg_ph & ~w_last;
  assign w_load_new = (reg_fsm_blk_current_state == ENUM_ST_IDLE) & i_load & (i_blk_cnt != 11'd0);

  // Blocks left after this pair and the counters of the next pair and of block B.
  assign w_rem_after = $bits(w_rem_after)'(reg_rem - (reg_b_vld ? 11'd2 : 11'd1));
  assign w_more      = (w_rem_after != 11'd0);
  assign w_ctr_b     = $bits(w_ctr_b)'(reg_ctr_a + 32'(reg_step));
  assign w_ctr_a_nxt = $bits(w_ctr_a_nxt)'(reg_ctr_a + 32'({reg_step, 1'b0}));

  // Initial states: of the head of the queue (to form the block output), of the next pair and of
  // block B.
  assign w_init_head  = f_init(i_key, reg_q0_ctr, i_nonce);
  assign w_init_a_new = f_init(i_key, w_ctr_a_nxt, i_nonce);
  assign w_init_b     = f_init(i_key, w_ctr_b, i_nonce);
  assign w_init_ld    = f_init(i_key, i_ctr0, i_nonce);

  // Queue: the head is taken first; the queue takes the pair when, after this cycle's take, it has
  // room for both blocks (or for one when the last pair has no block B).
  assign w_take = i_take & reg_q0_v;
  assign w_q_ok = reg_b_vld ? (~reg_q0_v | (w_take & ~reg_q1_v)) : (~reg_q1_v | w_take);

  // Queue content after this cycle's take.
  always_comb begin : p_com_qtake
    w_v0t   = reg_q0_v;
    w_st0t  = reg_q0_st;
    w_ctr0t = reg_q0_ctr;
    w_v1t   = reg_q1_v;
    w_st1t  = reg_q1_st;
    w_ctr1t = reg_q1_ctr;
    if (w_take) begin
      w_v0t   = reg_q1_v;
      w_st0t  = reg_q1_st;
      w_ctr0t = reg_q1_ctr;
      w_v1t   = 1'b0;
    end
  end

  // Block output: finished state plus the initial state, word by word, modulo 2^32.
  always_comb begin : p_com_blk_out
    o_blk = '0;
    for (int idx = 0; idx < 16; idx++)
      o_blk[32*idx +: 32] = $bits(o_blk[31:0])'(reg_q0_st[32*idx +: 32] + w_init_head[32*idx +: 32]);
  end
  assign o_blk_vld = reg_q0_v;

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_blk
    if (!i_rst_n_core)
      reg_fsm_blk_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_blk_current_state <= w_fsm_blk_nxt_state;
  end

  // Part 2 of the FSM: IDLE goes to LDB on a load with at least one block, LDB to RUN, RUN to LDB
  // (next pair) or IDLE when the pair is delivered. A clear returns to IDLE.
  always_comb begin : p_com_fsm_nxt
    w_fsm_blk_nxt_state = reg_fsm_blk_current_state;
    case (reg_fsm_blk_current_state)
      ENUM_ST_IDLE: begin
        if (w_load_new)
          w_fsm_blk_nxt_state = ENUM_ST_LDB;
      end
      ENUM_ST_LDB: w_fsm_blk_nxt_state = ENUM_ST_RUN;
      ENUM_ST_RUN: begin
        if (w_dlv) begin
          if (w_more)
            w_fsm_blk_nxt_state = ENUM_ST_LDB;
          else
            w_fsm_blk_nxt_state = ENUM_ST_IDLE;
        end
      end
      default: w_fsm_blk_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_blk_nxt_state = ENUM_ST_IDLE;
  end

  // Control registers: blocks left, counter step, partner flag, phase, iteration counters and the
  // queue flags. They are reset to idle values.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
    if (!i_rst_n_core) begin
      reg_rem   <= 11'd0;
      reg_step  <= 4'd1;
      reg_b_vld <= 1'b0;
      reg_ph    <= 1'b0;
      reg_left  <= 7'd0;
      reg_sub   <= 2'd0;
      reg_par   <= 1'b0;
      reg_q0_v  <= 1'b0;
      reg_q1_v  <= 1'b0;
    end else if (i_clr) begin
      reg_rem   <= 11'd0;
      reg_b_vld <= 1'b0;
      reg_ph    <= 1'b0;
      reg_left  <= 7'd0;
      reg_sub   <= 2'd0;
      reg_par   <= 1'b0;
      reg_q0_v  <= 1'b0;
      reg_q1_v  <= 1'b0;
    end else begin
      // Queue flags: valid entries after the take, plus the pair that is delivered.
      reg_q0_v <= w_v0t;
      reg_q1_v <= w_v1t;
      if (w_dlv) begin
        if (w_v0t) begin
          reg_q1_v <= 1'b1;
        end else begin
          reg_q0_v <= 1'b1;
          reg_q1_v <= reg_b_vld;
        end
      end
      // Priority: a load, the delivery of a pair, then one more step of the ring.
      casez ({w_load_new, w_dlv, w_tog})
        3'b1??: begin
          reg_rem   <= i_blk_cnt;
          reg_step  <= i_ctr_step;
          reg_b_vld <= (i_blk_cnt >= 11'd2);
          reg_left  <= 7'(LPARA_ITER - 32'd1);
          reg_sub   <= 2'd0;
          reg_par   <= 1'b0;
          reg_ph    <= 1'b0;
        end
        3'b01?: begin
          reg_rem   <= w_rem_after;
          reg_b_vld <= (w_rem_after >= 11'd2);
          reg_left  <= 7'(LPARA_ITER - 32'd1);
          reg_sub   <= 2'd0;
          reg_par   <= 1'b0;
          reg_ph    <= 1'b0;
        end
        3'b001: begin
          reg_ph <= ~reg_ph;
          if (w_it) begin
            reg_left <= $bits(reg_left)'(reg_left - 7'd1);
            reg_sub  <= w_last_sub ? 2'd0 : $bits(reg_sub)'(reg_sub + 2'd1);
            reg_par  <= w_last_sub ? ~reg_par : reg_par;
          end
        end
        default: begin
          // Idle, load cycle of block B or frozen ring: the counters hold.
        end
      endcase
    end
  end

  // Secret datapath registers: no reset, because the state and the queue flags qualify them; they
  // are cleared at the end of a message (REQ-SEC-004).
  always_ff @(posedge i_clk_core) begin : p_ff_state
    if (i_clr) begin
      reg_r0     <= '0;
      reg_r1     <= '0;
      reg_ctr_a  <= '0;
      reg_q0_st  <= '0;
      reg_q0_ctr <= '0;
      reg_q1_st  <= '0;
      reg_q1_ctr <= '0;
    end else begin
      // Ring register R0: priority is a load, the next pair, block B, then the stage 2 result.
      casez ({w_load_new, w_dlv & w_more, w_ldb & reg_b_vld, w_run & ~w_end_cyc})
        4'b1???: begin
          reg_r0    <= w_init_ld;
          reg_ctr_a <= i_ctr0;
        end
        4'b01??: begin
          reg_r0    <= w_init_a_new;
          reg_ctr_a <= w_ctr_a_nxt;
        end
        4'b001?: reg_r0 <= w_init_b;
        4'b0001: reg_r0 <= w_s_nxt;
        default: begin
          // Idle, last pair delivered, or frozen ring: R0 holds.
        end
      endcase
      // Ring register R1 follows stage 1 whenever the ring moves.
      if (w_ldb | (w_run & ~w_stall))
        reg_r1 <= w_f1;
      // Queue entries: shift on a take, then place the delivered pair.
      reg_q0_st  <= w_st0t;
      reg_q0_ctr <= w_ctr0t;
      reg_q1_st  <= w_st1t;
      reg_q1_ctr <= w_ctr1t;
      if (w_dlv) begin
        if (w_v0t) begin
          reg_q1_st  <= reg_r0;
          reg_q1_ctr <= reg_ctr_a;
        end else begin
          reg_q0_st  <= reg_r0;
          reg_q0_ctr <= reg_ctr_a;
          reg_q1_st  <= w_s_nxt;
          reg_q1_ctr <= w_ctr_b;
        end
      end
    end
  end

endmodule
