"""Automatic mutation run: operator flips at sampled places of the RTL, chosen without looking at the tests.

The handpicked mutations of run_mutation.py were chosen by the author of the testbench and prove less
than they seem. This script samples places of m_vlsit_dsig_ctl.sv and m_vlsit_dsig_buf.sv by a fixed
random seed and flips one operator at each place (== and !=, & and |, ~ removed, 1'b0 and 1'b1,
< and >=, > and <=, + and -). Each mutant runs the testbench; a mutant that survives is listed with its
line so that a person can decide whether it is equivalent (no change of behavior) or a hole of the tests.

Usage: python run_auto_mutation.py [--count N] [--seed S] [--n OPS] [--jobs J]
Works in $TEMP/vlsit_028_auto, writes verification/docs/auto_mutation_report.md. Not part of the RTL.
"""
import argparse
import os
import random
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
VER = os.path.dirname(os.path.dirname(HERE))
IP = os.path.dirname(VER)
RTL = os.path.join(IP, 'rtl')
MODELS = os.path.join(VER, 'models', 'dsig_p1')
TESTS = os.path.join(VER, 'tests', 'dsig_p1')
CSR_ASYNC = 1
WORK = os.path.join(os.environ.get('TEMP', '.'), 'vlsit_028_auto')
REPORT = os.path.join(VER, 'docs', 'auto_mutation_report.md')
FILES = ['m_vlsit_dsig_ctl.sv', 'm_vlsit_dsig_buf.sv']

OPS = [
    (re.compile(r'(?<![=!<>])==(?!=)'), '!='),
    (re.compile(r'!='), '=='),
    (re.compile(r' & '), ' | '),
    (re.compile(r' \| '), ' & '),
    (re.compile(r'~(?=[\w(])'), ''),
    (re.compile(r"1'b0"), "1'b1"),
    (re.compile(r"1'b1"), "1'b0"),
    (re.compile(r' < '), ' >= '),
    (re.compile(r' > '), ' <= '),
    (re.compile(r' >= '), ' < '),
    (re.compile(r' \+ '), ' - '),
]


def sites(fname):
    lines = open(os.path.join(RTL, fname), encoding='utf-8').read().split('\n')
    start = 0
    for i, l in enumerate(lines):
        if l.startswith(');'):
            start = i + 1
            break
    out = []
    in_block = False
    for i in range(start, len(lines)):
        l = lines[i]
        code = l.split('//')[0]
        s = code.strip()
        if not s or s.startswith(('input', 'output', 'logic', 'wire', 'localparam', 'parameter', 'genvar', 'typedef',
                                  'import', 'module', 'endmodule', 'begin', 'end')):
            continue
        for op_i, (rx, rep) in enumerate(OPS):
            for m in rx.finditer(code):
                out.append((fname, i, m.start(), m.end(), rep, code.strip()[:90]))
    return out


