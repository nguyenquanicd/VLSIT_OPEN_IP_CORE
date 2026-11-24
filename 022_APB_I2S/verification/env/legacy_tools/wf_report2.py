#!/usr/bin/env python3
"""Final waveform index (R-033) after the figures of the specification were redrawn from the simulation.
The simulated WaveJSON and SVG of waveforms_sim are the redrawn figures (same window, same rows); the table says what was wrong
before (round 1, waveform_compare_round1.md). Run after wf_figures.py --write and the SVG rendering."""
import json, os, shutil

V = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM = os.path.join(V, "waveforms_sim")
FIG = os.path.join(V, "..", "spec", "figures")
WAS = {
    "wf_001_apb_rw": "the register events were drawn in the PREADY cycle; the RTL gives them one cycle earlier (first access cycle)",
    "wf_002_apb_error": "PSLVERR was drawn for the completion cycle only; the RTL holds it until the next SETUP phase (generator DEV-001)",
    "wf_003_i2s_tx_master": "drawn with 4-bit slots (not configurable; the minimum is 8, REQ-FUNC-009) and a different window",
    "wf_004_i2s_rx_slave": "4-bit slots; the sample tick comes 2 master clocks after the pin edge (SYNC_DEPTH = 2), the old figure assumed 3",
    "wf_005_fmt_i2s_lj": "4-bit slots; the two frame sync rows are now two simulated runs aligned on the MSB",
    "wf_006_pcm_tdm_mask": "4-bit slots; the released line is shown as o_sdo_0 low with o_sdo_oe low (the IP has a separate enable, no z level)",
    "wf_007_mask_change": "4-bit slots; the mask change of the old figure now follows the RTL (effective at the next frame start)",
    "wf_008_unit_start": "the figure was simplified; the real latencies of the snapshot and of the arming are now shown",
    "wf_009_tx_underrun_auto": "4-bit slots and an invented level sequence; now the simulated sequence with the restart at a frame boundary",
    "wf_010_rx_overrun_err": "FIFO of two words was drawn; the build has 16 words",
    "wf_011_ondemand": "4-bit slots; helper w_apb_wr_frame (no RTL signal) removed",
    "wf_012_sync_hung": "4-bit slots; helpers w_tmo_run and w_sync_err replaced by the RTL events; timeout x 256 master clocks",
    "wf_013_dma_burst": "the request returned 1 cycle after the acknowledge fell; the RTL needs 2 (dmahs state IDLE in between); helper w_cond removed",
    "wf_014_dma_single": "the single fell in the cycle of the acknowledge rising; the RTL needs one more cycle",
    "wf_015_irq_four": "event drawn by a helper and invented spacing; now a real underrun and real APB write timing",
    "wf_016_stop_flush": "4-bit slots; busy is also high while the flush is pending (ASM-019)",
    "wf_017_reset": "the two clocks were drawn with one period; the testbench uses 13 ns (APB) and 10 ns (master); the mclk rows are sampled on the APB cells",
}
rows = []
for stem, was in WAS.items():
    wid = "WF-" + stem[3:6]
    for ext in ("json", "svg"):
        shutil.copy(os.path.join(FIG, stem + "." + ext), os.path.join(SIM, stem + "." + ext))
    a = json.load(open(os.path.join(FIG, stem + ".json"), encoding="utf-8"))
    b = json.load(open(os.path.join(SIM, stem + ".json"), encoding="utf-8"))
    same = a == b
    rows.append("| %s | figures/%s.svg | waveforms_sim/%s.svg | %s | The figure is the simulated window of `%s.vcd` (synthesis branch, `tools/wf_figures.py`), %d rows, identical WaveJSON. Round 1 (waveform_compare_round1.md): %s. |" % (
        wid, stem, stem, "MATCH" if same else "DIFFERENT", stem, len(a["signal"]), was))
out = ["# Waveform comparison (R-033), after the redraw of 2026-11-21", "",
       "Round 1 compared the original figures with the simulation: all 17 differed (`waveform_compare_round1.md`). The designer asked to correct the figures "
       "according to the RTL; the 17 figures of the specification were redrawn from the simulated windows (legal scale: 8-bit slots, divider 2, 16-word FIFO). "
       "The rows use the RTL signal names; the VCD files are the evidence, `run_wf.sh` and `tools/wf_figures.py` reproduce them.", "",
       "| Waveform ID | Specification figure | Simulated waveform | Result | Note |", "|---|---|---|---|---|"] + rows + [""]
open(os.path.join(SIM, "waveform_compare.md"), "w", encoding="utf-8").write("\n".join(out))
print(sum(1 for r in rows if "| MATCH |" in r), "of", len(rows), "MATCH")
