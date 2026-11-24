"""Runs the LMS/HSS program of the hash-tree processor against the reference (lms_ref.py): valid HSS signatures of
several parameter sets and levels, and corrupted ones."""
import os
import sys
import time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from htp_isa import *
import hbs_prog_lms as P
import lms_ref as L


def build():
    a = Asm()
    P.emit_lms(a)
    return a


def run_lms(code, labels, lt, lo, lv, msg, pub, sig):
    m = Machine(P.lms_tables(), {S_LEN_MSG: len(msg), S_LEN_CTX: 0, S_FORM: 0, S_LMSTYPE: lt, S_LMOTS: lo, S_HSSLVL: lv},
                {AREA_MSG: msg, AREA_SIG: sig, AREA_PK: pub}, ram_bytes=16384)
    m.run(code, labels['LMS_START'])
    return m


if __name__ == '__main__':
    a = build()
    code = a.resolve(0)
    print('LMS program: %d instructions' % len(code))
    cases = [(0, 3, 1), (0, 3, 2), (0, 2, 1), (0, 1, 3), (0, 0, 1), (5, 7, 1), (10, 11, 2), (15, 14, 1), (6, 6, 1), (11, 10, 2)]
    t0 = time.time()
    for lt, lo, lv in cases:
        msg = b'The enumeration in the new section is needed'
        pub, sig = L.make_hss(lt, lo, lv, msg, q=3 if lv == 1 else 1)
        assert L.hss_verify(lt, lo, lv, pub, msg, sig)
        m = run_lms(code, a.labels, lt, lo, lv, msg, pub, sig)
        assert m.ok, 'LMS type %d ots %d levels %d: the program rejects a valid signature' % (lt, lo, lv)
        bad = bytearray(sig); bad[len(sig) // 2] ^= 8
        assert not run_lms(code, a.labels, lt, lo, lv, msg, pub, bytes(bad)).ok, 'accepts a corrupted signature'
        assert not run_lms(code, a.labels, lt, lo, lv, msg + b'!', pub, sig).ok, 'accepts a wrong message'
        badpub = bytearray(pub); badpub[-1] ^= 1
        assert not run_lms(code, a.labels, lt, lo, lv, msg, bytes(badpub), sig).ok, 'accepts a wrong public key'
        assert not run_lms(code, a.labels, (lt + 1) % 5 + 5 * (lt // 5), lo, lv, msg, pub, sig).ok, 'accepts another LMS type'
        print('lms %2d ots %2d levels %d ok (%d hashes, %d steps, %.0f s)' % (lt, lo, lv, m.nhash, m.steps, time.time() - t0))
