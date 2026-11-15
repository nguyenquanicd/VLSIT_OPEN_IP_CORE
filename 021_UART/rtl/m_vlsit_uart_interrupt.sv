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
//    - UART IP - Interrupt Controller (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_uart_interrupt (
  input  logic       i_clk,
  input  logic       i_rst_n,
  input  logic [3:0] i_ier,
  input  logic [4:0] i_lsr,
  input  logic       i_thi,
  input  logic       i_rda,
  input  logic       i_cti,
  input  logic       i_afe,
  input  logic [3:0] i_msr,
  output logic [3:0] o_iir,
  output logic       o_int
);
//===================DECLARATION==================================================
  logic       iRLSInterrupt;
  logic       iRDAInterrupt;
  logic       iCTIInterrupt;
  logic       iTHRInterrupt;
  logic       iMSRInterrupt;
  logic [3:0] iIIR;
//==================Priority======================================================
  // Priority 1: Receiver line status interrupt on: Overrun error, parity error, framing error or break interrupt
  assign iRLSInterrupt = i_ier[2] & (i_lsr[1] | i_lsr[2] | i_lsr[3] | i_lsr[4]);
  // Priority 2: Received data available or trigger level reached in FIFO mode
  assign iRDAInterrupt = i_ier[0] & i_rda;
  // Priority 2: Character timeout indication
  assign iCTIInterrupt = i_ier[0] & i_cti;
  // Priority 3: Transmitter holding register empty
  assign iTHRInterrupt = i_ier[1] & i_thi;
  // Priority 4: Modem status interrupt: dCTS (when AFC is disabled), dDSR, TERI, dDCD
  assign iMSRInterrupt = i_ier[3] & ((i_msr[0] & ~i_afe) | i_msr[1] | i_msr[2] | i_msr[3]);
//==================IIR==============================================================
  always_ff @(posedge i_clk or negedge i_rst_n) begin : IC_IIR_PROCESS
    if (!i_rst_n) begin
      iIIR <= 4'b0001;
    end else begin
      if      (iRLSInterrupt) iIIR <= 4'b0110; // Priority 1: Receiver Line Status
      else if (iCTIInterrupt) iIIR <= 4'b1100; // Priority 2a: Character Timeout Indication
      else if (iRDAInterrupt) iIIR <= 4'b0100; // Priority 2b: Received Data Available
      else if (iTHRInterrupt) iIIR <= 4'b0010; // Priority 3: Transmitter Holding Register Empty
      else if (iMSRInterrupt) iIIR <= 4'b0000; // Priority 4: Modem Status
      else                    iIIR <= 4'b0001; // Không có ngắt nào kích hoạt
    end
  end
  assign o_iir  = iIIR;
  assign o_int = ~iIIR[0];
endmodule