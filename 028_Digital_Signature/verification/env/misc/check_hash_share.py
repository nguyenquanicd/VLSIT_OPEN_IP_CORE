"""REQ-FUNC-011 (verification method: inspection), made repeatable: the top m_vlsit_dsig_top is elaborated by Verilator
(--json-only) with every algorithm group and the Hash_DRBG built (the legal union of the tb_top_ec and tb_top_pq
configurations plus PARA_RNG_SRC 1); the instance tree is walked from the top and every instance of a hash core is listed
with its full path. REQ-FUNC-011 holds when there is exactly one m_vlsit_sha_core256, one m_vlsit_sha_core512 and one
m_vlsit_sha_keccak, all under the one m_vlsit_sha_eng of the shared sequencer. The simulation side (one owner at a time,
both engines served) is checked by tb_top_sys.
Usage: python check_hash_share.py"""
import json
import os
import subprocess
import sys
from collections import defaultdict

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).replace(chr(92), '/')
R = os.path.normpath(V + '/../rtl').replace(chr(92), '/')
S = V + '/sim/hash_share'
VBIN = 'C:/Tools/oss-cad-suite/bin/verilator_bin.exe'
CORES = ('m_vlsit_sha_core256', 'm_vlsit_sha_core512', 'm_vlsit_sha_keccak', 'm_vlsit_sha_eng')
PARAMS = dict(PARA_EN_ED25519=1, PARA_EN_ED25519CTX=1, PARA_EN_ED25519PH=1, PARA_EN_ED448=1, PARA_EN_ED448PH=1,
              PARA_EN_ECDSA_P256=1, PARA_EN_ECDSA_P384=1, PARA_EN_ECDSA_P521=1, PARA_EN_ECDSA_K256=1, PARA_EN_MLDSA44=1,
              PARA_EN_MLDSA65=1, PARA_EN_MLDSA87=1, PARA_EN_SLHDSA=1, PARA_SLHDSA_SETS=0xFFF, PARA_EN_LMS=1,
              PARA_LMS_SETS=0xFFFFF, PARA_LMOTS_SETS=0xFFFF, PARA_EN_XMSS=1, PARA_XMSS_SETS_LO=0xFFFFFFFF,
              PARA_XMSS_SETS_HI=0xFFF, PARA_OP_KGEN=0xFFF, PARA_OP_SIGN=0xFFF, PARA_OP_VRFY=0x7FFF, PARA_BUF_BYTES=65536,
              PARA_EN_AXI=1, PARA_EN_KEYIF=1, PARA_EN_KEYREG=1, PARA_RNG_SRC=1)


def main():
    os.makedirs(S, exist_ok=True)
    cmd = [VBIN, '--json-only', '-Wno-fatal', '-Wno-lint', '-Wno-style', '-DVLSIT_SYNTHESIS', '--top-module', 'm_vlsit_dsig_top']
    cmd += ['-G%s=%d' % kv for kv in PARAMS.items()] + ['-f', 'filelist.f', '-Mdir', S + '/obj']
    env = dict(os.environ)
    env['PATH'] = 'C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib;' + env.get('PATH', '')
    r = subprocess.run(cmd, cwd=R, capture_output=True, text=True, env=env, timeout=3600)
    jf = S + '/obj/Vm_vlsit_dsig_top.tree.json'
    if r.returncode != 0 or not os.path.exists(jf):
        print((r.stdout + r.stderr)[-2000:])
        print('RESULT: FAIL (elaboration)')
        return 1
    tree = json.load(open(jf))
    mods = {}                   # addr -> (origName, [(cell name, modp)])

    def collect(node, cur):
        if isinstance(node, dict):
            if node.get('type') == 'MODULE':
                cur = node['addr']
                mods[cur] = (node.get('origName', node['name']), [])
            elif node.get('type') == 'CELL' and cur is not None:
                mods[cur][1].append((node['name'], node['modp']))
            for v in node.values():
                if isinstance(v, (dict, list)):
                    collect(v, cur)
        elif isinstance(node, list):
            for v in node:
                collect(v, cur)
    collect(tree.get('modulesp', []), None)
    top = [a for a, (n, _) in mods.items() if n == 'm_vlsit_dsig_top'][0]
    found = defaultdict(list)

    def walk(addr, path):
        name, cells = mods[addr]
        if name in CORES:
            found[name].append(path)
        for cn, mp in cells:
            if mp in mods:
                walk(mp, path + '.' + cn)
    walk(top, 'm_vlsit_dsig_top')
    for c in CORES:
        print('%-22s %d: %s' % (c, len(found[c]), ', '.join(found[c])))
    ok = all(len(found[c]) == 1 for c in CORES) and all(p.startswith(found['m_vlsit_sha_eng'][0]) for c in CORES[:3]
                                                        for p in found[c])
    print('check_hash_share: %s' % ('one instance of each hash core, inside the one m_vlsit_sha_eng, with every algorithm group '
                                    'built' if ok else 'NOT one shared hash engine'))
    print('RESULT: %s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
