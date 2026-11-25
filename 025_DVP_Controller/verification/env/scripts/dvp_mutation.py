#!/usr/bin/env python3
"""dvp_mutation.py - mutation analysis of the DVP RTL against the regression and the formal obligations (AI-generated candidate, R-117).

Every mutant is applied to a temporary copy of the RTL (the repository RTL is never changed): one exact-string edit per mutant (the edit must
match exactly once), then the base-configuration regression tests (seed 1, first failing test stops the run) and the formal harnesses that
cover the mutated module. A mutant is KILLED when a test case fails or a formal task fails, SURVIVED otherwise. M00 is the unmutated control and
must survive the whole pipeline. Flat results go to the output directory (default verification/sim/final): mutation_summary.json/csv, one log per mutant.
Usage: python dvp_mutation.py [--out DIR] [--only M01 M02 ...]
"""
import argparse, csv, json, os, re, shutil, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dvp_regress as R
import dvp_formal as F

IPN = '025_DVP_Controller'
CAP, GATE, BUF, APB, DMA, SVC, DEC = ('m_dvp_capture.sv', 'm_dvp_gate_bridge.sv', 'm_dvp_buffer.sv', 'm_dvp_apb_data.sv', 'm_dvp_dma_req.sv',
                                      'm_dvp_apb_service.sv', 'm_dvp_apb_decode.sv')
CSRF = 'csr/m_vlsit_csr_dvp.sv'
CSR_NEW = """  assign w_dvp_ctrl_fifo_flush_nxt = (i_hw_we_dvp_ctrl_fifo_flush) ? i_hw_wdata_dvp_ctrl_fifo_flush
                          : ((w_we_dvp_ctrl & (|w_wmask[2])) ? ((reg_wdata[2] & w_wmask[2]) | (reg_dvp_ctrl_fifo_flush & ~w_wmask[2])) : reg_dvp_ctrl_fifo_flush);"""
CSR_OLD = """  assign w_dvp_ctrl_fifo_flush_nxt = (w_we_dvp_ctrl & (|w_wmask[2])) ? ((reg_wdata[2] & w_wmask[2])
                            | ((i_hw_we_dvp_ctrl_fifo_flush ? i_hw_wdata_dvp_ctrl_fifo_flush : reg_dvp_ctrl_fifo_flush) & ~w_wmask[2]))
                          : (i_hw_we_dvp_ctrl_fifo_flush ? i_hw_wdata_dvp_ctrl_fifo_flush : reg_dvp_ctrl_fifo_flush);"""
