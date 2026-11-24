#!/usr/bin/env python3
"""Write waveforms_sim/waveform_compare.md from compare_data.json (R-033). The numbers come from wf_tool.py; the
cause and the decision of every DIFFERENT row are the analysis of this file (R-026): the designer decides."""
import json, os

V = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(V, "waveforms_sim")
cd = json.load(open(os.path.join(SIM, "compare_data.json")))

PLAN = {
    "wf_001_apb_rw": "WF-001", "wf_002_apb_error": "WF-002", "wf_003_i2s_tx_master": "WF-003", "wf_004_i2s_rx_slave": "WF-004",
    "wf_005_fmt_i2s_lj": "WF-005", "wf_006_pcm_tdm_mask": "WF-006", "wf_007_mask_change": "WF-007", "wf_008_unit_start": "WF-008",
    "wf_009_tx_underrun_auto": "WF-009", "wf_010_rx_overrun_err": "WF-010", "wf_011_ondemand": "WF-011", "wf_012_sync_hung": "WF-012",
    "wf_013_dma_burst": "WF-013", "wf_014_dma_single": "WF-014", "wf_015_irq_four": "WF-015", "wf_016_stop_flush": "WF-016",
    "wf_017_reset": "WF-017"}

SCALE = ("The figure is drawn at a reduced scale that the IP cannot be configured to (4-bit slots, divider 2 with a 4-cycle bit; "
         "the legal minimum is an 8-bit slot, REQ-FUNC-009), so the cells cannot line up with the 8-bit simulation")
