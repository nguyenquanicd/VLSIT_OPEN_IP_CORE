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

// Description     : 
//    - UART IP - Transmitter (Project FU3).
//    - Integrates with the FU3 SoC architecture (32-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Date         Version    Author                 Description
// 2026-09-26   1.0        Chau Tran Vinh Lam   Initial creation.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_uart_transmitter (
  input  logic        i_clk,               
  input  logic        i_rst_n,               
  input  logic        i_tx_clk,           
  input  logic        i_tx_start,          
  input  logic        i_tx_clear,              
  input  logic [1:0]  i_wls,                
  input  logic        i_stb,             
  input  logic        i_pen,                     
  input  logic        i_eps,          
  input  logic        i_sp,                      
  input  logic        i_bc,                         
  input  logic [7:0]  i_tx_data,             
  output logic        o_tx_out,                    
  output logic        o_tx_finished            
);
//==================FSM_DECLARATION============================================
  typedef enum logic [3:0] {
    IDLE  = 4'd0,
    START = 4'd1,
    BIT0  = 4'd2,
    BIT1  = 4'd3,
    BIT2  = 4'd4,
    BIT3  = 4'd5,
    BIT4  = 4'd6,
    BIT5  = 4'd7,
    BIT6  = 4'd8,
    BIT7  = 4'd9,
    PAR   = 4'd10,
    STOP  = 4'd11,
    STOP2 = 4'd12
  } state_t_tx;
  state_t_tx c_state, n_state;
//==================DECLARATION===========================================================
  logic       iTx2;        // Two TX clocks per step
  logic       iSout;       // Internal transmitter output
  logic       iParity;     // Parity calculation result
  logic       iFinished;   // TX finished flag
  logic       iLast;       // Register to track last stop state
  logic       start_pending;

//========================Transmitter FSM Update Process==================================
  // always_ff @(posedge i_clk) begin : UART_TX_STATE_REG
  //   if (!i_rst_n) begin
  //     c_state <= IDLE;
  //   end else begin
  //     // if (c_state == IDLE && i_tx_start) begin
  //     //   c_state <= n_state; 
  //     // end else 
  //     if (i_tx_clk && iTx2 && c_state == IDLE) begin
  //       c_state <= n_state;
  //     end
  //   end
  // end
/* LamCTV - 16/10/26: Change the moment capturing the i_tx_start.
                      because i_tx_start asserted from UART Top, so it is not synchronize to UART Tx
                      the solution is force the i_tx_start to wait for i_tx_clk
                      */
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      c_state       <= IDLE;
      start_pending <= 1'b0;
    end else begin
      if (c_state == IDLE) begin
        if (i_tx_clk && (start_pending || i_tx_start)) begin
          c_state      <= START;
          start_pending <= 1'b0;
        end else if (i_tx_start) begin
          start_pending <= 1'b1;
        end
      end else if (i_tx_clk && iTx2) begin
        c_state <= n_state;
      end
    end
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin: TX_PROC
    if (!i_rst_n) begin
      iTx2 <= 1'b0;
    end else begin
      if (c_state == IDLE) begin 
        iTx2 <= 1'b0;
      end else if (i_tx_clk) begin
        if (!iTx2) begin
          iTx2 <= 1'b1;
          // LamCTV - 21/10/26:
          // In 5-bit mode with i_stb=1, keep iTx2 high on the STOP -> STOP2 transition
          // STOP2 is entered with iTx2=1 and exits on the next i_tx_clk pulse, giving STOP=1 bit and STOP2=0.5 bit.
          // At that pulse, the FSM enters START if i_tx_start is high; otherwise, it enters IDLE.
        end else if ((i_wls == 2'b00) && i_stb && (c_state == STOP)) begin
          iTx2 <= 1'b1;
        end else begin
          iTx2 <= 1'b0;
        end
      end
    end
  end
//=============Transmitter FSM Next-State & Output Logic=====================
  always_comb begin
    n_state  = IDLE;
    iSout = 1'b1;
    case (c_state)
      IDLE: begin
        if (i_tx_start) n_state = START;
      end
      START: begin
        iSout = 1'b0;
        n_state  = BIT0;
      end
      BIT0: begin
        iSout = i_tx_data[0];
        n_state  = BIT1;
      end
      BIT1: begin
        iSout = i_tx_data[1];
        n_state  = BIT2;
      end
      BIT2: begin
        iSout = i_tx_data[2];
        n_state  = BIT3;
      end
      BIT3: begin
        iSout = i_tx_data[3];
        n_state  = BIT4;
      end
      BIT4: begin
        iSout = i_tx_data[4];
        if (i_wls == 2'b00) begin // 5 bits
          if (i_pen) n_state = PAR;
          else       n_state = STOP;
        end else begin
          n_state = BIT5;
        end
      end
      BIT5: begin
        iSout = i_tx_data[5];
        if (i_wls == 2'b01) begin // 6 bits
          if (i_pen) n_state = PAR;
          else       n_state = STOP;
        end else begin
          n_state = BIT6;
        end
      end
      BIT6: begin
        iSout = i_tx_data[6];
        if (i_wls == 2'b10) begin // 7 bits
          if (i_pen) n_state = PAR;
          else n_state = STOP;
        end else begin
          n_state = BIT7;
        end
      end
      BIT7: begin
        iSout = i_tx_data[7];
        if (i_pen) n_state = PAR;
        else       n_state = STOP;
      end
      PAR: begin
        if (i_sp) begin // Sticky parity
          if (i_eps) iSout = 1'b0; // Even parity -> cleared
          else       iSout = 1'b1; // Odd parity -> set
        end else begin
            if (i_eps) iSout = iParity;     // Even parity
            else       iSout = ~iParity;    // Odd parity
        end
        n_state = STOP;
      end
      STOP: begin
        if (i_stb) n_state = STOP2; // 2 stop bits
        else begin
          if (i_tx_start) n_state = START;
          else            n_state = IDLE;
        end
      end
      STOP2: begin
        if (i_tx_start) n_state = START;
      end
      default: begin
        n_state  = IDLE;
        iSout    = 1'b1;
      end
    endcase
  end
//=======================Parity Generation=================================================
  always_comb begin
    logic iP40, iP50, iP60, iP70;
    iP40 = i_tx_data[4] ^ i_tx_data[3] ^ i_tx_data[2] ^ i_tx_data[1] ^ i_tx_data[0];
    iP50 = i_tx_data[5] ^ iP40;
    iP60 = i_tx_data[6] ^ iP50;
    iP70 = i_tx_data[7] ^ iP60;
    case (i_wls)
      2'b00:   iParity = iP40;
      2'b01:   iParity = iP50;
      2'b10:   iParity = iP60;
      default: iParity = iP70;
    endcase
  end
//==================Signal TX Finished on STOP Bit Transmission==============================
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      iFinished <= 1'b0;
      iLast     <= 1'b0;
    end else if (i_tx_clear) begin
      iLast     <= 1'b0;
      iFinished <= 1'b0;
    end else begin
      // iFinished <= 1'b0;
      if (!iLast && (c_state == STOP)) iFinished <= 1'b1;
      // LamCTV: 2026-09-26 - Fix bug: iFinished should be cleared when not in STOP state
      else                             iFinished <= 1'b0;
      if (c_state == STOP)             iLast <= 1'b1;
      else                             iLast <= 1'b0;
    end
  end
  assign o_tx_finished = iFinished;
  assign o_tx_out      = (i_bc) ? 1'b0 : iSout;
endmodule
