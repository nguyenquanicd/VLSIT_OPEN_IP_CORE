//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Danhht3
// Created Date    : 2026-10-15
// Description     : A rising-edge D flip-flop with active-low asynchronous reset.
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author        Description
// 2026-10-15   1.0        Danhht3       Initial common standard-cell wrapper.
// 2026-10-29   2.0        LinhHTA2      Replace Cell CSC20L.
//
// This section is not intended for routine updates or minor design changes.
// A new version is strictly reserved for major architectural shifts
// that require software modifications across different chip generations.
//------------------------------------------------------------------------------
module m_vlsit_lib_dff_rising_edge_async_reset_n (
    input  logic i_clk,
    input  logic i_d,
    input  logic i_reset_n,
    output logic o_q
);
`ifdef VLSIT_SIGNOFF
    SC7P5T_DFFRQX4_CSC20L u_dont_touch_dff_rising_edge_async_reset_n  (
        .CLK (i_clk), .D (i_d), .RESET (i_reset_n), .Q (o_q)
    );
`else
    always_ff @(posedge i_clk or negedge i_reset_n)
        if (!i_reset_n) o_q <= 1'b0;
        else            o_q <= i_d;
`endif
endmodule