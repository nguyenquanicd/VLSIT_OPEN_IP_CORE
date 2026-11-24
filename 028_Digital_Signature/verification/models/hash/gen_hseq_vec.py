"""Reference vectors of the hash stream sequencer, made with hashlib (independent of the RTL).
Line format: mode msglen outlen digest_hex. The message of vector n is pattern(n, i) = (i * 7 + n * 13 + 5) mod 256.
Writes the file given as the first argument."""
import hashlib
import sys

MODES = {1: ('sha256', 32), 2: ('sha384', 48), 3: ('sha512', 64), 9: ('sha3_256', 32), 10: ('sha3_384', 48),
         11: ('sha3_512', 64), 12: ('shake_128', None), 13: ('shake_256', None)}
LENS = [0, 1, 7, 8, 9, 55, 56, 63, 64, 65, 71, 72, 73, 103, 104, 111, 112, 127, 128, 129, 135, 136, 137, 167, 168, 169, 200, 257, 1000]
XOUT = {12: [1, 7, 32, 168, 169, 400], 13: [1, 32, 136, 137, 300]}


def pattern(n, i):
    return (i * 7 + n * 13 + 5) % 256


def main(path):
    lines = []
    n = 0
    for mode, (name, dl) in MODES.items():
        for ln in LENS:
            outs = [dl] if dl else XOUT[mode]
            for ol in outs:
                msg = bytes(pattern(n, i) for i in range(ln))
                h = getattr(hashlib, name)(msg)
                dig = h.digest() if dl else h.digest(ol)
                lines.append('%d %d %d %d %s' % (n, mode, ln, ol, dig.hex()))
                n += 1
    open(path, 'w').write('\n'.join(lines) + '\n')
    print(len(lines), 'vectors')


if __name__ == '__main__':
    main(sys.argv[1])
