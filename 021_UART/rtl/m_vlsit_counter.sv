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
//    - UART IP - Counter (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_counter #(
  parameter int WIDTH_COUNTER = 4
) (
  input  logic                     i_clk,       // Clock
  input  logic                     i_rst_n,     // Reset (Active-low)
  input  logic                     i_clear,     // Clear counter register
  input  logic                     i_load,      // Load counter register
  input  logic                     i_enable,    // Enable count operation
  input  logic                     i_down,      // Count direction down (1: down, 0: up)
  input  logic                     i_ovs_mode,  // 0: 16x Oversampling, 1: 8x Oversampling
  input  logic [WIDTH_COUNTER-1:0] i_d,         // Load counter register input
  output logic [WIDTH_COUNTER-1:0] o_q,         // Counter value output
  output logic                     o_overflow   // Counter overflow flag (1-cycle pulse)
);

  logic [WIDTH_COUNTER:0] iCounter;       // Internal Registers
  logic [WIDTH_COUNTER:0] iCounter_nxt;   // Register Update
  logic [WIDTH_COUNTER:0] iCounter_val;
  logic [WIDTH_COUNTER-1:0] max_count;
  // Change the max_count based on the oversampling mode
  assign max_count = i_ovs_mode ? (WIDTH_COUNTER'(7)) : (WIDTH_COUNTER'(15));
  always_comb begin : COUNT_NXT
    if (i_clear) begin
      iCounter_val = '0;
    end else if (i_load) begin
      iCounter_val = {1'b0, i_d};
    end else if (i_enable) begin
      if (~i_down) begin
        if (iCounter[WIDTH_COUNTER-1:0] >= max_count) begin
          iCounter_val = {1'b1, {WIDTH_COUNTER{1'b0}}};
        end else begin
          iCounter_val = iCounter + 1'b1;
        end
      end else begin
        if (iCounter[WIDTH_COUNTER-1:0] == '0) begin
          iCounter_val = {1'b1, max_count};
        end else begin
          iCounter_val = iCounter - 1'b1;
        end
      end
    end else begin
      iCounter_val = iCounter;
    end
    iCounter_nxt = {iCounter_val[WIDTH_COUNTER] & ~iCounter[WIDTH_COUNTER], iCounter_val[WIDTH_COUNTER-1:0]};
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin : COUNT_SHIFT
    if (!i_rst_n) begin
      iCounter <= '0;
    end else begin
      iCounter <= iCounter_nxt;
    end
  end

  // Output Assignments
  assign o_q        = iCounter[WIDTH_COUNTER-1:0];
  assign o_overflow = iCounter[WIDTH_COUNTER];
endmodule