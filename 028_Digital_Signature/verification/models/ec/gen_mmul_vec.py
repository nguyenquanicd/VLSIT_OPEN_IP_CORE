"""Vectors of the RTL test of the Montgomery multiplier m_vlsit_dsig_mmul (tests/ec/tb_mmul.sv): for the moduli p and n of the six
curves and digit widths w = 32, 64, 128, operands a, b in [0, m-1] (random and the edges 0, 1, m-1) and the expected
r = a b 2^(-w nd) mod m (Python integers), with nd = ceil(bits(m) / w) and m' = -m^-1 mod 2^w.
Line: w nd m mp a b r (hexadecimal). Usage: python gen_mmul_vec.py <out.txt> [w]"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ec_curves import CURVES


def main(out, ws):
    rnd = random.Random(5)
    lines = []
    for w in ws:
        for cname in ('Ed25519', 'Ed448', 'P-256', 'P-384', 'P-521', 'secp256k1'):
            c = CURVES[cname]
            for m in (c.p, c.n):
                nd = -(-m.bit_length() // w)
                R = 1 << (w * nd)
                mp = (-pow(m, -1, 1 << w)) % (1 << w)
                for a, b in [(0, 0), (1, 1), (m - 1, m - 1), (m - 1, 1), (1, m - 1)] + \
                            [(rnd.randrange(m), rnd.randrange(m)) for _ in range(6)]:
                    r = a * b * pow(R, -1, m) % m
                    lines.append('%d %d %x %x %x %x %x' % (w, nd, m, mp, a, b, r))
    open(out, 'w').write('\n'.join(lines) + '\n')
    print(len(lines), 'vectors')


if __name__ == '__main__':
    main(sys.argv[1], [int(x) for x in sys.argv[2:]] or [32, 64, 128])
