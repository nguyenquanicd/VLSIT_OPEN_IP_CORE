"""REQ-PARAM-001 and REQ-PARAM-002: elaboration of m_vlsit_dsig_top with legal and illegal parameter combinations.

Every illegal combination of section 8 must stop elaboration with the module m_vlsit_dsig_top_error_<reason> of that rule
(the RTL rule set forbids system tasks, so the top instantiates a module that does not exist); the check passes only when
Verilator reports exactly that missing module. Every legal combination (the defaults, the configurations of the top test
benches, PARA_MUL_W 32/64/128, the RNG and nonce options) must elaborate without error.
Usage: python run_params.py"""
import os
import re
import subprocess
import sys

IP = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')).replace(chr(92), '/')
VBIN = 'C:/Tools/oss-cad-suite/bin/verilator_bin.exe'

EC = dict(PARA_EN_ECDSA_P256=1, PARA_OP_SIGN=0x20, PARA_OP_VRFY=0x20, PARA_EN_KEYREG=1)
LEGAL = [
    ('defaults', {}),
    ('tb_top_ec configuration', dict(PARA_EN_ED25519=1, PARA_EN_ED25519CTX=1, PARA_EN_ED25519PH=1, PARA_EN_ED448=1, PARA_EN_ED448PH=1,
                                     PARA_EN_ECDSA_P256=1, PARA_EN_ECDSA_P384=1, PARA_EN_ECDSA_P521=1, PARA_EN_ECDSA_K256=1,
                                     PARA_OP_KGEN=0x1FF, PARA_OP_SIGN=0x1FF, PARA_OP_VRFY=0x1FF, PARA_EN_AXI=1, PARA_EN_DMA=1,
                                     PARA_EN_KEYIF=1, PARA_EN_KEYREG=1, PARA_ECDSA_NONCE=2, PARA_EN_VAS=1, PARA_EN_LOG=1)),
    ('tb_top_pq configuration', dict(PARA_EN_MLDSA44=1, PARA_EN_MLDSA65=1, PARA_EN_MLDSA87=1, PARA_EN_SLHDSA=1, PARA_SLHDSA_SETS=0xFFF,
                                     PARA_EN_LMS=1, PARA_LMS_SETS=0xFFFFF, PARA_LMOTS_SETS=0xFFFF, PARA_EN_XMSS=1,
                                     PARA_XMSS_SETS_LO=0xFFFFFFFF, PARA_XMSS_SETS_HI=0xFFF, PARA_OP_KGEN=0xE00, PARA_OP_SIGN=0xE00,
                                     PARA_OP_VRFY=0x7E00, PARA_BUF_BYTES=65536, PARA_EN_AXI=1, PARA_EN_KEYREG=1, PARA_EN_VAS=1)),
    ('hybrid, RNG_SRC 1, DPA_EC, nonce 1', dict(PARA_EN_ED25519=1, PARA_EN_MLDSA44=1, PARA_OP_VRFY=0x201, PARA_OP_SIGN=0x001,
                                                PARA_EN_KEYREG=1, PARA_EN_HYBRID=1, PARA_RNG_SRC=1, PARA_EN_DPA_EC=1,
                                                PARA_BUF_BYTES=4096, PARA_EN_VAS=1)),
    ('nonce 1 with P-256', dict(EC, PARA_ECDSA_NONCE=1)),
    ('DPA_PQ with ML-DSA-44', dict(PARA_EN_MLDSA44=1, PARA_OP_VRFY=0x200, PARA_OP_SIGN=0x200, PARA_EN_KEYREG=1, PARA_BUF_BYTES=4096,
                                   PARA_EN_DPA_PQ=1)),
    ('PARA_MUL_W 32', dict(EC, PARA_MUL_W=32)),
    ('PARA_MUL_W 128', dict(EC, PARA_MUL_W=128)),
]
ILLEGAL = [
    ('PARA_AXI_DW 32', dict(PARA_EN_AXI=1, PARA_AXI_DW=32), 'PARA_AXI_DW_shall_be_64'),
    ('no message form', dict(PARA_EN_PURE=0, PARA_EN_PREHASH=0), 'one_of_PARA_EN_PURE_and_PARA_EN_PREHASH_shall_be_1'),
    ('DMA without AXI4', dict(PARA_EN_DMA=1), 'PARA_EN_DMA_needs_PARA_EN_AXI'),
    ('SLH-DSA without sets', dict(PARA_EN_SLHDSA=1, PARA_OP_VRFY=0x1000), 'PARA_EN_SLHDSA_needs_a_nonzero_PARA_SLHDSA_SETS'),
    ('LMS without LM-OTS sets', dict(PARA_EN_LMS=1, PARA_LMS_SETS=1, PARA_OP_VRFY=0x2000), 'PARA_EN_LMS_needs_nonzero'),
    ('XMSS without sets', dict(PARA_EN_XMSS=1, PARA_OP_VRFY=0x4000), 'PARA_EN_XMSS_needs_nonzero_PARA_XMSS_SETS'),
    ('Ed25519ph without Ed25519', dict(PARA_EN_ED25519PH=1, PARA_OP_VRFY=0x4), 'Ed25519ctx_and_Ed25519ph_need_PARA_EN_ED25519'),
    ('Ed448ph without Ed448', dict(PARA_EN_ED448PH=1, PARA_OP_VRFY=0x10), 'Ed448ph_needs_PARA_EN_ED448'),
    ('DPA_PQ without ML-DSA', dict(PARA_EN_SLHDSA=1, PARA_SLHDSA_SETS=1, PARA_OP_VRFY=0x1000, PARA_BUF_BYTES=8192, PARA_EN_DPA_PQ=1),
     'PARA_EN_DPA_PQ_needs_ML_DSA'),
    ('nonce code 3', dict(EC, PARA_ECDSA_NONCE=3), 'PARA_ECDSA_NONCE_must_be_0_1_or_2'),
    ('RNG_SRC 2', dict(EC, PARA_RNG_SRC=2), 'PARA_RNG_SRC_shall_be_0_or_1'),
    ('no AXI4 and no window', dict(PARA_EN_WIN=0), 'one_of_PARA_EN_AXI_and_PARA_EN_WIN_shall_be_1'),
    ('nonce without ECDSA', dict(PARA_EN_ED25519=1, PARA_OP_VRFY=1, PARA_ECDSA_NONCE=2), 'PARA_ECDSA_NONCE_needs_an_ECDSA_curve'),
    ('DPA_EC without curve', dict(PARA_EN_MLDSA44=1, PARA_OP_VRFY=0x200, PARA_BUF_BYTES=4096, PARA_EN_DPA_EC=1),
     'PARA_EN_DPA_EC_needs_an_elliptic_curve_algorithm'),
    ('hybrid without ML-DSA', dict(PARA_EN_ED25519=1, PARA_OP_VRFY=1, PARA_EN_HYBRID=1), 'PARA_EN_HYBRID_needs_Ed25519_and_ML_DSA'),
    ('VAS without signing', dict(PARA_EN_ED25519=1, PARA_OP_VRFY=1, PARA_EN_VAS=1), 'PARA_EN_VAS_needs_a_signing_path'),
    ('operation mask of an algorithm not built', dict(PARA_EN_ED25519=1, PARA_OP_VRFY=0x3), 'PARA_OP_masks_name_an_algorithm'),
    ('signing of SLH-DSA', dict(PARA_EN_SLHDSA=1, PARA_SLHDSA_SETS=1, PARA_OP_VRFY=0x1000, PARA_OP_SIGN=0x1000, PARA_EN_KEYREG=1,
                                 PARA_BUF_BYTES=8192),
     'PARA_OP_masks_name_an_algorithm'),
    ('PARA_MUL_W 48', dict(EC, PARA_MUL_W=48), 'PARA_MUL_W_shall_be_32_64_or_128'),
    ('buffer too small for ML-DSA-87', dict(PARA_EN_MLDSA87=1, PARA_OP_VRFY=0x800, PARA_BUF_BYTES=4096),
     'PARA_BUF_BYTES_smaller_than_signature_and_public_key'),
    ('buffer too small for SLH-DSA-SHA2-256f', dict(PARA_EN_SLHDSA=1, PARA_SLHDSA_SETS=0x20, PARA_OP_VRFY=0x1000, PARA_BUF_BYTES=32768),
     'PARA_BUF_BYTES_smaller_than_signature_and_public_key'),
    ('signing without key source', dict(EC, PARA_EN_KEYREG=0), 'signing_or_key_generation_needs_PARA_EN_KEYIF_or_PARA_EN_KEYREG'),
]


