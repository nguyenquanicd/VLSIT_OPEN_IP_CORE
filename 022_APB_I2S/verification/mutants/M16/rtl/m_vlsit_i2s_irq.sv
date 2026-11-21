/*
 * Project      : VLSIT APB I2S Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Interrupt logic of the APB I2S controller (APB clock domain). Eight causes, each
 *                with a raw bit (set by hardware, cleared by writing 1 in the CSR), an enable bit,
 *                an injection bit and a masked status bit. The module drives the hardware-load
 *                ports of the raw bits: an event sets the raw bit for one cycle, a level cause
 *                (watermark) loads the raw bit in every cycle in which its condition holds, and the
 *                rising edge of an injection bit sets the raw bit. The masked status is the raw bit
 *                AND the enable bit; the interrupt output is the registered OR of the eight masked
 *                bits. Cause order: 0 tx_wm, 1 tx_und, 2 tx_ovr, 3 rx_wm, 4 rx_ovr, 5 sync, 6 hung,
 *                7 frm.
 * Decisions    : DEC-003, ASM-010, ASM-012, REQ-IF-009, REQ-IF-010, OP-014
 */
`timescale 1ns/1ps

module m_vlsit_i2s_irq #(
  // Parameter Description: number of interrupt causes. Fixed by the register map.
  // Parameter values: 8; default is 8.
  // Parameter unit: count
  parameter logic [31:0] PARA_I2S_IRQ_N = 8
) (
  // Clock and reset
  input  wire                       i_clk_apb,
  input  wire                       i_rst_n_apb,

  // Causes: level conditions of the watermarks, the transmit write overrun, and the event pulses
  // of the two units (underrun or overrun, sync error, hung clock, frame done) with the selector
  // of the frame-done unit
  input  wire                       i_tx_wm_cond,
  input  wire                       i_rx_wm_cond,
  input  wire                       i_tx_ovr,
  input  wire  [3:0]                i_ev_tx,
  input  wire  [3:0]                i_ev_rx,
  input  wire                       i_frm_sel,

  // Register fields of the four interrupt registers
  input  wire  [PARA_I2S_IRQ_N-1:0] i_en,
  input  wire  [PARA_I2S_IRQ_N-1:0] i_inj,

  // Hardware load of the raw bits and masked status
  output logic [PARA_I2S_IRQ_N-1:0] o_raw_we,
  output logic [PARA_I2S_IRQ_N-1:0] o_raw_wdata,
  input  wire  [PARA_I2S_IRQ_N-1:0] i_raw,
  output logic [PARA_I2S_IRQ_N-1:0] o_sts,

  // Interrupt outputs: registered pin and live flag of the global status register
  output logic                      o_irq_any,
  output logic                      o_int
);

  // Internal signal declarations
  logic [PARA_I2S_IRQ_N-1:0] w_cause;
  logic [PARA_I2S_IRQ_N-1:0] reg_inj_d;
  logic [PARA_I2S_IRQ_N-1:0] w_inj_rise;
  logic reg_int;

  // Cause vector: events are one-cycle pulses, the watermark causes are held while the condition
  // holds. The sync error and the hung clock are common to the two units, the frame-done cause
  // comes from the unit chosen by the selector (ASM-012).
  assign w_cause = {(i_frm_sel ? i_ev_rx[3] : i_ev_tx[3]), (i_ev_tx[2] | i_ev_rx[2]),
                    (i_ev_tx[1] | i_ev_rx[1]), i_ev_rx[0], i_rx_wm_cond, i_tx_ovr, i_ev_tx[0],
                    i_tx_wm_cond};

  // Rising edge of every injection bit: software injects a cause by writing 1 to its bit.
  assign w_inj_rise = i_inj & ~reg_inj_d;

  // Hardware load: a cause or an injection edge loads 1 into the raw bit. The hardware load wins
  // over a simultaneous software clear in the CSR, so no cause is lost.
  assign o_raw_we    = w_cause | w_inj_rise;
  assign o_raw_wdata = {PARA_I2S_IRQ_N{1'b1}};

  // Masked status: raw bit AND enable bit, same bit position in every register (REQ-IF-009).
  assign o_sts = i_raw & i_en;

  // Live OR of the masked status for the global status register.
  assign o_irq_any = |i_raw;

  // Injection edge detector: control state, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_inj_d
    if (!i_rst_n_apb)
      reg_inj_d <= '0;
    else
      reg_inj_d <= i_inj;
  end

  // Interrupt output flop: registered OR of the masked causes, asynchronously reset to 0.
  always_ff @(posedge i_clk_apb, negedge i_rst_n_apb) begin : p_ff_int
    if (!i_rst_n_apb)
      reg_int <= 1'b0;
    else
      reg_int <= o_irq_any;
  end

  // Output mapping of the interrupt pin.
  assign o_int = reg_int;

endmodule
