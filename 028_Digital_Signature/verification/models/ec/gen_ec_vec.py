"""Vector files of the RTL test of the elliptic-curve engine (verification/tests/ec/tb_ec.sv).

Every vector is a block of 1024 bytes, one byte per line in a $readmemh file:
  0 alg, 1 op (0 key generation, 1 sign, 2 verify, 3 sign then verify-after-sign, 4 sign, corrupt, then
  verify-after-sign), 2 hash of dsig_op.hash, 4..7 len_msg, 8..9 expected dsig_err flags, 10 expected
  result of the check (sigok or vas ok), 11 number of result bytes to compare, 12 deterministic ECDSA nonce (1: RFC 6979, no pool),
  16..83 key (68 bytes), 84..179 random pool (96 bytes), 192..391 message, 400..539 signature area,
  544..683 public key area, 688..827 expected result area.
The expected values are independent of the RTL: the RFC 8032 and RFC 6979 vectors, the verdict that a
corrupted input must be rejected, and the textbook group law of ec_curves.py (secp256k1).
Usage: python gen_ec_vec.py <set> <out.hex> <manifest.txt>   (sets: ed25519 ed448 edvar det ct p256 p384 p521 k256 quick)"""
import hashlib
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ec_curves import CURVES, mul
import test_ec_model as T

BLK = 1024
ALG = {'Ed25519': 0, 'Ed25519ctx': 1, 'Ed25519ph': 2, 'Ed448': 3, 'Ed448ph': 4, 'P-256': 5, 'P-384': 6, 'P-521': 7, 'secp256k1': 8}
HASHF = [hashlib.sha256, hashlib.sha384, hashlib.sha512]


class Vec:
    def __init__(self, name, curve, op, hash_=0, msg=b'', sig=b'', pk=b'', key=b'', pool=b'', exp_ok=0, exp_err=0, exp_res=b'', ctx=b'', det=0):
        self.name, self.curve, self.op, self.hash = name, curve, op, hash_
        self.msg, self.sig, self.pk, self.key, self.pool = msg, sig, pk, key, pool
        self.exp_ok, self.exp_err, self.exp_res = exp_ok, exp_err, exp_res
        self.ctx = ctx
        self.det = det

    def block(self):
        b = bytearray(BLK)
        b[0], b[1], b[2] = ALG[self.curve], self.op, self.hash
        b[3] = len(self.ctx)
        b[4:8] = len(self.msg).to_bytes(4, 'little')
        b[8:10] = self.exp_err.to_bytes(2, 'little')
        b[10], b[11] = self.exp_ok, len(self.exp_res)
        b[12] = self.det
        assert len(self.key) <= 68 and len(self.pool) <= 96 and len(self.msg) + len(self.ctx) <= 200 and len(self.sig) <= 140
        assert len(self.pk) <= 140 and len(self.exp_res) <= 140
        b[16:16 + len(self.key)] = self.key
        b[84:84 + len(self.pool)] = self.pool
        b[192:192 + len(self.msg) + len(self.ctx)] = self.msg + self.ctx
        b[400:400 + len(self.sig)] = self.sig
        b[544:544 + len(self.pk)] = self.pk
        b[688:688 + len(self.exp_res)] = self.exp_res
        return bytes(b)


def flip(b, i, m=1):
    b = bytearray(b)
    b[i] ^= m
    return bytes(b)


