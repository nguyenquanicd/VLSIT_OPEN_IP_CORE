"""Buffer images of the combined system test verification/tests/top/tb_top_sys.sv.

  sys_ed.hex     Ed25519 RFC 8032 section 7.1 TEST 2 (message 0x72): message at 0, signature at 256, public key at 512
  sys_ed_key.hex its 32-byte secret key (for the signing that the reset interrupts)
  sys_ml.hex     ML-DSA-44 signature of OpenSSL 3.6 over 50 bytes: message at 0, public key at 4096, signature at 8192
  sys_mlbad.hex  the same with one byte of the signature changed
  sys_len.txt    message lengths and image sizes
Usage: python gen_sys_vec.py <dir>"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'ec'))
sys.path.insert(0, os.path.join(HERE, '..', 'lat'))
import test_ec_model as TE
import test_mldsa_ref as TM


def wr(path, data):
    with open(path, 'w') as fh:
        fh.write('\n'.join('%02x' % b for b in data) + '\n')


def main(d):
    os.makedirs(d, exist_ok=True)
    sk, pk, msg, sig = TE.ed25519_vectors()[1]
    assert msg == b'\x72'
    img = bytearray(1024)
    img[0:len(msg)] = msg
    img[256:256 + 64] = sig
    img[512:512 + 32] = pk
    wr(os.path.join(d, 'sys_ed.hex'), img)
    wr(os.path.join(d, 'sys_ed_key.hex'), sk)
    seed = bytes((i * 7 + 44) % 256 for i in range(32))
    m = bytes(range(50))
    mpk, msig = TM.ossl_make(44, seed, m)
    img = bytearray(8192 + len(msig))
    img[0:50] = m
    img[4096:4096 + len(mpk)] = mpk
    img[8192:] = msig
    wr(os.path.join(d, 'sys_ml.hex'), img)
    img[8192 + 40] ^= 4
    wr(os.path.join(d, 'sys_mlbad.hex'), img)
    with open(os.path.join(d, 'sys_len.txt'), 'w') as fh:
        fh.write('%d %d %d\n' % (len(msg), len(m), len(img)))
    print('system test images written to', d)


if __name__ == '__main__':
    main(sys.argv[1])
