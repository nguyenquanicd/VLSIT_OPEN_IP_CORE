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
//    - Wrapper for the UART IP (Project FU3).
//    - Integrates with the FU3 SoC architecture (16-bit APB Bus).


// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.

//------------------------------------------------------------------------------
module m_vlsit_uart_wrap (
  //--------------------------------------
  // Clock / reset
  //--------------------------------------
  input logic i_uart_pclk,
  input logic i_uart_preset_n,
  //--------------------------------------
  // IO PAD - UART Signals
  //--------------------------------------
  /*AUTOINPUT("^i_uart_pad_")*/
  /*AUTOOUTPUT("^o_uart_pad_")*/
  //--------------------------------------
  // APB Interface (16-bit System Bus)
  //--------------------------------------
  /*AUTOINPUT("^i_uart_apb_")*/
  /*AUTOOUTPUT("^o_uart_apb_")*/
  
  //--------------------------------------
  // Interrupt (FU3 Spec Table 10-1)
  //--------------------------------------
  output logic o_uart_int,

  //--------------------------------------
  // DMA interface
  //--------------------------------------
  /*AUTOINPUT("^i_uart_dma_")*/
  /*AUTOOUTPUT("^o_uart_dma_")*/
  
  //--------------------------------------
  // Others (Clocks and Resets)
  //--------------------------------------
  /*AUTOINPUT*/
  /*AUTOOUTPUT*/
  /*AUTOINOUT*/
);

/*AUTOWIRE*/
/*AUTOREG*/

/* m_vlsit_uart_apbdec AUTO_TEMPLATE (
  // APB master interface
  .i_paddr          (i_uart_apb_paddr[]),
  .i_pwdata         (i_uart_apb_pwdata[]),
  .i_pstrb          (4'b1111),
  .i_pwrite         (i_uart_apb_pwrite),
  .i_psel           (i_uart_apb_psel),
  .i_penable        (i_uart_apb_penable),
  .o_pready         (o_uart_apb_pready),
  .o_pslverr        (o_uart_apb_pslverr),
  .o_prdata         (o_uart_apb_prdata[]),
  .o_pstrb_uart     (),

  // UART APB slave interface: decoder-to-core wires use w_*_uart.
  .o_\(.*\)_uart   (w_\1_uart[]),
  .i_\(.*\)_uart   (w_\1_uart[]),
); */
m_vlsit_uart_apbdec u_uart_apbdec (
  /*AUTOINST*/
);

/* m_vlsit_apb_uart AUTO_TEMPLATE (
  .PCLK                           (i_uart_pclk),
  .RSTN                           (i_uart_preset_n),
  .PRDATA                        (w_prdata_uart[]),
  .PREADY                        (w_pready_uart),
  .PSLVERR                       (w_pslverr_uart),
  .PADDR                         (w_paddr_uart[]),
  .PWDATA                        (w_pwdata_uart[]),
  .PSEL                          (w_psel_uart),
  .PENABLE                       (w_penable_uart),
  .PWRITE                        (w_pwrite_uart),
  .INT                            (o_uart_int),
  .\(TXD\|RTSN\|DTRN\|OUT1N\|OUT2N\) (o_uart_pad_@"(downcase vl-name)"[]),
  .\(RXD\|CTSN\|DSRN\|DCDN\|RIN\)     (i_uart_pad_@"(downcase vl-name)"[]),
); */
m_vlsit_apb_uart u_apb_uart_core (
    /*AUTOINST*/
);

endmodule: m_vlsit_uart_wrap
// Local Variables:
// verilog-library-directories: ("." ".." "./latest")
// verilog-library-extensions: (".v" ".sv" ".svh")
// verilog-auto-read-includes: t
// verilog-auto-star-expand: nil
// End:
