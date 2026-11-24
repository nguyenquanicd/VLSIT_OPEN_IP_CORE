#!/usr/bin/env python3
"""dvp_coverage.py - code coverage (Verilator line, branch and toggle points) of the DVP RTL under the base-configuration regression
(AI-generated candidate, R-117). Builds the harness once with --coverage, runs the directed and random cases of the `base` configuration,
merges the coverage data and writes flat results to the output directory (default verification/sim/final): coverage_summary.json,
coverage_summary.txt and coverage_uncovered.txt (every uncovered DVP-owned line/branch point). Build and raw data are temporary.
Usage: python dvp_coverage.py [--out DIR]
"""
import argparse, json, os, re, shutil, sys, tempfile
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dvp_regress as R

COV_TOOL = r'C:\Tools\oss-cad-suite\bin\verilator_coverage_bin.exe'
BRANCH_KINDS = {'if', 'else', 'elsif', 'case', 'cond', 'branch'}


def parse_dat(path):
    pts = {}
    for line in open(path, encoding='utf-8', errors='replace'):
        if not line.startswith('C '):
            continue
        body, _, count = line[3:].rpartition("' ")
        kv = {}
        for item in body.split('\x01'):
            if '\x02' in item:
                k, v = item.split('\x02', 1)
                kv[k] = v
        key = (kv.get('f', '?'), kv.get('l', '0'), kv.get('n', '0'), kv.get('page', ''), kv.get('o', ''), kv.get('h', ''), kv.get('S', ''))
        pts[key] = pts.get(key, 0) + int(count.strip() or 0)
    return pts


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default=os.path.join(R.VER, 'sim', 'final'))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    budget = json.load(open(os.path.join(R.ENVD, 'config', 'resource_budget.json'), encoding='utf-8'))
    R.preflight(budget, a.out)
    defines, tests, seeds, pseeds = R.CONFIGS['base']
    tmp = tempfile.mkdtemp(prefix='dvp_cov_')
    try:
        mdir = os.path.join(tmp, 'build')
        rc, _ = R.run(R.vl_common('tb_dvp_controller', mdir) + ['--coverage'] + ['-G' + d for d in defines] + ['-f', 'filelist.f'] + R.SRC_ENV,
                      R.RTL, os.path.join(tmp, 'compile.log'), 1800, 'coverage build')
        if rc != 0:
            sys.exit('coverage build failed')
        exe = os.path.join(mdir, 'Vtb_dvp_controller.exe')
        cases = [(t, s, []) for t in tests for s in seeds] + [(R.PERF, s, ['+MODE=%d' % m]) for s in pseeds for m in (0, 1)]
        dats, passed = [], 0
        for i, (t, s, extra) in enumerate(cases):
            cwd = os.path.join(tmp, 'c%d' % i); os.makedirs(cwd)
            dat = os.path.join(cwd, 'cov.dat')
            plus = ['+AFIFO_MSYNC_SEED=%d' % s, '+AFIFO_MSYNC_EN=1', '+RSTSYNC_MSYNC_SEED=%d' % s, '+RSTSYNC_MSYNC_EN=1'] + extra
            lp = os.path.join(cwd, 'sim.log')
            R.run([exe, '+TEST=' + t, '+SEED=%d' % s, '+TIMEOUT_NS=2000000', '+verilator+coverage+file+' + dat.replace('\\', '/')] + plus, cwd, lp, 600, 'coverage case %s s%d' % (t, s))
            res = R.parse_log(lp)['result']
            passed += res == 'PASS'
            if os.path.exists(dat):
                dats.append(dat)
            print('  %-40s s%d %s' % (t + (extra[0] if extra else ''), s, res), flush=True)
        merged = os.path.join(tmp, 'merged.dat')
        R.run([COV_TOOL, '--write', merged] + dats, tmp, os.path.join(tmp, 'merge.log'), 600, 'coverage merge')
        pts = parse_dat(merged)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    def group_of(base):
        if base.startswith('dv_') or base.startswith('tb_'):
            return 'verification-env'
        if base.startswith('m_dvp_') or base == 'm_vlsit_csr_dvp.sv':
            return 'DVP-owned'          # RTL of this IP (rtl/ and rtl/csr/)
        return 'shared'                 # 000_Common cells and the 001/002 FIFO modules reused by this IP
    rows = defaultdict(lambda: defaultdict(lambda: [0, 0]))   # file -> metric -> [covered, total]
    uncovered = []
    for (f, l, n, page, o, h, S), c in pts.items():
        base = os.path.basename(f.replace('\\', '/'))
        group = group_of(base)
        if page.startswith('v_toggle'):
            metric = 'toggle'
        elif o in BRANCH_KINDS:
            metric = 'branch'
        elif page.startswith('v_line') or page.startswith('v_branch'):
            metric = 'line'
        else:
            continue
        rows[(group, base)][metric][1] += 1
        rows[(group, base)][metric][0] += c > 0
        if group == 'DVP-owned' and metric in ('line', 'branch') and c == 0:
            uncovered.append((base, int(l or 0), metric, o, h))
    summary = {'cases': len(cases), 'cases_pass': passed, 'files': {}, 'totals': {}}
    tot = defaultdict(lambda: [0, 0])
    for (group, base), m in sorted(rows.items()):
        summary['files']['%s/%s' % (group, base)] = {k: {'covered': v[0], 'total': v[1], 'percent': round(100.0 * v[0] / v[1], 1) if v[1] else None} for k, v in m.items()}
        for k, v in m.items():
            tot[(group, k)][0] += v[0]; tot[(group, k)][1] += v[1]
    for (group, k), v in sorted(tot.items()):
        summary['totals']['%s/%s' % (group, k)] = {'covered': v[0], 'total': v[1], 'percent': round(100.0 * v[0] / v[1], 1) if v[1] else None}
    json.dump(summary, open(os.path.join(a.out, 'coverage_summary.json'), 'w', encoding='utf-8'), indent=1)
    with open(os.path.join(a.out, 'coverage_summary.txt'), 'w', encoding='utf-8') as f:
        f.write('Verilator code coverage, base configuration regression (%d cases, %d pass)\n\n' % (len(cases), passed))
        for k, v in summary['totals'].items():
            f.write('TOTAL %-22s %5d / %-5d %s%%\n' % (k, v['covered'], v['total'], v['percent']))
        f.write('\n')
        for k, m in summary['files'].items():
            f.write('%-48s %s\n' % (k, '  '.join('%s %d/%d (%s%%)' % (mk, mv['covered'], mv['total'], mv['percent']) for mk, mv in sorted(m.items()))))
    with open(os.path.join(a.out, 'coverage_uncovered.txt'), 'w', encoding='utf-8') as f:
        f.write('Uncovered line/branch points of DVP-owned RTL (file, line, kind, construct, hierarchy)\n')
        for base, l, metric, o, h in sorted(set(uncovered)):
            f.write('%-28s %5d %-7s %-8s %s\n' % (base, l, metric, o, h))
    print(open(os.path.join(a.out, 'coverage_summary.txt'), encoding='utf-8').read())
    return 0


if __name__ == '__main__':
    sys.exit(main())
