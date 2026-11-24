"""Checks mldsa_ref.py against OpenSSL 3.5 or later (independent): public key from a seed, deterministic signature,
hedged verification, verification of OpenSSL signatures, rejection of corrupted ones."""
import os
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mldsa_ref as M

OPENSSL = os.environ.get('OPENSSL', 'C:/Users/PC/Tools/msys64/usr/bin/openssl.exe')


def ossl(*args):
    r = subprocess.run([OPENSSL] + list(args), capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode(errors='replace'))
    return r.stdout


def ossl_make(level, seed, msg, ctx=b'', det=True):
    d = tempfile.mkdtemp()
    key, pub, mf, sf = (os.path.join(d, x) for x in ('k.pem', 'p.der', 'm.bin', 's.bin'))
    ossl('genpkey', '-algorithm', 'ML-DSA-%d' % level, '-pkeyopt', 'hexseed:' + seed.hex(), '-out', key)
    ossl('pkey', '-in', key, '-pubout', '-outform', 'DER', '-out', pub)
    open(mf, 'wb').write(msg)
    opts = (['-pkeyopt', 'deterministic:1'] if det else []) + (['-pkeyopt', 'context-string:' + ctx.decode()] if ctx else [])
    ossl('pkeyutl', '-sign', '-inkey', key, '-rawin', '-in', mf, '-out', sf, *opts)
    pk = open(pub, 'rb').read()[-(32 + 320 * M.PARAMS[level]['k']):]
    return pk, open(sf, 'rb').read()


def main():
    t0 = time.time()
    for level in (44, 65, 87):
        seed = bytes((i * 7 + level) % 256 for i in range(32))
        msg = bytes(range(50))
        pk, sig = ossl_make(level, seed, msg)
        m = M.MlDsa(level)
        key = m.keygen(seed)
        assert key['pk'] == pk, 'ML-DSA-%d: public key differs from OpenSSL' % level
        mp = b'\x00\x00' + msg
        assert m.verify(pk, mp, sig), 'ML-DSA-%d: the reference rejects an OpenSSL signature' % level
        mine = m.sign(key, mp)
        assert mine == sig, 'ML-DSA-%d: deterministic signature differs from OpenSSL (%d attempts)' % (level, m.last_attempts)
        bad = bytearray(sig); bad[len(sig) // 2] ^= 1
        assert not m.verify(pk, mp, bytes(bad))
        assert not m.verify(pk, b'\x00\x00' + msg[:-1] + b'x', sig)
        print('ML-DSA-%d ok: keygen, deterministic signature (%d attempts), verify; %.0f s' % (level, m.last_attempts, time.time() - t0))
    # context
    pk, sig = ossl_make(44, bytes(32), b'abc', ctx=b'hello')
    assert M.MlDsa(44).verify(pk, b'\x00\x05hello' + b'abc', sig)
    print('context string ok')


if __name__ == '__main__':
    main()