def build_run(mid, fname, line, a, b, rep, n, jobs_dir):
    d = os.path.join(WORK, mid)
    os.makedirs(os.path.join(d, 'rtl'), exist_ok=True)
    lines = open(os.path.join(RTL, fname), encoding='utf-8').read().split('\n')
    lines[line] = lines[line][:a] + rep + lines[line][b:]
    open(os.path.join(d, 'rtl', fname), 'w', encoding='utf-8').write('\n'.join(lines))
    fl = []
    for ln in open(os.path.join(RTL, 'filelist.f'), encoding='utf-8'):
        s = ln.rstrip('\n')
        if not s.strip() or s.strip().startswith('//'):
            fl.append(s)
        elif os.path.basename(s) == fname:
            fl.append(os.path.join(d, 'rtl', fname).replace('\\', '/'))
        else:
            fl.append(os.path.normpath(os.path.join(RTL, s)).replace('\\', '/'))
    open(os.path.join(d, 'rtl', 'filelist.f'), 'w', encoding='utf-8').write('\n'.join(fl) + '\n')
    vvp = os.path.join(d, 'tb.vvp')
    cmd = ['iverilog', '-g2012', '-DVLSIT_SYNTHESIS', '-DCSR_ASYNC=%d' % CSR_ASYNC, '-s', 'tb_dsig_p1', '-I', HERE, '-I', MODELS, '-I', TESTS,
           '-o', vvp, '-f', os.path.join(d, 'rtl', 'filelist.f')]
    cmd += [os.path.join(HERE, f) for f in ('dsig_p1_wrap.sv', 'dsig_apb_assert.sv', 'dsig_p1_assert.sv', 'dsig_wf_probe.sv')]
    cmd += [os.path.join(TESTS, 'tb_dsig_p1.sv')]
    r = subprocess.run(cmd, cwd=os.path.join(d, 'rtl'), capture_output=True, text=True)
    if r.returncode != 0 or any('error' in x.lower() for x in (r.stdout + r.stderr).splitlines()):
        return None
    return vvp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--count', type=int, default=70)
    ap.add_argument('--seed', type=int, default=20261124)
    ap.add_argument('--n', type=int, default=60)
    ap.add_argument('--jobs', type=int, default=5)
    ap.add_argument('--async', dest='csr_async', type=int, default=1, help='CSR_ASYNC of the build (1 asynchronous clocks, 0 one clock)')
    ap.add_argument('--only', default='', help='ids of the sample to run again, e.g. A05,A08')
    a = ap.parse_args()
    global CSR_ASYNC, WORK, REPORT
    CSR_ASYNC = a.csr_async
    if CSR_ASYNC == 0:
        WORK = WORK + '_sync'
        REPORT = os.path.join(VER, 'docs', 'auto_mutation_report_sync.md')
    os.makedirs(WORK, exist_ok=True)
    allsites = []
    for f in FILES:
        allsites += sites(f)
    rnd = random.Random(a.seed)
    pick = rnd.sample(allsites, min(a.count, len(allsites)))
    pick.sort(key=lambda s: (s[0], s[1], s[2]))
    print('%d places found, %d sampled' % (len(allsites), len(pick)))
    jobs = []
    res = {}
    sel = [x for x in a.only.split(',') if x]
    for k, (fname, line, s0, s1, rep, text) in enumerate(pick):
        mid = 'A%02d' % k
        if sel and mid not in sel:
            continue
        vvp = build_run(mid, fname, line, s0, s1, rep, a.n, WORK)
        info = (fname, line + 1, text, rep)
        if vvp is None:
            res[mid] = ('COMPILE-ERROR', 0, 0, info)
        else:
            jobs.append((mid, vvp, info))
    running = []
    t0 = time.time()
    while jobs or running:
        while jobs and len(running) < a.jobs:
            mid, vvp, info = jobs.pop(0)
            lf = open(os.path.join(WORK, mid, 'run.log'), 'w', encoding='utf-8')
            p = subprocess.Popen(['vvp', vvp, '+SEED=1', '+N=%d' % a.n], cwd=os.path.join(WORK, mid, 'rtl'), stdout=lf,
                                 stderr=subprocess.STDOUT)
            running.append((mid, p, lf, info, time.time()))
        time.sleep(1)
        for it in list(running):
            mid, p, lf, info, ts = it
            done = p.poll() is not None
            to = (not done) and time.time() - ts > 400
            if to:
                p.kill()
            if done or to:
                lf.close()
                running.remove(it)
                text = open(os.path.join(WORK, mid, 'run.log'), encoding='utf-8', errors='replace').read()
                nf = sum(1 for l in text.splitlines() if l.startswith('CHECK FAIL'))
                na = sum(1 for l in text.splitlines() if l.startswith('ASSERT FAIL'))
                fin = 'RESULT:' in text
                caught = nf > 0 or na > 0 or not fin
                res[mid] = ('CAUGHT' if caught else 'SURVIVED', nf, na, info)
                print('%s %s %s:%d %s -> %s (%d checks, %d assertions)' % (mid, res[mid][0], info[0], info[1], info[2][:60], info[3], nf, na),
                      flush=True)
    ids = sorted(res)
    caught = sum(1 for i in ids if res[i][0] == 'CAUGHT')
    surv = [i for i in ids if res[i][0] == 'SURVIVED']
    if sel:
        print('rerun of', ' '.join(sel), ':', 'caught' if not surv else 'survived ' + ' '.join(surv))
        return 0
    with open(REPORT, 'w', encoding='utf-8') as f:
        f.write('# Automatic mutation run\n\nOperator flips at %d places of the control block and the buffer sampled by seed %d '
                '(%d random operations per run, synthesis branch, %s).\n\n' % (len(ids), a.seed, a.n, 'asynchronous CSR' if CSR_ASYNC else 'one clock, CSR_ASYNC=0'))
        f.write('Caught %d, survived %d, compile errors %d. A survivor is either an equivalent mutant (no change of behavior) or a hole of the tests; '
                'each survivor is analysed in TEST_REVIEW.md.\n\n' % (caught, len(surv), sum(1 for i in ids if res[i][0] == 'COMPILE-ERROR')))
        f.write('| ID | Result | File:line | Code | Flip | Failed checks | Assertion failures |\n|---|---|---|---|---|---:|---:|\n')
        for i in ids:
            r = res[i]
            f.write('| %s | %s | %s:%d | `%s` | `%s` | %d | %d |\n' % (i, r[0], r[3][0], r[3][1], r[3][2].replace('|', '/'), r[3][3].replace('|', '/') or 'remove', r[1], r[2]))
    print('caught %d of %d, survived %s, time %d s' % (caught, len(ids), ' '.join(surv), time.time() - t0))
    return 0


if __name__ == '__main__':
    sys.exit(main())