# id, class, description, [(file, old, new)], formal harness names that cover the module
MUTANTS = [
    ('M00', 'control', 'unmutated copy (pipeline control)', [], []),
    ('M01', 'wrong sample edge', 'sample and toggle capture swap rising/falling edge', [(CAP, "if (PARA_SAMPLE_EDGE == 32'd0) begin : gen_rise_sample", "if (PARA_SAMPLE_EDGE == 32'd1) begin : gen_rise_sample"),
                                                                                         (CAP, "if (PARA_SAMPLE_EDGE == 32'd0) begin : gen_rise_toggle", "if (PARA_SAMPLE_EDGE == 32'd1) begin : gen_rise_toggle")], []),
    ('M02', 'toggle polarity', 'gated pixel event detects only one toggle direction', [(GATE, "assign w_pixel_event = reg_toggle_sync ^ reg_toggle_seen;", "assign w_pixel_event = reg_toggle_sync & ~reg_toggle_seen;")], []),
    ('M03', 'overwrite on full', 'SFIFO accepts a write while full', [(BUF, "assign w_sf_wr_acc = w_sfifo_wr_en & ~w_sfifo_full;", "assign w_sf_wr_acc = w_sfifo_wr_en;")], []),
    ('M04', 'double/early pop', 'an APB write to FIFO_DATA pops', [(APB, "~reg_access_done & ~i_pwrite &", "~reg_access_done &")], ['f_apb_data']),
    ('M05', 'double/early pop', 'pop even when the FIFO is empty', [(APB, "assign o_fifo_rd_en = w_success_now;", "assign o_fifo_rd_en = w_access_active & ~reg_access_done & ~i_pwrite & i_fifo_aligned;")], ['f_apb_data']),
    ('M06', 'timeout off-by-one', 'terminal cycle one later than specified', [(APB, "(reg_timeout_count >= (i_timeout_cycles - 32'd1))", "(reg_timeout_count >= i_timeout_cycles)")], ['f_apb_data']),
    ('M07', 'data priority reversal', 'timeout error even when data is present at the terminal cycle', [(APB, "(i_fifo_empty & w_timeout_hit)", "w_timeout_hit")], ['f_apb_data']),
    ('M08', 'error response', 'empty-read timeout completes without PSLVERR', [(APB, "assign o_pslverr = w_err_now;", "assign o_pslverr = 1'b0;")], ['f_apb_data']),
    ('M09', 'sample format', 'sign extension instead of zero extension', [(APB, "{(LPARA_BUS_W-PARA_DATA_W){1'b0}}", "{(LPARA_BUS_W-PARA_DATA_W){i_fifo_data[PARA_DATA_W-1]}}")], ['f_apb_data']),
    ('M10', 'premature flush', 'flush starts without waiting for capture off and a quiescent source', [(BUF, "assign w_flush_safe = ~i_capture_en &", "assign w_flush_safe = 1'b1 | ~i_capture_en &")], ['f_flush']),
    ('M11', 'unsafe mode change', 'mode write accepted while capture is enabled', [(SVC, "(o_capture_en | i_pwdata[0] | ~w_mode_change_safe |", "(i_pwdata[0] | ~w_mode_change_safe |")], ['f_ctrl']),
    ('M12', 'DMA re-arm', 'request re-arms immediately after ACK', [(DMA, "(i_occupancy < i_watermark))", "1'b1)")], ['f_dma_req']),
    ('M13', 'DMA hold', 'request drops without ACK', [(DMA, "if (i_dma_ack)", "if (1'b1)")], ['f_dma_req']),
    ('M14', 'DMA zero watermark', 'zero watermark starts requests', [(DMA, "if ((i_watermark != 32'd0) && (i_watermark <= PARA_FIFO_DEPTH) &&", "if ((i_watermark <= PARA_FIFO_DEPTH) &&")], ['f_dma_req']),
    ('M15', 'frame counter', 'gated VSYNC counted while capture is disabled', [(GATE, "& i_capture_en & i_pclk_mode;", "& i_pclk_mode;")], []),
    ('M16', 'frame state', 'gated frame state not cleared when capture is disabled', [(GATE, "else if (!i_capture_en)", "else if (1'b0)")], []),
    ('M17', 'HREF polarity', 'HREF qualifier polarity inverted', [(CAP, "assign w_href_active = (PARA_HREF_ACTIVE == 32'd1) ? i_dvp_href : ~i_dvp_href;", "assign w_href_active = (PARA_HREF_ACTIVE == 32'd1) ? ~i_dvp_href : i_dvp_href;")], []),
    ('M18', 'VSYNC polarity', 'VSYNC polarity inverted in the capture path', [(CAP, "assign w_vsync_active = (PARA_VSYNC_ACTIVE == 32'd1) ? i_dvp_vsync : ~i_dvp_vsync;", "assign w_vsync_active = (PARA_VSYNC_ACTIVE == 32'd1) ? ~i_dvp_vsync : i_dvp_vsync;")], []),
    ('M19', 'decode', 'misaligned FIFO_DATA address accepted as aligned', [(DEC, "assign o_fifo_aligned = (i_paddr == PARA_FIFO_DATA_ADDR[15:0]);", "assign o_fifo_aligned = (i_paddr[15:2] == PARA_FIFO_DATA_ADDR[15:2]);")], []),
    ('M20', 'flush done not repeated', 'WAIT_SW_CLEAR does not re-issue done while the request stays set (hardware-first CSR kept)', [(BUF, "        else\n          w_fsm_flush_nxt_state = ENUM_ST_CLEAR_REQ;\n", "")], ['f_flush']),
    ('M21', 'rwi software first', 'flush request bit: a software write wins over the hardware clear (generator 3.6 behavior, repeated done kept)', [(CSRF, CSR_NEW, CSR_OLD)], ['f_csr']),
    ('M22', 'flush stuck (original defect)', 'both M20 and M21: a CTRL write on the done cycle keeps the request set forever', [(BUF, "        else\n          w_fsm_flush_nxt_state = ENUM_ST_CLEAR_REQ;\n", ""), (CSRF, CSR_NEW, CSR_OLD)], []),
    ('M23', 'DMA threshold off by one', 'request only when occupancy is above the watermark', [(DMA, "(i_occupancy >= i_watermark))", "(i_occupancy > i_watermark))")], ['f_dma_req']),
    ('M24', 'DMA drain hysteresis', 'the request re-arms when occupancy equals the watermark', [(DMA, "(i_occupancy < i_watermark))", "(i_occupancy <= i_watermark))")], ['f_dma_req']),
    ('M25', 'overflow flag lost (continuous)', 'AFIFO overflow does not set the sticky status bit', [(BUF, "assign o_overflow_event = w_afifo_ovf_apb | w_sfifo_overflow;", "assign o_overflow_event = w_sfifo_overflow;")], []),
    ('M26', 'overflow flag lost (gated)', 'SFIFO overflow does not set the sticky status bit', [(BUF, "assign o_overflow_event = w_afifo_ovf_apb | w_sfifo_overflow;", "assign o_overflow_event = w_afifo_ovf_apb;")], []),
    ('M27', 'frame count step', 'the frame counter adds two per accepted frame start', [(SVC, "reg_frame_count <= reg_frame_count + 32'd1;", "reg_frame_count <= reg_frame_count + 32'd2;")], []),
    ('M28', 'W1C race: software clear wins', 'an overflow event in the cycle of a software clear is lost', [(CSRF, "assign w_dvp_fifo_sts_ovf_nxt = (i_hw_we_dvp_fifo_sts_ovf) ? i_hw_wdata_dvp_fifo_sts_ovf", "assign w_dvp_fifo_sts_ovf_nxt = (i_hw_we_dvp_fifo_sts_ovf & ~(w_we_dvp_fifo_sts & (|w_wmask[3]))) ? i_hw_wdata_dvp_fifo_sts_ovf")], ['f_csr']),
    ('M29', 'gated sample without frame', 'gated pixel events are written without an armed frame', [(GATE, "& i_pclk_mode & reg_frame_active;", "& i_pclk_mode;")], []),
    ('M30', 'continuous sample without frame', 'continuous samples are accepted without an armed frame', [(CAP, "reg_frame_active & w_href_active;", "w_href_active;")], []),
    ('M31', 'mode change ignores queued data', 'the mode-change-safe indication ignores non-empty FIFOs', [(BUF, "assign o_mode_change_safe = ~o_flush_busy & w_both_empty &", "assign o_mode_change_safe = ~o_flush_busy &")], []),
    ('M32', 'timeout counter keeps counting', 'the empty-read counter is not cleared when data appears', [(APB, "| i_pwrite | ~i_fifo_aligned | ~i_fifo_empty)", "| i_pwrite | ~i_fifo_aligned)")], ['f_apb_data']),
    ('M33', 'level off by one', 'the continuous-mode occupancy is reported one too high', [(BUF, "{1'b0}}, w_afifo_occupancy};", "{1'b0}}, w_afifo_occupancy + 1'b1};")], []),
    ('M34', 'gated VSYNC polarity', 'VSYNC polarity inverted in the gated bridge', [(GATE, "? reg_vsync_sync : ~reg_vsync_sync;", "? ~reg_vsync_sync : reg_vsync_sync;")], []),
    ('M35', 'CSR reset value: timeout', 'the empty-read timeout resets to 0 instead of the longest value', [(CSRF, "reg_dvp_timeout_cycles <= 32'hffffffff;", "reg_dvp_timeout_cycles <= 32'h0;")], []),
    ('M36', 'CSR reset value: watermark', 'the watermark resets to a nonzero value', [(CSRF, "reg_dvp_wmark_level <= 32'h0;", "reg_dvp_wmark_level <= 32'h2;")], []),
    ('M37', 'CSR reset value: sticky overflow', 'the sticky overflow flag resets to 1', [(CSRF, "reg_dvp_fifo_sts_ovf <= 1'h0;", "reg_dvp_fifo_sts_ovf <= 1'h1;")], []),
    ('M38', 'CSR reset value: capture enable', 'capture is enabled out of reset', [(CSRF, "reg_dvp_ctrl_capture_en <= 1'h0;", "reg_dvp_ctrl_capture_en <= 1'h1;")], []),
    ('MP1', 'VSYNC polarity ignored (continuous)', 'build e1v0h0: the continuous path treats VSYNC as active high whatever the parameter', [(CAP, "assign w_vsync_active = (PARA_VSYNC_ACTIVE == 32'd1) ? i_dvp_vsync : ~i_dvp_vsync;", "assign w_vsync_active = i_dvp_vsync;")], [], 'e1v0h0'),
    ('MP2', 'HREF polarity ignored', 'build e1v0h0: HREF is treated as active high whatever the parameter', [(CAP, "assign w_href_active = (PARA_HREF_ACTIVE == 32'd1) ? i_dvp_href : ~i_dvp_href;", "assign w_href_active = i_dvp_href;")], [], 'e1v0h0'),
    ('MP3', 'sample edge ignored (continuous)', 'build e1v0h0: the continuous path always samples on the rising edge', [(CAP, "if (PARA_SAMPLE_EDGE == 32'd0) begin : gen_rise_sample", "if (1'b1) begin : gen_rise_sample")], [], 'e1v0h0'),
    ('MP4', 'VSYNC polarity ignored (gated)', 'build e1v0h0: the gated bridge treats VSYNC as active high whatever the parameter', [(GATE, "assign w_vsync_active = (PARA_VSYNC_ACTIVE == 32'd1) ? reg_vsync_sync : ~reg_vsync_sync;", "assign w_vsync_active = reg_vsync_sync;")], [], 'e1v0h0'),
    ('MP5', 'data width truncated', 'build w10e1v0: the continuous path drops data bits above bit 7', [(CAP, "assign o_afifo_wr_data = reg_afifo_wr_data;", "assign o_afifo_wr_data = {{(PARA_DATA_W-8){1'b0}}, reg_afifo_wr_data[7:0]};")], [], 'w10e1v0'),
    ('MP6', 'sample edge ignored (gated)', 'build e1v0h0: the gated path always captures on the rising edge', [(CAP, "if (PARA_SAMPLE_EDGE == 32'd0) begin : gen_rise_toggle", "if (1'b1) begin : gen_rise_toggle")], [], 'e1v0h0'),
]
# base-configuration tests, seed 1; order puts the cheapest discriminating tests first
TESTS = [('t_dvp_endpoint_errors', []), ('t_dvp_apb_protocol', []), ('t_dvp_timeout_boundary', []), ('t_dvp_overflow', []), ('t_dvp_dma_rearm', []),
         ('t_dvp_mode_guard', []), ('t_dvp_flush_handshake', []), ('t_dvp_flush_race', []), ('t_dvp_frame_counter', []), ('t_dvp_continuous_e2e', []), ('t_dvp_gated_e2e', []),
         ('t_dvp_reset_recovery', []), ('t_dvp_profiles', []), ('t_dvp_performance_characterization', ['+MODE=0']), ('t_dvp_performance_characterization', ['+MODE=1'])]
