"""Updates the status and evidence columns of sim/docs/00_plan/vplan.csv from the retained run folders (R-245): a row is `passing`
only when every final run of every test it names passed and names those run folders as evidence; a row with a failing run is
`failing`; a row whose test has no run stays `planned` (or `implemented` for the review test). Nothing else in the row changes.
    python scripts/update_vplan.py --since r0336"""
import csv
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402
SIM = P.V
VPLAN = P.VPLAN
ALIAS = {}                                                   # a plan test is one testlist test (t_fml_fifo runs its three formal tasks)


def main():
    since = int(sys.argv[sys.argv.index('--since') + 1].lstrip('r'))
    last = {}
    for ln in open(P.INDEX, encoding='utf-8').read().split('\n'):
        p = ln.split(',')
        if len(p) >= 3 and p[0].startswith('r') and (int(re.match(r'r(\d+)_', p[0]).group(1)) >= since or p[2].startswith('REVIEW')):
            if not p[1].startswith(('t_mut_', 't_cov_', 't_dbg', 't_nc_')):
                last.setdefault(p[1], []).append((p[0], p[2]))
    rows = list(csv.DictReader(open(VPLAN, encoding='utf-8', newline='')))
    alias = {}
    ap = os.path.join(P.COV, 'bin_aliases.csv')
    if os.path.exists(ap):
        for ln in open(ap, encoding='utf-8').read().splitlines()[1:]:
            if ',' in ln:
                a, b = ln.strip().split(',')[:2]
                alias[a] = b
    hit = set()
    for t, rl in last.items():
        for rid, verdict in rl:
            bp = os.path.join(P.run_dir(rid), 'bins.txt')
            if verdict.startswith('PASS') and os.path.exists(bp):
                for ln in open(bp, encoding='utf-8').read().splitlines():
                    if ln.strip():
                        hit.add(alias.get(ln.split()[0], ln.split()[0]))
    names = list(rows[0].keys())
    counts = collections.Counter()
    for r in rows:
        tests = [t.strip() for t in re.split(r'[;,]', r['test']) if t.strip()]
        names_all = [x for t in tests for x in ALIAS.get(t, [t])]
        runs = [x for t in names_all for x in last.get(t, [])]
        if not runs:
            r['status'] = 'implemented' if r['method'] == 'review' else 'planned'
            r['evidence'] = ''
        else:
            missing = [t for t in names_all if t not in last and t != 't_rev_process']
            bad = [x for x in runs if not x[1].startswith(('PASS', 'REVIEW'))]
            review = [x for x in runs if x[1].startswith('REVIEW')]
            if bad:
                r['status'] = 'failing'
                r['evidence'] = ';'.join(sorted(set(x[0] for x in bad))[:4])
            elif review:                              # a record review by an AI agent is not a human decision: implemented, not passing
                r['status'] = 'implemented'
                r['evidence'] = ';'.join(sorted(set(x[0] for x in review)))
            elif missing:
                r['status'] = 'implemented'
                r['evidence'] = ''
            else:
                r['status'] = 'passing'
                r['evidence'] = ';'.join(sorted(set(x[0] for x in runs))[-6:])
                bl = [b.strip() for b in r['coverage_bin'].split(';') if b.strip()]
                miss = [b for b in bl if b not in hit]
                r['notes'] = re.sub(r' \[bins unhit: [^\]]*\]$', '', r['notes'])
                if bl and len(miss) == len(bl):                # the tests pass but none of the bins of the row was marked: not passing
                    r['status'] = 'implemented'
                    r['notes'] += ' [bins unhit: %s]' % ' '.join(miss)
                elif miss:
                    r['notes'] += ' [bins unhit: %s]' % ' '.join(miss)
        counts[r['status']] += 1
    with open(VPLAN, 'w', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=names, lineterminator='\n')
        w.writeheader()
        w.writerows(rows)
    print('vplan updated: ' + ', '.join('%s=%d' % kv for kv in sorted(counts.items())))


if __name__ == '__main__':
    main()
