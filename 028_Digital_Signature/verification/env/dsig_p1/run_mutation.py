"""Strength of the testbench: inject one bug at a time into a COPY of the RTL and run the testbench
(guide section 4 of the skill vlsit-rtl-generator). The delivered RTL is never changed.

Every mutation is a text replacement in m_vlsit_dsig_ctl.sv or m_vlsit_dsig_buf.sv chosen to break one
requirement of the specification (the requirement is named in the table). A mutation is CAUGHT when
the run shows a failed check or assertion that is not one of the OPEN-n checks (open decisions) or
the run does not finish; it SURVIVES when the run is as clean as the baseline run.

Usage: python run_mutation.py [--n N] [--jobs J] [--only M01,M02]
Works in $TEMP/vlsit_028_mutation and writes verification/docs/mutation_report.md. Needs iverilog and vvp. Not part of the RTL.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))          # verification/env/dsig_p1
VER = os.path.dirname(os.path.dirname(HERE))               # verification
IP = os.path.dirname(VER)
RTL = os.path.join(IP, 'rtl')
MODELS = os.path.join(VER, 'models', 'dsig_p1')
TESTS = os.path.join(VER, 'tests', 'dsig_p1')
# The copies of the RTL are working files outside the IP tree (the repository layout allows no deeper tree)
MUT = os.path.join(os.environ.get('TEMP', '.'), 'vlsit_028_mutation')
REPORT = os.path.join(VER, 'docs', 'mutation_report.md')

CTL = 'm_vlsit_dsig_ctl.sv'
BUF = 'm_vlsit_dsig_buf.sv'

# id, file, old text, new text, requirement that the mutation breaks
M = [
    ('M01', CTL, "w_alg_valid & ~(PARA_CAP_ALG[w_alg_idx5] & w_alg_act16[reg_run_alg])",
     "w_alg_valid & ~PARA_CAP_ALG[w_alg_idx5]", 'REQ-REG-001 effective enable bit ignored'),
    ('M02', CTL, "      4'b01??: w_chk_flag = LPARA_ERRF_OPUNS[11:0];\n      4'b001?: w_chk_flag = LPARA_ERRF_BADLEN[11:0];",
     "      4'b0?1?: w_chk_flag = LPARA_ERRF_BADLEN[11:0];\n      4'b01??: w_chk_flag = LPARA_ERRF_OPUNS[11:0];", 'DEC-038 priority of the checks'),
    ('M03', CTL, "if (w_is_ecdsa & (w_dig_len < w_min_len))", "if (w_is_ecdsa & (w_dig_len <= w_min_len))", 'DEC-032 curve and hash pairing'),
    ('M04', CTL, "({28'd0, reg_run_hsslvl} > LPARA_HSS_MAX)", "({28'd0, reg_run_hsslvl} >= LPARA_HSS_MAX)", 'ERR-003 HSS level count 1 to 8'),
    ('M05', CTL, "(w_msg_end > {2'b00, PARA_BUF_BYTES})", "(w_msg_end >= {2'b00, PARA_BUF_BYTES})", 'ERR-006 region fits the buffer'),
    ('M06', CTL, "((PARA_ECDSA_NONCE == LPARA_NONCE_CSR) & ~reg_run_nonce[0]))) |", "((PARA_ECDSA_NONCE == LPARA_NONCE_CSR)))) |", 'DEC-031 random nonce only when selected'),
    ('M07', CTL, "LPARA_ERRF_VASMIS[11:0]) != 12'd0)) ? LPARA_ALM_FAULT[2:0]", "LPARA_ERRF_VASMIS[11:0] & 12'd0) != 12'd0)) ? LPARA_ALM_FAULT[2:0]", 'ERR-010 mismatch sets the fault alarm'),
    ('M08', CTL, "(reg_fsm_ctl_current_state == ENUM_ST_CHECK) & w_chk_ok & (reg_cnt_ops != 32'hFFFFFFFF)",
     "(reg_fsm_ctl_current_state == ENUM_ST_CHECK) & (reg_cnt_ops != 32'hFFFFFFFF)", 'DEC-033 cnt_ops counts accepted starts'),
    ('M09', CTL, "        if (~reg_log_locked) begin\n          if ((reg_fsm_ctl_current_state == ENUM_ST_CHECK)", "        if (1'b1) begin\n          if ((reg_fsm_ctl_current_state == ENUM_ST_CHECK)", 'REQ-SEC-006 log lock freezes the counters'),
    ('M10', CTL, "(w_lock_viol ? LPARA_ALM_LOCKV[2:0] : 3'd0);", "3'd0;", 'ERR-011 lock violation sets the alarm'),
    ('M11', CTL, "LPARA_POL_ED:   w_sigok_nxt = w_ed_nxt;", "LPARA_POL_ED:   w_sigok_nxt = w_ml_nxt;", 'DEC-030 hybrid policy Ed25519 valid'),
    ('M12', CTL, "casez ({i_cmd_abort, i_eng_err, i_eng_done, w_vas_en})\n          4'b1???: w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;",
     "casez ({i_cmd_abort, i_eng_err, i_eng_done, w_vas_en})\n          4'b1???: w_fsm_ctl_nxt_state = ENUM_ST_IDLE;", 'REQ-SEC-005 abort clears the secrets'),
    ('M13', CTL, "      o_eng_start[0] = w_ec_group;\n      o_eng_start[1] = w_is_mldsa;", "      o_eng_start[0] = w_ec_group | w_is_mldsa;\n      o_eng_start[1] = 1'b0;", 'section 14.2 engine group of ML-DSA'),
    ('M14', CTL, "        if (i_zero_done)\n          w_fsm_ctl_nxt_state = ENUM_ST_IDLE;", "        w_fsm_ctl_nxt_state = ENUM_ST_IDLE;", 'REQ-SEC-005 CLEAR waits for the cleared level'),
    ('M15', CTL, "          4'b01??: w_fsm_ctl_nxt_state = ENUM_ST_ERR;\n          4'b0011: w_fsm_ctl_nxt_state = ENUM_ST_RNG;",
     "          4'b01??: w_fsm_ctl_nxt_state = ENUM_ST_RUN;\n          4'b0011: w_fsm_ctl_nxt_state = ENUM_ST_RNG;", 'ERR-009 key timeout ends the operation'),
    ('M16', CTL, "assign w_done_ev = (reg_fsm_ctl_current_state == ENUM_ST_RESULT) | (reg_fsm_ctl_current_state == ENUM_ST_ERR);",
     "assign w_done_ev = (reg_fsm_ctl_current_state == ENUM_ST_ERR);", 'ENUM_ST_RESULT raises the done event'),
    ('M17', CTL, "reg_sigok <= w_sigok_nxt;", "reg_sigok <= ~w_sigok_nxt;", 'OP-004 sigok is the verification result'),
    ('M18', CTL, "          2'b01:   w_fsm_ctl_nxt_state = ENUM_ST_CLEAR;", "          2'b01:   w_fsm_ctl_nxt_state = ENUM_ST_IDLE;", 'section 10.1 clear command enters ENUM_ST_CLEAR'),
    ('M19', CTL, "(w_state_bad ? LPARA_ALM_FAULT[2:0] : 3'd0) |", "3'd0 |", 'DEC-035 unused encoding sets the fault alarm'),
    ('M20', CTL, "LPARA_ERRF_ENTTMO[11:0]) != 12'd0)) ? LPARA_ALM_RNGFAIL", "LPARA_ERRF_ENTTMO[11:0] & 12'd0) != 12'd0)) ? LPARA_ALM_RNGFAIL", 'ERR-008 entropy timeout sets rngfail'),
    ('M21', CTL, "(w_is_mldsa & w_is_sign & reg_run_hedged) |", "(w_is_mldsa & w_is_sign) |", 'DEC-031 random only for hedged ML-DSA'),
    ('M22', CTL, "assign w_vas_en    = PARA_EN_VAS[0] & w_is_sign;", "assign w_vas_en    = 1'b0;", 'ENUM_ST_VAS after signing'),
    ('M23', CTL, "      if (i_lock_req & PARA_EN_LOCK[0])\n        reg_locked <= 1'b1;", "      if (i_lock_req & PARA_EN_LOCK[0] & 1'b0)\n        reg_locked <= 1'b1;", 'REQ-REG-002 lock request latches the lock'),
    ('M24', CTL, "assign w_inj_rise = i_irq_inj & ~reg_inj_prev;", "assign w_inj_rise = i_irq_inj;", 'section 6.4 injection acts on the rising edge'),
    ('M25', CTL, "assign o_irq_sts     = i_irq_raw & i_irq_en;", "assign o_irq_sts     = i_irq_raw;", 'section 6.4 the mask of the events'),
    ('M26', CTL, "assign o_alarm       = (i_alarm_flags != 3'd0);", "assign o_alarm       = (i_alarm_flags != 3'd0) & (i_irq_en != 3'd0);", 'section 6.4 the alarm is not maskable'),
    ('M27', CTL, "w_f_opuns = w_f_opuns | ~PARA_CAP_SIGN[w_alg_idx5];", "w_f_opuns = w_f_opuns | 1'b0;", 'ERR-002 signing not built'),
    ('M28', CTL, "if ((w_is_ecdsa | w_is_mldsa) & (reg_run_len_msg != w_dig_len))", "if ((w_is_ecdsa) & (reg_run_len_msg != w_dig_len))", 'ERR-003 prehash digest length of ML-DSA'),
    ('B01', BUF, "w_wr_strb = i_axi_wr_strb;", "w_wr_strb = '1;", 'REQ-IF-002 byte strobes'),
    ('B02', BUF, "LPARA_WIN_STEP = 4", "LPARA_WIN_STEP = 8", 'section 10.5 window address adds 4'),
    ('B03', BUF, "assign o_win_rd_data  = {LPARA_GRP_W{~i_busy}} & reg_win_rd_data;", "assign o_win_rd_data  = reg_win_rd_data;", 'section 10.5 window read data are 0 while busy'),
    ('B04', BUF, "assign w_sel_axi_wr = ~i_busy & i_axi_wr_en;", "assign w_sel_axi_wr = i_axi_wr_en;", 'REQ-IF-002 no bus write while busy'),
    ('B05', BUF, "    casez ({w_sel_eng_wr, w_sel_axi_wr, reg_win_wr_pend})", "    casez ({w_sel_eng_wr, w_sel_axi_wr, w_win_wr_ok})", 'DEC-039 window write one cycle after the event'),
    ('B06', BUF, "assign w_win_inr   = ({15'd0, i_win_addr} < PARA_BUF_BYTES);", "assign w_win_inr   = ({15'd0, i_win_addr} <= PARA_BUF_BYTES);", 'section 10.5 window range'),
    ('B07', BUF, "assign w_sel_eng_wr = i_busy & i_eng_wr_en;", "assign w_sel_eng_wr = 1'b0;", 'section 10.5 the engines write while busy'),
    ('B08', BUF, "reg_err_busy   <= w_win_wr_ev & i_busy;", "reg_err_busy   <= 1'b0;", 'ERR-012 window write while busy'),
    ('B09', BUF, "reg_err_ovf    <= (w_win_wr_ev | w_win_rd_ev) & ~w_win_inr & ~i_busy;", "reg_err_ovf    <= (w_win_wr_ev) & ~w_win_inr & ~i_busy;", 'ERR-006 window read outside the buffer'),
    ('B10', BUF, "assign o_win_addr_we    = reg_win_wr_pend | w_win_rd_ok;", "assign o_win_addr_we    = reg_win_wr_pend;", 'section 10.5 the address advances after a read'),
]


def make_copy(mid, fname, old, new, n):
    d = os.path.join(MUT, mid, 'rtl')
    os.makedirs(d, exist_ok=True)
    src = os.path.join(RTL, fname)
    text = open(src, encoding='utf-8').read()
    if text.count(old) != 1:
        return None, 'pattern found %d times' % text.count(old)
    open(os.path.join(d, fname), 'w', encoding='utf-8').write(text.replace(old, new))
    lines = []
    for ln in open(os.path.join(RTL, 'filelist.f'), encoding='utf-8'):
        s = ln.rstrip('\n')
        if not s.strip() or s.strip().startswith('//'):
            lines.append(s)
            continue
        if os.path.basename(s) == fname:
            lines.append(os.path.join(d, fname).replace('\\', '/'))
        else:
            lines.append(os.path.normpath(os.path.join(RTL, s)).replace('\\', '/'))
    open(os.path.join(d, 'filelist.f'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    out = os.path.join(MUT, mid, 'tb.vvp')
    cmd = ['iverilog', '-g2012', '-DVLSIT_SYNTHESIS', '-DCSR_ASYNC=1', '-s', 'tb_dsig_p1', '-I', HERE, '-I', MODELS, '-I', TESTS,
           '-o', out, '-f', os.path.join(d, 'filelist.f')]
    cmd += [os.path.join(HERE, f) for f in ('dsig_p1_wrap.sv', 'dsig_apb_assert.sv', 'dsig_p1_assert.sv', 'dsig_wf_probe.sv')]
    cmd += [os.path.join(TESTS, 'tb_dsig_p1.sv')]
    r = subprocess.run(cmd, cwd=d, capture_output=True, text=True)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if 'error' in l.lower()]
    if r.returncode != 0 or errs:
        return None, 'compile error: ' + (errs[0] if errs else '')
    return out, ''


def classify(log_text, finished):
    fails = [l for l in log_text.splitlines() if l.startswith('CHECK FAIL') and 'OPEN-' not in l]
    asserts = [l for l in log_text.splitlines() if l.startswith('ASSERT FAIL')]
    never = re.search(r'assertions never exercised: (\d+)', log_text)
    caught = bool(fails or asserts) or not finished
    first = ''
    if asserts:
        first = asserts[0][:140]
    elif fails:
        first = re.sub(r'^CHECK FAIL @\d+ ', '', fails[0])[:160]
    elif not finished:
        first = 'run did not finish'
    return caught, len(fails), len(asserts), first


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--n', type=int, default=80)
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--only', default='')
    a = ap.parse_args()
    sel = [x for x in a.only.split(',') if x]
    os.makedirs(MUT, exist_ok=True)
    todo = [m for m in M if not sel or m[0] in sel]
    jobs = []
    results = {}
    for mid, fname, old, new, why in todo:
        vvp, err = make_copy(mid, fname, old, new, a.n)
        if vvp is None:
            results[mid] = ('ERROR', 0, 0, err, why)
            print(mid, 'ERROR', err)
        else:
            jobs.append((mid, vvp, why))
    running = []
    t0 = time.time()
    while jobs or running:
        while jobs and len(running) < a.jobs:
            mid, vvp, why = jobs.pop(0)
            logp = os.path.join(MUT, mid, 'run.log')
            lf = open(logp, 'w', encoding='utf-8')
            p = subprocess.Popen(['vvp', vvp, '+SEED=1', '+N=%d' % a.n], cwd=os.path.join(MUT, mid, 'rtl'), stdout=lf,
                                 stderr=subprocess.STDOUT)
            running.append((mid, p, lf, logp, why, time.time()))
        time.sleep(1)
        for it in list(running):
            mid, p, lf, logp, why, ts = it
            fin = p.poll() is not None
            if not fin and time.time() - ts > 420:
                p.kill()
                fin = True
                timed = True
            else:
                timed = False
            if fin:
                lf.close()
                running.remove(it)
                text = open(logp, encoding='utf-8', errors='replace').read()
                finished = ('RESULT:' in text) and not timed
                caught, nf, na, first = classify(text, finished)
                results[mid] = ('CAUGHT' if caught else 'SURVIVED', nf, na, first, why)
                print('%s %s (%d failed checks, %d assertion failures) %s' % (mid, results[mid][0], nf, na, first[:100]))
    print('time %d s' % (time.time() - t0))
    ids = [m[0] for m in todo]
    caught = sum(1 for i in ids if results.get(i, ('',))[0] == 'CAUGHT')
    with open(REPORT, 'w', encoding='utf-8') as f:
        f.write('# Mutation run of the phase 1 testbench\n\n')
        f.write('Bugs injected into copies of the RTL (the delivered RTL is unchanged). CAUGHT = a failed check or assertion other than an\n')
        f.write('OPEN-n check (decision of the designer pending) or a run that did not finish.\n\n')
        f.write('Caught %d of %d.\n\n' % (caught, len(ids)))
        f.write('| ID | Requirement broken | Result | Failed checks | Assertion failures | First failure |\n|---|---|---|---:|---:|---|\n')
        for i in ids:
            r = results.get(i)
            if r:
                f.write('| %s | %s | %s | %d | %d | %s |\n' % (i, r[4], r[0], r[1], r[2], r[3].replace('|', '/')))
    print('caught %d of %d' % (caught, len(ids)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
