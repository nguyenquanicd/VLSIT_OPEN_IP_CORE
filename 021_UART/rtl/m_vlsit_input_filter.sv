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
//    - UART IP - Input Filter (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_input_filter #(
  parameter     SIZE_INPUT_FILTER      = 2,
  parameter int WIDTH_INPUT_FILTER     = $clog2(SIZE_INPUT_FILTER + 1),
  parameter     RST_INPUT_FILTER = 1'b0
)(
  input  logic i_clk,
  input  logic i_rst_n,
  input  logic i_ce,
  input  logic i_d,
  output logic o_q
);
//===================DECLARATION==================================================
  localparam logic [WIDTH_INPUT_FILTER-1:0] MAX_COUNT_VAL = SIZE_INPUT_FILTER;
  logic [WIDTH_INPUT_FILTER-1:0] iCount;
//================Input Filter==================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin : IF_D
    if (!i_rst_n) begin
      iCount <= RST_INPUT_FILTER ? MAX_COUNT_VAL : '0;
      o_q    <= RST_INPUT_FILTER;
    end else begin
      //-----------Input Counter-------------------
      if (i_ce) begin
        if (i_d && (iCount != SIZE_INPUT_FILTER)) begin
          iCount <= iCount + 1'b1;
        end else if (!i_d && (iCount != '0)) begin
          iCount <= iCount - 1'b1;
        end
      end
      //------------Output----------------------------
      if      (iCount == SIZE_INPUT_FILTER) o_q <= 1'b1;
      else if (iCount == '0)                o_q <= 1'b0;
    end
  end
endmodule