def ed_set(name, vecs, nb, big):
    out = []
    c = name
    for n, (sk, pk, msg, sig) in enumerate(vecs):
        tag = '%s rfc%d' % (name, n)
        out.append(Vec(tag + ' verify ok', c, 2, msg=msg, sig=sig, pk=pk, exp_ok=1))
        if msg:
            out.append(Vec(tag + ' verify bad msg', c, 2, msg=flip(msg, 0), sig=sig, pk=pk, exp_ok=0))
        out.append(Vec(tag + ' verify bad S', c, 2, msg=msg, sig=flip(sig, nb + 5, 4), pk=pk, exp_ok=0))
        out.append(Vec(tag + ' verify bad R', c, 2, msg=msg, sig=flip(sig, 3, 1), pk=pk, exp_ok=0))
        out.append(Vec(tag + ' sign', c, 1, msg=msg, key=sk, exp_ok=1, exp_res=sig))
        out.append(Vec(tag + ' keygen', c, 0, key=sk, exp_ok=1, exp_res=pk))
        out.append(Vec(tag + ' sign+vas', c, 3, msg=msg, key=sk, exp_ok=1, exp_res=sig))
        out.append(Vec(tag + ' sign+corrupt+vas', c, 4, msg=msg, key=sk, exp_ok=0))
        if n == 0:
            cv = CURVES[name]
            s_big = int.from_bytes(sig[nb:2 * nb], 'little')
            bad = sig[:nb] + cv.n.to_bytes(nb, 'little')
            out.append(Vec(tag + ' verify S = L', c, 2, msg=msg, sig=bad, pk=pk, exp_ok=0))
            ybad = (cv.p + 1).to_bytes(nb, 'little')
            out.append(Vec(tag + ' verify non-canonical A', c, 2, msg=msg, sig=sig, pk=ybad, exp_ok=0))
    return out


def edvar_set():
    """Ed25519ctx, Ed25519ph, Ed448 with a context and Ed448ph (RFC 8032 sections 7.2 to 7.5). The message of the ph forms is the
    digest PH(M); the context stands right after the message in the buffer."""
    out = []
    for n, (cname, sk, pk, msg, ctx, f, sig) in enumerate(T.ed_variant_cases()):
        alg = {('Ed25519', 0): 'Ed25519ctx', ('Ed25519', 1): 'Ed25519ph', ('Ed448', 0): 'Ed448', ('Ed448', 1): 'Ed448ph'}[(cname, f)]
        nb = 32 if cname == 'Ed25519' else 57
        tag = '%s var%d' % (alg, n)
        out.append(Vec(tag + ' verify ok', alg, 2, msg=msg, ctx=ctx, sig=sig, pk=pk, exp_ok=1))
        out.append(Vec(tag + ' verify bad msg', alg, 2, msg=flip(msg, 0), ctx=ctx, sig=sig, pk=pk, exp_ok=0))
        if ctx:
            out.append(Vec(tag + ' verify bad ctx', alg, 2, msg=msg, ctx=flip(ctx, 0), sig=sig, pk=pk, exp_ok=0))
            out.append(Vec(tag + ' verify ctx dropped', alg, 2, msg=msg, ctx=b'', sig=sig, pk=pk, exp_ok=0))
        out.append(Vec(tag + ' verify bad S', alg, 2, msg=msg, ctx=ctx, sig=flip(sig, nb + 5, 4), pk=pk, exp_ok=0))
        out.append(Vec(tag + ' sign', alg, 1, msg=msg, ctx=ctx, key=sk, exp_ok=1, exp_res=sig))
        out.append(Vec(tag + ' keygen', alg, 0, key=sk, ctx=ctx, exp_ok=1, exp_res=pk))
        out.append(Vec(tag + ' sign+vas', alg, 3, msg=msg, ctx=ctx, key=sk, exp_ok=1, exp_res=sig))
        out.append(Vec(tag + ' sign+corrupt+vas', alg, 4, msg=msg, ctx=ctx, key=sk, exp_ok=0))
    return out


