"""Instruction set, assembler and bit-exact model of the lattice processor of the ML-DSA engine (m_vlsit_dsig_lat) of the
digital signature IP. A 32-bit processor with 32 registers, 8 flags, a word RAM (polynomial and scratch storage), byte access
to the buffer, the key seed and the random pool, modular arithmetic modulo q = 8380417, a divider, a table of the
zeta powers of the NTT, a table of the parameters of the selected ML-DSA set and a byte-stream interface to the hash sequencer
(SHAKE128 and SHAKE256). ML-DSA key generation, signing and verification are programs (hbs-like microcode written in
lat_prog.py, tested against OpenSSL 3.5 through mldsa_ref.py); gen_lat_rom.py turns them into the ROM of the RTL.

Instruction word (64 bits): op[63:58] rd[57:53] ra[52:48] rb[47:43] imm[42:0].
"""
import hashlib

Q = 8380417
M32 = 0xFFFFFFFF

OPS = ['NOP', 'LDI', 'MOV', 'ADD', 'SUB', 'AND', 'OR', 'XOR', 'ADDI', 'SUBI', 'ANDI', 'SHLI', 'SHRI', 'SARI', 'SHL', 'SHR', 'SAR',
       'MULL', 'MULQ', 'ADDQ', 'SUBQ', 'DIVU', 'MODU', 'LDZ', 'LDP', 'LDS',
       'EQ', 'LTU', 'LTS', 'EQI', 'ISZ', 'FNOT', 'FAND', 'FOR', 'FSET',
       'BRF', 'BRN', 'JMP', 'CALL', 'RET', 'END', 'ERR',
       'LW', 'SW', 'BLB', 'BSB', 'LDK', 'LDR',
       'XSTART', 'XPUT', 'XFIN', 'XGET', 'XDRAIN']
OPC = {n: i for i, n in enumerate(OPS)}

AREA_MSG, AREA_SIG, AREA_PK, AREA_RES = 0, 1, 2, 3
# LDS selectors
S_LEN_MSG, S_LEN_CTX, S_FORM, S_OP, S_LEVEL, S_HEDGED, S_HASH, S_DPA = range(8)
# LDP fields of the parameter table
(P_K, P_L, P_ETA, P_TAU, P_LAM4, P_G1, P_G2, P_BETA, P_OMEGA, P_CBITS, P_WBITS, P_ALPHA, P_M, P_GB, P_G2B) = range(1, 16)
H_SHAKE128, H_SHAKE256 = 12, 13


def brv8(x):
    return int('{:08b}'.format(x)[::-1], 2)


ZETAS = [pow(1753, brv8(i), Q) for i in range(256)]

