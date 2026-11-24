"""Regression runner (R-215): the one testlist is sim/verification/tests/testlist.csv.

  python env/scripts/regress.py [tier] [test ...]      tier: smoke | nightly | full (default full); rows of tier 'open' (known open items) run only when named

Columns of the testlist: test, kind (sim | formal), tier, build or formal dir, generator or sby file, seeds, extra.
For a simulation test the generator is run for each seed (it writes verification/tests/ops/<name>_s<seed>.ops) and the scenario is
executed with run.py; every execution gets its own run folder. Run from the sim folder. One job at a time (R-277).
"""
import csv
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402
SIM = P.V
TIERS = ['smoke', 'nightly', 'full']


def main():
    args = sys.argv[1:]
    tier = args[0] if args and args[0] in TIERS else 'full'
    only = [a for a in args if a not in TIERS]
    rows = [r for r in csv.DictReader(open(P.TESTLIST)) if r['test'] and not r['test'].startswith('#')]
    summary = []
    for r in rows:
        if only and r['test'] not in only:
            continue
        if r['tier'] == 'open':                            # known open item (listed in bugs.md): run only when named
            if not only:
                continue
        elif not only and TIERS.index(r['tier']) > TIERS.index(tier):
            continue
        if r['kind'] == 'static':
            p = subprocess.run([sys.executable, 'env/scripts/run.py', 'static', r['test'], r['source']] + r['extra'].split(), cwd=SIM, capture_output=True, text=True)
            line = p.stdout.strip().split(chr(10))[0] if p.stdout.strip() else 'no output'
            summary.append((r['test'], '-', line))
            print(line, flush=True)
            continue
        if r['kind'] == 'formal':
            p = subprocess.run([sys.executable, 'env/scripts/run.py', 'formal', r['test'], r['target'], r['source']] + r['extra'].split(), cwd=SIM, capture_output=True, text=True)
            line = p.stdout.strip().split('\n')[0] if p.stdout.strip() else 'no output'
            summary.append((r['test'], '-', line))
            print(line, flush=True)
            continue
        seeds = [int(x) for x in r['seeds'].split()] if tier != 'smoke' else [int(r['seeds'].split()[0])]
        for seed in seeds:
            if r['source'] == '-':                         # self-contained testbench: no scenario generator
                p = subprocess.run([sys.executable, 'env/scripts/run.py', 'sim', r['test'], r['target'], 'tests/ops/none.ops', '+seed=%d' % seed] + r['extra'].split(),
                                   cwd=SIM, capture_output=True, text=True)
                line = p.stdout.strip().split(chr(10))[0] if p.stdout.strip() else 'no output'
                summary.append((r['test'], seed, line))
                print(line, flush=True)
                continue
            src = r['source'].split(':')                 # generator[:argument ...]
            g = subprocess.run([sys.executable, src[0], str(seed)] + src[1:], cwd=P.TESTS, capture_output=True, text=True)
            if g.returncode != 0:
                summary.append((r['test'], seed, 'GENERATOR FAILED: ' + g.stderr.strip().split('\n')[-1]))
                print(summary[-1], flush=True)
                continue
            ops = 'tests/' + g.stdout.strip().split('\n')[-1]
            p = subprocess.run([sys.executable, 'env/scripts/run.py', 'sim', r['test'], r['target'], ops, '+seed=%d' % seed] + r['extra'].split(),
                               cwd=SIM, capture_output=True, text=True)
            line = p.stdout.strip().split('\n')[0] if p.stdout.strip() else 'no output'
            summary.append((r['test'], seed, line))
            print(line, flush=True)
    bad = [s for s in summary if not s[2].endswith('PASS')]
    print('REGRESSION %s: %d run(s), %d not passing' % (tier, len(summary), len(bad)))
    for b in bad:
        print('  NOT PASSING: %s seed %s: %s' % b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
