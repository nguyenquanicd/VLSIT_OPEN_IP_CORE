"""a_sync_src (review 2026-11-22 F-020, CDC-001): structural check that the data input of every synchronizer instance is driven by a
register of the source domain (or by a module input, which the parent must drive from a register), never by combinational
logic: gates in front of a synchronizer can glitch between clock edges, and a multi-bit Gray word built by an encoder after
the register is no longer a Gray code at the sampling instant.
A synchronizer is an instance of a module whose name contains 'sync' (m_vlsit_afifo_sync, VLSIT_CELL_*SYNC*, m_vlsit_*sync*).
The signal on its data port (.i_data, .i_d, .i_din, .i_async) is traced through plain renames ('assign a = b;' or a bit select
of b) and through output ports of child instances; it passes when it ends at a signal written with a nonblocking assignment
(always_ff, by the RTL rules) or at an input port of the module. Anything else (an assign with an operator, an always_comb
output) is a violation. Connections only, no elaboration; it does not replace a CDC tool run.
    python scripts/check_sync_src.py [rtl folder ...]      exit 0 = no violation; default folders: ../rtl and the library cells
A folder given on the command line is checked; the default folders are always read for the definitions of child modules, and a
module found first in a given folder overrides the default one (used by the mutant check)."""
import os
import re
import sys

IP = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))   # verification/env/scripts -> IP
DEFAULT = [os.path.join(IP, 'rtl'), os.path.normpath(os.path.join(IP, '..', '001_AsyncGrayFIFO', 'rtl'))]
DATA_PORTS = ('i_data', 'i_d', 'i_din', 'i_async', 'i_data_async')
PLAIN = re.compile(r'^\{?\s*(\w+)\s*(\[[^\]]*\])?\s*\}?$')
PORT_RE = r'\b%s\b[^;,)]*?\b(\w+)\s*(?=[,;)\n])'
DB = {}


def strip(t):
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
    return re.sub(r'//[^\n]*', '', t)


def balanced(t, k):
    depth = 0
    while k < len(t):
        depth += (t[k] == '(') - (t[k] == ')')
        k += 1
        if depth == 0:
            return k
    return k


def facts(body):
    """Registers, ports, assigns and instance connections of one module body."""
    f = dict(inputs=set(re.findall(PORT_RE % 'input', body)), outputs=set(re.findall(PORT_RE % 'output', body)),
             ff=set(re.findall(r'\b(\w+)\s*(?:\[[^\]]*\])*\s*<=(?!=)', body)), assigns={}, insts=[])
    for a in re.finditer(r'\bassign\s+(\w+)\s*(?:\[[^\]]*\])?\s*=\s*([^;]+);', body):
        f['assigns'].setdefault(a.group(1), a.group(2).strip())
    for inst in re.finditer(r'\b(m_\w+|VLSIT_CELL_\w+)\s*(#\s*\()?', body):
        k = inst.end()
        if inst.group(2):
            k = balanced(body, inst.end() - 1)
        n = re.match(r'\s*(\w+)\s*\(', body[k:])
        if not n:
            continue
        start = k + n.end() - 1
        cb = body[start + 1:balanced(body, start) - 1]
        conns = {}
        for c in re.finditer(r'\.(\w+)\s*\(', cb):
            conns[c.group(1)] = cb[c.end():balanced(cb, c.end() - 1) - 1].strip()
        f['insts'].append((inst.group(1), n.group(1), conns))
    return f


def is_reg(mod, sig, depth=0):
    """(True, '') when sig of module mod is a register (through renames and child outputs) or an input port."""
    f = DB.get(mod)
    if f is None or depth > 8:
        return False, 'module %s not found' % mod
    seen = set()
    while True:
        m = PLAIN.match(sig)
        if not m:
            return False, 'expression "%s"' % sig
        b = m.group(1)
        if b in seen:
            return False, 'loop at %s' % b
        seen.add(b)
        if b in f['ff'] or b in f['inputs']:
            return True, ''
        if b in f['assigns']:
            sig = f['assigns'][b]
            if not PLAIN.match(sig):
                return False, '%s.%s = %s (combinational)' % (mod, b, sig)
            continue
        for smod, _, conns in f['insts']:
            for port, expr in conns.items():
                pm = PLAIN.match(expr)
                if pm and pm.group(1) == b and smod in DB and port in DB[smod]['outputs']:
                    return is_reg(smod, port, depth + 1)
        return False, '%s.%s is not a register, an input, a plain rename or a registered child output' % (mod, b)


def main():
    folders = [os.path.normpath(a) for a in sys.argv[1:]] or DEFAULT
    checked = []
    for d in folders + [x for x in DEFAULT if x not in folders]:
        for root, _, files in os.walk(d):
            for fn in sorted(files):
                if not fn.endswith(('.sv', '.v')):
                    continue
                t = strip(open(os.path.join(root, fn), encoding='utf-8', errors='ignore').read())
                for m in re.finditer(r'\bmodule\s+(\w+)(.*?)\bendmodule\b', t, flags=re.S):
                    if m.group(1) in DB:
                        continue
                    DB[m.group(1)] = facts(m.group(2))
                    if d in folders:
                        checked.append((fn, m.group(1)))
    viol, n = [], 0
    for fn, name in checked:
        for mod, iname, conns in DB[name]['insts']:
            if 'sync' not in mod.lower():
                continue
            for port in DATA_PORTS:
                if port in conns:
                    n += 1
                    ok, why = is_reg(name, conns[port])
                    if not ok:
                        viol.append('%s: %s: instance %s of %s, port .%s: %s' % (fn, name, iname, mod, port, why))
    for v in viol:
        print('VIOLATION: ' + v)
    print('modules checked: %d, synchronizer data inputs checked: %d, violations: %d' % (len(checked), n, len(viol)))
    return 1 if viol else 0


if __name__ == '__main__':
    sys.exit(main())
