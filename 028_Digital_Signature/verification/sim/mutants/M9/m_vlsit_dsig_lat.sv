/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-25
 * Description  : Lattice engine of the digital signature IP: ML-DSA-44, ML-DSA-65 and ML-DSA-87
 *                key generation, signing and verification (FIPS 204, pure form) and
 *                verify-after-sign. The engine is a small 32-bit processor, the lattice
 *                processor: 32 registers, 8 flags, a word RAM for the polynomials (the secrets
 *                of an operation live there), modular add, subtract and multiply modulo q =
 *                8380417, a divider, the zeta table of the NTT, a table of the set parameters,
 *                byte access to the buffer, the key seed and the random pool, and a byte-stream
 *                interface to the hash arbiter (SHAKE128 and SHAKE256). The algorithms are
 *                programs of the generated ROM m_vlsit_dsig_lat_rom
 *                (verification/models/lat/ltp_isa.py describes the instruction word and gives
 *                the bit-exact model that the programs were tested with against OpenSSL). The
 *                clear input zeroizes the word RAM one word per cycle and the control block
 *                holds it until o_cleared; this takes 2^PARA_WA_W cycles and so does not meet
 *                the 100-cycle target of OP-006 (recorded as a deviation in section 14.2.1 of
 *                the specification). Requirements: OP-002 to OP-004, ALG-006, section 14.2.
 *                Deviation from MOD-02 (SHOULD, one function per module size): the engine is one
 *                processor.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_lat #(
  // Parameter Description: width of the word address of the buffer port.
  // Parameter values: 4 to 16; default is 7.
  // Parameter unit: bit
  parameter logic [31:0] PARA_WA = 7,
  // Parameter Description: size of the word RAM of the processor; 32768 words hold every set.
  // Parameter values: 32768; default is 32768.
  // Parameter unit: word
  parameter logic [31:0] PARA_WORDS = 32768,
  // Parameter Description: masking of the linear secret products of ML-DSA signing (DEC-049).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_DPA = 0,
  localparam logic [31:0] LPARA_WW = $clog2(PARA_WORDS),
  localparam logic [31:0] LPARA_OP_LDI = 6'd1,
  localparam logic [31:0] LPARA_OP_MOV = 6'd2,
  localparam logic [31:0] LPARA_OP_ADD = 6'd3,
  localparam logic [31:0] LPARA_OP_SUB = 6'd4,
  localparam logic [31:0] LPARA_OP_AND = 6'd5,
  localparam logic [31:0] LPARA_OP_OR = 6'd6,
  localparam logic [31:0] LPARA_OP_XOR = 6'd7,
  localparam logic [31:0] LPARA_OP_ADDI = 6'd8,
  localparam logic [31:0] LPARA_OP_SUBI = 6'd9,
  localparam logic [31:0] LPARA_OP_ANDI = 6'd10,
  localparam logic [31:0] LPARA_OP_SHLI = 6'd11,
  localparam logic [31:0] LPARA_OP_SHRI = 6'd12,
  localparam logic [31:0] LPARA_OP_SARI = 6'd13,
  localparam logic [31:0] LPARA_OP_SHL = 6'd14,
  localparam logic [31:0] LPARA_OP_SHR = 6'd15,
  localparam logic [31:0] LPARA_OP_SAR = 6'd16,
  localparam logic [31:0] LPARA_OP_MULL = 6'd17,
  localparam logic [31:0] LPARA_OP_MULQ = 6'd18,
  localparam logic [31:0] LPARA_OP_ADDQ = 6'd19,
  localparam logic [31:0] LPARA_OP_SUBQ = 6'd20,
  localparam logic [31:0] LPARA_OP_DIVU = 6'd21,
  localparam logic [31:0] LPARA_OP_MODU = 6'd22,
  localparam logic [31:0] LPARA_OP_LDZ = 6'd23,
  localparam logic [31:0] LPARA_OP_LDP = 6'd24,
  localparam logic [31:0] LPARA_OP_LDS = 6'd25,
  localparam logic [31:0] LPARA_OP_EQ = 6'd26,
  localparam logic [31:0] LPARA_OP_LTU = 6'd27,
  localparam logic [31:0] LPARA_OP_LTS = 6'd28,
  localparam logic [31:0] LPARA_OP_EQI = 6'd29,
  localparam logic [31:0] LPARA_OP_ISZ = 6'd30,
  localparam logic [31:0] LPARA_OP_FNOT = 6'd31,
  localparam logic [31:0] LPARA_OP_FAND = 6'd32,
  localparam logic [31:0] LPARA_OP_FOR = 6'd33,
  localparam logic [31:0] LPARA_OP_FSET = 6'd34,
  localparam logic [31:0] LPARA_OP_BRF = 6'd35,
  localparam logic [31:0] LPARA_OP_BRN = 6'd36,
  localparam logic [31:0] LPARA_OP_JMP = 6'd37,
  localparam logic [31:0] LPARA_OP_CALL = 6'd38,
  localparam logic [31:0] LPARA_OP_RET = 6'd39,
  localparam logic [31:0] LPARA_OP_END = 6'd40,
  localparam logic [31:0] LPARA_OP_ERR = 6'd41,
  localparam logic [31:0] LPARA_OP_LW = 6'd42,
  localparam logic [31:0] LPARA_OP_SW = 6'd43,
  localparam logic [31:0] LPARA_OP_BLB = 6'd44,
  localparam logic [31:0] LPARA_OP_BSB = 6'd45,
  localparam logic [31:0] LPARA_OP_LDK = 6'd46,
  localparam logic [31:0] LPARA_OP_LDR = 6'd47,
  localparam logic [31:0] LPARA_OP_XSTART = 6'd48,
  localparam logic [31:0] LPARA_OP_XPUT = 6'd49,
  localparam logic [31:0] LPARA_OP_XFIN = 6'd50,
  localparam logic [31:0] LPARA_OP_XGET = 6'd51,
  localparam logic [31:0] LPARA_OP_XDRAIN = 6'd52,
  localparam logic [31:0] LPARA_Q = 32'd8380417,
  localparam logic [31:0] LPARA_ERRF_OPUNS = 12'd2
) (
  // Clock, reset and clearing
  input  wire                i_clk_core,
  input  wire                i_rst_n_core,
  input  wire                i_clr,

  // Start pulses and the snapshot of the operation
  input  wire                i_start,
  input  wire                i_vas_start,
  input  wire  [3:0]         i_run_alg,
  input  wire  [1:0]         i_run_op,
  input  wire  [1:0]         i_run_form,
  input  wire                i_run_hedged,
  input  wire  [2:0]         i_run_hash,
  input  wire  [31:0]        i_run_len_msg,
  input  wire  [7:0]         i_run_len_ctx,
  input  wire  [16:0]        i_run_off_msg,
  input  wire  [16:0]        i_run_off_sig,
  input  wire  [16:0]        i_run_off_pk,
  input  wire  [16:0]        i_run_off_res,

  // Result
  output logic               o_busy,
  output logic               o_done,
  output logic               o_err,
  output logic [11:0]        o_err_flags,
  output logic               o_sigok,
  output logic               o_vas_done,
  output logic               o_vas_ok,
  output logic               o_cleared,

  // Private key (seed) and random pool
  input  wire  [543:0]       i_key,
  input  wire  [767:0]       i_pool,

  // Buffer ports (64-bit words)
  output logic               o_rd_en,
  output logic [PARA_WA-1:0] o_rd_addr,
  input  wire  [63:0]        i_rd_data,
  input  wire                i_rd_valid,
  output logic               o_wr_en,
  output logic [PARA_WA-1:0] o_wr_addr,
  output logic [63:0]        o_wr_data,
  output logic [7:0]         o_wr_strb,

  // Hash arbiter side
  output logic               o_hs_req,
  input  wire                i_hs_grant,
  output logic               o_hs_start,
  output logic [3:0]         o_hs_mode,
  output logic [15:0]        o_hs_outlen,
  output logic               o_hs_in_valid,
  output logic [63:0]        o_hs_in_data,
  output logic [3:0]         o_hs_in_nb,
  output logic               o_hs_in_last,
  input  wire                i_hs_in_ready,
  input  wire                i_hs_out_valid,
  input  wire  [63:0]        i_hs_out_data,
  input  wire  [3:0]         i_hs_out_nb,
  input  wire                i_hs_out_last,
  output logic               o_hs_out_ready
);

  // Instruction codes (the order of OPS in ltp_isa.py)

  // q = 8380417 = 2^23 - 2^13 + 1

  // Unsupported operation flag (bit number of dsig_err)

  // States
  typedef enum logic [3:0] {
    ENUM_ST_IDLE  = 4'd0,
    ENUM_ST_ENTRY = 4'd1,
    ENUM_ST_EXEC  = 4'd2,
    ENUM_ST_LWW   = 4'd3,
    ENUM_ST_BWW   = 4'd4,
    ENUM_ST_DIVW  = 4'd5,
    ENUM_ST_XSG   = 4'd6,
    ENUM_ST_XSS   = 4'd7,
    ENUM_ST_XPW   = 4'd8,
    ENUM_ST_XFW   = 4'd9,
    ENUM_ST_XGW   = 4'd10,
    ENUM_ST_XDW   = 4'd11,
    ENUM_ST_FIN   = 4'd12,
    ENUM_ST_CLR   = 4'd13
  } lat_state_type_def;

  // Internal signal declarations
  lat_state_type_def reg_fsm_lat_current_state;
  lat_state_type_def w_fsm_lat_nxt_state;

  logic [31:0]   reg_rf [32];
  logic [7:0]    reg_f;
  logic [11:0]   reg_pc;
  logic [11:0]   reg_stack [8];
  logic [3:0]    reg_sp;
  logic [63:0]   reg_ins;

  // Snapshot
  logic [3:0]    reg_alg;
  logic [1:0]    reg_op;
  logic [1:0]    reg_form;
  logic          reg_hedged;
  logic [2:0]    reg_hash;
  logic [31:0]   reg_len_msg;
  logic [7:0]    reg_len_ctx;
  logic [16:0]   reg_off_msg;
  logic [16:0]   reg_off_sig;
  logic [16:0]   reg_off_pk;
  logic [16:0]   reg_off_res;

  // Result
  logic          reg_vas;
  logic          reg_err;
  logic [11:0]   reg_err_flags;
  logic          reg_sigok;
  logic          reg_cleared;

  // Word RAM and its clearing
  logic [31:0]   reg_wram [2**LPARA_WW-1:0];
  logic [31:0]   reg_wq;
  logic [LPARA_WW-1:0] reg_clr_cnt;

  // Divider
  logic [31:0]   reg_dv_n;
  logic [31:0]   reg_dv_d;
  logic [31:0]   reg_dv_q;
  logic [31:0]   reg_dv_r;
  logic [5:0]    reg_dv_cnt;
  logic          reg_dv_mod;

  // Buffer byte read
  logic [2:0]    reg_bq_lane;

  // Hash stream
  logic          reg_req;
  logic          reg_open;
  logic [3:0]    reg_xmode;
  logic [15:0]   reg_xout;
  logic [7:0]    reg_xbyte;
  logic [63:0]   reg_xw;
  logic [3:0]    reg_xcnt;
  logic          reg_xlast;

  // Instruction decode
  logic [63:0]   w_ins;
  logic [5:0]    w_op;
  logic [4:0]    w_rd;
  logic [4:0]    w_ra;
  logic [4:0]    w_rb;
  logic [42:0]   w_imm;
  logic [31:0]   w_ra_v;
  logic [31:0]   w_rb_v;
  logic [31:0]   w_imm32;
  logic [5:0]    w_ri_op;
  logic [4:0]    w_ri_rd;
  logic [4:0]    w_ri_ra;
  logic [4:0]    w_ri_rb;
  logic [42:0]   w_ri_imm;

  // ROM
  logic [22:0]   w_zeta;
  logic [31:0]   w_pval;
  logic [11:0]   w_entry;

  // Arithmetic
  logic [31:0]   w_addq;
  logic [31:0]   w_subq;
  logic [63:0]   w_mulq_p;
  logic [31:0]   w_mulq;
  logic [31:0]   w_ea;
  logic [31:0]   w_ea_ram;
  logic [23:0]   w_buf_base;
  logic [23:0]   w_buf_abs_r;
  logic [23:0]   w_buf_abs_w;
  logic [31:0]   w_key_byte;
  logic [31:0]   w_pool_byte;
  logic [31:0]   w_dv_next_r;
  logic          w_start_any;
  logic          w_unsup;

  // Function: arithmetic right shift of a 32-bit value
  function automatic logic [31:0] f_sar(input logic [31:0] x, input logic [4:0] n);
    logic [31:0] w_fill;
    begin
      w_fill = x[31] ? ~(32'hFFFF_FFFF >> n) : 32'd0;
      f_sar  = (x >> n) | w_fill;
    end
  endfunction

  // Function: signed less-than of two 32-bit values
  function automatic logic f_lts(input logic [31:0] a, input logic [31:0] b);
    begin
      f_lts = (a[31] != b[31]) ? a[31] : (a < b);
    end
  endfunction

  // Function: x modulo q for x < 2^46, with the identity 2^23 = 2^13 - 1 (mod q)
  function automatic logic [31:0] f_modq(input logic [63:0] x);
    logic [63:0] a1;
    logic [63:0] a2;
    logic [63:0] a3;
    logic [31:0] r;
    begin
      a1 = {41'd0, x[22:0]} + ((x >> 23) << 13) - (x >> 23);
      a2 = {41'd0, a1[22:0]} + ((a1 >> 23) << 13) - (a1 >> 23);
      a3 = {41'd0, a2[22:0]} + ((a2 >> 23) << 13) - (a2 >> 23);
      r = a3[31:0];
      if (r >= LPARA_Q)
        r = r - LPARA_Q;
      if (r >= LPARA_Q)
        r = r - LPARA_Q;
      f_modq = r;
    end
  endfunction

  m_vlsit_dsig_lat_rom u_rom (
    .i_pc     (reg_pc),
    .o_ins    (w_ins),
    .i_z      (w_ra_v[7:0]),
    .o_zeta   (w_zeta),
    .i_alg    (reg_alg),
    .i_field  (w_imm[3:0]),
    .o_val    (w_pval),
    .i_which  (reg_vas),
    .o_entry  (w_entry)
  );

  assign w_op    = w_ins[63:58];
  assign w_rd    = w_ins[57:53];
  assign w_ra    = w_ins[52:48];
  assign w_rb    = w_ins[47:43];
  assign w_imm   = w_ins[42:0];
  assign w_imm32 = w_ins[31:0];
  assign w_ri_op    = reg_ins[63:58];
  assign w_ri_rd    = reg_ins[57:53];
  assign w_ri_ra    = reg_ins[52:48];
  assign w_ri_rb    = reg_ins[47:43];
  assign w_ri_imm   = reg_ins[42:0];
  assign w_ra_v  = reg_rf[w_ra];
  assign w_rb_v  = reg_rf[w_rb];

  assign w_start_any = i_start | i_vas_start;
  assign w_unsup     = (i_run_alg < 4'd9) | (i_run_alg > 4'd11);

  // Modular arithmetic on operands smaller than q
  assign w_addq   = (w_ra_v + w_rb_v >= LPARA_Q) ? (w_ra_v + w_rb_v - LPARA_Q) : (w_ra_v + w_rb_v);
  assign w_subq   = (w_ra_v >= w_rb_v) ? (w_ra_v - w_rb_v) : (w_ra_v + LPARA_Q - w_rb_v);
  assign w_mulq_p = {32'd0, w_ra_v} * {32'd0, w_rb_v};
  assign w_mulq   = f_modq(w_mulq_p);

  // Effective addresses
  assign w_ea     = w_ra_v + w_imm32;
  assign w_ea_ram = w_ea;
  assign w_buf_base  = {7'd0, (w_rb_v[1:0] == 2'd0) ? reg_off_msg : ((w_rb_v[1:0] == 2'd1) ? reg_off_sig :
                       ((w_rb_v[1:0] == 2'd2) ? reg_off_pk : reg_off_res))};
  assign w_buf_abs_r = w_buf_base + w_ea[23:0];
  assign w_buf_abs_w = {7'd0, (w_imm[1:0] == 2'd0) ? reg_off_msg : ((w_imm[1:0] == 2'd1) ? reg_off_sig :
                       ((w_imm[1:0] == 2'd2) ? reg_off_pk : reg_off_res))} + w_ra_v[23:0] + w_imm[25:2];

  // Key and pool bytes (zero beyond their length)
  assign w_key_byte  = (w_ea < 32'd68) ? {24'd0, i_key[8 * w_ea[6:0] +: 8]} : 32'd0;
  assign w_pool_byte = (w_ea < 32'd96) ? {24'd0, i_pool[8 * w_ea[6:0] +: 8]} : 32'd0;

  // Divider step: shift the next bit of the dividend into the remainder
  assign w_dv_next_r = {reg_dv_r[30:0], reg_dv_n[31]};

  // ---------------------------------------------------------------------------------------------
  // Word RAM: one write port, one synchronous read port; the clear writes zero at the counter
  // ---------------------------------------------------------------------------------------------
  logic                w_ram_we;
  logic [LPARA_WW-1:0] w_ram_waddr;
  logic [31:0]         w_ram_wdata;
  logic [LPARA_WW-1:0] w_ram_raddr;

  always_comb begin : p_com_ram
    w_ram_we    = 1'b0;
    w_ram_waddr = w_ea[LPARA_WW-1:0];
    w_ram_wdata = w_rb_v;
    w_ram_raddr = w_ea[LPARA_WW-1:0];
    if (reg_fsm_lat_current_state == ENUM_ST_CLR) begin
      w_ram_we    = 1'b1;
      w_ram_waddr = reg_clr_cnt;
      w_ram_wdata = 32'd0;
    end else if ((reg_fsm_lat_current_state == ENUM_ST_EXEC) & (w_op == LPARA_OP_SW)) begin
      w_ram_we = 1'b1;
    end
  end

  always_ff @(posedge i_clk_core) begin : p_ff_ram
    reg_wq <= reg_wram[w_ram_raddr];
    if (w_ram_we)
      reg_wram[w_ram_waddr] <= w_ram_wdata;
  end

  // ---------------------------------------------------------------------------------------------
  // Buffer ports
  // ---------------------------------------------------------------------------------------------
  always_comb begin : p_com_buf
    o_rd_en   = 1'b0;
    o_rd_addr = w_buf_abs_r[PARA_WA+2:3];
    o_wr_en   = 1'b0;
    o_wr_addr = w_buf_abs_w[PARA_WA+2:3];
    o_wr_data = {8{w_rb_v[7:0]}};
    o_wr_strb = 8'd1 << w_buf_abs_w[2:0];
    if (reg_fsm_lat_current_state == ENUM_ST_EXEC) begin
      if (w_op == LPARA_OP_BLB)
        o_rd_en = 1'b1;
      if (w_op == LPARA_OP_BSB)
        o_wr_en = 1'b1;
    end
  end

  // ---------------------------------------------------------------------------------------------
  // Hash stream
  // ---------------------------------------------------------------------------------------------
  assign o_hs_req    = reg_req;
  assign o_hs_start  = (reg_fsm_lat_current_state == ENUM_ST_XSS);
  assign o_hs_mode   = reg_xmode;
  assign o_hs_outlen = reg_xout;

  always_comb begin : p_com_hin
    o_hs_in_valid = 1'b0;
    o_hs_in_data  = {56'd0, reg_xbyte};
    o_hs_in_nb    = 4'd1;
    o_hs_in_last  = 1'b0;
    if (reg_fsm_lat_current_state == ENUM_ST_XPW) begin
      o_hs_in_valid = 1'b1;
    end else if (reg_fsm_lat_current_state == ENUM_ST_XFW) begin
      o_hs_in_valid = 1'b1;
      o_hs_in_nb    = 4'd0;
      o_hs_in_last  = 1'b1;
    end
  end

  assign o_hs_out_ready = ((reg_fsm_lat_current_state == ENUM_ST_XGW) & (reg_xcnt == 4'd0)) |
                          ((reg_fsm_lat_current_state == ENUM_ST_XDW) & ~reg_xlast);

  // ---------------------------------------------------------------------------------------------
  // FSM
  // ---------------------------------------------------------------------------------------------
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_lat
    if (!i_rst_n_core)
      reg_fsm_lat_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_lat_current_state <= w_fsm_lat_nxt_state;
  end

  always_comb begin : p_com_fsm_nxt
    w_fsm_lat_nxt_state = reg_fsm_lat_current_state;
    case (reg_fsm_lat_current_state)
      ENUM_ST_IDLE: begin
        if (w_start_any)
          w_fsm_lat_nxt_state = ENUM_ST_ENTRY;
      end
      ENUM_ST_ENTRY: begin
        if (reg_err)
          w_fsm_lat_nxt_state = ENUM_ST_FIN;
        else
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_EXEC: begin
        case (w_op)
          LPARA_OP_DIVU,
          LPARA_OP_MODU:   w_fsm_lat_nxt_state = ENUM_ST_DIVW;
          LPARA_OP_LW:     w_fsm_lat_nxt_state = ENUM_ST_LWW;
          LPARA_OP_BLB:    w_fsm_lat_nxt_state = ENUM_ST_BWW;
          LPARA_OP_END,
          LPARA_OP_ERR:    w_fsm_lat_nxt_state = ENUM_ST_FIN;
          LPARA_OP_XSTART: w_fsm_lat_nxt_state = ENUM_ST_XSG;
          LPARA_OP_XPUT:   w_fsm_lat_nxt_state = ENUM_ST_XPW;
          LPARA_OP_XFIN:   w_fsm_lat_nxt_state = ENUM_ST_XFW;
          LPARA_OP_XGET:   w_fsm_lat_nxt_state = ENUM_ST_XGW;
          LPARA_OP_XDRAIN: begin
            if (reg_open)
              w_fsm_lat_nxt_state = ENUM_ST_XDW;
          end
          default:         w_fsm_lat_nxt_state = ENUM_ST_EXEC;
        endcase
      end
      ENUM_ST_LWW: w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      ENUM_ST_BWW: begin
        if (i_rd_valid)
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_DIVW: begin
        if (reg_dv_cnt == 6'd1)
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_XSG: begin
        if (i_hs_grant)
          w_fsm_lat_nxt_state = ENUM_ST_XSS;
      end
      ENUM_ST_XSS: w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      ENUM_ST_XPW: begin
        if (i_hs_in_ready)
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_XFW: begin
        if (i_hs_in_ready)
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_XGW: begin
        if (reg_xcnt != 4'd0)
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_XDW: begin
        if (reg_xlast | (i_hs_out_valid & i_hs_out_last))
          w_fsm_lat_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_FIN: begin
        // The verify-after-sign start of the control block arrives in the cycle of the end pulse.
        if (w_start_any)
          w_fsm_lat_nxt_state = ENUM_ST_ENTRY;
        else
          w_fsm_lat_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_CLR: begin
        if (!i_clr)
          w_fsm_lat_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_lat_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_lat_nxt_state = ENUM_ST_CLR;
  end

  assign o_busy      = (reg_fsm_lat_current_state != ENUM_ST_IDLE) & (reg_fsm_lat_current_state != ENUM_ST_CLR);
  assign o_done      = (reg_fsm_lat_current_state == ENUM_ST_FIN) & ~reg_vas & ~reg_err;
  assign o_err       = (reg_fsm_lat_current_state == ENUM_ST_FIN) & ~reg_vas & reg_err;
  assign o_err_flags = reg_err_flags;
  assign o_sigok     = reg_sigok;
  assign o_vas_done  = (reg_fsm_lat_current_state == ENUM_ST_FIN) & reg_vas;
  assign o_vas_ok    = reg_sigok & ~reg_err;
  assign o_cleared   = reg_cleared;

  // ---------------------------------------------------------------------------------------------
  // Data registers
  // ---------------------------------------------------------------------------------------------
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
    if (!i_rst_n_core) begin
      for (int i = 0; i < 32; i++)
        reg_rf[i] <= 32'd0;
      for (int i = 0; i < 8; i++)
        reg_stack[i] <= 12'd0;
      reg_f         <= 8'd0;
      reg_pc        <= 12'd0;
      reg_sp        <= 4'd0;
      reg_ins       <= 64'd0;
      reg_alg       <= 4'd0;
      reg_op        <= 2'd0;
      reg_form      <= 2'd0;
      reg_hedged    <= 1'b0;
      reg_hash      <= 3'd0;
      reg_len_msg   <= 32'd0;
      reg_len_ctx   <= 8'd0;
      reg_off_msg   <= 17'd0;
      reg_off_sig   <= 17'd0;
      reg_off_pk    <= 17'd0;
      reg_off_res   <= 17'd0;
      reg_vas       <= 1'b0;
      reg_err       <= 1'b0;
      reg_err_flags <= 12'd0;
      reg_sigok     <= 1'b0;
      reg_cleared   <= 1'b0;
      reg_clr_cnt   <= '0;
      reg_dv_n      <= 32'd0;
      reg_dv_d      <= 32'd0;
      reg_dv_q      <= 32'd0;
      reg_dv_r      <= 32'd0;
      reg_dv_cnt    <= 6'd0;
      reg_dv_mod    <= 1'b0;
      reg_bq_lane   <= 3'd0;
      reg_req       <= 1'b0;
      reg_open      <= 1'b0;
      reg_xmode     <= 4'd0;
      reg_xout      <= 16'd0;
      reg_xbyte     <= 8'd0;
      reg_xw        <= 64'd0;
      reg_xcnt      <= 4'd0;
      reg_xlast     <= 1'b0;
    end
    else if (i_clr) begin
      for (int i = 0; i < 32; i++)
        reg_rf[i] <= 32'd0;
      reg_f         <= 8'd0;
      reg_ins       <= 64'd0;
      reg_err       <= 1'b0;
      reg_err_flags <= 12'd0;
      reg_sigok     <= 1'b0;
      reg_req       <= 1'b0;
      reg_open      <= 1'b0;
      reg_xw        <= 64'd0;
      reg_xcnt      <= 4'd0;
      reg_xbyte     <= 8'd0;
      reg_dv_n      <= 32'd0;
      reg_dv_q      <= 32'd0;
      reg_dv_r      <= 32'd0;
      // The word RAM is cleared one word per cycle; the flag is set after the last word.
      if (reg_fsm_lat_current_state == ENUM_ST_CLR) begin
        reg_clr_cnt <= reg_clr_cnt + 1'b1;
        if (reg_clr_cnt == '1)
          reg_cleared <= 1'b1;
      end
    end
    else begin
      reg_clr_cnt <= '0;
      case (reg_fsm_lat_current_state)
        ENUM_ST_IDLE,
        ENUM_ST_FIN: begin
          if (w_start_any) begin
            reg_vas       <= i_vas_start;
            reg_alg       <= i_run_alg;
            reg_op        <= i_run_op;
            reg_form      <= i_run_form;
            reg_hedged    <= i_run_hedged;
            reg_hash      <= i_run_hash;
            reg_len_msg   <= i_run_len_msg;
            reg_len_ctx   <= i_run_len_ctx;
            reg_off_msg   <= i_run_off_msg;
            reg_off_sig   <= i_run_off_sig;
            reg_off_pk    <= i_run_off_pk;
            reg_off_res   <= i_run_off_res;
            reg_f         <= 8'd0;
            reg_sp        <= 4'd0;
            reg_sigok     <= 1'b0;
            reg_cleared   <= 1'b0;
            reg_err       <= w_unsup;
            reg_err_flags <= w_unsup ? LPARA_ERRF_OPUNS : 12'd0;
          end
        end
        ENUM_ST_ENTRY: begin
          reg_pc <= w_entry;
        end
        ENUM_ST_EXEC: begin
          reg_ins <= w_ins;
          reg_pc  <= reg_pc + 12'd1;
          case (w_op)
            LPARA_OP_LDI:  reg_rf[w_rd] <= w_imm32;
            LPARA_OP_MOV:  reg_rf[w_rd] <= w_ra_v;
            LPARA_OP_ADD:  reg_rf[w_rd] <= w_ra_v + w_rb_v;
            LPARA_OP_SUB:  reg_rf[w_rd] <= w_ra_v - w_rb_v;
            LPARA_OP_AND:  reg_rf[w_rd] <= w_ra_v & w_rb_v;
            LPARA_OP_OR:   reg_rf[w_rd] <= w_ra_v | w_rb_v;
            LPARA_OP_XOR:  reg_rf[w_rd] <= w_ra_v ^ w_rb_v;
            LPARA_OP_ADDI: reg_rf[w_rd] <= w_ra_v + w_imm32;
            LPARA_OP_SUBI: reg_rf[w_rd] <= w_ra_v - w_imm32;
            LPARA_OP_ANDI: reg_rf[w_rd] <= w_ra_v & w_imm32;
            LPARA_OP_SHLI: reg_rf[w_rd] <= w_ra_v << w_imm[4:0];
            LPARA_OP_SHRI: reg_rf[w_rd] <= w_ra_v >> w_imm[4:0];
            LPARA_OP_SARI: reg_rf[w_rd] <= f_sar(w_ra_v, w_imm[4:0]);
            LPARA_OP_SHL:  reg_rf[w_rd] <= w_ra_v << w_rb_v[4:0];
            LPARA_OP_SHR:  reg_rf[w_rd] <= w_ra_v >> w_rb_v[4:0];
            LPARA_OP_SAR:  reg_rf[w_rd] <= f_sar(w_ra_v, w_rb_v[4:0]);
            LPARA_OP_MULL: reg_rf[w_rd] <= w_mulq_p[31:0];
            LPARA_OP_MULQ: reg_rf[w_rd] <= w_mulq;
            LPARA_OP_ADDQ: reg_rf[w_rd] <= w_addq;
            LPARA_OP_SUBQ: reg_rf[w_rd] <= w_subq;
            LPARA_OP_DIVU,
            LPARA_OP_MODU: begin
              reg_dv_n   <= w_ra_v;
              reg_dv_d   <= w_rb_v;
              reg_dv_q   <= 32'd0;
              reg_dv_r   <= 32'd0;
              reg_dv_cnt <= 6'd32;
              reg_dv_mod <= (w_op == LPARA_OP_MODU);
            end
            LPARA_OP_LDZ:  reg_rf[w_rd] <= {9'd0, w_zeta};
            LPARA_OP_LDP:  reg_rf[w_rd] <= w_pval;
            LPARA_OP_LDS: begin
              case (w_imm[2:0])
                3'd0:    reg_rf[w_rd] <= reg_len_msg;
                3'd1:    reg_rf[w_rd] <= {24'd0, reg_len_ctx};
                3'd2:    reg_rf[w_rd] <= {30'd0, reg_form};
                3'd3:    reg_rf[w_rd] <= {30'd0, reg_op};
                3'd4:    reg_rf[w_rd] <= {28'd0, reg_alg};
                3'd5:    reg_rf[w_rd] <= {31'd0, reg_hedged};
                3'd6:    reg_rf[w_rd] <= {29'd0, reg_hash};
                default: reg_rf[w_rd] <= 32'd0;
              endcase
            end
            LPARA_OP_EQ:   reg_f[w_rd[2:0]] <= (w_ra_v == w_rb_v);
            LPARA_OP_LTU:  reg_f[w_rd[2:0]] <= (w_ra_v < w_rb_v);
            LPARA_OP_LTS:  reg_f[w_rd[2:0]] <= f_lts(w_ra_v, w_rb_v);
            LPARA_OP_EQI:  reg_f[w_rd[2:0]] <= (w_ra_v == w_imm32);
            LPARA_OP_ISZ:  reg_f[w_rd[2:0]] <= (w_ra_v == 32'd0);
            LPARA_OP_FNOT: reg_f[w_rd[2:0]] <= ~reg_f[w_ra[2:0]];
            LPARA_OP_FAND: reg_f[w_rd[2:0]] <= reg_f[w_ra[2:0]] & reg_f[w_rb[2:0]];
            LPARA_OP_FOR:  reg_f[w_rd[2:0]] <= reg_f[w_ra[2:0]] | reg_f[w_rb[2:0]];
            LPARA_OP_FSET: reg_f[w_rd[2:0]] <= w_imm[0];
            LPARA_OP_BRF: begin
              if (reg_f[w_ra[2:0]])
                reg_pc <= w_imm[11:0];
            end
            LPARA_OP_BRN: begin
              if (!reg_f[w_ra[2:0]])
                reg_pc <= w_imm[11:0];
            end
            LPARA_OP_JMP:  reg_pc <= w_imm[11:0];
            LPARA_OP_CALL: begin
              reg_stack[reg_sp[2:0]] <= reg_pc + 12'd1;
              reg_sp <= reg_sp + 4'd1;
              reg_pc <= w_imm[11:0];
            end
            LPARA_OP_RET: begin
              reg_sp <= reg_sp - 4'd1;
              reg_pc <= reg_stack[reg_sp[2:0] - 3'd1];
            end
            LPARA_OP_END:  reg_sigok <= reg_f[7];
            LPARA_OP_ERR: begin
              reg_err       <= 1'b1;
              reg_err_flags <= 12'd1 << w_imm[3:0];
              reg_sigok     <= 1'b0;
            end
            LPARA_OP_BLB:  reg_bq_lane <= w_buf_abs_r[2:0];
            LPARA_OP_LDK:  reg_rf[w_rd] <= w_key_byte;
            LPARA_OP_LDR:  reg_rf[w_rd] <= w_pool_byte;
            LPARA_OP_XSTART: begin
              reg_xmode <= w_imm[3:0];
              reg_xout  <= w_ra_v[15:0];
              reg_req   <= 1'b1;
              reg_xcnt  <= 4'd0;
              reg_xlast <= 1'b0;
            end
            LPARA_OP_XPUT: reg_xbyte <= w_ra_v[7:0];
            default: begin
              reg_pc <= reg_pc + 12'd1;
            end
          endcase
        end
        ENUM_ST_LWW: begin
          reg_rf[w_ri_rd] <= reg_wq;
        end
        ENUM_ST_BWW: begin
          if (i_rd_valid)
            reg_rf[w_ri_rd] <= {24'd0, i_rd_data[8 * reg_bq_lane +: 8]};
        end
        ENUM_ST_DIVW: begin
          reg_dv_cnt <= reg_dv_cnt - 6'd1;
          reg_dv_n   <= {reg_dv_n[30:0], 1'b0};
          if (w_dv_next_r >= reg_dv_d) begin
            reg_dv_r <= w_dv_next_r - reg_dv_d;
            reg_dv_q <= {reg_dv_q[30:0], 1'b1};
          end else begin
            reg_dv_r <= w_dv_next_r;
            reg_dv_q <= {reg_dv_q[30:0], 1'b0};
          end
          if (reg_dv_cnt == 6'd1)
            reg_rf[w_ri_rd] <= reg_dv_mod ? ((w_dv_next_r >= reg_dv_d) ? (w_dv_next_r - reg_dv_d) : w_dv_next_r) :
                            ((w_dv_next_r >= reg_dv_d) ? {reg_dv_q[30:0], 1'b1} : {reg_dv_q[30:0], 1'b0});
        end
        ENUM_ST_XSG: begin
          if (i_hs_grant)
            reg_open <= 1'b1;
        end
        ENUM_ST_XGW: begin
          if (reg_xcnt == 4'd0) begin
            if (i_hs_out_valid) begin
              reg_xw    <= i_hs_out_data;
              reg_xcnt  <= i_hs_out_nb;
              reg_xlast <= i_hs_out_last;
            end
          end else begin
            reg_rf[w_ri_rd] <= {24'd0, reg_xw[7:0]};
            reg_xw       <= reg_xw >> 8;
            reg_xcnt     <= reg_xcnt - 4'd1;
            if ((reg_xcnt == 4'd1) & reg_xlast) begin
              reg_open <= 1'b0;
              reg_req  <= 1'b0;
            end
          end
        end
        ENUM_ST_XDW: begin
          if (reg_xlast | (i_hs_out_valid & i_hs_out_last)) begin
            reg_open  <= 1'b0;
            reg_req   <= 1'b0;
            reg_xcnt  <= 4'd0;
            reg_xlast <= 1'b0;
          end
        end
        default: begin
          reg_clr_cnt <= '0;
        end
      endcase
    end
  end

endmodule
