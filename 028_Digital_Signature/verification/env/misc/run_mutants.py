"""Strength check of the checkers added in the second phase: each mutant puts one defect back into a copy of the RTL and runs
the test that is meant to catch it; the mutant must make that test FAIL. The original RTL is never edited: the mutated file
is written to a scratch folder and put in front of the file list of the test (same module name).

Mutants:
  M1 secret-dependent scalar multiplication (ADD only for a 1 bit)        -> tb_ec ct with +CT
  M2 Ed25519ph accepted in the pure form (ASM-023 check removed)            -> tb_top_err
  M3 deterministic nonce accepted with SHA3 (ASM-024 check removed)         -> tb_top_err
  M4 Hash_DRBG reseed counter not reset by a seed                           -> tb_rng_drbg
  M5 hybrid: Ed25519 result not latched in edok                             -> tb_top_sys
  M6 DMA output request ignores the acknowledge                             -> tb_top_sys
  M7 scalar blinding never taken (LDV 2 returns 0)                          -> tb_top_ec det with PARA_EN_DPA_EC (monitor)
  M8 curve and hash pairing applied to key generation (fixed bug put back)  -> phase 1 T05 is not used: tb_top_ec det (keygen P-384)
  M9 ML-DSA masking never taken (LDS 6 default returns 0)                   -> tb_lat quick with PARA_EN_DPA_PQ (mask monitor)
  M10 AXI4 write: refusal of the buffer in the middle of a burst ignored    -> tb_axi (mid-burst busy, DEC-050)
  M11 AXI4 read: refusal of the buffer in the middle of a burst ignored     -> tb_axi (mid-burst busy, DEC-050)
  M12 PARA_KEY_SRC 0 takes the key registers instead of the port            -> tb_key_rng (DEC-051)
  M13 SHA3-256 (dsig_op.hash 3) mapped to SHA-256 in the EC engine          -> tb_ec sha3 (DEC-018)
Usage: python run_mutants.py [M1 ...]"""
import os
import re
import shutil
import subprocess
import sys

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).replace(chr(92), '/')
R = os.path.normpath(V + '/../rtl').replace(chr(92), '/')
S = V + '/sim'
WORK = S + '/mutants'
PY = sys.executable

MUT = {
    'M1': ('m_vlsit_dsig_ec.sv', "              if (!reg_sm_bitq) begin\n                reg_rf[0] <= reg_sm_sh[575:0];",
           "              if (1'b0) begin\n                reg_rf[0] <= reg_sm_sh[575:0];",
           # with the restore removed the result is wrong too; make the time secret-dependent instead: skip ADD for a 0 bit
           None, 'ec_ct'),
    'M2': ('m_vlsit_dsig_ctl.sv', "& ({30'd0, reg_run_form} != LPARA_FORM_PREHASH))\n      w_f_opuns = 1'b1;",
           "& 1'b0)\n      w_f_opuns = 1'b1;", None, 'top_err'),
    'M3': ('m_vlsit_dsig_ctl.sv', "if (w_is_ecdsa & w_is_sign & w_det & (reg_run_hash > 3'd2))", "if (1'b0)", None, 'top_err'),
    'M4': ('m_vlsit_dsig_drbg.sv', "            reg_cnt  <= 32'd1;\n", "", None, 'rng_drbg'),
    'M5': ('m_vlsit_dsig_ctl.sv', "assign w_ed_nxt    = (w_alg32 == LPARA_ALG_ED25519) ? reg_raw_ok : reg_edok;",
           "assign w_ed_nxt    = reg_edok;", None, 'top_sys'),
    'M6': ('m_vlsit_dsig_axi.sv', "assign o_dma_out_req = i_resvld & ~reg_out_done;", "assign o_dma_out_req = i_resvld;", None, 'top_sys'),
    'M7': ('m_vlsit_dsig_ec.sv', "                2'd2:    reg_rf[w_rd] <= 576'(PARA_EN_DPA[0]);", "                2'd2:    reg_rf[w_rd] <= 576'd0;",
           None, 'top_ec_dpa'),
    'M8': ('m_vlsit_dsig_ctl.sv', "if (w_is_ecdsa & (w_is_sign | w_is_vrfy) & (w_dig_len < w_min_len))",
           "if (w_is_ecdsa & (w_dig_len < w_min_len))", None, 'top_ec_dpa'),
}
MUT['M9'] = ('m_vlsit_dsig_lat.sv', "                default: reg_rf[w_rd] <= {31'd0, PARA_EN_DPA[0]};",
             "                default: reg_rf[w_rd] <= 32'd0;", None, 'lat_dpa')
# M10, M11: a refusal of the buffer in the middle of a burst is ignored (write, read): the burst would end with OKAY
MUT['M10'] = ('m_vlsit_dsig_axi.sv', "          if (i_buf_wr_rej)\n            reg_werr <= 1'b1;\n        end\n        ENUM_ST_W_WAIT: begin\n          if (i_buf_wr_rej)\n            reg_werr <= 1'b1;",
              "          if (1'b0)\n            reg_werr <= 1'b1;\n        end\n        ENUM_ST_W_WAIT: begin\n          if (1'b0)\n            reg_werr <= 1'b1;", None, 'axi')
