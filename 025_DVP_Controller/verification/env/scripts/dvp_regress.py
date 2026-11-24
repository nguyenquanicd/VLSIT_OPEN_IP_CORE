#!/usr/bin/env python3
"""dvp_regress.py - the single retained verification driver of 025_DVP_Controller (AI-generated candidate, R-117).

One command runs the whole retained flow with Verilator on Windows (standard library only):
  1. checker qualification with synthetic traffic (env/tb/tb_qual_checker.sv)
  2. parameter legality (elaboration of legal and illegal compile-time parameters)
  3. static scope review of the top-level interface
  4. the regression matrix (tests/regression/testlist.yaml tests x configurations x seeds) on env/tb/tb_dvp_controller.sv
Builds go to a temporary directory outside the repository; every retained output is written flat into the output
directory (default verification/sim/final): one log per case, summary.json/csv, commands.json, resource_usage.json,
coverage_bins.json and manifest.sha256. The output directory must not exist yet, so a result set is never overwritten.

Usage:  python dvp_regress.py [--out DIR] [--only CONFIG ...] [--skip-qual]
"""
import argparse, csv, ctypes, hashlib, json, os, re, shutil, subprocess, sys, tempfile, threading, time
from ctypes import wintypes

HERE = os.path.dirname(os.path.abspath(__file__))
VER = os.path.dirname(os.path.dirname(HERE))        # .../025_DVP_Controller/verification
IP = os.path.dirname(VER)
RTL = os.path.join(IP, 'rtl')
ENVD = os.path.join(VER, 'env')
TOOLS = {
    'verilator': r'C:\Tools\oss-cad-suite\bin\verilator_bin.exe',
    'gxx_dir': r'C:\Users\PC\Tools\msys64\ucrt64\bin',
    'msys_usr': r'C:\Users\PC\Tools\msys64\usr\bin',
    'oss_bin': r'C:\Tools\oss-cad-suite\bin',
    'oss_lib': r'C:\Tools\oss-cad-suite\lib',
    'verilator_root': r'C:\Tools\oss-cad-suite\share\verilator',
}
ENV_KEYS = ('SystemRoot', 'TEMP', 'TMP', 'USERPROFILE', 'COMSPEC')
SRC_ENV = [os.path.join(ENVD, p) for p in ('bfm/dv_apb_requester.sv', 'bfm/dv_dvp_source.sv', 'scoreboards/dv_dvp_checker.sv', 'tb/tb_dvp_controller.sv')]
SRC_QUAL = [os.path.join(ENVD, p) for p in ('scoreboards/dv_dvp_checker.sv', 'tb/tb_qual_checker.sv')]

BASE_TESTS = ['t_dvp_continuous_e2e', 't_dvp_gated_e2e', 't_dvp_apb_protocol', 't_dvp_timeout_boundary', 't_dvp_flush_handshake',
              't_dvp_overflow', 't_dvp_reset_recovery', 't_dvp_dma_rearm', 't_dvp_endpoint_errors', 't_dvp_frame_counter',
              't_dvp_mode_guard', 't_dvp_profiles', 't_dvp_flush_race']
