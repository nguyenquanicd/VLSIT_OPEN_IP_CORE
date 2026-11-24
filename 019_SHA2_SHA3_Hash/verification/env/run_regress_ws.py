"""Runs the regression of the SHA2/SHA3 IP from the reorganized folder layout.

The scripts in legacy_scripts expect the layout that existed before the reorganization
(<IP>/verification/{scripts,tb,vec,ref_nist,unit} next to <IP>/rtl and the sibling IP folders).
This runner builds that layout in a temporary workspace outside the IP tree by copying the files,
runs run_regress.py there, prints the result lines and, with --save, stores the logs as a tar
archive under verification/sim/. It changes nothing in the IP folder except that archive.
Not part of the RTL.

Usage: python run_regress_ws.py [--work DIR] [--save] [suite ...]      (no suite: main64)
Needs Verilator (OSS CAD Suite) and the msys64 g++ named in legacy_scripts/simlib.py.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tarfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
VER = os.path.dirname(HERE)
IP = os.path.dirname(VER)
ROOT = os.path.dirname(IP)


def build_workspace(work):
    ws_ip = os.path.join(work, os.path.basename(IP))
    for sub in ('000_Common/rtl_lib', '002_SyncFIFO/rtl'):
        dst = os.path.join(work, sub)
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(os.path.join(ROOT, sub), dst)
    shutil.rmtree(ws_ip, ignore_errors=True)
    shutil.copytree(os.path.join(IP, 'rtl'), os.path.join(ws_ip, 'rtl'))
    v = os.path.join(ws_ip, 'verification')
    for src, dst in (('env/legacy_scripts', 'scripts'), ('env/legacy_tb', 'tb'), ('env/legacy_vec', 'vec'),
                     ('models/legacy_ref_nist', 'ref_nist'), ('tests/legacy_unit', 'unit')):
        shutil.copytree(os.path.join(VER, src), os.path.join(v, dst))
    return os.path.join(v, 'scripts')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('suites', nargs='*', default=['main64'])
    ap.add_argument('--work', default=os.path.join(os.environ.get('TEMP', '.'), 'vlsit_019_ws'))
    ap.add_argument('--save', action='store_true', help='store the logs under verification/sim/')
    a = ap.parse_args()
    os.makedirs(a.work, exist_ok=True)
    scripts = build_workspace(a.work)
    env = dict(os.environ, PYTHONIOENCODING='utf-8')
    t0 = time.time()
    r = subprocess.run([sys.executable, 'run_regress.py'] + a.suites, cwd=scripts, env=env, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip().splitlines()
    print('\n'.join(out[-(len(a.suites) + 6):]))
    print('workspace: %s; time %d s; exit code %d' % (a.work, time.time() - t0, r.returncode))
    if a.save:
        logs = os.path.join(os.path.dirname(scripts), 'logs')
        if os.path.isdir(logs):
            name = os.path.join(VER, 'sim', 'regress_%s.tar' % time.strftime('%Y%m%d_%H%M%S'))
            with tarfile.open(name, 'w') as tf:
                tf.add(logs, arcname='logs')
            print('logs saved to', name)
    return r.returncode


if __name__ == '__main__':
    sys.exit(main())
