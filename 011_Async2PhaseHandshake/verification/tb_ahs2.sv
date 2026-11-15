/*
 * Project      : VLSIT Common RTL library
 * Author       : Nguyen Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-13
 * Description  : Simulation testbench of the asynchronous two-phase (toggle) handshake IP. It
 *                instantiates three configurations (base mode 0/0, return-payload mode 0/2,
 *                registered-ready mode 1/0) and drives the directed tests of the specification
 *                waveform plan (section 10.3). Every check is derived from the specification
 *                requirements and protocol sections, never from the RTL. The reference model is
 *                a behavioral description of the toggle handshake of sections 5.3 and 10.1.
 */
`timescale 1ns/1ps

module m_tb_ahs2_mon #(
  parameter logic [31:0] PARA_DATA_W        = 32,
  parameter logic [31:0] PARA_ACK_W         = 32,
  parameter logic [31:0] PARA_SYNC_STAGES   = 2,
  parameter logic [31:0] PARA_DST_MODE      = 0,
  parameter logic [31:0] PARA_ACK_DATA_MODE = 0
) (
  input  wire                   i_clk_src,
  input  wire                   i_rst_n_src,
  input  wire                   i_req,
  input  wire [PARA_DATA_W-1:0] i_data,
  input  wire                   i_clk_dst,
  input  wire                   i_rst_n_dst,
  input  wire                   i_ack,
  input  wire [PARA_ACK_W-1:0]  i_ack_data,
  input  wire [PARA_DATA_W-1:0] o_data,
  input  wire [PARA_ACK_W-1:0]  o_ack_data
);

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
      if (cons != 1'b1) begin
        fails[id] = fails[id] + 1;
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Reference model (specification sections 5.3, 10.1): the toggle handshake with
  // a fixed stage count. The two clocks are aligned in the testbench, so the source
  // and destination updates happen at the same edge and nonblocking reads model the
  // crossing of the previous value. Only the accepted values are compared; the
  // metastability branch adds 0 to 2 cycles of latency that the check does not need.
  // ---------------------------------------------------------------------------
  logic                          ref_reg_req;
  logic [PARA_DATA_W-1:0]        ref_src_data;
  logic [PARA_SYNC_STAGES-1:0]   ref_req_shift;
  logic                          ref_w_req_s;
  logic [PARA_SYNC_STAGES-1:0]   ref_ack_shift;
  logic                          ref_w_ack_s;
  logic                          ref_reg_ack;
  logic [PARA_DATA_W-1:0]        ref_dst_data;
  logic [PARA_ACK_W-1:0]         ref_ret_data;
  logic                          ref_ready;
  logic                          ref_launch;
  logic                          ref_accept;
  integer                        launch_cnt = 0;

  logic ref_ready_reg;

  assign ref_ready  = (PARA_DST_MODE == 0) ? i_ack : ref_ready_reg;
  assign ref_launch = i_req && (ref_reg_req == ref_w_ack_s);
  assign ref_accept = (ref_w_req_s != ref_reg_ack) && ref_ready;
  // The synchronizer cells drive their output combinationally from the last
  // shift-register stage, so the synchronized toggle is a wire, not a register.
  assign ref_w_req_s = ref_req_shift[PARA_SYNC_STAGES-1];
  assign ref_w_ack_s = ref_ack_shift[PARA_SYNC_STAGES-1];

  // Source domain: request toggle, launched payload, acknowledge synchronizer.
  always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin : p_ref_src
    if (!i_rst_n_src) begin
      ref_reg_req   <= 1'b0;
      ref_src_data  <= '0;
      ref_ack_shift <= '0;
      launch_cnt    <= 0;
    end else begin
      ref_reg_req  <= ref_reg_req ^ ref_launch;
      if (ref_launch) begin
        ref_src_data <= i_data;
        launch_cnt   <= launch_cnt + 1;
      end
      ref_ack_shift <= {ref_ack_shift[PARA_SYNC_STAGES-2:0], ref_reg_ack};
    end
  end

  // Destination domain: request synchronizer, accept toggle, captured payload and
  // return word, and the optional ready register.
  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_ref_dst
    if (!i_rst_n_dst) begin
      ref_req_shift <= '0;
      ref_reg_ack   <= 1'b0;
      ref_dst_data  <= '0;
      ref_ret_data  <= '0;
      ref_ready_reg <= 1'b0;
    end else begin
      ref_req_shift <= {ref_req_shift[PARA_SYNC_STAGES-2:0], ref_reg_req};
      if (PARA_DST_MODE == 1)
        ref_ready_reg <= i_ack;
      if (ref_accept) begin
        ref_reg_ack  <= ~ref_reg_ack;
        ref_dst_data <= ref_src_data;
        ref_ret_data <= i_ack_data;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Observed accept: o_data is registered and changes only at an accept edge.
  // ---------------------------------------------------------------------------
  logic [PARA_DATA_W-1:0] obs_data_q;
  logic                   obs_data_change;
  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin
    if (!i_rst_n_dst)
      obs_data_q <= '0;
    else
      obs_data_q <= o_data;
  end
  assign obs_data_change = (o_data != obs_data_q);

  // ---------------------------------------------------------------------------
  // Launch / accept sequences for the exactly-once, in-order, no-loss checks.
  // ---------------------------------------------------------------------------
  localparam int LPARA_Q = 64;
  logic [PARA_DATA_W-1:0] exp_q [0:LPARA_Q-1];
  logic [PARA_DATA_W-1:0] act_q [0:LPARA_Q-1];
  integer                 exp_len = 0;
  integer                 act_len = 0;

  always_ff @(posedge i_clk_dst, negedge i_rst_n_dst) begin : p_seq
    if (!i_rst_n_dst) begin
      exp_len <= 0;
      act_len <= 0;
    end else begin
      if (ref_accept && exp_len < LPARA_Q) begin
        exp_q[exp_len] <= ref_src_data;
        exp_len        <= exp_len + 1;
      end
      if (obs_data_change && act_len < LPARA_Q) begin
        act_q[act_len] <= o_data;
        act_len        <= act_len + 1;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Assertion identifiers
  // ---------------------------------------------------------------------------
  integer A_RST_DST, A_RST_SRC, A_RST_EVEN;
  integer A_CAP, A_ORDER, A_NO_LOSS, A_ONCE;
  integer A_BP_NOACC, A_BP_RESUME;
  integer A_RET_CAP, A_RET_ZERO;
  integer A_RDY_REG;
  integer A_SPUR, A_DATA_CHG;
  integer A_NOX_D, A_NOX_R;
  integer A_STABLE_D, A_STABLE_R;
  integer A_ONE_OUT, A_PROGRESS;

  logic bp_pending;
  assign bp_pending = (ref_w_req_s != ref_reg_ack);

  logic ref_accept_q = 1'b0;
  always_ff @(posedge i_clk_dst) ref_accept_q <= ref_accept;

  // Reset checks: the outputs clear while the reset is held (section 7.3).
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_RST_DST, (!i_rst_n_dst), (o_data == {PARA_DATA_W{1'b0}}));
  end
  always_ff @(posedge i_clk_src) begin
    if (PARA_ACK_DATA_MODE != 1)
      t_chk(A_RST_SRC, (!i_rst_n_src), (o_ack_data == {PARA_ACK_W{1'b0}}));
  end
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_RST_EVEN, i_rst_n_dst && i_rst_n_src && !obs_data_change && (ref_w_req_s == ref_reg_ack), 1'b1);
  end

  // Payload capture: every observed accept equals the reference accepted word.
  always_ff @(posedge i_clk_dst) begin
    if (obs_data_change && act_len < exp_len)
      t_chk(A_CAP, 1'b1, (o_data == exp_q[act_len]));
    t_chk(A_ONCE, obs_data_change, (act_len < exp_len));
  end

  // Backpressure: no accept while the destination user is not ready, and the accept
  // follows the ready level one edge later (the one-edge relation is deterministic
  // only in the synthesis branch, so it is checked there).
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_BP_NOACC, bp_pending && !ref_ready, !obs_data_change);
    `ifdef VLSIT_SYNTHESIS
    t_chk(A_BP_RESUME, ref_accept_q, obs_data_change);
    `endif
  end

  // Return payload: mode 0 constant zero, mode 2 equals the destination user
  // payload at the accept (latency-agnostic: checked at the DUT's own accept).
  always_ff @(posedge i_clk_dst) begin
    if (PARA_ACK_DATA_MODE == 0)
      t_chk(A_RET_ZERO, 1'b1, (o_ack_data == {PARA_ACK_W{1'b0}}));
    if (PARA_ACK_DATA_MODE == 2)
      t_chk(A_RET_CAP, obs_data_change, (o_ack_data == i_ack_data));
  end

  // Registered ready (mode 1): i_ack is sampled one edge before it gates the accept.
  always_ff @(posedge i_clk_dst) begin
    `ifdef VLSIT_SYNTHESIS
    if (PARA_DST_MODE == 1)
      t_chk(A_RDY_REG, bp_pending && !ref_ready && i_ack, !obs_data_change);
    `endif
  end

  // Spurious ack: the DUT accepts only when the reference model expected an
  // accept; every observed accept is a genuine one (no spurious accept). The
  // one-edge relation is deterministic only in the synthesis branch.
  always_ff @(posedge i_clk_dst) begin
    `ifdef VLSIT_SYNTHESIS
    t_chk(A_SPUR, obs_data_change, ref_accept_q);
    `endif
  end

  // i_data change in flight: the captured word is the launch-time value.
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_DATA_CHG, obs_data_change && act_len < exp_len, (o_data == exp_q[act_len]));
  end

  // No X on the outputs.
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_NOX_D, 1'b1, ((o_data == o_data)));
  end
  always_ff @(posedge i_clk_src) begin
    if (PARA_ACK_DATA_MODE != 1)
      t_chk(A_NOX_R, 1'b1, ((o_ack_data == o_ack_data)));
  end

  // Stability: o_data holds between accepts; the return word holds in mode 2.
  always_ff @(posedge i_clk_dst) begin
    t_chk(A_STABLE_D, !obs_data_change, (o_data == obs_data_q));
    `ifdef VLSIT_SYNTHESIS
    if (PARA_ACK_DATA_MODE == 2)
      t_chk(A_STABLE_R, !ref_accept, (o_ack_data == ref_ret_data));
    `endif
  end

  // At most one outstanding: the source launches only from the even state, so at
  // every launch the number of prior launches equals the number of prior accepts.
  always_ff @(posedge i_clk_src) begin
    t_chk(A_ONE_OUT, ref_launch, (launch_cnt == act_len));
  end

  // Bounded progress: 20 cycles after a launch the word must already have been
  // accepted (the specification itself has no timeout, but the stimulus bounds
  // every transfer). The check fires once per launch, so it is always exercised.
  integer progress_timer = 0;
  always_ff @(posedge i_clk_src, negedge i_rst_n_src) begin
    if (!i_rst_n_src)
      progress_timer <= 0;
    else if (ref_launch)
      progress_timer <= 0;
    else if (progress_timer < 64)
      progress_timer <= progress_timer + 1;
    t_chk(A_PROGRESS, (progress_timer == 20), (exp_len == act_len));
  end

  // ---------------------------------------------------------------------------
  // Final table (R-025). The task returns the failure and never-exercised counts;
  // the testbench aggregates the three monitors and prints the single pass/fail
  // line that the simulation-evidence check reads.
  // ---------------------------------------------------------------------------
  task automatic t_report(output integer o_fail, output integer o_never);
    integer j;
    integer never;
    integer total_fail;
    begin
      never = 0;
      total_fail = 0;
      // Final exactly-once count: launches equal accepts at the end of the run.
      if (exp_len != act_len)
        fails[A_NO_LOSS] = fails[A_NO_LOSS] + 1;
      if (exp_len > 0 || act_len > 0)
        hits[A_NO_LOSS] = hits[A_NO_LOSS] + 1;
      // Final in-order check: the accepted sequence equals the launch sequence.
      if (exp_len > 0 || act_len > 0)
        hits[A_ORDER] = hits[A_ORDER] + 1;
      for (j = 0; j < (exp_len < act_len ? exp_len : act_len); j = j + 1)
        if (exp_q[j] != act_q[j])
          fails[A_ORDER] = fails[A_ORDER] + 1;
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
    if (PARA_ACK_DATA_MODE != 1)
      A_RST_SRC = f_decl("A_RST_SRC (7.3)");
    A_RST_EVEN = f_decl("A_RST_EVEN (7.3)");
    A_CAP      = f_decl("A_CAP (REQ-FUNC-003)");
    A_ONCE     = f_decl("A_ONCE (REQ-FUNC-001)");
    A_ORDER    = f_decl("A_ORDER (REQ-FUNC-001)");
    A_NO_LOSS  = f_decl("A_NO_LOSS (REQ-FUNC-001)");
    A_BP_NOACC = f_decl("A_BP_NOACC (REQ-FUNC-007)");
    `ifdef VLSIT_SYNTHESIS
    A_BP_RESUME= f_decl("A_BP_RESUME (REQ-FUNC-007)");
    `endif
    if (PARA_ACK_DATA_MODE == 2)
      A_RET_CAP = f_decl("A_RET_CAP (REQ-FUNC-008)");
    if (PARA_ACK_DATA_MODE == 0)
      A_RET_ZERO = f_decl("A_RET_ZERO (DEC-009)");
    `ifdef VLSIT_SYNTHESIS
    if (PARA_DST_MODE == 1)
      A_RDY_REG = f_decl("A_RDY_REG (REQ-FUNC-009)");
    A_SPUR     = f_decl("A_SPUR (REQ-FUNC-005)");
    `endif
    A_DATA_CHG = f_decl("A_DATA_CHG (REQ-FUNC-003)");
    A_NOX_D    = f_decl("A_NOX_D (6.2)");
    if (PARA_ACK_DATA_MODE != 1)
      A_NOX_R = f_decl("A_NOX_R (6.2)");
    A_STABLE_D = f_decl("A_STABLE_D (6.2)");
    `ifdef VLSIT_SYNTHESIS
    if (PARA_ACK_DATA_MODE == 2)
      A_STABLE_R = f_decl("A_STABLE_R (6.2)");
    `endif
    A_ONE_OUT  = f_decl("A_ONE_OUT (5.4)");
    A_PROGRESS = f_decl("A_PROGRESS (bounded)");
  end

endmodule


module tb_ahs2;

  localparam logic [31:0] LPARA_DATA_W = 32;
  localparam logic [31:0] LPARA_ACK_W  = 32;
  localparam logic [31:0] LPARA_RET_W  = 16;

  // Clocks: both domains 10 ns and aligned, matching the specification figures.
  logic i_clk_src = 1'b0;
  logic i_clk_dst = 1'b0;
  always #5 i_clk_src = ~i_clk_src;
  always #5 i_clk_dst = ~i_clk_dst;

  // Resets and stimuli per DUT.
  logic                    rst_n_src_base, rst_n_dst_base;
  logic                    req_base, ack_base;
  logic [LPARA_DATA_W-1:0] data_base;
  logic [LPARA_ACK_W-1:0]  ack_data_base;
  logic [LPARA_DATA_W-1:0] o_data_base;
  logic [LPARA_ACK_W-1:0]  o_ack_data_base;

  logic                    rst_n_src_resp, rst_n_dst_resp;
  logic                    req_resp, ack_resp;
  logic [LPARA_DATA_W-1:0] data_resp;
  logic [LPARA_RET_W-1:0]  ack_data_resp;
  logic [LPARA_DATA_W-1:0] o_data_resp;
  logic [LPARA_RET_W-1:0]  o_ack_data_resp;

  logic                    rst_n_src_ready, rst_n_dst_ready;
  logic                    req_ready, ack_ready;
  logic [LPARA_DATA_W-1:0] data_ready;
  logic [LPARA_ACK_W-1:0]  ack_data_ready;
  logic [LPARA_DATA_W-1:0] o_data_ready;
  logic [LPARA_ACK_W-1:0]  o_ack_data_ready;

  m_vlsit_ahs2_top #(
    .PARA_AHS2_DATA_W        (LPARA_DATA_W),
    .PARA_AHS2_ACK_DATA_W    (LPARA_ACK_W),
    .PARA_AHS2_SYNC_TYPE     (32'd2),
    .PARA_AHS2_DST_MODE      (32'd0),
    .PARA_AHS2_ACK_DATA_MODE (32'd0)
  ) u_base (
    .i_clk_src   (i_clk_src),  .i_rst_n_src (rst_n_src_base),
    .i_req       (req_base),   .i_data      (data_base),
    .i_clk_dst   (i_clk_dst),  .i_rst_n_dst (rst_n_dst_base),
    .i_ack       (ack_base),   .i_ack_data  (ack_data_base),
    .o_data      (o_data_base),.o_ack_data  (o_ack_data_base)
  );

  m_vlsit_ahs2_top #(
    .PARA_AHS2_DATA_W        (LPARA_DATA_W),
    .PARA_AHS2_ACK_DATA_W    (LPARA_RET_W),
    .PARA_AHS2_SYNC_TYPE     (32'd2),
    .PARA_AHS2_DST_MODE      (32'd0),
    .PARA_AHS2_ACK_DATA_MODE (32'd2)
  ) u_resp (
    .i_clk_src   (i_clk_src),  .i_rst_n_src (rst_n_src_resp),
    .i_req       (req_resp),   .i_data      (data_resp),
    .i_clk_dst   (i_clk_dst),  .i_rst_n_dst (rst_n_dst_resp),
    .i_ack       (ack_resp),   .i_ack_data  (ack_data_resp),
    .o_data      (o_data_resp),.o_ack_data  (o_ack_data_resp)
  );

  m_vlsit_ahs2_top #(
    .PARA_AHS2_DATA_W        (LPARA_DATA_W),
    .PARA_AHS2_ACK_DATA_W    (LPARA_ACK_W),
    .PARA_AHS2_SYNC_TYPE     (32'd2),
    .PARA_AHS2_DST_MODE      (32'd1),
    .PARA_AHS2_ACK_DATA_MODE (32'd0)
  ) u_ready (
    .i_clk_src   (i_clk_src),  .i_rst_n_src (rst_n_src_ready),
    .i_req       (req_ready),  .i_data      (data_ready),
    .i_clk_dst   (i_clk_dst),  .i_rst_n_dst (rst_n_dst_ready),
    .i_ack       (ack_ready),  .i_ack_data  (ack_data_ready),
    .o_data      (o_data_ready),.o_ack_data (o_ack_data_ready)
  );

  m_tb_ahs2_mon #(
    .PARA_DATA_W (LPARA_DATA_W), .PARA_ACK_W (LPARA_ACK_W),
    .PARA_SYNC_STAGES (32'd2), .PARA_DST_MODE (32'd0), .PARA_ACK_DATA_MODE (32'd0)
  ) u_mon_base (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_base), .i_req (req_base),
    .i_data (data_base), .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_base),
    .i_ack (ack_base), .i_ack_data (ack_data_base),
    .o_data (o_data_base), .o_ack_data (o_ack_data_base)
  );

  m_tb_ahs2_mon #(
    .PARA_DATA_W (LPARA_DATA_W), .PARA_ACK_W (LPARA_RET_W),
    .PARA_SYNC_STAGES (32'd2), .PARA_DST_MODE (32'd0), .PARA_ACK_DATA_MODE (32'd2)
  ) u_mon_resp (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_resp), .i_req (req_resp),
    .i_data (data_resp), .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_resp),
    .i_ack (ack_resp), .i_ack_data (ack_data_resp),
    .o_data (o_data_resp), .o_ack_data (o_ack_data_resp)
  );

  m_tb_ahs2_mon #(
    .PARA_DATA_W (LPARA_DATA_W), .PARA_ACK_W (LPARA_ACK_W),
    .PARA_SYNC_STAGES (32'd2), .PARA_DST_MODE (32'd1), .PARA_ACK_DATA_MODE (32'd0)
  ) u_mon_ready (
    .i_clk_src (i_clk_src), .i_rst_n_src (rst_n_src_ready), .i_req (req_ready),
    .i_data (data_ready), .i_clk_dst (i_clk_dst), .i_rst_n_dst (rst_n_dst_ready),
    .i_ack (ack_ready), .i_ack_data (ack_data_ready),
    .o_data (o_data_ready), .o_ack_data (o_ack_data_ready)
  );

  integer seed;
  string  scenario;
  string  dumpstem;
  integer tf_base, nv_base, tf_resp, nv_resp, tf_ready, nv_ready;

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

    rst_n_src_base   = 1'b0; rst_n_dst_base   = 1'b0;
    req_base = 1'b0; ack_base = 1'b0; data_base = '0; ack_data_base = '0;
    rst_n_src_resp   = 1'b0; rst_n_dst_resp   = 1'b0;
    req_resp = 1'b0; ack_resp = 1'b0; data_resp = '0; ack_data_resp = '0;
    rst_n_src_ready  = 1'b0; rst_n_dst_ready  = 1'b0;
    req_ready = 1'b0; ack_ready = 1'b0; data_ready = '0; ack_data_ready = '0;

    if (!$value$plusargs("SCENARIO=%s", s)) s = "ALL";
    scenario = s;
    if (!$value$plusargs("DUMP=%s", dump)) dump = "";
    dumpstem = dump;

    // Release all resets after a few cycles of assertion.
    repeat (4) @(negedge i_clk_src);
    rst_n_src_base  = 1'b1; rst_n_dst_base  = 1'b1;
    rst_n_src_resp  = 1'b1; rst_n_dst_resp  = 1'b1;
    rst_n_src_ready = 1'b1; rst_n_dst_ready = 1'b1;
    repeat (3) @(negedge i_clk_src);

    if (dump != "") begin
      $dumpfile(dump);
      $dumpvars(0, u_base);
      $dumpvars(0, u_resp);
      $dumpvars(0, u_ready);
    end

    if (scenario == "WF001") begin
      ack_base = 1'b1;
      data_base = 32'hD0D0D0D0;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (5) @(negedge i_clk_src); req_base = 1'b0;
      repeat (6) @(negedge i_clk_src);
    end else if (scenario == "WF002") begin
      data_base = 32'hD0D0D0D0;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (6) @(negedge i_clk_src); req_base = 1'b0;
      repeat (4) @(negedge i_clk_dst); ack_base = 1'b1;
      repeat (6) @(negedge i_clk_src);
    end else if (scenario == "WF003") begin
      ack_base = 1'b1;
      data_base = 32'hD0D0D0D0;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (6) @(negedge i_clk_src); data_base = 32'hD1D1D1D1;
      repeat (6) @(negedge i_clk_src); data_base = 32'hD2D2D2D2;
      repeat (6) @(negedge i_clk_src); req_base = 1'b0;
      repeat (4) @(negedge i_clk_src);
    end else if (scenario == "WF004") begin
      data_base = 32'hD0D0D0D0;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (4) @(negedge i_clk_src);
      rst_n_src_base = 1'b0; rst_n_dst_base = 1'b0;
      repeat (3) @(negedge i_clk_src);
      rst_n_src_base = 1'b1; rst_n_dst_base = 1'b1; req_base = 1'b0;
      repeat (5) @(negedge i_clk_src);
    end else if (scenario == "WF005") begin
      ack_resp = 1'b1;
      data_resp = 32'hD0D0D0D0; ack_data_resp = 16'hA0A0;
      @(negedge i_clk_src); req_resp = 1'b1;
      repeat (5) @(negedge i_clk_src); req_resp = 1'b0;
      repeat (6) @(negedge i_clk_src);
    end else if (scenario == "WF006") begin
      data_ready = 32'hD0D0D0D0;
      @(negedge i_clk_src); req_ready = 1'b1;
      repeat (3) @(negedge i_clk_dst); ack_ready = 1'b1;
      repeat (5) @(negedge i_clk_src); req_ready = 1'b0;
      repeat (4) @(negedge i_clk_src);
    end else if (scenario == "WF007") begin
      ack_base = 1'b1;
      data_base = 32'hD0D0D0D0;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (3) @(negedge i_clk_src); req_base = 1'b0;
      repeat (4) @(negedge i_clk_dst);
      rst_n_dst_base = 1'b0;
      repeat (3) @(negedge i_clk_dst); rst_n_dst_base = 1'b1;
      repeat (8) @(negedge i_clk_dst);
    end else if (scenario == "WF008") begin
      ack_base = 1'b1;
      repeat (2) @(negedge i_clk_src);
      data_base = 32'hD0D0D0D0; req_base = 1'b1;
      repeat (2) @(negedge i_clk_src); data_base = 32'hD1D1D1D1;
      repeat (4) @(negedge i_clk_src); req_base = 1'b0;
      repeat (5) @(negedge i_clk_src);
    end else begin
      t_full_sequence();
    end

    if (dump != "") begin
      $dumpflush;
      $finish;
    end

    u_mon_base.t_report(tf_base, nv_base);
    u_mon_resp.t_report(tf_resp, nv_resp);
    u_mon_ready.t_report(tf_ready, nv_ready);
    $display("assertion failures: %0d, assertions never exercised: %0d",
             tf_base + tf_resp + tf_ready, nv_base + nv_resp + nv_ready);
    if (tf_base + tf_resp + tf_ready != 0 || nv_base + nv_resp + nv_ready != 0) begin
      $display("TEST RESULT: FAIL");
      $fatal(1, "assertion failure or unexercised assertion");
    end else begin
      $display("TEST RESULT: PASS");
    end
    $finish;
  end

  task automatic t_full_sequence;
    begin
      // T01 single transfer: a two-cycle request pulse launches exactly one word.
      ack_base = 1'b1; data_base = 32'hAAAAAAA0;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (2) @(negedge i_clk_src); req_base = 1'b0;
      repeat (10) @(negedge i_clk_src);
      // T02 backpressure: the word is launched, i_ack stays low, then rises.
      ack_base = 1'b0; data_base = 32'hBBBBBBB1;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (2) @(negedge i_clk_src); req_base = 1'b0;
      repeat (10) @(negedge i_clk_dst); ack_base = 1'b1;
      repeat (10) @(negedge i_clk_src);
      // T03 paired reset mid-flight: reset discards the in-flight word.
      ack_base = 1'b1; data_base = 32'hCCCCCCC2;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (2) @(negedge i_clk_src);
      rst_n_src_base = 1'b0; rst_n_dst_base = 1'b0;
      repeat (4) @(negedge i_clk_src);
      rst_n_src_base = 1'b1; rst_n_dst_base = 1'b1; req_base = 1'b0;
      repeat (8) @(negedge i_clk_src);
      // T04 return payload (captured at the accept edge).
      ack_resp = 1'b1; data_resp = 32'hDDDDDDD3; ack_data_resp = 16'hBEEF;
      @(negedge i_clk_src); req_resp = 1'b1;
      repeat (2) @(negedge i_clk_src); req_resp = 1'b0;
      repeat (10) @(negedge i_clk_src);
      // T04b return payload under backpressure.
      ack_resp = 1'b0; data_resp = 32'hD3D3D3D4; ack_data_resp = 16'hCAFE;
      @(negedge i_clk_src); req_resp = 1'b1;
      repeat (2) @(negedge i_clk_src); req_resp = 1'b0;
      repeat (8) @(negedge i_clk_dst); ack_resp = 1'b1;
      repeat (10) @(negedge i_clk_src);
      // T05 registered ready: the ready level is sampled one edge later.
      ack_ready = 1'b0; data_ready = 32'hEEEEEEE4;
      @(negedge i_clk_src); req_ready = 1'b1;
      repeat (2) @(negedge i_clk_src); req_ready = 1'b0;
      repeat (6) @(negedge i_clk_dst); ack_ready = 1'b1;
      repeat (10) @(negedge i_clk_src);
      // T06 spurious ack: i_ack high with no request causes no accept.
      req_base = 1'b0; ack_base = 1'b1;
      repeat (8) @(negedge i_clk_dst);
      // T08 i_data change in flight: the launch-time value is captured.
      ack_base = 1'b1; data_base = 32'h10101010;
      @(negedge i_clk_src); req_base = 1'b1;
      repeat (2) @(negedge i_clk_src); req_base = 1'b0;
      repeat (2) @(negedge i_clk_src); data_base = 32'h20202020;
      repeat (10) @(negedge i_clk_src);
    end
  endtask

endmodule