PERF = 't_dvp_performance_characterization'
# name: (defines, directed tests, seeds, seeds of the constrained-random test or None for no random run)
CONFIGS = {
    'base':    (['P_W=8', 'P_EDGE=0', 'P_VS=1', 'P_HR=1', 'P_DEPTH=8'], BASE_TESTS, [1, 2, 3], [1, 2, 3, 4, 5]),
    'w10e1v0': (['P_W=10', 'P_EDGE=1', 'P_VS=0', 'P_HR=1', 'P_DEPTH=8'], ['t_dvp_profiles', 't_dvp_continuous_e2e', 't_dvp_gated_e2e', 't_dvp_overflow'], [1, 2], None),
    'w12h0':   (['P_W=12', 'P_EDGE=0', 'P_VS=1', 'P_HR=0', 'P_DEPTH=8'], ['t_dvp_profiles', 't_dvp_continuous_e2e', 't_dvp_gated_e2e', 't_dvp_overflow'], [1, 2], None),
    'e1v0h0':  (['P_W=8', 'P_EDGE=1', 'P_VS=0', 'P_HR=0', 'P_DEPTH=8'], ['t_dvp_profiles', 't_dvp_continuous_e2e', 't_dvp_gated_e2e', 't_dvp_frame_counter'], [1, 2], None),
    'd2':      (['P_W=8', 'P_EDGE=0', 'P_VS=1', 'P_HR=1', 'P_DEPTH=2'], ['t_dvp_overflow', 't_dvp_flush_handshake', 't_dvp_frame_counter', 't_dvp_timeout_boundary'], [1, 2], [1, 2]),
    'd4':      (['P_W=8', 'P_EDGE=0', 'P_VS=1', 'P_HR=1', 'P_DEPTH=4'], ['t_dvp_overflow', 't_dvp_flush_handshake', 't_dvp_mode_guard'], [1, 2], [1, 2]),
    'd16':     (['P_W=8', 'P_EDGE=0', 'P_VS=1', 'P_HR=1', 'P_DEPTH=16'], ['t_dvp_overflow', 't_dvp_flush_handshake', 't_dvp_dma_rearm', 't_dvp_continuous_e2e'], [1, 2], [1, 2]),
}
# t_dvp_parameter_legality: (parameter overrides, expected elaboration result)
LEGALITY = [
    ({'PARA_DVP_DATA_W': 8}, True), ({'PARA_DVP_DATA_W': 10}, True), ({'PARA_DVP_DATA_W': 12}, True), ({'PARA_DVP_DATA_W': 9}, False),
    ({'PARA_FIFO_DEPTH': 2}, True), ({'PARA_FIFO_DEPTH': 8}, True), ({'PARA_FIFO_DEPTH': 16}, True),
    ({'PARA_FIFO_DEPTH': 1}, False), ({'PARA_FIFO_DEPTH': 3}, False),
]
SCOPE_PORTS = {'i_clk_apb', 'i_rst_n_sys', 'i_clk_dvp', 'i_dvp_data', 'i_dvp_vsync', 'i_dvp_href', 'i_paddr', 'i_psel', 'i_penable', 'i_pwrite',
               'i_pwdata', 'i_pstrb', 'i_pprot', 'o_pready', 'o_prdata', 'o_pslverr', 'i_dma_ack', 'o_dma_req'}


def tool_env():
    env = {k: os.environ[k] for k in ENV_KEYS if k in os.environ}
    env['PATH'] = os.pathsep.join([TOOLS['gxx_dir'], TOOLS['msys_usr'], TOOLS['oss_bin'], TOOLS['oss_lib'], os.path.join(env.get('SystemRoot', r'C:\Windows'), 'System32')])
    env['VERILATOR_ROOT'] = TOOLS['verilator_root']
    return env


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


class PeakRam(threading.Thread):
    class PMC(ctypes.Structure):
        _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD), ('PeakWorkingSetSize', ctypes.c_size_t),
                    ('WorkingSetSize', ctypes.c_size_t), ('QuotaPeakPagedPoolUsage', ctypes.c_size_t), ('QuotaPagedPoolUsage', ctypes.c_size_t),
                    ('QuotaPeakNonPagedPoolUsage', ctypes.c_size_t), ('QuotaNonPagedPoolUsage', ctypes.c_size_t),
                    ('PagefileUsage', ctypes.c_size_t), ('PeakPagefileUsage', ctypes.c_size_t)]

    def __init__(self, pid):
        super().__init__(daemon=True)
        self.pid, self.peak, self.stop = pid, 0, False

    def run(self):
        k32, psapi = ctypes.windll.kernel32, ctypes.windll.psapi
        h = k32.OpenProcess(0x0400 | 0x0010, False, self.pid)
        if not h:
            return
        pmc = self.PMC(); pmc.cb = ctypes.sizeof(pmc)
        while not self.stop:
            if psapi.GetProcessMemoryInfo(h, ctypes.byref(pmc), pmc.cb):
                self.peak = max(self.peak, pmc.PeakWorkingSetSize)
            time.sleep(0.02)
        if psapi.GetProcessMemoryInfo(h, ctypes.byref(pmc), pmc.cb):
            self.peak = max(self.peak, pmc.PeakWorkingSetSize)
        k32.CloseHandle(h)


COMMANDS = []   # every launched command, with working directory, timeout, exit code, duration, peak RAM


def run(argv, cwd, log_path, timeout_s, label):
    t0 = time.time()
    with open(log_path, 'w', encoding='utf-8', errors='replace') as log:
        p = subprocess.Popen(argv, cwd=cwd, env=tool_env(), stdout=log, stderr=subprocess.STDOUT)
        meter = PeakRam(p.pid); meter.start()
        try:
            rc = p.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            p.kill(); rc = 124
        meter.stop = True; meter.join(1.0)
    COMMANDS.append({'label': label, 'argv': [a if not a.startswith(tempfile.gettempdir()) else '<tmp>' + a[len(tempfile.gettempdir()):] for a in argv],
                     'cwd': cwd if not cwd.startswith(tempfile.gettempdir()) else '<tmp>' + cwd[len(tempfile.gettempdir()):], 'timeout_s': timeout_s,
                     'exit_code': rc, 'seconds': round(time.time() - t0, 3), 'peak_ram_bytes': meter.peak})
    return rc, meter.peak


