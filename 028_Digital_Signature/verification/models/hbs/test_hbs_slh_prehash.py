"""HashSLH-DSA verification (FIPS 205 algorithm 25, pre-hash form) in the program of the hash-tree processor, against
OpenSSL (independent). The signature is made by OpenSSL with message-encoding 0 (the message is used as M' unchanged) over
M' = 0x01 || len(ctx) || ctx || OID || PH(M) built from FIPS 205 algorithm 23; the buffer holds PH(M) and the context.
Usage: python test_hbs_slh_prehash.py [set numbers]"""
import hashlib
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from htp_isa import *
import hbs_prog_slh as P
import slh_ref as S
import test_slh_ref as T

HASHES = {0: (hashlib.sha256, 1), 1: (hashlib.sha384, 2), 2: (hashlib.sha512, 3), 3: (hashlib.sha3_256, 8),
          4: (hashlib.sha3_384, 9), 5: (hashlib.sha3_512, 10)}
OID_PREFIX = bytes([0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02])


def make_raw(idx, mp):
    d = tempfile.mkdtemp()
    key, pub, mf, sf = (os.path.join(d, x) for x in ('k.pem', 'p.der', 'm.bin', 's.bin'))
    T.ossl('genpkey', '-algorithm', S.SETS[idx]['name'], '-out', key)
    T.ossl('pkey', '-in', key, '-pubout', '-outform', 'DER', '-out', pub)
    open(mf, 'wb').write(mp)
    T.ossl('pkeyutl', '-sign', '-inkey', key, '-rawin', '-in', mf, '-out', sf, '-pkeyopt', 'message-encoding:0')
    return open(pub, 'rb').read()[-2 * S.SETS[idx]['n']:], open(sf, 'rb').read()


def run(code, labels, idx, dig, ctx, sig, pk, hcode, form=1):
    m = Machine(P.slh_table(), {S_LEN_MSG: len(dig), S_LEN_CTX: len(ctx), S_FORM: form, S_SLH: idx, S_HASH: hcode},
                {AREA_MSG: dig + ctx, AREA_SIG: sig, AREA_PK: pk})
    m.run(code, labels['SLH_START'])
    return m


def main(sets):
    a = Asm()
    P.emit_slh(a)
    code = a.resolve(0)
    n = 0
    for idx in sets:
        for hcode, ctx in ((0, b''), (2, b'boot'), (4, b'')):
            msg = b'image %d' % idx
            dig = HASHES[hcode][0](msg).digest()
            mp = bytes([1, len(ctx)]) + ctx + OID_PREFIX + bytes([HASHES[hcode][1]]) + dig
            pk, sig = make_raw(idx, mp)
            assert run(code, a.labels, idx, dig, ctx, sig, pk, hcode).ok, '%s hash %d: rejects the OpenSSL HashSLH-DSA signature' % (
                S.SETS[idx]['name'], hcode)
            assert not run(code, a.labels, idx, dig, ctx, sig, pk, (hcode + 1) % 6).ok, 'accepts the wrong hash code'
            assert not run(code, a.labels, idx, bytes([dig[0] ^ 1]) + dig[1:], ctx, sig, pk, hcode).ok, 'accepts another digest'
            assert not run(code, a.labels, idx, dig, ctx, sig, pk, hcode, form=0).ok, 'accepts the pure form'
            n += 1
            print('%-22s hash %d ctx %r: HashSLH-DSA ok' % (S.SETS[idx]['name'], hcode, ctx))
    print('HashSLH-DSA: %d cases PASS' % n)


if __name__ == '__main__':
    main([int(x) for x in sys.argv[1:]] or [0, 1, 6, 7])
