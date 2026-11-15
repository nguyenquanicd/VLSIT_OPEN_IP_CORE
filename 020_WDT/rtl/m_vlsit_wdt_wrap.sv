//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Do Luong Minh Hoang
// Email           : HoangDLM2@fpt.com
// Created Date    : 2026-10-03
// Description     :
//   - Top-level wrapper for Watchdog Timer.
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-10-03   1.0             Hoang            Initial creation
// 2026-10-12   1.1             Hoang            Correct emacs & wrapper rules
//------------------------------------------------------------------------------

module m_vlsit_wdt_wrap (
    /*AUTOARG*/
   // Outputs
   o_wdt_apb_pslverr, o_wdt_apb_pready, o_wdt_apb_prdata, o_wdt_rst,
   o_wdt_int,
   // Inputs
   i_wdt_apb_pwrite, i_wdt_apb_pwdata, i_wdt_apb_psel,
   i_wdt_apb_penable, i_wdt_apb_paddr, i_wdt_pclk, i_wdt_preset_n,
   i_wdt_clk, i_wdt_rst_n, i_wdt_other_unlock
   );

//------------------------------------------------------------------------------
// 1. CLOCK & RESET
//------------------------------------------------------------------------------
input  wire i_wdt_pclk;
input  wire i_wdt_preset_n;
input  wire i_wdt_clk;
input  wire i_wdt_rst_n;
output wire o_wdt_rst;

//------------------------------------------------------------------------------
// 2. Others
//------------------------------------------------------------------------------
input  wire i_wdt_other_unlock;

//------------------------------------------------------------------------------
// 3. APB SLAVE INTERFACE
//------------------------------------------------------------------------------
/*AUTOINPUT("^i_wdt_apb_")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [15:0]	i_wdt_apb_paddr;	// To u_vlsit_wdt_top of m_vlsit_wdt_top.v
input logic		i_wdt_apb_penable;	// To u_vlsit_wdt_top of m_vlsit_wdt_top.v
input logic		i_wdt_apb_psel;		// To u_vlsit_wdt_top of m_vlsit_wdt_top.v
input logic [31:0]	i_wdt_apb_pwdata;	// To u_vlsit_wdt_top of m_vlsit_wdt_top.v
input logic		i_wdt_apb_pwrite;	// To u_vlsit_wdt_top of m_vlsit_wdt_top.v
// End of automatics
/*AUTOOUTPUT("^o_wdt_apb_")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]	o_wdt_apb_prdata;	// From u_vlsit_wdt_top of m_vlsit_wdt_top.v
output logic		o_wdt_apb_pready;	// From u_vlsit_wdt_top of m_vlsit_wdt_top.v
output logic		o_wdt_apb_pslverr;	// From u_vlsit_wdt_top of m_vlsit_wdt_top.v
// End of automatics

//------------------------------------------------------------------------------
// 4. Interrupt
//------------------------------------------------------------------------------
output wire o_wdt_int;

//------------------------------------------------------------------------------
// 5. Internal wires & sequential signals
//------------------------------------------------------------------------------
/*AUTOWIRE*/
/*AUTOREG*/


//==============================================================================
// WATCHDOG TIMER
//==============================================================================

/* m_vlsit_wdt_top AUTO_TEMPLATE "u_vlsit_wdt_top" (
    .i_clk_wdog                                 (i_wdt_clk),
    .i_rst_n_wdog                               (i_wdt_rst_n),
    .o_wdogres                                  (o_wdt_rst),

    .i_clk_apb                                  (i_wdt_pclk),
    .i_rst_n_apb                                (i_wdt_preset_n),

    .o_int_wdog                                 (o_wdt_int),
    
    .i_unlock                                   (i_wdt_other_unlock),

    .i_\(psel\|penable\|paddr\|pwrite\|pwdata\) (i_wdt_apb_\1[]),
    .o_\(prdata\|pready\|pslverr\)              (o_wdt_apb_\1[]),
); */

m_vlsit_wdt_top #(
    .PARA_APB_ADDR_WIDTH (16),
    .PARA_APB_DATA_WIDTH (32),
    .PARA_WD_DATA_WIDTH  (32),
    .PARA_RESDIV_WIDTH   (4)
) u_vlsit_wdt_top (
    /*AUTOINST*/
		 // Outputs
		 .o_prdata		(o_wdt_apb_prdata[31:0]), // Templated
		 .o_pready		(o_wdt_apb_pready),	 // Templated
		 .o_pslverr		(o_wdt_apb_pslverr),	 // Templated
		 .o_int_wdog		(o_wdt_int),		 // Templated
		 .o_wdogres		(o_wdt_rst),		 // Templated
		 // Inputs
		 .i_clk_apb		(i_wdt_pclk),		 // Templated
		 .i_rst_n_apb		(i_wdt_preset_n),	 // Templated
		 .i_psel		(i_wdt_apb_psel),	 // Templated
		 .i_penable		(i_wdt_apb_penable),	 // Templated
		 .i_paddr		(i_wdt_apb_paddr[15:0]), // Templated
		 .i_pwrite		(i_wdt_apb_pwrite),	 // Templated
		 .i_pwdata		(i_wdt_apb_pwdata[31:0]), // Templated
		 .i_clk_wdog		(i_wdt_clk),		 // Templated
		 .i_rst_n_wdog		(i_wdt_rst_n),		 // Templated
		 .i_unlock		(i_wdt_other_unlock));	 // Templated

endmodule : m_vlsit_wdt_wrap


// Local Variables:
// verilog-library-directories: ("." "./wdt_in_house_v6")
// verilog-library-files: ("./wdt_in_house_v6/m_vlsit_wdt_top.sv")
// verilog-library-flags: ("-F filelist.f")
// verilog-library-extensions: (".v" ".sv" ".vh" ".svh")
// verilog-auto-read-includes: t
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// End:
