/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Input stream adapter. After a run pulse it reads beats from the input buffer
 *                (show-ahead read port, one beat per cycle) in the order associated data, message
 *                data and, for a decryption, the 16-byte tag; each part starts on a new beat and a
 *                part of n bytes takes ceil(n / W) beats, W = PARA_AXI_DW / 8 (section 6.3). The
 *                beats are assembled into chunks of at most 64 bytes (64 / W beats) in an assembly
 *                register and moved to a chunk register, so the next chunk is fetched while the
 *                previous one is used. A chunk carries its valid byte count (1 to 64), its kind and
 *                a flag for the last chunk of its part; the bytes beyond the count are zero.
 *                A part of length 0 gives no chunk.
 *                With PARA_PIPE_IO = 1 the last-beat flag of a part (remaining bytes not above
 *                one beat) is computed in the cycle before it is used and kept in a register; the
 *                behavior and the cycle count do not change (DEC-036).
 * Decisions    : DEC-022, DEC-030, DEC-036, DEC-037
 */
`timescale 1ns/1ps

module m_chacha_ingest #(
  // Parameter Description: data width of the input buffer beat; a beat is PARA_AXI_DW / 8 bytes.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  // Parameter Description: 1 keeps the last-beat flag of a part in a register (look-ahead).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_PIPE_IO = 32'd0,
  localparam logic [31:0] LPARA_BYTES  = PARA_AXI_DW / 32'd8,
  localparam logic [31:0] LPARA_BPC    = 32'd512 / PARA_AXI_DW,
  localparam logic [31:0] LPARA_BEAT_W = $clog2(LPARA_BPC)
) (
  // Clock, reset and clear
  input  wire                    i_clk_core,
  input  wire                    i_rst_n_core,
  input  wire                    i_clr,

  // Message description: run pulse, lengths in bytes and direction (1 = decryption)
  input  wire                    i_run,
  input  wire  [15:0]            i_aad_len,
  input  wire  [15:0]            i_msg_len,
  input  wire                    i_dir,

  // Input buffer read port (show-ahead)
  output logic                   o_in_rd_en,
  input  wire  [PARA_AXI_DW-1:0] i_in_data,
  input  wire                    i_in_empty,

  // Chunk output
  output logic                   o_chk_vld,
  output logic [511:0]           o_chk_data,
  output logic [6:0]             o_chk_bytes,
  output logic [1:0]             o_chk_kind,
  output logic                   o_chk_last,
  input  wire                    i_chk_take,

  // Status: no part left and no chunk held
  output logic                   o_idle
);

  // Part kinds: associated data, message data and the received tag of a decryption.
  typedef enum logic [1:0] {
    ENUM_KIND_AAD = 2'd0,
    ENUM_KIND_MSG = 2'd1,
    ENUM_KIND_TAG = 2'd2
  } kind_type_def;

  // Internal signal declarations
  logic                    reg_active;
  kind_type_def            reg_kind;
  logic [16:0]             reg_rem;
  logic                    reg_pend;
  logic [15:0]             reg_len_msg;
  logic                    reg_dir;
  logic [LPARA_BEAT_W-1:0] reg_beat;
  logic [6:0]              reg_bytes;
  logic [511:0]            reg_asm;
  logic                    reg_asm_done;
  kind_type_def            reg_asm_kind;
  logic                    reg_asm_last;
  logic [6:0]              reg_asm_bytes;
  logic [511:0]            reg_chk;
  logic                    reg_chk_vld;
  logic [6:0]              reg_chk_bytes;
  kind_type_def            reg_chk_kind;
  logic                    reg_chk_last;
  logic                    w_pop;
  logic                    w_move;
  logic [6:0]              w_bb;
  logic [16:0]             w_rem_nxt;
  logic [6:0]              w_bytes_nxt;
  logic                    w_part_end;
  logic                    w_chunk_end;
  kind_type_def            w_nx_kind;
  logic [16:0]             w_nx_len;
  logic                    w_nx_vld;
  kind_type_def            w_run_kind;
  logic [16:0]             w_run_len;
  logic                    w_run_vld;
  logic [511:0]            w_masked;

  // Beat bookkeeping: bytes of this beat (W or the rest of the part), remaining bytes after the
  // beat, bytes of the chunk so far, and the two end conditions.
  assign w_bb = (PARA_PIPE_IO == 32'd1) ? (reg_pend ? reg_rem[6:0] : 7'(LPARA_BYTES)) :
                ((reg_rem >= 17'(LPARA_BYTES)) ? 7'(LPARA_BYTES) : reg_rem[6:0]);
  assign w_rem_nxt   = $bits(w_rem_nxt)'(reg_rem - 17'(w_bb));
  assign w_bytes_nxt = $bits(w_bytes_nxt)'(reg_bytes + w_bb);
  assign w_part_end  = (PARA_PIPE_IO == 32'd1) ? reg_pend : (w_rem_nxt == 17'd0);
  assign w_chunk_end = (reg_beat == LPARA_BEAT_W'(LPARA_BPC - 32'd1)) | w_part_end;

  // The finished assembly moves to the chunk register when that is free or being taken.
  assign w_move = reg_asm_done & (~reg_chk_vld | i_chk_take);

  // A beat is read when a part is active, the assembly register is free or is being moved in this
  // cycle, and the buffer has data; the first beat of the next chunk is read in the cycle of the
  // move, so a stream of one-beat blocks has no gap between two chunks (DEC-037).
  assign w_pop      = reg_active & (~reg_asm_done | w_move) & ~i_in_empty;
  assign o_in_rd_en = w_pop;

  // Next part after the current one: associated data, message data, tag (decryption only).
  always_comb begin : p_com_nxt
    w_nx_kind = ENUM_KIND_TAG;
    w_nx_len  = 17'd16;
    w_nx_vld  = 1'b0;
    case (reg_kind)
      ENUM_KIND_AAD: begin
        w_nx_kind = ENUM_KIND_TAG;
        w_nx_len  = 17'd16;
        w_nx_vld  = reg_dir;
        if (reg_len_msg != 16'd0) begin
          w_nx_kind = ENUM_KIND_MSG;
          w_nx_len  = {1'b0, reg_len_msg};
          w_nx_vld  = 1'b1;
        end
      end
      ENUM_KIND_MSG: begin
        w_nx_kind = ENUM_KIND_TAG;
        w_nx_len  = 17'd16;
        w_nx_vld  = reg_dir;
      end
      default: begin
        w_nx_kind = ENUM_KIND_TAG;
        w_nx_len  = 17'd16;
        w_nx_vld  = 1'b0;
      end
    endcase
  end

  // First part of a run: associated data if any, else message data, else the tag of a decryption.
  always_comb begin : p_com_run
    w_run_kind = ENUM_KIND_TAG;
    w_run_len  = 17'd16;
    w_run_vld  = 1'b0;
    casez ({(i_aad_len != 16'd0), (i_msg_len != 16'd0), i_dir})
      3'b1??:  begin
        w_run_kind = ENUM_KIND_AAD;
        w_run_len  = {1'b0, i_aad_len};
        w_run_vld  = 1'b1;
      end
      3'b01?:  begin
        w_run_kind = ENUM_KIND_MSG;
        w_run_len  = {1'b0, i_msg_len};
        w_run_vld  = 1'b1;
      end
      3'b001:  begin
        w_run_kind = ENUM_KIND_TAG;
        w_run_len  = 17'd16;
        w_run_vld  = 1'b1;
      end
      default: begin
        w_run_kind = ENUM_KIND_TAG;
        w_run_len  = 17'd16;
        w_run_vld  = 1'b0;
      end
    endcase
  end

  // Byte mask of the chunk about to move: lane i is kept while i is below the valid byte count.
  always_comb begin : p_com_mask
    w_masked = '0;
    for (int idx = 0; idx < 64; idx++) begin
      if (7'(idx) < reg_asm_bytes)
        w_masked[8*idx +: 8] = reg_asm[8*idx +: 8];
    end
  end

  // Part control: the active flag, the current part and its remaining bytes. A run loads the first
  // part; the last beat of a part loads the next one or ends the stream; every other beat only
  // reduces the remaining bytes.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_part
    if (!i_rst_n_core) begin
      reg_active  <= 1'b0;
      reg_kind    <= ENUM_KIND_AAD;
      reg_rem     <= 17'd0;
      reg_pend    <= 1'b1;
      reg_len_msg <= 16'd0;
      reg_dir     <= 1'b0;
    end else if (i_clr) begin
      reg_active <= 1'b0;
    end else begin
      casez ({i_run, w_pop & w_part_end, w_pop})
        3'b1??: begin
          reg_active  <= w_run_vld;
          reg_kind    <= w_run_kind;
          reg_rem     <= w_run_len;
          reg_pend    <= (w_run_len < 17'(LPARA_BYTES + 32'd1));
          reg_len_msg <= i_msg_len;
          reg_dir     <= i_dir;
        end
        3'b011: begin
          reg_active <= w_nx_vld;
          reg_kind   <= w_nx_kind;
          reg_rem    <= w_nx_len;
          reg_pend   <= (w_nx_len < 17'(LPARA_BYTES + 32'd1));
        end
        3'b001: begin
          reg_rem  <= w_rem_nxt;
          reg_pend <= (reg_rem < 17'(2 * LPARA_BYTES + 32'd1));
        end
        default: begin
          // No beat and no run: the part registers hold.
        end
      endcase
    end
  end

  // Assembly control: the beat index, the byte count of the chunk, the done flag and the
  // metadata of the finished chunk.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_asm
    if (!i_rst_n_core) begin
      reg_beat      <= '0;
      reg_bytes     <= 7'd0;
      reg_asm_done  <= 1'b0;
      reg_asm_kind  <= ENUM_KIND_AAD;
      reg_asm_last  <= 1'b0;
      reg_asm_bytes <= 7'd0;
    end else if (i_clr | i_run) begin
      reg_beat     <= '0;
      reg_bytes    <= 7'd0;
      reg_asm_done <= 1'b0;
    end else begin
      if (w_move)
        reg_asm_done <= 1'b0;
      if (w_pop) begin
        reg_bytes <= w_bytes_nxt;
        reg_beat  <= $bits(reg_beat)'(reg_beat + 1'b1);
        if (w_chunk_end) begin
          reg_asm_done  <= 1'b1;
          reg_asm_kind  <= reg_kind;
          reg_asm_last  <= w_part_end;
          reg_asm_bytes <= w_bytes_nxt;
          reg_beat      <= '0;
          reg_bytes     <= 7'd0;
        end
      end
    end
  end

  // Chunk register control: valid flag and metadata of the presented chunk.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_chk
    if (!i_rst_n_core) begin
      reg_chk_vld   <= 1'b0;
      reg_chk_bytes <= 7'd0;
      reg_chk_kind  <= ENUM_KIND_AAD;
      reg_chk_last  <= 1'b0;
    end else if (i_clr | i_run) begin
      reg_chk_vld <= 1'b0;
    end else begin
      if (w_move) begin
        reg_chk_vld   <= 1'b1;
        reg_chk_bytes <= reg_asm_bytes;
        reg_chk_kind  <= reg_asm_kind;
        reg_chk_last  <= reg_asm_last;
      end else if (i_chk_take)
        reg_chk_vld <= 1'b0;
    end
  end

  // Payload registers: no reset; the done flag and the valid flag qualify them, and i_clr empties
  // them at the end of a message. The assembly register takes one beat at its beat position.
  always_ff @(posedge i_clk_core) begin : p_ff_data
    if (i_clr) begin
      reg_asm <= '0;
      reg_chk <= '0;
    end else begin
      if (w_pop)
        reg_asm[32'(reg_beat) * PARA_AXI_DW +: PARA_AXI_DW] <= i_in_data;
      if (w_move)
        reg_chk <= w_masked;
    end
  end

  // Output mapping of the chunk and the idle status.
  assign o_chk_vld   = reg_chk_vld;
  assign o_chk_data  = reg_chk;
  assign o_chk_bytes = reg_chk_bytes;
  assign o_chk_kind  = reg_chk_kind;
  assign o_chk_last  = reg_chk_last;
  assign o_idle      = ~reg_active & ~reg_asm_done & ~reg_chk_vld;

endmodule
