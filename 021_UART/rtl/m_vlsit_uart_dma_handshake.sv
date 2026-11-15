import m_vlsit_uart_package::*;
module m_vlsit_uart_dma_handshake (
  input  logic i_uart_pclk,
  input  logic i_uart_prst_n,
  input  logic i_dma_mode_sl,
  input  logic i_tx_int,
  input  logic i_rx_int,
  input  logic i_uart_dma_tx_clr,
  input  logic i_uart_dma_rx_clr,
  output logic o_uart_dma_tx_req,
  output logic o_uart_dma_rx_req
);
//------------------------------------------------------------------------------
// 2-WIRE DMA HANDSHAKE LOGIC
//------------------------------------------------------------------------------
logic r_dma_txreq;
logic r_dma_rxreq;

// 1. Generate Transmit Request (Pull data from Memory -> UART)
always_ff @(posedge i_uart_pclk or negedge i_uart_prst_n) begin
  if (!i_uart_prst_n) begin
    r_dma_txreq <= 1'b0;
  end else if (!i_dma_mode_sl) begin
    r_dma_txreq <= 1'b0;
  end else begin
    // Ưu tiên 1: Hạ cờ khi DMA xác nhận đã bơm data
    if (i_uart_dma_tx_clr) begin
      r_dma_txreq <= 1'b0;                
    // Ưu tiên 2: Giương cờ khi khoang phát cạn (dưới ngưỡng Trigger)
    end else if (i_tx_int) begin
      r_dma_txreq <= 1'b1;                
    end
  end
end
assign o_uart_dma_tx_req = r_dma_txreq & i_dma_mode_sl;

// 2. Generate Receive Request (Push data from UART -> Memory)
always_ff @(posedge i_uart_pclk or negedge i_uart_prst_n) begin
  if (!i_uart_prst_n) begin
    r_dma_rxreq <= 1'b0;
  end else if (!i_dma_mode_sl) begin
    r_dma_rxreq <= 1'b0;
  end else begin
    if (i_uart_dma_rx_clr) begin
        r_dma_rxreq <= 1'b0;
      end else if (i_rx_int) begin
        r_dma_rxreq <= 1'b1;
      end
    end
  end
assign o_uart_dma_rx_req = r_dma_rxreq & i_dma_mode_sl;
endmodule
