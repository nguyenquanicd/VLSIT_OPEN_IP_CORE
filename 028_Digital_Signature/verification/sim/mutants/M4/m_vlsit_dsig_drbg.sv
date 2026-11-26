/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Opus 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-25
 * Description  : Hash_DRBG of NIST SP 800-90A Rev. 1 with SHA-512 (seedlen 888 bits) for the
 *                random block of the digital signature IP (PARA_RNG_SRC = 1, DEC-014,
 *                REQ-SEC-007). i_seed (one-cycle pulse) seeds the generator from the 96 bytes of
 *                i_ent: instantiation (section 10.1.1.2, entropy_input = bytes 0 to 63, nonce =
 *                bytes 64 to 95) when it is not instantiated yet, otherwise a reseed (section
 *                10.1.1.3, entropy_input = the 96 bytes). i_gen (one-cycle pulse) runs the
 *                generate function (section 10.1.1.4) for 96 bytes into o_pool (byte i in bits
 *                [8 i +: 8]). No personalization string and no additional input. Hash_df is
 *                section 10.3.1. Every hash is one job of the hash feeder on the shared hash
 *                engine (mode SHA-512). o_done is a one-cycle pulse at the end of a seed or a
 *                generate. The working state (V, C, reseed counter) is kept between operations
 *                and cleared by reset; i_clr clears the output pool only. o_due is set when the
 *                reseed counter exceeds PARA_RESEED_INT. Byte strings are big-endian integers
 *                (SP 800-90A section 5): byte 0 of V is V[887:880]. i_zero (one-cycle pulse)
 *                uninstantiates the generator (working state and pool cleared).
 */
