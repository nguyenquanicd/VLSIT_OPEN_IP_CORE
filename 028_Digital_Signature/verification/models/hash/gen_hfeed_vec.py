"""Vectors of the hash job feeder: digest of head || tail made with hashlib.
Line: n mode outlen hlen taddr tlen taddr2 tlen2 midlen digest_hex (mid, then tail2, follow tail 1: head || tail1 || mid || tail2). Head byte i of vector n is (i*5+n) mod 256; the tail source is the memory
mem[i] = (i*11+3) mod 256 (4096 bytes). Writes the file named by the first argument."""
import hashlib, random, sys
MODES = {1: ('sha256', 32), 2: ('sha384', 48), 3: ('sha512', 64), 9: ('sha3_256', 32), 11: ('sha3_512', 64), 12: ('shake_128', None), 13: ('shake_256', None)}
def mem(n): return bytes((i * 11 + 3) % 256 for i in range(n))
def main(path):
    rnd = random.Random(5)
    M = mem(4096)
    lines = []
    for n in range(500):
        mode = rnd.choice(list(MODES))
        name, dl = MODES[mode]
        hl = rnd.choice([0, 1, 7, 8, 9, 31, 32, 33, 64, 100, 127])
        ta = rnd.choice([0, 1, 3, 7, 8, 13, 100, 1001])
        tl = rnd.choice([0, 1, 5, 8, 9, 16, 31, 64, 129, 300, 1000])
        ta2 = rnd.choice([0, 2, 5, 8, 17, 200, 2001])
        tl2 = rnd.choice([0, 0, 1, 3, 8, 9, 40, 130, 500])
        ml = rnd.choice([0, 0, 1, 7, 8, 9, 33, 100])
        ol = dl if dl else rnd.choice([1, 32, 64, 100])
        head = bytes((i * 5 + n) % 256 for i in range(hl))
        mid = bytes((i * 3 + n + 1) % 256 for i in range(ml))
        msg = head + M[ta:ta + tl] + mid + M[ta2:ta2 + tl2]
        h = getattr(hashlib, name)(msg)
        dig = h.digest() if dl else h.digest(ol)
        lines.append('%d %d %d %d %d %d %d %d %d %s' % (n, mode, ol, hl, ta, tl, ta2, tl2, ml, dig.hex()))
    open(path, 'w').write('\n'.join(lines) + '\n')
    print(len(lines), 'vectors')
main(sys.argv[1])
