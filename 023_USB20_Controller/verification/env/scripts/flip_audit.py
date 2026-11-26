"""Expectation-inversion audit of the scenarios (2026-11-27, review finding: false PASS and checkers that cannot fail).

For every simulation row of tests/usb20/testlist.csv (first seed) it runs the scenario twice under the same build:
  base   the unchanged scenario; the testbench prints CHKEXEC (line:count), the number of times each scenario line executed a check;
  flip   the same scenario with the expectation of every check operation inverted (a check that compares a value gets a different
         value, a window gets an impossible window, an expected error flag is toggled); watchdog times are multiplied by 4.
A check line is DETECTED when the flipped run reports FAIL at that line. It is
  NOT_RUN       the line never executed a check in the base run (the scenario ended earlier, or the check is guarded),
  UNDETECTED    the line ran in the base run but the inverted expectation did not fail (the comparison cannot fail: wrong mask,
                tautology, window wider than the data, guard that skips it),
  STATIC        flagged without a run: mask 0 (R, RS, P, XP, WP, RANY), P and WP that only wait (their timing is not inverted, a wait
                that is already satisfied passes at once), XN with fewer than 20 cycles, SOF count only (window 0..max).
The audit proves only that a check can fail; it does not prove that the expected value is right. A check that survives here and is
still wrong needs the engineer review.
    python env/scripts/flip_audit.py [--only test ...] [--skip-long]       (from the verification folder)
Output: sim/flip_audit.md, sim/flip_audit.csv, sim/flip_audit_detail.csv (one row per check line that is not DETECTED)."""
import csv
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402

LONG = ('gen_host_edge.py:imax', 'gen_host_edge.py:sof', 'gen_dir_timing_ts1', 'gen_timing')    # prefixes of scenarios that run for minutes
CHECK_OPS = {'R', 'RS', 'WS', 'RANY', 'P', 'XP', 'WP', 'XH', 'XD', 'XT', 'XC', 'XK', 'XS', 'XN', 'MC', 'GAP', 'GAPB', 'TC', 'SOF', 'SOFD',
             'SOFQ', 'SOFW', 'SOFR', 'NSOF', 'WSOF', 'LSR', 'XWAKE'}


def h(v):
    return '%x' % (v & 0xFFFFFFFFFFFF)


def flip_line(t):
    """Returns (new tokens or None, static note or None)."""
    op = t[0]
    try:
        v = [int(x, 16) for x in t[1:]]
    except ValueError:
        return None, None
    n = len(v)
    if op == 'R' and n >= 3:
        return ([op, h(v[0]), h(v[1] ^ v[2]), h(v[2])], None) if v[2] else (None, 'R mask 0')
    if op == 'RANY' and n >= 2:
        return ([op, h(v[0]), '0'], None) if v[1] else (None, 'RANY mask 0')
    if op in ('RS', 'WS') and n >= 5:
        return [op, h(v[0]), h(v[1]), h(v[2]), h(v[3]), h(v[4] ^ 1)], None
    if op == 'XP' and n >= 3:
        return ([op, h(v[0]), h(v[1] ^ v[2]), h(v[2])], None) if v[2] else (None, 'XP mask 0')
    if op == 'P' and n >= 4:
        return None, ('P mask 0' if v[2] == 0 else 'P wait only')
    if op == 'WP' and n >= 4:
        return None, ('WP mask 0' if v[2] == 0 else 'WP wait only')
    if op == 'XH' and n >= 2:
        return [op, h(v[0] ^ 1), h(v[1])], None
    if op == 'XD' and n >= 3:
        if v[2] > 0 and n >= 4:
            return [op, h(v[0]), h(v[1]), h(v[2]), h(v[3] ^ 1)] + [h(x) for x in v[4:]], None
        return [op, h(v[0] ^ 1)] + [h(x) for x in v[1:]], None
    if op == 'XT' and n >= 4:
        return [op, h(v[0]), h(v[1] ^ 1), h(v[2]), h(v[3])], None
    if op == 'XC' and n >= 4:
        return [op, h(v[0]), h(v[1]), h(v[2] ^ 1), h(v[3])], None
    if op == 'XK' and n >= 4:
        return [op, h(v[0]), h(v[1]), 'ffff', h(v[3])], None
    if op == 'XS' and n >= 7:
        return [op, h(v[0] ^ 1)] + [h(x) for x in v[1:]], None
    if op == 'XN' and n >= 1:
        return None, ('XN %d cycles' % v[0] if v[0] < 20 else 'XN not inverted')
    if op == 'MC' and n >= 3:
        return [op, h(v[0]), h(v[1]), h(v[2] ^ 1)] + [h(x) for x in v[3:]], None
    if op in ('GAP', 'GAPB', 'TC', 'SOFD') and n >= 2:
        return [op, '7fffffff', '7fffffff'], None
    if op == 'SOF' and n >= 3:
        note = 'SOF count only' if v[1] == 0 and v[2] >= 0xFFFFFFF else None
        return [op, h(v[0] + 0x100000), h(v[1]), h(v[2])], note
    if op == 'SOFQ' and n >= 2:
        return [op, h(v[0]), '0'], None
    if op in ('SOFW', 'SOFR') and n >= 1:
        return ([op, h(v[0] + 0x100000)], None) if v[0] > 0 else (None, None)
    if op == 'LSR' and n >= 2:
        return [op, '3', h(v[1])], None
    if op == 'XWAKE' and n >= 2:
        return [op, h(v[0] + 1), h(v[1])], None
    return None, None


