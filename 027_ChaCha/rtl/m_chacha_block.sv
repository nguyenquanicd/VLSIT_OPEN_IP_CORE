/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : One ChaCha20 core (RFC 8439 sections 2.3 and 2.4). After a load it free-runs and
 *                produces one 64-byte keystream block every C core cycles, with C = ceil(20 / R) *
 *                (4 / Q), R = PARA_RND_CYC rounds per cycle and Q = PARA_QR_NUM quarter-round
 *                units: 80, 40, 20 or 10 cycles. A column round is followed by a row rotation that
 *                turns the diagonals into columns and the inverse rotation follows the diagonal
 *                round, so one set of units serves both round types. With Q below 4 the columns
 *                shift through the units, Q at a time. The finished state waits in one output
 *                register; the block output is that state plus the initial state, formed on the
 *                way out, so the core restarts at once on the next counter without a lost cycle.
 *                The key and the nonce inputs shall stay stable while blocks are produced.
 * Decisions    : DEC-008, DEC-030
 */
`timescale 1ns/1ps

module m_chacha_block #(
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

  // FSM states: IDLE waits for a load, RUN executes the iterations of one block, WAIT holds a
  // finished state until the output register is free. The encoding 2'b11 recovers to IDLE.
  typedef enum logic [1:0] {
    ENUM_ST_IDLE = 2'b00,
    ENUM_ST_RUN  = 2'b01,
    ENUM_ST_WAIT = 2'b10
  } blk_state_type_def;

  // Internal signal declarations
  blk_state_type_def reg_fsm_blk_current_state;
  blk_state_type_def w_fsm_blk_nxt_state;
  logic [511:0]      reg_st;
  logic [511:0]      reg_out;
  logic [31:0]       reg_ctr;
  logic [31:0]       reg_ctr_out;
  logic [3:0]        reg_step;
  logic [10:0]       reg_rem;
  logic [6:0]        reg_left;
  logic [1:0]        reg_sub;
  logic              reg_par;
  logic              reg_out_vld;
  logic [511:0]      w_x;
  logic [511:0]      w_x2;
  logic [511:0]      w_y;
  logic [511:0]      w_s_nxt;
  logic [511:0]      w_init_new;
  logic [511:0]      w_init_out;
  logic [31:0]       w_ctr_new;
  logic              w_last;
  logic              w_last_sub;
  logic              w_out_free;
  logic              w_blk_done;
  logic              w_more;
  logic              w_ld_out;
  logic              w_load_new;
  logic              w_run_cnt;
  logic              w_run;

  // Initial state of one block (RFC 8439 section 2.3): four constants, eight key words, the block
  // counter and three nonce words, word 0 in the low 32 bits.
  function automatic logic [511:0] f_init (
    input logic [255:0] a_key,
    input logic [31:0]  a_ctr,
    input logic [95:0]  a_nonce
  );
    f_init = {a_nonce, a_ctr, a_key, LPARA_SIGMA3, LPARA_SIGMA2, LPARA_SIGMA1, LPARA_SIGMA0};
  endfunction

  // Diagonalization: row 1 rotates left by one word, row 2 by two and row 3 by three, so that the
  // diagonals of the state become its columns. Row r is words 4r to 4r+3.
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

  // Inverse of f_diag: row 1 rotates right by one word, row 2 by two and row 3 by three.
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

  // Column rotation: column j of the result is column (j + Q) mod 4 of the input, where column j
  // is words j, j+4, j+8 and j+12. With Q = 4 it is the identity.
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

  // First layer of quarter-round units: the head columns 0 to Q-1 of the state go through a unit,
  // the other columns pass unchanged.
  for (genvar gen_idx = 0; gen_idx < 4; gen_idx++) begin : gen_col
    if (gen_idx < PARA_QR_NUM) begin : gen_qr
      m_chacha_qr u_qr (
        .i_a (reg_st[32*gen_idx +: 32]),
        .i_b (reg_st[32*(4+gen_idx) +: 32]),
        .i_c (reg_st[32*(8+gen_idx) +: 32]),
        .i_d (reg_st[32*(12+gen_idx) +: 32]),
        .o_a (w_x[32*gen_idx +: 32]),
        .o_b (w_x[32*(4+gen_idx) +: 32]),
        .o_c (w_x[32*(8+gen_idx) +: 32]),
        .o_d (w_x[32*(12+gen_idx) +: 32])
      );
    end else begin : gen_pass
      assign w_x[32*gen_idx +: 32]      = reg_st[32*gen_idx +: 32];
      assign w_x[32*(4+gen_idx) +: 32]  = reg_st[32*(4+gen_idx) +: 32];
      assign w_x[32*(8+gen_idx) +: 32]  = reg_st[32*(8+gen_idx) +: 32];
      assign w_x[32*(12+gen_idx) +: 32] = reg_st[32*(12+gen_idx) +: 32];
    end
  end

  // Second layer (two rounds per cycle only): the four columns of the diagonalized first result
  // go through a second set of units; with one round per cycle the layer is not used.
  for (genvar gen_idx2 = 0; gen_idx2 < 4; gen_idx2++) begin : gen_col2
    if (PARA_RND_CYC == 32'd2) begin : gen_qr2
      logic [511:0] w_d;
      assign w_d = f_diag(w_x);
      m_chacha_qr u_qr (
        .i_a (w_d[32*gen_idx2 +: 32]),
        .i_b (w_d[32*(4+gen_idx2) +: 32]),
        .i_c (w_d[32*(8+gen_idx2) +: 32]),
        .i_d (w_d[32*(12+gen_idx2) +: 32]),
        .o_a (w_x2[32*gen_idx2 +: 32]),
        .o_b (w_x2[32*(4+gen_idx2) +: 32]),
        .o_c (w_x2[32*(8+gen_idx2) +: 32]),
        .o_d (w_x2[32*(12+gen_idx2) +: 32])
      );
    end else begin : gen_nopass
      assign w_x2[32*gen_idx2 +: 32]      = 32'd0;
      assign w_x2[32*(4+gen_idx2) +: 32]  = 32'd0;
      assign w_x2[32*(8+gen_idx2) +: 32]  = 32'd0;
      assign w_x2[32*(12+gen_idx2) +: 32] = 32'd0;
    end
  end

  // Column rotation after the first layer.
  assign w_y = f_rotcol(w_x);

  // Round bookkeeping: the last sub-step of a round, the last iteration of a block.
  assign w_last_sub = (reg_sub == 2'(LPARA_STEPS - 32'd1));
  assign w_last     = (reg_left == 7'd0);

  // State after this iteration. Two rounds per cycle: double round, back in the original
  // orientation. One round per cycle: rotate the columns, and at the last sub-step of a round
  // diagonalize after a column round or undo it after a diagonal round.
  always_comb begin : p_com_s_nxt
    w_s_nxt = w_y;
    if (PARA_RND_CYC == 32'd2)
      w_s_nxt = f_undiag(w_x2);
    else if (w_last_sub) begin
      if (reg_par)
        w_s_nxt = f_undiag(w_y);
      else
        w_s_nxt = f_diag(w_y);
    end
  end

  // Initial state of the next block (counter plus the step) and of the block in the output
  // register.
  assign w_ctr_new  = $bits(w_ctr_new)'(reg_ctr + 32'(reg_step));
  assign w_init_new = f_init(i_key, w_ctr_new, i_nonce);
  assign w_init_out = f_init(i_key, reg_ctr_out, i_nonce);

  // Output register status: free when empty or when the consumer takes the block this cycle.
  assign w_out_free = ~reg_out_vld | i_take;

  // A block leaves the state register in the last iteration when the output is free, or from the
  // wait state when the output becomes free; more blocks follow when more than one is left.
  assign w_blk_done = ((reg_fsm_blk_current_state == ENUM_ST_RUN) & w_last & w_out_free) |
                      ((reg_fsm_blk_current_state == ENUM_ST_WAIT) & w_out_free);
  assign w_more     = (reg_rem > 11'd1);
  assign w_ld_out   = w_blk_done;

  // A load is accepted in IDLE; one more iteration of a running block counts down while the
  // block is neither at its last iteration nor delivered.
  assign w_load_new = (reg_fsm_blk_current_state == ENUM_ST_IDLE) & i_load;
  assign w_run      = (reg_fsm_blk_current_state == ENUM_ST_RUN);
  assign w_run_cnt  = w_run & ~w_last;

  // Block output: finished state plus the initial state, word by word, modulo 2^32.
  always_comb begin : p_com_blk_out
    o_blk = '0;
    for (int idx = 0; idx < 16; idx++)
      o_blk[32*idx +: 32] = $bits(o_blk[31:0])'(reg_out[32*idx +: 32] + w_init_out[32*idx +: 32]);
  end
  assign o_blk_vld = reg_out_vld;

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_blk
    if (!i_rst_n_core)
      reg_fsm_blk_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_blk_current_state <= w_fsm_blk_nxt_state;
  end

  // Part 2 of the FSM: IDLE goes to RUN on a load with at least one block; RUN goes to IDLE or RUN
  // when the block is delivered, to WAIT when the output register is still full; WAIT delivers
  // when the output frees up. A clear returns to IDLE.
  always_comb begin : p_com_fsm_nxt
    w_fsm_blk_nxt_state = reg_fsm_blk_current_state;
    case (reg_fsm_blk_current_state)
      ENUM_ST_IDLE: begin
        if (i_load & (i_blk_cnt != 11'd0))
          w_fsm_blk_nxt_state = ENUM_ST_RUN;
      end
      ENUM_ST_RUN: begin
        if (w_last & w_out_free & ~w_more)
          w_fsm_blk_nxt_state = ENUM_ST_IDLE;
        else if (w_last & ~w_out_free)
          w_fsm_blk_nxt_state = ENUM_ST_WAIT;
      end
      ENUM_ST_WAIT: begin
        if (w_out_free & ~w_more)
          w_fsm_blk_nxt_state = ENUM_ST_IDLE;
        else if (w_out_free)
          w_fsm_blk_nxt_state = ENUM_ST_RUN;
      end
      default: w_fsm_blk_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_blk_nxt_state = ENUM_ST_IDLE;
  end

  // Control registers: remaining blocks, iterations left, round position and parity, counter
  // step and the valid flag of the output register. They are reset to idle values.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
    if (!i_rst_n_core) begin
      reg_rem     <= 11'd0;
      reg_left    <= 7'd0;
      reg_sub     <= 2'd0;
      reg_par     <= 1'b0;
      reg_step    <= 4'd1;
      reg_out_vld <= 1'b0;
    end else if (i_clr) begin
      reg_rem     <= 11'd0;
      reg_left    <= 7'd0;
      reg_sub     <= 2'd0;
      reg_par     <= 1'b0;
      reg_out_vld <= 1'b0;
    end else begin
      // The output register becomes empty when taken and full when a block is loaded into it.
      if (w_ld_out)
        reg_out_vld <= 1'b1;
      else if (i_take)
        reg_out_vld <= 1'b0;
      // Priority: a load in IDLE, then the end of a block, then one more iteration of a block.
      casez ({w_load_new, w_blk_done, w_run_cnt})
        3'b1??: begin
          reg_rem  <= i_blk_cnt;
          reg_step <= i_ctr_step;
          reg_left <= 7'(LPARA_ITER - 32'd1);
          reg_sub  <= 2'd0;
          reg_par  <= 1'b0;
        end
        3'b01?: begin
          reg_rem  <= $bits(reg_rem)'(reg_rem - 11'd1);
          reg_left <= 7'(LPARA_ITER - 32'd1);
          reg_sub  <= 2'd0;
          reg_par  <= 1'b0;
        end
        3'b001: begin
          reg_left <= $bits(reg_left)'(reg_left - 7'd1);
          reg_sub  <= w_last_sub ? 2'd0 : $bits(reg_sub)'(reg_sub + 2'd1);
          reg_par  <= w_last_sub ? ~reg_par : reg_par;
        end
        default: begin
          // No block event: the round counters hold.
        end
      endcase
    end
  end

  // Secret datapath registers: no reset, because the state flag, the valid flag and the remaining
  // block count qualify them; they are cleared at the end of a message (REQ-SEC-004).
  always_ff @(posedge i_clk_core) begin : p_ff_state
    if (i_clr) begin
      reg_st      <= '0;
      reg_out     <= '0;
      reg_ctr     <= '0;
      reg_ctr_out <= '0;
    end else begin
      // Priority: initial state of a load, initial state of the next block, next round state.
      casez ({w_load_new, w_blk_done & w_more, w_run})
        3'b1??: begin
          reg_st  <= f_init(i_key, i_ctr0, i_nonce);
          reg_ctr <= i_ctr0;
        end
        3'b01?: begin
          reg_st  <= w_init_new;
          reg_ctr <= w_ctr_new;
        end
        3'b001: reg_st <= w_s_nxt;
        default: begin
          // Waiting or idle: the state register holds.
        end
      endcase
      if (w_ld_out) begin
        reg_out     <= (reg_fsm_blk_current_state == ENUM_ST_WAIT) ? reg_st : w_s_nxt;
        reg_ctr_out <= reg_ctr;
      end
    end
  end

endmodule
