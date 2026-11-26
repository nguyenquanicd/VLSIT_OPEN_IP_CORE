"""Test cases of RFC 8554 Appendix F (file vlsit_lms_rfc8554.md of the skill vlsit-asic-ip-microspec, converted from the RFC text
obtained from rfc-editor.org): the HSS public key, the message and the HSS signature of each test case as bytes.
The dumps list one field per line (label, hexadecimal value, optional comment after '#', ASCII after '|'); the values are
concatenated in order. Page headers and footers of the RFC text are skipped."""
import os
import re

MD = os.path.expanduser('~/.claude/skills/vlsit-asic-ip-microspec/reference/md_doc/vlsit_lms_rfc8554.md')
HEX = re.compile(r'^[0-9a-f]+$')


def _section(txt, title, end_titles):
    i = txt.index(title)
    j = min([txt.index(e, i + len(title)) for e in end_titles if e in txt[i + len(title):]] + [len(txt)])
    return txt[i + len(title):j]


def _bytes(sec):
    out = []
    for line in sec.splitlines():
        if 'RFC 8554' in line or 'McGrew' in line:
            continue
        line = line.split('|')[0].split('#')[0]
        for tok in line.split():
            if HEX.match(tok) and len(tok) % 2 == 0 and len(tok) >= 2:
                out.append(tok)
    return bytes.fromhex(''.join(out))


def test_cases():
    txt = open(MD, encoding='utf-8').read()
    tc = {}
    for n in (1, 2):
        nxt = ['Test Case %d Message' % n, 'Test Case %d Signature' % n, 'Test Case %d Public Key' % (n + 1),
               'Test Case %d Private Key' % (n + 1), 'Acknowledgements',
               'Authors\' Addresses']
        pub = _bytes(_section(txt, 'Test Case %d Public Key' % n, nxt))
        msg = _bytes(_section(txt, 'Test Case %d Message' % n, nxt))
        sig = _bytes(_section(txt, 'Test Case %d Signature' % n, nxt))
        tc[n] = (pub, msg, sig)
    return tc


if __name__ == '__main__':
    for n, (pub, msg, sig) in test_cases().items():
        print('test case %d: public key %d bytes, message %d bytes (%r...), signature %d bytes' % (n, len(pub), len(msg), msg[:20], len(sig)))
