/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Packet receiver of the link (REQ-FUNC-001 to REQ-FUNC-005, DEC-005). It takes
 *                the byte lanes of the PHY interface (one lane in 8-bit mode, two in 16-bit
 *                mode), finds the PID byte, checks the PID complement, classifies the packet and
 *                then collects the token fields, handshake or data payload. Data payload leaves
 *                with a two-byte delay so that the CRC16 bytes never reach the consumer; the
 *                CRC16 is checked with the residual of REF-001 8.3.5.2. Token and split fields
 *                are checked with CRC5. An EXT token marks the next packet as the LPM extended
 *                token. Every output is registered once. PARA_USB2_PIPE_RX adds a register stage
 *                on the PHY inputs and PARA_USB2_PIPE_CRC adds one stage before the byte
 *                processing; each stage adds one cycle to the turn-around path.
 */
`timescale 1ns/1ps

module m_usb2_lnkrx #(
  // Parameter Description: 1 adds a register stage on the PHY receive inputs (timing option).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_RX = 0,
  // Parameter Description: 1 adds a register stage between byte extraction and the CRC and
  // collection logic (timing option for the CRC16 update).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_CRC = 0,
  // Parameter Description: UTMI+ data width; selects one or two byte lanes.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  localparam logic [31:0] LPARA_CLS_NONE   = 0,
  localparam logic [31:0] LPARA_CLS_TOK    = 1,
  localparam logic [31:0] LPARA_CLS_SPLIT  = 2,
  localparam logic [31:0] LPARA_CLS_DATA   = 3,
  localparam logic [31:0] LPARA_CLS_HS     = 4,
  localparam logic [31:0] LPARA_CLS_EXT    = 5,
  localparam logic [31:0] LPARA_CLS_ETK    = 6,
  localparam logic [31:0] LPARA_PID_OUT    = 32'h1,
  localparam logic [31:0] LPARA_PID_IN     = 32'h9,
  localparam logic [31:0] LPARA_PID_SETUP  = 32'hD,
  localparam logic [31:0] LPARA_PID_SOF    = 32'h5,
  localparam logic [31:0] LPARA_PID_PING   = 32'h4,
  localparam logic [31:0] LPARA_PID_SPLIT  = 32'h8,
  localparam logic [31:0] LPARA_PID_EXT    = 32'h0,
  localparam logic [31:0] LPARA_PID_DATA0  = 32'h3,
  localparam logic [31:0] LPARA_PID_DATA1  = 32'hB,
  localparam logic [31:0] LPARA_PID_DATA2  = 32'h7,
  localparam logic [31:0] LPARA_PID_MDATA  = 32'hF,
  localparam logic [31:0] LPARA_PID_ACK    = 32'h2,
  localparam logic [31:0] LPARA_PID_NAK    = 32'hA,
  localparam logic [31:0] LPARA_PID_STALL  = 32'hE,
  localparam logic [31:0] LPARA_PID_NYET   = 32'h6,
  localparam logic [31:0] LPARA_PID_ERR    = 32'hC,
  localparam logic [31:0] LPARA_CRC16_RES  = 32'h0000800D,
  localparam logic [31:0] LPARA_CRC16_SEED = 32'h0000FFFF,
  localparam logic [31:0] LPARA_CNT_W      = 13,
  localparam logic [31:0] LPARA_CNT_MAX    = 32'd4095,
  localparam logic [31:0] LPARA_MAX_PAY    = 32'd1026,
  localparam logic [31:0] LPARA_W16        = 16,
  localparam logic [31:0] LPARA_CRC_TWO    = 2,
  localparam logic [31:0] LPARA_CRC5_TOK_W = 11,
  localparam logic [31:0] LPARA_CRC5_SPL_W = 19
) (
  // Clock and reset
  input  wire         i_clk_phy,
  input  wire         i_rst_n_core,

  // Receive stream from the PHY interface (or the loopback of the link)
  input  wire  [15:0] i_rx_data,
  input  wire  [1:0]  i_rx_valid,
  input  wire         i_rx_active,
  input  wire         i_rx_err,

  // Token, split token and handshake events
  output logic        o_tok_vld,
  output logic        o_tok_ext,
  output logic [10:0] o_tok_efld,
  output logic [3:0]  o_tok_pid,
  output logic [10:0] o_tok_fld,
  output logic        o_spl_vld,
  output logic        o_hs_vld,
  output logic [3:0]  o_hs_pid,

  // Data packet events and payload stream (CRC16 removed)
  output logic        o_dat_sop,
  output logic [3:0]  o_dat_pid,
  output logic [1:0]  o_dat_n,
  output logic [15:0] o_dat_b,
  output logic        o_dat_end,
  output logic        o_dat_ok,
  output logic [11:0] o_dat_len,

  // Error pulses and packet status
  output logic        o_err_pid,
  output logic        o_err_crc,
  output logic        o_err_stuf,
  output logic        o_err_babble,
  output logic        o_rx_busy
);

  // Internal signal declarations
  logic [15:0]             reg_in_data;
  logic [1:0]              reg_in_valid;
  logic                    reg_in_active;
  logic                    reg_in_err;
  logic [15:0]             w_in_data;
  logic [1:0]              w_in_valid;
  logic                    w_in_active;
  logic                    w_in_err;
  logic                    reg_act_d;
  logic                    reg_got_pid;
  logic                    w_v0;
  logic                    w_v1;
  logic                    w_first;
  logic                    w_eop;
  logic [1:0]              w_pay_n;
  logic [7:0]              w_pay_b0;
  logic [7:0]              w_pay_b1;
  logic                    reg_s_sop;
  logic [7:0]              reg_s_pid;
  logic [1:0]              reg_s_n;
  logic [7:0]              reg_s_b0;
  logic [7:0]              reg_s_b1;
  logic                    reg_s_eop;
  logic                    reg_s_err;
  logic                    w_s_sop;
  logic [7:0]              w_s_pid;
  logic [1:0]              w_s_n;
  logic [7:0]              w_s_b0;
  logic [7:0]              w_s_b1;
  logic                    w_s_eop;
  logic                    w_s_err;
  logic [2:0]              reg_cls;
  logic [2:0]              w_cls_nxt;
  logic [3:0]              reg_pid;
  logic                    reg_pid_ok;
  logic                    w_pid_ok;
  logic                    reg_ext_pend;
  logic                    reg_etk;
  logic                    reg_in_pkt;
  logic                    reg_err_seen;
  logic [LPARA_CNT_W-1:0]  reg_cnt;
  logic [LPARA_CNT_W-1:0]  w_cnt_base;
  logic [LPARA_CNT_W-1:0]  w_cnt_fin;
  logic [15:0]             reg_crc;
  logic [15:0]             w_crc_base;
  logic [15:0]             w_crc_nxt;
  logic [15:0]             w_crc_fin;
  logic [7:0]              reg_h0;
  logic [7:0]              reg_h1;
  logic [7:0]              reg_h2;
  logic [7:0]              w_h0;
  logic [7:0]              w_h1;
  logic [7:0]              w_h2;
  logic [15:0]             reg_buf;
  logic [1:0]              reg_buf_n;
  logic [31:0]             w_win;
  logic [15:0]             w_buf_m;
  logic [1:0]              w_bn;
  logic [2:0]              w_tot;
  logic [2:0]              w_out_n;
  logic [31:0]             w_win_sh;
  logic [4:0]              w_crc5_tok;
  logic [4:0]              w_crc5_spl;
  logic                    w_data_cls;
  logic [LPARA_CNT_W-1:0]  w_pay_cnt_sum;
  logic reg_tok_vld;
  logic reg_tok_ext;
  logic [3:0] reg_tok_pid;
  logic [10:0] reg_tok_fld;
  logic [10:0] reg_tok_efld;
  logic reg_spl_vld;
  logic reg_hs_vld;
  logic [3:0] reg_hs_pid;
  logic reg_dat_sop;
  logic [3:0] reg_dat_pid;
  logic [1:0] reg_dat_n;
  logic [15:0] reg_dat_b;
  logic reg_dat_end;
  logic reg_dat_ok;
  logic [11:0] reg_dat_len;
  logic reg_err_pid;
  logic reg_err_crc;
  logic reg_err_stuf;
  logic reg_err_babble;

  // Optional register stage on the PHY inputs.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_in
    if (!i_rst_n_core) begin
      reg_in_data   <= '0;
      reg_in_valid  <= '0;
      reg_in_active <= 1'b0;
      reg_in_err    <= 1'b0;
    end else begin
      reg_in_data   <= i_rx_data;
      reg_in_valid  <= i_rx_valid;
      reg_in_active <= i_rx_active;
      reg_in_err    <= i_rx_err;
    end
  end

  assign w_in_data   = (PARA_USB2_PIPE_RX != 32'd0) ? reg_in_data : i_rx_data;
  assign w_in_valid  = (PARA_USB2_PIPE_RX != 32'd0) ? reg_in_valid : i_rx_valid;
  assign w_in_active = (PARA_USB2_PIPE_RX != 32'd0) ? reg_in_active : i_rx_active;
  assign w_in_err    = (PARA_USB2_PIPE_RX != 32'd0) ? reg_in_err : i_rx_err;

  // Stage A: lane extraction. The first valid byte after idle is the PID; the remaining bytes of
  // the cycle are payload bytes in lane order.
  assign w_v0    = w_in_valid[0];
  assign w_v1    = w_in_valid[1] & w_in_valid[0] & (PARA_USB2_UTMI_W == LPARA_W16);
  assign w_first = w_v0 & ~reg_got_pid;
  assign w_eop   = reg_act_d & ~w_in_active;

  always_comb begin : p_com_lane
    w_pay_n  = 2'd0;
    w_pay_b0 = w_in_data[7:0];
    w_pay_b1 = w_in_data[15:8];
    case ({w_first, w_v1, w_v0})
      3'b011:  w_pay_n = 2'd2;
      3'b001:  w_pay_n = 2'd1;
      3'b111: begin
        w_pay_n  = 2'd1;
        w_pay_b0 = w_in_data[15:8];
      end
      default: w_pay_n = 2'd0;
    endcase
  end

  // State of stage A: previous activity and whether the PID of this packet was seen.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_a
    if (!i_rst_n_core) begin
      reg_act_d   <= 1'b0;
      reg_got_pid <= 1'b0;
    end else begin
      reg_act_d <= w_in_active;
      if (w_eop)
        reg_got_pid <= 1'b0;
      else if (w_first)
        reg_got_pid <= 1'b1;
    end
  end

  // Optional stage S between extraction and processing (timing option for the CRC).
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_s
    if (!i_rst_n_core) begin
      reg_s_sop <= 1'b0;
      reg_s_pid <= 8'h00;
      reg_s_n   <= 2'd0;
      reg_s_b0  <= 8'h00;
      reg_s_b1  <= 8'h00;
      reg_s_eop <= 1'b0;
      reg_s_err <= 1'b0;
    end else begin
      reg_s_sop <= w_first;
      reg_s_pid <= w_in_data[7:0];
      reg_s_n   <= w_pay_n;
      reg_s_b0  <= w_pay_b0;
      reg_s_b1  <= w_pay_b1;
      reg_s_eop <= w_eop;
      reg_s_err <= w_in_err;
    end
  end

  assign w_s_sop = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_sop : w_first;
  assign w_s_pid = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_pid : w_in_data[7:0];
  assign w_s_n   = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_n : w_pay_n;
  assign w_s_b0  = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_b0 : w_pay_b0;
  assign w_s_b1  = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_b1 : w_pay_b1;
  assign w_s_eop = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_eop : w_eop;
  assign w_s_err = (PARA_USB2_PIPE_CRC != 32'd0) ? reg_s_err : w_in_err;

  // Classification of the PID byte: the high nibble must be the complement of the low nibble.
  assign w_pid_ok = (w_s_pid[3:0] == ~w_s_pid[7:4]);

  always_comb begin : p_com_cls
    w_cls_nxt = LPARA_CLS_NONE[2:0];
    if (reg_ext_pend) begin
      w_cls_nxt = LPARA_CLS_ETK[2:0];
    end else begin
      case (w_s_pid[3:0])
        LPARA_PID_OUT[3:0], LPARA_PID_IN[3:0], LPARA_PID_SETUP[3:0],
        LPARA_PID_SOF[3:0], LPARA_PID_PING[3:0]:
          w_cls_nxt = LPARA_CLS_TOK[2:0];
        LPARA_PID_SPLIT[3:0]:
          w_cls_nxt = LPARA_CLS_SPLIT[2:0];
        LPARA_PID_EXT[3:0]:
          w_cls_nxt = LPARA_CLS_EXT[2:0];
        LPARA_PID_DATA0[3:0], LPARA_PID_DATA1[3:0], LPARA_PID_DATA2[3:0], LPARA_PID_MDATA[3:0]:
          w_cls_nxt = LPARA_CLS_DATA[2:0];
        LPARA_PID_ACK[3:0], LPARA_PID_NAK[3:0], LPARA_PID_STALL[3:0], LPARA_PID_NYET[3:0],
        LPARA_PID_ERR[3:0]:
          w_cls_nxt = LPARA_CLS_HS[2:0];
        default: w_cls_nxt = LPARA_CLS_NONE[2:0];
      endcase
    end
    if (!w_pid_ok)
      w_cls_nxt = LPARA_CLS_NONE[2:0];
  end

  // Bases of the running values: a new packet starts from the initial values in the same cycle.
  assign w_data_cls    = (reg_cls == LPARA_CLS_DATA[2:0]);
  assign w_cnt_base    = w_s_sop ? '0 : reg_cnt;
  assign w_crc_base    = w_s_sop ? LPARA_CRC16_SEED[15:0] : reg_crc;
  assign w_pay_cnt_sum = {11'd0, w_s_n};
  assign w_cnt_fin     = (w_cnt_base > (LPARA_CNT_MAX[LPARA_CNT_W-1:0] - w_pay_cnt_sum)) ?
                         LPARA_CNT_MAX[LPARA_CNT_W-1:0] : (w_cnt_base + w_pay_cnt_sum);

  // CRC16 update over the payload bytes of this cycle (the CRC bytes are included).
  m_usb2_crc16 #(
    .PARA_USB2_CRC_BYTES (LPARA_CRC_TWO)
  ) u_crc16_rx (
    .i_crc         (w_crc_base),
    .i_data        ({w_s_b1, w_s_b0}),
    .i_high_en     (w_s_n == 2'd2),
    .o_crc_nxt     (w_crc_nxt),
    .o_residual_ok (),
    .o_tx_lo       (),
    .o_tx_hi       ()
  );

  assign w_crc_fin = (w_s_n != 2'd0) ? w_crc_nxt : w_crc_base;

  // Header bytes of tokens: the first three payload bytes of the packet.
  always_comb begin : p_com_hdr
    w_h0 = w_s_sop ? 8'h00 : reg_h0;
    w_h1 = w_s_sop ? 8'h00 : reg_h1;
    w_h2 = w_s_sop ? 8'h00 : reg_h2;
    if (w_s_n != 2'd0) begin
      case (w_cnt_base[1:0])
        2'd0: begin
          w_h0 = w_s_b0;
          if (w_s_n == 2'd2)
            w_h1 = w_s_b1;
        end
        2'd1: begin
          w_h1 = w_s_b0;
          if (w_s_n == 2'd2)
            w_h2 = w_s_b1;
        end
        2'd2: w_h2 = w_s_b0;
        default: begin
          // Bytes beyond the third are not header bytes.
        end
      endcase
    end
  end

  // CRC5 of the token (11 bits) and of the split token (19 bits).
  m_usb2_crc5 #(
    .PARA_USB2_CRC5_W (LPARA_CRC5_TOK_W)
  ) u_crc5_tok (
    .i_data ({w_h1[2:0], w_h0}),
    .o_crc  (w_crc5_tok)
  );

  m_usb2_crc5 #(
    .PARA_USB2_CRC5_W (LPARA_CRC5_SPL_W)
  ) u_crc5_spl (
    .i_data ({w_h2[2:0], w_h1, w_h0}),
    .o_crc  (w_crc5_spl)
  );

  // Delay line of two bytes: the window is the held bytes followed by the new bytes; all but the
  // last two bytes leave, the last two stay.
  always_comb begin : p_com_win
    w_bn     = w_s_sop ? 2'd0 : reg_buf_n;
    w_buf_m  = 16'h0000;
    w_win    = {16'h0000, w_s_b1, w_s_b0};
    w_win    = w_win << (8 * w_bn);
    case (w_bn)
      2'd0:    w_buf_m = 16'h0000;
      2'd1:    w_buf_m = {8'h00, reg_buf[7:0]};
      default: w_buf_m = reg_buf;
    endcase
    w_win    = w_win | {16'h0000, w_buf_m};
    w_tot    = {1'b0, w_bn} + {1'b0, w_s_n};
    w_out_n  = (w_tot > 3'd2) ? (w_tot - 3'd2) : 3'd0;
    w_win_sh = w_win >> (8 * w_out_n);
  end

  // Processing state: class, PID, counters, CRC, header bytes and the delay line.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_b
    if (!i_rst_n_core) begin
      reg_cls      <= LPARA_CLS_NONE[2:0];
      reg_pid      <= 4'h0;
      reg_pid_ok   <= 1'b0;
      reg_ext_pend <= 1'b0;
      // Reset in the only process that writes it (2026-11-24, lint MULTIDRIVEN: the reset
      // was in p_ff_out).
      reg_tok_efld <= '0;
      reg_etk      <= 1'b0;
      reg_in_pkt   <= 1'b0;
      reg_err_seen <= 1'b0;
      reg_cnt      <= '0;
      reg_crc      <= LPARA_CRC16_SEED[15:0];
      reg_h0       <= 8'h00;
      reg_h1       <= 8'h00;
      reg_h2       <= 8'h00;
      reg_buf      <= 16'h0000;
      reg_buf_n    <= 2'd0;
    end else begin
      if (w_s_sop) begin
        reg_cls    <= w_cls_nxt;
        reg_pid    <= w_s_pid[3:0];
        reg_pid_ok <= w_pid_ok;
        reg_etk    <= reg_ext_pend;
        reg_in_pkt <= 1'b1;
        reg_err_seen <= w_s_err;
      end else if (w_s_err) begin
        reg_err_seen <= 1'b1;
      end
      reg_cnt   <= w_cnt_fin;
      reg_crc   <= w_crc_fin;
      reg_h0    <= w_h0;
      reg_h1    <= w_h1;
      reg_h2    <= w_h2;
      reg_buf   <= w_win_sh[15:0];
      reg_buf_n <= w_tot[1:0] - w_out_n[1:0];
      if (w_s_sop & reg_ext_pend)
        reg_ext_pend <= 1'b0;
      if (w_s_eop) begin
        reg_in_pkt <= 1'b0;
        if (reg_cls == LPARA_CLS_EXT[2:0] && reg_pid_ok && w_cnt_fin == 13'd2 &&
            w_crc5_tok == w_h1[7:3]) begin
          reg_ext_pend <= 1'b1;
          reg_tok_efld <= {w_h1[2:0], w_h0};
        end
      end
    end
  end

  // Registered outputs: events at the end of the packet and the payload stream.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_out
    if (!i_rst_n_core) begin
      reg_tok_vld    <= 1'b0;
      reg_tok_ext    <= 1'b0;
      reg_tok_pid    <= 4'h0;
      reg_tok_fld    <= '0;
      reg_spl_vld    <= 1'b0;
      reg_hs_vld     <= 1'b0;
      reg_hs_pid     <= 4'h0;
      reg_dat_sop    <= 1'b0;
      reg_dat_pid    <= 4'h0;
      reg_dat_n      <= 2'd0;
      reg_dat_b      <= 16'h0000;
      reg_dat_end    <= 1'b0;
      reg_dat_ok     <= 1'b0;
      reg_dat_len    <= '0;
      reg_err_pid    <= 1'b0;
      reg_err_crc    <= 1'b0;
      reg_err_stuf   <= 1'b0;
      reg_err_babble <= 1'b0;
    end else begin
      reg_tok_vld    <= 1'b0;
      reg_spl_vld    <= 1'b0;
      reg_hs_vld     <= 1'b0;
      reg_dat_sop    <= 1'b0;
      reg_dat_end    <= 1'b0;
      reg_err_pid    <= 1'b0;
      reg_err_crc    <= 1'b0;
      reg_err_stuf   <= 1'b0;
      reg_err_babble <= 1'b0;
      reg_dat_n      <= 2'd0;
      if (w_s_sop & (w_cls_nxt == LPARA_CLS_DATA[2:0])) begin
        reg_dat_sop <= 1'b1;
        reg_dat_pid <= w_s_pid[3:0];
      end
      if (w_s_sop & ~w_pid_ok)
        reg_err_pid <= 1'b1;
      if (w_data_cls | (w_s_sop & (w_cls_nxt == LPARA_CLS_DATA[2:0]))) begin
        reg_dat_n <= w_out_n[1:0];
        reg_dat_b <= w_win[15:0];
      end
      if (w_s_eop & (reg_in_pkt | w_s_sop)) begin
        reg_tok_pid  <= reg_pid;
        reg_tok_ext  <= reg_etk;
        reg_tok_fld  <= {w_h1[2:0], w_h0};
        reg_hs_pid   <= reg_pid;
        reg_dat_len  <= (w_cnt_fin > 13'd2) ? (w_cnt_fin[11:0] - 12'd2) : 12'd0;
        reg_err_stuf <= reg_err_seen | w_s_err;
        case (reg_cls)
          LPARA_CLS_TOK[2:0], LPARA_CLS_ETK[2:0]: begin
            if (w_cnt_fin == 13'd2 && w_crc5_tok == w_h1[7:3])
              reg_tok_vld <= ~(reg_err_seen | w_s_err);
            else
              reg_err_crc <= 1'b1;
          end
          LPARA_CLS_SPLIT[2:0]: begin
            if (w_cnt_fin == 13'd3 && w_crc5_spl == w_h2[7:3])
              reg_spl_vld <= ~(reg_err_seen | w_s_err);
            else
              reg_err_crc <= 1'b1;
          end
          LPARA_CLS_HS[2:0]: begin
            if (w_cnt_fin == 13'd0)
              reg_hs_vld <= ~(reg_err_seen | w_s_err);
            else
              reg_err_crc <= 1'b1;
          end
          LPARA_CLS_DATA[2:0]: begin
            reg_dat_end <= 1'b1;
            reg_dat_ok  <= (w_cnt_fin >= 13'd2) & (w_crc_fin == LPARA_CRC16_RES[15:0]) &
                         ~(reg_err_seen | w_s_err);
            if (w_cnt_fin > LPARA_MAX_PAY[LPARA_CNT_W-1:0])
              reg_err_babble <= 1'b1;
            else if (w_crc_fin != LPARA_CRC16_RES[15:0])
              reg_err_crc <= 1'b1;
          end
          LPARA_CLS_EXT[2:0]: begin
            reg_tok_vld <= 1'b0;
          end
          default: begin
            reg_tok_vld <= 1'b0;
          end
        endcase
      end
    end
  end

  // Busy while a packet is on the bus or in the pipeline.
  assign o_rx_busy = w_in_active | reg_act_d | reg_in_pkt;

  // Registered outputs.
  assign o_tok_vld = reg_tok_vld;
  assign o_tok_ext = reg_tok_ext;
  assign o_tok_efld = reg_tok_efld;
  assign o_tok_pid = reg_tok_pid;
  assign o_tok_fld = reg_tok_fld;
  assign o_spl_vld = reg_spl_vld;
  assign o_hs_vld = reg_hs_vld;
  assign o_hs_pid = reg_hs_pid;
  assign o_dat_sop = reg_dat_sop;
  assign o_dat_pid = reg_dat_pid;
  assign o_dat_n = reg_dat_n;
  assign o_dat_b = reg_dat_b;
  assign o_dat_end = reg_dat_end;
  assign o_dat_ok = reg_dat_ok;
  assign o_dat_len = reg_dat_len;
  assign o_err_pid = reg_err_pid;
  assign o_err_crc = reg_err_crc;
  assign o_err_stuf = reg_err_stuf;
  assign o_err_babble = reg_err_babble;

endmodule
