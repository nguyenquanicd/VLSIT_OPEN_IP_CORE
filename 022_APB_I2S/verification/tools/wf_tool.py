#!/usr/bin/env python3
"""Waveform evidence of the APB I2S testbench (R-033): VCD -> WaveJSON/SVG of the simulated window and a
cell-by-cell comparison with the figure of the specification.

  wf_tool.py build   : write waveforms_sim/<stem>.json for every waveform of the plan
  wf_tool.py compare : write waveforms_sim/compare_data.json (per-row result of the comparison)

Standard library only. The VCD files are written by the testbench (+WF=<n> +VCD=<file>), one scenario per file.
A cell of the figure is one clock cycle (or one bit clock); a row is compared cell by cell after the window of the
simulation was aligned on the event named in WINDOW. Multi-bit rows are compared by their change positions only,
because the figures name the values symbolically.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
VER = os.path.dirname(HERE)
SPEC_FIG = os.path.join(VER, "..", "figures")
SIM = os.path.join(VER, "waveforms_sim")
D = "tb_i2s.dut."
G = "tb_i2s."

# stem -> (cell clock path, edge, anchor path, anchor value, anchor occurrence, anchor cell in the figure, rows)
# rows: figure row name -> VCD path (relative to tb_i2s.), or None when the signal does not exist in the RTL
APB = {"clk": G + "clk_apb"}
WINDOW = {
    "wf_001_apb_rw": dict(clk=G + "clk_apb", anchor=(G + "psel", "1", 1), cell=1, rows={
        "i_clk_apb": "CLK", "i_apb_psel": "dut.i_apb_psel", "i_apb_penable": "dut.i_apb_penable",
        "i_apb_pwrite": "dut.i_apb_pwrite", "i_apb_paddr": "dut.i_apb_paddr", "i_apb_pwdata": "dut.i_apb_pwdata",
        "i_apb_pstrb": "dut.i_apb_pstrb", "o_apb_pready": "dut.o_apb_pready", "o_apb_prdata": "dut.o_apb_prdata",
        "o_apb_pslverr": "dut.o_apb_pslverr", "o_reg_wr_en": "dut.u_csr_i2s.o_reg_wr_en",
        "o_reg_rd_en": "dut.u_csr_i2s.o_reg_rd_en"}),
    "wf_002_apb_error": dict(clk=G + "clk_apb", anchor=(G + "psel", "1", 1), cell=1, rows={
        "i_clk_apb": "CLK", "i_apb_psel": "dut.i_apb_psel", "i_apb_penable": "dut.i_apb_penable",
        "i_apb_pwrite": "dut.i_apb_pwrite", "i_apb_paddr": "dut.i_apb_paddr", "i_apb_pstrb": "dut.i_apb_pstrb",
        "o_apb_pready": "dut.o_apb_pready", "o_apb_pslverr": "dut.o_apb_pslverr",
        "o_reg_wr_en": "dut.u_csr_i2s.o_reg_wr_en"}),
    "wf_003_i2s_tx_master": dict(clk=G + "clk_mclk", anchor=(G + "dut.o_ws_tx", "0", 1), cell=4, ncell=44, rows={
        "i_clk_mclk": "CLK", "o_bclk_tx": "dut.o_bclk_tx", "o_ws_tx": "dut.o_ws_tx",
        "w_pop_word": "dut.gen_tx.w_pop_slot", "o_sdo_oe": "dut.o_sdo_oe", "o_sdo_0": "dut.o_sdo_0"}),
    "wf_004_i2s_rx_slave": dict(clk=G + "clk_mclk", anchor=(G + "dut.i_ws_rx", "0", 1), cell=8, ncell=88, rows={
        "i_clk_mclk": "CLK", "i_bclk_rx": "dut.i_bclk_rx", "i_ws_rx": "dut.i_ws_rx", "i_sdi_0": "dut.i_sdi_0",
        "w_sample": "dut.gen_rx.u_frame_1.o_tick_s", "w_rx_push": "dut.gen_rx.u_rxdes.o_wr_en"}),
    "wf_005_fmt_i2s_lj": dict(clk=G + "dut.o_bclk_tx", anchor=(G + "dut.o_ws_tx", "0", 1), cell=1, ncell=12, rows={
        "o_bclk_tx": "dut.o_bclk_tx", "o_ws_tx [fmt=1 I2S]": "dut.o_ws_tx", "o_ws_tx [fmt=2 LJ]": {"path": "dut.o_ws_tx", "after_reset": 2},
        "o_sdo_0": "dut.o_sdo_0"}),
    "wf_006_pcm_tdm_mask": dict(clk=G + "dut.o_bclk_tx", anchor=(G + "dut.o_ws_tx", "1", 1), cell=1, ncell=18, rows={
        "o_bclk_tx": "dut.o_bclk_tx", "o_ws_tx": "dut.o_ws_tx", "o_sdo_oe": "dut.o_sdo_oe", "o_sdo_0": "dut.o_sdo_0"}),
    "wf_007_mask_change": dict(clk=G + "dut.i_bclk_rx", anchor=(G + "dut.i_ws_rx", "1", 1), cell=1, ncell=34, rows={
        "i_bclk_rx": "dut.i_bclk_rx", "i_ws_rx": "dut.i_ws_rx", "i_sdi_0": "dut.i_sdi_0",
        "w_mask_apb": "dut.u_csr_i2s.o_i2s_rx_mask_mask", "w_mask_act": "dut.gen_rx.u_frame_1.w_mask_eff",
        "w_rx_push": "dut.gen_rx.u_rxdes.o_wr_en"}),
    "wf_008_unit_start": dict(clk=G + "clk_mclk", anchor=(G + "dut.o_bclk_tx_oe", "1", 1), cell=20, ncell=40, rows={
        "i_clk_mclk": "CLK", "w_en": "dut.gen_tx.w_en_s", "w_cfg_snap": "dut.gen_tx.u_cfgsync_tx.w_en_rise",
        "w_fsm_frame_state": "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state",
        "i2s_sts.tx_busy": "dut.u_csr_i2s.i_i2s_tx_sts_busy", "o_bclk_tx_oe": "dut.o_bclk_tx_oe",
        "o_bclk_tx": "dut.o_bclk_tx", "o_ws_tx": "dut.o_ws_tx"}),
    "wf_009_tx_underrun_auto": dict(clk=G + "dut.o_bclk_tx", anchor=(G + "dut.gen_tx.w_und", "1", 1), cell=9, ncell=26, rows={
        "o_bclk_tx": "dut.o_bclk_tx", "o_ws_tx": "dut.o_ws_tx",
        "w_fsm_frame_state": "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state",
        "w_tx_level": "dut.w_tx_level", "w_und": "dut.gen_tx.w_und",
        "i2s_irq_raw.tx_und": "dut.u_csr_i2s.o_i2s_irq_raw_tx_und", "o_sdo_0": "dut.o_sdo_0"}),
    "wf_010_rx_overrun_err": dict(clk=G + "dut.i_bclk_rx", anchor=(G + "dut.gen_rx.w_ovr", "1", 1), cell=10, ncell=34, rows={
        "i_bclk_rx": "dut.i_bclk_rx", "w_rx_push_try": "dut.gen_rx.u_rxdes.w_push_ev", "w_rx_level": "dut.w_rx_level",
        "w_rx_ovr": "dut.gen_rx.w_ovr", "w_fsm_frame_state": "dut.gen_rx.u_frame_1.reg_fsm_frame_current_state",
        "i2s_irq_raw.rx_ovr": "dut.u_csr_i2s.o_i2s_irq_raw_rx_ovr", "w_flush": "dut.gen_rx.w_flush_ev"}),
    "wf_011_ondemand": dict(clk=G + "dut.o_bclk_tx", anchor=(G + "dut.o_ws_tx", "0", 1), cell=2, ncell=29, rows={
        "o_bclk_tx": "dut.o_bclk_tx", "w_tx_level": "dut.w_tx_level", "w_apb_wr_frame": None,
        "w_ready": "dut.gen_tx.u_frame_0.w_ready_ok",
        "w_fsm_frame_state": "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state", "o_ws_tx": "dut.o_ws_tx",
        "o_sdo_0": "dut.o_sdo_0"}),
    "wf_012_sync_hung": dict(clk=G + "dut.i_bclk_rx", anchor=(G + "dut.gen_rx.u_frame_1.w_hung_pulse", "1", 1), cell=14, ncell=24, rows={
        "i_bclk_rx": "dut.i_bclk_rx", "i_ws_rx": "dut.i_ws_rx",
        "w_fsm_frame_state": "dut.gen_rx.u_frame_1.reg_fsm_frame_current_state", "w_sync_err": "dut.gen_rx.u_frame_1.o_ev_sync",
        "i2s_irq_raw.sync": "dut.u_csr_i2s.o_i2s_irq_raw_sync", "w_tmo_run": None,
        "w_hung": "dut.gen_rx.u_frame_1.w_hung_pulse", "i2s_irq_raw.hung": "dut.u_csr_i2s.o_i2s_irq_raw_hung"}),
    "wf_013_dma_burst": dict(clk=G + "clk_apb", anchor=(G + "dma_tx_req", "1", 1), cell=2, rows={
        "i_clk_apb": "CLK", "w_cond": None, "o_dma_tx_req": "dut.o_dma_tx_req", "i_dma_tx_ack": "dut.i_dma_tx_ack",
        "o_dma_tx_single": "dut.o_dma_tx_single"}),
    "wf_014_dma_single": dict(clk=G + "clk_apb", anchor=(G + "dma_rx_ack", "1", 1), cell=2, rows={
        "i_clk_apb": "CLK", "w_rx_level": "dut.w_rx_level", "o_dma_rx_req": "dut.o_dma_rx_req",
        "o_dma_rx_single": "dut.o_dma_rx_single", "i_dma_rx_ack": "dut.i_dma_rx_ack"}),
    "wf_015_irq_four": dict(clk=G + "clk_apb", anchor=(G + "dut.u_csr_i2s.o_i2s_irq_raw_tx_und", "1", 1), cell=3, rows={
        "i_clk_apb": "CLK", "w_event": "dut.gen_tx.w_und", "i2s_irq_raw.tx_und": "dut.u_csr_i2s.o_i2s_irq_raw_tx_und",
        "i2s_irq_en.tx_und": "dut.u_csr_i2s.o_i2s_irq_en_tx_und", "i2s_irq_inj.tx_und": "dut.u_csr_i2s.o_i2s_irq_inj_tx_und",
        "i2s_irq_sts.tx_und": "dut.u_csr_i2s.i_i2s_irq_sts_tx_und", "o_int_i2s": "dut.o_int_i2s", "w_apb_clr": None}),
    "wf_016_stop_flush": dict(clk=G + "clk_mclk", anchor=(G + "dut.gen_tx.w_en_s", "0", 1), cell=4, ncell=20, rows={
        "i_clk_mclk": "CLK", "w_en": "dut.gen_tx.w_en_s",
        "w_fsm_frame_state": "dut.gen_tx.u_frame_0.reg_fsm_frame_current_state",
        "i2s_sts.tx_busy": "dut.u_csr_i2s.i_i2s_tx_sts_busy", "w_flush": "dut.gen_tx.w_flush_ev",
        "w_tx_level": "dut.w_tx_level"}),
    "wf_017_reset": dict(clk=G + "clk_apb", anchor=(G + "rst_n_apb", "0", 1), cell=0, rows={
        "i_clk_apb": "CLK", "i_rst_n_apb": "dut.i_rst_n_apb", "w_rst_apb_sync": "dut.w_rst_n_apb",
        "i_clk_mclk": "CLK2", "i_rst_n_mclk": "dut.i_rst_n_mclk", "w_rst_mclk_sync": "dut.w_rst_n_mclk",
        "o_bclk_tx": "dut.o_bclk_tx", "o_sdo_0": "dut.o_sdo_0"}),
}
PULSE = {"w_pop_word", "w_sample", "w_rx_push", "w_rx_push_try", "w_rx_ovr", "w_und", "w_flush", "w_hung", "w_sync_err", "w_cfg_snap", "w_event"}
SAME_SCALE = {"wf_001_apb_rw", "wf_002_apb_error", "wf_013_dma_burst", "wf_014_dma_single", "wf_015_irq_four", "wf_017_reset"}


def parse_vcd(path):
    ids, scope, sigs, cur = {}, [], {}, 0
    with open(path) as f:
        text = f.read().split("\n")
    i = 0
    while i < len(text):
        l = text[i].strip(); i += 1
        if l.startswith("$scope"): scope.append(l.split()[2])
        elif l.startswith("$upscope"): scope.pop()
        elif l.startswith("$var"):
            p = l.split(); name = ".".join(scope) + "." + p[4]
            ids.setdefault(p[3], []).append(name); sigs[name] = {"w": int(p[2]), "ch": []}
        elif l.startswith("$enddefinitions"): break
    while i < len(text):
        l = text[i].strip(); i += 1
        if not l: continue
        if l[0] == "#": cur = int(l[1:])
        elif l[0] in "01xzXZ" and len(l) > 1:
            for n in ids.get(l[1:], []): sigs[n]["ch"].append((cur, l[0].lower()))
        elif l[0] == "b":
            v, k = l[1:].split()
            for n in ids.get(k, []): sigs[n]["ch"].append((cur, v.lower()))
    return sigs


def val_at(sig, t):
    ch = sig["ch"]; lo, hi = 0, len(ch) - 1; r = "x"
    while lo <= hi:
        mid = (lo + hi) // 2
        if ch[mid][0] <= t: r = ch[mid][1]; lo = mid + 1
        else: hi = mid - 1
    return r


def first_edge(sig, value, nth, t_min=0):
    c = 0; prev = None
    for t, v in sig["ch"]:
        if t >= t_min and v == value and prev is not None and prev != value:
            c += 1
            if c == nth: return t
        prev = v
    return None


def rising_edges(clk, t0, t1):
    out = []; prev = None
    for t, v in clk["ch"]:
        if prev == "0" and v == "1" and t0 <= t <= t1: out.append(t)
        prev = v
    return out


def spec_cells(wave):
    """decode a WaveDrom string to a list of cell values ('0','1','x','=' ...)"""
    out = []; last = "x"
    for c in wave:
        if c == ".": out.append(last)
        else: last = c; out.append(c)
    return out


def sample_row(sig, t_cells, width, pulse_span=0):
    out = []; data = []; last = None
    for t in t_cells:
        v = val_at(sig, t)
        if pulse_span and width == 1:
            # a one-clock pulse inside a slow cell is drawn in that cell (the figures show one pulse per bit-clock cell)
            if v != "1" and any(c == "1" for tt, c in sig["ch"] if t - pulse_span <= tt < t): v = "1"
        if width == 1:
            out.append(v if v in "01xz" else "x")
        else:
            if v == last and out: out.append(".")
            else:
                out.append("=" if not set(v) <= set("xz") else "x"); data.append(hex(int(v, 2)) if set(v) <= set("01") and v else "x")
            last = v
    return out, data


def build_one(stem, cfg, sigs):
    vcd = os.path.join(SIM, stem + ".vcd")
    clk = sigs[cfg["clk"]]
    spec = json.load(open(os.path.join(SPEC_FIG, stem + ".json")))
    n_spec = max(len(r.get("wave", "")) for r in spec["signal"] if "wave" in r)
    ncell = cfg.get("ncell", n_spec)
    a_path, a_val, a_n = cfg["anchor"]
    t_a = first_edge(sigs[a_path], a_val, a_n)
    if t_a is None: return None, "anchor event not found"
    edges = rising_edges(clk, 0, sigs[a_path]["ch"][-1][0] + 10**9)
    # cell index of the anchor: the cell whose start edge is the last edge before or at the anchor time
    k = max(i for i, e in enumerate(edges) if e <= t_a) if any(e <= t_a for e in edges) else 0
    start = k - cfg["cell"]
    if start < 0: start = 0
    cells = edges[start:start + ncell]
    if len(cells) < 2: return None, "window too short"
    period = cells[1] - cells[0]
    bit_grid = cfg["clk"].endswith("bclk_tx") or cfg["clk"].endswith("bclk_rx")
    # a bit-clock cell is sampled late in the cell (data and frame sync are launched at the falling edge); other cells mid-cell
    t_cells = [e + (period * 3) // 4 if bit_grid else e + period // 2 for e in cells]
    rows = []
    for name, path in cfg["rows"].items():
        if isinstance(path, dict):
            # a second scenario inside the same dump: window re-anchored on the first anchor event after the n-th reset assertion
            t_rst = first_edge(sigs[G + "rst_n_apb"], "0", path["after_reset"])
            t_a2 = first_edge(sigs[a_path], a_val, 1, t_min=t_rst)
            k2 = max(i for i, e in enumerate(edges) if e <= t_a2)
            c2 = edges[max(0, k2 - cfg["cell"]):max(0, k2 - cfg["cell"]) + ncell]
            tc2 = [e + (period * 3) // 4 if bit_grid else e + period // 2 for e in c2]
            p2 = G + path["path"]
            wave, data = sample_row(sigs[p2], tc2, sigs[p2]["w"])
            rows.append({"name": name, "wave": "".join(wave)}); continue
        if path is None: rows.append({"name": name, "missing": True}); continue
        if path == "CLK": rows.append({"name": name, "wave": "p" + "." * (len(cells) - 1)}); continue
        if path == "CLK2": rows.append({"name": name, "wave": "p" + "." * (len(cells) - 1)}); continue
        p = path if path.startswith("tb_i2s.") else G + path
        if p == cfg["clk"]: rows.append({"name": name, "wave": "p" + "." * (len(cells) - 1)}); continue
        if p not in sigs: rows.append({"name": name, "missing": True}); continue
        w = sigs[p]["w"]
        wave, data = sample_row(sigs[p], t_cells, w, (period * 3) // 4 + 0 if (name in PULSE and bit_grid) else 0)
        r = {"name": name, "wave": "".join(wave)}
        if data: r["data"] = data
        rows.append(r)
    return {"rows": rows, "ncell": len(cells), "period_ps": period, "t_start_ps": cells[0]}, None


def to_wavejson(stem, built, spec):
    sig = []
    for r in built["rows"]:
        if r.get("missing"): continue
        e = {"name": r["name"], "wave": r["wave"]}
        if r.get("data"): e["data"] = r["data"]
        sig.append(e)
    head = {"text": "Simulated " + spec.get("head", {}).get("text", stem) + " (synthesis branch, legal scale)"}
    foot = {"text": "From %s.vcd, %d cells of %d ps from t=%d ps. Rows without a RTL signal are omitted." % (stem, built["ncell"], built["period_ps"], built["t_start_ps"])}
    return {"signal": sig, "head": head, "foot": foot, "config": {"hscale": 1}}


def compare_rows(spec, built):
    res = {}
    for r in spec["signal"]:
        if "wave" not in r: continue
        name = r["name"]
        sc = spec_cells(r["wave"])
        b = next((x for x in built["rows"] if x["name"] == name), None)
        if b is None or b.get("missing"):
            res[name] = ("MISSING", None); continue
        wave = b["wave"]
        # expand sim wave for compare
        sim = []; last = "x"
        for c in wave:
            if c == ".": sim.append(last)
            else: last = c; sim.append(c)
        if name.startswith("i_clk") or name.startswith("i_clk_mclk"): res[name] = ("CLOCK", None); continue
        n = min(len(sc), len(sim))
        multi = any(c == "=" for c in sc) or any(c == "=" for c in sim)
        if multi:
            # compare the change positions only
            # positions of the value changes ('=' cells of the raw wave string); cells after an unknown value in the figure are free
            sp = [i for i, c in enumerate(r["wave"][:n]) if c == "=" and i > 0 and sc[i - 1] != "x"]
            mp = [i for i, c in enumerate(wave[:n]) if c == "=" and i > 0 and sc[i - 1] != "x" and sc[i] != "x"]
            ok = sp == mp
            res[name] = ("MATCH" if ok else "DIFFERENT", None if ok else "change positions differ")
        else:
            bad = [i for i in range(n) if sc[i] != sim[i] and sc[i] != "x" and sc[i] != "="]
            res[name] = ("MATCH", None) if not bad else ("DIFFERENT", "first mismatch at cell %d (figure %s, simulation %s)" % (bad[0], sc[bad[0]], sim[bad[0]]))
    return res


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "build"
    out = {}
    for stem, cfg in WINDOW.items():
        vcd = os.path.join(SIM, stem + ".vcd")
        if not os.path.exists(vcd): out[stem] = {"error": "no vcd"}; continue
        sigs = parse_vcd(vcd)
        spec = json.load(open(os.path.join(SPEC_FIG, stem + ".json")))
        built, err = build_one(stem, cfg, sigs)
        if err: out[stem] = {"error": err}; print(stem, "ERROR", err); continue
        wj = to_wavejson(stem, built, spec)
        json.dump(wj, open(os.path.join(SIM, stem + ".json"), "w"), indent=1)
        cmp_ = compare_rows(spec, built)
        out[stem] = {"rows": {k: v[0] for k, v in cmp_.items()}, "notes": {k: v[1] for k, v in cmp_.items() if v[1]},
                     "ncell": built["ncell"], "period_ps": built["period_ps"], "same_scale": stem in SAME_SCALE}
        print(stem, {k: v[0] for k, v in cmp_.items()})
    json.dump(out, open(os.path.join(SIM, "compare_data.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
