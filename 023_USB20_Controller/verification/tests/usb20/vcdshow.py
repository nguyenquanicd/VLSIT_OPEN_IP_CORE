"""Prints selected signals of a solver trace (VCD) at every clock step: python vcdshow.py trace.vcd sig1 sig2 ..."""
import re
import sys
ids = {}; cur = {}; hist = []; want = set(sys.argv[2:]); t = 0
for ln in open(sys.argv[1]):
    ln = ln.strip()
    m = re.match(r'\$var \w+ (\d+) (\S+) (\S+)', ln)
    if m and m.group(3).split('[')[0] in want and m.group(3) not in ids.values():
        ids[m.group(2)] = m.group(3)
    if ln.startswith('#'):
        hist.append((t, dict(cur))); t = int(ln[1:])
    elif ln and ln[0] == 'b':
        v, i = ln[1:].split()
        if i in ids: cur[ids[i]] = int(v, 2) if set(v) <= set('01') else v
    elif ln and ln[0] in '01' and ln[1:] in ids:
        cur[ids[ln[1:]]] = int(ln[0])
hist.append((t, dict(cur)))
for t, h in hist:
    if t % 10 == 5:
        print(t, {k: h.get(k) for k in sorted(set(ids.values()))})