def ecdsa_set(cname, per_curve=None):
    out = []
    c = CURVES[cname]
    nb = c.nbytes
    used = {}
    for (cn, x, ux, uy, hop, msg, k, r, s) in T.ecdsa_vectors():
        if cn != cname:
            continue
        key = (hop, msg)
        if per_curve is not None and (hop, msg) not in per_curve:
            continue
        tag = '%s hash%d %s' % (cname, hop, msg.decode())
        xb = x.to_bytes(nb, 'big')
        sig = r.to_bytes(nb, 'big') + s.to_bytes(nb, 'big')
        pk = ux.to_bytes(nb, 'big') + uy.to_bytes(nb, 'big')
        pool = (k - 1).to_bytes(nb, 'big') + bytes(8)
        out.append(Vec(tag + ' verify ok', cname, 2, hash_=hop, msg=msg, sig=sig, pk=pk, exp_ok=1))
        out.append(Vec(tag + ' verify bad msg', cname, 2, hash_=hop, msg=flip(msg, 0), sig=sig, pk=pk, exp_ok=0))
        out.append(Vec(tag + ' verify bad s', cname, 2, hash_=hop, msg=msg, sig=flip(sig, nb + 3, 8), pk=pk, exp_ok=0))
        out.append(Vec(tag + ' sign', cname, 1, hash_=hop, msg=msg, key=xb, pool=pool, exp_ok=1, exp_res=sig))
        if len(used) == 0:
            out.append(Vec(tag + ' keygen', cname, 0, key=xb, pool=b'', exp_ok=1, exp_res=pk))
            out.append(Vec(tag + ' sign+vas', cname, 3, hash_=hop, msg=msg, key=xb, pool=pool, exp_ok=1, exp_res=sig))
            out.append(Vec(tag + ' sign+corrupt+vas', cname, 4, hash_=hop, msg=msg, key=xb, pool=pool, exp_ok=0))
            out.append(Vec(tag + ' verify r = 0', cname, 2, hash_=hop, msg=msg, sig=bytes(nb) + sig[nb:], pk=pk, exp_ok=0))
            out.append(Vec(tag + ' verify s = n', cname, 2, hash_=hop, msg=msg, sig=sig[:nb] + c.n.to_bytes(nb, 'big'), pk=pk, exp_ok=0))
            badpk = pk[:-1] + bytes([pk[-1] ^ 1])
            out.append(Vec(tag + ' verify point not on curve', cname, 2, hash_=hop, msg=msg, sig=sig, pk=badpk, exp_ok=0))
            out.append(Vec(tag + ' sign d = 0 (BADKEY)', cname, 1, hash_=hop, msg=msg, key=bytes(nb), pool=pool, exp_ok=0, exp_err=8))
            out.append(Vec(tag + ' sign d = n (BADKEY)', cname, 1, hash_=hop, msg=msg, key=c.n.to_bytes(nb, 'big'), pool=pool, exp_ok=0, exp_err=8))
        used[key] = 1
    return out


def det_set():
    """ECDSA signing with the deterministic nonce of RFC 6979 computed by the engine: every RFC 6979 vector of A.2.5 to A.2.7
    (SHA-256, SHA-384, SHA-512), no random pool; the signature must equal the vector. One verify-after-sign per curve."""
    out = []
    seen = set()
    for (cn, x, ux, uy, hop, msg, k, r, s) in T.ecdsa_vectors():
        c = CURVES[cn]
        nb = c.nbytes
        sig = r.to_bytes(nb, 'big') + s.to_bytes(nb, 'big')
        tag = '%s hash%d %s det' % (cn, hop, msg.decode())
        out.append(Vec(tag + ' sign', cn, 1, hash_=hop, msg=msg, key=x.to_bytes(nb, 'big'), exp_ok=1, exp_res=sig, det=1))
        if cn not in seen:
            seen.add(cn)
            if cn in ('P-384', 'P-521'):
                # key generation uses no hash: the curve and hash pairing must not reject it (hash code 0)
                out.append(Vec('%s keygen with hash code 0' % cn, cn, 0, hash_=0, key=x.to_bytes(nb, 'big'), exp_ok=1,
                               exp_res=ux.to_bytes(nb, 'big') + uy.to_bytes(nb, 'big')))
            out.append(Vec(tag + ' sign+vas', cn, 3, hash_=hop, msg=msg, key=x.to_bytes(nb, 'big'), exp_ok=1, exp_res=sig, det=1))
    # secp256k1 has no RFC 6979 vector: the nonce comes from the reference of RFC 6979 section 3.2 in test_rfc6979_retry.py
    # (written from the text) and the signature from the textbook group law
    import test_rfc6979_retry as R6
    c = CURVES['secp256k1']
    for hop, hname in ((0, 'sha256'), (1, 'sha384'), (2, 'sha512')):
        d = 0x1E99423A4ED27608A15A2616A2B0E9E52CED330AC530EDCC32C8FFC6A526AEDD + hop
        msg = b'deterministic secp256k1 %d' % hop
        h1 = getattr(hashlib, hname)(msg).digest()
        k, _ = R6.ref_k(d, h1, c.n, 256, hname, c.n)
        e = R6.bits2int(h1, 256) % c.n
        Rp = mul(c, k, (c.gx, c.gy))
        r = Rp[0] % c.n
        s = pow(k, -1, c.n) * (e + r * d) % c.n
        sig = r.to_bytes(32, 'big') + s.to_bytes(32, 'big')
        out.append(Vec('secp256k1 hash%d det sign' % hop, 'secp256k1', 1, hash_=hop, msg=msg, key=d.to_bytes(32, 'big'), exp_ok=1,
                       exp_res=sig, det=1))
    return out


