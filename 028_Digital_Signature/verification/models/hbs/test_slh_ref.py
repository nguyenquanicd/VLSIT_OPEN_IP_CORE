"""Checks slh_ref.py (and so the later microprogram) against signatures made by OpenSSL 3.5 or later, an independent
SLH-DSA implementation: for each of the 12 parameter sets a key is generated, a message is signed in the pure form
(M' = 0x00 || len(ctx) || ctx || M) and verified with the reference; corrupted signatures must be rejected.
OpenSSL is only called as a local program; its path is OPENSSL below."""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slh_ref as S

OPENSSL = os.environ.get('OPENSSL', 'C:/Users/PC/Tools/msys64/usr/bin/openssl.exe')


def ossl(*args, cwd=None):
    r = subprocess.run([OPENSSL] + list(args), capture_output=True, cwd=cwd)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode(errors='replace'))
    return r.stdout


def make(idx, msg, ctx=b'', tmp=None):
    """Returns (pk, sig) of a fresh key of parameter set idx for message msg."""
    name = S.SETS[idx]['name'].replace('SLH-DSA-', 'SLH-DSA-')
    d = tmp or tempfile.mkdtemp()
    key, pub, mf, sf = (os.path.join(d, x) for x in ('k.pem', 'p.der', 'm.bin', 's.bin'))
    ossl('genpkey', '-algorithm', name, '-out', key)
    ossl('pkey', '-in', key, '-pubout', '-outform', 'DER', '-out', pub)
    open(mf, 'wb').write(msg)
    opts = ['-pkeyopt', 'context-string:' + ctx.hex()] if False else []
    ossl('pkeyutl', '-sign', '-inkey', key, '-rawin', '-in', mf, '-out', sf)
    pk = open(pub, 'rb').read()[-2 * S.SETS[idx]['n']:]
    return pk, open(sf, 'rb').read()


def main():
    n_ok = 0
    for idx in range(12):
        p = S.SETS[idx]
        msg = bytes(range(37 + idx))
        pk, sig = make(idx, msg)
        assert len(sig) == p['sig'], (p['name'], len(sig), p['sig'])
        v = S.Slh(idx)
        mp = b'\x00\x00' + msg
        assert v.verify(mp, sig, pk), '%s: the reference rejects an OpenSSL signature' % p['name']
        bad = bytearray(sig)
        bad[len(sig) // 2] ^= 4
        assert not v.verify(mp, bytes(bad), pk), '%s: accepts a corrupted signature' % p['name']
        assert not v.verify(b'\x00\x00' + msg[:-1] + b'x', sig, pk), '%s: accepts a wrong message' % p['name']
        n_ok += 1
        print('%-22s ok (sig %d bytes)' % (p['name'], len(sig)))
    print('SLH-DSA reference: %d of 12 sets agree with OpenSSL' % n_ok)


if __name__ == '__main__':
    main()
