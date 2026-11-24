#!/usr/bin/env python3
"""Formula model of the core cycles of one ChaCha20-Poly1305 message (027_ChaCha, HDS section 13).

Purpose : back the architectural numbers of HDS section 13 with a script. This is a formula, not a
          cycle-accurate model of RTL, and it contains no measured value. Every constant below is a
          stated assumption of the specification (ASM-014), not a result. Since 2026-11-24 the formula
          is the refined one (TBD-026 decision): it adds the Poly1305 time of the last chunk and a tail
          of 6 cycles; it applies to messages of at least one byte.
Usage   : python chacha_cycle_model.py            print the tables used in section 13
          import chacha_cycle_model as m; m.start_to_done("CFG-BASE", aad, msg)
Model   : T = KEY_HS + max(chacha_path, poly_path) + SEQ_TAIL, in core clock cycles, from the start
          being accepted until the done event, with the input data already in the input buffer and
          room in the output buffer.
          chacha_path = ceil((1 + B) / N) * C + P * (nL + 1)
                        B = ceil(msg / 64) data blocks, one block of counter 0 for the one-time key,
                        N cores, C cycles per block per core; nL = 16-byte blocks of the last chunk,
                        which can start only when its keystream block exists, then the length block
          poly_path   = C + P * (nA + nM + 1)        the one-time key must exist before Poly1305 starts;
                        nA, nM = 16-byte blocks of AAD and message, one block for the lengths,
                        P = cycles per 16-byte Poly1305 block
          C = ceil(20 / R) * (4 / Q) with R rounds per cycle and Q quarter-round units.
Pipeline options (DEC-036, start_to_done arguments pc and pp; PARA_PIPE_IO changes no cycle count):
          pc = 1 (PARA_PIPE_CHACHA): a core makes blocks in pairs, a pair takes 2 * C + 1 cycles and
               the key block comes with the first pair, so the ChaCha20 term is
               ceil(ceil((1 + B) / N) / 2) * (2 * C + 1) and the Poly1305 term starts at 2 * C + 1.
          pp = 1 (PARA_PIPE_POLY): P becomes P + 1.
"""
import math

KEY_HS = 2      # core cycles of the key-store handshake (request, valid): assumption of the model key store
SEQ_TAIL = 6    # core cycles of the LEN, TAG and DONE steps and the registered crossings: assumption

# name: (Q quarter-round units, R rounds per cycle, N cores, Poly1305 architecture)
CONFIGS = {
    "CFG-LP": (1, 1, 1, 0),
    "CFG-BASE": (4, 1, 1, 1),
    "CFG-HP": (4, 2, 2, 2),
}

# Poly1305 cycles per 16-byte block.
#   architecture 0: a 32-bit multiply-accumulate; the 130-bit accumulator has 5 limbs of 32 bits and r has
#                   4 limbs of 32 bits, so 5 * 4 = 20 limb products, plus 2 cycles for the reduction and
#                   the addition of the block (derived, the only value here that follows from a structure).
#   architecture 1 and 2: requirements on the micro-architecture, not results: the block interval needed so
#                   that Poly1305 does not limit the configuration (HDS REQ-PERF-002).
POLY_CYCLES = {0: 22, 1: 5, 2: 1}


def chacha_cycles_per_block(q, r):
    return math.ceil(20 / r) * (4 // q)


def required_poly_interval(cfg):
    """Largest Poly1305 block interval that does not limit the ChaCha20 rate of the configuration."""
    q, r, n, _ = CONFIGS[cfg]
    c = chacha_cycles_per_block(q, r)
    return math.floor(c / (4 * n))


def start_to_done(cfg, aad, msg, pc=0, pp=0):
    q, r, n, arch = CONFIGS[cfg]
    c = chacha_cycles_per_block(q, r)
    p = POLY_CYCLES[arch] + pp
    b = math.ceil(msg / 64)
    n_a = math.ceil(aad / 16)
    n_m = math.ceil(msg / 16)
    last_chunk = msg - 64 * (b - 1) if msg > 0 else 0
    n_l = math.ceil(last_chunk / 16)
    per_core = math.ceil((1 + b) / n)
    if pc:
        chacha_blocks = math.ceil(per_core / 2) * (2 * c + 1)
        first_block = 2 * c + 1
    else:
        chacha_blocks = per_core * c
        first_block = c
    chacha_path = chacha_blocks + p * (n_l + 1)
    poly_path = first_block + p * (n_a + n_m + 1)
    return KEY_HS + max(chacha_path, poly_path) + SEQ_TAIL


def sustained_gbit_per_ghz(cfg):
    """Sustained bound for a long message: the slower of ChaCha20 and Poly1305, per GHz of core clock."""
    q, r, n, arch = CONFIGS[cfg]
    c = chacha_cycles_per_block(q, r)
    p = POLY_CYCLES[arch]
    cycles_per_64b = max(c / n, 4 * p)
    return 8 * 64 / cycles_per_64b


def main():
    print("cycles per 64-byte block per core, required Poly1305 block interval, Poly1305 cycles used, sustained bound")
    for cfg, (q, r, n, arch) in CONFIGS.items():
        c = chacha_cycles_per_block(q, r)
        print("%-9s C=%3d  N=%d  P_required<=%d  P_used=%2d  ChaCha20 bound %.1f  sustained %.2f Gbit/s per GHz"
              % (cfg, c, n, required_poly_interval(cfg), POLY_CYCLES[arch], 8 * 64 * n / c, sustained_gbit_per_ghz(cfg)))
    print()
    print("start-to-done core cycles (AAD, message): (0,16) (0,64) (12,127) (0,1280)")
    for cfg in CONFIGS:
        row = [start_to_done(cfg, a, m) for a, m in ((0, 16), (0, 64), (12, 127), (0, 1280))]
        print("%-9s %s" % (cfg, row))
    print()
    print("at 80 MHz (12.5 ns per cycle), microseconds:")
    for cfg in CONFIGS:
        row = [round(start_to_done(cfg, a, m) * 0.0125, 2) for a, m in ((0, 16), (0, 64), (12, 127), (0, 1280))]
        print("%-9s %s" % (cfg, row))


if __name__ == "__main__":
    main()
