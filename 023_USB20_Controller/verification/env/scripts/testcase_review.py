"""Testcase quality report (R-282) and engineer review ledger (R-284), 2026-11-24.

For every simulation test of tests/usb20/testlist.csv it collects, from retained files only:
  - the scenario sources (generator files) and their SHA-256;
  - the final runs since --since (simulation verdict and the executed check count from the RESULT line of sim.log);
  - the negative-control results of sim/oracle_audit.csv (GAP = passed although the control broke the DUT side);
  - the static flags of sim/ops_audit.csv (FLUSH count, bins without a check, weak checks);
  - header compliance: R-281 asks for a structured header with checkpoints, R-286 for at least five documented check IDs;
    the generators have a prose docstring only, so both are reported as gaps until the headers are written;
  - the waveform of the run when the priority list names the test (R-283; path and SHA-256 from sim/waveform_index.csv).
The quality verdict is separate from the simulation result: invalid (a negative control showed a GAP), weak (passes but the
header/check-ID gaps or static flags remain), not_run, or effective (no GAP, no flag, header complete). The engineer columns
of the ledger stay 'pending': an AI cannot fill them (R-284).
    python env/scripts/testcase_review.py --since rNNNN      -> docs/testcase_quality.md, docs/testcase_review.csv"""
import csv
import hashlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def main():
    since = int(sys.argv[sys.argv.index('--since') + 1].lstrip('r'))
    rows = [r for r in csv.DictReader(open(P.TESTLIST)) if r['kind'] == 'sim']
    runs = {}
    for ln in open(P.INDEX, encoding='utf-8'):
        p = ln.strip().split(',')
        m = re.match(r'r(\d+)_', p[0]) if p else None
        if m and int(m.group(1)) >= since and len(p) >= 3:
            runs.setdefault(p[1], []).append((p[0], p[2]))
    audit = {}
    ap = os.path.join(P.SIMOUT, 'oracle_audit.csv')
    if os.path.exists(ap):
        for r in csv.DictReader(open(ap)):
            audit.setdefault(r['test'], []).append(r)
    ops = {}
    op = os.path.join(P.SIMOUT, 'ops_audit.csv')
    if os.path.exists(op):
        for r in csv.DictReader(open(op)):
            ops.setdefault(r['test'], []).append(r)
    waves = {}
    wp = os.path.join(P.SIMOUT, 'waveform_index.csv')
    if os.path.exists(wp):
        for r in csv.DictReader(open(wp)):
            waves[r['test']] = r
    tests = []
    for r in rows:
        if r['test'] not in [t[0] for t in tests]:
            tests.append((r['test'], []))
        dict(tests)[r['test']].append(r)
    q_rows, ledger = [], []
    for test, rr in tests:
        gens = sorted({x['source'].split(':')[0] for x in rr if x['source'] != '-'})
        srcs = [(g, sha(os.path.join(P.TESTS, g))) for g in gens if os.path.exists(os.path.join(P.TESTS, g))]
        rl = runs.get(test, [])
        npass = sum(1 for _, v in rl if v.startswith('PASS'))
        checks = []
        for rid, _ in rl:
            lp = os.path.join(P.run_dir(rid), 'sim.log')
            if os.path.exists(lp):
                m = re.search(r'RESULT \w+ checks=(\d+)', open(lp, errors='ignore').read())
                if m:
                    checks.append(int(m.group(1)))
        au = audit.get(test, [])
        gaps = ['%s:%s' % (a['control'], a['source']) for a in au if a['result'] == 'GAP']
        caught = sum(1 for a in au if a['result'] == 'caught')
        oa = ops.get(test, [])
        flush = sum(int(o['flush']) for o in oa)
        nochk = sum(int(o['bins_without_check']) for o in oa)
        weak = [o['weak checks'] for o in oa if o['weak checks']]
        if not rl:
            verdict = 'not_run'
        elif gaps:
            verdict = 'invalid'
        else:
            verdict = 'weak'                          # header (R-281) and check-ID list (R-286) not yet written for any generator
        w = waves.get(test, {})
        q_rows.append((test, ' '.join(gens), '%d/%d' % (npass, len(rl)), '%d..%d' % (min(checks), max(checks)) if checks else '-',
                       '%d caught, %d GAP' % (caught, len(gaps)) if au else 'not audited', '; '.join(gaps[:4]), flush, nochk,
                       '; '.join(weak)[:120], 'no (prose docstring)', 'no', w.get('waveform', 'N/A (outside the priority set)'), verdict))
        ledger.append([test, ' '.join(g for g, _ in srcs), ' '.join(h for _, h in srcs), w.get('waveform', 'N/A (outside the priority set of R-283)'),
                       w.get('sha256', 'N/A'), ' '.join(rid for rid, _ in rl[-6:]), ' '.join(sorted({x['target'] for x in rr})),
                       ' '.join(sorted({x['seeds'] for x in rr})), 'pending', 'pending', 'pending', 'pending', 'pending', 'pending',
                       'pending', 'pending', 'pending', 'pending', 'AI pre-review: quality verdict %s' % verdict, 'pending'])
    head = ['test_id', 'source_path', 'source_sha256', 'waveform_path', 'waveform_sha256', 'run_id', 'configuration', 'seed', 'reviewer_name',
            'reviewer_role', 'review_date_utc', 'source_reviewed', 'software_flow_reviewed', 'checkpoints_reviewed', 'expected_vs_observed_reviewed',
            'defect_detection_reviewed', 'waveform_reviewed', 'disposition', 'findings', 'author_response']
    with open(os.path.join(P.DOCS, 'testcase_review.csv'), 'w', newline='', encoding='utf-8') as f:
        cw = csv.writer(f)
        cw.writerow(head)
        cw.writerows(ledger)
    md = ['# Testcase quality report (R-282) / Báo cáo chất lượng testcase', '',
          'Generated by `env/scripts/testcase_review.py --since r%04d`. The quality verdict is separate from the simulation result. '
          'GAP = a negative control (`env/scripts/oracle_audit.py`) broke the DUT side and the scenario still passed. '
          'The engineer review of every source and waveform (R-284) is pending in `testcase_review.csv`; no row is human-reviewed.' % since, '',
          '| Test | Generators | Final runs PASS | Checks executed | Negative controls | GAPs | FLUSH | Bins without check | Weak checks | R-281 header | R-286 five check IDs | Waveform | Quality |',
          '|---|---|---|---|---|---|---|---|---|---|---|---|---|']
    md += ['| %s |' % ' | '.join(str(x).replace('|', '/') for x in q) for q in q_rows]
    cnt = {}
    for q in q_rows:
        cnt[q[-1]] = cnt.get(q[-1], 0) + 1
    md += ['', 'Verdicts: ' + ', '.join('%s %d' % kv for kv in sorted(cnt.items()))]
    open(os.path.join(P.DOCS, 'testcase_quality.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    print('tests %d; verdicts %s' % (len(q_rows), cnt))
    return 0


if __name__ == '__main__':
    sys.exit(main())
