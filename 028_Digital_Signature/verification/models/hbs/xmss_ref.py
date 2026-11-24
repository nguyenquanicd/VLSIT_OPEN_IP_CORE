"""Reference XMSS / XMSS^MT verification and a test signer (RFC 8391 algorithms from memory; the hash function constructions,
the padding lengths and the type codes are those of NIST SP 800-208 section 5, which is among the converted standards).
The RFC itself is not converted, so the tree and address handling is checked only against a signer written here.
Set numbers 0..43 follow section 10.2.3 of the specification."""
import hashlib
import re

# (name, oid) from SP 800-208 tables 10..17
_OID = {
    'XMSS-SHA2_10_256': 0x01, 'XMSS-SHA2_16_256': 0x02, 'XMSS-SHA2_20_256': 0x03,
    'XMSS-SHA2_10_192': 0x0D, 'XMSS-SHA2_16_192': 0x0E, 'XMSS-SHA2_20_192': 0x0F,
    'XMSS-SHAKE256_10_256': 0x10, 'XMSS-SHAKE256_16_256': 0x11, 'XMSS-SHAKE256_20_256': 0x12,
    'XMSS-SHAKE256_10_192': 0x13, 'XMSS-SHAKE256_16_192': 0x14, 'XMSS-SHAKE256_20_192': 0x15,
}
_MT = {('SHA2', 256): 0x01, ('SHA2', 192): 0x21, ('SHAKE256', 256): 0x29, ('SHAKE256', 192): 0x31}
_MT_HD = [(20, 2), (20, 4), (40, 2), (40, 4), (40, 8), (60, 3), (60, 6), (60, 12)]