`timescale 1ns/1ps

module m_vlsit_dsig_drbg #(
  // Parameter Description: generate requests allowed between two seeds (reseed_interval).
  // Parameter values: 1 to 2^32 - 1 (SP 800-90A allows up to 2^48); default is 1024.
  // Parameter unit: request
  parameter logic [31:0] PARA_RESEED_INT = 1024,
  localparam logic [31:0] LPARA_H_SHA512 = 3
) (
  // Clock, reset and clearing of the pool
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,
  input  wire          i_clr,

  // Commands and entropy
  input  wire          i_zero,
  input  wire          i_seed,
  input  wire          i_gen,
  input  wire  [767:0] i_ent,
  output logic         o_done,
  output logic         o_inst,
  output logic         o_due,
  output logic [767:0] o_pool,

  // Hash arbiter side
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

  // Steps: Hash_df of the seed material (two blocks), Hash_df of 0x00 || V (two blocks), Hashgen
  // (two blocks), Hash (0x03 || V), then the two additions of the state update.
  typedef enum logic [3:0] {
    ENUM_ST_IDLE  = 4'd0,
    ENUM_ST_DF1   = 4'd1,
    ENUM_ST_DF2   = 4'd2,
    ENUM_ST_DC1   = 4'd3,
    ENUM_ST_DC2   = 4'd4,
    ENUM_ST_G1    = 4'd5,
    ENUM_ST_G2    = 4'd6,
    ENUM_ST_G3    = 4'd7,
    ENUM_ST_ADDC  = 4'd8,
    ENUM_ST_ADDH  = 4'd9,
    ENUM_ST_DONE  = 4'd10
  } drbg_state_type_def;

  // Internal signal declarations
  drbg_state_type_def reg_fsm_drbg_current_state;
  drbg_state_type_def w_fsm_drbg_nxt_state;
  logic [887:0]   reg_v;
  logic [887:0]   reg_c;
  logic [31:0]    reg_cnt;
  logic           reg_inst;
  logic           reg_reseed;
  logic [767:0]   reg_ent;
  logic [511:0]   reg_t1;
  logic [511:0]   reg_h;
  logic [767:0]   reg_pool;
  logic           reg_go;
  logic [2047:0]  w_head;
  logic [8:0]     w_head_len;
  logic [511:0]   w_dig;
  logic           w_hf_done;
  logic [887:0]   w_vstr;
  logic [887:0]   w_v1str;
  logic [887:0]   w_df_int;
  logic [511:0]   w_h_int;

  // Byte string of an 888-bit integer (byte 0 = most significant byte) and its inverse.
  function automatic logic [887:0] f_str(input logic [887:0] x);
    logic [887:0] r;
    begin
      for (int k = 0; k < 111; k++)
        r[8*k +: 8] = x[8*(110-k) +: 8];
      f_str = r;
    end
  endfunction

  // Integer of a 64-byte string (byte 0 = most significant byte).
  function automatic logic [511:0] f_int64(input logic [511:0] x);
    logic [511:0] r;
    begin
      for (int k = 0; k < 64; k++)
        r[8*k +: 8] = x[8*(63-k) +: 8];
      f_int64 = r;
    end
  endfunction

  assign w_vstr   = f_str(reg_v);
  assign w_v1str  = f_str(reg_v + 888'd1);
  // V or C from the two Hash_df blocks: bytes 0 to 63 of block 1 and 0 to 46 of block 2
  assign w_df_int = f_str({w_dig[375:0], reg_t1});
  assign w_h_int  = f_int64(w_dig);

  // Hash input of each step: counter || no_of_bits_to_return (888 = 0x00000378) || input_string
  always_comb begin : p_com_head
    w_head     = 2048'd0;
    w_head_len = 9'd0;
    case (reg_fsm_drbg_current_state)
      ENUM_ST_DF1,
      ENUM_ST_DF2: begin
        if (reg_reseed) begin
          w_head     = 2048'({reg_ent, w_vstr, 8'h01, 8'h78, 8'h03, 8'h00, 8'h00,
                               (reg_fsm_drbg_current_state == ENUM_ST_DF1) ? 8'h01 : 8'h02});
          w_head_len = 9'd213;
        end else begin
          w_head     = 2048'({reg_ent, 8'h78, 8'h03, 8'h00, 8'h00,
                               (reg_fsm_drbg_current_state == ENUM_ST_DF1) ? 8'h01 : 8'h02});
          w_head_len = 9'd101;
        end
      end
      ENUM_ST_DC1,
      ENUM_ST_DC2: begin
        w_head     = 2048'({w_vstr, 8'h00, 8'h78, 8'h03, 8'h00, 8'h00,
                             (reg_fsm_drbg_current_state == ENUM_ST_DC1) ? 8'h01 : 8'h02});
        w_head_len = 9'd117;
      end
      ENUM_ST_G1: begin
        w_head     = 2048'(w_vstr);
        w_head_len = 9'd111;
      end
      ENUM_ST_G2: begin
        w_head     = 2048'(w_v1str);
        w_head_len = 9'd111;
      end
      ENUM_ST_G3: begin
        w_head     = 2048'({w_vstr, 8'h03});
        w_head_len = 9'd112;
      end
      default: begin
        w_head     = 2048'd0;
        w_head_len = 9'd0;
      end
    endcase
  end

  m_vlsit_dsig_hfeed #(.PARA_HEAD_BYTES(256), .PARA_DIG_BYTES(64), .PARA_TA_W(24), .PARA_MID_BYTES(8)) u_hfeed (
    .i_clk_core     (i_clk_core),
    .i_rst_n_core   (i_rst_n_core),
    .i_clr          (1'b0),
    .i_go           (reg_go),
    .i_mode         (LPARA_H_SHA512[3:0]),
    .i_outlen       (16'd0),
    .i_head         (w_head),
    .i_head_len     (w_head_len),
    .i_tail_addr    (24'd0),
    .i_tail_len     (24'd0),
    .i_tail2_addr   (24'd0),
    .i_tail2_len    (24'd0),
    .i_mid          (64'd0),
    .i_mid_len      (9'd0),
    .o_digest       (w_dig),
    .o_done         (w_hf_done),
    .o_busy         (),
    .o_tr_en        (),
    .o_tr_addr      (),
    .i_tr_data      (64'd0),
    .i_tr_valid     (1'b0),
    .o_hs_req       (o_hs_req),
    .i_hs_grant     (i_hs_grant),
    .o_hs_start     (o_hs_start),
    .o_hs_mode      (o_hs_mode),
    .o_hs_outlen    (o_hs_outlen),
    .o_hs_in_valid  (o_hs_in_valid),
    .o_hs_in_data   (o_hs_in_data),
    .o_hs_in_nb     (o_hs_in_nb),
    .o_hs_in_last   (o_hs_in_last),
    .i_hs_in_ready  (i_hs_in_ready),
    .i_hs_out_valid (i_hs_out_valid),
    .i_hs_out_data  (i_hs_out_data),
    .i_hs_out_nb    (i_hs_out_nb),
    .i_hs_out_last  (i_hs_out_last),
    .o_hs_out_ready (o_hs_out_ready)
  );

  // Outputs
  assign o_done = (reg_fsm_drbg_current_state == ENUM_ST_DONE);
  assign o_inst = reg_inst;
  assign o_due  = (reg_cnt > PARA_RESEED_INT);
  assign o_pool = reg_pool;

  // ---------------------------------------------------------------------------------------------
  // FSM
  // ---------------------------------------------------------------------------------------------
  // Part 1: state register
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_drbg
    if (!i_rst_n_core)
      reg_fsm_drbg_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_drbg_current_state <= w_fsm_drbg_nxt_state;
  end

  // Part 2: next state
  always_comb begin : p_com_fsm_nxt
    w_fsm_drbg_nxt_state = reg_fsm_drbg_current_state;
    case (reg_fsm_drbg_current_state)
      ENUM_ST_IDLE: begin
        if (i_seed)
          w_fsm_drbg_nxt_state = ENUM_ST_DF1;
        else if (i_gen)
          w_fsm_drbg_nxt_state = ENUM_ST_G1;
      end
      ENUM_ST_DF1: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_DF2;
      end
      ENUM_ST_DF2: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_DC1;
      end
      ENUM_ST_DC1: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_DC2;
      end
      ENUM_ST_DC2: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_G1: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_G2;
      end
      ENUM_ST_G2: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_G3;
      end
      ENUM_ST_G3: begin
        if (w_hf_done)
          w_fsm_drbg_nxt_state = ENUM_ST_ADDC;
      end
      ENUM_ST_ADDC: w_fsm_drbg_nxt_state = ENUM_ST_ADDH;
      ENUM_ST_ADDH: w_fsm_drbg_nxt_state = ENUM_ST_DONE;
      default:      w_fsm_drbg_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Part 3: datapath
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_drbg
    if (!i_rst_n_core) begin
      reg_v      <= 888'd0;
      reg_c      <= 888'd0;
      reg_cnt    <= 32'd0;
      reg_inst   <= 1'b0;
      reg_reseed <= 1'b0;
      reg_ent    <= 768'd0;
      reg_t1     <= 512'd0;
      reg_h      <= 512'd0;
      reg_pool   <= 768'd0;
      reg_go     <= 1'b0;
    end
    else if (i_zero) begin
      // uninstantiate: the working state and the pool are cleared (end of the health test)
      reg_v      <= 888'd0;
      reg_c      <= 888'd0;
      reg_cnt    <= 32'd0;
      reg_inst   <= 1'b0;
      reg_pool   <= 768'd0;
      reg_go     <= 1'b0;
    end
    else begin
      // one go pulse of the hash feeder when a hash step begins
      reg_go <= 1'b0;
      if (i_clr)
        reg_pool <= 768'd0;
      case (reg_fsm_drbg_current_state)
        ENUM_ST_IDLE: begin
          if (i_seed) begin
            reg_ent    <= i_ent;
            reg_reseed <= reg_inst;
            reg_go     <= 1'b1;
          end else if (i_gen) begin
            reg_go     <= 1'b1;
          end
        end
        ENUM_ST_DF1: begin
          if (w_hf_done) begin
            reg_t1 <= w_dig;
            reg_go <= 1'b1;
          end
        end
        ENUM_ST_DF2: begin
          if (w_hf_done) begin
            reg_v  <= w_df_int;
            reg_go <= 1'b1;
          end
        end
        ENUM_ST_DC1: begin
          if (w_hf_done) begin
            reg_t1 <= w_dig;
            reg_go <= 1'b1;
          end
        end
        ENUM_ST_DC2: begin
          if (w_hf_done) begin
            reg_c    <= w_df_int;
            reg_inst <= 1'b1;
            reg_ent  <= 768'd0;
          end
        end
        ENUM_ST_G1: begin
          if (w_hf_done) begin
            reg_pool[511:0] <= w_dig;
            reg_go          <= 1'b1;
          end
        end
        ENUM_ST_G2: begin
          if (w_hf_done) begin
            reg_pool[767:512] <= w_dig[255:0];
            reg_go            <= 1'b1;
          end
        end
        ENUM_ST_G3: begin
          if (w_hf_done)
            reg_h <= w_h_int;
        end
        ENUM_ST_ADDC: begin
          reg_v <= reg_v + reg_c;
        end
        ENUM_ST_ADDH: begin
          reg_v   <= reg_v + {376'd0, reg_h} + {856'd0, reg_cnt};
          reg_cnt <= reg_cnt + 32'd1;
          reg_h   <= 512'd0;
        end
        default: begin
          reg_go <= 1'b0;
        end
      endcase
    end
  end

endmodule
