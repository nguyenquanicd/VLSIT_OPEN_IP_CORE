"""Builds tb_hbs once (through run_unit.py) and runs the vector sets of the hash-based engine in parallel processes.
Usage: python run_hbs.py [set ...]   (sets: quick slh lms xmss; default: slh lms xmss)"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
IP = os.path.normpath(os.path.join(HERE, '..', '..', '..')).replace(chr(92), '/')
SIM = IP + '/verification/sim/hbs' + os.environ.get('UNIT_TAG', '')
sys.path.insert(0, IP + '/verification/env/misc')
import run_unit as U


def main(argv):
    sets = argv or ['slh', 'lms', 'xmss']
    # the build (the run of zero vectors prints a message and finishes)
    U.main(['hbs', '+DIR=' + SIM, '+NVEC=0'])
    exe = SIM + '/obj/Vtb_hbs.exe'
    procs = []
    for s in sets:
        d = IP + '/verification/sim/hbs_' + s
        subprocess.run([sys.executable, IP + '/verification/models/hbs/gen_hbs_vec.py', d, s], check=True)
        n = len(open(d + '/hbs_vecs.txt').read().splitlines())
        log = open(d + '/run.log', 'w')
        p = subprocess.Popen([exe, '+DIR=' + d, '+NVEC=%d' % n], stdout=log, stderr=subprocess.STDOUT, env=U.env_for(SIM), cwd=SIM)
        procs.append((s, n, p, log, d, time.time()))
    rc = 0
    for s, n, p, log, d, t0 in procs:
        p.wait()
        log.close()
        out = open(d + '/run.log').read()
        names = dict(l.rstrip('\n').split('\t', 1) for l in open(d + '/hbs_names.txt'))
        res = re.findall(r'VEC (\d+) (PASS|FAIL) cycles=(\d+)', out)
        fails = [(i, names[i]) for i, r, c in res if r == 'FAIL']
        tot = sum(int(c) for _, _, c in res)
        ok = 'RESULT: PASS' in out and len(res) == n
        print('%-6s %s  %d/%d vectors, %d cycles, %.0f s' % (s, 'PASS' if ok else 'FAIL', len(res) - len(fails), n, tot, time.time() - t0))
        for i, nm in fails:
            print('    FAIL %s %s' % (i, nm))
        if not ok:
            rc = 1
            print('\n'.join(l for l in out.splitlines() if 'VEC' in l and 'PASS' not in l)[:1500])
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
