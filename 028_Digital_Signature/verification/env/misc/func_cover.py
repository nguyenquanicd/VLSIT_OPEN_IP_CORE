"""Functional coverage of the operation space of the specification, measured on the vectors of the engine tests that passed
(the vectors are the stimulus; each set is listed in COVERAGE_MATRIX.md with its pass line). A bin is hit when at least one
vector of a passing set has that combination. The bins are the combinations that the specification allows and tests:

  B1  algorithm x operation x outcome        (key generation; sign; verify valid; verify invalid), only the legal ones
  B2  ECDSA curve x hash x {sign, verify}    (the legal pairs of DEC-032: digest at least as long as the curve needs)
  B3  ECDSA sign with a given nonce and with the deterministic nonce (RFC 6979), per curve
  B4  ML-DSA set x form {pure, pre-hash} x {deterministic, hedged} x {sign, verify}
  B5  SLH-DSA parameter set x form x {valid, invalid}
  B6  EC sign + verify-after-sign: accepted and corrupted (verify-after-sign must reject), per curve
Writes docs/FUNC_COVERAGE.md and prints the bins that no vector hits. Usage: python func_cover.py"""
import os
import sys
from collections import defaultdict

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).replace(chr(92), '/')
S = V + '/sim'
EC_ALG = {0: 'Ed25519', 1: 'Ed25519ctx', 2: 'Ed25519ph', 3: 'Ed448', 4: 'Ed448ph', 5: 'P-256', 6: 'P-384', 7: 'P-521', 8: 'secp256k1'}
HASH = {0: 'SHA-256', 1: 'SHA-384', 2: 'SHA-512', 3: 'SHA3-256', 4: 'SHA3-384', 5: 'SHA3-512'}
# digest length in bits of the hash codes and the minimum the curve needs (DEC-032)
HBITS = {0: 256, 1: 384, 2: 512, 3: 256, 4: 384, 5: 512}
CURVE_MIN = {'P-256': 256, 'secp256k1': 256, 'P-384': 384, 'P-521': 512}
ECSETS = ['ed25519', 'ed448', 'edvar', 'det', 'p256', 'p384', 'p521', 'k256', 'sha3', 'p384full', 'p521full']
hits = defaultdict(int)
legal = set()


def bin_(group, key, legal_=True):
    k = (group, key)
    if legal_:
        legal.add(k)
    return k


def outcome(op, ok):
    return {0: 'keygen', 1: 'sign'}.get(op) or ('verify valid' if ok else 'verify invalid')


