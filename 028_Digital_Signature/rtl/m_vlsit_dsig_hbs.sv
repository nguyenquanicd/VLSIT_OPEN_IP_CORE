/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan and Claude Sonnet 5.5 (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-25
 * Description  : Hash-based signature verification engine of the digital signature IP: SLH-DSA
 *                (12 sets of FIPS 205, pure form), LMS and HSS (RFC 8554) and XMSS and XMSS^MT
 *                (RFC 8391, with the hash functions of SP 800-208). The engine is a small
 *                processor, the hash-tree processor. It has 32 registers of 64 bits, 8 flags, a
 *                local byte RAM (public data only), a hash head of up to 256 bytes with two
 *                tails, a byte mover (RAM, buffer, digest, hash head) and the hash feeder
 *                m_vlsit_dsig_hfeed. A verification is a program of the instruction set in the
 *                generated ROM m_vlsit_dsig_hbs_rom (verification/models/hbs/htp_isa.py
 *                describes the instruction word and gives the bit-exact model that the programs
 *                were tested with). The signature, the public key and the message are read from
 *                the buffer; the result is the flag sigok (an invalid signature is a result, not
 *                an error). The local RAM holds only public data (hash chain values, tree
 *                nodes), so it is not cleared by the clear input; the registers, the hash head
 *                and the digest are. Requirements: OP-004, OP-008, ALG-007 to ALG-009, section
 *                14.2. Deviation from MOD-02 (SHOULD, one function per module size): the engine
 *                is one processor; its datapath and its sequencer share the registers and are
 *                not split.
 */
`timescale 1ns/1ps

module m_vlsit_dsig_hbs #(
  // Parameter Description: width of the word address of the buffer port.
  // Parameter values: 4 to 16; default is 7.
  // Parameter unit: bit
  parameter logic [31:0] PARA_WA = 7,
  // Parameter Description: SLH-DSA is built.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_SLHDSA = 1,
  // Parameter Description: LMS and HSS are built.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_LMS = 1,
  // Parameter Description: XMSS and XMSS^MT are built.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_EN_XMSS = 1,
  // Parameter Description: size of the local RAM; 16384 bytes hold every set.
  // Parameter values: 4096 to 65536, a power of 2; default is 16384.
  // Parameter unit: byte
  parameter logic [31:0] PARA_RAM_BYTES = 16384,
  localparam logic [31:0] LPARA_RAM_W = $clog2(PARA_RAM_BYTES / 8),
  localparam logic [31:0] LPARA_OP_LDI = 6'd1,
  localparam logic [31:0] LPARA_OP_MOV = 6'd2,
  localparam logic [31:0] LPARA_OP_ADD = 6'd3,
  localparam logic [31:0] LPARA_OP_SUB = 6'd4,
  localparam logic [31:0] LPARA_OP_AND = 6'd5,
  localparam logic [31:0] LPARA_OP_OR = 6'd6,
  localparam logic [31:0] LPARA_OP_XOR = 6'd7,
  localparam logic [31:0] LPARA_OP_MUL = 6'd8,
  localparam logic [31:0] LPARA_OP_ADDI = 6'd9,
  localparam logic [31:0] LPARA_OP_SUBI = 6'd10,
  localparam logic [31:0] LPARA_OP_ANDI = 6'd11,
  localparam logic [31:0] LPARA_OP_SHLI = 6'd12,
  localparam logic [31:0] LPARA_OP_SHRI = 6'd13,
  localparam logic [31:0] LPARA_OP_SHL = 6'd14,
  localparam logic [31:0] LPARA_OP_SHR = 6'd15,
  localparam logic [31:0] LPARA_OP_LDT = 6'd16,
  localparam logic [31:0] LPARA_OP_LDS = 6'd17,
  localparam logic [31:0] LPARA_OP_EQ = 6'd18,
  localparam logic [31:0] LPARA_OP_LTU = 6'd19,
  localparam logic [31:0] LPARA_OP_EQI = 6'd20,
  localparam logic [31:0] LPARA_OP_ISZ = 6'd21,
  localparam logic [31:0] LPARA_OP_FNOT = 6'd22,
  localparam logic [31:0] LPARA_OP_FAND = 6'd23,
  localparam logic [31:0] LPARA_OP_FOR = 6'd24,
  localparam logic [31:0] LPARA_OP_FSET = 6'd25,
  localparam logic [31:0] LPARA_OP_BRF = 6'd26,
  localparam logic [31:0] LPARA_OP_BRN = 6'd27,
  localparam logic [31:0] LPARA_OP_JMP = 6'd28,
  localparam logic [31:0] LPARA_OP_CALL = 6'd29,
  localparam logic [31:0] LPARA_OP_RET = 6'd30,
  localparam logic [31:0] LPARA_OP_END = 6'd31,
  localparam logic [31:0] LPARA_OP_ERR = 6'd32,
  localparam logic [31:0] LPARA_OP_RLB = 6'd33,
  localparam logic [31:0] LPARA_OP_RSB = 6'd34,
  localparam logic [31:0] LPARA_OP_BLB = 6'd35,
  localparam logic [31:0] LPARA_OP_CPBR = 6'd36,
  localparam logic [31:0] LPARA_OP_CPRR = 6'd37,
  localparam logic [31:0] LPARA_OP_CMPRR = 6'd38,
  localparam logic [31:0] LPARA_OP_XORR = 6'd39,
  localparam logic [31:0] LPARA_OP_HCLR = 6'd40,
  localparam logic [31:0] LPARA_OP_HREG = 6'd41,
  localparam logic [31:0] LPARA_OP_HRAM = 6'd42,
  localparam logic [31:0] LPARA_OP_HBUF = 6'd43,
  localparam logic [31:0] LPARA_OP_HZERO = 6'd44,
  localparam logic [31:0] LPARA_OP_HZERI = 6'd45,
  localparam logic [31:0] LPARA_OP_HT1 = 6'd46,
  localparam logic [31:0] LPARA_OP_HT2 = 6'd47,
  localparam logic [31:0] LPARA_OP_HGO = 6'd48,
  localparam logic [31:0] LPARA_OP_DST = 6'd49,
  localparam logic [31:0] LPARA_OP_HMID = 6'd50,
  localparam logic [31:0] LPARA_MV_RLB = 4'd0,
  localparam logic [31:0] LPARA_MV_BLB = 4'd1,
  localparam logic [31:0] LPARA_MV_CPBR = 4'd2,
  localparam logic [31:0] LPARA_MV_CPRR = 4'd3,
  localparam logic [31:0] LPARA_MV_CMPRR = 4'd4,
  localparam logic [31:0] LPARA_MV_XORR = 4'd5,
  localparam logic [31:0] LPARA_MV_HRAM = 4'd6,
  localparam logic [31:0] LPARA_MV_HBUF = 4'd7,
  localparam logic [31:0] LPARA_MV_DST = 4'd8,
  localparam logic [31:0] LPARA_ERRF_OPUNS = 12'd2
) (
  // Clock, reset and clearing
  input  wire                i_clk_core,
  input  wire                i_rst_n_core,
  input  wire                i_clr,

  // Start and the snapshot of the operation
  input  wire                i_start,
  input  wire  [3:0]         i_run_alg,
  input  wire  [1:0]         i_run_form,
  input  wire  [3:0]         i_run_slh,
  input  wire  [4:0]         i_run_lmstype,
  input  wire  [3:0]         i_run_lmots,
  input  wire  [3:0]         i_run_hsslvl,
  input  wire  [5:0]         i_run_xmss,
  input  wire  [31:0]        i_run_len_msg,
  input  wire  [7:0]         i_run_len_ctx,
  input  wire  [2:0]         i_run_hash,
  input  wire  [16:0]        i_run_off_msg,
  input  wire  [16:0]        i_run_off_sig,
  input  wire  [16:0]        i_run_off_pk,

  // Result
  output logic               o_busy,
  output logic               o_done,
  output logic               o_err,
  output logic [11:0]        o_err_flags,
  output logic               o_sigok,
  output logic               o_cleared,

  // Buffer read port (64-bit words)
  output logic               o_rd_en,
  output logic [PARA_WA-1:0] o_rd_addr,
  input  wire  [63:0]        i_rd_data,
  input  wire                i_rd_valid,

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

  // Instruction codes (the order of OPS in htp_isa.py)

  // Kinds of the byte mover

  // Unsupported operation flag (bit number of dsig_err)

  // States
  typedef enum logic [3:0] {
    ENUM_ST_IDLE  = 4'd0,
    ENUM_ST_ENTRY = 4'd1,
    ENUM_ST_EXEC  = 4'd2,
    ENUM_ST_MOVE  = 4'd3,
    ENUM_ST_HWAIT = 4'd4,
    ENUM_ST_FIN   = 4'd5
  } hbs_state_type_def;

  // Internal signal declarations
  hbs_state_type_def reg_fsm_hbs_current_state;
  hbs_state_type_def w_fsm_hbs_nxt_state;

  // Registers of the processor
  logic [63:0]   reg_rf [32];
  logic [7:0]    reg_f;
  logic [11:0]   reg_pc;
  logic [11:0]   reg_stack [4];
  logic [2:0]    reg_sp;
  logic [63:0]   reg_ins;

  // Snapshot
  logic [3:0]    reg_alg;
  logic [1:0]    reg_form;
  logic [2:0]    reg_hash;
  logic [3:0]    reg_slh;
  logic [4:0]    reg_lmstype;
  logic [3:0]    reg_lmots;
  logic [3:0]    reg_hsslvl;
  logic [5:0]    reg_xmss;
  logic [31:0]   reg_len_msg;
  logic [7:0]    reg_len_ctx;
  logic [16:0]   reg_off_msg;
  logic [16:0]   reg_off_sig;
  logic [16:0]   reg_off_pk;

  // Result
  logic          reg_err;
  logic [11:0]   reg_err_flags;
  logic          reg_sigok;
  logic          reg_cleared;

  // Hash head, tails and job
  logic [2047:0] reg_head;
  logic [8:0]    reg_head_len;
  logic [127:0]  reg_mid;
  logic [8:0]    reg_mid_len;
  logic [23:0]   reg_t1_addr;
  logic [23:0]   reg_t1_len;
  logic [23:0]   reg_t2_addr;
  logic [23:0]   reg_t2_len;
  logic          reg_tsrc;
  logic [3:0]    reg_hmode;
  logic [15:0]   reg_hout;
  logic          reg_go;

  // Byte mover
  logic [3:0]    reg_mv_kind;
  logic [23:0]   reg_mv_k;
  logic [23:0]   reg_mv_n;
  logic [23:0]   reg_mv_a;
  logic [23:0]   reg_mv_b;
  logic [23:0]   reg_mv_d;
  logic [1:0]    reg_mv_area;
  logic [1:0]    reg_mv_ph;
  logic [7:0]    reg_mv_byte_a;
  logic [7:0]    reg_mv_byte_b;
  logic          reg_mv_eq;
  logic [4:0]    reg_mv_rd;

  // Local RAM
  logic [63:0]   reg_ram [2**LPARA_RAM_W-1:0];
  logic [63:0]   reg_ram_q;
  logic          reg_ram_vq;

  // Instruction decode
  logic [63:0]   w_ins;
  logic [5:0]    w_op;
  logic [4:0]    w_rd;
  logic [4:0]    w_ra;
  logic [4:0]    w_rb;
  logic [42:0]   w_imm;
  logic [63:0]   w_ra_v;
  logic [63:0]   w_rb_v;
  logic [63:0]   w_rd_v;
  logic [63:0]   w_len_v;
  logic [5:0]    w_ri_op;
  logic [4:0]    w_ri_rd;
  logic [4:0]    w_ri_ra;
  logic [4:0]    w_ri_rb;
  logic [42:0]   w_ri_imm;

  // ROM
  logic [63:0]   w_tab_val;
  logic [11:0]   w_entry;
  logic [1:0]    w_which;

  // Mover and RAM access
  logic [23:0]   w_mv_src_abs;
  logic [23:0]   w_mv_abs;
  logic [23:0]   w_mv_ram_addr;
  logic [7:0]    w_mv_lane_byte;
  logic [7:0]    w_mv_ram_byte;
  logic [7:0]    w_mv_ram_byte_b;
  logic [2:0]    w_mv_b_lane;
  logic [7:0]    w_mv_buf_byte;
  logic [7:0]    w_mv_dig_byte;
  logic [7:0]    w_mv_wbyte;
  logic          w_mv_is_buf;
  logic          w_mv_is_dig;
  logic          w_mv_need_b;
  logic          w_mv_last;
  logic [16:0]   w_area_base;
  logic [2:0]    w_ram_lane;
  logic [LPARA_RAM_W-1:0] w_ram_raddr;
  logic          w_ram_we;
  logic [LPARA_RAM_W-1:0] w_ram_waddr;
  logic [63:0]   w_ram_wdata;
  logic [7:0]    w_ram_wstrb;
  logic [23:0]   w_wr_byte_addr;
  logic [7:0]    w_wr_byte;
  logic          w_wr_byte_en;

  // Hash feeder
  logic [8*64-1:0] w_digest;
  logic          w_hf_done;
  logic          w_tr_en;
  logic [20:0]   w_tr_addr_full;
  logic [63:0]   w_tr_data;
  logic          w_tr_valid;
  logic [16:0]   w_t_area_base;

  // Function: the low n bytes of x, big endian, with byte 0 in bits [7:0] of the result
  function automatic logic [63:0] f_be(input logic [63:0] x, input logic [7:0] n);
    logic [63:0] r;
    logic [6:0]  sh;
    begin
      r = 64'd0;
      for (int i = 0; i < 8; i++)
        r[8*i +: 8] = x[8*(7-i) +: 8];
      sh = {1'b0, (8'd8 - n[7:0])} << 3;
      f_be = (n >= 8'd8) ? r : (r >> sh);
    end
  endfunction

  // Entry of the program of the algorithm
  always_comb begin : p_com_which
    w_which = 2'd2;
    case (reg_alg)
      4'd12:   w_which = 2'd0;
      4'd13:   w_which = 2'd1;
      default: w_which = 2'd2;
    endcase
  end

  m_vlsit_dsig_hbs_rom u_rom (
    .i_pc     (reg_pc),
    .o_ins    (w_ins),
    .i_tab    (w_imm[9:8]),
    .i_key    (w_ra_v[6:0]),
    .i_field  (w_imm[7:0]),
    .o_val    (w_tab_val),
    .i_which  (w_which),
    .o_entry  (w_entry)
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

  assign w_ra_v  = reg_rf[w_ra];
  assign w_rb_v  = reg_rf[w_rb];
  assign w_rd_v  = reg_rf[w_rd];
  assign w_len_v = reg_rf[w_imm[4:0]];

  // ---------------------------------------------------------------------------------------------
  // Hash feeder with the head, the tails and the digest
  // ---------------------------------------------------------------------------------------------
  assign w_t_area_base = 17'd0;

  m_vlsit_dsig_hfeed #(.PARA_HEAD_BYTES(256), .PARA_DIG_BYTES(64), .PARA_TA_W(24), .PARA_MID_BYTES(16)) u_hfeed (
    .i_clk_core     (i_clk_core),
    .i_rst_n_core   (i_rst_n_core),
    .i_clr          (i_clr),
    .i_go           (reg_go & (reg_fsm_hbs_current_state == ENUM_ST_HWAIT)),
    .i_mode         (reg_hmode),
    .i_outlen       (reg_hout),
    .i_head         (reg_head),
    .i_head_len     (reg_head_len),
    .i_tail_addr    (reg_t1_addr),
    .i_tail_len     (reg_t1_len),
    .i_tail2_addr   (reg_t2_addr),
    .i_tail2_len    (reg_t2_len),
    .i_mid          (reg_mid),
    .i_mid_len      (reg_mid_len),
    .o_digest       (w_digest),
    .o_done         (w_hf_done),
    .o_busy         (),
    .o_tr_en        (w_tr_en),
    .o_tr_addr      (w_tr_addr_full),
    .i_tr_data      (w_tr_data),
    .i_tr_valid     (w_tr_valid),
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

  // The tails come from the buffer (reg_tsrc = 1) or from the local RAM.
  assign w_tr_data  = reg_tsrc ? i_rd_data : reg_ram_q;
  assign w_tr_valid = reg_tsrc ? i_rd_valid : reg_ram_vq;

  // ---------------------------------------------------------------------------------------------
  // Byte mover: addresses and the byte of each step
  // ---------------------------------------------------------------------------------------------
  assign w_area_base = (reg_mv_area == 2'd0) ? reg_off_msg : ((reg_mv_area == 2'd1) ? reg_off_sig : reg_off_pk);
  assign w_mv_is_buf = (reg_mv_kind == LPARA_MV_BLB) | (reg_mv_kind == LPARA_MV_CPBR) | (reg_mv_kind == LPARA_MV_HBUF);
  assign w_mv_is_dig = (reg_mv_kind == LPARA_MV_DST);
  assign w_mv_need_b = (reg_mv_kind == LPARA_MV_CMPRR) | (reg_mv_kind == LPARA_MV_XORR);
  assign w_mv_src_abs  = reg_mv_a + reg_mv_k;
  assign w_mv_abs      = {7'd0, w_area_base} + w_mv_src_abs;
  assign w_mv_ram_addr = (reg_mv_ph == 2'd1) ? (reg_mv_b + reg_mv_k) : w_mv_src_abs;
  assign w_mv_last     = (reg_mv_k + 24'd1 == reg_mv_n);

  // RAM read address: the hash tail (word address) or the mover
  assign w_ram_raddr = w_tr_en ? w_tr_addr_full[LPARA_RAM_W-1:0] : w_mv_ram_addr[LPARA_RAM_W+2:3];
  assign w_ram_lane  = w_mv_src_abs[2:0];
  assign w_mv_ram_byte = reg_ram_q[8 * w_ram_lane +: 8];
  assign w_mv_b_lane = (reg_mv_b + reg_mv_k);
  assign w_mv_ram_byte_b = reg_ram_q[8 * w_mv_b_lane +: 8];
  assign w_mv_buf_byte = i_rd_data[8 * w_mv_abs[2:0] +: 8];
  assign w_mv_dig_byte = w_digest[8 * reg_mv_k[5:0] +: 8];
  assign w_mv_lane_byte = w_mv_is_buf ? w_mv_buf_byte : (w_mv_is_dig ? w_mv_dig_byte : w_mv_ram_byte);

  // Byte written to the RAM by the mover (copy, digest store) or by RSB
  always_comb begin : p_com_wbyte
    w_mv_wbyte = reg_mv_byte_a;
    if (reg_mv_kind == LPARA_MV_XORR)
      w_mv_wbyte = reg_mv_byte_a ^ reg_mv_byte_b;
  end

  always_comb begin : p_com_wr
    w_wr_byte_en   = 1'b0;
    w_wr_byte_addr = 24'd0;
    w_wr_byte      = 8'd0;
    if ((reg_fsm_hbs_current_state == ENUM_ST_MOVE) & (reg_mv_ph == 2'd3)) begin
      case (reg_mv_kind)
        LPARA_MV_CPBR,
        LPARA_MV_CPRR,
        LPARA_MV_XORR,
        LPARA_MV_DST: begin
          w_wr_byte_en   = 1'b1;
          w_wr_byte_addr = reg_mv_d + reg_mv_k;
          w_wr_byte      = w_mv_wbyte;
        end
        default: begin
          w_wr_byte_en = 1'b0;
        end
      endcase
    end
    if ((reg_fsm_hbs_current_state == ENUM_ST_EXEC) & (w_op == LPARA_OP_RSB)) begin
      w_wr_byte_en   = 1'b1;
      w_wr_byte_addr = w_ra_v[23:0] + w_imm[23:0];
      w_wr_byte      = w_rb_v[7:0];
    end
  end

  assign w_ram_we    = w_wr_byte_en;
  assign w_ram_waddr = w_wr_byte_addr[LPARA_RAM_W+2:3];
  assign w_ram_wdata = {8{w_wr_byte}};
  assign w_ram_wstrb = 8'd1 << w_wr_byte_addr[2:0];

  // RAM: one write port with byte lanes, one synchronous read port (data one cycle later)
  always_ff @(posedge i_clk_core) begin : p_ff_ram
    reg_ram_q <= reg_ram[w_ram_raddr];
    if (w_ram_we) begin
      for (int lane = 0; lane < 8; lane++) begin
        if (w_ram_wstrb[lane])
          reg_ram[w_ram_waddr][8*lane +: 8] <= w_ram_wdata[8*lane +: 8];
      end
    end
  end

  // Buffer read port: the mover (buffer kinds) or the hash tail
  assign o_rd_en   = (reg_fsm_hbs_current_state == ENUM_ST_MOVE & w_mv_is_buf & (reg_mv_ph == 2'd0)) | (w_tr_en & reg_tsrc);
  assign o_rd_addr = (w_tr_en & reg_tsrc) ? w_tr_addr_full[PARA_WA-1:0] : w_mv_abs[PARA_WA+2:3];

  // ---------------------------------------------------------------------------------------------
  // FSM
  // ---------------------------------------------------------------------------------------------
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_hbs
    if (!i_rst_n_core)
      reg_fsm_hbs_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_hbs_current_state <= w_fsm_hbs_nxt_state;
  end

  always_comb begin : p_com_fsm_nxt
    w_fsm_hbs_nxt_state = reg_fsm_hbs_current_state;
    case (reg_fsm_hbs_current_state)
      ENUM_ST_IDLE: begin
        if (i_start)
          w_fsm_hbs_nxt_state = ENUM_ST_ENTRY;
      end
      ENUM_ST_ENTRY: begin
        if (reg_err)
          w_fsm_hbs_nxt_state = ENUM_ST_FIN;
        else
          w_fsm_hbs_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_EXEC: begin
        case (w_op)
          LPARA_OP_RLB,
          LPARA_OP_BLB,
          LPARA_OP_CPBR,
          LPARA_OP_CPRR,
          LPARA_OP_CMPRR,
          LPARA_OP_XORR,
          LPARA_OP_HRAM,
          LPARA_OP_HBUF,
          LPARA_OP_DST: begin
            w_fsm_hbs_nxt_state = ENUM_ST_MOVE;
          end
          LPARA_OP_HGO: w_fsm_hbs_nxt_state = ENUM_ST_HWAIT;
          LPARA_OP_END: w_fsm_hbs_nxt_state = ENUM_ST_FIN;
          LPARA_OP_ERR: w_fsm_hbs_nxt_state = ENUM_ST_FIN;
          default:      w_fsm_hbs_nxt_state = ENUM_ST_EXEC;
        endcase
      end
      ENUM_ST_MOVE: begin
        if ((reg_mv_ph == 2'd3) & w_mv_last)
          w_fsm_hbs_nxt_state = ENUM_ST_EXEC;
        else if (reg_mv_n == 24'd0)
          w_fsm_hbs_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_HWAIT: begin
        if (w_hf_done)
          w_fsm_hbs_nxt_state = ENUM_ST_EXEC;
      end
      ENUM_ST_FIN: w_fsm_hbs_nxt_state = ENUM_ST_IDLE;
      default:     w_fsm_hbs_nxt_state = ENUM_ST_IDLE;
    endcase
    if (i_clr)
      w_fsm_hbs_nxt_state = ENUM_ST_IDLE;
  end

  assign o_busy      = (reg_fsm_hbs_current_state != ENUM_ST_IDLE);
  assign o_done      = (reg_fsm_hbs_current_state == ENUM_ST_FIN) & ~reg_err;
  assign o_err       = (reg_fsm_hbs_current_state == ENUM_ST_FIN) & reg_err;
  assign o_err_flags = reg_err_flags;
  assign o_sigok     = reg_sigok;
  assign o_cleared   = reg_cleared;

  // ---------------------------------------------------------------------------------------------
  // Data registers
  // ---------------------------------------------------------------------------------------------
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_dp
    if (!i_rst_n_core) begin
      for (int i = 0; i < 32; i++)
        reg_rf[i] <= 64'd0;
      for (int i = 0; i < 4; i++)
        reg_stack[i] <= 12'd0;
      reg_f         <= 8'd0;
      reg_pc        <= 12'd0;
      reg_sp        <= 3'd0;
      reg_ins       <= 64'd0;
      reg_alg       <= 4'd0;
      reg_form      <= 2'd0;
      reg_hash      <= 3'd0;
      reg_slh       <= 4'd0;
      reg_lmstype   <= 5'd0;
      reg_lmots     <= 4'd0;
      reg_hsslvl    <= 4'd0;
      reg_xmss      <= 6'd0;
      reg_len_msg   <= 32'd0;
      reg_len_ctx   <= 8'd0;
      reg_off_msg   <= 17'd0;
      reg_off_sig   <= 17'd0;
      reg_off_pk    <= 17'd0;
      reg_err       <= 1'b0;
      reg_err_flags <= 12'd0;
      reg_sigok     <= 1'b0;
      reg_cleared   <= 1'b1;
      reg_head      <= 2048'd0;
      reg_head_len  <= 9'd0;
      reg_mid       <= 128'd0;
      reg_mid_len   <= 9'd0;
      reg_t1_addr   <= 24'd0;
      reg_t1_len    <= 24'd0;
      reg_t2_addr   <= 24'd0;
      reg_t2_len    <= 24'd0;
      reg_tsrc      <= 1'b0;
      reg_hmode     <= 4'd0;
      reg_hout      <= 16'd0;
      reg_go        <= 1'b0;
      reg_mv_kind   <= 4'd0;
      reg_mv_k      <= 24'd0;
      reg_mv_n      <= 24'd0;
      reg_mv_a      <= 24'd0;
      reg_mv_b      <= 24'd0;
      reg_mv_d      <= 24'd0;
      reg_mv_area   <= 2'd0;
      reg_mv_ph     <= 2'd0;
      reg_mv_byte_a <= 8'd0;
      reg_mv_byte_b <= 8'd0;
      reg_mv_eq     <= 1'b1;
      reg_mv_rd     <= 5'd0;
      reg_ram_vq    <= 1'b0;
    end
    else if (i_clr) begin
      for (int i = 0; i < 32; i++)
        reg_rf[i] <= 64'd0;
      reg_f         <= 8'd0;
      reg_ins       <= 64'd0;
      reg_err       <= 1'b0;
      reg_err_flags <= 12'd0;
      reg_sigok     <= 1'b0;
      reg_cleared   <= 1'b1;
      reg_head      <= 2048'd0;
      reg_head_len  <= 9'd0;
      reg_mid       <= 128'd0;
      reg_mid_len   <= 9'd0;
      reg_go        <= 1'b0;
      reg_mv_byte_a <= 8'd0;
      reg_mv_byte_b <= 8'd0;
      reg_ram_vq    <= 1'b0;
    end
    else begin
      reg_ram_vq <= w_tr_en & ~reg_tsrc;
      case (reg_fsm_hbs_current_state)
        ENUM_ST_IDLE: begin
          if (i_start) begin
            reg_alg       <= i_run_alg;
            reg_form      <= i_run_form;
            reg_hash      <= i_run_hash;
            reg_slh       <= i_run_slh;
            reg_lmstype   <= i_run_lmstype;
            reg_lmots     <= i_run_lmots;
            reg_hsslvl    <= i_run_hsslvl;
            reg_xmss      <= i_run_xmss;
            reg_len_msg   <= i_run_len_msg;
            reg_len_ctx   <= i_run_len_ctx;
            reg_off_msg   <= i_run_off_msg;
            reg_off_sig   <= i_run_off_sig;
            reg_off_pk    <= i_run_off_pk;
            reg_f         <= 8'd0;
            reg_sp        <= 3'd0;
            reg_sigok     <= 1'b0;
            reg_cleared   <= 1'b0;
            reg_head_len  <= 9'd0;
            reg_mid_len   <= 9'd0;
            reg_t1_len    <= 24'd0;
            reg_t2_len    <= 24'd0;
            // Unsupported algorithm: the group of the algorithm is not built.
            if (((i_run_alg == 4'd12) & (PARA_EN_SLHDSA == 32'd0)) | ((i_run_alg == 4'd13) & (PARA_EN_LMS == 32'd0)) |
                ((i_run_alg == 4'd14) & (PARA_EN_XMSS == 32'd0)) | (i_run_alg < 4'd12) | (i_run_alg > 4'd14)) begin
              reg_err       <= 1'b1;
              reg_err_flags <= LPARA_ERRF_OPUNS;
            end else begin
              reg_err       <= 1'b0;
              reg_err_flags <= 12'd0;
            end
          end
        end
        ENUM_ST_ENTRY: begin
          reg_pc <= w_entry;
        end
        ENUM_ST_EXEC: begin
          reg_ins <= w_ins;
          reg_pc  <= reg_pc + 12'd1;
          case (w_op)
            LPARA_OP_LDI:  reg_rf[w_rd] <= {21'd0, w_imm};
            LPARA_OP_MOV:  reg_rf[w_rd] <= w_ra_v;
            LPARA_OP_ADD:  reg_rf[w_rd] <= w_ra_v + w_rb_v;
            LPARA_OP_SUB:  reg_rf[w_rd] <= w_ra_v - w_rb_v;
            LPARA_OP_AND:  reg_rf[w_rd] <= w_ra_v & w_rb_v;
            LPARA_OP_OR:   reg_rf[w_rd] <= w_ra_v | w_rb_v;
            LPARA_OP_XOR:  reg_rf[w_rd] <= w_ra_v ^ w_rb_v;
            LPARA_OP_MUL:  reg_rf[w_rd] <= {32'd0, w_ra_v[31:0]} * {32'd0, w_rb_v[31:0]};
            LPARA_OP_ADDI: reg_rf[w_rd] <= w_ra_v + {21'd0, w_imm};
            LPARA_OP_SUBI: reg_rf[w_rd] <= w_ra_v - {21'd0, w_imm};
            LPARA_OP_ANDI: reg_rf[w_rd] <= w_ra_v & {21'd0, w_imm};
            LPARA_OP_SHLI: reg_rf[w_rd] <= w_ra_v << w_imm[5:0];
            LPARA_OP_SHRI: reg_rf[w_rd] <= w_ra_v >> w_imm[5:0];
            LPARA_OP_SHL:  reg_rf[w_rd] <= w_ra_v << w_rb_v[5:0];
            LPARA_OP_SHR:  reg_rf[w_rd] <= w_ra_v >> w_rb_v[5:0];
            LPARA_OP_LDT:  reg_rf[w_rd] <= w_tab_val;
            LPARA_OP_LDS: begin
              case (w_imm[3:0])
                4'd0:    reg_rf[w_rd] <= {32'd0, reg_len_msg};
                4'd1:    reg_rf[w_rd] <= {56'd0, reg_len_ctx};
                4'd2:    reg_rf[w_rd] <= {62'd0, reg_form};
                4'd3:    reg_rf[w_rd] <= {60'd0, reg_slh};
                4'd4:    reg_rf[w_rd] <= {59'd0, reg_lmstype};
                4'd5:    reg_rf[w_rd] <= {60'd0, reg_lmots};
                4'd6:    reg_rf[w_rd] <= {60'd0, reg_hsslvl};
                4'd7:    reg_rf[w_rd] <= {58'd0, reg_xmss};
                4'd9:    reg_rf[w_rd] <= {61'd0, reg_hash};
                default: reg_rf[w_rd] <= {60'd0, reg_alg};
              endcase
            end
            LPARA_OP_EQ:   reg_f[w_rd[2:0]] <= (w_ra_v == w_rb_v);
            LPARA_OP_LTU:  reg_f[w_rd[2:0]] <= (w_ra_v < w_rb_v);
            LPARA_OP_EQI:  reg_f[w_rd[2:0]] <= (w_ra_v == {21'd0, w_imm});
            LPARA_OP_ISZ:  reg_f[w_rd[2:0]] <= (w_ra_v == 64'd0);
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
              reg_stack[reg_sp[1:0]] <= reg_pc + 12'd1;
              reg_sp <= reg_sp + 3'd1;
              reg_pc <= w_imm[11:0];
            end
            LPARA_OP_RET: begin
              reg_sp <= reg_sp - 3'd1;
              reg_pc <= reg_stack[reg_sp[1:0] - 2'd1];
            end
            LPARA_OP_END:  reg_sigok <= reg_f[7];
            LPARA_OP_ERR: begin
              reg_err       <= 1'b1;
              reg_err_flags <= 12'd1 << w_imm[3:0];
              reg_sigok     <= 1'b0;
            end
            LPARA_OP_RLB: begin
              reg_mv_kind <= LPARA_MV_RLB;
              reg_mv_a    <= w_ra_v[23:0] + w_imm[23:0];
              reg_mv_n    <= 24'd1;
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
              reg_mv_rd   <= w_rd;
            end
            LPARA_OP_BLB: begin
              reg_mv_kind <= LPARA_MV_BLB;
              reg_mv_a    <= w_ra_v[23:0] + {2'd0, w_imm[23:2]};
              reg_mv_area <= w_imm[1:0];
              reg_mv_n    <= 24'd1;
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
              reg_mv_rd   <= w_rd;
            end
            LPARA_OP_CPBR: begin
              reg_mv_kind <= LPARA_MV_CPBR;
              reg_mv_d    <= w_rd_v[23:0];
              reg_mv_a    <= w_ra_v[23:0];
              reg_mv_n    <= w_rb_v[23:0];
              reg_mv_area <= w_imm[1:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
            end
            LPARA_OP_CPRR: begin
              reg_mv_kind <= LPARA_MV_CPRR;
              reg_mv_d    <= w_rd_v[23:0];
              reg_mv_a    <= w_ra_v[23:0];
              reg_mv_n    <= w_rb_v[23:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
            end
            LPARA_OP_CMPRR: begin
              reg_mv_kind <= LPARA_MV_CMPRR;
              reg_mv_a    <= w_ra_v[23:0];
              reg_mv_b    <= w_rb_v[23:0];
              reg_mv_n    <= w_len_v[23:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
              reg_mv_eq   <= 1'b1;
              reg_mv_rd   <= w_rd;
              if (w_len_v[23:0] == 24'd0)
                reg_f[w_rd[2:0]] <= 1'b1;
            end
            LPARA_OP_XORR: begin
              reg_mv_kind <= LPARA_MV_XORR;
              reg_mv_d    <= w_rd_v[23:0];
              reg_mv_a    <= w_ra_v[23:0];
              reg_mv_b    <= w_rb_v[23:0];
              reg_mv_n    <= w_len_v[23:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
            end
            LPARA_OP_HRAM: begin
              reg_mv_kind <= LPARA_MV_HRAM;
              reg_mv_a    <= w_ra_v[23:0];
              reg_mv_n    <= w_rb_v[23:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
            end
            LPARA_OP_HBUF: begin
              reg_mv_kind <= LPARA_MV_HBUF;
              reg_mv_a    <= w_ra_v[23:0];
              reg_mv_n    <= w_rb_v[23:0];
              reg_mv_area <= w_imm[1:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
            end
            LPARA_OP_DST: begin
              reg_mv_kind <= LPARA_MV_DST;
              reg_mv_d    <= w_ra_v[23:0];
              reg_mv_a    <= 24'd0;
              reg_mv_n    <= w_rb_v[23:0];
              reg_mv_k    <= 24'd0;
              reg_mv_ph   <= 2'd0;
            end
            LPARA_OP_HCLR: begin
              reg_head     <= 2048'd0;
              reg_head_len <= 9'd0;
              reg_mid      <= 128'd0;
              reg_mid_len  <= 9'd0;
              reg_t1_len   <= 24'd0;
              reg_t2_len   <= 24'd0;
            end
            LPARA_OP_HREG: begin
              reg_head     <= reg_head | (2048'(f_be(w_ra_v, w_imm[7:0])) << {reg_head_len, 3'b000});
              reg_head_len <= reg_head_len + {1'b0, w_imm[7:0]};
            end
            LPARA_OP_HMID: begin
              reg_mid     <= reg_mid | (128'(f_be(w_ra_v, w_imm[7:0])) << {reg_mid_len, 3'b000});
              reg_mid_len <= reg_mid_len + {1'b0, w_imm[7:0]};
            end
            LPARA_OP_HZERO: reg_head_len <= reg_head_len + {1'b0, w_ra_v[7:0]};
            LPARA_OP_HZERI: reg_head_len <= reg_head_len + {1'b0, w_imm[7:0]};
            LPARA_OP_HT1: begin
              reg_tsrc   <= w_imm[0];
              reg_t1_len <= w_rb_v[23:0];
              if (w_imm[0])
                reg_t1_addr <= w_ra_v[23:0] + {7'd0, (w_imm[2:1] == 2'd0) ? reg_off_msg :
                                                     ((w_imm[2:1] == 2'd1) ? reg_off_sig : reg_off_pk)};
              else
                reg_t1_addr <= w_ra_v[23:0];
            end
            LPARA_OP_HT2: begin
              reg_t2_len <= w_rb_v[23:0];
              if (reg_t1_len == 24'd0)
                reg_tsrc <= w_imm[0];
              if (w_imm[0])
                reg_t2_addr <= w_ra_v[23:0] + {7'd0, (w_imm[2:1] == 2'd0) ? reg_off_msg :
                                                     ((w_imm[2:1] == 2'd1) ? reg_off_sig : reg_off_pk)};
              else
                reg_t2_addr <= w_ra_v[23:0];
            end
            LPARA_OP_HGO: begin
              reg_hmode <= w_imm[3:0];
              reg_hout  <= w_ra_v[15:0];
              reg_go    <= 1'b1;
            end
            default: begin
              reg_pc <= reg_pc + 12'd1;
            end
          endcase
        end
        ENUM_ST_MOVE: begin
          case (reg_mv_ph)
            2'd0: begin
              // The source address is presented (RAM read address, buffer request).
              reg_mv_ph <= 2'd1;
            end
            2'd1: begin
              // The first byte arrives (the RAM has answered, the buffer must have valid data).
              if (w_mv_is_buf & ~i_rd_valid) begin
                reg_mv_ph <= 2'd1;
              end else begin
                reg_mv_byte_a <= w_mv_lane_byte;
                reg_mv_ph     <= w_mv_need_b ? 2'd2 : 2'd3;
              end
            end
            2'd2: begin
              reg_mv_byte_b <= w_mv_ram_byte_b;
              reg_mv_ph     <= 2'd3;
            end
            default: begin
              // The byte is used: a write, a compare, a head append or a register load.
              case (reg_mv_kind)
                LPARA_MV_CMPRR: begin
                  reg_mv_eq <= reg_mv_eq & (reg_mv_byte_a == reg_mv_byte_b);
                  if (w_mv_last)
                    reg_f[reg_mv_rd[2:0]] <= reg_mv_eq & (reg_mv_byte_a == reg_mv_byte_b);
                end
                LPARA_MV_HRAM,
                LPARA_MV_HBUF: begin
                  reg_head     <= reg_head | (2048'(reg_mv_byte_a) << {reg_head_len, 3'b000});
                  reg_head_len <= reg_head_len + 9'd1;
                end
                LPARA_MV_RLB,
                LPARA_MV_BLB: begin
                  reg_rf[reg_mv_rd] <= {56'd0, reg_mv_byte_a};
                end
                default: begin
                  reg_mv_eq <= reg_mv_eq;
                end
              endcase
              reg_mv_k  <= reg_mv_k + 24'd1;
              reg_mv_ph <= 2'd0;
            end
          endcase
        end
        ENUM_ST_HWAIT: begin
          reg_go <= 1'b0;
          if (w_hf_done) begin
            reg_t1_len  <= 24'd0;
            reg_t2_len  <= 24'd0;
            reg_mid     <= 128'd0;
            reg_mid_len <= 9'd0;
          end
        end
        default: begin
          reg_go <= 1'b0;
        end
      endcase
    end
  end

endmodule
