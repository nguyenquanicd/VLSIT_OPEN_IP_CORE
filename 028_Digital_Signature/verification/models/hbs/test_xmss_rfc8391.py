"""Consistency of the XMSS model (xmss_ref.py, which the RTL test vectors come from) with the text of RFC 8391 (file
vlsit_xmss_rfc8391.md, converted from the RFC obtained from rfc-editor.org). RFC 8391 has no test vectors, so this is a check
of the constructions, not a known-answer test:
  1. the domain-separation prefixes of F, H, H_msg and PRF (section 5.1: toByte(0..3, n));
  2. the address layout (section 2.5: layer 32 bits, tree 64 bits, type 32 bits, three words, keyAndMask 32 bits);
  3. the identifiers of the sets that exist in both RFC 8391 and SP 800-208 (XMSS-SHA2_h_256 and XMSSMT-SHA2_h/d_256);
  4. the address types 0 (OTS), 1 (L-tree), 2 (hash tree) used by the model.
Usage: python test_xmss_rfc8391.py"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xmss_ref as X

MD = os.path.expanduser('~/.claude/skills/vlsit-asic-ip-microspec/reference/md_doc/vlsit_xmss_rfc8391.md')


def main():
    txt = open(MD, encoding='utf-8').read()
    n = 0
    # 1. prefixes of the SHA2-256 constructions in section 5.1
    for fn, x in (('F', 0), ('H', 1), ('H_msg', 2), ('PRF', 3)):
        m = re.search(r'\b%s: SHA2-256\(toByte\((\d), 32\) \|\| KEY \|\| M\)' % re.escape(fn), txt)
        assert m and int(m.group(1)) == x, fn
    x = X.Xmss(0)
    key, msg = bytes(32), b'\x01' * 32
    import hashlib
    for fn, pre in (('F', 0), ('H', 1), ('Hmsg', 2), ('PRF', 3)):
        assert getattr(x, fn)(key, msg) == hashlib.sha256(pre.to_bytes(32, 'big') + key + msg).digest(), fn
        n += 1
    # 2. address layout of section 2.5
    lay = re.findall(r'\| (layer address|tree address|type|keyAndMask)\s+\((\d+) bits\)\|', txt)
    widths = dict(lay)
    assert widths.get('layer address') == '32' and widths.get('tree address') == '64' and widths.get('keyAndMask') == '32', lay
    a = X.Xmss.adrs([0x01020304, 0x0506070809101112, 0x13141516, 0x17181920, 0x21222324, 0x25262728, 0x29303132])
    assert len(a) == 32 and a[:4] == bytes.fromhex('01020304') and a[4:12] == bytes.fromhex('0506070809101112') and \
        a[12:16] == bytes.fromhex('13141516') and a[28:32] == bytes.fromhex('29303132')
    n += 1
    # 3. identifiers of the XMSS and XMSS^MT registries
    reg = dict((name, int(code, 16)) for code, name in re.findall(r'\|\s+(0x[0-9A-Fa-f]{8})\s+\|\s+(XMSS(?:MT)?-SHA2_[\w/]+_256)\s+\|', txt))
    common = 0
    for s in X.SETS:
        if s['name'] in reg:
            assert s['oid'] == reg[s['name']], (s['name'], s['oid'], reg[s['name']])
            common += 1
    assert common >= 11, common
    n += common
    # 4. address types
    assert re.search(r'It is set to 0 for an OTS address, to 1 for an L-tree address, and to\s+2 for a hash tree address', txt)
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'xmss_ref.py')).read()
    # the three address forms of section 2.5 and the words that the verification path of the model sets in each
    for t, words in ((0, ('OTS address', 'chain address', 'hash address')), (1, ('L-tree address', 'tree height', 'tree index')),
                     (2, ('Padding = 0', 'tree height', 'tree index'))):
        pat = r'type = %d\s+\(32 bits\)\|[\s+\-]*\|\s+%s' % (t, re.escape(words[0]))
        assert re.search(pat, txt), (t, words[0])
    assert 'a[2], a[3], a[4], a[5], a[6] = 0, idx, 0, 0, 0' in src      # OTS address = leaf index, chain and hash set per step
    assert 'a[2], a[3], a[4], a[5], a[6] = 1, idx, 0, 0, 0' in src      # L-tree address = leaf index
    assert 'a[2], a[3], a[4], a[5], a[6] = 2, 0, 0, idx, 0' in src      # hash tree: padding 0, height per level, index
    n += 3
    print('RFC 8391 consistency: %d checks (prefixes, address layout, %d identifiers shared with SP 800-208); address types per the text'
          % (n, common))


if __name__ == '__main__':
    main()
