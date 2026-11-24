"""Reference SLH-DSA verification (FIPS 205, Algorithms 24 and following) written straight from the standard, used to
check the microprogram of the hash-based engine. The signatures that it is tested with are made by OpenSSL 3.5 or later
(an independent implementation): see test_slh_ref.py.
Parameter sets: index 0..11 as section 10.2.1 of the specification (SHA2 128s 128f 192s 192f 256s 256f, then SHAKE)."""
import hashlib

# name, n, h, d, a, k
SETS = []
for fam in ('SHA2', 'SHAKE'):
    for n, row in ((16, ((63, 7, 12, 14), (66, 22, 6, 33))), (24, ((63, 7, 14, 17), (66, 22, 8, 33))), (32, ((64, 8, 14, 22), (68, 17, 9, 35)))):
        for sf, (h, d, a, k) in zip('sf', row):
            SETS.append(dict(name='SLH-DSA-%s-%d%s' % (fam, 8 * n, sf), fam=fam, n=n, h=h, d=d, hp=h // d, a=a, k=k, w=16,
                             len1=2 * n, len2=3, len=2 * n + 3,
                             m=(k * a + 7) // 8 + (h - h // d + 7) // 8 + (h // d + 7) // 8,
                             sig=(1 + k * (1 + a) + h + d * (2 * n + 3)) * n, pk=2 * n))

# address types
WOTS_HASH, WOTS_PK, TREE, FORS_TREE, FORS_ROOTS, WOTS_PRF, FORS_PRF = range(7)


class Adrs:
    def __init__(self):
        self.layer = self.tree = self.type = self.kp = self.ch = self.hs = 0   # ch: chain / tree height, hs: hash / tree index

    def copy(self):
        a = Adrs()
        a.__dict__.update(self.__dict__)
        return a

    def set_type(self, t):
        self.type = t
        self.kp = self.ch = self.hs = 0

    def bytes32(self):
        return (self.layer.to_bytes(4, 'big') + self.tree.to_bytes(12, 'big') + self.type.to_bytes(4, 'big') +
                self.kp.to_bytes(4, 'big') + self.ch.to_bytes(4, 'big') + self.hs.to_bytes(4, 'big'))

    def bytes22(self):
        """Compressed address of the SHA2 variants."""
        return (bytes([self.layer & 255]) + (self.tree & ((1 << 64) - 1)).to_bytes(8, 'big') + bytes([self.type & 255]) +
                self.kp.to_bytes(4, 'big') + self.ch.to_bytes(4, 'big') + self.hs.to_bytes(4, 'big'))


def mgf1(h, seed, ln):
    out = b''
    c = 0
    while len(out) < ln:
        out += h(seed + c.to_bytes(4, 'big')).digest()
        c += 1
    return out[:ln]


