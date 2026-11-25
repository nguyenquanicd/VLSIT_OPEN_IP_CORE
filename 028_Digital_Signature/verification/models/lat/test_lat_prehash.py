"""HashML-DSA (FIPS 204 algorithms 4 and 5) in the programs of the lattice processor, against OpenSSL (independent).

The buffer holds the digest PH(M) (prehash form, dsig_op.form = 1) followed by the context. The expected values come from
OpenSSL with message-encoding 0 (the message is used as M' unchanged), where M' is built from FIPS 204 algorithm 4 line 23:
M' = 0x01 || len(ctx) || ctx || OID || PH(M). The DER encodings of the OIDs of SHA-256, SHA-512 and SHAKE128 are given by
FIPS 204; those of SHA-384 and the SHA3 functions follow the same NIST arc 2.16.840.1.101.3.4.2 (x = 2, 8, 9, 10).
Usage: python test_lat_prehash.py [levels]"""
import hashlib
import os
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ltp_isa import *
import lat_prog as P
import test_lat_prog as TL
import test_mldsa_ref as T
import mldsa_ref as M

HASHES = {0: (hashlib.sha256, 1), 1: (hashlib.sha384, 2), 2: (hashlib.sha512, 3), 3: (hashlib.sha3_256, 8),
          4: (hashlib.sha3_384, 9), 5: (hashlib.sha3_512, 10)}
OID_PREFIX = bytes([0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02])


def mprime(hcode, digest, ctx):
    return bytes([1, len(ctx)]) + ctx + OID_PREFIX + bytes([HASHES[hcode][1]]) + digest


def ossl_raw(level, seed, mp, det=True):
    d = tempfile.mkdtemp()
    key, pub, mf, sf = (os.path.join(d, x) for x in ('k.pem', 'p.der', 'm.bin', 's.bin'))
    T.ossl('genpkey', '-algorithm', 'ML-DSA-%d' % level, '-pkeyopt', 'hexseed:' + seed.hex(), '-out', key)
    T.ossl('pkey', '-in', key, '-pubout', '-outform', 'DER', '-out', pub)
    open(mf, 'wb').write(mp)
    T.ossl('pkeyutl', '-sign', '-inkey', key, '-rawin', '-in', mf, '-out', sf, '-pkeyopt', 'message-encoding:0',
           *(['-pkeyopt', 'deterministic:1'] if det else []))
    pk = open(pub, 'rb').read()[-(32 + 320 * M.PARAMS[level]['k']):]
    return pk, open(sf, 'rb').read()


def machine(level, op, dig, ctx, buf, hcode, key=b''):
    snap = {S_LEN_MSG: len(dig), S_LEN_CTX: len(ctx), S_FORM: 1, S_OP: op, S_LEVEL: 9 + {44: 0, 65: 1, 87: 2}[level],
            S_HEDGED: 0, S_HASH: hcode}
    return Machine(param_table(), snap, buf, key, b'', words=P.SCR + 2048)


def main(levels):
    a = TL.build()
    code = a.resolve(0)
    t0 = time.time()
    n = 0
    for level in levels:
        seed = bytes((i * 5 + level) % 256 for i in range(32))
        msg = b'firmware image of the prehash test'
        for hcode, ctx in ((0, b''), (2, b'ctx-1'), (3, b'')) if level == 44 else ((2, b''),):
            dig = HASHES[hcode][0](msg).digest()
            pk, sig = ossl_raw(level, seed, mprime(hcode, dig, ctx))
            # signing (deterministic) equals OpenSSL
            buf = {AREA_MSG: dig + ctx, AREA_RES: bytearray()}
            m = machine(level, 1, dig, ctx, buf, hcode, key=seed)
            TL.run(m, code, a.labels, 'LAT_START')
            assert m.ok and bytes(buf[AREA_RES][:len(sig)]) == sig, 'HashML-DSA-%d hash %d: signature differs from OpenSSL' % (level, hcode)
            # verification of the OpenSSL signature, and rejections
            for tag, d2, h2, want in (('valid', dig, hcode, True), ('other digest', bytes([dig[0] ^ 1]) + dig[1:], hcode, False),
                                      ('other hash code', dig, (hcode + 1) % 3, False)):
                bf = {AREA_MSG: d2 + ctx, AREA_SIG: sig, AREA_PK: pk}
                m = machine(level, 2, d2, ctx, bf, h2)
                TL.run(m, code, a.labels, 'LAT_START')
                assert m.ok == want, 'HashML-DSA-%d hash %d verify %s: got %s' % (level, hcode, tag, m.ok)
            n += 1
            print('HashML-DSA-%d hash %d ctx %r: sign = OpenSSL, verify and rejections ok (%.0f s)' % (level, hcode, ctx, time.time() - t0))
    print('HashML-DSA: %d cases PASS' % n)


if __name__ == '__main__':
    main([int(x) for x in sys.argv[1:]] or [44, 65, 87])
