// Synthesis-only stand-in of the SRAM macro: the address, write data and enables end in flops and the read data starts
// from a flop, so the timing paths stop at the macro boundary (the real macro is not part of this synthesis).
module VLSIT_CELL_SRAM_1W1R #(parameter logic [31:0] ADDR_W = 3, parameter logic [31:0] DATA_W = 8) (
  input wire CLKW, input wire WEB, input wire [ADDR_W-1:0] AW, input wire [DATA_W-1:0] DW,
  input wire [DATA_W-1:0] BWEB, input wire CLKR, input wire REB, input wire [ADDR_W-1:0] AR,
  output logic [DATA_W-1:0] QR);
  logic [DATA_W-1:0] r_w;
  logic [ADDR_W-1:0] r_aw;
  logic r_web;
  always_ff @(posedge CLKW) begin r_w <= DW & ~BWEB; r_aw <= AW; r_web <= WEB; end
  always_ff @(posedge CLKR) QR <= {DATA_W{^AR ^ REB ^ (^r_w) ^ (^r_aw) ^ r_web}};
endmodule
