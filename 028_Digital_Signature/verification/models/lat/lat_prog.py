"""ML-DSA key generation, signing and verification (FIPS 204, pure form) as programs of the lattice processor.
Conventions: R0..R9 and R19 are the temporaries and the arguments of the subroutines, R10..R18 hold the loop variables of the
programs (the subroutines keep them), R20..R31 hold the parameters of the selected set (globals, never written after the start).
Flags F2..F5 are scratch (never live across a call), F6 = emit the public key to the buffer, F7 = result.
Word RAM map: polynomial p at word address 256 p; scratch bytes (one per word) from SCR."""
from ltp_isa import *

# parameters (globals)
gK, gL, gETA, gTAU, gG1, gG2, gBETA, gOMEGA, gLAM4, gCBITS, gWBITS, gALPHA = range(20, 32)

# polynomial indexes
PS1H, PS2H, PT0H, PY, PYH, PW, PTMP, PCH, PCT, PA, PT1, PH = 0, 7, 15, 23, 30, 37, 45, 46, 47, 48, 104, 112
NPOLY = 120
SCR = 256 * NPOLY
SCR_RHO, SCR_RHO2, SCR_K, SCR_TR, SCR_MU, SCR_RHOPP, SCR_CT, SCR_CT2 = (SCR + o for o in (0, 32, 96, 128, 192, 256, 320, 384))
SCR_MSEED = SCR + 512                 # seed of the masks of PARA_EN_DPA_PQ (32 random bytes of the pool)
PM, PT2 = 124, 125                    # mask polynomial and product temporary of PARA_EN_DPA_PQ (words SCR + 1024 to SCR + 1535)
F_EMIT = 6
INV256 = 8347681


class Prog:
    """Assembler helper with the macros used by the programs."""

    def __init__(self, a):
        self.a = a

    def E(self, *args, **kw):
        self.a.emit(*args, **kw)

    def L(self, name):
        self.a.label(name)

    def ldi(self, r, v): self.E('LDI', r, 0, 0, v)
    def mov(self, d, s): self.E('MOV', d, s)
    def add(self, d, a, b): self.E('ADD', d, a, b)
    def sub(self, d, a, b): self.E('SUB', d, a, b)
    def addi(self, d, a, v): self.E('ADDI', d, a, 0, v)
    def subi(self, d, a, v): self.E('SUBI', d, a, 0, v)
    def andi(self, d, a, v): self.E('ANDI', d, a, 0, v)
    def shli(self, d, a, v): self.E('SHLI', d, a, 0, v)
    def shri(self, d, a, v): self.E('SHRI', d, a, 0, v)
    def lw(self, d, addr, imm=0): self.E('LW', d, addr, 0, imm)
    def sw(self, addr, val, imm=0): self.E('SW', 0, addr, val, imm)
    def call(self, lab): self.E('CALL', target=lab)
    def jmp(self, lab): self.E('JMP', target=lab)
    def brf(self, f, lab): self.E('BRF', 0, f, 0, target=lab)
    def brn(self, f, lab): self.E('BRN', 0, f, 0, target=lab)
    def ltu(self, f, a, b): self.E('LTU', f, a, b)
    def eqi(self, f, a, v): self.E('EQI', f, a, 0, v)
    def ret(self): self.E('RET')

    def loop_lt(self, counter, limit_reg, label):
        """counter += 1, then branch to label while counter < limit_reg (flag F2)."""
        self.addi(counter, counter, 1)
        self.ltu(2, counter, limit_reg)
        self.brf(2, label)


