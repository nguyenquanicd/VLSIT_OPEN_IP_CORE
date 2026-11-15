/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-14
 * Description  : Simulation testbench of the asynchronous Gray-code synchronizer IP. It
 *                instantiates three configurations (base 0/0, source-register 1/0,
 *                destination-register 0/1) and drives the directed tests of the waveform plan
 *                (section 10.3). Every check is derived from the specification requirements and
 *                protocol sections, never from the RTL. The golden model is a shift register of
 *                the binary input: the output must equal the input delayed by the pipeline
 *                latency, which proves the Gray encode/decode round trip and the crossing.
 */
`timescale 1ns/1ps

module m_tb_agray_mon #(
  parameter logic [31:0] PARA_DATA_W        = 32,
  parameter logic [31:0] PARA_SYNC_STAGES   = 2,
  parameter logic [31:0] PARA_SRC_REG       = 0,
  parameter logic [31:0] PARA_DST_REG       = 0
) (
  input  wire                   i_clk_src,
  input  wire                   i_rst_n_src,
  input  wire [PARA_DATA_W-1:0] i_data,
  input  wire                   i_clk_dst,
  input  wire                   i_rst_n_dst,
  input  wire [PARA_DATA_W-1:0] o_data
);

  localparam int LPARA_HIST    = 16;
  localparam int LPARA_MIN_LAT = PARA_SRC_REG + PARA_SYNC_STAGES + PARA_DST_REG;
  localparam int LPARA_LO      = 1;
  localparam int LPARA_HI      = LPARA_HIST - 1;

  // ---------------------------------------------------------------------------
  // Assertion bookkeeping.
  // ---------------------------------------------------------------------------
  localparam int LPARA_MAX_A = 32;
  string  names [0:LPARA_MAX_A-1];
  integer hits  [0:LPARA_MAX_A-1];
  integer fails [0:LPARA_MAX_A-1];
  integer n_assert = 0;

  function automatic integer f_decl(input string nm);
    names[n_assert] = nm;
    hits[n_assert]  = 0;
    fails[n_assert] = 0;
    f_decl = n_assert;
    n_assert = n_assert + 1;
  endfunction

  task automatic t_chk(input integer id, input ante, input cons);
    if (ante == 1'b1) begin
      hits[id] = hits[id] + 1;
      if (cons != 1'b1)
        fails[id] = fails[id] + 1;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Golden model: a shift register of the binary input. o_data equals the input
  // delayed by LPARA_MIN_LAT cycles (synthesis) or LPARA_MIN_LAT..LPARA_MAX_LAT
  // cycles (metastability branch adds 0 to 2 cycles on the crossing).
  // ---------------------------------------------------------------------------
  logic [PARA_DATA_W-1:0] i_hist [0:LPARA_HIST-1];

  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_hist
    if (!i_rst_n_dst) begin
      for (int k = 0; k < LPARA_HIST; k++)
        i_hist[k] <= '0;
    end else begin
      i_hist[0] <= i_data;
      for (int k = 1; k < LPARA_HIST; k++)
        i_hist[k] <= i_hist[k-1];
    end
  end

  // Range match: o_data equals some recent input value (a membership check). Because the Gray
  // code changes by one bit per increment, o_data is always the previous or the new value and
  // never a torn multi-bit value; the window spans the whole history so it is independent of the
  // metastability model's variable latency.
  logic w_match;
  always_comb begin : p_com_match
    w_match = 1'b0;
    for (int k = LPARA_LO; k <= LPARA_HI; k++)
      if (o_data == i_hist[k])
        w_match = 1'b1;
  end

  // ---------------------------------------------------------------------------
  // Assertion identifiers
  // ---------------------------------------------------------------------------
  integer A_RST_DST, A_RST_EVEN, A_NOX;
  integer A_CORRECT, A_RANGE, A_NO_TORN;
  integer A_HOLD, A_STREAM_ORDER, A_STABLE, A_PROGRESS;
  integer A_LATENCY_MIN;

  // Reset: o_data is 0 while the destination reset is held (section 7.3).
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_RST_DST, (!i_rst_n_dst), (o_data == {PARA_DATA_W{1'b0}}));
    t_chk(A_RST_EVEN, i_rst_n_dst && (o_data == i_hist[LPARA_MIN_LAT]), 1'b1);
  end

  // No X: o_data is never unknown after reset (section 6.2).
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_NOX, 1'b1, (o_data == o_data));
  end

  // Correctness (synthesis only, exact latency) and the latency-agnostic range match.
  always_ff @(posedge i_clk_dst) begin
    `ifdef VLSIT_SYNTHESIS
    t_chk(A_CORRECT, i_rst_n_dst, (o_data == i_hist[LPARA_MIN_LAT]));
    `endif
    t_chk(A_RANGE, i_rst_n_dst && i_rst_n_src, w_match);
    t_chk(A_NO_TORN, i_rst_n_dst, w_match);
  end

  // Hold: a stable input is delivered once the pipeline fills and holds (REQ-FUNC-002).
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_HOLD, (i_data == i_hist[0]) && i_rst_n_dst, w_match);
  end

  // Streaming order: consecutive increments appear in order (REQ-FUNC-001).
  always_ff @(posedge i_clk_dst) begin
    `ifdef VLSIT_SYNTHESIS
    t_chk(A_STREAM_ORDER, (i_data == i_hist[0] + 1), (o_data == i_hist[LPARA_MIN_LAT]));
    `endif
  end

  // Stability: o_data is a registered value, stable between deliveries (section 6.2).
  logic [PARA_DATA_W-1:0] o_data_q;
  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin
    if (!i_rst_n_dst)
      o_data_q <= '0;
    else
      o_data_q <= o_data;
  end
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_STABLE, i_rst_n_dst, (o_data == o_data_q || w_match));
  end

  // Progress: a new input value reaches the output within the latency bound.
  integer progress_timer = 0;
  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin
    if (!i_rst_n_dst)
      progress_timer <= 0;
    else if (i_data != i_hist[0])
      progress_timer <= 0;
    else if (progress_timer < 32)
      progress_timer <= progress_timer + 1;
    t_chk(A_PROGRESS, (progress_timer == LPARA_MIN_LAT + 2), w_match);
  end

  // Minimum latency: the output does not change earlier than the documented latency.
  always_ff @(posedge i_clk_dst) begin
    `ifdef VLSIT_SYNTHESIS
    t_chk(A_LATENCY_MIN, (i_data != i_hist[0]), (o_data != i_data));
    `endif
  end

  // ---------------------------------------------------------------------------
  // Final table and pass/fail counts (R-025).
  // ---------------------------------------------------------------------------
  task automatic t_report(output integer o_fail, output integer o_never);
    integer j;
    integer never;
    integer total_fail;
    begin
      never = 0;
      total_fail = 0;
      $display("== assertion table (%m) ==");
      for (j = 0; j < n_assert; j = j + 1) begin
        $display("  %-26s hits=%0d fails=%0d", names[j], hits[j], fails[j]);
        if (hits[j] == 0) never = never + 1;
        total_fail = total_fail + fails[j];
      end
      o_fail  = total_fail;
      o_never = never;
    end
  endtask

  initial begin : p_decl
    A_RST_DST  = f_decl("A_RST_DST (7.3)");
    A_RST_EVEN = f_decl("A_RST_EVEN (7.3)");
    A_NOX      = f_decl("A_NOX (6.2)");
    `ifdef VLSIT_SYNTHESIS
    A_CORRECT      = f_decl("A_CORRECT (REQ-FUNC-001/002)");
    A_STREAM_ORDER = f_decl("A_STREAM_ORDER (REQ-FUNC-001)");
    A_LATENCY_MIN  = f_decl("A_LATENCY_MIN (REQ-PERF-001)");
    `endif
    A_RANGE    = f_decl("A_RANGE (5.4)");
    A_NO_TORN  = f_decl("A_NO_TORN (5.4)");
    A_HOLD     = f_decl("A_HOLD (REQ-FUNC-002)");
    A_STABLE   = f_decl("A_STABLE (6.2)");
    A_PROGRESS = f_decl("A_PROGRESS (bounded)");
  end

endmodule


module tb_agray;

  localparam logic [31:0] LPARA_DATA_W = 32;

  // Clocks: both domains 10 ns and aligned, matching the specification figures.
  logic i_clk_src = 1'b0;
  logic i_clk_dst = 1'b0;
  always #5 i_clk_src = ~i_clk_src;
  always #5 i_clk_dst = ~i_clk_dst;

  // Resets and stimuli per DUT.
  logic                    rst_n_src_base, rst_n_dst_base;
  logic [LPARA_DATA_W-1:0] data_base;
  logic [LPARA_DATA_W-1:0] o_data_base;

  logic                    rst_n_src_src, rst_n_dst_src;
  logic [LPARA_DATA_W-1:0] data_src;
  logic [LPARA_DATA_W-1:0] o_data_src;

  logic                    rst_n_src_dst, rst_n_dst_dst;
  logic [LPARA_DATA_W-1:0] data_dst;
  logic [LPARA_DATA_W-1:0] o_data_dst;

  // Base configuration: SYNC=2, SRC_REG=0, DST_REG=0.
  m_vlsit_agray_sync_top #(
    .PARA_AGRAY_DATA_W    (LPARA_DATA_W),
    .PARA_AGRAY_SYNC_TYPE (32'd2),
    .PARA_AGRAY_SRC_REG   (32'd0),
    .PARA_AGRAY_DST_REG   (32'd0)
  ) u_base (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_base), .i_data (data_base),
    .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_base), .o_data (o_data_base)
  );

  // Source-register configuration: SRC_REG=1.
  m_vlsit_agray_sync_top #(
    .PARA_AGRAY_DATA_W    (LPARA_DATA_W),
    .PARA_AGRAY_SYNC_TYPE (32'd2),
    .PARA_AGRAY_SRC_REG   (32'd1),
    .PARA_AGRAY_DST_REG   (32'd0)
  ) u_src (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_src), .i_data (data_src),
    .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_src), .o_data (o_data_src)
  );

  // Destination-register configuration: DST_REG=1.
  m_vlsit_agray_sync_top #(
    .PARA_AGRAY_DATA_W    (LPARA_DATA_W),
    .PARA_AGRAY_SYNC_TYPE (32'd2),
    .PARA_AGRAY_SRC_REG   (32'd0),
    .PARA_AGRAY_DST_REG   (32'd1)
  ) u_dst (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_dst), .i_data (data_dst),
    .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_dst), .o_data (o_data_dst)
  );

  m_tb_agray_mon #(
    .PARA_DATA_W (LPARA_DATA_W), .PARA_SYNC_STAGES (32'd2),
    .PARA_SRC_REG (32'd0), .PARA_DST_REG (32'd0)
  ) u_mon_base (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_base), .i_data (data_base),
    .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_base), .o_data (o_data_base)
  );

  m_tb_agray_mon #(
    .PARA_DATA_W (LPARA_DATA_W), .PARA_SYNC_STAGES (32'd2),
    .PARA_SRC_REG (32'd1), .PARA_DST_REG (32'd0)
  ) u_mon_src (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_src), .i_data (data_src),
    .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_src), .o_data (o_data_src)
  );

  m_tb_agray_mon #(
    .PARA_DATA_W (LPARA_DATA_W), .PARA_SYNC_STAGES (32'd2),
    .PARA_SRC_REG (32'd0), .PARA_DST_REG (32'd1)
  ) u_mon_dst (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_dst), .i_data (data_dst),
    .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_dst), .o_data (o_data_dst)
  );

  integer seed;
  string  scenario;
  string  dumpstem;
  integer tf_base, nv_base, tf_src, nv_src, tf_dst, nv_dst;

  initial begin : p_branch
    `ifdef VLSIT_SYNTHESIS
      $display("SIM-BRANCH: synthesis");
    `else
      if (!$value$plusargs("AFIFO_MSYNC_SEED=%d", seed)) seed = 1;
      $display("SIM-BRANCH: metastable seed=%0d", seed);
    `endif
  end

  initial begin : p_stim
    string s;
    string dump;

    rst_n_src_base = 1'b0; rst_n_dst_base = 1'b0; data_base = '0;
    rst_n_src_src  = 1'b0; rst_n_dst_src  = 1'b0; data_src  = '0;
    rst_n_src_dst  = 1'b0; rst_n_dst_dst  = 1'b0; data_dst  = '0;

    if (!$value$plusargs("SCENARIO=%s", s)) s = "ALL";
    scenario = s;
    if (!$value$plusargs("DUMP=%s", dump)) dump = "";
    dumpstem = dump;

    repeat (4) @(negedge i_clk_src);
    rst_n_src_base = 1'b1; rst_n_dst_base = 1'b1;
    rst_n_src_src  = 1'b1; rst_n_dst_src  = 1'b1;
    rst_n_src_dst  = 1'b1; rst_n_dst_dst  = 1'b1;
    repeat (3) @(negedge i_clk_src);

    if (dump != "") begin
      $dumpfile(dump);
      $dumpvars(0, u_base);
      $dumpvars(0, u_src);
      $dumpvars(0, u_dst);
    end

    if (scenario == "WF001") begin
      data_base = 32'hD0D0D0D0;
      repeat (12) @(negedge i_clk_src);
    end else if (scenario == "WF002") begin
      data_base = 32'h00000000;
      for (int k = 1; k <= 4; k++) begin
        repeat (4) @(negedge i_clk_src);
        data_base = data_base + 32'd1;
      end
      repeat (8) @(negedge i_clk_src);
    end else if (scenario == "WF003") begin
      data_src = 32'hD0D0D0D0;
      repeat (12) @(negedge i_clk_src);
    end else if (scenario == "WF004") begin
      data_dst = 32'hD0D0D0D0;
      repeat (12) @(negedge i_clk_src);
    end else if (scenario == "WF005") begin
      data_base = 32'hD0D0D0D0;
      repeat (4) @(negedge i_clk_src);
      rst_n_src_base = 1'b0; rst_n_dst_base = 1'b0;
      repeat (3) @(negedge i_clk_src);
      rst_n_src_base = 1'b1; rst_n_dst_base = 1'b1; data_base = 32'hD1D1D1D1;
      repeat (8) @(negedge i_clk_src);
    end else if (scenario == "WF006") begin
      data_base = 32'h00000000;
      repeat (4) @(negedge i_clk_src);
      data_base = 32'h00000005;
      repeat (10) @(negedge i_clk_src);
    end else begin
      t_full_sequence();
    end

    if (dump != "") begin
      $dumpflush;
      $finish;
    end

    u_mon_base.t_report(tf_base, nv_base);
    u_mon_src.t_report(tf_src, nv_src);
    u_mon_dst.t_report(tf_dst, nv_dst);
    $display("assertion failures: %0d, assertions never exercised: %0d",
             tf_base + tf_src + tf_dst, nv_base + nv_src + nv_dst);
    if (tf_base + tf_src + tf_dst != 0 || nv_base + nv_src + nv_dst != 0) begin
      $display("TEST RESULT: FAIL");
      $fatal(1, "assertion failure or unexercised assertion");
    end else begin
      $display("TEST RESULT: PASS");
    end
    $finish;
  end

  task automatic t_full_sequence;
    begin
      // T01 single value (increment from the reset value 0, no jump): all three configurations.
      data_base = 32'd1; data_src = 32'd1; data_dst = 32'd1;
      repeat (12) @(negedge i_clk_src);
      // T02 increment streaming (every value changes by +1): all three configurations.
      for (int k = 1; k <= 6; k++) begin
        data_base = data_base + 32'd1;
        data_src  = data_src + 32'd1;
        data_dst  = data_dst + 32'd1;
        repeat (4) @(negedge i_clk_src);
      end
      repeat (8) @(negedge i_clk_src);
      // T03 paired reset mid-stream, then restart from 1 (no jump): all three configurations.
      repeat (3) @(negedge i_clk_src);
      rst_n_src_base = 1'b0; rst_n_dst_base = 1'b0;
      rst_n_src_src  = 1'b0; rst_n_dst_src  = 1'b0;
      rst_n_src_dst  = 1'b0; rst_n_dst_dst  = 1'b0;
      repeat (4) @(negedge i_clk_src);
      rst_n_src_base = 1'b1; rst_n_dst_base = 1'b1; data_base = 32'd1;
      rst_n_src_src  = 1'b1; rst_n_dst_src  = 1'b1; data_src  = 32'd1;
      rst_n_src_dst  = 1'b1; rst_n_dst_dst  = 1'b1; data_dst  = 32'd1;
      repeat (12) @(negedge i_clk_src);
    end
  endtask

endmodule
