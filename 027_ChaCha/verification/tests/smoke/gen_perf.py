"""Vector files for the cycle measurement of 027_ChaCha (scratch, not a delivered testbench).

Writes <tag>_in.hex / <tag>_out.hex for every (aad, msg, DW) of the plan, key.hex, nonce.hex and
perf_plan.txt (tag dw aad msg nin nout).
"""
import os
import random
import sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, '..', '..', 'models'))
import chacha20poly1305_ref as m


def beats(b, w):
    return [int.from_bytes(b[i:i + w], 'little') for i in range(0, len(b), w)]


def gen(name, dw, key, nonce, aad, msg):
    w = dw // 8
    ct, tag = m.aead_encrypt(key, nonce, aad, msg)
    inp = beats(aad, w) + beats(msg, w)
    out = beats(ct, w) + beats(tag, w)
    fmt = '%0' + str(dw // 4) + 'x\n'
    open(os.path.join(here, name + '_in.hex'), 'w').write(''.join(fmt % x for x in inp))
    open(os.path.join(here, name + '_out.hex'), 'w').write(''.join(fmt % x for x in out))
    return len(inp), len(out)


rows = [(160, 0), (320, 0), (640, 0), (0, 640), (0, 0), (0, 1), (1, 0), (16, 16), (0, 16), (17, 63), (0, 64), (5, 65), (12, 114), (0, 127), (12, 127), (130, 200), (12, 1280)]
key = bytes(range(0x80, 0xA0))
nonce = bytes.fromhex('070000004041424344454647')
open(os.path.join(here, 'key.hex'), 'w').write('%064x\n' % int.from_bytes(key, 'little'))
open(os.path.join(here, 'nonce.hex'), 'w').write('%024x\n' % int.from_bytes(nonce, 'little'))
random.seed(5)
plan = []
for dw in (32, 64, 128):
    for a, mm in rows:
        A = bytes(random.getrandbits(8) for _ in range(a))
        M = bytes(random.getrandbits(8) for _ in range(mm))
        tag = 'p%d_%d_%d' % (dw, a, mm)
        nin, nout = gen(tag, dw, key, nonce, A, M)
        plan.append('%s %d %d %d %d %d' % (tag, dw, a, mm, nin, nout))
open(os.path.join(here, 'perf_plan.txt'), 'w').write('\n'.join(plan) + '\n')
print(len(plan), 'vector sets')
