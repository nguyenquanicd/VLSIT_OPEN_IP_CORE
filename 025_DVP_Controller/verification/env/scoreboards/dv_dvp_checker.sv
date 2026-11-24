// dv_dvp_checker.sv - passive monitors, HDS-derived reference model, scoreboard and checkers for m_dvp_controller.
// AI-generated candidate (R-117): derived from HDS v0.3, CSR v1.1 and APB4 clauses; reads only the public DUT pins.
// Observes: DVP pins, APB4 pins, o_dma_req/i_dma_ack and the reset. Never drives a signal (R-124).
// Windows (Q-ENV-2): behaviour the HDS calls CDC-latency dependent is checked for monotonic consistency and
// eventual agreement inside WIN_APB APB cycles plus WIN_PCLK PCLK cycles; the DUT is never asked for exact latency.
// Timeout (Q-ENV-1): an empty FIFO_DATA read errors in access cycle 1 for N = 0 or 1 and in access cycle N for N > 1.
`timescale 1ns/1ps
module dv_dvp_checker #(
  parameter int W = 8,
  parameter int EDGE = 0,
  parameter int VS_ACT = 1,
  parameter int HR_ACT = 1,
  parameter int DEPTH = 8,
  parameter logic [15:0] FIFO_ADDR = 16'h0100,
  parameter int WIN_APB = 16,
  parameter int WIN_PCLK = 8,
  parameter real T_APB_NS = 10.26,
  parameter real T_DVP_NS = 13.71,
  parameter int GATE_MIN_APB = 4
) (
  input  wire              i_clk_apb,
  input  wire              i_rst_n,
  input  wire              i_clk_dvp,
  input  wire  [W-1:0]     i_data,
  input  wire              i_vsync,
  input  wire              i_href,
  input  wire  [15:0]      i_paddr,
  input  wire              i_psel,
  input  wire              i_penable,
  input  wire              i_pwrite,
  input  wire  [31:0]      i_pwdata,
  input  wire  [3:0]       i_pstrb,
  input  wire  [2:0]       i_pprot,
  input  wire              i_pready,
  input  wire  [31:0]      i_prdata,
  input  wire              i_pslverr,
  input  wire              i_dma_req,
  input  wire              i_dma_ack
);
  localparam realtime WIN_NS = WIN_APB * T_APB_NS + WIN_PCLK * T_DVP_NS;
  localparam logic [31:0] VERSION_RESET = 32'h0001_0001;   // CSR v1.1: major 1, minor 1
  localparam logic [31:0] TIMEOUT_RESET = 32'hFFFF_FFFF;   // REQ-REG-002

  // ---------------------------------------------------------------- result bookkeeping
  int n_checks = 0;
  int n_errors = 0;
  int n_tb_assume = 0;
  int cov [string];
  bit dbg;
  initial dbg = $test$plusargs("DV_DEBUG");

  task automatic hit(input string b);
    if (cov.exists(b)) cov[b] = cov[b] + 1; else cov[b] = 1;
  endtask
  task automatic chk(input bit ok, input string id, input string msg);
    n_checks = n_checks + 1;
    if (!ok) begin
      n_errors = n_errors + 1;
      $display("DV_ERROR %s t=%0t %s", id, $time, msg);
    end
  endtask
  task automatic assume_chk(input bit ok, input string id, input string msg);
    if (!ok) begin
      n_tb_assume = n_tb_assume + 1;
      $display("DV_TB_ASSUME %s t=%0t %s", id, $time, msg);
    end
  endtask

  // ---------------------------------------------------------------- reference model state (HDS-derived)
  bit          m_cap_en;
  bit          m_mode;
  bit          m_mode_unk;
  bit [31:0]   m_wm;
  bit [31:0]   m_to;
  bit          m_armed;
  bit          wm_rearm_pulse;   // decision Q-DMA-1 (2026-11-24): a watermark write of 0 or above DEPTH resets the DMA re-arm state
  bit          m_armed_unc;
  bit          m_ovf_cert;
  bit          m_ovf_maybe;
  bit          m_flush_pend;
  longint      m_fc_min;
  longint      m_fc_max;
  bit [31:0]   q_d [$];
  bit          q_u [$];
  realtime     q_t [$];   // push time of every queue entry (DUT-visible occupancy lower bound)
  realtime     pop_t [$];
  realtime     t_nonempty;
  realtime     t_drop = -1.0e9;
  realtime     t_en_set, t_en_clr, t_q_chg, t_wm_w, t_vs_edge, t_ovf_ev, t_flush, t_mode_w, t_rst;
  int          q_hwm;

  task automatic model_reset();
    m_cap_en = 0; m_mode = 0; m_mode_unk = 0; m_wm = 0; m_to = TIMEOUT_RESET;
    m_armed = 0; m_armed_unc = 0; m_ovf_cert = 0; m_ovf_maybe = 0; m_flush_pend = 0;
    m_fc_min = 0; m_fc_max = 0; q_d.delete(); q_u.delete(); q_t.delete(); pop_t.delete(); q_hwm = 0;
    t_en_set = -1.0e9; t_en_clr = -1.0e9; t_q_chg = $realtime; t_wm_w = -1.0e9; t_vs_edge = -1.0e9;
    t_ovf_ev = -1.0e9; t_flush = -1.0e9; t_mode_w = -1.0e9; t_rst = $realtime; t_nonempty = $realtime;
  endtask
  initial model_reset();

  function automatic bit stable_since(input realtime t);
    return (($realtime - t) >= WIN_NS);
  endfunction
  function automatic bit cap_certain();
    return m_cap_en && stable_since(t_en_set);
  endfunction
  function automatic bit cap_possible();
    return m_cap_en || !stable_since(t_en_clr);
  endfunction
  function automatic int pops_recent();
    int n = 0;
    foreach (pop_t[i]) if (($realtime - pop_t[i]) < WIN_NS) n = n + 1;
    return n;
  endfunction

  // occupancy bounds: certain entries are in the FIFO; uncertain entries (CDC-lag acceptance) may or may not be
  function automatic int occ_min();
    int n = 0;
    foreach (q_u[i]) if (!q_u[i]) n = n + 1;
    return n;
  endfunction
  // lower bound of the occupancy the DUT can see: entries pushed less than one CDC window ago may not have arrived yet
  function automatic int occ_lo();
    int n = 0;
    foreach (q_u[i]) if (!q_u[i] && (($realtime - q_t[i]) >= WIN_NS)) n = n + 1;
    return n;
  endfunction
  function automatic int occ_max();
    return (q_d.size() > DEPTH) ? DEPTH : q_d.size();
  endfunction

  // ---------------------------------------------------------------- reset handling
  int rst_low_cycles = 0;
  always begin
    @(negedge i_rst_n);
    model_reset();
    hit("cg_reset_asserted");
  end

  // ---------------------------------------------------------------- DVP input monitor and pixel model
  bit     prev_vs_act = 0;
  bit     act;   // declared at module level: a declaration with an initializer inside an always block is static and runs once
  realtime t_vs_rise = 0;
  realtime t_last_edge = -1.0e9;
  bit [W-1:0] last_edge_data;
  realtime t_last_data_chg = 0;

  task automatic push_pixel(input bit [W-1:0] d, input bit unc);
    int size = q_d.size();
    if (dbg) $display("DV_DBG push d=%0h unc=%0d size=%0d t=%0t", d, unc, size, $time);
    // gated mode: the SFIFO write happens a few APB cycles after the PCLK edge, so a pop inside that window can make room the model does not yet see
    if ((occ_min() >= DEPTH && !(m_mode == 1 && pops_recent() > 0)) || (size >= DEPTH && unc)) begin
      // certainly full (certain entries fill the FIFO): newest sample dropped, sticky overflow set
      if (!unc) begin m_ovf_cert = 1; end else begin m_ovf_maybe = 1; end
      t_ovf_ev = $realtime; t_drop = $realtime;
      hit("cg_overflow_drop_newest_set_dominant");
    end else begin
      bit u = unc;
      if (size >= DEPTH) begin u = 1; m_ovf_maybe = 1; hit("cg_afifo_lag_uncertain_accept"); end   // uncertain entries may have been dropped by the DUT
      else if (m_mode == 0 && (size + pops_recent() >= DEPTH)) begin u = 1; m_ovf_maybe = 1; hit("cg_afifo_lag_uncertain_accept"); end
      if (size == 0) t_nonempty = $realtime;
      q_d.push_back({{(32-W){1'b0}}, d});
      q_u.push_back(u);
      q_t.push_back($realtime);
      t_q_chg = $realtime;
      if (q_d.size() > q_hwm) q_hwm = q_d.size();
    end
  endtask

  task automatic sample_pixel();
    bit hr = (i_href == HR_ACT[0]);
    if (dbg) $display("DV_DBG sample href=%0d armed=%0d capc=%0d capp=%0d en=%0d t=%0t", hr, m_armed, cap_certain(), cap_possible(), m_cap_en, $time);
    // gated-mode spacing and data-hold assumptions of the sensor BFM (REQ-FUNC-007, REQ-PERF-001)
    if (m_mode == 1 && !m_mode_unk) begin
      assume_chk((($realtime - t_last_edge) >= (GATE_MIN_APB * T_APB_NS)) || t_last_edge < 0.0,
                 "chk_dvp_bundled_data", "gated pixel edges closer than the four-APB-cycle contract");
      hit("cg_gated_pixel_spacing_margin");
    end
    t_last_edge = $realtime;
    last_edge_data = i_data;
    if (hr) begin
      hit("cg_frame_href_qualifier");
      if (m_armed && cap_certain())               push_pixel(i_data, 0);
      else if ((m_armed || m_armed_unc) && cap_possible()) push_pixel(i_data, 1);
    end else if (m_armed) begin
      hit("cg_href_inactive_no_sample");
    end
  endtask

  generate
    if (EDGE == 0) begin : g_pos
      always @(posedge i_clk_dvp) if (i_rst_n) sample_pixel();
    end else begin : g_neg
      always @(negedge i_clk_dvp) if (i_rst_n) sample_pixel();
    end
  endgenerate

  // data hold after a gated selected edge (assumption monitor on the BFM)
  always begin
    @(i_data);
    if (m_mode == 1 && !m_mode_unk && t_last_edge > 0.0)
      assume_chk(($realtime - t_last_edge) >= (GATE_MIN_APB * T_APB_NS) || ($realtime - t_last_edge) < 1e-6,
                 "chk_dvp_bundled_data", "gated data changed before the bundled-data hold interval");
  end

  // VSYNC active edge: frame counter model and frame arming (REQ-FUNC-009, REQ-FUNC-005/006)
  always begin
    @(i_vsync);
    if (i_rst_n) begin
      act = (i_vsync == VS_ACT[0]);
      if (act && !prev_vs_act) begin
        t_vs_edge = $realtime; t_vs_rise = $realtime;
        if (dbg) $display("DV_DBG vsync edge capc=%0d en=%0d t=%0t", cap_certain(), m_cap_en, $time);
        hit("cg_vsync_active_edge");
        if (cap_certain()) begin
          m_fc_min = m_fc_min + 1; m_fc_max = m_fc_max + 1; m_armed = 1;
          hit("cg_frame_count_events");
        end else if (cap_possible()) begin
          m_fc_max = m_fc_max + 1; m_armed_unc = 1;
          hit("cg_frame_count_uncertain_edge");
        end else begin
          hit("cg_frame_count_disabled_suppress");
        end
      end
      if (!act && prev_vs_act) begin
        if (m_mode == 1 && !m_mode_unk)
          assume_chk(($realtime - t_vs_rise) >= (GATE_MIN_APB * T_APB_NS), "chk_dvp_bundled_data",
                     "gated VSYNC active pulse shorter than four APB cycles");
      end
      prev_vs_act = act;
    end
  end

  // ---------------------------------------------------------------- APB4 monitor (chk_apb4_protocol)
  logic [15:0] s_addr; logic s_write; logic [31:0] s_wdata; logic [3:0] s_strb; logic [2:0] s_prot;
  bit prev_setup = 0, prev_wait = 0, prev_done = 0;
  int acc_cycles = 0;
  longint apb_cyc = 0;
  longint rd_start_cyc = 0;

  function automatic bit fields_same();
    return (i_paddr == s_addr) && (i_pwrite == s_write) && (i_pwdata == s_wdata) && (i_pstrb == s_strb) && (i_pprot == s_prot);
  endfunction

  always @(posedge i_clk_apb) begin
    apb_cyc = apb_cyc + 1;
    if (!i_rst_n) begin
      rst_low_cycles = rst_low_cycles + 1;
      prev_setup = 0; prev_wait = 0; prev_done = 0; acc_cycles = 0;
      if (rst_low_cycles >= 3 && i_psel && i_penable) begin
        chk(!i_pready && !i_pslverr, "chk_dvp_reset", "pending APB transfer completed while reset is asserted (a_reset_cancels_read)");
        hit("cg_reset_pending_read_and_stopped_clock");
      end
      if (rst_low_cycles >= 3) chk(!i_dma_req, "chk_dvp_reset", "o_dma_req high during reset");
    end else begin
      rst_low_cycles = 0;
      chk(!(i_penable && !i_psel), "chk_apb4_protocol", "PENABLE high without PSEL (a_apb_setup_fields_valid)");
      if (prev_setup) begin
        chk(i_psel && i_penable, "chk_apb4_protocol", "access phase did not follow the setup phase");
        chk(fields_same(), "chk_apb4_protocol", "address/control changed between setup and access (a_apb_setup_fields_valid)");
      end
      if (prev_wait) begin
        chk(i_psel && i_penable, "chk_apb4_protocol", "transfer withdrawn during a wait state (a_apb_stable_when_waiting)");
        chk(fields_same(), "chk_apb4_protocol", "address/control changed during a wait state (a_apb_stable_when_waiting)");
        hit("cg_apb_wait_stability");
      end
      if (prev_done) chk(!(i_psel && i_penable), "chk_apb4_protocol", "access phase repeated after completion without a new setup");
      if (i_psel && !i_penable) begin
        if (!i_pwrite) begin chk(i_pstrb == 4'h0, "chk_apb4_protocol", "PSTRB not low on a read (a_pstrb_low_on_read)"); hit("cg_apb_read_strobe_low"); end
        s_addr = i_paddr; s_write = i_pwrite; s_wdata = i_pwdata; s_strb = i_pstrb; s_prot = i_pprot;
        prev_setup = 1; acc_cycles = 0; rd_start_cyc = apb_cyc; hit("cg_apb_setup_fields");
      end else prev_setup = 0;
      prev_done = 0;
      if (i_psel && i_penable) begin
        acc_cycles = acc_cycles + 1;
        if (i_pready) begin
          process_txn(i_paddr, i_pwrite, i_pwdata, i_pstrb, i_prdata, i_pslverr, acc_cycles);
          prev_wait = 0; prev_done = 1; hit("cg_apb_access_completion");
        end else prev_wait = 1;
      end else prev_wait = 0;
      dma_step();
    end
  end

  // ---------------------------------------------------------------- transaction scoreboard (CSR predictor + FIFO scoreboard)
  task automatic process_txn(input logic [15:0] a, input bit wr, input logic [31:0] wd, input logic [3:0] strb,
                             input logic [31:0] rd, input bit e, input int cyc);
    bit fifo_word  = (a[15:2] == FIFO_ADDR[15:2]);
    bit fifo_exact = (a == FIFO_ADDR);
    bit aligned    = (a[1:0] == 2'b00);
    int ci         = a[15:2];
    bit stq        = stable_since(t_q_chg);
    int size       = q_d.size();
    if (e) hit("cg_apb_error_terminal");
    if (fifo_word) begin
      hit("cg_fifo_endpoint_decode");
      if (wr) begin
        chk(e, "chk_dvp_apb_scoreboard", "write to the FIFO_DATA endpoint completed without PSLVERR (a_fifo_write_rejected)");
        hit("cg_fifo_endpoint_write_error");
      end else if (!fifo_exact) begin
        chk(e, "chk_dvp_apb_scoreboard", "misaligned FIFO_DATA read completed without PSLVERR (a_decode_policy_matches_hds)");
        hit("cg_fifo_decode_error_policy");
      end else begin
        fifo_read(e, rd, cyc, size, stq);
      end
    end else if (!aligned) begin
      chk(e, "chk_dvp_csr_model", "unaligned CSR access completed without PSLVERR (a_decode_policy_matches_hds)");
      hit("cg_fifo_decode_error_policy");
    end else if (wr && strb != 4'hF) begin
      chk(e, "chk_dvp_csr_model", "CSR partial-strobe write completed without PSLVERR");
      hit("cg_csr_partial_strobe_error");
    end else begin
      chk(!e, "chk_dvp_csr_model", "aligned CSR access returned PSLVERR");
      if (wr) csr_write(ci, wd); else csr_read(ci, rd);
    end
  endtask

  function automatic int exp_term_cycle(input bit [31:0] n);
    return (n <= 1) ? 1 : ((n > 32'd1000000) ? 1000000 : int'(n));
  endfunction

  realtime t_nonempty_at_pop;
  task automatic fifo_read(input bit e, input logic [31:0] rd, input int cyc, input int size, input bit stq);
    int term = exp_term_cycle(m_to);
    if (dbg) $display("DV_DBG fifo_read e=%0d rd=%0h cyc=%0d term=%0d to=%0h size=%0d t=%0t", e, rd, cyc, term, m_to, size, $time);
    if (!e) begin
      // successful read: one sample, in order, zero-extended (REQ-IF-001, REQ-FUNC-008, a_fifo_order_preserved)
      hit("cg_apb_one_read_one_pop");
      chk(!m_flush_pend || stable_since(t_flush) == 0, "chk_dvp_flush", "FIFO_DATA read succeeded while a flush is pending (a_flush_blocks_fifo_read)");
      if (rd[31:W] != '0) chk(0, "chk_dvp_pixel_scoreboard", $sformatf("upper bits not zero: 0x%08h (a_sample_zero_extended)", rd));
      else hit("cg_sample_zero_extend");
      // skip entries the DUT may legitimately have dropped (uncertain acceptance), then compare the head
      while (q_d.size() > 0 && q_u[0] && q_d[0] != rd) begin
        q_d.pop_front(); q_u.pop_front(); q_t.pop_front(); m_ovf_cert = 1; hit("cg_uncertain_entry_dropped");
      end
      if (q_d.size() == 0) begin
        chk(0, "chk_dvp_pixel_scoreboard", $sformatf("read returned 0x%08h but no expected sample exists", rd));
      end else begin
        chk(q_d[0] == rd, "chk_dvp_pixel_scoreboard", $sformatf("data/order mismatch: got 0x%08h expected 0x%08h", rd, q_d[0]));
        t_nonempty_at_pop = t_nonempty;
        q_d.pop_front(); q_u.pop_front(); q_t.pop_front(); pop_t.push_back($realtime); t_q_chg = $realtime;
        hit(m_mode ? "cg_gated_apb_pop_count" : "cg_continuous_fifo_order");
      end
      // a_ready_when_data_available: certain data present from the setup cycle completes in access cycle 1
      if (stable_since(t_q_chg) && q_d.size() > 0 && !m_flush_pend && cyc == 1) hit("cg_empty_read_not_waiting");
      if (cyc > term && cyc > 1) begin
        // success after the terminal cycle is legal only if the data arrived near or after the terminal decision
        realtime start_t = $realtime - cyc * T_APB_NS;
        chk(t_nonempty_at_pop >= start_t + (term - 1) * T_APB_NS - WIN_NS, "chk_dvp_timeout",
            $sformatf("read succeeded after %0d cycles with timeout %0d although data was queued earlier", cyc, m_to));
        hit("cg_empty_wait_then_data");
      end
    end else begin
      // error completion of an aligned FIFO_DATA read can only be the empty-read timeout (a_timeout_error_no_pop)
      chk(occ_min() == 0 || !stable_since(t_q_chg) || m_flush_pend, "chk_dvp_timeout", "FIFO_DATA read errored while certain data was available");
      chk(cyc == term, "chk_dvp_timeout", $sformatf("timeout error at access cycle %0d, expected %0d for timeout %0d (a_timeout_exact_terminal_cycle)", cyc, term, m_to));
      hit("cg_empty_read_timeout_error");
      if (m_to == 0) hit("cg_timeout_zero"); else if (m_to == 1) hit("cg_timeout_one"); else hit("cg_timeout_positive");
    end
  endtask

  task automatic csr_read(input int ci, input logic [31:0] rd);
    bit stq = stable_since(t_q_chg);
    case (ci)
      0: begin chk(rd == VERSION_RESET, "chk_dvp_csr_model", $sformatf("dvp_version 0x%08h expected 0x00010001", rd)); hit("cg_csr_access_reset"); end
      1: begin
        chk(rd[31:3] == '0, "chk_dvp_csr_model", "dvp_ctrl reserved bits not zero");
        chk(rd[0] == m_cap_en, "chk_dvp_csr_model", "dvp_ctrl.capture_en readback mismatch");
        if (m_mode_unk) begin m_mode = rd[1]; m_mode_unk = 0; end
        else chk(rd[1] == m_mode, "chk_dvp_csr_model", $sformatf("dvp_ctrl.pclk_mode readback %0b expected %0b (a_mode_changes_only_when_safe)", rd[1], m_mode));
        if (m_flush_pend && rd[2] == 1'b0) begin
          m_flush_pend = 0; hit("cg_flush_handshake_by_mode");
        end else if (!m_flush_pend) chk(rd[2] == 1'b0, "chk_dvp_flush", "fifo_flush set without a pending request");
        hit("cg_csr_v11_fields");
      end
      2: chk(rd == m_wm, "chk_dvp_csr_model", $sformatf("dvp_wmark 0x%08h expected 0x%08h", rd, m_wm));
      3: begin chk(rd == m_to, "chk_dvp_csr_model", $sformatf("dvp_timeout 0x%08h expected 0x%08h", rd, m_to)); hit("cg_csr_access_reset"); end
      4: begin
        int sz = q_d.size();
        chk(rd[31:4] == '0, "chk_dvp_csr_model", "dvp_fifo_sts reserved bits not zero");
        if (stq && stable_since(t_flush)) begin
          if (m_flush_pend || occ_max() == 0) chk(rd[1] == 1'b1, "chk_dvp_csr_model", "dvp_fifo_sts.empty mismatch (must be set)");
          else if (occ_min() > 0) chk(rd[1] == 1'b0, "chk_dvp_csr_model", "dvp_fifo_sts.empty mismatch (must be clear)");
          if (!m_flush_pend) begin
            if (occ_min() >= DEPTH) chk(rd[2] == 1'b1, "chk_dvp_csr_model", "dvp_fifo_sts.full mismatch (must be set)");
            else if (occ_max() < DEPTH) chk(rd[2] == 1'b0, "chk_dvp_csr_model", "dvp_fifo_sts.full mismatch (must be clear)");
          end else chk(rd[2] == 1'b0, "chk_dvp_csr_model", "dvp_fifo_sts.full mismatch while flush pending");
        end
        if (stable_since(t_en_set) && stable_since(t_en_clr)) begin
          if (!m_cap_en) chk(rd[0] == 1'b0, "chk_dvp_csr_model", "dvp_fifo_sts.active high while capture is disabled");
          else if (m_armed) chk(rd[0] == 1'b1, "chk_dvp_csr_model", "dvp_fifo_sts.active low although capture is armed");
        end
        if (stable_since(t_ovf_ev)) begin
          if (m_ovf_cert) chk(rd[3], "chk_dvp_csr_model", "dvp_fifo_sts.ovf not set after a certain overflow");
          else if (!m_ovf_maybe) chk(!rd[3], "chk_dvp_csr_model", "dvp_fifo_sts.ovf set without an overflow");
        end
      end
      5: begin
        int sz = q_d.size();
        chk(rd <= DEPTH, "chk_dvp_csr_model", "dvp_fifo_level above the FIFO depth");
        if (stq && stable_since(t_flush)) begin
          if (m_flush_pend) chk(rd == 0, "chk_dvp_csr_model", $sformatf("dvp_fifo_level %0d expected 0 while flush pending", rd));
          else chk(rd >= occ_min() && rd <= occ_max(), "chk_dvp_csr_model", $sformatf("dvp_fifo_level %0d outside [%0d,%0d]", rd, occ_min(), occ_max()));
        end
        hit("cg_fifo_occupancy_boundary");
      end
      6: begin
        if (stable_since(t_vs_edge)) chk(rd >= m_fc_min[31:0] && rd <= m_fc_max[31:0], "chk_dvp_frame_count", $sformatf("dvp_frame_count %0d outside [%0d,%0d] (a_frame_count_one_per_event)", rd, m_fc_min, m_fc_max));
        hit("cg_frame_count_csr");
      end
      default: begin chk(rd == 32'h0, "chk_dvp_csr_model", "aligned unmapped CSR read did not return zero"); hit("cg_csr_unmapped_zero"); end
    endcase
  endtask

  task automatic csr_write(input int ci, input logic [31:0] wd);
    case (ci)
      1: begin
        bit new_en = wd[0]; bit new_mode = wd[1]; bit new_fl = wd[2];
        bit safe_certain = !m_cap_en && !new_en && stable_since(t_en_clr) && stable_since(t_q_chg) && q_d.size() == 0 && stable_since(t_vs_edge);
        bit rej_certain = m_cap_en || new_en || (q_d.size() != 0 && stable_since(t_q_chg));
        if (new_mode != m_mode) begin
          if (rej_certain) begin hit("cg_mode_guard_conditions"); end
          else if (safe_certain) begin m_mode = new_mode; t_mode_w = $realtime; hit("cg_mode_guard_conditions"); end
          else begin m_mode_unk = 1; hit("cg_mode_guard_uncertain"); end
        end
        if (new_fl && !m_flush_pend) begin
          if (!m_cap_en && !new_en) begin
            m_flush_pend = 1; t_flush = $realtime; q_d.delete(); q_u.delete(); q_t.delete(); t_q_chg = $realtime; hit("cg_flush_invalid_and_blocked_read");
          end else hit("cg_flush_ignored_while_enabled");
        end
        if (new_en != m_cap_en) begin
          if (new_en) begin t_en_set = $realtime; end
          else begin t_en_clr = $realtime; m_armed = 0; m_armed_unc = 0; end
          m_cap_en = new_en;
        end
      end
      2: begin m_wm = wd; t_wm_w = $realtime; if (wd == 32'd0 || wd > DEPTH) begin wm_rearm_pulse = 1; hit("cg_dma_wm_rearm_by_disable"); end end
      3: begin m_to = wd; end
      4: begin
        if (wd[3]) begin m_ovf_cert = 0; m_ovf_maybe = !stable_since(t_drop); t_ovf_ev = $realtime; hit("cg_overflow_w1c_clear"); if (m_ovf_maybe) hit("cg_w1c_race_window"); end
      end
      default: hit("cg_csr_write_ignored");
    endcase
    if (ci != 1 && !(ci == 2 || ci == 3 || ci == 4)) hit("cg_csr_reserved_ignored");
  endtask

  // ---------------------------------------------------------------- DMA request checker (REQ-IF-004, chk_dvp_dma)
  typedef enum int {D_WAIT, D_PEND, D_SERV} dma_st_t;
  dma_st_t ds = D_WAIT;
  bit req_prev = 0, ack_prev = 0, below_seen = 0, below_poss = 0;   // below_seen: certainly below the watermark; below_poss: possibly below (CDC latency)
  realtime t_ack = -1.0e9;
  int occ_hist_max = 0;
  realtime t_occ_max = 0;

  task automatic dma_step();
    int occ = occ_min();
    int occx = occ_max();
    int occl = occ_lo();
    bit stq = stable_since(t_q_chg);
    bit stw = stable_since(t_wm_w);
    int wm  = (m_wm > DEPTH) ? DEPTH + 1 : int'(m_wm);
    if (occx >= occ_hist_max || ($realtime - t_occ_max) > WIN_NS) begin occ_hist_max = occx; t_occ_max = $realtime; end
    if (stw && m_wm == 0) begin chk(!i_dma_req, "chk_dvp_dma", "zero watermark must keep o_dma_req low"); hit("cg_dma_zero_watermark"); end
    if (req_prev && !ack_prev && !i_dma_req && stw && m_wm != 0 && !m_flush_pend)
      chk(0, "chk_dvp_dma", "o_dma_req dropped without i_dma_ack (a_dma_req_holds_until_ack)");
    if (wm_rearm_pulse) begin wm_rearm_pulse = 0; if (ds != D_PEND) begin ds = D_WAIT; below_seen = 0; below_poss = 0; occ_hist_max = 0; end end
    case (ds)
      D_WAIT: begin
        if (stq && stw && m_wm != 0 && m_wm <= DEPTH && occ >= wm && !m_flush_pend) chk(i_dma_req, "chk_dvp_dma", $sformatf("occupancy %0d >= watermark %0d but o_dma_req low", occ, wm));
        if (i_dma_req && !req_prev) begin
          chk(m_wm != 0 && occ_hist_max >= wm, "chk_dvp_dma", "o_dma_req rose without the occupancy reaching the watermark");
          ds = D_PEND; hit("cg_dma_watermark_ack_rearm");
        end
      end
      D_PEND: begin
        if (i_dma_ack) begin ds = D_SERV; below_seen = 0; below_poss = 0; t_ack = $realtime; hit("cg_dma_ack_seen"); end
      end
      D_SERV: begin
        if (stw && occl < wm) below_poss = 1;
        if (stq && stw && occx < wm) begin below_seen = 1; below_poss = 1; end
        if (i_dma_req && !req_prev) begin
          chk(below_poss && occ_hist_max >= wm, "chk_dvp_dma", "o_dma_req re-asserted without the occupancy falling below and re-crossing the watermark (a_dma_rearm_requires_new_crossing)");
          ds = D_PEND; hit("cg_dma_req_rearm_edges");
        end else if (below_seen && stq && occ >= wm && m_wm != 0) begin
          ds = D_WAIT; below_seen = 0; below_poss = 0;
        end
        if (i_dma_req && ($realtime - t_ack) > WIN_NS && !below_poss) chk(0, "chk_dvp_dma", "o_dma_req still high a window after i_dma_ack");
      end
      default: ds = D_WAIT;
    endcase
    if (dbg && (i_dma_req != req_prev || i_dma_ack != ack_prev)) $display("DV_DBG dma ds=%0d req=%0d ack=%0d occ=[%0d,%0d] wm=%0d below_seen=%0d t=%0t", ds, i_dma_req, i_dma_ack, occ, occx, m_wm, below_seen, $time);
    req_prev = i_dma_req; ack_prev = i_dma_ack;
  endtask
  always @(negedge i_rst_n) begin ds = D_WAIT; req_prev = 0; ack_prev = 0; below_seen = 0; below_poss = 0; occ_hist_max = 0; end

  // ---------------------------------------------------------------- end of test report
  task automatic drain_check();
    int hard = 0;
    for (int i = 0; i < q_d.size(); i++) if (!q_u[i]) hard = hard + 1;
    chk(hard == 0, "chk_dvp_pixel_scoreboard", $sformatf("%0d expected samples were never read (drain)", hard));
  endtask

  task automatic report();
    $display("DV_RESULT checks=%0d errors=%0d tb_assume=%0d queue_left=%0d", n_checks, n_errors, n_tb_assume, q_d.size());
    foreach (cov[k]) $display("DV_COV %s %0d", k, cov[k]);
  endtask

  // ---------------------------------------------------------------- exposed counters for the testbench
  function automatic int errors();   return n_errors; endfunction
  function automatic int checks();   return n_checks; endfunction
  function automatic int expected_left(); return q_d.size(); endfunction
endmodule
