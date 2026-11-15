//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary 
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Chau Tran Vinh Lam
// Email           : lamctv@fpt.com
// Created Date    : 2026-11-06

// Description     : 
//    - UART IP - Start Bit Detector (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-11-06   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
module m_vlsit_start_detect (
  input  logic i_clk,
  input  logic i_rst_n,
  input  logic i_tick,       // xung oversampling (16x hoặc 8x baud)
  input  logic i_ovs_mode,   // 0: 16x, 1: 8x
  input  logic i_en,         // 1 khi RX ở IDLE hoặc START
  input  logic i_rx,         // RX đã đồng bộ 2-FF, idle = 1
  output logic o_busy,       // đang kiểm tra start bit
  output logic o_done,       // pulse 1 chu kỳ khi có kết quả
  output logic o_start_ok    // hợp lệ khi o_done = 1
);
  logic       rx_d;
  logic       check_en;
  logic [3:0] tick_cnt;
  logic [3:0] mid, smp_lo, smp_hi, dec_pt;
  logic       smp;
  logic       mv_q;
  logic       start_edge;

  assign start_edge = rx_d & ~i_rx;
  assign o_busy     = check_en;

  assign mid    = i_ovs_mode ? 4'd4 : 4'd8;
  assign smp_lo = mid - 4'd1;
  assign smp_hi = mid + 4'd1;
  assign dec_pt = mid + 4'd2;

  assign smp = check_en & i_tick & (tick_cnt >= smp_lo) & (tick_cnt <= smp_hi);

  m_vlsit_mv_filter #(
    .WIDTH_MV (2),
    .THR_OVS  (2),
    .THR_NORM (2)
  ) u_mv_start (
    .i_clk      (i_clk),
    .i_rst_n    (i_rst_n),
    .i_sample   (smp),
    .i_clear    (~check_en),
    .i_d        (~i_rx),
    .i_ovs_mode (i_ovs_mode),
    .o_q        (mv_q)
  );

  always_ff @(posedge i_clk or negedge i_rst_n) begin: START_DET
    if (!i_rst_n) begin
      rx_d       <= 1'b1;
      check_en   <= 1'b0;
      tick_cnt   <= '0;
      o_done     <= 1'b0;
      o_start_ok <= 1'b0;
    end else begin
      rx_d   <= i_rx;
      o_done <= 1'b0;

      if (!i_en) begin
        check_en <= 1'b0;                    // hủy khi RX đã rời IDLE/START
      end else if (!check_en) begin
        if (start_edge) begin
          check_en <= 1'b1;
          tick_cnt <= '0;
        end
      end else if (i_tick) begin
        tick_cnt <= tick_cnt + 1'b1;
        if (tick_cnt == dec_pt) begin
          check_en   <= 1'b0;
          o_done     <= 1'b1;
          o_start_ok <= mv_q;
        end
      end
    end
  end
endmodule