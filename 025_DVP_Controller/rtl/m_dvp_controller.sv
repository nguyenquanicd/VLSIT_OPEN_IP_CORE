/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-22
 * Description  : Structural DVP controller top for continuous-PCLK AFIFO and gated-valid-pixel
 *                SFIFO modes. Implements REQ-IF-001..009 and DEC-012, DEC-018, DEC-027..032.
 */
`timescale 1ns/1ps

module m_dvp_controller #(
  // Parameter Description: width of the unsigned sensor pixel sample.
  // Parameter values: 8, 10, or 12; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DVP_DATA_W = 32'd8,
  // Parameter Description: selected PCLK sample edge; 0 is rising and 1 is falling.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_DVP_SAMPLE_EDGE = 32'd0,
  // Parameter Description: active logic level of the sensor VSYNC pulse.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_DVP_VSYNC_ACTIVE = 32'd1,
  // Parameter Description: active logic level of the sensor HREF qualifier.
  // Parameter values: 0 (active-low) or 1 (active-high); default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_DVP_HREF_ACTIVE = 32'd1,
  // Parameter Description: number of entries in each mode-specific pixel FIFO.
  // Parameter values: power of 2, minimum 2; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_FIFO_DEPTH = 32'd8,
  // Parameter Description: AFIFO Gray-pointer synchronizer cell selection.
  // Parameter values: 0 to 4; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_AFIFO_CELL_TYPE = 32'd2,
  // Parameter Description: AFIFO memory implementation selection.
  // Parameter values: 0 (RTL array) or 1 (SRAM wrapper); default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_AFIFO_MEM_USE_MACRO = 32'd0,
  // Parameter Description: byte address of the custom FIFO_DATA APB endpoint.
  // Parameter values: aligned 16-bit address outside CSR space; default is 16'h0100.
  // Parameter unit: byte
  parameter logic [31:0] PARA_FIFO_DATA_ADDR = 32'h0000_0100
) (
  // Clock and common active-low reset
  input  wire                        i_clk_apb,
  input  wire                        i_rst_n_sys,
  input  wire                        i_clk_dvp,

  // Sensor DVP interface
  input  wire  [PARA_DVP_DATA_W-1:0] i_dvp_data,
  input  wire                        i_dvp_vsync,
  input  wire                        i_dvp_href,

  // APB4 requester interface
  input  wire  [15:0]                i_paddr,
  input  wire                        i_psel,
  input  wire                        i_penable,
  input  wire                        i_pwrite,
  input  wire  [31:0]                i_pwdata,
  input  wire  [3:0]                 i_pstrb,
  input  wire  [2:0]                 i_pprot,
  output logic                       o_pready,
  output logic [31:0]                o_prdata,
  output logic                       o_pslverr,

  // DMA batch handshake in CLK-APB
  input  wire                        i_dma_ack,
  output logic                       o_dma_req
);

  // Elaboration-time parameter legality (REQ-PARAM-001, ERR-006): an unsupported value is reported
  // as an elaboration error with a message.
  // Each branch is generated only for an illegal override; legal values omit it.
  // 32'h0000_0018 is the last implemented CSR byte address (dvp_frame_count, REQ-IF-006).
  // Simulation-only check; VLSIT_SYNTHESIS excludes it from synthesis and lint (SCP-03).
`ifndef VLSIT_SYNTHESIS
  generate
    if ((PARA_DVP_DATA_W != 32'd8) && (PARA_DVP_DATA_W != 32'd10) && (PARA_DVP_DATA_W != 32'd12)) begin : gen_invalid_dvp_data_w
      $error("PARA_DVP_DATA_W must be 8, 10 or 12");
    end
    if (PARA_DVP_SAMPLE_EDGE > 32'd1) begin : gen_invalid_dvp_sample_edge
      $error("PARA_DVP_SAMPLE_EDGE must be 0 or 1");
    end
    if (PARA_DVP_VSYNC_ACTIVE > 32'd1) begin : gen_invalid_dvp_vsync_active
      $error("PARA_DVP_VSYNC_ACTIVE must be 0 or 1");
    end
    if (PARA_DVP_HREF_ACTIVE > 32'd1) begin : gen_invalid_dvp_href_active
      $error("PARA_DVP_HREF_ACTIVE must be 0 or 1");
    end
    if ((PARA_FIFO_DEPTH < 32'd2) || ((PARA_FIFO_DEPTH & (PARA_FIFO_DEPTH - 32'd1)) != 32'd0)) begin : gen_invalid_fifo_depth
      $error("PARA_FIFO_DEPTH must be a power of two and at least 2");
    end
    if (PARA_AFIFO_CELL_TYPE > 32'd4) begin : gen_invalid_afifo_cell_type
      $error("PARA_AFIFO_CELL_TYPE must be between 0 and 4");
    end
    if (PARA_AFIFO_MEM_USE_MACRO > 32'd1) begin : gen_invalid_afifo_mem_use_macro
      $error("PARA_AFIFO_MEM_USE_MACRO must be 0 or 1");
    end
    if ((PARA_FIFO_DATA_ADDR[31:16] != 16'd0) || (PARA_FIFO_DATA_ADDR[1:0] != 2'd0) ||
        (PARA_FIFO_DATA_ADDR <= 32'h0000_0018)) begin : gen_invalid_fifo_data_addr
      $error("PARA_FIFO_DATA_ADDR must be a 16-bit word-aligned address above the CSR map (0x18)");
    end
  endgenerate
`endif

  // Local reset releases and interconnects between the capture and APB subsystems.
  logic w_rst_n_apb;
  logic w_rst_n_dvp;
  logic w_capture_en;
  logic w_pclk_mode;
  logic w_afifo_wr_en;
  logic [PARA_DVP_DATA_W-1:0] w_afifo_wr_data;
  logic [PARA_DVP_DATA_W-1:0] w_gated_data;
  logic w_valid_toggle;
  logic w_cont_frame_active;
  logic w_cont_frame_start;
  logic w_capture_quiescent;

  // APB-local reset release for the generated CSR, APB endpoint and gated-mode launch reset.
  m_vlsit_rst_sync u_rst_sync_apb (
    .i_clk_dst   (i_clk_apb),
    .i_rst_n_src (i_rst_n_sys),
    .o_rst_n_dst (w_rst_n_apb)
  );

  // PCLK-local reset release for continuous capture and the asynchronous FIFO write side.
  m_vlsit_rst_sync u_rst_sync_dvp (
    .i_clk_dst   (i_clk_dvp),
    .i_rst_n_src (i_rst_n_sys),
    .o_rst_n_dst (w_rst_n_dvp)
  );

  // Sensor sampling and both mode-specific source paths.
  m_dvp_capture #(
    .PARA_DATA_W       (PARA_DVP_DATA_W),
    .PARA_SAMPLE_EDGE  (PARA_DVP_SAMPLE_EDGE),
    .PARA_VSYNC_ACTIVE (PARA_DVP_VSYNC_ACTIVE),
    .PARA_HREF_ACTIVE  (PARA_DVP_HREF_ACTIVE)
  ) u_dvp_capture (
    .i_clk_dvp             (i_clk_dvp),
    .i_rst_n_dvp           (w_rst_n_dvp),
    .i_rst_n_gated         (w_rst_n_apb),
    .i_dvp_data            (i_dvp_data),
    .i_dvp_vsync           (i_dvp_vsync),
    .i_dvp_href            (i_dvp_href),
    .i_capture_en          (w_capture_en),
    .i_pclk_mode           (w_pclk_mode),
    .o_afifo_wr_en         (w_afifo_wr_en),
    .o_afifo_wr_data       (w_afifo_wr_data),
    .o_gated_data          (w_gated_data),
    .o_valid_toggle        (w_valid_toggle),
    .o_cont_frame_active   (w_cont_frame_active),
    .o_cont_frame_start    (w_cont_frame_start),
    .o_capture_quiescent   (w_capture_quiescent)
  );

  // APB/CSR service and selected FIFO subsystem.
  m_dvp_apb_service #(
    .PARA_FIFO_DEPTH          (PARA_FIFO_DEPTH),
    .PARA_DATA_W              (PARA_DVP_DATA_W),
    .PARA_VSYNC_ACTIVE        (PARA_DVP_VSYNC_ACTIVE),
    .PARA_AFIFO_CELL_TYPE     (PARA_AFIFO_CELL_TYPE),
    .PARA_AFIFO_MEM_USE_MACRO (PARA_AFIFO_MEM_USE_MACRO),
    .PARA_FIFO_DATA_ADDR      (PARA_FIFO_DATA_ADDR)
  ) u_dvp_apb_service (
    .i_clk_apb            (i_clk_apb),
    .i_rst_n_apb          (w_rst_n_apb),
    .i_clk_dvp            (i_clk_dvp),
    .i_rst_n_dvp          (w_rst_n_dvp),
    .i_dvp_vsync           (i_dvp_vsync),
    .i_afifo_wr_en         (w_afifo_wr_en),
    .i_afifo_wr_data       (w_afifo_wr_data),
    .i_pixel_toggle        (w_valid_toggle),
    .i_gated_data          (w_gated_data),
    .i_cont_frame_active   (w_cont_frame_active),
    .i_cont_frame_start    (w_cont_frame_start),
    .i_capture_quiescent   (w_capture_quiescent),
    .i_paddr               (i_paddr),
    .i_psel                (i_psel),
    .i_penable             (i_penable),
    .i_pwrite              (i_pwrite),
    .i_pwdata              (i_pwdata),
    .i_pstrb               (i_pstrb),
    .i_pprot               (i_pprot),
    .i_dma_ack             (i_dma_ack),
    .o_pready              (o_pready),
    .o_prdata              (o_prdata),
    .o_pslverr             (o_pslverr),
    .o_capture_en           (w_capture_en),
    .o_pclk_mode            (w_pclk_mode),
    .o_dma_req              (o_dma_req)
  );

endmodule
