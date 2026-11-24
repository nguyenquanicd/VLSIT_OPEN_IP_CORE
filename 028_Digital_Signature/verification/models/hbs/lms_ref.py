"""Reference LMS / LM-OTS / HSS (RFC 8554, written from the algorithms of the RFC; the RFC is not among the converted
standards of the skill, so this model is checked only against itself: a signer and a verifier written here).
Hash families: SHA-256 (n = 32), SHA-256/192 (n = 24), SHAKE256/256, SHAKE256/192.
LMS type numbers 0..19 and LM-OTS type numbers 0..15 are those of section 10.2.2 of the specification; the type codes
carried in the keys and signatures follow the IANA registry of RFC 8554 and SP 800-208 (assumption ASM-022: the codes of the
families other than SHA-256/32 are not in SP 800-208, "TBD")."""
import hashlib
import os

D_MESG, D_PBLC, D_LEAF, D_INTR = 0x8181, 0x8080, 0x8282, 0x8383


def lms_params(lmstype):
    fam, hi = divmod(lmstype, 5)        # fam 0 SHA256/32, 1 SHA256/24, 2 SHAKE/32, 3 SHAKE/24
    return dict(shake=fam >= 2, n=32 if fam in (0, 2) else 24, h=5 * (hi + 1), code=5 + lmstype)


