"""Regression of the phase 1 testbench (CSR, control block, buffer) of the digital signature IP.

Builds the testbench with Icarus Verilog in the configurations below and runs them in parallel; the
logs go to verification/sim/regress/ with the branch and the seed in the name (R-093):

  syn_async1            synthesis branch (VLSIT_SYNTHESIS), asynchronous CSR clocks
  sim_async1_seed<n>    simulation branch with the metastability model, seeds 1 to 3
  syn_async0            synthesis branch, CSR register clock equal to the APB clock

Usage: python run_regress.py [--n N] [--seeds 1,2,3] [--only K] [--jobs J]
Needs iverilog and vvp (OSS CAD Suite, see the PATH note in the README). Not part of the RTL.
"""
import argparse
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))          # verification/env/dsig_p1
VER = os.path.dirname(os.path.dirname(HERE))               # verification
IP = os.path.dirname(VER)
RTL = os.path.join(IP, 'rtl')
MODELS = os.path.join(VER, 'models', 'dsig_p1')
TESTS = os.path.join(VER, 'tests', 'dsig_p1')
LOGS = os.path.join(VER, 'sim', 'regress')
BUILD = os.path.join(VER, 'sim', 'build')

SRC = [os.path.join(HERE, 'dsig_p1_wrap.sv'), os.path.join(HERE, 'dsig_apb_assert.sv'),
       os.path.join(HERE, 'dsig_p1_assert.sv'), os.path.join(HERE, 'dsig_wf_probe.sv'),
       os.path.join(TESTS, 'tb_dsig_p1.sv')]
INCS = [HERE, MODELS, TESTS]


def build(name, defines, rtl_dir=RTL):
    out = os.path.join(BUILD, name + '.vvp')
    cmd = ['iverilog', '-g2012', '-s', 'tb_dsig_p1', '-o', out]
    for inc in INCS:
        cmd += ['-I', inc]
    cmd += ['-D' + d for d in defines]
    cmd += ['-f', os.path.join(rtl_dir, 'filelist.f')]
    cmd += SRC
    r = subprocess.run(cmd, cwd=rtl_dir, capture_output=True, text=True)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if 'error' in l.lower()]
    if r.returncode != 0 or errs:
        print('BUILD FAILED', name)
        print('\n'.join(errs[:20]))
        sys.exit(2)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--n', type=int, default=200, help='random operations per run')
    ap.add_argument('--seeds', default='1,2,3')
    ap.add_argument('--only', type=int, default=0, help='run only the test with this number')
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--rtl', default=RTL, help='folder with rtl/filelist.f (a mutated copy for the mutation run)')
    ap.add_argument('--tag', default='', help='prefix of the log names')
    ap.add_argument('--logs', default=LOGS)
    a = ap.parse_args()
    os.makedirs(a.logs, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)
    seeds = [int(s) for s in a.seeds.split(',') if s]
    runs = []
    syn1 = build(a.tag + 'syn_async1', ['VLSIT_SYNTHESIS', 'CSR_ASYNC=1'], a.rtl)
    runs.append((a.tag + 'syn_async1', syn1, ['+SEED=1', '+N=%d' % a.n]))
    sim1 = build(a.tag + 'sim_async1', ['CSR_ASYNC=1'], a.rtl)
    for s in seeds:
        runs.append(('%ssim_async1_seed%d' % (a.tag, s), sim1,
                     ['+SEED=%d' % (10 + s), '+N=%d' % a.n, '+AFIFO_MSYNC_SEED=%d' % s]))
    syn0 = build(a.tag + 'syn_async0', ['VLSIT_SYNTHESIS', 'CSR_ASYNC=0'], a.rtl)
    runs.append((a.tag + 'syn_async0', syn0, ['+SEED=5', '+N=%d' % a.n]))
    if a.only:
        runs = [(n, v, args + ['+ONLY=%d' % a.only]) for n, v, args in runs]
    pending = list(runs)
    active = []
    results = {}
    t0 = time.time()
    while pending or active:
        while pending and len(active) < a.jobs:
            name, vvp, args = pending.pop(0)
            log = open(os.path.join(a.logs, name + '.log'), 'w', encoding='utf-8')
            p = subprocess.Popen(['vvp', vvp] + args, cwd=rtl_dir_of(a.rtl), stdout=log, stderr=subprocess.STDOUT)
            active.append((name, p, log))
        time.sleep(1.0)
        for item in list(active):
            name, p, log = item
            if p.poll() is not None:
                log.close()
                active.remove(item)
                text = open(os.path.join(a.logs, name + '.log'), encoding='utf-8', errors='replace').read()
                ok = 'RESULT: PASS' in text
                summ = [l for l in text.splitlines() if l.startswith('SUMMARY') or l.startswith('assertion failures')]
                results[name] = (ok, summ)
                print('%-24s %s  %s' % (name, 'PASS' if ok else 'FAIL', ' | '.join(summ)))
    print('time %d s' % (time.time() - t0))
    return 0 if all(v[0] for v in results.values()) else 1


def rtl_dir_of(p):
    return p


if __name__ == '__main__':
    sys.exit(main())