def main():
    # legal bins
    for a in EC_ALG.values():
        for o in ('keygen', 'sign', 'verify valid', 'verify invalid'):
            bin_('B1', (a, o))
    for a in ('ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87'):
        for o in ('keygen', 'sign', 'verify valid', 'verify invalid'):
            bin_('B1', (a, o))
    for a in ('SLH-DSA', 'LMS/HSS', 'XMSS/XMSS^MT'):
        for o in ('verify valid', 'verify invalid'):
            bin_('B1', (a, o))
    for c, m in CURVE_MIN.items():
        for h, b in HBITS.items():
            if b >= m:
                for o in ('sign', 'verify'):
                    bin_('B2', (c, HASH[h], o))
        for n in ('given nonce', 'deterministic nonce (RFC 6979)'):
            bin_('B3', (c, n))
        for o in ('accepted', 'corrupted, rejected'):
            bin_('B6', (c, o))
    for s in ('ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87'):
        for f in ('pure', 'pre-hash'):
            for hd in ('deterministic', 'hedged'):
                bin_('B4', (s, f, hd, 'sign'))
            bin_('B4', (s, f, '-', 'verify'))
    for k in range(12):
        for f in ('pure', 'pre-hash'):
            for o in ('valid', 'invalid'):
                bin_('B5', ('set %d' % k, f, o))
    # elliptic-curve vectors: blocks of 1024 bytes
    for st in ECSETS:
        p = '%s/ec_final/%s.hex' % (S, st)
        if not os.path.exists(p):
            continue
        b = [int(x, 16) for x in open(p).read().split()]
        for i in range(0, len(b), 1024):
            blk = b[i:i + 1024]
            alg, op, hs, ok, exp_err, det = EC_ALG[blk[0]], blk[1], blk[2], blk[10], blk[8] | (blk[9] << 8), blk[12]
            if exp_err:
                continue                       # error vectors are counted by the control block tests, not here
            if op in (0, 1, 2):
                hits[('B1', (alg, outcome(op, ok)))] += 1
            elif op == 3:
                hits[('B1', (alg, 'sign'))] += 1
            if alg in CURVE_MIN and op in (1, 2, 3):
                hits[('B2', (alg, HASH[hs], 'sign' if op != 2 else 'verify'))] += 1
                if op in (1, 3):
                    hits[('B3', (alg, 'deterministic nonce (RFC 6979)' if det else 'given nonce'))] += 1
            if alg in CURVE_MIN and op in (3, 4):
                hits[('B6', (alg, 'accepted' if op == 3 else 'corrupted, rejected'))] += 1
    # lattice vectors
    ML = {9: 'ML-DSA-44', 10: 'ML-DSA-65', 11: 'ML-DSA-87'}
    for d in ('lat_all', 'lat_prehash'):
        p = '%s/%s/lat_vecs.txt' % (S, d)
        if not os.path.exists(p):
            continue
        for line in open(p):
            f = line.split()
            alg, op, mode, ok = ML[int(f[1])], int(f[2]), int(f[3]), int(f[10])
            hits[('B1', (alg, outcome(op, ok)))] += 1
            form = 'pre-hash' if (mode >> 1) & 3 == 1 else 'pure'
            if op == 1:
                hits[('B4', (alg, form, 'hedged' if mode & 1 else 'deterministic', 'sign'))] += 1
            if op == 2 and ok:
                hits[('B4', (alg, form, '-', 'verify'))] += 1
    # hash-based vectors
    for d in ('hbs_slh', 'hbs_prehash', 'hbs_lms', 'hbs_xmss', 'hbs_rfc8554'):
        p = '%s/%s/hbs_vecs.txt' % (S, d)
        if not os.path.exists(p):
            continue
        for line in open(p):
            f = line.split()
            alg, mode, ok = int(f[1]), int(f[2]), int(f[12])
            name = {12: 'SLH-DSA', 13: 'LMS/HSS', 14: 'XMSS/XMSS^MT'}[alg]
            hits[('B1', (name, 'verify valid' if ok else 'verify invalid'))] += 1
            if alg == 12:
                form = 'pre-hash' if (mode >> 4) & 3 == 1 else 'pure'
                hits[('B5', ('set %d' % (mode & 15), form, 'valid' if ok else 'invalid'))] += 1
    groups = {'B1': 'algorithm x operation x outcome', 'B2': 'ECDSA curve x hash x operation (DEC-032 legal pairs)',
              'B3': 'ECDSA nonce mode per curve', 'B4': 'ML-DSA set x form x mode', 'B5': 'SLH-DSA set x form x outcome',
              'B6': 'EC sign with verify-after-sign, accepted and corrupted'}
    lines = ['# Functional coverage of the operation space', '',
             'Generated by `verification/env/misc/func_cover.py` from the vectors of the engine tests (the sets of '
             '`COVERAGE_MATRIX.md`, each with its pass line). A bin is hit when a vector of a passing set has that combination. Phase 1 '
             'and the top tests cover the error and control combinations (their own random and directed tests) and are not in these bins.',
             '', '| Group | Bins | Hit | Not hit |', '|---|---|---|---|']
    holes = []
    for g in sorted(groups):
        lb = sorted(k for k in legal if k[0] == g)
        miss = [k for k in lb if hits[k] == 0]
        lines.append('| %s %s | %d | %d | %d |' % (g, groups[g], len(lb), len(lb) - len(miss), len(miss)))
        holes += miss
    if holes:
        lines += ['', '## Bins that no vector hits', ''] + ['- %s: %s' % (g, ' / '.join(k)) for g, k in holes]
    open(V + '/docs/FUNC_COVERAGE.md', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print('\n'.join(lines))
    print('func_cover: %d bins, %d not hit' % (len(legal), len(holes)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