def ots_params(lmots):
    fam, wi = divmod(lmots, 4)
    w = (1, 2, 4, 8)[wi]
    n = 32 if fam in (0, 2) else 24
    u = -(-8 * n // w)
    # v: smallest number of w-bit digits that holds the checksum ((2^w - 1) * u)
    maxsum = ((1 << w) - 1) * u
    v = -(-(maxsum.bit_length()) // w)
    p = u + v
    ls = 16 - v * w
    return dict(shake=fam >= 2, n=n, w=w, u=u, v=v, p=p, ls=ls, code=1 + lmots)


def H(shake, n, data):
    if shake:
        return hashlib.shake_256(data).digest(n)
    return hashlib.sha256(data).digest()[:n]


def coef(s, i, w):
    return (s[(i * w) // 8] >> (8 - (w * (i % (8 // w)) + w))) & ((1 << w) - 1)


def cksm(s, n, w, ls):
    u = -(-8 * n // w)
    return (sum(((1 << w) - 1) - coef(s, i, w) for i in range(u)) << ls) & 0xFFFF


def ots_pk_from_sig(op, I, q, sigbytes, msg):
    n, w, p, ls, sh = op['n'], op['w'], op['p'], op['ls'], op['shake']
    c, y = sigbytes[:n], sigbytes[n:]
    Q = H(sh, n, I + q.to_bytes(4, 'big') + D_MESG.to_bytes(2, 'big') + c + msg)
    Qc = Q + cksm(Q, n, w, ls).to_bytes(2, 'big')
    z = b''
    for i in range(p):
        a = coef(Qc, i, w)
        tmp = y[i * n:(i + 1) * n]
        for j in range(a, (1 << w) - 1):
            tmp = H(sh, n, I + q.to_bytes(4, 'big') + i.to_bytes(2, 'big') + bytes([j]) + tmp)
        z += tmp
    return H(sh, n, I + q.to_bytes(4, 'big') + D_PBLC.to_bytes(2, 'big') + z)


def lms_verify(lmstype, lmots, pub, msg, sig):
    """pub: type(4) otstype(4) I(16) T1(n); sig: q(4) otssig(4+n+p*n) lmstype(4) path(h*n)."""
    lp, op = lms_params(lmstype), ots_params(lmots)
    n, h = lp['n'], lp['h']
    if lp['n'] != op['n'] or lp['shake'] != op['shake']:
        return False
    if len(pub) != 24 + n or int.from_bytes(pub[:4], 'big') != lp['code'] or int.from_bytes(pub[4:8], 'big') != op['code']:
        return False
    I, T1 = pub[8:24], pub[24:]
    otsz = 4 + n + op['p'] * n
    if len(sig) != 4 + otsz + 4 + h * n:
        return False
    q = int.from_bytes(sig[:4], 'big')
    if int.from_bytes(sig[4:8], 'big') != op['code'] or int.from_bytes(sig[4 + otsz:8 + otsz], 'big') != lp['code'] or q >= (1 << h):
        return False
    path = sig[8 + otsz:]
    kc = ots_pk_from_sig(op, I, q, sig[8:4 + otsz], msg)
    node = (1 << h) + q
    tmp = H(lp['shake'], n, I + node.to_bytes(4, 'big') + D_LEAF.to_bytes(2, 'big') + kc)
    for i in range(h):
        pi = path[i * n:(i + 1) * n]
        if node & 1:
            tmp = H(lp['shake'], n, I + (node >> 1).to_bytes(4, 'big') + D_INTR.to_bytes(2, 'big') + pi + tmp)
        else:
            tmp = H(lp['shake'], n, I + (node >> 1).to_bytes(4, 'big') + D_INTR.to_bytes(2, 'big') + tmp + pi)
        node >>= 1
    return tmp == T1


def hss_verify(lmstype, lmots, L, pub, msg, sig):
    """pub: u32 L || lms pub; sig: u32 Nspk || (lms sig || lms pub)* || lms sig."""
    lp, op = lms_params(lmstype), ots_params(lmots)
    n = lp['n']
    pubsz = 24 + n
    sigsz = 4 + 4 + n + op['p'] * n + 4 + lp['h'] * n
    if len(pub) != 4 + pubsz or int.from_bytes(pub[:4], 'big') != L:
        return False
    nspk = int.from_bytes(sig[:4], 'big')
    if nspk != L - 1 or len(sig) != 4 + nspk * (sigsz + pubsz) + sigsz:
        return False
    key = pub[4:]
    pos = 4
    for _ in range(nspk):
        s = sig[pos:pos + sigsz]
        nxt = sig[pos + sigsz:pos + sigsz + pubsz]
        if not lms_verify(lmstype, lmots, key, nxt, s):
            return False
        key = nxt
        pos += sigsz + pubsz
    return lms_verify(lmstype, lmots, key, msg, sig[pos:pos + sigsz])


# ---- signer (test vectors only) ----
class LmsKey:
    def __init__(self, lmstype, lmots, seed, I=None):
        self.lp, self.op = lms_params(lmstype), ots_params(lmots)
        self.lmstype, self.lmots = lmstype, lmots
        self.seed = seed
        self.I = I or hashlib.sha256(b'I' + seed).digest()[:16]
        h, n = self.lp['h'], self.lp['n']
        self.leaves = [self._ots_pk(q) for q in range(1 << h)]
        self.nodes = {}
        for q in range(1 << h):
            self.nodes[(1 << h) + q] = H(self.lp['shake'], n, self.I + ((1 << h) + q).to_bytes(4, 'big') + D_LEAF.to_bytes(2, 'big') + self.leaves[q])
        for r in range((1 << h) - 1, 0, -1):
            self.nodes[r] = H(self.lp['shake'], n, self.I + r.to_bytes(4, 'big') + D_INTR.to_bytes(2, 'big') + self.nodes[2 * r] + self.nodes[2 * r + 1])
        self.pub = self.lp['code'].to_bytes(4, 'big') + self.op['code'].to_bytes(4, 'big') + self.I + self.nodes[1]

    def _x(self, q, i):
        n = self.lp['n']
        return H(self.op['shake'], n, self.I + q.to_bytes(4, 'big') + i.to_bytes(2, 'big') + b'\xff' + self.seed)

    def _ots_pk(self, q):
        op, n = self.op, self.op['n']
        z = b''
        for i in range(op['p']):
            tmp = self._x(q, i)
            for j in range((1 << op['w']) - 1):
                tmp = H(op['shake'], n, self.I + q.to_bytes(4, 'big') + i.to_bytes(2, 'big') + bytes([j]) + tmp)
            z += tmp
        return H(op['shake'], n, self.I + q.to_bytes(4, 'big') + D_PBLC.to_bytes(2, 'big') + z)

    def sign(self, q, msg, c=None):
        op, n, h = self.op, self.op['n'], self.lp['h']
        c = c or hashlib.sha256(b'C' + self.seed + q.to_bytes(4, 'big') + msg).digest()[:n]
        Q = H(op['shake'], n, self.I + q.to_bytes(4, 'big') + D_MESG.to_bytes(2, 'big') + c + msg)
        Qc = Q + cksm(Q, n, op['w'], op['ls']).to_bytes(2, 'big')
        y = b''
        for i in range(op['p']):
            a = coef(Qc, i, op['w'])
            tmp = self._x(q, i)
            for j in range(a):
                tmp = H(op['shake'], n, self.I + q.to_bytes(4, 'big') + i.to_bytes(2, 'big') + bytes([j]) + tmp)
            y += tmp
        node = (1 << h) + q
        path = b''
        for _ in range(h):
            path += self.nodes[node ^ 1]
            node >>= 1
        return (q.to_bytes(4, 'big') + op['code'].to_bytes(4, 'big') + c + y + self.lp['code'].to_bytes(4, 'big') + path)


def make_hss(lmstype, lmots, L, msg, seed=b'seed', q=0):
    """Returns (pub, sig) of an HSS tree of L levels (homogeneous parameters)."""
    keys = [LmsKey(lmstype, lmots, seed + bytes([i])) for i in range(L)]
    sig = (L - 1).to_bytes(4, 'big')
    for i in range(L - 1):
        sig += keys[i].sign(q, keys[i + 1].pub) + keys[i + 1].pub
    sig += keys[L - 1].sign(q, msg)
    return L.to_bytes(4, 'big') + keys[0].pub, sig
