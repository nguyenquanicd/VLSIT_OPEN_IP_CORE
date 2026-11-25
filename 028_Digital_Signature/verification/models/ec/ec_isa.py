"""Instruction set, assembler and bit-exact model of the microcoded elliptic-curve engine
(m_vlsit_dsig_ec) of the digital signature IP.

The engine is a small processor: 32 registers of 576 bits, 8 flags, a modular arithmetic unit
(add, subtract, bit-serial multiply, reduce, power) with a selectable modulus, and I/O operations
to the buffer, the key store, the random pool and the hash stream. An algorithm (Ed25519 verify, ECDSA
sign, ...) is a program of this instruction set; the programs are written in ec_progs.py, tested
here against the test vectors of RFC 8032 and RFC 6979, and turned into the ROM of the RTL by
gen_ec_rom.py. Every operation of the model is the operation of the RTL: operands of ADD, SUB and MUL
must be smaller than the modulus (the model asserts it), RED reduces any 576-bit value.

Instruction word (64 bits): op[63:58] rd[57:53] ra[52:48] rb[47:43] imm[42:0].
"""

import hashlib

W = 576
MASK = (1 << W) - 1

OPS = ['NOP', 'ADD', 'SUB', 'MUL', 'RED', 'MOV', 'LDI', 'LDC', 'SETM', 'POW', 'SMUL',
       'EQ', 'LTU', 'BIT', 'ISZ', 'FNOT', 'FAND', 'FOR', 'FSET', 'CMOV',
       'AND', 'OR', 'SHR', 'SHL', 'SETB', 'TRUNCE',
       'CALL', 'RET', 'JMP', 'BRF', 'BRN', 'END', 'ERR',
       'RDB', 'WRB', 'LDK', 'LDR',
       'HDCLR', 'HDREG', 'HDIMM', 'HGO', 'HRD', 'HRDV', 'HMID', 'LDV', 'XORB']
OPC = {n: i for i, n in enumerate(OPS)}

AREA_MSG, AREA_SIG, AREA_PK, AREA_RES = 0, 1, 2, 3
LE, BE = 0, 1
SEL_P, SEL_N, SEL_NM1 = 0, 1, 2

# error codes of ERR (bit numbers of dsig_err flags)
ERR_BADKEY, ERR_BADPT = 3, 4

# hash mode codes of the stream sequencer
H_SHA256, H_SHA384, H_SHA512, H_SHA3_256, H_SHA3_384, H_SHA3_512, H_SHAKE128, H_SHAKE256 = 1, 2, 3, 9, 10, 11, 12, 13
HASH_OF_OP = {0: H_SHA256, 1: H_SHA384, 2: H_SHA512, 3: H_SHA3_256, 4: H_SHA3_384, 5: H_SHA3_512}
HASH_MODE_OP = 15      # HGO mode field: the hash selected by dsig_op.hash


class Asm:
    """Assembler: a list of instructions (op, rd, ra, rb, imm) and labels."""

    def __init__(self):
        self.code = []
        self.labels = {}
        self.fix = []

    def label(self, name):
        assert name not in self.labels, name
        self.labels[name] = len(self.code)

    def emit(self, op, rd=0, ra=0, rb=0, imm=0, target=None):
        if target is not None:
            self.fix.append((len(self.code), target))
        self.code.append([op, rd, ra, rb, imm])

    def resolve(self, base=0):
        for pos, tgt in self.fix:
            if isinstance(tgt, tuple):
                _, dbl, add = tgt
                self.code[pos][4] |= ((self.labels[dbl] + base) << 16) | (self.labels[add] + base)
            else:
                self.code[pos][4] = self.labels[tgt] + base
        return self.code

    # arithmetic
    def add(self, d, a, b): self.emit('ADD', d, a, b)
    def sub(self, d, a, b): self.emit('SUB', d, a, b)
    def mul(self, d, a, b): self.emit('MUL', d, a, b)
    def red(self, d, a): self.emit('RED', d, a)
    def mov(self, d, a): self.emit('MOV', d, a)
    def ldi(self, d, v): self.emit('LDI', d, imm=v)
    def ldc(self, d, name): self.emit('LDC', d, imm=name)
    def setm(self, sel): self.emit('SETM', imm=sel)
    def pow(self, d, a, e): self.emit('POW', d, a, e)
    def smul(self, k, nbits, dbl, add):
        self.fix.append((len(self.code), ('smul', dbl, add)))
        self.emit('SMUL', 0, k, 0, nbits << 33)
    # flags and logic
    def eq(self, f, a, b): self.emit('EQ', f, a, b)
    def ltu(self, f, a, b): self.emit('LTU', f, a, b)
    def bit(self, f, a, i): self.emit('BIT', f, a, imm=i)
    def isz(self, f, a): self.emit('ISZ', f, a)
    def fnot(self, d, a): self.emit('FNOT', d, a)
    def fand(self, d, a, b): self.emit('FAND', d, a, b)
    def forr(self, d, a, b): self.emit('FOR', d, a, b)
    def fset(self, f, v): self.emit('FSET', f, imm=v)
    def cmov(self, d, a, f): self.emit('CMOV', d, a, f)
    def and_(self, d, a, b): self.emit('AND', d, a, b)
    def or_(self, d, a, b): self.emit('OR', d, a, b)
    def shr(self, d, a, n): self.emit('SHR', d, a, imm=n)
    def shl(self, d, a, n): self.emit('SHL', d, a, imm=n)
    def setb(self, d, a, i, f): self.emit('SETB', d, a, f, i)
    def trunce(self, d, a): self.emit('TRUNCE', d, a)
    # control
    def call(self, lab): self.emit('CALL', target=lab)
    def ret(self): self.emit('RET')
    def jmp(self, lab): self.emit('JMP', target=lab)
    def brf(self, f, lab): self.emit('BRF', 0, f, target=lab)
    def brn(self, f, lab): self.emit('BRN', 0, f, target=lab)
    def end(self): self.emit('END')
    def err(self, code): self.emit('ERR', imm=code)
    # I/O
    def rdb(self, d, area, off, ln, en): self.emit('RDB', d, area, en, (off << 12) | ln)
    def wrb(self, s, area, off, ln, en): self.emit('WRB', s, area, en, (off << 12) | ln)
    def ldk(self, d, off, ln, en): self.emit('LDK', d, 0, en, (off << 12) | ln)
    def ldr(self, d, off, ln, en): self.emit('LDR', d, 0, en, (off << 12) | ln)
    def hdclr(self): self.emit('HDCLR')
    def hdreg(self, a, ln, en): self.emit('HDREG', 0, a, en, ln)
    def hdimm(self, ident): self.emit('HDIMM', imm=ident)
    def hgo(self, mode, tail, outlen=0): self.emit('HGO', 0, mode, tail, outlen)
    def hrd(self, d, off, ln, en): self.emit('HRD', d, 0, en, (off << 12) | ln)
    def hrdv(self, d): self.emit('HRDV', d)
    def hmid(self): self.emit('HMID')
    def ldv(self, d, sel): self.emit('LDV', d, imm=sel)
    def xorb(self, d, a, byte): self.emit('XORB', d, a, imm=byte)


