"""Instruction set, assembler and bit-exact model of the hash-tree processor of the hash-based verification engine
(m_vlsit_dsig_hbs) of the digital signature IP.

The processor has 32 registers of 64 bits, 8 flags, a local byte RAM, a hash head buffer (up to 256 bytes), up to two
hash tails (sources in the local RAM or in the external buffer) and a digest of the last hash. A verification algorithm
(SLH-DSA, LMS/HSS, XMSS/XMSS^MT) is a program of this instruction set (programs in hbs_progs_*.py); gen_hbs_rom.py turns
the programs into the ROM of the RTL. Every operation of the model is the operation of the RTL.

Instruction word (64 bits): op[63:58] rd[57:53] ra[52:48] rb[47:43] imm[42:0]; the registers are 64-bit, the byte string
operations take their lengths and addresses from registers.
"""
import hashlib

OPS = ['NOP', 'LDI', 'MOV', 'ADD', 'SUB', 'AND', 'OR', 'XOR', 'MUL', 'ADDI', 'SUBI', 'ANDI', 'SHLI', 'SHRI', 'SHL', 'SHR',
       'LDT', 'LDS',
       'EQ', 'LTU', 'EQI', 'ISZ', 'FNOT', 'FAND', 'FOR', 'FSET',
       'BRF', 'BRN', 'JMP', 'CALL', 'RET', 'END', 'ERR',
       'RLB', 'RSB', 'BLB', 'CPBR', 'CPRR', 'CMPRR', 'XORR',
       'HCLR', 'HREG', 'HRAM', 'HBUF', 'HZERO', 'HZERI', 'HT1', 'HT2', 'HGO', 'DST', 'HMID']
OPC = {n: i for i, n in enumerate(OPS)}
M64 = (1 << 64) - 1

AREA_MSG, AREA_SIG, AREA_PK = 0, 1, 2
TAB_SLH, TAB_LMS, TAB_OTS, TAB_XMSS = 0, 1, 2, 3
# LDS selectors
S_LEN_MSG, S_LEN_CTX, S_FORM, S_SLH, S_LMSTYPE, S_LMOTS, S_HSSLVL, S_XMSS, S_ALG, S_HASH = range(10)
# hash modes (codes of the stream sequencer)
H_SHA256, H_SHA512, H_SHAKE256 = 1, 3, 13


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
        if target is not None:
            self.fix.append((len(self.code), target))
        self.code.append([op, rd, ra, rb, imm])

    def resolve(self, base=0):
        for pos, tgt in self.fix:
            self.code[pos][4] = self.labels[tgt] + base
        return self.code


class Fail(Exception):
    pass


