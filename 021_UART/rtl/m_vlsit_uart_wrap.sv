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
import m_vlsit_uart_package::*;
module m_vlsit_uart_wrap (
  //--------------------------------------
  // Clock / reset
  //--------------------------------------
  input logic         i_uart_pclk,
  input logic         i_uart_preset_n,
  //--------------------------------------
  // IO PAD - UART Signals
  //--------------------------------------
  /*AUTOINPUT("^i_uart_pad_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  input logic		     i_uart_pad_ctsn,	// To u_apb_uart_core of m_vlsit_apb_uart.v
  input logic		     i_uart_pad_dcdn,	// To u_apb_uart_core of m_vlsit_apb_uart.v
  input logic		     i_uart_pad_dsrn,	// To u_apb_uart_core of m_vlsit_apb_uart.v
  input logic		     i_uart_pad_rin,		// To u_apb_uart_core of m_vlsit_apb_uart.v
  input logic		     i_uart_pad_rxd,		// To u_apb_uart_core of m_vlsit_apb_uart.v
  // End of automatics
  /*AUTOOUTPUT("^o_uart_pad_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  output logic    	 o_uart_pad_dtrn,	// From u_apb_uart_core of m_vlsit_apb_uart.v
  output logic    	 o_uart_pad_out1n,	// From u_apb_uart_core of m_vlsit_apb_uart.v
  output logic    	 o_uart_pad_out2n,	// From u_apb_uart_core of m_vlsit_apb_uart.v
  output logic    	 o_uart_pad_rtsn,	// From u_apb_uart_core of m_vlsit_apb_uart.v
  output logic    	 o_uart_pad_txd,		// From u_apb_uart_core of m_vlsit_apb_uart.v
  // End of automatics
  //--------------------------------------
  // APB Interface (16-bit System Bus)
  //--------------------------------------
  /*AUTOINPUT("^i_uart_apb_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  input logic [15:0] i_uart_apb_paddr,	// To u_uart_apbdec of m_vlsit_uart_apbdec.v
  input logic		     i_uart_apb_penable,	// To u_uart_apbdec of m_vlsit_uart_apbdec.v
  input logic		     i_uart_apb_psel,	// To u_uart_apbdec of m_vlsit_uart_apbdec.v
  input logic [31:0] i_uart_apb_pwdata,	// To u_uart_apbdec of m_vlsit_uart_apbdec.v
  input logic		     i_uart_apb_pwrite,	// To u_uart_apbdec of m_vlsit_uart_apbdec.v
  // End of automatics
  /*AUTOOUTPUT("^o_uart_apb_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  output logic [31:0]	o_uart_apb_prdata,	// From u_uart_apbdec of m_vlsit_uart_apbdec.v
  output logic		    o_uart_apb_pready,	// From u_uart_apbdec of m_vlsit_uart_apbdec.v
  output logic		    o_uart_apb_pslverr,	// From u_uart_apbdec of m_vlsit_uart_apbdec.v
  // End of automatics
  //--------------------------------------
  // Interrupt (FU3 Spec Table 10-1)
  //--------------------------------------
  output logic        o_uart_int,
  //--------------------------------------
  // DMA interface
  //--------------------------------------
  /*AUTOINPUT("^i_uart_dma_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  input logic		     i_uart_dma_rx_clr,	// To u_apb_uart_core of m_vlsit_apb_uart.v
  input logic		     i_uart_dma_tx_clr,	// To u_apb_uart_core of m_vlsit_apb_uart.v
  // End of automatics
  /*AUTOOUTPUT("^o_uart_dma_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  output logic    	 o_uart_dma_rx_req,	// From u_apb_uart_core of m_vlsit_apb_uart.v
  output logic    	 o_uart_dma_tx_req	// From u_apb_uart_core of m_vlsit_apb_uart.v
  // End of automatics
  //--------------------------------------
  // Others (Clocks and Resets)
  //--------------------------------------
  /*AUTOINPUT*/
  /*AUTOOUTPUT*/
  /*AUTOINOUT*/
);

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [2:0]	 w_paddr_uart;		// From u_uart_apbdec of m_vlsit_uart_apbdec.v
logic [3:0]	 w_pstrb_uart;		// From u_uart_apbdec of m_vlsit_uart_apbdec.v
logic			   w_penable_uart;		// From u_uart_apbdec of m_vlsit_uart_apbdec.v
logic [31:0] w_prdata_uart;		// From u_apb_uart_core of m_vlsit_apb_uart.v
logic			   w_pready_uart;		// From u_apb_uart_core of m_vlsit_apb_uart.v
logic			   w_psel_uart;		// From u_uart_apbdec of m_vlsit_uart_apbdec.v
logic			   w_pslverr_uart;		// From u_apb_uart_core of m_vlsit_apb_uart.v
logic [31:0] w_pwdata_uart;		// From u_uart_apbdec of m_vlsit_uart_apbdec.v
logic			   w_pwrite_uart;		// From u_uart_apbdec of m_vlsit_uart_apbdec.v
// End of automatics
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
				 // Outputs
				 .o_pready		   (o_uart_apb_pready), // Templated
				 .o_pslverr		   (o_uart_apb_pslverr), // Templated
				 .o_prdata		   (o_uart_apb_prdata[31:0]), // Templated
				 .o_paddr_uart	 (w_paddr_uart[2:0]), // Templated
				 .o_pwdata_uart	 (w_pwdata_uart[31:0]), // Templated
				 .o_psel_uart		 (w_psel_uart),	 // Templated
				 .o_penable_uart (w_penable_uart), // Templated
				 .o_pwrite_uart	 (w_pwrite_uart), // Templated
				 // Inputs
				 .i_paddr	     	 (i_uart_apb_paddr[15:0]), // Templated
				 .i_pwdata		   (i_uart_apb_pwdata[31:0]), // Templated
				 .i_pwrite		   (i_uart_apb_pwrite), // Templated
				 .i_psel		     (i_uart_apb_psel), // Templated
				 .i_penable		   (i_uart_apb_penable), // Templated
				 .i_pready_uart	 (w_pready_uart), // Templated
				 .i_pslverr_uart (w_pslverr_uart), // Templated
				 .i_prdata_uart	 (w_prdata_uart[31:0])); // Templated

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
				// Outputs
				.PRDATA		(w_prdata_uart[31:0]), // Templated
				.PREADY		(w_pready_uart), // Templated
				.PSLVERR	(w_pslverr_uart), // Templated
				.INT		(o_uart_int),	 // Templated
				.RTSN		(o_uart_pad_rtsn), // Templated
				.DTRN		(o_uart_pad_dtrn), // Templated
				.OUT1N		(o_uart_pad_out1n), // Templated
				.OUT2N		(o_uart_pad_out2n), // Templated
				.TXD		(o_uart_pad_txd), // Templated
				.o_uart_dma_tx_req(o_uart_dma_tx_req),
				.o_uart_dma_rx_req(o_uart_dma_rx_req),
				// Inputs
				.PCLK		(i_uart_pclk),	 // Templated
				.RSTN		(i_uart_preset_n), // Templated
				.PSEL		(w_psel_uart),	 // Templated
				.PENABLE	(w_penable_uart), // Templated
				.PWRITE		(w_pwrite_uart), // Templated
				.PADDR		(w_paddr_uart[2:0]), // Templated
				.PWDATA		(w_pwdata_uart[31:0]), // Templated
				.CTSN		(i_uart_pad_ctsn), // Templated
				.DCDN		(i_uart_pad_dcdn), // Templated
				.DSRN		(i_uart_pad_dsrn), // Templated
				.RIN		(i_uart_pad_rin), // Templated
				.RXD		(i_uart_pad_rxd), // Templated
				.i_uart_dma_tx_clr(i_uart_dma_tx_clr),
				.i_uart_dma_rx_clr(i_uart_dma_rx_clr));

endmodule: m_vlsit_uart_wrap
// Local Variables:
// verilog-library-directories: ("." ".." "./latest")
// verilog-library-extensions: (".v" ".sv" ".svh")
// verilog-auto-read-includes: t
// verilog-auto-star-expand: nil
// End:
