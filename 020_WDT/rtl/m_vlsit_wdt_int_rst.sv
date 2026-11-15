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
// Created Date    : 2026-10-10
// Description     :
//   - INTERRUPT AND RESET GENERATION LOGIC (wdogclk domain)
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-10-10   1.0             Hoang            Initial creation
// 2026-10-15   1.1             Hoang            Instance inside m_vlsit_wdt_core
// 2026-11-07   1.2             Hoang            Timeout/reset logic enabled by
//                                               i_cnt_en; i_inten gates the
//                                               interrupt only. o_wdogres replaced
//                                               by o_rst_set strobe, pulse is
//                                               generated in m_vlsit_wdt_rst_pulse
//------------------------------------------------------------------------------

module m_vlsit_wdt_int_rst #(
    parameter int PARA_WD_DATA_WIDTH  = 32
) (

    //-------------------- Watchdog clock, reset, interrupt, reset signals ----------------
    //input  logic                           wdogclken,
    input  logic                           i_clk_wdog,
    input  logic                           i_rst_n_wdog,
    output logic                           o_int_wdog,
    output logic                           o_rst_set,

    //-------------------- Counter port ---------------------------------------------------
    input  logic [PARA_WD_DATA_WIDTH-1:0]  i_cnt_val,

    //-------------------- CSR ports (synchronized) ---------------------------------------
    input  logic                           i_ld_write,
    input  logic                           i_int_clr,
    input  logic                           i_halt,
    input  logic                           i_cnt_en,
    input  logic                           i_inten,
    input  logic                           i_resen,
    output logic                           o_timeout_seen,
    output logic                           o_cnt_stop

);

    logic reg_timeout_seen, reg_rst, reg_int, w_rst_set, w_ld_write, w_int_clr, w_cnt_en, w_inten, w_resen, w_halt, w_timeout, w_second_timeout, w_int_gen;

    //---------------------------------------------------------------
    // INTERRUPT & RESET GENERATOR
    //---------------------------------------------------------------

    assign w_ld_write    = i_ld_write;
    assign w_int_clr     = i_int_clr;
    assign w_halt        = i_halt;
    assign w_cnt_en      = i_cnt_en;
    assign w_inten       = i_inten;
    assign w_resen       = i_resen;
    assign w_rst_set     = w_resen & w_cnt_en & ~w_halt & w_second_timeout & ~w_ld_write & ~w_int_clr;

    assign w_timeout        = ~|i_cnt_val;
    assign w_second_timeout = w_timeout & reg_timeout_seen;
    assign w_int_gen        = (w_second_timeout) ? 1'b1 : reg_timeout_seen;

    always_ff @(posedge i_clk_wdog or negedge i_rst_n_wdog) begin : p_ff_res
        if      (!i_rst_n_wdog) reg_rst <= 1'b0;
        else if (w_rst_set)     reg_rst <= 1'b1;
    end

    always_ff @(posedge i_clk_wdog or negedge i_rst_n_wdog) begin : p_ff_int
        if      (!i_rst_n_wdog)  reg_int <= 1'b0;
        else                     reg_int <= w_int_gen & w_inten;
    end

    assign o_rst_set      = w_rst_set & ~reg_rst; //one-cycle reset request strobe
    assign o_int_wdog     = reg_int;
    assign o_timeout_seen = reg_timeout_seen;
    assign o_cnt_stop = w_rst_set | reg_rst; //freeze the counter upon reset request

    always_ff @(posedge i_clk_wdog or negedge i_rst_n_wdog) begin : p_ff_timeout_seen
        if      (!i_rst_n_wdog)                         reg_timeout_seen <= 1'b0;
        else if (w_ld_write | w_int_clr | ~w_cnt_en)    reg_timeout_seen <= 1'b0;
        else if (w_cnt_en & ~w_halt & w_timeout)        reg_timeout_seen <= 1'b1;
    end


endmodule: m_vlsit_wdt_int_rst
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------