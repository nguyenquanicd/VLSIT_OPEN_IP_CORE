#!/usr/bin/env python3
"""Put the redrawn WaveJSON of spec/figures into the wavedrom blocks of the specification (R-073: the JSON block follows the
image link) and the plan date. usage: wf_spec_update.py [--date YYYY-MM-DD]"""
import json, os, re, sys

V = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = os.path.join(V, "..", "spec", "VLSIT_APB_I2S_HDS.md")
FIG = os.path.join(V, "..", "spec", "figures")


def dump(d):
    rows = ",\n".join("  " + json.dumps(r, ensure_ascii=False) for r in d["signal"])
    return '{"signal": [\n%s\n ],\n "head": %s,\n "foot": %s,\n "config": %s}' % (
        rows, json.dumps(d["head"]), json.dumps(d["foot"]), json.dumps(d["config"]))


text = open(SPEC, encoding="utf-8", newline="").read()
n = 0
for fn in sorted(os.listdir(FIG)):
    m = re.match(r"(wf_\d{3}_.*)\.json$", fn)
    if not m: continue
    stem = m.group(1)
    d = json.load(open(os.path.join(FIG, fn), encoding="utf-8"))
    pat = re.compile(r"(\]\(figures/%s\.svg\)\n\n```wavedrom\n)(.*?)(\n```)" % re.escape(stem), re.S)
    if not pat.search(text): print("block not found:", stem); continue
    text = pat.sub(lambda mo: mo.group(1) + dump(d) + mo.group(3), text, count=1)
    n += 1
open(SPEC, "w", encoding="utf-8", newline="").write(text)
print("updated", n, "wavedrom blocks")
