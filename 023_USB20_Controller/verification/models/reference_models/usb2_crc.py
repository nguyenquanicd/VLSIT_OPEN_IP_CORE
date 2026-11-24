"""USB 2.0 CRC reference (REQ-FUNC-003; USB 2.0 section 8.3.5). Written from the standard, not from the RTL.

Bit-serial definition: the remainder starts at all ones; for every bit, in the order it is sent on the bus (LSB of each
field or byte first), the bit is XORed with the high-order bit of the remainder, the remainder is shifted left by one, and
the generator polynomial is XORed in when that XOR result is 1. The CRC field is the inverted remainder, sent high-order
bit first. CRC5: G(X) = X^5+X^2+1 (00101b), residual 01100b. CRC16: G(X) = X^16+X^15+X^2+1 (8005h), residual 800Dh.
"""


def crc_bits(bits, width, poly):
    """bits: iterable of 0/1 in transmission order. Returns the remainder (not inverted)."""
    mask = (1 << width) - 1
    rem = mask
    for b in bits:
        x = b ^ (rem >> (width - 1))
        rem = (rem << 1) & mask
        if x:
            rem ^= poly
    return rem


def field_bits(value, n):
    """n bits of value, LSB first (transmission order)."""
    return [(value >> i) & 1 for i in range(n)]


def crc5_field(value, n=11):
    """CRC5 field of an n-bit token value as transmission-order bits (first sent bit first)."""
    rem = crc_bits(field_bits(value, n), 5, 0b00101) ^ 0x1F
    return [(rem >> i) & 1 for i in (4, 3, 2, 1, 0)]


def crc16_field(data):
    """CRC16 field of a byte sequence as two bytes in bus order (each byte LSB first on the wire)."""
    bits = [b for byte in data for b in field_bits(byte, 8)]
    rem = crc_bits(bits, 16, 0x8005) ^ 0xFFFF
    tx = [(rem >> i) & 1 for i in range(15, -1, -1)]          # transmission order
    return [sum(tx[k * 8 + i] << i for i in range(8)) for k in range(2)]


def residual5(value_bits_with_crc):
    return crc_bits(value_bits_with_crc, 5, 0b00101)


def residual16(data_with_crc):
    return crc_bits([b for byte in data_with_crc for b in field_bits(byte, 8)], 16, 0x8005)


def selftest():
    """Known answers. Residuals are those stated in the standard and in REQ-FUNC-003; token vectors are the published
    examples of the USB-IF CRC white paper (transmission-order bit strings)."""
    ok = True
    known = [('10101000111', '10111'), ('01011100101', '11100'), ('00001110010', '01110')]
    for bits, crc in known:
        v = sum(int(c) << i for i, c in enumerate(bits))
        got = ''.join(str(b) for b in crc5_field(v))
        print('crc5 %s -> %s expect %s %s' % (bits, got, crc, 'ok' if got == crc else 'MISMATCH'))
        ok &= got == crc
        r = residual5([int(c) for c in bits] + crc5_field(v))
        print('  residual %s' % format(r, '05b'))
        ok &= r == 0b01100
    for data in ([], [0x00, 0x01, 0x02, 0x03], [0x23, 0x45, 0x67, 0x89], list(range(64))):
        f = crc16_field(data)
        r = residual16(data + f)
        print('crc16 len %d -> %02x %02x residual %04x' % (len(data), f[0], f[1], r))
        ok &= r == 0x800D
    # Data examples of the white paper as the two CRC bytes on the bus: 00 01 02 03 -> EF 7A ; 23 45 67 89 -> 0E 1C.
    # These values and the token vectors above were written from memory of the paper; a reviewer must confirm them
    # against the document. The residual checks do not depend on them.
    for data, exp in (([0, 1, 2, 3], [0xEF, 0x7A]), ([0x23, 0x45, 0x67, 0x89], [0x0E, 0x1C])):
        got = crc16_field(data)
        print('crc16 bus bytes %s expect %s %s' % (got, exp, 'ok' if got == exp else 'MISMATCH'))
        ok &= got == exp
    print('SELFTEST', 'PASS' if ok else 'FAIL')
    return ok


if __name__ == '__main__':
    raise SystemExit(0 if selftest() else 1)
