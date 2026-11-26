/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Private-key intake and clearing of the digital signature IP (FEAT-015,
 *                REQ-SEC-001, REQ-SEC-005). At the start pulse of the control block
 *                (ENUM_ST_KEY) it fills the key store of 17 words (544 bits, key byte i in bits
 *                [8 i +: 8]) with the words that the algorithm needs: from the key input port
 *                (one request per word, o_key_req with the word index, answered by one
 *                i_key_valid pulse) or from the write-only key registers of the CSR. A word that
 *                does not arrive within i_tmo_key units of 1024 clocks gives a one-cycle o_tmo
 *                pulse and clears the store. o_done is a one-cycle pulse when all words are in.
 *                The clear input empties the store; o_cleared is high while the store is zero.
 *                Source (PARA_KEY_SRC): 0 port, 1 registers, 2 registers when any register word
 *                is not zero and the port otherwise. A source that is not built (PARA_EN_KEYIF,
 *                PARA_EN_KEYREG) is never selected. Words needed: Ed25519 family 8, Ed448 family
 *                15, P-256 8, P-384 12, P-521 17, secp256k1 8, ML-DSA 8 (the seed); other
 *                algorithms need no key. Assumption ASM-017: key generation takes the private
 *                key or seed from the same sources as signing and derives the public key; the
 *                generation of the secret itself is the task of the key store. Requirements:
 *                REQ-SEC-001, REQ-SEC-005, REQ-SEC-007.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_key #(
  // Parameter Description: the key input port is built.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_KEYIF = 1,
  // Parameter Description: the write-only key registers of the CSR are used.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_KEYREG = 1,
  // Parameter Description: source of the key when both are built.
  // Parameter values: 0 port, 1 registers, 2 registers if loaded else the port; default is 2.
  // Parameter unit: code
  parameter logic [31:0] PARA_KEY_SRC = 2,
  localparam logic [31:0] LPARA_ALG_ED448 = 3,
  localparam logic [31:0] LPARA_ALG_ED448PH = 4,
  localparam logic [31:0] LPARA_ALG_P384 = 6,
  localparam logic [31:0] LPARA_ALG_P521 = 7
) (
  // Clock, reset and clearing
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,
  input  wire          i_clr,

  // Handshake with the control block
  input  wire          i_start,
  input  wire  [3:0]   i_run_alg,
  input  wire  [15:0]  i_tmo_key,
  output logic         o_done,
  output logic         o_tmo,

  // Key input port
  output logic         o_key_req,
  output logic [4:0]   o_key_idx,
  input  wire          i_key_valid,
  input  wire  [31:0]  i_key_data,

  // Write-only key registers of the CSR
  input  wire  [543:0] i_key_reg,

  // Key store for the engines
  output logic [543:0] o_key,
  output logic         o_cleared
);

  // States
  typedef enum logic [2:0] {
    ENUM_ST_IDLE = 3'd0,
    ENUM_ST_REG  = 3'd1,
    ENUM_ST_REQ  = 3'd2,
    ENUM_ST_DONE = 3'd3,
    ENUM_ST_TMO  = 3'd4
  } key_state_type_def;

  // Internal signal declarations
  key_state_type_def reg_fsm_key_current_state;
  key_state_type_def w_fsm_key_nxt_state;
  logic [543:0]  reg_key;
  logic [4:0]    reg_cnt;
  logic [4:0]    reg_nw;
  logic [25:0]   reg_tmo_cnt;
  logic [4:0]    w_nw;
  logic          w_use_reg;
  logic          w_use_port;
  logic [25:0]   w_tmo_lim;
  logic          w_tmo_hit;
  logic [543:0]  w_mask;

  // Words needed by the algorithm of the operation.
  always_comb begin : p_com_nw
    w_nw = 5'd8;
    case ({28'd0, i_run_alg})
      LPARA_ALG_ED448,
      LPARA_ALG_ED448PH: w_nw = 5'd15;
      LPARA_ALG_P384:    w_nw = 5'd12;
      LPARA_ALG_P521:    w_nw = 5'd17;
      default:           w_nw = 5'd8;
    endcase
  end

  // Source of the key: a source that is not built is never chosen.
  always_comb begin : p_com_src
    w_use_reg  = 1'b0;
    w_use_port = 1'b0;
    if ((PARA_EN_KEYIF == 32'd0) & (PARA_EN_KEYREG != 32'd0)) begin
      w_use_reg = 1'b1;
    end else if ((PARA_EN_KEYREG == 32'd0) & (PARA_EN_KEYIF != 32'd0)) begin
      w_use_port = 1'b1;
    end else begin
      case (PARA_KEY_SRC)
        32'd0:   w_use_reg  = 1'b1;
        32'd1:   w_use_reg  = 1'b1;
        default: begin
          w_use_reg  = (|i_key_reg);
          w_use_port = ~(|i_key_reg);
        end
      endcase
    end
  end

  // Mask of the words that the algorithm needs (words above are cleared when loading registers).
  always_comb begin : p_com_mask
    w_mask = '0;
    for (int w = 0; w < 17; w++) begin
      if (w < {27'd0, w_nw})
        w_mask[32 * w +: 32] = 32'hFFFF_FFFF;
    end
  end

  // Timeout limit in clocks: tmo units of 1024 clocks, a value of 0 counts as 1.
  assign w_tmo_lim = {((i_tmo_key == 16'd0) ? 16'd1 : i_tmo_key), 10'd0};
  assign w_tmo_hit = (reg_tmo_cnt >= w_tmo_lim);

  assign o_key_req = (reg_fsm_key_current_state == ENUM_ST_REQ);
  assign o_key_idx = reg_cnt;
  assign o_done    = (reg_fsm_key_current_state == ENUM_ST_DONE);
  assign o_tmo     = (reg_fsm_key_current_state == ENUM_ST_TMO);
  assign o_key     = reg_key;
  assign o_cleared = ~(|reg_key);

  // Part 1 of the FSM: state register.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_key
    if (!i_rst_n_core)
      reg_fsm_key_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_key_current_state <= w_fsm_key_nxt_state;
  end

  // Part 2 of the FSM: next state.
  always_comb begin : p_com_fsm_nxt
    w_fsm_key_nxt_state = reg_fsm_key_current_state;
    case (reg_fsm_key_current_state)
      ENUM_ST_IDLE: begin
        if (i_start) begin
          if (w_use_reg)
            w_fsm_key_nxt_state = ENUM_ST_REG;
          else if (w_use_port)
            w_fsm_key_nxt_state = ENUM_ST_REQ;
        end
      end
      ENUM_ST_REG: w_fsm_key_nxt_state = ENUM_ST_DONE;
      ENUM_ST_REQ: begin
        if (w_tmo_hit)
          w_fsm_key_nxt_state = ENUM_ST_TMO;
        else if (i_key_valid & (reg_cnt + 5'd1 == reg_nw))
          w_fsm_key_nxt_state = ENUM_ST_DONE;
      end
      ENUM_ST_DONE: w_fsm_key_nxt_state = ENUM_ST_IDLE;
      ENUM_ST_TMO:  w_fsm_key_nxt_state = ENUM_ST_IDLE;
      default:      w_fsm_key_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_key_nxt_state = ENUM_ST_IDLE;
  end

  // Data registers: key store, word counter and timeout counter.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
    if (!i_rst_n_core) begin
      reg_key     <= 544'd0;
      reg_cnt     <= 5'd0;
      reg_nw      <= 5'd0;
      reg_tmo_cnt <= 26'd0;
    end
    else if (i_clr) begin
      reg_key     <= 544'd0;
      reg_cnt     <= 5'd0;
      reg_tmo_cnt <= 26'd0;
    end
    else begin
      case (reg_fsm_key_current_state)
        ENUM_ST_IDLE: begin
          reg_cnt     <= 5'd0;
          reg_tmo_cnt <= 26'd0;
          reg_nw      <= w_nw;
          if (i_start)
            reg_key <= 544'd0;
        end
        ENUM_ST_REG: begin
          reg_key <= i_key_reg & w_mask;
        end
        ENUM_ST_REQ: begin
          if (i_key_valid) begin
            reg_key[32 * reg_cnt +: 32] <= i_key_data;
            reg_cnt     <= reg_cnt + 5'd1;
            reg_tmo_cnt <= 26'd0;
          end else begin
            reg_tmo_cnt <= reg_tmo_cnt + 26'd1;
          end
        end
        ENUM_ST_TMO: begin
          reg_key <= 544'd0;
        end
        default: begin
          reg_cnt <= 5'd0;
        end
      endcase
    end
  end

endmodule
