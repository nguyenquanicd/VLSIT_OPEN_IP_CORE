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
//    - UART IP - Edge Detector (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
// LamCTv: 16/10/26: Add RESET paramter for different reset type (active high or active low)
import m_vlsit_uart_package::*;
module m_vlsit_edge_detect #(
  parameter logic RST_EDGE_DETECT = 1'b0
)(
  input  logic i_clk,
  input  logic i_rst_n,
  input  logic i_signal,
  output logic o_rising_edge,
  output logic o_falling_edge
);
//=====================DECLARATION============================================
  logic iDd;
//=====================Store D================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin: ED_D
    if(!i_rst_n) begin
      iDd <= RST_EDGE_DETECT;
    end else begin
      iDd <= i_signal;
    end
  end
  assign o_rising_edge  = ~iDd &  i_signal;
  assign o_falling_edge =  iDd & ~i_signal;
endmodule