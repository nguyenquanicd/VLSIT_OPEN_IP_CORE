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
// Created Date    : 2026-11-10
// Description     :
//     - APB ERROR ASSERTION CONDITIONS:
//     + out-of-range address.
//     + misaligned address.
//     + reserved resdiv values 
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version         Author           Description
// 2026-11-10   1.0             Hoang            Initial creation
//------------------------------------------------------------------------------

module m_vlsit_wdt_apb_err #(
    parameter int PARA_APB_ADDR_WIDTH = 16,
    parameter int PARA_APB_DATA_WIDTH = 32,
    parameter int PARA_RESDIV_MAX     = 8      // 2^8 = 256, matches rst_pulse counter
) (
    input  logic [PARA_APB_ADDR_WIDTH-1:0] i_paddr,
    input  logic                           i_pwrite,
    input  logic [PARA_APB_DATA_WIDTH-1:0] i_pwdata,
    output logic                           o_err
);
    logic w_misalign, w_out_of_range, w_resdiv_rsvd;

    assign w_misalign     = |i_paddr[1:0];
    assign w_out_of_range = (i_paddr != 16'h0000) &
                            ((i_paddr < 16'h1004) | (i_paddr > 16'h101C));
    assign w_resdiv_rsvd  = i_pwrite & (i_paddr == 16'h100C) &
                            (i_pwdata[7:4] > PARA_RESDIV_MAX);

    assign o_err       = w_misalign | w_out_of_range | w_resdiv_rsvd;
endmodule
//-----------------------------------------------------------------
// EOFNEWLINE
//-----------------------------------------------------------------