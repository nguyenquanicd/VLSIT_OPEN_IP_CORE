"""Programs of the elliptic-curve engine: Ed25519 (verify, sign, key generation) and ECDSA on P-256,
P-384, P-521 and secp256k1 (verify, sign, key generation). Register map (all programs):
  R0..R3   accumulator point (Edwards X Y Z T, Weierstrass X Y Z)
  R4..R7   second operand of the point addition
  R8..R11  base point of SMUL (and the public key in the ECDSA verify)
  R12..R15 saved point
  R16..R23 temporaries of the subroutines (SMUL and the point additions overwrite them)
  R24..R27, R30, R31  program variables;  R28 curve constant a;  R29 curve constant d (Edwards) or 3b (Weierstrass)
Flag F7 is the result of END (1: valid / done)."""

from ec_curves import CURVES
from ec_isa import *


def consts(c):
    k = {}
    k['BIG'] = 1 << 575
    k['P'], k['N'], k['NM1'] = c.p, c.n, c.n - 1
    k['A'] = c.a
    k['PM2'], k['NM2'] = c.p - 2, c.n - 2
    k['GX'], k['GY'] = c.gx, c.gy
    k['NBITS'], k['PBITS'] = c.nbits, c.pbits
    if c.kind == 'E':
        k['D'] = c.d
        k['GT'] = c.gx * c.gy % c.p
        for i, v in enumerate([0, 1, 1, 0]):
            k['IDENT%d' % i] = v
        k['MASKY'] = (1 << (8 * c.nbytes - 1)) - 1
        if c.name == 'Ed448':
            k['P34'] = (c.p - 3) // 4
            k['CLAMP_AND'] = (1 << 448) - 4
            k['CLAMP_OR'] = 1 << 447
            k['TWO576'] = pow(2, 576, c.n)
        if c.name == 'Ed25519':
            k['P58'] = (c.p - 5) // 8
            k['SQRTM1'] = pow(2, (c.p - 1) // 4, c.p)
            k['CLAMP_AND'] = (1 << 254) - 8
            k['CLAMP_OR'] = 1 << 254
    else:
        k['B3'] = 3 * c.b % c.p
        k['B'] = c.b
        for i, v in enumerate([0, 1, 0, 0]):
            k['IDENT%d' % i] = v
        k['HIFACTOR'] = pow(2, 8 * c.nbytes, c.n - 1)
    return k


def build_point_code(asm, c):
    """Subroutines: PADD_BODY (acc = acc + R4..), ADD (R4.. = R8.., then body), DBL (R4.. = R0.., then body)."""
    if c.kind == 'E':
        asm.label('DBL')
        for i in range(4):
            asm.mov(4 + i, i)
        asm.jmp('PADD_BODY')
        asm.label('ADD')
        for i in range(4):
            asm.mov(4 + i, 8 + i)
        asm.label('PADD_BODY')
        # unified addition of Hisil, Wong, Carter, Dawson (2008), general a
        asm.mul(16, 0, 4)       # A = X1 X2
        asm.mul(17, 1, 5)       # B = Y1 Y2
        asm.mul(18, 3, 29)      # T1 d
        asm.mul(18, 18, 7)      # C = T1 d T2
        asm.mul(19, 2, 6)       # D = Z1 Z2
        asm.add(20, 0, 1)
        asm.add(21, 4, 5)
        asm.mul(20, 20, 21)
        asm.sub(20, 20, 16)
        asm.sub(20, 20, 17)     # E
        asm.sub(21, 19, 18)     # F = D - C
        asm.add(22, 19, 18)     # G = D + C
        asm.mul(23, 28, 16)     # a A
        asm.sub(23, 17, 23)     # H = B - a A
        asm.mul(0, 20, 21)      # X3 = E F
        asm.mul(1, 22, 23)      # Y3 = G H
        asm.mul(3, 20, 23)      # T3 = E H
        asm.mul(2, 21, 22)      # Z3 = F G
        asm.ret()
    else:
        asm.label('DBL')
        for i in range(3):
            asm.mov(4 + i, i)
        asm.jmp('PADD_BODY')
        asm.label('ADD')
        for i in range(3):
            asm.mov(4 + i, 8 + i)
        asm.label('PADD_BODY')
        # complete addition, Renes, Costello, Batina 2016, algorithm 1 (general a)
        X1, Y1, Z1, X2, Y2, Z2, a, b3 = 0, 1, 2, 4, 5, 6, 28, 29
        t0, t1, t2, t3, t4, t5, X3, Y3, Z3 = 16, 17, 18, 19, 20, 21, 22, 23, 3   # R3 is free for Weierstrass curves
        m, ad, sb = asm.mul, asm.add, asm.sub
        m(t0, X1, X2); m(t1, Y1, Y2); m(t2, Z1, Z2)
        ad(t3, X1, Y1); ad(t4, X2, Y2); m(t3, t3, t4)
        ad(t4, t0, t1); sb(t3, t3, t4)
        ad(t4, X1, Z1); ad(t5, X2, Z2); m(t4, t4, t5)
        ad(t5, t0, t2); sb(t4, t4, t5)
        ad(t5, Y1, Z1); ad(X3, Y2, Z2); m(t5, t5, X3)
        ad(X3, t1, t2); sb(t5, t5, X3)
        m(Z3, a, t4); m(X3, b3, t2); ad(Z3, X3, Z3)
        sb(X3, t1, Z3); ad(Z3, t1, Z3); m(Y3, X3, Z3)
        ad(t1, t0, t0); ad(t1, t1, t0); m(t2, a, t2)
        m(t4, b3, t4); ad(t1, t1, t2); sb(t2, t0, t2)
        m(t2, a, t2); ad(t4, t4, t2); m(t0, t1, t4)
        ad(Y3, Y3, t0); m(t0, t5, t4); m(X3, t3, X3)
        sb(X3, X3, t0); m(t0, t3, t1); m(Z3, t5, Z3)
        ad(Z3, Z3, t0)
        asm.mov(0, X3); asm.mov(1, Y3); asm.mov(2, Z3)
        asm.ret()


def load_base(asm, c):
    """Base point G into R8..: subroutine LOADG."""
    asm.label('LOADG')
    asm.ldc(8, 'GX')
    asm.ldc(9, 'GY')
    asm.ldi(10, 1)
    if c.kind == 'E':
        asm.ldc(11, 'GT')
    asm.ret()


def ed_encode(asm, c):
    """Subroutine ENC: acc (R0..R3) to the encoded point in R19: y with the sign of x at bit 8*nbytes-1."""
    asm.label('ENC')
    asm.ldc(16, 'PM2')
    asm.pow(20, 2, 16)           # 1/Z
    asm.mul(21, 0, 20)           # x
    asm.mul(22, 1, 20)           # y
    asm.bit(0, 21, 0)
    asm.setb(19, 22, 8 * c.nbytes - 1, 0)
    asm.ret()


_BL = [0]


def smul_secret(a, c, k, nbits):
    """Scalar multiplication by a secret scalar in register k. With masking of the elliptic-curve engine (LDV 2 = 1,
    PARA_EN_DPA_EC) the scalar is blinded first (Coron): k' = k + r n with a 48-bit r from the random pool (bytes 88 to 93),
    so k' G = k G while the bits that are processed change for every operation. Uses R14, R15 and flag F0."""
    _BL[0] += 1
    plain, done = 'SMS_P%d' % _BL[0], 'SMS_E%d' % _BL[0]
    a.ldv(14, 2); a.isz(0, 14); a.brf(0, plain)
    a.setm(SEL_BIG)
    a.ldr(14, 88, 6, BE); a.ldc(15, 'N'); a.mul(14, 14, 15); a.add(14, 14, k)
    a.setm(SEL_P)
    a.smul(14, max(nbits, c.nbits + 48) + 1, 'DBL', 'ADD')
    a.jmp(done)
    a.label(plain)
    a.smul(k, nbits, 'DBL', 'ADD')
    a.label(done)


def ed_hash(a, parts, dom):
    """SHA-512 of [dom2(f, ctx)] || parts || message; dom2 = prefix, f, len(ctx) in the head, the context as the first tail,
    the parts as the mid segment, the message as the second tail."""
    a.hdclr()
    if dom:
        a.hdimm(1); a.ldv(16, 0); a.hdreg(16, 1, LE); a.ldv(17, 1); a.hdreg(17, 1, LE); a.hmid()
    for r, ln in parts:
        a.hdreg(r, ln, LE)
    a.hgo(H_SHA512, 2 if dom else 1)


def prog_ed(c, op, vas=False, dom=False):
    a = Asm()
    nb = c.nbytes
    assert c.name == 'Ed25519'
    a.label('START')
    a.setm(SEL_P)
    a.ldc(28, 'A')
    a.ldc(29, 'D')
    if op == 'verify':
        sigarea = AREA_RES if vas else AREA_SIG
        if vas:
            # verify-after-sign: the public key is derived from the private key
            a.ldk(24, 0, nb, LE)
            a.hdclr(); a.hdreg(24, nb, LE); a.hgo(H_SHA512, 0)
            a.hrd(25, 0, 32, LE)
            a.ldc(16, 'CLAMP_AND'); a.and_(25, 25, 16); a.ldc(16, 'CLAMP_OR'); a.or_(25, 25, 16)
            a.call('LOADG'); smul_secret(a, c, 25, 255); a.call('ENC'); a.mov(26, 19)
        a.rdb(24, sigarea, 0, nb, LE)           # R encoded
        a.rdb(25, sigarea, nb, nb, LE)          # S
        if not vas:
            a.rdb(26, AREA_PK, 0, nb, LE)        # A encoded
        ed_hash(a, [(24, nb), (26, nb)], dom)
        a.hrd(27, 0, 64, LE)
        a.setm(SEL_N); a.red(27, 27); a.setm(SEL_P)          # k
        a.ldc(16, 'N'); a.ltu(0, 25, 16); a.brn(0, 'FAIL')    # S < L
        # decode A
        a.ldc(16, 'MASKY'); a.and_(17, 26, 16); a.bit(1, 26, 8 * nb - 1)
        a.ldc(16, 'P'); a.ltu(0, 17, 16); a.brn(0, 'FAIL')
        a.ldi(20, 1)
        a.mul(18, 17, 17); a.sub(19, 18, 20)                 # u = y^2 - 1
        a.mul(21, 18, 29); a.add(21, 21, 20)                 # v = d y^2 + 1
        a.mul(22, 21, 21); a.mul(22, 22, 21)                 # v^3
        a.mul(23, 22, 22); a.mul(23, 23, 21); a.mul(23, 23, 19)   # u v^7
        a.ldc(16, 'P58'); a.pow(23, 23, 16)
        a.mul(22, 22, 19); a.mul(22, 22, 23)                 # x candidate
        a.mul(23, 22, 22); a.mul(23, 23, 21); a.eq(0, 23, 19)     # v x^2 == u
        a.ldc(16, 'SQRTM1'); a.mul(20, 22, 16)
        a.mul(23, 20, 20); a.mul(23, 23, 21); a.eq(2, 23, 19)
        a.fnot(3, 0); a.fand(3, 3, 2); a.cmov(22, 20, 3)
        a.forr(4, 0, 2); a.brn(4, 'FAIL')
        a.isz(5, 22); a.fand(5, 5, 1); a.brf(5, 'FAIL')
        a.bit(6, 22, 0)
        a.fand(3, 6, 1); a.forr(2, 6, 1); a.fnot(3, 3); a.fand(2, 2, 3)   # parity != sign
        a.ldi(16, 0); a.sub(20, 16, 22); a.cmov(22, 20, 2)
        # -A into R12..R15
        a.ldi(16, 0); a.sub(12, 16, 22); a.mov(13, 17); a.ldi(14, 1); a.mul(15, 12, 13)
        # k * (-A)
        for i in range(4):
            a.mov(8 + i, 12 + i)
        a.smul(27, 253, 'DBL', 'ADD')
        for i in range(4):
            a.mov(12 + i, i)
        a.call('LOADG')
        a.smul(25, 253, 'DBL', 'ADD')
        for i in range(4):
            a.mov(4 + i, 12 + i)
        a.call('PADD_BODY')
        a.call('ENC')
        a.eq(7, 19, 24)
        a.end()
        a.label('FAIL'); a.fset(7, 0); a.end()
    elif op in ('sign', 'keygen'):
        a.ldk(24, 0, nb, LE)
        a.hdclr(); a.hdreg(24, nb, LE)
        a.hgo(H_SHA512, 0)
        a.hrd(25, 0, 32, LE); a.hrd(26, 32, 32, LE)
        a.ldc(16, 'CLAMP_AND'); a.and_(25, 25, 16); a.ldc(16, 'CLAMP_OR'); a.or_(25, 25, 16)
        a.call('LOADG')
        smul_secret(a, c, 25, 255)
        a.call('ENC'); a.mov(27, 19)                         # encoded A
        if op == 'keygen':
            a.wrb(27, AREA_RES, 0, nb, LE)
        else:
            ed_hash(a, [(26, 32)], dom)
            a.hrd(31, 0, 64, LE); a.setm(SEL_N); a.red(31, 31); a.setm(SEL_P)     # r
            a.call('LOADG')
            smul_secret(a, c, 31, 253)
            a.call('ENC'); a.mov(30, 19)                     # encoded R
            ed_hash(a, [(30, nb), (27, nb)], dom)
            a.hrd(12, 0, 64, LE); a.setm(SEL_N); a.red(12, 12)       # k
            a.red(25, 25)                                    # s mod L
            a.mul(13, 12, 25); a.add(13, 13, 31)             # S = r + k s
            a.wrb(30, AREA_RES, 0, nb, LE); a.wrb(13, AREA_RES, nb, nb, LE)
        a.fset(7, 1); a.end()
    build_point_code(a, c)
    load_base(a, c)
    ed_encode(a, c)
    return a


STRINGS = {0: b'SigEd448', 1: b'SigEd25519 no Ed25519 collisions'}


def prog_ed448(c, op, vas=False):
    """Ed448 with the empty context (RFC 8032 section 5.2). A context needs a second tail in the hash feeder."""
    a = Asm()
    nb = c.nbytes     # 57
    a.label('START')
    a.setm(SEL_P)
    a.ldc(28, 'A')
    a.ldc(29, 'D')

    def hash_to_scalar(dst, parts, tail):
        """dst = SHAKE256(dom4 || parts || [message]) mod L; parts is a list of (register, length)."""
        a.hdclr(); a.hdimm(0); a.ldv(20, 0); a.hdreg(20, 1, LE); a.ldv(21, 1); a.hdreg(21, 1, LE); a.hmid()
        for reg, ln in parts:
            a.hdreg(reg, ln, LE)
        a.hgo(H_SHAKE256, 2 if tail else 0, 114)
        a.hrd(dst, 0, 72, LE); a.hrd(21, 72, 42, LE)
        a.setm(SEL_N); a.red(dst, dst); a.red(21, 21)
        a.ldc(20, 'TWO576'); a.mul(21, 21, 20); a.add(dst, dst, 21)
        a.setm(SEL_P)

    if op == 'verify':
        sigarea = AREA_RES if vas else AREA_SIG
        if vas:
            a.ldk(24, 0, nb, LE)
            a.hdclr(); a.hdreg(24, nb, LE); a.hgo(H_SHAKE256, 0, 114)
            a.hrd(25, 0, nb, LE)
            a.ldc(16, 'CLAMP_AND'); a.and_(25, 25, 16); a.ldc(16, 'CLAMP_OR'); a.or_(25, 25, 16)
            a.call('LOADG'); smul_secret(a, c, 25, 448); a.call('ENC'); a.mov(26, 19)
        a.rdb(24, sigarea, 0, nb, LE)
        a.rdb(25, sigarea, nb, nb, LE)
        if not vas:
            a.rdb(26, AREA_PK, 0, nb, LE)
        hash_to_scalar(27, [(24, nb), (26, nb)], 1)          # k
        a.ldc(16, 'N'); a.ltu(0, 25, 16); a.brn(0, 'FAIL')
        a.ldc(16, 'MASKY'); a.and_(17, 26, 16); a.bit(1, 26, 8 * nb - 1)
        a.ldc(16, 'P'); a.ltu(0, 17, 16); a.brn(0, 'FAIL')
        a.ldi(20, 1)
        a.mul(18, 17, 17); a.sub(19, 18, 20)                 # u = y^2 - 1
        a.mul(21, 18, 29); a.sub(21, 21, 20)                 # v = d y^2 - 1
        a.mul(22, 19, 19); a.mul(22, 22, 19)                 # u^3
        a.mul(22, 22, 21)                                    # u^3 v
        a.mul(23, 19, 19); a.mul(23, 23, 23); a.mul(23, 23, 19)   # u^5
        a.mul(20, 21, 21); a.mul(20, 20, 21)                 # v^3
        a.mul(23, 23, 20)                                    # u^5 v^3
        a.ldc(16, 'P34'); a.pow(23, 23, 16)
        a.mul(22, 22, 23)                                    # x candidate
        a.mul(23, 22, 22); a.mul(23, 23, 21); a.eq(0, 23, 19)
        a.brn(0, 'FAIL')
        a.isz(5, 22); a.fand(5, 5, 1); a.brf(5, 'FAIL')
        a.bit(6, 22, 0)
        a.fand(3, 6, 1); a.forr(2, 6, 1); a.fnot(3, 3); a.fand(2, 2, 3)
        a.ldi(16, 0); a.sub(20, 16, 22); a.cmov(22, 20, 2)
        a.ldi(16, 0); a.sub(12, 16, 22); a.mov(13, 17); a.ldi(14, 1); a.mul(15, 12, 13)
        for i in range(4):
            a.mov(8 + i, 12 + i)
        a.smul(27, 446, 'DBL', 'ADD')
        for i in range(4):
            a.mov(12 + i, i)
        a.call('LOADG')
        a.smul(25, 446, 'DBL', 'ADD')
        for i in range(4):
            a.mov(4 + i, 12 + i)
        a.call('PADD_BODY')
        a.call('ENC')
        a.eq(7, 19, 24)
        a.end()
        a.label('FAIL'); a.fset(7, 0); a.end()
    else:
        a.ldk(24, 0, nb, LE)
        a.hdclr(); a.hdreg(24, nb, LE)
        a.hgo(H_SHAKE256, 0, 114)
        a.hrd(25, 0, nb, LE); a.hrd(26, nb, nb, LE)
        a.ldc(16, 'CLAMP_AND'); a.and_(25, 25, 16); a.ldc(16, 'CLAMP_OR'); a.or_(25, 25, 16)
        a.call('LOADG')
        smul_secret(a, c, 25, 448)
        a.call('ENC'); a.mov(27, 19)
        if op == 'keygen':
            a.wrb(27, AREA_RES, 0, nb, LE)
        else:
            hash_to_scalar(31, [(26, nb)], 1)                # r
            a.call('LOADG')
            smul_secret(a, c, 31, 446)
            a.call('ENC'); a.mov(30, 19)
            hash_to_scalar(12, [(30, nb), (27, nb)], 1)      # k
            a.setm(SEL_N); a.red(25, 25)
            a.mul(13, 12, 25); a.add(13, 13, 31)
            a.wrb(30, AREA_RES, 0, nb, LE); a.wrb(13, AREA_RES, nb, nb, LE)
        a.fset(7, 1); a.end()
    build_point_code(a, c)
    load_base(a, c)
    ed_encode(a, c)
    return a


HASH_LEN = {H_SHA256: (32, 64), H_SHA384: (48, 128), H_SHA512: (64, 128)}


def rfc6979_k(a, c, hmode):
    """k of RFC 6979 section 3.2 into R30 (HMAC_DRBG with the hash hmode). Inputs: R25 = x, R26 = bits2int(h1) mod q.
    Uses R0 (K), R1 (V), R2/R3 (ipad/opad bytes), R4, R5 (temporaries), R6 = 0, R7 = 1, R8 (first block of T)."""
    hlen, block = HASH_LEN[hmode]
    rlen = c.nbytes
    nblk = -(-c.nbits // (8 * hlen))
    tbytes = -(-c.nbits // 8)

    def pad(reg):
        n = block - hlen
        while n > 0:
            ln = min(n, 72)
            a.hdreg(reg, ln, BE)
            n -= ln

    def hmac(dst, parts):
        a.xorb(4, 0, 0x36)
        a.hdclr(); a.hdreg(4, hlen, BE); pad(2); a.hmid()
        for r, ln in parts:
            a.hdreg(r, ln, BE)
        a.hgo(hmode, 3); a.hrdv(5)
        a.xorb(4, 0, 0x5C)
        a.hdclr(); a.hdreg(4, hlen, BE); pad(3); a.hmid(); a.hdreg(5, hlen, BE)
        a.hgo(hmode, 3); a.hrdv(dst)

    a.ldi(2, 0); a.xorb(2, 2, 0x36)
    a.ldi(3, 0); a.xorb(3, 3, 0x5C)
    a.ldi(6, 0); a.ldi(7, 1)
    a.ldi(0, 0)                                         # K = 0x00 ... 00
    a.ldi(1, 0); a.xorb(1, 1, 0x01)                     # V = 0x01 ... 01
    for sep in (6, 7):
        hmac(0, [(1, hlen), (sep, 1), (25, rlen), (26, rlen)])
        hmac(1, [(1, hlen)])
    a.label('K6979')
    hmac(1, [(1, hlen)])
    if nblk == 1:
        a.trunce(30, 1)
    else:
        # T = V1 || V2 || ...; k = leftmost qlen bits of the first ceil(qlen / 8) bytes of T
        a.mov(8, 1)
        have = hlen
        while have < tbytes:
            hmac(1, [(1, hlen)])
            take = min(hlen, tbytes - have)
            a.shl(8, 8, 8 * take); a.shr(9, 1, 8 * (hlen - take)); a.or_(8, 8, 9)
            have += take
        a.shr(30, 8, 8 * tbytes - c.nbits)
    a.ldc(16, 'N'); a.ltu(0, 30, 16); a.isz(1, 30); a.fnot(1, 1); a.fand(0, 0, 1)
    a.brn(0, 'K6979_RETRY')
    a.jmp('K6979_OK')
    a.label('K6979_RETRY')
    hmac(0, [(1, hlen), (6, 1)])
    hmac(1, [(1, hlen)])
    a.jmp('K6979')
    a.label('K6979_OK')



def prog_ecdsa(c, op, vas=False, det=None):
    a = Asm()
    nb = c.nbytes
    a.label('START')
    a.setm(SEL_P)
    a.ldc(28, 'A')
    a.ldc(29, 'B3')
    if op == 'verify':
        sigarea = AREA_RES if vas else AREA_SIG
        if vas:
            a.ldk(25, 0, nb, BE)
            a.call('LOADG'); smul_secret(a, c, 25, c.nbits)
            a.ldc(16, 'PM2'); a.pow(20, 2, 16); a.mul(21, 0, 20); a.mul(22, 1, 20)
            a.mov(8, 21); a.mov(9, 22)
        a.rdb(24, sigarea, 0, nb, BE); a.rdb(25, sigarea, nb, nb, BE)
        if not vas:
            a.rdb(8, AREA_PK, 0, nb, BE); a.rdb(9, AREA_PK, nb, nb, BE)
        a.ldc(16, 'N')
        a.ltu(0, 24, 16); a.isz(1, 24); a.fnot(1, 1); a.fand(0, 0, 1)
        a.ltu(2, 25, 16); a.isz(3, 25); a.fnot(3, 3); a.fand(2, 2, 3)
        a.fand(0, 0, 2); a.brn(0, 'FAIL')
        a.ldc(16, 'P'); a.ltu(1, 8, 16); a.ltu(2, 9, 16); a.fand(1, 1, 2); a.brn(1, 'FAIL')
        a.mul(16, 9, 9); a.mul(17, 8, 8); a.mul(17, 17, 8); a.mul(18, 28, 8); a.add(17, 17, 18)
        a.ldc(18, 'B'); a.add(17, 17, 18); a.eq(3, 16, 17); a.brn(3, 'FAIL')
        a.hdclr(); a.hgo(HASH_MODE_OP, 1)
        a.hrdv(26); a.trunce(26, 26)
        a.setm(SEL_N); a.red(26, 26)
        a.ldc(16, 'NM2'); a.pow(27, 25, 16)          # w = s^-1
        a.mul(30, 26, 27); a.mul(31, 24, 27)        # u1, u2
        a.setm(SEL_P)
        a.ldi(10, 1)
        a.smul(31, c.nbits, 'DBL', 'ADD')            # u2 Q
        for i in range(3):
            a.mov(12 + i, i)
        a.call('LOADG')
        a.smul(30, c.nbits, 'DBL', 'ADD')            # u1 G
        for i in range(3):
            a.mov(4 + i, 12 + i)
        a.call('PADD_BODY')
        a.isz(4, 2); a.brf(4, 'FAIL')
        a.ldc(16, 'PM2'); a.pow(20, 2, 16); a.mul(21, 0, 20)
        a.setm(SEL_N); a.red(21, 21)
        a.eq(7, 21, 24)
        a.end()
        a.label('FAIL'); a.fset(7, 0); a.end()
    else:
        a.ldk(25, 0, nb, BE)                          # d
        a.ldc(16, 'N'); a.ltu(0, 25, 16); a.isz(1, 25); a.fnot(1, 1); a.fand(0, 0, 1); a.brn(0, 'BADKEY')
        if op == 'sign' and det is not None:
            # deterministic nonce (RFC 6979) with the hash det; z = bits2int(H(m)) mod q
            a.hdclr(); a.hgo(det, 1)
            a.hrdv(26); a.trunce(26, 26)
            a.setm(SEL_N); a.red(26, 26); a.setm(SEL_P)
            rfc6979_k(a, c, det)
        elif op == 'sign':
            a.ldr(17, 0, nb, BE); a.ldr(18, nb, 8, BE)
            a.setm(SEL_NM1); a.red(17, 17); a.red(18, 18)
            a.ldc(16, 'HIFACTOR'); a.mul(18, 18, 16); a.add(30, 17, 18)
            a.setm(SEL_N); a.ldi(16, 1); a.add(30, 30, 16)                  # k in 1..n-1
            a.setm(SEL_P)
        if op == 'sign':
            a.call('LOADG')
            smul_secret(a, c, 30, c.nbits)
            a.ldc(16, 'PM2'); a.pow(20, 2, 16); a.mul(21, 0, 20)
            a.setm(SEL_N); a.red(27, 21)                                  # r
            a.isz(4, 27); a.brf(4, 'BADPT')
            a.hdclr(); a.hgo(HASH_MODE_OP, 1)
            a.hrdv(26); a.trunce(26, 26); a.red(26, 26)                   # e
            a.ldc(16, 'NM2'); a.pow(31, 30, 16)                           # k^-1
            a.mul(22, 27, 25); a.add(22, 22, 26); a.mul(22, 22, 31)       # s
            a.isz(4, 22); a.brf(4, 'BADPT')
            a.wrb(27, AREA_RES, 0, nb, BE); a.wrb(22, AREA_RES, nb, nb, BE)
        else:
            a.call('LOADG')
            smul_secret(a, c, 25, c.nbits)
            a.ldc(16, 'PM2'); a.pow(20, 2, 16); a.mul(21, 0, 20); a.mul(22, 1, 20)
            a.wrb(21, AREA_RES, 0, nb, BE); a.wrb(22, AREA_RES, nb, nb, BE)
        a.fset(7, 1); a.end()
        a.label('BADKEY'); a.err(ERR_BADKEY)
        a.label('BADPT'); a.err(ERR_BADPT)
    build_point_code(a, c)
    load_base(a, c)
    return a


def assemble(asm):
    return asm.resolve(0)
