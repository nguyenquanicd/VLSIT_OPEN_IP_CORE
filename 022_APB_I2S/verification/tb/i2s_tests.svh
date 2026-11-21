`include "i2s_scn.svh"
`include "i2s_wf.svh"

// =====================================================================================
// Focused tests (one primary function each), then integrated flows (R-048).
// =====================================================================================

function automatic logic [31:0] exp_cap();
  logic [31:0] c;
  begin
    c = 0;
    c[0] = (TX_EN != 0); c[1] = (RX_EN != 0);
    c[6:4] = (TX_EN != 0) ? LINES : 0; c[10:8] = (RX_EN != 0) ? LINES : 0;
    c[15:12] = $clog2(DEPTH);
    c[21:16] = (FMT_EXT_EN != 0) ? MAX_SLOTS : 2;
    c[24] = (PACK_EN != 0); c[25] = (MASTER_EN != 0);
    c[26] = (ONDEM_EN != 0) && (MASTER_EN != 0); c[27] = (TRI_EN != 0) && (TX_EN != 0);
    c[28] = (HUNG_EN != 0); c[29] = (DMA_EN != 0); c[30] = (FMT_EXT_EN != 0);
    exp_cap = c;
  end
endfunction

// ---------------------------------------------------------------- TEST-001 reset values (REQ-RESET-*, REQ-REG-005/008)
task automatic t_reset();
  logic [31:0] v;
  begin
    begin_test("TEST-001 reset and capability", "REQ-FUNC-001 REQ-REG-005 REQ-REG-008 REQ-RESET-001/002");
    hw_reset();
    rd32(R_VERSION, v); sb(10, 1'b1, v == 32'h00010000, $sformatf("version %h", v));
    rd32(R_CAP, v);     sb(10, 1'b1, v == exp_cap(), $sformatf("capability %h expected %h", v, exp_cap()));
    rd32(R_GCTRL, v);   sb(10, 1'b1, v == 32'h0, $sformatf("global control %h", v));
    rd32(R_GSTS, v);    sb(10, 1'b1, v == 32'h0, $sformatf("global status %h", v));
    rd32(R_IRAW, v);    sb(10, 1'b1, (v & 32'hFF) == ((TX_EN != 0) ? 32'h1 : 32'h0) || v[7:0] == 8'h01 || v[7:0] == 8'h00, $sformatf("raw %h", v));
    rd32(R_IEN, v);     sb(10, 1'b1, v == 32'h0, $sformatf("enable %h", v));
    rd32(R_IINJ, v);    sb(10, 1'b1, v == 32'h0, $sformatf("injection %h", v));
    for (int u = 0; u < 2; u++) begin
      if ((u == 0 && TX_EN != 0) || (u == 1 && RX_EN != 0)) begin
        rd32(U(u, R_CTRL), v);  sb(10, 1'b1, v == 32'h0, $sformatf("unit %0d ctrl %h", u, v));
        rd32(U(u, R_FRAME), v); sb(10, 1'b1, v == 32'h20200201, $sformatf("unit %0d frame %h", u, v));
        rd32(U(u, R_SYNC), v);  sb(10, 1'b1, v == 32'h00000201, $sformatf("unit %0d sync %h", u, v));
        rd32(U(u, R_CLK), v);   sb(10, 1'b1, v == 32'h2, $sformatf("unit %0d clk %h", u, v));
        rd32(U(u, R_MASK), v);  sb(10, 1'b1, v == 32'hFFFFFFFF, $sformatf("unit %0d mask %h", u, v));
        rd32(U(u, R_FIFO), v);  sb(10, 1'b1, v == 32'h4, $sformatf("unit %0d fifo %h", u, v));
        rd32(U(u, R_STS), v);   sb(10, 1'b1, v == 32'h2, $sformatf("unit %0d status %h (empty only)", u, v));
        rd32(U(u, R_TMO), v);   sb(10, 1'b1, v == 32'h0, $sformatf("unit %0d timeout %h", u, v));
      end
    end
    dtx.check_idle(1'b1, 1'b1); drx.check_idle(1'b1, 1'b1);
    check(!sdo_oe && !bclk_tx_oe && !ws_tx_oe && !bclk_rx_oe && !ws_rx_oe && !sdo0 && !sdo1 && !sdo2 && !sdo3,
          "REQ-FUNC-001: data, enables, bit clock and frame sync low after reset");
    check(!dma_tx_req && !dma_rx_req, "no DMA request after reset (units stopped, DMA disabled)");
    end_test();
  end
endtask