NOTES = {
    "wf_001_apb_rw": "Cause: figure. All APB rows are equal cell by cell, including one wait state and the read data. Only `o_reg_wr_en` "
                     "and `o_reg_rd_en` differ: the simulation gives each pulse in the first access cycle (cells 2 and 5), one cycle "
                     "before PREADY; the figure draws it in the PREADY cycle (cells 3 and 6). The generated CSR block derives the enables "
                     "from the SETUP strobes through one flop and registers PREADY from them (generator specification, APB4 timing), so the "
                     "figure is one cycle late. Decision needed: correct the figure (recommended) or ask for a later event.",
    "wf_002_apb_error": "Cause: known deviation of the generated CSR. Every row is equal except `o_apb_pslverr`: the figure shows PSLVERR "
                        "only in the completion cycle, the RTL keeps it high until the next SETUP phase (cells 3 to 7). This is DEV-001 of "
                        "the generator specification and the recommendation-only item APB-19 of the testbench (12 cycles counted, not a "
                        "protocol failure). Decision needed: correct the figure (recommended) or require a CSR change.",
    "wf_003_i2s_tx_master": SCALE + ". The relations of the figure hold: the bit clock row is equal; the frame sync falls at cell 4, the "
                            "first word pop is at cell 7 and the first data bit at cell 8, as drawn. Differences: the frame sync stays low for 8 bit "
                            "clocks instead of 4, and `o_sdo_oe` rises at cell 4 because the window starts at the unit start (the figure starts "
                            "with the output already enabled). The data bits are the scoreboard words, not L3..R0. Decision needed: redraw at the "
                            "legal scale or keep the figure as an illustration.",
    "wf_004_i2s_rx_slave": SCALE + ". Equal relations: the frame sync falls at cell 8, the first data bit starts at cell 16, a sample tick "
                           "every 8 master clocks. Differences: the 8-bit slot doubles the slot length, the first sample tick is at cell 14 "
                           "(figure: 7) because the default build has `PARA_I2S_SYNC_DEPTH` = 2 while the figure assumes a 3-cycle input path, and "
                           "the word push is at the end of the 8-bit slot (cell 79). Decision needed: figure or SYNC_DEPTH statement.",
    "wf_005_fmt_i2s_lj": SCALE + ". The two formats are two runs of one dump (the left-justified window starts after the second reset). The "
                         "position of the frame sync against the first data bit is also checked in every transmit run by SER-02 (REQ-FUNC-004 to "
                         "REQ-FUNC-008), which passes. Decision needed: redraw at the legal scale.",
    "wf_006_pcm_tdm_mask": SCALE + ". Slot 0 is driven and slot 1 is released as in the figure (`o_sdo_oe` low for the whole masked slot). The "
                           "figure draws the released line as `z` on `o_sdo_0`; the IP has a separate enable `o_sdo_oe` and keeps `o_sdo_0` at 0, so "
                           "the level row cannot show `z`. Decision needed: redraw at the legal scale and show the line as 0 with the enable low.",
    "wf_007_mask_change": SCALE + ". The bit clock row is equal. The change of the effective mask and of the receive pushes at the next frame "
                          "boundary is not reachable in the window of the same length; the behaviour is covered by TEST-008 (every frame carries one "
                          "programmed slot set, INV-005). Decision needed: redraw at the legal scale.",
    "wf_008_unit_start": 'Cause: scenario timing and simplified figure. The same order is simulated (enable, snapshot, busy, frame state ARM to RUN, bit clock and frame sync start) but the cells differ: snapshot pulse at cells 7 and 8 (figure: 8), frame state changes at cells 14 and 18 (figure: 8 and 12), `o_bclk_tx_oe` rises at cell 15 and the bit clock at cell 16 (figure: 8 and 10). The crossing of the enable to the master clock and the arming of the engine take longer than the figure draws. Decision needed: state the latency in the figure (REQ-FUNC-001 with TBD-001) or keep the figure as an illustration.',
    "wf_009_tx_underrun_auto": SCALE + ". In both, the frame sync pattern repeats, the level goes to 0, the cause `tx_und` is set one bit after "
                               "the underrun pulse and stays set, the state returns to ARM and the unit restarts at a frame boundary after the "
                               "two words are written. The simulated frame has 8-bit slots and the level steps differ because the scenario writes "
                               "two words at a time. Decision needed: redraw at the legal scale.",
    "wf_010_rx_overrun_err": 'The figure is drawn at a reduced scale that the IP cannot be configured to (4-bit slots, divider 2 with a 4-cycle bit; the legal minimum is an 8-bit slot, REQ-FUNC-009), so the cells cannot line up with the 8-bit simulation, and the FIFO of the figure holds two words while the build holds 16 (`PARA_I2S_FIFO_DEPTH`). The sequence is checked by TEST-010 (PASS): the cause `rx_ovr` is set when the FIFO is full, the oldest words are kept, and with automatic restart off the unit receives again only after the flush. Decision needed: redraw with the real capacity or state that the capacity is illustrative.',
    "wf_011_ondemand": 'The figure is drawn at a reduced scale that the IP cannot be configured to (4-bit slots, divider 2 with a 4-cycle bit; the legal minimum is an 8-bit slot, REQ-FUNC-009), so the cells cannot line up with the 8-bit simulation. The sequence is checked by TEST-015 (PASS): an empty FIFO stalls the master with no frame sync and no underrun, and two written words start the next frame. `w_apb_wr_frame` is a figure-only helper and has no RTL signal. Decision needed: redraw at the legal scale.',
    "wf_012_sync_hung": 'The figure is drawn at a reduced scale that the IP cannot be configured to (4-bit slots, divider 2 with a 4-cycle bit; the legal minimum is an 8-bit slot, REQ-FUNC-009), so the cells cannot line up with the 8-bit simulation. The sequence of the figure (a frame sync inside a frame, then a stopped bit clock) is checked by TEST-012 (PASS): the sync cause and the unit flag, no hung cause before the timeout and the hung cause after it. `w_tmo_run` has no RTL signal, and at the build timeout (timeout x 256 master clocks) the hung cause falls outside a 24-cell window of this length. Decision needed: redraw with the timeout of the build.',
    "wf_013_dma_burst": "Cause: figure. Request, acknowledge and single follow the figure. The request returns 2 cycles after the acknowledge "
                        "falls (cell 11) while the figure draws it 1 cycle after (cell 10); the single leads the request by one cycle at the "
                        "second rise as drawn. `w_cond` is a figure-only helper. Decision needed: correct the figure or the dmahs timing; "
                        "INV-006 (request low while the acknowledge is high) holds in both.",
    "wf_014_dma_single": "Cause: figure and scenario. The request stays low and the single is high while words remain, as drawn. The single falls "
                         "one cycle after the acknowledge rises (the figure: in the same cycle), consistent with DMA-01 and DMA-03 which pass; "
                         "the second and third acknowledgements come later because the scenario reads the word over APB before acknowledging. "
                         "Decision needed: correct the figure.",
    "wf_015_irq_four": 'Cause: scenario timing. The same order is simulated with real APB writes of 3 cycles each (a real underrun sets the raw bit while masked, the enable raises the output, a clear, an injection, a clear while the injection is held), so the cells do not line up with the figure. `w_apb_clr` is a figure-only helper. TEST-016 and SB-04, SB-05 pass for every cause. Decision needed: keep the figure as an illustration.',
    "wf_016_stop_flush": 'The figure is drawn at a reduced scale that the IP cannot be configured to (4-bit slots, divider 2 with a 4-cycle bit; the legal minimum is an 8-bit slot, REQ-FUNC-009), so the cells cannot line up with the 8-bit simulation. The running frame finishes after the enable is cleared (STOP) and busy stays high to its end, which is 64 master clocks away at the legal scale and outside the 20-cell window, so the flush row is not reached. The behaviour is checked by TEST-020 (PASS). Decision needed: redraw at the legal scale.',
    "wf_017_reset": "Cause: figure. The reset rows of the APB domain are equal cell by cell (asynchronous assertion, release 2 edges after the "
                    "release of the input). The row `w_rst_mclk_sync` differs because the figure draws the two clocks with the same cell while the "
                    "testbench uses 10 ns and 13 ns periods; the release is also two master clock edges after the input release. Decision needed: "
                    "state the clock ratio of the figure.",
}

