"""Testcase quality report (R-282) and engineer review ledger (R-284), 2026-11-24.

For every simulation test of tests/usb20/testlist.csv it collects, from retained files only:
  - the scenario sources (generator files) and their SHA-256;
  - the final runs since --since (simulation verdict and the executed check count from the RESULT line of sim.log);
  - the negative-control results of sim/oracle_audit.csv (GAP = passed although the control broke the DUT side);
  - the static flags of sim/ops_audit.csv (FLUSH count, bins without a check, weak checks);
  - header compliance (R-281, R-286) from sim/header_check.csv (env/scripts/header_check.py: fields, at least five documented
    checkpoint IDs, every ID emitted and followed by a check) and the checkpoints actually reached: the distinct IDs of the CHKPT
    lines in sim.log of the passing final runs (the harness fails a run whose checkpoint executed no check);
  - the waveform of the run when the priority list names the test (R-283; path and SHA-256 from sim/waveform_index.csv).
The quality verdict is separate from the simulation result: invalid (a negative control showed a GAP), not_run, weak (passes but
the header check fails, fewer than five checkpoints were reached in passing runs, a weak check remains, or the header lists known
gaps), or unproven (none of these). FLUSH counts are reported for information. "unproven" (called "effective" until 2026-11-27)
only means that this script found no static weakness: it does NOT show that the checks can detect a defect (review finding of 2026-11-27, report section 20). The engineer columns
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
    hdr = {}
    hp = os.path.join(P.SIMOUT, 'header_check.csv')
    if os.path.exists(hp):
        for r in csv.DictReader(open(hp)):
            hdr[r['test']] = r
    gaps_known = {}
    for t, h in hdr.items():
        hf = os.path.join(P.TESTS, h['header'])
        if os.path.exists(hf):
            txt = open(hf, encoding='utf-8').read()
            gaps_known[t] = 'Known gaps' in txt[:txt.find('AI-generated candidate')]
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
        checks, reached = [], set()
        for rid, v in rl:
            lp = os.path.join(P.run_dir(rid), 'sim.log')
            if os.path.exists(lp):
                lt = open(lp, errors='ignore').read()
                m = re.search(r'RESULT \w+ checks=(\d+)', lt)
                if m:
                    checks.append(int(m.group(1)))
                if v.startswith('PASS'):
                    reached |= set(re.findall(r'CHKPT @\d+: (\S+)', lt))
        au = audit.get(test, [])
        gaps = ['%s:%s' % (a['control'], a['source']) for a in au if a['result'] == 'GAP']
        caught = sum(1 for a in au if a['result'] == 'caught')
        oa = ops.get(test, [])
        flush = sum(int(o['flush']) for o in oa)
        nochk = sum(int(o['bins_without_check']) for o in oa)
        weak = [o['weak checks'] for o in oa if o['weak checks']]
        h = hdr.get(test, {})
        hok = h.get('result') == 'pass'
        if not rl:
            verdict = 'not_run'
        elif gaps:
            verdict = 'invalid'
        elif not hok or len(reached) < 5 or weak or gaps_known.get(test):
            verdict = 'weak'
        else:
            verdict = 'unproven'
        w = waves.get(test, {})
        q_rows.append((test, ' '.join(gens), '%d/%d' % (npass, len(rl)), '%d..%d' % (min(checks), max(checks)) if checks else '-',
                       '%d caught, %d GAP' % (caught, len(gaps)) if au else 'not audited', '; '.join(gaps[:4]), flush, nochk,
                       '; '.join(weak)[:120], '%s (%s)' % (h.get('result', 'missing'), h.get('header', '-')),
                       '%s listed, %d reached' % (h.get('checkpoints_listed', '0'), len(reached)), 'yes' if gaps_known.get(test) else 'no',
                       w.get('waveform', 'N/A (outside the priority set)'), verdict))
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
          '| Test | Generators | Final runs PASS | Checks executed | Negative controls | GAPs | FLUSH | Bins without check | Weak checks | R-281 header check | R-286 checkpoints (header / reached in passing runs) | Known gaps in header | Waveform | Quality |',
          '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|']
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
