/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Wrapper of the USB 2.0 controller with ULPI PHY pins and the AXI4 slave with
 *                DMA handshake (section 6.2, ASM-002). The wrapper fixes the interface
 *                parameters of the core and ties off the pins of the interfaces that this build
 *                does not have. It holds one instance and nothing else.
 */
`timescale 1ns/1ps

module m_usb2_top_ulpi_axis #(
  // Parameter Description: role: 0 device, 1 host, 2 dual-role by the ID pin.
  // Parameter values: 0, 1 or 2; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_ROLE = 2,
  // Parameter Description: device endpoints besides EP0.
  // Parameter values: 1 to 15; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NUM_EP = 8,
  // Parameter Description: host channels.
  // Parameter values: 1 to 16; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NUM_HC = 8,
  // Parameter Description: FIFO RAM depth in 32-bit words.
  // Parameter values: power of two, 256 to 32768; default is 1024.
  // Parameter unit: word
  parameter logic [31:0] PARA_USB2_FIFO_DEPTH = 1024,
  // Parameter Description: LPM L1 support.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_LPM_EN = 0,
  // Parameter Description: host split transactions.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_SPLIT_EN = 0,
  // Parameter Description: AXI address width.
  // Parameter values: 32, 40 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_ADDR_W = 32,
  // Parameter Description: AXI data width, four times the UTMI+ width (DEC-010).
  // Parameter values: 32 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_DATA_W = 32,
  // Parameter Description: AXI ID width.
  // Parameter values: 1 to 8; default is 4.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_ID_W = 4,
  // Parameter Description: external DMA handshake channels.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NUM_DMA_CH = 4,
  // Parameter Description: double-buffered status bit of endpoints and channels.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_DBUF_EN = 1,
  // Parameter Description: scatter-gather descriptor engine of the AXI master DMA (DEC-013).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_SG_EN = 0,
  // Parameter Description: one parity bit per FIFO RAM row.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_RAM_PAR_EN = 1,
  // Parameter Description: single-port serialization of the FIFO RAM accesses.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_RAM_1P = 0,
  // Parameter Description: register stage on the UTMI+ receive pins.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_PHY_IN = 0,
  // Parameter Description: register stage on the PHY inputs of the link.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_RX = 0,
  // Parameter Description: register stage before the CRC16 and field processing.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_CRC = 0,
  // Parameter Description: register stage on the PHY mode outputs of the speed engine.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_MODE = 0,
  // Parameter Description: register slice on the AXI4 slave read data channel.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_AXS = 0,
  // Parameter Description: register stage on the shadow words of CLK-PHY.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_XREG = 0,
  // Parameter Description: divider of the timers, simulation only (must be 1 in a netlist).
  // Parameter values: 1, 16, 256 or 4096; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_TSCALE = 1
) (
  // Clocks and resets
  input  wire                               i_clk_phy,
  input  wire                               i_clk_bus,
  input  wire                               i_rst_n_phy,
  input  wire                               i_rst_n_bus,
  output logic                              o_phy_rst_n,

  // APB4 slave of the CSR
  input  wire  [15:0]                       i_apb_paddr,
  input  wire  [31:0]                       i_apb_pwdata,
  input  wire                               i_apb_pwrite,
  input  wire                               i_apb_penable,
  input  wire                               i_apb_psel,
  input  wire  [3:0]                        i_apb_pstrb,
  input  wire  [2:0]                        i_apb_pprot,
  output logic                              o_apb_pready,
  output logic                              o_apb_pslverr,
  output logic [31:0]                       o_apb_prdata,
  input  wire                               i_protect_en,
  input  wire                               i_slverr_en,

  // Power switch, test and interrupt
  input  wire                               i_ovrcur_n,
  output logic                              o_vbus_pwr_en,
  input  wire                               i_dft_test_en,
  input  wire                               i_dft_scan_en,
  output logic                              o_int_usb,

  // PHY interface
  input  wire                               i_ulpi_dir,
  input  wire                               i_ulpi_nxt,
  output logic                              o_ulpi_stp,
  input  wire  [7:0]                        i_ulpi_data,
  output logic [7:0]                        o_ulpi_data,
  output logic                              o_ulpi_data_oe,

  // Data interface
  input  wire  [PARA_USB2_AXI_ID_W-1:0]     i_axis_awid,
  input  wire  [PARA_USB2_AXI_ADDR_W-1:0]   i_axis_awaddr,
  input  wire  [7:0]                        i_axis_awlen,
  input  wire  [2:0]                        i_axis_awsize,
  input  wire  [1:0]                        i_axis_awburst,
  input  wire                               i_axis_awvalid,
  output logic                              o_axis_awready,
  input  wire  [PARA_USB2_AXI_DATA_W-1:0]   i_axis_wdata,
  input  wire  [PARA_USB2_AXI_DATA_W/8-1:0] i_axis_wstrb,
  input  wire                               i_axis_wlast,
  input  wire                               i_axis_wvalid,
  output logic                              o_axis_wready,
  output logic [PARA_USB2_AXI_ID_W-1:0]     o_axis_bid,
  output logic [1:0]                        o_axis_bresp,
  output logic                              o_axis_bvalid,
  input  wire                               i_axis_bready,
  input  wire  [PARA_USB2_AXI_ID_W-1:0]     i_axis_arid,
  input  wire  [PARA_USB2_AXI_ADDR_W-1:0]   i_axis_araddr,
  input  wire  [7:0]                        i_axis_arlen,
  input  wire  [2:0]                        i_axis_arsize,
  input  wire  [1:0]                        i_axis_arburst,
  input  wire                               i_axis_arvalid,
  output logic                              o_axis_arready,
  output logic [PARA_USB2_AXI_ID_W-1:0]     o_axis_rid,
  output logic [PARA_USB2_AXI_DATA_W-1:0]   o_axis_rdata,
  output logic [1:0]                        o_axis_rresp,
  output logic                              o_axis_rlast,
  output logic                              o_axis_rvalid,
  input  wire                               i_axis_rready,
  output logic [PARA_USB2_NUM_DMA_CH-1:0]   o_dma_req,
  input  wire  [PARA_USB2_NUM_DMA_CH-1:0]   i_dma_ack
);

  // Core with the fixed interface selection; the pins of the other interfaces are tied off.
  m_usb2_core #(
    .PARA_USB2_ROLE (PARA_USB2_ROLE),
    .PARA_USB2_PHY_IF (32'd1),
    .PARA_USB2_UTMI_W (32'd8),
    .PARA_USB2_DATA_IF (32'd1),
    .PARA_USB2_NUM_EP (PARA_USB2_NUM_EP),
    .PARA_USB2_NUM_HC (PARA_USB2_NUM_HC),
    .PARA_USB2_FIFO_DEPTH (PARA_USB2_FIFO_DEPTH),
    .PARA_USB2_LPM_EN (PARA_USB2_LPM_EN),
    .PARA_USB2_SPLIT_EN (PARA_USB2_SPLIT_EN),
    .PARA_USB2_AXI_ADDR_W (PARA_USB2_AXI_ADDR_W),
    .PARA_USB2_AXI_DATA_W (PARA_USB2_AXI_DATA_W),
    .PARA_USB2_AXI_ID_W (PARA_USB2_AXI_ID_W),
    .PARA_USB2_NUM_DMA_CH (PARA_USB2_NUM_DMA_CH),
    .PARA_USB2_DBUF_EN (PARA_USB2_DBUF_EN),
    .PARA_USB2_SG_EN (PARA_USB2_SG_EN),
    .PARA_USB2_RAM_PAR_EN (PARA_USB2_RAM_PAR_EN),
    .PARA_USB2_RAM_1P (PARA_USB2_RAM_1P),
    .PARA_USB2_PIPE_PHY_IN (PARA_USB2_PIPE_PHY_IN),
    .PARA_USB2_PIPE_RX (PARA_USB2_PIPE_RX),
    .PARA_USB2_PIPE_CRC (PARA_USB2_PIPE_CRC),
    .PARA_USB2_PIPE_MODE (PARA_USB2_PIPE_MODE),
    .PARA_USB2_PIPE_AXS (PARA_USB2_PIPE_AXS),
    .PARA_USB2_PIPE_XREG (PARA_USB2_PIPE_XREG),
    .PARA_USB2_TSCALE (PARA_USB2_TSCALE)
  ) u_core (
    .i_clk_phy (i_clk_phy),
    .i_clk_bus (i_clk_bus),
    .i_rst_n_phy (i_rst_n_phy),
    .i_rst_n_bus (i_rst_n_bus),
    .o_phy_rst_n (o_phy_rst_n),
    .i_apb_paddr (i_apb_paddr),
    .i_apb_pwdata (i_apb_pwdata),
    .i_apb_pwrite (i_apb_pwrite),
    .i_apb_penable (i_apb_penable),
    .i_apb_psel (i_apb_psel),
    .i_apb_pstrb (i_apb_pstrb),
    .i_apb_pprot (i_apb_pprot),
    .o_apb_pready (o_apb_pready),
    .o_apb_pslverr (o_apb_pslverr),
    .o_apb_prdata (o_apb_prdata),
    .i_protect_en (i_protect_en),
    .i_slverr_en (i_slverr_en),
    .i_ovrcur_n (i_ovrcur_n),
    .o_vbus_pwr_en (o_vbus_pwr_en),
    .i_dft_test_en (i_dft_test_en),
    .i_dft_scan_en (i_dft_scan_en),
    .o_int_usb (o_int_usb),
    .o_utmi_dataout (),
    .o_utmi_txvalid (),
    .o_utmi_txvalidh (),
    .i_utmi_txready ('0),
    .i_utmi_datain ('0),
    .i_utmi_rxvalid ('0),
    .i_utmi_rxvalidh ('0),
    .i_utmi_rxactive ('0),
    .i_utmi_rxerror ('0),
    .i_utmi_linestate ('0),
    .o_utmi_opmode (),
    .o_utmi_xcvrsel (),
    .o_utmi_termsel (),
    .o_utmi_suspend_n (),
    .o_utmi_databus16_8 (),
    .o_utmi_bitstuff_en (),
    .o_utmi_bitstuff_en_h (),
    .o_utmi_dppulldown (),
    .o_utmi_dmpulldown (),
    .i_utmi_hostdisc ('0),
    .o_utmi_drvvbus (),
    .o_utmi_chrgvbus (),
    .o_utmi_dischrgvbus (),
    .o_utmi_idpullup (),
    .i_utmi_iddig ('0),
    .i_utmi_avalid ('0),
    .i_utmi_bvalid ('0),
    .i_utmi_vbusvalid ('0),
    .i_utmi_sessend ('0),
    .i_ulpi_dir (i_ulpi_dir),
    .i_ulpi_nxt (i_ulpi_nxt),
    .o_ulpi_stp (o_ulpi_stp),
    .i_ulpi_data (i_ulpi_data),
    .o_ulpi_data (o_ulpi_data),
    .o_ulpi_data_oe (o_ulpi_data_oe),
    .o_axim_awid (),
    .o_axim_awaddr (),
    .o_axim_awlen (),
    .o_axim_awsize (),
    .o_axim_awburst (),
    .o_axim_awcache (),
    .o_axim_awprot (),
    .o_axim_awvalid (),
    .i_axim_awready ('0),
    .o_axim_wdata (),
    .o_axim_wstrb (),
    .o_axim_wlast (),
    .o_axim_wvalid (),
    .i_axim_wready ('0),
    .i_axim_bid ('0),
    .i_axim_bresp ('0),
    .i_axim_bvalid ('0),
    .o_axim_bready (),
    .o_axim_arid (),
    .o_axim_araddr (),
    .o_axim_arlen (),
    .o_axim_arsize (),
    .o_axim_arburst (),
    .o_axim_arcache (),
    .o_axim_arprot (),
    .o_axim_arvalid (),
    .i_axim_arready ('0),
    .i_axim_rid ('0),
    .i_axim_rdata ('0),
    .i_axim_rresp ('0),
    .i_axim_rlast ('0),
    .i_axim_rvalid ('0),
    .o_axim_rready (),
    .i_axis_awid (i_axis_awid),
    .i_axis_awaddr (i_axis_awaddr),
    .i_axis_awlen (i_axis_awlen),
    .i_axis_awsize (i_axis_awsize),
    .i_axis_awburst (i_axis_awburst),
    .i_axis_awvalid (i_axis_awvalid),
    .o_axis_awready (o_axis_awready),
    .i_axis_wdata (i_axis_wdata),
    .i_axis_wstrb (i_axis_wstrb),
    .i_axis_wlast (i_axis_wlast),
    .i_axis_wvalid (i_axis_wvalid),
    .o_axis_wready (o_axis_wready),
    .o_axis_bid (o_axis_bid),
    .o_axis_bresp (o_axis_bresp),
    .o_axis_bvalid (o_axis_bvalid),
    .i_axis_bready (i_axis_bready),
    .i_axis_arid (i_axis_arid),
    .i_axis_araddr (i_axis_araddr),
    .i_axis_arlen (i_axis_arlen),
    .i_axis_arsize (i_axis_arsize),
    .i_axis_arburst (i_axis_arburst),
    .i_axis_arvalid (i_axis_arvalid),
    .o_axis_arready (o_axis_arready),
    .o_axis_rid (o_axis_rid),
    .o_axis_rdata (o_axis_rdata),
    .o_axis_rresp (o_axis_rresp),
    .o_axis_rlast (o_axis_rlast),
    .o_axis_rvalid (o_axis_rvalid),
    .i_axis_rready (i_axis_rready),
    .o_dma_req (o_dma_req),
    .i_dma_ack (i_dma_ack)
  );

endmodule