PARAMS = {
    44: dict(k=4, l=4, eta=2, tau=39, lam4=32, g1=1 << 17, g2=(Q - 1) // 88, beta=78, omega=80, cbits=18, wbits=6),
    65: dict(k=6, l=5, eta=4, tau=49, lam4=48, g1=1 << 19, g2=(Q - 1) // 32, beta=196, omega=55, cbits=20, wbits=4),
    87: dict(k=8, l=7, eta=2, tau=60, lam4=64, g1=1 << 19, g2=(Q - 1) // 32, beta=120, omega=75, cbits=20, wbits=4),
}


def param_table():
    """LEVEL (9, 10, 11 for ML-DSA-44, 65, 87 as dsig_op.alg) -> {field: value}."""
    t = {}
    for alg, lvl in ((9, 44), (10, 65), (11, 87)):
        p = PARAMS[lvl]
        t[alg] = {P_K: p['k'], P_L: p['l'], P_ETA: p['eta'], P_TAU: p['tau'], P_LAM4: p['lam4'], P_G1: p['g1'], P_G2: p['g2'],
                  P_BETA: p['beta'], P_OMEGA: p['omega'], P_CBITS: p['cbits'], P_WBITS: p['wbits'], P_ALPHA: 2 * p['g2'],
                  P_M: (Q - 1) // (2 * p['g2']), P_GB: p['g1'] - p['beta'], P_G2B: p['g2'] - p['beta']}
    return t


class Asm:
    def __init__(self):
        self.code = []
        self.labels = {}
        self.fix = []

    def label(self, name):
        assert name not in self.labels, name
        self.labels[name] = len(self.code)

    def emit(self, op, rd=0, ra=0, rb=0, imm=0, target=None):
        assert 0 <= rd < 32 and 0 <= ra < 32 and 0 <= rb < 32, (op, rd, ra, rb)
        assert op in OPC, op
        if target is not None:
            self.fix.append((len(self.code), target))
        self.code.append([op, rd, ra, rb, imm])

    def resolve(self, base=0):
        for pos, tgt in self.fix:
            self.code[pos][4] = self.labels[tgt] + base
        return self.code


def s32(x):
    x &= M32
    return x - (1 << 32) if x & 0x80000000 else x


class Machine:
    """snap: dict LDS selector -> value; buf: dict area -> bytearray (written areas are updated in place);
    key, pool: bytes; words: size of the word RAM."""

    def __init__(self, params, snap, buf, key=b'', pool=b'', words=32768):
        self.T = params
        self.snap = snap
        self.buf = buf
        self.key, self.pool = key, pool
        self.W = [0] * words
        self.R = [0] * 32
        self.F = [0] * 8
        self.stack = []
        self.ok = False
        self.err = None
        self.steps = 0
        self.nhash = 0
        self.job = None            # (alg, absorbed bytearray, outlen)
        self.stream = b''
        self.spos = 0
        self.xopen = False

    def _byte(self, area, off):
        b = self.buf.get(area, b'')
        return b[off] if 0 <= off < len(b) else 0

    def run(self, code, pc, limit=2_000_000_000):
        R, F, W = self.R, self.F, self.W
        while True:
            self.steps += 1
            assert self.steps < limit
            op, rd, ra, rb, imm = code[pc]
            pc += 1
            if op == 'NOP':
                pass
            elif op == 'LDI':
                R[rd] = imm & M32
            elif op == 'MOV':
                R[rd] = R[ra]
            elif op == 'ADD':
                R[rd] = (R[ra] + R[rb]) & M32
            elif op == 'SUB':
                R[rd] = (R[ra] - R[rb]) & M32
            elif op == 'AND':
                R[rd] = R[ra] & R[rb]
            elif op == 'OR':
                R[rd] = R[ra] | R[rb]
            elif op == 'XOR':
                R[rd] = R[ra] ^ R[rb]
            elif op == 'ADDI':
                R[rd] = (R[ra] + imm) & M32
            elif op == 'SUBI':
                R[rd] = (R[ra] - imm) & M32
            elif op == 'ANDI':
                R[rd] = R[ra] & (imm & M32)
            elif op == 'SHLI':
                R[rd] = (R[ra] << (imm & 31)) & M32
            elif op == 'SHRI':
                R[rd] = R[ra] >> (imm & 31)
            elif op == 'SARI':
                R[rd] = (s32(R[ra]) >> (imm & 31)) & M32
            elif op == 'SHL':
                R[rd] = (R[ra] << (R[rb] & 31)) & M32
            elif op == 'SHR':
                R[rd] = R[ra] >> (R[rb] & 31)
            elif op == 'SAR':
                R[rd] = (s32(R[ra]) >> (R[rb] & 31)) & M32
            elif op == 'MULL':
                R[rd] = (R[ra] * R[rb]) & M32
            elif op == 'MULQ':
                R[rd] = (R[ra] * R[rb]) % Q
            elif op == 'ADDQ':
                R[rd] = (R[ra] + R[rb]) % Q
            elif op == 'SUBQ':
                R[rd] = (R[ra] - R[rb]) % Q
            elif op == 'DIVU':
                R[rd] = (R[ra] // R[rb]) if R[rb] else M32
            elif op == 'MODU':
                R[rd] = (R[ra] % R[rb]) if R[rb] else R[ra]
            elif op == 'LDZ':
                R[rd] = ZETAS[R[ra] & 255]
            elif op == 'LDP':
                R[rd] = self.T[self.snap[S_LEVEL]][imm]
            elif op == 'LDS':
                R[rd] = self.snap.get(imm, 0) & M32     # a selector that the snapshot does not give reads 0 (S_DPA: no masking)
            elif op == 'EQ':
                F[rd & 7] = int(R[ra] == R[rb])
            elif op == 'LTU':
                F[rd & 7] = int(R[ra] < R[rb])
            elif op == 'LTS':
                F[rd & 7] = int(s32(R[ra]) < s32(R[rb]))
            elif op == 'EQI':
                F[rd & 7] = int(R[ra] == (imm & M32))
            elif op == 'ISZ':
                F[rd & 7] = int(R[ra] == 0)
            elif op == 'FNOT':
                F[rd & 7] = 1 - F[ra & 7]
            elif op == 'FAND':
                F[rd & 7] = F[ra & 7] & F[rb & 7]
            elif op == 'FOR':
                F[rd & 7] = F[ra & 7] | F[rb & 7]
            elif op == 'FSET':
                F[rd & 7] = imm & 1
            elif op == 'BRF':
                if F[ra & 7]:
                    pc = imm
            elif op == 'BRN':
                if not F[ra & 7]:
                    pc = imm
            elif op == 'JMP':
                pc = imm
            elif op == 'CALL':
                self.stack.append(pc)
                assert len(self.stack) <= 8
                pc = imm
            elif op == 'RET':
                pc = self.stack.pop()
            elif op == 'END':
                self.ok = bool(F[7])
                return
            elif op == 'ERR':
                self.err = imm
                self.ok = False
                return
            elif op == 'LW':
                R[rd] = W[(R[ra] + imm) & 0xFFFFFF]
            elif op == 'SW':
                W[(R[ra] + imm) & 0xFFFFFF] = R[rb]
            elif op == 'BLB':
                R[rd] = self._byte(R[rb] & 3, (R[ra] + imm) & 0xFFFFFF)
            elif op == 'BSB':
                a, off = imm & 3, (R[ra] + (imm >> 2)) & 0xFFFFFF
                b = self.buf.setdefault(a, bytearray())
                if off >= len(b):
                    b.extend(bytes(off + 1 - len(b)))
                b[off] = R[rb] & 255
            elif op == 'LDK':
                i = (R[ra] + imm) & 0xFFFFFF
                R[rd] = self.key[i] if i < len(self.key) else 0
            elif op == 'LDR':
                i = (R[ra] + imm) & 0xFFFFFF
                R[rd] = self.pool[i] if i < len(self.pool) else 0
            elif op == 'XSTART':
                assert not self.xopen, 'hash job still open'
                self.job = [imm & 15, bytearray(), R[ra] & 0xFFFF]
                self.xopen = True
                self.stream = b''
                self.spos = 0
            elif op == 'XPUT':
                assert self.xopen and self.job is not None
                self.job[1].append(R[ra] & 255)
            elif op == 'XFIN':
                alg, data, outlen = self.job
                self.stream = (hashlib.shake_128 if alg == H_SHAKE128 else hashlib.shake_256)(bytes(data)).digest(max(outlen, 1))
                self.spos = 0
                self.nhash += 1
            elif op == 'XGET':
                assert self.spos < len(self.stream), 'squeeze past the output length'
                R[rd] = self.stream[self.spos]
                self.spos += 1
                if self.spos >= len(self.stream):
                    self.xopen = False       # the job ends with the last byte of its output
            elif op == 'XDRAIN':
                self.spos = len(self.stream)
                self.xopen = False
            else:
                raise AssertionError(op)
