"""Curve parameters of the elliptic-curve engine of the digital signature IP.

The constants are checked by self_test(): p prime, G on the curve, n times G is the identity, and the
group order is prime (Miller-Rabin). Sources: FIPS 186-5 / SP 800-186 (NIST curves), SEC 2 (secp256k1),
RFC 8032 (Ed25519, Ed448)."""

import random


def is_prime(n, k=24):
    if n < 4:
        return n in (2, 3)
    if n % 2 == 0:
        return False
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    rnd = random.Random(1234)
    for _ in range(k):
        a = rnd.randrange(2, n - 1)
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = x * x % n
            if x == n - 1:
                break
        else:
            return False
    return True


class Curve:
    pass


def _w(name, p, n, a, b, gx, gy, nbytes):
    c = Curve()
    c.name, c.kind, c.p, c.n, c.a, c.b, c.gx, c.gy, c.nbytes = name, 'W', p, n, a % p, b, gx, gy, nbytes
    c.nbits = n.bit_length()
    c.pbits = p.bit_length()
    return c


def _e(name, p, n, a, d, gx, gy, nbytes, cofactor):
    c = Curve()
    c.name, c.kind, c.p, c.n, c.a, c.d, c.gx, c.gy, c.nbytes, c.cofactor = name, 'E', p, n, a % p, d % p, gx, gy, nbytes, cofactor
    c.nbits = n.bit_length()
    c.pbits = p.bit_length()
    return c


P256 = _w('P-256', 2**256 - 2**224 + 2**192 + 2**96 - 1,
          0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551, -3,
          0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B,
          0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296,
          0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5, 32)
P384 = _w('P-384', 2**384 - 2**128 - 2**96 + 2**32 - 1,
          0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52973, -3,
          0xB3312FA7E23EE7E4988E056BE3F82D19181D9C6EFE8141120314088F5013875AC656398D8A2ED19D2A85C8EDD3EC2AEF,
          0xAA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7,
          0x3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F, 48)
P521 = _w('P-521', 2**521 - 1,
          int('01FF' + 'FF' * 31 + 'FA51868783BF2F966B7FCC0148F709A5D03BB5C9B8899C47AEBB6FB71E91386409', 16),
          -3,
          0x0051953EB9618E1C9A1F929A21A0B68540EEA2DA725B99B315F3B8B489918EF109E156193951EC7E937B1652C0BD3BB1BF073573DF883D2C34F1EF451FD46B503F00,
          0x00C6858E06B70404E9CD9E3ECB662395B4429C648139053FB521F828AF606B4D3DBAA14B5E77EFE75928FE1DC127A2FFA8DE3348B3C1856A429BF97E7E31C2E5BD66,
          0x011839296A789A3BC0045C8A5FB42C7D1BD998F54449579B446817AFBD17273E662C97EE72995EF42640C550B9013FAD0761353C7086A272C24088BE94769FD16650, 66)
K256 = _w('secp256k1', 2**256 - 2**32 - 977,
          0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141, 0, 7,
          0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
          0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8, 32)

_p25519 = 2**255 - 19
_d25519 = (-121665 * pow(121666, -1, _p25519)) % _p25519


def _recover_x(y, p, d, a, sign):
    """x of the Edwards point with y (RFC 8032 section 5.1.3 / 5.2.3), or None."""
    u = (y * y - 1) % p
    v = (d * y * y - a) % p
    if p % 8 == 5:
        x = (u * pow(v, 3, p) * pow(u * pow(v, 7, p), (p - 5) // 8, p)) % p
        if (v * x * x - u) % p != 0:
            x = x * pow(2, (p - 1) // 4, p) % p
    else:
        x = (u * pow(v, 3, p) * pow(u * pow(v, 5, p), (p - 3) // 4, p)) % p
    if (v * x * x - u) % p != 0:
        return None
    if x == 0 and sign:
        return None
    if (x & 1) != sign:
        x = p - x
    return x


_gy25519 = 4 * pow(5, -1, _p25519) % _p25519
_gx25519 = _recover_x(_gy25519, _p25519, _d25519, -1, 0)
ED25519 = _e('Ed25519', _p25519, 2**252 + 27742317777372353535851937790883648493, -1, _d25519, _gx25519, _gy25519, 32, 8)

_p448 = 2**448 - 2**224 - 1
_d448 = (-39081) % _p448
_L448 = 2**446 - 13818066809895115352007386748515426880336692474882178609894547503885
_gy448 = int('2988192100784814926760179304' + '43930673437544040154080242095928241372331506189835876' + '00353687865541878473398230323350346250053154506283266' + '0')
_gx448 = int('224580' + '04029592430018760433409989603624678964163256413424612' + '54616869504154674060329090291928693579532825780320751' + '46446173674602635247710')
ED448 = _e('Ed448', _p448, _L448, 1, _d448, _gx448, _gy448, 57, 4)

CURVES = {'P-256': P256, 'P-384': P384, 'P-521': P521, 'secp256k1': K256, 'Ed25519': ED25519, 'Ed448': ED448}


# ---- affine reference arithmetic (textbook group law) used only to check the constants and the microcode

def w_add(c, P, Q):
    if P is None:
        return Q
    if Q is None:
        return P
    p = c.p
    if P[0] == Q[0]:
        if (P[1] + Q[1]) % p == 0:
            return None
        lam = (3 * P[0] * P[0] + c.a) * pow(2 * P[1], -1, p) % p
    else:
        lam = (Q[1] - P[1]) * pow(Q[0] - P[0], -1, p) % p
    x = (lam * lam - P[0] - Q[0]) % p
    return (x, (lam * (P[0] - x) - P[1]) % p)


def e_add(c, P, Q):
    p, d, a = c.p, c.d, c.a
    x1, y1 = P
    x2, y2 = Q
    t = d * x1 * x2 * y1 * y2 % p
    x3 = (x1 * y2 + x2 * y1) * pow(1 + t, -1, p) % p
    y3 = (y1 * y2 - a * x1 * x2) * pow(1 - t, -1, p) % p
    return (x3, y3)


def mul(c, k, P):
    add = w_add if c.kind == 'W' else e_add
    R = None if c.kind == 'W' else (0, 1)
    for i in range(k.bit_length() - 1, -1, -1):
        R = add(c, R, R)
        if (k >> i) & 1:
            R = add(c, R, P)
    return R


def self_test():
    ok = True
    for c in CURVES.values():
        res = []
        res.append(is_prime(c.p))
        if c.kind == 'W':
            res.append((c.gy * c.gy - (c.gx ** 3 + c.a * c.gx + c.b)) % c.p == 0)
            res.append(mul(c, c.n, (c.gx, c.gy)) is None)
        else:
            res.append((c.a * c.gx * c.gx + c.gy * c.gy - 1 - c.d * c.gx * c.gx * c.gy * c.gy) % c.p == 0)
            res.append(mul(c, c.n, (c.gx, c.gy)) == (0, 1))
        res.append(is_prime(c.n))
        print('%-10s p prime %s, G on curve %s, n*G = identity %s, n prime %s' % ((c.name,) + tuple(res[:4])))
        ok = ok and all(res)
    return ok


if __name__ == '__main__':
    print('ALL OK' if self_test() else 'FAILED')
