//------------------------------------------------------------------------------
// Copyright (c) 2026 FPT Telecom. All rights reserved.
//
// This RTL source code and the associated design are the proprietary 
// and confidential information of FPT Telecom.
// Any unauthorized use, reproduction, or disclosure is strictly prohibited.
//------------------------------------------------------------------------------
// Author          : Chau Tran Vinh Lam
// Email           : lamctv@fpt.com
// Created Date    : 2026-09-26
// Update Date     : 2026-11-11

// Description     : 
//    - UART IP - Receiver (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author               Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
// 2026-11-04   1.0        Chau Tran Vinh Lam   Configured Oversampling
// 2026-11-11   2.2        Chau Tran Vinh Lam   Rephase RX timing on RXD edges
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_uart_receiver (
  input  logic        i_clk,
  input  logic        i_rst_n,
  input  logic        i_rx_clk,
  input  logic        i_rx_clear,
  input  logic        i_ovs_mode,
  input  logic [1:0]  i_wls,
  input  logic        i_stb,
  input  logic        i_pen,
  input  logic        i_eps,
  input  logic        i_sp,
  input  logic        i_rx_in,
  output logic        o_rx_pe,
  output logic        o_rx_bi,
  output logic        o_rx_fe,
  output logic [7:0]  o_rx_data,
  output logic        o_rx_finished
);
//=================FSM States=====================================================
  typedef enum logic [2:0] {
    IDLE  = 3'd0,
    START = 3'd1,
    DATA  = 3'd2,
    PAR   = 3'd3,
    STOP  = 3'd4,
    MWAIT = 3'd5
  } state_t_rx;
  state_t_rx c_state_rx, n_state_rx;
