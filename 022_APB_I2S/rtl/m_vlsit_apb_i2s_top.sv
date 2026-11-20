/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Structural top of the APB4 I2S, PCM and TDM controller. It holds the interface,
 *                the parameters, the interconnect and the instances only: two reset synchronizers,
 *                the generated register block (instantiated once), the register control, the
 *                interrupt logic, and for each present unit (transmit, receive) the configuration
 *                crossing, the FIFO, the frame engine and the serializer or deserializer, plus the
 *                DMA handshake of each direction. Ports of an absent unit or feature stay in the
 *                interface and are tied off (a pure SystemVerilog interface cannot drop ports).
 *                Clock domains: i_clk_apb (register side) and i_clk_mclk (all serial logic).
 * Decisions    : DEC-001, DEC-002, DEC-005..DEC-011, DEC-014..DEC-019
 */
`timescale 1ns/1ps

module m_vlsit_apb_i2s_top #(
  // Parameter Description: transmit unit present (registers, FIFO, engine, serializer, ports).
  // Parameter values: 0 or 1; default is 1. At least one of the two units shall be present.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_TX_EN = 1,
  // Parameter Description: receive unit present.
  // Parameter values: 0 or 1; default is 1. At least one of the two units shall be present.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_RX_EN = 1,
  // Parameter Description: transmit data lines, one FIFO per line.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_TX_LINES = 1,
  // Parameter Description: receive data lines, one FIFO per line.
  // Parameter values: 1 to 4; default is 1.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_RX_LINES = 1,
  // Parameter Description: words of each line FIFO.
  // Parameter values: 2, 4, 8, 16, 32, 64, 128 or 256; default is 16.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_FIFO_DEPTH = 16,
  // Parameter Description: largest number of slots of a frame.
  // Parameter values: 2 to 32; default is 32. Forced to 2 when the extended formats are off.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_MAX_SLOTS = 32,
  // Parameter Description: left-justified, PCM, TDM and custom frame sync, more than 2 slots.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_FMT_EXT_EN = 1,
  // Parameter Description: 16-bit packing of two samples in one FIFO word.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_PACK_EN = 1,
  // Parameter Description: bit clock divider and master role.
  // Parameter values: 0 or 1; default is 1. With 0 the units are slaves only.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_MASTER_EN = 1,
  // Parameter Description: on-demand frame start of a master.
  // Parameter values: 0 or 1; default is 1. Needs the master divider.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_ONDEM_EN = 1,
  // Parameter Description: release of masked transmit slots (tri-state).
  // Parameter values: 0 or 1; default is 1. Needs the transmit unit.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_TRI_EN = 1,
  // Parameter Description: hung clock timer.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_HUNG_EN = 1,
  // Parameter Description: DMA handshake.
  // Parameter values: 0 or 1; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_I2S_DMA_EN = 1,
  // Parameter Description: synchronizer stages of every crossing (the event crossings use two).
  // Parameter values: 2 or 3; default is 2.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_SYNC_DEPTH = 2,
  localparam logic [31:0] LPARA_ADDR_W = 32'd16,
  localparam logic [31:0] LPARA_DATA_W = 32'd32,
  localparam logic [31:0] LPARA_LVL_W  = 32'd12,
  localparam logic [31:0] LPARA_IRQ_N  = 32'd8,
  localparam logic [31:0] LPARA_MAX_LINES = 32'd4,
  localparam logic [31:0] LPARA_WORD_W = 32'd32,
  // Capability constants of the build, read through the capability register.
  localparam logic [31:0] LPARA_CAP_FMT_EXT = (PARA_I2S_FMT_EXT_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_DMA     = (PARA_I2S_DMA_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_HUNG    = (PARA_I2S_HUNG_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_TRI     = ((PARA_I2S_TRI_EN != 32'd0) &&
                                               (PARA_I2S_TX_EN != 32'd0)) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_ONDEM   = ((PARA_I2S_ONDEM_EN != 32'd0) &&
                                               (PARA_I2S_MASTER_EN != 32'd0)) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_DIV     = (PARA_I2S_MASTER_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_PACK    = (PARA_I2S_PACK_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_TX_PRES = (PARA_I2S_TX_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_RX_PRES = (PARA_I2S_RX_EN != 32'd0) ? 32'd1 : 32'd0,
  localparam logic [31:0] LPARA_CAP_MAX_SLOT = (PARA_I2S_FMT_EXT_EN != 32'd0) ? PARA_I2S_MAX_SLOTS : 32'd2,
  localparam logic [31:0] LPARA_CAP_DEPTH_L2 = $clog2(PARA_I2S_FIFO_DEPTH),
  localparam logic [31:0] LPARA_CAP_TX_LINES = (PARA_I2S_TX_EN != 32'd0) ? PARA_I2S_TX_LINES : 32'd0,
  localparam logic [31:0] LPARA_CAP_RX_LINES = (PARA_I2S_RX_EN != 32'd0) ? PARA_I2S_RX_LINES : 32'd0
) (
  // Clocks and resets
  input  wire                     i_clk_apb,
  input  wire                     i_rst_n_apb,
  input  wire                     i_clk_mclk,
  input  wire                     i_rst_n_mclk,

  // APB4 completer
  input  wire                     i_apb_psel,
  input  wire                     i_apb_penable,
  input  wire                     i_apb_pwrite,
  input  wire  [LPARA_ADDR_W-1:0] i_apb_paddr,
  input  wire  [LPARA_DATA_W-1:0] i_apb_pwdata,
  input  wire  [3:0]              i_apb_pstrb,
  input  wire  [2:0]              i_apb_pprot,
  output logic                    o_apb_pready,
  output logic                    o_apb_pslverr,
  output logic [LPARA_DATA_W-1:0] o_apb_prdata,

  // Static configuration of the register block
  input  wire                     i_protect_en,
  input  wire                     i_slverr_en,

  // Transmit serial interface
  output logic                    o_bclk_tx,
  output logic                    o_bclk_tx_oe,
  input  wire                     i_bclk_tx,
  output logic                    o_ws_tx,
  output logic                    o_ws_tx_oe,
  input  wire                     i_ws_tx,
  output logic                    o_sdo_0,
  output logic                    o_sdo_1,
  output logic                    o_sdo_2,
  output logic                    o_sdo_3,
  output logic                    o_sdo_oe,

  // Receive serial interface
  output logic                    o_bclk_rx,
  output logic                    o_bclk_rx_oe,
  input  wire                     i_bclk_rx,
  output logic                    o_ws_rx,
  output logic                    o_ws_rx_oe,
  input  wire                     i_ws_rx,
  input  wire                     i_sdi_0,
  input  wire                     i_sdi_1,
  input  wire                     i_sdi_2,
  input  wire                     i_sdi_3,

  // DMA handshake
  output logic                    o_dma_tx_req,
  input  wire                     i_dma_tx_ack,
  output logic                    o_dma_tx_single,
  output logic                    o_dma_rx_req,
  input  wire                     i_dma_rx_ack,
  output logic                    o_dma_rx_single,

  // Interrupt
  output logic                    o_int_i2s
);

  // Resets synchronized in each domain
  logic w_rst_n_apb;
  logic w_rst_n_mclk;

  // Register block: bus events, generated field outputs, and design inputs
  logic w_reg_rd_en;
  logic [LPARA_ADDR_W-1:0] w_reg_rd_addr;
  logic w_reg_wr_en;
  logic [LPARA_ADDR_W-1:0] w_reg_wr_addr;
  logic w_i2s_ctrl_frm_sel;
  logic w_i2s_ctrl_srst;
  logic w_i2s_tx_ctrl_dma;
  logic w_i2s_tx_ctrl_tri;
  logic w_i2s_tx_ctrl_auto;
  logic w_i2s_tx_ctrl_ondem;
  logic w_i2s_tx_ctrl_shr;
  logic w_i2s_tx_ctrl_role;
  logic w_i2s_tx_ctrl_flush;
  logic w_i2s_tx_ctrl_srst;
  logic w_i2s_tx_ctrl_en;
  logic [5:0] w_i2s_tx_frame_data_w;
  logic [5:0] w_i2s_tx_frame_slot_w;
  logic [5:0] w_i2s_tx_frame_nslot;
  logic w_i2s_tx_frame_pack;
  logic w_i2s_tx_frame_align;
  logic [2:0] w_i2s_tx_frame_fmt;
  logic w_i2s_tx_sync_bpol;
  logic w_i2s_tx_sync_fse;
  logic w_i2s_tx_sync_fsp;
  logic [5:0] w_i2s_tx_sync_sync_w;
  logic [15:0] w_i2s_tx_clk_div;
  logic [31:0] w_i2s_tx_mask_mask;
  logic [11:0] w_i2s_tx_fifo_wm;
  logic w_i2s_tx_sts_hung;
  logic w_i2s_tx_sts_sync;
  logic [31:0] w_i2s_tx_data_data;
  logic [15:0] w_i2s_tx_tmo_tmo;
  logic w_i2s_rx_ctrl_dma;
  logic w_i2s_rx_ctrl_tri;
  logic w_i2s_rx_ctrl_auto;
  logic w_i2s_rx_ctrl_ondem;
  logic w_i2s_rx_ctrl_shr;
  logic w_i2s_rx_ctrl_role;
  logic w_i2s_rx_ctrl_flush;
  logic w_i2s_rx_ctrl_srst;
  logic w_i2s_rx_ctrl_en;
  logic [5:0] w_i2s_rx_frame_data_w;
  logic [5:0] w_i2s_rx_frame_slot_w;
  logic [5:0] w_i2s_rx_frame_nslot;
  logic w_i2s_rx_frame_pack;
  logic w_i2s_rx_frame_align;
  logic [2:0] w_i2s_rx_frame_fmt;
  logic w_i2s_rx_sync_bpol;
  logic w_i2s_rx_sync_fse;
  logic w_i2s_rx_sync_fsp;
  logic [5:0] w_i2s_rx_sync_sync_w;
  logic [15:0] w_i2s_rx_clk_div;
  logic [31:0] w_i2s_rx_mask_mask;
  logic [11:0] w_i2s_rx_fifo_wm;
  logic w_i2s_rx_sts_hung;
  logic w_i2s_rx_sts_sync;
  logic [15:0] w_i2s_rx_tmo_tmo;
  logic [LPARA_IRQ_N-1:0] w_irq_raw;
  logic [LPARA_IRQ_N-1:0] w_irq_en;
  logic [LPARA_IRQ_N-1:0] w_irq_inj;
  logic [LPARA_IRQ_N-1:0] w_irq_sts;
  logic [LPARA_IRQ_N-1:0] w_raw_we;
  logic [LPARA_IRQ_N-1:0] w_raw_wdata;
  logic w_irq_any;

  // Register control
  logic w_hw_clr_glob_srst;
  logic w_hw_clr_tx_srst;
  logic w_hw_clr_tx_flush;
  logic w_hw_clr_rx_srst;
  logic w_hw_clr_rx_flush;
  logic w_hw_clr_tx_data;
  logic [PARA_I2S_TX_LINES-1:0] w_tx_wr_en;
  logic w_tx_flush_req;
  logic w_tx_srst_req;
  logic w_tx_flag_clr;
  logic [LPARA_LVL_W-1:0] w_tx_level_r;
  logic w_tx_empty_r;
  logic w_tx_full_r;
  logic w_tx_busy_r;
  logic w_tx_wm_cond;
  logic [PARA_I2S_RX_LINES-1:0] w_rx_rd_en;
  logic [LPARA_WORD_W-1:0] w_rx_data_r;
  logic w_rx_flush_req;
  logic w_rx_srst_req;
  logic w_rx_flag_clr;
  logic [LPARA_LVL_W-1:0] w_rx_level_r;
  logic w_rx_empty_r;
  logic w_rx_full_r;
  logic w_rx_busy_r;
  logic w_rx_wm_cond;

  // Transmit unit results, tied off when the unit is absent
  logic [PARA_I2S_TX_LINES-1:0] w_tx_full;
  logic [LPARA_LVL_W-1:0] w_tx_level;
  logic w_tx_flush_done;
  logic w_tx_ovr;
  logic [3:0] w_tx_ev_apb;
  logic [1:0] w_tx_flag_we;
  logic [1:0] w_tx_flag_wdata;
  logic w_tx_busy_s;
  logic w_tx_eff_bclk;
  logic w_tx_eff_ws;
  logic [LPARA_MAX_LINES-1:0] w_tx_sdo4;

  // Receive unit results, tied off when the unit is absent
  logic [PARA_I2S_RX_LINES*LPARA_WORD_W-1:0] w_rx_rdata;
  logic [PARA_I2S_RX_LINES-1:0] w_rx_empty;
  logic [LPARA_LVL_W-1:0] w_rx_level;
  logic w_rx_flush_done;
  logic [3:0] w_rx_ev_apb;
  logic [1:0] w_rx_flag_we;
  logic [1:0] w_rx_flag_wdata;
  logic w_rx_busy_s;
  logic w_rx_eff_bclk;
  logic w_rx_eff_ws;
  logic [LPARA_MAX_LINES-1:0] w_sdi4;

  // Reset synchronizers: asynchronous assertion, synchronous release in each domain (DEC-007).
  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (PARA_I2S_SYNC_DEPTH)
  ) u_rstsync_apb (
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_src (i_rst_n_apb),
    .o_rst_n_dst (w_rst_n_apb)
  );

  m_vlsit_rst_sync #(
    .PARA_RST_SYNC_TYPE (PARA_I2S_SYNC_DEPTH)
  ) u_rstsync_mclk (
    .i_clk_dst   (i_clk_mclk),
    .i_rst_n_src (i_rst_n_mclk),
    .o_rst_n_dst (w_rst_n_mclk)
  );

  // Generated APB4 register block, instantiated once. The register clock is the APB clock.
  m_vlsit_csr_i2s #(
    .PARA_ASYNCHRONOUS (32'd0)
  ) u_csr_i2s (
    .i_clk_apb                     (i_clk_apb),
    .i_rst_n_apb                   (w_rst_n_apb),
    .i_clk_reg                     (i_clk_apb),
    .i_rst_n_reg                   (w_rst_n_apb),
    .i_apb_paddr                   (i_apb_paddr),
    .i_protect_en                  (i_protect_en),
    .i_slverr_en                   (i_slverr_en),
    .i_apb_pprot                   (i_apb_pprot),
    .i_apb_pwdata                  (i_apb_pwdata),
    .i_apb_pwrite                  (i_apb_pwrite),
    .i_apb_penable                 (i_apb_penable),
    .i_apb_psel                    (i_apb_psel),
    .i_apb_pstrb                   (i_apb_pstrb),
    .o_apb_pslverr                 (o_apb_pslverr),
    .o_apb_pready                  (o_apb_pready),
    .o_apb_prdata                  (o_apb_prdata),
    .o_reg_rd_en                   (w_reg_rd_en),
    .o_reg_rd_addr                 (w_reg_rd_addr),
    .o_reg_wr_en                   (w_reg_wr_en),
    .o_reg_wr_addr                 (w_reg_wr_addr),
    .i_i2s_version_major           (16'd1),
    .i_i2s_version_minor           (16'd0),
    .i_i2s_cap_fmt_ext             (LPARA_CAP_FMT_EXT[0]),
    .i_i2s_cap_dma                 (LPARA_CAP_DMA[0]),
    .i_i2s_cap_hung                (LPARA_CAP_HUNG[0]),
    .i_i2s_cap_tri                 (LPARA_CAP_TRI[0]),
    .i_i2s_cap_ondem               (LPARA_CAP_ONDEM[0]),
    .i_i2s_cap_div                 (LPARA_CAP_DIV[0]),
    .i_i2s_cap_pack                (LPARA_CAP_PACK[0]),
    .i_i2s_cap_max_slot            (LPARA_CAP_MAX_SLOT[5:0]),
    .i_i2s_cap_depth_l2            (LPARA_CAP_DEPTH_L2[3:0]),
    .i_i2s_cap_rx_lines            (LPARA_CAP_RX_LINES[2:0]),
    .i_i2s_cap_tx_lines            (LPARA_CAP_TX_LINES[2:0]),
    .i_i2s_cap_rx_pres             (LPARA_CAP_RX_PRES[0]),
    .i_i2s_cap_tx_pres             (LPARA_CAP_TX_PRES[0]),
    .o_i2s_ctrl_frm_sel            (w_i2s_ctrl_frm_sel),
    .o_i2s_ctrl_srst               (w_i2s_ctrl_srst),
    .i_hw_clr_i2s_ctrl_srst        (w_hw_clr_glob_srst),
    .i_i2s_sts_irq                 (w_irq_any),
    .i_i2s_sts_rx_busy             (w_rx_busy_r),
    .i_i2s_sts_tx_busy             (w_tx_busy_r),
    .o_i2s_irq_raw_frm             (w_irq_raw[7]),
    .i_hw_wdata_i2s_irq_raw_frm    (w_raw_wdata[7]),
    .i_hw_we_i2s_irq_raw_frm       (w_raw_we[7]),
    .o_i2s_irq_raw_hung            (w_irq_raw[6]),
    .i_hw_wdata_i2s_irq_raw_hung   (w_raw_wdata[6]),
    .i_hw_we_i2s_irq_raw_hung      (w_raw_we[6]),
    .o_i2s_irq_raw_sync            (w_irq_raw[5]),
    .i_hw_wdata_i2s_irq_raw_sync   (w_raw_wdata[5]),
    .i_hw_we_i2s_irq_raw_sync      (w_raw_we[5]),
    .o_i2s_irq_raw_rx_ovr          (w_irq_raw[4]),
    .i_hw_wdata_i2s_irq_raw_rx_ovr (w_raw_wdata[4]),
    .i_hw_we_i2s_irq_raw_rx_ovr    (w_raw_we[4]),
    .o_i2s_irq_raw_rx_wm           (w_irq_raw[3]),
    .i_hw_wdata_i2s_irq_raw_rx_wm  (w_raw_wdata[3]),
    .i_hw_we_i2s_irq_raw_rx_wm     (w_raw_we[3]),
    .o_i2s_irq_raw_tx_ovr          (w_irq_raw[2]),
    .i_hw_wdata_i2s_irq_raw_tx_ovr (w_raw_wdata[2]),
    .i_hw_we_i2s_irq_raw_tx_ovr    (w_raw_we[2]),
    .o_i2s_irq_raw_tx_und          (w_irq_raw[1]),
    .i_hw_wdata_i2s_irq_raw_tx_und (w_raw_wdata[1]),
    .i_hw_we_i2s_irq_raw_tx_und    (w_raw_we[1]),
    .o_i2s_irq_raw_tx_wm           (w_irq_raw[0]),
    .i_hw_wdata_i2s_irq_raw_tx_wm  (w_raw_wdata[0]),
    .i_hw_we_i2s_irq_raw_tx_wm     (w_raw_we[0]),
    .o_i2s_irq_en_frm              (w_irq_en[7]),
    .o_i2s_irq_en_hung             (w_irq_en[6]),
    .o_i2s_irq_en_sync             (w_irq_en[5]),
    .o_i2s_irq_en_rx_ovr           (w_irq_en[4]),
    .o_i2s_irq_en_rx_wm            (w_irq_en[3]),
    .o_i2s_irq_en_tx_ovr           (w_irq_en[2]),
    .o_i2s_irq_en_tx_und           (w_irq_en[1]),
    .o_i2s_irq_en_tx_wm            (w_irq_en[0]),
    .o_i2s_irq_inj_frm             (w_irq_inj[7]),
    .o_i2s_irq_inj_hung            (w_irq_inj[6]),
    .o_i2s_irq_inj_sync            (w_irq_inj[5]),
    .o_i2s_irq_inj_rx_ovr          (w_irq_inj[4]),
    .o_i2s_irq_inj_rx_wm           (w_irq_inj[3]),
    .o_i2s_irq_inj_tx_ovr          (w_irq_inj[2]),
    .o_i2s_irq_inj_tx_und          (w_irq_inj[1]),
    .o_i2s_irq_inj_tx_wm           (w_irq_inj[0]),
    .i_i2s_irq_sts_frm             (w_irq_sts[7]),
    .i_i2s_irq_sts_hung            (w_irq_sts[6]),
    .i_i2s_irq_sts_sync            (w_irq_sts[5]),
    .i_i2s_irq_sts_rx_ovr          (w_irq_sts[4]),
    .i_i2s_irq_sts_rx_wm           (w_irq_sts[3]),
    .i_i2s_irq_sts_tx_ovr          (w_irq_sts[2]),
    .i_i2s_irq_sts_tx_und          (w_irq_sts[1]),
    .i_i2s_irq_sts_tx_wm           (w_irq_sts[0]),
    .o_i2s_tx_ctrl_dma             (w_i2s_tx_ctrl_dma),
    .o_i2s_tx_ctrl_tri             (w_i2s_tx_ctrl_tri),
    .o_i2s_tx_ctrl_auto            (w_i2s_tx_ctrl_auto),
    .o_i2s_tx_ctrl_ondem           (w_i2s_tx_ctrl_ondem),
    .o_i2s_tx_ctrl_shr             (w_i2s_tx_ctrl_shr),
    .o_i2s_tx_ctrl_role            (w_i2s_tx_ctrl_role),
    .o_i2s_tx_ctrl_flush           (w_i2s_tx_ctrl_flush),
    .i_hw_clr_i2s_tx_ctrl_flush    (w_hw_clr_tx_flush),
    .o_i2s_tx_ctrl_srst            (w_i2s_tx_ctrl_srst),
    .i_hw_clr_i2s_tx_ctrl_srst     (w_hw_clr_tx_srst),
    .o_i2s_tx_ctrl_en              (w_i2s_tx_ctrl_en),
    .o_i2s_tx_frame_data_w         (w_i2s_tx_frame_data_w),
    .o_i2s_tx_frame_slot_w         (w_i2s_tx_frame_slot_w),
    .o_i2s_tx_frame_nslot          (w_i2s_tx_frame_nslot),
    .o_i2s_tx_frame_pack           (w_i2s_tx_frame_pack),
    .o_i2s_tx_frame_align          (w_i2s_tx_frame_align),
    .o_i2s_tx_frame_fmt            (w_i2s_tx_frame_fmt),
    .o_i2s_tx_sync_bpol            (w_i2s_tx_sync_bpol),
    .o_i2s_tx_sync_fse             (w_i2s_tx_sync_fse),
    .o_i2s_tx_sync_fsp             (w_i2s_tx_sync_fsp),
    .o_i2s_tx_sync_sync_w          (w_i2s_tx_sync_sync_w),
    .o_i2s_tx_clk_div              (w_i2s_tx_clk_div),
    .o_i2s_tx_mask_mask            (w_i2s_tx_mask_mask),
    .o_i2s_tx_fifo_wm              (w_i2s_tx_fifo_wm),
    .i_i2s_tx_sts_level            (w_tx_level_r),
    .o_i2s_tx_sts_hung             (w_i2s_tx_sts_hung),
    .i_hw_wdata_i2s_tx_sts_hung    (w_tx_flag_wdata[1]),
    .i_hw_we_i2s_tx_sts_hung       (w_tx_flag_we[1]),
    .o_i2s_tx_sts_sync             (w_i2s_tx_sts_sync),
    .i_hw_wdata_i2s_tx_sts_sync    (w_tx_flag_wdata[0]),
    .i_hw_we_i2s_tx_sts_sync       (w_tx_flag_we[0]),
    .i_i2s_tx_sts_full             (w_tx_full_r),
    .i_i2s_tx_sts_empty            (w_tx_empty_r),
    .i_i2s_tx_sts_busy             (w_tx_busy_r),
    .o_i2s_tx_data_data            (w_i2s_tx_data_data),
    .i_hw_clr_i2s_tx_data_data     (w_hw_clr_tx_data),
    .o_i2s_tx_tmo_tmo              (w_i2s_tx_tmo_tmo),
    .o_i2s_rx_ctrl_dma             (w_i2s_rx_ctrl_dma),
    .o_i2s_rx_ctrl_tri             (w_i2s_rx_ctrl_tri),
    .o_i2s_rx_ctrl_auto            (w_i2s_rx_ctrl_auto),
    .o_i2s_rx_ctrl_ondem           (w_i2s_rx_ctrl_ondem),
    .o_i2s_rx_ctrl_shr             (w_i2s_rx_ctrl_shr),
    .o_i2s_rx_ctrl_role            (w_i2s_rx_ctrl_role),
    .o_i2s_rx_ctrl_flush           (w_i2s_rx_ctrl_flush),
    .i_hw_clr_i2s_rx_ctrl_flush    (w_hw_clr_rx_flush),
    .o_i2s_rx_ctrl_srst            (w_i2s_rx_ctrl_srst),
    .i_hw_clr_i2s_rx_ctrl_srst     (w_hw_clr_rx_srst),
    .o_i2s_rx_ctrl_en              (w_i2s_rx_ctrl_en),
    .o_i2s_rx_frame_data_w         (w_i2s_rx_frame_data_w),
    .o_i2s_rx_frame_slot_w         (w_i2s_rx_frame_slot_w),
    .o_i2s_rx_frame_nslot          (w_i2s_rx_frame_nslot),
    .o_i2s_rx_frame_pack           (w_i2s_rx_frame_pack),
    .o_i2s_rx_frame_align          (w_i2s_rx_frame_align),
    .o_i2s_rx_frame_fmt            (w_i2s_rx_frame_fmt),
    .o_i2s_rx_sync_bpol            (w_i2s_rx_sync_bpol),
    .o_i2s_rx_sync_fse             (w_i2s_rx_sync_fse),
    .o_i2s_rx_sync_fsp             (w_i2s_rx_sync_fsp),
    .o_i2s_rx_sync_sync_w          (w_i2s_rx_sync_sync_w),
    .o_i2s_rx_clk_div              (w_i2s_rx_clk_div),
    .o_i2s_rx_mask_mask            (w_i2s_rx_mask_mask),
    .o_i2s_rx_fifo_wm              (w_i2s_rx_fifo_wm),
    .i_i2s_rx_sts_level            (w_rx_level_r),
    .o_i2s_rx_sts_hung             (w_i2s_rx_sts_hung),
    .i_hw_wdata_i2s_rx_sts_hung    (w_rx_flag_wdata[1]),
    .i_hw_we_i2s_rx_sts_hung       (w_rx_flag_we[1]),
    .o_i2s_rx_sts_sync             (w_i2s_rx_sts_sync),
    .i_hw_wdata_i2s_rx_sts_sync    (w_rx_flag_wdata[0]),
    .i_hw_we_i2s_rx_sts_sync       (w_rx_flag_we[0]),
    .i_i2s_rx_sts_full             (w_rx_full_r),
    .i_i2s_rx_sts_empty            (w_rx_empty_r),
    .i_i2s_rx_sts_busy             (w_rx_busy_r),
    .i_i2s_rx_data_data            (w_rx_data_r),
    .o_i2s_rx_tmo_tmo              (w_i2s_rx_tmo_tmo)
  );

  // Register control: data register events, flush and soft reset, flags and levels.
  m_vlsit_i2s_regctl #(
    .PARA_I2S_TX_EN      (PARA_I2S_TX_EN),
    .PARA_I2S_RX_EN      (PARA_I2S_RX_EN),
    .PARA_I2S_TX_LINES   (PARA_I2S_TX_LINES),
    .PARA_I2S_RX_LINES   (PARA_I2S_RX_LINES),
    .PARA_I2S_FIFO_DEPTH (PARA_I2S_FIFO_DEPTH)
  ) u_regctl (
    .i_clk_apb          (i_clk_apb),
    .i_rst_n_apb        (w_rst_n_apb),
    .i_reg_wr_en        (w_reg_wr_en),
    .i_reg_wr_addr      (w_reg_wr_addr),
    .i_reg_rd_en        (w_reg_rd_en),
    .i_reg_rd_addr      (w_reg_rd_addr),
    .i_tx_wm            (w_i2s_tx_fifo_wm),
    .i_rx_wm            (w_i2s_rx_fifo_wm),
    .i_tx_en            (w_i2s_tx_ctrl_en),
    .i_rx_en            (w_i2s_rx_ctrl_en),
    .i_tx_busy_s        (w_tx_busy_s),
    .i_rx_busy_s        (w_rx_busy_s),
    .o_tx_wm_cond       (w_tx_wm_cond),
    .o_rx_wm_cond       (w_rx_wm_cond),
    .o_tx_busy          (w_tx_busy_r),
    .o_rx_busy          (w_rx_busy_r),
    .i_glob_srst        (w_i2s_ctrl_srst),
    .i_tx_srst          (w_i2s_tx_ctrl_srst),
    .i_tx_flush         (w_i2s_tx_ctrl_flush),
    .i_rx_srst          (w_i2s_rx_ctrl_srst),
    .i_rx_flush         (w_i2s_rx_ctrl_flush),
    .o_hw_clr_glob_srst (w_hw_clr_glob_srst),
    .o_hw_clr_tx_srst   (w_hw_clr_tx_srst),
    .o_hw_clr_tx_flush  (w_hw_clr_tx_flush),
    .o_hw_clr_rx_srst   (w_hw_clr_rx_srst),
    .o_hw_clr_rx_flush  (w_hw_clr_rx_flush),
    .o_hw_clr_tx_data   (w_hw_clr_tx_data),
    .i_tx_full          (w_tx_full),
    .i_tx_level         (w_tx_level),
    .i_tx_flush_done    (w_tx_flush_done),
    .o_tx_wr_en         (w_tx_wr_en),
    .o_tx_flush_req     (w_tx_flush_req),
    .o_tx_srst_req      (w_tx_srst_req),
    .o_tx_flag_clr      (w_tx_flag_clr),
    .o_tx_level         (w_tx_level_r),
    .o_tx_empty         (w_tx_empty_r),
    .o_tx_full          (w_tx_full_r),
    .i_rx_rdata         (w_rx_rdata),
    .i_rx_empty         (w_rx_empty),
    .i_rx_level         (w_rx_level),
    .i_rx_flush_done    (w_rx_flush_done),
    .o_rx_rd_en         (w_rx_rd_en),
    .o_rx_data          (w_rx_data_r),
    .o_rx_flush_req     (w_rx_flush_req),
    .o_rx_srst_req      (w_rx_srst_req),
    .o_rx_flag_clr      (w_rx_flag_clr),
    .o_rx_level         (w_rx_level_r),
    .o_rx_empty         (w_rx_empty_r),
    .o_rx_full          (w_rx_full_r)
  );

  // Interrupt logic: eight causes with raw, enable, injection and masked status.
  m_vlsit_i2s_irq #(
    .PARA_I2S_IRQ_N (LPARA_IRQ_N)
  ) u_irq (
    .i_clk_apb    (i_clk_apb),
    .i_rst_n_apb  (w_rst_n_apb),
    .i_tx_wm_cond (w_tx_wm_cond),
    .i_rx_wm_cond (w_rx_wm_cond),
    .i_tx_ovr     (w_tx_ovr),
    .i_ev_tx      (w_tx_ev_apb),
    .i_ev_rx      (w_rx_ev_apb),
    .i_frm_sel    (w_i2s_ctrl_frm_sel),
    .i_en         (w_irq_en),
    .i_inj        (w_irq_inj),
    .o_raw_we     (w_raw_we),
    .o_raw_wdata  (w_raw_wdata),
    .i_raw        (w_irq_raw),
    .o_sts        (w_irq_sts),
    .o_irq_any    (w_irq_any),
    .o_int        (o_int_i2s)
  );

  // Transmit unit: configuration crossing, FIFO, frame engine, serializer and DMA handshake.
  if (PARA_I2S_TX_EN != 32'd0) begin : gen_tx
    logic w_en_s;
    logic w_flush_ev;
    logic w_srst_ev;
    logic [3:0] w_ev_mclk;
    logic w_snap_valid;
    logic w_snap_take;
    logic w_mask_valid;
    logic w_mask_take;
    logic w_cfg_role;
    logic w_cfg_shr;
    logic w_cfg_ondem;
    logic w_cfg_auto;
    logic w_cfg_tri;
    logic [2:0] w_cfg_fmt;
    logic w_cfg_align;
    logic w_cfg_pack;
    logic [5:0] w_cfg_nslot;
    logic [5:0] w_cfg_slot_w;
    logic [5:0] w_cfg_data_w;
    logic [5:0] w_cfg_sync_w;
    logic w_cfg_fsp;
    logic w_cfg_fse;
    logic w_cfg_bpol;
    logic [15:0] w_cfg_div;
    logic [15:0] w_cfg_tmo;
    logic [31:0] w_cfg_mask;
    logic [31:0] w_mask_data;
    logic w_busy_mclk;
    logic [5:0] w_words_pf;
    logic w_rd_ready;
    logic [PARA_I2S_TX_LINES*LPARA_WORD_W-1:0] w_rd_data;
    logic [PARA_I2S_TX_LINES-1:0] w_rd_empty;
    logic [PARA_I2S_TX_LINES-1:0] w_rd_en;
    logic w_pop_slot;
    logic w_und;
    logic w_und_q;
    logic [5:0] w_data_w;
    logic w_align;
    logic w_pack;
    logic w_tri;
    logic w_on;
    logic w_tick_l;
    logic w_nx_active;
    logic w_nx_slot_start;
    logic w_nx_slot_en;
    logic w_nx_bit_vld;
    logic w_nx_pack_hi;
    logic w_ev_sync;
    logic w_ev_hung;
    logic w_ev_frm;
    logic [PARA_I2S_TX_LINES-1:0] w_sdo;

    // Event vector to the APB domain: underrun, sync error, hung clock, frame done.
    assign w_ev_mclk = {w_ev_frm, w_ev_hung, w_ev_sync, w_und_q};

    // Configuration crossing of the transmit unit.
    m_vlsit_i2s_cfgsync #(
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH)
    ) u_cfgsync_tx (
      .i_clk_apb    (i_clk_apb),
      .i_rst_n_apb  (w_rst_n_apb),
      .i_en         (w_i2s_tx_ctrl_en),
      .i_role       (w_i2s_tx_ctrl_role),
      .i_shr        (w_i2s_tx_ctrl_shr),
      .i_shr_block  (w_i2s_rx_ctrl_shr),
      .i_ondem      (w_i2s_tx_ctrl_ondem),
      .i_auto       (w_i2s_tx_ctrl_auto),
      .i_tri        (w_i2s_tx_ctrl_tri),
      .i_fmt        (w_i2s_tx_frame_fmt),
      .i_align      (w_i2s_tx_frame_align),
      .i_pack       (w_i2s_tx_frame_pack),
      .i_nslot      (w_i2s_tx_frame_nslot),
      .i_slot_w     (w_i2s_tx_frame_slot_w),
      .i_data_w     (w_i2s_tx_frame_data_w),
      .i_sync_w     (w_i2s_tx_sync_sync_w),
      .i_fsp        (w_i2s_tx_sync_fsp),
      .i_fse        (w_i2s_tx_sync_fse),
      .i_bpol       (w_i2s_tx_sync_bpol),
      .i_div        (w_i2s_tx_clk_div),
      .i_tmo        (w_i2s_tx_tmo_tmo),
      .i_mask       (w_i2s_tx_mask_mask),
      .i_flush_req  (w_tx_flush_req),
      .i_srst_req   (w_tx_srst_req),
      .i_flag_clr   (w_tx_flag_clr),
      .o_flag_we    (w_tx_flag_we),
      .o_flag_wdata (w_tx_flag_wdata),
      .o_ev_apb     (w_tx_ev_apb),
      .o_busy       (w_tx_busy_s),
      .i_clk_mclk   (i_clk_mclk),
      .i_rst_n_mclk (w_rst_n_mclk),
      .o_en_s       (w_en_s),
      .o_flush_ev   (w_flush_ev),
      .o_srst_ev    (w_srst_ev),
      .i_ev_mclk    (w_ev_mclk),
      .i_busy_mclk  (w_busy_mclk),
      .o_snap_valid (w_snap_valid),
      .i_snap_take  (w_snap_take),
      .o_mask_valid (w_mask_valid),
      .i_mask_take  (w_mask_take),
      .o_cfg_role   (w_cfg_role),
      .o_cfg_shr    (w_cfg_shr),
      .o_cfg_ondem  (w_cfg_ondem),
      .o_cfg_auto   (w_cfg_auto),
      .o_cfg_tri    (w_cfg_tri),
      .o_cfg_fmt    (w_cfg_fmt),
      .o_cfg_align  (w_cfg_align),
      .o_cfg_pack   (w_cfg_pack),
      .o_cfg_nslot  (w_cfg_nslot),
      .o_cfg_slot_w (w_cfg_slot_w),
      .o_cfg_data_w (w_cfg_data_w),
      .o_cfg_sync_w (w_cfg_sync_w),
      .o_cfg_fsp    (w_cfg_fsp),
      .o_cfg_fse    (w_cfg_fse),
      .o_cfg_bpol   (w_cfg_bpol),
      .o_cfg_div    (w_cfg_div),
      .o_cfg_tmo    (w_cfg_tmo),
      .o_cfg_mask   (w_cfg_mask),
      .o_mask_data  (w_mask_data)
    );

    // Transmit FIFO of all lines: written by the register block, read by the serializer.
    m_vlsit_i2s_txfifo #(
      .PARA_I2S_LINES      (PARA_I2S_TX_LINES),
      .PARA_I2S_FIFO_DEPTH (PARA_I2S_FIFO_DEPTH),
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH)
    ) u_txfifo (
      .i_clk_apb    (i_clk_apb),
      .i_rst_n_apb  (w_rst_n_apb),
      .i_wr_en      (w_tx_wr_en),
      .i_wr_data    (w_i2s_tx_data_data),
      .o_full       (w_tx_full),
      .o_overflow   (w_tx_ovr),
      .i_flush      (w_tx_flush_req),
      .o_flush_done (w_tx_flush_done),
      .o_level      (w_tx_level),
      .i_clk_mclk   (i_clk_mclk),
      .i_rst_n_mclk (w_rst_n_mclk),
      .i_rd_en      (w_rd_en),
      .i_pop_slot   (w_pop_slot),
      .i_words_pf   (w_words_pf),
      .o_rd_data    (w_rd_data),
      .o_rd_empty   (w_rd_empty),
      .o_rd_ready   (w_rd_ready)
    );

    // Frame engine of the transmit unit (instance u_frame_0).
    m_vlsit_i2s_frame #(
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH),
      .PARA_I2S_MASTER_EN  (PARA_I2S_MASTER_EN),
      .PARA_I2S_FMT_EXT_EN (PARA_I2S_FMT_EXT_EN),
      .PARA_I2S_PACK_EN    (PARA_I2S_PACK_EN),
      .PARA_I2S_ONDEM_EN   (PARA_I2S_ONDEM_EN),
      .PARA_I2S_HUNG_EN    (PARA_I2S_HUNG_EN),
      .PARA_I2S_MAX_SLOTS  (PARA_I2S_MAX_SLOTS)
    ) u_frame_0 (
      .i_clk_mclk      (i_clk_mclk),
      .i_rst_n_mclk    (w_rst_n_mclk),
      .i_snap_valid    (w_snap_valid),
      .o_snap_take     (w_snap_take),
      .i_mask_valid    (w_mask_valid),
      .o_mask_take     (w_mask_take),
      .i_cfg_role      (w_cfg_role),
      .i_cfg_shr       (w_cfg_shr),
      .i_cfg_ondem     (w_cfg_ondem),
      .i_cfg_auto      (w_cfg_auto),
      .i_cfg_tri       (w_cfg_tri),
      .i_cfg_fmt       (w_cfg_fmt),
      .i_cfg_align     (w_cfg_align),
      .i_cfg_pack      (w_cfg_pack),
      .i_cfg_nslot     (w_cfg_nslot),
      .i_cfg_slot_w    (w_cfg_slot_w),
      .i_cfg_data_w    (w_cfg_data_w),
      .i_cfg_sync_w    (w_cfg_sync_w),
      .i_cfg_fsp       (w_cfg_fsp),
      .i_cfg_fse       (w_cfg_fse),
      .i_cfg_bpol      (w_cfg_bpol),
      .i_cfg_div       (w_cfg_div),
      .i_cfg_tmo       (w_cfg_tmo),
      .i_cfg_mask      (w_cfg_mask),
      .i_mask_data     (w_mask_data),
      .i_en            (w_en_s),
      .i_flush_ev      (w_flush_ev),
      .i_srst_ev       (w_srst_ev),
      .i_bclk_pin      (i_bclk_tx),
      .i_ws_pin        (i_ws_tx),
      .o_bclk          (o_bclk_tx),
      .o_bclk_oe       (o_bclk_tx_oe),
      .o_ws            (o_ws_tx),
      .o_ws_oe         (o_ws_tx_oe),
      .i_oth_bclk      (w_rx_eff_bclk),
      .i_oth_ws        (w_rx_eff_ws),
      .o_eff_bclk      (w_tx_eff_bclk),
      .o_eff_ws        (w_tx_eff_ws),
      .i_fifo_ok       (w_rd_ready),
      .o_words_pf      (w_words_pf),
      .i_err           (w_und),
      .o_data_w        (w_data_w),
      .o_align         (w_align),
      .o_pack          (w_pack),
      .o_tri           (w_tri),
      .o_on            (w_on),
      .o_tick_l        (w_tick_l),
      .o_nx_active     (w_nx_active),
      .o_nx_slot_start (w_nx_slot_start),
      .o_nx_slot_en    (w_nx_slot_en),
      .o_nx_bit_vld    (w_nx_bit_vld),
      .o_nx_pack_hi    (w_nx_pack_hi),
      .o_tick_s        (),
      .o_smp_active    (),
      .o_smp_slot_en   (),
      .o_smp_bit_vld   (),
      .o_smp_last      (),
      .o_smp_pack_hi   (),
      .o_ev_sync       (w_ev_sync),
      .o_ev_hung       (w_ev_hung),
      .o_ev_frm        (w_ev_frm),
      .o_busy          (w_busy_mclk)
    );

    // Transmit serializer.
    m_vlsit_i2s_txser #(
      .PARA_I2S_LINES   (PARA_I2S_TX_LINES),
      .PARA_I2S_PACK_EN (PARA_I2S_PACK_EN),
      .PARA_I2S_TRI_EN  (PARA_I2S_TRI_EN)
    ) u_txser (
      .i_clk_mclk      (i_clk_mclk),
      .i_rst_n_mclk    (w_rst_n_mclk),
      .i_tick_l        (w_tick_l),
      .i_nx_active     (w_nx_active),
      .i_nx_slot_start (w_nx_slot_start),
      .i_nx_slot_en    (w_nx_slot_en),
      .i_nx_bit_vld    (w_nx_bit_vld),
      .i_nx_pack_hi    (w_nx_pack_hi),
      .i_on            (w_on),
      .i_data_w        (w_data_w),
      .i_align         (w_align),
      .i_pack          (w_pack),
      .i_tri           (w_tri),
      .i_rd_data       (w_rd_data),
      .i_rd_empty      (w_rd_empty),
      .o_rd_en         (w_rd_en),
      .o_pop_slot      (w_pop_slot),
      .o_sdo           (w_sdo),
      .o_sdo_oe        (o_sdo_oe),
      .o_und           (w_und),
      .o_und_q         (w_und_q)
    );

    // Data line outputs: lines above the build are tied to 0.
    for (genvar gen_idx = 0; gen_idx < LPARA_MAX_LINES; gen_idx++) begin : gen_sdo
      if (gen_idx < PARA_I2S_TX_LINES) begin : gen_line
        // A line of the build drives its pin.
        assign w_tx_sdo4[gen_idx] = w_sdo[gen_idx];
      end else begin : gen_tie
        // A line above the build is tied low.
        assign w_tx_sdo4[gen_idx] = 1'b0;
      end
    end
  end else begin : gen_no_tx
    // Tie-off of the absent transmit unit: results and pins are 0 (DEC-019).
    assign w_tx_full       = '0;
    assign w_tx_level      = '0;
    assign w_tx_flush_done = 1'b0;
    assign w_tx_ovr        = 1'b0;
    assign w_tx_ev_apb     = 4'd0;
    assign w_tx_flag_we    = 2'd0;
    assign w_tx_flag_wdata = 2'd0;
    assign w_tx_busy_s     = 1'b0;
    assign w_tx_eff_bclk   = 1'b0;
    assign w_tx_eff_ws     = 1'b0;
    assign w_tx_sdo4       = '0;
    assign o_bclk_tx       = 1'b0;
    assign o_bclk_tx_oe    = 1'b0;
    assign o_ws_tx         = 1'b0;
    assign o_ws_tx_oe      = 1'b0;
    assign o_sdo_oe        = 1'b0;
  end

  // Transmit data pins.
  assign o_sdo_0 = w_tx_sdo4[0];
  assign o_sdo_1 = w_tx_sdo4[1];
  assign o_sdo_2 = w_tx_sdo4[2];
  assign o_sdo_3 = w_tx_sdo4[3];

  // Receive unit: configuration crossing, FIFO, frame engine, deserializer and DMA handshake.
  if (PARA_I2S_RX_EN != 32'd0) begin : gen_rx
    logic w_en_s;
    logic w_flush_ev;
    logic w_srst_ev;
    logic [3:0] w_ev_mclk;
    logic w_snap_valid;
    logic w_snap_take;
    logic w_mask_valid;
    logic w_mask_take;
    logic w_cfg_role;
    logic w_cfg_shr;
    logic w_cfg_ondem;
    logic w_cfg_auto;
    logic w_cfg_tri;
    logic [2:0] w_cfg_fmt;
    logic w_cfg_align;
    logic w_cfg_pack;
    logic [5:0] w_cfg_nslot;
    logic [5:0] w_cfg_slot_w;
    logic [5:0] w_cfg_data_w;
    logic [5:0] w_cfg_sync_w;
    logic w_cfg_fsp;
    logic w_cfg_fse;
    logic w_cfg_bpol;
    logic [15:0] w_cfg_div;
    logic [15:0] w_cfg_tmo;
    logic [31:0] w_cfg_mask;
    logic [31:0] w_mask_data;
    logic w_busy_mclk;
    logic [5:0] w_words_pf;
    logic w_wr_room;
    logic [PARA_I2S_RX_LINES*LPARA_WORD_W-1:0] w_wr_data;
    logic [PARA_I2S_RX_LINES-1:0] w_wr_full;
    logic [PARA_I2S_RX_LINES-1:0] w_wr_en;
    logic w_ovr;
    logic w_ovr_q;
    logic [5:0] w_data_w;
    logic w_align;
    logic w_pack;
    logic w_on;
    logic w_tick_s;
    logic w_smp_active;
    logic w_smp_slot_en;
    logic w_smp_bit_vld;
    logic w_smp_last;
    logic w_smp_pack_hi;
    logic w_ev_sync;
    logic w_ev_hung;
    logic w_ev_frm;

    // Event vector to the APB domain: overrun, sync error, hung clock, frame done.
    assign w_ev_mclk = {w_ev_frm, w_ev_hung, w_ev_sync, w_ovr_q};

    // Configuration crossing of the receive unit; no other unit can block its shared clock.
    m_vlsit_i2s_cfgsync #(
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH)
    ) u_cfgsync_rx (
      .i_clk_apb    (i_clk_apb),
      .i_rst_n_apb  (w_rst_n_apb),
      .i_en         (w_i2s_rx_ctrl_en),
      .i_role       (w_i2s_rx_ctrl_role),
      .i_shr        (w_i2s_rx_ctrl_shr),
      .i_shr_block  (1'b0),
      .i_ondem      (w_i2s_rx_ctrl_ondem),
      .i_auto       (w_i2s_rx_ctrl_auto),
      .i_tri        (w_i2s_rx_ctrl_tri),
      .i_fmt        (w_i2s_rx_frame_fmt),
      .i_align      (w_i2s_rx_frame_align),
      .i_pack       (w_i2s_rx_frame_pack),
      .i_nslot      (w_i2s_rx_frame_nslot),
      .i_slot_w     (w_i2s_rx_frame_slot_w),
      .i_data_w     (w_i2s_rx_frame_data_w),
      .i_sync_w     (w_i2s_rx_sync_sync_w),
      .i_fsp        (w_i2s_rx_sync_fsp),
      .i_fse        (w_i2s_rx_sync_fse),
      .i_bpol       (w_i2s_rx_sync_bpol),
      .i_div        (w_i2s_rx_clk_div),
      .i_tmo        (w_i2s_rx_tmo_tmo),
      .i_mask       (w_i2s_rx_mask_mask),
      .i_flush_req  (w_rx_flush_req),
      .i_srst_req   (w_rx_srst_req),
      .i_flag_clr   (w_rx_flag_clr),
      .o_flag_we    (w_rx_flag_we),
      .o_flag_wdata (w_rx_flag_wdata),
      .o_ev_apb     (w_rx_ev_apb),
      .o_busy       (w_rx_busy_s),
      .i_clk_mclk   (i_clk_mclk),
      .i_rst_n_mclk (w_rst_n_mclk),
      .o_en_s       (w_en_s),
      .o_flush_ev   (w_flush_ev),
      .o_srst_ev    (w_srst_ev),
      .i_ev_mclk    (w_ev_mclk),
      .i_busy_mclk  (w_busy_mclk),
      .o_snap_valid (w_snap_valid),
      .i_snap_take  (w_snap_take),
      .o_mask_valid (w_mask_valid),
      .i_mask_take  (w_mask_take),
      .o_cfg_role   (w_cfg_role),
      .o_cfg_shr    (w_cfg_shr),
      .o_cfg_ondem  (w_cfg_ondem),
      .o_cfg_auto   (w_cfg_auto),
      .o_cfg_tri    (w_cfg_tri),
      .o_cfg_fmt    (w_cfg_fmt),
      .o_cfg_align  (w_cfg_align),
      .o_cfg_pack   (w_cfg_pack),
      .o_cfg_nslot  (w_cfg_nslot),
      .o_cfg_slot_w (w_cfg_slot_w),
      .o_cfg_data_w (w_cfg_data_w),
      .o_cfg_sync_w (w_cfg_sync_w),
      .o_cfg_fsp    (w_cfg_fsp),
      .o_cfg_fse    (w_cfg_fse),
      .o_cfg_bpol   (w_cfg_bpol),
      .o_cfg_div    (w_cfg_div),
      .o_cfg_tmo    (w_cfg_tmo),
      .o_cfg_mask   (w_cfg_mask),
      .o_mask_data  (w_mask_data)
    );

    // Receive FIFO of all lines: written by the deserializer, read by the register block.
    m_vlsit_i2s_rxfifo #(
      .PARA_I2S_LINES      (PARA_I2S_RX_LINES),
      .PARA_I2S_FIFO_DEPTH (PARA_I2S_FIFO_DEPTH),
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH)
    ) u_rxfifo (
      .i_clk_mclk   (i_clk_mclk),
      .i_rst_n_mclk (w_rst_n_mclk),
      .i_wr_en      (w_wr_en),
      .i_wr_data    (w_wr_data),
      .i_flush      (w_flush_ev),
      .i_words_pf   (w_words_pf),
      .o_wr_full    (w_wr_full),
      .o_wr_room    (w_wr_room),
      .i_clk_apb    (i_clk_apb),
      .i_rst_n_apb  (w_rst_n_apb),
      .i_rd_en      (w_rx_rd_en),
      .o_rd_data    (w_rx_rdata),
      .o_rd_empty   (w_rx_empty),
      .o_flush_done (w_rx_flush_done),
      .o_level      (w_rx_level)
    );

    // Frame engine of the receive unit (instance u_frame_1).
    m_vlsit_i2s_frame #(
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH),
      .PARA_I2S_MASTER_EN  (PARA_I2S_MASTER_EN),
      .PARA_I2S_FMT_EXT_EN (PARA_I2S_FMT_EXT_EN),
      .PARA_I2S_PACK_EN    (PARA_I2S_PACK_EN),
      .PARA_I2S_ONDEM_EN   (PARA_I2S_ONDEM_EN),
      .PARA_I2S_HUNG_EN    (PARA_I2S_HUNG_EN),
      .PARA_I2S_MAX_SLOTS  (PARA_I2S_MAX_SLOTS)
    ) u_frame_1 (
      .i_clk_mclk      (i_clk_mclk),
      .i_rst_n_mclk    (w_rst_n_mclk),
      .i_snap_valid    (w_snap_valid),
      .o_snap_take     (w_snap_take),
      .i_mask_valid    (w_mask_valid),
      .o_mask_take     (w_mask_take),
      .i_cfg_role      (w_cfg_role),
      .i_cfg_shr       (w_cfg_shr),
      .i_cfg_ondem     (w_cfg_ondem),
      .i_cfg_auto      (w_cfg_auto),
      .i_cfg_tri       (w_cfg_tri),
      .i_cfg_fmt       (w_cfg_fmt),
      .i_cfg_align     (w_cfg_align),
      .i_cfg_pack      (w_cfg_pack),
      .i_cfg_nslot     (w_cfg_nslot),
      .i_cfg_slot_w    (w_cfg_slot_w),
      .i_cfg_data_w    (w_cfg_data_w),
      .i_cfg_sync_w    (w_cfg_sync_w),
      .i_cfg_fsp       (w_cfg_fsp),
      .i_cfg_fse       (w_cfg_fse),
      .i_cfg_bpol      (w_cfg_bpol),
      .i_cfg_div       (w_cfg_div),
      .i_cfg_tmo       (w_cfg_tmo),
      .i_cfg_mask      (w_cfg_mask),
      .i_mask_data     (w_mask_data),
      .i_en            (w_en_s),
      .i_flush_ev      (w_flush_ev),
      .i_srst_ev       (w_srst_ev),
      .i_bclk_pin      (i_bclk_rx),
      .i_ws_pin        (i_ws_rx),
      .o_bclk          (o_bclk_rx),
      .o_bclk_oe       (o_bclk_rx_oe),
      .o_ws            (o_ws_rx),
      .o_ws_oe         (o_ws_rx_oe),
      .i_oth_bclk      (w_tx_eff_bclk),
      .i_oth_ws        (w_tx_eff_ws),
      .o_eff_bclk      (w_rx_eff_bclk),
      .o_eff_ws        (w_rx_eff_ws),
      .i_fifo_ok       (w_wr_room),
      .o_words_pf      (w_words_pf),
      .i_err           (w_ovr),
      .o_data_w        (w_data_w),
      .o_align         (w_align),
      .o_pack          (w_pack),
      .o_tri           (),
      .o_on            (w_on),
      .o_tick_l        (),
      .o_nx_active     (),
      .o_nx_slot_start (),
      .o_nx_slot_en    (),
      .o_nx_bit_vld    (),
      .o_nx_pack_hi    (),
      .o_tick_s        (w_tick_s),
      .o_smp_active    (w_smp_active),
      .o_smp_slot_en   (w_smp_slot_en),
      .o_smp_bit_vld   (w_smp_bit_vld),
      .o_smp_last      (w_smp_last),
      .o_smp_pack_hi   (w_smp_pack_hi),
      .o_ev_sync       (w_ev_sync),
      .o_ev_hung       (w_ev_hung),
      .o_ev_frm        (w_ev_frm),
      .o_busy          (w_busy_mclk)
    );

    // Receive deserializer.
    m_vlsit_i2s_rxdes #(
      .PARA_I2S_LINES      (PARA_I2S_RX_LINES),
      .PARA_I2S_PACK_EN    (PARA_I2S_PACK_EN),
      .PARA_I2S_SYNC_DEPTH (PARA_I2S_SYNC_DEPTH)
    ) u_rxdes (
      .i_clk_mclk    (i_clk_mclk),
      .i_rst_n_mclk  (w_rst_n_mclk),
      .i_sdi         (w_sdi4[PARA_I2S_RX_LINES-1:0]),
      .i_tick_s      (w_tick_s),
      .i_smp_active  (w_smp_active),
      .i_smp_slot_en (w_smp_slot_en),
      .i_smp_bit_vld (w_smp_bit_vld),
      .i_smp_last    (w_smp_last),
      .i_smp_pack_hi (w_smp_pack_hi),
      .i_data_w      (w_data_w),
      .i_align       (w_align),
      .i_pack        (w_pack),
      .i_wr_full     (w_wr_full),
      .o_wr_en       (w_wr_en),
      .o_wr_data     (w_wr_data),
      .o_ovr         (w_ovr),
      .o_ovr_q       (w_ovr_q)
    );
  end else begin : gen_no_rx
    // Tie-off of the absent receive unit: results and pins are 0 (DEC-019).
    assign w_rx_rdata      = '0;
    assign w_rx_empty      = '1;
    assign w_rx_level      = '0;
    assign w_rx_flush_done = 1'b0;
    assign w_rx_ev_apb     = 4'd0;
    assign w_rx_flag_we    = 2'd0;
    assign w_rx_flag_wdata = 2'd0;
    assign w_rx_busy_s     = 1'b0;
    assign w_rx_eff_bclk   = 1'b0;
    assign w_rx_eff_ws     = 1'b0;
    assign o_bclk_rx       = 1'b0;
    assign o_bclk_rx_oe    = 1'b0;
    assign o_ws_rx         = 1'b0;
    assign o_ws_rx_oe      = 1'b0;
  end

  // Receive data pins.
  assign w_sdi4 = {i_sdi_3, i_sdi_2, i_sdi_1, i_sdi_0};

  // DMA handshake of the transmit direction: request while the level is at or below the watermark.
  if ((PARA_I2S_DMA_EN != 32'd0) && (PARA_I2S_TX_EN != 32'd0)) begin : gen_dma_tx
    m_vlsit_i2s_dmahs u_dmahs_tx (
      .i_clk_apb    (i_clk_apb),
      .i_rst_n_apb  (w_rst_n_apb),
      .i_dma_en     (w_i2s_tx_ctrl_dma),
      .i_wm_cond    (w_tx_wm_cond),
      .i_one_cond   (~w_tx_full_r),
      .i_dma_ack    (i_dma_tx_ack),
      .o_dma_req    (o_dma_tx_req),
      .o_dma_single (o_dma_tx_single)
    );
  end else begin : gen_no_dma_tx
    // No transmit DMA handshake: outputs are low.
    assign o_dma_tx_req    = 1'b0;
    assign o_dma_tx_single = 1'b0;
  end

  // DMA handshake of the receive direction: request while the level is at or above the watermark.
  if ((PARA_I2S_DMA_EN != 32'd0) && (PARA_I2S_RX_EN != 32'd0)) begin : gen_dma_rx
    m_vlsit_i2s_dmahs u_dmahs_rx (
      .i_clk_apb    (i_clk_apb),
      .i_rst_n_apb  (w_rst_n_apb),
      .i_dma_en     (w_i2s_rx_ctrl_dma),
      .i_wm_cond    (w_rx_wm_cond),
      .i_one_cond   (~w_rx_empty_r),
      .i_dma_ack    (i_dma_rx_ack),
      .o_dma_req    (o_dma_rx_req),
      .o_dma_single (o_dma_rx_single)
    );
  end else begin : gen_no_dma_rx
    // No receive DMA handshake: outputs are low.
    assign o_dma_rx_req    = 1'b0;
    assign o_dma_rx_single = 1'b0;
  end

endmodule
