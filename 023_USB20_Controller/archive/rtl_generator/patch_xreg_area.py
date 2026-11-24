import re
p = '../rtl/m_usb2_xreg.sv'
s = open(p).read()

# port widths of the engine side: only the scanned slots
for n in ('i_pub', 'i_set', 'i_clr'):
    s = re.sub(r"(input\s+wire\s+)\[PARA_USB2_XREG_NS\*LPARA_WORD_W-1:0\](\s+" + n + r")", r"\1[PARA_USB2_XREG_NA*LPARA_WORD_W-1:0]\2", s)

# declarations
for n in ('reg_pub_sent', 'reg_set_pend', 'reg_clr_pend'):
    s = re.sub(r"logic \[PARA_USB2_XREG_NS\*LPARA_WORD_W-1:0\](\s+)" + n + r";",
               r"logic [PARA_USB2_XREG_NA*LPARA_WORD_W-1:0]\1" + n + ";", s)
s = re.sub(r"  logic \[PARA_USB2_XREG_NS\*LPARA_WORD_W-1:0\]\s+w_set_nxt;\n", "", s)
s = re.sub(r"  logic \[PARA_USB2_XREG_NS\*LPARA_WORD_W-1:0\]\s+w_clr_nxt;\n", "", s)
s = re.sub(r"  logic \[PARA_USB2_XREG_NA-1:0\]\s+w_pdirty_nxt;\n", "", s)
s = s.replace("  logic                                        w_pub_dirty;\n",
              "  logic                                        w_pub_dirty;\n"
              "  logic [PARA_USB2_XREG_NA-1:0]                w_sel;\n"
              "  logic [PARA_USB2_XREG_NA-1:0]                w_dirty;\n"
              "  logic [PARA_USB2_XREG_NA-1:0]                w_setany;\n"
              "  logic [PARA_USB2_XREG_NA-1:0]                w_clrany;\n"
              "  logic                                        w_sel_dirty;\n"
              "  logic                                        w_sel_set;\n"
              "  logic                                        w_sel_clr;\n")

a = s.index("  // Scanner: the selected slot words")
b = s.index("endmodule")
new = """  // One-hot selection of the scan slot.
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

  // Flags of the scan slot: a published word that differs from the pushed one, pending sets and clears.
  assign w_sel_dirty = |(w_sel & w_dirty);
  assign w_sel_set   = |(w_sel & w_setany);
  assign w_sel_clr   = |(w_sel & w_clrany);

  // Hit: events wait while any published word is dirty, so a published word always reaches the CSR
  // before an event that was raised together with it (DEC-002).
  assign w_pub_dirty = (reg_pdirty != '0);
  assign w_hit       = ((w_sel_set | w_sel_clr) & ~w_pub_dirty) | w_sel_dirty;

  // Value and kind of the entry pushed for the scan slot, by priority: published word, event set
  // mask, command clear mask.
  always_comb begin : p_com_scan_val
    w_scan_val  = w_scan_pub;
    w_scan_kind = LPARA_KIND_PUB[LPARA_KIND_W-1:0];
    casez ({w_sel_dirty, w_sel_set, w_sel_clr})
      3'b1??: begin
        w_scan_val  = w_scan_pub;
        w_scan_kind = LPARA_KIND_PUB[LPARA_KIND_W-1:0];
      end
      3'b01?: begin
        w_scan_val  = w_scan_set;
        w_scan_kind = LPARA_KIND_SET[LPARA_KIND_W-1:0];
      end
      3'b001: begin
        w_scan_val  = w_scan_clr;
        w_scan_kind = LPARA_KIND_CLR[LPARA_KIND_W-1:0];
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

"""
s = s[:a] + new + s[b:]
open(p, 'w').write(s)

# generator: engine-side vectors only for the scanned slots
g = open('gen_regs.py').read()
g = g.replace("for ln in ['w_cfg_all', 'w_shadow', 'w_shadow_init', 'w_pub_all', 'w_set_all', 'w_clr_all']:\n    D.append(f'  logic [LPARA_NS*32-1:0] {ln};')",
              "for ln in ['w_cfg_all', 'w_shadow', 'w_shadow_init']:\n    D.append(f'  logic [LPARA_NS*32-1:0] {ln};')\nfor ln in ['w_pub_all', 'w_set_all', 'w_clr_all']:\n    D.append(f'  logic [LPARA_NA*32-1:0] {ln};')")
open('gen_regs.py', 'w').write(g)
print('ok')
