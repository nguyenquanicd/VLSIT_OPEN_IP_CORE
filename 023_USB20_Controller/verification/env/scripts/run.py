"""Project runner: every execution gets a fresh run folder verification/sim/r<NNNN>_<name>/ with its inputs (files in__*),
commands, tool versions, raw logs, results and resource use (R-112, R-272..R-280). Nothing is deleted or reused. A run
folder has no subfolder (the package keeps at most two directory levels below verification/).

  python env/scripts/run.py formal <test> <legacy dir name> <file.sby> [task ...]   (harnesses in env/formal)
  python env/scripts/run.py sim    <test> <build name> <ops file> [+plusarg ...]    (see env/scripts/build.py)
  python env/scripts/run.py static <test> <script of env/scripts> [args ...]

Run from the verification folder. Exit code 0 when every task or the simulation passed, 1 otherwise.
"""
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

import vpaths as P

SIM = P.V
TOOLS = 'C:/Users/PC/Tools/msys64/ucrt64/bin;C:/Users/PC/Tools/msys64/usr/bin;C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib'
STOP_FREE = 2 * 1024 ** 3        # sim/env/resource_budget.json: disk_stop_free_bytes


TOOLS_FORMAL = 'C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib'


def env(formal=False):
    e = dict(os.environ)
    e['PATH'] = (TOOLS_FORMAL if formal else TOOLS) + ';' + e['PATH']
    e['VERILATOR_ROOT'] = 'C:/Tools/oss-cad-suite/share/verilator'
    return e


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def tree_size(d):
    return sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(d) for f in fs)


def version(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, env=env(), timeout=60).stdout.strip().split('\n')[0]
    except Exception as ex:                                             # tool missing: recorded, not hidden
        return 'not available: %s' % ex


def new_run(test):
    os.makedirs(P.SIMOUT, exist_ok=True)
    nums = [int(m.group(1)) for m in (re.match(r'r(\d+)_', n) for n in os.listdir(P.SIMOUT)) if m]
    if os.path.exists(P.INDEX):                                         # run numbers of the archived runs continue
        nums += [int(m.group(1)) for m in (re.match(r'r(\d+)_', ln) for ln in open(P.INDEX, encoding='utf-8')) if m]
    rid = 'r%04d_%s' % (max(nums + [0]) + 1, test[2:] if test.startswith('t_') else test)
    d = P.run_dir(rid)
    os.makedirs(d)
    return rid, d


def keep_input(d, path, name=None):
    """Copy of an input file into the run folder as in__<name> (no subfolder)."""
    shutil.copy(path, os.path.join(d, 'in__' + (name or os.path.basename(path))))


def admit():
    free = shutil.disk_usage(SIM).free
    if free < STOP_FREE:
        print('STOP: free disk %d below the stop threshold %d (R-279)' % (free, STOP_FREE))
        sys.exit(2)
    return free


def finish(rid, d, test, rec, free0, t0, wave):
    rec.update({'run_id': rid, 'test': test, 'date': datetime.datetime.now().isoformat(timespec='seconds'),
                'elapsed_s': round(time.time() - t0, 1), 'ai_generated_testbench': True,
                'environment': {'PATH prefix': TOOLS, 'VERILATOR_ROOT': 'C:/Tools/oss-cad-suite/share/verilator'}})
    json.dump(rec, open(os.path.join(d, 'run_record.json'), 'w'), indent=1)
    ru = {'schema_version': 1, 'run_id': rid, 'budget': 'env/resource_budget.json', 'simulation_jobs': 1,
          'ram': {'peak_bytes': rec.get('peak_rss_bytes'), 'measurement_method': rec.get('peak_method', ''),
                  'status': 'measured' if rec.get('peak_rss_bytes') else 'not_measured',
                  'reason': '' if rec.get('peak_rss_bytes') else 'no per-process peak measurement for this tool chain'},
          'disk': {'free_before_bytes': free0, 'free_after_bytes': shutil.disk_usage(SIM).free, 'expected_output_bytes': None,
                   'run_output_bytes': tree_size(d), 'measurement_method': 'python shutil.disk_usage and file sizes',
                   'status': 'measured', 'reason': ''},
          'waveform': wave,
          'compression': {'status': 'not_used', 'method': '', 'original_sha256': '', 'archive_sha256': '', 'round_trip_verified': False}}
    json.dump(ru, open(os.path.join(d, 'resource_usage.json'), 'w'), indent=1)
    with open(P.INDEX, 'a') as f:
        f.write('%s,%s,%s,%s\n' % (rid, test, rec['verdict'], rec['date']))
    print('%s %s %s' % (rid, test, rec['verdict']))
    for k, v in rec.get('results', {}).items():
        print('   %-14s %s' % (k, v))