def ed_pub(cname, seed):
    """Public key from the definition of RFC 8032 sections 5.1.5 and 5.2.5 with the textbook Edwards group law of
    ec_curves.py (independent of the engine programs)."""
    c = CURVES[cname]
    if cname == 'Ed25519':
        h = hashlib.sha512(seed).digest()[:32]
        a = bytearray(h); a[0] &= 248; a[31] &= 127; a[31] |= 64
    else:
        h = hashlib.shake_256(seed).digest(114)[:57]
        a = bytearray(h); a[0] &= 252; a[55] |= 128; a[56] = 0
    s = int.from_bytes(a, 'little')
    x, y = mul(c, s, (c.gx, c.gy))
    nb = c.nbytes
    return (y | ((x & 1) << (8 * nb - 1))).to_bytes(nb, 'little')


def ct_set():
    """REQ-SEC-002: key generation with three keys of very different Hamming weight per curve (ECDSA: d = 1, n - 1, random;
    EdDSA: three random seeds) and ECDSA signing with the nonces k = 1, n - 1 and a random one. The test bench checks the
    results (textbook group law) and that the cycle count is the same inside each group of curve and operation."""
    out = []
    rnd = random.Random(6979)
    for cname in ('Ed25519', 'Ed448'):
        for i in range(3):
            seed = bytes(rnd.randrange(256) for _ in range(CURVES[cname].nbytes))
            out.append(Vec('%s ct keygen %d' % (cname, i), cname, 0, key=seed, exp_ok=1, exp_res=ed_pub(cname, seed)))
    msg = b'constant time'
    for cname in ('P-256', 'P-384', 'P-521', 'secp256k1'):
        c = CURVES[cname]
        nb = c.nbytes
        hop = {'P-384': 1, 'P-521': 2}.get(cname, 0)
        e = int.from_bytes(HASHF[hop](msg).digest(), 'big')
        hl = 8 * HASHF[hop]().digest_size
        if hl > c.nbits:
            e >>= hl - c.nbits
        for i, d in enumerate((1, c.n - 1, rnd.randrange(2, c.n - 1))):
            Q = mul(c, d, (c.gx, c.gy))
            out.append(Vec('%s ct keygen d%d' % (cname, i), cname, 0, hash_=hop, key=d.to_bytes(nb, 'big'), exp_ok=1,
                           exp_res=Q[0].to_bytes(nb, 'big') + Q[1].to_bytes(nb, 'big')))
        d = rnd.randrange(2, c.n - 1)
        for i, k in enumerate((1, c.n - 1, rnd.randrange(2, c.n - 1))):
            Rp = mul(c, k, (c.gx, c.gy))
            r = Rp[0] % c.n
            sg = pow(k, -1, c.n) * (e % c.n + r * d) % c.n
            pool = (k - 1).to_bytes(nb, 'big') + bytes(8)
            out.append(Vec('%s ct sign k%d' % (cname, i), cname, 1, hash_=hop, msg=msg, key=d.to_bytes(nb, 'big'), pool=pool,
                           exp_ok=1, exp_res=r.to_bytes(nb, 'big') + sg.to_bytes(nb, 'big')))
    return out


