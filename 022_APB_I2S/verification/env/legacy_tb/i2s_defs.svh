// Register map of the APB I2S IP: offsets, field positions and reset values (workbook I2S_CSR.xlsx).
localparam logic [15:0] R_VERSION = 16'h0000, R_CAP = 16'h0004, R_GCTRL = 16'h0008, R_GSTS = 16'h000C,
                        R_IRAW = 16'h0010, R_IEN = 16'h0014, R_IINJ = 16'h0018, R_ISTS = 16'h001C;
localparam logic [15:0] TX_BASE = 16'h0100, RX_BASE = 16'h0200;
localparam logic [15:0] R_CTRL = 16'h00, R_FRAME = 16'h04, R_SYNC = 16'h08, R_CLK = 16'h0C, R_MASK = 16'h10,
                        R_FIFO = 16'h14, R_STS = 16'h18, R_DATA = 16'h1C, R_TMO = 16'h20;
// control bits
localparam int C_EN = 0, C_SRST = 1, C_FLUSH = 2, C_ROLE = 4, C_SHR = 5, C_ONDEM = 6, C_AUTO = 7, C_TRI = 8, C_DMA = 9;
// interrupt cause bits
localparam int I_TXWM = 0, I_TXUND = 1, I_TXOVR = 2, I_RXWM = 3, I_RXOVR = 4, I_SYNC = 5, I_HUNG = 6, I_FRM = 7;
