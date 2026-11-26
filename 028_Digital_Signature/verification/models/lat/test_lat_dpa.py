"""PARA_EN_DPA_PQ (DEC-049) in the ML-DSA signing program: with the mask flag set and a random mask seed (pool bytes 32 to 63) the
signature must be the same as without masking (OpenSSL deterministic signature, and the hedged signature with pool bytes 0 to
31 as rnd), and the word RAM must hold the shares s + M instead of s (the secret polynomials differ from the unmasked run).
Usage: python test_lat_dpa.py [levels]"""
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ltp_isa import *
import lat_prog as P
import test_lat_prog as TL
import test_mldsa_ref as T
import gen_lat_vec as G


def machine(level, msg, buf, key, pool, dpa, hedged=0):
    snap = {S_LEN_MSG: len(msg), S_LEN_CTX: 0, S_FORM: 0, S_OP: 1, S_LEVEL: 9 + {44: 0, 65: 1, 87: 2}[level], S_HEDGED: hedged,
            S_HASH: 0, S_DPA: dpa}
    return Machine(param_table(), snap, buf, key, pool, words=P.SCR + 2048)


def main(levels):
    a = TL.build()
    code = a.resolve(0)
    rnd = random.Random(49)
    t0 = time.time()
    n = 0
    for level in levels:
        seed = bytes((i * 7 + level) % 256 for i in range(32))
        msg = bytes(range(50))
        pk, sig = T.ossl_make(level, seed, msg)
        rnd_bytes = bytes(rnd.randrange(256) for _ in range(32))
        hs = G.ossl_hedged(level, seed, msg, rnd_bytes)
        for hedged, exp in ((0, sig), (1, hs)):
            pool = rnd_bytes + bytes(rnd.randrange(256) for _ in range(32)) + bytes(32)
            res = []
            for dpa in (0, 1):
                buf = {AREA_MSG: msg, AREA_RES: bytearray()}
                m = machine(level, msg, buf, seed, pool, dpa, hedged)
                TL.run(m, code, a.labels, 'LAT_START')
                assert m.ok and bytes(buf[AREA_RES][:len(exp)]) == exp, 'ML-DSA-%d hedged %d dpa %d: signature differs from OpenSSL' % (
                    level, hedged, dpa)
                res.append([m.W[(P.PS1H << 8) + i] for i in range(256)])
            assert res[0] != res[1], 'ML-DSA-%d: the stored s1 is the same with masking (no share)' % level
            n += 1
            print('ML-DSA-%d hedged %d: masked signature = OpenSSL, s1 stored as a share (%.0f s)' % (level, hedged, time.time() - t0))
    print('PARA_EN_DPA_PQ model: %d cases PASS' % n)


if __name__ == '__main__':
    main([int(x) for x in sys.argv[1:]] or [44, 65, 87])
