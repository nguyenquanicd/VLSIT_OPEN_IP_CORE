#!/usr/bin/env python3
"""Redraw the waveform figures of the specification from the simulation (R-033, R-017, R-058).
Reads waveforms_sim/<stem>.vcd (legal scale, synthesis branch) and writes ../../figures/<stem>.json (WaveJSON) and
prints an ASCII view for review. A cell is one clock cycle (APB or master clock) or one bit clock; signals are named as
in the RTL. The rows follow the plan of section 10.3.   usage: wf_figures.py [stem-substring] [--write]"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wf_tool as W

V = W.VER
G = W.G
STATE = {0: "OFF", 1: "ARM", 2: "RUN", 3: "ERR", 4: "STOP"}
DMA = {0: "IDLE", 1: "REQ", 2: "WAIT"}


def label(kind, v):
    if set(v) - set("01"): return "x"
    n = int(v, 2)
    return {"s": STATE.get(n, str(n)), "d": DMA.get(n, str(n)), "n": str(n), "h": "%X" % n}[kind]


def sample(sigs, path, t_cells, kind, span):
    sig = sigs[G + path]
    w = sig["w"]
    out = []; data = []; last = None
    for t in t_cells:
        v = W.val_at(sig, t)
        if w == 1:
            if kind == "u" and v != "1" and any(c == "1" for tt, c in sig["ch"] if t - span <= tt < t): v = "1"
            out.append(v if v in "01xz" else "x")
        else:
            if v == last: out.append(".")
            else: out.append("="); data.append(label(kind if kind in "sdnh" else "h", v))
            last = v
    return "".join(out), data


def edge(sig, val, nth, t_min=0):
    # n-th change to val from the opposite binary value (an initial x does not count)
    c = 0; prev = None
    for t, v in sig["ch"]:
        if t >= t_min and v == val and prev in ("0", "1") and prev != val:
            c += 1
            if c == nth: return t
        prev = v
    return None


FIG = {
    "wf_001_apb_rw": dict(clk="clk_apb", anchor=("psel", "1", 1), cell=1, ncell=8, rows=[
        ("i_clk_apb", "CLK", ""), ("i_apb_psel", "dut.i_apb_psel", "b"), ("i_apb_penable", "dut.i_apb_penable", "b"),
        ("i_apb_pwrite", "dut.i_apb_pwrite", "b"), ("i_apb_paddr", "dut.i_apb_paddr", "h"), ("i_apb_pwdata", "dut.i_apb_pwdata", "h"),
        ("i_apb_pstrb", "dut.i_apb_pstrb", "h"), ("o_apb_pready", "dut.o_apb_pready", "b"), ("o_apb_prdata", "dut.o_apb_prdata", "h"),
        ("o_apb_pslverr", "dut.o_apb_pslverr", "b"), ("o_reg_wr_en", "dut.u_csr_i2s.o_reg_wr_en", "b"), ("o_reg_rd_en", "dut.u_csr_i2s.o_reg_rd_en", "b")],
        head="WF-001 OP-016 APB write and read of a register (success)",
        foot="One wait state per access, back to back. A write of i2s_tx_fifo is followed by a read of i2s_irq_sts. The register events o_reg_wr_en and o_reg_rd_en are given in the first access cycle, one cycle before PREADY (simulated, synthesis branch)."),
    "wf_002_apb_error": dict(clk="clk_apb", anchor=("psel", "1", 1), cell=1, ncell=10, rows=[
        ("i_clk_apb", "CLK", ""), ("i_apb_psel", "dut.i_apb_psel", "b"), ("i_apb_penable", "dut.i_apb_penable", "b"),
        ("i_apb_pwrite", "dut.i_apb_pwrite", "b"), ("i_apb_paddr", "dut.i_apb_paddr", "h"), ("i_apb_pstrb", "dut.i_apb_pstrb", "h"),
        ("o_apb_pready", "dut.o_apb_pready", "b"), ("o_apb_pslverr", "dut.o_apb_pslverr", "b"), ("o_reg_wr_en", "dut.u_csr_i2s.o_reg_wr_en", "b")],
        head="WF-002 OP-016 APB error responses (PSLVERR)",
        foot="i_slverr_en = 1. A partial-strobe write and a misaligned read answer in the first access cycle with no wait state and no register change. PSLVERR stays high until the next SETUP phase."),
    "wf_003_i2s_tx_master": dict(clk="dut.o_bclk_tx", grid="bit", anchor=("dut.o_ws_tx", "0", 1), cell=1, ncell=21, rows=[
        ("o_bclk_tx", "CLK", ""), ("o_ws_tx", "dut.o_ws_tx", "b"), ("w_pop_slot", "dut.gen_tx.w_pop_slot", "u"),
        ("o_sdo_oe", "dut.o_sdo_oe", "b"), ("o_sdo_0", "dut.o_sdo_0", "b")],
        head="WF-003 OP-003 I2S transmit frame, master (success)",
        foot="Cell = one bit clock, divider 2, two 8-bit slots (legal minimum), words 0xC3 and 0x5A. The frame sync falls one bit before the MSB; data and frame sync change at the launch edge (bit clock falling); the word is popped (w_pop_slot) in the bit cell before its launch. Simulated, synthesis branch."),
    "wf_004_i2s_rx_slave": dict(clk="dut.i_bclk_rx", grid="bit", anchor=("dut.i_ws_rx", "0", 1), cell=2, ncell=26, rows=[
        ("i_bclk_rx", "CLK", ""), ("i_ws_rx", "dut.i_ws_rx", "b"), ("i_sdi_0", "dut.i_sdi_0", "b"),
        ("w_rx_push", "dut.gen_rx.u_rxdes.o_wr_en", "u")],
        head="WF-004 OP-004 I2S receive frame, slave (success)",
        foot="Cell = one bit clock, master clock 8 times the bit clock, two 8-bit slots, words 0xC3 and 0x5A. Inputs are synchronized in the master clock domain; the sample tick follows each rising bit clock edge by two master clocks (PARA_I2S_SYNC_DEPTH = 2); a word is pushed at the end of each slot."),
    "wf_005_fmt_i2s_lj": dict(clk="dut.o_bclk_tx", grid="bit", anchor=("dut.o_ws_tx", "0", 1), cell=2, ncell=14, rows=[
        ("o_bclk_tx", "CLK", ""), ("o_ws_tx [fmt=1 I2S]", "dut.o_ws_tx", "b"),
        ("o_ws_tx [fmt=2 LJ]", {"path": "dut.o_ws_tx", "after_reset": 2, "cell": 3}, "b"), ("o_sdo_0 [fmt=1 I2S]", "dut.o_sdo_0", "b"),
        ("o_sdo_0 [fmt=2 LJ]", {"path": "dut.o_sdo_0", "after_reset": 2, "cell": 3, "anchor_path": "dut.o_ws_tx"}, "b")],
        head="WF-005 OP-005 Frame sync of the Philips I2S and the left-justified preset (success)",
        foot="Cell = one bit clock. The data (0xC3, MSB first) is the same; the I2S frame sync changes one bit before the MSB, the left-justified frame sync changes with the MSB (the two frame sync rows come from two runs and are aligned on the MSB). The data rows show the MSB position of each run."),
    "wf_006_pcm_tdm_mask": dict(clk="dut.o_bclk_tx", grid="bit", anchor=("dut.o_ws_tx", "1", 1), cell=2, ncell=38, rows=[
        ("o_bclk_tx", "CLK", ""), ("o_ws_tx", "dut.o_ws_tx", "b"), ("o_sdo_oe", "dut.o_sdo_oe", "b"), ("o_sdo_0", "dut.o_sdo_0", "b")],
        head="WF-006 OP-005 PCM short frame with four slots, one masked slot (success)",
        foot="Cell = one bit clock, four 8-bit slots, slot mask 0xD (slot 1 masked), tri-state bit set, words 0xC3, 0x5A, 0x96 for slots 0, 2 and 3. Preset 3: frame sync of one bit, one bit before slot 0. In the masked slot the enable o_sdo_oe is low (the line is released) and o_sdo_0 stays 0."),
}


from wf_figures2 import FIG2
FIG.update(FIG2)


def build(stem, cfg, write):
    vcd = os.path.join(W.SIM, stem + ".vcd")
    sigs = W.parse_vcd(vcd)
    clk = sigs[G + cfg["clk"]]
    a_path, a_val, a_n = cfg["anchor"]
    t_a = edge(sigs[G + a_path], a_val, a_n)
    if t_a is None: print('  anchor event not found'); return
    edges = W.rising_edges(clk, 0, clk["ch"][-1][0] + 10 ** 9)
    per0 = edges[1] - edges[0]
    period = per0
    edges = [edges[0] - per0 * j for j in range(8, 0, -1)] + edges      # a few synthetic cells before the first edge
    k = max(i for i, e in enumerate(edges) if e <= t_a)
    bit = cfg.get("grid") == "bit"
    off = (period * 3) // 4 if bit else period // 2
    # uniform grid of one clock period per cell, anchored on the clock edge of the anchor event
    cells = [edges[k] + (i - cfg["cell"]) * period for i in range(cfg["ncell"])]
    t_cells = [e + off for e in cells]
    span = (period * 3) // 4
    sig = []
    for name, path, kind in cfg["rows"]:
        if path == "CLK": sig.append({"name": name, "wave": "p" + "." * (len(cells) - 1)}); continue
        if isinstance(path, dict):
            t_rst = W.first_edge(sigs[G + "rst_n_apb"], "0", path["after_reset"])
            t2 = edge(sigs[G + path.get("anchor_path", a_path)], a_val, 1, t_min=t_rst)
            k2 = max(i for i, e in enumerate(edges) if e <= t2)
            c2 = [edges[k2] + (i - path.get("cell", cfg["cell"])) * period for i in range(cfg["ncell"])]
            wave, data = sample(sigs, path["path"], [e + off for e in c2], kind, span)
        else:
            wave, data = sample(sigs, path, t_cells, kind, period)
        r = {"name": name, "wave": wave}
        if data: r["data"] = data
        sig.append(r)
    fig = {"signal": sig, "head": {"text": cfg["head"]}, "foot": {"text": cfg["foot"]}, "config": {"hscale": 1}}
    for r in sig: print("  %-22s %s %s" % (r["name"], r["wave"], r.get("data", "")))
    if write: json.dump(fig, open(os.path.join(V, "..", "figures", stem + ".json"), "w"), indent=1)


if __name__ == "__main__":
    pat = next((a for a in sys.argv[1:] if not a.startswith("--")), "")
    for stem, cfg in FIG.items():
        if pat in stem:
            print("==", stem); build(stem, cfg, "--write" in sys.argv)