BASE_DEFINES = ['P_W=8', 'P_EDGE=0', 'P_VS=1', 'P_HR=1', 'P_DEPTH=8']
FORMAL_ALL = dict(F.JOBS)


def copy_tree(dst):
    ip = R.IP
    root = os.path.dirname(ip)
    for rel in ('000_Common/rtl_lib', '000_Common/rtl_cells', '001_AsyncGrayFIFO/rtl', '002_SyncFIFO/rtl', IPN + '/rtl', IPN + '/verification/env/formal'):
        shutil.copytree(os.path.join(root, rel), os.path.join(dst, rel))


def apply(dst, edits):
    for fn, old, new in edits:
        p = os.path.join(dst, IPN, 'rtl', fn)
        s = open(p, encoding='utf-8').read()
        if s.count(old) != 1:
            raise SystemExit('mutation text must match exactly once in %s: %r (found %d)' % (fn, old, s.count(old)))
        open(p, 'w', encoding='utf-8').write(s.replace(old, new))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default=os.path.join(R.VER, 'sim', 'final'))
    ap.add_argument('--only', nargs='*', default=[])
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    budget = json.load(open(os.path.join(R.ENVD, 'config', 'resource_budget.json'), encoding='utf-8'))
    results = []
    for mid, cls, desc, edits, fnames, *cfg_opt in MUTANTS:
        if a.only and mid not in a.only:
            continue
        defines = R.CONFIGS[cfg_opt[0]][0] if cfg_opt else BASE_DEFINES
        R.preflight(budget, a.out)
        tmp = tempfile.mkdtemp(prefix='dvp_mut_')
        log = open(os.path.join(a.out, 'mutation_%s.log' % mid), 'w', encoding='utf-8')
        rec = {'id': mid, 'class': cls, 'description': desc, 'killed_by': [], 'status': 'SURVIVED'}
        try:
            copy_tree(tmp)
            apply(tmp, edits)
            R.RTL = os.path.join(tmp, IPN, 'rtl')
            log.write('%s %s: %s\n' % (mid, cls, desc))
            for fn, old, new in edits:
                log.write('  %s: %r -> %r\n' % (fn, old, new))
            mdir = os.path.join(tmp, 'build')
            rc, _ = R.run(R.vl_common('tb_dvp_controller', mdir) + ['-G' + d for d in defines] + ['-f', 'filelist.f'] + R.SRC_ENV,
                          R.RTL, os.path.join(tmp, 'compile.log'), 900, 'mutant build ' + mid)
            if rc != 0:
                rec['status'] = 'BUILD_FAIL'
                log.write('build failed (the mutant is not a valid design); first error: %s\n' % next((l for l in open(os.path.join(tmp, 'compile.log'), errors='replace') if 'rror' in l), ''))
            else:
                exe = os.path.join(mdir, 'Vtb_dvp_controller.exe')
                cwd = os.path.join(tmp, 'cwd'); os.makedirs(cwd)
                for t, extra in TESTS:
                    plus = ['+AFIFO_MSYNC_SEED=1', '+AFIFO_MSYNC_EN=1', '+RSTSYNC_MSYNC_SEED=1', '+RSTSYNC_MSYNC_EN=1'] + extra
                    lp = os.path.join(tmp, 'case.log')
                    R.run([exe, '+TEST=' + t, '+SEED=1', '+TIMEOUT_NS=2000000'] + plus, cwd, lp, 300, 'mutant %s %s' % (mid, t))
                    r = R.parse_log(lp)
                    log.write('  sim %-40s %s errors=%d\n' % (t + (extra[0] if extra else ''), r['result'], r['errors']))
                    if r['result'] != 'PASS':
                        rec['killed_by'].append('sim:' + t + (extra[0] if extra else ''))
                        first = next((l.strip() for l in open(lp, errors='replace') if l.startswith('DV_ERROR') or 'DV_TEST' in l), '')
                        log.write('    first message: %s\n' % first[:200])
                        break
                if fnames:
                    jobs = [(n, [t for t in FORMAL_ALL[n] if t != 'cover']) for n in fnames]
                    rows = F.run_all(os.path.join(tmp, IPN, 'verification', 'env', 'formal'), tmp, 'mut_', jobs)
                    for row in rows:
                        log.write('  formal %-12s %-6s %s\n' % (row['harness'], row['task'], row['result']))
                        if row['result'] != 'PASS':
                            rec['killed_by'].append('formal:%s/%s' % (row['harness'], row['task']))
                rec['status'] = 'KILLED' if rec['killed_by'] else 'SURVIVED'
        finally:
            log.write('RESULT %s %s\n' % (rec['status'], rec['killed_by']))
            log.close()
            shutil.rmtree(tmp, ignore_errors=True)
        results.append(rec)
        print('%s %-22s %-9s %s' % (mid, cls, rec['status'], ', '.join(rec['killed_by'])), flush=True)
    real = [r for r in results if r['id'] != 'M00']
    killed = [r for r in real if r['status'] == 'KILLED']
    json.dump({'results': results, 'mutants': len(real), 'killed': len(killed), 'survived': [r['id'] for r in real if r['status'] == 'SURVIVED'],
               'build_fail': [r['id'] for r in real if r['status'] == 'BUILD_FAIL'], 'control': next((r['status'] for r in results if r['id'] == 'M00'), 'not run')},
              open(os.path.join(a.out, 'mutation_summary.json'), 'w', encoding='utf-8'), indent=1)
    with open(os.path.join(a.out, 'mutation_summary.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(['id', 'class', 'status', 'killed_by', 'description'])
        for r in results:
            w.writerow([r['id'], r['class'], r['status'], ';'.join(r['killed_by']), r['description']])
    print('MUTATION', len(real), 'mutants', 'killed', len(killed), 'survived', [r['id'] for r in real if r['status'] == 'SURVIVED'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
