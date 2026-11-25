"""Vectors of the RTL test of the lattice engine (verification/tests/lat/tb_lat.sv).
For vector i: <dir>/lat_v<i>.hex holds the buffer image (one byte per line), <dir>/lat_e<i>.hex the expected result bytes, and line i of
<dir>/lat_vecs.txt the fields: i alg op mode len_msg len_ctx off_msg off_sig off_pk off_res expect_ok exp_len vas nbytes key_hex pool_hex.
alg 9 / 10 / 11 = ML-DSA-44 / 65 / 87; mode = hedged | form << 1 | hash << 3 (form 1: HashML-DSA, the message is the
digest PH(M) and hash is dsig_op.hash); op 0 key generation, 1 sign, 2 verify; vas 1 = run the verify-after-sign afterwards.
Expected values: OpenSSL 3.5 or later (public key from the seed, deterministic signatures, valid signatures); the reference model
also OpenSSL (hextest-entropy) for the hedged signature.
Usage: python gen_lat_vec.py <dir> <set>   (sets: quick, all, prehash)"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mldsa_ref as M
import test_mldsa_ref as T

OFF_MSG, OFF_PK, OFF_SIG, OFF_RES = 0, 4096, 8192, 16384
ALG = {44: 9, 65: 10, 87: 11}


class V:
    def __init__(self, name, level, op, msg=b'', ctx=b'', sig=b'', pk=b'', key=b'', pool=b'', hedged=0, ok=1, exp=b'', vas=0, form=0, hcode=0):
        self.name, self.level, self.op, self.msg, self.ctx, self.sig, self.pk = name, level, op, msg, ctx, sig, pk
        self.key, self.pool, self.hedged, self.ok, self.exp, self.vas = key, pool, hedged, ok, exp, vas
        self.form, self.hcode = form, hcode

    def image(self):
        img = bytearray(OFF_SIG + len(self.sig))
        img[OFF_MSG:OFF_MSG + len(self.msg) + len(self.ctx)] = self.msg + self.ctx
        img[OFF_PK:OFF_PK + len(self.pk)] = self.pk
        img[OFF_SIG:OFF_SIG + len(self.sig)] = self.sig
        return bytes(img)


def ossl_hedged(level, seed, msg, rnd):
    """Hedged signature of OpenSSL with the given 32 random bytes (hextest-entropy)."""
    import tempfile
    d = tempfile.mkdtemp()
    k, m, s = (os.path.join(d, x) for x in ('k.pem', 'm.bin', 's.bin'))
    T.ossl('genpkey', '-algorithm', 'ML-DSA-%d' % level, '-pkeyopt', 'hexseed:' + seed.hex(), '-out', k)
    open(m, 'wb').write(msg)
    T.ossl('pkeyutl', '-sign', '-inkey', k, '-rawin', '-in', m, '-out', s, '-pkeyopt', 'hextest-entropy:' + rnd.hex())
    return open(s, 'rb').read()


def flip(b, i, m=4):
    b = bytearray(b)
    b[i % len(b)] ^= m
    return bytes(b)


def vecs_for(level, full):
    out = []
    seed = bytes((i * 7 + level) % 256 for i in range(32))
    msg = bytes(range(50))
    pk, sig = T.ossl_make(level, seed, msg)
    nm = 'ML-DSA-%d ' % level
    out.append(V(nm + 'key generation', level, 0, key=seed, exp=pk))
    out.append(V(nm + 'verify valid', level, 2, msg=msg, sig=sig, pk=pk, ok=1))
    out.append(V(nm + 'verify corrupted z', level, 2, msg=msg, sig=flip(sig, 40), pk=pk, ok=0))
    out.append(V(nm + 'verify corrupted c', level, 2, msg=msg, sig=flip(sig, 0, 1), pk=pk, ok=0))
    out.append(V(nm + 'verify wrong message', level, 2, msg=flip(msg, 3, 1), sig=sig, pk=pk, ok=0))
    out.append(V(nm + 'verify corrupted hint', level, 2, msg=msg, sig=flip(sig, len(sig) - 3, 1), pk=pk, ok=0))
    out.append(V(nm + 'sign deterministic + verify-after-sign', level, 1, msg=msg, key=seed, exp=sig, vas=1))
    if full:
        ctx = b'hello'
        pk2, sig2 = T.ossl_make(level, seed, b'abc', ctx=ctx)
        out.append(V(nm + 'verify with context', level, 2, msg=b'abc', ctx=ctx, sig=sig2, pk=pk2, ok=1))
        out.append(V(nm + 'sign with context', level, 1, msg=b'abc', ctx=ctx, key=seed, exp=sig2, vas=1))
        rnd = bytes((i * 13 + 5) % 256 for i in range(32))
        key = M.MlDsa(level).keygen(seed)
        hs = ossl_hedged(level, seed, msg, rnd)
        out.append(V(nm + 'sign hedged', level, 1, msg=msg, key=seed, pool=rnd, hedged=1, exp=hs, vas=1))
        out.append(V(nm + 'verify empty message', level, 2, msg=b'', sig=M.MlDsa(level).sign(key, b'\x00\x00'), pk=pk, ok=1))
    return out


def prehash_vecs():
    """HashML-DSA (FIPS 204 algorithms 4 and 5): expected values from OpenSSL with message-encoding 0 over M' built from the
    standard (see test_lat_prehash.py)."""
    import test_lat_prehash as TP
    out = []
    msg = b'firmware image of the prehash test'
    for level, hcode, ctx in ((44, 0, b''), (44, 2, b'ctx-1'), (44, 3, b''), (65, 2, b''), (87, 1, b'')):
        seed = bytes((i * 5 + level) % 256 for i in range(32))
        dig = TP.HASHES[hcode][0](msg).digest()
        pk, sig = TP.ossl_raw(level, seed, TP.mprime(hcode, dig, ctx))
        nm = 'HashML-DSA-%d hash %d%s ' % (level, hcode, ' ctx' if ctx else '')
        out.append(V(nm + 'sign + verify-after-sign', level, 1, msg=dig, ctx=ctx, key=seed, exp=sig, vas=1, form=1, hcode=hcode))
        out.append(V(nm + 'verify valid', level, 2, msg=dig, ctx=ctx, sig=sig, pk=pk, ok=1, form=1, hcode=hcode))
        if level == 44:
            # another hash with the same digest length (SHA-2 <-> SHA3): only the OID in M' differs
            out.append(V(nm + 'verify with another hash code', level, 2, msg=dig, ctx=ctx, sig=sig, pk=pk, ok=0, form=1,
                         hcode=(hcode + 3) % 6))
            out.append(V(nm + 'verify in the pure form', level, 2, msg=dig, ctx=ctx, sig=sig, pk=pk, ok=0, form=0, hcode=hcode))
    return out


def build(name):
    if name == 'prehash':
        return prehash_vecs()
    if name == 'quick':
        return vecs_for(44, False)[:3] + vecs_for(44, False)[6:7]
    out = []
    out += vecs_for(44, True)
    out += vecs_for(65, False)
    out += vecs_for(87, False)
    return out


def main(d, name):
    os.makedirs(d, exist_ok=True)
    vecs = build(name)
    with open(os.path.join(d, 'lat_vecs.txt'), 'w') as fh, open(os.path.join(d, 'lat_names.txt'), 'w') as fn:
        for i, v in enumerate(vecs):
            img = v.image()
            with open(os.path.join(d, 'lat_v%d.hex' % i), 'w') as fx:
                fx.write('\n'.join('%02x' % b for b in img) + '\n')
            with open(os.path.join(d, 'lat_e%d.hex' % i), 'w') as fx:
                fx.write('\n'.join('%02x' % b for b in (v.exp or b'\x00')) + '\n')
            fh.write('%d %d %d %d %d %d %d %d %d %d %d %d %d %d %s %s\n' % (
                i, ALG[v.level], v.op, v.hedged | (v.form << 1) | (v.hcode << 3), len(v.msg), len(v.ctx), OFF_MSG, OFF_SIG, OFF_PK, OFF_RES, v.ok, len(v.exp), v.vas, len(img),
                (v.key or bytes(1)).hex(), (v.pool or bytes(1)).hex()))
            fn.write('%d\t%s\n' % (i, v.name))
    print('%s: %d vectors' % (name, len(vecs)))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
