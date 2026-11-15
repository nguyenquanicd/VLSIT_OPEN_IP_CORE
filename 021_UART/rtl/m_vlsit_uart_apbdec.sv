//--------------------------------------
//Project: APB Decoder Generator
//Module:  m_vlsit_uart_apbdec
//Function: APB Decoder
//Author:  lamctv
//Script Author: Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
//Generated: 2026-10-09 18:00:40
//--------------------------------------
//Address Width: 16
//Data Width: 32
//Write Strobe: 4
//Number of Slaves: 1
//--------------------------------------
module m_vlsit_uart_apbdec (
  // APB Master Interface
  input  logic [15:0]   i_paddr,            
  input  logic [31:0]   i_pwdata,                  
  input  logic          i_pwrite,          
  input  logic          i_psel,                         
  input  logic          i_penable,           
  output logic          o_pready,         
  output logic          o_pslverr,            
  output logic [31:0]   o_prdata,                

  // APB Slave Interfaces
  // Slave 1: UART
  output logic [ 2:0]   o_paddr_uart,              
  output logic [31:0]   o_pwdata_uart,                 
  output logic          o_psel_uart,              
  output logic          o_penable_uart,             
  output logic          o_pwrite_uart,           
  input  logic          i_pready_uart,                
  input  logic          i_pslverr_uart,           
  input  logic [31:0]   i_prdata_uart                  
);

  // Internal signals
  logic w_slave_uart_sel;
  // ============================================================================
  // Address Decode Logic
  // ============================================================================
  // UART registers use word-aligned byte addresses 0x00 through 0x1C.
  // Select the full 32-byte window so PADDR[4:2] can address all 8 registers.
  assign w_slave_uart_sel = (i_paddr >= 16'h0000) & (i_paddr <= 16'h001F);

  // ============================================================================
  // PREADY, PSLVERR and PRDATA Generation
  // ============================================================================
  always_comb begin
    casez ({
      w_slave_uart_sel
    })
      1'b1: begin
        o_pready  = i_pready_uart;
        o_pslverr = i_pslverr_uart;
        o_prdata  = i_prdata_uart;
      end
      default: begin
        o_pready  = 1'b1;
        o_pslverr = 1'b1;
        o_prdata  = 32'd0;
      end
    endcase
  end

  // ============================================================================
  // Slave Select Generation
  // ============================================================================
  assign o_psel_uart    = w_slave_uart_sel & i_psel;
  assign o_penable_uart = i_penable;
  assign o_pwrite_uart  = i_pwrite;
  // LamCTV - 20/10/26: Change the Address Decode
  assign o_paddr_uart   = i_paddr[4:2];
  assign o_pwdata_uart  = i_pwdata;
endmodule
