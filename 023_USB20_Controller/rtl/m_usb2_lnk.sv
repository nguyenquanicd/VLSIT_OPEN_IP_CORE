/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Link layer of the USB 2.0 controller (section 5, FEAT-001, FEAT-022, DEC-005).
 *                It holds the packet receiver and the packet transmitter and the loopback of
 *                u2_ctrl.lpbk: with lpbk set the transmit stream is fed back into the receiver,
 *                the PHY pins stay idle and two counters (good and bad packets, 12 bit) run
 *                until the clear pulse (ASM-023, OP-022). Without loopback the module passes the
 *                streams between the PHY interface and the engines.
 */
`timescale 1ns/1ps

module m_usb2_lnk #(
  // Parameter Description: UTMI+ data width; selects one or two byte lanes.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: 1 adds a register stage on the PHY receive inputs (timing option).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_RX = 0,
  // Parameter Description: 1 adds a register stage before the CRC16 and field processing.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_CRC = 0,
  localparam logic [31:0] LPARA_CNT_W = 12,
  localparam logic [31:0] LPARA_ONE   = 1
) (
  // Clock and reset
  input  wire         i_clk_phy,
  input  wire         i_rst_n_core,

  // Stream from and to the PHY interface
  input  wire  [15:0] i_phy_rx_data,
  input  wire  [1:0]  i_phy_rx_valid,
  input  wire         i_phy_rx_active,
  input  wire         i_phy_rx_err,
  output logic [15:0] o_phy_tx_data,
  output logic [1:0]  o_phy_tx_valid,
  input  wire         i_phy_tx_ready,
  input  wire         i_phy_tx_abort,

  // Loopback control and counters
  input  wire         i_lpbk,
  input  wire         i_lpbk_clr,
  output logic [11:0] o_lpbk_ok,
  output logic [11:0] o_lpbk_err,

  // Receive events to the engines
  output logic        o_tok_vld,
  output logic        o_tok_ext,
  output logic [10:0] o_tok_efld,
  output logic [3:0]  o_tok_pid,
  output logic [10:0] o_tok_fld,
  output logic        o_spl_vld,
  output logic [18:0] o_spl_fld,
  output logic        o_hs_vld,
  output logic [3:0]  o_hs_pid,
  output logic        o_dat_sop,
  output logic [3:0]  o_dat_pid,
  output logic [1:0]  o_dat_n,
  output logic [15:0] o_dat_b,
  output logic        o_dat_end,
  output logic        o_dat_ok,
  output logic [11:0] o_dat_len,
  output logic        o_err_pid,
  output logic        o_err_crc,
  output logic        o_err_stuf,
  output logic        o_err_babble,
  output logic        o_rx_busy,
  output logic        o_pkt_end,

  // Transmit request from the engines and payload source
  input  wire         i_tx_req,
  input  wire  [2:0]  i_tx_kind,
  input  wire  [3:0]  i_tx_pid,
  input  wire  [18:0] i_tx_fld,
  input  wire  [11:0] i_tx_len,
  input  wire  [15:0] i_src_dat,
  input  wire         i_src_vld,
  output logic        o_src_pop,
  output logic        o_tx_busy,
  output logic        o_tx_starve,
  output logic        o_tx_done,
  output logic        o_tx_fail,
  output logic        o_link_idle
);

  // Internal signal declarations
  logic [15:0]           w_tx_data;
  logic [1:0]            w_tx_valid;
  logic                  w_tx_ready;
  logic [15:0]           w_rx_data;
  logic [1:0]            w_rx_valid;
  logic                  w_rx_active;
  logic                  w_rx_err;
  logic                  w_tx_done;
  logic                  w_good;
  logic                  w_bad;
  logic                  w_tok_vld;
  logic                  w_spl_vld;
  logic                  w_hs_vld;
  logic                  w_dat_end;
  logic                  w_dat_ok;
  logic                  w_err_pid;
  logic                  w_err_crc;
  logic                  w_err_stuf;
  logic                  w_err_babble;
  logic                  w_rx_busy;
  logic                  w_tx_busy;
  logic [LPARA_CNT_W-1:0] reg_ok_cnt;
  logic [LPARA_CNT_W-1:0] reg_err_cnt;

  // Loopback multiplexer: with lpbk the transmit words (accepted ones only) become the receive
  // stream and the PHY sees an idle transmitter; the internal ready is always 1.
  assign w_tx_ready      = i_lpbk ? 1'b1 : i_phy_tx_ready;
  assign o_phy_tx_data   = w_tx_data;
  assign o_phy_tx_valid  = i_lpbk ? 2'b00 : w_tx_valid;
  assign w_rx_data       = i_lpbk ? w_tx_data : i_phy_rx_data;
  assign w_rx_valid      = i_lpbk ? w_tx_valid : i_phy_rx_valid;
  assign w_rx_active     = i_lpbk ? w_tx_valid[0] : i_phy_rx_active;
  assign w_rx_err        = i_lpbk ? 1'b0 : i_phy_rx_err;

  // Packet receiver.
  m_usb2_lnkrx #(
    .PARA_USB2_PIPE_RX  (PARA_USB2_PIPE_RX),
    .PARA_USB2_PIPE_CRC (PARA_USB2_PIPE_CRC),
    .PARA_USB2_UTMI_W   (PARA_USB2_UTMI_W)
  ) u_rx (
    .i_clk_phy    (i_clk_phy),
    .i_rst_n_core (i_rst_n_core),
    .i_rx_data    (w_rx_data),
    .i_rx_valid   (w_rx_valid),
    .i_rx_active  (w_rx_active),
    .i_rx_err     (w_rx_err),
    .o_tok_vld    (w_tok_vld),
    .o_tok_ext    (o_tok_ext),
    .o_tok_efld   (o_tok_efld),
    .o_tok_pid    (o_tok_pid),
    .o_tok_fld    (o_tok_fld),
    .o_spl_vld    (w_spl_vld),
    .o_spl_fld    (o_spl_fld),
    .o_hs_vld     (w_hs_vld),
    .o_hs_pid     (o_hs_pid),
    .o_dat_sop    (o_dat_sop),
    .o_dat_pid    (o_dat_pid),
    .o_dat_n      (o_dat_n),
    .o_dat_b      (o_dat_b),
    .o_dat_end    (w_dat_end),
    .o_dat_ok     (w_dat_ok),
    .o_dat_len    (o_dat_len),
    .o_err_pid    (w_err_pid),
    .o_err_crc    (w_err_crc),
    .o_err_stuf   (w_err_stuf),
    .o_err_babble (w_err_babble),
    .o_rx_busy    (w_rx_busy),
    .o_pkt_end    (o_pkt_end)
  );

  // Packet transmitter.
  m_usb2_lnktx #(
    .PARA_USB2_UTMI_W (PARA_USB2_UTMI_W)
  ) u_tx (
    .i_clk_phy    (i_clk_phy),
    .i_rst_n_core (i_rst_n_core),
    .i_tx_req     (i_tx_req),
    .i_tx_kind    (i_tx_kind),
    .i_tx_pid     (i_tx_pid),
    .i_tx_fld     (i_tx_fld),
    .i_tx_len     (i_tx_len),
    .i_src_dat    (i_src_dat),
    .i_src_vld    (i_src_vld),
    .o_src_pop    (o_src_pop),
    .o_tx_busy    (w_tx_busy),
    .o_starve     (o_tx_starve),
    .o_tx_done    (w_tx_done),
    .o_tx_fail    (o_tx_fail),
    .o_tx_data    (w_tx_data),
    .o_tx_valid   (w_tx_valid),
    .i_tx_ready   (w_tx_ready),
    .i_tx_abort   (i_phy_tx_abort)
  );

  // Event outputs and busy flags.
  assign o_tok_vld    = w_tok_vld;
  assign o_spl_vld    = w_spl_vld;
  assign o_hs_vld     = w_hs_vld;
  assign o_dat_end    = w_dat_end;
  assign o_dat_ok     = w_dat_ok;
  assign o_err_pid    = w_err_pid;
  assign o_err_crc    = w_err_crc;
  assign o_err_stuf   = w_err_stuf;
  assign o_err_babble = w_err_babble;
  assign o_rx_busy    = w_rx_busy;
  assign o_tx_busy    = w_tx_busy;
  assign o_tx_done    = w_tx_done;
  assign o_link_idle  = ~w_rx_busy & ~w_tx_busy & ~i_tx_req;

  // Packet classification for the loopback counters: a good packet is a token, split token,
  // handshake or data packet with a good CRC; a bad packet is any error or a data packet with
  // a failed CRC.
  assign w_good = w_tok_vld | w_spl_vld | w_hs_vld | (w_dat_end & w_dat_ok);
  assign w_bad  = w_err_pid | w_err_crc | w_err_stuf | w_err_babble | (w_dat_end & ~w_dat_ok);

  // Loopback counters, saturating at the maximum and cleared by the clear pulse.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_core) begin : p_ff_lpbk
    if (!i_rst_n_core) begin
      reg_ok_cnt  <= '0;
      reg_err_cnt <= '0;
    end else if (i_lpbk_clr) begin
      reg_ok_cnt  <= '0;
      reg_err_cnt <= '0;
    end else begin
      if (w_good & (reg_ok_cnt != '1))
        reg_ok_cnt <= reg_ok_cnt + LPARA_ONE[LPARA_CNT_W-1:0];
      if (w_bad & (reg_err_cnt != '1))
        reg_err_cnt <= reg_err_cnt + LPARA_ONE[LPARA_CNT_W-1:0];
    end
  end

  assign o_lpbk_ok  = reg_ok_cnt;
  assign o_lpbk_err = reg_err_cnt;

endmodule
