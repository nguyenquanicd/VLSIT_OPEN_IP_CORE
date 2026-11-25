`timescale 1ns/1ps
// Unit test of the register crossing m_usb2_xreg (t_fml_cdc_xreg companion, REQ-CLK-003, REQ-REG-002, ERR-016).
// AI-generated candidate (R-117). Checks from the specification only:
//  - every CSR write crosses as one whole 32-bit word (no torn value), in write order, once;
//  - a write while the command FIFO is full (o_xq_free = 0) is dropped and flagged by o_xq_ovf, and never appears;
//  - o_xq_free is between 0 and 8;
//  - an event set pushed by CLK-PHY arrives on the update port as a kind-1 entry and is not lost.
// Clock periods of both domains come from +pb and +pp (picoseconds) and random phase; the stimulus is seeded by +seed.
module tb_xreg;
  parameter int NS = 8, NA = 4;
  int pb = 10000, pp = 16667, seed = 1, n_cycles = 20000;
  logic clk_bus = 0, clk_phy = 0, rst_n = 0;
  initial begin
    void'($value$plusargs("pb=%d", pb)); void'($value$plusargs("pp=%d", pp)); void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("cycles=%d", n_cycles));
    #(($urandom(seed) % 7000) * 1ps);
    fork forever #(pb / 2 * 1ps) clk_bus = ~clk_bus; forever #(pp / 2 * 1ps) clk_phy = ~clk_phy; join_none
  end
  logic wr_en = 0; logic [7:0] wr_slot = 0; logic [31:0] wr_word = 0; logic [5:0] xq_free; logic xq_ovf;
  logic ld_en; logic [3:0] ld_kind; logic [7:0] ld_slot; logic [31:0] ld_val;
  logic [NS*32-1:0] shadow; logic [NS*32-1:0] shadow_init = '0;
  logic [NA*32-1:0] pub = '0, setv = '0, clrv = '0;
  m_usb2_xreg #(.PARA_USB2_XREG_NS(NS), .PARA_USB2_XREG_NA(NA)) dut (
    .i_clk_bus(clk_bus), .i_rst_n_bus(rst_n), .i_clk_phy(clk_phy), .i_rst_n_phy(rst_n), .i_wr_en(wr_en), .i_wr_slot(wr_slot),
    .i_wr_word(wr_word), .o_xq_free(xq_free), .o_xq_ovf(xq_ovf), .o_ld_en(ld_en), .o_ld_kind(ld_kind), .o_ld_slot(ld_slot),
    .o_ld_val(ld_val), .i_shadow_init(shadow_init), .o_shadow(shadow), .i_pub(pub), .i_set(setv), .i_clr(clrv));

  int errors = 0, checks = 0, accepted = 0, dropped = 0, ovf_seen = 0, sets_sent = 0, sets_seen = 0;
  logic [31:0] sent_word [int];          // sequence number -> word
  int          sent_slot [int];
  bit stop = 0;
  int seq = 0, n_free0 = 0, n_free0_acc = 0;
  int last_seq_seen [NS];
  logic [31:0] cur [NS];
  // Checkpoint IDs of the header (tests/usb20/tc_t_fml_cdc_xreg.txt, R-286, 2026-11-25): each check counts under its ID; the log
  // lists every ID with its first time and count (CHKPT and CHKPT_END lines, as the operation harnesses do).
  int cp_cnt [string]; longint cp_t0 [string];
  task automatic chk(input string id, input bit c, input string m);
    checks++; if (!cp_cnt.exists(id)) begin cp_cnt[id] = 0; cp_t0[id] = $time; end cp_cnt[id]++;
    if (!c) begin errors++; $display("FAIL @%0t: %s: %s", $time, id, m); end
  endtask

  // bus-side stimulus: bursts of writes, some at free = 0
  always @(posedge clk_bus) begin
    wr_en <= 1'b0;
    if (rst_n && !stop && ($urandom_range(0, 99) < 55)) begin
      wr_en <= 1'b1; wr_slot <= 8'($urandom_range(0, NS - 1));
      wr_word <= {8'(seq[7:0]), 24'($urandom)};
    end
    // account the write presented in this cycle (values before the edge are the ones the DUT samples)
    if (rst_n && wr_en) begin
      if (xq_ovf) begin dropped++; end
      else begin
        accepted++; sent_word[seq] = wr_word; sent_slot[seq] = wr_slot;
        seq++;
      end
      chk("XRG-FREE", xq_free <= 6'd8, $sformatf("xq_free = %0d above 8", xq_free));
      // a former check "ovf with free entries" here had a constant-false term (&& 0) and checked nothing; removed 2026-11-25,
      // the condition is checked by XRG-OVF below
    end
    if (rst_n && wr_en && xq_free == 0) begin n_free0++; if (!xq_ovf) n_free0_acc++; end
    if (rst_n && wr_en && xq_ovf) chk("XRG-OVF", xq_free == 0, $sformatf("write dropped (xq_ovf) while xq_free = %0d", xq_free));
  end
  // CLK-PHY: every value that appears in a shadow slot is a whole accepted word, in order
  always @(posedge clk_phy) begin
    if (rst_n) begin
      for (int s = 0; s < NS; s++) begin
        logic [31:0] w; w = shadow[s*32 +: 32];
        if (w !== cur[s]) begin
          bit found; found = 0;
          for (int q = last_seq_seen[s] + 1; q < seq && !found; q++)
            if (sent_slot.exists(q) && sent_slot[q] == s && sent_word[q] === w) begin found = 1; last_seq_seen[s] = q; end
          chk("XRG-WORD", found, $sformatf("slot %0d took value %08x that is not a later accepted write (torn, stale or dropped word)", s, w));
          cur[s] = w;
        end
      end
    end
  end
  // event sets from CLK-PHY: pulse one bit per slot at random, expect a kind-1 update for it
  int set_pending [NA];
  always @(posedge clk_phy) begin
    setv <= '0;
    if (rst_n && ($urandom_range(0, 99) < 3)) begin
      int a; a = $urandom_range(0, NA - 1);
      if (set_pending[a] == 0) begin setv[a*32 + 3] <= 1'b1; set_pending[a] = 1; sets_sent++; end
    end
  end
  always @(posedge clk_bus) if (ld_en && ld_kind == 4'd1) begin
    chk("XRG-SLOT", ld_slot < NA, "update for a slot that does not exist");
    if (ld_slot < NA && ld_val[3]) begin set_pending[ld_slot] = 0; sets_seen++; end
  end

  initial begin
    for (int s = 0; s < NS; s++) begin cur[s] = '0; last_seq_seen[s] = -1; end
    for (int a = 0; a < NA; a++) set_pending[a] = 0;
    repeat (6) @(posedge clk_bus); rst_n = 1;
    repeat (n_cycles) @(posedge clk_bus);
    stop = 1;
    repeat (200) @(posedge clk_bus);
    // every accepted write must have arrived (the last write of each slot is in the shadow)
    for (int s = 0; s < NS; s++) begin
      int lastq; lastq = -1;
      for (int q = 0; q < seq; q++) if (sent_slot[q] == s) lastq = q;
      if (lastq >= 0) chk("XRG-FINAL", shadow[s*32 +: 32] === sent_word[lastq], $sformatf("slot %0d final value %08x expected %08x", s, shadow[s*32 +: 32], sent_word[lastq]));
    end
    chk("XRG-DRAIN", xq_free == 6'd8, $sformatf("xq_free = %0d after the FIFO drained, expected 8", xq_free));
    chk("XRG-ACTIVITY", accepted > 50, "too few accepted writes: the test did not exercise the crossing");
    chk("XRG-ACTIVITY", dropped > 0 || pb >= pp, "no write was dropped at xq_free = 0 although the bus side is faster");
    chk("XRG-EVENT", sets_seen >= sets_sent - NA, $sformatf("event sets lost: %0d sent, %0d seen", sets_sent, sets_seen));
    // REQ-REG-002: a write while xq_free = 0 shall be dropped and set xq_ovf
    chk("XRG-DROP", n_free0_acc == 0, $sformatf("%0d of %0d write(s) at xq_free = 0 were accepted instead of dropped", n_free0_acc, n_free0));
    $display("XREG accepted=%0d dropped=%0d sets_sent=%0d sets_seen=%0d", accepted, dropped, sets_sent, sets_seen);
    foreach (cp_cnt[id]) begin $display("CHKPT @%0d: %s", cp_t0[id], id); $display("CHKPT_END %s checks=%0d", id, cp_cnt[id]); end
    $display("CHECKPOINTS reached=%0d", cp_cnt.num());
    $display("RESULT %s checks=%0d errors=%0d", (errors == 0 && checks > 0) ? "PASS" : "FAIL", checks, errors);
    $finish;
  end
endmodule
