//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary 
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Chau Tran Vinh Lam
// Email           : lamctv@fpt.com
// Created Date    : 2026-09-26

// Description     : 
//    - UART IP - Asynchronous FIFO (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_uart_fifo #(
  parameter int DATA_WIDTH_FIFO = 8,
  parameter int DEPTH_FIFO = 6
)(
  input  logic                       i_clk,
  input  logic                       i_rst_n,
  input  logic                       i_clear,
  input  logic                       i_write,
  input  logic                       i_read,
  input  logic [DATA_WIDTH_FIFO-1:0] i_d,
  output logic [DATA_WIDTH_FIFO-1:0] o_q,
  output logic                       o_empty,
  output logic                       o_full,
  output logic [DEPTH_FIFO-1:0]      o_usage
);
//=====================DECLARATION============================================
  logic                       iEMPTY;
  logic                       iFULL;
  logic [DEPTH_FIFO:0]        iWRAddr;    // Con trỏ ghi (Thêm 1 bit MSB để kiểm tra FULL/EMPTY)
  logic [DEPTH_FIFO:0]        iRDAddr;    // Con trỏ đọc (Thêm 1 bit MSB để kiểm tra FULL/EMPTY)
  logic [DEPTH_FIFO-1:0]      iUSAGE;
  logic [DATA_WIDTH_FIFO-1:0] iFIFOMem [2**DEPTH_FIFO];
  int                         i;
//=====================MAIN PROCESS================================================
  assign iFULL  = (iRDAddr[DEPTH_FIFO-1:0] == iWRAddr[DEPTH_FIFO-1:0]) & 
                  (iRDAddr[DEPTH_FIFO]     != iWRAddr[DEPTH_FIFO]);
  assign iEMPTY = (iRDAddr == iWRAddr);
  always_ff @(posedge i_clk or negedge i_rst_n) begin : FF_ADDR
    if (!i_rst_n) begin
      iWRAddr <= '0;
      iRDAddr <= '0;
    end else begin
      if (i_clear) begin                                    // Reset FIFO
        iWRAddr <= '0;
        iRDAddr <= '0;
      end else begin
        if (i_write && !iFULL)  iWRAddr <= iWRAddr + 1'b1;  // Write to FIFO
        if (i_read  && !iEMPTY) iRDAddr <= iRDAddr + 1'b1;  // Read from FIFO
      end
      // Warning: LamCTV: Empty Logic must be combination
      // if (iRDAddr == iWRAddr) iEMPTY <= 1'b1;
      // else                    iEMPTY <= 1'b0;
    end
  end
//=================FIFO MEMORY ACCESS=================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin : FF_MEM
    if (!i_rst_n) begin
      for (i = 0; i < 2**DEPTH_FIFO; i++) begin
        iFIFOMem[i] <= '0;
      end
    end else if (i_write && !iFULL) begin 
      iFIFOMem[iWRAddr[DEPTH_FIFO-1:0]] <= i_d;
      // LamCTV: Read Asynchronous
      // else                   o_q <= iFIFOMem[iRDAddr[DEPTH_FIFO-1:0]];
    end
  end
  assign o_q = iFIFOMem[iRDAddr[DEPTH_FIFO-1:0]];
//==================USAGE COUNTER======================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin : FF_USAGE
    if (!i_rst_n) begin
      iUSAGE <= '0;
    end else begin
      if      (i_clear)                       iUSAGE <= '0;
      else if (!i_read && i_write && !iFULL)  iUSAGE <= iUSAGE + 1'b1;
      else if (!i_write && i_read && !iEMPTY) iUSAGE <= iUSAGE - 1'b1;
    end
  end
  assign o_empty = iEMPTY;
  assign o_full  = iFULL;
  assign o_usage = iUSAGE;
endmodule