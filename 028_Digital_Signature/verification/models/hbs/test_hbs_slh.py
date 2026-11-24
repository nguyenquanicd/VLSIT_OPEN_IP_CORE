"""Runs the SLH-DSA program of the hash-tree processor on signatures made by OpenSSL (independent) and on corrupted
ones. Usage: python test_hbs_slh.py [set numbers]"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from htp_isa import *
import hbs_prog_slh as P
import slh_ref as S
import test_slh_ref as T


def build():
    a = Asm()
    P.emit_slh(a)
    return a


def run_slh(code, labels, idx, msg, sig, pk, ctx=b''):
    m = Machine(P.slh_table(), {S_LEN_MSG: len(msg), S_LEN_CTX: len(ctx), S_FORM: 0, S_SLH: idx}, {AREA_MSG: msg + ctx, AREA_SIG: sig, AREA_PK: pk})
    m.run(code, labels['SLH_START'])
    return m


if __name__ == '__main__':
    sets = [int(x) for x in sys.argv[1:]] or list(range(12))
    a = build()
    code = a.resolve(0)
    print('SLH program: %d instructions' % len(code))
    for idx in sets:
        msg = bytes(range(37 + idx))
        pk, sig = T.make(idx, msg)
        m = run_slh(code, a.labels, idx, msg, sig, pk)
        assert m.ok, '%s: the program rejects an OpenSSL signature' % S.SETS[idx]['name']
        bad = bytearray(sig); bad[len(sig) // 2] ^= 4
        assert not run_slh(code, a.labels, idx, msg, bytes(bad), pk).ok
        assert not run_slh(code, a.labels, idx, msg[:-1] + b'x', sig, pk).ok
        print('%-22s ok  (%d hashes, %d steps)' % (S.SETS[idx]['name'], m.nhash, m.steps))