def emit_subs(p):
    """Subroutines. R0 is the first argument (base word address of a polynomial unless noted)."""
    E, L = p.E, p.L

    L('L_PZERO')
    p.ldi(1, 0)
    p.ldi(2, 256)
    p.ldi(3, 0)
    L('L_PZERO_L')
    p.add(4, 0, 1)
    p.sw(4, 3)
    p.loop_lt(1, 2, 'L_PZERO_L')
    p.ret()

    L('L_PCOPY')                       # R0 destination, R1 source
    p.ldi(2, 0)
    p.ldi(3, 256)
    L('L_PCOPY_L')
    p.add(4, 1, 2)
    p.lw(5, 4)
    p.add(4, 0, 2)
    p.sw(4, 5)
    p.loop_lt(2, 3, 'L_PCOPY_L')
    p.ret()

    for name, kind in (('L_PADD', 'ADDQ'), ('L_PSUB', 'SUBQ'), ('L_PMUL', 'MULQ')):
        L(name)                        # R0 destination, R1 a, R2 b
        p.ldi(3, 0)
        p.ldi(4, 256)
        L(name + '_L')
        p.add(5, 1, 3)
        p.lw(6, 5)
        p.add(5, 2, 3)
        p.lw(7, 5)
        E(kind, 6, 6, 7)
        p.add(5, 0, 3)
        p.sw(5, 6)
        p.loop_lt(3, 4, name + '_L')
        p.ret()

    L('L_PMAC')                        # R0 += R1 * R2
    p.ldi(3, 0)
    p.ldi(4, 256)
    L('L_PMAC_L')
    p.add(5, 1, 3)
    p.lw(6, 5)
    p.add(5, 2, 3)
    p.lw(7, 5)
    E('MULQ', 6, 6, 7)
    p.add(5, 0, 3)
    p.lw(7, 5)
    E('ADDQ', 6, 6, 7)
    p.sw(5, 6)
    p.loop_lt(3, 4, 'L_PMAC_L')
    p.ret()

    # NTT in place (FIPS 204 algorithm 41): R1 m, R2 len, R3 start, R4 zeta, R5 j, R6 end, R7 address, R8 a, R9 b, R19 temp
    L('L_NTT')
    p.ldi(1, 0)
    p.ldi(2, 128)
    L('L_NTT_LEN')
    p.ldi(3, 0)
    L('L_NTT_START')
    p.addi(1, 1, 1)
    E('LDZ', 4, 1)
    p.mov(5, 3)
    p.add(6, 3, 2)
    L('L_NTT_J')
    p.add(7, 0, 5)
    p.lw(8, 7)
    p.add(7, 7, 2)
    p.lw(9, 7)
    E('MULQ', 9, 9, 4)
    E('SUBQ', 19, 8, 9)
    p.sw(7, 19)
    E('ADDQ', 8, 8, 9)
    p.sub(7, 7, 2)
    p.sw(7, 8)
    p.addi(5, 5, 1)
    p.ltu(2, 5, 6)
    p.brf(2, 'L_NTT_J')
    p.shli(7, 2, 1)
    p.add(3, 3, 7)
    p.ldi(7, 256)
    p.ltu(2, 3, 7)
    p.brf(2, 'L_NTT_START')
    p.shri(2, 2, 1)
    E('ISZ', 2, 2)
    p.brn(2, 'L_NTT_LEN')
    p.ret()

    # INTT in place (algorithm 42) and the scaling by 1/256
    L('L_INTT')
    p.ldi(1, 256)
    p.ldi(2, 1)
    L('L_INTT_LEN')
    p.ldi(3, 0)
    L('L_INTT_START')
    p.subi(1, 1, 1)
    E('LDZ', 4, 1)
    p.ldi(7, 0)
    E('SUBQ', 4, 7, 4)
    p.mov(5, 3)
    p.add(6, 3, 2)
    L('L_INTT_J')
    p.add(7, 0, 5)
    p.lw(8, 7)
    p.add(7, 7, 2)
    p.lw(9, 7)
    E('SUBQ', 19, 8, 9)
    E('MULQ', 19, 19, 4)
    p.sw(7, 19)
    E('ADDQ', 8, 8, 9)
    p.sub(7, 7, 2)
    p.sw(7, 8)
    p.addi(5, 5, 1)
    p.ltu(2, 5, 6)
    p.brf(2, 'L_INTT_J')
    p.shli(7, 2, 1)
    p.add(3, 3, 7)
    p.ldi(7, 256)
    p.ltu(2, 3, 7)
    p.brf(2, 'L_INTT_START')
    p.shli(2, 2, 1)
    p.ltu(2, 2, 7)
    p.brf(2, 'L_INTT_LEN')
    p.ldi(4, INV256)
    p.ldi(5, 0)
    L('L_INTT_S')
    p.add(7, 0, 5)
    p.lw(8, 7)
    E('MULQ', 8, 8, 4)
    p.sw(7, 8)
    p.addi(5, 5, 1)
    p.ldi(6, 256)
    p.ltu(2, 5, 6)
    p.brf(2, 'L_INTT_S')
    p.ret()

    # DECOMP: R8 = r (0 <= r < q) -> R1 = r1, R2 = r0 (signed); R3..R7 temporaries
    L('L_DECOMP')
    E('DIVU', 3, 8, gALPHA)
    E('MULL', 4, 3, gALPHA)
    p.sub(5, 8, 4)                     # r mod alpha
    p.ltu(2, gG2, 5)
    p.brf(2, 'L_DECOMP_BIG')
    p.mov(2, 5)
    p.mov(1, 3)
    p.jmp('L_DECOMP_CHK')
    L('L_DECOMP_BIG')
    p.sub(2, 5, gALPHA)
    p.addi(1, 3, 1)
    L('L_DECOMP_CHK')
    p.sub(6, 8, 2)
    p.ldi(7, Q - 1)
    E('EQ', 2, 6, 7)
    p.brn(2, 'L_DECOMP_E')
    p.ldi(1, 0)
    p.subi(2, 2, 1)
    L('L_DECOMP_E')
    p.ret()

    # NORM: R0 = polynomial, R1 = bound -> F5 = 1 when a coefficient has |centered value| >= bound
    L('L_NORM')
    E('FSET', 5, 0, 0, 0)
    p.ldi(2, 0)
    p.ldi(3, (Q - 1) // 2)
    L('L_NORM_L')
    p.add(4, 0, 2)
    p.lw(5, 4)
    p.ltu(4, 3, 5)
    p.brn(4, 'L_NORM_P')
    p.ldi(6, Q)
    p.sub(5, 6, 5)
    L('L_NORM_P')
    p.ltu(4, 5, 1)
    p.brf(4, 'L_NORM_K')
    E('FSET', 5, 0, 0, 1)
    p.ret()
    L('L_NORM_K')
    p.addi(2, 2, 1)
    p.ldi(6, 256)
    p.ltu(4, 2, 6)
    p.brf(4, 'L_NORM_L')
    p.ret()
