"""Test of the retry path of the RFC 6979 nonce program (ec_progs.rfc6979_k).

The RFC 6979 vectors never produce a candidate k outside [1, q-1], so the retry branch of section 3.2 step h.3 is not
exercised by them. Here the constant N of the curve is replaced by a smaller value (q' about 2^(qlen-1)), so that about
half of the candidates are rejected; the program (stopped right after k is found) must return the k of a reference
implementation of RFC 6979 section 3.2 written from the text with the same q'. qlen stays the bit length of the real
order (the program takes it from the curve), which is what the reference uses too. The
reduction of h1 (step a, bits2octets) uses the real order in the program (SETM selects the curve modulus), so the
reference reduces h1 by the real order as well; only the acceptance test of k uses q'."""
import hashlib
import hmac
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ec_curves import CURVES
from ec_isa import *
import ec_progs as P

HN = {H_SHA256: 'sha256', H_SHA384: 'sha384', H_SHA512: 'sha512'}


def bits2int(b, qlen):
    v = int.from_bytes(b, 'big')
    blen = 8 * len(b)
    return v >> (blen - qlen) if blen > qlen else v


def ref_k(x, h1, q, qlen, hname, zmod):
    """RFC 6979 section 3.2 (steps a to h) with modulus q and bit length qlen; returns (k, number of rejected candidates)."""
    rlen = (qlen + 7) // 8
    hlen = hashlib.new(hname).digest_size
    xo = x.to_bytes(rlen, 'big')
    z = bits2int(h1, qlen) % zmod
    zo = z.to_bytes(rlen, 'big')
    V = b'\x01' * hlen
    K = b'\x00' * hlen
    K = hmac.new(K, V + b'\x00' + xo + zo, hname).digest()
    V = hmac.new(K, V, hname).digest()
    K = hmac.new(K, V + b'\x01' + xo + zo, hname).digest()
    V = hmac.new(K, V, hname).digest()
    rej = 0
    while True:
        T = b''
        while len(T) < rlen:
            V = hmac.new(K, V, hname).digest()
            T += V
        k = bits2int(T[:rlen], qlen)
        if 1 <= k < q:
            return k, rej
        rej += 1
        K = hmac.new(K, V + b'\x00', hname).digest()
        V = hmac.new(K, V, hname).digest()


def run_kgen(c, hmode, q, x, msg):
    a = Asm()
    a.label('START')
    a.setm(SEL_P)
    a.ldk(25, 0, c.nbytes, BE)
    a.hdclr(); a.hgo(hmode, 1)
    a.hrdv(26); a.trunce(26, 26)
    a.setm(SEL_N); a.red(26, 26); a.setm(SEL_P)
    P.rfc6979_k(a, c, hmode)
    a.end()
    consts = dict(P.consts(c))
    consts['N'] = q
    buf = bytearray(1024)
    buf[0:len(msg)] = msg
    m = Machine(c, consts, {}, buf, x.to_bytes(c.nbytes, 'big'), b'', {AREA_MSG: 0, AREA_SIG: 200, AREA_PK: 400, AREA_RES: 600},
                len(msg), 0)
    m.run(P.assemble(a))
    return m.R[30]


def main():
    total = rejected = 0
    for cname in ('P-256', 'P-384', 'P-521', 'secp256k1'):
        c = CURVES[cname]
        q = (1 << (c.nbits - 1)) + 12345           # smaller order: about half of the candidates are rejected
        for hmode in (H_SHA256, H_SHA384, H_SHA512):
            for i in range(4):
                x = (0x1234567 * (i + 3) + c.nbits) % q
                msg = b'retry test %d %s' % (i, cname.encode())
                h1 = hashlib.new(HN[hmode], msg).digest()
                kr, rej = ref_k(x, h1, q, c.nbits, HN[hmode], c.n)
                kp = run_kgen(c, hmode, q, x, msg)
                assert kp == kr, '%s hash %d case %d: program k differs from the reference (%d rejections)' % (cname, hmode, i, rej)
                total += 1
                rejected += rej
    assert rejected > 0, 'no case exercised the retry path'
    print('RFC 6979 retry path: %d cases equal to the reference, %d rejected candidates in total' % (total, rejected))


if __name__ == '__main__':
    main()