def _build():
    sets = []
    for fam in ('SHA2', 'SHAKE256'):
        for h in (10, 16, 20):
            for n in (256, 192):
                nm = 'XMSS-%s_%d_%d' % (fam, h, n)
                sets.append(dict(name=nm, fam=fam, n=n // 8, h=h, d=1, oid=_OID[nm]))
    for fam in ('SHA2', 'SHAKE256'):
        for k, (h, d) in enumerate(_MT_HD):
            for n in (256, 192):
                base = _MT[(fam, n)]
                # SP 800-208: the MT identifiers of one family run in the order of _MT_HD
                sets.append(dict(name='XMSSMT-%s_%d/%d_%d' % (fam, h, d, n), fam=fam, n=n // 8, h=h, d=d, oid=base + k))
    for s in sets:
        s['pl'] = 32 if s['n'] == 32 else 4
        s['w'] = 16
        s['len1'] = 2 * s['n']
        s['len2'] = 3
        s['len'] = 2 * s['n'] + 3
        s['hp'] = s['h'] // s['d']
        s['idxlen'] = 4 if s['d'] == 1 else (s['h'] + 7) // 8
        s['sig'] = s['idxlen'] + s['n'] + s['d'] * (s['len'] + s['hp']) * s['n']
        s['pk'] = 4 + 2 * s['n']
    return sets


SETS = _build()


class Xmss:
    def __init__(self, idx):
        self.p = SETS[idx]
        self.n = self.p['n']

    def _h(self, x, key, m):
        p = self.p
        data = x.to_bytes(p['pl'], 'big') + key + m
        if p['fam'] == 'SHA2':
            return hashlib.sha256(data).digest()[:p['n']]
        return hashlib.shake_256(data).digest(p['n'])

    def F(self, key, m): return self._h(0, key, m)
    def H(self, key, m): return self._h(1, key, m)
    def Hmsg(self, key, m): return self._h(2, key, m)
    def PRF(self, key, m): return self._h(3, key, m)

    # address: [layer, tree, type, w3, w4, w5, keyandmask]
    @staticmethod
    def adrs(a):
        return a[0].to_bytes(4, 'big') + a[1].to_bytes(8, 'big') + a[2].to_bytes(4, 'big') + a[3].to_bytes(4, 'big') + \
            a[4].to_bytes(4, 'big') + a[5].to_bytes(4, 'big') + a[6].to_bytes(4, 'big')

    def chain(self, x, i, s, seed, a):
        tmp = x
        for k in range(s):
            a[5] = i + k
            a[6] = 0
            key = self.PRF(seed, self.adrs(a))
            a[6] = 1
            bm = self.PRF(seed, self.adrs(a))
            tmp = self.F(key, bytes(u ^ v for u, v in zip(tmp, bm)))
        return tmp

    def digits(self, m):
        n, len1, len2 = self.n, self.p['len1'], self.p['len2']
        d = []
        for b in m:
            d += [b >> 4, b & 15]
        csum = sum(15 - x for x in d)
        csum <<= 4
        cb = csum.to_bytes(2, 'big')
        return d[:len1] + [cb[0] >> 4, cb[0] & 15, cb[1] >> 4]

    def wots_pk_from_sig(self, msg, sig, seed, a):
        n = self.n
        d = self.digits(msg)
        out = b''
        for i in range(self.p['len']):
            a[4] = i
            out += self.chain(sig[i * n:(i + 1) * n], d[i], 15 - d[i], seed, a)
        return out

    def rand_hash(self, left, right, seed, a):
        a[6] = 0
        key = self.PRF(seed, self.adrs(a))
        a[6] = 1
        bm0 = self.PRF(seed, self.adrs(a))
        a[6] = 2
        bm1 = self.PRF(seed, self.adrs(a))
        return self.H(key, bytes(u ^ v for u, v in zip(left, bm0)) + bytes(u ^ v for u, v in zip(right, bm1)))

    def ltree(self, pk, seed, a):
        n = self.n
        nodes = [pk[i * n:(i + 1) * n] for i in range(self.p['len'])]
        a[4] = 0
        while len(nodes) > 1:
            nxt = []
            for i in range(len(nodes) // 2):
                a[5] = i
                nxt.append(self.rand_hash(nodes[2 * i], nodes[2 * i + 1], seed, a))
            if len(nodes) % 2:
                nxt.append(nodes[-1])
            nodes = nxt
            a[4] += 1
        return nodes[0]

    def root_from_sig(self, idx, sig_ots, auth, msg, seed, a):
        n = self.n
        a[2], a[3], a[4], a[5], a[6] = 0, idx, 0, 0, 0
        pk = self.wots_pk_from_sig(msg, sig_ots, seed, a)
        a[2], a[3], a[4], a[5], a[6] = 1, idx, 0, 0, 0
        node = self.ltree(pk, seed, a)
        a[2], a[3], a[4], a[5], a[6] = 2, 0, 0, idx, 0
        for k in range(self.p['hp']):
            a[4] = k
            au = auth[k * n:(k + 1) * n]
            if (idx >> k) & 1 == 0:
                a[5] = a[5] // 2
                node = self.rand_hash(node, au, seed, a)
            else:
                a[5] = (a[5] - 1) // 2
                node = self.rand_hash(au, node, seed, a)
        return node

    def verify(self, msg, sig, pk):
        p, n = self.p, self.n
        if len(sig) != p['sig'] or len(pk) != p['pk'] or int.from_bytes(pk[:4], 'big') != p['oid']:
            return False
        root, seed = pk[4:4 + n], pk[4 + n:]
        il = p['idxlen']
        idx = int.from_bytes(sig[:il], 'big')
        r = sig[il:il + n]
        mp = self.Hmsg(r + root + idx.to_bytes(n, 'big'), msg)
        pos = il + n
        step = (p['len'] + p['hp']) * n
        idx_leaf = idx % (1 << p['hp'])
        idx_tree = idx >> p['hp']
        node = None
        for j in range(p['d']):
            blk = sig[pos + j * step:pos + (j + 1) * step]
            a = [j, idx_tree, 0, 0, 0, 0, 0]
            node = self.root_from_sig(idx_leaf, blk[:p['len'] * n], blk[p['len'] * n:], mp if j == 0 else node, seed, a)
            idx_leaf = idx_tree % (1 << p['hp'])
            idx_tree >>= p['hp']
        return node == root

    # ---- test signer ----
    def _sk(self, sk_seed, layer, tree, leaf, i):
        return self.PRF(sk_seed, self.adrs([layer, tree, 7, leaf, i, 0, 0]))

    def _leaf(self, sk_seed, seed, layer, tree, leaf):
        n = self.n
        a = [layer, tree, 0, leaf, 0, 0, 0]
        pk = b''
        for i in range(self.p['len']):
            a[4] = i
            pk += self.chain(self._sk(sk_seed, layer, tree, leaf, i), 0, 15, seed, a)
        a2 = [layer, tree, 1, leaf, 0, 0, 0]
        return self.ltree(pk, seed, a2)

    def _tree(self, sk_seed, seed, layer, tree):
        hp = self.p['hp']
        lv = [[self._leaf(sk_seed, seed, layer, tree, i) for i in range(1 << hp)]]
        for k in range(hp):
            prev = lv[-1]
            a = [layer, tree, 2, 0, k, 0, 0]
            nxt = []
            for i in range(len(prev) // 2):
                a[5] = i
                nxt.append(self.rand_hash(prev[2 * i], prev[2 * i + 1], seed, a))
            lv.append(nxt)
        return lv

    def _sign_ots(self, sk_seed, seed, layer, tree, leaf, msg):
        n = self.n
        d = self.digits(msg)
        a = [layer, tree, 0, leaf, 0, 0, 0]
        out = b''
        for i in range(self.p['len']):
            a[4] = i
            out += self.chain(self._sk(sk_seed, layer, tree, leaf, i), 0, d[i], seed, a)
        return out

    def make(self, msg, sk_seed=b'S', seed=None, idx=0, r=None):
        """Returns (pk, sig) for the leaf index idx (the layer trees are built lazily for the path only)."""
        p, n = self.p, self.n
        seed = seed or hashlib.sha256(b'pubseed' + sk_seed).digest()[:n]
        il = p['idxlen']
        idx_tree_top = None
        # trees on the path and the root of the top tree
        hp, d = p['hp'], p['d']
        tr = idx >> hp
        trees = []
        t = tr
        for j in range(d):
            trees.append((j, t))
            t >>= hp
        built = {}
        for (j, t) in trees:
            built[(j, t)] = self._tree(sk_seed, seed, j, t)
        root = built[trees[-1]][-1][0]
        r = r or hashlib.sha256(b'r' + sk_seed + idx.to_bytes(8, 'big') + msg).digest()[:n]
        mp = self.Hmsg(r + root + idx.to_bytes(n, 'big'), msg)
        sig = idx.to_bytes(il, 'big') + r
        leaf = idx % (1 << hp)
        cur = mp
        for j, (layer, tree) in enumerate(trees):
            lv = built[(layer, tree)]
            sig += self._sign_ots(sk_seed, seed, layer, tree, leaf, cur)
            node = leaf
            for k in range(hp):
                sig += lv[k][node ^ 1]
                node >>= 1
            cur = lv[-1][0]
            leaf = tree % (1 << hp)
        pk = p['oid'].to_bytes(4, 'big') + root + seed
        return pk, sig
