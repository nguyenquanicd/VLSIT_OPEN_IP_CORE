/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-25
 * Description  : Random source of the digital signature IP (OP-007, REQ-SEC-007, DEC-014). At the
 *                start pulse of the control block (ENUM_ST_RNG) it delivers a pool of 96 random
 *                bytes (768 bits, byte i in bits [8 i +: 8]). PARA_RNG_SRC 0: the pool is read
 *                from the entropy port (o_ent_req stays high, one 32-bit word per cycle with
 *                i_ent_valid). PARA_RNG_SRC 1: the pool is the output of the Hash_DRBG
 *                m_vlsit_dsig_drbg (SHA-512, SP 800-90A); 96 entropy bytes are read first when the
 *                generator is not instantiated, when the reseed command of the CSR is pending or
 *                when the reseed counter exceeds PARA_RESEED_INT, and they seed the generator. A
 *                word that does not arrive within i_tmo_ent units of 1024 clocks gives a
 *                one-cycle o_tmo pulse and clears the pool. o_done is a one-cycle pulse when the
 *                pool is ready. The clear input empties the pool (the generator keeps its state).
 *                o_ready is 1 when the generator is instantiated (always 1 for the entropy port)
 *                and o_due when a reseed is needed. Health test (SP 800-90A section 11.3): before
 *                the first use the generator runs instantiate with the fixed entropy KAT_E1,
 *                generate, reseed with KAT_E2 and generate; the second output must equal
 *                f_kat_out() (computed with the model written from SP 800-90A). On success the
 *                generator is uninstantiated and the normal instantiation follows; on failure the
 *                random block stays in an error state until reset: every request ends with
 *                o_tmo (dsig_err.enttmo, dsig_alarm.rngfail) and o_ready is 0. The test outputs
 *                are never delivered as the pool. Requirements: REQ-SEC-007, OP-007, DEC-014.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_rng #(
  // Parameter Description: source of the random bytes: 0 entropy port, 1 Hash_DRBG seeded by it.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: code
  parameter logic [31:0] PARA_RNG_SRC = 0,
  // Parameter Description: generate requests between two seeds of the Hash_DRBG.
  // Parameter values: 1 to 2^32 - 1; default is 1024.
  // Parameter unit: request
  parameter logic [31:0] PARA_RESEED_INT = 1024
) (
  // Clock, reset and clearing
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,
  input  wire          i_clr,

  // Handshake with the control block
  input  wire          i_start,
  input  wire  [15:0]  i_tmo_ent,
  output logic         o_done,
  output logic         o_tmo,

  // Entropy port
  output logic         o_ent_req,
  input  wire          i_ent_valid,
  input  wire  [31:0]  i_ent_data,

  // CSR: reseed command (taken at once) and status
  input  wire          i_reseed,
  output logic         o_reseed_clr,
  output logic         o_ready,
  output logic         o_due,

  // Pool for the engines
  output logic [767:0] o_pool,
  output logic         o_cleared,

  // Hash arbiter side (Hash_DRBG; inactive when PARA_RNG_SRC is 0)
  output logic         o_hs_req,
  input  wire          i_hs_grant,
  output logic         o_hs_start,
  output logic [3:0]   o_hs_mode,
  output logic [15:0]  o_hs_outlen,
  output logic         o_hs_in_valid,
  output logic [63:0]  o_hs_in_data,
  output logic [3:0]   o_hs_in_nb,
  output logic         o_hs_in_last,
  input  wire          i_hs_in_ready,
  input  wire          i_hs_out_valid,
  input  wire  [63:0]  i_hs_out_data,
  input  wire  [3:0]   i_hs_out_nb,
  input  wire          i_hs_out_last,
  output logic         o_hs_out_ready
);

  // States
  typedef enum logic [3:0] {
    ENUM_ST_IDLE = 4'd0,
    ENUM_ST_REQ  = 4'd1,
    ENUM_ST_DONE = 4'd2,
    ENUM_ST_TMO  = 4'd3,
    ENUM_ST_SEED = 4'd4,
    ENUM_ST_GEN  = 4'd5,
    ENUM_ST_KS1  = 4'd6,
    ENUM_ST_KG1  = 4'd7,
    ENUM_ST_KS2  = 4'd8,
    ENUM_ST_KG2  = 4'd9,
    ENUM_ST_KCHK = 4'd10
  } rng_state_type_def;

  // Constants of the health test (SP 800-90A section 11.3): fixed entropy of the instantiate
  // and the reseed steps and the expected second output, computed with
  // verification/models/rng/hash_drbg_ref.py.
  function automatic logic [767:0] f_kat_e1();
    f_kat_e1 = 768'hfafbf8f9fefffcfdf2f3f0f1f6f7f4f5eaebe8e9eeefecede2e3e0e1e6e7e4e59a9b98999e9f9c9d92939091969794958a8b88898e8f8c8d8283808186878485babbb8b9bebfbcbdb2b3b0b1b6b7b4b5aaaba8a9aeafacada2a3a0a1a6a7a4a5;
  endfunction

  function automatic logic [767:0] f_kat_e2();
    f_kat_e2 = 768'h595653504d4a4744413e3b3835322f2c292623201d1a1714110e0b080502fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b4845423f3c;
  endfunction

  function automatic logic [767:0] f_kat_out();
    f_kat_out = 768'hd772af4d1e450cc101105abddc666d119b3f70326a92b62afa4dea8b11074c0e63b60b605917aaa96605e064f43f99a17c1b31f37c6c28828e96cfdea9910a2bf28e4e339f5e06ccc2eb682b0b625b8f070e8ba1271e3ca126441e3d9efa1509;
  endfunction

  // Internal signal declarations
  rng_state_type_def reg_fsm_rng_current_state;
  rng_state_type_def w_fsm_rng_nxt_state;
  logic [767:0]  reg_pool;
  logic [4:0]    reg_cnt;
  logic [25:0]   reg_tmo_cnt;
  logic [25:0]   w_tmo_lim;
  logic          w_tmo_hit;
  logic          reg_rs_pend;
  logic          reg_go;
  logic          w_drbg_done;
  logic          w_drbg_inst;
  logic          w_drbg_due;
  logic [767:0]  w_drbg_pool;
  logic          w_need_seed;
  logic          w_src_drbg;
  logic          reg_kat_done;
  logic          reg_kat_fail;
  logic          w_seed_st;
  logic          w_gen_st;

  assign w_tmo_lim = {((i_tmo_ent == 16'd0) ? 16'd1 : i_tmo_ent), 10'd0};
  assign w_tmo_hit = (reg_tmo_cnt >= w_tmo_lim);

  assign o_ent_req    = (reg_fsm_rng_current_state == ENUM_ST_REQ);
  assign o_done       = (reg_fsm_rng_current_state == ENUM_ST_DONE);
  assign o_tmo        = (reg_fsm_rng_current_state == ENUM_ST_TMO);
  assign w_src_drbg   = (PARA_RNG_SRC == 32'd1);
  assign w_need_seed  = ~w_drbg_inst | reg_rs_pend | w_drbg_due;
  assign o_reseed_clr = i_reseed;
  assign o_ready      = w_src_drbg ? (w_drbg_inst & reg_kat_done & ~reg_kat_fail) : 1'b1;
  // states that give a seed or a generate command to the Hash_DRBG
  assign w_seed_st    = (w_fsm_rng_nxt_state == ENUM_ST_SEED) | (w_fsm_rng_nxt_state == ENUM_ST_KS1) |
                        (w_fsm_rng_nxt_state == ENUM_ST_KS2);
  assign w_gen_st     = (w_fsm_rng_nxt_state == ENUM_ST_GEN) | (w_fsm_rng_nxt_state == ENUM_ST_KG1) |
                        (w_fsm_rng_nxt_state == ENUM_ST_KG2);
  assign o_due        = w_src_drbg ? (w_drbg_due | reg_rs_pend) : 1'b0;
  assign o_pool       = w_src_drbg ? w_drbg_pool : reg_pool;
  assign o_cleared    = ~(|reg_pool) & ~(|w_drbg_pool);

  // Hash_DRBG (PARA_RNG_SRC 1)
  generate
    if (PARA_RNG_SRC == 32'd1) begin : g_drbg
      m_vlsit_dsig_drbg #(
        .PARA_RESEED_INT (PARA_RESEED_INT)
      ) u_drbg (
        .i_clk_core      (i_clk_core),
        .i_rst_n_core    (i_rst_n_core),
        .i_clr           (i_clr),
        .i_zero          (reg_fsm_rng_current_state == ENUM_ST_KCHK),
        .i_seed          (reg_go & ((reg_fsm_rng_current_state == ENUM_ST_SEED) |
                                    (reg_fsm_rng_current_state == ENUM_ST_KS1) |
                                    (reg_fsm_rng_current_state == ENUM_ST_KS2))),
        .i_gen           (reg_go & ((reg_fsm_rng_current_state == ENUM_ST_GEN) |
                                    (reg_fsm_rng_current_state == ENUM_ST_KG1) |
                                    (reg_fsm_rng_current_state == ENUM_ST_KG2))),
        .i_ent           (reg_pool),
        .o_done          (w_drbg_done),
        .o_inst          (w_drbg_inst),
        .o_due           (w_drbg_due),
        .o_pool          (w_drbg_pool),
        .o_hs_req        (o_hs_req),
        .i_hs_grant      (i_hs_grant),
        .o_hs_start      (o_hs_start),
        .o_hs_mode       (o_hs_mode),
        .o_hs_outlen     (o_hs_outlen),
        .o_hs_in_valid   (o_hs_in_valid),
        .o_hs_in_data    (o_hs_in_data),
        .o_hs_in_nb      (o_hs_in_nb),
        .o_hs_in_last    (o_hs_in_last),
        .i_hs_in_ready   (i_hs_in_ready),
        .i_hs_out_valid  (i_hs_out_valid),
        .i_hs_out_data   (i_hs_out_data),
        .i_hs_out_nb     (i_hs_out_nb),
        .i_hs_out_last   (i_hs_out_last),
        .o_hs_out_ready  (o_hs_out_ready)
      );
    end else begin : g_no_drbg
      assign w_drbg_done    = 1'b0;
      assign w_drbg_inst    = 1'b0;
      assign w_drbg_due     = 1'b0;
      assign w_drbg_pool    = 768'd0;
      assign o_hs_req       = 1'b0;
      assign o_hs_start     = 1'b0;
      assign o_hs_mode      = 4'd0;
      assign o_hs_outlen    = 16'd0;
      assign o_hs_in_valid  = 1'b0;
      assign o_hs_in_data   = 64'd0;
      assign o_hs_in_nb     = 4'd0;
      assign o_hs_in_last   = 1'b0;
      assign o_hs_out_ready = 1'b0;
    end
  endgenerate

  // Part 1 of the FSM: state register.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_rng
    if (!i_rst_n_core)
      reg_fsm_rng_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_rng_current_state <= w_fsm_rng_nxt_state;
  end

  // Part 2 of the FSM: next state.
  always_comb begin : p_com_fsm_nxt
    w_fsm_rng_nxt_state = reg_fsm_rng_current_state;
    case (reg_fsm_rng_current_state)
      ENUM_ST_IDLE: begin
        if (i_start) begin
          casez ({w_src_drbg, reg_kat_fail, reg_kat_done, w_need_seed})
            4'b0???: w_fsm_rng_nxt_state = ENUM_ST_REQ;
            4'b11??: w_fsm_rng_nxt_state = ENUM_ST_TMO;
            4'b100?: w_fsm_rng_nxt_state = ENUM_ST_KS1;
            4'b1011: w_fsm_rng_nxt_state = ENUM_ST_REQ;
            default: w_fsm_rng_nxt_state = ENUM_ST_GEN;
          endcase
        end
      end
      ENUM_ST_REQ: begin
        if (w_tmo_hit)
          w_fsm_rng_nxt_state = ENUM_ST_TMO;
        else if (i_ent_valid & (reg_cnt == 5'd23))
          w_fsm_rng_nxt_state = w_src_drbg ? ENUM_ST_SEED : ENUM_ST_DONE;
      end
      ENUM_ST_SEED: begin
        if (w_drbg_done)
          w_fsm_rng_nxt_state = ENUM_ST_GEN;
      end
      ENUM_ST_GEN: begin
        if (w_drbg_done)
          w_fsm_rng_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_KS1: begin
        if (w_drbg_done)
          w_fsm_rng_nxt_state = ENUM_ST_KG1;
      end
      ENUM_ST_KG1: begin
        if (w_drbg_done)
          w_fsm_rng_nxt_state = ENUM_ST_KS2;
      end
      ENUM_ST_KS2: begin
        if (w_drbg_done)
          w_fsm_rng_nxt_state = ENUM_ST_KG2;
      end
      ENUM_ST_KG2: begin
        if (w_drbg_done)
          w_fsm_rng_nxt_state = ENUM_ST_KCHK;
      end
      ENUM_ST_KCHK: begin
        if (w_drbg_pool == f_kat_out())
          w_fsm_rng_nxt_state = ENUM_ST_REQ;
        else
          w_fsm_rng_nxt_state = ENUM_ST_TMO;
      end
      ENUM_ST_DONE: w_fsm_rng_nxt_state = ENUM_ST_IDLE;
      ENUM_ST_TMO:  w_fsm_rng_nxt_state = ENUM_ST_IDLE;
      default:      w_fsm_rng_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_rng_nxt_state = ENUM_ST_IDLE;
  end

  // Data registers: pool, word counter and timeout counter.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
    if (!i_rst_n_core) begin
      reg_pool    <= 768'd0;
      reg_cnt     <= 5'd0;
      reg_tmo_cnt <= 26'd0;
      reg_rs_pend <= 1'b0;
      reg_go      <= 1'b0;
      reg_kat_done <= 1'b0;
      reg_kat_fail <= 1'b0;
    end
    else if (i_clr) begin
      reg_pool    <= 768'd0;
      reg_cnt     <= 5'd0;
      reg_tmo_cnt <= 26'd0;
      reg_go      <= 1'b0;
    end
    else begin
      // one-cycle command pulse to the Hash_DRBG at the entry of ENUM_ST_SEED and ENUM_ST_GEN
      reg_go <= (w_seed_st | w_gen_st) & (w_fsm_rng_nxt_state != reg_fsm_rng_current_state);
      if (i_reseed)
        reg_rs_pend <= 1'b1;
      case (reg_fsm_rng_current_state)
        ENUM_ST_IDLE: begin
          reg_cnt     <= 5'd0;
          reg_tmo_cnt <= 26'd0;
          // health test: the fixed entropy of the instantiate step
          if (i_start & w_src_drbg & ~reg_kat_done & ~reg_kat_fail)
            reg_pool <= f_kat_e1();
        end
        ENUM_ST_KG1: begin
          // the fixed entropy of the reseed step
          if (w_drbg_done)
            reg_pool <= f_kat_e2();
        end
        ENUM_ST_KCHK: begin
          reg_pool     <= 768'd0;
          reg_kat_done <= (w_drbg_pool == f_kat_out());
          reg_kat_fail <= (w_drbg_pool != f_kat_out());
        end
        ENUM_ST_REQ: begin
          if (i_ent_valid) begin
            reg_pool[32 * reg_cnt +: 32] <= i_ent_data;
            reg_cnt     <= reg_cnt + 5'd1;
            reg_tmo_cnt <= 26'd0;
          end else begin
            reg_tmo_cnt <= reg_tmo_cnt + 26'd1;
          end
        end
        ENUM_ST_TMO: begin
          reg_pool <= 768'd0;
        end
        ENUM_ST_SEED: begin
          // the entropy bytes are consumed by the seed: clear them when it ends
          if (w_drbg_done) begin
            reg_pool    <= 768'd0;
            reg_rs_pend <= 1'b0;
          end
        end
        default: begin
          reg_cnt <= 5'd0;
        end
      endcase
    end
  end

endmodule
