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
//   - WATCHDOG COUNTER (wdogclk domain)
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-10-10   1.0             Hoang            Initial creation
// 2026-10-15   1.1             Hoang            Added i_cnt_stop: counter is
//                                               halted when interrupt occurs.
//                                               Instance inside m_vlsit_wdt_core
// 2026-11-07   1.4             Hoang            Counter enabled by i_cnt_en
//                                               (CNT_EN) instead of i_inten
//------------------------------------------------------------------------------

module m_vlsit_wdt_counter #(
    parameter int PARA_WD_DATA_WIDTH  = 32
) (

    //-------------------- Watchdog clk & rst ----------------
    //input  logic                         wdogclken,
    input  logic                           i_clk_wdog,
    input  logic                           i_rst_n_wdog,

    //------------------------CSR ports (synchronized) -------
    input  logic                           i_cnt_en,
    input  logic                           i_ld_write,
    input  logic                           i_int_clr,
    input  logic                           i_halt,
    input  logic                           i_cnt_stop, 
    input  logic [PARA_WD_DATA_WIDTH-1:0]  i_load_val,
    output logic [PARA_WD_DATA_WIDTH-1:0]  o_cnt_val

);
    logic [PARA_WD_DATA_WIDTH-1:0] w_load_val, reg_count, w_count_pre;
    logic w_cnt_disable, w_ld_write, w_int_clr, w_halt, w_timeout, w_cnt_stop;
    //---------------------------------------------------------------
    // 32-BIT DOWN COUNTER
    //---------------------------------------------------------------

    // counter has the following states:
    // - reset
    // - disabled through CNT_EN bit
    // - enabled through CNT_EN bit
    // - halt in debug mode through DBGEN Bit
    // - decrement from loaded value again after first timeout
    // - decrement from loaded value again after interrupt clear
    // - decrement from newly loaded value
    // - normal decrementing
    assign w_load_val    =  i_load_val;
    assign w_cnt_disable = ~i_cnt_en;
    assign w_ld_write    =  i_ld_write;
    assign w_int_clr     =  i_int_clr;
    assign w_halt        =  i_halt;
    assign w_timeout     = ~|reg_count;
    assign w_cnt_stop    =  i_cnt_stop;
    always_comb begin : p_com_count_pre
        w_count_pre = reg_count;
        if      (w_cnt_stop)                w_count_pre = reg_count;
        else if (w_cnt_disable)             w_count_pre = w_load_val;
        else if (w_ld_write)                w_count_pre = w_load_val;
        else if (w_int_clr)                 w_count_pre = w_load_val;
        else if (w_halt)                    w_count_pre = reg_count;
        else if (w_timeout)                 w_count_pre = w_load_val;
        else                                w_count_pre = reg_count - 1'b1;
    end
    always_ff @(posedge i_clk_wdog or negedge i_rst_n_wdog) begin : p_ff_count
        if      (!i_rst_n_wdog)   reg_count <= '1;
        else                      reg_count <= w_count_pre;
    end
    assign o_cnt_val = reg_count;

endmodule: m_vlsit_wdt_counter
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------