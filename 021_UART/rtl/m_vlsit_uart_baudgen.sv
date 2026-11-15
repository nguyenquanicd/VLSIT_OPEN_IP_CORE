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
//    - UART IP - BaudRate Generator (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_uart_baudgen (
  input  logic        i_clk,
  input  logic        i_rst_n,
  input  logic        i_ce,
  input  logic        i_clear,
  input  logic [15:0] i_divider,
  output logic        o_baudtick
);
//==============DECLARATION===============================================================
  logic [15:0] iCounter; 
//==============BAUDRATE COUNTER==========================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin : BG_COUNT
    if (!i_rst_n) begin
      iCounter   <= '0;
      o_baudtick <= 1'b0;
    end else begin
      if (i_clear) begin
        iCounter   <= '0;
        o_baudtick <= 1'b0;
      end else if (i_ce) begin
        if (i_divider == 16'd1) begin
           iCounter   <= '0;
           o_baudtick <= 1'b1;        
        end else if (iCounter >= i_divider - 16'd1) begin
           iCounter   <= '0;
           o_baudtick <= 1'b1;
        end else begin
           iCounter   <= iCounter + 1'b1;
           o_baudtick <= 1'b0;
        end
      end else begin
        o_baudtick <= 1'b0; 
      end
    end
  end
endmodule