def elab(params):
    cmd = [VBIN, '--lint-only', '-Wno-fatal', '-Wno-lint', '-Wno-style', '-f', 'filelist.f', '--top-module', 'm_vlsit_dsig_top']
    cmd += ['-G%s=%d' % (k, v) for k, v in params.items()]
    r = subprocess.run(cmd, cwd=IP + '/rtl', capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def main():
    nfail = 0
    for name, prm in LEGAL:
        rc, out = elab(prm)
        errs = [l for l in out.splitlines() if l.startswith('%Error')]
        ok = rc == 0 and not errs
        nfail += not ok
        print('%-5s legal   %-45s %s' % ('PASS' if ok else 'FAIL', name, '' if ok else errs[:2]))
    for name, prm, reason in ILLEGAL:
        rc, out = elab(prm)
        errs = [l for l in out.splitlines() if l.startswith('%Error')]
        missing = re.findall(r"m_vlsit_dsig_top_error_\w+", out)
        ok = rc != 0 and missing and all(reason in m for m in missing)
        nfail += not ok
        print('%-5s illegal %-45s %s' % ('PASS' if ok else 'FAIL', name, sorted(set(missing)) if not ok else reason))
    print('run_params: %d legal, %d illegal, %d failed' % (len(LEGAL), len(ILLEGAL), nfail))
    print('RESULT: %s' % ('PASS' if nfail == 0 else 'FAIL'))
    return nfail


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
