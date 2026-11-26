"""a_cdc_struct (REQ-CLK-002): structural check that every wire that crosses between the CLK-BUS and the CLK-PHY domain in rtl/m_usb2_core.sv
goes through a crossing structure (m_usb2_xreg, m_usb2_cdc_fifo, reset block, ULPI or UTMI+ wake detector or a VLSIT synchronizer cell). Each instance is
assigned a domain from the clock input it is connected to (i_clk_bus or i_clk_phy); a wire driven by an output of an instance of one domain and
read by an input of an instance of the other domain, where neither instance is a crossing structure, is a violation. Connections only: no
timing, no combinational analysis inside the modules; it does not replace a CDC tool run (vlsit-cdc-review).
    python scripts/check_cdc_struct.py [rtl folder]      exit 0 = no violation (the folder argument is for the mutant check)"""
import os
import re
import sys

IP = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))   # verification/env/scripts -> IP
RTL = os.path.normpath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(IP, 'rtl')
CROSSING = ('m_usb2_xreg', 'm_usb2_cdc_fifo', 'm_usb2_rst', 'm_usb2_ulpilp', 'm_usb2_utmilp', 'm_usb2_cfgchk')   # utmilp: DEC-049, CDC-008
SYNC_PREFIX = ('VLSIT_CELL', 'm_vlsit_')
ORIG = os.path.join(IP, 'rtl')


def strip(t):
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
    return re.sub(r'//[^\n]*', '', t)


def balanced(t, k):
    """Index after the parenthesis group that starts at t[k] == '('."""
    depth = 0
    while k < len(t):
        depth += (t[k] == '(') - (t[k] == ')')
        k += 1
        if depth == 0:
            return k
    return k


def ports_of(mod):
    for d in (RTL, os.path.join(RTL, 'csr'), ORIG, os.path.join(ORIG, 'csr')):
        p = os.path.join(d, mod + '.sv')
        if os.path.exists(p):
            t = strip(open(p, encoding='utf-8', errors='ignore').read())
            m = re.search(r'\bmodule\s+' + mod + r'\b', t)
            k = t.index('(', m.end())
            if t[m.end():].lstrip().startswith('#'):
                k = t.index('(', balanced(t, k))
            hdr = t[k:balanced(t, k)]
            res = {}
            for x in re.finditer(r'\b(input|output)\b([^,;]*?)\b(\w+)\s*(?=,|$|\)|\[)', hdr):
                res[x.group(3)] = x.group(1)
            return res
    return None


def main():
    core = strip(open(os.path.join(RTL, 'm_usb2_core.sv'), encoding='utf-8').read())
    insts = []
    for m in re.finditer(r'\b(m_usb2_\w+|m_vlsit_\w+|VLSIT_CELL_\w+)\s*(#\s*\()?', core):
        mod, k = m.group(1), m.end()
        if m.group(2):
            k = balanced(core, m.end() - 1)
        n = re.match(r'\s*(\w+)\s*\(', core[k:])
        if not n:
            continue
        start = k + n.end() - 1
        body = core[start + 1:balanced(core, start) - 1]
        conns = {}
        for c in re.finditer(r'\.(\w+)\s*\(', body):
            conns[c.group(1)] = body[c.end():balanced(body, c.end() - 1) - 1]
        insts.append((mod, n.group(1), conns))
    drivers, readers, dom = {}, {}, {}
    for mod, name, conns in insts:
        d = None
        for k, v in conns.items():
            if k.startswith('i_clk'):
                if 'i_clk_bus' in v:
                    d = 'bus'
                elif 'i_clk_phy' in v:
                    d = d or 'phy'
        dom[name] = d
        pl = ports_of(mod)
        if pl is None:
            continue
        crossing = mod in CROSSING or mod.startswith(SYNC_PREFIX)
        for port, expr in conns.items():
            dirn = pl.get(port)
            for w in set(re.findall(r'\b(?:w|reg)_\w+', expr)):
                (drivers if dirn == 'output' else readers).setdefault(w, []).append((name, mod, crossing, d))
    viol = set()
    for w, rd in readers.items():
        for (dn, dmod, dcross, ddom) in drivers.get(w, []):
            for (rn, rmod, rcross, rdom) in rd:
                if ddom and rdom and ddom != rdom and not (dcross or rcross):
                    viol.add((w, dn, ddom, rn, rdom))
    for w, dn, dd, rn, rd in sorted(viol):
        print('VIOLATION: %s driven by %s (%s) and read by %s (%s) without a crossing structure' % (w, dn, dd, rn, rd))
    both = sum(1 for w in readers if w in drivers)
    print('instances parsed: %d (domain known for %d), wires with a driver and a reader: %d, violations: %d' % (len(insts), sum(1 for v in dom.values() if v), both, len(viol)))
    return 1 if viol else 0


if __name__ == '__main__':
    sys.exit(main())