class Fail(Exception):
    pass


class Machine:
    def __init__(self, curve, consts, strings, buf, key=b'', pool=b'', off=None, len_msg=0, op_hash=0, curve_kind=None, len_ctx=0, f_ph=0):
        self.c = curve
        self.consts = consts          # name -> int
        self.strings = strings        # id -> bytes
        self.R = [0] * 32
        self.F = [0] * 8
        self.M = 0
        self.mbits = 0
        self.buf = bytearray(buf)
        self.key = key
        self.pool = pool
        self.off = off or {}
        self.len_msg = len_msg
        self.op_hash = op_hash
        self.head = b''
        self.mid = b''
        self.hsel = 0
        self.len_ctx = len_ctx
        self.f_ph = f_ph
        self.digest = b''
        self.dlen = 0
        self.stack = []
        self.err = None
        self.ok = False
        self.steps = 0
        self.mulcount = 0

    def _chk(self, v):
        assert 0 <= v <= MASK, 'register overflow'
        return v

    def _modsel(self, sel):
        c = self.c
        if sel == SEL_P:
            self.M = c.p
        elif sel == SEL_N:
            self.M = c.n
        else:
            self.M = c.n - 1
        self.mbits = self.M.bit_length()

    def _area(self, area):
        return self.off[area]

    def _bytes_to_int(self, b, en):
        return int.from_bytes(b, 'little' if en == LE else 'big')

    def _int_to_bytes(self, v, ln, en):
        return (v & ((1 << (8 * ln)) - 1)).to_bytes(ln, 'little' if en == LE else 'big')

    def run(self, code, pc=0, limit=50_000_000):
        R, F = self.R, self.F
        while True:
            self.steps += 1
            assert self.steps < limit
            op, rd, ra, rb, imm = code[pc]
            pc += 1
            M = self.M
            if op == 'NOP':
                pass
            elif op == 'ADD':
                assert R[ra] < M and R[rb] < M
                R[rd] = (R[ra] + R[rb]) % M
            elif op == 'SUB':
                assert R[ra] < M and R[rb] < M
                R[rd] = (R[ra] - R[rb]) % M
            elif op == 'MUL':
                assert R[ra] < M, 'MUL multiplicand %d >= modulus' % ra
                R[rd] = (R[ra] * (R[rb] & ((1 << self.mbits) - 1))) % M
                assert R[rb] < (1 << self.mbits)
                self.mulcount += 1
            elif op == 'RED':
                R[rd] = R[ra] % M
            elif op == 'MOV':
                R[rd] = R[ra]
            elif op == 'LDI':
                R[rd] = imm
            elif op == 'LDC':
                R[rd] = self._chk(self.consts[imm])
            elif op == 'SETM':
                self._modsel(imm)
            elif op == 'POW':
                base = R[ra]
                assert base < M
                e = R[rb]
                acc = 1 % M
                for i in range(e.bit_length() - 1, -1, -1):
                    acc = acc * acc % M
                    if (e >> i) & 1:
                        acc = acc * base % M
                R[rd] = acc
            elif op == 'SMUL':
                nbits = imm >> 33
                dbl, add = (imm >> 16) & 0xFFFF, imm & 0xFFFF
                k = R[ra]
                # accumulator = identity
                for i in range(4):
                    R[i] = self.consts['IDENT%d' % i]
                for i in range(nbits - 1, -1, -1):
                    self.run(code, dbl)
                    if (k >> i) & 1:
                        self.run(code, add)
            elif op == 'EQ':
                F[rd] = int(R[ra] == R[rb])
            elif op == 'LTU':
                F[rd] = int(R[ra] < R[rb])
            elif op == 'BIT':
                F[rd] = (R[ra] >> imm) & 1
            elif op == 'ISZ':
                F[rd] = int(R[ra] == 0)
            elif op == 'FNOT':
                F[rd] = 1 - F[ra]
            elif op == 'FAND':
                F[rd] = F[ra] & F[rb]
            elif op == 'FOR':
                F[rd] = F[ra] | F[rb]
            elif op == 'FSET':
                F[rd] = imm
            elif op == 'CMOV':
                if F[rb]:
                    R[rd] = R[ra]
            elif op == 'AND':
                R[rd] = R[ra] & R[rb]
            elif op == 'OR':
                R[rd] = R[ra] | R[rb]
            elif op == 'SHR':
                R[rd] = R[ra] >> imm
            elif op == 'SHL':
                R[rd] = (R[ra] << imm) & MASK
            elif op == 'SETB':
                R[rd] = R[ra] | (F[rb] << imm)
            elif op == 'TRUNCE':
                sh = max(0, 8 * self.dlen - self.c.nbits)
                R[rd] = R[ra] >> sh
            elif op == 'CALL':
                self.stack.append(pc)
                pc = imm
            elif op == 'RET':
                if not self.stack:
                    return
                pc = self.stack.pop()
            elif op == 'JMP':
                pc = imm
            elif op == 'BRF':
                if F[ra]:
                    pc = imm & 0xFFFF
            elif op == 'BRN':
                if not F[ra]:
                    pc = imm & 0xFFFF
            elif op == 'END':
                self.ok = bool(F[7])
                return 'END'
            elif op == 'ERR':
                self.err = imm
                self.ok = False
                return 'END'
            elif op == 'RDB':
                off, ln = imm >> 12, imm & 0xFFF
                a = self._area(ra) + off
                R[rd] = self._bytes_to_int(bytes(self.buf[a:a + ln]), rb)
            elif op == 'WRB':
                off, ln = imm >> 12, imm & 0xFFF
                a = self._area(ra) + off
                self.buf[a:a + ln] = self._int_to_bytes(R[rd], ln, rb)
            elif op == 'LDK':
                off, ln = imm >> 12, imm & 0xFFF
                R[rd] = self._bytes_to_int(self.key[off:off + ln], rb)
            elif op == 'LDR':
                off, ln = imm >> 12, imm & 0xFFF
                R[rd] = self._bytes_to_int(self.pool[off:off + ln], rb)
            elif op == 'HDCLR':
                self.head = b''
                self.mid = b''
                self.hsel = 0
            elif op == 'HDREG':
                if self.hsel:
                    self.mid += self._int_to_bytes(R[ra], imm, rb)
                else:
                    self.head += self._int_to_bytes(R[ra], imm, rb)
            elif op == 'HDIMM':
                if self.hsel:
                    self.mid += self.strings[imm]
                else:
                    self.head += self.strings[imm]
            elif op == 'HGO':
                mode = HASH_OF_OP[self.op_hash] if ra == HASH_MODE_OP else ra
                s = self._area(AREA_MSG)
                if rb == 2:
                    data = self.head + bytes(self.buf[s + self.len_msg:s + self.len_msg + self.len_ctx]) + self.mid + bytes(self.buf[s:s + self.len_msg])
                elif rb == 1:
                    data = self.head + bytes(self.buf[s:s + self.len_msg])
                elif rb == 3:
                    data = self.head + self.mid
                else:
                    data = self.head
                name = {1: 'sha256', 2: 'sha384', 3: 'sha512', 9: 'sha3_256', 10: 'sha3_384', 11: 'sha3_512'}.get(mode)
                if name:
                    self.digest = getattr(hashlib, name)(data).digest()
                else:
                    self.digest = hashlib.shake_256(data).digest(imm) if mode == 13 else hashlib.shake_128(data).digest(imm)
                self.dlen = len(self.digest)
            elif op == 'HRD':
                off, ln = imm >> 12, imm & 0xFFF
                R[rd] = self._bytes_to_int(self.digest[off:off + ln], rb)
            elif op == 'HMID':
                self.hsel = 1
            elif op == 'XORB':
                R[rd] = R[ra] ^ int.from_bytes(bytes([imm & 0xFF]) * 72, 'big')
            elif op == 'LDV':
                R[rd] = (self.f_ph, self.len_ctx)[imm]
            elif op == 'HRDV':
                R[rd] = int.from_bytes(self.digest, 'big')
            else:
                raise AssertionError(op)
