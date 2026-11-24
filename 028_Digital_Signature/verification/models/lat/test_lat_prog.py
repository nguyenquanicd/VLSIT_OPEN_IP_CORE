"""Runs the ML-DSA programs of the lattice processor (key generation, signing, verification, verify-after-sign) and compares them
with OpenSSL 3.5 or later (independent): public key from a seed, deterministic signature, verification of OpenSSL signatures.
Usage: python test_lat_prog.py [levels]"""
import os
import sys
import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ltp_isa import *
import lat_prog as P
import lat_prog_sampling as PS
import lat_prog_main as PM
import lat_prog_sign as PG
import lat_prog_verify as PV
import mldsa_ref as M
import test_mldsa_ref as T


def build():
    a = Asm()
    p = P.Prog(a)
    PM.emit_main(p)
    P.emit_subs(p)
    PS.emit_sampling(p)
    PG.emit_sign(p)
    PV.emit_verify(p)
    return a


def machine(level, op, msg, ctx, buf, key=b'', pool=b'', hedged=0):
    snap = {S_LEN_MSG: len(msg), S_LEN_CTX: len(ctx), S_FORM: 0, S_OP: op, S_LEVEL: 9 + {44: 0, 65: 1, 87: 2}[level], S_HEDGED: hedged, S_HASH: 0}
    return Machine(param_table(), snap, buf, key, pool, words=P.SCR + 2048)


def run(m, code, labels, entry):
    m.stack = []
    m.run(code, labels[entry])


def main(levels):
    a = build()
    code = a.resolve(0)
    print('ML-DSA program: %d instructions' % len(code))
    t0 = time.time()
    for level in levels:
        seed = bytes((i * 7 + level) % 256 for i in range(32))
        msg = bytes(range(50))
        ctx = b''
        opk, osig = T.ossl_make(level, seed, msg)
        # key generation
        buf = {AREA_MSG: msg + ctx, AREA_RES: bytearray()}
        m = machine(level, 0, msg, ctx, buf, key=seed)
        run(m, code, a.labels, 'LAT_START')
        assert m.ok and bytes(buf[AREA_RES][:len(opk)]) == opk, 'ML-DSA-%d key generation differs from OpenSSL' % level
        print('ML-DSA-%d keygen ok (%.0f s)' % (level, time.time() - t0))
        # verification of the OpenSSL signature and of corrupted inputs
        for tag, mm, sg, pk, want in (('valid', msg, osig, opk, True), ('corrupted z', msg, osig[:40] + bytes([osig[40] ^ 4]) + osig[41:], opk, False),
                                      ('corrupted c', msg, bytes([osig[0] ^ 1]) + osig[1:], opk, False),
                                      ('wrong message', msg[:-1] + b'x', osig, opk, False), ('corrupted hint', msg, osig[:-3] + bytes([osig[-3] ^ 1]) + osig[-2:], opk, False)):
            bf = {AREA_MSG: mm + ctx, AREA_SIG: sg, AREA_PK: pk}
            m = machine(level, 2, mm, ctx, bf)
            run(m, code, a.labels, 'LAT_START')
            assert m.ok == want, 'ML-DSA-%d verify %s: got %s' % (level, tag, m.ok)
        print('ML-DSA-%d verify ok (%.0f s)' % (level, time.time() - t0))
        # signing (deterministic) and verify-after-sign
        buf = {AREA_MSG: msg + ctx, AREA_RES: bytearray()}
        m = machine(level, 1, msg, ctx, buf, key=seed)
        run(m, code, a.labels, 'LAT_START')
        assert m.ok and bytes(buf[AREA_RES][:len(osig)]) == osig, 'ML-DSA-%d signature differs from OpenSSL' % level
        m.stack = []
        run(m, code, a.labels, 'LAT_VAS')
        assert m.ok, 'verify-after-sign rejects the signature'
        buf[AREA_RES][100] ^= 1
        m.stack = []
        run(m, code, a.labels, 'LAT_VAS')
        assert not m.ok, 'verify-after-sign accepts a corrupted signature'
        print('ML-DSA-%d sign + verify-after-sign ok (%d steps, %.0f s)' % (level, m.steps, time.time() - t0))


if __name__ == '__main__':
    main([int(x) for x in sys.argv[1:]] or [44, 65, 87])
