import json, os, sys
V = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cd = json.load(open(os.path.join(V, 'waveforms_sim/compare_data.json')))
for st in sorted(cd):
    if len(sys.argv) > 1 and sys.argv[1] not in st: continue
    s = json.load(open(os.path.join(V, '../spec/figures/%s.json' % st))); m = json.load(open(os.path.join(V, 'waveforms_sim/%s.json' % st)))
    sm = {r['name']: r for r in m['signal']}
    print('==', st, 'cells', cd[st].get('ncell'), 'period_ps', cd[st].get('period_ps'))
    for r in s['signal']:
        if cd[st]['rows'].get(r['name']) == 'CLOCK': continue
        print('  %-22s %-10s spec %s\n  %-22s %-10s sim  %s' % (r['name'], cd[st]['rows'].get(r['name']), r['wave'], '', '', sm.get(r['name'], {}).get('wave', '-')))
