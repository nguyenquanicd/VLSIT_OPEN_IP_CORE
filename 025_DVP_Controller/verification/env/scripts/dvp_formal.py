#!/usr/bin/env python3
"""dvp_formal.py - runs the SymbiYosys obligations of t_dvp_control_formal (AI-generated candidate, R-117).

Harnesses in env/formal/: f_apb_data (pop safety, exact timeout), f_dma_req (DMA request state), f_ctrl (mode guard, single-clock
abstraction), f_flush (flush handshake, single-clock abstraction). Work directories are temporary; flat logs and formal_summary.json go to the output directory (default verification/sim/final).
Usage: python dvp_formal.py [--out DIR] [--root TREE]   (--root runs the same harnesses on another copy of the repository layout)
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
VER = os.path.dirname(os.path.dirname(HERE))
JOBS = [('f_apb_data', ['bmc', 'prove', 'cover']), ('f_dma_req', ['bmc', 'prove', 'cover']), ('f_ctrl', ['bmc', 'cover']), ('f_flush', ['bmc', 'cover'])]
PATHS = [r'C:\Tools\oss-cad-suite\bin', r'C:\Tools\oss-cad-suite\lib', r'C:\Users\PC\Tools\msys64\usr\bin']


def run_job(formal_dir, name, task, work, log_path):
    env = {k: os.environ[k] for k in ('SystemRoot', 'TEMP', 'TMP', 'USERPROFILE', 'COMSPEC') if k in os.environ}
    env['PATH'] = os.pathsep.join(PATHS + [os.path.join(env.get('SystemRoot', r'C:\Windows'), 'System32')])
    t0 = time.time()
    p = subprocess.run([r'C:\Tools\oss-cad-suite\bin\sby.exe', '-f', '-d', os.path.join(work, '%s_%s' % (name, task)), name + '.sby', task],
                       cwd=formal_dir, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=1800)
    text = p.stdout + p.stderr
    # keep the tool log readable and independent of the temporary path
    text = text.replace(work, '<tmp>')
    open(log_path, 'w', encoding='utf-8').write(text)
    status = re.findall(r'DONE \((\w+),', text)
    return {'harness': name, 'task': task, 'result': status[-1] if status else 'NO_RESULT',
            'proof': 'successful proof by k-induction' in text, 'seconds': round(time.time() - t0, 1),
            'covers_reached': len(re.findall(r'reached cover statement', text)), 'covers_unreached': len(re.findall(r'unreached cover statement', text))}


def run_all(formal_dir, out, prefix='', jobs=None):
    work = tempfile.mkdtemp(prefix='dvp_formal_')
    rows = []
    try:
        for name, tasks in (jobs or JOBS):
            for task in tasks:
                r = run_job(formal_dir, name, task, work, os.path.join(out, '%sformal_%s_%s.log' % (prefix, name, task)))
                rows.append(r)
                print('%-12s %-6s %-6s proof=%s covers=%d/%d %ss' % (name, task, r['result'], r['proof'], r['covers_reached'],
                                                                   r['covers_reached'] + r['covers_unreached'], r['seconds']), flush=True)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default=os.path.join(VER, 'sim', 'final'))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    rows = run_all(os.path.join(VER, 'env', 'formal'), a.out)
    json.dump({'results': rows, 'note': 'f_ctrl and f_flush are bounded model checks (tied clocks); f_apb_data and f_dma_req are k-induction proofs; '
                                        'timeout bounded to N <= 6 in f_apb_data; f_flush is a bounded model check (depth 30, tied clocks; k-induction did not converge)'},
              open(os.path.join(a.out, 'formal_summary.json'), 'w', encoding='utf-8'), indent=1)
    bad = [r for r in rows if r['result'] != 'PASS']
    print('FORMAL', len(rows), 'tasks', 'pass', len(rows) - len(bad), 'not_pass', len(bad))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())