def formal(test, sub, sby, tasks):
    free0, t0 = admit(), time.time()
    rid, d = new_run(test)
    src = P.FORMAL
    text = open(os.path.join(src, sby)).read()
    files = [sby] + [ln.strip() for ln in text.split('[files]')[1].split('\n') if ln.strip() and not ln.startswith('[')]
    hashes = {}
    for f in files:
        p = os.path.normpath(os.path.join(src, f))
        keep_input(d, p)
        hashes[P.rel(p)] = sha(p)
    if not tasks:
        tasks = [ln.split()[0] for ln in text.split('[tasks]')[1].split('[')[0].split('\n') if ln.strip()]
    results, cmds, traces = {}, [], []
    work = tempfile.mkdtemp(prefix='usb2_sby_')                      # the solver work tree is deep: it stays outside the package
    for t in tasks:
        cmd = ['C:/Tools/oss-cad-suite/bin/sby.exe', '-d', os.path.join(work, t), sby, t]
        cmds.append(' '.join(cmd))
        r = subprocess.run(cmd, cwd=src, capture_output=True, text=True, env=env(True))
        open(os.path.join(d, t + '.log'), 'w').write(r.stdout + r.stderr)
        m = re.search(r'DONE \((\w+)', r.stdout)
        st = m.group(1) if m else 'ERROR'
        fails = sorted(set(re.findall(r'failed assertion (\S+)', r.stdout)))
        covers = len(set(re.findall(r'Reached cover statement in step \d+ at [^:]+: (\S+)', r.stdout)))
        unreached = sorted(set(re.findall(r'Unreached cover statement at [^:]+: (\S+)', r.stdout)))
        results[t] = st + (' failed: ' + ' '.join(fails) if fails else '') + (' covers reached: %d' % covers if covers else '') + \
            (' UNREACHED: ' + ' '.join(unreached) if unreached else '')
        if fails or unreached:
            for root, _, fs in os.walk(os.path.join(work, t)):
                for fn in fs:
                    if fn.endswith(('.vcd', '.yw')):
                        dst = '%s__%s' % (t, fn)
                        shutil.copy(os.path.join(root, fn), os.path.join(d, dst))
                        traces.append(dst)
    ok = all(v.startswith('PASS') and 'UNREACHED' not in v for v in results.values())
    rec = {'kind': 'formal', 'working_directory': 'verification/env/formal (solver work tree in the temporary folder)', 'commands': cmds, 'input_sha256': hashes,
           'tools': {'sby': version(['C:/Tools/oss-cad-suite/bin/sby.exe', '--version']), 'yosys': version(['C:/Tools/oss-cad-suite/bin/yosys.exe', '-V']), 'z3': version(['C:/Tools/oss-cad-suite/bin/z3.exe', '--version'])},
           'seed': 'not applicable (formal)', 'timeout_s': 'none', 'results': results, 'verdict': 'PASS' if ok else 'FAIL'}
    wave = {'status': 'captured' if traces else 'not_captured',
            'reason': 'counterexample traces written by the solver' if traces else 'all tasks passed, no trace needed',
            'signal_scope': 'formal harness signals' if traces else 'none', 'time_window': 'counterexample length' if traces else 'none',
            'paths': traces}
    finish(rid, d, test, rec, free0, t0, wave)
    return 0 if ok else 1


