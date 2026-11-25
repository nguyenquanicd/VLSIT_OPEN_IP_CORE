"""Vectors of the RTL test of the hash-based verification engine (verification/tests/hbs/tb_hbs.sv).
For vector i the file <dir>/hbs_v<i>.hex holds the buffer image (one byte per line) and the line i of <dir>/hbs_vecs.txt
holds the fields: i alg slhmode lmstype lmots hsslvl xmss len_msg len_ctx off_msg off_sig off_pk expect_ok nbytes.
Expected results: SLH-DSA signatures are made by OpenSSL 3.5 or later (independent); LMS/HSS and XMSS/XMSS^MT signatures are
made by the signers of lms_ref.py and xmss_ref.py (self-made, see the notes there); corrupted inputs must be rejected.
slhmode = slh | form << 4 | hash << 6 (form 1: HashSLH-DSA, the message is the digest PH(M), hash = dsig_op.hash).
Usage: python gen_hbs_vec.py <dir> <set>   (sets: quick, slh, lms, xmss, prehash)"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slh_ref as S
import lms_ref as L
import xmss_ref as X

OPENSSL = os.environ.get('OPENSSL', 'C:/Users/PC/Tools/msys64/usr/bin/openssl.exe')
OFF_MSG, OFF_PK, OFF_SIG = 0, 2048, 4096


def ossl(*args):
    r = subprocess.run([OPENSSL] + list(args), capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode(errors='replace'))


def slh_make(idx, msg, ctx):
    d = tempfile.mkdtemp()
    key, pub, mf, sf = (os.path.join(d, x) for x in ('k.pem', 'p.der', 'm.bin', 's.bin'))
    ossl('genpkey', '-algorithm', S.SETS[idx]['name'], '-out', key)
    ossl('pkey', '-in', key, '-pubout', '-outform', 'DER', '-out', pub)
    open(mf, 'wb').write(msg)
    opts = ['-pkeyopt', 'context-string:' + ctx.decode()] if ctx else []
    ossl('pkeyutl', '-sign', '-inkey', key, '-rawin', '-in', mf, '-out', sf, *opts)
    return open(pub, 'rb').read()[-2 * S.SETS[idx]['n']:], open(sf, 'rb').read()


def flip(b, i, m=4):
    b = bytearray(b)
    b[i % len(b)] ^= m
    return bytes(b)


class V:
    def __init__(self, name, alg, msg, sig, pk, ok, ctx=b'', slh=0, lmstype=0, lmots=0, hsslvl=0, xmss=0, form=0, hcode=0):
        self.name, self.alg, self.msg, self.sig, self.pk, self.ok, self.ctx = name, alg, msg, sig, pk, ok, ctx
        self.slh, self.lmstype, self.lmots, self.hsslvl, self.xmss = slh, lmstype, lmots, hsslvl, xmss
        self.form, self.hcode = form, hcode

    def image(self):
        assert len(self.msg) + len(self.ctx) <= OFF_PK and len(self.pk) <= OFF_SIG - OFF_PK
        img = bytearray(OFF_SIG + len(self.sig))
        img[OFF_MSG:OFF_MSG + len(self.msg)] = self.msg
        img[OFF_MSG + len(self.msg):OFF_MSG + len(self.msg) + len(self.ctx)] = self.ctx
        img[OFF_PK:OFF_PK + len(self.pk)] = self.pk
        img[OFF_SIG:] = self.sig
        return bytes(img)


def slh_vecs(sets, ctxsets):
    out = []
    for idx in sets:
        name = S.SETS[idx]['name']
        msg = bytes((i * 3 + idx) % 256 for i in range(37 + idx))
        pk, sig = slh_make(idx, msg, b'')
        mp = lambda m, c=b'': b'\x00' + bytes([len(c)]) + c + m
        out.append(V(name + ' valid', 12, msg, sig, pk, 1, slh=idx))
        out.append(V(name + ' corrupted signature', 12, msg, flip(sig, len(sig) // 3), pk, 0, slh=idx))
        out.append(V(name + ' wrong message', 12, flip(msg, len(msg) - 1, 1), sig, pk, 0, slh=idx))
        out.append(V(name + ' wrong root', 12, msg, sig, flip(pk, len(pk) - 1), 0, slh=idx))
        if idx in ctxsets:
            ctx = b'hello'
            pk2, sig2 = slh_make(idx, msg, ctx)
            out.append(V(name + ' valid with context', 12, msg, sig2, pk2, 1, ctx=ctx, slh=idx))
            out.append(V(name + ' context missing', 12, msg, sig2, pk2, 0, ctx=b'', slh=idx))
    return out


def lms_vecs(cases):
    out = []
    for lt, lo, lv in cases:
        msg = b'The enumeration in the new section is needed'
        pub, sig = L.make_hss(lt, lo, lv, msg, q=3 if lv == 1 else 1)
        nm = 'LMS %d OTS %d levels %d' % (lt, lo, lv)
        out.append(V(nm + ' valid', 13, msg, sig, pub, 1, lmstype=lt, lmots=lo, hsslvl=lv))
        out.append(V(nm + ' corrupted signature', 13, msg, flip(sig, len(sig) // 2, 8), pub, 0, lmstype=lt, lmots=lo, hsslvl=lv))
        out.append(V(nm + ' wrong message', 13, msg + b'!', sig, pub, 0, lmstype=lt, lmots=lo, hsslvl=lv))
        out.append(V(nm + ' wrong key', 13, msg, sig, flip(pub, len(pub) - 1, 1), 0, lmstype=lt, lmots=lo, hsslvl=lv))
        out.append(V(nm + ' wrong LMS type', 13, msg, sig, pub, 0, lmstype=(lt + 1) % 5 + 5 * (lt // 5), lmots=lo, hsslvl=lv))
    return out


def xmss_vecs(sets):
    out = []
    for idx in sets:
        x = X.Xmss(idx)
        msg = bytes(range(41))
        pk, sig = x.make(msg, idx=5 if X.SETS[idx]['d'] > 1 else 3)
        nm = X.SETS[idx]['name']
        out.append(V(nm + ' valid', 14, msg, sig, pk, 1, xmss=idx))
        out.append(V(nm + ' corrupted signature', 14, msg, flip(sig, len(sig) // 2, 8), pk, 0, xmss=idx))
        out.append(V(nm + ' wrong message', 14, msg + b'!', sig, pk, 0, xmss=idx))
        out.append(V(nm + ' wrong root', 14, msg, sig, flip(pk, 6, 1), 0, xmss=idx))
    return out


def prehash_vecs():
    """HashSLH-DSA (FIPS 205 algorithm 25): signatures of OpenSSL with message-encoding 0 over M' built from the standard
    (see test_hbs_slh_prehash.py)."""
    import test_hbs_slh_prehash as TP
    out = []
    for idx, hcode, ctx in ((0, 0, b''), (1, 2, b'boot'), (6, 4, b''), (7, 3, b'boot')):
        name = S.SETS[idx]['name']
        dig = TP.HASHES[hcode][0](b'image %d' % idx).digest()
        mp = bytes([1, len(ctx)]) + ctx + TP.OID_PREFIX + bytes([TP.HASHES[hcode][1]]) + dig
        pk, sig = TP.make_raw(idx, mp)
        nm = 'Hash' + name + ' hash %d%s ' % (hcode, ' ctx' if ctx else '')
        out.append(V(nm + 'valid', 12, dig, sig, pk, 1, ctx=ctx, slh=idx, form=1, hcode=hcode))
        out.append(V(nm + 'another hash code', 12, dig, sig, pk, 0, ctx=ctx, slh=idx, form=1, hcode=(hcode + 3) % 6))   # same length
        out.append(V(nm + 'pure form', 12, dig, sig, pk, 0, ctx=ctx, slh=idx, form=0, hcode=hcode))
    return out


def build(name):
    if name == 'prehash':
        return prehash_vecs()
    if name == 'slh':
        return slh_vecs(list(range(12)), {0, 1, 6, 8})
    if name == 'lms':
        return lms_vecs([(0, 3, 1), (0, 3, 2), (0, 2, 1), (0, 1, 3), (0, 0, 1), (5, 7, 1), (10, 11, 2), (15, 14, 1), (6, 6, 1), (11, 10, 2)])
    if name == 'xmss':
        return xmss_vecs([14, 15, 12, 20, 26, 0, 6, 7])
    if name == 'quick':
        return slh_vecs([0, 6], {0}) + lms_vecs([(0, 3, 1)]) + xmss_vecs([14])
    raise SystemExit('unknown set ' + name)


def main(d, name):
    os.makedirs(d, exist_ok=True)
    vecs = build(name)
    with open(os.path.join(d, 'hbs_vecs.txt'), 'w') as fh, open(os.path.join(d, 'hbs_names.txt'), 'w') as fn:
        for i, v in enumerate(vecs):
            img = v.image()
            with open(os.path.join(d, 'hbs_v%d.hex' % i), 'w') as fx:
                fx.write('\n'.join('%02x' % b for b in img) + '\n')
            fh.write('%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n' % (i, v.alg, v.slh | (v.form << 4) | (v.hcode << 6), v.lmstype, v.lmots, v.hsslvl, v.xmss, len(v.msg), len(v.ctx),
                                                                   OFF_MSG, OFF_SIG, OFF_PK, v.ok, len(img)))
            fn.write('%d\t%s\n' % (i, v.name))
    print('%s: %d vectors' % (name, len(vecs)))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
