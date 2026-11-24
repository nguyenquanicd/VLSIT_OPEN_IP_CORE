"""Testcase header check (R-281, R-286), 2026-11-25.

Every simulation test of tests/usb20/testlist.csv has one header: the docstring of the generator whose field "Test ID and title"
names the test, or tests/usb20/tc_<test>.txt for a test that only reuses other generators (a configuration sweep). The script
checks, from the files and from the regenerated operation files of every testlist row and seed:
  H1  the header has every field of the template (reference/templates/vlsit_testcase_header.md.tpl), none empty or a placeholder;
  H2  the header documents at least five distinct checkpoint IDs: its own rows, each with seven fields
      (ID | requirement | trigger | expected | checker | deadline | fails when), plus the shared IDs it names on its line
      "Shared checkpoints ...:" (each a full row of the library catalogue);
  H3  every checkpoint ID the header lists is emitted (op CHK) by the operation files of that test (of the generator when one header
      names several tests, e.g. the reset and clock parts of gen_dir_reset_clk.py), and every ID an operation file
      emits is listed in the header of its generator or in the catalogue of the shared library (usb2lib, devlib, hostlib);
  H4  every CHK is followed by at least one check operation before the next CHK or END (the harness also fails a run whose
      checkpoint executed no check);
  H5  the test reaches at least five distinct checkpoint IDs over its rows (R-286).
The header states intent; whether a run reached its checkpoints is read from sim.log (CHKPT lines) by testcase_review.py.
    python env/scripts/header_check.py          (from the verification folder) -> sim/header_check.md, sim/header_check.csv"""
import csv
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402
from ops_audit import CHECK  # noqa: E402

FIELDS = ['Test ID and title', 'Priority and rationale', 'Purpose', 'Requirements and features', 'DUT configuration and preconditions',
          'Software flow', 'Stimulus', 'Functional checkpoints and assertions', 'Expected outcome', 'Defect/fault targeted',
          'Checker/oracle', 'Reproducibility', 'Waveform', 'Evidence']
ROW = re.compile(r'^\s+([A-Z][A-Z0-9]*-[A-Z0-9-]+)\s*\|(.*)$')
LIBS = ['usb2lib.py', 'devlib.py', 'hostlib.py']


def docstring(path):
    s = open(path, encoding='utf-8').read()
    if path.endswith('.txt'):
        return s
    if not s.startswith('"""'):
        return ''
    return s[3:s.index('"""', 3)]


def parse(text):
    """Fields (name -> text) and checkpoint rows (id -> list of the six fields after the ID)."""
    fields, cur, rows = {}, None, {}
    for ln in text.split('\n'):
        m = re.match(r'^([A-Z][A-Za-z/ ]+?)(?: \([^)]*\))?:\s*(.*)$', ln)
        if m and m.group(1) in FIELDS:
            cur = m.group(1)
            fields[cur] = m.group(2).strip()
            continue
        r = ROW.match(ln)
        if r:
            rows[r.group(1)] = [x.strip() for x in r.group(2).split('|')]
        if cur:
            fields[cur] = (fields[cur] + ' ' + ln.strip()).strip()
    return fields, rows


def ops_of(row, seed):
    src = row['source'].split(':')
    g = subprocess.run([sys.executable, src[0], seed] + src[1:], cwd=P.TESTS, capture_output=True, text=True)
    if g.returncode != 0:
        return None
    return os.path.join(P.V, 'tests', g.stdout.strip().split('\n')[-1])


def scan(path):
    """Checkpoint IDs of an operation file and the IDs followed by no check (H4)."""
    ids, empty, cur, n = [], [], None, 0
    for ln in open(path):
        t = ln.split()
        if not t or t[0] == '#':
            continue
        if t[0] in ('CHK', 'END'):
            if cur is not None and n == 0:
                empty.append(cur)
            cur, n = (t[1], 0) if t[0] == 'CHK' else (None, 0)
            if t[0] == 'CHK':
                ids.append(t[1])
            continue
        if t[0] in CHECK:
            n += 1
    return ids, empty


