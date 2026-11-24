"""Builds one simulation executable with Verilator into verification/sim/build_<name>/ and records its inputs (R-267, R-274).

  python env/scripts/build.py <name> [--trace]               the build of env/env/builds.json with that name (--trace: build
                                                             <name>_trace that writes wave.vcd when run with +vcd)
  python env/scripts/build.py <name> <tb top> <filelist> [-GPARAM=value ...] [--extra FILE ...] [--exclude FILE ...] [--coverage]

Run from the verification folder. <filelist> is a path relative to the IP folder (rtl/filelist.f, the canonical list) or an
absolute path; its entries are relative to the folder of the filelist. --extra adds files (relative to the IP folder or absolute)
after the filelist, e.g. a BFM or a fault model; --exclude drops a file of the filelist (the RAM cell when the fault model replaces it). The testbench <tb top>.sv is taken from env/tb. An existing build folder is
replaced only with --rebuild (outputs are regenerable; the record of every run keeps the build record it used).
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402

TOOLS = 'C:/Users/PC/Tools/msys64/ucrt64/bin;C:/Users/PC/Tools/msys64/usr/bin;C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib'


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def ip_path(p):
    return os.path.normpath(p if os.path.isabs(p) else os.path.join(P.IP, p))


def read_filelist(fl):
    base = os.path.dirname(fl)
    out = []
    for ln in open(fl):
        ln = ln.strip()
        if ln and not ln.startswith(('//', '#', '+', '-')):
            out.append(os.path.normpath(os.path.join(base, ln)))
    return out


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 2
    rebuild = '--rebuild' in a
    trace = '--trace' in a                                              # waveform build: +vcd at run time writes wave.vcd
    a = [x for x in a if x not in ('--rebuild', '--trace')]
    if len(a) == 1:
        defs = {b['name']: b for b in json.load(open(P.BUILDS_JSON))}
        if a[0] not in defs:
            print('build %s is not in %s' % (a[0], P.rel(P.BUILDS_JSON)))
            return 2
        b = defs[a[0]]
        name, top, flist, extra, params = b['name'], b['top'], b['filelist'], b.get('extra', []), list(b['parameters'])
        exclude = b.get('exclude', [])
        if b.get('coverage'):
            params.append('--coverage')
    else:
        if len(a) < 3:
            print(__doc__)
            return 2
        name, top, flist = a[0], a[1], a[2]
        extra, params, exclude, k = [], [], [], 3
        while k < len(a):
            if a[k] == '--extra':
                extra.append(a[k + 1])
                k += 2
            elif a[k] == '--exclude':
                exclude.append(a[k + 1])
                k += 2
            else:
                params.append(a[k])
                k += 1
    bdir = P.build_dir(name + ('_trace' if trace else ''))
    if os.path.exists(bdir):
        if not rebuild:
            print('build %s exists; use --rebuild' % name)
            return 2
        shutil.rmtree(bdir)
    os.makedirs(bdir)
    fl = ip_path(flist)
    tbf = os.path.join(P.TB, top + '.sv')
    if not os.path.exists(tbf):
        print('testbench %s.sv not found in env/tb' % top)
        return 2
    drop = {ip_path(e) for e in exclude}                                   # e.g. the RAM cell replaced by the fault model
    srcs = [f for f in read_filelist(fl) if f not in drop] + [ip_path(e) for e in extra] + [tbf]
    missing = [s for s in srcs if not os.path.exists(s)]
    if missing:
        print('build %s: fail, missing source(s): %s' % (name, ', '.join(missing[:5])))
        return 1
    env = dict(os.environ)
    env['PATH'] = TOOLS + ';' + env['PATH']
    env['VERILATOR_ROOT'] = 'C:/Tools/oss-cad-suite/share/verilator'
    cmd = ['C:/Tools/oss-cad-suite/bin/verilator_bin.exe', '--binary', '--timing', '-Wno-fatal', '-Werror-USERERROR', '-Werror-USERFATAL', '-Wno-lint', '-Wno-style', '-j', '0',
           '--top-module', top, '--Mdir', bdir, '-MAKEFLAGS', 'PYTHON3=C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe',
           '-CFLAGS', '-D_GLIBCXX_USE_CXX11_ABI=0'] + ((['--trace', '-DVLSIT_TB_TRACE'] + ([] if os.environ.get('VLSIT_TRACE_FULL') else ['--trace-depth', '1'])) if trace else []) + params + [s.replace(chr(92), '/') for s in srcs]
    t0 = time.time()
    r = subprocess.run(cmd, cwd=P.RTL, capture_output=True, text=True, env=env)
    open(os.path.join(bdir, 'build.log'), 'w').write(r.stdout + r.stderr)
    exe = os.path.join(bdir, 'V%s.exe' % top)
    ok = r.returncode == 0 and os.path.exists(exe)
    ver = subprocess.run(['C:/Tools/oss-cad-suite/bin/verilator_bin.exe', '--version'], capture_output=True, text=True, env=env).stdout.strip()
    rec = {'build': os.path.basename(bdir)[6:], 'trace': trace, 'top': top, 'filelist': os.path.relpath(fl, P.IP).replace(chr(92), '/'),
           'extra': [os.path.relpath(ip_path(e), P.IP).replace(chr(92), '/') for e in extra],
           'exclude': [os.path.relpath(ip_path(e), P.IP).replace(chr(92), '/') for e in exclude],
           'parameters': [x for x in params if x != '--coverage'], 'coverage': '--coverage' in params,
           'command': ' '.join(cmd), 'working_directory': 'rtl', 'tools': {'verilator': ver}, 'result': 'pass' if ok else 'fail',
           'elapsed_s': round(time.time() - t0, 1),
           'input_sha256': {os.path.relpath(s, P.IP).replace(chr(92), '/'): sha(s) for s in srcs}}
    json.dump(rec, open(os.path.join(bdir, 'build_record.json'), 'w'), indent=1)
    for g in [f for f in os.listdir(bdir) if f.endswith('.gch')]:         # precompiled headers (about 300 MB each) are regenerable (R-279)
        os.remove(os.path.join(bdir, g))
    errs = [ln for ln in (r.stdout + r.stderr).split('\n') if ln.startswith('%Error')]
    print('build %s: %s (%.0f s)' % (name, rec['result'], rec['elapsed_s']))
    for e in errs[:15]:
        print('  ' + e[:200])
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
