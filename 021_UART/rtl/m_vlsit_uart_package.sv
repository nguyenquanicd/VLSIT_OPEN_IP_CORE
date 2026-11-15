package m_vlsit_uart_package;
  // COUNTER
  parameter       WIDTH_COUNTER      = 4;
  // MAJORITY FILTER
  parameter       WIDTH_MV           = 4;   // size of counter
  // EDGE DETECT
  parameter logic RST_EDGE_DETECT    = 1'b0;
  // INPUT FILTER
  parameter logic RST_INPUT_FILTER   = 1'b0;
  parameter       SIZE_INPUT_FILTER  = 2;
  parameter       WIDTH_INPUT_FILTER = $clog2(RST_INPUT_FILTER + 1);
  // INPUT SYNC 2-FF CDC
  parameter logic RST_INPUT_SYNC     = 1'b0;
  // FIFO RX
  parameter       DATA_WIDTH_FIFOTX  = 8;
  parameter       DEPTH_FIFO = 6;
  // FIFO TX
  parameter       DATA_WIDTH_FIFORX  = 11;
endpackage  