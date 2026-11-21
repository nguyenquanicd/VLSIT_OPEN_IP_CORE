#!/usr/bin/env python3
"""Summarise a merged Verilator coverage database (logs/cov/merged.dat) by file group and metric (R-047).
Metrics of Verilator 5 with --coverage-line --coverage-toggle: line, branch (recorded with the line points) and toggle.
usage: cov_report.py merged.dat > coverage_report.md"""
import collections, os, re, sys

path = sys.argv[1]
pts = []
for raw in open(path, encoding="latin-1"):
    if not raw.startswith("C '"): continue
    body, cnt = raw[3:].rsplit("' ", 1)
    f = {}
    for part in body.split("\x01"):
        if "\x02" in part:
            k, v = part.split("\x02", 1); f[k] = v
    pts.append((f.get("f", ""), int(f.get("l", 0)), f.get("t", ""), f.get("o", ""), f.get("h", ""), int(cnt)))


def group(fn):
    n = fn.replace("\\", "/")
    if "/tb/" in n or n.endswith("tb_i2s.sv") or "i2s_dev" in n or "i2s_apb_chk" in n: return "testbench"
    if n.startswith("csr/") or "/csr/" in n: return "generated CSR (APB-CSR-Generator)"
    if "../../" in n: return "reused library (000_Common, 001, 010)"
    return "DUT own RTL (rtl/*.sv)"


tot = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0]))
per_file = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0]))
unc = collections.defaultdict(list)
file_group = {}
for fn, ln, t, o, h, c in pts:
    g = group(fn)
    file_group[os.path.basename(fn.replace("\\", "/"))] = g
    tot[g][t][1] += 1
    per_file[os.path.basename(fn.replace("\\", "/"))][t][1] += 1
    if c > 0: tot[g][t][0] += 1; per_file[os.path.basename(fn.replace("\\", "/"))][t][0] += 1
    elif t != "toggle": unc[os.path.basename(fn.replace("\\", "/"))].append((ln, t, o))

print("# Code coverage (Verilator 5.053, --coverage-line --coverage-toggle, merged over the runs of logs/cov)\n")
print("Status: `baseline_only` (no target was set by the designer). Metrics: line, branch and toggle; Verilator records branch points with "
      "the line instrumentation and has no separate condition metric. Toggle counts each rising and falling transition of a bit as one point.\n")
print("| Scope | Line | Branch | Toggle |")
print("|---|---|---|---|")
for g in ["DUT own RTL (rtl/*.sv)", "generated CSR (APB-CSR-Generator)", "reused library (000_Common, 001, 010)", "testbench"]:
    row = []
    for t in ["line", "branch", "toggle"]:
        a, b = tot[g][t]
        row.append("%d / %d = %.1f%%" % (a, b, 100.0 * a / b) if b else "n/a")
    print("| %s | %s |" % (g, " | ".join(row)))
print("\n## Per file of the DUT own RTL\n")
print("| File | Line | Branch | Toggle |")
print("|---|---|---|---|")
for fn in sorted(per_file):
    if file_group[fn] != "DUT own RTL (rtl/*.sv)": continue
    row = []
    for t in ["line", "branch", "toggle"]:
        a, b = per_file[fn][t]
        row.append("%d / %d = %.1f%%" % (a, b, 100.0 * a / b) if b else "n/a")
    print("| %s | %s |" % (fn, " | ".join(row)))
print("\n## Uncovered line and branch points of the DUT own RTL\n")
for fn in sorted(unc):
    if file_group[fn] != "DUT own RTL (rtl/*.sv)": continue
    print("- `%s`: %s" % (fn, ", ".join("%d(%s)" % (l, t[0]) for l, t, o in sorted(set(unc[fn])))))