def k256_set():
    out = []
    c = CURVES['secp256k1']
    rnd = random.Random(11)
    nb = 32
    for i in range(3):
        d = rnd.randrange(1, c.n)
        k = rnd.randrange(1, c.n - 1)
        msg = bytes(rnd.randrange(256) for _ in range(20 + 9 * i))
        e = int.from_bytes(hashlib.sha256(msg).digest(), 'big')
        R = mul(c, k, (c.gx, c.gy))
        r = R[0] % c.n
        s = pow(k, -1, c.n) * (e + r * d) % c.n
        Q = mul(c, d, (c.gx, c.gy))
        sig = r.to_bytes(nb, 'big') + s.to_bytes(nb, 'big')
        pk = Q[0].to_bytes(nb, 'big') + Q[1].to_bytes(nb, 'big')
        pool = (k - 1).to_bytes(nb, 'big') + bytes(8)
        tag = 'secp256k1 rnd%d' % i
        out.append(Vec(tag + ' verify ok', 'secp256k1', 2, msg=msg, sig=sig, pk=pk, exp_ok=1))
        out.append(Vec(tag + ' verify bad msg', 'secp256k1', 2, msg=flip(msg, 1), sig=sig, pk=pk, exp_ok=0))
        out.append(Vec(tag + ' sign', 'secp256k1', 1, msg=msg, key=d.to_bytes(nb, 'big'), pool=pool, exp_ok=1, exp_res=sig))
        if i == 0:
            out.append(Vec(tag + ' keygen', 'secp256k1', 0, key=d.to_bytes(nb, 'big'), exp_ok=1, exp_res=pk))
            out.append(Vec(tag + ' sign+vas', 'secp256k1', 3, msg=msg, key=d.to_bytes(nb, 'big'), pool=pool, exp_ok=1, exp_res=sig))
            out.append(Vec(tag + ' sign+corrupt+vas', 'secp256k1', 4, msg=msg, key=d.to_bytes(nb, 'big'), pool=pool, exp_ok=0))
    return out


OPENSSL = os.environ.get('OPENSSL', 'C:/Users/PC/Tools/msys64/usr/bin/openssl.exe')
CURVE_OID = {'P-256': '06082a8648ce3d030107', 'P-384': '06052b81040022', 'P-521': '06052b81040023',
             'secp256k1': '06052b8104000a'}


def _der(tag, body):
    n = len(body)
    ln = bytes([n]) if n < 128 else (bytes([0x81, n]) if n < 256 else bytes([0x82, n >> 8, n & 255]))
    return bytes([tag]) + ln + body


