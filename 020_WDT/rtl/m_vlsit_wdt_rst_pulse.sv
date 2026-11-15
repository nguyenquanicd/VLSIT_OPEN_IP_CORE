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
// Created Date    : 2026-11-07
// Description     :
//   - PROGRAMMABLE RESET PULSE LENGTH (wdogclk domain)
//   - On a reset request strobe (i_rst_set) from m_vlsit_wdt_int_rst, drives
//     o_wdogres high for 2^RESDIV wdogclk cycles:
//        RESDIV 4'b0000 - 4'b1000 : len = 1, 2, 4, ..., 256
//        RESDIV 4'b1001 - 4'b1111 : reserved, saturates to len = 256
//   - Instance inside m_vlsit_wdt_core
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-11-07   1.0             Hoang            Initial creation
//------------------------------------------------------------------------------

module m_vlsit_wdt_rst_pulse #(
    parameter int PARA_RESDIV_WIDTH  = 4
) (
    input  logic                           i_clk_wdog,
    input  logic                           i_rst_n_wdog,
    input  logic                           i_rst_set,     // one-cycle reset request strobe
    input  logic [PARA_RESDIV_WIDTH-1:0]   i_resdiv,
    output logic                           o_wdogres
);

    logic       reg_rst;
    logic [7:0] reg_len_cnt;    // remaining pulse cycles - 1
    logic [7:0] w_len_m1;       // decoded pulse length - 1

    assign w_len_m1 = (i_resdiv > PARA_RESDIV_WIDTH'(8)) ? 8'hFF
                                                         : 8'((9'd1 << i_resdiv) - 9'd1);

    always_ff @(posedge i_clk_wdog or negedge i_rst_n_wdog) begin : p_ff_len_cnt
        if      (!i_rst_n_wdog)                reg_len_cnt <= '0;
        else if (i_rst_set)                    reg_len_cnt <= w_len_m1;
        else if (reg_rst && |reg_len_cnt)      reg_len_cnt <= reg_len_cnt - 1'b1;
    end

    always_ff @(posedge i_clk_wdog or negedge i_rst_n_wdog) begin : p_ff_res
        if      (!i_rst_n_wdog)                reg_rst <= 1'b0;
        else if (i_rst_set)                    reg_rst <= 1'b1;
        else if (reg_rst && ~|reg_len_cnt)     reg_rst <= 1'b0;
    end

    assign o_wdogres = reg_rst;

endmodule: m_vlsit_wdt_rst_pulse
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------
