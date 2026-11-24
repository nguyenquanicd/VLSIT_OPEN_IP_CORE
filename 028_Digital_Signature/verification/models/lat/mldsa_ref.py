"""Reference ML-DSA (FIPS 204, algorithms 6 to 8 internal functions, pure form) written from the standard and checked against
OpenSSL 3.5 or later (independent): key generation from a seed, deterministic and hedged signing, verification.
Parameter sets: 44, 65, 87."""
import hashlib

Q = 8380417
ZETA = 1753
D = 13
N = 256

PARAMS = {
    44: dict(k=4, l=4, eta=2, tau=39, lam=128, gamma1=1 << 17, gamma2=(Q - 1) // 88, beta=78, omega=80),
    65: dict(k=6, l=5, eta=4, tau=49, lam=192, gamma1=1 << 19, gamma2=(Q - 1) // 32, beta=196, omega=55),
    87: dict(k=8, l=7, eta=2, tau=60, lam=256, gamma1=1 << 19, gamma2=(Q - 1) // 32, beta=120, omega=75),
}


def brv8(x):
    return int('{:08b}'.format(x)[::-1], 2)


ZETAS = [pow(ZETA, brv8(i), Q) for i in range(256)]
INV256 = pow(256, Q - 2, Q)


def ntt(a):
    w = list(a)
    m = 0
    ln = 128
    while ln >= 1:
        for start in range(0, 256, 2 * ln):
            m += 1
            z = ZETAS[m]
            for j in range(start, start + ln):
                t = z * w[j + ln] % Q
                w[j + ln] = (w[j] - t) % Q
                w[j] = (w[j] + t) % Q
        ln >>= 1
    return w


def intt(a):
    w = list(a)
    m = 256
    ln = 1
    while ln < 256:
        for start in range(0, 256, 2 * ln):
            m -= 1
            z = -ZETAS[m] % Q
            for j in range(start, start + ln):
                t = w[j]
                w[j] = (t + w[j + ln]) % Q
                w[j + ln] = z * ((t - w[j + ln]) % Q) % Q
        ln <<= 1
    return [x * INV256 % Q for x in w]


def pmul(a, b):
    return [x * y % Q for x, y in zip(a, b)]


def padd(a, b):
    return [(x + y) % Q for x, y in zip(a, b)]


def psub(a, b):
    return [(x - y) % Q for x, y in zip(a, b)]


def modpm(r, a):
    r0 = r % a
    return r0 - a if r0 > a // 2 else r0


def power2round(r):
    rp = r % Q
    r0 = modpm(rp, 1 << D)
    return (rp - r0) >> D, r0


def decompose(r, g2):
    rp = r % Q
    r0 = modpm(rp, 2 * g2)
    if rp - r0 == Q - 1:
        return 0, r0 - 1
    return (rp - r0) // (2 * g2), r0


def highbits(r, g2): return decompose(r, g2)[0]
def lowbits(r, g2): return decompose(r, g2)[1]


def make_hint(z, r, g2):
    return int(highbits(r, g2) != highbits(r + z, g2))


def use_hint(h, r, g2):
    m = (Q - 1) // (2 * g2)
    r1, r0 = decompose(r, g2)
    if h == 1 and r0 > 0:
        return (r1 + 1) % m
    if h == 1 and r0 <= 0:
        return (r1 - 1) % m
    return r1


def shake(alg, data, n):
    return (hashlib.shake_128 if alg == 128 else hashlib.shake_256)(data).digest(n)


def rej_ntt_poly(rho, s, r):
    stream = hashlib.shake_128(rho + bytes([s, r])).digest(3 * 1024)
    a = []
    i = 0
    while len(a) < 256:
        z = stream[i] + 256 * stream[i + 1] + 65536 * (stream[i + 2] & 0x7F)
        i += 3
        if z < Q:
            a.append(z)
    return a


def expand_a(rho, k, l):
    return [[rej_ntt_poly(rho, s, r) for s in range(l)] for r in range(k)]


def coeff_half(b, eta):
    if eta == 2:
        return 2 - (b % 5) if b < 15 else None
    return 4 - b if b < 9 else None


def rej_bounded_poly(seed, eta):
    stream = hashlib.shake_256(seed).digest(1024)
    a = []
    for z in stream:
        z0, z1 = coeff_half(z & 15, eta), coeff_half(z >> 4, eta)
        if z0 is not None and len(a) < 256:
            a.append(z0 % Q)
        if z1 is not None and len(a) < 256:
            a.append(z1 % Q)
        if len(a) == 256:
            return a
    raise AssertionError


def expand_s(rho2, k, l, eta):
    s1 = [rej_bounded_poly(rho2 + r.to_bytes(2, 'little'), eta) for r in range(l)]
    s2 = [rej_bounded_poly(rho2 + (r + l).to_bytes(2, 'little'), eta) for r in range(k)]
    return s1, s2


def bits_to_int(b, nbits_total_unused=None):
    return int.from_bytes(b, 'little')


def simple_bit_pack(poly, bits):
    v = 0
    for i, c in enumerate(poly):
        v |= c << (bits * i)
    return v.to_bytes(bits * 256 // 8, 'little')


def simple_bit_unpack(b, bits):
    v = int.from_bytes(b, 'little')
    return [(v >> (bits * i)) & ((1 << bits) - 1) for i in range(256)]


def expand_mask(rho2, kappa, l, g1):
    c = 1 + (g1 - 1).bit_length()
    out = []
    for r in range(l):
        v = hashlib.shake_256(rho2 + (kappa + r).to_bytes(2, 'little')).digest(32 * c)
        out.append([(g1 - x) % Q for x in simple_bit_unpack(v, c)])
    return out


def sample_in_ball(seed, tau):
    s = hashlib.shake_256(seed).digest(1024)
    signs = int.from_bytes(s[:8], 'little')
    c = [0] * 256
    k = 8
    for i in range(256 - tau, 256):
        while s[k] > i:
            k += 1
        j = s[k]
        k += 1
        c[i] = c[j]
        c[j] = 1 if ((signs >> (i + tau - 256)) & 1) == 0 else Q - 1
    return c


def centered(x):
    x %= Q
    return x - Q if x > Q // 2 else x


def norm_inf(poly):
    return max(abs(centered(x)) for x in poly)


def hint_pack(h, k, omega):
    y = bytearray(omega + k)
    idx = 0
    for i in range(k):
        for j in range(256):
            if h[i][j]:
                y[idx] = j
                idx += 1
        y[omega + i] = idx
    return bytes(y)


def hint_unpack(y, k, omega):
    h = [[0] * 256 for _ in range(k)]
    idx = 0
    for i in range(k):
        if y[omega + i] < idx or y[omega + i] > omega:
            return None
        first = idx
        while idx < y[omega + i]:
            if idx > first and y[idx - 1] >= y[idx]:
                return None
            h[i][y[idx]] = 1
            idx += 1
    for i in range(idx, omega):
        if y[i] != 0:
            return None
    return h


class MlDsa:
    def __init__(self, level):
        self.level = level
        self.p = PARAMS[level]

    def keygen(self, xi):
        p = self.p
        k, l = p['k'], p['l']
        h = hashlib.shake_256(xi + bytes([k, l])).digest(128)
        rho, rho2, K = h[:32], h[32:96], h[96:]
        A = expand_a(rho, k, l)
        s1, s2 = expand_s(rho2, k, l, p['eta'])
        s1h = [ntt(x) for x in s1]
        t = []
        for r in range(k):
            acc = [0] * 256
            for s in range(l):
                acc = padd(acc, pmul(A[r][s], s1h[s]))
            t.append(padd(intt(acc), s2[r]))
        t1, t0 = [], []
        for r in range(k):
            pr = [power2round(c) for c in t[r]]
            t1.append([a for a, b in pr])
            t0.append([b % Q for a, b in pr])
        pk = rho + b''.join(simple_bit_pack(x, 10) for x in t1)
        tr = hashlib.shake_256(pk).digest(64)
        return dict(pk=pk, rho=rho, rho2=rho2, K=K, tr=tr, s1=s1, s2=s2, t0=t0, t1=t1, A=A)

    def sign(self, key, mprime, rnd=bytes(32)):
        p = self.p
        k, l, g1, g2, beta, omega = p['k'], p['l'], p['gamma1'], p['gamma2'], p['beta'], p['omega']
        A, s1, s2, t0 = key['A'], key['s1'], key['s2'], key['t0']
        s1h, s2h, t0h = [ntt(x) for x in s1], [ntt(x) for x in s2], [ntt(x) for x in t0]
        mu = hashlib.shake_256(key['tr'] + mprime).digest(64)
        rho2 = hashlib.shake_256(key['K'] + rnd + mu).digest(64)
        kappa = 0
        attempts = 0
        while True:
            attempts += 1
            y = expand_mask(rho2, kappa, l, g1)
            yh = [ntt(x) for x in y]
            w = []
            for r in range(k):
                acc = [0] * 256
                for s in range(l):
                    acc = padd(acc, pmul(A[r][s], yh[s]))
                w.append(intt(acc))
            w1 = [[highbits(c, g2) for c in poly] for poly in w]
            wbits = 6 if g2 == (Q - 1) // 88 else 4
            ct = hashlib.shake_256(mu + b''.join(simple_bit_pack(x, wbits) for x in w1)).digest(p['lam'] // 4)
            ch = ntt(sample_in_ball(ct, p['tau']))
            cs1 = [intt(pmul(ch, x)) for x in s1h]
            cs2 = [intt(pmul(ch, x)) for x in s2h]
            z = [padd(y[i], cs1[i]) for i in range(l)]
            r0 = [[lowbits(c, g2) for c in psub(w[i], cs2[i])] for i in range(k)]
            if max(norm_inf(x) for x in z) >= g1 - beta or max(max(abs(c) for c in x) for x in r0) >= g2 - beta:
                kappa += l
                continue
            ct0 = [intt(pmul(ch, x)) for x in t0h]
            h = [[make_hint((-ct0[i][j]) % Q, (w[i][j] - cs2[i][j] + ct0[i][j]) % Q, g2) for j in range(256)] for i in range(k)]
            if max(norm_inf(x) for x in ct0) >= g2 or sum(sum(x) for x in h) > omega:
                kappa += l
                continue
            cbits = 1 + (g1 - 1).bit_length()
            zb = b''.join(simple_bit_pack([(g1 - centered(c)) for c in poly], cbits) for poly in z)
            self.last_attempts = attempts
            return ct + zb + hint_pack(h, k, omega)

    def verify(self, pk, mprime, sig):
        p = self.p
        k, l, g1, g2, beta, omega = p['k'], p['l'], p['gamma1'], p['gamma2'], p['beta'], p['omega']
        cbits = 1 + (g1 - 1).bit_length()
        if len(sig) != p['lam'] // 4 + 32 * cbits * l + omega + k or len(pk) != 32 + 320 * k:
            return False
        rho = pk[:32]
        t1 = [simple_bit_unpack(pk[32 + 320 * i:32 + 320 * (i + 1)], 10) for i in range(k)]
        ct = sig[:p['lam'] // 4]
        zb = sig[p['lam'] // 4:p['lam'] // 4 + 32 * cbits * l]
        z = [[(g1 - x) % Q for x in simple_bit_unpack(zb[32 * cbits * i:32 * cbits * (i + 1)], cbits)] for i in range(l)]
        h = hint_unpack(sig[p['lam'] // 4 + 32 * cbits * l:], k, omega)
        if h is None:
            return False
        A = expand_a(rho, k, l)
        tr = hashlib.shake_256(pk).digest(64)
        mu = hashlib.shake_256(tr + mprime).digest(64)
        ch = ntt(sample_in_ball(ct, p['tau']))
        zh = [ntt(x) for x in z]
        t1h = [ntt([(c << D) % Q for c in x]) for x in t1]
        w1 = []
        for r in range(k):
            acc = [0] * 256
            for s in range(l):
                acc = padd(acc, pmul(A[r][s], zh[s]))
            acc = psub(acc, pmul(ch, t1h[r]))
            wa = intt(acc)
            w1.append([use_hint(h[r][j], wa[j], g2) for j in range(256)])
        wbits = 6 if g2 == (Q - 1) // 88 else 4
        ct2 = hashlib.shake_256(mu + b''.join(simple_bit_pack(x, wbits) for x in w1)).digest(p['lam'] // 4)
        return max(norm_inf(x) for x in z) < g1 - beta and ct == ct2
