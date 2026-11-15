//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Danhht3
// Created Date    : 2026-10-15
// Description     : A 2-stage rising-edge data synchronizer with active-low asynchronous reset.
//
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author        Description
// 2026-10-15   1.0        Danhht3       Initial common standard-cell wrapper.
//
// This section is not intended for routine updates or minor design changes.
// A new version is strictly reserved for major architectural shifts
// that require software modifications across different chip generations.
//------------------------------------------------------------------------------
module m_vlsit_lib_sync_rising_edge_async_reset_n (
    input  logic i_clk,
    input  logic i_async_reset_n,
    input  logic i_async,
    output logic o_sync
);
    logic sync_q;

    m_vlsit_lib_dff_rising_edge_async_reset_n u_sync_0 (
        .i_clk     (i_clk),
        .i_d       (i_async),
        .i_reset_n (i_async_reset_n),
        .o_q       (sync_q)
    );

    m_vlsit_lib_dff_rising_edge_async_reset_n u_sync_1 (
        .i_clk     (i_clk),
        .i_d       (sync_q),
        .i_reset_n (i_async_reset_n),
        .o_q       (o_sync)
    );
endmodule
