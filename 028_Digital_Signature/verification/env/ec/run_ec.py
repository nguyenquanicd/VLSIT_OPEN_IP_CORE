"""Build tb_ec with Verilator (OSS CAD Suite on Windows) and run the vector sets of the EC engine test.
Usage: python run_ec.py [set ...]   (sets: quick ed25519 ed448 edvar p256 p384 p521 k256; default: all but quick)
The sets run in parallel processes; a log per set is kept in verification/sim/ec."""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
IP = os.path.normpath(os.path.join(HERE, '..', '..', '..')).replace(chr(92), '/')
TAG = os.environ.get('EC_TAG', 'ec')
SIM = IP + '/verification/sim/' + TAG
HASH = os.path.normpath(os.path.join(IP, '..', '019_SHA2_SHA3_Hash', 'rtl')).replace(chr(92), '/')
VBIN = 'C:/Tools/oss-cad-suite/bin/verilator_bin.exe'
GXX = 'C:/Users/PC/Tools/msys64/ucrt64/bin'
RTL = ['m_vlsit_sha_core256', 'm_vlsit_sha_core512', 'm_vlsit_sha_keccak', 'm_vlsit_sha_pad']


def env_for(bdir):
    os.makedirs(bdir + '/tmp', exist_ok=True)
    os.makedirs(bdir + '/shim', exist_ok=True)
    with open(bdir + '/shim/python3', 'w', newline=chr(10)) as fh:
        fh.write('#!/bin/bash' + chr(10) + 'exec "%s" "$@"' % sys.executable.replace(chr(92), '/') + chr(10))
    env = dict(os.environ)
    env.update(TMP=bdir + '/tmp', TEMP=bdir + '/tmp', TMPDIR=bdir + '/tmp', VERILATOR_ROOT='C:/Tools/oss-cad-suite/share/verilator')
    env['PATH'] = os.pathsep.join([bdir + '/shim', GXX, 'C:/Tools/oss-cad-suite/bin', 'C:/Users/PC/Tools/msys64/usr/bin', env['PATH']])
    return env


def build(trace=False):
    os.makedirs(SIM, exist_ok=True)
    exe = SIM + '/obj/Vtb_ec.exe'
    files = [HASH + '/%s.sv' % m for m in RTL]
    files += [IP + '/rtl/' + f for f in ['m_vlsit_sha_eng.sv', 'm_vlsit_dsig_hseq.sv', 'm_vlsit_dsig_harb.sv', 'm_vlsit_dsig_hfeed.sv',
                                         'm_vlsit_dsig_brd.sv', 'm_vlsit_dsig_bwr.sv', 'm_vlsit_dsig_ec_rom.sv', 'm_vlsit_dsig_ec.sv']]
    files.append(IP + '/verification/tests/ec/tb_ec.sv')
    cmd = [VBIN, '--binary', '--timing', '-O2', '-Wno-fatal', '-Wno-lint', '-Wno-style', '--top-module', 'tb_ec', '--x-assign', '0', '--x-initial', '0']
    if trace:
        cmd.append('--trace')
    cmd += ['-Mdir', SIM + '/obj', '-j', '4', '-CFLAGS', '-O2 -std=gnu++17', '-LDFLAGS', '-static-libstdc++ -static-libgcc', '-o', 'Vtb_ec'] + files
    r = subprocess.run(cmd, capture_output=True, text=True, env=env_for(SIM))
    open(SIM + '/build.log', 'w').write(r.stdout + r.stderr)
    if not os.path.exists(exe):
        print('COMPILE FAIL')
        print((r.stdout + r.stderr)[-4000:])
        return None
    return exe


def main(argv):
    sets = argv or ['ed25519', 'ed448', 'edvar', 'p256', 'p384', 'p521', 'k256']
    exe = build()
    if not exe:
        return 2
    procs = []
    for s in sets:
        hexf, man = SIM + '/%s.hex' % s, SIM + '/%s.txt' % s
        subprocess.run([sys.executable, IP + '/verification/models/ec/gen_ec_vec.py', s, hexf, man], check=True)
        n = len(open(man).read().splitlines())
        log = open(SIM + '/%s.log' % s, 'w')
        p = subprocess.Popen([exe, '+VEC=' + hexf, '+NVEC=%d' % n], stdout=log, stderr=subprocess.STDOUT, env=env_for(SIM), cwd=SIM)
        procs.append((s, n, p, log, time.time()))
    rc = 0
    for s, n, p, log, t0 in procs:
        p.wait()
        log.close()
        out = open(SIM + '/%s.log' % s).read()
        names = dict(l.rstrip('\n').split('\t', 1) for l in open(SIM + '/%s.txt' % s))
        res = re.findall(r'VEC (\d+) (PASS|FAIL) cycles=(\d+)', out)
        fails = [(i, names[i]) for i, r, c in res if r == 'FAIL']
        tot = sum(int(c) for _, _, c in res)
        ok = 'RESULT: PASS' in out and len(res) == n
        print('%-8s %s  %d/%d vectors, %d cycles, %.0f s' % (s, 'PASS' if ok else 'FAIL', len(res) - len(fails), n, tot, time.time() - t0))
        for i, nm in fails:
            print('    FAIL %s %s' % (i, nm))
        if not ok:
            rc = 1
            print('\n'.join(l for l in out.splitlines() if 'VEC' in l and 'PASS' not in l)[:1500])
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
