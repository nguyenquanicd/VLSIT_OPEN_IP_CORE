"""Tests of the model of the elliptic-curve engine against independent vectors: RFC 8032 section 7.1
(Ed25519) and RFC 6979 appendix A.2 (ECDSA P-256, P-384, P-521: key pair, message, k, r, s; the
signature is also checked with a verification of a corrupted message).
The vectors are read from the converted standards of the skill vlsit-asic-ip-microspec."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ec_curves import CURVES
from ec_isa import *
import ec_progs as P

MD = os.path.expanduser('~/.claude/skills/vlsit-asic-ip-microspec/reference/md_doc')


def machine(c, asm, buf, key=b'', pool=b'', msg_len=0, op_hash=0, offs=None):
    code = P.assemble(asm)
    m = Machine(c, P.consts(c), {}, buf, key, pool, offs or {AREA_MSG: 0, AREA_SIG: 200, AREA_PK: 400, AREA_RES: 600}, msg_len, op_hash)
    return m, code


def run(c, asm, buf, **kw):
    m, code = machine(c, asm, buf, **kw)
    m.run(code)
    return m


def _clean(sec):
    return '\n'.join(l for l in sec.split('\n') if not l.startswith('Josefsson') and not l.startswith('RFC 8032'))


def ed448_vectors():
    txt = open(os.path.join(MD, 'vlsit_eddsa_rfc8032.md'), encoding='utf-8').read()
    i = txt.rindex('7.4.  Test Vectors for Ed448\n')
    sec = _clean(txt[i:txt.index('7.5.  Test Vectors for Ed448ph\n', i)])
    out = []
    for blk in sec.split('   -----')[1:]:
        if 'CONTEXT' in blk:
            continue
        def field(name):
            m = re.search(name + r':\n((?:\s+[0-9a-f]+\n)+)', blk)
            return bytes.fromhex(''.join(m.group(1).split())) if m else b''
        sk, pk, sig = field('SECRET KEY'), field('PUBLIC KEY'), field('SIGNATURE')
        mm = re.search(r'MESSAGE \(length (\d+) bytes?\):\n((?:\s+[0-9a-f]+\n)*)', blk)
        msg = bytes.fromhex(''.join(mm.group(2).split())) if mm else b''
        if len(sk) == 57 and len(msg) <= 120 and len(sig) == 114:
            out.append((sk, pk, msg, sig))
    return out


def test_ed448():
    c = CURVES['Ed448']
    n = 0
    for sk, pk, msg, sig in ed448_vectors():
        buf = bytearray(1024)
        buf[0:len(msg)] = msg
        buf[200:314] = sig
        buf[400:457] = pk
        kw = dict(msg_len=len(msg))
        def runit(op, b, **extra):
            code = P.assemble(P.prog_ed448(c, op))
            m = Machine(c, P.consts(c), P.STRINGS, b, extra.get('key', b''), b'', {AREA_MSG: 0, AREA_SIG: 200, AREA_PK: 400, AREA_RES: 600}, len(msg), 0)
            m.run(code)
            return m
        assert runit('verify', buf).ok, 'Ed448 verify rejects vector %d' % n
        bad = bytearray(buf); bad[200 + 70] ^= 2
        assert not runit('verify', bad).ok, 'Ed448 accepts a corrupted S'
        m = runit('sign', buf, key=sk)
        assert bytes(m.buf[600:714]) == sig, 'Ed448 sign differs from vector %d' % n
        m = runit('keygen', buf, key=sk)
        assert bytes(m.buf[600:657]) == pk, 'Ed448 public key differs from vector %d' % n
        n += 1
    print('Ed448: %d vectors verify, sign and keygen OK' % n)


def ed25519_vectors():
    txt = open(os.path.join(MD, 'vlsit_eddsa_rfc8032.md'), encoding='utf-8').read()
    sec = txt[txt.index('7.1.  Test Vectors for Ed25519\n\n   These'):txt.index('7.2.  Test Vectors for Ed25519ctx\n\n   ')]
    out = []
    for blk in sec.split('-----TEST ')[1:]:
        def field(name):
            m = re.search(name + r':\n((?:   [0-9a-f]+\n)+)', blk)
            return bytes.fromhex(''.join(m.group(1).split())) if m else b''
        sk, pk, sig = field('SECRET KEY'), field('PUBLIC KEY'), field('SIGNATURE')
        mm = re.search(r'MESSAGE \(length (\d+) bytes?\):\n((?:   [0-9a-f]+\n)*)', blk)
        msg = bytes.fromhex(''.join(mm.group(2).split())) if mm else b''
        if len(msg) <= 120:
            out.append((sk, pk, msg, sig))
    return out


def test_ed25519():
    c = CURVES['Ed25519']
    n = 0
    for sk, pk, msg, sig in ed25519_vectors():
        buf = bytearray(1024)
        buf[0:len(msg)] = msg
        buf[200:264] = sig
        buf[400:432] = pk
        m = run(c, P.prog_ed(c, 'verify'), buf, msg_len=len(msg))
        assert m.ok, 'Ed25519 verify rejects a valid signature (vector %d)' % n
        # corrupted message
        bad = bytearray(buf)
        bad[0] ^= 1 if msg else 0
        if msg:
            m = run(c, P.prog_ed(c, 'verify'), bad, msg_len=len(msg))
            assert not m.ok, 'accepts a corrupted message'
        bad = bytearray(buf)
        bad[200 + 40] ^= 4
        m = run(c, P.prog_ed(c, 'verify'), bad, msg_len=len(msg))
        assert not m.ok, 'accepts a corrupted S'
        # sign and keygen
        m = run(c, P.prog_ed(c, 'sign'), buf, key=sk, msg_len=len(msg))
        assert bytes(m.buf[600:664]) == sig, 'Ed25519 sign differs from the vector %d' % n
        m = run(c, P.prog_ed(c, 'keygen'), buf, key=sk)
        assert bytes(m.buf[600:632]) == pk, 'Ed25519 public key differs from the vector %d' % n
        ms = run(c, P.prog_ed(c, 'sign'), buf, key=sk, msg_len=len(msg))
        mv = run(c, P.prog_ed(c, 'verify', vas=True), ms.buf, key=sk, msg_len=len(msg))
        assert mv.ok, 'Ed25519 verify-after-sign rejects the signature'
        bb = bytearray(ms.buf); bb[600 + 5] ^= 1
        assert not run(c, P.prog_ed(c, 'verify', vas=True), bb, key=sk, msg_len=len(msg)).ok
        n += 1
    print('Ed25519: %d vectors verify, sign and keygen OK' % n)


def eddsa_variant_vectors(first, last, with_ctx_only=False):
    """RFC 8032 vectors of a section (7.2, 7.3, 7.5) and the context vectors of 7.4: (sk, pk, msg, ctx, sig)."""
    txt = open(os.path.join(MD, 'vlsit_eddsa_rfc8032.md'), encoding='utf-8').read()
    i = txt.rindex(first)
    j = txt.index(last, i) if last else txt.index('8.  Security Considerations', i)
    sec = _clean(txt[i:j])
    out = []
    for blk in sec.split('   -----')[1:]:
        if 'ALGORITHM' not in blk:
            continue
        def field(name):
            m = re.search(name + r':\n((?:\s+[0-9a-f]+\n)+)', blk)
            return bytes.fromhex(''.join(m.group(1).split())) if m else b''
        mm = re.search(r'MESSAGE \(length (\d+) bytes?\):\n((?:\s+[0-9a-f]+\n)*)', blk)
        msg = bytes.fromhex(''.join(mm.group(2).split())) if mm else b''
        ctx = field('CONTEXT')
        alg = re.search(r'ALGORITHM:\n\s+(\S+)', blk).group(1)
        if with_ctx_only and not ctx:
            continue
        if alg == 'Ed448' and len(msg) > 120:
            continue
        out.append((alg, field('SECRET KEY'), field('PUBLIC KEY'), msg, ctx, field('SIGNATURE')))
    return out


def ed_variant_cases():
    """All Ed25519ctx, Ed25519ph, Ed448 (context) and Ed448ph vectors of RFC 8032: (curve, sk, pk, msg_in_buffer, ctx, f, sig).
    For the ph variants the message of the buffer is the digest PH(M)."""
    import hashlib
    out = []
    for alg, sk, pk, msg, ctx, sig in eddsa_variant_vectors('7.2.  Test Vectors for Ed25519ctx\n', '7.3.  Test Vectors for Ed25519ph\n'):
        out.append(('Ed25519', sk, pk, msg, ctx, 0, sig))
    for alg, sk, pk, msg, ctx, sig in eddsa_variant_vectors('7.3.  Test Vectors for Ed25519ph\n', '7.4.  Test Vectors for Ed448\n'):
        out.append(('Ed25519', sk, pk, hashlib.sha512(msg).digest(), ctx, 1, sig))
    for alg, sk, pk, msg, ctx, sig in eddsa_variant_vectors('7.4.  Test Vectors for Ed448\n', '7.5.  Test Vectors for Ed448ph\n', True):
        out.append(('Ed448', sk, pk, msg, ctx, 0, sig))
    for alg, sk, pk, msg, ctx, sig in eddsa_variant_vectors('7.5.  Test Vectors for Ed448ph\n', None):
        out.append(('Ed448', sk, pk, hashlib.shake_256(msg).digest(64), ctx, 1, sig))
    return out


def test_ed_variants():
    n = 0
    for cname, sk, pk, msg, ctx, f, sig in ed_variant_cases():
        c = CURVES[cname]
        nb = c.nbytes
        sl = 2 * nb
        buf = bytearray(1024)
        buf[0:len(msg)] = msg
        buf[len(msg):len(msg) + len(ctx)] = ctx
        buf[200:200 + sl] = sig
        buf[400:400 + nb] = pk
        offs = {AREA_MSG: 0, AREA_SIG: 200, AREA_PK: 400, AREA_RES: 600}

        def runit(op, b, key=b'', vas=False):
            if cname == 'Ed448':
                prog = P.prog_ed448(c, op)
            else:
                prog = P.prog_ed(c, op, vas=vas, dom=True)
            m = Machine(c, P.consts(c), P.STRINGS, b, key, b'', offs, len(msg), 0, curve_kind=cname, len_ctx=len(ctx), f_ph=f)
            m.run(P.assemble(prog))
            return m
        assert runit('verify', buf).ok, '%s variant vector %d: verify rejects the RFC signature' % (cname, n)
        bad = bytearray(buf); bad[200 + nb + 3] ^= 2
        assert not runit('verify', bad).ok, '%s variant: accepts a corrupted S' % cname
        if ctx:
            bad = bytearray(buf); bad[len(msg)] ^= 1
            assert not runit('verify', bad).ok, '%s variant: accepts a corrupted context' % cname
        m = runit('sign', buf, key=sk)
        assert bytes(m.buf[600:600 + sl]) == sig, '%s variant vector %d: sign differs from the RFC' % (cname, n)
        m = runit('keygen', buf, key=sk)
        assert bytes(m.buf[600:600 + nb]) == pk, '%s variant vector %d: key differs' % (cname, n)
        n += 1
    print('Ed25519ctx/ph, Ed448 context, Ed448ph: %d RFC 8032 vectors verify, sign and keygen OK' % n)


def ecdsa_vectors():
    txt = open(os.path.join(MD, 'vlsit_ecdsa_rfc6979.md'), encoding='utf-8').read()
    out = []
    for tag, cname in (('A.2.5.  ECDSA, 256 Bits (Prime Field)', 'P-256'), ('A.2.6.  ECDSA, 384 Bits (Prime Field)', 'P-384'),
                       ('A.2.7.  ECDSA, 521 Bits (Prime Field)', 'P-521')):
        i = txt.rindex(tag)
        j = txt.find('A.2.', i + 10)
        sec = txt[i:j if j > 0 else len(txt)]
        x = int(re.search(r'x = ([0-9A-F]+)', sec.replace('\n', '').replace(' ', '') if False else sec.replace('\n   ', '')).group(1), 16) \
            if False else None
        flat = re.sub(r'\n\s+(?=[0-9A-F]{8,}\n)', '', sec)
        xs = re.search(r'x = ((?:[0-9A-F]+\s*)+?)\n\s*\n', sec)
        x = int(''.join(xs.group(1).split()), 16)
        ux = int(''.join(re.search(r'Ux = ((?:[0-9A-F]+\s*)+?)\n\s*\n', sec).group(1).split()), 16)
        uy = int(''.join(re.search(r'Uy = ((?:[0-9A-F]+\s*)+?)\n\s*\n', sec).group(1).split()), 16)
        for hname, hop in (('SHA-256', 0), ('SHA-384', 1), ('SHA-512', 2)):
            for msg in (b'sample', b'test'):
                pat = r'With %s, message = "%s":\n\s+k = ((?:[0-9A-F]+\s*)+?)\n\s+r = ((?:[0-9A-F]+\s*)+?)\n\s+s = ((?:[0-9A-F]+\s*)+?)\n' % (hname, msg.decode())
                mm = re.search(pat, sec)
                if mm:
                    k, r, s = (int(''.join(g.split()), 16) for g in mm.groups())
                    out.append((cname, x, ux, uy, hop, msg, k, r, s))
    return out


def test_ecdsa():
    n = 0
    for cname, x, ux, uy, hop, msg, k, r, s in ecdsa_vectors():
        c = CURVES[cname]
        nb = c.nbytes
        buf = bytearray(1024)
        buf[0:len(msg)] = msg
        buf[200:200 + nb] = r.to_bytes(nb, 'big')
        buf[200 + nb:200 + 2 * nb] = s.to_bytes(nb, 'big')
        buf[400:400 + nb] = ux.to_bytes(nb, 'big')
        buf[400 + nb:400 + 2 * nb] = uy.to_bytes(nb, 'big')
        m = run(c, P.prog_ecdsa(c, 'verify'), buf, msg_len=len(msg), op_hash=hop)
        assert m.ok, '%s verify rejects the RFC 6979 signature (%s, hash %d)' % (cname, msg, hop)
        bad = bytearray(buf)
        bad[0] ^= 1
        m = run(c, P.prog_ecdsa(c, 'verify'), bad, msg_len=len(msg), op_hash=hop)
        assert not m.ok, 'accepts a corrupted message'
        bad = bytearray(buf)
        bad[200 + nb + 3] ^= 8
        m = run(c, P.prog_ecdsa(c, 'verify'), bad, msg_len=len(msg), op_hash=hop)
        assert not m.ok, 'accepts a corrupted s'
        # sign with the nonce of the vector: the pool holds k - 1 in the low nb bytes and 8 zero bytes
        pool = (k - 1).to_bytes(nb, 'big') + bytes(8) + bytes(96)
        m = run(c, P.prog_ecdsa(c, 'sign'), buf, key=x.to_bytes(nb, 'big'), pool=pool, msg_len=len(msg), op_hash=hop)
        assert m.ok and int.from_bytes(m.buf[600:600 + nb], 'big') == r and int.from_bytes(m.buf[600 + nb:600 + 2 * nb], 'big') == s, \
            '%s sign differs from RFC 6979 (%s, hash %d)' % (cname, msg, hop)
        # deterministic nonce of RFC 6979 computed by the program: the signature must equal the vector
        m = run(c, P.prog_ecdsa(c, 'sign', det=HASH_OF_OP[hop]), buf, key=x.to_bytes(nb, 'big'), msg_len=len(msg), op_hash=hop)
        assert m.ok and int.from_bytes(m.buf[600:600 + nb], 'big') == r and int.from_bytes(m.buf[600 + nb:600 + 2 * nb], 'big') == s,             '%s deterministic sign differs from RFC 6979 (%s, hash %d)' % (cname, msg, hop)
        if hop == 0 and msg == b'sample':
            m = run(c, P.prog_ecdsa(c, 'keygen'), buf, key=x.to_bytes(nb, 'big'))
            assert int.from_bytes(m.buf[600:600 + nb], 'big') == ux and int.from_bytes(m.buf[600 + nb:600 + 2 * nb], 'big') == uy
        n += 1
    print('ECDSA P-256/384/521: %d RFC 6979 vectors verify, sign (given k), sign (RFC 6979 nonce by the program) and keygen OK' % n)


def test_secp256k1():
    """No standard vector in the converted documents: sign with the model, verify with the model and with
    the textbook group law of ec_curves."""
    import random
    from ec_curves import mul, w_add
    c = CURVES['secp256k1']
    rnd = random.Random(7)
    nb = 32
    for i in range(3):
        d = rnd.randrange(1, c.n)
        k = rnd.randrange(1, c.n - 1)
        msg = bytes(rnd.randrange(256) for _ in range(20 + i))
        buf = bytearray(1024)
        buf[0:len(msg)] = msg
        pool = (k - 1).to_bytes(nb, 'big') + bytes(8) + bytes(96)
        m = run(c, P.prog_ecdsa(c, 'sign'), buf, key=d.to_bytes(nb, 'big'), pool=pool, msg_len=len(msg), op_hash=0)
        r = int.from_bytes(m.buf[600:632], 'big')
        s = int.from_bytes(m.buf[632:664], 'big')
        # textbook check
        import hashlib
        e = int.from_bytes(hashlib.sha256(msg).digest(), 'big')
        R = mul(c, k, (c.gx, c.gy))
        assert r == R[0] % c.n and s == pow(k, -1, c.n) * (e + r * d) % c.n
        Q = mul(c, d, (c.gx, c.gy))
        buf[200:232], buf[232:264] = r.to_bytes(32, 'big'), s.to_bytes(32, 'big')
        buf[400:432], buf[432:464] = Q[0].to_bytes(32, 'big'), Q[1].to_bytes(32, 'big')
        m = run(c, P.prog_ecdsa(c, 'verify'), buf, msg_len=len(msg), op_hash=0)
        assert m.ok
    print('secp256k1: 3 sign/verify rounds agree with the textbook group law')


if __name__ == '__main__':
    test_ed25519()
    test_ed448()
    test_ed_variants()
    test_ecdsa()
    test_secp256k1()
    print('ALL MODEL TESTS PASSED')
