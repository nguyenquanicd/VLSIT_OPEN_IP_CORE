"""Expected pools of the RTL test of the random block with the Hash_DRBG (verification/tests/key_rng/tb_rng_drbg.sv).

The test runs 6 pool requests with PARA_RESEED_INT = 3; the model decides when to seed (not instantiated, reseed_counter >
reseed_interval, or the reseed command of the CSR given before request 5); the entropy sets are numbered in order of use. The expected pools come from hash_drbg_ref.py (SP 800-90A Rev. 1).
Output: one line per request: <reseeds 0/1> <96 entropy bytes hex or -> <96 pool bytes hex>.
Usage: python gen_drbg_vec.py <out.txt>"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hash_drbg_ref as D

INTERVAL = 3


def entropy(k):
    return bytes((i * 29 + 7 * k + 1) % 256 for i in range(96))


def main(out):
    d = D.HashDrbg()
    k = [0]

    def ent():
        e = entropy(k[0])
        k[0] += 1
        return e
    with open(out, 'w') as fh:
        for req in range(6):
            seed, e, pool = D.ip_request(d, ent, req == 5, INTERVAL)
            fh.write('%d %s %s\n' % (int(seed), e.hex() if seed else '-', pool.hex()))
            print('request %d: %s' % (req, 'seed + generate' if seed else 'generate'))


if __name__ == '__main__':
    main(sys.argv[1])
