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
//    - UART IP - Clock Divider (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_uart_clk_div (
  input  logic i_clk,
  input  logic i_rst_n,
  input  logic i_ovs_mode,
  input  logic i_ce,
  output logic o_clk
);
//===========INSTANTIATION========================================================
  logic       iQ;
  logic [7:0] iCounter;
  logic [7:0] counter_threshold;
//==========MAIN PROCESS==========================================================
  // Keep the output at 2x baud: divide 8x input by 4, or 16x input by 8.
  assign counter_threshold = i_ovs_mode ? 8'd4 : 8'd8;

  always_ff @(posedge i_clk or negedge i_rst_n) begin : CD_PROC
    if (!i_rst_n) begin
      iCounter <= '0;
      iQ       <= 1'b0;
    end else begin
      iQ <= 1'b0;

      if (i_ce) begin
        if (iCounter >= (counter_threshold - 8'd1)) begin
          iQ       <= 1'b1;
          iCounter <= '0;
        end else begin
          iCounter <= iCounter + 8'd1;
        end
      end
    end
  end
  assign o_clk = iQ;
endmodule
