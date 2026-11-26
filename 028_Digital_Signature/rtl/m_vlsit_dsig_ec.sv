/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-25
 * Description  : Elliptic-curve engine of the digital signature IP: Ed25519, Ed448, ECDSA P-256,
 *                P-384, P-521 and secp256k1; key generation, signing, verification and
 *                verify-after-sign. The engine is a small processor. It has 32 registers of 576
 *                bits, 8 flags, a modular unit (add, subtract, bit-serial multiply of mbits
 *                cycles, bit-serial reduce of 576 cycles, power through multiplies) with the
 *                selectable modulus p, n or n-1, a scalar-multiply loop that calls the point
 *                doubling and addition subroutines, and I/O operations to the buffer
 *                (m_vlsit_dsig_brd, m_vlsit_dsig_bwr), the key store, the random pool and the
 *                hash feeder (m_vlsit_dsig_hfeed). Every algorithm is a program of the
 *                instruction set in the generated ROM m_vlsit_dsig_ec_rom
 *                (verification/models/ec/ec_isa.py describes the instruction word and gives the
 *                bit-exact model that the programs were tested with). Ed25519ctx, Ed25519ph and
 *                Ed448ph are not implemented: the engine ends with the operation-unsupported
 *                flag for them. Requirements: OP-001 to OP-008, ALG-001 to ALG-006, section
 *                14.2. Deviation from MOD-02 (SHOULD, one function per module size): the engine
 *                is one processor; its datapath and its sequencer are not split because they
 *                share the registers.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_ec #(
  // Parameter Description: width of the word address of the buffer port.
  // Parameter values: 4 to 16; default is 7.
  // Parameter unit: bit
  parameter logic [31:0] PARA_WA = 7,
  // Parameter Description: scalar blinding of the secret scalar multiplications (PARA_EN_DPA_EC).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_DPA = 0,
  // Parameter Description: digit width of the Montgomery multiplier (odd moduli p and n).
  // Parameter values: 32, 64 or 128; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_MUL_W = 64,
  localparam logic [31:0] LPARA_MULW_CODE = (PARA_MUL_W == 32'd128) ? 32'd2 : ((PARA_MUL_W == 32'd32) ? 32'd0 : 32'd1),
  localparam logic [31:0] LPARA_OP_ADD = 6'd1,
  localparam logic [31:0] LPARA_OP_SUB = 6'd2,
  localparam logic [31:0] LPARA_OP_MUL = 6'd3,
  localparam logic [31:0] LPARA_OP_RED = 6'd4,
  localparam logic [31:0] LPARA_OP_MOV = 6'd5,
  localparam logic [31:0] LPARA_OP_LDI = 6'd6,
  localparam logic [31:0] LPARA_OP_LDC = 6'd7,
  localparam logic [31:0] LPARA_OP_SETM = 6'd8,
  localparam logic [31:0] LPARA_OP_POW = 6'd9,
  localparam logic [31:0] LPARA_OP_SMUL = 6'd10,
  localparam logic [31:0] LPARA_OP_EQ = 6'd11,
  localparam logic [31:0] LPARA_OP_LTU = 6'd12,
  localparam logic [31:0] LPARA_OP_BIT = 6'd13,
  localparam logic [31:0] LPARA_OP_ISZ = 6'd14,
  localparam logic [31:0] LPARA_OP_FNOT = 6'd15,
  localparam logic [31:0] LPARA_OP_FAND = 6'd16,
  localparam logic [31:0] LPARA_OP_FOR = 6'd17,
  localparam logic [31:0] LPARA_OP_FSET = 6'd18,
  localparam logic [31:0] LPARA_OP_CMOV = 6'd19,
  localparam logic [31:0] LPARA_OP_AND = 6'd20,
  localparam logic [31:0] LPARA_OP_OR = 6'd21,
  localparam logic [31:0] LPARA_OP_SHR = 6'd22,
  localparam logic [31:0] LPARA_OP_SHL = 6'd23,
  localparam logic [31:0] LPARA_OP_SETB = 6'd24,
  localparam logic [31:0] LPARA_OP_TRUNCE = 6'd25,
  localparam logic [31:0] LPARA_OP_CALL = 6'd26,
  localparam logic [31:0] LPARA_OP_RET = 6'd27,
  localparam logic [31:0] LPARA_OP_JMP = 6'd28,
  localparam logic [31:0] LPARA_OP_BRF = 6'd29,
  localparam logic [31:0] LPARA_OP_BRN = 6'd30,
  localparam logic [31:0] LPARA_OP_END = 6'd31,
  localparam logic [31:0] LPARA_OP_ERR = 6'd32,
  localparam logic [31:0] LPARA_OP_RDB = 6'd33,
  localparam logic [31:0] LPARA_OP_WRB = 6'd34,
  localparam logic [31:0] LPARA_OP_LDK = 6'd35,
  localparam logic [31:0] LPARA_OP_LDR = 6'd36,
  localparam logic [31:0] LPARA_OP_HDCLR = 6'd37,
  localparam logic [31:0] LPARA_OP_HDREG = 6'd38,
  localparam logic [31:0] LPARA_OP_HDIMM = 6'd39,
  localparam logic [31:0] LPARA_OP_HGO = 6'd40,
  localparam logic [31:0] LPARA_OP_HRD = 6'd41,
  localparam logic [31:0] LPARA_OP_HRDV = 6'd42,
  localparam logic [31:0] LPARA_OP_HMID = 6'd43,
  localparam logic [31:0] LPARA_OP_LDV = 6'd44,
  localparam logic [31:0] LPARA_OP_XORB = 6'd45,
  localparam logic [31:0] LPARA_CID_NBITS = 5'd24,
  localparam logic [31:0] LPARA_CID_IDENT0 = 5'd20,
  localparam logic [31:0] LPARA_HMODE_OP = 5'd15,
  localparam logic [31:0] LPARA_ERRF_OPUNS = 12'd2,
  localparam logic [31:0] LPARA_IO_RDB = 2'd0,
  localparam logic [31:0] LPARA_IO_WRB = 2'd1,
  localparam logic [31:0] LPARA_IO_HGO = 2'd2
) (
  // Clock, reset and clearing (i_clr zeroizes every register that can hold a secret)
  input  wire                i_clk_core,
  input  wire                i_rst_n_core,
  input  wire                i_clr,

  // Start pulses and the snapshot of the operation
  input  wire                i_start,
  input  wire                i_vas_start,
  input  wire  [3:0]         i_run_alg,
  input  wire  [1:0]         i_run_op,
  input  wire  [2:0]         i_run_hash,
  input  wire  [31:0]        i_run_len_msg,
  input  wire  [7:0]         i_run_len_ctx,
  input  wire                i_run_det,
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

  // Private key and random pool
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

  // Instruction codes (the order of OPS in ec_isa.py)

  // Constant ids of the ROM table (order of CNAMES in gen_ec_rom.py)

  // Hash mode field of HGO that selects the hash of dsig_op.hash

  // Unsupported operation flag (bit number of dsig_err)

  // States
  typedef enum logic [3:0] {
    ENUM_ST_IDLE  = 4'd0,
    ENUM_ST_ENTRY = 4'd1,
    ENUM_ST_EXEC  = 4'd2,
    ENUM_ST_MUL   = 4'd3,
    ENUM_ST_RED   = 4'd4,
    ENUM_ST_POW   = 4'd5,
    ENUM_ST_SMUL  = 4'd6,
    ENUM_ST_IOW   = 4'd7,
    ENUM_ST_FIN   = 4'd8,
    ENUM_ST_MM    = 4'd9
  } ec_state_type_def;

  // Kinds of waiting I/O operations

  // Internal signal declarations
  ec_state_type_def reg_fsm_ec_current_state;
  ec_state_type_def w_fsm_ec_nxt_state;

  // Register file, flags, modulus and program counter
  logic [575:0]  reg_rf [32];
  logic [7:0]    reg_f;
  logic [575:0]  reg_m;
  logic [9:0]    reg_mbits;
  logic [12:0]   reg_pc;
  logic [12:0]   reg_ret_pc;
  logic [63:0]   reg_ins;

  // Operation snapshot
  logic [2:0]    reg_curve;
  logic [1:0]    reg_op;
  logic [2:0]    reg_hash;
  logic          reg_vas;
  logic [31:0]   reg_len_msg;
  logic [7:0]    reg_len_ctx;
  logic          reg_f_ph;
  logic          reg_det;
  logic [16:0]   reg_off_msg;
  logic [16:0]   reg_off_sig;
  logic [16:0]   reg_off_pk;
  logic [16:0]   reg_off_res;

  // Result
  logic          reg_err;
  logic [11:0]   reg_err_flags;
  logic          reg_sigok;
  logic          reg_cleared;

  // Multiplier and reducer
  logic [575:0]  reg_ma;
  logic [575:0]  reg_mb;
  logic [575:0]  reg_acc;
  logic [9:0]    reg_cnt;
  logic          reg_mul_ret;
  // Montgomery path: odd modulus, constants of the modulus, phase (0: a b R^-1, 1: times R^2 R^-1)
  logic          reg_modd;
  logic [127:0]  reg_mp;
  logic [575:0]  reg_r2;
  logic [4:0]    reg_nd;
  logic          reg_mm_ph;
  logic          reg_mm_go;
  logic [575:0]  reg_mm_t;
  logic [127:0]  w_rom_mp;
  logic [575:0]  w_rom_r2;
  logic [4:0]    w_rom_nd;
  logic          w_mm_done;
  logic [575:0]  w_mm_r;

  // Power
  logic [575:0]  reg_pw_acc;
  logic [9:0]    reg_pw_i;
  logic [1:0]    reg_pw_ph;

  // Scalar multiplication
  logic [12:0]   reg_sm_dbl;
  logic [12:0]   reg_sm_add;
  logic [12:0]   reg_sm_ret;
  logic [9:0]    reg_sm_i;
  logic [4:0]    reg_sm_k;
  logic [1:0]    reg_sm_c;
  logic [1:0]    reg_sm_ph;
  logic          reg_sm_call;
  logic          reg_sm_bitq;
  logic [2303:0] reg_sm_sh;

  // I/O
  logic [1:0]    reg_io_kind;
  logic          reg_go;
  logic [1023:0] reg_head;
  logic [8:0]    reg_head_len;
  logic [2047:0] reg_mid;
  logic [8:0]    reg_mid_len;
  logic          reg_hsel;
  logic [3:0]    reg_hmode;
  logic [15:0]   reg_hout;
  logic [1:0]    reg_htail;
  logic [7:0]    reg_dlen;

  // Instruction decode (live and latched)
  logic [63:0]   w_ins;
  logic [5:0]    w_op;
  logic [4:0]    w_rd;
  logic [4:0]    w_ra;
  logic [4:0]    w_rb;
  logic [42:0]   w_imm;
  logic [5:0]    w_ri_op;
  logic [4:0]    w_ri_rd;
  logic [4:0]    w_ri_ra;
  logic [4:0]    w_ri_rb;
  logic [42:0]   w_ri_imm;

  // ROM and constants
  logic [4:0]    w_cid;
  logic [575:0]  w_const;
  logic [12:0]   w_entry;
  logic [255:0]  w_str;
  logic [7:0]    w_str_len;

  // Operand reads
  logic [575:0]  w_ra_v;
  logic [575:0]  w_rb_v;

  // Modular add, subtract and the serial step
  logic [577:0]  w_add_s;
  logic [577:0]  w_add_d;
  logic [575:0]  w_add_r;
  logic [577:0]  w_sub_d;
  logic [575:0]  w_sub_r;
  logic          w_mulbit;
  logic [575:0]  w_addend;
  logic [579:0]  w_sum;
  logic [579:0]  w_s1;
  logic [579:0]  w_s2;
  logic [575:0]  w_mul_next;
  logic [9:0]    w_mbits_new;

  // Exponent, scalar and generic helpers
  logic [9:0]    w_e_msb;
  logic          w_e_zero;
  logic          w_pw_bit;
  logic          w_sm_bit;
  logic [10:0]   w_trunce_sh;

  // Conversion and I/O data
  logic [575:0]  w_key_vec;
  logic [575:0]  w_pool_vec;
  logic [575:0]  w_dig_vec;
  logic [575:0]  w_dig_all;
  logic [575:0]  w_brd_data;
  logic [575:0]  w_wr_vec;
  logic [575:0]  w_hd_vec;
  logic [23:0]   w_ctx_addr;
  logic          w_htail_ctx;
  logic          w_htail_mid;
  logic [575:0]  w_xorb_pat;
  logic [19:0]   w_io_addr;
  logic [16:0]   w_area_base;
  logic [3:0]    w_hash_mode;
  logic          w_brd_done;
  logic          w_bwr_done;
  logic          w_hf_done;
  logic [1023:0] w_digest;
  logic [3:0]    w_hf_mode_map;
  logic [7:0]    w_dlen_new;
  logic          w_rd_en_b;
  logic [PARA_WA-1:0] w_rd_addr_b;
  logic          w_tr_en;
  logic [PARA_WA-1:0] w_tr_addr;
  logic [20:0]   w_tr_addr_full;
  logic [2:0]    w_curve_new;
  logic          w_start_any;

  // Byte string conversion: low ln bytes of x as a byte vector (byte 0 in bits [7:0]); big-endian
  // form reverses the bytes. It is its own inverse, so it serves the reads and the writes.
  function automatic logic [575:0] f_conv(input logic [575:0] x, input logic [7:0] ln, input logic be);
    logic [575:0] m;
    logic [575:0] r;
    logic [10:0]  sh;
    begin
      m = x & ((576'd1 << {ln, 3'b000}) - 576'd1);
      r = 576'd0;
      for (int i = 0; i < 72; i++)
        r[8*i +: 8] = m[8*(71-i) +: 8];
      sh = {3'd0, (8'd72 - ln)} << 3;
      if (be)
        f_conv = r >> sh;
      else
        f_conv = m;
    end
  endfunction

  // Index of the most significant 1 of x (0 when x is 0 or 1).
  function automatic logic [9:0] f_msb(input logic [575:0] x);
    logic [9:0] r;
    begin
      r = 10'd0;
      for (int i = 0; i < 576; i++)
        if (x[i])
          r = 10'(i);
      f_msb = r;
    end
  endfunction

  // Curve number of an algorithm (the unsupported variants give 7).
  function automatic logic [2:0] f_curve(input logic [3:0] alg);
    case (alg)
      4'd0:    f_curve = 3'd0;
      4'd1:    f_curve = 3'd6;
      4'd2:    f_curve = 3'd6;
      4'd3:    f_curve = 3'd1;
      4'd4:    f_curve = 3'd1;
      4'd5:    f_curve = 3'd2;
      4'd6:    f_curve = 3'd3;
      4'd7:    f_curve = 3'd4;
      4'd8:    f_curve = 3'd5;
      default: f_curve = 3'd7;
    endcase
  endfunction

  // ---------------------------------------------------------------------------------------------
  // ROM
  // ---------------------------------------------------------------------------------------------
  m_vlsit_dsig_ec_rom u_rom (
    .i_pc      (reg_pc),
    .o_ins     (w_ins),
    .i_curve   (reg_curve),
    .i_cid     (w_cid),
    .o_const   (w_const),
    .i_op      (reg_op),
    .i_det     (reg_det),
    .i_hsel    (reg_hash[1:0]),
    .o_entry   (w_entry),
    .i_str_id  (w_imm[3:0]),
    .o_str     (w_str),
    .o_str_len (w_str_len),
    .i_msel    (w_imm[0]),
    .i_mulw    (LPARA_MULW_CODE[1:0]),
    .o_mp      (w_rom_mp),
    .o_r2      (w_rom_r2),
    .o_nd      (w_rom_nd)
  );

  // Digit-serial Montgomery multiplier (phase 0: a b R^-1; phase 1: times R^2 R^-1, so a b mod m)
  m_vlsit_dsig_mmul #(
    .PARA_MUL_W   (PARA_MUL_W)
  ) u_mmul (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (i_clr),
    .i_start      (reg_mm_go),
    .i_a          (reg_mm_ph ? reg_mm_t : reg_ma),
    .i_b          (reg_mm_ph ? reg_r2 : reg_mb),
    .i_m          (reg_m),
    .i_mp         (reg_mp),
    .i_nd         (reg_nd),
    .o_done       (w_mm_done),
    .o_r          (w_mm_r)
  );

  assign w_op  = w_ins[63:58];
  assign w_rd  = w_ins[57:53];
  assign w_ra  = w_ins[52:48];
  assign w_rb  = w_ins[47:43];
  assign w_imm = w_ins[42:0];

  assign w_ri_op  = reg_ins[63:58];
  assign w_ri_rd  = reg_ins[57:53];
  assign w_ri_ra  = reg_ins[52:48];
  assign w_ri_rb  = reg_ins[47:43];
  assign w_ri_imm = reg_ins[42:0];

  // Constant id: SETM and LDC take it from the instruction, TRUNCE reads NBITS, SMUL reads IDENTi.
  always_comb begin : p_com_cid
    w_cid = w_imm[4:0];
    if (reg_fsm_ec_current_state == ENUM_ST_SMUL)
      w_cid = LPARA_CID_IDENT0 + {3'd0, reg_sm_c};
    else if (w_op == LPARA_OP_TRUNCE)
      w_cid = LPARA_CID_NBITS;
  end

  // ---------------------------------------------------------------------------------------------
  // Operand reads and the modular arithmetic
  // ---------------------------------------------------------------------------------------------
  assign w_ra_v = reg_rf[w_ra];
  assign w_rb_v = reg_rf[w_rb];

  // Modular add: a + b, minus m when the sum is not smaller than m.
  assign w_add_s = {2'b00, w_ra_v} + {2'b00, w_rb_v};
  assign w_add_d = w_add_s - {2'b00, reg_m};
  assign w_add_r = w_add_d[577] ? w_add_s[575:0] : w_add_d[575:0];

  // Modular subtract: a - b, plus m when the difference is negative.
  assign w_sub_d = {2'b00, w_ra_v} - {2'b00, w_rb_v};
  assign w_sub_r = w_sub_d[577] ? (w_sub_d[575:0] + reg_m) : w_sub_d[575:0];

  // Serial step of the multiply (shift, add the multiplicand) and of the reduce (shift, add a bit):
  // the
  // sum is smaller than 3 m, so one of the sum, sum - m and sum - 2 m is the result.
  assign w_mulbit = reg_mb[reg_cnt];
  assign w_addend = (reg_fsm_ec_current_state == ENUM_ST_RED) ? {575'd0, w_mulbit} :
                    (w_mulbit ? reg_ma : 576'd0);
  assign w_sum    = {3'd0, reg_acc, 1'b0} + {4'd0, w_addend};
  assign w_s1     = w_sum - {4'd0, reg_m};
  assign w_s2     = w_sum - {3'd0, reg_m, 1'b0};

  always_comb begin : p_com_mul_next
    w_mul_next = w_sum[575:0];
    if (!w_s2[579])
      w_mul_next = w_s2[575:0];
    else if (!w_s1[579])
      w_mul_next = w_s1[575:0];
    else
      w_mul_next = w_sum[575:0];
  end

  // Number of bits of the new modulus (SETM)
  assign w_mbits_new = f_msb(w_const) + 10'd1;

  // Exponent of POW, scalar bit of SMUL
  assign w_e_msb  = f_msb(w_rb_v);
  assign w_e_zero = (w_rb_v == 576'd0);
  assign w_pw_bit = reg_rf[w_ri_rb][reg_pw_i];
  assign w_sm_bit = reg_rf[reg_sm_k][reg_sm_i];

  // TRUNCE shift: the bits of the digest beyond the bit length of n
  assign w_trunce_sh = ({3'd0, reg_dlen} << 3) > {1'b0, w_const[9:0]} ?
                       (({3'd0, reg_dlen} << 3) - {1'b0, w_const[9:0]}) : 11'd0;

  // ---------------------------------------------------------------------------------------------
  // I/O units
  // ---------------------------------------------------------------------------------------------
  assign w_area_base = (w_ri_ra[1:0] == 2'd0) ? reg_off_msg :
                       (w_ri_ra[1:0] == 2'd1) ? reg_off_sig :
                       (w_ri_ra[1:0] == 2'd2) ? reg_off_pk  : reg_off_res;
  assign w_io_addr   = 20'(w_area_base) + w_ri_imm[31:12];

  assign w_wr_vec    = f_conv(reg_rf[w_ri_rd], w_ri_imm[7:0], w_ri_rb[0]);
  assign w_hd_vec    = f_conv(w_ra_v, w_imm[7:0], w_rb[0]);
  assign w_key_vec   = 576'(({32'd0, i_key} >> {w_imm[19:12], 3'b000}));
  assign w_pool_vec  = 576'(i_pool >> {w_imm[19:12], 3'b000});
  assign w_dig_vec   = 576'(w_digest >> {w_imm[19:12], 3'b000});
  assign w_dig_all   = w_digest[575:0];

  // Hash selected by dsig_op.hash
  always_comb begin : p_com_hmap
    w_hf_mode_map = 4'd1;
    case (reg_hash)
      3'd0:    w_hf_mode_map = 4'd1;
      3'd1:    w_hf_mode_map = 4'd2;
      3'd2:    w_hf_mode_map = 4'd3;
      3'd3:    w_hf_mode_map = 4'd9;
      3'd4:    w_hf_mode_map = 4'd10;
      3'd5:    w_hf_mode_map = 4'd11;
      default: w_hf_mode_map = 4'd1;
    endcase
  end

  // Length of the digest that HGO produces
  always_comb begin : p_com_dlen
    w_dlen_new = w_imm[7:0];
    w_hash_mode = (w_ra == LPARA_HMODE_OP) ? w_hf_mode_map : w_ra[3:0];
    case (w_hash_mode)
      4'd1:    w_dlen_new = 8'd32;
      4'd2:    w_dlen_new = 8'd48;
      4'd3:    w_dlen_new = 8'd64;
      4'd9:    w_dlen_new = 8'd32;
      4'd10:   w_dlen_new = 8'd48;
      4'd11:   w_dlen_new = 8'd64;
      default: w_dlen_new = w_imm[7:0];
    endcase
  end

  m_vlsit_dsig_brd #(.PARA_WA(PARA_WA)) u_brd (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (i_clr),
    .i_go         (reg_go & (reg_io_kind == LPARA_IO_RDB) & (reg_fsm_ec_current_state == ENUM_ST_IOW)),
    .i_addr       (w_io_addr),
    .i_len        (w_ri_imm[7:0]),
    .o_data       (w_brd_data),
    .o_done       (w_brd_done),
    .o_rd_en      (w_rd_en_b),
    .o_rd_addr    (w_rd_addr_b),
    .i_rd_data    (i_rd_data),
    .i_rd_valid   (i_rd_valid)
  );

  m_vlsit_dsig_bwr #(.PARA_WA(PARA_WA)) u_bwr (
    .i_clk_core   (i_clk_core),
    .i_rst_n_core (i_rst_n_core),
    .i_clr        (i_clr),
    .i_go         (reg_go & (reg_io_kind == LPARA_IO_WRB) & (reg_fsm_ec_current_state == ENUM_ST_IOW)),
    .i_addr       (w_io_addr),
    .i_len        (w_ri_imm[7:0]),
    .i_data       (w_wr_vec),
    .o_done       (w_bwr_done),
    .o_wr_en      (o_wr_en),
    .o_wr_addr    (o_wr_addr),
    .o_wr_data    (o_wr_data),
    .o_wr_strb    (o_wr_strb)
  );

  assign w_htail_ctx = (reg_htail == 2'd2);
  assign w_htail_mid = reg_htail[1];
  assign w_xorb_pat  = {72{w_imm[7:0]}};
  assign w_ctx_addr  = {7'd0, reg_off_msg} + reg_len_msg[23:0];

  m_vlsit_dsig_hfeed #(.PARA_HEAD_BYTES(128), .PARA_DIG_BYTES(128), .PARA_TA_W(24), .PARA_MID_BYTES(256)) u_hfeed (
    .i_clk_core     (i_clk_core),
    .i_rst_n_core   (i_rst_n_core),
    .i_clr          (i_clr),
    .i_go           (reg_go & (reg_io_kind == LPARA_IO_HGO) & (reg_fsm_ec_current_state == ENUM_ST_IOW)),
    .i_mode         (reg_hmode),
    .i_outlen       (reg_hout),
    .i_head         (reg_head),
    .i_head_len     (reg_head_len),
    .i_mid          (reg_mid),
    .i_mid_len      (w_htail_mid ? reg_mid_len : 9'd0),
    .i_tail_addr    (w_htail_ctx ? w_ctx_addr : ((reg_htail == 2'd1) ? {7'd0, reg_off_msg} : 24'd0)),
    .i_tail_len     (w_htail_ctx ? {16'd0, reg_len_ctx} : ((reg_htail == 2'd1) ? reg_len_msg[23:0] : 24'd0)),
    .i_tail2_addr   (w_htail_ctx ? {7'd0, reg_off_msg} : 24'd0),
    .i_tail2_len    (w_htail_ctx ? reg_len_msg[23:0] : 24'd0),
    .o_digest       (w_digest),
    .o_done         (w_hf_done),
    .o_busy         (),
    .o_tr_en        (w_tr_en),
    .o_tr_addr      (w_tr_addr_full),
    .i_tr_data      (i_rd_data),
    .i_tr_valid     (i_rd_valid),
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

  // The tail of the hash and the byte reader share the buffer read port (never active together).
  assign w_tr_addr = w_tr_addr_full[PARA_WA-1:0];
  assign o_rd_en   = w_rd_en_b | w_tr_en;
  assign o_rd_addr = w_tr_en ? w_tr_addr : w_rd_addr_b;

  // ---------------------------------------------------------------------------------------------
  // Start decode
  // ---------------------------------------------------------------------------------------------
  assign w_start_any   = i_start | i_vas_start;
  assign w_curve_new   = f_curve(i_run_alg);

  // ---------------------------------------------------------------------------------------------
  // FSM
  // ---------------------------------------------------------------------------------------------
  // Part 1: state register
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_ec
    if (!i_rst_n_core)
      reg_fsm_ec_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_ec_current_state <= w_fsm_ec_nxt_state;
  end

  // Part 2: next state
  always_comb begin : p_com_fsm_nxt
    w_fsm_ec_nxt_state = reg_fsm_ec_current_state;
    case (reg_fsm_ec_current_state)
      ENUM_ST_IDLE: begin
        if (w_start_any)
          w_fsm_ec_nxt_state = ENUM_ST_ENTRY;
      end
      ENUM_ST_ENTRY: begin
        if (reg_err)
          w_fsm_ec_nxt_state = ENUM_ST_FIN;
        else
          w_fsm_ec_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_EXEC: begin
        case (w_op)
          LPARA_OP_MUL:  w_fsm_ec_nxt_state = reg_modd ? ENUM_ST_MM : ENUM_ST_MUL;
          LPARA_OP_RED:  w_fsm_ec_nxt_state = ENUM_ST_RED;
          LPARA_OP_POW: begin
            if (!w_e_zero && (w_e_msb != 10'd0))
              w_fsm_ec_nxt_state = ENUM_ST_POW;
          end
          LPARA_OP_SMUL: w_fsm_ec_nxt_state = ENUM_ST_SMUL;
          LPARA_OP_RET: begin
            if (reg_sm_call)
              w_fsm_ec_nxt_state = ENUM_ST_SMUL;
          end
          LPARA_OP_END:  w_fsm_ec_nxt_state = ENUM_ST_FIN;
          LPARA_OP_ERR:  w_fsm_ec_nxt_state = ENUM_ST_FIN;
          LPARA_OP_RDB:  w_fsm_ec_nxt_state = ENUM_ST_IOW;
          LPARA_OP_WRB:  w_fsm_ec_nxt_state = ENUM_ST_IOW;
          LPARA_OP_HGO:  w_fsm_ec_nxt_state = ENUM_ST_IOW;
          default:       w_fsm_ec_nxt_state = ENUM_ST_EXEC;
        endcase
      end
      ENUM_ST_MUL: begin
        if (reg_cnt == 10'd0) begin
          if (reg_mul_ret)
            w_fsm_ec_nxt_state = ENUM_ST_POW;
          else
            w_fsm_ec_nxt_state = ENUM_ST_EXEC;
        end
      end
      ENUM_ST_RED: begin
        if (reg_cnt == 10'd0)
          w_fsm_ec_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_MM: begin
        if (w_mm_done & reg_mm_ph) begin
          if (reg_mul_ret)
            w_fsm_ec_nxt_state = ENUM_ST_POW;
          else
            w_fsm_ec_nxt_state = ENUM_ST_EXEC;
        end
      end
      ENUM_ST_POW: begin
        case (reg_pw_ph)
          2'd0:    w_fsm_ec_nxt_state = reg_modd ? ENUM_ST_MM : ENUM_ST_MUL;
          2'd1:    w_fsm_ec_nxt_state = reg_modd ? ENUM_ST_MM : ENUM_ST_MUL;
          default: begin
            if (reg_pw_i == 10'd0)
              w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          end
        endcase
      end
      ENUM_ST_SMUL: begin
        case (reg_sm_ph)
          2'd0:    w_fsm_ec_nxt_state = ENUM_ST_SMUL;
          2'd1:    w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          2'd2:    w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          default: begin
            if (reg_sm_i == 10'd0)
              w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          end
        endcase
      end
      ENUM_ST_IOW: begin
        case (reg_io_kind)
          LPARA_IO_RDB: begin
            if (w_brd_done)
              w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          end
          LPARA_IO_WRB: begin
            if (w_bwr_done)
              w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          end
          default: begin
            if (w_hf_done)
              w_fsm_ec_nxt_state = ENUM_ST_EXEC;
          end
        endcase
      end
      ENUM_ST_FIN: begin
        // The verify-after-sign start of the control block arrives in the cycle of the end pulse.
        if (w_start_any)
          w_fsm_ec_nxt_state = ENUM_ST_ENTRY;
        else
          w_fsm_ec_nxt_state = ENUM_ST_IDLE;
      end
      default:     w_fsm_ec_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_ec_nxt_state = ENUM_ST_IDLE;
  end

  // Part 3: outputs that follow the state
  assign o_busy      = (reg_fsm_ec_current_state != ENUM_ST_IDLE);
  assign o_done      = (reg_fsm_ec_current_state == ENUM_ST_FIN) & ~reg_vas & ~reg_err;
  assign o_err       = (reg_fsm_ec_current_state == ENUM_ST_FIN) & ~reg_vas & reg_err;
  assign o_err_flags = reg_err_flags;
  assign o_sigok     = reg_sigok;
  assign o_vas_done  = (reg_fsm_ec_current_state == ENUM_ST_FIN) & reg_vas;
  assign o_vas_ok    = reg_sigok & ~reg_err;
  assign o_cleared   = reg_cleared;

  // ---------------------------------------------------------------------------------------------
  // Data registers
  // ---------------------------------------------------------------------------------------------
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
    if (!i_rst_n_core) begin
      for (int i = 0; i < 32; i++)
        reg_rf[i] <= 576'd0;
      reg_f         <= 8'd0;
      reg_m         <= 576'd0;
      reg_mbits     <= 10'd0;
      reg_pc        <= 13'd0;
      reg_ret_pc    <= 13'd0;
      reg_ins       <= 64'd0;
      reg_curve     <= 3'd0;
      reg_op        <= 2'd0;
      reg_hash      <= 3'd0;
      reg_vas       <= 1'b0;
      reg_len_msg   <= 32'd0;
      reg_len_ctx   <= 8'd0;
      reg_f_ph      <= 1'b0;
      reg_det       <= 1'b0;
      reg_off_msg   <= 17'd0;
      reg_off_sig   <= 17'd0;
      reg_off_pk    <= 17'd0;
      reg_off_res   <= 17'd0;
      reg_err       <= 1'b0;
      reg_err_flags <= 12'd0;
      reg_sigok     <= 1'b0;
      reg_cleared   <= 1'b1;
      reg_ma        <= 576'd0;
      reg_mb        <= 576'd0;
      reg_acc       <= 576'd0;
      reg_cnt       <= 10'd0;
      reg_mul_ret   <= 1'b0;
      reg_modd      <= 1'b0;
      reg_mp        <= 128'd0;
      reg_r2        <= 576'd0;
      reg_nd        <= 5'd0;
      reg_mm_ph     <= 1'b0;
      reg_mm_go     <= 1'b0;
      reg_mm_t      <= 576'd0;
      reg_pw_acc    <= 576'd0;
      reg_pw_i      <= 10'd0;
      reg_pw_ph     <= 2'd0;
      reg_sm_dbl    <= 13'd0;
      reg_sm_add    <= 13'd0;
      reg_sm_ret    <= 13'd0;
      reg_sm_i      <= 10'd0;
      reg_sm_k      <= 5'd0;
      reg_sm_c      <= 2'd0;
      reg_sm_ph     <= 2'd0;
      reg_sm_call   <= 1'b0;
      reg_sm_bitq   <= 1'b0;
      reg_sm_sh     <= 2304'd0;
      reg_io_kind   <= 2'd0;
      reg_go        <= 1'b0;
      reg_head      <= 1024'd0;
      reg_head_len  <= 9'd0;
      reg_mid       <= 2048'd0;
      reg_mid_len   <= 9'd0;
      reg_hsel      <= 1'b0;
      reg_hmode     <= 4'd0;
      reg_hout      <= 16'd0;
      reg_htail     <= 2'd0;
      reg_dlen      <= 8'd0;
    end
    else if (i_clr) begin
      for (int i = 0; i < 32; i++)
        reg_rf[i] <= 576'd0;
      reg_f         <= 8'd0;
      reg_ins       <= 64'd0;
      reg_err       <= 1'b0;
      reg_err_flags <= 12'd0;
      reg_sigok     <= 1'b0;
      reg_cleared   <= 1'b1;
      reg_ma        <= 576'd0;
      reg_mb        <= 576'd0;
      reg_acc       <= 576'd0;
      reg_pw_acc    <= 576'd0;
      reg_mm_t      <= 576'd0;
      reg_mm_go     <= 1'b0;
      reg_sm_call   <= 1'b0;
      reg_sm_bitq   <= 1'b0;
      reg_sm_sh     <= 2304'd0;
      reg_go        <= 1'b0;
      reg_head      <= 1024'd0;
      reg_head_len  <= 9'd0;
      reg_mid       <= 2048'd0;
      reg_mid_len   <= 9'd0;
      reg_hsel      <= 1'b0;
      reg_dlen      <= 8'd0;
    end
    else begin
      case (reg_fsm_ec_current_state)
        ENUM_ST_IDLE,
        ENUM_ST_FIN: begin
          if (w_start_any) begin
            reg_vas       <= i_vas_start;
            reg_curve     <= w_curve_new;
            reg_op        <= i_vas_start ? 2'd3 : i_run_op;
            reg_hash      <= i_run_hash;
            reg_len_msg   <= i_run_len_msg;
            reg_len_ctx   <= i_run_len_ctx;
            reg_f_ph      <= (i_run_alg == 4'd2) | (i_run_alg == 4'd4);
            reg_det       <= i_run_det;
            reg_off_msg   <= i_run_off_msg;
            reg_off_sig   <= i_run_off_sig;
            reg_off_pk    <= i_run_off_pk;
            reg_off_res   <= i_run_off_res;
            reg_f         <= 8'd0;
            reg_err       <= (w_curve_new == 3'd7);
            reg_err_flags <= (w_curve_new == 3'd7) ? LPARA_ERRF_OPUNS : 12'd0;
            reg_sigok     <= 1'b0;
            reg_cleared   <= 1'b0;
            reg_sm_call   <= 1'b0;
            reg_head_len  <= 9'd0;
          end
        end
        ENUM_ST_ENTRY: begin
          reg_pc <= w_entry;
        end
        ENUM_ST_EXEC: begin
          reg_ins <= w_ins;
          reg_pc  <= reg_pc + 13'd1;
          case (w_op)
            LPARA_OP_ADD: reg_rf[w_rd] <= w_add_r;
            LPARA_OP_SUB: reg_rf[w_rd] <= w_sub_r;
            LPARA_OP_MUL: begin
              reg_ma      <= w_ra_v;
              reg_mb      <= w_rb_v;
              reg_acc     <= 576'd0;
              reg_cnt     <= reg_mbits - 10'd1;
              reg_mul_ret <= 1'b0;
              reg_mm_go   <= reg_modd;
              reg_mm_ph   <= 1'b0;
            end
            LPARA_OP_RED: begin
              reg_mb  <= w_ra_v;
              reg_acc <= 576'd0;
              reg_cnt <= 10'd575;
            end
            LPARA_OP_MOV: reg_rf[w_rd] <= w_ra_v;
            LPARA_OP_LDI: reg_rf[w_rd] <= 576'(w_imm);
            LPARA_OP_LDC: reg_rf[w_rd] <= w_const;
            LPARA_OP_SETM: begin
              reg_m     <= w_const;
              reg_mbits <= w_mbits_new;
              reg_modd  <= (w_imm[4:1] == 4'd0);
              reg_mp    <= w_rom_mp;
              reg_r2    <= w_rom_r2;
              reg_nd    <= w_rom_nd;
            end
            LPARA_OP_POW: begin
              if (w_e_zero)
                reg_rf[w_rd] <= 576'd1;
              else if (w_e_msb == 10'd0)
                reg_rf[w_rd] <= w_ra_v;
              else begin
                reg_pw_acc <= w_ra_v;
                reg_pw_i   <= w_e_msb - 10'd1;
                reg_pw_ph  <= 2'd0;
              end
            end
            LPARA_OP_SMUL: begin
              reg_sm_dbl  <= w_imm[28:16];
              reg_sm_add  <= w_imm[12:0];
              reg_sm_ret  <= reg_pc + 13'd1;
              reg_sm_i    <= w_imm[42:33] - 10'd1;
              reg_sm_k    <= w_ra;
              reg_sm_c    <= 2'd0;
              reg_sm_ph   <= 2'd0;
            end
            LPARA_OP_EQ:  reg_f[w_rd[2:0]] <= (w_ra_v == w_rb_v);
            LPARA_OP_LTU: reg_f[w_rd[2:0]] <= (w_ra_v < w_rb_v);
            LPARA_OP_BIT: reg_f[w_rd[2:0]] <= w_ra_v[w_imm[9:0]];
            LPARA_OP_ISZ: reg_f[w_rd[2:0]] <= (w_ra_v == 576'd0);
            LPARA_OP_FNOT: reg_f[w_rd[2:0]] <= ~reg_f[w_ra[2:0]];
            LPARA_OP_FAND: reg_f[w_rd[2:0]] <= reg_f[w_ra[2:0]] & reg_f[w_rb[2:0]];
            LPARA_OP_FOR:  reg_f[w_rd[2:0]] <= reg_f[w_ra[2:0]] | reg_f[w_rb[2:0]];
            LPARA_OP_FSET: reg_f[w_rd[2:0]] <= w_imm[0];
            LPARA_OP_CMOV: begin
              if (reg_f[w_rb[2:0]])
                reg_rf[w_rd] <= w_ra_v;
            end
            LPARA_OP_AND: reg_rf[w_rd] <= w_ra_v & w_rb_v;
            LPARA_OP_OR:  reg_rf[w_rd] <= w_ra_v | w_rb_v;
            LPARA_OP_SHR: reg_rf[w_rd] <= w_ra_v >> w_imm[9:0];
            LPARA_OP_SHL: reg_rf[w_rd] <= w_ra_v << w_imm[9:0];
            LPARA_OP_SETB: reg_rf[w_rd] <= w_ra_v | (576'(reg_f[w_rb[2:0]]) << w_imm[9:0]);
            LPARA_OP_TRUNCE: reg_rf[w_rd] <= w_ra_v >> w_trunce_sh;
            LPARA_OP_CALL: begin
              reg_ret_pc <= reg_pc + 13'd1;
              reg_pc     <= w_imm[12:0];
            end
            LPARA_OP_RET: begin
              if (reg_sm_call)
                reg_sm_call <= 1'b0;
              else
                reg_pc <= reg_ret_pc;
            end
            LPARA_OP_JMP: reg_pc <= w_imm[12:0];
            LPARA_OP_BRF: begin
              if (reg_f[w_ra[2:0]])
                reg_pc <= w_imm[12:0];
            end
            LPARA_OP_BRN: begin
              if (!reg_f[w_ra[2:0]])
                reg_pc <= w_imm[12:0];
            end
            LPARA_OP_END: reg_sigok <= reg_f[7];
            LPARA_OP_ERR: begin
              reg_err       <= 1'b1;
              reg_err_flags <= 12'd1 << w_imm[3:0];
              reg_sigok     <= 1'b0;
            end
            LPARA_OP_RDB: begin
              reg_io_kind <= LPARA_IO_RDB;
              reg_go      <= 1'b1;
            end
            LPARA_OP_WRB: begin
              reg_io_kind <= LPARA_IO_WRB;
              reg_go      <= 1'b1;
            end
            LPARA_OP_LDK: reg_rf[w_rd] <= f_conv(w_key_vec, w_imm[7:0], w_rb[0]);
            LPARA_OP_LDR: reg_rf[w_rd] <= f_conv(w_pool_vec, w_imm[7:0], w_rb[0]);
            LPARA_OP_HDCLR: begin
              reg_head     <= 1024'd0;
              reg_head_len <= 9'd0;
              reg_mid      <= 2048'd0;
              reg_mid_len  <= 9'd0;
              reg_hsel     <= 1'b0;
            end
            LPARA_OP_HDREG: begin
              if (reg_hsel) begin
                reg_mid     <= reg_mid | (2048'(w_hd_vec) << {reg_mid_len, 3'b000});
                reg_mid_len <= reg_mid_len + {1'b0, w_imm[7:0]};
              end else begin
                reg_head     <= reg_head | (1024'(w_hd_vec) << {reg_head_len, 3'b000});
                reg_head_len <= reg_head_len + {1'b0, w_imm[7:0]};
              end
            end
            LPARA_OP_HDIMM: begin
              if (reg_hsel) begin
                reg_mid     <= reg_mid | (2048'(w_str) << {reg_mid_len, 3'b000});
                reg_mid_len <= reg_mid_len + {1'b0, w_str_len};
              end else begin
                reg_head     <= reg_head | (1024'(w_str) << {reg_head_len, 3'b000});
                reg_head_len <= reg_head_len + {1'b0, w_str_len};
              end
            end
            LPARA_OP_HMID: reg_hsel <= 1'b1;
            LPARA_OP_LDV: begin
              case (w_imm[1:0])
                2'd0:    reg_rf[w_rd] <= 576'(reg_f_ph);
                2'd1:    reg_rf[w_rd] <= 576'(reg_len_ctx);
                2'd2:    reg_rf[w_rd] <= 576'(PARA_EN_DPA[0]);
                default: reg_rf[w_rd] <= 576'd0;
              endcase
            end
            LPARA_OP_XORB: reg_rf[w_rd] <= w_ra_v ^ w_xorb_pat;
            LPARA_OP_HGO: begin
              reg_io_kind <= LPARA_IO_HGO;
              reg_go      <= 1'b1;
              reg_hmode   <= w_hash_mode;
              reg_hout    <= w_imm[15:0];
              reg_htail   <= w_rb[1:0];
              reg_dlen    <= w_dlen_new;
            end
            LPARA_OP_HRD:  reg_rf[w_rd] <= f_conv(w_dig_vec, w_imm[7:0], w_rb[0]);
            LPARA_OP_HRDV: reg_rf[w_rd] <= f_conv(w_dig_all, reg_dlen, 1'b1);
            default: begin
              reg_pc <= reg_pc + 13'd1;
            end
          endcase
        end
        ENUM_ST_MUL: begin
          reg_acc <= w_mul_next;
          reg_cnt <= reg_cnt - 10'd1;
          if (reg_cnt == 10'd0) begin
            if (reg_mul_ret) begin
              reg_pw_acc <= w_mul_next;
              if (reg_pw_ph == 2'd0)
                reg_pw_ph <= w_pw_bit ? 2'd1 : 2'd2;
              else
                reg_pw_ph <= 2'd2;
            end else begin
              reg_rf[w_ri_rd] <= w_mul_next;
            end
          end
        end
        ENUM_ST_RED: begin
          reg_acc <= w_mul_next;
          reg_cnt <= reg_cnt - 10'd1;
          if (reg_cnt == 10'd0)
            reg_rf[w_ri_rd] <= w_mul_next;
        end
        ENUM_ST_MM: begin
          reg_mm_go <= 1'b0;
          if (w_mm_done) begin
            if (!reg_mm_ph) begin
              // a b R^-1: multiply by R^2 to leave the Montgomery form
              reg_mm_t  <= w_mm_r;
              reg_mm_ph <= 1'b1;
              reg_mm_go <= 1'b1;
            end else if (reg_mul_ret) begin
              reg_pw_acc <= w_mm_r;
              if (reg_pw_ph == 2'd0)
                reg_pw_ph <= w_pw_bit ? 2'd1 : 2'd2;
              else
                reg_pw_ph <= 2'd2;
            end else begin
              reg_rf[w_ri_rd] <= w_mm_r;
            end
          end
        end
        ENUM_ST_POW: begin
          case (reg_pw_ph)
            2'd0: begin
              reg_ma      <= reg_pw_acc;
              reg_mb      <= reg_pw_acc;
              reg_acc     <= 576'd0;
              reg_cnt     <= reg_mbits - 10'd1;
              reg_mul_ret <= 1'b1;
              reg_mm_go   <= reg_modd;
              reg_mm_ph   <= 1'b0;
            end
            2'd1: begin
              reg_ma      <= reg_rf[w_ri_ra];
              reg_mb      <= reg_pw_acc;
              reg_acc     <= 576'd0;
              reg_cnt     <= reg_mbits - 10'd1;
              reg_mul_ret <= 1'b1;
              reg_mm_go   <= reg_modd;
              reg_mm_ph   <= 1'b0;
            end
            default: begin
              if (reg_pw_i == 10'd0) begin
                reg_rf[w_ri_rd] <= reg_pw_acc;
              end else begin
                reg_pw_i  <= reg_pw_i - 10'd1;
                reg_pw_ph <= 2'd0;
              end
            end
          endcase
        end
        ENUM_ST_SMUL: begin
          case (reg_sm_ph)
            2'd0: begin
              reg_rf[{3'd0, reg_sm_c}] <= w_const;
              reg_sm_c <= reg_sm_c + 2'd1;
              if (reg_sm_c == 2'd3)
                reg_sm_ph <= 2'd1;
            end
            2'd1: begin
              reg_pc      <= reg_sm_dbl;
              reg_sm_call <= 1'b1;
              reg_sm_ph   <= 2'd2;
            end
            2'd2: begin
              // double-and-add-always: ADD runs for every bit; the accumulator before ADD is kept
              // and put back in phase 3 when the bit is 0, so the time does not depend on the
              // scalar (REQ-SEC-002)
              reg_sm_ph   <= 2'd3;
              reg_pc      <= reg_sm_add;
              reg_sm_call <= 1'b1;
              reg_sm_bitq <= w_sm_bit;
              reg_sm_sh   <= {reg_rf[3], reg_rf[2], reg_rf[1], reg_rf[0]};
            end
            default: begin
              if (!reg_sm_bitq) begin
                reg_rf[0] <= reg_sm_sh[575:0];
                reg_rf[1] <= reg_sm_sh[1151:576];
                reg_rf[2] <= reg_sm_sh[1727:1152];
                reg_rf[3] <= reg_sm_sh[2303:1728];
              end
              if (reg_sm_i == 10'd0) begin
                reg_pc <= reg_sm_ret;
              end else begin
                reg_sm_i  <= reg_sm_i - 10'd1;
                reg_sm_ph <= 2'd1;
              end
            end
          endcase
        end
        ENUM_ST_IOW: begin
          reg_go <= 1'b0;
          case (reg_io_kind)
            LPARA_IO_RDB: begin
              if (w_brd_done)
                reg_rf[w_ri_rd] <= f_conv(w_brd_data, w_ri_imm[7:0], w_ri_rb[0]);
            end
            default: begin
              reg_io_kind <= reg_io_kind;
            end
          endcase
        end
        default: begin
          reg_go <= 1'b0;
        end
      endcase
    end
  end

endmodule
