`timescale 1ns/1ps

//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Do Luong Minh Hoang
// Email           : HoangDLM2@fpt.com
// Created Date    : 2026-10-15
// Description     :
//   - WDT Core includes:
//      + 32-bit down counter. (m_vlsit_wdt_counter.sv)
//      + Interrupt and reset generation. (m_vlsit_wdt_int_rst.sv)
//      + Programmable reset pulse length. (m_vlsit_wdt_rst_pulse.sv)
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-10-15   1.0             Hoang            Initial creation
// 2026-11-07   1.4             Hoang            Add i_cnt_en (CNT_EN), i_resdiv
//                                               and m_vlsit_wdt_rst_pulse
//------------------------------------------------------------------------------


module m_vlsit_wdt_core #(
    parameter int PARA_WD_DATA_WIDTH = 32,
    parameter int PARA_RESDIV_WIDTH  = 4
) (
    input 			    i_clk_wdog,
    input 			    i_rst_n_wdog,
    input 		 	    i_ld_write,
    input 			    i_int_clr,
    input 			    i_halt,
    input 			    i_cnt_en,
    input 		   	 i_inten,
    input 			    i_resen,
    input  [PARA_RESDIV_WIDTH-1:0]  i_resdiv,
    input  [PARA_WD_DATA_WIDTH-1:0] i_load_val,
    output [PARA_WD_DATA_WIDTH-1:0] o_cnt_val,
    output 		 	    o_timeout_seen,
    output			    o_int_wdog,
    output 			    o_wdogres
);	
    logic w_cnt_stop, w_ld_write, w_int_clr, w_inten, w_halt, w_rst_set;
    logic [PARA_WD_DATA_WIDTH-1:0] w_cnt_val;
    assign o_cnt_val  = w_cnt_val;
    assign w_ld_write = i_ld_write;
    assign w_int_clr  = i_int_clr;
    assign w_inten    = i_inten;
    assign w_halt     = i_halt;

    m_vlsit_wdt_counter # (
    	.PARA_WD_DATA_WIDTH (PARA_WD_DATA_WIDTH)
    ) u_vlsit_wdt_counter (
	.i_clk_wdog		(i_clk_wdog),
	.i_rst_n_wdog		(i_rst_n_wdog),
	.i_cnt_en		(i_cnt_en),
	.i_ld_write		(w_ld_write),
	.i_int_clr		(w_int_clr),
	.i_halt 	  	(w_halt),
	.i_cnt_stop 	  	(w_cnt_stop),
	.i_load_val 		(i_load_val),
	.o_cnt_val 		(w_cnt_val)
    );

   m_vlsit_wdt_int_rst # (
	.PARA_WD_DATA_WIDTH (PARA_WD_DATA_WIDTH)
   ) u_vlsit_wdt_int_rst (
	.i_clk_wdog		(i_clk_wdog),
	.i_rst_n_wdog		(i_rst_n_wdog),
	.i_cnt_val		(w_cnt_val),
	.i_ld_write 		(w_ld_write),
	.i_int_clr 		(w_int_clr),
	.i_halt 		(w_halt),
	.i_cnt_en		(i_cnt_en),
	.i_inten		(w_inten),
	.i_resen		(i_resen),
	.o_timeout_seen		(o_timeout_seen),
	.o_cnt_stop		(w_cnt_stop),
	.o_int_wdog		(o_int_wdog),
	.o_rst_set		(w_rst_set)
   );

   m_vlsit_wdt_rst_pulse # (
	.PARA_RESDIV_WIDTH (PARA_RESDIV_WIDTH)
   ) u_vlsit_wdt_rst_pulse (
	.i_clk_wdog		(i_clk_wdog),
	.i_rst_n_wdog		(i_rst_n_wdog),
	.i_rst_set		(w_rst_set),
	.i_resdiv		(i_resdiv),
	.o_wdogres		(o_wdogres)
   );

endmodule: m_vlsit_wdt_core
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------