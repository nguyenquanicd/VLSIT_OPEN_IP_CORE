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
//    - UART IP - Majority Voting Filter (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_mv_filter #(
  parameter int WIDTH_MV = 4
) (
  input  logic i_clk,       
  input  logic i_rst_n,     
  input  logic i_sample,    
  input  logic i_clear,     
  input  logic i_d,         
  output logic o_q          
);
  logic [WIDTH_MV-1:0] iCounter;
  logic                iQ;
  logic [WIDTH_MV-1:0] threshold;

  assign threshold = 4'd3;

  always_ff @(posedge i_clk or negedge i_rst_n) begin: MV_PROC
    if (!i_rst_n) begin
      iCounter <= '0;
      iQ       <= 1'b0;
    end else begin
      if (i_clear) begin
        iCounter <= '0;
        iQ       <= 1'b0;
      end else begin
        if (iCounter >= threshold) begin
          iQ <= 1'b1;
        end else begin
          if (i_sample && i_d) begin
            iCounter <= iCounter + 1'b1;
          end
        end
      end
    end
  end
  assign o_q = iQ;
endmodule