rows = []
for stem, wid in PLAN.items():
    d = cd[stem]
    r = d["rows"]
    comp = {n: x for n, x in r.items() if x != "CLOCK"}
    eq = sum(1 for x in comp.values() if x == "MATCH")
    diff = [n for n, x in comp.items() if x == "DIFFERENT"]
    miss = [n for n, x in comp.items() if x == "MISSING"]
    note = "%d of %d compared rows equal; " % (eq, len(comp))
    if diff: note += "different: " + ", ".join("`%s`" % n for n in diff) + "; "
    if miss: note += "no RTL signal: " + ", ".join("`%s`" % n for n in miss) + "; "
    note += NOTES[stem]
    result = "MATCH" if (not diff and not miss) else "DIFFERENT"
    rows.append("| %s | figures/%s.svg | waveforms_sim/%s.svg | %s | %s |" % (wid, stem, stem, result, note))

out = ["# Waveform comparison (R-033)", "",
       "Simulated waveforms come from the synthesis-branch build with VCD tracing (`run_wf.sh`, one scenario per run, `+WF=<n>`); "
       "`tools/wf_tool.py` samples each row on the cell grid of the figure, aligned on the event named in its table, and compares it cell by "
       "cell (multi-bit rows by the positions of their value changes). The scenarios use the legal minimum scale of the IP. No row of the "
       "figures was changed by the testbench. Every DIFFERENT row has an analysis (R-026); the decisions are the designer's.", "",
       "| Waveform ID | Specification figure | Simulated waveform | Result | Note |", "|---|---|---|---|---|"] + rows + [""]
open(os.path.join(SIM, "waveform_compare.md"), "w", encoding="utf-8").write("\n".join(out))
print("waveform_compare.md:", len(rows), "rows;", sum(1 for r in rows if "| MATCH |" in r), "MATCH")
