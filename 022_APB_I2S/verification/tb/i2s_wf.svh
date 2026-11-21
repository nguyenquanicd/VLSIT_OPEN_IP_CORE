// Waveform scenarios of the testbench (included in tb_i2s). One scenario per waveform of section 10.3 of the
// specification; each run (+WF=<n> +VCD=<file>) holds one scenario so that the dump contains only that scenario (R-033).
// The scenarios use the legal minimum scale of the IP (8-bit slots, divider 2), not the reduced scale of the figures.
string vcd_name = "";
bit    wf_on = 0;

task automatic wf_begin();
  begin
    if (wf_on == 0) begin
      if ($value$plusargs("VCD=%s", vcd_name)) begin
        $dumpfile(vcd_name);
        $dumpvars(0, tb_i2s);
      end
      wf_on = 1;
    end
  end
endtask
task automatic wf_end();
  begin
    wait_m(8); wait_apb(4);
    $dumpoff;
    wf_on = 0;
  end
endtask

task automatic wf_run(input int n);
  logic [31:0] v;
  int t, e0;
  begin
    begin_test($sformatf("WF-%03d waveform scenario", n), "R-033 section 10.3");
    hw_reset();
    case (n)
      // ---- APB write and read of a register (WF-001)
      1: begin
        wf_begin();
        wait_apb(3);
        apb_hold = 1;                              // back-to-back, as the figure shows
        wr32(U(0, R_FIFO), 32'h5);                // a write that starts no activity
        apb_hold = 0;
        rd32(R_ISTS, v);
        wait_apb(3);
        wf_end();
      end
      // ---- APB errors (WF-002): partial strobe write and misaligned read
      2: begin
        wf_begin();
        wait_apb(3);
        apb_xfer(1, U(0, R_MASK), 32'h12345678, 4'h3, 3'b000, rv_, ev_);
        check(ev_, "partial strobe write gives PSLVERR");
        apb_xfer(0, 16'h0003, 32'h0, 4'h0, 3'b000, rv_, ev_);
        check(ev_, "misaligned read gives PSLVERR");
        wait_apb(3);
        wf_end();
      end
      // ---- I2S transmit, master (WF-003)
      3: begin
        wf_begin();
        tx_scn("wf003", 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 1, 2, 0, 1, 0, 1, 2, 0, 4);
        wf_end();
      end
      // ---- I2S receive, slave at ratio 8 (WF-004)
      4: begin
        wf_begin();
        rx_scn("wf004", 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 0, 2, 0, 1, 0, 1, 2, 4);
        wf_end();
      end
      // ---- I2S and left-justified frame sync (WF-005): two runs in one dump
      5: begin
        wf_begin();
        tx_scn("wf005 I2S", 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 1, 2, 0, 1, 0, 1, 2, 0, 4);
        tx_scn("wf005 LJ",  2, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 1, 2, 0, 1, 0, 1, 2, 0, 4);
        wf_end();
      end
      // ---- PCM short, four slots, slot 1 masked with tri-state (WF-006)
      6: begin
        wf_begin();
        tx_scn("wf006", 3, 4, 8, 8, 0, 0, 32'hD, 1, 2, 0, 1, 0, 1, 2, 1, 4);
        wf_end();
      end
      // ---- mask change at a frame boundary (WF-007): receive slave, four slots
      7: begin
        wf_begin();
        dev_cfg(1, 5, 4, 8, 8, 0, 1, 0, 1, 32'hF);
        drx.src_en = 1; drx.cap_en = 0; drx.master = 1; drx.hp_ps = 4 * TM_PS; drx.div = 2;
        cfg_unit(1, 5, 4, 8, 8, 0, 0, 32'hF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 200; i++) drx.src_q.push_back(32'h10 + i);
        unit_en(1, (1 << C_AUTO));
        wait_apb(20); drx.run = 1;
        wait_m(300);
        wr32(U(1, R_MASK), 32'hD);                // slot 1 off from the next frame
        wait_m(700);
        unit_dis(1); drx.run = 0;
        wf_end();
      end
      // ---- unit start (WF-008)
      8: begin
        dev_cfg(0, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.div = 2; dtx.hp_ps = 4 * TM_PS; dtx.chk_en = 0;
        cfg_unit(0, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 4; i++) wr32(U(0, R_DATA), 32'hA0 + i);
        wf_begin();
        wait_apb(3);
        dtx.run = 1;
        unit_en(0, (1 << C_ROLE));
        wait_m(400);
        unit_dis(0); dtx.run = 0;
        wf_end();
      end
      // ---- transmit underrun with automatic restart (WF-009)
      9: begin
        dev_cfg(0, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.div = 2; dtx.hp_ps = 4 * TM_PS; dtx.chk_en = 0; dtx.chk_mask = 1;
        cfg_unit(0, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        wr32(U(0, R_DATA), 32'hA1); wr32(U(0, R_DATA), 32'hA2);
        wf_begin();
        dtx.run = 1;
        unit_en(0, (1 << C_ROLE) | (1 << C_AUTO));
        wait_m(700);
        wr32(U(0, R_DATA), 32'hB1); wr32(U(0, R_DATA), 32'hB2);
        wait_m(700);
        unit_dis(0); dtx.run = 0;
        wf_end();
      end
      // ---- receive overrun with automatic restart off (WF-010)
      10: begin
        dev_cfg(1, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        drx.src_en = 1; drx.master = 1; drx.hp_ps = 4 * TM_PS; drx.div = 2;
        cfg_unit(1, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < (DEPTH * LINES + 8); i++) drx.src_q.push_back(32'h40 + i);
        wf_begin();
        unit_en(1, 0);
        wait_apb(20); drx.run = 1;
        t = 0; v = 0;
        while (!v[I_RXOVR] && t < 400) begin wait_m(100); rd32(R_IRAW, v); t++; end
        wait_m(200);
        drx.run = 0;
        flush_unit(1);
        wait_m(100);
        unit_dis(1);
        wf_end();
      end
      // ---- on-demand frame start (WF-011)
      11: begin
        dev_cfg(0, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.div = 2; dtx.hp_ps = 4 * TM_PS; dtx.chk_en = 0;
        cfg_unit(0, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        wf_begin();
        dtx.run = 1;
        unit_en(0, (1 << C_ROLE) | (1 << C_ONDEM));
        wait_m(300);
        wr32(U(0, R_DATA), 32'hC1); wr32(U(0, R_DATA), 32'hC2);
        wait_m(500);
        wr32(U(0, R_DATA), 32'hC3); wr32(U(0, R_DATA), 32'hC4);
        wait_m(500);
        unit_dis(0); dtx.run = 0;
        wf_end();
      end
      // ---- frame sync error and hung clock, slave (WF-012)
      12: begin
        dev_cfg(1, 5, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        drx.src_en = 1; drx.master = 1; drx.hp_ps = 4 * TM_PS; drx.div = 2;
        cfg_unit(1, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 400; i++) drx.src_q.push_back(32'h20 + i);
        wr32(U(1, R_TMO), 1);
        wf_begin();
        unit_en(1, (1 << C_AUTO)); wait_apb(20); drx.run = 1;
        wait_m(300);
        drx.glitch_t = 20;
        wait_m(300);
        drx.glitch_t = -1;
        wait_m(100);
        drx.clk_stop = 1;
        wait_m(600);
        drx.clk_stop = 0;
        wait_m(100);
        unit_dis(1); drx.run = 0;
        wf_end();
      end
      // ---- DMA burst handshake, transmit (WF-013): request, acknowledge, request again while the condition holds
      13: begin
        dev_cfg(0, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        cfg_unit(0, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        wf_begin();
        dma_en_tx = 1;
        wr32(U(0, R_CTRL), (1 << C_DMA));
        t = 0;
        while (!dma_tx_req && t < 100) begin @(posedge clk_apb); t++; end
        repeat (3) @(posedge clk_apb);
        #1 dma_tx_ack = 1;
        repeat (4) @(posedge clk_apb);
        #1 dma_tx_ack = 0;
        repeat (4) @(posedge clk_apb);
        #1 dma_tx_ack = 1;
        repeat (3) @(posedge clk_apb);
        #1 dma_tx_ack = 0;
        repeat (4) @(posedge clk_apb);
        dma_en_tx = 0; wr32(U(0, R_CTRL), 32'h0);
        wait_apb(4);
        wf_end();
      end
      // ---- DMA single transactions, receive (WF-014): three words, below the burst length of four
      14: begin
        dev_cfg(1, 5, 3, 8, 8, 0, 1, 0, 1, 32'h7);
        drx.src_en = 1; drx.master = 1; drx.hp_ps = 4 * TM_PS; drx.div = 2;
        cfg_unit(1, 5, 3, 8, 8, 0, 0, 32'h7, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 3; i++) drx.src_q.push_back(32'h60 + i);
        wf_begin();
        unit_en(1, 0);
        wait_apb(20); drx.run = 1;
        t = 0;
        while (dut.w_rx_level < 3 && t < 4000) begin @(posedge clk_mclk); t++; end
        drx.clk_stop = 1;                          // no further word: the level stays at three
        wait_apb(6);
        dma_en_rx = 1;
        wr32(U(1, R_CTRL), (1 << C_DMA) | 32'h1);
        for (int k = 0; k < 3; k++) begin
          t = 0;
          while (!dma_rx_single && t < 400) begin @(posedge clk_apb); t++; end
          repeat (2) @(posedge clk_apb);
          rd32(U(1, R_DATA), v);
          #1 dma_rx_ack = 1; repeat (3) @(posedge clk_apb); #1 dma_rx_ack = 0;
          repeat (3) @(posedge clk_apb);
        end
        dma_en_rx = 0; wr32(U(1, R_CTRL), 32'h0); drx.run = 0; drx.clk_stop = 0;
        wait_apb(4);
        wf_end();
      end
      // ---- interrupt raw, enable, injection, masked status (WF-015): a real transmit underrun is the event
      15: begin
        dev_cfg(0, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.div = 2; dtx.hp_ps = 4 * TM_PS; dtx.chk_en = 0; dtx.run = 1;
        cfg_unit(0, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        wf_begin();
        wait_apb(2);
        unit_en(0, (1 << C_ROLE));                 // empty FIFO: the first slot is an underrun (the event)
        t = 0;
        while (!dut.u_csr_i2s.o_i2s_irq_raw_tx_und && t < 2000) begin @(posedge clk_apb); t++; end
        repeat (2) @(posedge clk_apb);
        wr32(R_IEN, 32'h1 << I_TXUND);            // enabling raises the output
        repeat (1) @(posedge clk_apb);
        wr32(R_IRAW, 32'h1 << I_TXUND);           // clear (the unit is in the error state, no new event)
        repeat (2) @(posedge clk_apb);
        wr32(R_IINJ, 32'h1 << I_TXUND);           // injection sets it again
        repeat (2) @(posedge clk_apb);
        wr32(R_IRAW, 32'h1 << I_TXUND);           // the clear does not hold while the injection is high
        wr32(R_IINJ, 32'h0);
        repeat (2) @(posedge clk_apb);
        wr32(R_IRAW, 32'h1 << I_TXUND);
        wait_apb(4);
        wr32(R_IEN, 32'h0);
        unit_dis(0); dtx.run = 0;
        wf_end();
      end
      // ---- unit stop, busy and flush (WF-016)
      16: begin
        dev_cfg(0, 1, 2, 8, 8, 0, 1, 0, 1, 32'hFFFFFFFF);
        dtx.cap_en = 1; dtx.master = 0; dtx.div = 2; dtx.hp_ps = 4 * TM_PS; dtx.chk_en = 0; dtx.run = 1;
        cfg_unit(0, 1, 2, 8, 8, 0, 0, 32'hFFFFFFFF, 2, 0, 1, 0, 1, 4);
        for (int i = 0; i < 8; i++) wr32(U(0, R_DATA), 32'hD0 + i);
        unit_en(0, (1 << C_ROLE));
        wait_m(150);
        wf_begin();
        wr32(U(0, R_CTRL), 32'h0);                // stop: the running frame finishes
        wait_m(300);
        wr32(U(0, R_CTRL), 32'h4);                // flush
        wait_m(40);
        wf_end();
        dtx.run = 0;
      end
      // ---- reset assertion and release (WF-017): asserted at the start, released, a short second assertion
      17: begin
        wf_begin();
        wait_m(2); wait_apb(2);
        rst_n_apb = 0; rst_n_mclk = 0;
        wait_apb(2);
        @(posedge clk_apb); #1 rst_n_apb = 1; @(posedge clk_mclk); #1 rst_n_mclk = 1;
        wait_apb(6);
        #1 rst_n_apb = 0; rst_n_mclk = 0;
        @(posedge clk_apb); #1 rst_n_apb = 1; @(posedge clk_mclk); #1 rst_n_mclk = 1;
        wait_apb(8); wait_m(12);
        wf_end();
      end
      default: check(1'b0, "unknown waveform scenario");
    endcase
    end_test();
  end
endtask
