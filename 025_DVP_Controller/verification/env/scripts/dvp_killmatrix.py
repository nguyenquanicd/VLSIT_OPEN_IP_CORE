#!/usr/bin/env python3
"""dvp_killmatrix.py - full test x mutant kill matrix of the simulation tests (AI-generated candidate, R-117).

dvp_mutation.py stops at the first failing test of each mutant, so it cannot tell which tests are weak. This driver runs EVERY simulation
test of the mutation test list against every mutant (and the unmutated control M00) without stopping, and writes
sim/<out>/killmatrix.csv and killmatrix.json: rows = tests, columns = mutants, cell = FAIL (the test detects the mutant) or pass.
Only simulation is judged here; the formal harnesses are not run.
Usage: python dvp_killmatrix.py [--out DIR] [--only M01 M05 ...]
"""
import argparse, csv, json, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dvp_regress as R
import dvp_mutation as M


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default=os.path.join(R.VER, 'sim', 'final'))
    ap.add_argument('--only', nargs='*', default=[])
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    budget = json.load(open(os.path.join(R.ENVD, 'config', 'resource_budget.json'), encoding='utf-8'))
    tests = [(t, e) for t, e in M.TESTS]
    names = [t + (e[0] if e else '') for t, e in tests]
    matrix = {}      # mutant -> test -> result
    order = {m: i for i, m in enumerate(a.only)}
    todo = [x for x in M.MUTANTS if (not a.only or x[0] in order)]
    if a.only:
        todo.sort(key=lambda x: order[x[0]])
    for mid, cls, desc, edits, fnames, *cfg_opt in todo:
        defines = R.CONFIGS[cfg_opt[0]][0] if cfg_opt else M.BASE_DEFINES
        R.preflight(budget, a.out)
        tmp = tempfile.mkdtemp(prefix='dvp_km_')
        try:
            M.copy_tree(tmp)
            M.apply(tmp, edits)
            R.RTL = os.path.join(tmp, M.IPN, 'rtl')
            mdir = os.path.join(tmp, 'build')
            rc, _ = R.run(R.vl_common('tb_dvp_controller', mdir) + ['-G' + d for d in defines] + ['-f', 'filelist.f'] + R.SRC_ENV,
                          R.RTL, os.path.join(tmp, 'compile.log'), 900, 'matrix build ' + mid)
            if rc != 0:
                matrix[mid] = {n: 'BUILD_FAIL' for n in names}
                continue
            exe = os.path.join(mdir, 'Vtb_dvp_controller.exe')
            cwd = os.path.join(tmp, 'cwd'); os.makedirs(cwd)
            row = {}
            for (t, extra), n in zip(tests, names):
                plus = ['+AFIFO_MSYNC_SEED=1', '+AFIFO_MSYNC_EN=1', '+RSTSYNC_MSYNC_SEED=1', '+RSTSYNC_MSYNC_EN=1'] + extra
                lp = os.path.join(tmp, 'case.log')
                R.run([exe, '+TEST=' + t, '+SEED=1', '+TIMEOUT_NS=2000000'] + plus, cwd, lp, 300, 'matrix %s %s' % (mid, n))
                r = R.parse_log(lp)
                row[n] = 'pass' if r['result'] == 'PASS' else 'FAIL'
            matrix[mid] = row
            json.dump({'tests': names, 'matrix': matrix}, open(os.path.join(a.out, 'killmatrix.json'), 'w', encoding='utf-8'), indent=1)
            print('%s %s' % (mid, ' '.join(n.replace('t_dvp_', '')[:10] + '=' + row[n] for n in names if row[n] != 'pass') or 'no test detects it'), flush=True)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    json.dump({'tests': names, 'matrix': matrix}, open(os.path.join(a.out, 'killmatrix.json'), 'w', encoding='utf-8'), indent=1)
    with open(os.path.join(a.out, 'killmatrix.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        mids = list(matrix)
        w.writerow(['test'] + mids)
        for n in names:
            w.writerow([n] + [matrix[m][n] for m in mids])
        w.writerow(['mutants detected'] + [sum(1 for n in names if matrix[m][n] == 'FAIL') for m in mids])
    print('TESTS detecting no mutant:', [n for n in names if not any(matrix[m][n] == 'FAIL' for m in matrix if m != 'M00')])
    print('MUTANTS detected by no simulation test:', [m for m in matrix if m != 'M00' and not any(matrix[m][n] == 'FAIL' for n in names)])
    return 0


if __name__ == '__main__':
    sys.exit(main())
