`timescale 1ns/1ps
// Behavioral serial device (verification only) for one unit of the APB I2S IP. Written from the
// frame definitions of VLSIT_APB_I2S_HDS.md (REQ-FUNC-003..REQ-FUNC-012, section 10.3) and the
// Philips I2S bus specification (REF-006), not from the RTL.
//   master = 1 : the device makes the bit clock and the frame sync (the IP is a slave)
//   master = 0 : the IP makes them; the device follows its pins
//   cap_en = 1 : capture the data lines of the IP (transmit tests)
//   src_en = 1 : drive the data line from src_q (receive tests)
module i2s_dev #(
  parameter int LINES = 1,
  parameter int TM_PS = 10000
) (
  input  logic             clk_m,
  input  logic [3:0]       dut_sd,
  input  logic             dut_sd_oe,
  input  logic             dut_bclk,
  input  logic             dut_bclk_oe,
  input  logic             dut_ws,
  input  logic             dut_ws_oe,
  output logic             bclk_out,
  output logic             ws_out,
  output logic [3:0]       sd_out
);
  // configuration, written by the testbench
  int          fmt = 1, nslot = 2, slot_w = 16, data_w = 16, bpol = 0, sync_w = 1, fsp = 0, fse = 1;
  logic [31:0] mask = 32'hFFFFFFFF;
  int          hp_ps = 80000;        // half period of the bit clock made by the device
  int          div = 8;              // divider expected from an IP master
  bit          master = 0, run = 0, cap_en = 0, src_en = 0, chk_en = 1, chk_mask = 1, clk_stop = 0;
  int          glitch_t = -1;        // frame position at which one false frame sync is inserted
  int          settle_ps = 0;        // window after a launch edge in which data may change (0: auto)
  // results
  logic [31:0] cap_val [$];
  int          cap_slot [$];
  int          cap_frame [$];
  int          cap_line [$];
  logic [31:0] src_q [$];
  int          src_empty = 0;
  int          frames_seen = 0;
  int          ws_edges = 0;
  bit          dbg = 0;
  int          cap_limit = 0;       // stop the pattern checks when this many samples are captured
  bit          pre_skip = 0;        // the position before the first frame is not a data bit
  int          dbg_n = 0;
  int          msk_oe_low = 0, msk_oe_high = 0;   // masked-slot samples with the output enable low / high

  // checks
  int hit [1:8];
  int bad [1:8];
  string nm [1:8];
  initial begin
    for (int i = 1; i <= 8; i++) begin hit[i] = 0; bad[i] = 0; end
    nm[1] = "SER-01 data lines change only after the launch edge (REQ-IF-011, SVA-002)";
    nm[2] = "SER-02 frame sync follows the format pattern (REQ-FUNC-004..008, SVA-003)";
    nm[3] = "SER-03 bits after the data width are zero (REQ-FUNC-009, REQ-FUNC-003)";
    nm[4] = "SER-04 masked slot is zero or released (REQ-FUNC-011, INV-004, SVA-008)";
    nm[5] = "SER-05 bit clock half period equals the divider (REQ-FUNC-017)";
    nm[6] = "SER-06 stopped unit: data low, enables low, clock and sync low (REQ-FUNC-001, 020)";
    nm[7] = "SER-07 data is not X when the output enable is high (REQ-IF-011)";
    nm[8] = "SER-08 frame sync inactive for a stalled or stopped master (REQ-FUNC-020, 021)";
  end
  task automatic chk(input int id, input logic ante, input logic cons);
    begin
      if (ante === 1'b1) begin
        hit[id]++;
        if (cons !== 1'b1) begin
          bad[id]++;
          if (bad[id] <= 3) $display("ASSERT FAIL @%0t: %s", $time, nm[id]);
        end
      end
    end
  endtask

  // ---- frame definition from the specification
  function automatic int n_bits();
    return nslot * slot_w;
  endfunction
  function automatic int early();
    case (fmt)
      0: return fse;
      2, 4: return 0;
      default: return 1;
    endcase
  endfunction
  function automatic logic lvl_act();
    case (fmt)
      0: return (fsp == 0);
      3, 4, 5: return 1'b1;
      default: return 1'b0;
    endcase
  endfunction
  function automatic logic ws_active_at(input int t);   // t: position of the data bit
    int n, w;
    begin
      n = n_bits();
      w = (t + early()) % n;
      case (fmt)
        0:       ws_active_at = (w < sync_w);
        3, 5:    ws_active_at = (w == 0);
        4:       ws_active_at = (w < slot_w);
        default: ws_active_at = (w < n / 2);
      endcase
    end
  endfunction
  function automatic logic ws_level(input int t);
    return ws_active_at(t) ? lvl_act() : ~lvl_act();
  endfunction
  function automatic logic [31:0] dmask();
    return (data_w >= 32) ? 32'hFFFFFFFF : ((32'h1 << data_w) - 1);
  endfunction

  // ---- capture of the data lines at the sample edge of position t
  logic [31:0] sh [0:3];
  task automatic cap_bit(input int t);
    int slot, b;
    logic bv;
    begin
      slot = t / slot_w; b = t % slot_w;
      if (pre_skip) begin
        pre_skip = 0;
        if (t == n_bits() - 1) return;
      end
      for (int l = 0; l < LINES; l++) begin
        bv = dut_sd_oe ? dut_sd[l] : 1'b0;
        chk(7, dut_sd_oe, !$isunknown(dut_sd[l]));
        if (mask[slot]) begin
          if (b < data_w) begin
            sh[l] = {sh[l][30:0], bv};
            if (b == data_w - 1) begin
              cap_val.push_back(sh[l] & dmask());
              cap_slot.push_back(slot);
              cap_frame.push_back(frames_seen);
              cap_line.push_back(l);
              if (cap_limit != 0 && cap_val.size() >= cap_limit && l == LINES - 1) chk_en = 0;
            end
          end else begin
            chk(3, 1'b1, bv == 1'b0);
          end
        end else begin
          if (chk_en) begin if (dut_sd_oe) msk_oe_high++; else msk_oe_low++; end
          if (chk_mask) chk(4, 1'b1, (dut_sd_oe == 1'b0) || (bv == 1'b0));
        end
      end
      if (t == n_bits() - 1) frames_seen++;
    end
  endtask

  // ---- source value for position t: one sample per line at the first bit of an enabled slot
  logic [31:0] cur [0:3];
  function automatic logic src_bit(input int l, input int b);
    return (b < data_w) ? cur[l][data_w - 1 - b] : 1'b0;
  endfunction
  task automatic src_pos(input int t);
    int slot, b;
    begin
      slot = t / slot_w; b = t % slot_w;
      if (b == 0) begin
        for (int l = 0; l < LINES; l++) begin
          if (mask[slot]) begin
            if (src_q.size() > 0) cur[l] = src_q.pop_front();
            else begin cur[l] = 32'h0; src_empty++; end
          end else cur[l] = 32'hA5C3A5C3 ^ (slot * 32'h1111);   // garbage in a masked slot
        end
      end
      for (int l = 0; l < LINES; l++) sd_out[l] = src_bit(l, b);
    end
  endtask

  // ---- device as master: bit clock, frame sync, data
  longint gt;
  real    t_launch = 0.0;
  initial begin
    bclk_out = 1'b1; ws_out = 1'b0; sd_out = 4'h0;
    forever begin
      wait (master && run);
      bclk_out = (bpol == 0) ? 1'b1 : 1'b0;      // level before the launch edge
      ws_out   = ~lvl_act();
      gt = (n_bits() - early()) % n_bits();
      pre_skip = (early() != 0);
      #(2 * hp_ps * 1ps);                          // idle levels are seen for a while before the first launch
      while (master && run) begin
        if (clk_stop) begin
          #(hp_ps * 1ps);
        end else begin
          int t;
          t = int'(gt % n_bits());
          bclk_out = (bpol == 0) ? 1'b0 : 1'b1;   // launch edge
          t_launch = $realtime;
          ws_out   = ws_level(t);
          if (glitch_t >= 0 && t == glitch_t) ws_out = lvl_act();
          if (src_en) src_pos(t);
          #(hp_ps * 1ps);
          bclk_out = (bpol == 0) ? 1'b1 : 1'b0;   // sample edge
          if (cap_en) cap_bit(t);
          if (dbg && dbg_n < 140) begin dbg_n++; $display("%0t DEV t=%0d ws=%b sd=%b oe=%b", $time, t, ws_out, dut_sd[0], dut_sd_oe); end
          #(hp_ps * 1ps);
          gt++;
        end
      end
      bclk_out = (bpol == 0) ? 1'b1 : 1'b0; ws_out = ~lvl_act(); sd_out = 4'h0;
    end
  end

  // ---- device as slave: follow the pins of the IP
  bit    synced = 0, prev_act = 0;
  int    tt = 0;
  real   t_last_edge = 0.0;
  logic  prev_bclk = 1'b0;
  always @(dut_bclk) begin
    if (!master && dut_bclk_oe && run) begin
      #1ps;
      // period check against the divider (an edge after a long pause is not checked)
      if (t_last_edge != 0.0 && chk_en && ($realtime - t_last_edge) < 4.0 * div * TM_PS / 1000.0)
        chk(5, 1'b1, (($realtime - t_last_edge) > (div * TM_PS / 1000.0 - 0.01)) &&
                     (($realtime - t_last_edge) < (div * TM_PS / 1000.0 + 0.01)));
      t_last_edge = $realtime;
      if (dut_bclk == (bpol == 0 ? 1'b0 : 1'b1)) begin
        // launch edge: the frame sync and the data of the IP have changed
        logic act;
        act = (dut_ws_oe && (dut_ws == lvl_act()));
        t_launch = $realtime;
        if (synced) tt = (tt + 1) % n_bits();
        if (act && !prev_act) begin
          // an activation edge starts a frame: the position of the frame sync index 0
          ws_edges++;
          if (synced && tt != (n_bits() - early()) % n_bits()) begin
            if (chk_en) chk(2, 1'b1, 1'b0);
          end else if (synced && chk_en) chk(2, 1'b1, 1'b1);
          if (!synced || tt != (n_bits() - early()) % n_bits()) pre_skip = (early() != 0);
          synced = 1;
          tt = (n_bits() - early()) % n_bits();
        end else if (synced) begin
          // at the last bit of an early format the frame sync of the next frame is launched, or not
          // when no frame follows (stall, end of data): both are legal, the data bit is still valid
          if (!(early() != 0 && tt == n_bits() - 1)) begin
            if (chk_en) begin chk(2, 1'b1, dut_ws === ws_level(tt)); if (dut_ws !== ws_level(tt) && bad[2] <= 3) $display("   SER-02 detail: tt=%0d ws=%b expected=%b fmt=%0d nslot=%0d slot_w=%0d", tt, dut_ws, ws_level(tt), fmt, nslot, slot_w); end
            if (dut_ws !== ws_level(tt)) synced = 0;
          end
        end
        prev_act = act;
        if (synced && src_en) src_pos(tt);
        else if (src_en) sd_out = 4'h0;
      end else begin
        // sample edge
        if (synced && cap_en) cap_bit(tt);
      end
    end
  end

  // data change window (SVA-002): data may change only shortly after the launch edge
  real t_edge_raw = 0.0;
  always @(dut_bclk) t_edge_raw = $realtime;
  always @(dut_sd or dut_sd_oe) begin
    real tc, lim;
    tc = $realtime;
    if (cap_en && run && chk_en && t_launch != 0.0) begin
      #2ps;     // the launch edge of this very instant is registered by now
      lim = (settle_ps != 0) ? settle_ps : (master ? (hp_ps - TM_PS) : (2 * TM_PS));   // master: before the sample edge
      chk(1, 1'b1, (tc - t_launch) <= (lim / 1000.0 + 0.01));
      if ((tc - t_launch) > (lim / 1000.0 + 0.01) && bad[1] <= 3) $display("   SER-01 detail: now=%f t_launch=%f lim=%f master=%b sd=%b oe=%b", tc, t_launch, lim, master, dut_sd, dut_sd_oe);
    end
  end

  task automatic reset_tracker();
    begin synced = 0; prev_act = 0; t_last_edge = 0.0; tt = 0; end
  endtask
  task automatic clear_results();
    begin
      cap_val.delete(); cap_slot.delete(); cap_frame.delete(); cap_line.delete(); src_q.delete();
      src_empty = 0; cap_limit = 0; frames_seen = 0; ws_edges = 0; msk_oe_low = 0; msk_oe_high = 0;
      for (int l = 0; l < 4; l++) begin sh[l] = 0; cur[l] = 0; end
    end
  endtask

  // idle check of a stopped unit (SER-06)
  task automatic check_idle(input logic has_clk, input logic lvl);
    begin
      chk(6, 1'b1, (dut_sd_oe == 1'b0) && (has_clk ? (dut_bclk_oe == 1'b0 && dut_ws_oe == 1'b0) : 1'b1) &&
                   (lvl ? (dut_sd == 4'h0 && (has_clk ? (dut_bclk == 1'b0 && dut_ws == 1'b0) : 1'b1)) : 1'b1));
    end
  endtask
  task automatic check_ws_idle();
    begin chk(8, 1'b1, dut_ws_oe == 1'b0 || dut_ws == ~lvl_act()); end
  endtask

  task report(output int total, output int failed, output int never);
    begin
      total = 0; failed = 0; never = 0;
      for (int i = 1; i <= 8; i++) begin
        total++;
        if (bad[i] != 0) failed++;
        if (hit[i] == 0) never++;
        $display("  %-92s hits=%0d fails=%0d", nm[i], hit[i], bad[i]);
      end
    end
  endtask
endmodule