def sim(test, build, ops, plus):
    free0, t0 = admit(), time.time()
    rid, d = new_run(test)
    bdir = P.build_dir(build)
    exe = [f for f in os.listdir(bdir) if f.endswith('.exe')][0]
    binfo = json.load(open(os.path.join(bdir, 'build_record.json')))
    hashes = dict(binfo['input_sha256'])
    opath = os.path.join(SIM, ops)
    keep_input(d, opath)
    hashes[ops.replace(chr(92), '/')] = sha(opath)
    keep_input(d, os.path.join(bdir, 'build_record.json'))
    cmd = [os.path.join(bdir, exe), '+ops=' + opath.replace('\\', '/'), '+out=' + d.replace('\\', '/')] + plus
    to = 3600
    try:
        r = subprocess.run(cmd, cwd=d, capture_output=True, text=True, env=env(), timeout=to)
        out, rc = r.stdout + r.stderr, r.returncode
    except subprocess.TimeoutExpired as ex:
        out, rc = (ex.stdout or b'').decode(errors='replace') + '\nTIMEOUT', 124
    open(os.path.join(d, 'sim.log'), 'w').write(out)
    m = re.search(r'RESULT (\w+) checks=(\d+) errors=(\d+)', out)
    ok = bool(m) and m.group(1) == 'PASS' and m.group(3) == '0' and rc == 0
    results = {'summary': m.group(0) if m else 'no RESULT line', 'exit_code': rc}
    for ln in re.findall(r'^(?:FAIL|ERROR).*$', out, re.M)[:20]:
        results.setdefault('failures', []).append(ln)
    rec = {'kind': 'simulation', 'working_directory': 'verification/sim/' + rid, 'commands': [' '.join(cmd)], 'input_sha256': hashes,
           'build': build, 'tools': {'verilator': binfo['tools']['verilator'], 'python': sys.version.split()[0]},
           'seed': next((p for p in plus if p.startswith('+seed=')), '+seed=1 (default)'), 'timeout_s': to,
           'results': results, 'verdict': 'PASS' if ok else 'FAIL'}
    wave = {'status': 'not_captured', 'reason': 'waveforms are captured only in a targeted rerun of a failure (R-278)',
            'signal_scope': 'none', 'time_window': 'none', 'paths': []}
    finish(rid, d, test, rec, free0, t0, wave)
    return 0 if ok else 1


def static(test, script, args):
    """A static structural check (a script of sim/scripts, exit 0 = pass): its output, the hashes of the RTL and SDC it reads."""
    free0, t0 = admit(), time.time()
    rid, d = new_run(test)
    sp = os.path.join(P.SCRIPTS, script)
    keep_input(d, sp)
    hashes = {P.rel(sp): sha(sp)}
    for sub in ('rtl', 'sdc'):
        for root, _, fs in os.walk(os.path.join(P.IP, sub)):
            for f in fs:
                if f.endswith(('.sv', '.v', '.sdc')):
                    p = os.path.join(root, f)
                    hashes[os.path.relpath(p, SIM).replace(chr(92), '/')] = sha(p)
    cmd = [sys.executable, sp] + args
    r = subprocess.run(cmd, cwd=SIM, capture_output=True, text=True)
    open(os.path.join(d, 'sim.log'), 'w').write(r.stdout + r.stderr)
    last = (r.stdout.strip().split(chr(10)) or [''])[-1]
    rec = {'kind': 'static', 'working_directory': 'verification', 'commands': [' '.join(cmd)], 'input_sha256': hashes,
           'tools': {'python': sys.version.split()[0]}, 'seed': 'not applicable (static)', 'timeout_s': 'none',
           'results': {'summary': last, 'exit_code': r.returncode}, 'verdict': 'PASS' if r.returncode == 0 else 'FAIL'}
    finish(rid, d, test, rec, free0, t0, {'status': 'not_captured', 'reason': 'static check', 'signal_scope': 'none',
                                         'time_window': 'none', 'paths': []})
    return r.returncode


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == 'formal':
        sys.exit(formal(a[1], a[2], a[3], a[4:]))
    if a and a[0] == 'static':
        sys.exit(static(a[1], a[2], a[3:]))
    if a and a[0] == 'sim':
        sys.exit(sim(a[1], a[2], a[3], a[4:]))
    print(__doc__)
    sys.exit(2)
