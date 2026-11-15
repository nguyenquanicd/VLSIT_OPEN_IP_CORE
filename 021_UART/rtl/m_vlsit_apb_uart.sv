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
//    - UART IP TOP MODULE (Project FU3).
//    - Integrates with the FU3 SoC architecture (16-bit APB Bus).
// Evolution History:
// -----------------------------------------------------------------------------
// Update Date   Version   Author   Description
// 2026-09-26     1.0      LamCTV   Initial creation.
// 2026-10-26     2.2      LamCTV   Update CSR for Oversampling configuration.
//------------------------------------------------------------------------------
import m_vlsit_uart_package::*;
module m_vlsit_apb_uart (
    //-------------System_Signal-------------
    input  logic        PCLK,
    input  logic        RSTN,
    //----------APB3 Interface--------------
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [2:0]  PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,
    output logic        INT,
    //---------------Modem Signal-------------
    input  logic        CTSN,
    input  logic        DCDN,
    input  logic        DSRN,
    input  logic        RIN,
    output logic        RTSN,
    output logic        DTRN,
    output logic        OUT1N,
    output logic        OUT2N,
    //---------------UART Signal-------------
    input  logic        RXD,
    output logic        TXD,
    //---------------DMA Interface-------------
    /* LamCTV: Add DMA interface for UART */
    input  logic        i_uart_dma_tx_clr,
    output logic        o_uart_dma_tx_req,
    input  logic        i_uart_dma_rx_clr,
    output logic        o_uart_dma_rx_req
);
//==============================DECLARATION====================
  //-------------TYPEDEF---------------------------------------
  typedef enum logic [1:0] { TXIDLE = 2'b00, TXSTART = 2'b01, TXRUN = 2'b10, TXEND = 2'b11 } tx_state_e;
  tx_state_e state, next_state;
  typedef enum logic { RXIDLE = 1'b0, RXSAVE = 1'b1 } rx_state_e;
  rx_state_e rx_state;
  rx_state_e next_state_var;
  rx_state_e next_state_comb;
  logic      iRXFIFOWrite_nxt;
  logic      iRXFIFOClear_nxt;
  logic      iRXFIFOD_load;
  //-------------Global device signals//-----------------------
  logic       iWrite;                                          // Write to UART
  logic       iRead;                                           // Read from UART
  //------------UART registers read/write signals--------------
  logic       iRBRRead;                                        // Read from RBR
  logic       iTHRWrite;                                       // Write to THR
  logic       iDLLWrite;                                       // Write to DLL
  logic       iDLMWrite;                                       // Write to DLM
  logic       iIERWrite;                                       // Write to IER
  logic       iIIRRead;                                        // Read from IIR
  logic       iFCRWrite;                                       // Write to FCR
  logic       iLCRWrite;                                       // Write to LCR
  logic       iMCRWrite;                                       // Write to MCR
  logic       iLSRRead;                                        // Read from LSR
  logic       iMSRRead;                                        // Read from MSR
  logic       iSCRWrite;                                       // Write to SCR
  logic       iCFRWrite;                                       // Write to CFR
  //-------------UART registers--------------------------------
  logic [7:0] iTSR;                                            // Transmitter holding register
  logic [7:0] iRBR;                                            // Receiver buffer register
  logic [7:0] iDLL;                                            // Divisor latch LSB
  logic [7:0] iDLM;                                            // Divisor latch MSB
  logic [7:0] iIER;                                            // Interrupt enable register
  logic [7:0] iIIR;                                            // Interrupt identification register
  logic [7:0] iFCR;                                            // FIFO control register
  logic [7:0] iLCR;                                            // Line control register
  logic [7:0] iMCR;                                            // Modem control register
  logic [7:0] iLSR;                                            // Line status register
  logic [7:0] iMSR;                                            // Modem status register
  logic [7:0] iSCR;                                            // Scratch register
  logic [7:0] iCFR;                                            // Configuration register
  //-------------IER register signals--------------------------
  // logic        iIER_ERBI;                                       // IER: Enable received data available interrupt
  // logic        iIER_ETBEI;                                      // IER: Enable transmitter holding register empty interrupt
  // logic        iIER_ELSI;                                       // IER: Enable receiver line status interrupt
  // logic        iIER_EDSSI;                                      // IER: Enable modem status interrupt
  //-------------IIR register signals--------------------------
  // logic        iIIR_PI;                                         // IIR: Pending interrupt
  // logic        iIIR_ID0;                                        // IIR: Interrupt ID0
  // logic        iIIR_ID1;                                        // IIR: Interrupt ID1
  // logic        iIIR_ID2;                                        // IIR: Interrupt ID2
  // logic        iIIR_FIFO64;                                     // IIR: 64 byte FIFO enabled
  //-------------FCR register signals--------------------------
  logic        iFCR_FIFOEnable;                                 // FCR: FIFO enable
  logic        iFCR_RXFIFOReset;                                // FCR: Receiver FIFO reset
  logic        iFCR_TXFIFOReset;                                // FCR: Transmitter FIFO reset
  logic        iFCR_DMAMode;                                    // FCR: DMA mode select
  logic        iFCR_FIFO64E;                                    // FCR: 64 byte FIFO enable
  logic [1:0]  iFCR_RXTrigger;                                  // FCR: Receiver trigger
  //-------------LCR register signals--------------------------
  logic [1:0]  iLCR_WLS;                                        // LCR: Word length select
  logic        iLCR_STB;                                        // LCR: Number of stop bits
  logic        iLCR_PEN;                                        // LCR: Parity enable
  logic        iLCR_EPS;                                        // LCR: Even parity select
  logic        iLCR_SP;                                         // LCR: Sticky parity
  logic        iLCR_BC;                                         // LCR: Break control
  logic        iLCR_DLAB;                                       // LCR: Divisor latch access bit
  //-------------MCR register signals--------------------------
  logic        iMCR_DTR;                                        // MCR: Data terminal ready
  logic        iMCR_RTS;                                        // MCR: Request to send
  logic        iMCR_OUT1;                                       // MCR: OUT1
  logic        iMCR_OUT2;                                       // MCR: OUT2
  logic        iMCR_LOOP;                                       // MCR: Loop
  logic        iMCR_AFE;                                        // MCR: Auto flow control enable
  //-------------LSR register signals--------------------------
  logic        iLSR_DR;                                         // LSR: Data ready
  logic        iLSR_OE;                                         // LSR: Overrun error
  logic        iLSR_PE;                                         // LSR: Parity error
  logic        iLSR_FE;                                         // LSR: Framing error
  logic        iLSR_BI;                                         // LSR: Break Interrupt
  logic        iLSR_THRE;                                       // LSR: Transmitter holding register empty
  logic        iLSR_THRNF;                                      // LSR: Transmitter holding register not full
  logic        iLSR_TEMT;                                       // LSR: Transmitter empty
  logic        iLSR_FIFOERR;                                    // LSR: Error in receiver FIFO
  //-------------MSR register signals--------------------------
  logic        iMSR_dCTS;                                       // MSR: Delta CTS
  logic        iMSR_dDSR;                                       // MSR: Delta DSR
  logic        iMSR_TERI;                                       // MSR: Trailing edge ring indicator
  logic        iMSR_dDCD;                                       // MSR: Delta DCD
  logic        iMSR_CTS;                                        // MSR: CTS
  logic        iMSR_DSR;                                        // MSR: DSR
  logic        iMSR_RI;                                         // MSR: RI
  logic        iMSR_DCD;                                        // MSR: DCD
  //-------------UART CFR signals------------------------------
  logic        iCFR_OVSMode;                                    // CFR: Oversampling mode 0: 16x, 1: 8x
  // logic        iCFR_DataOrder;                                  // CFR: Data order Mode 0: LSB first, 1: MSB first
  //-------------UART MSR signals------------------------------
  logic        iCTSNs;                                          // Synchronized CTSN input
  logic        iDSRNs;                                          // Synchronized DSRN input
  logic        iDCDNs;                                          // Synchronized DCDN input
  logic        iRINs;                                           // Synchronized RIN input
  logic        iCTSn;                                           // Filtered CTSN input
  logic        iDSRn;                                           // Filtered DSRN input
  logic        iDCDn;                                           // Filtered DCDN input
  logic        iRIn;                                            // Filtered RIN input
  logic        iCTSnRE;                                         // CTSn rising edge
  logic        iCTSnFE;                                         // CTSn falling edge
  logic        iDSRnRE;                                         // DSRn rising edge
  logic        iDSRnFE;                                         // DSRn falling edge
  logic        iDCDnRE;                                         // DCDn rising edge
  logic        iDCDnFE;                                         // DCDn falling edge
  logic        iRInRE;                                          // RIn rising edge
  logic        iRInFE;                                          // RIn falling edge
  //-------------UART baudrate generation signals--------------
  logic [15:0] iBaudgenDiv;                                     // Baudivider
  logic        iBaudrate;                                    // 16x Baudrate output from baudrate generator
  logic        iBaudtick2x;                                     // 2x Baudrate for transmitter
  logic        iRCLK;                                           // 16x Baudrate for receiver
  //-------------UART FIFO signl------------------------
  logic        iTXFIFOClear;                                    // Clear TX FIFO
  logic        iTXFIFOWrite;                                    // Write to TX FIFO
  logic        iTXFIFORead;                                     // Read from TX FIFO
  logic        iTXFIFOEmpty;                                    // TX FIFO is empty
  logic        iTXFIFOFull;                                     // TX FIFO is full
  logic        iTXFIFO16Full;                                   // TX FIFO 16 byte mode is full
  logic        iTXFIFO64Full;                                   // TX FIFO 64 byte mode is full
  logic [5:0]  iTXFIFOUsage;                                    // TX FIFO usage
  logic [7:0]  iTXFIFOQ;                                        // TX FIFO output
  logic        iRXFIFOClear;
  logic        iRXFIFOWrite;                                    // Write to RX FIFO
  logic        iRXFIFORead;                                     // Read from RX FIFO
  logic        iRXFIFOEmpty;                                    // RX FIFO is empty
  logic        iRXFIFOFull;                                     // RX FIFO is full
  logic        iRXFIFO16Full;                                   // RX FIFO 16 byte mode is full
  logic        iRXFIFO64Full;                                   // RX FIFO 64 byte mode is full
  logic [10:0] iRXFIFOD;                                        // RX FIFO input
  logic [10:0] iRXFIFOQ;                                        // RX FIFO output
  logic [5:0]  iRXFIFOUsage;                                    // RX FIFO usage
  logic        iRXFIFOTrigger;                                  // FIFO trigger level reached
  logic        iRXFIFO16Trigger;                                // FIFO 16 byte mode trigger level reached
  logic        iRXFIFO64Trigger;                                // FIFO 64 byte mode trigger level reached
  logic        iRXFIFOPE;                                       // Parity error from FIFO
  logic        iRXFIFOFE;                                       // Frame error from FIFO
  logic        iRXFIFOBI;                                       // Break interrupt from FIFO
  //------------UART transmitter signals-----------------------
  logic        iSOUT;                                           // Transmitter output
  logic        iTXStart;                                        // Start transmitter
  logic        iTXClear;                                        // Clear transmitter status
  logic        iTXFinished;                                     // TX finished, character transmitted
  logic        iTXRunning;                                      // TX in progress
  //-------------UART receiver signals-------------------------
  logic        iSINr;                                           // Synchronized SIN input
  logic        iSIN;                                            // Receiver input
  logic        iRXFinished;                                     // RX finished, character received
  logic        iRXClear;                                        // Clear receiver status
  logic [7:0]  iRXData;                                         // RX data
  logic        iRXPE;                                           // RX parity error
  logic        iRXFE;                                           // RX frame error
  logic        iRXBI;                                           // RX break interrupt
  //-------------UART control signals--------------------------
  logic        iFERE;                                           // Frame error detected
  logic        iPERE;                                           // Parity error detected
  logic        iBIRE;                                           // Break interrupt detected
  logic [DEPTH_FIFO:0] iFECounter;                              // FIFO error counter
  logic        iFEIncrement;                                    // FIFO error counter increment
  logic        iFEDecrement;                                    // FIFO error counter decrement
  logic        iRDAInterrupt;                                   // Receiver data available interrupt (DA or FIFO trigger level)
  logic [5:0]  iTimeoutCount;                                   // Character timeout counter (FIFO mode)
  logic        iCharTimeout;                                    // Character timeout indication (FIFO mode)
  logic        iLSR_THRERE;                                     // LSR THRE rising edge for interrupt generation
  logic        iTHRInterrupt;                                   // Transmitter holding register empty interrupt
  logic        iTXEnable;                                       // Transmitter enable signal
  logic        iRTS;                                            // Internal RTS signal with/without automatic flow control
  // logic        iTXInt;                                            // Internal RTS signal with/without automatic flow control

  //----------Interrupt Control anh IIR--------------------------------
  m_vlsit_uart_interrupt UART_IIC (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_ier   (iIER[3:0]),
    .i_lsr   (iLSR[4:0]),
    .i_thi   (iTHRInterrupt),
    .i_rda   (iRDAInterrupt),
    .i_cti   (iCharTimeout),
    .i_afe   (iMCR_AFE),
    .i_msr   (iMSR[3:0]),
    .o_iir   (iIIR[3:0]),
    .o_int   (INT)
  );