MUT['M11'] = ('m_vlsit_dsig_axi.sv', "            if (i_buf_rd_rej)\n              reg_rerr <= 1'b1;",
              "            if (1'b0)\n              reg_rerr <= 1'b1;", None, 'axi')
# M12: PARA_KEY_SRC 0 (port) takes the registers instead
MUT['M12'] = ('m_vlsit_dsig_key.sv', "32'd0:   w_use_port = 1'b1;", "32'd0:   w_use_reg  = 1'b1;", None, 'key_rng')
# M13: SHA3-256 of dsig_op.hash 3 mapped to SHA-256 in the elliptic-curve engine
MUT['M13'] = ('m_vlsit_dsig_ec.sv', "3'd3:    w_hf_mode_map = 4'd9;", "3'd3:    w_hf_mode_map = 4'd1;", None, 'ec_sha3')
# M1: the restore stays, but ADD is skipped for a 0 bit (the original double-and-add): result right, time secret-dependent
MUT['M1'] = ('m_vlsit_dsig_ec.sv', "          2'd2:    w_fsm_ec_nxt_state = ENUM_ST_EXEC;",
             "          2'd2:    w_fsm_ec_nxt_state = w_sm_bit ? ENUM_ST_EXEC : ENUM_ST_SMUL;", None, 'ec_ct')


def mutate(m):
    f, old, new, _, test = MUT[m]
    src = open(R + '/' + f, encoding='utf-8').read()
    assert src.count(old) == 1, (m, 'pattern not found once')
    d = WORK + '/' + m
    os.makedirs(d, exist_ok=True)
    txt = src.replace(old, new)
    if m == 'M1':
        # phase 2 must not call ADD for a 0 bit either
        a = "              reg_sm_ph   <= 2'd3;\n              reg_pc      <= reg_sm_add;\n              reg_sm_call <= 1'b1;\n"
        assert txt.count(a) == 1
        txt = txt.replace(a, "              reg_sm_ph   <= 2'd3;\n              if (w_sm_bit) begin\n                reg_pc      <= reg_sm_add;\n"
                             "                reg_sm_call <= 1'b1;\n              end\n")
    open(d + '/' + f, 'w', encoding='utf-8').write(txt)
    return d + '/' + f, test


def run(m):
    path, test = mutate(m)
    env = dict(os.environ)
    env['UNIT_TAG'] = '_mut_' + m
    env['MUT_FILE'] = path
    if test == 'ec_sha3':
        env['EC_TAG'] = 'ec_mut_' + m
        cmd = [PY, 'env/ec/run_ec.py', 'sha3']
        log = S + '/ec_mut_%s/sha3.log' % m
    elif test == 'ec_ct':
        env['EC_TAG'] = 'ec_mut_' + m
        cmd = [PY, 'env/ec/run_ec.py', 'ct']
        log = S + '/ec_mut_%s/ct.log' % m
    elif test == 'top_ec_dpa':
        env['UNIT_DEFS'] = '-DTB_RNG_SRC=1 -DTB_DPA_EC=1'
        cmd = [PY, 'env/misc/run_unit.py', 'top_ec', '+VEC=' + S + '/det.hex', '+NVEC=26']
        log = S + '/top_ec_mut_%s/run.log' % m
    elif test == 'lat_dpa':
        env['UNIT_DEFS'] = '-DTB_DPA=1'
        env['LAT_SET_TAG'] = '_mut'
        cmd = [PY, 'env/lat/run_lat.py', 'quick']
        log = S + '/lat_quick_mut/run.log'
    elif test == 'rng_drbg':
        cmd = [PY, 'env/misc/run_unit.py', 'rng_drbg', '+VEC=' + S + '/drbg_vec.txt']
        log = S + '/rng_drbg_mut_%s/run.log' % m
    elif test == 'top_sys':
        cmd = [PY, 'env/misc/run_unit.py', 'top_sys', '+DIR=' + S + '/sys']
        log = S + '/top_sys_mut_%s/run.log' % m
    else:
        cmd = [PY, 'env/misc/run_unit.py', test]
        log = S + '/%s_mut_%s/run.log' % (test, m)
    subprocess.run(cmd, cwd=V, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    out = open(log, errors='replace').read() if os.path.exists(log) else ''
    killed = 'RESULT: FAIL' in out or ('RESULT: PASS' not in out and out != '')
    fails = [l for l in out.splitlines() if 'FAIL' in l][:2]
    return killed, out != '', fails


def main(ms):
    nk = 0
    for m in ms:
        killed, ran, fails = run(m)
        nk += killed
        print('%s %-9s %s' % (m, 'KILLED' if killed else ('SURVIVED' if ran else 'NO LOG'), fails))
    print('run_mutants: %d of %d mutants killed' % (nk, len(ms)))
    print('RESULT: %s' % ('PASS' if nk == len(ms) else 'FAIL'))


if __name__ == '__main__':
    main(sys.argv[1:] or sorted(MUT))
