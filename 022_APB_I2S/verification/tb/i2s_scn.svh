// Scenario tasks of the testbench (included in tb_i2s). Expected values come from the specification:
// frame format REQ-FUNC-003..009, word order REQ-FUNC-012, alignment and packing REQ-FUNC-010.

// ---- applicability of assertions for a build (a feature that is absent cannot be exercised)
function automatic bit sb_na(input int id);
  begin
    sb_na = 0;
    case (id)
      6:  sb_na = (TX_EN == 0);
      7:  sb_na = (RX_EN == 0);
      9:  sb_na = (DMA_EN == 0);
      8:  sb_na = (TX_EN == 0) || (MASTER_EN == 0);
      12: sb_na = 0;
      default: sb_na = 0;
    endcase
  end
endfunction
function automatic bit dma_na(input int id);
  return (DMA_EN == 0);
endfunction
function automatic bit ser_na(input int id);     // serial-device assertion that this build cannot reach
  begin
    if (TX_EN == 0) ser_na = 1;
    else if (MASTER_EN == 0) ser_na = (id == 2 || id == 5 || id == 8);   // they need an IP master
    else ser_na = 0;
  end
endfunction

logic [31:0] words [0:2047];
logic [31:0] samp  [0:2047];
int          t_scn_err;
longint      scn_count = 0;

task automatic dev_cfg(input int u, input int fmt, input int nslot, input int slot_w, input int data_w,
                       input int bpol, input int sync_w, input int fsp, input int fse, input logic [31:0] mask);
  begin
    if (u == 0) begin
      dtx.chk_en = 0;
      dtx.fmt = fmt; dtx.nslot = nslot; dtx.slot_w = slot_w; dtx.data_w = data_w; dtx.bpol = bpol;
      dtx.sync_w = sync_w; dtx.fsp = fsp; dtx.fse = fse; dtx.mask = mask;
    end else begin
      drx.chk_en = 0;
      drx.fmt = fmt; drx.nslot = nslot; drx.slot_w = slot_w; drx.data_w = data_w; drx.bpol = bpol;
      drx.sync_w = sync_w; drx.fsp = fsp; drx.fse = fse; drx.mask = mask;
    end
  end
endtask

// words per frame and per direction pushed by software: lines x (enabled slots, halved with packing)
function automatic int wpf_of(input int nslot, input logic [31:0] mask, input int pack);
  int en;
  begin
    en = popc(mask, nslot);
    wpf_of = LINES * ((pack != 0) ? ((en + 1) / 2) : en);
  end
endfunction

