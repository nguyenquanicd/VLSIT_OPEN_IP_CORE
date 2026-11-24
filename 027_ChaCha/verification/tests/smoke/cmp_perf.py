import os
import re
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'models'))
import chacha_cycle_model as m

kd = sys.argv[1] if len(sys.argv) > 1 else '2'
worst = {}
for cfg, key in (('CFG-LP', 'LP'), ('CFG-BASE', 'BASE'), ('CFG-HP', 'HP')):
    print('###', cfg, 'KD=' + kd)
    print('| AAD | msg | formula | measured | difference |')
    print('|---:|---:|---:|---:|---:|')
    for line in open('res_%s_kd%s.txt' % (key, kd)):
        a = int(re.search(r'AAD=(\d+)', line).group(1))
        mm = int(re.search(r'MSG=(\d+)', line).group(1))
        cyc = int(re.search(r' cycles=(\d+)', line).group(1))
        f = m.start_to_done(cfg, a, mm)
        d = (cyc - f) / f * 100
        print('| %d | %d | %d | %d | %+.1f %% |' % (a, mm, f, cyc, d))
        if mm > 0:
            w = worst.get(cfg)
            if w is None or d > w[0]:
                worst[cfg] = (d, a, mm)
print()
for cfg, w in worst.items():
    print('worst (msg >= 1 byte)', cfg, '%+.1f %% at AAD=%d msg=%d' % w)