def _der_int(v):
    b = v.to_bytes((v.bit_length() + 8) // 8, 'big')
    return _der(0x02, b)


def openssl_verify(cname, qx, qy, msg, r, s, hname):
    """Independent check of an ECDSA signature with OpenSSL (dgst -verify over the message with the SHA3 hash)."""
    import subprocess
    import tempfile
    nb = CURVES[cname].nbytes
    spki = _der(0x30, _der(0x30, bytes.fromhex('06072a8648ce3d0201' + CURVE_OID[cname])) +
                _der(0x03, b'\x00\x04' + qx.to_bytes(nb, 'big') + qy.to_bytes(nb, 'big')))
    sig = _der(0x30, _der_int(r) + _der_int(s))
    with tempfile.TemporaryDirectory() as d:
        open(d + '/pub.der', 'wb').write(spki)
        open(d + '/sig.der', 'wb').write(sig)
        open(d + '/msg.bin', 'wb').write(msg)
        p = subprocess.run([OPENSSL, 'dgst', '-' + hname.replace('_', '-'), '-verify', d + '/pub.der', '-keyform', 'DER',
                            '-signature', d + '/sig.der', d + '/msg.bin'], capture_output=True, text=True)
    return 'Verified OK' in p.stdout


def sha3_set():
    """DEC-018: ECDSA with the SHA3 hashes (dsig_op.hash 3, 4, 5 = SHA3-256, SHA3-384, SHA3-512) and a given nonce (pool).
    The signature is computed with the textbook group law (e = leftmost bits of the digest, FIPS 186-5 section 6.4.1) and
    then checked by OpenSSL (dgst -verify); a vector that OpenSSL does not verify stops the generator. Per pair: verify ok,
    verify with a changed message, sign (the result must equal the signature)."""
    out = []
    rnd = random.Random(3202)
    pairs = [('P-256', 3, 'sha3_256'), ('P-384', 4, 'sha3_384'), ('P-521', 5, 'sha3_512'), ('P-256', 5, 'sha3_512'),
             ('secp256k1', 3, 'sha3_256'), ('P-256', 4, 'sha3_384'), ('P-384', 5, 'sha3_512'), ('secp256k1', 1, 'sha384'),
             ('secp256k1', 2, 'sha512'), ('secp256k1', 4, 'sha3_384'), ('secp256k1', 5, 'sha3_512')]
    for cname, hop, hname in pairs:
        c = CURVES[cname]
        nb = c.nbytes
        d = rnd.randrange(1, c.n)
        k = rnd.randrange(2, c.n - 1)
        msg = b'ECDSA %s with %s' % (cname.encode(), hname.encode())
        dig = getattr(hashlib, hname)(msg).digest()
        e = int.from_bytes(dig, 'big') >> max(0, 8 * len(dig) - c.n.bit_length())
        R = mul(c, k, (c.gx, c.gy))
        r = R[0] % c.n
        s = pow(k, -1, c.n) * (e + r * d) % c.n
        Q = mul(c, d, (c.gx, c.gy))
        assert openssl_verify(cname, Q[0], Q[1], msg, r, s, hname), ('OpenSSL rejects', cname, hname)
        sig = r.to_bytes(nb, 'big') + s.to_bytes(nb, 'big')
        pk = Q[0].to_bytes(nb, 'big') + Q[1].to_bytes(nb, 'big')
        pool = (k - 1).to_bytes(nb, 'big') + bytes(8)
        tag = '%s %s' % (cname, hname)
        out.append(Vec(tag + ' verify ok', cname, 2, hash_=hop, msg=msg, sig=sig, pk=pk, exp_ok=1))
        out.append(Vec(tag + ' verify bad msg', cname, 2, hash_=hop, msg=flip(msg, 2), sig=sig, pk=pk, exp_ok=0))
        out.append(Vec(tag + ' sign', cname, 1, hash_=hop, msg=msg, key=d.to_bytes(nb, 'big'), pool=pool, exp_ok=1, exp_res=sig))
    return out


def build(setname):
    ed25519 = T.ed25519_vectors()
    ed448 = T.ed448_vectors()
    if setname == 'ed25519':
        return ed_set('Ed25519', ed25519, 32, False)
    if setname == 'ed448':
        return ed_set('Ed448', ed448, 57, True)
    if setname == 'ct':
        return ct_set()
    if setname == 'det':
        return det_set()
    if setname == 'edvar':
        return edvar_set()
    if setname == 'p256':
        return ecdsa_set('P-256')
    if setname == 'p384':
        return ecdsa_set('P-384', per_curve=[(1, b'sample'), (2, b'test')])
    if setname == 'p521':
        return ecdsa_set('P-521', per_curve=[(2, b'sample')])
    if setname == 'p384full':
        return ecdsa_set('P-384')
    if setname == 'p521full':
        return ecdsa_set('P-521')
    if setname == 'k256':
        return k256_set()
    if setname == 'sha3':
        return sha3_set()
    if setname == 'quick':
        return (ed_set('Ed25519', ed25519[:1], 32, False)[:6] + ecdsa_set('P-256', per_curve=[(0, b'sample')])[:4])
    raise SystemExit('unknown set ' + setname)


def main(setname, out, manifest):
    vecs = build(setname)
    with open(out, 'w') as fh:
        for v in vecs:
            for byte in v.block():
                fh.write('%02x\n' % byte)
    with open(manifest, 'w') as fh:
        for i, v in enumerate(vecs):
            fh.write('%d\t%s\n' % (i, v.name))
    print('%s: %d vectors' % (setname, len(vecs)))


if __name__ == '__main__':
    main(*sys.argv[1:4])
