/*
 * Project      : VLSIT_OPEN_IP_CORE
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-24
 * Description  : Key request and capture (section 6.3, rules KEY-T1 to KEY-T5). A request pulse
 *                raises o_key_req with the slot index and holds both until the key store answers
 *                with i_key_vld (key on i_key_data) or i_key_err; the key is copied at the edge
 *                where the request and the valid answer are both high and no other edge samples
 *                i_key_data. An error answer wins over a valid one in the same cycle and no key is
 *                copied. The request drops in the next cycle. The key register is cleared by i_clr
 *                at the end of a message, on an abort and on reset, and is never readable by
 *                software: it feeds only the cipher cores.
 * Decisions    : DEC-006, DEC-020
 */
`timescale 1ns/1ps

module m_chacha_key (
  // Clock and reset
  input  wire          i_clk_core,
  input  wire          i_rst_n_core,

  // Control: request pulse with the slot, clear of the key and the request
  input  wire          i_clr,
  input  wire          i_req_start,
  input  wire  [3:0]   i_slot,

  // Key-store port
  output logic         o_key_req,
  output logic [3:0]   o_key_slot,
  input  wire  [255:0] i_key_data,
  input  wire          i_key_vld,
  input  wire          i_key_err,

  // Result: captured key and one-cycle pulses for a key copy and a key error
  output logic [255:0] o_key,
  output logic         o_got,
  output logic         o_err
);

  // Internal signal declarations
  logic         reg_req;
  logic [3:0]   reg_slot;
  logic         reg_got;
  logic         reg_err;
  logic [255:0] reg_key;
  logic         w_take_key;
  logic         w_take_err;

  // Answer decode: the error answer wins over the valid answer (KEY-T4).
  assign w_take_key = reg_req & i_key_vld & ~i_key_err;
  assign w_take_err = reg_req & i_key_err;

  // Control state: the request, its slot and the result pulses. A clear drops the request at once.
  always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_ctrl
    if (!i_rst_n_core) begin
      reg_req  <= 1'b0;
      reg_slot <= 4'd0;
      reg_got  <= 1'b0;
      reg_err  <= 1'b0;
    end else if (i_clr) begin
      reg_req <= 1'b0;
      reg_got <= 1'b0;
      reg_err <= 1'b0;
    end else begin
      reg_got <= w_take_key;
      reg_err <= w_take_err;
      if (i_req_start & ~reg_req) begin
        reg_req  <= 1'b1;
        reg_slot <= i_slot;
      end else if (w_take_key | w_take_err)
        reg_req <= 1'b0;
    end
  end

  // Key register: no reset, cleared by i_clr, copied only at the transfer edge of the handshake.
  // The pulse reg_got qualifies it for the consumers.
  always_ff @(posedge i_clk_core) begin : p_ff_key
    if (i_clr)
      reg_key <= '0;
    else if (w_take_key)
      reg_key <= i_key_data;
  end

  // Output mapping.
  assign o_key_req  = reg_req;
  assign o_key_slot = reg_slot;
  assign o_key      = reg_key;
  assign o_got      = reg_got;
  assign o_err      = reg_err;

endmodule
