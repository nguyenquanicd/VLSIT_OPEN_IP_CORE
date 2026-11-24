/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : One DMA request channel (section 6.3, rules DMA-T1 to DMA-T7). A start pulse
 *                loads the number of beats of the message. While enabled the channel repeats:
 *                choose the burst size N (the watermark W, or the rest of the message in tail
 *                mode 0 and one beat in tail mode 1 when fewer than W beats remain), set the FIFO
 *                threshold register for N (write channel: depth - N + 1 so that o_full_thr low
 *                means room for N beats; read channel: N - 1 so that o_empty_thr low means N
 *                beats readable), wait until the flag is low and the acknowledge is low, raise
 *                the request, hold it until the acknowledge is seen, lower it one cycle later,
 *                wait until the acknowledge falls after the burst, subtract N and pause one
 *                cycle. The channel is in CLK-AXI.
 * Decisions    : DEC-010, DEC-013, DEC-019, DEC-029
 */
`timescale 1ns/1ps

module m_chacha_dma_ch #(
  // Parameter Description: direction of the channel, 0 write channel (room for N beats), 1 read
  // channel (N beats readable).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_DIR = 32'd0,
  // Parameter Description: depth of the FIFO of the channel in beats.
  // Parameter values: power of two from 4 to 16384; default is 16.
  // Parameter unit: beat
  parameter logic [31:0] PARA_DEPTH = 32'd16,
  localparam logic [31:0] LPARA_THR_W = $clog2(PARA_DEPTH) + 32'd1
) (
  // Clock and reset
  input  wire                    i_clk_axi,
  input  wire                    i_rst_n_axi,

  // Message start with the number of beats, run enable, watermark and tail mode
  input  wire                    i_start,
  input  wire  [16:0]            i_total_beats,
  input  wire                    i_en,
  input  wire  [8:0]             i_wm,
  input  wire                    i_tail_mode,

  // FIFO threshold register and threshold flag
  output logic [LPARA_THR_W-1:0] o_thr,
  input  wire                    i_flag,

  // Request and acknowledge pair
  output logic                   o_req,
  input  wire                    i_ack,

  // Status: beats left to move
  output logic                   o_busy
);

  // FSM states: IDLE waits for work, ARM sets the threshold register, WAIT waits for room or data,
  // REQ raises the request, HOLD waits for the acknowledge to fall, GAP pauses one cycle.
  // Encodings 3'b110 and 3'b111 recover to IDLE.
  typedef enum logic [2:0] {
    ENUM_ST_IDLE = 3'b000,
    ENUM_ST_ARM  = 3'b001,
    ENUM_ST_WAIT = 3'b010,
    ENUM_ST_REQ  = 3'b011,
    ENUM_ST_HOLD = 3'b100,
    ENUM_ST_GAP  = 3'b101
  } dma_state_type_def;

  // Internal signal declarations
  dma_state_type_def reg_fsm_dma_current_state;
  dma_state_type_def w_fsm_dma_nxt_state;
  logic [16:0]       reg_rem;
  logic [8:0]        reg_n;
  logic [LPARA_THR_W-1:0] reg_thr;
  logic [8:0]        w_n;
  logic [8:0]        w_n_thr;
  logic [LPARA_THR_W-1:0] w_thr;
  logic              w_more;

  // Burst size: the watermark while at least W beats remain, else the rest (tail mode 0) or one
  // beat (tail mode 1).
  always_comb begin : p_com_n
    w_n = i_wm;
    if (reg_rem < 17'(i_wm)) begin
      if (i_tail_mode)
        w_n = 9'd1;
      else
        w_n = reg_rem[8:0];
    end
  end

  // Threshold for the burst size: depth - N + 1 for the write channel, N - 1 for the read channel.
  // With no beats left the threshold follows the watermark, so the flag gives the polling status.
  assign w_n_thr = w_more ? w_n : i_wm;
  assign w_thr   = (PARA_DIR == 32'd0) ? LPARA_THR_W'(PARA_DEPTH - 32'(w_n_thr) + 32'd1) :
                                         LPARA_THR_W'(32'(w_n_thr) - 32'd1);
  assign w_more = (reg_rem != 17'd0);

  // Output mapping: the request is high in REQ only; the threshold register and the status.
  assign o_req  = (reg_fsm_dma_current_state == ENUM_ST_REQ);
  assign o_thr  = reg_thr;
  assign o_busy = w_more;

  // Part 1 of the FSM: current state register, reset to IDLE.
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_fsm_dma
    if (!i_rst_n_axi)
      reg_fsm_dma_current_state <= ENUM_ST_IDLE;
    else
      reg_fsm_dma_current_state <= w_fsm_dma_nxt_state;
  end

  // Part 2 of the FSM. A disabled channel returns to IDLE at once, except that a burst in progress
  // (state HOLD) waits for the acknowledge to fall first so that the handshake is not broken.
  always_comb begin : p_com_fsm_nxt
    w_fsm_dma_nxt_state = reg_fsm_dma_current_state;
    case (reg_fsm_dma_current_state)
      ENUM_ST_IDLE: begin
        if (i_en & w_more & ~i_ack & ~i_start)
          w_fsm_dma_nxt_state = ENUM_ST_ARM;
      end
      ENUM_ST_ARM: begin
        if (i_en)
          w_fsm_dma_nxt_state = ENUM_ST_WAIT;
        else
          w_fsm_dma_nxt_state = ENUM_ST_IDLE;
      end
      ENUM_ST_WAIT: begin
        casez ({i_en, i_flag, i_ack})
          3'b0??:  w_fsm_dma_nxt_state = ENUM_ST_IDLE;
          3'b100:  w_fsm_dma_nxt_state = ENUM_ST_REQ;
          default: w_fsm_dma_nxt_state = ENUM_ST_WAIT;
        endcase
      end
      ENUM_ST_REQ: begin
        casez ({i_en, i_ack})
          2'b0?:   w_fsm_dma_nxt_state = ENUM_ST_IDLE;
          2'b11:   w_fsm_dma_nxt_state = ENUM_ST_HOLD;
          default: w_fsm_dma_nxt_state = ENUM_ST_REQ;
        endcase
      end
      ENUM_ST_HOLD: begin
        if (~i_ack)
          w_fsm_dma_nxt_state = ENUM_ST_GAP;
      end
      ENUM_ST_GAP: w_fsm_dma_nxt_state = ENUM_ST_IDLE;
      default:     w_fsm_dma_nxt_state = ENUM_ST_IDLE;
    endcase
  end

  // Burst bookkeeping: the remaining beats load at a start and fall by the burst size when the
  // acknowledge has fallen; the burst size is fixed when the request rises.
  always_ff @(posedge i_clk_axi, negedge i_rst_n_axi) begin : p_ff_rem
    if (!i_rst_n_axi) begin
      reg_rem <= 17'd0;
      reg_n   <= 9'd0;
      reg_thr <= '0;
    end else begin
      if (reg_fsm_dma_current_state == ENUM_ST_IDLE)
        reg_thr <= w_thr;
      if (reg_fsm_dma_current_state == ENUM_ST_WAIT)
        reg_n <= w_n;
      casez ({i_start, (reg_fsm_dma_current_state == ENUM_ST_HOLD) & ~i_ack})
        2'b1?:   reg_rem <= i_total_beats;
        2'b01:   reg_rem <= $bits(reg_rem)'(reg_rem - 17'(reg_n));
        default: begin
          // No start and no finished burst: the count holds.
        end
      endcase
    end
  end

endmodule
