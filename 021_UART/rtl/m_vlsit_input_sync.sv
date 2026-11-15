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
//    - UART IP - Input Synchronizer (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-10-06   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
// LamCTv: 16/10/26: Add RST_INPUT_SYNC parameter (0: Active-high input, 1: Active-low input)
import m_vlsit_uart_package::*;
module m_vlsit_input_sync #(
  parameter logic RST_INPUT_SYNC = 1'b0
)(
  input  logic i_clk,
  input  logic i_rst_n,
  input  logic i_d,
  output logic o_q
);
//===================DECLARATION=================================
  logic [1:0] iD;
//================Input Synchronous==============================
  always_ff @(posedge i_clk or negedge i_rst_n) begin : IS_D
    if (!i_rst_n) begin
      iD <= {2{RST_INPUT_SYNC}};
    end else begin
      iD[0] <= i_d;
      iD[1] <= iD[0];
    end
  end
  assign o_q = iD[1];
endmodule