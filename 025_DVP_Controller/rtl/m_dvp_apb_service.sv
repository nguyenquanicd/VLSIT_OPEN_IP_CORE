/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Integrates APB decode, generated CSR, FIFO_DATA timeout, both FIFO paths and DMA
 *                request logic. Implements REQ-IF-001..010 and DEC-028, DEC-031..032.
 */
`timescale 1ns/1ps

module m_dvp_apb_service #(
  // Parameter Description: number of entries in both sample FIFOs.
  // Parameter values: power of 2, minimum 2; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_DEPTH = 32'd8,
  // Parameter Description: sample width used by the capture and FIFO paths.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32'd8,
  // Parameter Description: active logic level of the sensor VSYNC pulse.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_VSYNC_ACTIVE = 32'd1,
  // Parameter Description: AFIFO synchronizer cell selection.
  // Parameter values: 0 to 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AFIFO_CELL_TYPE = 32'd2,
  // Parameter Description: AFIFO memory implementation selection.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AFIFO_MEM_USE_MACRO = 32'd0,
  // Parameter Description: byte address of the read-only FIFO_DATA endpoint.
  // Parameter values: aligned 16-bit address outside CSR space; default is 16'h0100.
  // Parameter unit: byte
  parameter logic [31:0] PARA_FIFO_DATA_ADDR = 32'h0000_0100,
  localparam logic [31:0] LPARA_VERSION_MAJOR = 32'd1,
  localparam logic [31:0] LPARA_VERSION_MINOR = 32'd1,
  localparam logic [31:0] LPARA_CSR_CTRL_ADDR = 32'h0000_0004
) (
  // APB clock and local reset
  input  wire                    i_clk_apb,
  input  wire                    i_rst_n_apb,

  // Sensor clock and local reset
  input  wire                    i_clk_dvp,
  input  wire                    i_rst_n_dvp,

  // Sensor and capture-path status/data
  input  wire                    i_dvp_vsync,
  input  wire                    i_afifo_wr_en,
  input  wire  [PARA_DATA_W-1:0] i_afifo_wr_data,
  input  wire                    i_pixel_toggle,
  input  wire  [PARA_DATA_W-1:0] i_gated_data,
  input  wire                    i_cont_frame_active,
  input  wire                    i_cont_frame_start,
  input  wire                    i_capture_quiescent,

  // APB4 and DMA handshake
  input  wire  [15:0]            i_paddr,
  input  wire                    i_psel,
  input  wire                    i_penable,
  input  wire                    i_pwrite,
  input  wire  [31:0]            i_pwdata,
  input  wire  [3:0]             i_pstrb,
  input  wire  [2:0]             i_pprot,
  input  wire                    i_dma_ack,
  output logic                   o_pready,
  output logic [31:0]            o_prdata,
  output logic                   o_pslverr,

  // Capture controls and DMA request
  output logic                   o_capture_en,
  output logic                   o_pclk_mode,
  output logic                   o_dma_req
);

  // APB routing, CSR, FIFO endpoint and selected-buffer interconnects.
  logic w_csr_sel;
  logic w_fifo_sel;
  logic w_fifo_aligned;
  logic w_csr_pready;
  logic w_csr_pslverr;
  logic [31:0] w_csr_prdata;
  logic w_fifo_pready;
  logic w_fifo_pslverr;
  logic [31:0] w_fifo_prdata;
  logic w_fifo_rd_en;
  logic w_fifo_flush_req;
  logic w_fifo_flush_busy;
  logic w_fifo_flush_done;
  logic w_frame_start;
  logic [31:0] reg_frame_count;
  logic [PARA_DATA_W-1:0] w_fifo_data;
  logic w_fifo_empty;
  logic w_fifo_full;
  logic [31:0] w_fifo_occupancy;
  logic w_capture_active;
  logic w_overflow_event;
  logic w_mode_change_safe;
  logic [31:0] w_wmark_level;
  logic [31:0] w_timeout_cycles;
  logic w_mask_mode_wr;
  logic w_mask_capture_wr;
  logic w_mask_flush_wr;
  logic w_csr_mode_wr;
  logic w_csr_pwdata_mode;
  logic w_csr_pwdata_capture;
  logic w_csr_pwdata_flush;
  logic [31:0] w_csr_pwdata;
  logic w_protect_en;
  logic w_slverr_en;

  // Decode every non-FIFO address to CSR; reserve the FIFO_DATA word for the custom endpoint.
  m_dvp_apb_decode #(
    .PARA_FIFO_DATA_ADDR (PARA_FIFO_DATA_ADDR)
  ) u_apb_decode (
    .i_psel         (i_psel),
    .i_paddr        (i_paddr),
    .o_csr_sel      (w_csr_sel),
    .o_fifo_sel     (w_fifo_sel),
    .o_fifo_aligned (w_fifo_aligned)
  );

  // Identify a PCLK_MODE write in the APB setup phase.
  assign w_csr_mode_wr = w_csr_sel & ~i_penable & i_pwrite &
                            (i_paddr == LPARA_CSR_CTRL_ADDR[15:0]) & i_pstrb[0];
  // Prevent capture from starting in the same write that requests a flush.
  assign w_mask_capture_wr = w_csr_mode_wr &
                             (w_fifo_flush_req | w_fifo_flush_busy | i_pwdata[2]);
  // Ignore flush requests while capture is active or another flush is pending.
  assign w_mask_flush_wr = w_csr_mode_wr &
                           (o_capture_en | i_pwdata[0] | w_fifo_flush_req | w_fifo_flush_busy);
  // Preserve the mode value while capture, flush, FIFO or source safety blocks the update.
  assign w_mask_mode_wr = w_csr_mode_wr &
                             (o_capture_en | i_pwdata[0] | ~w_mode_change_safe |
                              w_fifo_flush_req | w_fifo_flush_busy | i_pwdata[2]);
  // Select the accepted mode bit while leaving all other CSR write data unchanged.
  assign w_csr_pwdata_mode = w_mask_mode_wr ? o_pclk_mode : i_pwdata[1];
  assign w_csr_pwdata_capture = w_mask_capture_wr ? o_capture_en : i_pwdata[0];
  assign w_csr_pwdata_flush = w_mask_flush_wr ? w_fifo_flush_req : i_pwdata[2];
  // Build the write payload presented to the generated CSR block.
  always_comb begin : p_com_csr_wdata
    w_csr_pwdata = i_pwdata;
    w_csr_pwdata[0] = w_csr_pwdata_capture;
    w_csr_pwdata[1] = w_csr_pwdata_mode;
    w_csr_pwdata[2] = w_csr_pwdata_flush;
  end

  // Count accepted frame-start events in the APB domain; natural overflow is modulo 2^32.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_frame_count
    if (!i_rst_n_apb)
      reg_frame_count <= '0;
    else if (w_frame_start)
      reg_frame_count <= reg_frame_count + 32'd1;
  end

  // Tie CSR access protection off and enable the generated alignment/strobe error behavior.
  m_vlsit_tie #(
    .PARA_TIE_WIDTH (32'd1),
    .PARA_TIE_VALUE (32'd0)
  ) u_tie_protect (
    .o_tie (w_protect_en)
  );

  m_vlsit_tie #(
    .PARA_TIE_WIDTH (32'd1),
    .PARA_TIE_VALUE (32'd1)
  ) u_tie_slverr (
    .o_tie (w_slverr_en)
  );

  // Generated CSR block from the approved workbook; its RTL remains untouched.
  m_vlsit_csr_dvp #(
    .PARA_ASYNCHRONOUS (32'd0)
  ) u_csr (
    .i_clk_apb                     (i_clk_apb),
    .i_rst_n_apb                   (i_rst_n_apb),
    .i_clk_reg                     (i_clk_apb),
    .i_rst_n_reg                   (i_rst_n_apb),
    .i_apb_psel                    (w_csr_sel),
    .i_apb_penable                 (i_penable),
    .i_apb_pwrite                  (i_pwrite),
    .i_apb_paddr                   (i_paddr),
    .i_apb_pwdata                  (w_csr_pwdata),
    .i_apb_pstrb                   (i_pstrb),
    .i_apb_pprot                   (i_pprot),
    .o_apb_pready                  (w_csr_pready),
    .o_apb_pslverr                 (w_csr_pslverr),
    .o_apb_prdata                  (w_csr_prdata),
    .i_protect_en                  (w_protect_en),
    .i_slverr_en                   (w_slverr_en),
    .i_dvp_version_major           (LPARA_VERSION_MAJOR[15:0]),
    .i_dvp_version_minor           (LPARA_VERSION_MINOR[15:0]),
    .o_dvp_ctrl_pclk_mode          (o_pclk_mode),
    .o_dvp_ctrl_capture_en         (o_capture_en),
    .o_dvp_ctrl_fifo_flush         (w_fifo_flush_req),
    .i_hw_wdata_dvp_ctrl_fifo_flush(1'b0),
    .i_hw_we_dvp_ctrl_fifo_flush   (w_fifo_flush_done),
    .o_dvp_wmark_level             (w_wmark_level),
    .o_dvp_timeout_cycles          (w_timeout_cycles),
    .o_dvp_fifo_sts_ovf            (),
    .i_hw_wdata_dvp_fifo_sts_ovf   (w_overflow_event),
    .i_hw_we_dvp_fifo_sts_ovf     (w_overflow_event),
    .i_dvp_fifo_sts_full           (w_fifo_full),
    .i_dvp_fifo_sts_empty          (w_fifo_empty),
    .i_dvp_fifo_sts_active         (w_capture_active),
    .i_dvp_fifo_level_count        (w_fifo_occupancy),
    .i_dvp_frame_count_count       (reg_frame_count)
  );

  // FIFO_DATA waits when empty, times out and pops only on success.
  m_dvp_apb_data #(
    .PARA_DATA_W (PARA_DATA_W)
  ) u_apb_data (
    .i_clk_apb        (i_clk_apb),
    .i_rst_n_apb      (i_rst_n_apb),
    .i_psel           (w_fifo_sel),
    .i_penable        (i_penable),
    .i_pwrite         (i_pwrite),
    .i_fifo_aligned   (w_fifo_aligned),
    .i_timeout_cycles(w_timeout_cycles),
    .i_fifo_data      (w_fifo_data),
    .i_fifo_empty     (w_fifo_empty),
    .o_fifo_rd_en     (w_fifo_rd_en),
    .o_pready         (w_fifo_pready),
    .o_prdata         (w_fifo_prdata),
    .o_pslverr        (w_fifo_pslverr)
  );

  // The mode-selected buffer joins both capture paths and reports APB-visible occupancy/status.
  m_dvp_buffer #(
    .PARA_FIFO_DEPTH         (PARA_FIFO_DEPTH),
    .PARA_DATA_W             (PARA_DATA_W),
    .PARA_AFIFO_CELL_TYPE    (PARA_AFIFO_CELL_TYPE),
    .PARA_AFIFO_MEM_USE_MACRO(PARA_AFIFO_MEM_USE_MACRO),
    .PARA_VSYNC_ACTIVE       (PARA_VSYNC_ACTIVE)
  ) u_dvp_buf (
    .i_clk_apb           (i_clk_apb),
    .i_rst_n_apb         (i_rst_n_apb),
    .i_clk_dvp           (i_clk_dvp),
    .i_rst_n_dvp         (i_rst_n_dvp),
    .i_capture_en        (o_capture_en),
    .i_pclk_mode         (o_pclk_mode),
    .i_dvp_vsync         (i_dvp_vsync),
    .i_cont_frame_active(i_cont_frame_active),
    .i_cont_frame_start(i_cont_frame_start),
    .i_afifo_wr_en       (i_afifo_wr_en),
    .i_afifo_wr_data     (i_afifo_wr_data),
    .i_pixel_toggle      (i_pixel_toggle),
    .i_gated_data        (i_gated_data),
    .i_capture_quiescent(i_capture_quiescent),
    .i_flush_req        (w_fifo_flush_req),
    .i_rd_en             (w_fifo_rd_en),
    .o_rd_data           (w_fifo_data),
    .o_empty             (w_fifo_empty),
    .o_full              (w_fifo_full),
    .o_occupancy         (w_fifo_occupancy),
    .o_active            (w_capture_active),
    .o_overflow_event    (w_overflow_event),
    .o_mode_change_safe  (w_mode_change_safe),
    .o_frame_start       (w_frame_start),
    .o_flush_busy        (w_fifo_flush_busy),
    .o_flush_done        (w_fifo_flush_done)
  );

  // Request one DMA service batch at the configured selected-FIFO occupancy watermark.
  m_dvp_dma_req #(
    .PARA_FIFO_DEPTH (PARA_FIFO_DEPTH)
  ) u_dma_req (
    .i_clk_apb   (i_clk_apb),
    .i_rst_n_apb (i_rst_n_apb),
    .i_occupancy (w_fifo_occupancy),
    .i_watermark (w_wmark_level),
    .i_dma_ack   (i_dma_ack),
    .o_dma_req   (o_dma_req)
  );

  // Select the response from the APB endpoint addressed by the decoder.
  always_comb begin : p_com_apb_resp
    o_pready = 1'b0;
    o_prdata = '0;
    o_pslverr = 1'b0;
    case ({w_csr_sel, w_fifo_sel})
      2'b10: begin
        o_pready = w_csr_pready;
        o_prdata = w_csr_prdata;
        o_pslverr = w_csr_pslverr;
      end
      2'b01: begin
        o_pready = w_fifo_pready;
        o_prdata = w_fifo_prdata;
        o_pslverr = w_fifo_pslverr;
      end
      default: begin
        o_pready = 1'b0;
        o_prdata = '0;
        o_pslverr = 1'b0;
      end
    endcase
  end

endmodule
