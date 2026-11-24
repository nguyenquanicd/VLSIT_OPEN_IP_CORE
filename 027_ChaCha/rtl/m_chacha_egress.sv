/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Output stream adapter. It accepts a chunk (up to 64 bytes with its valid byte
 *                count) and writes ceil(v / W) beats to the output buffer, W = PARA_AXI_DW / 8,
 *                one beat per cycle while the buffer is not full. The unused byte lanes of the
 *                last beat are zero because the chunk is masked by its producer. A new chunk is
 *                accepted when the machine is idle or writes the last beat of the previous chunk,
 *                so consecutive chunks follow without a gap.
 * Decisions    : DEC-022, DEC-030
 */
`timescale 1ns/1ps

module m_chacha_egress #(
  // Parameter Description: data width of the output buffer beat; a beat is PARA_AXI_DW / 8 bytes.
  // Parameter values: 32, 64, 128 or 256; default is 64.
  // Parameter unit: bit
  parameter logic [31:0] PARA_AXI_DW = 32'd64,
  localparam logic [31:0] LPARA_BYTES   = PARA_AXI_DW / 32'd8,
  localparam logic [31:0] LPARA_BYTE_LG = $clog2(LPARA_BYTES),
  localparam logic [31:0] LPARA_BPC     = 32'd512 / PARA_AXI_DW,
  localparam logic [31:0] LPARA_BEAT_W  = $clog2(LPARA_BPC)
) (
  // Clock, reset and clear
  input  wire                    i_clk_core,
  input  wire                    i_rst_n_core,
  input  wire                    i_clr,

  // Chunk input
  input  wire                    i_chk_vld,
  input  wire  [511:0]           i_chk_data,
  input  wire  [6:0]             i_chk_bytes,
  output logic                   o_chk_rdy,

  // Output buffer write port
  output logic                   o_out_wr_en,
  output logic [PARA_AXI_DW-1:0] o_out_wr_data,
  input  wire                    i_out_full,

  // Status: no chunk held
  output logic                   o_idle
);

  // Internal signal declarations
  logic                    reg_busy;
  logic [511:0]            reg_data;
  logic [LPARA_BEAT_W:0]   reg_nbeat;
  logic [LPARA_BEAT_W:0]   reg_beat;
  logic [6:0]              w_bytes_up;
  logic [LPARA_BEAT_W:0]   w_nbeat_new;
  logic                    w_wr_ok;
  logic                    w_last_beat;
  logic                    w_load;

  // Number of beats of a new chunk: bytes rounded up to a whole beat, divided by the beat size.
  assign w_bytes_up  = $bits(w_bytes_up)'(i_chk_bytes + 7'(LPARA_BYTES - 32'd1));
  assign w_nbeat_new = (LPARA_BEAT_W + 1)'(w_bytes_up >> LPARA_BYTE_LG);

  // A beat is written when a chunk is held and the buffer has room; the chunk is finished when
  // that beat is its last one.
  assign w_wr_ok     = reg_busy & ~i_out_full;
  assign w_last_beat = (reg_beat == (reg_nbeat - 1'b1));

  // A chunk is accepted when idle or when the last beat of the held chunk is written now.
  assign o_chk_rdy = ~reg_busy | (w_wr_ok & w_last_beat);
  assign w_load    = i_chk_vld & o_chk_rdy;

  // Beat output: beat number reg_beat of the held chunk.
  assign o_out_wr_en   = w_wr_ok;
  assign o_out_wr_data = reg_data[32'(reg_beat) * PARA_AXI_DW +: PARA_AXI_DW];

  // Control state: busy flag, beat count of the chunk and beat index.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
    if (!i_rst_n_core) begin
      reg_busy  <= 1'b0;
      reg_nbeat <= '0;
      reg_beat  <= '0;
    end else begin
      // Priority: clear, then a new chunk, then the next beat of the held chunk.
      casez ({i_clr, w_load, w_wr_ok})
        3'b1??: reg_busy <= 1'b0;
        3'b01?: begin
          reg_busy  <= 1'b1;
          reg_nbeat <= w_nbeat_new;
          reg_beat  <= '0;
        end
        3'b001: begin
          reg_beat <= $bits(reg_beat)'(reg_beat + 1'b1);
          if (w_last_beat)
            reg_busy <= 1'b0;
        end
        default: begin
          // Idle or waiting for room: hold.
        end
      endcase
    end
  end

  // Payload register: no reset; the busy flag qualifies it and i_clr empties it.
  always_ff @(posedge i_clk_core) begin : p_ff_data
    if (i_clr)
      reg_data <= '0;
    else if (w_load)
      reg_data <= i_chk_data;
  end

  // Output mapping of the idle status.
  assign o_idle = ~reg_busy;

endmodule
