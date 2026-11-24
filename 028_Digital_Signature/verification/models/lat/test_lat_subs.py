"""Tests the subroutines of the lattice processor programs (lat_prog.py, lat_prog_sampling.py) against mldsa_ref.py."""
import os
import random
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ltp_isa import *
import lat_prog as P
import lat_prog_sampling as PS
import mldsa_ref as M

NAMES = ('PZERO', 'PCOPY', 'PADD', 'PSUB', 'PMUL', 'PMAC', 'NTT', 'INTT', 'DECOMP', 'NORM', 'SAMPLE_A', 'EXPAND_S', 'EXPAND_MASK', 'SAMPLE_BALL')


def build():
    a = Asm()
    p = P.Prog(a)
    for name in NAMES:
        a.label('T_' + name)
        a.emit('CALL', target='L_' + name)
        a.emit('END')
    P.emit_subs(p)
    PS.emit_sampling(p)
    return a


def machine(level):
    snap = {S_LEN_MSG: 0, S_LEN_CTX: 0, S_FORM: 0, S_OP: 0, S_LEVEL: 9 + {44: 0, 65: 1, 87: 2}[level], S_HEDGED: 0, S_HASH: 0}
    m = Machine(param_table(), snap, {}, words=P.SCR + 2048)
    pr = param_table()[snap[S_LEVEL]]
    for r, f in zip(range(20, 32), (P_K, P_L, P_ETA, P_TAU, P_G1, P_G2, P_BETA, P_OMEGA, P_LAM4, P_CBITS, P_WBITS, P_ALPHA)):
        m.R[r] = pr[f]
    return m


def setpoly(m, base, poly):
    m.W[base:base + 256] = poly


def getpoly(m, base):
    return m.W[base:base + 256]


def run(m, code, a, name):
    m.stack = []
    m.run(code, a.labels['T_' + name])


def main():
    a = build()
    code = a.resolve(0)
    print('subroutines: %d instructions' % len(code))
    rnd = random.Random(3)
    m = machine(44)
    poly = [rnd.randrange(M.Q) for _ in range(256)]
    p2 = [rnd.randrange(M.Q) for _ in range(256)]
    setpoly(m, 0, poly)
    setpoly(m, 256, p2)
    m.R[0], m.R[1] = 512, 0
    run(m, code, a, 'PCOPY')
    assert getpoly(m, 512) == poly
    for nm, ref in (('PADD', M.padd), ('PSUB', M.psub), ('PMUL', M.pmul)):
        m.R[0], m.R[1], m.R[2] = 768, 0, 256
        run(m, code, a, nm)
        assert getpoly(m, 768) == ref(poly, p2), nm
    setpoly(m, 768, poly)
    m.R[0], m.R[1], m.R[2] = 768, 0, 256
    run(m, code, a, 'PMAC')
    assert getpoly(m, 768) == M.padd(poly, M.pmul(poly, p2))
    m.R[0] = 768
    run(m, code, a, 'PZERO')
    assert getpoly(m, 768) == [0] * 256
    setpoly(m, 1024, poly)
    m.R[0] = 1024
    run(m, code, a, 'NTT')
    assert getpoly(m, 1024) == M.ntt(poly), 'NTT'
    m.R[0] = 1024
    run(m, code, a, 'INTT')
    assert getpoly(m, 1024) == poly, 'INTT roundtrip'
    setpoly(m, 1280, M.ntt(p2))
    m.R[0] = 1280
    run(m, code, a, 'INTT')
    assert getpoly(m, 1280) == p2
    print('polynomial subroutines ok')
    for level in (44, 65, 87):
        m = machine(level)
        g2 = M.PARAMS[level]['gamma2']
        for r in [0, 1, g2, g2 + 1, 2 * g2, 2 * g2 + 1, M.Q - 1, M.Q - 2, M.Q - 1 - g2] + [rnd.randrange(M.Q) for _ in range(300)]:
            m.R[8] = r
            run(m, code, a, 'DECOMP')
            r1, r0 = M.decompose(r, g2)
            assert m.R[1] == r1 and s32(m.R[2]) == r0, (level, r, m.R[1], s32(m.R[2]), r1, r0)
        for pol, bound in ((poly, 4190208), ([5] * 256, 6), ([M.Q - 5] * 256, 5), ([M.Q - 4] * 256, 5)):
            setpoly(m, 0, pol)
            m.R[0], m.R[1] = 0, bound
            run(m, code, a, 'NORM')
            assert m.F[5] == int(max(abs(M.centered(x)) for x in pol) >= bound), (bound,)
    print('decompose and norm ok')
    for level in (44, 65, 87):
        m = machine(level)
        pr = M.PARAMS[level]
        rho = bytes(range(32))
        rho2 = bytes((i * 3) % 256 for i in range(64))
        for i in range(32):
            m.W[P.SCR_RHO + i] = rho[i]
        for i in range(64):
            m.W[P.SCR_RHO2 + i] = rho2[i]
            m.W[P.SCR_RHOPP + i] = (i * 5 + 1) % 256
        m.R[0], m.R[1], m.R[2] = 0, 2, 3
        run(m, code, a, 'SAMPLE_A')
        assert getpoly(m, 0) == M.rej_ntt_poly(rho, 3, 2), 'SAMPLE_A'
        m.R[0], m.R[1] = 256, 5
        run(m, code, a, 'EXPAND_S')
        assert getpoly(m, 256) == M.rej_bounded_poly(rho2 + (5).to_bytes(2, 'little'), pr['eta']), 'EXPAND_S'
        m.R[0], m.R[1] = 512, 300
        run(m, code, a, 'EXPAND_MASK')
        assert getpoly(m, 512) == M.expand_mask(bytes((i * 5 + 1) % 256 for i in range(64)), 300, 1, pr['gamma1'])[0], 'EXPAND_MASK'
        ct = bytes((i * 11 + 7) % 256 for i in range(pr['lam'] // 4))
        for i, b in enumerate(ct):
            m.W[P.SCR_CT + i] = b
        m.R[0] = 768
        run(m, code, a, 'SAMPLE_BALL')
        assert getpoly(m, 768) == M.sample_in_ball(ct, pr['tau']), 'SAMPLE_BALL'
    print('samplers ok (hash jobs of the last run: %d)' % m.nhash)


if __name__ == '__main__':
    main()
