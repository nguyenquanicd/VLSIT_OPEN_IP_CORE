"""Rebuilds the simulation builds of env/env/builds.json (all, or the names given) after an RTL or testbench change, after
regenerating the derived testbenches (ULPI and AXI-slave variants) from env/tb/tb_usb2_utmi_axim.sv.
Run from the verification folder:   python env/scripts/rebuild_all.py [name ...]"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402

os.chdir(P.V)
defs = [b['name'] for b in json.load(open(P.BUILDS_JSON))]
names = sys.argv[1:] or defs
subprocess.run([sys.executable, 'env/scripts/gen_ulpi_tb.py'], check=True)
subprocess.run([sys.executable, 'env/scripts/gen_axis_tb.py'], check=True)
subprocess.run([sys.executable, 'env/scripts/gen_ulpi_axis_tb.py'], check=True)
bad = 0
for n in names:
    r = subprocess.run([sys.executable, 'env/scripts/build.py', n, '--rebuild'], capture_output=True, text=True)
    print((r.stdout.strip().splitlines() or ['?'])[-1], flush=True)
    bad += r.returncode != 0
sys.exit(1 if bad else 0)
