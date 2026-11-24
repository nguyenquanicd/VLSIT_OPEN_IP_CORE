"""Runs the XMSS / XMSS^MT program of the hash-tree processor against the reference signer and verifier (xmss_ref.py)."""
import os
import sys
import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from htp_isa import *
import hbs_prog_xmss as P
import xmss_ref as X


def build():
    a = Asm()
    P.emit_xmss(a)
    return a


def run_x(code, labels, idx, msg, pk, sig):
    m = Machine(P.xmss_tables(), {S_LEN_MSG: len(msg), S_LEN_CTX: 0, S_FORM: 0, S_XMSS: idx}, {AREA_MSG: msg, AREA_SIG: sig, AREA_PK: pk}, ram_bytes=16384)
    m.run(code, labels['XMSS_START'])
    return m


if __name__ == '__main__':
    sets = [int(x) for x in sys.argv[1:]] or [14, 15, 20, 26, 12, 0, 6, 7]
    a = build()
    code = a.resolve(0)
    print('XMSS program: %d instructions' % len(code))
    t0 = time.time()
    for idx in sets:
        x = X.Xmss(idx)
        msg = bytes(range(41))
        pk, sig = x.make(msg, idx=5 if X.SETS[idx]['d'] > 1 else 3)
        m = run_x(code, a.labels, idx, msg, pk, sig)
        assert m.ok, '%s: the program rejects a valid signature' % X.SETS[idx]['name']
        bad = bytearray(sig); bad[len(sig) // 2] ^= 8
        assert not run_x(code, a.labels, idx, msg, pk, bytes(bad)).ok
        assert not run_x(code, a.labels, idx, msg + b'!', pk, sig).ok
        badpk = bytearray(pk); badpk[-1] ^= 1
        assert not run_x(code, a.labels, idx, msg, bytes(badpk), sig).ok
        print('%-26s ok (%d hashes, %d steps, %.0f s)' % (X.SETS[idx]['name'], m.nhash, m.steps, time.time() - t0))
