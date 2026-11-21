/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Packet transmitter of the link (REQ-FUNC-001 to REQ-FUNC-005, DEC-005). One
 *                request sends a handshake (PID), a token (PID, 11 bits, CRC5), a split token
 *                (PID, 19 bits, CRC5), a data packet (PID, payload from the source, CRC16) or a
 *                raw byte stream. A byte packer builds words of one or two lanes from chunks of
 *                the generator, so the stream to the PHY has no gap inside a packet: the payload
 *                source must deliver one chunk per cycle while a packet is sent (the FIFO checks
 *                that the whole payload is stored before it starts a packet). The output
 *                register holds its word until the PHY accepts it (ready with valid), and loads
 *                the next word in the same cycle as the acceptance.
 */
`timescale 1ns/1ps

module m_usb2_lnktx #(
  // Parameter Description: UTMI+ data width; selects one or two byte lanes.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  localparam logic [31:0] LPARA_KIND_TOK   = 1,
  localparam logic [31:0] LPARA_KIND_SPLIT = 2,
  localparam logic [31:0] LPARA_KIND_DATA  = 3,
  localparam logic [31:0] LPARA_KIND_RAW   = 4,
  localparam logic [31:0] LPARA_W16        = 16,
  localparam logic [31:0] LPARA_CRC16_SEED = 32'h0000FFFF,
  localparam logic [31:0] LPARA_CRC5_TOK_W = 11,
  localparam logic [31:0] LPARA_CRC5_SPL_W = 19,
  localparam logic [31:0] LPARA_CRC_TWO    = 2,
  localparam logic [31:0] LPARA_NFLD_TOK   = 2,
  localparam logic [31:0] LPARA_NFLD_SPLIT = 3,
  localparam logic [31:0] LPARA_CRC_BYTES  = 2
) (
  // Clock and reset
  input  wire         i_clk_phy,
  input  wire         i_rst_n_core,

  // Packet request from the engines
  input  wire         i_tx_req,
  input  wire  [2:0]  i_tx_kind,
  input  wire  [3:0]  i_tx_pid,
  input  wire  [18:0] i_tx_fld,
  input  wire  [11:0] i_tx_len,

  // Payload source (show-ahead word; one pop per chunk)
  input  wire  [15:0] i_src_dat,
  input  wire         i_src_vld,
  output logic        o_src_pop,

  // Status
  output logic        o_tx_busy,
  output logic        o_tx_done,
  output logic        o_tx_fail,

  // Stream to the PHY interface
  output logic [15:0] o_tx_data,
  output logic [1:0]  o_tx_valid,
  input  wire         i_tx_ready,
  input  wire         i_tx_abort
);

  // FSM states of the packet generator.
  typedef enum logic [2:0] {
    ENUM_ST_IDLE  = 3'd0,
    ENUM_ST_PID   = 3'd1,
    ENUM_ST_FLD   = 3'd2,
    ENUM_ST_PAY   = 3'd3,
    ENUM_ST_CRC   = 3'd4,
    ENUM_ST_FLUSH = 3'd5,
    ENUM_ST_WAIT  = 3'd6
  } tx_state_type_def;

  // Internal signal declarations
  tx_state_type_def   reg_fsm_tx_current_state;
  tx_state_type_def   w_fsm_tx_nxt_state;
  logic [2:0]         reg_kind;
  logic [3:0]         reg_pid;
  logic [18:0]        reg_fld;
  logic [11:0]        reg_rem;
  logic [15:0]        reg_crc;
  logic [1:0]         reg_fbi;
  logic [1:0]         reg_cbi;
  logic [7:0]         reg_stg;
  logic               reg_stg_v;
  logic [15:0]        reg_o_data;
  logic [1:0]         reg_o_valid;
  logic               reg_done;
  logic               reg_fail;
  logic [3:0]         reg_starve;
  logic               w_abort;
  logic               w_wide;
  logic               w_out_free;
  logic               w_step;
  logic [1:0]         w_ch_n;
  logic [7:0]         w_ch_b0;
  logic [7:0]         w_ch_b1;
  logic [4:0]         w_crc5_tok;
  logic [4:0]         w_crc5_spl;
  logic [31:0]        w_fb;
  logic [1:0]         w_nfld;
  logic [15:0]        w_fb_sl;
  logic [1:0]         w_fld_n;
  logic [1:0]         w_cr_n;
  logic [1:0]         w_pay_n;
  logic [15:0]        w_crc_nxt;
  logic [7:0]         w_crc_lo;
  logic [7:0]         w_crc_hi;
  logic               w_emit;
  logic [15:0]        w_emit_data;
  logic               w_stg_nxt_v;
  logic [7:0]         w_stg_nxt;
  logic               w_flush_emit;
  logic               w_out_empty;

  // A payload source that stays empty for 16 cycles inside a packet aborts the packet, so the link
  // never hangs (for example when the test packet source is removed in the middle of a packet).
  assign w_abort = i_tx_abort | ((reg_fsm_tx_current_state == ENUM_ST_PAY) & ~i_src_vld & (reg_starve == 4'd15));

  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_starve
    if (!i_rst_n_core)
      reg_starve <= 4'd0;
    else if ((reg_fsm_tx_current_state == ENUM_ST_PAY) & ~i_src_vld)
      reg_starve <= reg_starve + 4'd1;
    else
      reg_starve <= 4'd0;
  end

  // 16-bit mode packs two bytes per word.
  assign w_wide     = (PARA_USB2_UTMI_W == LPARA_W16) ? 1'b1 : 1'b0;
  assign w_out_free = ~reg_o_valid[0] | i_tx_ready;
  assign w_out_empty = ~reg_o_valid[0];

  // CRC5 of the token and split fields; they are sent after the fields, inside the last byte.
  m_usb2_crc5 #(
    .PARA_USB2_CRC5_W (LPARA_CRC5_TOK_W)
  ) u_crc5_tok (
    .i_data (reg_fld[10:0]),
    .o_crc  (w_crc5_tok)
  );

  m_usb2_crc5 #(
    .PARA_USB2_CRC5_W (LPARA_CRC5_SPL_W)
  ) u_crc5_spl (
    .i_data (reg_fld[18:0]),
    .o_crc  (w_crc5_spl)
  );

  // Field bytes of the token (two bytes) or the split token (three bytes).
  assign w_fb   = (reg_kind == LPARA_KIND_TOK[2:0]) ? {16'h0000, w_crc5_tok, reg_fld[10:8], reg_fld[7:0]} :
                                                      {8'h00, w_crc5_spl, reg_fld[18:16], reg_fld[15:0]};
  assign w_fb_sl = w_fb[8*reg_fbi +: 16];
  assign w_nfld = (reg_kind == LPARA_KIND_TOK[2:0]) ? LPARA_NFLD_TOK[1:0] : LPARA_NFLD_SPLIT[1:0];

  // Number of field, payload and CRC bytes in the chunk of this step.
  always_comb begin : p_com_cnt
    w_fld_n = 2'd1;
    if (w_wide && (w_nfld - reg_fbi) >= 2'd2)
      w_fld_n = 2'd2;
    w_cr_n = 2'd1;
    if (w_wide && reg_cbi == 2'd0)
      w_cr_n = 2'd2;
    w_pay_n = 2'd1;
    if (w_wide && reg_rem >= 12'd2)
      w_pay_n = 2'd2;
  end

  // CRC16 over the payload chunk of this step; the transmit bytes come from the final remainder.
  m_usb2_crc16 #(
    .PARA_USB2_CRC_BYTES (LPARA_CRC_TWO)
  ) u_crc16_tx (
    .i_crc         (reg_crc),
    .i_data        (i_src_dat),
    .i_high_en     (w_pay_n == 2'd2),
    .o_crc_nxt     (w_crc_nxt),
    .o_residual_ok (),
    .o_tx_lo       (w_crc_lo),
    .o_tx_hi       (w_crc_hi)
  );

  // Chunk of the step: count and bytes by state.
  always_comb begin : p_com_chunk
    w_ch_n  = 2'd0;
    w_ch_b0 = 8'h00;
    w_ch_b1 = 8'h00;
    case (reg_fsm_tx_current_state)
      ENUM_ST_PID: begin
        w_ch_n  = 2'd1;
        w_ch_b0 = {~reg_pid, reg_pid};
      end
      ENUM_ST_FLD: begin
        w_ch_n  = w_fld_n;
        w_ch_b0 = w_fb_sl[7:0];
        w_ch_b1 = w_fb_sl[15:8];
      end
      ENUM_ST_PAY: begin
        w_ch_n  = w_pay_n;
        w_ch_b0 = i_src_dat[7:0];
        w_ch_b1 = i_src_dat[15:8];
      end
      ENUM_ST_CRC: begin
        w_ch_n  = w_cr_n;
        w_ch_b0 = (reg_cbi == 2'd0) ? w_crc_lo : w_crc_hi;
        w_ch_b1 = w_crc_hi;
      end
      default: begin
        w_ch_n = 2'd0;
      end
    endcase
  end

  // A step happens when the output register can take a word and the state has a chunk (the
  // payload state also needs the source).
  assign w_step = w_out_free & (w_ch_n != 2'd0) &
                  ((reg_fsm_tx_current_state != ENUM_ST_PAY) | i_src_vld) & ~w_abort;
  assign o_src_pop = w_step & (reg_fsm_tx_current_state == ENUM_ST_PAY);

  // Packer: held byte plus chunk bytes; a word is emitted when the lanes are full.
  always_comb begin : p_com_pack
    w_emit       = 1'b0;
    w_emit_data  = 16'h0000;
    w_stg_nxt_v  = reg_stg_v;
    w_stg_nxt    = reg_stg;
    if (w_step) begin
      casez ({w_wide, reg_stg_v, (w_ch_n == 2'd2)})
        3'b0??: begin
          w_emit      = 1'b1;
          w_emit_data = {8'h00, w_ch_b0};
          w_stg_nxt_v = 1'b0;
        end
        3'b11?: begin
          w_emit      = 1'b1;
          w_emit_data = {w_ch_b0, reg_stg};
          w_stg_nxt_v = (w_ch_n == 2'd2);
          w_stg_nxt   = w_ch_b1;
        end
        3'b101: begin
          w_emit      = 1'b1;
          w_emit_data = {w_ch_b1, w_ch_b0};
          w_stg_nxt_v = 1'b0;
        end
        default: begin
          w_stg_nxt_v = 1'b1;
          w_stg_nxt   = w_ch_b0;
        end
      endcase
    end
  end

  // Flush of a held byte at the end of the packet.
  assign w_flush_emit = (reg_fsm_tx_current_state == ENUM_ST_FLUSH) & reg_stg_v & w_out_free;

  // Part 1, sequential: the current state of the generator.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_fsm_tx
    if (!i_rst_n_core)
      reg_fsm_tx_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_tx_current_state <= w_fsm_tx_nxt_state;
  end

  // Part 2, combinational: next state. IDLE starts on a request; PID goes to the fields, the
  // payload or the flush by kind; the payload goes to the CRC (data) or the flush (raw).
  always_comb begin : p_com_fsm_nxt
    w_fsm_tx_nxt_state = reg_fsm_tx_current_state;
    case (reg_fsm_tx_current_state)
      ENUM_ST_IDLE: begin
        if (i_tx_req)
          case (i_tx_kind)
            LPARA_KIND_RAW[2:0]: w_fsm_tx_nxt_state = (i_tx_len == 12'd0) ? ENUM_ST_FLUSH : ENUM_ST_PAY;
            default: w_fsm_tx_nxt_state = ENUM_ST_PID;
          endcase
      end
      ENUM_ST_PID: begin
        if (w_step) begin
          case (reg_kind)
            LPARA_KIND_TOK[2:0], LPARA_KIND_SPLIT[2:0]: w_fsm_tx_nxt_state = ENUM_ST_FLD;
            LPARA_KIND_DATA[2:0]: w_fsm_tx_nxt_state = (reg_rem == 12'd0) ? ENUM_ST_CRC : ENUM_ST_PAY;
            default: w_fsm_tx_nxt_state = ENUM_ST_FLUSH;
          endcase
        end
      end
      ENUM_ST_FLD: begin
        if (w_step && (reg_fbi + w_fld_n) >= w_nfld)
          w_fsm_tx_nxt_state = ENUM_ST_FLUSH;
      end
      ENUM_ST_PAY: begin
        if (w_step && reg_rem <= {10'd0, w_pay_n})
          w_fsm_tx_nxt_state = (reg_kind == LPARA_KIND_DATA[2:0]) ? ENUM_ST_CRC : ENUM_ST_FLUSH;
      end
      ENUM_ST_CRC: begin
        if (w_step && (reg_cbi + w_cr_n) >= LPARA_CRC_BYTES[1:0])
          w_fsm_tx_nxt_state = ENUM_ST_FLUSH;
      end
      ENUM_ST_FLUSH: begin
        if (w_out_free)
          w_fsm_tx_nxt_state = ENUM_ST_WAIT;
      end
      ENUM_ST_WAIT: begin
        if (w_out_empty | i_tx_ready)
          w_fsm_tx_nxt_state = ENUM_ST_IDLE;
      end
      default: w_fsm_tx_nxt_state = ENUM_ST_IDLE;
    endcase
    if (w_abort)
      w_fsm_tx_nxt_state = ENUM_ST_IDLE;
  end

  // Request fields and counters of the packet in progress.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_req
    if (!i_rst_n_core) begin
      reg_kind <= 3'd0;
      reg_pid  <= 4'h0;
      reg_fld  <= '0;
      reg_rem  <= '0;
      reg_crc  <= LPARA_CRC16_SEED[15:0];
      reg_fbi  <= 2'd0;
      reg_cbi  <= 2'd0;
    end else begin
      if ((reg_fsm_tx_current_state == ENUM_ST_IDLE) & i_tx_req) begin
        reg_kind <= i_tx_kind;
        reg_pid  <= i_tx_pid;
        reg_fld  <= i_tx_fld;
        reg_rem  <= i_tx_len;
        reg_crc  <= LPARA_CRC16_SEED[15:0];
        reg_fbi  <= 2'd0;
        reg_cbi  <= 2'd0;
      end
      if (w_step) begin
        case (reg_fsm_tx_current_state)
          ENUM_ST_FLD: reg_fbi <= reg_fbi + w_fld_n;
          ENUM_ST_PAY: begin
            reg_rem <= reg_rem - {10'd0, w_pay_n};
            if (reg_kind == LPARA_KIND_DATA[2:0])
              reg_crc <= w_crc_nxt;
          end
          ENUM_ST_CRC: reg_cbi <= reg_cbi + w_cr_n;
          default: begin
            reg_cbi <= reg_cbi;
          end
        endcase
      end
    end
  end

  // Packer state and the output register: loaded by an emitted word or by the flush, cleared when
  // the PHY accepts the word and nothing new is loaded. The done pulse comes when the last word of
  // the packet was accepted.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_out
    if (!i_rst_n_core) begin
      reg_stg     <= 8'h00;
      reg_stg_v   <= 1'b0;
      reg_o_data  <= 16'h0000;
      reg_o_valid <= 2'b00;
      reg_done    <= 1'b0;
      reg_fail    <= 1'b0;
    end else begin
      reg_done <= 1'b0;
      reg_fail <= 1'b0;
      reg_stg_v <= w_stg_nxt_v;
      reg_stg   <= w_stg_nxt;
      casez ({w_abort, w_emit, w_flush_emit, (reg_o_valid[0] & i_tx_ready)})
        4'b1???: begin
          reg_o_valid <= 2'b00;
          reg_stg_v   <= 1'b0;
          reg_fail    <= (reg_fsm_tx_current_state != ENUM_ST_IDLE);
        end
        4'b01??: begin
          reg_o_data  <= w_emit_data;
          reg_o_valid <= w_wide ? 2'b11 : 2'b01;
        end
        4'b001?: begin
          reg_o_data  <= {8'h00, reg_stg};
          reg_o_valid <= 2'b01;
          reg_stg_v   <= 1'b0;
        end
        4'b0001: reg_o_valid <= 2'b00;
        default: begin
          reg_o_valid <= reg_o_valid;
        end
      endcase
      if ((reg_fsm_tx_current_state == ENUM_ST_WAIT) & (w_out_empty | i_tx_ready) & ~w_abort)
        reg_done <= 1'b1;
    end
  end

  // Outputs: the stream to the PHY, the busy flag and the pulses.
  assign o_tx_data  = reg_o_data;
  assign o_tx_valid = reg_o_valid;
  assign o_tx_busy  = (reg_fsm_tx_current_state != ENUM_ST_IDLE) | reg_o_valid[0];
  assign o_tx_done  = reg_done;
  assign o_tx_fail  = reg_fail;

endmodule
