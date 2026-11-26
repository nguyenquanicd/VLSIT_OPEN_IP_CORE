"""Formal proof of the hash arbiter m_vlsit_dsig_harb with SymbiYosys (verification/formal/harb.sby, properties in
harb_props.sv: one owner, grant only to a requester, the owner keeps the grant, fixed-priority hand-over, stream isolation),
then the same properties on a mutant that re-arbitrates every cycle (formal/mut): the proof must PASS and the mutant must
FAIL. Usage: python run_formal.py"""
import os
import subprocess
import sys

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).replace(chr(92), '/')
F = V + '/formal'
R = os.path.normpath(V + '/../rtl').replace(chr(92), '/')


def sby(name):
    env = dict(os.environ)
    env['PATH'] = 'C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib;' + env.get('PATH', '')
    r = subprocess.run(['C:/Tools/oss-cad-suite/bin/sby.exe', '-f', name + '.sby'], cwd=F, env=env, capture_output=True, text=True,
                       timeout=1800)
    open(F + '/%s_run.txt' % name, 'w').write(r.stdout + r.stderr)
    return r.stdout


def main():
    # the mutant: the grant register is loaded every cycle (the owner can lose the grant while it still requests)
    src = open(R + '/m_vlsit_dsig_harb.sv', encoding='utf-8').read()
    assert src.count('    else if (!w_owner_req)\n') + src.count('    else if (!w_owner_req)\r\n') == 1
    os.makedirs(F + '/mut', exist_ok=True)
    open(F + '/mut/m_vlsit_dsig_harb.sv', 'w', encoding='utf-8').write(
        src.replace('    else if (!w_owner_req)\r\n', '    else\r\n').replace('    else if (!w_owner_req)\n', '    else\n'))
    proof = sby('harb')
    mut = sby('harb_mut')
    ok_p = 'DONE (PASS' in proof and 'successful proof by k-induction' in proof
    ok_m = 'returned FAIL' in mut
    print('harb proof: %s; mutant: %s' % ('PASS (k-induction)' if ok_p else 'NOT PROVEN', 'FAIL as required' if ok_m else 'NOT CAUGHT'))
    print('RESULT: %s' % ('PASS' if ok_p and ok_m else 'FAIL'))
    return 0 if ok_p and ok_m else 1


if __name__ == '__main__':
    sys.exit(main())
