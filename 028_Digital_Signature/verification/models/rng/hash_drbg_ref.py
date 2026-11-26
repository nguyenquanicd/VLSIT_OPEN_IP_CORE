"""Hash_DRBG with SHA-512 written from NIST SP 800-90A Rev. 1 (file vlsit_drbg_sp800_90ar1.md): section 10.1.1.2 (instantiate),
10.1.1.3 (reseed), 10.1.1.4 (generate and Hashgen), section 10.3.1 (Hash_df), Table 2 (seedlen 888 for SHA-512).
No personalization string and no additional input are used.

ip_pool() models how the random block of the IP uses the generator (PARA_RNG_SRC = 1): the 96 bytes of the entropy port are
entropy_input || nonce (64 + 32 bytes) at instantiation and entropy_input at a reseed; every request returns 96 bytes."""
import hashlib

SEEDLEN = 888
MOD = 1 << SEEDLEN
NB = SEEDLEN // 8           # 111 bytes


def H(b):
    return hashlib.sha512(b).digest()


def hash_df(inp, nbits=SEEDLEN):
    temp = b''
    n = -(-nbits // 512)
    for counter in range(1, n + 1):
        temp += H(bytes([counter]) + nbits.to_bytes(4, 'big') + inp)
    return temp[:nbits // 8]


class HashDrbg:
    def __init__(self):
        self.V = self.C = None
        self.counter = 0

    def instantiate(self, entropy, nonce, pers=b''):
        seed = hash_df(entropy + nonce + pers)
        self.V = seed
        self.C = hash_df(b'\x00' + self.V)
        self.counter = 1

    def reseed(self, entropy, add=b''):
        seed = hash_df(b'\x01' + self.V + entropy + add)
        self.V = seed
        self.C = hash_df(b'\x00' + self.V)
        self.counter = 1

    def generate(self, nbytes):
        # Hashgen
        m = -(-nbytes // 64)
        data = int.from_bytes(self.V, 'big')
        W = b''
        for _ in range(m):
            W += H(data.to_bytes(NB, 'big'))
            data = (data + 1) % MOD
        out = W[:nbytes]
        Hh = int.from_bytes(H(b'\x03' + self.V), 'big')
        v = (int.from_bytes(self.V, 'big') + Hh + int.from_bytes(self.C, 'big') + self.counter) % MOD
        self.V = v.to_bytes(NB, 'big')
        self.counter += 1
        return out


def ip_request(drbg, entropy_fn, reseed_cmd, interval):
    """One pool request with the decision of the random block: seed when not instantiated, when the reseed command is
    pending or when reseed_counter > reseed_interval (SP 800-90A section 10.1.1.4 step 1). Returns (seeded, entropy, pool)."""
    seed = drbg.V is None or reseed_cmd or drbg.counter > interval
    e = entropy_fn() if seed else b''
    return seed, e, ip_pool(drbg, e, seed)


def ip_pool(drbg, entropy96, reseed):
    """One pool request of the random block: (re)seed with the 96 entropy bytes when asked, then 96 output bytes."""
    if reseed:
        if drbg.V is None:
            drbg.instantiate(entropy96[:64], entropy96[64:])
        else:
            drbg.reseed(entropy96)
    return drbg.generate(96)


if __name__ == '__main__':
    d = HashDrbg()
    e = bytes(range(96))
    p1 = ip_pool(d, e, True)
    p2 = ip_pool(d, b'', False)
    assert p1 != p2 and len(p1) == 96
    print(p1.hex()[:32], p2.hex()[:32])
