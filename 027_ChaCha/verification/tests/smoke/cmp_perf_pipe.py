"""Compare the measured start-to-done cycles of the pipeline options with the formula (scratch).

Reads res_<CFG>_c<PC>p<PP>.txt written by runperf_all.sh (CFG = LP, BASE, HP; PC = PARA_PIPE_CHACHA,
PP = PARA_PIPE_POLY) and prints, for every combination, the largest difference (measured - formula)
/ formula over the messages of at least one byte, with the formula of
verification/models/chacha_cycle_model.py (HDS section 13.2, DEC-036).
Usage: python cmp_perf_pipe.py            summary
       python cmp_perf_pipe.py all        every row
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'models'))
import chacha_cycle_model as m

show_all = len(sys.argv) > 1 and sys.argv[1] == 'all'
for key, cfg in (('LP', 'CFG-LP'), ('BASE', 'CFG-BASE'), ('HP', 'CFG-HP')):
    for pc in (0, 1):
        for pp in (0, 1):
            worst = None
            for line in open('res_%s_c%dp%d.txt' % (key, pc, pp)):
                a = int(re.search(r'AAD=(\d+)', line).group(1))
                mm = int(re.search(r'MSG=(\d+)', line).group(1))
                cyc = int(re.search(r' cycles=(\d+)', line).group(1))
                f = m.start_to_done(cfg, a, mm, pc, pp)
                d = (cyc - f) / f * 100
                if show_all:
                    print('%s PC=%d PP=%d AAD=%d MSG=%d formula=%d measured=%d %+.1f %%' % (cfg, pc, pp, a, mm, f, cyc, d))
                if mm > 0 and (worst is None or d > worst[0]):
                    worst = (d, a, mm, cyc, f)
            print('%-8s PC=%d PP=%d worst %+.1f %% at AAD=%d MSG=%d (measured %d, formula %d)' % ((cfg, pc, pp) + worst))