// Transmit scenario: software writes words, the IP sends frames, a device captures and compares.
//   ipm = 1: the IP is the master (the device follows its pins); 0: the device makes the clock.
task automatic tx_scn(input string tag, input int fmt, input int nslot, input int slot_w, input int data_w,
                      input int align, input int pack, input logic [31:0] mask, input bit ipm_in, input int div,
                      input int bpol, input int sync_w, input int fsp, input int fse, input int nframes,
                      input int trs, input int hpc);
  int en, wpf, nw, nsamp, t, errs, widx, k;
  int ctl;
  int pk;
  bit ipm;
  begin
    ipm = ipm_in && (MASTER_EN != 0);
    if (TX_EN == 0) begin end
    else begin
      scn_count++;
      pk = (PACK_EN != 0) ? pack : 0;
      hw_reset();
      dev_cfg(0, fmt, nslot, slot_w, data_w, bpol, sync_w, fsp, fse, mask);
      dtx.cap_en = 1; dtx.src_en = 0; dtx.master = !ipm; dtx.div = div; dtx.hp_ps = hpc * TM_PS; dtx.chk_mask = 1; dtx.chk_en = 1;
      cfg_unit(0, fmt, nslot, slot_w, data_w, align, pk, mask, div, bpol, sync_w, fsp, fse, 4);
      en = popc(mask, nslot);
      wpf = wpf_of(nslot, mask, pk);
      nw = wpf * nframes;
      if (nw > DEPTH * LINES) begin nframes = (DEPTH * LINES) / wpf; nw = wpf * nframes; end
      for (int i = 0; i < nw; i++) begin words[i] = rnd32(); wr32(U(0, R_DATA), words[i]); end
      rd32(U(0, R_STS), r_);
      sb(1, 1'b1, r_[27:16] == nw, $sformatf("%s: TX level after %0d pushes is %0d", tag, nw, r_[27:16]));
      dtx.cap_limit = nframes * en * LINES;
      ctl = (ipm ? (1 << C_ROLE) : 0) | ((trs != 0) ? (1 << C_TRI) : 0);
      if (ipm) begin dtx.run = 1; unit_en(0, ctl); end
      else begin unit_en(0, ctl); wait_apb(20); dtx.run = 1; end
      nsamp = nframes * en * LINES;
      t = 0;
      while (dtx.cap_val.size() < nsamp && t < 4000) begin wait_m(200); t++; end
      check(dtx.cap_val.size() >= nsamp, $sformatf("%s: captured %0d of %0d samples", tag, dtx.cap_val.size(), nsamp));
      dtx.chk_en = 0;     // the stream may stop after the data: the checks cover the data frames
      unit_dis(0);
      dtx.run = 0;
      wait_m(20);
      if (ipm) dtx.check_idle(1'b1, 1'b0);
      errs = 0;
      k = 0;
      for (int f = 0; f < nframes; f++) begin
        for (int si = 0; si < en; si++) begin
          for (int l = 0; l < LINES; l++) begin
            if (k < dtx.cap_val.size()) begin
              if (pk != 0) widx = f * wpf + (si / 2) * LINES + l;
              else         widx = f * wpf + si * LINES + l;
              sb(1, 1'b1, dtx.cap_val[k] === exp_tx(words[widx], align, pk, (pk != 0) ? (si % 2) : 0, data_w),
                 $sformatf("%s: sample %0d (frame %0d slot#%0d line %0d) got %h exp %h", tag, k, f, si, l,
                           dtx.cap_val[k], exp_tx(words[widx], align, pk, (pk != 0) ? (si % 2) : 0, data_w)));
              if (!(dtx.cap_val[k] === exp_tx(words[widx], align, pk, (pk != 0) ? (si % 2) : 0, data_w))) errs++;
            end
            k++;
          end
        end
      end
      t_scn_err = errs;
    end
  end
endtask

// Receive scenario: a device sends samples, the IP receives, software reads the words and compares.
task automatic rx_scn(input string tag, input int fmt, input int nslot, input int slot_w, input int data_w,
                      input int align, input int pack, input logic [31:0] mask, input bit ipm_in, input int div,
                      input int bpol, input int sync_w, input int fsp, input int fse, input int nframes,
                      input int hpc);
  int en, wpf, nw, nsamp, t, errs, k, pk;
  logic [31:0] got, s0, s1;
  bit ipm;
  begin
    ipm = ipm_in && (MASTER_EN != 0);
    if (RX_EN == 0) begin end
    else begin
      scn_count++;
      pk = (PACK_EN != 0) ? pack : 0;
      hw_reset();
      dev_cfg(1, fmt, nslot, slot_w, data_w, bpol, sync_w, fsp, fse, mask);
      drx.cap_en = 0; drx.src_en = 1; drx.master = !ipm; drx.div = div; drx.hp_ps = hpc * TM_PS; drx.chk_en = 1;
      cfg_unit(1, fmt, nslot, slot_w, data_w, align, pk, mask, div, bpol, sync_w, fsp, fse, 4);
      en = popc(mask, nslot);
      wpf = wpf_of(nslot, mask, pk);
      if (wpf * nframes > DEPTH * LINES) nframes = (DEPTH * LINES) / wpf;
      nw = wpf * nframes;
      nsamp = nframes * en * LINES;
      for (int i = 0; i < nsamp; i++) begin samp[i] = rnd32() & dmk(data_w); drx.src_q.push_back(samp[i]); end
      if (ipm) begin drx.run = 1; unit_en(1, (1 << C_ROLE)); end
      else begin unit_en(1, 0); wait_apb(20); drx.run = 1; end
      t = 0; r_ = 0;
      while (r_[27:16] < nw && t < 4000) begin wait_m(200); rd32(U(1, R_STS), r_); t++; end
      check(r_[27:16] >= nw, $sformatf("%s: RX level %0d of %0d words", tag, r_[27:16], nw));
      drx.chk_en = 0;
      rd32(R_IRAW, r_);
      check(!r_[I_SYNC] && !r_[I_HUNG], $sformatf("%s: clean stream raises no sync error and no hung (raw %h)", tag, r_[7:0]));
      unit_dis(1);
      drx.run = 0;
      errs = 0;
      for (int f = 0; f < nframes; f++) begin
        for (int w = 0; w < wpf / LINES; w++) begin
          for (int l = 0; l < LINES; l++) begin
            rd32(U(1, R_DATA), got);
            if (pk != 0) begin
              s0 = samp[f * en * LINES + (2 * w) * LINES + l];
              s1 = ((2 * w + 1) < en) ? samp[f * en * LINES + (2 * w + 1) * LINES + l] : 32'h0;
            end else begin
              s0 = samp[f * en * LINES + w * LINES + l]; s1 = 0;
            end
            sb(1, 1'b1, got === exp_rx(s0, s1, align, pk, data_w),
               $sformatf("%s: word f%0d w%0d l%0d got %h exp %h", tag, f, w, l, got, exp_rx(s0, s1, align, pk, data_w)));
            if (got !== exp_rx(s0, s1, align, pk, data_w)) errs++;
          end
        end
      end
      t_scn_err = errs;
    end
  end
endtask

// pick a legal random mask: at least one enabled slot; an even count with packing (ASM-020)
function automatic logic [31:0] rnd_mask(input int nslot, input int pack);
  logic [31:0] m;
  int c, tries;
  begin
    tries = 0;
    do begin
      m = rnd32() | rnd32();
      if (nslot < 32) m = m & ((32'h1 << nslot) - 1);
      c = popc(m, nslot);
      tries++;
      if (tries > 20) begin m = (nslot < 32) ? ((32'h1 << nslot) - 1) : 32'hFFFFFFFF; c = nslot; end
    end while (c == 0 || (pack != 0 && (c % 2) != 0));
    rnd_mask = m;
  end
endfunction
