`timescale 1ns/1ps
// Verification model of the FIFO RAM macro VLSIT_CELL_SRAM_1W1R with a fault injector (t_fi_ram_parity, REQ-FUNC-040).
// AI-generated candidate (R-117). Same ports and behavior as the cell of 000_Common/rtl_cells; in addition, when the plusarg
// +par_nth=N is given, the N-th read of the 33-bit RAM (32 data bits + parity bit) returns the word with bit +par_bit
// inverted (default 0), once. Reads of other widths and writes are untouched. It is a simulation-only model that replaces the
// cell in the file list of the fault build; it is not a force of a design signal (R-258).
module VLSIT_CELL_SRAM_1W1R #(
  parameter logic [31:0] ADDR_W = 3,
  parameter logic [31:0] DATA_W = 8,
  localparam logic [31:0] LPARA_DEPTH = 32'd1 << ADDR_W
) (
  input  wire               CLKW,
  input  wire               WEB,
  input  wire  [ADDR_W-1:0] AW,
  input  wire  [DATA_W-1:0] DW,
  input  wire  [DATA_W-1:0] BWEB,
  input  wire               CLKR,
  input  wire               REB,
  input  wire  [ADDR_W-1:0] AR,
  output logic [DATA_W-1:0] QR
);
  logic [DATA_W-1:0] reg_mem [0:LPARA_DEPTH-1];
  logic [DATA_W-1:0] reg_qr;
  int nth = -1, bit_no = 0, cnt = 0;
  initial begin
    void'($value$plusargs("par_nth=%d", nth));
    void'($value$plusargs("par_bit=%d", bit_no));
  end
  always_ff @(posedge CLKW) begin
    if (!WEB) reg_mem[AW] <= (reg_mem[AW] & BWEB) | (DW & ~BWEB);
  end
  always_ff @(posedge CLKR) begin
    if (!REB) begin
      cnt <= cnt + 1;
      if (DATA_W == 33 && nth >= 0 && cnt == nth) begin
        reg_qr <= reg_mem[AR] ^ (33'd1 << bit_no);
        $display("FAULT_INJECTED read %0d address %0d bit %0d", cnt, AR, bit_no);
      end else reg_qr <= reg_mem[AR];
    end
  end
  assign QR = reg_qr;
endmodule
