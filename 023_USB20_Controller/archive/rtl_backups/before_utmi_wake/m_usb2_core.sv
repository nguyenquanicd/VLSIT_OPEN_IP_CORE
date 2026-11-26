/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Structural core of the USB 2.0 controller (section 5 and 14.2, DEC-012). It
 *                holds the parameter check, the resets, the over-current block, the CSR
 *                integration, the PHY adapter, the link, the speed engine, the device and host
 *                engines, the FIFO manager, its crossing and the DMA or the AXI slave. The four
 *                wrappers tie off the pins of the interfaces that a build does not have.
 */
`timescale 1ns/1ps

module m_usb2_core #(
  // Parameter Description: role: 0 device, 1 host, 2 dual-role by the ID pin.
  // Parameter values: 0, 1 or 2; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_ROLE = 2,
  // Parameter Description: PHY interface: 0 UTMI+, 1 ULPI.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PHY_IF = 0,
  // Parameter Description: UTMI+ data width.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: data interface: 0 AXI4 master DMA, 1 AXI4 slave with DMA handshake.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_DATA_IF = 0,
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
  parameter logic [31:0] PARA_USB2_TSCALE = 1,
  localparam logic [31:0] LPARA_NEP1 = PARA_USB2_NUM_EP + 32'd1,
  localparam logic [31:0] LPARA_NQ = PARA_USB2_NUM_EP + 32'd4,
  localparam logic [31:0] LPARA_HQ_NP = PARA_USB2_NUM_EP + 32'd2,
  localparam logic [31:0] LPARA_ROW_W = PARA_USB2_UTMI_W * 32'd4,
  localparam logic [31:0] LPARA_FIFO_LOG2 = $clog2(PARA_USB2_FIFO_DEPTH),
  localparam logic [31:0] LPARA_CLK_MHZ = (PARA_USB2_UTMI_W == 32'd16) ? 32'd30 : 32'd60,
  localparam logic [31:0] LPARA_W16 = 16,
  localparam logic [31:0] LPARA_CELL_2FF = 2,
  localparam logic [31:0] LPARA_KIND_DATA = 3
) (
  // Clocks, resets and the PHY reset request
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

  // UTMI+ pins
  output logic [15:0]                       o_utmi_dataout,
  output logic                              o_utmi_txvalid,
  output logic                              o_utmi_txvalidh,
  input  wire                               i_utmi_txready,
  input  wire  [15:0]                       i_utmi_datain,
  input  wire                               i_utmi_rxvalid,
  input  wire                               i_utmi_rxvalidh,
  input  wire                               i_utmi_rxactive,
  input  wire                               i_utmi_rxerror,
  input  wire  [1:0]                        i_utmi_linestate,
  output logic [1:0]                        o_utmi_opmode,
  output logic [1:0]                        o_utmi_xcvrsel,
  output logic                              o_utmi_termsel,
  output logic                              o_utmi_suspend_n,
  output logic                              o_utmi_databus16_8,
  output logic                              o_utmi_bitstuff_en,
  output logic                              o_utmi_bitstuff_en_h,
  output logic                              o_utmi_dppulldown,
  output logic                              o_utmi_dmpulldown,
  input  wire                               i_utmi_hostdisc,
  output logic                              o_utmi_drvvbus,
  output logic                              o_utmi_chrgvbus,
  output logic                              o_utmi_dischrgvbus,
  output logic                              o_utmi_idpullup,
  input  wire                               i_utmi_iddig,
  input  wire                               i_utmi_avalid,
  input  wire                               i_utmi_bvalid,
  input  wire                               i_utmi_vbusvalid,
  input  wire                               i_utmi_sessend,

  // ULPI pins
  input  wire                               i_ulpi_dir,
  input  wire                               i_ulpi_nxt,
  output logic                              o_ulpi_stp,
  input  wire  [7:0]                        i_ulpi_data,
  output logic [7:0]                        o_ulpi_data,
  output logic                              o_ulpi_data_oe,

  // AXI4 master
  output logic [PARA_USB2_AXI_ID_W-1:0]     o_axim_awid,
  output logic [PARA_USB2_AXI_ADDR_W-1:0]   o_axim_awaddr,
  output logic [7:0]                        o_axim_awlen,
  output logic [2:0]                        o_axim_awsize,
  output logic [1:0]                        o_axim_awburst,
  output logic [3:0]                        o_axim_awcache,
  output logic [2:0]                        o_axim_awprot,
  output logic                              o_axim_awvalid,
  input  wire                               i_axim_awready,
  output logic [PARA_USB2_AXI_DATA_W-1:0]   o_axim_wdata,
  output logic [PARA_USB2_AXI_DATA_W/8-1:0] o_axim_wstrb,
  output logic                              o_axim_wlast,
  output logic                              o_axim_wvalid,
  input  wire                               i_axim_wready,
  input  wire  [PARA_USB2_AXI_ID_W-1:0]     i_axim_bid,
  input  wire  [1:0]                        i_axim_bresp,
  input  wire                               i_axim_bvalid,
  output logic                              o_axim_bready,
  output logic [PARA_USB2_AXI_ID_W-1:0]     o_axim_arid,
  output logic [PARA_USB2_AXI_ADDR_W-1:0]   o_axim_araddr,
  output logic [7:0]                        o_axim_arlen,
  output logic [2:0]                        o_axim_arsize,
  output logic [1:0]                        o_axim_arburst,
  output logic [3:0]                        o_axim_arcache,
  output logic [2:0]                        o_axim_arprot,
  output logic                              o_axim_arvalid,
  input  wire                               i_axim_arready,
  input  wire  [PARA_USB2_AXI_ID_W-1:0]     i_axim_rid,
  input  wire  [PARA_USB2_AXI_DATA_W-1:0]   i_axim_rdata,
  input  wire  [1:0]                        i_axim_rresp,
  input  wire                               i_axim_rlast,
  input  wire                               i_axim_rvalid,
  output logic                              o_axim_rready,

  // AXI4 slave and DMA handshake
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

  // Internal signal declarations
  logic w_rst_n_phy;
  logic w_rst_n_core;
  logic w_rst_n_bus;
  logic w_soft_req;
  logic w_phy_hold;
  logic w_soft_busy;
  logic w_soft_clr;
  logic w_role_bus;
  logic w_ocur_flag;
  logic w_oc_evt;
  logic w_oc_act;
  logic w_pwr_en_phy;
  logic w_phy_alive;
  logic reg_alive;
  logic w_axi_err;
  logic w_dma_err;
  logic w_wake_csr;
  logic [31:0] w_ld_addr;
  logic [LPARA_NEP1-1:0] w_ld_epi_we;
  logic [LPARA_NEP1-1:0] w_ld_epo_we;
  logic [PARA_USB2_NUM_HC-1:0] w_ld_hc_we;
  logic [31:0] w_bus_ctrl;
  logic [31:0] w_bus_dctrl;
  logic [31:0] w_bus_hport;
  logic [31:0] w_bus_hsts;
  logic [31:0] w_bus_dma_cfg;
  logic [31:0] w_bus_dma_hi;
  logic [31:0] w_bus_dma_wbase;
  logic [31:0] w_bus_dma_wlim;
  logic [31:0] w_bus_fifo_hnp;
  logic [31:0] w_bus_fifo_hpt;
  logic [31:0] w_bus_fifo_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_bus_epi_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_bus_epi_xfr;
  logic [LPARA_NEP1-1:0][31:0] w_bus_epi_dma;
  logic [LPARA_NEP1-1:0][31:0] w_bus_epi_buf;
  logic [LPARA_NEP1-1:0][31:0] w_bus_epo_dma;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_bus_hc_ctrl;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_bus_hc_xfer;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_bus_hc_dma;
  logic [PARA_USB2_NUM_DMA_CH-1:0][31:0] w_bus_dma_map;
  logic [31:0] w_ph_dctrl;
  logic [31:0] w_ph_hport;
  logic [31:0] w_ph_phy_acc;
  logic [31:0] w_ph_fifo_ctl;
  logic [31:0] w_ph_lpbk_sts;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epi_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epi_xfr;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epo_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epo_xfr;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_ph_hc_ctrl;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_ph_hc_xfer;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_ph_hc_cfg;
  logic [31:0] w_ph_ctrl;
  logic [31:0] w_ph_sof_cfg;
  logic [31:0] w_ph_fifo_rx;
  logic [31:0] w_ph_fifo_hnp;
  logic [31:0] w_ph_fifo_hpt;
  logic [31:0] w_ph_lpm_cfg;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epi_buf;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epi_ien;
  logic [LPARA_NEP1-1:0][31:0] w_ph_epo_ien;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_ph_hc_spl;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_ph_hc_ien;
  logic [31:0] w_pub_sts;
  logic [31:0] w_pub_dsts;
  logic [31:0] w_pub_hsts;
  logic [31:0] w_pub_phy_acc;
  logic [31:0] w_pub_lpbk_sts;
  logic [LPARA_NEP1-1:0][31:0] w_pub_epi_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_pub_epi_xfr;
  logic [LPARA_NEP1-1:0][31:0] w_pub_epo_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_pub_epo_xfr;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_pub_hc_xfer;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_pub_hc_cfg;
  logic [31:0] w_set_irq_raw;
  logic [LPARA_NEP1-1:0][31:0] w_set_epi_int;
  logic [LPARA_NEP1-1:0][31:0] w_set_epo_int;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_set_hc_int;
  logic [31:0] w_clr_dctrl;
  logic [31:0] w_clr_hport;
  logic [31:0] w_clr_phy_acc;
  logic [31:0] w_clr_fifo_ctl;
  logic [31:0] w_clr_lpbk_sts;
  logic [LPARA_NEP1-1:0][31:0] w_clr_epi_ctl;
  logic [LPARA_NEP1-1:0][31:0] w_clr_epo_ctl;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_clr_hc_ctrl;
  logic [15:0] w_phy_rx_data;
  logic [1:0] w_phy_rx_valid;
  logic w_phy_rx_active;
  logic w_phy_rx_err;
  logic [1:0] w_linestate;
  logic [15:0] w_phy_tx_data;
  logic [1:0] w_phy_tx_valid;
  logic w_phy_tx_ready;
  logic w_phy_tx_abort;
  logic w_tx_starve;
  logic [15:0] w_lnk_tx_data;
  logic [1:0] w_lnk_tx_valid;
  logic w_hostdisc;
  logic w_iddig;
  logic w_avalid;
  logic w_bvalid;
  logic w_vbusvalid;
  logic w_sessend;
  logic [1:0] w_xcvr_sel;
  logic w_term_sel;
  logic [1:0] w_op_mode;
  logic w_suspend_n;
  logic w_dp_pd;
  logic w_dm_pd;
  logic w_drv_vbus;
  logic w_chrg_vbus;
  logic w_dischrg_vbus;
  logic w_id_pullup;
  logic w_stp_lp;
  logic w_lp_active;
  logic w_reg_start;
  logic w_reg_busy;
  logic w_reg_done;
  logic [7:0] w_reg_rdata;
  logic w_link_idle;
  logic [15:0] w_ch_data;
  logic [1:0] w_ch_valid;
  logic w_ch_active;
  logic w_tp_req;
  logic [3:0] w_tp_pid;
  logic [11:0] w_tp_len;
  logic [15:0] w_tp_dat;
  logic w_tp_pop;
  logic w_tp_vld;
  logic w_role_host;
  logic w_test_nak;
  logic w_dev_act;
  logic w_host_act;
  logic w_host_quiet;
  logic [1:0] w_speed;
  logic w_attached;
  logic w_suspended;
  logic w_l1_state;
  logic w_susp_det;
  logic w_port_en;
  logic w_evt_rst;
  logic w_evt_susp;
  logic w_evt_resume;
  logic w_evt_conn;
  logic w_evt_disc;
  logic w_evt_role;
  logic w_evt_enum;
  logic w_clr_rmt_wake;
  logic w_clr_port_rst;
  logic w_clr_port_susp;
  logic w_clr_port_res;
  logic [3:0] w_spd_lpm_hird;
  logic w_spd_lpm_rw;
  logic w_tok_vld;
  logic w_tok_ext;
  logic [10:0] w_tok_efld;
  logic [3:0] w_tok_pid;
  logic [10:0] w_tok_fld;
  logic w_hs_vld;
  logic [3:0] w_hs_pid;
  logic w_dat_sop;
  logic [3:0] w_dat_pid;
  logic [1:0] w_dat_n;
  logic [15:0] w_dat_b;
  logic w_dat_end;
  logic w_dat_ok;
  logic [11:0] w_dat_len;
  logic w_err_pid;
  logic w_err_crc;
  logic w_err_stuf;
  logic w_err_babble;
  logic w_rx_busy;
  logic w_tx_busy;
  logic w_tx_done;
  logic w_tx_fail;
  logic w_tx_req;
  logic [2:0] w_tx_kind;
  logic [3:0] w_tx_pid;
  logic [18:0] w_tx_fld;
  logic [11:0] w_tx_len;
  logic [15:0] w_src_dat;
  logic w_src_vld;
  logic w_src_pop;
  logic [11:0] w_lpbk_ok;
  logic [11:0] w_lpbk_err;
  logic w_dev_tx_req;
  logic [2:0] w_dev_tx_kind;
  logic [3:0] w_dev_tx_pid;
  logic [18:0] w_dev_tx_fld;
  logic [11:0] w_dev_tx_len;
  logic w_dev_rxw_sop;
  logic [4:0] w_dev_rxw_tag;
  logic [1:0] w_dev_rxw_n;
  logic [15:0] w_dev_rxw_b;
  logic w_dev_rxw_end;
  logic w_dev_rxw_ok;
  logic [11:0] w_dev_rxw_len;
  logic w_dev_txr_start;
  logic [4:0] w_dev_txr_q;
  logic [11:0] w_dev_txr_len;
  logic w_dev_txr_commit;
  logic w_dev_txr_cancel;
  logic w_dev_evt_sof;
  logic w_dev_evt_xfer;
  logic w_host_tx_req;
  logic [2:0] w_host_tx_kind;
  logic [3:0] w_host_tx_pid;
  logic [18:0] w_host_tx_fld;
  logic [11:0] w_host_tx_len;
  logic w_host_rxw_sop;
  logic [4:0] w_host_rxw_tag;
  logic [1:0] w_host_rxw_n;
  logic [15:0] w_host_rxw_b;
  logic w_host_rxw_end;
  logic w_host_rxw_ok;
  logic [11:0] w_host_rxw_len;
  logic w_host_txr_start;
  logic [4:0] w_host_txr_q;
  logic [11:0] w_host_txr_len;
  logic w_host_txr_commit;
  logic w_host_txr_cancel;
  logic w_host_evt_sof;
  logic w_host_evt_xfer;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epi_ctrl_pub;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epi_xfer_pub;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epo_ctrl_pub;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epo_xfer_pub;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epi_int_set;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epo_int_set;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epi_ctrl_clr;
  logic [LPARA_NEP1-1:0][31:0] w_dev_epo_ctrl_clr;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_host_hc_xfer_pub;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_host_hc_cfg_pub;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_host_hc_int_set;
  logic [PARA_USB2_NUM_HC-1:0][31:0] w_host_hc_ctrl_clr;
  logic [10:0] w_dev_frame;
  logic [2:0] w_dev_uframe;
  logic w_dev_lpm_vld;
  logic [3:0] w_dev_lpm_hird;
  logic w_dev_lpm_rw;
  logic w_dev_evt_udf;
  logic w_evt_tmo;
  logic w_evt_iso;
  logic [13:0] w_host_frame;
  logic w_host_lpm_evt;
  logic w_host_lpm_ack;
  logic w_host_lpm_clr;
  logic [LPARA_NQ*16-1:0] w_q_base;
  logic [LPARA_NQ*16-1:0] w_q_size;
  logic w_flush_vld;
  logic [4:0] w_flush_q;
  logic [4:0] w_txq_phy;
  logic [4:0] w_txq_bus;
  logic w_rxw_sop;
  logic [4:0] w_rxw_tag;
  logic [1:0] w_rxw_n;
  logic [15:0] w_rxw_b;
  logic w_rxw_end;
  logic w_rxw_ok;
  logic [11:0] w_rxw_len;
  logic [16:0] w_rx_free;
  logic w_plq_free;
  logic w_txr_start;
  logic [4:0] w_txr_q;
  logic [11:0] w_txr_len;
  logic w_txr_commit;
  logic w_txr_cancel;
  logic [15:0] w_fifo_src_dat;
  logic w_fifo_src_vld;
  logic w_fifo_src_pop;
  logic [LPARA_NQ*17-1:0] w_q_cnt;
  logic w_bp_vld;
  logic [2:0] w_bp_op;
  logic [4:0] w_bp_q;
  logic [LPARA_ROW_W-1:0] w_bp_data;
  logic w_bp_rdy;
  logic w_bp_rsp_vld;
  logic [LPARA_ROW_W-1:0] w_bp_rsp_data;
  logic w_fev_vld;
  logic [1:0] w_fev_type;
  logic [4:0] w_fev_q;
  logic [16:0] w_fev_val;
  logic w_fev_rdy;
  logic w_fifo_ovf;
  logic w_fifo_par;
  logic w_rq_vld;
  logic [2:0] w_rq_op;
  logic [4:0] w_rq_q;
  logic [LPARA_ROW_W-1:0] w_rq_data;
  logic w_rq_rdy;
  logic w_rs_vld;
  logic [LPARA_ROW_W-1:0] w_rs_data;
  logic w_rs_pop;
  logic w_bev_vld;
  logic [1:0] w_bev_type;
  logic [4:0] w_bev_q;
  logic [16:0] w_bev_val;
  logic w_bev_pop;
  logic [1:0] reg_flc_seen;
  logic reg_lpclr_seen;
  logic reg_acc_seen;
  logic w_fl_rx;
  logic w_fl_tx;
  logic w_acc_edge;
  logic w_lpclr_edge;
  logic [LPARA_NEP1*17-1:0] w_ep_cnt;
  logic [33:0] w_hq_cnt;

  // Elaboration check of the parameters.
  m_usb2_cfgchk #(
    .PARA_USB2_ROLE       (PARA_USB2_ROLE),
    .PARA_USB2_PHY_IF     (PARA_USB2_PHY_IF),
    .PARA_USB2_UTMI_W     (PARA_USB2_UTMI_W),
    .PARA_USB2_DATA_IF    (PARA_USB2_DATA_IF),
    .PARA_USB2_SPLIT_EN   (PARA_USB2_SPLIT_EN),
    .PARA_USB2_SG_EN      (PARA_USB2_SG_EN),
    .PARA_USB2_NUM_DMA_CH (PARA_USB2_NUM_DMA_CH),
    .PARA_USB2_FIFO_DEPTH (PARA_USB2_FIFO_DEPTH),
    .PARA_USB2_TSCALE     (PARA_USB2_TSCALE),
    .PARA_USB2_AXI_DATA_W (PARA_USB2_AXI_DATA_W)
  ) u_cfgchk (
    .o_cfg_err ()   // marker for tb_cfgchk; an illegal set stops elaboration
  );

  // Reset controller: synchronized releases, soft reset of the engines, reset of the PHY.
  m_usb2_rst u_rst (
    .i_clk_phy    (i_clk_phy),
    .i_rst_n_phy  (i_rst_n_phy),
    .i_clk_bus    (i_clk_bus),
    .i_rst_n_bus  (i_rst_n_bus),
    .i_dft_test_en (i_dft_test_en),
    .i_soft_req   (w_soft_req),
    .i_phy_hold   (w_phy_hold),
    .o_soft_busy  (w_soft_busy),
    .o_soft_clr   (w_soft_clr),
    .o_rst_n_phy  (w_rst_n_phy),
    .o_rst_n_core (w_rst_n_core),
    .o_rst_n_bus  (w_rst_n_bus),
    .o_phy_rst_n  (o_phy_rst_n)
  );

  // Over-current protection of the port power in CLK-BUS.
  m_usb2_ocp u_ocp (
    .i_clk_bus   (i_clk_bus),
    .i_rst_n_bus (w_rst_n_bus),
    .i_ovrcur_n  (i_ovrcur_n),
    .i_oc_en     (w_bus_hport[22]),
    .i_vbus_drv  (w_bus_hport[3]),
    .i_ocur_flag (w_ocur_flag),
    .o_pwr_en    (o_vbus_pwr_en),
    .o_oc_evt    (w_oc_evt),
    .o_oc_act    (w_oc_act)
  );

  // Crossings of single status bits: the port power state to CLK-PHY, the PHY clock alive flag
  // (the reset of CLK-PHY is released) to CLK-BUS.
  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (1),
    .PARA_AFIFO_SYNC_RST_VAL (0),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_pwr (
    .i_clk_dst   (i_clk_phy),
    .i_rst_n_dst (w_rst_n_phy),
    .i_data      (o_vbus_pwr_en),
    .o_data      (w_pwr_en_phy)
  );

  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (1),
    .PARA_AFIFO_SYNC_RST_VAL (0),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_alive (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (w_rst_n_bus),
    .i_data      (reg_alive),
    .o_data      (w_phy_alive)
  );

  // PHY clock alive flag in CLK-PHY.
  always_ff @(posedge i_clk_phy, negedge w_rst_n_phy) begin : p_ff_alive
    if (!w_rst_n_phy)
      reg_alive <= 1'b0;
    else
      reg_alive <= 1'b1;
  end

  // CSR integration: CSR, register crossing and interrupt block.
  m_usb2_regs #(
    .PARA_USB2_NEP1       (LPARA_NEP1),
    .PARA_USB2_NHC        (PARA_USB2_NUM_HC),
    .PARA_USB2_NUM_DMA_CH (PARA_USB2_NUM_DMA_CH),
    .PARA_USB2_ROLE_CFG   (PARA_USB2_ROLE),
    .PARA_USB2_PHY_ULPI   (PARA_USB2_PHY_IF),
    .PARA_USB2_UTMI_16    ((PARA_USB2_UTMI_W == LPARA_W16) ? 32'd1 : 32'd0),
    .PARA_USB2_AXI_SLAVE  (PARA_USB2_DATA_IF),
    .PARA_USB2_LPM_CFG    (PARA_USB2_LPM_EN),
    .PARA_USB2_SPLIT_CFG  (PARA_USB2_SPLIT_EN),
    .PARA_USB2_FIFO_LOG2  (LPARA_FIFO_LOG2),
    .PARA_USB2_SG_CFG     (PARA_USB2_SG_EN),
    .PARA_USB2_DBUF_CFG   (PARA_USB2_DBUF_EN),
    .PARA_USB2_PAR_CFG    (PARA_USB2_RAM_PAR_EN),
    .PARA_USB2_PIPE_XREG  (PARA_USB2_PIPE_XREG)
  ) u_regs (
    .i_clk_bus     (i_clk_bus),
    .i_rst_n_bus   (w_rst_n_bus),
    .i_clk_phy     (i_clk_phy),
    .i_rst_n_phy   (w_rst_n_phy),
    .i_apb_psel (i_apb_psel),
    .i_apb_penable (i_apb_penable),
    .i_apb_pwrite (i_apb_pwrite),
    .i_apb_paddr (i_apb_paddr),
    .i_apb_pwdata (i_apb_pwdata),
    .i_apb_pstrb (i_apb_pstrb),
    .i_apb_pprot (i_apb_pprot),
    .o_apb_pready  (o_apb_pready),
    .o_apb_pslverr (o_apb_pslverr),
    .o_apb_prdata  (o_apb_prdata),
    .i_protect_en  (i_protect_en),
    .i_slverr_en   (i_slverr_en),
    .o_int_usb     (o_int_usb),
    .i_phy_alive   (w_phy_alive),
    .i_soft_busy   (w_soft_busy),
    .i_oc_act      (w_oc_act),
    .i_evt_ocur    (w_oc_evt),
    .i_evt_axi_err (w_axi_err),
    .i_evt_dma_err (w_dma_err),
    .o_role_host   (w_role_bus),
    .o_ocur_flag   (w_ocur_flag),
    .o_soft_req    (w_soft_req),
    .o_phy_hold    (w_phy_hold),
    .i_soft_clr    (w_soft_clr),
    .i_ld_addr     (w_ld_addr),
    .i_ld_epi_we   (w_ld_epi_we),
    .i_ld_epo_we   (w_ld_epo_we),
    .i_ld_hc_we    (w_ld_hc_we),
    .o_bus_ctrl (w_bus_ctrl),
    .o_bus_dctrl (w_bus_dctrl),
    .o_bus_hport (w_bus_hport),
    .o_bus_hsts (w_bus_hsts),
    .o_bus_dma_cfg (w_bus_dma_cfg),
    .o_bus_dma_hi (w_bus_dma_hi),
    .o_bus_dma_wbase (w_bus_dma_wbase),
    .o_bus_dma_wlim (w_bus_dma_wlim),
    .o_bus_fifo_hnp (w_bus_fifo_hnp),
    .o_bus_fifo_hpt (w_bus_fifo_hpt),
    .o_bus_fifo_ctl (w_bus_fifo_ctl),
    .o_bus_epi_ctl (w_bus_epi_ctl),
    .o_bus_epi_xfr (w_bus_epi_xfr),
    .o_bus_epi_dma (w_bus_epi_dma),
    .o_bus_epi_buf (w_bus_epi_buf),
    .o_bus_epo_dma (w_bus_epo_dma),
    .o_bus_hc_ctrl (w_bus_hc_ctrl),
    .o_bus_hc_xfer (w_bus_hc_xfer),
    .o_bus_hc_dma (w_bus_hc_dma),
    .o_bus_dma_map (w_bus_dma_map),
    .o_ph_dctrl (w_ph_dctrl),
    .o_ph_hport (w_ph_hport),
    .o_ph_phy_acc (w_ph_phy_acc),
    .o_ph_fifo_ctl (w_ph_fifo_ctl),
    .o_ph_lpbk_sts (w_ph_lpbk_sts),
    .o_ph_epi_ctl (w_ph_epi_ctl),
    .o_ph_epi_xfr (w_ph_epi_xfr),
    .o_ph_epo_ctl (w_ph_epo_ctl),
    .o_ph_epo_xfr (w_ph_epo_xfr),
    .o_ph_hc_ctrl (w_ph_hc_ctrl),
    .o_ph_hc_xfer (w_ph_hc_xfer),
    .o_ph_hc_cfg (w_ph_hc_cfg),
    .o_ph_ctrl (w_ph_ctrl),
    .o_ph_sof_cfg (w_ph_sof_cfg),
    .o_ph_fifo_rx (w_ph_fifo_rx),
    .o_ph_fifo_hnp (w_ph_fifo_hnp),
    .o_ph_fifo_hpt (w_ph_fifo_hpt),
    .o_ph_lpm_cfg (w_ph_lpm_cfg),
    .o_ph_epi_buf (w_ph_epi_buf),
    .o_ph_epi_ien (w_ph_epi_ien),
    .o_ph_epo_ien (w_ph_epo_ien),
    .o_ph_hc_spl (w_ph_hc_spl),
    .o_ph_hc_ien (w_ph_hc_ien),
    .i_ph_pub_sts (w_pub_sts),
    .i_ph_pub_dsts (w_pub_dsts),
    .i_ph_pub_hsts (w_pub_hsts),
    .i_ph_pub_phy_acc (w_pub_phy_acc),
    .i_ph_pub_lpbk_sts (w_pub_lpbk_sts),
    .i_ph_pub_epi_ctl (w_pub_epi_ctl),
    .i_ph_pub_epi_xfr (w_pub_epi_xfr),
    .i_ph_pub_epo_ctl (w_pub_epo_ctl),
    .i_ph_pub_epo_xfr (w_pub_epo_xfr),
    .i_ph_pub_hc_xfer (w_pub_hc_xfer),
    .i_ph_pub_hc_cfg (w_pub_hc_cfg),
    .i_ph_set_irq_raw (w_set_irq_raw),
    .i_ph_set_epi_int (w_set_epi_int),
    .i_ph_set_epo_int (w_set_epo_int),
    .i_ph_set_hc_int (w_set_hc_int),
    .i_ph_clr_dctrl (w_clr_dctrl),
    .i_ph_clr_hport (w_clr_hport),
    .i_ph_clr_phy_acc (w_clr_phy_acc),
    .i_ph_clr_fifo_ctl (w_clr_fifo_ctl),
    .i_ph_clr_lpbk_sts (w_clr_lpbk_sts),
    .i_ph_clr_epi_ctl (w_clr_epi_ctl),
    .i_ph_clr_epo_ctl (w_clr_epo_ctl),
    .i_ph_clr_hc_ctrl (w_clr_hc_ctrl)
  );

  // PHY interface: UTMI+ or ULPI adapter with the same stream interface to the link.
  generate
    if (PARA_USB2_PHY_IF == 32'd0) begin : gen_utmi
      m_usb2_phyif_utmi #(
        .PARA_USB2_UTMI_W      (PARA_USB2_UTMI_W),
        .PARA_USB2_PIPE_PHY_IN (PARA_USB2_PIPE_PHY_IN)
      ) u_phyif (
        .i_clk_phy            (i_clk_phy),
        .i_rst_n_phy          (w_rst_n_core),
        .o_utmi_dataout (o_utmi_dataout),
        .o_utmi_txvalid (o_utmi_txvalid),
        .o_utmi_txvalidh (o_utmi_txvalidh),
        .i_utmi_txready (i_utmi_txready),
        .i_utmi_datain (i_utmi_datain),
        .i_utmi_rxvalid (i_utmi_rxvalid),
        .i_utmi_rxvalidh (i_utmi_rxvalidh),
        .i_utmi_rxactive (i_utmi_rxactive),
        .i_utmi_rxerror (i_utmi_rxerror),
        .i_utmi_linestate (i_utmi_linestate),
        .o_utmi_opmode (o_utmi_opmode),
        .o_utmi_xcvrsel (o_utmi_xcvrsel),
        .o_utmi_termsel (o_utmi_termsel),
        .o_utmi_suspend_n (o_utmi_suspend_n),
        .o_utmi_databus16_8 (o_utmi_databus16_8),
        .o_utmi_bitstuff_en (o_utmi_bitstuff_en),
        .o_utmi_bitstuff_en_h (o_utmi_bitstuff_en_h),
        .o_utmi_dppulldown (o_utmi_dppulldown),
        .o_utmi_dmpulldown (o_utmi_dmpulldown),
        .o_utmi_drvvbus (o_utmi_drvvbus),
        .o_utmi_chrgvbus (o_utmi_chrgvbus),
        .o_utmi_dischrgvbus (o_utmi_dischrgvbus),
        .o_utmi_idpullup (o_utmi_idpullup),
        .i_utmi_hostdisc (i_utmi_hostdisc),
        .i_utmi_iddig (i_utmi_iddig),
        .i_utmi_avalid (i_utmi_avalid),
        .i_utmi_bvalid (i_utmi_bvalid),
        .i_utmi_vbusvalid (i_utmi_vbusvalid),
        .i_utmi_sessend (i_utmi_sessend),
        .i_tx_data            (w_phy_tx_data),
        .i_tx_valid           (w_phy_tx_valid),
        .o_tx_ready           (w_phy_tx_ready),
        .o_rx_data            (w_phy_rx_data),
        .o_rx_valid           (w_phy_rx_valid),
        .o_rx_active          (w_phy_rx_active),
        .o_rx_err             (w_phy_rx_err),
        .o_linestate          (w_linestate),
        .i_xcvr_sel           (w_xcvr_sel),
        .i_term_sel           (w_term_sel),
        .i_op_mode            (w_op_mode),
        .i_suspend_n          (w_suspend_n),
        .i_dp_pd              (w_dp_pd),
        .i_dm_pd              (w_dm_pd),
        .i_drv_vbus           (w_drv_vbus),
        .i_chrg_vbus          (w_chrg_vbus),
        .i_dischrg_vbus       (w_dischrg_vbus),
        .i_id_pullup          (w_id_pullup),
        .o_hostdisc           (w_hostdisc),
        .o_iddig              (w_iddig),
        .o_avalid             (w_avalid),
        .o_bvalid             (w_bvalid),
        .o_vbusvalid          (w_vbusvalid),
        .o_sessend            (w_sessend)
      );
      assign o_ulpi_stp     = 1'b0;
      assign o_ulpi_data    = 8'h00;
      assign o_ulpi_data_oe = 1'b0;
      assign w_stp_lp       = 1'b0;
      assign w_lp_active    = 1'b0;
      assign w_reg_busy     = 1'b0;
      assign w_reg_done     = w_reg_start;
      assign w_reg_rdata    = 8'h00;
      assign w_phy_tx_abort = 1'b0;
    end else begin : gen_ulpi
      m_usb2_phyif_ulpi u_phyif (
        .i_clk_phy       (i_clk_phy),
        .i_rst_n_phy     (w_rst_n_core),
        .i_ulpi_dir      (i_ulpi_dir),
        .i_ulpi_nxt      (i_ulpi_nxt),
        .i_ulpi_data     (i_ulpi_data),
        .o_ulpi_stp      (o_ulpi_stp),
        .o_ulpi_data     (o_ulpi_data),
        .o_ulpi_data_oe  (o_ulpi_data_oe),
        .i_stp_lp        (w_stp_lp),
        .o_lp_active     (w_lp_active),
        .i_tx_data       (w_phy_tx_data),
        .i_tx_valid      (w_phy_tx_valid),
        .o_tx_ready      (w_phy_tx_ready),
        .o_tx_abort      (w_phy_tx_abort),
        .i_link_idle     (w_link_idle),
        .o_rx_data       (w_phy_rx_data),
        .o_rx_valid      (w_phy_rx_valid),
        .o_rx_active     (w_phy_rx_active),
        .o_rx_err        (w_phy_rx_err),
        .o_linestate     (w_linestate),
        .i_xcvr_sel      (w_xcvr_sel),
        .i_term_sel      (w_term_sel),
        .i_op_mode       (w_op_mode),
        .i_suspend_n     (w_suspend_n),
        .i_dp_pd         (w_dp_pd),
        .i_dm_pd         (w_dm_pd),
        .i_drv_vbus      (w_drv_vbus),
        .i_ext_vbus      (w_ph_hport[23]),   // u2_hport.ext_vbus (DEC-048 PHY-06)
        .i_chrg_vbus     (w_chrg_vbus),
        .i_dischrg_vbus  (w_dischrg_vbus),
        .i_id_pullup     (w_id_pullup),
        .o_hostdisc      (w_hostdisc),
        .o_iddig         (w_iddig),
        .o_avalid        (w_avalid),
        .o_bvalid        (w_bvalid),
        .o_vbusvalid     (w_vbusvalid),
        .o_sessend       (w_sessend),
        .i_reg_start     (w_reg_start),
        .i_reg_wr        (w_ph_phy_acc[24]),
        .i_reg_addr      (w_ph_phy_acc[7:0]),
        .i_reg_wdata     (w_ph_phy_acc[15:8]),
        .o_reg_busy      (w_reg_busy),
        .o_reg_done      (w_reg_done),
        .o_reg_rdata     (w_reg_rdata)
      );
      m_usb2_ulpilp u_ulpilp (
        .i_clk_bus   (i_clk_bus),
        .i_rst_n_bus (w_rst_n_bus),
        .i_ulpi_dir  (i_ulpi_dir),
        .i_lp_active (w_lp_active),
        .i_wake_req  (w_wake_csr),
        .o_stp_lp    (w_stp_lp),
        .o_lp_sync   ()
      );
      assign o_utmi_dataout = 16'h0000;
      assign o_utmi_opmode = 2'b00;
      assign o_utmi_xcvrsel = 2'b00;
      assign o_utmi_txvalid = 1'b0;
      assign o_utmi_txvalidh = 1'b0;
      assign o_utmi_termsel = 1'b0;
      assign o_utmi_suspend_n = 1'b0;
      assign o_utmi_databus16_8 = 1'b0;
      assign o_utmi_bitstuff_en = 1'b0;
      assign o_utmi_bitstuff_en_h = 1'b0;
      assign o_utmi_dppulldown = 1'b0;
      assign o_utmi_dmpulldown = 1'b0;
      assign o_utmi_drvvbus = 1'b0;
      assign o_utmi_chrgvbus = 1'b0;
      assign o_utmi_dischrgvbus = 1'b0;
      assign o_utmi_idpullup = 1'b0;
    end
  endgenerate

  // PHY transmit stream: the chirp and test stream of the speed engine has priority over the link.
  assign w_phy_tx_data  = w_ch_active ? w_ch_data : w_lnk_tx_data;
  assign w_phy_tx_valid = w_ch_active ? w_ch_valid : w_lnk_tx_valid;

  // Link layer: packet receiver and transmitter with the loopback.
  m_usb2_lnk #(
    .PARA_USB2_UTMI_W   (PARA_USB2_UTMI_W),
    .PARA_USB2_PIPE_RX  (PARA_USB2_PIPE_RX),
    .PARA_USB2_PIPE_CRC (PARA_USB2_PIPE_CRC)
  ) u_lnk (
    .i_clk_phy       (i_clk_phy),
    .i_rst_n_core    (w_rst_n_core),
    .i_phy_rx_data   (w_phy_rx_data),
    .i_phy_rx_valid  (w_phy_rx_valid),
    .i_phy_rx_active (w_phy_rx_active),
    .i_phy_rx_err    (w_phy_rx_err),
    .o_phy_tx_data   (w_lnk_tx_data),
    .o_phy_tx_valid  (w_lnk_tx_valid),
    .i_phy_tx_ready  (w_phy_tx_ready),
    .i_phy_tx_abort  (w_phy_tx_abort),
    .i_lpbk          (w_ph_ctrl[7]),
    .i_lpbk_clr      (w_lpclr_edge),
    .o_lpbk_ok       (w_lpbk_ok),
    .o_lpbk_err      (w_lpbk_err),
    .o_tok_vld (w_tok_vld),
    .o_tok_ext (w_tok_ext),
    .o_tok_efld (w_tok_efld),
    .o_tok_pid (w_tok_pid),
    .o_tok_fld (w_tok_fld),
    .o_hs_vld (w_hs_vld),
    .o_hs_pid (w_hs_pid),
    .o_dat_sop (w_dat_sop),
    .o_dat_pid (w_dat_pid),
    .o_dat_n (w_dat_n),
    .o_dat_b (w_dat_b),
    .o_dat_end (w_dat_end),
    .o_dat_ok (w_dat_ok),
    .o_dat_len (w_dat_len),
    .o_err_pid (w_err_pid),
    .o_err_crc (w_err_crc),
    .o_err_stuf (w_err_stuf),
    .o_err_babble (w_err_babble),
    .o_rx_busy (w_rx_busy),
    .i_tx_req        (w_tx_req),
    .i_tx_kind       (w_tx_kind),
    .i_tx_pid        (w_tx_pid),
    .i_tx_fld        (w_tx_fld),
    .i_tx_len        (w_tx_len),
    .i_src_dat       (w_src_dat),
    .i_src_vld       (w_src_vld),
    .o_src_pop       (w_src_pop),
    .o_tx_busy       (w_tx_busy),
    .o_tx_starve     (w_tx_starve),
    .o_tx_done       (w_tx_done),
    .o_tx_fail       (w_tx_fail),
    .o_link_idle     (w_link_idle)
  );

  // Request multiplexer: the test packet of the speed engine, else the engine of the active role.
  always_comb begin : p_com_tx_mux
    w_tx_req  = 1'b0;
    w_tx_kind = 3'd0;
    w_tx_pid  = 4'h0;
    w_tx_fld  = 19'd0;
    w_tx_len  = 12'd0;
    if (w_tp_req) begin
      w_tx_req  = 1'b1;
      w_tx_kind = LPARA_KIND_DATA[2:0];
      w_tx_pid  = w_tp_pid;
      w_tx_len  = w_tp_len;
    end else if (w_role_host) begin
      w_tx_req  = w_host_tx_req;
      w_tx_kind = w_host_tx_kind;
      w_tx_pid  = w_host_tx_pid;
      w_tx_fld  = w_host_tx_fld;
      w_tx_len  = w_host_tx_len;
    end else begin
      w_tx_req  = w_dev_tx_req;
      w_tx_kind = w_dev_tx_kind;
      w_tx_pid  = w_dev_tx_pid;
      w_tx_fld  = w_dev_tx_fld;
      w_tx_len  = w_dev_tx_len;
    end
  end

  // Payload source: the test packet pattern or the FIFO reader.
  assign w_src_dat      = w_tp_vld ? w_tp_dat : w_fifo_src_dat;
  assign w_src_vld      = w_tp_vld ? 1'b1 : w_fifo_src_vld;
  assign w_tp_pop       = w_src_pop & w_tp_vld;
  assign w_fifo_src_pop = w_src_pop & ~w_tp_vld;

  // Speed, reset, chirp, suspend, resume and role.
  m_usb2_spd #(
    .PARA_USB2_CLK_MHZ (LPARA_CLK_MHZ),
    .PARA_USB2_TSCALE  (PARA_USB2_TSCALE),
    .PARA_USB2_ROLE    (PARA_USB2_ROLE),
    .PARA_USB2_UTMI_W  (PARA_USB2_UTMI_W),
    .PARA_USB2_PIPE_MODE (PARA_USB2_PIPE_MODE)
  ) u_spd (
    .i_clk_phy       (i_clk_phy),
    .i_rst_n_core    (w_rst_n_core),
    .i_linestate     (w_linestate),
    .i_vbusvalid     (w_vbusvalid),
    .i_iddig         (w_iddig),
    .i_hostdisc      (w_hostdisc),
    .i_ctrl          (w_ph_ctrl),
    .i_dctrl         (w_ph_dctrl),
    .i_hport         (w_ph_hport),
    .i_pwr_en        (w_pwr_en_phy),
    .i_bus_act       (w_rx_busy | w_tx_busy),
    .i_link_idle     (w_link_idle),
    .o_ch_data       (w_ch_data),
    .o_ch_valid      (w_ch_valid),
    .o_ch_active     (w_ch_active),
    .o_tp_req        (w_tp_req),
    .o_tp_pid        (w_tp_pid),
    .o_tp_len        (w_tp_len),
    .o_tp_dat        (w_tp_dat),
    .i_tp_pop        (w_tp_pop),
    .o_tp_vld        (w_tp_vld),
    .o_xcvr_sel      (w_xcvr_sel),
    .o_term_sel      (w_term_sel),
    .o_op_mode       (w_op_mode),
    .o_suspend_n     (w_suspend_n),
    .o_dp_pd         (w_dp_pd),
    .o_dm_pd         (w_dm_pd),
    .o_drv_vbus      (w_drv_vbus),
    .o_chrg_vbus     (w_chrg_vbus),
    .o_dischrg_vbus  (w_dischrg_vbus),
    .o_id_pullup     (w_id_pullup),
    .o_role_host     (w_role_host),
    .o_dev_act       (w_dev_act),
    .o_test_nak      (w_test_nak),
    .o_host_act      (w_host_act),
    .o_host_quiet    (w_host_quiet),
    .o_speed         (w_speed),
    .o_attached      (w_attached),
    .o_suspended     (w_suspended),
    .o_l1_state      (w_l1_state),
    .o_susp_det      (w_susp_det),
    .o_port_en       (w_port_en),
    .o_evt_rst       (w_evt_rst),
    .o_evt_susp      (w_evt_susp),
    .o_evt_resume    (w_evt_resume),
    .o_evt_conn      (w_evt_conn),
    .o_evt_disc      (w_evt_disc),
    .o_evt_role      (w_evt_role),
    .o_evt_enum      (w_evt_enum),
    .o_clr_rmt_wake  (w_clr_rmt_wake),
    .o_clr_port_rst  (w_clr_port_rst),
    .o_clr_port_susp (w_clr_port_susp),
    .o_clr_port_res  (w_clr_port_res),
    .i_hlpm_ack      (w_host_lpm_ack),
    .i_lpm_vld       (w_dev_lpm_vld),
    .i_lpm_hird      (w_dev_lpm_hird),
    .i_lpm_rw        (w_dev_lpm_rw),
    .o_lpm_hird      (w_spd_lpm_hird),
    .o_lpm_rw        (w_spd_lpm_rw)
  );

  // Device engine (builds with a device or a dual role).
  generate
    if (PARA_USB2_ROLE != 32'd1) begin : gen_dev
      m_usb2_dev #(
        .PARA_USB2_NEP1   (LPARA_NEP1),
        .PARA_USB2_UTMI_W (PARA_USB2_UTMI_W)
      ) u_dev (
        .i_clk_phy       (i_clk_phy),
        .i_rst_n_core    (w_rst_n_core),
        .i_dev_act       (w_dev_act),
        .i_speed_hs      (w_speed == 2'd0),
        .i_test_nak      (w_test_nak),
        .i_tok_vld (w_tok_vld),
        .i_tok_ext (w_tok_ext),
        .i_tok_efld (w_tok_efld),
        .i_tok_pid (w_tok_pid),
        .i_tok_fld (w_tok_fld),
        .i_hs_vld (w_hs_vld),
        .i_hs_pid (w_hs_pid),
        .i_dat_sop (w_dat_sop),
        .i_dat_pid (w_dat_pid),
        .i_dat_n (w_dat_n),
        .i_dat_b (w_dat_b),
        .i_dat_end (w_dat_end),
        .i_dat_ok (w_dat_ok),
        .i_dat_len (w_dat_len),
        .o_tx_req (w_dev_tx_req),
        .o_tx_kind (w_dev_tx_kind),
        .o_tx_pid (w_dev_tx_pid),
        .o_tx_len (w_dev_tx_len),
        .i_tx_done       (w_tx_done),
        .i_tx_fail       (w_tx_fail),
        .o_rxw_sop (w_dev_rxw_sop),
        .o_rxw_tag (w_dev_rxw_tag),
        .o_rxw_n (w_dev_rxw_n),
        .o_rxw_b (w_dev_rxw_b),
        .o_rxw_end (w_dev_rxw_end),
        .o_rxw_ok (w_dev_rxw_ok),
        .o_rxw_len (w_dev_rxw_len),
        .o_txr_start (w_dev_txr_start),
        .o_txr_q (w_dev_txr_q),
        .o_txr_len (w_dev_txr_len),
        .o_txr_commit (w_dev_txr_commit),
        .o_txr_cancel (w_dev_txr_cancel),
        .i_rx_free       (w_rx_free),
        .i_plq_free      (w_plq_free),
        .i_ep_cnt        (w_ep_cnt),
        .i_dctrl         (w_ph_dctrl),
        .i_lpm_cfg       (w_ph_lpm_cfg),
        .i_epi_ctrl      (w_ph_epi_ctl),
        .i_epi_xfer      (w_ph_epi_xfr),
        .i_epi_int_en    (w_ph_epi_ien),
        .i_epo_ctrl      (w_ph_epo_ctl),
        .i_epo_xfer      (w_ph_epo_xfr),
        .i_epo_int_en    (w_ph_epo_ien),
        .o_epi_ctrl_pub  (w_dev_epi_ctrl_pub),
        .o_epi_xfer_pub  (w_dev_epi_xfer_pub),
        .o_epo_ctrl_pub  (w_dev_epo_ctrl_pub),
        .o_epo_xfer_pub  (w_dev_epo_xfer_pub),
        .o_epi_int_set   (w_dev_epi_int_set),
        .o_epo_int_set   (w_dev_epo_int_set),
        .o_epi_ctrl_clr  (w_dev_epi_ctrl_clr),
        .o_epo_ctrl_clr  (w_dev_epo_ctrl_clr),
        .o_frame         (w_dev_frame),
        .o_uframe        (w_dev_uframe),
        .o_evt_sof       (w_dev_evt_sof),
        .o_evt_xfer      (w_dev_evt_xfer),
        .i_tx_starve     (w_tx_starve),
        .o_evt_udf       (w_dev_evt_udf),
        .o_lpm_vld       (w_dev_lpm_vld),
        .o_lpm_hird      (w_dev_lpm_hird),
        .o_lpm_rw        (w_dev_lpm_rw)
      );
      assign w_dev_tx_fld = 19'd0;
    end else begin : gen_nodev
      assign w_dev_tx_req = 1'b0;
      assign w_dev_tx_kind = 3'd0;
      assign w_dev_tx_pid = 4'h0;
      assign w_dev_tx_fld = 19'd0;
      assign w_dev_tx_len = 12'd0;
      assign w_dev_rxw_sop = 1'b0;
      assign w_dev_rxw_tag = 5'd0;
      assign w_dev_rxw_n = 2'd0;
      assign w_dev_rxw_b = 16'h0000;
      assign w_dev_rxw_end = 1'b0;
      assign w_dev_rxw_ok = 1'b0;
      assign w_dev_rxw_len = 12'd0;
      assign w_dev_txr_start = 1'b0;
      assign w_dev_txr_q = 5'd0;
      assign w_dev_txr_len = 12'd0;
      assign w_dev_txr_commit = 1'b0;
      assign w_dev_txr_cancel = 1'b0;
      assign w_dev_evt_sof = 1'b0;
      assign w_dev_evt_xfer = 1'b0;
      assign w_dev_frame = 11'd0;
      assign w_dev_uframe = 3'd0;
      assign w_dev_lpm_vld = 1'b0;
      assign w_dev_lpm_hird = 4'd0;
      assign w_dev_lpm_rw = 1'b0;
      assign w_dev_evt_udf = 1'b0;
      assign w_dev_epi_ctrl_pub = '0;
      assign w_dev_epi_xfer_pub = '0;
      assign w_dev_epo_ctrl_pub = '0;
      assign w_dev_epo_xfer_pub = '0;
      assign w_dev_epi_int_set = '0;
      assign w_dev_epo_int_set = '0;
      assign w_dev_epi_ctrl_clr = '0;
      assign w_dev_epo_ctrl_clr = '0;
    end
  endgenerate

  // Host engine (builds with a host or a dual role).
  generate
    if (PARA_USB2_ROLE != 32'd0) begin : gen_host
      m_usb2_host #(
        .PARA_USB2_NHC    (PARA_USB2_NUM_HC),
        .PARA_USB2_UTMI_W (PARA_USB2_UTMI_W),
        .PARA_USB2_HQ_NP  (LPARA_HQ_NP),
        .PARA_USB2_TSCALE (PARA_USB2_TSCALE)
      ) u_host (
        .i_clk_phy       (i_clk_phy),
        .i_rst_n_core    (w_rst_n_core),
        .i_host_act      (w_host_act),
        .i_host_quiet    (w_host_quiet),
        .i_port_speed    (w_speed),
        .i_hs_vld (w_hs_vld),
        .i_hs_pid (w_hs_pid),
        .i_dat_sop (w_dat_sop),
        .i_dat_pid (w_dat_pid),
        .i_dat_n (w_dat_n),
        .i_dat_b (w_dat_b),
        .i_dat_end (w_dat_end),
        .i_dat_ok (w_dat_ok),
        .i_dat_len (w_dat_len),
        .o_tx_req (w_host_tx_req),
        .o_tx_kind (w_host_tx_kind),
        .o_tx_pid (w_host_tx_pid),
        .o_tx_fld (w_host_tx_fld),
        .o_tx_len (w_host_tx_len),
        .i_tx_done       (w_tx_done),
        .i_tx_fail       (w_tx_fail),
        .o_rxw_sop (w_host_rxw_sop),
        .o_rxw_tag (w_host_rxw_tag),
        .o_rxw_n (w_host_rxw_n),
        .o_rxw_b (w_host_rxw_b),
        .o_rxw_end (w_host_rxw_end),
        .o_rxw_ok (w_host_rxw_ok),
        .o_rxw_len (w_host_rxw_len),
        .o_txr_start (w_host_txr_start),
        .o_txr_q (w_host_txr_q),
        .o_txr_len (w_host_txr_len),
        .o_txr_commit (w_host_txr_commit),
        .o_txr_cancel (w_host_txr_cancel),
        .i_rx_free       (w_rx_free),
        .i_plq_free      (w_plq_free),
        .i_q_cnt         (w_hq_cnt),
        .i_hport         (w_ph_hport),
        .i_sof_cfg       (w_ph_sof_cfg),
        .i_hc_ctrl       (w_ph_hc_ctrl),
        .i_hc_split      (w_ph_hc_spl),
        .i_hc_xfer       (w_ph_hc_xfer),
        .i_hc_int_en     (w_ph_hc_ien),
        .i_hc_cfg        (w_ph_hc_cfg),
        .o_hc_xfer_pub   (w_host_hc_xfer_pub),
        .o_hc_cfg_pub    (w_host_hc_cfg_pub),
        .o_hc_int_set    (w_host_hc_int_set),
        .o_hc_ctrl_clr   (w_host_hc_ctrl_clr),
        .o_frame         (w_host_frame),
        .o_evt_sof       (w_host_evt_sof),
        .o_evt_xfer      (w_host_evt_xfer),
        .o_lpm_evt       (w_host_lpm_evt),
        .o_lpm_ack       (w_host_lpm_ack),
        .o_lpm_clr       (w_host_lpm_clr)
      );
    end else begin : gen_nohost
      assign w_host_tx_req = 1'b0;
      assign w_host_tx_kind = 3'd0;
      assign w_host_tx_pid = 4'h0;
      assign w_host_tx_fld = 19'd0;
      assign w_host_tx_len = 12'd0;
      assign w_host_rxw_sop = 1'b0;
      assign w_host_rxw_tag = 5'd0;
      assign w_host_rxw_n = 2'd0;
      assign w_host_rxw_b = 16'h0000;
      assign w_host_rxw_end = 1'b0;
      assign w_host_rxw_ok = 1'b0;
      assign w_host_rxw_len = 12'd0;
      assign w_host_txr_start = 1'b0;
      assign w_host_txr_q = 5'd0;
      assign w_host_txr_len = 12'd0;
      assign w_host_txr_commit = 1'b0;
      assign w_host_txr_cancel = 1'b0;
      assign w_host_evt_sof = 1'b0;
      assign w_host_evt_xfer = 1'b0;
      assign w_host_frame = 14'd0;
      assign w_host_lpm_evt = 1'b0;
      assign w_host_lpm_ack = 1'b0;
      assign w_host_lpm_clr = 1'b0;
      assign w_host_hc_xfer_pub = '0;
      assign w_host_hc_cfg_pub = '0;
      assign w_host_hc_int_set = '0;
      assign w_host_hc_ctrl_clr = '0;
    end
  endgenerate

  // Region configuration of the FIFO manager: the start (low half) and size (high half) words.
  always_comb begin : p_com_regions
    w_q_base = '0;
    w_q_size = '0;
    w_q_base[15:0] = w_ph_fifo_rx[15:0];
    w_q_size[15:0] = w_ph_fifo_rx[31:16];
    for (int idx = 0; idx < LPARA_NEP1; idx++) begin
      w_q_base[(idx + 1)*16 +: 16] = w_ph_epi_buf[idx][15:0];
      w_q_size[(idx + 1)*16 +: 16] = w_ph_epi_buf[idx][31:16];
    end
    w_q_base[(LPARA_NQ - 2)*16 +: 16] = w_ph_fifo_hnp[15:0];
    w_q_size[(LPARA_NQ - 2)*16 +: 16] = w_ph_fifo_hnp[31:16];
    w_q_base[(LPARA_NQ - 1)*16 +: 16] = w_ph_fifo_hpt[15:0];
    w_q_size[(LPARA_NQ - 1)*16 +: 16] = w_ph_fifo_hpt[31:16];
  end

  // Flush requests of u2_fifo_ctl and the command edges of CLK-PHY.
  always_ff @(posedge i_clk_phy, negedge w_rst_n_core) begin : p_ff_edges
    if (!w_rst_n_core) begin
      reg_flc_seen   <= 2'b00;
      reg_lpclr_seen <= 1'b0;
      reg_acc_seen   <= 1'b0;
    end else begin
      reg_flc_seen   <= w_ph_fifo_ctl[1:0];
      reg_lpclr_seen <= w_ph_lpbk_sts[24];
      reg_acc_seen   <= w_ph_phy_acc[25];
    end
  end

  assign w_fl_rx      = w_ph_fifo_ctl[0] & ~reg_flc_seen[0];
  assign w_fl_tx      = w_ph_fifo_ctl[1] & ~reg_flc_seen[1];
  assign w_flush_vld  = w_fl_rx | w_fl_tx;
  // u2_fifo_ctl.tx_sel names a device IN endpoint (0 to 15) or a host region (10h, 11h); the FIFO
  // queues are numbered receive 0, IN endpoint n = n + 1, host non-periodic and periodic last
  // (BUG-025).
  assign w_txq_phy    = w_ph_fifo_ctl[6] ? (LPARA_NQ[4:0] - 5'd2 + {4'd0, w_ph_fifo_ctl[2]}) : ({1'b0, w_ph_fifo_ctl[5:2]} + 5'd1);
  assign w_txq_bus    = w_bus_fifo_ctl[6] ? (LPARA_NQ[4:0] - 5'd2 + {4'd0, w_bus_fifo_ctl[2]}) : ({1'b0, w_bus_fifo_ctl[5:2]} + 5'd1);
  assign w_flush_q    = w_fl_rx ? 5'd0 : w_txq_phy;
  assign w_lpclr_edge = w_ph_lpbk_sts[24] & ~reg_lpclr_seen;
  assign w_acc_edge   = w_ph_phy_acc[25] & ~reg_acc_seen;
  assign w_reg_start  = w_acc_edge;

  // Packet port: the engine of the active role drives it; the idle engine drives zeros.
  assign w_rxw_sop    = w_dev_rxw_sop | w_host_rxw_sop;
  assign w_rxw_end    = w_dev_rxw_end | w_host_rxw_end;
  assign w_rxw_tag    = w_role_host ? w_host_rxw_tag : w_dev_rxw_tag;
  assign w_rxw_n      = w_role_host ? w_host_rxw_n : w_dev_rxw_n;
  assign w_rxw_b      = w_role_host ? w_host_rxw_b : w_dev_rxw_b;
  assign w_rxw_ok     = w_role_host ? w_host_rxw_ok : w_dev_rxw_ok;
  assign w_rxw_len    = w_role_host ? w_host_rxw_len : w_dev_rxw_len;
  assign w_txr_start  = w_dev_txr_start | w_host_txr_start;
  assign w_txr_commit = w_dev_txr_commit | w_host_txr_commit;
  assign w_txr_cancel = w_dev_txr_cancel | w_host_txr_cancel;
  assign w_txr_q      = w_role_host ? w_host_txr_q : w_dev_txr_q;
  assign w_txr_len    = w_role_host ? w_host_txr_len : w_dev_txr_len;
  assign w_ep_cnt     = w_q_cnt[17 +: LPARA_NEP1*17];
  assign w_hq_cnt     = {w_q_cnt[(LPARA_NQ - 1)*17 +: 17], w_q_cnt[(LPARA_NQ - 2)*17 +: 17]};

  // FIFO manager.
  m_usb2_fifo #(
    .PARA_USB2_UTMI_W    (PARA_USB2_UTMI_W),
    .PARA_USB2_NQ        (LPARA_NQ),
    .PARA_USB2_FIFO_DEPTH (PARA_USB2_FIFO_DEPTH),
    .PARA_USB2_RAM_PAR_EN (PARA_USB2_RAM_PAR_EN),
    .PARA_USB2_RAM_1P    (PARA_USB2_RAM_1P)
  ) u_fifo (
    .i_clk_phy       (i_clk_phy),
    .i_rst_n_core    (w_rst_n_core),
    .i_q_base        (w_q_base),
    .i_q_size        (w_q_size),
    .i_flush_vld     (w_flush_vld),
    .i_flush_q       (w_flush_q),
    .i_rxw_sop       (w_rxw_sop),
    .i_rxw_tag       (w_rxw_tag),
    .i_rxw_n         (w_rxw_n),
    .i_rxw_b         (w_rxw_b),
    .i_rxw_end       (w_rxw_end),
    .i_rxw_ok        (w_rxw_ok),
    .i_rxw_len       (w_rxw_len),
    .o_rx_free       (w_rx_free),
    .o_plq_free      (w_plq_free),
    .i_txr_start     (w_txr_start),
    .i_txr_q         (w_txr_q),
    .i_txr_len       (w_txr_len),
    .i_txr_commit    (w_txr_commit),
    .i_txr_cancel    (w_txr_cancel),
    .i_src_pop       (w_fifo_src_pop),
    .o_src_dat       (w_fifo_src_dat),
    .o_src_vld       (w_fifo_src_vld),
    .o_q_cnt         (w_q_cnt),
    .i_bp_vld        (w_bp_vld),
    .i_bp_op         (w_bp_op),
    .i_bp_q          (w_bp_q),
    .i_bp_data       (w_bp_data),
    .o_bp_rdy        (w_bp_rdy),
    .o_bp_rsp_vld    (w_bp_rsp_vld),
    .o_bp_rsp_data   (w_bp_rsp_data),
    .o_ev_vld        (w_fev_vld),
    .o_ev_type       (w_fev_type),
    .o_ev_q          (w_fev_q),
    .o_ev_val        (w_fev_val),
    .i_ev_rdy        (w_fev_rdy),
    .o_ovf           (w_fifo_ovf),
    .o_par_err       (w_fifo_par)
  );

  // Crossing of the bus port between CLK-PHY and CLK-BUS.
  m_usb2_cdc_fifo #(
    .PARA_USB2_ROW_W (LPARA_ROW_W)
  ) u_cdc_fifo (
    .i_clk_bus     (i_clk_bus),
    .i_rst_n_bus   (w_rst_n_bus),
    .i_clk_phy     (i_clk_phy),
    .i_rst_n_phy   (w_rst_n_core),
    .i_rq_vld      (w_rq_vld),
    .i_rq_op       (w_rq_op),
    .i_rq_q        (w_rq_q),
    .i_rq_data     (w_rq_data),
    .o_rq_rdy      (w_rq_rdy),
    .o_rs_vld      (w_rs_vld),
    .o_rs_data     (w_rs_data),
    .i_rs_pop      (w_rs_pop),
    .o_ev_vld      (w_bev_vld),
    .o_ev_type     (w_bev_type),
    .o_ev_q        (w_bev_q),
    .o_ev_val      (w_bev_val),
    .i_ev_pop      (w_bev_pop),
    .o_bp_vld      (w_bp_vld),
    .o_bp_op       (w_bp_op),
    .o_bp_q        (w_bp_q),
    .o_bp_data     (w_bp_data),
    .i_bp_rdy      (w_bp_rdy),
    .i_bp_rsp_vld  (w_bp_rsp_vld),
    .i_bp_rsp_data (w_bp_rsp_data),
    .i_ev_vld      (w_fev_vld),
    .i_ev_type     (w_fev_type),
    .i_ev_q        (w_fev_q),
    .i_ev_val      (w_fev_val),
    .o_ev_rdy      (w_fev_rdy)
  );

  // Data interface: AXI4 master DMA or AXI4 slave windows with the DMA handshake.
  generate
    if (PARA_USB2_DATA_IF == 32'd0) begin : gen_dma
      m_usb2_dma #(
        .PARA_USB2_AXI_DATA_W (PARA_USB2_AXI_DATA_W),
        .PARA_USB2_AXI_ADDR_W (PARA_USB2_AXI_ADDR_W),
        .PARA_USB2_AXI_ID_W   (PARA_USB2_AXI_ID_W),
        .PARA_USB2_NEP1       (LPARA_NEP1),
        .PARA_USB2_NHC        (PARA_USB2_NUM_HC),
        .PARA_USB2_SG_EN      (PARA_USB2_SG_EN),
        .PARA_USB2_FIFO_DEPTH (PARA_USB2_FIFO_DEPTH)
      ) u_dma (
        .i_clk_bus     (i_clk_bus),
        .i_rst_n_bus   (w_rst_n_bus),
        .i_core_en     (w_bus_ctrl[0]),
        .i_dma_en      (w_bus_ctrl[5]),
        .i_role_host   (w_role_bus),
        .i_fl_tx       (w_bus_fifo_ctl[1]),
        .i_sg_mode     (w_bus_hsts[20]),
        .i_win_en      (w_bus_hsts[21]),
        .i_err_stop    (w_bus_ctrl[6]),
        .i_win_base    (w_bus_dma_wbase),
        .i_win_lim     (w_bus_dma_wlim),
        .i_tx_sel      (w_txq_bus),
        .i_dma_cfg     (w_bus_dma_cfg),
        .i_dma_hi      (w_bus_dma_hi),
        .i_fifo_hnp    (w_bus_fifo_hnp),
        .i_fifo_hpt    (w_bus_fifo_hpt),
        .i_epi_ctrl    (w_bus_epi_ctl),
        .i_epi_xfer    (w_bus_epi_xfr),
        .i_epi_dma     (w_bus_epi_dma),
        .i_epi_fifo    (w_bus_epi_buf),
        .i_epo_dma     (w_bus_epo_dma),
        .i_hc_ctrl     (w_bus_hc_ctrl),
        .i_hc_xfer     (w_bus_hc_xfer),
        .i_hc_dma      (w_bus_hc_dma),
        .o_ld_addr     (w_ld_addr),
        .o_ld_epi_we   (w_ld_epi_we),
        .o_ld_epo_we   (w_ld_epo_we),
        .o_ld_hc_we    (w_ld_hc_we),
        .o_rq_vld      (w_rq_vld),
        .o_rq_op       (w_rq_op),
        .o_rq_q        (w_rq_q),
        .o_rq_data     (w_rq_data),
        .i_rq_rdy      (w_rq_rdy),
        .i_rs_vld      (w_rs_vld),
        .i_rs_data     (w_rs_data),
        .o_rs_pop      (w_rs_pop),
        .i_ev_vld      (w_bev_vld),
        .i_ev_type     (w_bev_type),
        .i_ev_q        (w_bev_q),
        .i_ev_val      (w_bev_val),
        .o_ev_pop      (w_bev_pop),
        .o_axim_awid (o_axim_awid),
        .o_axim_awaddr (o_axim_awaddr),
        .o_axim_awlen (o_axim_awlen),
        .o_axim_awsize (o_axim_awsize),
        .o_axim_awburst (o_axim_awburst),
        .o_axim_awcache (o_axim_awcache),
        .o_axim_awprot (o_axim_awprot),
        .o_axim_awvalid (o_axim_awvalid),
        .o_axim_wdata (o_axim_wdata),
        .o_axim_wstrb (o_axim_wstrb),
        .o_axim_wlast (o_axim_wlast),
        .o_axim_wvalid (o_axim_wvalid),
        .o_axim_bready (o_axim_bready),
        .o_axim_arid (o_axim_arid),
        .o_axim_araddr (o_axim_araddr),
        .o_axim_arlen (o_axim_arlen),
        .o_axim_arsize (o_axim_arsize),
        .o_axim_arburst (o_axim_arburst),
        .o_axim_arcache (o_axim_arcache),
        .o_axim_arprot (o_axim_arprot),
        .o_axim_arvalid (o_axim_arvalid),
        .o_axim_rready (o_axim_rready),
        .i_axim_awready (i_axim_awready),
        .i_axim_wready (i_axim_wready),
        .i_axim_bid (i_axim_bid),
        .i_axim_bresp (i_axim_bresp),
        .i_axim_bvalid (i_axim_bvalid),
        .i_axim_arready (i_axim_arready),
        .i_axim_rid (i_axim_rid),
        .i_axim_rdata (i_axim_rdata),
        .i_axim_rresp (i_axim_rresp),
        .i_axim_rlast (i_axim_rlast),
        .i_axim_rvalid (i_axim_rvalid),
        .o_axi_err     (w_axi_err),
        .o_dma_err     (w_dma_err)
      );
      assign o_axis_awready = 1'b0;
      assign o_axis_wready = 1'b0;
      assign o_axis_bid = '0;
      assign o_axis_bresp = 2'b00;
      assign o_axis_bvalid = 1'b0;
      assign o_axis_arready = 1'b0;
      assign o_axis_rid = '0;
      assign o_axis_rdata = '0;
      assign o_axis_rresp = 2'b00;
      assign o_axis_rlast = 1'b0;
      assign o_axis_rvalid = 1'b0;
      assign o_dma_req = '0;
    end else begin : gen_axs
      m_usb2_axs #(
        .PARA_USB2_AXI_DATA_W (PARA_USB2_AXI_DATA_W),
        .PARA_USB2_AXI_ADDR_W (PARA_USB2_AXI_ADDR_W),
        .PARA_USB2_AXI_ID_W   (PARA_USB2_AXI_ID_W),
        .PARA_USB2_NUM_DMA_CH (PARA_USB2_NUM_DMA_CH),
        .PARA_USB2_NEP1       (LPARA_NEP1),
        .PARA_USB2_FIFO_DEPTH (PARA_USB2_FIFO_DEPTH),
        .PARA_USB2_PIPE_AXS   (PARA_USB2_PIPE_AXS)
      ) u_axs (
        .i_clk_bus     (i_clk_bus),
        .o_err_evt     (w_axi_err),
        .i_rst_n_bus   (w_rst_n_bus),
        .i_core_en     (w_bus_ctrl[0]),
        .i_win_en      (w_bus_hsts[21]),
        .i_req_thr     (w_bus_dma_cfg[19:12]),
        .i_fifo_hnp    (w_bus_fifo_hnp),
        .i_fifo_hpt    (w_bus_fifo_hpt),
        .i_epi_ctrl    (w_bus_epi_ctl),
        .i_epi_fifo    (w_bus_epi_buf),
        .i_dmach_map   (w_bus_dma_map),
        .o_dma_req     (o_dma_req),
        .i_dma_ack     (i_dma_ack),
        .o_rq_vld      (w_rq_vld),
        .o_rq_op       (w_rq_op),
        .o_rq_q        (w_rq_q),
        .o_rq_data     (w_rq_data),
        .i_rq_rdy      (w_rq_rdy),
        .i_rs_vld      (w_rs_vld),
        .i_rs_data     (w_rs_data),
        .o_rs_pop      (w_rs_pop),
        .i_ev_vld      (w_bev_vld),
        .i_ev_type     (w_bev_type),
        .i_ev_q        (w_bev_q),
        .i_ev_val      (w_bev_val),
        .o_ev_pop      (w_bev_pop),
        .i_axis_awid (i_axis_awid),
        .i_axis_awaddr (i_axis_awaddr),
        .i_axis_awlen (i_axis_awlen),
        .i_axis_awsize (i_axis_awsize),
        .i_axis_awburst (i_axis_awburst),
        .i_axis_awvalid (i_axis_awvalid),
        .i_axis_wdata (i_axis_wdata),
        .i_axis_wstrb (i_axis_wstrb),
        .i_axis_wlast (i_axis_wlast),
        .i_axis_wvalid (i_axis_wvalid),
        .i_axis_bready (i_axis_bready),
        .i_axis_arid (i_axis_arid),
        .i_axis_araddr (i_axis_araddr),
        .i_axis_arlen (i_axis_arlen),
        .i_axis_arsize (i_axis_arsize),
        .i_axis_arburst (i_axis_arburst),
        .i_axis_arvalid (i_axis_arvalid),
        .i_axis_rready (i_axis_rready),
        .o_axis_awready (o_axis_awready),
        .o_axis_wready (o_axis_wready),
        .o_axis_bid (o_axis_bid),
        .o_axis_bresp (o_axis_bresp),
        .o_axis_bvalid (o_axis_bvalid),
        .o_axis_arready (o_axis_arready),
        .o_axis_rid (o_axis_rid),
        .o_axis_rdata (o_axis_rdata),
        .o_axis_rresp (o_axis_rresp),
        .o_axis_rlast (o_axis_rlast),
        .o_axis_rvalid (o_axis_rvalid)
      );
      assign o_axim_awid = '0;
      assign o_axim_awaddr = '0;
      assign o_axim_awlen = 8'd0;
      assign o_axim_awsize = 3'd0;
      assign o_axim_awburst = 2'b00;
      assign o_axim_awcache = 4'd0;
      assign o_axim_awprot = 3'd0;
      assign o_axim_awvalid = 1'b0;
      assign o_axim_wdata = '0;
      assign o_axim_wstrb = '0;
      assign o_axim_wlast = 1'b0;
      assign o_axim_wvalid = 1'b0;
      assign o_axim_bready = 1'b0;
      assign o_axim_arid = '0;
      assign o_axim_araddr = '0;
      assign o_axim_arlen = 8'd0;
      assign o_axim_arsize = 3'd0;
      assign o_axim_arburst = 2'b00;
      assign o_axim_arcache = 4'd0;
      assign o_axim_arprot = 3'd0;
      assign o_axim_arvalid = 1'b0;
      assign o_axim_rready = 1'b0;
      assign w_ld_addr   = 32'd0;
      assign w_ld_epi_we = '0;
      assign w_ld_epo_we = '0;
      assign w_ld_hc_we  = '0;
      assign w_dma_err   = 1'b0;
    end
  endgenerate

  // Published words of the status registers.
  assign w_pub_sts      = {23'd0, ~w_iddig, w_vbusvalid, w_linestate, w_suspended, w_attached, w_speed, w_role_host};
  assign w_pub_dsts     = {11'd0, w_spd_lpm_rw, w_spd_lpm_hird, w_l1_state, w_susp_det, w_dev_uframe, w_dev_frame};
  // Wake request of the always-on ULPI logic from the bus-side CSR bits: the remote wake
  // request of a device
  // (with remote wake enabled) and the resume request of a host port.
  assign w_wake_csr     = (w_bus_dctrl[8] & w_bus_dctrl[9] & ~w_role_bus) | (w_bus_hport[2] & w_role_bus);
  assign w_pub_hsts     = {13'd0, w_host_frame, w_suspended & w_role_host, w_speed, w_port_en, w_attached & w_role_host};
  assign w_pub_phy_acc  = {5'd0, w_reg_busy, 2'd0, w_reg_rdata, 16'd0};
  assign w_pub_lpbk_sts = {8'd0, w_lpbk_err, w_lpbk_ok};
  assign w_pub_epi_ctl = w_dev_epi_ctrl_pub;
  assign w_pub_epi_xfr = w_dev_epi_xfer_pub;
  assign w_pub_epo_ctl = w_dev_epo_ctrl_pub;
  assign w_pub_epo_xfr = w_dev_epo_xfer_pub;
  assign w_pub_hc_xfer  = w_host_hc_xfer_pub;
  assign w_pub_hc_cfg   = w_host_hc_cfg_pub;

  // Event sets: the interrupt causes of CLK-PHY in the bit positions of u2_irq_raw.
  // Response time-out and isochronous-incomplete events of every endpoint and channel also reach
  // the global flags (REQ-ERR-001, REQ-FUNC-033, BUG-011, BUG-012).
  always_comb begin : p_com_evt_sum
    w_evt_tmo = 1'b0;
    w_evt_iso = 1'b0;
    for (int idx = 0; idx < LPARA_NEP1; idx++) begin
      w_evt_tmo = w_evt_tmo | w_dev_epi_int_set[idx][2];
      w_evt_iso = w_evt_iso | w_dev_epi_int_set[idx][9] | w_dev_epo_int_set[idx][9];
    end
    for (int idx = 0; idx < PARA_USB2_NUM_HC; idx++) begin
      w_evt_tmo = w_evt_tmo | w_host_hc_int_set[idx][2];
      w_evt_iso = w_evt_iso | w_host_hc_int_set[idx][12];
    end
  end
  assign w_set_irq_raw = {7'd0, 1'b0, w_fifo_par, 1'b0, w_evt_iso, w_reg_done, w_host_evt_xfer, w_dev_evt_xfer,
                          (w_dev_lpm_vld | w_host_lpm_evt), 1'b0, 1'b0, w_dev_evt_udf, w_fifo_ovf, w_err_babble, w_evt_tmo, w_err_stuf,
                          w_err_crc, w_err_pid, w_evt_enum, w_evt_role, w_evt_disc, w_evt_conn,
                          w_evt_resume, w_evt_susp, w_evt_rst, (w_dev_evt_sof | w_host_evt_sof)};
  assign w_set_epi_int  = w_dev_epi_int_set;
  assign w_set_epo_int  = w_dev_epo_int_set;
  assign w_set_hc_int   = w_host_hc_int_set;

  // Command clears: bits that the engines took (the rwi fields of the registers).
  assign w_clr_dctrl    = {23'd0, w_clr_rmt_wake, 8'd0};
  assign w_clr_hport    = {23'd0, w_host_lpm_clr, 5'd0, w_clr_port_res, w_clr_port_susp, w_clr_port_rst};
  assign w_clr_phy_acc  = {6'd0, w_reg_done, 25'd0};
  assign w_clr_fifo_ctl = {30'd0, w_fl_tx, w_fl_rx};
  assign w_clr_lpbk_sts = {7'd0, w_lpclr_edge, 24'd0};
  assign w_clr_epi_ctl = w_dev_epi_ctrl_clr;
  assign w_clr_epo_ctl = w_dev_epo_ctrl_clr;
  assign w_clr_hc_ctrl  = w_host_hc_ctrl_clr;

endmodule