//==============DMA_HANDSHAKE====================================
  /* LamCTV: Add DMA Instatiation for UART */
  m_vlsit_uart_dma_handshake UART_DMA (
    .i_uart_pclk       (PCLK),
    .i_uart_prst_n     (RSTN),
    .i_dma_mode_sl     (iFCR_DMAMode),
    .i_tx_int          (iLSR_THRNF),          // FIFO TX Empty
    .i_rx_int          (iRDAInterrupt),       // FIFO RX Empty || Fifo RX Trigger Level
    .i_uart_dma_tx_clr (i_uart_dma_tx_clr),
    .i_uart_dma_rx_clr (i_uart_dma_rx_clr),
    .o_uart_dma_tx_req (o_uart_dma_tx_req),
    .o_uart_dma_rx_req (o_uart_dma_rx_req)
  );
  //--------------------Signal Synchronizer----------------------
  // LamCTV - 16/10/26: Change the reset value of the synchronizer to 1'b1 for active low reset
  m_vlsit_input_sync #(
    .RST_INPUT_SYNC (~RST_INPUT_SYNC) // ACTIVE LOW SIGNAL
  ) UART_IS_SIN (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_d     (RXD),
    .o_q     (iSINr)
  );
  m_vlsit_input_sync #(
    .RST_INPUT_SYNC (~RST_INPUT_SYNC) // ACTIVE LOW SIGNAL
  ) UART_IS_CTS (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_d     (CTSN),
    .o_q     (iCTSNs)
  );
  m_vlsit_input_sync #(
    .RST_INPUT_SYNC (~RST_INPUT_SYNC) // ACTIVE LOW SIGNAL
  ) UART_IS_DSR (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_d     (DSRN),
    .o_q     (iDSRNs)
  );
  m_vlsit_input_sync #(
    .RST_INPUT_SYNC (~RST_INPUT_SYNC) // ACTIVE LOW SIGNAL
  ) UART_IS_DCD (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_d     (DCDN),
    .o_q     (iDCDNs)
  );
  m_vlsit_input_sync #(
    .RST_INPUT_SYNC (~RST_INPUT_SYNC) // ACTIVE LOW SIGNAL
  ) UART_IS_RI (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_d     (RIN),
    .o_q     (iRINs)
  );
  //--------------------Input Filter--------------------------------
  m_vlsit_input_filter #(
    .SIZE_INPUT_FILTER(SIZE_INPUT_FILTER),
    .WIDTH_INPUT_FILTER(WIDTH_INPUT_FILTER),
    .RST_INPUT_FILTER(~RST_INPUT_FILTER)       // ACTIVE LOW SIGNAL
  ) UART_IF_CTS (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_ce    (iBaudtick2x),
    .i_d     (iCTSNs),
    .o_q     (iCTSn)
  );
  m_vlsit_input_filter #(
    .SIZE_INPUT_FILTER(SIZE_INPUT_FILTER),
    .WIDTH_INPUT_FILTER(WIDTH_INPUT_FILTER),
    .RST_INPUT_FILTER(~RST_INPUT_FILTER)       // ACTIVE LOW SIGNAL
  ) UART_IF_DSR (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_ce    (iBaudtick2x),
    .i_d     (iDSRNs),
    .o_q     (iDSRn)
  );
  m_vlsit_input_filter #(
    .SIZE_INPUT_FILTER(SIZE_INPUT_FILTER),
    .WIDTH_INPUT_FILTER(WIDTH_INPUT_FILTER),
    .RST_INPUT_FILTER(~RST_INPUT_FILTER)       // ACTIVE LOW SIGNAL
  ) UART_IF_DCD (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_ce    (iBaudtick2x),
    .i_d     (iDCDNs),
    .o_q     (iDCDn)
  );
  m_vlsit_input_filter #(
    .SIZE_INPUT_FILTER(SIZE_INPUT_FILTER),
    .WIDTH_INPUT_FILTER(WIDTH_INPUT_FILTER),
    .RST_INPUT_FILTER(~RST_INPUT_FILTER)       // ACTIVE LOW SIGNAL
  ) UART_IF_RI (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_ce    (iBaudtick2x),
    .i_d     (iRINs),
    .o_q     (iRIn)
  );

  //========================LOGIC_CONTROL===========================
  //---------GLobal Device Signals--------------------------------
  assign iWrite = PSEL & PENABLE & PWRITE;
  assign iRead  = PSEL & PENABLE & ~PWRITE;
  // assign i_rst_n   = !i_rst_n;
  //---------UART Registers Read/Write Signals---------------------
  assign iRBRRead  = iRead  & (PADDR == 3'b000) & ~iLCR_DLAB;
  assign iTHRWrite = iWrite & (PADDR == 3'b000) & ~iLCR_DLAB;
  assign iDLLWrite = iWrite & (PADDR == 3'b000) &  iLCR_DLAB;
  assign iDLMWrite = iWrite & (PADDR == 3'b001) &  iLCR_DLAB;
  assign iIERWrite = iWrite & (PADDR == 3'b001) & ~iLCR_DLAB;
  assign iIIRRead  = iRead  & (PADDR == 3'b010) & ~iLCR_DLAB;
  assign iFCRWrite = iWrite & (PADDR == 3'b010);
  assign iLCRWrite = iWrite & (PADDR == 3'b011);
  assign iCFRWrite = iWrite & (PADDR == 3'b100) &  iLCR_DLAB;
  assign iMCRWrite = iWrite & (PADDR == 3'b100) & ~iLCR_DLAB;
  assign iLSRRead  = iRead  & (PADDR == 3'b101);
  assign iMSRRead  = iRead  & (PADDR == 3'b110); 
  assign iSCRWrite = iWrite & (PADDR == 3'b111);  
  //----------Divisor Latch Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_DLR
    if (!RSTN) begin
      iDLL <= '0;
      iDLM <= '0;
    end else begin
      if (iDLLWrite) begin
          iDLL <= PWDATA[7:0];
      end
      if (iDLMWrite) begin
          iDLM <= PWDATA[7:0];
      end
    end
  end
  //----------Configuration Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_CFR
    if (!RSTN) begin
      iCFR <= '0;
    end else begin
      if (iCFRWrite) begin
        iCFR <= PWDATA[7:0];
      end
    end
  end
  always_comb begin
    iCFR_OVSMode   = iCFR[0];
    // iCFR_DataOrder = iCFR[1];
  end
  //---------Interrupt Enable Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_IER
    if (!RSTN) begin
      iIER[7:0] <= '0;
    end else begin
      if (iIERWrite) begin
        iIER[3:0] <= PWDATA[3:0];
        iIER[7:4] <= '0;
      end
    end
  end
  //------THR Empty Interrupt----------
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_IIC_THRE_ED (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iLSR_THRE),
    .o_rising_edge  (iLSR_THRERE)
    // .o_falling_edge () //
  );
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_IIC_THREI
    if(!RSTN) begin
      iTHRInterrupt <= '0;
    end else begin
      if(iLSR_THRERE || iFCR_TXFIFOReset || (iIERWrite && PWDATA[1] && iLSR_THRE)) begin
        iTHRInterrupt <= 1'b1;         // Set on THRE, TX FIFO reset (FIFO enable) or ETBEI enable
      end else if ((iIIRRead && (iIIR[3:1] == 3'b001)) || iTHRWrite) begin
        iTHRInterrupt <= 1'b0;
      end
    end
  end
  always_comb begin
    iRDAInterrupt = (~iFCR_FIFOEnable & iLSR_DR) | (iFCR_FIFOEnable & iRXFIFOTrigger);
    //iIIR_PI       = iIIR[0];
    //iIIR_ID0      = iIIR[1];
    //iIIR_ID1      = iIIR[2];
    //iIIR_ID2      = iIIR[3];
    //iIIR_FIFO64   = iIIR[5];
    iIIR[4]       = '0;
    iIIR[5]       = iFCR_FIFOEnable ? iFCR_FIFO64E : 1'b0;
    iIIR[6]       = iFCR_FIFOEnable;
    iIIR[7]       = iFCR_FIFOEnable;
  end
  //-------Character Timeout Indication--------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_CTI
    if(!RSTN) begin
      iTimeoutCount <= '0;
      iCharTimeout  <= '0;
    end else begin
      if(iRXFIFOEmpty || iRBRRead || iRXFIFOWrite) begin
        iTimeoutCount <= 1'b0;
      end else if (!iRXFIFOEmpty && iBaudtick2x && !iTimeoutCount[5]) begin
        iTimeoutCount <= iTimeoutCount + 1;
      end
      //--------Timeout Indication----------------
      if (iFCR_FIFOEnable) begin
        if(iRBRRead) begin
          iCharTimeout <= 1'b0;
        end else if (iTimeoutCount[5]) begin
          iCharTimeout <= 1'b1;
        end else begin
          iCharTimeout <= 1'b0;
        end
      end
    end
  end
  //------------FIFO Control Register--------------------------------
always_ff @(posedge PCLK or negedge RSTN) begin : UART_FCR
  if (!RSTN) begin
    iFCR_FIFOEnable  <= '0;
    iFCR_RXFIFOReset <= '0;
    iFCR_TXFIFOReset <= '0;
    iFCR_DMAMode     <= '0;
    iFCR_FIFO64E     <= '0;
    iFCR_RXTrigger   <= '0;
  end else begin
    if (iFCRWrite) begin
      iFCR_FIFOEnable <= PWDATA[0];
      iFCR_DMAMode    <= PWDATA[3];
      iFCR_RXTrigger  <= PWDATA[7:6];
      if (iLCR_DLAB) begin
        iFCR_FIFO64E <= PWDATA[5];
      end
      if (PWDATA[1] || (iFCR_FIFOEnable != PWDATA[0])) begin
        iFCR_RXFIFOReset <= 1'b1;
      end else begin
        iFCR_RXFIFOReset <= 1'b0;
      end
      if (PWDATA[2] || (iFCR_FIFOEnable != PWDATA[0])) begin
        iFCR_TXFIFOReset <= 1'b1;
      end else begin
        iFCR_TXFIFOReset <= 1'b0;
      end 
    end else begin
      iFCR_RXFIFOReset <= 1'b0;
      iFCR_TXFIFOReset <= 1'b0;
    end
    end
  end
  always_comb begin
    iFCR[0]   = iFCR_FIFOEnable;
    iFCR[1]   = iFCR_RXFIFOReset;
    iFCR[2]   = iFCR_TXFIFOReset;
    iFCR[3]   = iFCR_DMAMode;
    iFCR[4]   = 1'b0;
    iFCR[5]   = iFCR_FIFO64E;
    iFCR[7:6] = iFCR_RXTrigger;
  end
  //-------Line Control Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_LCR
    if (!RSTN) begin
      iLCR <= '0;
    end else if (iLCRWrite) begin
      iLCR <= PWDATA[7:0];
    end
  end
  always_comb begin
    iLCR_WLS  = iLCR[1:0];
    iLCR_STB  = iLCR[2];
    iLCR_PEN  = iLCR[3];
    iLCR_EPS  = iLCR[4];
    iLCR_SP   = iLCR[5];
    iLCR_BC   = iLCR[6];
    iLCR_DLAB = iLCR[7];
  end
  //-------Modem Control Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_MCR
    if (!RSTN) begin
      iMCR[5:0] <= '0;
    end else if (iMCRWrite) begin
      iMCR[5:0] <= PWDATA[5:0];
    end
  end
  always_comb begin 
    iMCR_DTR  = iMCR[0];
    iMCR_RTS  = iMCR[1];
    iMCR_OUT1 = iMCR[2];
    iMCR_OUT2 = iMCR[3];
    iMCR_LOOP = iMCR[4];
    iMCR_AFE  = iMCR[5];
    iMCR[7:6] = '0;
  end 
  //-------Line Status Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_LSR
    if (!RSTN) begin
      iLSR_OE      <= '0;
      iLSR_PE      <= '0;
      iLSR_FE      <= '0;
      iLSR_BI      <= '0;
      iFECounter   <= '0;
    end else begin
      //----Overrun Error (OE)----------------
      if((!iFCR_FIFOEnable && iLSR_DR && iRXFinished) || (iFCR_FIFOEnable && iRXFIFOFull && iRXFinished)) begin
        iLSR_OE <= 1'b1;
      end else if (iLSRRead) begin 
        iLSR_OE <= 1'b0;
      end
      //----Parity Error (PE)-----------------
      if (iPERE) begin
        iLSR_PE <= 1'b1;
      end else if (iLSRRead) begin
        iLSR_PE <= 1'b0;
      end
      //----Frame Error (FE)------------------
      if (iFERE) begin
        iLSR_FE <= 1'b1;
      end else if (iLSRRead) begin
        iLSR_FE <= 1'b0;
      end
      //----Break Interrupt (BI)------------------
      if (iBIRE) begin 
        iLSR_BI <= 1'b1;
      end else if (iLSRRead) begin
        iLSR_BI <= 1'b0;
      end
      //----FIFO Error Counter----------------
      if(iRXFIFOClear) begin
        iFECounter <= '0;
      end else begin
        if (iFEIncrement && !iFEDecrement) begin
           iFECounter <= iFECounter + 1;
        end else if (!iFEIncrement && iFEDecrement) begin
          iFECounter <= iFECounter - 1;
        end else begin 
          iFECounter <= iFECounter;
        end
      end
    end 
  end
  assign iLSR_FIFOERR = (iFECounter != '0);
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_PEDET (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iRXFIFOPE),
    .o_rising_edge  (iPERE)
    // .o_falling_edge () // 
  );
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_FEDET (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iRXFIFOFE),
    .o_rising_edge  (iFERE)
    // .o_falling_edge ()
  );
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_BIDET (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iRXFIFOBI),
    .o_rising_edge  (iBIRE)
    // .o_falling_edge () // 
  );
always_comb begin
    iRXFIFOPE    = ~iRXFIFOEmpty & iRXFIFOQ[8];
    iRXFIFOFE    = ~iRXFIFOEmpty & iRXFIFOQ[9];
    iRXFIFOBI    = ~iRXFIFOEmpty & iRXFIFOQ[10];
    iFEIncrement = iRXFIFOWrite  & ~iRXFIFO64Full & (|iRXFIFOD[10:8]);  // Increment if FIFO actually fail entry
    iFEDecrement = iRXFIFORead   & ~iRXFIFOEmpty  & (|iRXFIFOQ[10:8]);  // Decrement if read fail entry
    iLSR_DR      = ~iRXFIFOEmpty;
    iLSR_THRE    = iTXFIFOEmpty;
    iLSR_TEMT    = ~iTXRunning & iTXFIFOEmpty;
    iLSR_THRNF   = ((~iFCR_FIFOEnable & iTXFIFOEmpty) | (iFCR_FIFOEnable & ~iTXFIFOFull));
    iLSR[0]      = iLSR_DR;
    iLSR[1]      = iLSR_OE;
    iLSR[2]      = iLSR_PE;
    iLSR[3]      = iLSR_FE;
    iLSR[4]      = iLSR_BI;
    iLSR[5]      = iLSR_THRE;
    iLSR[6]      = iLSR_TEMT;
    iLSR[7]      = (iFCR_FIFOEnable & iLSR_FIFOERR);
  end
    // LamCTV: Bug here iLSR[5] must be assigned by iLSR_THRE
  //----------Modem Status Register--------------------------------
  always_comb begin
    iMSR_CTS = (iMCR_LOOP & iRTS)      | (~iMCR_LOOP & ~iCTSn);
    iMSR_DSR = (iMCR_LOOP & iMCR_DTR)  | (~iMCR_LOOP & ~iDSRn);
    iMSR_RI  = (iMCR_LOOP & iMCR_OUT1) | (~iMCR_LOOP & ~iRIn);
    iMSR_DCD = (iMCR_LOOP & iMCR_OUT2) | (~iMCR_LOOP & ~iDCDn);
  end
  //---------Edge Detection for CTS, DSR, DCD and RI------------
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_ED_CTS (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iMSR_CTS),
    .o_rising_edge  (iCTSnRE),
    .o_falling_edge (iCTSnFE)
  );
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_ED_DSR (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iMSR_DSR),
    .o_rising_edge  (iDSRnRE),
    .o_falling_edge (iDSRnFE)
  );
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_ED_RI (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iMSR_RI),
    .o_rising_edge  (iRInRE),
    .o_falling_edge (iRInFE)
  );
  m_vlsit_edge_detect #(
    .RST_EDGE_DETECT (RST_EDGE_DETECT)
  ) UART_ED_DCD (
    .i_clk          (PCLK),
    .i_rst_n        (RSTN),
    .i_signal       (iMSR_DCD),
    .o_rising_edge  (iDCDnRE),
    .o_falling_edge (iDCDnFE)
  );
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_MSR
    if (!RSTN) begin
      iMSR_dCTS <= '0;
      iMSR_dDSR <= '0;
      iMSR_TERI <= '0;
      iMSR_dDCD <= '0;
    end else begin
      // LamCTV: 16/10/26: Change the priority of if-else statement, because the prority of VHDL is from bottom to top, so the if-else statement will be executed from top to bottom, and the last statement will be executed first. So the if-else statement will be executed in the order of iMSRRead, iCTSnRE, iCTSnFE, iDSRnRE, iDSRnFE, iDCDnRE, iDCDnFE, iRInRE. So the if-else statement will be executed in the order of iMSRRead, iCTSnRE, iCTSnFE, iDSRnRE, iDSRnFE, iDCDnRE, iDCDnFE, iRInRE.
      //-------Delta CTS----------
      if (iMSRRead) begin
        iMSR_dCTS <= 1'b0;
      end else if (iCTSnRE || iCTSnFE) begin
        iMSR_dCTS <= 1'b1;
      end
      //-------Delta DSR----------
      if (iMSRRead) begin
        iMSR_dDSR <= 1'b0;
      end else if (iDSRnRE || iDSRnFE) begin
        iMSR_dDSR <= 1'b1;
      end
      //-------Delta DCD----------
      if (iMSRRead) begin
        iMSR_dDCD <= 1'b0;
      end else if(iDCDnRE || iDCDnFE) begin
        iMSR_dDCD <= 1'b1;
      end
      //-------Trailing edge RI---
      if (iMSRRead) begin
        iMSR_TERI <= 1'b0;
      end else if(iRInRE) begin
        iMSR_TERI <= 1'b1;
      end
    end 
  end
  always_comb begin
    iMSR[0] = iMSR_dCTS;
    iMSR[1] = iMSR_dDSR;
    iMSR[2] = iMSR_TERI;
    iMSR[3] = iMSR_dDCD;
    iMSR[4] = iMSR_CTS;
    iMSR[5] = iMSR_DSR;
    iMSR[6] = iMSR_RI;
    iMSR[7] = iMSR_DCD;
  end
  //---------Scratch Register--------------------------------
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_SCR
    if (!RSTN) begin
      iSCR <= '0;
    end else if (iSCRWrite) begin
      iSCR <= PWDATA[7:0];
    end
  end
//========================UART Baudrate Gene========================-
  assign iBaudgenDiv = {iDLM, iDLL};
  // UART Baudrate Generator 16x
  m_vlsit_uart_baudgen UART_BG16 (
    .i_clk      (PCLK),
    .i_rst_n    (RSTN),
    .i_ce       (1'b1),
    .i_clear    (1'b0),
    .i_divider  (iBaudgenDiv),
    .o_baudtick (iBaudrate)
  );
  //--------------------Clock Divider--------------------------------
  m_vlsit_uart_clk_div UART_BG2 (
    .i_clk      (PCLK),
    .i_rst_n    (RSTN),
    .i_ovs_mode (iCFR_OVSMode),
    .i_ce       (iBaudrate),
    .o_clk      (iBaudtick2x)
  );
//===================Transmitter FIFO===================
  m_vlsit_uart_fifo #(
    .DATA_WIDTH_FIFO(DATA_WIDTH_FIFOTX),
    .DEPTH_FIFO(DEPTH_FIFO)
  ) UART_TXFF (
    .i_clk   (PCLK),
    .i_rst_n (RSTN),
    .i_clear (iTXFIFOClear),
    .i_write (iTXFIFOWrite),
    .i_read  (iTXFIFORead),
    .i_d     (PWDATA[7:0]),
    .o_q     (iTXFIFOQ),
    .o_empty (iTXFIFOEmpty),
    .o_full  (iTXFIFO64Full),
    .o_usage (iTXFIFOUsage)
  );
  //--------------Transmitter FIFO Inputs---------------------------
  always_comb begin: FIFO_TX_INPUTS
    iTXFIFO16Full = iTXFIFOUsage[4];
    iTXFIFOFull   = !iFCR_FIFO64E ? iTXFIFO16Full : iTXFIFO64Full;      // 2 modes fifo 16byte and 64byte
    iTXFIFOWrite  = iLSR_THRNF & iTHRWrite;
    iTXFIFOClear  = iFCR_TXFIFOReset;
  end
//=======================-Receiver FIFO=======================
  m_vlsit_uart_fifo #(
    .DATA_WIDTH_FIFO(DATA_WIDTH_FIFORX),
    .DEPTH_FIFO(DEPTH_FIFO)
  ) UART_RXFF (
    .i_clk      (PCLK),
    .i_rst_n    (RSTN),
    .i_clear    (iRXFIFOClear),
    .i_write    (iRXFIFOWrite),
    .i_read     (iRXFIFORead),
    .i_d        (iRXFIFOD),
    .o_q        (iRXFIFOQ),
    .o_empty    (iRXFIFOEmpty),
    .o_full     (iRXFIFO64Full),
    .o_usage    (iRXFIFOUsage)
  );
  //--------------Receiver FIFO Inputs---------------------------
  always_comb begin: FIFO_RX_INPUTS
    iRXFIFORead   = iRBRRead;
    iRXFIFO16Full = iRXFIFOUsage[4];
    iRXFIFOFull   = !iFCR_FIFO64E ? iRXFIFO16Full : iRXFIFO64Full;      // 2 modes fifo 16byte and 64byte
  end
  //--------------Receiver FIFO Ouputs---------------------------
  assign iRBR = iRXFIFOQ[7:0];
  //--------------FIFO 16 Trigger Level 1, 4, 8, 14-----------------
  assign iRXFIFO16Trigger = (iFCR_RXTrigger == 2'b00 & ~iRXFIFOEmpty)                                         |
                            (iFCR_RXTrigger == 2'b01 & (iRXFIFOUsage[2] | iRXFIFOUsage[3]))                  |
                            (iFCR_RXTrigger == 2'b10 & iRXFIFOUsage[3])                                       |
                            (iFCR_RXTrigger == 2'b11 & iRXFIFOUsage[3] & iRXFIFOUsage[2] & iRXFIFOUsage[1]) |
                            iRXFIFO16Full;
  //--------------iRXFIFO64Trigger 64 Trigger Level 1, 4, 8, 14-----------------
  assign iRXFIFO64Trigger = (iFCR_RXTrigger == 2'b00 & ~iRXFIFOEmpty)                                         |
                            (iFCR_RXTrigger == 2'b01 & (iRXFIFOUsage[4] | iRXFIFOUsage[5]))                  |
                            (iFCR_RXTrigger == 2'b10 & iRXFIFOUsage[5])                                       |
                            (iFCR_RXTrigger == 2'b11 & iRXFIFOUsage[5] & iRXFIFOUsage[4] & iRXFIFOUsage[3]) |
                            iRXFIFO64Full;
  assign iRXFIFOTrigger   = !iFCR_FIFO64E ? iRXFIFO16Trigger : iRXFIFO64Trigger;
//==================UART Transmitter========================================================
  m_vlsit_uart_transmitter UART_TX (
    .i_clk         (PCLK),
    .i_rst_n       (RSTN),
    .i_tx_clk      (iBaudtick2x),
    .i_tx_start    (iTXStart),
    .i_tx_clear    (iTXClear),
    .i_wls         (iLCR_WLS),
    .i_stb         (iLCR_STB),
    .i_pen         (iLCR_PEN),
    .i_eps         (iLCR_EPS),
    .i_sp          (iLCR_SP),
    .i_bc          (iLCR_BC),
    .i_tx_data     (iTSR),
    .o_tx_out      (iSOUT),
    .o_tx_finished (iTXFinished)
  );
  assign iTXClear = '0;
  //---------------------Transmitter Enable Signal---------------------------------------
  assign iTXEnable = ~iTXFIFOEmpty & (~iMCR_AFE | iMSR_CTS);
  //----------------------Transmitter Proceccess------------------------------------------
  // LamCTV: Fix FSM with 3 Block
  always_ff @(posedge PCLK or negedge RSTN) begin : UART_TX_STATE_REG
    if (!RSTN) state <= TXIDLE;
    else       state <= next_state;
  end
  always_ff @(posedge PCLK or negedge RSTN) begin : UART_TXPROC
    if (!RSTN) begin
      iTSR        <= '0;
      iTXStart    <= '0;
      iTXFIFORead <= '0;
      iTXRunning  <= '0;
    end else begin
      iTXStart    <= '0;
      iTXFIFORead <= '0;
      iTXRunning  <= '0;
      case (next_state)
        TXIDLE: begin
          if (iTXEnable) begin
            iTXRunning <= 1'b1;                // Start transmitter
          end
        end
        TXSTART: begin
          iTSR        <= iTXFIFOQ;
          iTXStart    <= 1'b1;                // Start transmitter
          iTXFIFORead <= 1'b1;                // Increment TX FIFO read counter
          iTXRunning  <= 1'b1;
        end        
        TXRUN: begin
          iTXRunning  <= 1'b1;
          iTXStart    <= 1'b1;
        end        
        TXEND: begin
          iTXStart    <= '0;
          iTXFIFORead <= '0;
          iTXRunning  <= '0;
        end        
        default: begin
          iTXStart    <= '0;
          iTXFIFORead <= '0;
          iTXRunning  <= '0;
        end
      endcase
    end
  end
  always_comb begin : UART_TX_NEXT_STATE
    next_state = state;
    case (state)
      TXIDLE: begin
        if (iTXEnable)     next_state = TXSTART;
        else               next_state = TXIDLE;
      end      
      TXSTART:             next_state = TXRUN;   
      TXRUN: begin
          if (iTXFinished) next_state = TXEND;
          else             next_state = TXRUN;
      end      
      TXEND:               next_state = TXIDLE;    
      default:             next_state = TXIDLE;
    endcase
end
//==================UART Receiver========================================================
  m_vlsit_uart_receiver UART_RX (
    .i_clk         (PCLK),
    .i_rst_n       (RSTN),
    .i_rx_clk      (iBaudrate),
    .i_rx_clear    (iRXClear),
    .i_ovs_mode    (iCFR_OVSMode),
    .i_wls         (iLCR_WLS),
    .i_stb         (iLCR_STB),
    .i_pen         (iLCR_PEN),
    .i_eps         (iLCR_EPS),
    .i_sp          (iLCR_SP),
    .i_rx_in       (iSIN),
    .o_rx_pe       (iRXPE),
    .o_rx_fe       (iRXFE),
    .o_rx_bi       (iRXBI),
    .o_rx_data     (iRXData),
    .o_rx_finished (iRXFinished)
  );
  assign iRXClear = '0;
  assign iSIN     = iMCR_LOOP ? iSOUT : iSINr;
  //---------------Receiver Processing------------------------------------------------------
always_comb begin : UART_RXPROC_COMB
  next_state_comb  = rx_state;
  iRXFIFOWrite_nxt = 1'b0;
  iRXFIFOD_load    = 1'b0;
  case (rx_state)
    RXIDLE: begin
      if (iRXFinished) begin
        iRXFIFOD_load = 1'b1;
        next_state_comb = RXSAVE;
      end
    end
    RXSAVE: begin
      if (!iFCR_FIFOEnable || !iRXFIFOFull) begin
        iRXFIFOWrite_nxt = 1'b1;
      end else begin
        iRXFIFOWrite_nxt = 1'b0;
      end
      next_state_comb = RXIDLE;
    end

    default: next_state_comb = RXIDLE;
  endcase
end
assign iRXFIFOClear = iFCR_RXFIFOReset | ((rx_state == RXIDLE) & ~iFCR_FIFOEnable & iRXFinished);
always_ff @(posedge PCLK or negedge RSTN) begin : UART_RXPROC
  if (!RSTN) begin
    rx_state     <= RXIDLE;
    iRXFIFOWrite <= 1'b0;
    iRXFIFOD     <= '0;
  end else begin
    rx_state     <= next_state_comb;
    iRXFIFOWrite <= iRXFIFOWrite_nxt;
    if (iRXFIFOD_load)
      iRXFIFOD <= {iRXBI, iRXFE, iRXPE, iRXData};
  end
end
//====================Automatic Flow Control==================================================
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_AFC
    if(!RSTN) begin
      iRTS <= '0;
    end else begin
      if(!iMCR_RTS || (iMCR_AFE && iRXFIFOTrigger)) begin
        // Deassert when MCR_RTS is not set or AFC is enabled and the RX FIFO trigger level is reached
        iRTS <= '0;
      end else if (iMCR_RTS && (!iMCR_AFE || (iMCR_AFE && iRXFIFOEmpty))) begin
        iRTS <= 1'b1;
      end
    end
  end
//=================Output Register==============================================================
  always_ff @(posedge PCLK or negedge RSTN) begin: UART_OUTREGS
    if(!RSTN) begin
      OUT1N     <= '1;
      OUT2N     <= '1;
      RTSN      <= '1;
      DTRN      <= '1;
      TXD       <= '1;
      // LamCTV - 21/10/26: Fix the value assignment 
    end else begin
      // Notes: The Output OUT1n, OUT2n, RTSn, DTRn is active low and controlled by MCR[3:0]
      OUT1N     <= iMCR_LOOP | ~iMCR_OUT1;
      OUT2N     <= iMCR_LOOP | ~iMCR_OUT2;
      RTSN      <= iMCR_LOOP | ~iRTS;
      DTRN      <= iMCR_LOOP | ~iMCR_DTR;
      TXD       <= iMCR_LOOP | iSOUT;
    end
  end
//=================UART Data Output=================================================================
  always_comb begin : UART_REG_READ_MUX
    case (PADDR)
      3'b000: begin
                if (!iLCR_DLAB) PRDATA[7:0] = iRBR;
                else            PRDATA[7:0] = iDLL;
              end
      3'b001: begin
                if (!iLCR_DLAB) PRDATA[7:0] = iIER;
                else            PRDATA[7:0] = iDLM;
              end
      3'b010:  PRDATA[7:0] = iIIR;
      3'b011:  PRDATA[7:0] = iLCR;
      3'b100:  begin
                if (!iLCR_DLAB) PRDATA[7:0] = iMCR;
                else            PRDATA[7:0] = iCFR;
              end
      3'b101:  PRDATA[7:0] = iLSR;
      3'b110:  PRDATA[7:0] = iMSR;
      3'b111:  PRDATA[7:0] = iSCR;      
      default: PRDATA[7:0] = iRBR;
    endcase
  end
  assign PRDATA[31:8] = '0;
  assign PREADY       = 1'b1;
  assign PSLVERR      = 1'b0;
endmodule