def vl_common(top, mdir):
    return [TOOLS['verilator'], '--binary', '--timing', '--x-initial-edge', '-Wno-fatal', '-Wno-lint', '-Wno-style', '--top-module', top,
            '-Mdir', mdir, '-CFLAGS', '-D_GLIBCXX_USE_CXX11_ABI=0']


def preflight(budget, out):
    free = shutil.disk_usage(out if os.path.exists(out) else os.path.dirname(out)).free
    need = budget['limits']['disk_stop_free_bytes'] + 600 * 1024 * 1024
    if free < need:
        sys.exit('PAUSE: free disk %d is below the stop threshold plus the working set %d (R-279)' % (free, need))
    return free


def parse_log(path):
    text = open(path, encoding='utf-8', errors='replace').read()
    res = re.findall(r'^DV_TEST name=\S+.*?result=(\S+)', text, re.M)
    return {'result': res[-1] if res else 'NO_RESULT', 'errors': len(re.findall(r'^DV_ERROR', text, re.M)),
            'tb_assume': len(re.findall(r'^DV_TB_ASSUME', text, re.M)),
            'checks': int(next(iter(re.findall(r'^DV_RESULT checks=(\d+)', text, re.M)), 0)),
            'cov': {m[0]: int(m[1]) for m in re.findall(r'^DV_COV (\S+) (\d+)', text, re.M)}}


def step_qualification(out, tmp, timeout_s):
    mdir = os.path.join(tmp, 'qual')
    rc, _ = run(vl_common('tb_qual_checker', mdir) + SRC_QUAL, ENVD, os.path.join(out, 'qualification_compile.log'), 600, 'qualification compile')
    if rc != 0:
        return {'status': 'BUILD_FAIL'}
    log = os.path.join(out, 'qualification.log')
    rc, _ = run([os.path.join(mdir, 'Vtb_qual_checker.exe')], tmp, log, timeout_s, 'qualification run')
    text = open(log, encoding='utf-8', errors='replace').read()
    cases = re.findall(r'^QUAL case=(\S+) expect=\s*(\S+) observed_errors=(\d+) result=(\S+)', text, re.M)
    bad = [c for c in cases if c[3] != 'OK']
    return {'status': 'PASS' if (rc == 0 and cases and not bad) else 'FAIL', 'cases': len(cases), 'unexpected': len(bad),
            'known_answer': len([c for c in cases if c[1] == 'PASS']), 'injected_faults': len([c for c in cases if c[1] == 'DETECT'])}


def step_legality(out, tmp):
    log = open(os.path.join(out, 'parameter_legality.log'), 'w', encoding='utf-8')
    rows = []
    for params, legal in LEGALITY:
        mdir = os.path.join(tmp, 'lint_' + '_'.join('%s%d' % kv for kv in params.items()))
        argv = [TOOLS['verilator'], '--lint-only', '-Wno-fatal', '-Wno-lint', '-Wno-style', '--top-module', 'm_dvp_controller', '-Mdir', mdir] + \
               ['-G%s=%d' % kv for kv in params.items()] + ['-f', 'filelist.f']
        lp = os.path.join(tmp, 'legality.tmp')
        rc, _ = run(argv, RTL, lp, 120, 'parameter legality ' + str(params))
        text = open(lp, encoding='utf-8', errors='replace').read()
        elaborated = (rc == 0) and ('USERERROR' not in text)   # an elaboration $error is reported as USERERROR (the build uses -Wno-fatal)
        ok = (elaborated == legal)
        rows.append({'params': params, 'expected_legal': legal, 'elaborated': elaborated, 'ok': ok})
        log.write('%s expected_%s elaborated=%s %s\n' % (params, 'legal' if legal else 'illegal', elaborated, 'OK' if ok else 'MISMATCH'))
        if not elaborated:
            log.write('  first error: %s\n' % next((l.strip() for l in text.splitlines() if 'Error' in l or 'error' in l or 'USERERROR' in l), '(none)'))
    log.close()
    bad = [r for r in rows if not r['ok']]
    return {'status': 'PASS' if not bad else 'FAIL', 'cases': len(rows), 'mismatches': len(bad)}


