"""Scalar blinding of the elliptic-curve programs (PARA_EN_DPA_EC, LDV 2 = 1): with a random 48-bit r in the pool bytes 88 to 93
every key generation, signature and verify-after-sign must give the same bytes as the standard vectors (RFC 8032, RFC 6979),
and the blinded path must really run (the scalar multiplication then processes more bits)."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ec_curves import CURVES
from ec_isa import *
import ec_progs as P
import test_ec_model as T

OFFS = {AREA_MSG: 0, AREA_SIG: 200, AREA_PK: 400, AREA_RES: 600}


def run(c, prog, buf, key, pool, msg_len, hop=0, dpa=1, **kw):
    m = Machine(c, P.consts(c), P.STRINGS, buf, key, pool, OFFS, msg_len, hop, dpa=dpa, **kw)
    m.run(P.assemble(prog))
    return m


def main():
    rnd = random.Random(2026)
    n = 0
    # Ed25519 and Ed448: keygen, sign, verify-after-sign
    for cname, vecs, prog, sl in (('Ed25519', T.ed25519_vectors(), lambda c, op, vas=False: P.prog_ed(c, op, vas=vas), 64),
                                  ('Ed448', T.ed448_vectors(), lambda c, op, vas=False: P.prog_ed448(c, op, vas=vas), 114)):
        c = CURVES[cname]
        for sk, pk, msg, sig in vecs:
            pool = bytes(88) + bytes(rnd.randrange(256) for _ in range(6)) + bytes(2)
            buf = bytearray(1024); buf[0:len(msg)] = msg
            m = run(c, prog(c, 'keygen'), bytearray(buf), sk, pool, len(msg))
            assert bytes(m.buf[600:600 + c.nbytes]) == pk, '%s blinded keygen differs' % cname
            m = run(c, prog(c, 'sign'), buf, sk, pool, len(msg))
            assert bytes(m.buf[600:600 + sl]) == sig, '%s blinded sign differs' % cname
            assert run(c, prog(c, 'verify', vas=True), m.buf, sk, pool, len(msg)).ok, '%s blinded verify-after-sign' % cname
            n += 3
    # ECDSA: sign with the nonce of the vector, keygen, verify-after-sign
    for cname, x, ux, uy, hop, msg, k, r, s in T.ecdsa_vectors():
        c = CURVES[cname]
        nb = c.nbytes
        pool = (k - 1).to_bytes(nb, 'big') + bytes(8)
        pool = pool + bytes(88 - len(pool)) + bytes(rnd.randrange(256) for _ in range(6)) + bytes(2)
        buf = bytearray(1024); buf[0:len(msg)] = msg
        m = run(c, P.prog_ecdsa(c, 'sign'), buf, x.to_bytes(nb, 'big'), pool, len(msg), hop)
        assert int.from_bytes(m.buf[600:600 + nb], 'big') == r and int.from_bytes(m.buf[600 + nb:600 + 2 * nb], 'big') == s, \
            '%s blinded sign differs' % cname
        assert run(c, P.prog_ecdsa(c, 'verify', vas=True), m.buf, x.to_bytes(nb, 'big'), pool, len(msg), hop).ok
        m = run(c, P.prog_ecdsa(c, 'keygen'), bytearray(buf), x.to_bytes(nb, 'big'), pool, len(msg), hop)
        assert int.from_bytes(m.buf[600:600 + nb], 'big') == ux
        n += 3
    # the blinded path runs: more point doublings than the plain path
    c = CURVES['P-256']
    sk = (12345).to_bytes(32, 'big')
    pool = bytes(88) + bytes([1, 2, 3, 4, 5, 6]) + bytes(2)
    steps = [run(c, P.prog_ecdsa(c, 'keygen'), bytearray(1024), sk, pool, 0, dpa=d).steps for d in (0, 1)]
    assert steps[1] > steps[0] * 1.1, steps
    print('Scalar blinding: %d operations equal to the RFC 8032 and RFC 6979 vectors; blinded keygen %d steps vs %d plain'
          % (n, steps[1], steps[0]))


if __name__ == '__main__':
    main()
