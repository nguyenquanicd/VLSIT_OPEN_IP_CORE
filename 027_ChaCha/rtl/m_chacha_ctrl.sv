/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Message sequencer of the ChaCha20-Poly1305 engine (section 10.1). One FSM with the
 *                states IDLE, KEY, AAD, DATA, LEN, TAG, DONE and ABORT steers one message: it
 *                checks a start request, takes the nonce, asks the key store for the key, starts
 *                the keystream cores, loads the Poly1305 one-time key from keystream block 0, feeds
 *                the associated data, the ciphertext and the length block to Poly1305, XORs the
 *                keystream with the message chunks, writes the result and the tag to the output
 *                stream (or compares the received tag), raises the events, advances the hardware
 *                nonce counter and clears the secret state. A chunk is a block of up to 64 bytes
 *                (section 10.6). The sequencer also owns the nonce guard, the flush requests of the
 *                window buffers, the hold gate of a decryption and the message parameters of the
 *                DMA request logic. A zero length part is skipped: the sequencer goes from the key
 *                state to the first state that has data (DEC-037).
 * Decisions    : DEC-005, DEC-017, DEC-020, DEC-022, DEC-023, DEC-027, DEC-028, DEC-030,
 *                DEC-031, DEC-037
 */
`timescale 1ns/1ps

module m_chacha_ctrl #(
  // Parameter Description: data width of the window beat; a beat is PARA_AXI_DW / 8 bytes.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  // Parameter Description: depth of the input buffer in beats; limits the write watermark.
  // Parameter values: power of two from 4 to 4096; default is 16.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_IN_DEPTH = 32'd16,
  // Parameter Description: depth of the output buffer in beats; limits the read watermark.
  // Parameter values: power of two from 4 to 16384; default is 256.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_OUT_DEPTH = 32'd256,
  // Parameter Description: longest message accepted, in bytes; a longer message sets len_err.
  // Parameter values: 64 to 65535; default is 1280.
  // Parameter unit: byte
  parameter logic [31:0] PARA_MSG_MAX_B = 32'd1280,
  // Parameter Description: 1 holds the plaintext of a decryption until the tag matched.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_HOLD_EN = 32'd1,
  // Parameter Description: 0 software nonce, 1 hardware nonce counter for encryption.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_NONCE_HW = 32'd0,
  // Parameter Description: 1 refuses a software nonce equal to the previous one of the key slot.
  // Parameter values: 0 or 1; default is 1. No effect when PARA_NONCE_HW = 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_NONCE_CHK = 32'd1,
  localparam logic [31:0] LPARA_BYTES   = PARA_AXI_DW / 32'd8,
  localparam logic [31:0] LPARA_BYTE_LG = $clog2(LPARA_BYTES),
  localparam logic [31:0] LPARA_BMAX_RAW = 32'd4096 / LPARA_BYTES,
  localparam logic [31:0] LPARA_BMAX    = (LPARA_BMAX_RAW > 32'd256) ? 32'd256 : LPARA_BMAX_RAW,
  localparam logic [31:0] LPARA_WMAX_WR = (LPARA_BMAX > PARA_FIFO_IN_DEPTH) ? PARA_FIFO_IN_DEPTH : LPARA_BMAX,
  localparam logic [31:0] LPARA_WMAX_RD = (LPARA_BMAX > PARA_FIFO_OUT_DEPTH) ? PARA_FIFO_OUT_DEPTH : LPARA_BMAX
) (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Register block fields: control
  input  wire          i_cha_ctrl_en,
  input  wire          i_cha_ctrl_start,
  input  wire          i_cha_ctrl_dir,
  input  wire          i_cha_ctrl_abort,
  input  wire          i_cha_ctrl_dma_en,
  input  wire          i_cha_ctrl_tail_mode,
  input  wire  [3:0]   i_cha_ctrl_key_slot,

  // Register block fields: lengths, watermarks, nonce words, salt and nonce counter
  input  wire  [15:0]  i_cha_len_aad_len,
  input  wire  [15:0]  i_cha_len_msg_len,
  input  wire  [8:0]   i_cha_wm_wm_wr,
  input  wire  [8:0]   i_cha_wm_wm_rd,
  input  wire  [31:0]  i_cha_nonce0_nonce_w,
  input  wire  [31:0]  i_cha_nonce1_nonce_w,
  input  wire  [31:0]  i_cha_nonce2_nonce_w,
  input  wire  [31:0]  i_cha_salt_salt,
  input  wire  [31:0]  i_cha_ctr_lo_ctr,
  input  wire  [31:0]  i_cha_ctr_hi_ctr,

  // Register block hardware loads: start and abort clear, nonce counter
  output logic         o_hw_we_start,
  output logic         o_hw_we_abort,
  output logic [31:0]  o_hw_ctr_lo,
  output logic         o_hw_we_ctr_lo,
  output logic [31:0]  o_hw_ctr_hi,
  output logic         o_hw_we_ctr_hi,

  // Events (one-cycle pulses) and status to the register block
  output logic         o_ev_done,
  output logic         o_ev_tag_err,
  output logic         o_ev_len_err,
  output logic         o_ev_axi_err,
  output logic         o_ev_ctr_err,
  output logic         o_ev_key_err,
  output logic         o_sts_busy,
  output logic         o_sts_ctr_vld,

  // Events from the AXI domain: window error and reset indication (one-cycle pulses)
  input  wire          i_axi_err_evt,
  input  wire          i_axi_rstd_evt,

  // Key module: request pulse with the slot, key copied and key error pulses
  output logic         o_key_req_start,
  output logic [3:0]   o_key_slot_cfg,
  input  wire          i_key_got,
  input  wire          i_key_err_evt,

  // Cipher: load with the number of blocks, nonce and block stream
  output logic         o_ks_load,
  output logic [10:0]  o_ks_total,
  output logic [95:0]  o_nonce,
  input  wire          i_ks_vld,
  input  wire  [511:0] i_ks_blk,
  output logic         o_ks_take,

  // Poly1305: one-time key, block feed, finalize and tag
  output logic         o_otk_vld,
  output logic [255:0] o_otk,
  output logic         o_pl_blk_vld,
  output logic [127:0] o_pl_blk,
  input  wire          i_pl_blk_rdy,
  output logic         o_pl_fin,
  input  wire          i_pl_tag_vld,
  input  wire  [127:0] i_pl_tag,
  input  wire          i_pl_idle,

  // Input stream: run with the lengths and the direction, chunk interface
  output logic         o_in_run,
  output logic [15:0]  o_in_aad_len,
  output logic [15:0]  o_in_msg_len,
  output logic         o_in_dir,
  input  wire          i_chk_vld,
  input  wire  [511:0] i_chk_data,
  input  wire  [6:0]   i_chk_bytes,
  input  wire  [1:0]   i_chk_kind,
  input  wire          i_chk_last,
  output logic         o_chk_take,

  // Output stream: chunk to write and status
  output logic         o_eg_vld,
  output logic [511:0] o_eg_data,
  output logic [6:0]   o_eg_bytes,
  input  wire          i_eg_rdy,
  input  wire          i_eg_idle,

  // Window buffer flush: requests and done pulses
  output logic         o_flush_in_req,
  output logic         o_flush_out_req,
  input  wire          i_flush_in_done,
  input  wire          i_flush_out_done,

  // Datapath clear, hold gate, clock-gate enable
  output logic         o_dp_clr,
  output logic         o_out_gate,
  output logic         o_cg_en,

  // Message parameters for the DMA request logic (quasi-static, valid from the start)
  output logic [8:0]   o_dma_wm_wr,
  output logic [8:0]   o_dma_wm_rd,
  output logic         o_dma_tail_mode,
  output logic         o_dma_en,
  output logic [16:0]  o_dma_beats_wr,
  output logic [16:0]  o_dma_beats_rd,
  output logic         o_dma_msg_act,

  // Message description for the AXI window logic (quasi-static, valid from the start)
  output logic [15:0]  o_msg_aad_len,
  output logic [15:0]  o_msg_msg_len,
  output logic         o_msg_dir
);

  // FSM states (section 10.1): IDLE, KEY, AAD, DATA, LEN, TAG, DONE, ABORT; all eight codes of the
  // 3-bit state are defined and any other value cannot occur.
  typedef enum logic [2:0] {
    ENUM_ST_IDLE  = 3'b000,
    ENUM_ST_KEY   = 3'b001,
    ENUM_ST_AAD   = 3'b010,
    ENUM_ST_DATA  = 3'b011,
    ENUM_ST_LEN   = 3'b100,
    ENUM_ST_TAG   = 3'b101,
    ENUM_ST_DONE  = 3'b110,
    ENUM_ST_ABORT = 3'b111
  } msg_state_type_def;

  // Chunk kinds of the input stream, the same encoding as m_chacha_ingest.
  typedef enum logic [1:0] {
    ENUM_KIND_AAD = 2'd0,
    ENUM_KIND_MSG = 2'd1,
    ENUM_KIND_TAG = 2'd2
  } kind_type_def;

  // Internal signal declarations
  msg_state_type_def reg_fsm_msg_current_state;
  msg_state_type_def w_fsm_msg_nxt_state;
  kind_type_def      w_kind;
  logic              reg_dir;
  logic [15:0]       reg_aad_len;
  logic [15:0]       reg_msg_len;
  logic [95:0]       reg_nonce;
  logic              reg_tag_ok;
  logic              reg_tag_sent;
  logic              reg_cmp_done;
  logic              reg_fin_sent;
  logic              reg_ctr_vld;
  logic [95:0]       reg_prev_nonce;
  logic [3:0]        reg_prev_slot;
  logic              reg_prev_vld;
  logic              reg_gate;
  logic              reg_fl_in_pend;
  logic              reg_fl_out_pend;
  logic              reg_abort_axi;
  logic              reg_act;
  logic [8:0]        reg_wm_wr;
  logic [8:0]        reg_wm_rd;
  logic              reg_tail;
  logic              reg_dma_en;
  logic [16:0]       reg_beats_wr;
  logic [16:0]       reg_beats_rd;
  logic [511:0]      reg_pf;
  logic              reg_pf_vld;
  logic [6:0]        reg_pf_bytes;
  logic [1:0]        reg_pf_blk;
  logic [95:0]       w_nonce_sw;
  logic [95:0]       w_nonce_pick;
  logic              w_hw_enc;
  logic              w_start_now;
  logic              w_len_bad;
  logic              w_ctr_bad;
  logic              w_accept;
  logic              w_abort_req;
  logic              w_enter_abort;
  logic              w_abort_leave;
  logic              w_keyerr_now;
  logic              w_otk_go;
  logic              w_aad_end;
  logic              w_pf_ld_aad;
  logic              w_xor;
  logic              w_msg_end;
  logic              w_len_load;
  logic              w_fin_go;
  logic              w_tag_ld;
  logic              w_cmp_go;
  logic              w_tag_done;
  logic              w_pf_fire;
  logic              w_pf_last;
  logic              w_pf_free;
  logic [6:0]        w_pf_nblk_m1;
  logic [511:0]      w_res;
  logic [511:0]      w_ct;
  logic [63:0]       w_ctr_nxt;
  logic              w_dma_on;
  logic              w_busy_st;
  logic [16:0]       w_beats_a;
  logic [16:0]       w_beats_m;
  logic [16:0]       w_beats_t;

  // Chunk kind decode of the input chunk.
  assign w_kind = kind_type_def'(i_chk_kind);

  // Nonce selection at start: software words, or salt and the 64-bit counter of a hardware-nonce
  // encryption (salt is word 2, counter high is word 1 and counter low is word 0, ASM-010).
  assign w_nonce_sw   = {i_cha_nonce2_nonce_w, i_cha_nonce1_nonce_w, i_cha_nonce0_nonce_w};
  assign w_hw_enc     = (PARA_NONCE_HW == 32'd1) & ~i_cha_ctrl_dir;
  assign w_nonce_pick = w_hw_enc ? {i_cha_salt_salt, i_cha_ctr_hi_ctr, i_cha_ctr_lo_ctr} : w_nonce_sw;

  // Start evaluation in IDLE: a start request is always cleared (hardware load of 0). It is
  // refused silently while the engine is disabled, with len_err for a length or watermark above
  // its limit (a watermark of 0 is also illegal), and with ctr_err for an unloaded or wrapping
  // hardware counter or a repeated software nonce under the same key slot.
  assign w_dma_on    = i_cha_ctrl_dma_en;
  assign w_start_now = (reg_fsm_msg_current_state == ENUM_ST_IDLE) & i_cha_ctrl_start &
                       ~reg_fl_in_pend & ~reg_fl_out_pend;
  assign w_len_bad   = (i_cha_len_msg_len > 16'(PARA_MSG_MAX_B)) |
                       (w_dma_on & ((i_cha_wm_wm_wr == 9'd0) | (i_cha_wm_wm_wr > 9'(LPARA_WMAX_WR)) |
                                    (i_cha_wm_wm_rd == 9'd0) | (i_cha_wm_wm_rd > 9'(LPARA_WMAX_RD))));
  assign w_ctr_bad   = (w_hw_enc & (~reg_ctr_vld | ({i_cha_ctr_hi_ctr, i_cha_ctr_lo_ctr} == 64'hffffffffffffffff))) |
                       ((PARA_NONCE_HW == 32'd0) & (PARA_NONCE_CHK == 32'd1) & ~i_cha_ctrl_dir &
                        reg_prev_vld & (w_nonce_sw == reg_prev_nonce) & (i_cha_ctrl_key_slot == reg_prev_slot));
  assign w_accept    = w_start_now & i_cha_ctrl_en & ~w_len_bad & ~w_ctr_bad;

  // Abort sources: the abort bit or the AXI reset indication while a message is busy, and the AXI
  // reset indication in IDLE (flush only).
  assign w_busy_st     = (reg_fsm_msg_current_state != ENUM_ST_IDLE) & (reg_fsm_msg_current_state != ENUM_ST_DONE) &
                         (reg_fsm_msg_current_state != ENUM_ST_ABORT);
  assign w_abort_req   = w_busy_st & (i_cha_ctrl_abort | i_axi_rstd_evt);
  assign w_enter_abort = w_abort_req | ((reg_fsm_msg_current_state == ENUM_ST_IDLE) & i_axi_rstd_evt);
  assign w_abort_leave = (reg_fsm_msg_current_state == ENUM_ST_ABORT) & ~reg_fl_in_pend & ~reg_fl_out_pend;

  // KEY state: a key error returns to IDLE; the one-time key is taken from keystream block 0.
  assign w_keyerr_now = (reg_fsm_msg_current_state == ENUM_ST_KEY) & i_key_err_evt;
  assign w_otk_go     = (reg_fsm_msg_current_state == ENUM_ST_KEY) & i_ks_vld;

  // AAD state: an associated-data chunk moves into the feeder register when it is free; the last
  // chunk, or a zero length, ends the state.
  assign w_pf_ld_aad = (reg_fsm_msg_current_state == ENUM_ST_AAD) & i_chk_vld & (w_kind == ENUM_KIND_AAD) & w_pf_free;
  assign w_aad_end   = (reg_fsm_msg_current_state == ENUM_ST_AAD) &
                       ((reg_aad_len == 16'd0) | (w_pf_ld_aad & i_chk_last));

  // DATA state: the XOR step fires when a message chunk, its keystream block, the output stream
  // and the feeder register are all available; the last chunk, or a zero length, ends the state.
  assign w_xor     = (reg_fsm_msg_current_state == ENUM_ST_DATA) & i_chk_vld & (w_kind == ENUM_KIND_MSG) &
                     i_ks_vld & i_eg_rdy & w_pf_free;
  assign w_msg_end = (reg_fsm_msg_current_state == ENUM_ST_DATA) &
                     ((reg_msg_len == 16'd0) | (w_xor & i_chk_last));

  // Byte-masked XOR of the chunk and the keystream block; the ciphertext is the result of an
  // encryption and the received chunk of a decryption.
  always_comb begin : p_com_res
    w_res = '0;
    for (int idx = 0; idx < 64; idx++) begin
      if (7'(idx) < i_chk_bytes)
        w_res[8*idx +: 8] = i_chk_data[8*idx +: 8] ^ i_ks_blk[8*idx +: 8];
    end
  end
  assign w_ct = reg_dir ? i_chk_data : w_res;

  // LEN state: the length block (aad length in the low 8 bytes, message length in the high 8) moves
  // into the feeder register when it is free.
  assign w_len_load = (reg_fsm_msg_current_state == ENUM_ST_LEN) & w_pf_free;

  // TAG state: finalize once the feeder is empty and Poly1305 is idle; then write the tag
  // (encryption) or compare the received tag (decryption) in constant time over all 16 bytes.
  assign w_fin_go   = (reg_fsm_msg_current_state == ENUM_ST_TAG) & ~reg_pf_vld & i_pl_idle & ~reg_fin_sent;
  assign w_tag_ld   = (reg_fsm_msg_current_state == ENUM_ST_TAG) & ~reg_dir & i_pl_tag_vld & i_eg_rdy & ~reg_tag_sent;
  assign w_cmp_go   = (reg_fsm_msg_current_state == ENUM_ST_TAG) & reg_dir & i_pl_tag_vld & i_chk_vld &
                      (w_kind == ENUM_KIND_TAG) & ~reg_cmp_done;
  assign w_tag_done = (reg_fsm_msg_current_state == ENUM_ST_TAG) & i_eg_idle &
                      (reg_dir ? reg_cmp_done : reg_tag_sent);

  // Feeder register: the chunk being fed to Poly1305 in 16-byte blocks; one block is offered per
  // cycle and consumed when Poly1305 is ready; the last block frees the register. The register is
  // also free for the next chunk in the cycle in which its last block is consumed, so that a
  // Poly1305 that takes one block per cycle is fed without a gap between two chunks (DEC-037).
  assign w_pf_fire    = reg_pf_vld & i_pl_blk_rdy;
  assign w_pf_nblk_m1 = $bits(w_pf_nblk_m1)'(($bits(w_pf_nblk_m1)'(reg_pf_bytes + 7'd15) >> 4) - 7'd1);
  assign w_pf_last    = (reg_pf_blk == w_pf_nblk_m1[1:0]);
  assign w_pf_free    = ~reg_pf_vld | (w_pf_fire & w_pf_last);
  assign o_pl_blk_vld = reg_pf_vld;
  assign o_pl_blk     = reg_pf[128*reg_pf_blk +: 128];

  // Interface strobes to the datapath.
  assign o_key_req_start = w_accept;
  assign o_key_slot_cfg  = i_cha_ctrl_key_slot;
  assign o_ks_load       = i_key_got;
  assign o_ks_total      = 11'(17'd1 + ((17'(reg_msg_len) + 17'd63) >> 6));
  assign o_nonce         = reg_nonce;
  assign o_ks_take       = w_otk_go | w_xor;
  assign o_otk_vld       = w_otk_go;
  assign o_otk           = i_ks_blk[255:0];
  assign o_pl_fin        = w_fin_go;
  assign o_in_run        = w_accept;
  assign o_in_aad_len    = i_cha_len_aad_len;
  assign o_in_msg_len    = i_cha_len_msg_len;
  assign o_in_dir        = i_cha_ctrl_dir;
  assign o_chk_take      = w_pf_ld_aad | w_xor | w_cmp_go;
  assign o_eg_vld        = w_xor | w_tag_ld;
  assign o_eg_data       = w_xor ? w_res : {384'd0, i_pl_tag};
  assign o_eg_bytes      = w_xor ? i_chk_bytes : 7'd16;

  // Flush requests: both buffers on an abort and on a key error, the output buffer after a hold
  // mode decryption with a wrong tag. The pending flags keep the engine busy until the flush is
  // done.
  assign o_flush_in_req  = w_enter_abort | w_keyerr_now;
  assign o_flush_out_req = w_enter_abort | w_keyerr_now |
                           ((reg_fsm_msg_current_state == ENUM_ST_DONE) & reg_dir & ~reg_tag_ok & (PARA_HOLD_EN == 32'd1));

  // Datapath clear: at the end of a message, during an abort and on a key error.
  assign o_dp_clr = (reg_fsm_msg_current_state == ENUM_ST_DONE) | (reg_fsm_msg_current_state == ENUM_ST_ABORT) |
                    w_keyerr_now;

  // Clock-gate enable: the core datapath clock runs while a message is active or about to start.
  assign o_cg_en = (reg_fsm_msg_current_state != ENUM_ST_IDLE) | w_accept;

  // Hold gate, status and DMA parameters.
  assign o_out_gate    = reg_gate;
  assign o_sts_busy    = (reg_fsm_msg_current_state != ENUM_ST_IDLE) | reg_fl_in_pend | reg_fl_out_pend;
  assign o_sts_ctr_vld = reg_ctr_vld;

  // Total beats of the message: the associated data and the message data are written to the input
  // stream, plus the tag of a decryption; the message data and the tag of an encryption are read.
  assign w_beats_a = $bits(w_beats_a)'(($bits(w_beats_a)'(i_cha_len_aad_len) + 17'(LPARA_BYTES - 32'd1)) >> LPARA_BYTE_LG);
  assign w_beats_m = $bits(w_beats_m)'(($bits(w_beats_m)'(i_cha_len_msg_len) + 17'(LPARA_BYTES - 32'd1)) >> LPARA_BYTE_LG);
  assign w_beats_t = $bits(w_beats_t)'((17'd16 + 17'(LPARA_BYTES - 32'd1)) >> LPARA_BYTE_LG);
  assign o_dma_wm_wr     = reg_wm_wr;
  assign o_dma_wm_rd     = reg_wm_rd;
  assign o_dma_tail_mode = reg_tail;
  assign o_dma_en        = reg_dma_en;
  assign o_dma_beats_wr  = reg_beats_wr;
  assign o_dma_beats_rd  = reg_beats_rd;
  assign o_dma_msg_act   = reg_act;
  assign o_msg_aad_len   = reg_aad_len;
  assign o_msg_msg_len   = reg_msg_len;
  assign o_msg_dir       = reg_dir;

  // Hardware nonce counter: the incremented 64-bit value is loaded at the end of an encryption.
  assign w_ctr_nxt = $bits(w_ctr_nxt)'({i_cha_ctr_hi_ctr, i_cha_ctr_lo_ctr} + 64'd1);

  // Events and hardware loads. Done is raised for an encryption or a decryption with a matching
  // tag, tag_err for a mismatch; the AXI error is the window event, plus the reset-driven abort.
  assign o_ev_done     = (reg_fsm_msg_current_state == ENUM_ST_DONE) & (~reg_dir | reg_tag_ok);
  assign o_ev_tag_err  = (reg_fsm_msg_current_state == ENUM_ST_DONE) & reg_dir & ~reg_tag_ok;
  assign o_ev_len_err  = w_start_now & i_cha_ctrl_en & w_len_bad;
  assign o_ev_ctr_err  = w_start_now & i_cha_ctrl_en & ~w_len_bad & w_ctr_bad;
  assign o_ev_key_err  = w_keyerr_now;
  assign o_ev_axi_err  = i_axi_err_evt | (w_abort_leave & reg_abort_axi);
  assign o_hw_we_start = i_cha_ctrl_start;
  assign o_hw_we_abort = w_abort_leave | ((reg_fsm_msg_current_state == ENUM_ST_IDLE) & i_cha_ctrl_abort);
  assign o_hw_ctr_lo    = w_ctr_nxt[31:0];
  assign o_hw_ctr_hi    = w_ctr_nxt[63:32];
  assign o_hw_we_ctr_lo = (reg_fsm_msg_current_state == ENUM_ST_DONE) & ~reg_dir & (PARA_NONCE_HW == 32'd1);
  assign o_hw_we_ctr_hi = (reg_fsm_msg_current_state == ENUM_ST_DONE) & ~reg_dir & (PARA_NONCE_HW == 32'd1);

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_fsm_msg
    if (!i_rst_n_core)
      reg_fsm_msg_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_msg_current_state <= w_fsm_msg_nxt_state;
  end

  // Part 2 of the FSM. IDLE goes to KEY on an accepted start, or to ABORT on an AXI reset; KEY goes
  // to IDLE on a key error and to AAD when the one-time key is loaded; AAD, DATA, LEN and TAG
  // follow
  // the end conditions above; DONE returns to IDLE; ABORT returns when both flushes are done. Any
  // busy state goes to ABORT on an abort request, which has priority.
  always_comb begin : p_com_fsm_nxt
    w_fsm_msg_nxt_state = reg_fsm_msg_current_state;
    case (reg_fsm_msg_current_state)
      ENUM_ST_IDLE: begin
        if (w_accept)
          w_fsm_msg_nxt_state = ENUM_ST_KEY;
        else if (w_enter_abort)
          w_fsm_msg_nxt_state = ENUM_ST_ABORT;
      end
      ENUM_ST_KEY: begin
        casez ({w_abort_req, w_keyerr_now, w_otk_go})
          3'b1??:  w_fsm_msg_nxt_state = ENUM_ST_ABORT;
          3'b01?:  w_fsm_msg_nxt_state = ENUM_ST_IDLE;
          3'b001: begin
            // A state without data is skipped: no associated data goes to the message data, no
            // message data goes to the length block (DEC-037).
            if (reg_aad_len != 16'd0)
              w_fsm_msg_nxt_state = ENUM_ST_AAD;
            else if (reg_msg_len != 16'd0)
              w_fsm_msg_nxt_state = ENUM_ST_DATA;
            else
              w_fsm_msg_nxt_state = ENUM_ST_LEN;
          end
          default: w_fsm_msg_nxt_state = ENUM_ST_KEY;
        endcase
      end
      ENUM_ST_AAD: begin
        casez ({w_abort_req, w_aad_end})
          2'b1?:   w_fsm_msg_nxt_state = ENUM_ST_ABORT;
          2'b01: begin
            if (reg_msg_len != 16'd0)
              w_fsm_msg_nxt_state = ENUM_ST_DATA;
            else
              w_fsm_msg_nxt_state = ENUM_ST_LEN;
          end
          default: w_fsm_msg_nxt_state = ENUM_ST_AAD;
        endcase
      end
      ENUM_ST_DATA: begin
        casez ({w_abort_req, w_msg_end})
          2'b1?:   w_fsm_msg_nxt_state = ENUM_ST_ABORT;
          2'b01:   w_fsm_msg_nxt_state = ENUM_ST_LEN;
          default: w_fsm_msg_nxt_state = ENUM_ST_DATA;
        endcase
      end
      ENUM_ST_LEN: begin
        casez ({w_abort_req, w_len_load})
          2'b1?:   w_fsm_msg_nxt_state = ENUM_ST_ABORT;
          2'b01:   w_fsm_msg_nxt_state = ENUM_ST_TAG;
          default: w_fsm_msg_nxt_state = ENUM_ST_LEN;
        endcase
      end
      ENUM_ST_TAG: begin
        casez ({w_abort_req, w_tag_done})
          2'b1?:   w_fsm_msg_nxt_state = ENUM_ST_ABORT;
          2'b01:   w_fsm_msg_nxt_state = ENUM_ST_DONE;
          default: w_fsm_msg_nxt_state = ENUM_ST_TAG;
        endcase
      end
      ENUM_ST_DONE: w_fsm_msg_nxt_state = ENUM_ST_IDLE;
      ENUM_ST_ABORT: begin
        if (w_abort_leave)
          w_fsm_msg_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_msg_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Control flags: step flags of one message, the counter-valid flag, the flush pending flags, the
  // hold gate and the reason of an abort. They are reset to their idle values.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_flags
    if (!i_rst_n_core) begin
      reg_tag_ok      <= 1'b0;
      reg_tag_sent    <= 1'b0;
      reg_cmp_done    <= 1'b0;
      reg_fin_sent    <= 1'b0;
      reg_ctr_vld     <= 1'b0;
      reg_prev_vld    <= 1'b0;
      reg_gate        <= 1'b0;
      reg_fl_in_pend  <= 1'b0;
      reg_fl_out_pend <= 1'b0;
      reg_abort_axi   <= 1'b0;
      reg_act         <= 1'b0;
    end else begin
      // The message-active level is registered because it crosses into CLK-AXI (rule CLK-01).
      reg_act <= w_busy_st;
      // Step flags are cleared at a start and set by the step events.
      if (w_accept) begin
        reg_tag_ok   <= 1'b0;
        reg_tag_sent <= 1'b0;
        reg_cmp_done <= 1'b0;
        reg_fin_sent <= 1'b0;
        reg_gate     <= ~((PARA_HOLD_EN == 32'd1) & i_cha_ctrl_dir);
      end
      if (w_fin_go)
        reg_fin_sent <= 1'b1;
      if (w_tag_ld)
        reg_tag_sent <= 1'b1;
      if (w_cmp_go) begin
        reg_cmp_done <= 1'b1;
        reg_tag_ok   <= (i_chk_data[127:0] == i_pl_tag);
      end
      // The hold gate opens when a decryption ended with a matching tag, and closes on an abort.
      if ((reg_fsm_msg_current_state == ENUM_ST_DONE) & reg_dir & reg_tag_ok)
        reg_gate <= 1'b1;
      if (w_enter_abort | w_keyerr_now)
        reg_gate <= 1'b0;
      // The nonce counter is valid once software has loaded a non-zero start value (DEC-031).
      if ((PARA_NONCE_HW == 32'd1) & ((i_cha_ctr_lo_ctr != 32'd0) | (i_cha_ctr_hi_ctr != 32'd0)))
        reg_ctr_vld <= 1'b1;
      // Nonce guard: the nonce and slot of an accepted software-nonce encryption.
      if (w_accept & ~i_cha_ctrl_dir & (PARA_NONCE_HW == 32'd0))
        reg_prev_vld <= 1'b1;
      // Flush pending flags: set with the request, cleared by the done pulse.
      if (o_flush_in_req)
        reg_fl_in_pend <= 1'b1;
      else if (i_flush_in_done)
        reg_fl_in_pend <= 1'b0;
      if (o_flush_out_req)
        reg_fl_out_pend <= 1'b1;
      else if (i_flush_out_done)
        reg_fl_out_pend <= 1'b0;
      // An abort caused by the AXI reset raises axi_err when it ends.
      if (w_enter_abort)
        reg_abort_axi <= i_axi_rstd_evt & w_busy_st;
    end
  end

  // Message registers: latched at an accepted start; no reset, because the state machine qualifies
  // them (nothing reads them in IDLE).
  always_ff @(posedge i_clk_core) begin : p_ff_msg
    if (w_accept) begin
      reg_dir        <= i_cha_ctrl_dir;
      reg_aad_len    <= i_cha_len_aad_len;
      reg_msg_len    <= i_cha_len_msg_len;
      reg_nonce      <= w_nonce_pick;
      reg_wm_wr      <= i_cha_wm_wm_wr;
      reg_wm_rd      <= i_cha_wm_wm_rd;
      reg_tail       <= i_cha_ctrl_tail_mode;
      reg_dma_en     <= i_cha_ctrl_dma_en;
      reg_beats_wr   <= $bits(reg_beats_wr)'(w_beats_a + w_beats_m + (i_cha_ctrl_dir ? w_beats_t : 17'd0));
      reg_beats_rd   <= $bits(reg_beats_rd)'(w_beats_m + (i_cha_ctrl_dir ? 17'd0 : w_beats_t));
      if (~i_cha_ctrl_dir) begin
        reg_prev_nonce <= w_nonce_sw;
        reg_prev_slot  <= i_cha_ctrl_key_slot;
      end
    end
  end

  // Feeder register: loaded with an associated-data chunk, a ciphertext chunk or the length block;
  // it offers 16-byte blocks to Poly1305 and frees itself with the last block. The valid flag and
  // the block index are control state (reset); the payload has no reset and is cleared by o_dp_clr.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_pf
    if (!i_rst_n_core) begin
      reg_pf_vld   <= 1'b0;
      reg_pf_bytes <= 7'd0;
      reg_pf_blk   <= 2'd0;
    end else if (o_dp_clr) begin
      reg_pf_vld <= 1'b0;
      reg_pf_blk <= 2'd0;
    end else begin
      casez ({w_pf_ld_aad, w_xor, w_len_load, w_pf_fire})
        4'b1???: begin
          reg_pf_vld   <= 1'b1;
          reg_pf_bytes <= i_chk_bytes;
          reg_pf_blk   <= 2'd0;
        end
        4'b01??: begin
          reg_pf_vld   <= 1'b1;
          reg_pf_bytes <= i_chk_bytes;
          reg_pf_blk   <= 2'd0;
        end
        4'b001?: begin
          reg_pf_vld   <= 1'b1;
          reg_pf_bytes <= 7'd16;
          reg_pf_blk   <= 2'd0;
        end
        4'b0001: begin
          if (w_pf_last) begin
            reg_pf_vld <= 1'b0;
            reg_pf_blk <= 2'd0;
          end else
            reg_pf_blk <= $bits(reg_pf_blk)'(reg_pf_blk + 2'd1);
        end
        default: begin
          // No feeder event: hold.
        end
      endcase
    end
  end

  // Feeder payload: the chunk to feed, selected by the load source.
  always_ff @(posedge i_clk_core) begin : p_ff_pfdata
    if (o_dp_clr)
      reg_pf <= '0;
    else begin
      casez ({w_pf_ld_aad, w_xor, w_len_load})
        3'b1??:  reg_pf <= i_chk_data;
        3'b01?:  reg_pf <= w_ct;
        3'b001:  reg_pf <= {384'd0, 48'd0, reg_msg_len, 48'd0, reg_aad_len};
        default: reg_pf <= reg_pf;
      endcase
    end
  end

endmodule
