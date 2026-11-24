#!/usr/bin/env python3
"""Reference model of AEAD_CHACHA20_POLY1305 (RFC 8439), written from the RFC text only.

Purpose : independent expected-value source for the ChaCha20-Poly1305 IP (027_ChaCha).
          It models the algorithm, not the RTL, so it is not a cycle model.
Usage   : python chacha20poly1305_ref.py            run the RFC 8439 vectors (selftest)
          import chacha20poly1305_ref as m; m.aead_encrypt(key, nonce, aad, pt) -> (ct, tag)
Source  : RFC 8439 sections 2.1 to 2.8 (reference/md_doc/vlsit_chacha_rfc8439.md of the
          specification skill); vectors of sections 2.3.2, 2.5.2, 2.6.2 and 2.8.2.
"""
import struct
import sys

MASK = 0xFFFFFFFF


def rotl(x, n):
    return ((x << n) & MASK) | (x >> (32 - n))


def quarter_round(s, a, b, c, d):
    s[a] = (s[a] + s[b]) & MASK; s[d] ^= s[a]; s[d] = rotl(s[d], 16)
    s[c] = (s[c] + s[d]) & MASK; s[b] ^= s[c]; s[b] = rotl(s[b], 12)
    s[a] = (s[a] + s[b]) & MASK; s[d] ^= s[a]; s[d] = rotl(s[d], 8)
    s[c] = (s[c] + s[d]) & MASK; s[b] ^= s[c]; s[b] = rotl(s[b], 7)


def chacha20_block(key, counter, nonce):
    """RFC 8439 section 2.3: 256-bit key, 32-bit counter, 96-bit nonce -> 64 bytes."""
    assert len(key) == 32 and len(nonce) == 12 and 0 <= counter <= MASK
    init = [0x61707865, 0x3320646E, 0x79622D32, 0x6B206574]
    init += list(struct.unpack("<8I", key))
    init += [counter]
    init += list(struct.unpack("<3I", nonce))
    s = list(init)
    for _ in range(10):
        quarter_round(s, 0, 4, 8, 12); quarter_round(s, 1, 5, 9, 13)
        quarter_round(s, 2, 6, 10, 14); quarter_round(s, 3, 7, 11, 15)
        quarter_round(s, 0, 5, 10, 15); quarter_round(s, 1, 6, 11, 12)
        quarter_round(s, 2, 7, 8, 13); quarter_round(s, 3, 4, 9, 14)
    return struct.pack("<16I", *[(s[i] + init[i]) & MASK for i in range(16)])


def chacha20_xor(key, counter, nonce, data):
    out = bytearray()
    for i in range(0, len(data), 64):
        block = chacha20_block(key, counter + i // 64, nonce)
        chunk = data[i:i + 64]
        out += bytes(a ^ b for a, b in zip(chunk, block))
    return bytes(out)


def poly1305_mac(msg, key):
    """RFC 8439 section 2.5: 32-byte one-time key, any message -> 16-byte tag."""
    assert len(key) == 32
    r = int.from_bytes(key[:16], "little") & 0x0FFFFFFC0FFFFFFC0FFFFFFC0FFFFFFF
    s = int.from_bytes(key[16:], "little")
    p = (1 << 130) - 5
    acc = 0
    for i in range(0, len(msg), 16):
        block = msg[i:i + 16]
        n = int.from_bytes(block, "little") + (1 << (8 * len(block)))
        acc = ((acc + n) * r) % p
    return ((acc + s) & ((1 << 128) - 1)).to_bytes(16, "little")


def poly1305_key_gen(key, nonce):
    """RFC 8439 section 2.6: first 32 bytes of block counter 0."""
    return chacha20_block(key, 0, nonce)[:32]


def pad16(x):
    return b"\x00" * (-len(x) % 16)


def aead_mac_data(aad, ct):
    return aad + pad16(aad) + ct + pad16(ct) + struct.pack("<QQ", len(aad), len(ct))


def aead_encrypt(key, nonce, aad, pt):
    otk = poly1305_key_gen(key, nonce)
    ct = chacha20_xor(key, 1, nonce, pt)
    return ct, poly1305_mac(aead_mac_data(aad, ct), otk)


def aead_decrypt(key, nonce, aad, ct, tag):
    """Returns (plaintext, tag_ok). The tag comparison is over all 16 bytes."""
    otk = poly1305_key_gen(key, nonce)
    calc = poly1305_mac(aead_mac_data(aad, ct), otk)
    ok = 0
    for a, b in zip(calc, tag):
        ok |= a ^ b
    return chacha20_xor(key, 1, nonce, ct), ok == 0


def selftest():
    hx = bytes.fromhex
    failures = 0

    def check(name, got, want):
        nonlocal failures
        good = got == want
        failures += 0 if good else 1
        print("%-40s %s" % (name, "PASS" if good else "FAIL"))

    # section 2.3.2: block function
    key = bytes(range(32))
    nonce = hx("000000090000004a00000000")
    blk = chacha20_block(key, 1, nonce)
    words = struct.unpack("<16I", blk)
    check("2.3.2 block function (words 0..3)", words[:4], (0xE4E7F110, 0x15593BD1, 0x1FDD0F50, 0xC47120A3))
    check("2.3.2 block function (words 12..15)", words[12:], (0xD19C12B5, 0xB94E16DE, 0xE883D0CB, 0x4E3C50A2))
    # section 2.5.2: Poly1305
    pkey = hx("85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")
    check("2.5.2 Poly1305 tag", poly1305_mac(b"Cryptographic Forum Research Group", pkey),
          hx("a8061dc1305136c6c22b8baf0c0127a9"))
    # section 2.6.2: one-time key
    k26 = bytes(range(0x80, 0xA0))
    n26 = hx("000000000001020304050607")
    check("2.6.2 one-time key",
          poly1305_key_gen(k26, n26),
          hx("8ad5a08b905f81cc815040274ab29471a833b637e3fd0da508dbb8e2fdd1a646"))
    # section 2.8.2: AEAD
    k28 = bytes(range(0x80, 0xA0))
    n28 = hx("070000004041424344454647")
    aad = hx("50515253c0c1c2c3c4c5c6c7")
    pt = (b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, "
          b"sunscreen would be it.")
    ct, tag = aead_encrypt(k28, n28, aad, pt)
    want_ct = hx("d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b"
                 "1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc"
                 "3ff4def08e4b7a9de576d26586cec64b6116")
    check("2.8.2 AEAD ciphertext", ct, want_ct)
    check("2.8.2 AEAD tag", tag, hx("1ae10b594f09e26a7e902ecbd0600691"))
    back, ok = aead_decrypt(k28, n28, aad, ct, tag)
    check("2.8.2 AEAD decrypt (tag ok, plaintext)", (back, ok), (pt, True))
    bad = bytes([tag[0] ^ 1]) + tag[1:]
    check("2.8.2 AEAD decrypt (flipped tag)", aead_decrypt(k28, n28, aad, ct, bad)[1], False)
    check("2.8.2 length 0 and 0 (tag only)", len(aead_encrypt(k28, n28, b"", b"")[0]), 0)
    print("RESULT: %s (%d failure(s))" % ("PASS" if failures == 0 else "FAIL", failures))
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(selftest())