class Slh:
    def __init__(self, idx):
        self.p = SETS[idx]
        self.n = self.p['n']

    # tweakable hash functions
    def F(self, pk_seed, adrs, m1):
        n = self.n
        if self.p['fam'] == 'SHAKE':
            return hashlib.shake_256(pk_seed + adrs.bytes32() + m1).digest(n)
        return hashlib.sha256(pk_seed + bytes(64 - n) + adrs.bytes22() + m1).digest()[:n]

    def Hn(self, pk_seed, adrs, m):
        """H (two nodes) and T_l (l nodes) share the construction."""
        n = self.n
        if self.p['fam'] == 'SHAKE':
            return hashlib.shake_256(pk_seed + adrs.bytes32() + m).digest(n)
        if n == 16:
            return hashlib.sha256(pk_seed + bytes(64 - n) + adrs.bytes22() + m).digest()[:n]
        return hashlib.sha512(pk_seed + bytes(128 - n) + adrs.bytes22() + m).digest()[:n]

    def H_msg(self, r, pk_seed, pk_root, msg):
        m = self.p['m']
        if self.p['fam'] == 'SHAKE':
            return hashlib.shake_256(r + pk_seed + pk_root + msg).digest(m)
        h = hashlib.sha256 if self.n == 16 else hashlib.sha512
        return mgf1(h, r + pk_seed + h(r + pk_seed + pk_root + msg).digest(), m)

    # helpers
    @staticmethod
    def base_2b(x, b, out_len):
        v = int.from_bytes(x, 'big')
        total = 8 * len(x)
        res = []
        for i in range(out_len):
            sh = total - (i + 1) * b
            res.append((v >> sh) & ((1 << b) - 1))
        return res

    def chain(self, x, i, s, pk_seed, adrs):
        tmp = x
        for j in range(i, i + s):
            adrs.hs = j
            tmp = self.F(pk_seed, adrs, tmp)
        return tmp

    def wots_pk_from_sig(self, sig, msg, pk_seed, adrs):
        n, w, len1, len2 = self.n, 16, self.p['len1'], self.p['len2']
        m = self.base_2b(msg, 4, len1)
        csum = sum(w - 1 - x for x in m)
        csum <<= (8 - ((len2 * 4) % 8)) % 8
        m += self.base_2b(csum.to_bytes((len2 * 4 + 7) // 8, 'big'), 4, len2)
        tmp = b''
        for i in range(len1 + len2):
            adrs.ch = i
            tmp += self.chain(sig[i * n:(i + 1) * n], m[i], w - 1 - m[i], pk_seed, adrs)
        wots = adrs.copy()
        wots.set_type(WOTS_PK)
        wots.kp = adrs.kp
        return self.Hn(pk_seed, wots, tmp)

    def xmss_pk_from_sig(self, idx, sig_xmss, msg, pk_seed, adrs):
        n, hp, ln = self.n, self.p['hp'], self.p['len']
        adrs.set_type(WOTS_HASH)
        adrs.kp = idx
        sig = sig_xmss[:ln * n]
        auth = sig_xmss[ln * n:]
        node = self.wots_pk_from_sig(sig, msg, pk_seed, adrs)
        adrs.set_type(TREE)
        adrs.hs = idx
        for k in range(hp):
            adrs.ch = k + 1
            a = auth[k * n:(k + 1) * n]
            if (idx >> k) & 1 == 0:
                adrs.hs = adrs.hs // 2
                node = self.Hn(pk_seed, adrs, node + a)
            else:
                adrs.hs = (adrs.hs - 1) // 2
                node = self.Hn(pk_seed, adrs, a + node)
        return node

    def fors_pk_from_sig(self, sig_fors, md, pk_seed, adrs):
        n, a_, k = self.n, self.p['a'], self.p['k']
        idxs = self.base_2b(md, a_, k)
        roots = b''
        for i in range(k):
            blk = sig_fors[i * (a_ + 1) * n:(i + 1) * (a_ + 1) * n]
            sk, auth = blk[:n], blk[n:]
            adrs.ch = 0
            adrs.hs = i * (1 << a_) + idxs[i]
            node = self.F(pk_seed, adrs, sk)
            for j in range(a_):
                adrs.ch = j + 1
                au = auth[j * n:(j + 1) * n]
                if (idxs[i] >> j) & 1 == 0:
                    adrs.hs = adrs.hs // 2
                    node = self.Hn(pk_seed, adrs, node + au)
                else:
                    adrs.hs = (adrs.hs - 1) // 2
                    node = self.Hn(pk_seed, adrs, au + node)
            roots += node
        fpk = adrs.copy()
        fpk.set_type(FORS_ROOTS)
        fpk.kp = adrs.kp
        return self.Hn(pk_seed, fpk, roots)

    def verify(self, msg_prime, sig, pk):
        """msg_prime is M' (the encoded message), pk is PK.seed || PK.root."""
        p, n = self.p, self.n
        if len(sig) != p['sig'] or len(pk) != 2 * n:
            return False
        pk_seed, pk_root = pk[:n], pk[n:]
        r = sig[:n]
        sig_fors = sig[n:n + p['k'] * (1 + p['a']) * n]
        sig_ht = sig[n + p['k'] * (1 + p['a']) * n:]
        digest = self.H_msg(r, pk_seed, pk_root, msg_prime)
        l1 = (p['k'] * p['a'] + 7) // 8
        l2 = (p['h'] - p['h'] // p['d'] + 7) // 8
        l3 = (p['h'] // p['d'] + 7) // 8
        md = digest[:l1]
        idx_tree = int.from_bytes(digest[l1:l1 + l2], 'big') % (1 << (p['h'] - p['hp']))
        idx_leaf = int.from_bytes(digest[l1 + l2:l1 + l2 + l3], 'big') % (1 << p['hp'])
        adrs = Adrs()
        adrs.tree = idx_tree
        adrs.set_type(FORS_TREE)
        adrs.kp = idx_leaf
        node = self.fors_pk_from_sig(sig_fors, md, pk_seed, adrs)
        step = (p['hp'] + p['len']) * n
        for j in range(p['d']):
            adrs = Adrs()
            adrs.layer = j
            adrs.tree = idx_tree
            node = self.xmss_pk_from_sig(idx_leaf, sig_ht[j * step:(j + 1) * step], node, pk_seed, adrs)
            idx_leaf = idx_tree % (1 << p['hp'])
            idx_tree >>= p['hp']
        return node == pk_root
