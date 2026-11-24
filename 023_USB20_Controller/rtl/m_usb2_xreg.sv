/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : Register crossing between CLK-BUS and CLK-PHY (CDC-001, CDC-002, REQ-CLK-003,
 *                REQ-REG-002, DEC-001, DEC-002). The command FIFO carries every CSR write {slot
 *                8, kind 4, word 32, tag 4} from CLK-BUS to the shadow registers of CLK-PHY. The
 *                update FIFO carries three kinds from CLK-PHY to CLK-BUS: 1 = event set mask, 2
 *                = command clear mask, 3 = published register word. A scanner in CLK-PHY visits
 *                one slot per cycle and pushes the pending kinds, so an event is never lost
 *                while the FIFO is full; events of one bit that arrive twice before the push
 *                merge. xq_free is the number of free command entries, seen through a Gray pop
 *                counter. PARA_USB2_PIPE_XREG adds an output register stage on the shadow words.
 */
`timescale 1ns/1ps

module m_usb2_xreg #(
  // Parameter Description: number of register slots (one slot is one register entry).
  // Parameter values: 1 to 255; default is 64.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_XREG_NS = 64,
  // Parameter Description: number of slots that the scanner visits (slots 0 to NA-1 have published
  // words, event sets or command clears; the other slots only hold shadow words).
  // Parameter values: 1 to the value of PARA_USB2_XREG_NS; default is 64.
  // Parameter unit: count
  parameter logic [31:0] PARA_USB2_XREG_NA = 64,
  // Parameter Description: 1 adds a register stage on the shadow outputs (timing option).
  // Parameter values: 0 or 1; default is 0.
  // Parameter unit: none
  parameter logic [31:0] PARA_USB2_PIPE_XREG = 0,
  localparam logic [31:0] LPARA_SLOT_W    = 8,
  localparam logic [31:0] LPARA_KIND_W    = 4,
  localparam logic [31:0] LPARA_WORD_W    = 32,
  localparam logic [31:0] LPARA_TAG_W     = 4,
  localparam logic [31:0] LPARA_ENTRY_W   = 48,
  localparam logic [31:0] LPARA_FIFO_DEPTH = 8,
  localparam logic [31:0] LPARA_PTR_W     = 4,
  // Cycles for which event sets and command clears wait after a new one was raised, so that a
  // published word that the same hardware step changes one or two cycles later is dirty first
  // (review 2026-11-22 F-001, BUG-044).
  localparam logic [31:0] LPARA_EVT_HOLD  = 7,
  localparam logic [31:0] LPARA_CELL_2FF  = 2,
  localparam logic [31:0] LPARA_MEM_RTL   = 0,
  localparam logic [31:0] LPARA_KIND_SET  = 1,
  localparam logic [31:0] LPARA_KIND_CLR  = 2,
  localparam logic [31:0] LPARA_KIND_PUB  = 3,
  localparam logic [31:0] LPARA_ONE       = 1,
  localparam logic [31:0] LPARA_FREE_W    = 6
) (
  // CLK-BUS clock and reset
  input  wire                                       i_clk_bus,
  input  wire                                       i_rst_n_bus,

  // CLK-PHY clock and reset (hard reset domain: the shadow keeps its values over a soft reset)
  input  wire                                       i_clk_phy,
  input  wire                                       i_rst_n_phy,

  // Command push from the CSR integration (CLK-BUS)
  input  wire                                       i_wr_en,
  input  wire  [LPARA_SLOT_W-1:0]                   i_wr_slot,
  input  wire  [LPARA_WORD_W-1:0]                   i_wr_word,
  output logic [LPARA_FREE_W-1:0]                   o_xq_free,
  output logic                                      o_xq_ovf,

  // Update pop to the CSR integration (CLK-BUS)
  output logic                                      o_ld_en,
  output logic [LPARA_KIND_W-1:0]                   o_ld_kind,
  output logic [LPARA_SLOT_W-1:0]                   o_ld_slot,
  output logic [LPARA_WORD_W-1:0]                   o_ld_val,

  // Shadow registers and reset values (CLK-PHY)
  input  wire  [PARA_USB2_XREG_NS*LPARA_WORD_W-1:0] i_shadow_init,
  output logic [PARA_USB2_XREG_NS*LPARA_WORD_W-1:0] o_shadow,

  // Published words, event sets and command clears of the engines (CLK-PHY)
  input  wire  [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0] i_pub,
  input  wire  [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0] i_set,
  input  wire  [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0] i_clr
);

  // Internal signal declarations
  logic [LPARA_ENTRY_W-1:0]                    w_cmd_wr_data;
  logic [LPARA_ENTRY_W-1:0]                    w_cmd_rd_data;
  logic                                        w_cmd_full;
  logic                                        w_cmd_wr_ok;
  logic [LPARA_FREE_W-1:0]                     w_free_cnt;
  logic                                        w_cmd_empty;
  logic                                        w_cmd_rd_en;
  logic [LPARA_ENTRY_W-1:0]                    w_upd_wr_data;
  logic [LPARA_ENTRY_W-1:0]                    w_upd_rd_data;
  logic                                        w_upd_full;
  logic                                        w_upd_empty;
  logic                                        w_upd_wr_en;
  logic                                        w_upd_rd_en;
  logic [LPARA_PTR_W-1:0]                      reg_push_cnt;
  logic [LPARA_PTR_W-1:0]                      reg_pop_cnt_phy;
  logic [LPARA_PTR_W-1:0]                      w_pop_gray_phy;
  logic [LPARA_PTR_W-1:0]                      w_pop_gray_bus;
  logic [LPARA_PTR_W-1:0]                      w_pop_bin_bus;
  logic [LPARA_PTR_W-1:0]                      w_used;
  logic [LPARA_TAG_W-1:0]                      reg_seq;
  logic [LPARA_TAG_W-1:0]                      reg_upd_seq;
  logic [LPARA_SLOT_W-1:0]                     w_cmd_slot;
  logic [LPARA_WORD_W-1:0]                     w_cmd_word;
  logic [PARA_USB2_XREG_NS*LPARA_WORD_W-1:0]   reg_shadow;
  logic [PARA_USB2_XREG_NS*LPARA_WORD_W-1:0]   reg_shadow_out;
  logic [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0]   reg_pub_sent;
  logic [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0]   reg_set_pend;
  logic [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0]   reg_clr_pend;
  logic [LPARA_SLOT_W-1:0]                     reg_scan;
  logic [LPARA_SLOT_W-1:0]                     w_scan_nxt;
  logic [LPARA_WORD_W-1:0]                     w_scan_pub;
  logic [LPARA_WORD_W-1:0]                     w_scan_set;
  logic [LPARA_WORD_W-1:0]                     w_scan_clr;
  logic [LPARA_WORD_W-1:0]                     w_scan_val;
  logic [LPARA_KIND_W-1:0]                     w_scan_kind;
  logic [LPARA_PTR_W-1:0]                      w_pop_bin_nxt;
  logic [LPARA_PTR_W-1:0]                      reg_pop_gray_phy;
  logic                                        w_hit;
  logic                                        reg_evt_in;
  logic [2:0]                                  reg_evt_hold;
  logic                                        w_evt_hold;
  logic                                        reg_wr_v;
  logic [LPARA_ENTRY_W-1:0]                    reg_wr_data;
  logic                                        w_fifo_wr_en;
  logic [LPARA_ENTRY_W-1:0]                    w_fifo_wr_data;
  logic [PARA_USB2_XREG_NA-1:0]                reg_pdirty;
  logic                                        w_pub_dirty;
  logic [PARA_USB2_XREG_NA-1:0]                w_sel;
  logic [PARA_USB2_XREG_NA-1:0]                w_dirty;
  logic [PARA_USB2_XREG_NA-1:0]                w_setany;
  logic [PARA_USB2_XREG_NA-1:0]                w_clrany;
  logic                                        w_sel_dirty;
  logic                                        w_sel_set;
  logic                                        w_sel_set_ok;
  logic                                        w_clr_pend;
  logic                                        w_sel_clr;

  // Command FIFO from CLK-BUS to CLK-PHY: 8 entries of 48 bits. A push while full is dropped and
  // reported on o_xq_ovf; software reads u2_sts.xq_free before a burst of writes.
  assign w_cmd_wr_data = {i_wr_slot, 4'd0, i_wr_word, reg_seq};
  assign w_cmd_slot    = w_cmd_rd_data[47:40];
  assign w_cmd_word    = w_cmd_rd_data[35:4];
  assign w_cmd_rd_en   = ~w_cmd_empty;

  m_vlsit_afifo_top #(
    .PARA_AFIFO_DEPTH         (LPARA_FIFO_DEPTH),
    .PARA_AFIFO_DATA_W        (LPARA_ENTRY_W),
    .PARA_AFIFO_CELL_TYPE     (LPARA_CELL_2FF),
    .PARA_AFIFO_MEM_USE_MACRO (LPARA_MEM_RTL)
  ) u_cmd_fifo (
    .i_clk_wr      (i_clk_bus),
    .i_rst_n_wr    (i_rst_n_bus),
    .i_wr_en       (w_cmd_wr_ok),
    .i_wr_data     (w_cmd_wr_data),
    .i_full_thr    ('0),
    .o_full        (w_cmd_full),
    .o_full_thr    (),
    .o_overflow    (),
    .i_rst_n_sw    (i_rst_n_bus),
    .o_sw_rst_busy (),
    .i_clk_rd      (i_clk_phy),
    .i_rst_n_rd    (i_rst_n_phy),
    .i_rd_en       (w_cmd_rd_en),
    .i_empty_thr   ('0),
    .o_rd_data     (w_cmd_rd_data),
    .o_empty       (w_cmd_empty),
    .o_empty_thr   (),
    .o_underflow   ()
  );

  // Update FIFO from CLK-PHY to CLK-BUS: written by the scanner, drained every cycle.
  assign w_upd_wr_data = {reg_scan, w_scan_kind, w_scan_val, reg_upd_seq};
  // With PARA_USB2_PIPE_XREG the entry is registered for one cycle before the FIFO write (the
  // status words that
  // feed the scanner are long combinational cones); a new entry is decided only when the stage
  // is empty.
  assign w_upd_wr_en   = w_hit & ~w_upd_full & ~((PARA_USB2_PIPE_XREG != 32'd0) & reg_wr_v);
  assign w_fifo_wr_en  = (PARA_USB2_PIPE_XREG != 32'd0) ? reg_wr_v : w_upd_wr_en;
  assign w_fifo_wr_data = (PARA_USB2_PIPE_XREG != 32'd0) ? reg_wr_data : w_upd_wr_data;

  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_updstage
    if (!i_rst_n_phy) begin
      reg_wr_v    <= 1'b0;
      reg_wr_data <= '0;
    end else begin
      reg_wr_v    <= w_upd_wr_en;
      reg_wr_data <= w_upd_wr_data;
    end
  end

  assign w_upd_rd_en   = ~w_upd_empty;
  assign o_ld_en       = ~w_upd_empty;
  assign o_ld_slot     = w_upd_rd_data[47:40];
  assign o_ld_kind     = w_upd_rd_data[39:36];
  assign o_ld_val      = w_upd_rd_data[35:4];

  m_vlsit_afifo_top #(
    .PARA_AFIFO_DEPTH         (LPARA_FIFO_DEPTH),
    .PARA_AFIFO_DATA_W        (LPARA_ENTRY_W),
    .PARA_AFIFO_CELL_TYPE     (LPARA_CELL_2FF),
    .PARA_AFIFO_MEM_USE_MACRO (LPARA_MEM_RTL)
  ) u_upd_fifo (
    .i_clk_wr      (i_clk_phy),
    .i_rst_n_wr    (i_rst_n_phy),
    .i_wr_en       (w_fifo_wr_en),
    .i_wr_data     (w_fifo_wr_data),
    .i_full_thr    ('0),
    .o_full        (w_upd_full),
    .o_full_thr    (),
    .o_overflow    (),
    .i_rst_n_sw    (i_rst_n_phy),
    .o_sw_rst_busy (),
    .i_clk_rd      (i_clk_bus),
    .i_rst_n_rd    (i_rst_n_bus),
    .i_rd_en       (w_upd_rd_en),
    .i_empty_thr   ('0),
    .o_rd_data     (w_upd_rd_data),
    .o_empty       (w_upd_empty),
    .o_empty_thr   (),
    .o_underflow   ()
  );

  // Pop counter in CLK-PHY, sent to CLK-BUS as a Gray code (library synchronizer). The free
  // count is pessimistic: it can be late to rise, never early. The Gray word is a register of
  // CLK-PHY (from the next binary value), so the synchronizer never samples the output of the
  // encoder gates (review 2026-11-22 F-020, BUG-045).
  assign w_pop_bin_nxt  = reg_pop_cnt_phy + (w_cmd_rd_en ? LPARA_ONE[LPARA_PTR_W-1:0] : '0);
  assign w_pop_gray_phy = reg_pop_gray_phy;

  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_pop_gray
    if (!i_rst_n_phy)
      reg_pop_gray_phy <= '0;
    else
      reg_pop_gray_phy <= w_pop_bin_nxt ^ (w_pop_bin_nxt >> 1);
  end

  m_vlsit_afifo_sync #(
    .PARA_AFIFO_SYNC_W       (LPARA_PTR_W),
    .PARA_AFIFO_SYNC_RST_VAL (32'd0),
    .PARA_AFIFO_CELL_TYPE    (LPARA_CELL_2FF)
  ) u_sync_pop (
    .i_clk_dst   (i_clk_bus),
    .i_rst_n_dst (i_rst_n_bus),
    .i_data      (w_pop_gray_phy),
    .o_data      (w_pop_gray_bus)
  );

  // Gray to binary conversion of the synchronized pop counter.
  always_comb begin : p_com_gray
    w_pop_bin_bus[3] = w_pop_gray_bus[3];
    w_pop_bin_bus[2] = w_pop_gray_bus[3] ^ w_pop_gray_bus[2];
    w_pop_bin_bus[1] = w_pop_gray_bus[3] ^ w_pop_gray_bus[2] ^ w_pop_gray_bus[1];
    w_pop_bin_bus[0] = w_pop_gray_bus[3] ^ w_pop_gray_bus[2] ^ w_pop_gray_bus[1] ^ w_pop_gray_bus[0];
  end

  // Used entries and the free count (8 minus used); the event is the accepted push.
  assign w_used    = reg_push_cnt - w_pop_bin_bus;
  // Free count: zero when all entries are used.
  assign w_free_cnt = (w_used >= LPARA_FIFO_DEPTH[LPARA_PTR_W-1:0]) ? 6'd0 :
                      (LPARA_FIFO_DEPTH[LPARA_FREE_W-1:0] - {2'b00, w_used});
  // The reported free count is also 0 while the FIFO flag is full, and a write is accepted only
  // when both views have room, so that a write is dropped exactly when o_xq_free is 0
  // (REQ-REG-002, BUG-022: the two views could differ by one entry in either direction).
  assign o_xq_free  = w_cmd_full ? 6'd0 : w_free_cnt;
  assign w_cmd_wr_ok = i_wr_en & ~w_cmd_full & (w_free_cnt != 6'd0);
  // Overflow event: a push while no entry is free is dropped.
  assign o_xq_ovf   = i_wr_en & ~w_cmd_wr_ok;

  // Push counter and tag sequence of CLK-BUS; they move only on an accepted push.
  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_push
    if (!i_rst_n_bus) begin
      reg_push_cnt <= '0;
      reg_seq      <= '0;
    end else if (w_cmd_wr_ok) begin
      reg_push_cnt <= reg_push_cnt + LPARA_ONE[LPARA_PTR_W-1:0];
      reg_seq      <= reg_seq + LPARA_ONE[LPARA_TAG_W-1:0];
    end
  end

  // Pop counter of CLK-PHY: one count for every command entry taken.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_pop
    if (!i_rst_n_phy)
      reg_pop_cnt_phy <= '0;
    else if (w_cmd_rd_en)
      reg_pop_cnt_phy <= reg_pop_cnt_phy + LPARA_ONE[LPARA_PTR_W-1:0];
  end

  // Shadow registers of CLK-PHY: one command writes one slot. The generation tag of the entry is
  // not used to drop a word: a stale clear is a per-bit mask and cannot change a value that
  // software has not seen (DEC-002); the tag stays in the entry for debug.
  // The command bits that the engine consumes (the clear mask i_clr) also leave the shadow word,
  // so that software can write the same command again and the engine sees a new edge (DEC-014); a
  // command written in the same cycle wins over the clear.
  generate
    for (genvar gen_h = 0; gen_h < PARA_USB2_XREG_NS; gen_h++) begin : gen_shadow
      logic [LPARA_WORD_W-1:0] w_clr_h;

      if (gen_h < PARA_USB2_XREG_NA) begin : gen_clr
        assign w_clr_h = i_clr[gen_h*LPARA_WORD_W +: LPARA_WORD_W];
      end else begin : gen_noclr
        assign w_clr_h = '0;
      end

      always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_shadow
        if (!i_rst_n_phy)
          reg_shadow[gen_h*LPARA_WORD_W +: LPARA_WORD_W] <= i_shadow_init[gen_h*LPARA_WORD_W +: LPARA_WORD_W];
        else if (w_cmd_rd_en & (w_cmd_slot == gen_h[LPARA_SLOT_W-1:0]))
          reg_shadow[gen_h*LPARA_WORD_W +: LPARA_WORD_W] <= w_cmd_word;
        else
          reg_shadow[gen_h*LPARA_WORD_W +: LPARA_WORD_W] <=
            reg_shadow[gen_h*LPARA_WORD_W +: LPARA_WORD_W] & ~w_clr_h;
      end
    end
  endgenerate

  // Optional output stage of the shadow words (timing option PARA_USB2_PIPE_XREG).
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_shadow_out
    if (!i_rst_n_phy)
      reg_shadow_out <= i_shadow_init;
    else
      reg_shadow_out <= reg_shadow;
  end

  // Select the shadow words with or without the output stage.
  assign o_shadow = (PARA_USB2_PIPE_XREG != 32'd0) ? reg_shadow_out : reg_shadow;

  // One-hot selection of the scan slot.
  always_comb begin : p_com_sel
    w_sel = '0;
    for (int idx = 0; idx < PARA_USB2_XREG_NA; idx++) begin
      w_sel[idx] = (reg_scan == idx[LPARA_SLOT_W-1:0]);
    end
  end

  // Words of the scan slot by AND-OR selection of the per-slot words (no barrel shifter).
  always_comb begin : p_com_scan_words
    w_scan_pub = '0;
    w_scan_set = '0;
    w_scan_clr = '0;
    for (int idx = 0; idx < PARA_USB2_XREG_NA; idx++) begin
      w_scan_pub = w_scan_pub | (i_pub[idx*LPARA_WORD_W +: LPARA_WORD_W] & {LPARA_WORD_W{w_sel[idx]}});
      w_scan_set = w_scan_set | (reg_set_pend[idx*LPARA_WORD_W +: LPARA_WORD_W] & {LPARA_WORD_W{w_sel[idx]}});
      w_scan_clr = w_scan_clr | (reg_clr_pend[idx*LPARA_WORD_W +: LPARA_WORD_W] & {LPARA_WORD_W{w_sel[idx]}});
    end
  end

  // Flags of the scan slot: a published word that differs from the pushed one (the registered flag
  // reg_pdirty, one cycle old, so that the comparison of the 32-bit words is not in the path of the
  // push decision, DEC-025), pending sets and clears.
  assign w_sel_dirty = |(w_sel & reg_pdirty);
  assign w_sel_set   = |(w_sel & w_setany);
  assign w_sel_clr   = |(w_sel & w_clrany);

  // Hit: events wait while any published word is dirty, so a published word always reaches the CSR
  // before an event that was raised together with it (DEC-002).
  assign w_pub_dirty = (reg_pdirty != '0);
  // Events and clears also wait LPARA_EVT_HOLD cycles after the last new one: the engines change a
  // published word (remaining length, active flag) one or two cycles after the event pulse, and
  // reg_pdirty is one more cycle late. Without the wait, done reached the CSR before the final
  // xsize, and the clear of ep_en before active (BUG-044, found by t_dev_xreg_race).
  assign w_evt_hold  = reg_evt_in | (reg_evt_hold != 3'd0);
  // Clears go before events: an event set waits while a command clear of any slot is pending, so
  // software sees a done flag only after the command bit it wrote has returned to 0. Otherwise a
  // re-arm right after done hit a command bit still at 1 (no arming edge for the DMA) and the late
  // clear then removed the new command (BUG-049, found by t_rand_host_traffic seed 7).
  assign w_clr_pend   = (w_clrany != '0);
  assign w_sel_set_ok = w_sel_set & ~w_clr_pend;
  assign w_hit       = ((w_sel_set_ok | w_sel_clr) & ~w_pub_dirty & ~w_evt_hold) | w_sel_dirty;

  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_evthold
    if (!i_rst_n_phy) begin
      reg_evt_in   <= 1'b0;
      reg_evt_hold <= 3'd0;
    end else begin
      reg_evt_in <= (i_set != '0) | (i_clr != '0);
      if (reg_evt_in)
        reg_evt_hold <= LPARA_EVT_HOLD[2:0];
      else if (reg_evt_hold != 3'd0)
        reg_evt_hold <= reg_evt_hold - 3'd1;
    end
  end

  // Value and kind of the entry pushed for the scan slot, by priority: published word, command
  // clear mask, event set mask (BUG-049).
  always_comb begin : p_com_scan_val
    w_scan_val  = w_scan_pub;
    w_scan_kind = LPARA_KIND_PUB[LPARA_KIND_W-1:0];
    casez ({w_sel_dirty, w_sel_clr, w_sel_set_ok})
      3'b1??: begin
        w_scan_val  = w_scan_pub;
        w_scan_kind = LPARA_KIND_PUB[LPARA_KIND_W-1:0];
      end
      3'b01?: begin
        w_scan_val  = w_scan_clr;
        w_scan_kind = LPARA_KIND_CLR[LPARA_KIND_W-1:0];
      end
      3'b001: begin
        w_scan_val  = w_scan_set;
        w_scan_kind = LPARA_KIND_SET[LPARA_KIND_W-1:0];
      end
      default: begin
        w_scan_val = w_scan_pub;
      end
    endcase
  end

  // The scanner stays on a slot while something is pending there, and then moves on by one.
  always_comb begin : p_com_scan_nxt
    w_scan_nxt = reg_scan;
    if (!w_hit) begin
      if (reg_scan == (PARA_USB2_XREG_NA[LPARA_SLOT_W-1:0] - LPARA_ONE[LPARA_SLOT_W-1:0]))
        w_scan_nxt = '0;
      else
        w_scan_nxt = reg_scan + LPARA_ONE[LPARA_SLOT_W-1:0];
    end
  end

  // Per-slot state: last pushed word, pending set and clear masks, and the dirty flag. Events
  // accumulate; the pushed kind clears the pending word of its slot except for events of the
  // same cycle.
  generate
    for (genvar gen_s = 0; gen_s < PARA_USB2_XREG_NA; gen_s++) begin : gen_slot
      logic w_push_pub;
      logic w_push_set;
      logic w_push_clr;

      assign w_dirty[gen_s]  = (i_pub[gen_s*LPARA_WORD_W +: LPARA_WORD_W] !=
                                reg_pub_sent[gen_s*LPARA_WORD_W +: LPARA_WORD_W]);
      assign w_setany[gen_s] = (reg_set_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W] != '0);
      assign w_clrany[gen_s] = (reg_clr_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W] != '0);
      assign w_push_pub = w_upd_wr_en & w_sel[gen_s] & (w_scan_kind == LPARA_KIND_PUB[LPARA_KIND_W-1:0]);
      assign w_push_set = w_upd_wr_en & w_sel[gen_s] & (w_scan_kind == LPARA_KIND_SET[LPARA_KIND_W-1:0]);
      assign w_push_clr = w_upd_wr_en & w_sel[gen_s] & (w_scan_kind == LPARA_KIND_CLR[LPARA_KIND_W-1:0]);

      always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_slot
        if (!i_rst_n_phy) begin
          reg_pub_sent[gen_s*LPARA_WORD_W +: LPARA_WORD_W] <= '0;
          reg_set_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W] <= '0;
          reg_clr_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W] <= '0;
          reg_pdirty[gen_s]                               <= 1'b0;
        end else begin
          reg_pdirty[gen_s] <= w_dirty[gen_s] & ~w_push_pub;
          reg_set_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W] <=
            (w_push_set ? '0 : reg_set_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W]) |
            i_set[gen_s*LPARA_WORD_W +: LPARA_WORD_W];
          reg_clr_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W] <=
            (w_push_clr ? '0 : reg_clr_pend[gen_s*LPARA_WORD_W +: LPARA_WORD_W]) |
            i_clr[gen_s*LPARA_WORD_W +: LPARA_WORD_W];
          if (w_push_pub)
            reg_pub_sent[gen_s*LPARA_WORD_W +: LPARA_WORD_W] <= i_pub[gen_s*LPARA_WORD_W +: LPARA_WORD_W];
        end
      end
    end
  endgenerate

  // Scanner pointer and the update tag.
  always_ff @(posedge i_clk_phy, negedge i_rst_n_phy) begin : p_ff_scan
    if (!i_rst_n_phy) begin
      reg_scan    <= '0;
      reg_upd_seq <= '0;
    end else begin
      reg_scan <= w_scan_nxt;
      if (w_upd_wr_en)
        reg_upd_seq <= reg_upd_seq + LPARA_ONE[LPARA_TAG_W-1:0];
    end
  end

endmodule