localparam logic [15:0] UNMAPPED [0:7] = '{16'h0020, 16'h0024, 16'h00F0, 16'h0124, 16'h01FC, 16'h0224, 16'h02F0, 16'h03FC};
// ---------------------------------------------------------------- TEST-018 APB behavior (REQ-IF-001..006, REQ-SEC-001)
task automatic t_apb();
  logic [31:0] v, v0;
  bit e;
  logic [15:0] wa;
  begin
    begin_test("TEST-018 APB access behavior", "REQ-IF-001..006 REQ-SEC-001 11.4");
    hw_reset();
    wa = U(TX_EN != 0 ? 0 : 1, R_MASK);
    // back-to-back transfers without an idle cycle
    apb_hold = 1;
    wr32(wa, 32'h0000A5A5); wr32(wa, 32'h00005A5A); rd32(wa, v); rd32(wa, v0);
    apb_hold = 0; apb_chain = 0; psel = 0; penable = 0;
    check(v == 32'h5A5A && v0 == 32'h5A5A, "back-to-back write, write, read, read");
    // partial strobe: error, no change
    apb_xfer(1, wa, 32'hFFFFFFFF, 4'hE, 3'b000, rv_, e);
    check(e, "partial strobe write gives PSLVERR (REQ-IF-003)");
    rd32(wa, v); sb(2, 1'b1, v == 32'h5A5A, "partial strobe write left the register unchanged");
    apb_xfer(1, wa, 32'hFFFFFFFF, 4'h0, 3'b000, rv_, e);
    check(e, "write with all strobes low gives PSLVERR");
    rd32(wa, v); sb(2, 1'b1, v == 32'h5A5A, "zero strobe write left the register unchanged");
    // misaligned address
    apb_xfer(1, wa + 16'd1, 32'h12345678, 4'hF, 3'b000, rv_, e);
    check(e, "misaligned write gives PSLVERR (REQ-IF-003)");
    apb_xfer(0, wa + 16'd2, 0, 4'h0, 3'b000, v, e);
    check(e, "misaligned read gives PSLVERR");
    rd32(wa, v); sb(2, 1'b1, v == 32'h5A5A, "misaligned write left the register unchanged");
    // unmapped aligned addresses: OKAY, read 0, write ignored (REQ-IF-004)
    foreach (UNMAPPED[i]) begin
      apb_xfer(1, UNMAPPED[i], 32'hFFFFFFFF, 4'hF, 3'b000, rv_, e);
      check(!e, "write to an unmapped address gives OKAY");
      apb_xfer(0, UNMAPPED[i], 0, 4'h0, 3'b000, v, e);
      check(!e && v == 0, "read of an unmapped address gives OKAY and 0");
    end
    // reserved bits read 0 and ignore writes; read-only registers ignore writes (REQ-IF-005)
    wa = U(TX_EN != 0 ? 0 : 1, R_FIFO);
    wr32(wa, 32'hFFFFFFFF); rd32(wa, v); sb(3, 1'b1, v == 32'h00000FFF, $sformatf("watermark register with reserved bits written: %h", v));
    wr32(wa, 32'h4);
    wr32(R_VERSION, 32'hFFFFFFFF); rd32(R_VERSION, v); sb(3, 1'b1, v == 32'h00010000, "version register ignores writes");
    wr32(R_CAP, 32'hFFFFFFFF); rd32(R_CAP, v); sb(3, 1'b1, v == exp_cap(), "capability register ignores writes");
    wr32(R_ISTS, 32'hFFFFFFFF); rd32(R_ISTS, v); sb(3, 1'b1, v == 32'h0, "masked status register ignores writes");
    // non-secure access with protection off is allowed
    apb_xfer(1, U(TX_EN != 0 ? 0 : 1, R_MASK), 32'h000000F0, 4'hF, 3'b010, rv_, e);
    check(!e, "non-secure write with protection off gives OKAY");
    rd32(U(TX_EN != 0 ? 0 : 1, R_MASK), v); check(v == 32'hF0, "non-secure write stored with protection off");
    // protection on (static input): non-secure access gives PSLVERR and changes nothing (REQ-SEC-001)
    protect_en = 1; hw_reset();
    wa = U(TX_EN != 0 ? 0 : 1, R_MASK);
    apb_xfer(1, wa, 32'h000000F0, 4'hF, 3'b010, rv_, e);
    check(e, "non-secure write gives PSLVERR when protection is on (REQ-SEC-001)");
    rd32(wa, v); sb(2, 1'b1, v == 32'hFFFFFFFF, "non-secure write left the register unchanged");
    apb_xfer(0, wa, 0, 4'h0, 3'b010, v, e);
    check(e, "non-secure read gives PSLVERR when protection is on");
    apb_xfer(1, wa, 32'h000000F0, 4'hF, 3'b000, rv_, e);
    check(!e, "secure write gives OKAY when protection is on");
    apb_xfer(0, wa, 0, 4'h0, 3'b001, v, e);
    check(!e && v == 32'hF0, "privileged secure read gives OKAY (only PPROT[1] is used)");
    protect_en = 0;
    // error response disabled: no PSLVERR, PSTRB still selects the byte lanes (11.4, DEC-021, generator REQ-ERR-004)
    slverr_en = 0; hw_reset();
    wa = U(TX_EN != 0 ? 0 : 1, R_MASK);
    apb_xfer(1, wa, 32'h12345678, 4'h3, 3'b000, rv_, e);
    check(!e, "partial strobe write gives no PSLVERR when the error response is disabled");
    rd32(wa, v); check(v == 32'hFFFF5678, $sformatf("only the strobed lanes are written when the error response is disabled (11.4), read %h", v));
    apb_xfer(1, wa, 32'hABCDEF01, 4'hC, 3'b000, rv_, e);
    rd32(wa, v); check(!e && v == 32'hABCD5678, $sformatf("upper byte lanes written, lower lanes kept, read %h", v));
    apb_xfer(1, wa, 32'h0, 4'h0, 3'b000, rv_, e);
    rd32(wa, v); check(!e && v == 32'hABCD5678, $sformatf("write with PSTRB 0000 changes nothing, read %h", v));
    apb_xfer(1, wa, 32'h0F0F0F0F, 4'hF, 3'b000, rv_, e);
    rd32(wa, v); check(!e && v == 32'h0F0F0F0F, $sformatf("full strobe writes the whole word, read %h", v));
    slverr_en = 1; hw_reset();
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-019 data registers (REQ-FUNC-030, REQ-IF-008)
task automatic t_data_regs();
  logic [31:0] v;
  int cap;
  begin
    begin_test("TEST-019 data registers, full and empty", "REQ-FUNC-030 REQ-IF-008 INV-002 REQ-FUNC-013");
    hw_reset();
    cap = DEPTH * LINES;
    if (TX_EN != 0) begin
      for (int i = 0; i < cap; i++) wr32(U(0, R_DATA), 32'h1000 + i);
      rd32(U(0, R_STS), v);
      sb(6, 1'b1, v[27:16] == cap && v[2] && !v[1], $sformatf("TX full after %0d writes: sts %h", cap, v));
      wr32(R_IRAW, 32'h4); wait_apb(4);
      wr32(U(0, R_DATA), 32'hDEAD);
      wait_apb(8);
      rd32(U(0, R_STS), v);
      sb(6, 1'b1, v[27:16] == cap, "write to a full FIFO dropped: level unchanged");
      rd32(R_IRAW, v);
      sb(6, 1'b1, v[I_TXOVR], "write to a full FIFO sets the transmit overrun cause");
      flush_unit(0);
      rd32(U(0, R_STS), v);
      sb(6, 1'b1, v[27:16] == 0 && v[1] && !v[2], "flush empties the FIFO");
      rd32(U(0, R_CTRL), v);
      sb(3, 1'b1, v[C_FLUSH] == 0 && v[C_SRST] == 0, "flush and reset bits read 0 (REQ-REG-006)");
    end
    if (RX_EN != 0) begin
      rd32(U(1, R_DATA), v);
      sb(7, 1'b1, v == 32'h0, "read of an empty receive FIFO returns 0");
      rd32(U(1, R_STS), v);
      sb(7, 1'b1, v[1] && v[27:16] == 0, "an empty read has no other effect");
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-003/004/005 formats
task automatic fmt_set(input int idx, output int fmt, output int nslot, output int slot_w, output int dw,
                       output logic [31:0] mask, output int sw, output int fsp, output int fse);
  begin
    fsp = 0; fse = 1; sw = 1; mask = 32'hFFFFFFFF;
    case (idx)
      0: begin fmt = 1; nslot = 2; slot_w = 16; dw = 16; end              // Philips I2S
      1: begin fmt = 2; nslot = 2; slot_w = 32; dw = 24; end              // left-justified
      2: begin fmt = 3; nslot = 4; slot_w = 16; dw = 16; mask = 32'hB; end // PCM short, slot 2 masked
      3: begin fmt = 4; nslot = 2; slot_w = 16; dw = 16; end              // PCM long
      4: begin fmt = 5; nslot = 4; slot_w = 8;  dw = 8;  end              // TDM
      5: begin fmt = 0; nslot = 2; slot_w = 16; dw = 12; sw = 3; fsp = 1; fse = 0; end // custom
      default: begin fmt = 1; nslot = 2; slot_w = 16; dw = 16; end
    endcase
    if (FMT_EXT_EN == 0) begin fmt = 1; nslot = 2; mask = 32'hFFFFFFFF; sw = 1; fsp = 0; fse = 1; end
  end
endtask

task automatic t_tx_formats();
  int fmt, nslot, slot_w, dw, sw, fsp, fse;
  logic [31:0] mask;
  begin
    begin_test("TEST-003/005 transmit formats", "REQ-FUNC-003..009 REQ-IF-011 REQ-FUNC-017");
    for (int i = 0; i < ((FMT_EXT_EN != 0) ? 6 : 1); i++) begin
      for (int m = 0; m < ((MASTER_EN != 0) ? 2 : 1); m++) begin
        fmt_set(i, fmt, nslot, slot_w, dw, mask, sw, fsp, fse);
        tx_scn($sformatf("tx fmt%0d idx%0d %s", fmt, i, m ? "IP slave" : "IP master"), fmt, nslot, slot_w, dw, 0, 0,
               mask, (MASTER_EN != 0) ? (m == 0) : 0, 2, 0, sw, fsp, fse, 3, 0, 16);
      end
    end
    end_test();
  end
endtask

task automatic t_rx_formats();
  int fmt, nslot, slot_w, dw, sw, fsp, fse;
  logic [31:0] mask;
  begin
    begin_test("TEST-004/005 receive formats", "REQ-FUNC-003 REQ-FUNC-009 REQ-FUNC-018 REQ-IF-011");
    for (int i = 0; i < ((FMT_EXT_EN != 0) ? 6 : 1); i++) begin
      for (int m = 0; m < ((MASTER_EN != 0) ? 2 : 1); m++) begin
        fmt_set(i, fmt, nslot, slot_w, dw, mask, sw, fsp, fse);
        rx_scn($sformatf("rx fmt%0d idx%0d %s", fmt, i, m ? "IP slave" : "IP master"), fmt, nslot, slot_w, dw, 0, 0,
               mask, (MASTER_EN != 0) ? (m == 0) : 0, 2, 0, sw, fsp, fse, 3, 16);
      end
    end
    end_test();
  end
endtask

// slave at the lowest legal ratio: the master clock is 8 times the bit clock (REQ-FUNC-018, DEP-004)
task automatic t_ratio8();
  begin
    begin_test("TEST-004 slave at ratio 8", "REQ-FUNC-018 ASM-008 TBD-001");
    // Finding F-2 (TBD-001): with a synchronizer depth above 2 the data of a slave at ratio 8 arrives after the
    // device samples it, so a build with SYNC_DEPTH > 2 is tested at ratio 12 (bit clock half period of 6 master clocks).
    tx_scn("tx slave ratio 8", 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 0, 2, 0, 1, 0, 1, 3, 0, (SYNC_DEPTH > 2) ? 6 : 4);
    rx_scn("rx slave ratio 8", 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 0, 2, 0, 1, 0, 1, 3, (SYNC_DEPTH > 2) ? 6 : 4);
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-006 widths, alignment, packing
task automatic t_widths();
  int dws [0:5];
  int sw;
  begin
    begin_test("TEST-006 data width, alignment, packing", "REQ-FUNC-009 REQ-FUNC-010 9");
    dws[0] = 8; dws[1] = 12; dws[2] = 16; dws[3] = 20; dws[4] = 24; dws[5] = 32;
    for (int i = 0; i < 6; i++) begin
      for (int al = 0; al < 2; al++) begin
        for (int pk = 0; pk < 2; pk++) begin
          if ((pk == 0 || (dws[i] <= 16 && PACK_EN != 0)) && (FMT_EXT_EN != 0 || (dws[i] == 16 && al == 0 && pk == 0) || 1)) begin
            sw = (dws[i] <= 16) ? 16 : 32;
            if (dws[i] == 8) sw = 8;
            tx_scn($sformatf("tx dw%0d al%0d pk%0d", dws[i], al, pk), 1, 2, sw, dws[i], al, pk, 32'hFFFFFFFF, 1, 2, 0, 1, 0, 1, 2, 0, 16);
            rx_scn($sformatf("rx dw%0d al%0d pk%0d", dws[i], al, pk), 1, 2, sw, dws[i], al, pk, 32'hFFFFFFFF, 0, 2, 0, 1, 0, 1, 2, 16);
          end
        end
      end
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-007 lines and masks
task automatic t_lines_masks();
  logic [31:0] m;
  int ns;
  begin
    begin_test("TEST-007 lines, slot masks, word order", "REQ-FUNC-011 REQ-FUNC-012 REQ-FUNC-013 INV-001");
    for (int i = 0; i < 6; i++) begin
      ns = (FMT_EXT_EN != 0) ? ((i % 2) ? 8 : 4) : 2;
      if (ns > MAX_SLOTS && FMT_EXT_EN != 0) ns = MAX_SLOTS;
      m = rnd_mask(ns, 0);
      if (FMT_EXT_EN == 0) m = (i % 2) ? 32'h1 : 32'h2;
      tx_scn($sformatf("tx mask %h of %0d slots", m, ns), (FMT_EXT_EN != 0) ? 5 : 1, ns, 8, 8, 0, 0, m, 1, 2, 0, 1, 0, 1, 2, 0, 16);
      rx_scn($sformatf("rx mask %h of %0d slots", m, ns), (FMT_EXT_EN != 0) ? 5 : 1, ns, 8, 8, 0, 0, m, 0, 2, 0, 1, 0, 1, 2, 16);
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-008 mask change and tri-state
task automatic t_mask_change();
  int t, fed, k, nfr;
  logic [31:0] lvl;
  bit [31:0] seen [int];
  begin
    begin_test("TEST-008 mask change, tri-state", "REQ-FUNC-011 INV-005 REQ-FUNC-020");
    if (TX_EN != 0 && FMT_EXT_EN != 0 && MAX_SLOTS >= 4) begin
      // static mask, tri-state off and on
      for (int trs = 0; trs < ((TRI_EN != 0) ? 2 : 1); trs++) begin
        tx_scn($sformatf("tx trs=%0d mask B", trs), 5, 4, 8, 8, 0, 0, 32'hB, 1, 2, 0, 1, 0, 1, 3, trs, 16);
        if (trs == 0) check(dtx.msk_oe_high > 0 && dtx.msk_oe_low == 0, "masked slots drive zero with the output enable high when tri-state is off");
        else          check(dtx.msk_oe_low > 0 && dtx.msk_oe_high == 0, $sformatf("masked slots release the lines when tri-state is on (low=%0d high=%0d cap=%0d)", dtx.msk_oe_low, dtx.msk_oe_high, dtx.cap_val.size()));
      end
      // mask change while running: applies at a frame boundary; words keep their order
      hw_reset();
      dev_cfg(0, 5, 4, 8, 8, 0, 1, 0, 1, 32'hF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.chk_mask = 0; dtx.div = 2;
      cfg_unit(0, 5, 4, 8, 8, 0, 0, 32'hF, 2, 0, 1, 0, 1, 4);
      fed = 0;
      for (int i = 0; i < DEPTH * LINES / 2; i++) begin words[fed % 2048] = 32'h5000 + (fed % 250) + 1; wr32(U(0, R_DATA), words[fed % 2048]); fed++; end
      unit_en(0, (1 << C_ROLE));
      t = 0; nfr = 0;
      while (dtx.frames_seen < 30 && t < 3000) begin
        rd32(U(0, R_STS), lvl);
        if (lvl[27:16] + 8 <= DEPTH * LINES && fed < 2000) begin
          for (int i = 0; i < 8; i++) begin words[fed % 2048] = 32'h5000 + (fed % 250) + 1; wr32(U(0, R_DATA), words[fed % 2048]); fed++; end
        end
        if (dtx.frames_seen == 8) wr32(U(0, R_MASK), 32'h5);
        if (dtx.frames_seen == 16) wr32(U(0, R_MASK), 32'hE);
        if (dtx.frames_seen == 24) wr32(U(0, R_MASK), 32'hF);
        t++;
      end
      unit_dis(0); dtx.run = 0;
      // masked slots carry zeros; the other samples keep the written order; each frame has one slot set
      begin
        int j, ok, nfrs;
        j = 0;
        for (int i = 0; i < dtx.cap_val.size(); i++) begin
          if (dtx.cap_val[i] != 0) begin
            if (j < fed) sb(1, 1'b1, dtx.cap_val[i] === (words[j % 2048] & 32'hFF), $sformatf("mask change: data sample %0d got %h", j, dtx.cap_val[i]));
            j++;
            seen[dtx.cap_frame[i]] |= (32'h1 << dtx.cap_slot[i]);
          end
        end
        ok = 1; nfrs = 0;
        foreach (seen[f]) begin
          if (f == dtx.frames_seen - 1 || f == dtx.frames_seen) continue;   // the last frame may be cut by the end of the data
          nfrs++;
          if (!(seen[f] == 32'hF || seen[f] == 32'h5 || seen[f] == 32'hE)) begin ok = 0; $display("  frame %0d slot set %h", f, seen[f]); end
        end
        check(ok && nfrs > 20, $sformatf("every frame carries one programmed slot set (%0d frames)", nfrs));
        check(j > 40, "mask change: enough data samples were sent");
      end
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-009 underrun
task automatic t_underrun();
  int t, base, e0, e1;
  logic [31:0] v;
  begin
    begin_test("TEST-009 transmit underrun", "REQ-FUNC-014 REQ-ERR-001 ERR-001");
    if (TX_EN != 0 && MASTER_EN != 0) begin
      for (int au = 0; au < 2; au++) begin
        hw_reset();
        dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.chk_mask = 1; dtx.div = 2; dtx.run = 1; dtx.chk_en = 0;
        cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 2 * LINES; i++) wr32(U(0, R_DATA), 32'hA000 + i);
        unit_en(0, (1 << C_ROLE) | (au << C_AUTO));
        wait_m(6000);
        rd32(R_IRAW, v);
        sb(12, 1'b1, v[I_TXUND], $sformatf("auto=%0d: underrun cause set", au));
        rd32(U(0, R_STS), v);
        sb(12, 1'b1, v[0], $sformatf("auto=%0d: unit stays busy after the underrun", au));
        // the first frame carries the words; later slots carry zeros
        sb(12, 1'b1, dtx.cap_val.size() >= 2 * LINES && dtx.cap_val[0] === 32'hA000, "first frame carries the written words");
        if (au == 0) begin
          e0 = dtx.ws_edges; wait_m(4000); e1 = dtx.ws_edges;
          sb(12, 1'b1, e0 == e1, "auto restart off: no frame starts while the unit is in the error state");
          for (int i = 0; i < 2 * LINES; i++) wr32(U(0, R_DATA), 32'hB000 + i);
          wait_m(4000);
          sb(12, 1'b1, dtx.ws_edges == e1, "auto restart off: refilling alone does not restart the unit");
          e0 = dtx.ws_edges;
          wr32(U(0, R_CTRL), 32'h1 | (1 << C_ROLE) | (1 << C_FLUSH));
          wait_m(3000);
          sb(12, 1'b1, dtx.ws_edges > e0, "auto restart off: the flush takes the unit out of the error state (frames start again)");
          // recover by software: stop, flush, refill, start
          unit_dis(0);
          flush_unit(0);
          for (int i = 0; i < 2 * LINES; i++) wr32(U(0, R_DATA), 32'hC000 + i);
          unit_en(0, (1 << C_ROLE));
          wait_m(6000);
        end else begin
          for (int i = 0; i < 2 * LINES; i++) wr32(U(0, R_DATA), 32'hC000 + i);
          wait_m(6000);
        end
        // the new words arrive in order after the restart at a frame boundary
        begin
          int fnd;
          fnd = 0;
          for (int i = 0; i + 2 * LINES <= dtx.cap_val.size(); i++) begin
            int ok; ok = 1;
            for (int j = 0; j < 2 * LINES; j++) if (dtx.cap_val[i + j] !== (32'hC000 + j)) ok = 0;
            if (ok) fnd = 1;
          end
          sb(12, 1'b1, fnd == 1, $sformatf("auto=%0d: words written after the error are sent from a frame boundary", au));
        end
        unit_dis(0); dtx.run = 0;
      end
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-010 overrun
task automatic t_overrun();
  int cap, nf, t, off;
  logic [31:0] v, w0, got1;
  int ok;
  begin
    begin_test("TEST-010 receive overrun", "REQ-FUNC-015 REQ-ERR-001 ERR-003");
    if (RX_EN != 0) begin
      cap = DEPTH * LINES;
      for (int au = 0; au < 2; au++) begin
        hw_reset();
        dev_cfg(1, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
        drx.src_en = 1; drx.master = 1; drx.hp_ps = 16 * TM_PS; drx.div = 2;
        cfg_unit(1, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        nf = cap / (2 * LINES) + 3;
        for (int i = 0; i < nf * 2 * LINES; i++) drx.src_q.push_back(32'h1000 + i);
        unit_en(1, (au << C_AUTO));
        wait_apb(20); drx.run = 1;
        t = 0; v = 0;
        while (!v[I_RXOVR] && t < 400) begin wait_m(300); rd32(R_IRAW, v); t++; end
        sb(12, 1'b1, v[I_RXOVR], $sformatf("auto=%0d: overrun cause set", au));
        rd32(U(1, R_STS), v);
        sb(12, 1'b1, v[2] && v[27:16] == cap, "FIFO is full and keeps its content");
        // the oldest words are kept, the later ones were dropped (INV-002)
        ok = 1;
        for (int i = 0; i < cap; i++) begin rd32(U(1, R_DATA), w0); if (w0 !== 32'h1000 + i) ok = 0; end
        sb(1, 1'b1, ok == 1, "the first words of the stream were received in order and the others dropped");
        if (au == 0) begin
          wait_m(4000);
          rd32(U(1, R_STS), v);
          sb(12, 1'b1, v[27:16] == 0, "auto restart off: no word is stored while the unit is in the error state");
          flush_unit(1);
          wr32(U(1, R_CTRL), 32'h1);   // flush self-cleared; keep enabled
          drx.src_q.delete();
          for (int i = 0; i < 6 * LINES; i++) drx.src_q.push_back(32'h7000 + i);
          wait_m(6000);
          rd32(U(1, R_STS), v);
          sb(12, 1'b1, v[27:16] >= 2 * LINES, "after the flush the unit receives again");
        end else begin
          drx.src_q.delete();
          for (int i = 0; i < 6 * LINES; i++) drx.src_q.push_back(32'h7000 + i);
          wait_m(6000);
          rd32(U(1, R_STS), v);
          sb(12, 1'b1, v[27:16] >= 2 * LINES, "auto restart on: the unit receives again by itself");
        end
        t = 0; v = 0;
        while (v[27:16] < 2 * LINES && t < 100) begin wait_m(200); rd32(U(1, R_STS), v); t++; end
        rd32(U(1, R_DATA), w0);
        // the stream went on while the software read: the words that follow are consecutive and start at a slot boundary
        ok = 1;
        if (w0 >= 32'h7000) off = w0 - 32'h7000; else off = w0 - 32'h1000;
        if ((off % LINES) != 0) ok = 0;
        for (int i = 1; i < 2 * LINES; i++) begin rd32(U(1, R_DATA), got1); if (got1 !== w0 + i && got1 !== 32'h7000) ok = 0; w0 = (got1 === 32'h7000) ? 32'h7000 - i : w0; end
        sb(12, 1'b1, ok == 1, $sformatf("auto=%0d: after the restart the words are consecutive from a slot boundary (first %h)", au, w0));
        unit_dis(1); drx.run = 0;
      end
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-011 watermark
task automatic t_watermark();
  logic [31:0] v;
  int t, wmk;
  begin
    wmk = (DEPTH * LINES / 2 < 4) ? (DEPTH * LINES / 2) : 4;
    if (wmk < 1) wmk = 1;
    begin_test("TEST-011 watermark causes", "REQ-FUNC-016 ASM-010");
    hw_reset();
    wr32(U(0, R_FIFO), wmk); wr32(U(1, R_FIFO), wmk);
    if (TX_EN != 0) begin
      rd32(R_IRAW, v);
      sb(11, 1'b1, v[I_TXWM], "TX: level 0 is at or below the watermark: cause set");
      wr32(R_IRAW, 32'h1); wait_apb(6); rd32(R_IRAW, v);
      sb(11, 1'b1, v[I_TXWM], "TX: the cause is loaded again while the condition holds");
      for (int i = 0; i < wmk + 1; i++) wr32(U(0, R_DATA), 32'h100 + i);
      wr32(R_IRAW, 32'h1); wait_apb(6); rd32(R_IRAW, v);
      sb(11, 1'b1, !v[I_TXWM], "TX: level above the watermark: the cleared cause stays clear");
      flush_unit(0); wait_apb(10); rd32(R_IRAW, v);
      sb(11, 1'b1, v[I_TXWM], "TX: level back at 0 sets the cause");
      wr32(U(0, R_FIFO), 0);
      wr32(U(0, R_DATA), 32'h1); wait_apb(6);
      wr32(R_IRAW, 32'h1); wait_apb(6); rd32(R_IRAW, v);
      sb(11, 1'b1, !v[I_TXWM], "TX: watermark 0 and level 1: condition false");
      wr32(U(0, R_FIFO), wmk); flush_unit(0);
    end
    if (RX_EN != 0) begin
      rd32(R_IRAW, v);
      sb(11, 1'b1, !v[I_RXWM], "RX: empty FIFO is below the watermark: no cause");
      dev_cfg(1, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      drx.src_en = 1; drx.master = 1; drx.hp_ps = 16 * TM_PS; drx.div = 2;
      cfg_unit(1, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, wmk);
      for (int i = 0; i < 64 * LINES; i++) drx.src_q.push_back(32'h200 + i);
      unit_en(1, 0); wait_apb(20); drx.run = 1;
      wait_m(5000);
      unit_dis(1); drx.run = 0;
      rd32(U(1, R_STS), v);
      sb(11, 1'b1, v[27:16] >= wmk, "RX: level reached the watermark");
      rd32(R_IRAW, v);
      sb(11, 1'b1, v[I_RXWM], "RX: level at or above the watermark sets the cause");
      for (int i = 0; i < 400; i++) begin rd32(U(1, R_STS), v); if (v[27:16] >= wmk) rd32(U(1, R_DATA), r_); end
      rd32(U(1, R_STS), v);
      wr32(R_IRAW, 32'h8); wait_apb(6); rd32(R_IRAW, v);
      sb(11, 1'b1, !v[I_RXWM], "RX: level below the watermark: the cleared cause stays clear");
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-012 sync error and hung clock
task automatic drain_rx();
  logic [31:0] st, d;
  begin
    rd32(U(1, R_STS), st);
    while (!st[1]) begin rd32(U(1, R_DATA), d); rd32(U(1, R_STS), st); end
  end
endtask
task automatic t_sync_hung();
  logic [31:0] v;
  int t, ok;
  begin
    begin_test("TEST-012 frame sync error, hung clock", "REQ-FUNC-022 REQ-FUNC-023 ERR-004 ERR-005");
    if (RX_EN != 0) begin
      hw_reset();
      dev_cfg(1, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      drx.src_en = 1; drx.master = 1; drx.hp_ps = 16 * TM_PS; drx.div = 2;
      cfg_unit(1, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      for (int i = 0; i < 4000; i++) drx.src_q.push_back(32'h300 + (i % 4000));
      wr32(U(1, R_TMO), 2);
      unit_en(1, (1 << C_AUTO)); wait_apb(20); drx.run = 1;
      for (int i = 0; i < 6; i++) begin wait_m(500); drain_rx(); end
      rd32(R_IRAW, v); sb(12, 1'b1, !v[I_SYNC], "no sync error in a clean stream");
      drx.glitch_t = 20;          // one extra frame sync inside the right slot of a Philips frame
      for (int i = 0; i < 6; i++) begin wait_m(500); drain_rx(); end
      drx.glitch_t = -1;
      rd32(R_IRAW, v); check(v[I_SYNC], "frame sync inside a frame sets the sync cause (REQ-FUNC-022)");
      rd32(U(1, R_STS), v); check(v[4], "frame sync inside a frame sets the unit sync flag");
      wr32(U(1, R_STS), 32'h10); wr32(R_IRAW, 32'h20); wait_apb(10);
      rd32(U(1, R_STS), v); check(!v[4], "the sync flag is cleared by writing 1");
      rd32(R_IRAW, v); check(!v[I_SYNC], "the sync cause is cleared by writing 1");
      if (HUNG_EN != 0) begin
        // stop the bit clock: the hung cause comes after about timeout x 256 master clock cycles
        drx.clk_stop = 1;
        wait_m(2 * 256 - 200);
        rd32(R_IRAW, v); check(!v[I_HUNG], "no hung cause before the timeout (REQ-FUNC-023)");
        wait_m(600);
        rd32(R_IRAW, v); check(v[I_HUNG], "hung cause after the timeout (REQ-FUNC-023)");
        rd32(U(1, R_STS), v); check(v[5], "unit hung flag set");
        wr32(U(1, R_STS), 32'h20); wr32(R_IRAW, 32'h40);
        drx.clk_stop = 0;
      end
      unit_dis(1); drx.run = 0;
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-013 dividers
task automatic t_dividers();
  int divs [0:6];
  begin
    begin_test("TEST-013 bit clock divider, start and stop", "REQ-FUNC-017 REQ-FUNC-020 REQ-CLK-004");
    divs[0] = 1; divs[1] = 2; divs[2] = 3; divs[3] = 5; divs[4] = 8; divs[5] = 16; divs[6] = 33;
    if (MASTER_EN != 0) begin
      for (int i = 0; i < 7; i++) begin
        tx_scn($sformatf("tx master divider %0d", divs[i]), 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 1, divs[i], 0, 1, 0, 1, 2, 0, 16);
        rx_scn($sformatf("rx master divider %0d", divs[i]), 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 1, divs[i], 0, 1, 0, 1, 2, 16);
      end
      tx_scn("tx master bpol 1", 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 1, 3, 1, 1, 0, 1, 2, 0, 16);
      rx_scn("rx master bpol 1", 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 1, 3, 1, 1, 0, 1, 2, 16);
    end
    tx_scn("tx slave bpol 1", 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 0, 2, 1, 1, 0, 1, 2, 0, 16);
    rx_scn("rx slave bpol 1", 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 0, 2, 1, 1, 0, 1, 2, 16);
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-014 shared clock and independence
task automatic t_shared();
  int nw, t;
  logic [31:0] v, got;
  int errs;
  begin
    begin_test("TEST-014 shared clock, independent units", "REQ-FUNC-019 REQ-FUNC-031");
    if (TX_EN != 0 && RX_EN != 0 && MASTER_EN != 0) begin
      // receive unit uses the clock and frame sync of the transmit master
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dev_cfg(1, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      drx.src_en = 1; drx.master = 0; drx.run = 1; drx.div = 2;
      rx_follow_tx = 1;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      cfg_unit(1, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      nw = (DEPTH * LINES / (2 * LINES)) * 2 * LINES;
      if (nw > 6 * LINES) nw = 6 * LINES;
      for (int i = 0; i < nw; i++) begin words[i] = rnd32(); wr32(U(0, R_DATA), words[i]); end
      for (int i = 0; i < nw; i++) begin samp[i] = rnd32() & 32'hFFFF; drx.src_q.push_back(samp[i]); end
      unit_en(1, (1 << C_SHR));
      wait_apb(20);
      unit_en(0, (1 << C_ROLE));
      t = 0; r_ = 0;
      while (r_[27:16] < nw && t < 400) begin wait_m(300); rd32(U(1, R_STS), r_); t++; end
      check(r_[27:16] >= nw, $sformatf("shared clock: RX level %0d of %0d", r_[27:16], nw));
      dtx.chk_en = 0; drx.chk_en = 0;
      errs = 0;
      for (int i = 0; i < nw; i++) begin rd32(U(1, R_DATA), got); if (got !== samp[i]) errs++; end
      sb(1, 1'b1, errs == 0, "shared clock: received words equal the device samples");
      errs = 0;
      for (int i = 0; i < nw && i < dtx.cap_val.size(); i++) if (dtx.cap_val[i] !== (words[i] & 32'hFFFF)) errs++;
      sb(1, 1'b1, errs == 0 && dtx.cap_val.size() >= nw, "shared clock: the transmit stream is correct at the same time");
      dtx.chk_en = 0; drx.chk_en = 0;
      unit_dis(1); unit_dis(0); dtx.run = 0; drx.run = 0; rx_follow_tx = 0;
      dtx.chk_en = 1; drx.chk_en = 1;

      // independent units: the receive unit has its own clock, starts and stops while the transmitter runs
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dev_cfg(1, 2, 2, 32, 24, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      drx.src_en = 1; drx.master = 1; drx.hp_ps = 24 * TM_PS; drx.div = 2;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      cfg_unit(1, 2, 2, 32, 24, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      nw = 6 * LINES;
      for (int i = 0; i < nw; i++) begin words[i] = rnd32(); wr32(U(0, R_DATA), words[i]); end
      for (int i = 0; i < 2 * LINES * 3; i++) drx.src_q.push_back(32'h400000 + i);
      unit_en(0, (1 << C_ROLE));
      wait_m(500);
      unit_en(1, 0); wait_apb(20); drx.run = 1;
      wait_m(3000);
      unit_dis(1); drx.run = 0;
      wait_m(3000);
      errs = 0;
      for (int i = 0; i < nw && i < dtx.cap_val.size(); i++) if (dtx.cap_val[i] !== (words[i] & 32'hFFFF)) errs++;
      sb(1, 1'b1, errs == 0 && dtx.cap_val.size() >= nw, "independent units: the transmit stream is not disturbed by the receive unit");
      dtx.chk_en = 0;
      unit_dis(0); dtx.run = 0;
      dtx.chk_en = 1;
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-015 on-demand
task automatic t_ondemand();
  logic [31:0] v;
  int e0;
  begin
    begin_test("TEST-015 on-demand frame start", "REQ-FUNC-021 OP-009");
    if (TX_EN != 0 && MASTER_EN != 0 && ONDEM_EN != 0) begin
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      unit_en(0, (1 << C_ROLE) | (1 << C_ONDEM));
      wait_m(3000);
      rd32(R_IRAW, v); sb(12, 1'b1, !v[I_TXUND], "on-demand: an empty FIFO stalls the master and raises no underrun");
      dtx.check_ws_idle();
      check(dtx.ws_edges == 0, "on-demand: no frame starts without data");
      for (int rep = 0; rep < 4; rep++) begin
        for (int i = 0; i < 2 * LINES; i++) wr32(U(0, R_DATA), 32'h900 + rep * 16 + i);
        wait_m(3000);
        rd32(R_IRAW, v); sb(12, 1'b1, !v[I_TXUND], "on-demand: no underrun with slow software");
        dtx.check_ws_idle();
      end
      check(dtx.cap_val.size() >= 8 * LINES && dtx.cap_val[0] === 32'h900, $sformatf("on-demand: the frames carried the words in order (%0d samples, first %h)", dtx.cap_val.size(), dtx.cap_val.size() > 0 ? dtx.cap_val[0] : 32'hx));
      unit_dis(0); dtx.run = 0;
    end
    if (RX_EN != 0 && MASTER_EN != 0 && ONDEM_EN != 0) begin
      hw_reset();
      dev_cfg(1, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      drx.src_en = 1; drx.master = 0; drx.run = 1; drx.div = 2;
      cfg_unit(1, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      for (int i = 0; i < 4 * DEPTH * LINES; i++) drx.src_q.push_back(32'h2000 + i);
      unit_en(1, (1 << C_ROLE) | (1 << C_ONDEM));
      wait_m(DEPTH * LINES * 400);
      rd32(R_IRAW, v); sb(12, 1'b1, !v[I_RXOVR], "on-demand: a full receive FIFO stalls the master and raises no overrun");
      rd32(U(1, R_STS), v); check(v[27:16] >= DEPTH * LINES - 2 * LINES, "on-demand: the FIFO filled before the stall");
      begin
        int ok; ok = 1;
        for (int i = 0; i < 3 * DEPTH * LINES; i++) begin
          rd32(U(1, R_STS), v);
          while (v[1] && i < 3 * DEPTH * LINES) begin wait_m(100); rd32(U(1, R_STS), v); end
          rd32(U(1, R_DATA), r_);
          if (r_ !== 32'h2000 + i) ok = 0;
        end
        sb(1, 1'b1, ok == 1, "on-demand: all words arrive in order with a slow reader");
      end
      rd32(R_IRAW, v); sb(12, 1'b1, !v[I_RXOVR], "on-demand: still no overrun after draining");
      unit_dis(1); drx.run = 0;
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-016 interrupts
task automatic t_irq();
  logic [31:0] v, en, inj, expv;
  begin
    begin_test("TEST-016 interrupt registers", "REQ-IF-009 REQ-IF-010 REQ-FUNC-024");
    hw_reset();
    // injection of every cause with the mask off and on
    for (int b = 0; b < 8; b++) begin
      wr32(R_IEN, 32'h0); wr32(R_IRAW, 32'hFF); wr32(R_IINJ, 32'h0); wait_apb(6);
      if (b == I_TXWM || b == I_RXWM) begin end   // level causes may be set by their condition
      wr32(R_IINJ, 32'h1 << b); wait_apb(8);
      rd32(R_IRAW, v); sb(5, 1'b1, v[b], $sformatf("injection sets raw bit %0d", b));
      rd32(R_ISTS, v); sb(4, 1'b1, !v[b], $sformatf("masked status %0d is 0 while the enable is off", b));
      check(irq === 1'b0 || (b == I_TXWM || b == I_RXWM), $sformatf("pin low with all enables off (bit %0d)", b));
      wr32(R_IEN, 32'h1 << b); wait_apb(8);
      rd32(R_ISTS, v); sb(4, 1'b1, v[b], $sformatf("masked status %0d follows raw AND enable", b));
      check(irq === 1'b1, $sformatf("pin high with enable %0d", b));
      rd32(R_GSTS, v); check(v[4], "global status irq flag");
      // clear while the injection bit is still 1: no new edge, so the cause stays clear
      wr32(R_IRAW, 32'h1 << b); wait_apb(8);
      rd32(R_IRAW, v);
      if (b != I_TXWM && b != I_RXWM) sb(5, 1'b1, !v[b], $sformatf("raw bit %0d stays clear while the injection bit is held", b));
      wr32(R_IINJ, 32'h0);
    end
    // random enable and injection patterns: status = raw AND enable, pin = OR of the status
    for (int i = 0; i < 24; i++) begin
      en = rnd32() & 32'hFF; inj = rnd32() & 32'hFF;
      wr32(R_IEN, 32'h0); wr32(R_IINJ, 32'h0); wr32(R_IRAW, 32'hFF); wait_apb(8);
      wr32(R_IINJ, inj); wr32(R_IEN, en); wait_apb(10);
      rd32(R_IRAW, v); expv = v & en;
      rd32(R_ISTS, v);
      sb(4, 1'b1, v[7:0] == expv[7:0], $sformatf("status %h equals raw AND enable %h", v[7:0], expv[7:0]));
      check(irq === (|expv[7:0]), "pin equals the OR of the masked status");
      wr32(R_IINJ, 32'h0);
    end
    wr32(R_IEN, 32'h0); wr32(R_IRAW, 32'hFF);
    // frame-done cause from the unit chosen by frm_sel (REQ-FUNC-024)
    if (TX_EN != 0 && MASTER_EN != 0) begin
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      wr32(R_GCTRL, 32'h0);
      for (int i = 0; i < 4 * LINES; i++) wr32(U(0, R_DATA), 32'h1 + i);
      unit_en(0, (1 << C_ROLE) | (1 << C_AUTO));
      wait_m(3000);
      rd32(R_IRAW, v); check(v[I_FRM], "frame-done cause set for the transmit unit (frm_sel 0)");
      unit_dis(0); dtx.run = 0;
      hw_reset();
      wr32(R_GCTRL, 32'h10);      // frame done from the receive unit: transmit frames do not set it
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      dtx.run = 1;
      for (int i = 0; i < 4 * LINES; i++) wr32(U(0, R_DATA), 32'h1 + i);
      unit_en(0, (1 << C_ROLE) | (1 << C_AUTO));
      wait_m(3000);
      rd32(R_IRAW, v); check(!v[I_FRM], "frame-done cause not set by the transmit unit when frm_sel selects the receiver");
      unit_dis(0); dtx.run = 0;
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-017 DMA
logic dma_run = 0;
int   dma_burst = 4;
task automatic dma_tx_bfm_once(input int nwords, input int base);
  int t;
  begin
    t = 0;
    while (!dma_tx_req && t < 2000) begin @(posedge clk_apb); t++; end
    if (t >= 2000) begin check(1'b0, "DMA transmit request did not come"); end
    else begin
      repeat (2) @(posedge clk_apb);
      for (int i = 0; i < nwords; i++) wr32(U(0, R_DATA), base + i);
      #1 dma_tx_ack = 1;
      repeat (3) @(posedge clk_apb);
      #1 dma_tx_ack = 0;
      repeat (2) @(posedge clk_apb);
    end
  end
endtask
task automatic t_dma();
  logic [31:0] v;
  int t, ok;
  begin
    begin_test("TEST-017 DMA handshake", "REQ-FUNC-028 REQ-FUNC-029 REQ-IF-012 INV-006");
    if (DMA_EN != 0) begin
      if (TX_EN != 0) begin
        hw_reset();
        dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
        cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        check(!dma_tx_req && !dma_tx_single, "no request and no single while the DMA enable bit is 0");
        dma_en_tx = 1;
        wr32(U(0, R_CTRL), (1 << C_DMA));
        wait_apb(8);
        check(dma_tx_req && dma_tx_single, "level 0 is at or below the watermark: request and single are high");
        // burst: the DMA writes words, then acknowledges
        sb(9, 1'b1, dma_tx_req, "request waits for the acknowledge");
        for (int i = 0; i < DEPTH * LINES / 2; i++) wr32(U(0, R_DATA), 32'h4000 + i);
        wait_apb(4);
        check(dma_tx_req, "request stays high until the acknowledge even if the level rose");
        #1 dma_tx_ack = 1;
        repeat (2) @(posedge clk_apb);
        sb(9, 1'b1, !dma_tx_req && !dma_tx_single, "request and single low while the acknowledge is high");
        #1 dma_tx_ack = 0;
        wait_apb(4);
        rd32(U(0, R_STS), v);
        check(dma_tx_req === (v[27:16] <= 4), "request again after the acknowledge falls only if the condition holds");
        // fill to full: no request, single low (no free word)
        for (int i = 0; i < DEPTH * LINES; i++) wr32(U(0, R_DATA), 32'h4100 + i);
        wait_apb(6);
        rd32(U(0, R_STS), v);
        check(!dma_tx_req && (v[2] ? !dma_tx_single : 1'b1), "full FIFO: no request, single low");
        // run the unit so that words drain: the request returns when the level reaches the watermark
        unit_en(0, (1 << C_ROLE) | (1 << C_DMA));
        t = 0;
        while (!dma_tx_req && t < 2000) begin wait_m(200); t++; end
        check(dma_tx_req, "request returns when the level falls to the watermark");
        dma_en_tx = 0;
        unit_dis(0); dtx.run = 0;
        wr32(U(0, R_CTRL), 32'h0);
        wait_apb(12);
        check(!dma_tx_req && !dma_tx_single, "DMA disabled: no request and no single");
        // single transactions with a watermark above the capacity: always requests
        wr32(U(0, R_FIFO), 0);
        dma_en_tx = 1; wr32(U(0, R_CTRL), (1 << C_DMA)); wait_apb(6);
        flush_unit(0, (1 << C_DMA));
        wait_apb(6);
        check(dma_tx_single, "empty FIFO: single high");
        dma_en_tx = 0; wr32(U(0, R_CTRL), 32'h0); wait_apb(12);
      end
      if (RX_EN != 0) begin
        hw_reset();
        dev_cfg(1, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
        drx.src_en = 1; drx.master = 1; drx.hp_ps = 16 * TM_PS; drx.div = 2;
        cfg_unit(1, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 8 * 2 * LINES; i++) drx.src_q.push_back(32'h8000 + i);
        dma_en_rx = 1;
        wr32(U(1, R_CTRL), (1 << C_DMA));
        wait_apb(8);
        check(!dma_rx_req && !dma_rx_single, "receive: empty FIFO: no request, no single");
        unit_en(1, (1 << C_DMA)); wait_apb(20); drx.run = 1;
        t = 0;
        while (!dma_rx_req && t < 2000) begin wait_m(200); t++; end
        check(dma_rx_req, "receive request once the level reaches the watermark");
        check(dma_rx_single, "receive single high while a word can be read");
        // the DMA reads a burst and acknowledges
        ok = 1;
        for (int i = 0; i < 4; i++) begin rd32(U(1, R_DATA), r_); if (r_ !== 32'h8000 + i) ok = 0; end
        sb(1, 1'b1, ok == 1, "DMA reads words in order from one address");
        #1 dma_rx_ack = 1;
        repeat (2) @(posedge clk_apb);
        sb(9, 1'b1, !dma_rx_req && !dma_rx_single, "receive request and single low while the acknowledge is high");
        #1 dma_rx_ack = 0;
        wait_apb(6);
        dma_en_rx = 0;
        unit_dis(1); drx.run = 0;
        wr32(U(1, R_CTRL), 32'h0); wait_apb(12);
      end
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-020 resets and flush
task automatic t_resets();
  logic [31:0] v, fr;
  int t;
  begin
    begin_test("TEST-020 soft reset, flush, reset in operation", "REQ-FUNC-025 REQ-REG-006 REQ-RESET-001/002");
    if (TX_EN != 0 && MASTER_EN != 0) begin
      // unit soft reset while running keeps the configuration
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      for (int i = 0; i < DEPTH * LINES; i++) wr32(U(0, R_DATA), 32'h700 + i);
      unit_en(0, (1 << C_ROLE) | (1 << C_AUTO));
      wait_m(1500);
      wr32(U(0, R_CTRL), (1 << C_ROLE) | (1 << C_AUTO) | (1 << C_SRST) | 32'h1);
      t = 0; v = 32'h1;
      while (v[0] && t < 400) begin wait_apb(10); rd32(U(0, R_STS), v); t++; end
      rd32(U(0, R_STS), v);
      check(v[27:16] == 0 && v[1], "unit soft reset empties the FIFO");
      rd32(U(0, R_FRAME), fr); check(fr == (1 | (2 << 8) | (16 << 16) | (16 << 24)), "unit soft reset keeps the configuration");
      rd32(U(0, R_CTRL), v); sb(3, 1'b1, v[C_SRST] == 0 && v[C_FLUSH] == 0, "the reset bit reads 0 after the reset");
      for (int i = 0; i < 2 * LINES; i++) wr32(U(0, R_DATA), 32'h900 + i);
      wait_m(3000);
      check(dtx.cap_val.size() > 0, "unit runs again after the soft reset with the kept configuration");
      // global soft reset
      wr32(R_GCTRL, 32'h1);
      t = 0; v = 32'h3;
      while (v[1:0] != 0 && t < 400 && 0) begin end
      wait_apb(200);
      rd32(R_GCTRL, v); sb(3, 1'b1, v[0] == 0, "the global reset bit reads 0");
      rd32(U(0, R_STS), v); check(v[27:16] == 0, "global soft reset empties the FIFO");
      unit_dis(0); dtx.run = 0;
    end
    // flush while stopped
    if (TX_EN != 0) begin
      hw_reset();
      for (int i = 0; i < 5; i++) wr32(U(0, R_DATA), i);
      flush_unit(0);
      rd32(U(0, R_STS), v); check(v[27:16] == 0, "flush while stopped empties the FIFO");
    end
    // hardware reset in the middle of a frame and of a bus transfer
    if (TX_EN != 0 && MASTER_EN != 0) begin
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      for (int i = 0; i < 4 * LINES; i++) wr32(U(0, R_DATA), 32'h700 + i);
      unit_en(0, (1 << C_ROLE) | (1 << C_AUTO));
      wait_m(777);
      hw_reset();
      dtx.check_idle(1'b1, 1'b1);
      check(!sdo_oe && !bclk_tx_oe && !ws_tx_oe && !sdo0, "reset in the middle of a frame: outputs idle (REQ-FUNC-001)");
      rd32(U(0, R_CTRL), v); check(v == 0, "reset in the middle of a frame: registers at their reset values");
      rd32(U(0, R_STS), v); check(v == 32'h2, "reset in the middle of a frame: FIFO empty, unit idle (REQ-RESET-002)");
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-021 clock ratios
task automatic t_clockratio();
  int aps [0:4];
  begin
    begin_test("TEST-021 clock ratios and phases", "REQ-CLK-001 REQ-CDC-001..004 DEC-008");
    aps[0] = 4000; aps[1] = 7300; aps[2] = 13000; aps[3] = 37000; aps[4] = 100000;
    for (int i = 0; i < 5; i++) begin
      apb_ps = aps[i];
      tx_scn($sformatf("tx apb period %0d ps", aps[i]), 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, (MASTER_EN != 0), 2, 0, 1, 0, 1, 2, 0, 16);
      rx_scn($sformatf("rx apb period %0d ps", aps[i]), 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 0, 2, 0, 1, 0, 1, 2, 16);
    end
    apb_ps = 13000;
    end_test();
  end
endtask

// ---------------------------------------------------------------- TEST-022 absent features
task automatic t_params();
  logic [31:0] v;
  begin
    begin_test("TEST-022 absent units and features", "REQ-PARAM-002 REQ-REG-007 DEC-009 DEC-019");
    hw_reset();
    rd32(R_CAP, v); check(v == exp_cap(), "capability register shows the build");
    if (TX_EN == 0) begin
      wr32(U(0, R_CTRL), 32'h1); wait_apb(20); rd32(U(0, R_STS), v);
      check(v[0] == 0, "absent transmit unit: enable has no effect, busy stays 0");
      check(!sdo_oe && !bclk_tx_oe && !ws_tx_oe, "absent transmit unit: pins tied off");
    end
    if (RX_EN == 0) begin
      wr32(U(1, R_CTRL), 32'h1); wait_apb(20); rd32(U(1, R_STS), v);
      check(v[0] == 0, "absent receive unit: enable has no effect, busy stays 0");
      check(!bclk_rx_oe && !ws_rx_oe, "absent receive unit: pins tied off");
    end
    if (MASTER_EN == 0 && TX_EN != 0) begin
      wr32(U(0, R_CTRL), 32'h11); wait_m(2000);
      check(!bclk_tx_oe && !ws_tx_oe, "no master built: a unit with the role bit set stays a slave");
      wr32(U(0, R_CTRL), 32'h0); wait_m(500);
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- random test (+SEED, +N)
task automatic t_random();
  int fmt, nslot, slot_w, dw, al, pk, sw, fsp, fse, dir, ipm, div, nfr, bpol;
  logic [31:0] mask;
  int maxs;
  begin
    begin_test("TEST-RND constrained random", "REQ-FUNC-003..013 REQ-IF-011 INV-001");
    for (int it = 0; it < n_rand; it++) begin
      if (FMT_EXT_EN != 0) begin
        fmt = rnd(6);
        maxs = (MAX_SLOTS < 8) ? MAX_SLOTS : 8;
        nslot = (fmt == 1 || fmt == 2) ? 2 : (2 + rnd(maxs - 1));
        if (fmt == 1 || fmt == 2) nslot = 2;
      end else begin fmt = 1; nslot = 2; end
      slot_w = 8 + 8 * rnd(3);
      dw = 8 + rnd(slot_w - 7);
      al = rnd(2);
      pk = (PACK_EN != 0 && dw <= 16) ? rnd(2) : 0;
      mask = (FMT_EXT_EN != 0) ? rnd_mask(nslot, pk) : 32'h3;
      sw = 1 + rnd(slot_w);
      fsp = rnd(2); fse = rnd(2);
      bpol = rnd(2);
      div = 1 + rnd(6);
      ipm = (MASTER_EN != 0) ? rnd(2) : 0;
      dir = rnd(2);
      nfr = 1 + rnd(3);
      if (dir == 0 && TX_EN != 0)
        tx_scn($sformatf("rnd%0d tx fmt%0d n%0d sw%0d dw%0d al%0d pk%0d m%h %s", it, fmt, nslot, slot_w, dw, al, pk, mask, ipm ? "M" : "S"),
               fmt, nslot, slot_w, dw, al, pk, mask, ipm, div, bpol, sw, fsp, fse, nfr, rnd(2), 8 + rnd(8));
      else if (RX_EN != 0)
        rx_scn($sformatf("rnd%0d rx fmt%0d n%0d sw%0d dw%0d al%0d pk%0d m%h %s", it, fmt, nslot, slot_w, dw, al, pk, mask, ipm ? "M" : "S"),
               fmt, nslot, slot_w, dw, al, pk, mask, ipm, div, bpol, sw, fsp, fse, nfr, 8 + rnd(8));
    end
    end_test();
  end
endtask

// ---------------------------------------------------------------- integrated flow: duplex with DMA and interrupts
task automatic t_integrated();
  logic [31:0] v, got;
  int t, nw, errs;
  begin
    begin_test("FLOW-001 duplex stream, DMA, interrupts", "REQ-FUNC-012 REQ-FUNC-016 REQ-FUNC-028 REQ-FUNC-031");
    if (TX_EN != 0 && RX_EN != 0 && MASTER_EN != 0 && DMA_EN != 0) begin
      hw_reset();
      dev_cfg(0, 5, 4, 16, 16, 0, 1, 0, 1, 32'hF);
      dev_cfg(1, 3, 2, 32, 24, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2;
      drx.src_en = 1; drx.master = 1; drx.hp_ps = 20 * TM_PS; drx.div = 2;
      cfg_unit(0, 5, 4, 16, 16, 0, 0, 32'hF, 2, 0, 1, 0, 1, 4 * LINES);   // the watermark covers a whole frame
      cfg_unit(1, 3, 2, 32, 24, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      wr32(R_IEN, 32'hFF);
      nw = 2 * DEPTH * LINES;
      if (nw > 96) nw = 96;
      for (int i = 0; i < nw; i++) drx.src_q.push_back(32'h100000 + i);
      dma_en_tx = 1; dma_en_rx = 1;
      unit_en(1, (1 << C_DMA)); wait_apb(20); drx.run = 1;
      unit_en(0, (1 << C_ROLE) | (1 << C_DMA) | (1 << C_AUTO));
      begin
        int sent, recv, guard;
        sent = 0; recv = 0; guard = 0;
        while ((sent < nw || recv < nw) && guard < 4000) begin
          guard++;
          if (dma_tx_req && sent < nw) begin
            for (int i = 0; i < 4 * LINES && sent < nw; i++) begin words[sent] = 32'h200001 + sent; wr32(U(0, R_DATA), words[sent]); sent++; end
            #1 dma_tx_ack = 1; repeat (2) @(posedge clk_apb); #1 dma_tx_ack = 0;
          end
          if (dma_rx_req && recv < nw) begin
            for (int i = 0; i < 4 && recv < nw; i++) begin
              rd32(U(1, R_DATA), got);
              sb(1, 1'b1, got === 32'h100000 + recv, $sformatf("duplex: RX word %0d got %h", recv, got));
              recv++;
            end
            #1 dma_rx_ack = 1; repeat (2) @(posedge clk_apb); #1 dma_rx_ack = 0;
          end
          wait_m(50);
        end
        check(sent == nw && recv == nw, $sformatf("duplex: %0d words sent, %0d received of %0d", sent, recv, nw));
      end
      errs = 0;
      begin
        int j; j = 0;
        // an underrun slot sends zeros (no word is taken); the other samples keep the written order
        for (int i = 0; i < dtx.cap_val.size(); i++) begin
          if (dtx.cap_val[i] != 0) begin
            if (j < nw && dtx.cap_val[i] !== (words[j] & 32'hFFFF)) begin errs++; if (errs <= 4) $display("   flow tx mismatch: capture %0d (nonzero #%0d) slot %0d got %h expected %h", i, j, dtx.cap_slot[i], dtx.cap_val[i], words[j] & 32'hFFFF); end
            j++;
          end
        end
        if (errs != 0) for (int i = 0; i < 40 && i < dtx.cap_val.size(); i++) $display("   cap %0d frame %0d slot %0d line %0d val %h", i, dtx.cap_frame[i], dtx.cap_slot[i], dtx.cap_line[i], dtx.cap_val[i]);
        sb(1, 1'b1, errs == 0 && j >= nw - 4 * LINES, $sformatf("duplex: transmitted stream correct (%0d nonzero samples of %0d)", j, nw));
      end
      rd32(R_ISTS, v);
      check(irq === (|v[7:0]), "interrupt pin follows the masked status in the flow");
      dma_en_tx = 0; dma_en_rx = 0;
      unit_dis(0); unit_dis(1); dtx.run = 0; drx.run = 0;
      wr32(U(0, R_CTRL), 32'h0); wr32(U(1, R_CTRL), 32'h0); wait_apb(12);
    end
    end_test();
  end
endtask


// ---------------------------------------------------------------- INV-005 configuration of a running unit
task automatic t_cfg_running();
  int t, fed, b2, b5, f0;
  logic [31:0] lvl;
  begin
    begin_test("TEST-023 configuration of a running unit", "REQ-FUNC-002 INV-005 SVA-007 ERR-008");
    if (TX_EN != 0 && MASTER_EN != 0) begin
      hw_reset();
      dev_cfg(0, 1, 2, 16, 16, 0, 1, 0, 1, 32'hFFFFFFFF);
      dtx.cap_en = 1; dtx.master = 0; dtx.run = 1; dtx.div = 2; dtx.chk_en = 1; dtx.chk_mask = 1;
      cfg_unit(0, 1, 2, 16, 16, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
      fed = 0;
      for (int i = 0; i < DEPTH * LINES / 2; i++) begin words[fed % 2048] = 32'h6000 + (fed % 250) + 1; wr32(U(0, R_DATA), words[fed % 2048]); fed++; end
      unit_en(0, (1 << C_ROLE));
      t = 0;
      while (dtx.frames_seen < 40 && t < 3000) begin
        rd32(U(0, R_STS), lvl);
        if (lvl[27:16] + 8 <= DEPTH * LINES) begin
          for (int i = 0; i < 8; i++) begin words[fed % 2048] = 32'h6000 + (fed % 250) + 1; wr32(U(0, R_DATA), words[fed % 2048]); fed++; end
        end
        if (dtx.frames_seen == 10 && t > 0) begin
          b2 = dtx.bad[2]; b5 = dtx.bad[5]; f0 = dtx.frames_seen;
          wr32(U(0, R_FRAME), 3 | (4 << 8) | (8 << 16) | (8 << 24));     // format, slots, widths
          wr32(U(0, R_SYNC), 32'h1 | (1 << 12));                          // bit clock polarity
          wr32(U(0, R_CLK), 5);                                           // divider
          wr32(U(0, R_FIFO), 7);
        end
        t++;
      end
      sb(8, 1'b1, dtx.bad[2] == b2 && dtx.bad[5] == b5 && dtx.frames_seen > f0 + 10,
         "a configuration change while running leaves the frame format and the bit clock unchanged");
      begin
        int ok; ok = 1;
        for (int i = 0; i < dtx.cap_val.size() && i < fed; i++) if (dtx.cap_val[i] !== (words[i % 2048] & 32'hFFFF)) ok = 0;
        sb(8, 1'b1, ok == 1, "the stream is unchanged by the register change (data and order)");
      end
      dtx.chk_en = 0;
      unit_dis(0);
      // the new configuration applies at the next start (snapshot at the rising edge of the enable)
      flush_unit(0);
      dtx.clear_results();
      dev_cfg(0, 3, 4, 8, 8, 1, 7, 0, 1, 32'hFFFFFFFF);
      dtx.div = 5; dtx.chk_en = 1; dtx.cap_limit = 8;
      for (int i = 0; i < 8; i++) begin words[i] = 32'h40 + i; wr32(U(0, R_DATA), words[i]); end
      unit_en(0, (1 << C_ROLE));
      t = 0;
      while (dtx.cap_val.size() < 8 && t < 800) begin wait_m(200); t++; end
      sb(8, 1'b1, dtx.cap_val.size() >= 8 && dtx.cap_val[0] === 32'h40 && dtx.cap_val[7] === 32'h47, "the new configuration applies at the next start");
      unit_dis(0); dtx.run = 0;
    end
    end_test();
  end
endtask

// =====================================================================================
task automatic run_all(input string sel, input int wf);
  bit all;
  begin
    all = (sel == "ALL");
    if (wf != 0) begin wf_run(wf); return; end     // waveform scenario of section 10.3 (R-033)
    if (all || sel == "T001") t_reset();
    if (all || sel == "T018") t_apb();
    if (all || sel == "T019") t_data_regs();
    if (all || sel == "T003") t_tx_formats();
    if (all || sel == "T004") begin t_rx_formats(); t_ratio8(); end
    if (all || sel == "T006") t_widths();
    if (all || sel == "T007") t_lines_masks();
    if (all || sel == "T008") t_mask_change();
    if (all || sel == "T009") t_underrun();
    if (all || sel == "T010") t_overrun();
    if (all || sel == "T011") t_watermark();
    if (all || sel == "T012") t_sync_hung();
    if (all || sel == "T013") t_dividers();
    if (all || sel == "T014") t_shared();
    if (all || sel == "T015") t_ondemand();
    if (all || sel == "T016") t_irq();
    if (all || sel == "T017") t_dma();
    if (all || sel == "T020") t_resets();
    if (all || sel == "T021") t_clockratio();
    if (all || sel == "T022") t_params();
    if (all || sel == "T023") t_cfg_running();
    if (all || sel == "RND")  t_random();
    if (all || sel == "FLOW") t_integrated();
  end
endtask