class Machine:
    """tables[(tab, key)] is a dict field -> value; snap is a dict with the LDS fields."""

    def __init__(self, tables, snap, buf, ram_bytes=16384):
        self.T = tables
        self.snap = snap
        self.buf = buf                      # dict area -> bytes
        self.ram = bytearray(ram_bytes)
        self.R = [0] * 32
        self.F = [0] * 8
        self.head = bytearray()
        self.mid = bytearray()               # bytes hashed between the first and the second tail (at most 16)
        self.tails = [None, None]           # (src, area, addr, len)
        self.dig = b''
        self.stack = []
        self.ok = False
        self.err = None
        self.steps = 0
        self.nhash = 0

    def _bufbyte(self, area, off):
        b = self.buf[area]
        return b[off] if 0 <= off < len(b) else 0

    def run(self, code, pc, limit=200_000_000):
        R, F = self.R, self.F
        while True:
            self.steps += 1
            assert self.steps < limit
            op, rd, ra, rb, imm = code[pc]
            pc += 1
            if op == 'NOP':
                pass
            elif op == 'LDI':
                R[rd] = imm
            elif op == 'MOV':
                R[rd] = R[ra]
            elif op == 'ADD':
                R[rd] = (R[ra] + R[rb]) & M64
            elif op == 'SUB':
                R[rd] = (R[ra] - R[rb]) & M64
            elif op == 'AND':
                R[rd] = R[ra] & R[rb]
            elif op == 'OR':
                R[rd] = R[ra] | R[rb]
            elif op == 'XOR':
                R[rd] = R[ra] ^ R[rb]
            elif op == 'MUL':
                R[rd] = ((R[ra] & 0xFFFFFFFF) * (R[rb] & 0xFFFFFFFF)) & M64
            elif op == 'ADDI':
                R[rd] = (R[ra] + imm) & M64
            elif op == 'SUBI':
                R[rd] = (R[ra] - imm) & M64
            elif op == 'ANDI':
                R[rd] = R[ra] & imm
            elif op == 'SHLI':
                R[rd] = (R[ra] << (imm & 63)) & M64
            elif op == 'SHRI':
                R[rd] = R[ra] >> (imm & 63)
            elif op == 'SHL':
                R[rd] = (R[ra] << (R[rb] & 63)) & M64
            elif op == 'SHR':
                R[rd] = R[ra] >> (R[rb] & 63)
            elif op == 'LDT':
                tab, field = imm >> 8, imm & 255
                R[rd] = self.T.get((tab, R[ra]), {}).get(field, 0)
            elif op == 'LDS':
                R[rd] = self.snap[imm]
            elif op == 'EQ':
                F[rd & 7] = int(R[ra] == R[rb])
            elif op == 'LTU':
                F[rd & 7] = int(R[ra] < R[rb])
            elif op == 'EQI':
                F[rd & 7] = int(R[ra] == imm)
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
                assert len(self.stack) <= 4
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
            elif op == 'RLB':
                R[rd] = self.ram[(R[ra] + imm) & 0xFFFFFF]
            elif op == 'RSB':
                self.ram[(R[ra] + imm) & 0xFFFFFF] = R[rb] & 255
            elif op == 'BLB':
                R[rd] = self._bufbyte(imm & 3, (R[ra] + (imm >> 2)) & 0xFFFFFFFF)
            elif op == 'CPBR':
                d, s, n, area = R[rd], R[ra], R[rb], imm & 3
                for k in range(n):
                    self.ram[d + k] = self._bufbyte(area, s + k)
            elif op == 'CPRR':
                d, s, n = R[rd], R[ra], R[rb]
                for k in range(n):
                    self.ram[d + k] = self.ram[s + k]
            elif op == 'CMPRR':
                a, b, n = R[ra], R[rb], R[imm & 31]
                F[rd & 7] = int(self.ram[a:a + n] == self.ram[b:b + n])
            elif op == 'XORR':
                d, x, y, n = R[rd], R[ra], R[rb], R[imm & 31]
                for k in range(n):
                    self.ram[d + k] = self.ram[x + k] ^ self.ram[y + k]
            elif op == 'HCLR':
                self.head = bytearray()
                self.mid = bytearray()
                self.tails = [None, None]
            elif op == 'HREG':
                self.head += (R[ra] & ((1 << (8 * imm)) - 1)).to_bytes(imm, 'big')
            elif op == 'HRAM':
                a, n = R[ra], R[rb]
                self.head += self.ram[a:a + n]
            elif op == 'HBUF':
                s, n, area = R[ra], R[rb], imm & 3
                self.head += bytes(self._bufbyte(area, s + k) for k in range(n))
            elif op == 'HZERO':
                self.head += bytes(R[ra] & 255)
            elif op == 'HZERI':
                self.head += bytes(imm & 255)
            elif op == 'HMID':
                self.mid += (R[ra] & ((1 << (8 * imm)) - 1)).to_bytes(imm, 'big')
                assert len(self.mid) <= 16
            elif op in ('HT1', 'HT2'):
                src, area = imm & 1, (imm >> 1) & 3
                self.tails[0 if op == 'HT1' else 1] = (src, area, R[ra], R[rb])
            elif op == 'HGO':
                mode, outlen = imm & 15, R[ra] & 0xFFFF
                assert len(self.head) <= 256
                data = bytes(self.head)
                for ti, t in enumerate(self.tails):
                    if ti == 1:
                        data += bytes(self.mid)
                    if t and t[3]:
                        src, area, a, n = t
                        if src == 0:
                            data += bytes(self.ram[a:a + n])
                        else:
                            data += bytes(self._bufbyte(area, a + k) for k in range(n))
                if mode == H_SHA256:
                    self.dig = hashlib.sha256(data).digest()
                elif mode == H_SHA512:
                    self.dig = hashlib.sha512(data).digest()
                else:
                    self.dig = hashlib.shake_256(data).digest(outlen)
                self.nhash += 1
                self.tails = [None, None]
                self.mid = bytearray()
            elif op == 'DST':
                a, n = R[ra], R[rb]
                self.ram[a:a + n] = self.dig[:n].ljust(n, b'\0')
            else:
                raise AssertionError(op)
