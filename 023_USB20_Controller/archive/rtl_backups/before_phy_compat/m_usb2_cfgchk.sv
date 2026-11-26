/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Elaboration check of the parameters (REQ-PARAM-001, REQ-PARAM-003, REQ-
 *                PARAM-004, section 4 illegal combinations). o_cfg_err is a constant: 1 if a
 *                combination is illegal; it is read by the configuration testbench tb_cfgchk.
 *                Outside the synthesis branch an illegal combination also stops elaboration with
 *                $error (2026-11-24); the behavior for an illegal combination is not defined
 *                (ASM-011).
 */
`timescale 1ns/1ps

module m_usb2_cfgchk #(
  // Parameter Description: role, 0 device, 1 host, 2 dual-role by ID.
  // Parameter values: 0, 1 or 2; default is 2.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_ROLE = 2,
  // Parameter Description: PHY interface, 0 UTMI+, 1 ULPI.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PHY_IF = 0,
  // Parameter Description: UTMI+ data width; 8 is required with ULPI.
  // Parameter values: 8 or 16; default is 8.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_UTMI_W = 8,
  // Parameter Description: data interface, 0 AXI4 master DMA, 1 AXI4 slave with DMA handshake.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_DATA_IF = 0,
  // Parameter Description: host split transactions; needs a host role.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_SPLIT_EN = 0,
  // Parameter Description: scatter-gather DMA; needs the AXI master data interface.
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_SG_EN = 0,
  // Parameter Description: number of external DMA handshake channels.
  // Parameter values: 1 to 16; default is 4.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_NUM_DMA_CH = 4,
  // Parameter Description: FIFO RAM depth in words.
  // Parameter values: power of two from 256 to 32768; default is 1024.
  // Parameter unit: word
  parameter logic [31:0] PARA_USB2_FIFO_DEPTH = 1024,
  // Parameter Description: verification-only timer divider, must be 1 in a delivered netlist.
  // Parameter values: 1, 16, 256 or 4096; default is 1.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_TSCALE = 1,
  // Parameter Description: AXI data width, which must be four times the UTMI+ width (DEC-010).
  // Parameter values: 32 or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_USB2_AXI_DATA_W = 32,
  localparam logic [31:0] LPARA_ONE       = 1,
  localparam logic [31:0] LPARA_ZERO      = 0,
  localparam logic [31:0] LPARA_W16       = 16,
  localparam logic [31:0] LPARA_TS_16     = 16,
  localparam logic [31:0] LPARA_TS_256    = 256,
  localparam logic [31:0] LPARA_TS_4096   = 4096,
  localparam logic [31:0] LPARA_MIN_DEPTH = 256,
  localparam logic [31:0] LPARA_MAX_DEPTH = 32768,
  localparam logic [31:0] LPARA_ROW_MUL   = 4,
  // 1 for an illegal parameter combination of sections 4 and 8: split needs a host role, 16-bit
  // UTMI+ cannot be combined with ULPI, scatter-gather needs the master data interface, the slave
  // interface needs a handshake channel, the depth is a power of two in range, the timer divider
  // is one of the allowed values, and the AXI data width is four chunks of the UTMI+ width.
  localparam logic [31:0] LPARA_CFG_ERR   = (
      ((PARA_USB2_SPLIT_EN == LPARA_ONE) & (PARA_USB2_ROLE == LPARA_ZERO)) |
      ((PARA_USB2_PHY_IF == LPARA_ONE) & (PARA_USB2_UTMI_W == LPARA_W16)) |
      ((PARA_USB2_SG_EN == LPARA_ONE) & (PARA_USB2_DATA_IF == LPARA_ONE)) |
      ((PARA_USB2_DATA_IF == LPARA_ONE) & (PARA_USB2_NUM_DMA_CH == LPARA_ZERO)) |
      (PARA_USB2_FIFO_DEPTH < LPARA_MIN_DEPTH) | (PARA_USB2_FIFO_DEPTH > LPARA_MAX_DEPTH) |
      ((PARA_USB2_FIFO_DEPTH & (PARA_USB2_FIFO_DEPTH - LPARA_ONE)) != LPARA_ZERO) |
      ((PARA_USB2_TSCALE != LPARA_ONE) & (PARA_USB2_TSCALE != LPARA_TS_16) &
      (PARA_USB2_TSCALE != LPARA_TS_256) & (PARA_USB2_TSCALE != LPARA_TS_4096)) |
      (PARA_USB2_AXI_DATA_W != (PARA_USB2_UTMI_W * LPARA_ROW_MUL))) ? 32'd1 : 32'd0
) (
  // Elaboration result
  output logic o_cfg_err
);

  // Result: 1 if a combination is illegal (constant).
  assign o_cfg_err = (LPARA_CFG_ERR != 32'd0);

  // Elaboration stop for an illegal parameter combination (REQ-PARAM-001, HDS section 8: "the
  // configuration check reports them"). Outside the synthesis branch only (R-027).
`ifndef VLSIT_SYNTHESIS
  if (LPARA_CFG_ERR != 32'd0) begin : gen_cfg_err
    $error("m_usb2_cfgchk: illegal parameter combination (REQ-PARAM-001, HDS sections 4 and 8)");
  end
`endif

endmodule