//===================Internal Signals===============================================
  logic [3:0] iBaudCount;         // Baud counter output
  logic       iBaudCountClear;    // Baud counter clear
  logic       iBaudStep;          // Next symbol pulse
  logic       iBaudStepD;         // Next symbol pulse delayed by one clock
  logic       iFilterClear;       // Reset input filter
  logic       iFSIN;              // Filtered SIN
  logic       iFStopBit;          // Filtered SIN for stop bit detection
  logic       iParity;            // Calculated data parity
  logic       iParityReceived;    // Captured parity bit
  logic [3:0] iDataCount;         // Data bit counter (0 to 8)
  logic       iBitTick;           // Consume a valid MV bit on overflow or RX edge
  logic       iRxResync;          // RX edge establishes a new bit time origin
  logic       iSampleWindowDone;
  logic       iSampleValid;       // MV result has not yet been consumed
  logic       iDataCountInit;     // Initialize data bit counter
  logic       iDataCountFinish;   // Data bit counter finished
  logic       iRXFinished;        // Internal rx finished flag
  logic       iFE;                // Internal frame error
  logic       iBI;                // Internal break interrupt
  logic       iNoStopReceived;    // No valid stop bit received flag
  logic [7:0] iDOUT;              // Data output register
  logic iWinOpen;
  logic i_rx_in_d;
  logic i_rx_fledge;
  logic i_rx_poedge;
  // Baudrate counter: RXCLK/16 or RXCLK/8, rephased by RX edges
  m_vlsit_counter #(
    .WIDTH_COUNTER(WIDTH_COUNTER)
  ) RX_BRC (
    .i_clk      (i_clk),
    .i_rst_n    (i_rst_n),
    .i_clear    (iBaudCountClear),
    .i_load     (1'b0),
    .i_enable   (i_rx_clk),
    .i_ovs_mode (i_ovs_mode),
    .i_down     (1'b0),
    .i_d        (4'h0),
    .o_q        (iBaudCount),
    .o_overflow (iBaudStep)
  );
  assign iWinOpen = i_ovs_mode ? ((iBaudCount >= 2) & (iBaudCount <= 5))     // oversampling 8x
                               : ((iBaudCount >= 6) & (iBaudCount <= 9));    // oversampling 16x
  // Input filter (Majority voting)
  m_vlsit_mv_filter #(
    .WIDTH_MV(WIDTH_MV)
  ) RX_MVF (
    .i_clk      (i_clk),
    .i_rst_n    (i_rst_n),
    .i_sample   (i_rx_clk & iWinOpen),
    .i_clear    (iFilterClear),
    .i_d        (i_rx_in),
    .o_q        (iFSIN)
  );
  // Input filter for the stop bit
  m_vlsit_input_filter #(
    .RST_INPUT_FILTER(RST_INPUT_FILTER),
    .SIZE_INPUT_FILTER(SIZE_INPUT_FILTER),
    .WIDTH_INPUT_FILTER(WIDTH_INPUT_FILTER)
  ) u_rx_ifsb (
    .i_clk   (i_clk),
    .i_rst_n (i_rst_n),
    .i_ce    (i_rx_clk),
    .i_d     (i_rx_in),
    .o_q     (iFStopBit)
  );
  // Delayed Baud Step & Filter Clear
  always_ff @(posedge i_clk or negedge i_rst_n) begin: RX_IFC
    if (!i_rst_n) begin
      iBaudStepD <= 1'b0;
    end else if (i_rx_clear || iBaudCountClear) begin
      iBaudStepD <= 1'b0;
    end else begin
      iBaudStepD <= iBaudStep;
    end
  end
  always_ff @(posedge i_clk or negedge i_rst_n) begin: RX_RXIN_DELAY
    if (!i_rst_n) begin
      i_rx_in_d <= 1'b1;
    end else begin
      i_rx_in_d <= i_rx_in;
    end
  end
  assign i_rx_fledge = (i_rx_in_d == 1'b1) & (i_rx_in == 1'b0);
  assign i_rx_poedge = (i_rx_in_d == 1'b0) & (i_rx_in == 1'b1);
  // Both RX edges rephase the counter, regardless of its current count.
  // IDLE already holds the counter clear; MWAIT waits for the line to recover.
  assign iRxResync = (i_rx_fledge | i_rx_poedge) & ~i_rx_clear &
                    ((c_state_rx == START) | (c_state_rx == DATA) |
                     (c_state_rx == PAR) | (c_state_rx == STOP));
  assign iFilterClear = iBaudStepD | iBaudCountClear;
  // Wait until the complete MV window has been sampled, including one clock
  // for RX_MVF to publish its registered result. A zero bit is valid too.
  // Clearing on either boundary consumes the result exactly once: an edge
  // just after overflow only rephases, without capturing the old bit again.
  always_ff @(posedge i_clk or negedge i_rst_n) begin: RX_SAMPLE_VALID
    if (!i_rst_n) begin
      iSampleWindowDone <= 1'b0;
      iSampleValid      <= 1'b0;
    end else if (iFilterClear || i_rx_clear) begin
      iSampleWindowDone <= 1'b0;
      iSampleValid      <= 1'b0;
    end else begin
      iSampleWindowDone <= i_rx_clk & (i_ovs_mode ? (iBaudCount == 4'd5)
                                                   : (iBaudCount == 4'd9));
      if (iSampleWindowDone) begin
        iSampleValid <= 1'b1;
      end
    end
  end
  // Capture the PRE-clear MV value on the same clock that clears the filter.
  // Suppress completion for edges before a valid sample window is available.
  assign iBitTick = iSampleValid & (iBaudStepD | iRxResync) & ~i_rx_clear;
  // Parity Generation (Combinational)
  always_comb begin: RX_PAR
    iParity = iDOUT[7] ^ iDOUT[6] ^ iDOUT[5] ^ iDOUT[4] ^ 
              iDOUT[3] ^ iDOUT[2] ^ iDOUT[1] ^ iDOUT[0] ^ (~i_eps);
  end
  // Data Bit Capture
  always_ff @(posedge i_clk or negedge i_rst_n) begin: RX_DATACOUNT
    if (!i_rst_n) begin
      iDataCount <= '0;
      iDOUT      <= '0;
    end else begin
      if (iDataCountInit) begin
        iDataCount <= '0;
        iDOUT      <= '0;
      end else begin
        if ((c_state_rx == DATA) && iBitTick && !iDataCountFinish) begin
          iDOUT[iDataCount] <= iFSIN;
          iDataCount        <= iDataCount + 1'b1;
        end
      end
    end
  end
  always_comb begin
    if ((i_wls == 2'b00 && iDataCount == 4'd5) ||
        (i_wls == 2'b01 && iDataCount == 4'd6) ||
        (i_wls == 2'b10 && iDataCount == 4'd7) ||
        (i_wls == 2'b11 && iDataCount == 4'd8)) begin
        iDataCountFinish = 1'b1;
    end else begin
        iDataCountFinish = 1'b0;
    end
  end
  // FSM Update Process
  always_ff @(posedge i_clk or negedge i_rst_n) begin: RX_FSMUPDATE
    if (!i_rst_n) begin
      c_state_rx <= IDLE;
    end else begin
      c_state_rx <= n_state_rx;
    end
  end
  // RX FSM Next-State Logic
  always_comb begin
    n_state_rx      = IDLE;
    iBaudCountClear = iRxResync;
    iDataCountInit  = 1'b0;
    iRXFinished     = 1'b0;
    case (c_state_rx)
      IDLE: begin
        if (i_rx_in == 1'b0) n_state_rx = START; // Start detected
        iBaudCountClear = 1'b1;
        iDataCountInit  = 1'b1;
      end
      START: begin
        iDataCountInit = 1'b1;
        if (iBitTick) begin
            if (iFSIN == 1'b0) begin
              n_state_rx = DATA;
            end else begin
              n_state_rx = IDLE;
            end 
        end else begin
            n_state_rx = START;
        end
      end
      DATA: begin
        if (iDataCountFinish) begin
          if (i_pen)  n_state_rx = PAR;  // Parity enabled
          else        n_state_rx = STOP; // No parity
        end else begin
          n_state_rx = DATA;
        end
      end
      PAR: begin
        if (iBitTick) n_state_rx = STOP;
        else n_state_rx = PAR;
      end
      STOP: begin
        if(i_ovs_mode) begin
          if (iBaudCount[2]) begin // Wait for stop bit (iBaudCount >= 4)
              if (iFStopBit == 1'b0) begin
                  iRXFinished = 1'b1;
                  n_state_rx = MWAIT;
              end else begin
                  iRXFinished = 1'b1;
                  n_state_rx = IDLE;
              end
          end else begin
              n_state_rx = STOP;
          end
        end else begin
          if (iBaudCount[3]) begin // Wait for stop bit (iBaudCount >= 8)
              if (iFStopBit == 1'b0) begin
                  iRXFinished = 1'b1;
                  n_state_rx = MWAIT;
              end else begin
                  iRXFinished = 1'b1;
                  n_state_rx = IDLE;
              end
          end else begin
              n_state_rx = STOP;
          end
        end
      end
      MWAIT: begin
          if (i_rx_in == 1'b0) n_state_rx = MWAIT; // Wait for mark
          else                 n_state_rx = IDLE;
      end

      default: begin
          n_state_rx = IDLE;
      end
    endcase
  end
  // Parity Check
  always_ff @(posedge i_clk or negedge i_rst_n) begin : RX_PARCHECK
    if (!i_rst_n) begin
      o_rx_pe         <= 1'b0;
      iParityReceived <= 1'b0;
    end else begin
      // iParityReceived
      if (!i_pen) begin
        iParityReceived <= 1'b0;
      end else if ((c_state_rx == PAR) && iBitTick) begin
        iParityReceived <= iFSIN;
      end
      // o_rx_pe
      if (i_pen) begin
        if (i_sp) begin
          o_rx_pe <= ((i_eps ^ iParityReceived) == 1'b0);  // Sticky parity
        end else begin
          o_rx_pe <= (iParity != iParityReceived);
        end
      end else begin
        o_rx_pe <= 1'b0;
      end
    end
  end
  // Framing Error and Break Interrupt Detection
  assign iNoStopReceived = (~iFStopBit & (c_state_rx == STOP));
  assign iBI             = ((iDOUT == 8'd0) && !iParityReceived && iNoStopReceived) ? 1'b1 : 1'b0;
  assign iFE             = iNoStopReceived;
  // Continuous Assignments for Outputs
  assign o_rx_data       = iDOUT;
  assign o_rx_bi         = iBI;
  assign o_rx_fe         = iFE;
  assign o_rx_finished   = iRXFinished;
endmodule
