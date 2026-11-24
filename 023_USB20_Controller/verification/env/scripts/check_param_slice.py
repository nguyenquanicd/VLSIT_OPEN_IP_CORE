"""a_param_slice (review 2026-11-22 F-021): static check of every part-select of a parameter, PARA_X[h:l], in the RTL. The legal range
of PARA_X is read from its declaration comment ('Parameter values: A to B') in the module that declares it, or in any RTL module
that declares a parameter of the same name. A select that cannot hold the largest legal value (B > 2**(h-l+1) - 1, for l = 0)
truncates it: a count of 16 seen through [3:0] is 0, so a compare 'index < PARA_X[3:0]' refuses every index. Each such select
is reported with its line; selects whose largest value fits, and parameters without a stated range (reported as UNKNOWN), pass.
    python scripts/check_param_slice.py [rtl folder]      exit 0 = no truncating select"""
import os
import re
import sys

IP = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))   # verification/env/scripts -> IP
RTL = os.path.normpath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(IP, 'rtl')


def files():
    for root, _, fs in os.walk(RTL):
        for f in sorted(fs):
            if f.endswith('.sv'):
                yield os.path.join(root, f)


def main():
    rng = {}
    for p in files():
        t = open(p, encoding='utf-8', errors='ignore').read()
        for m in re.finditer(r'Parameter values:\s*([^\n]*)\n(?:\s*//[^\n]*\n)*?\s*parameter\b[^=;]*?\b(PARA_\w+)\s*=', t):
            vals = [int(x) for x in re.findall(r'\b\d+\b', m.group(1).split(';')[0])]
            if vals:
                rng[m.group(2)] = max(rng.get(m.group(2), 0), max(vals))
    bad, unknown, ok = [], set(), 0
    for p in files():
        for n, ln in enumerate(open(p, encoding='utf-8', errors='ignore'), 1):
            code = ln.split('//')[0]
            for m in re.finditer(r'\b(PARA_\w+)\s*\[\s*(\d+)\s*:\s*0\s*\]', code):
                name, h = m.group(1), int(m.group(2))
                if name not in rng:
                    unknown.add(name)
                    continue
                if rng[name] > (1 << (h + 1)) - 1:
                    bad.append('%s:%d: %s[%d:0] cannot hold the largest legal value %d: %s' % (os.path.basename(p), n, name, h, rng[name], code.strip()))
                else:
                    ok += 1
    for b in bad:
        print('VIOLATION: ' + b)
    for u in sorted(unknown):
        print('UNKNOWN range (no "Parameter values" comment found): ' + u)
    print('parameters with a range: %d, selects that fit: %d, truncating selects: %d' % (len(rng), ok, len(bad)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
