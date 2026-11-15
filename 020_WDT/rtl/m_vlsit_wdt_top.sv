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
// Created Date    : 2026-09-30
// Description     :
//   - TOP Module for WDT. It includes instantiation of:
//      + m_vlsit_wdt_csr.sv
//      + m_vlsit_wdt_core.sv
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-10-03   1.0             Hoang            Initial creation
// 2026-10-15   1.1             Hoang            2FF, APB interface, 
//						                         APB interface sync, 
//						                         separate CSR, WDT core
// 2026-10-20   1.2             Hoang            Delete m_vlsit_wdt_apb.sv + 
//                                               m_vlsit_wdt_cdc.sv. 
//                                               m_vlsit_wdt_csr.sv now contains
//                                               APB slave + async CSR
// 2026-11-07   1.3             Hoang            CNT_EN (counter enable) split
//                                               from INTEN; RESDIV drives the
//                                               reset pulse length
//------------------------------------------------------------------------------

module m_vlsit_wdt_top #(
    parameter int PARA_APB_ADDR_WIDTH = 16,     // fixed by the generated CSR
    parameter int PARA_APB_DATA_WIDTH = 32,     // fixed by the generated CSR
    parameter int PARA_WD_DATA_WIDTH  = 32,
    parameter int PARA_RESDIV_WIDTH   = 4
) (
    //------------------------ APB4 interface ----------------------------
    input  logic                           i_clk_apb,
    input  logic                           i_rst_n_apb,
    input  logic                           i_psel,
    input  logic                           i_penable,
    input  logic [PARA_APB_ADDR_WIDTH-1:0] i_paddr,
    input  logic                           i_pwrite,
    input  logic [PARA_APB_DATA_WIDTH-1:0] i_pwdata,
    output logic [PARA_APB_DATA_WIDTH-1:0] o_prdata,
    output logic                           o_pready,
    output logic                           o_pslverr,
    // THIS APB4 INTERFACE IMPLEMENTS FULL STROBE

    //------------------------ CSR & Core ----------------------------
    input  logic                           i_clk_wdog,
    input  logic                           i_rst_n_wdog,
    input  logic 		   	               i_unlock,
    output logic                           o_int_wdog,
    output logic                           o_wdogres
);

    //---------------------------------------------------------------
    // INTERCONNECT
    //---------------------------------------------------------------

    // APB bus / APB Interface <-> CDC <-> CSR
    logic		  	    w_apb_err;
    // Requests from APB -> core
    logic 			    w_ld_write;
    logic 			    w_int_clr;

    // CSR <-> core
    logic 			   w_timeout_seen, w_cnt_en, w_inten, w_resen;
    logic [PARA_WD_DATA_WIDTH-1:0] w_cnt_val, w_ld_val;
    logic [PARA_RESDIV_WIDTH-1:0]  w_resdiv;   // RESDIV: reset pulse length
    logic 			   w_dbgen;   

    //---------------------------------------------------------------
    // APB ERROR ASSERTION
    //---------------------------------------------------------------
    m_vlsit_wdt_apb_err u_vlsit_wdt_apb_err (
        .i_paddr            (i_paddr),
        .i_pwrite           (i_pwrite),
        .i_pwdata           (i_pwdata),
        .o_err              (w_apb_err)
    );

    //---------------------------------------------------------------
    // APB SLAVE + ASYNC CSR
    //---------------------------------------------------------------
    m_vlsit_wdt_csr u_vlsit_wdt_csr (
        .i_bus_clk                      (i_clk_apb),
        .i_bus_rstn                     (i_rst_n_apb),
        .i_reg_clk                      (i_clk_wdog),
        .i_reg_rstn                     (i_rst_n_wdog),
        .i_version_major                (16'h1),
        .i_version_minor                (16'h0),
        .i_paddr                        (i_paddr),
        .i_protect_en                   (1'b1),
        .i_slverr_en                    (1'b1),
        .i_pprot                        ({1'b0, w_apb_err, 1'b0}),
        .i_pwdata                       (i_pwdata),
        .i_pwrite                       (i_pwrite),   
        .i_penable                      (i_penable),
        .i_psel                         (i_psel),
        .i_pstrb                        (4'hF),
        .i_unlock                       (i_unlock),
	.i_wd_int_raw_stat_timeout_seen (w_timeout_seen),
	.i_wd_int_mask_stat_wdogmis	(w_timeout_seen & w_inten),
	.i_wd_dbg_stat_dbg_stat		(w_dbgen),
	.i_wd_cnt_val_cnt_val 		(w_cnt_val),
	.o_wd_cnt_ld_ld_val		(w_ld_val),
	.o_wd_cnt_ctrl_resdiv 		(w_resdiv),
	.o_wd_cnt_ctrl_dbgen		(w_dbgen),
	.o_wd_cnt_ctrl_cnt_en		(w_cnt_en),
  	.o_wd_cnt_ctrl_inten		(w_inten),
  	.o_wd_cnt_ctrl_resen		(w_resen),
        .o_pslverr                      (o_pslverr),
        .o_pready                       (o_pready),
        .o_prdata                       (o_prdata),
        .o_ld_write                     (w_ld_write),
        .o_int_clr                      (w_int_clr)
    );


    //---------------------------------------------------------------
    // WATCHDOG CORE
    //---------------------------------------------------------------

    m_vlsit_wdt_core #(
        .PARA_WD_DATA_WIDTH (PARA_WD_DATA_WIDTH),
        .PARA_RESDIV_WIDTH  (PARA_RESDIV_WIDTH)
    ) u_vlsit_wdt_core (
        .i_clk_wdog     (i_clk_wdog),
        .i_rst_n_wdog   (i_rst_n_wdog),
        .i_ld_write     (w_ld_write),
        .i_int_clr      (w_int_clr),
        .i_halt         (w_dbgen),
        .i_load_val     (w_ld_val),
	.i_cnt_en       (w_cnt_en),
	.i_inten        (w_inten),
	.i_resen  	(w_resen),
	.i_resdiv       (w_resdiv),
        .o_cnt_val      (w_cnt_val),
	.o_timeout_seen (w_timeout_seen),
	.o_int_wdog     (o_int_wdog),
	.o_wdogres	(o_wdogres)
    );

endmodule: m_vlsit_wdt_top
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------