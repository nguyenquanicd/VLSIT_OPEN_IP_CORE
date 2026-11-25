// dv_dvp_source.sv - project-local DVP sensor source BFM (HDS v0.3 REQ-IF-003, REQ-FUNC-005/006/007).
// AI-generated candidate (R-117). Drives only the public DVP pins. Continuous mode: free-running PCLK, values change
// on the non-sample edge. Gated mode: PCLK exists only as one pulse per valid pixel, at least GATE_GAP_APB APB cycles
// apart, with the data held stable through that gap; VSYNC active for at least VS_APB_CYC APB cycles with PCLK stopped.
`timescale 1ns/1ps
module dv_dvp_source #(
  parameter int W = 8,
  parameter int EDGE = 0,
  parameter int VS_ACT = 1,
  parameter int HR_ACT = 1,
  parameter real T_APB_NS = 10.26,
  parameter int GATE_GAP_APB = 6,
  parameter int VS_APB_CYC = 8
) (
  output logic          o_clk,
  output logic [W-1:0]  o_data,
  output logic          o_vsync,
  output logic          o_href
);
  localparam bit VS_IDLE = (VS_ACT == 0) ? 1'b1 : 1'b0;
  localparam bit HR_IDLE = (HR_ACT == 0) ? 1'b1 : 1'b0;
  localparam logic [W-1:0] MASK = {W{1'b1}};

  bit  clk_run = 0;
  real half_ns = 6.855;
  longint lfsr = 64'h1;

  initial begin
    o_clk = (EDGE == 0) ? 1'b0 : 1'b1;   // idle level of a gated PCLK
    o_data = '0; o_vsync = VS_IDLE; o_href = HR_IDLE;
  end

  // free-running PCLK for continuous mode
  always begin
    wait (clk_run);
    #(half_ns);
    if (clk_run) o_clk = ~o_clk;
  end

  task automatic start_clk(input real period_ns);
    half_ns = period_ns / 2.0;
    clk_run = 1;
  endtask
  task automatic stop_clk();
    clk_run = 0;
    #1;
    o_clk = (EDGE == 0) ? 1'b0 : 1'b1;
  endtask

  function automatic logic [W-1:0] pixel(input int l, input int p, input int pat, input int seed);
    logic [W-1:0] v;
    case (pat)
      0: v = W'((l * 16 + p * 5 + 1));
      1: v = '0;
      2: v = MASK;
      3: v = W'(1) << (p % W);
      4: v = ~(W'(1) << (p % W));
      default: begin
        lfsr = (lfsr == 0 ? 64'h1 : lfsr) ^ (longint'(seed) * 64'h9E3779B97F4A7C15);
        lfsr = lfsr ^ (lfsr << 13); lfsr = lfsr ^ (lfsr >> 7); lfsr = lfsr ^ (lfsr << 17);
        v = lfsr[W-1:0];
      end
    endcase
    return v;
  endfunction

  // one continuous-mode PCLK period: values are driven on the non-sample edge and sampled on the next selected edge
  task automatic cont_cycle(input logic [W-1:0] d, input bit hr_active, input bit vs_active);
    if (EDGE == 0) @(negedge o_clk); else @(posedge o_clk);
    o_data <= d;
    o_href <= hr_active ? ~HR_IDLE : HR_IDLE;
    o_vsync <= vs_active ? ~VS_IDLE : VS_IDLE;
    // data is valid only around the selected edge: a quarter period after it the bus carries the complement, so that a sampler on
    // the other edge sees a different value (a wrong-edge DUT is then detected)
    fork
      begin
        if (EDGE == 0) @(posedge o_clk); else @(negedge o_clk);
        #(half_ns / 2.0);
        o_data <= ~d;
      end
    join_none
  endtask

  // one gated-mode valid pixel: set values, pulse PCLK once, hold the data through the spacing gap
  task automatic gated_pixel(input logic [W-1:0] d);
    o_data = d;
    #(T_APB_NS);
    o_clk = (EDGE == 0) ? 1'b1 : 1'b0;       // selected edge
    #(T_APB_NS / 2.0);
    o_data = ~d;                              // the source registers the pixel at the selected edge; the pins carry the complement afterwards,
    #(T_APB_NS / 2.0);                        // so a sampler on the other edge (or a late sampler) is detected
    o_clk = (EDGE == 0) ? 1'b0 : 1'b1;
    #(T_APB_NS * GATE_GAP_APB);
  endtask

  task automatic set_href(input bit active);
    o_href = active ? ~HR_IDLE : HR_IDLE;
  endtask
  task automatic set_vsync(input bit active);
    o_vsync = active ? ~VS_IDLE : VS_IDLE;
  endtask

  // frame: VSYNC pulse, quiet gap, n_lines of n_pix pixels, then idle. mode 0 continuous (clock must be running), 1 gated.
  task automatic frame(input bit gated, input int n_lines, input int n_pix, input int pat, input int seed, input int hblank);
    if (!gated) begin
      repeat (4) cont_cycle('0, 0, 1);
      repeat (6) cont_cycle('0, 0, 0);
      for (int l = 0; l < n_lines; l++) begin
        for (int p = 0; p < n_pix; p++) cont_cycle(pixel(l, p, pat, seed + l), 1, 0);
        repeat (hblank) cont_cycle('0, 0, 0);
      end
      repeat (3) cont_cycle('0, 0, 0);
    end else begin
      set_vsync(1); #(T_APB_NS * VS_APB_CYC); set_vsync(0); #(T_APB_NS * 8);
      for (int l = 0; l < n_lines; l++) begin
        set_href(1); #(T_APB_NS * 4);
        for (int p = 0; p < n_pix; p++) gated_pixel(pixel(l, p, pat, seed + l));
        set_href(0); #(T_APB_NS * 4 * (hblank + 1));
      end
    end
  endtask
endmodule