def step_scope(out):
    text = open(os.path.join(RTL, 'm_dvp_controller.sv'), encoding='utf-8').read()
    body = text[text.index(') (', text.index('module m_dvp_controller')):]
    body = body[:body.index(');')]
    ports = set(re.findall(r'\b((?:i|o)_[a-z0-9_]+)\s*(?:,|$|\n)', re.sub(r'//.*', '', body)))
    extra, missing = sorted(ports - SCOPE_PORTS), sorted(SCOPE_PORTS - ports)
    with open(os.path.join(out, 'scope_review.log'), 'w', encoding='utf-8') as f:
        f.write('top m_dvp_controller ports: %d\nextra (outside DVP capture + APB4 data endpoint + DMA REQ/ACK): %s\nmissing: %s\n' % (len(ports), extra, missing))
    return {'status': 'PASS' if not extra and not missing else 'FAIL', 'ports': len(ports), 'extra': extra, 'missing': missing}


def write_manifest(out):
    """SHA-256 of every source (env, tests, rtl) and every retained output of one result set."""
    lines = []
    for base in (ENVD, os.path.join(VER, 'tests'), RTL):
        for dp, _, fs in os.walk(base):
            for n in sorted(fs):
                p = os.path.join(dp, n)
                lines.append('%s  %s' % (sha256(p), os.path.relpath(p, IP).replace(os.sep, '/')))
    for n in sorted(os.listdir(out)):
        if n != 'manifest.sha256':
            lines.append('%s  %s' % (sha256(os.path.join(out, n)), 'verification/sim/' + os.path.basename(out) + '/' + n))
    open(os.path.join(out, 'manifest.sha256'), 'w', encoding='utf-8', newline=chr(10)).write(chr(10).join(lines) + chr(10))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--manifest-only', action='store_true', help='recompute manifest.sha256 of an existing output directory and exit')
    ap.add_argument('--out', default=os.path.join(VER, 'sim', 'final'))
    ap.add_argument('--only', nargs='*', default=[])
    ap.add_argument('--skip-qual', action='store_true')
    a = ap.parse_args()
    if a.manifest_only:
        write_manifest(a.out)
        print('manifest written', a.out)
        return 0
    budget = json.load(open(os.path.join(ENVD, 'config', 'resource_budget.json'), encoding='utf-8'))
    if os.path.exists(a.out):
        sys.exit('ERROR: output directory exists, a result set is never overwritten: %s' % a.out)
    os.makedirs(a.out)
    free0 = preflight(budget, a.out)
    tmp = tempfile.mkdtemp(prefix='dvp_regress_')
    summary, steps = [], {}
    peak_all = 0
    try:
        for label, argv in (('version verilator', [TOOLS['verilator'], '--version']), ('version python', [sys.executable, '--version']),
                            ('version g++', [os.path.join(TOOLS['gxx_dir'], 'g++.exe'), '--version'])):
            run(argv, VER, os.path.join(tmp, 'v.txt'), 60, label)
            COMMANDS[-1]['version_output'] = open(os.path.join(tmp, 'v.txt'), encoding='utf-8', errors='replace').read().strip().splitlines()[0]
        if not a.skip_qual:
            steps['checker_qualification'] = step_qualification(a.out, tmp, 600)
            print('qualification', steps['checker_qualification'], flush=True)
        steps['parameter_legality'] = step_legality(a.out, tmp)
        print('legality', steps['parameter_legality'], flush=True)
        steps['scope_review'] = step_scope(a.out)
        print('scope', steps['scope_review'], flush=True)
        cov = {}
        for name, (defines, tests, seeds, pseeds) in CONFIGS.items():
            if a.only and name not in a.only:
                continue
            free = preflight(budget, a.out)
            mdir = os.path.join(tmp, 'b_' + name)
            argv = vl_common('tb_dvp_controller', mdir) + ['-G' + d for d in defines] + ['-f', 'filelist.f'] + SRC_ENV
            rc, _ = run(argv, RTL, os.path.join(a.out, name + '__build.log'), 900, 'build ' + name)
            if rc != 0:
                summary.append({'config': name, 'case': 'BUILD', 'result': 'BUILD_FAIL'})
                print(name, 'BUILD_FAIL', flush=True)
                continue
            exe = os.path.join(mdir, 'Vtb_dvp_controller.exe')
            cases = [(t, s, []) for t in tests for s in seeds]
            if pseeds:
                cases += [(PERF, s, ['+MODE=%d' % m]) for s in pseeds for m in (0, 1)]
            for t, s, extra in cases:
                tag = ('_m%s' % extra[0].split('=')[1]) if extra else ''
                case = '%s%s_s%d' % (t, tag, s)
                plus = ['+AFIFO_MSYNC_SEED=%d' % s, '+AFIFO_MSYNC_EN=1', '+RSTSYNC_MSYNC_SEED=%d' % s, '+RSTSYNC_MSYNC_EN=1'] + extra
                logp = os.path.join(a.out, '%s__%s.log' % (name, case))
                cwd = os.path.join(tmp, 'cwd'); os.makedirs(cwd, exist_ok=True)
                rc, peak = run([exe, '+TEST=' + t, '+SEED=%d' % s, '+TIMEOUT_NS=2000000'] + plus, cwd, logp, 300, 'case %s %s' % (name, case))
                peak_all = max(peak_all, peak)
                r = parse_log(logp)
                for k, v in r['cov'].items():
                    cov[k] = cov.get(k, 0) + v
                rec = {'config': name, 'defines': defines, 'case': case, 'test': t, 'seed': s, 'plusargs': plus, 'result': r['result'], 'errors': r['errors'],
                       'tb_assume': r['tb_assume'], 'checks': r['checks'], 'exit_code': rc, 'peak_ram_bytes': peak}
                summary.append(rec)
                print('  %-8s %-48s %-6s errors=%d checks=%d' % (name, case, r['result'], r['errors'], r['checks']), flush=True)
        json.dump(cov, open(os.path.join(a.out, 'coverage_bins.json'), 'w', encoding='utf-8'), indent=1, sort_keys=True)
    finally:
        free1 = shutil.disk_usage(a.out).free
        passed = [r for r in summary if r['result'] == 'PASS']
        with open(os.path.join(a.out, 'summary.json'), 'w', encoding='utf-8') as f:
            json.dump({'steps': steps, 'cases': summary, 'totals': {'cases': len(summary), 'pass': len(passed), 'not_pass': len(summary) - len(passed)}}, f, indent=1)
        with open(os.path.join(a.out, 'summary.csv'), 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f); w.writerow(['config', 'case', 'result', 'errors', 'checks', 'tb_assume', 'seed'])
            for r in summary:
                w.writerow([r['config'], r['case'], r['result'], r.get('errors'), r.get('checks'), r.get('tb_assume'), r.get('seed')])
        with open(os.path.join(a.out, 'commands.json'), 'w', encoding='utf-8') as f:
            json.dump(COMMANDS, f, indent=1)
        peak = max([c.get('peak_ram_bytes', 0) for c in COMMANDS] or [0])
        with open(os.path.join(a.out, 'resource_usage.json'), 'w', encoding='utf-8') as f:
            json.dump({'budget': 'env/config/resource_budget.json', 'simulation_jobs': 1,
                       'peak_ram_bytes_any_process': peak, 'ram_budget_bytes': budget['limits']['simulation_ram_budget_bytes'], 'ram_within_budget': peak <= budget['limits']['simulation_ram_budget_bytes'],
                       'disk_free_before_bytes': free0, 'disk_free_after_bytes': free1, 'disk_stop_free_bytes': budget['limits']['disk_stop_free_bytes'],
                       'retained_output_bytes': sum(os.path.getsize(os.path.join(a.out, n)) for n in os.listdir(a.out)),
                       'waveforms': 'none captured', 'build_directory': 'temporary, outside the repository, discarded after the run'}, f, indent=1)
        shutil.rmtree(tmp, ignore_errors=True)
        lines = []
        for base in (os.path.join(ENVD), os.path.join(VER, 'tests'), RTL):
            for dp, _, fs in os.walk(base):
                for n in sorted(fs):
                    p = os.path.join(dp, n)
                    lines.append('%s  %s' % (sha256(p), os.path.relpath(p, IP).replace(os.sep, '/')))
        for n in sorted(os.listdir(a.out)):
            if n != 'manifest.sha256':
                lines.append('%s  %s' % (sha256(os.path.join(a.out, n)), 'verification/sim/' + os.path.basename(a.out) + '/' + n))
        open(os.path.join(a.out, 'manifest.sha256'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    print('REGRESS cases', len(summary), 'pass', len(passed), 'not_pass', len(summary) - len(passed), 'steps', {k: v['status'] for k, v in steps.items()})
    return 0 if (len(summary) == len(passed) and all(v['status'] == 'PASS' for v in steps.values())) else 1


if __name__ == '__main__':
    sys.exit(main())