def main():
    os.chdir(P.V)
    rows = [r for r in csv.DictReader(open(P.TESTLIST)) if r['kind'] == 'sim' and r['source'] != '-']
    lib_ids = {}
    for lib in LIBS:
        lib_ids.update(parse(docstring(os.path.join(P.TESTS, lib)))[1])
    headers = {}                                       # test -> (header file, fields, rows)
    gen_rows = {}
    for g in sorted({r['source'].split(':')[0] for r in rows}):
        f, rr = parse(docstring(os.path.join(P.TESTS, g)))
        gen_rows[g] = (f, rr)
        for t in re.findall(r'\bt_[a-z0-9_]+', f.get('Test ID and title', '')):
            headers.setdefault(t, (g, f, rr))
    for t in sorted({r['test'] for r in rows}):
        tc = os.path.join(P.TESTS, 'tc_%s.txt' % t)
        if os.path.exists(tc):
            f, rr = parse(docstring(tc))
            headers[t] = ('tc_%s.txt' % t, f, rr)
    emitted_t, emitted_g, errs = {}, {}, []
    for r in rows:
        g = r['source'].split(':')[0]
        for seed in (r['seeds'].split() or ['1']):
            op = ops_of(r, seed)
            if op is None:
                errs.append(('-', r['test'], 'generator %s failed for seed %s' % (r['source'], seed)))
                continue
            ids, empty = scan(op)
            emitted_t.setdefault(r['test'], set()).update(ids)
            emitted_g.setdefault(g, set()).update(ids)
            for e in sorted(set(empty)):
                errs.append(('H4', r['test'], '%s seed %s: checkpoint %s is followed by no check' % (r['source'], seed, e)))
    for g, (f, rr) in gen_rows.items():
        for i in sorted(emitted_g.get(g, set()) - set(rr) - set(lib_ids)):
            errs.append(('H3', g, 'checkpoint %s is emitted but not listed in the header of %s or the library catalogue' % (i, g)))
        for i in sorted(set(rr) - emitted_g.get(g, set())):
            errs.append(('H3', g, 'checkpoint %s of the header is never emitted by %s' % (i, g)))
    out = []
    for t in sorted({r['test'] for r in rows}):
        if t not in headers:
            errs.append(('H1', t, 'no header names this test'))
            out.append((t, '-', 0, len(emitted_t.get(t, ())), 'no header'))
            continue
        hf, f, rr = headers[t]
        miss = [x for x in FIELDS if not f.get(x) or re.search(r'<[^>]+>|TBD|placeholder', f.get(x, ''))]
        for x in miss:
            errs.append(('H1', t, '%s: field "%s" missing, empty or a placeholder' % (hf, x)))
        bad = [i for i, v in rr.items() if len(v) != 6 or not all(v)]
        for i in bad:
            errs.append(('H2', t, '%s: checkpoint row %s does not have seven non-empty fields' % (hf, i)))
        sh = set()
        for m in re.finditer(r'^Shared checkpoints[^:]*:(.*)$', open(os.path.join(P.TESTS, hf), encoding='utf-8').read(), re.M):
            sh |= set(re.findall(r'\b[A-Z]{3}-[A-Z0-9]+\b', m.group(1)))
        for i in sorted(sh - set(lib_ids)):
            errs.append(('H2', t, '%s: shared checkpoint %s is not in the library catalogue' % (hf, i)))
        if len(set(rr) | (sh & set(lib_ids))) < 5:
            errs.append(('H2', t, '%s documents %d checkpoint IDs (own rows and shared IDs, at least 5)' % (hf, len(set(rr) | sh))))
        known = set(rr)
        shared = len(set(re.findall(r'\bt_[a-z0-9_]+', f.get('Test ID and title', '')))) > 1
        for i in sorted(set() if shared else known - emitted_t.get(t, set())):   # a header of several tests: H3 per generator
            errs.append(('H3', t, '%s lists %s, which no operation file of the test emits' % (hf, i)))
        reach = emitted_t.get(t, set())
        if len(reach) < 5:
            errs.append(('H5', t, 'the operation files reach %d distinct checkpoints (at least 5)' % len(reach)))
        ok = not [e for e in errs if e[1] in (t, hf)]
        out.append((t, hf, len(rr), len(reach), 'pass' if ok else 'fail'))
    with open(os.path.join(P.SIMOUT, 'header_check.csv'), 'w', newline='') as fo:
        w = csv.writer(fo)
        w.writerow(['test', 'header', 'checkpoints_listed', 'checkpoints_emitted', 'result'])
        w.writerows(out)
    md = ['# Testcase header check (R-281, R-286)', '', 'Generated by `env/scripts/header_check.py` (rules H1 to H5 in its docstring).', '',
          '| Test | Header | Checkpoints listed | Distinct checkpoints emitted | Result |', '|---|---|---|---|---|']
    md += ['| %s | %s | %d | %d | %s |' % o for o in out]
    md += ['', '## Findings', ''] + (['- %s %s: %s' % e for e in errs] if errs else ['None.'])
    open(os.path.join(P.SIMOUT, 'header_check.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    for e in errs:
        print('%s %s: %s' % e)
    print('tests %d, pass %d, findings %d' % (len(out), sum(1 for o in out if o[-1] == 'pass'), len(errs)))
    return 1 if errs else 0


if __name__ == '__main__':
    sys.exit(main())
