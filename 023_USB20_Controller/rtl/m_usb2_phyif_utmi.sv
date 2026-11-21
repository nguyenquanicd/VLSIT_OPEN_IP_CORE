/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : UTMI+ link-side adapter (section 6.3, FEAT-002, REQ-IF-002, DEC-003). The
 *                receive pins and the line state are passed to the link, optionally through one
 *                register stage (PARA_USB2_PIPE_PHY_IN). The transmit pins are driven straight
 *                from the flops of the link, so TXValid and the data hold until TXReady with no
 *                extra cycle. The mode controls of the speed engine drive XcvrSelect,
 *                TermSelect, OpMode and the pull-downs and VBUS controls. In 8-bit mode the high
 *                byte is 0 and TXValidH is 0.
 */
`timescale 1ns/1ps

module m_usb2_phyif_utmi #(
  // Parameter Description: UTMI+ data width in bits.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: 1 registers the receive pins and the line state (timing option).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_PHY_IN = 0,
  localparam logic [31:0] LPARA_W16 = 16
) (
  // Clock and reset
  input  wire         i_clk_phy,
  input  wire         i_rst_n_phy,

  // UTMI+ transmit pins
  output logic [15:0] o_utmi_dataout,
  output logic        o_utmi_txvalid,
  output logic        o_utmi_txvalidh,
  input  wire         i_utmi_txready,

  // UTMI+ receive pins and line state
  input  wire  [15:0] i_utmi_datain,
  input  wire         i_utmi_rxvalid,
  input  wire         i_utmi_rxvalidh,
  input  wire         i_utmi_rxactive,
  input  wire         i_utmi_rxerror,
  input  wire  [1:0]  i_utmi_linestate,

  // UTMI+ mode and power pins
  output logic [1:0]  o_utmi_opmode,
  output logic [1:0]  o_utmi_xcvrsel,
  output logic        o_utmi_termsel,
  output logic        o_utmi_suspend_n,
  output logic        o_utmi_databus16_8,
  output logic        o_utmi_bitstuff_en,
  output logic        o_utmi_bitstuff_en_h,
  output logic        o_utmi_dppulldown,
  output logic        o_utmi_dmpulldown,
  output logic        o_utmi_drvvbus,
  output logic        o_utmi_chrgvbus,
  output logic        o_utmi_dischrgvbus,
  output logic        o_utmi_idpullup,

  // UTMI+ status pins
  input  wire         i_utmi_hostdisc,
  input  wire         i_utmi_iddig,
  input  wire         i_utmi_avalid,
  input  wire         i_utmi_bvalid,
  input  wire         i_utmi_vbusvalid,
  input  wire         i_utmi_sessend,

  // Link transmit stream
  input  wire  [15:0] i_tx_data,
  input  wire  [1:0]  i_tx_valid,
  output logic        o_tx_ready,

  // Link receive stream and line state
  output logic [15:0] o_rx_data,
  output logic [1:0]  o_rx_valid,
  output logic        o_rx_active,
  output logic        o_rx_err,
  output logic [1:0]  o_linestate,

  // Mode controls from the speed engine
  input  wire  [1:0]  i_xcvr_sel,
  input  wire         i_term_sel,
  input  wire  [1:0]  i_op_mode,
  input  wire         i_suspend_n,
  input  wire         i_dp_pd,
  input  wire         i_dm_pd,
  input  wire         i_drv_vbus,
  input  wire         i_chrg_vbus,
  input  wire         i_dischrg_vbus,
  input  wire         i_id_pullup,

  // Status to the speed engine
  output logic        o_hostdisc,
  output logic        o_iddig,
  output logic        o_avalid,
  output logic        o_bvalid,
  output logic        o_vbusvalid,
  output logic        o_sessend
);

  // Internal signal declarations
  logic [15:0] reg_rx_data;
  logic [1:0]  reg_rx_valid;
  logic        reg_rx_active;
  logic        reg_rx_err;
  logic [1:0]  reg_linestate;
  logic [15:0] w_rx_data;
  logic [1:0]  w_rx_valid;
  logic        w_wide;

  // 16-bit mode selects the high byte lane and its valid and ready qualification.
  assign w_wide = (PARA_USB2_UTMI_W == LPARA_W16) ? 1'b1 : 1'b0;

  // Receive lanes: the high lane is forced to 0 in 8-bit mode.
  assign w_rx_data = w_wide ? i_utmi_datain : {8'h00, i_utmi_datain[7:0]};
  assign w_rx_valid = {i_utmi_rxvalidh & w_wide, i_utmi_rxvalid};

  // Optional register stage of the receive pins.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_rx
    if (!i_rst_n_phy) begin
      reg_rx_data   <= '0;
      reg_rx_valid  <= '0;
      reg_rx_active <= 1'b0;
      reg_rx_err  <= 1'b0;
      reg_linestate <= '0;
    end else begin
      reg_rx_data   <= w_rx_data;
      reg_rx_valid  <= w_rx_valid;
      reg_rx_active <= i_utmi_rxactive;
      reg_rx_err  <= i_utmi_rxerror;
      reg_linestate <= i_utmi_linestate;
    end
  end

  // Receive outputs to the link, with or without the register stage.
  assign o_rx_data   = (PARA_USB2_PIPE_PHY_IN != 32'd0) ? reg_rx_data : w_rx_data;
  assign o_rx_valid  = (PARA_USB2_PIPE_PHY_IN != 32'd0) ? reg_rx_valid : w_rx_valid;
  assign o_rx_active = (PARA_USB2_PIPE_PHY_IN != 32'd0) ? reg_rx_active : i_utmi_rxactive;
  assign o_rx_err  = (PARA_USB2_PIPE_PHY_IN != 32'd0) ? reg_rx_err : i_utmi_rxerror;
  assign o_linestate = (PARA_USB2_PIPE_PHY_IN != 32'd0) ? reg_linestate : i_utmi_linestate;

  // Transmit pins follow the link flops; TXReady goes straight back to the link.
  assign o_utmi_dataout  = w_wide ? i_tx_data : {8'h00, i_tx_data[7:0]};
  assign o_utmi_txvalid  = i_tx_valid[0];
  assign o_utmi_txvalidh = i_tx_valid[1] & w_wide;
  assign o_tx_ready      = i_utmi_txready;

  // Mode and power pins come from flops of the speed engine; bit stuffing stays enabled.
  assign o_utmi_opmode        = i_op_mode;
  assign o_utmi_xcvrsel       = i_xcvr_sel;
  assign o_utmi_termsel       = i_term_sel;
  assign o_utmi_suspend_n     = i_suspend_n;
  assign o_utmi_databus16_8   = w_wide;
  assign o_utmi_bitstuff_en   = 1'b1;
  assign o_utmi_bitstuff_en_h = w_wide;
  assign o_utmi_dppulldown    = i_dp_pd;
  assign o_utmi_dmpulldown    = i_dm_pd;
  assign o_utmi_drvvbus       = i_drv_vbus;
  assign o_utmi_chrgvbus      = i_chrg_vbus;
  assign o_utmi_dischrgvbus   = i_dischrg_vbus;
  assign o_utmi_idpullup      = i_id_pullup;

  // Status pins to the speed engine.
  assign o_hostdisc  = i_utmi_hostdisc;
  assign o_iddig     = i_utmi_iddig;
  assign o_avalid    = i_utmi_avalid;
  assign o_bvalid    = i_utmi_bvalid;
  assign o_vbusvalid = i_utmi_vbusvalid;
  assign o_sessend   = i_utmi_sessend;

endmodule