def make_flip(src, dst):
    """Writes the inverted scenario; returns {line: op text} flipped and {line: note} static."""
    flipped, static = {}, {}
    out = []
    for n, ln in enumerate(open(src), 1):
        t = ln.split()
        if t and t[0] == 'WD' and len(t) > 1:
            out.append('WD %x\n' % (int(t[1], 16) * 4))
            continue
        if t and t[0] in CHECK_OPS:
            new, note = flip_line(t)
            if note:
                static[n] = '%s (%s)' % (note, ' '.join(t)[:60])
            if new:
                flipped[n] = ' '.join(t)[:70]
                out.append(' '.join(new) + '\n')
                continue
        out.append(ln)
    open(dst, 'w').write(''.join(out))
    return flipped, static


def run(name, target, ops, seed, extra):
    p = subprocess.run([sys.executable, 'env/scripts/run.py', 'sim', name, target, ops, '+seed=%s' % seed] + extra.split(),
                       capture_output=True, text=True, timeout=7200)
    first = (p.stdout.strip().split('\n') or [''])[0]
    rid = first.split()[0] if first else ''
    log = os.path.join(P.run_dir(rid), 'sim.log') if rid else ''
    return rid, (open(log, errors='ignore').read() if log and os.path.exists(log) else '')


def main():
    a = sys.argv[1:]
    only = a[a.index('--only') + 1:] if '--only' in a else []
    rows = [r for r in csv.DictReader(open(P.TESTLIST)) if r['kind'] == 'sim' and r['source'] != '-' and (not only or r['test'] in only)]
    if '--skip-long' in a:
        rows = [r for r in rows if not r['source'].startswith(LONG)]
    os.chdir(P.V)
    summary, detail = [], []
    seen = set()
    for r in rows:
        key = (r['test'], r['source'], r['target'])
        if key in seen:
            continue
        seen.add(key)
        seed = r['seeds'].split()[0] if r['seeds'].strip() else '1'
        src = r['source'].split(':')
        g = subprocess.run([sys.executable, src[0], seed] + src[1:], cwd=P.TESTS, capture_output=True, text=True)
        if g.returncode != 0:
            summary.append((r['test'], r['source'], r['target'], 'GENERATOR FAILED', '', '', '', '', '', ''))
            continue
        rel = g.stdout.strip().split('\n')[-1]
        base_ops = os.path.join('tests', rel)
        flip_ops = os.path.join('tests', os.path.dirname(rel), '_flip_%s_%s.ops' % (r['test'][2:], abs(hash(r['source'])) % 1000))
        flipped, static = make_flip(base_ops, flip_ops)
        name = r['test'][2:]
        brid, btxt = run('t_flipb_' + name, r['target'], base_ops, seed, r['extra'])
        frid, ftxt = run('t_flipf_' + name, r['target'], flip_ops, seed, r['extra'])
        os.remove(flip_ops)
        bres = re.search(r'RESULT (\w+) checks=(\d+)', btxt)
        executed = {}
        m = re.search(r'^CHKEXEC(.*)$', btxt, re.M)
        if m:
            executed = {int(x.split(':')[0]): int(x.split(':')[1]) for x in m.group(1).split()}
        detected = {int(x) for x in re.findall(r'^FAIL @\d+: line (\d+):', ftxt, re.M)}
        undet, notrun = [], []
        for ln, txt in flipped.items():
            if ln not in executed:
                notrun.append(ln)
                detail.append((r['test'], r['source'], 'NOT_RUN', ln, txt))
            elif ln not in detected:
                undet.append(ln)
                detail.append((r['test'], r['source'], 'UNDETECTED', ln, txt))
        for ln, txt in static.items():
            detail.append((r['test'], r['source'], 'STATIC', ln, txt))
        base_ok = bres.group(1) if bres else 'NO RESULT'
        summary.append((r['test'], r['source'], r['target'], base_ok, len(flipped), len(flipped) - len(undet) - len(notrun), len(undet),
                        len(notrun), len(static), '%s %s' % (brid, frid)))
        print('%-24s %-30s base=%-9s flipped=%-4d detected=%-4d undetected=%-3d notrun=%-3d static=%-3d' % (
            r['test'], r['source'][:30], base_ok, len(flipped), len(flipped) - len(undet) - len(notrun), len(undet), len(notrun), len(static)), flush=True)
        with open(os.path.join(P.SIMOUT, 'flip_audit.csv'), 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['test', 'source', 'build', 'base_result', 'flipped_checks', 'detected', 'undetected', 'not_run', 'static_flags', 'runs'])
            w.writerows(summary)
        with open(os.path.join(P.SIMOUT, 'flip_audit_detail.csv'), 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['test', 'source', 'class', 'line', 'operation'])
            w.writerows(detail)
    tot = [sum(x[i] for x in summary if isinstance(x[i], int)) for i in (4, 5, 6, 7, 8)]
    md = ['# Expectation-inversion audit (2026-11-27)', '', 'Generated by `env/scripts/flip_audit.py` (see its docstring). DETECTED = the inverted '
          'expectation failed at that line. Totals: %d flipped checks, %d detected, %d undetected, %d not run, %d static flags.' % tuple(tot), '',
          '| Test | Scenario | Build | Base | Flipped | Detected | Undetected | Not run | Static | Runs |', '|---|---|---|---|---|---|---|---|---|---|']
    md += ['| %s |' % ' | '.join(str(x).replace('|', '/') for x in s) for s in summary]
    open(os.path.join(P.SIMOUT, 'flip_audit.md'), 'w').write('\n'.join(md) + '\n')
    print('TOTAL flipped %d detected %d undetected %d not_run %d static %d' % tuple(tot))
    return 0


if __name__ == '__main__':
    sys.exit(main())
