"""a_sdc_bind (review 2026-11-22 F-002): every get_cells / get_pins pattern of the SDC files must match at least one object of the RTL
hierarchy below each wrapper, otherwise the exception has no endpoint and timing analysis is silently clean. The hierarchy is
built from the RTL text (instance names and the registers, i.e. signals written with '<=', of every module); a cell object is
'inst/inst/.../reg', a pin object is a cell object plus '/<port>'. Patterns use the Tcl glob of -hierarchical (* matches '/').
It also flags set_max_delay or set_min_delay between two clocks that a set_clock_groups -asynchronous already cuts (most STA tools
do not time those paths, so the delay would never be checked).
    python scripts/check_sdc_objects.py [sdc ...]      exit 0 = every pattern matches in every wrapper"""
import fnmatch
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_sync_src as cs                                    # noqa: E402  (module parser shared with a_sync_src)

IP = cs.IP
TOPS = ['m_usb2_top_utmi_axim', 'm_usb2_top_utmi_axis', 'm_usb2_top_ulpi_axim', 'm_usb2_top_ulpi_axis']


def load():
    for d in cs.DEFAULT + [os.path.normpath(os.path.join(IP, '..', '000_Common'))]:
        for root, _, files in os.walk(d):
            for fn in sorted(files):
                if fn.endswith(('.sv', '.v')):
                    t = cs.strip(open(os.path.join(root, fn), encoding='utf-8', errors='ignore').read())
                    for m in re.finditer(r'\bmodule\s+(\w+)(.*?)\bendmodule\b', t, flags=re.S):
                        cs.DB.setdefault(m.group(1), cs.facts(m.group(2)))


def objects(mod, path, out, depth=0):
    f = cs.DB.get(mod)
    if f is None or depth > 12:
        return
    for r in f['ff']:
        out.add(path + r)
    for smod, iname, _ in f['insts']:
        out.add(path + iname)
        objects(smod, path + iname + '/', out, depth + 1)


def main():
    load()
    sdcs = sys.argv[1:] or sorted(glob.glob(os.path.join(IP, 'sdc', '*.sdc')))
    objs = {}
    for top in TOPS:
        if top in cs.DB:
            o = set()
            objects(top, '', o)
            objs[top] = o
    bad = 0
    for p in sdcs:
        text = open(p, encoding='utf-8').read()
        groups = []
        for n, ln in enumerate(text.split('\n'), 1):
            code = ln.split('#')[0]
            if 'set_clock_groups' in code and '-asynchronous' in code:
                groups.append(set(re.findall(r'get_clocks\s+(\w+)', code)))
            if re.search(r'set_(max|min)_delay', code):
                clks = set(re.findall(r'get_clocks\s+(\w+)', code))
                if not clks:
                    for g in groups:
                        if len(g) >= 2:
                            print('WARN %s:%d: %s -- the two clocks of this crossing are cut by set_clock_groups -asynchronous (line above);'
                                  ' most STA tools ignore the delay on those paths' % (os.path.basename(p), n, code.strip()[:90]))
            for kind, pat in re.findall(r'get_(cells|pins)\s+(?:-hierarchical\s+)?\[?\{?([^\]\}\s]+)', code):
                pats = [pat]
                for pt in pats:
                    miss = [t for t, o in objs.items() if not any(fnmatch.fnmatchcase(x if kind == 'cells' else x + '/i', pt) for x in o)]
                    hit = [t for t in objs if t not in miss]
                    if miss:
                        bad += 1
                        print('VIOLATION %s:%d: get_%s %s matches nothing in %s%s' % (os.path.basename(p), n, kind, pt, ', '.join(miss),
                              (' (matches in %s)' % ', '.join(hit)) if hit else ''))
    print('SDC files: %d, wrappers: %d, patterns without an object: %d' % (len(sdcs), len(objs), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
