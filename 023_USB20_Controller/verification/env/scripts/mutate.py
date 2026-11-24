"""Bug-library mutation check (R-241): each mutant re-injects one fixed bug (or a small neighbouring fault) into a copy of one RTL
file, builds the target configuration with the mutated file and runs the test that is supposed to catch it. A failing run means
the mutant is killed; a passing run means the mutant survived (the test cannot see the fault) and is reported as such.
Mutated files live in sim/mutants/<id>/; builds are named mut_<id> and their binaries are removed after the run (the build record
and the run folder stay). Run from the sim folder:   python scripts/mutate.py [id ...]   Results: coverage/mutation_report.md."""
import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402
SIM = P.V
IP = P.IP
RTL = P.RTL

# id, bug, file, [(old, new)], target build, generator (name + args as in testlist), test name, note
MUTANTS = [
    ('M01', 'BUG-001', 'm_usb2_crc5.sv', [('o_crc = ~{w_rem[0], w_rem[1], w_rem[2], w_rem[3], w_rem[4]};', 'o_crc = ~w_rem;')],
     'dev_utmi8_axim', ['gen_dev_enum_bulk_dma.py'], 't_dev_enum_bulk_dma', 'CRC5 bit order of the token fields'),
    ('M02', 'BUG-031', 'm_usb2_fifo.sv', [('assign w_bus_wr_req  = w_bus_wr_op & ~w_bus_q_full;', 'assign w_bus_wr_req  = w_bus_wr_op;')],
     'dev_utmi8_axis', ['gen_dev_axis_win.py'], 't_dev_axis_win', 'bus row write into a full transmit queue is not held back'),
    ('M03', 'BUG-030', 'm_usb2_axs.sv', [('reg_req_msk <= i_dma_ack;', 'reg_req_msk <= (reg_req_msk | i_dma_ack) & w_req_cond;'),
                                          ('assign o_dma_req = w_req_cond & ~w_busy & ~reg_req_msk;', 'assign o_dma_req = w_req_cond & ~reg_req_msk;')],
     'dev_utmi8_axis', ['gen_dev_axis_win.py'], 't_dev_axis_win', 'request stays low after an acknowledge until the condition falls'),
    ('M04', 'BUG-032', 'm_usb2_axs.sv', [('assign o_err_evt = reg_err_evt;', "assign o_err_evt = 1'b0;")],
     'dev_utmi8_axis', ['gen_fi_axis_err.py'], 't_fi_axis_err', 'axi_err never set in the AXI-slave builds'),
    ('M05', 'BUG-029', 'm_usb2_spd.sv', [("if (i_ctrl[7]) begin\n      w_xcvr_sel = 2'b01;", "if (1'b0) begin\n      w_xcvr_sel = 2'b01;")],
     'host_utmi8_axim_ts16', ['gen_dir_loopback.py', 'ts16'], 't_dir_loopback', 'loopback mode pins not forced'),
    ('M06', 'BUG-004', 'm_usb2_spd.sv', [("ENUM_ST_DV_CHK: begin\n          w_xcvr_sel = 2'b00;\n          w_term_sel = 1'b1;", "ENUM_ST_DV_CHK: begin\n          w_xcvr_sel = 2'b00;\n          w_term_sel = 1'b0;"),
      ("ENUM_ST_DV_CHJ: begin\n          w_xcvr_sel = 2'b00;\n          w_term_sel = 1'b1;", "ENUM_ST_DV_CHJ: begin\n          w_xcvr_sel = 2'b00;\n          w_term_sel = 1'b0;")],
     'dev_utmi8_axim', ['gen_dev_enum_bulk_dma.py'], 't_dev_enum_bulk_dma', 'TermSelect low during the device chirp'),
    ('M07', 'BUG-024', 'm_usb2_spd.sv', [('assign o_drv_vbus     = reg_role_host & i_hport[3] & i_pwr_en;', 'assign o_drv_vbus     = reg_role_host & i_hport[3];')],
     'host_utmi8_axim_ts16', ['gen_fi_ocp.py'], 't_fi_ocp', 'DrvVbus does not follow the over-current power-off'),
    ('M08', 'BUG-027', 'm_usb2_phyif_ulpi.sv', [('assign w_tx_go    = i_tx_valid[0] & ~i_ulpi_dir & ~reg_dir_d & ~w_mode_pend;', 'assign w_tx_go    = i_tx_valid[0] & ~i_ulpi_dir & ~reg_dir_d;')],
     'dev_ulpi_axim', ['gen_dev_enum_bulk_dma.py', 'ulpi'], 't_dev_ulpi_traffic', 'a ULPI transmit starts before the mode register write'),
    ('M09', 'BUG-028', 'm_usb2_phyif_ulpi.sv', [("            w_abort    = 1'b1;\n            w_data_nxt = 8'h00;\n", "            w_abort    = 1'b1;\n", 2)],
     'dev_ulpi_axim', ['gen_fi_ulpi_abort.py'], 't_fi_ulpi_abort', 'abandoned TX CMD stays on the data bus after a DIR abort (hardening only)'),
    ('M10', 'BUG-006', 'm_usb2_dev.sv', [("(PARA_USB2_UTMI_W == 32'd16) ? 32'd48 : 32'd97", "(PARA_USB2_UTMI_W == 32'd16) ? 32'd48 : 32'd60")],
     'dev_utmi8_axim', ['gen_fi_bus_errors.py'], 't_fi_bus_errors', 'ACK time-out of the device shorter than the allowed response time'),
    ('M11', 'BUG-033', 'm_usb2_axs.sv', [("(reg_rs_out < LPARA_RS_DEPTH[3:0])", "1'b1")],
     'dev_utmi8_axis', ['gen_dev_axis_win.py'], 't_dev_axis_win', 'no limit on the outstanding read requests of a window read (seed 3)'),
    ('M12', 'BUG-034', 'm_usb2_spd.sv', [("assign w_mode_rdy  = reg_mode_rdy;", "assign w_mode_rdy  = 1'b1;")],
     'dev_utmi8_axim', ['gen_dev_enum_bulk_dma.py'], 't_dev_enum_bulk_dma', 'chirp stream starts in the same cycle as the mode pins change'),
    ('M13', 'BUG-035', 'm_usb2_spd.sv', [("if (w_ls_se0 & w_se0_det & ~reg_rev_wait)", "if (w_ls_se0 & w_se0_det)")],
     'dev_utmi8_axim_ts1', ['gen_dev_fs.py', 'ts1'], 't_dev_fs_fallback', 'device chirps again during the same reset after the revert to full-speed'),
    ('M14', 'BUG-036', 'm_usb2_spd.sv', [("(i_hport[21] | (reg_speed == 2'd2)) ? ENUM_ST_HP_RSTW", "i_hport[21] ? ENUM_ST_HP_RSTW")],
     'host_utmi8_axim_ts16', ['gen_host_conn.py', 'ls', 'ts16'], 't_host_conn', 'a low-speed device is taken for a high-speed chirp candidate'),
    ('M15', 'BUG-039', 'm_usb2_host.sv', [("assign w_wait_end = (reg_tmo == '0) & ~reg_rx_go & ~i_dat_sop;", "assign w_wait_end = (reg_tmo == '0);"),
      ("if ((reg_tmo != '0) & ~reg_rx_go & ~i_dat_sop)", "if (reg_tmo != '0)")],
     'host_utmi8_axim_ts16', ['gen_host_bigpkt.py', 'ts16'], 't_host_bigpkt', 'the response time-out cuts a long packet'),
    ('M16', 'BUG-038', 'm_usb2_host.sv', [("if (w_data_ok & ~reg_iso & ~w_bab) begin", "if (w_data_ok & ~reg_iso) begin")],
     'host_utmi8_axim_ts16', ['gen_host_babble.py', 'ts16'], 't_host_babble', 'a babble packet is acknowledged'),
    ('M17', 'BUG-040', 'm_usb2_dev.sv', [("assign o_rxw_ok  = i_dat_ok & w_pid_ok & ~w_o_bab;", "assign o_rxw_ok  = i_dat_ok & w_pid_ok;"),
      ("i_dat_ok & w_pid_ok & ~w_o_bab;", "i_dat_ok & w_pid_ok;"), ("casez ({(~i_dat_ok | w_o_bab),", "casez ({(~i_dat_ok),")],
     'dev_utmi8_axim', ['gen_dev_edge.py', 'len'], 't_dev_edge', 'an OUT packet longer than the maximum packet size is acknowledged and stored'),
    ('M18', 'BUG-041', 'm_usb2_host.sv', [("& reg_iso & ~reg_bab;", "& reg_iso & ~reg_bab & 1'b0;"),
      ("(((reg_err[idx] == 2'd2) & ~reg_iso) | reg_bab)", "((reg_err[idx] == 2'd2) | reg_bab)")],
     'host_utmi8_axim_ts16', ['gen_host_edge.py', 'iso', 'ts16'], 't_host_edge', 'an isochronous transaction with an error is retried'),
    ('M19', 'BUG-042', 'm_usb2_host.sv', [("if (reg_cscnt[gen_ch] == 2'd2) begin", "if (1'b0) begin")],
     'host_utmi8_axim_ts16', ['gen_host_edge.py', 'psplit', 'ts16'], 't_host_edge', 'no limit on the complete-splits of a periodic split transaction'),
    ('M20', 'BUG-043', 'm_usb2_host.sv', [("LPARA_B2B_W8    = 7,", "LPARA_B2B_W8    = 0,")],
     'host_utmi8_axim_ts16', ['gen_host_edge.py', 'gaps', 'ts16'], 't_host_edge', 'the host sends its data packet 5 cycles after the token (no 88 bit time gap)'),
    ('M21', 'REV-F-021', 'm_usb2_axs.sv', [("({28'd0, w_w_ch} < PARA_USB2_NUM_DMA_CH)", "(w_w_ch < PARA_USB2_NUM_DMA_CH[3:0])"),
      ("({28'd0, w_r_ch} < PARA_USB2_NUM_DMA_CH)", "(w_r_ch < PARA_USB2_NUM_DMA_CH[3:0])")],
     'dev_utmi8_axis_ch16', ['gen_dir_last_index.py', 'win=16'], 't_dir_param_max', 'window channel compare through PARA[3:0]: a 16-channel build refuses every window'),
    ('M22', 'REV-NEP1', 'm_usb2_regs.sv', [("({28'd0, w_reg_wr_addr[5:2]} < PARA_USB2_NEP1)", "(w_reg_wr_addr[5:2] < PARA_USB2_NEP1[3:0])", 7)],
     'dev_utmi8_axim_epmax', ['gen_dir_last_index.py', 'ep=15'], 't_dir_param_max', 'endpoint bank decode through PARA[3:0]: with 16 endpoints no bank write reaches CLK-PHY'),
    ('M23', 'REV-NHC', 'm_usb2_regs.sv', [("({28'd0, w_reg_wr_addr[5:2]} < PARA_USB2_NHC)", "(w_reg_wr_addr[5:2] < PARA_USB2_NHC[3:0])", 5)],
     'host_utmi8_axim_hcmax_ts16', ['gen_dir_last_index.py', 'hc=16', 'ts16'], 't_dir_param_max', 'channel bank decode through PARA[3:0]: with 16 channels no bank write reaches CLK-PHY'),
    ('M24', 'BUG-044', 'm_usb2_xreg.sv', [("& ~w_pub_dirty & ~w_evt_hold)", "& ~w_pub_dirty)")],
     'dev_utmi8_axim', ['gen_dev_xreg_race.py'], 't_dev_xreg_race', 'events and clears overtake the published word changed by the same step'),
    ('M25', 'BUG-049', 'm_usb2_xreg.sv', [("  assign w_sel_set_ok = w_sel_set & ~w_clr_pend;", "  assign w_sel_set_ok = w_sel_set;"),
      ("    casez ({w_sel_dirty, w_sel_clr, w_sel_set_ok})", "    casez ({w_sel_dirty, w_sel_set_ok & ~w_sel_clr, w_sel_clr & ~w_sel_set_ok})")],
     'host_utmi8_axim_ts16', ['gen_host_xreg_race.py', 'ts16'], 't_host_xreg_race', 'a done event overtakes the clear of the command bit: re-arm right after done is lost'),
    ('M26', 'BUG-047', 'm_usb2_spd.sv', [("          ENUM_ST_HP_LISTK: reg_htmr <= LPARA_T_CHWAIT[LPARA_TMR_W-1:0];", "          ENUM_ST_HP_LISTK: reg_atmr <= LPARA_T_CHWAIT[LPARA_TMR_W-1:0];"),
      ("          else if (reg_htmr == '0)" + chr(10) + "            w_fsm_hp_nxt_state = ENUM_ST_HP_RSTW;", "          else if (reg_atmr == '0)" + chr(10) + "            w_fsm_hp_nxt_state = ENUM_ST_HP_RSTW;")],
     'host_utmi8_axim_ts16', ['gen_host_enum_bulk_dma.py', 'ts16'], 't_host_enum_bulk_dma', 'the listen window reloads the 50 ms reset timer: reset of about 5 ms'),
    ('M27', 'BUG-048', 'm_usb2_host.sv', [("        casez ({reg_sof_pend & w_sof_en & ~i_host_quiet, w_lpm_start,", "        casez ({reg_sof_pend & w_sof_en, w_lpm_start,"),
      ("          casez ({(w_lpm_start & ~(reg_sof_pend & w_sof_en & ~i_host_quiet)), (reg_sof_pend & w_sof_en & ~i_host_quiet),", "          casez ({(w_lpm_start & ~(reg_sof_pend & w_sof_en)), (reg_sof_pend & w_sof_en),"),
      ("        reg_sof_pend <= ~i_host_quiet;          // a SOF due while the port is quiet is dropped", "        reg_sof_pend <= 1'b1;")],
     'host_utmi8_axim_ts16', ['gen_host_susp_res.py', 'ts16'], 't_host_susp_res', 'the host sends SOF while the port is suspended'),
]

SEEDS = {'M11': '3'}                                    # scenario seed of a mutant (default 1)


def sh(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def main():
    ids = sys.argv[1:] or [m[0] for m in MUTANTS]
    results = []
    for mid, bug, fname, edits, target, gen, test, note in MUTANTS:
        if mid not in ids:
            continue
        src = open(os.path.join(RTL, fname), newline='').read()
        crlf = '\r\n' in src
        txt = src.replace('\r\n', '\n')
        for old, new, *cnt in [tuple(e) for e in edits]:
            if txt.count(old) != (cnt[0] if cnt else 1):
                results.append((mid, bug, test, 'NOT APPLIED', 'pattern found %d times in %s' % (txt.count(old), fname), note))
                break
            txt = txt.replace(old, new)
        else:
            mdir = P.MUTANTS                                           # flat: <id>__<file> (two-level limit of the package)
            os.makedirs(mdir, exist_ok=True)
            mfile = os.path.join(mdir, '%s__%s' % (mid, fname))
            open(mfile, 'w', newline='').write(txt.replace('\n', '\r\n') if crlf else txt)
            rec = json.load(open(os.path.join(P.build_dir(target), 'build_record.json')))
            flp = os.path.join(IP, rec['filelist'])
            lines = []
            for ln in open(flp):
                ln = ln.strip()
                if not ln or ln.startswith(('//', '#', '+', '-')):
                    continue
                p = os.path.normpath(os.path.join(os.path.dirname(flp), ln))
                if p in {os.path.normpath(os.path.join(IP, e)) for e in rec.get('exclude', [])}:
                    continue
                lines.append((mfile if os.path.basename(p) == fname and os.path.dirname(p) == os.path.normpath(RTL) else p).replace(chr(92), '/'))
            lines += [os.path.normpath(os.path.join(IP, e)).replace(chr(92), '/') for e in rec.get('extra', [])]
            flist = os.path.join(mdir, '%s__filelist.f' % mid)
            open(flist, 'w').write('\n'.join(lines) + '\n')
            b = sh([sys.executable, 'env/scripts/build.py', 'mut_' + mid, rec['top'], flist.replace(chr(92), '/')] + rec['parameters'] + ['--rebuild'], SIM)
            if 'pass' not in b.stdout.split('\n')[0]:
                results.append((mid, bug, test, 'BUILD FAILED', b.stdout.strip()[-200:], note))
                continue
            g = sh([sys.executable, gen[0], SEEDS.get(mid, '1')] + gen[1:], P.TESTS)
            ops = 'tests/' + g.stdout.strip().split('\n')[-1]
            r = sh([sys.executable, 'env/scripts/run.py', 'sim', 't_mut_' + mid + '_' + test[2:], 'mut_' + mid, ops], SIM)
            first = r.stdout.strip().split('\n')[0]
            verdict = 'KILLED' if first.endswith('FAIL') else ('SURVIVED' if first.endswith('PASS') else 'NO RESULT')
            results.append((mid, bug, test, verdict, first, note))
            bdir = P.build_dir('mut_' + mid)
            for f in os.listdir(bdir):
                if f not in ('build_record.json', 'build.log'):
                    p = os.path.join(bdir, f)
                    shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
        print(results[-1], flush=True)
    os.makedirs(P.COV, exist_ok=True)
    out = os.path.join(P.COV, 'mutation_report.md')
    old = open(out).read().split('\n') if os.path.exists(out) else []
    head = ['# Bug-library mutation check (R-241)', '', 'Generated by `env/scripts/mutate.py`. Each mutant re-injects one fixed bug into a copy of one RTL file (`verification/tests/mutants/<id>__<file>`) and runs the test that should catch it; KILLED = the test failed, SURVIVED = the test passed with the fault present.', '',
            '| Mutant | Bug | Test | Verdict | Run line | Fault |', '|---|---|---|---|---|---|']
    rows = {ln.split('|')[1].strip(): ln for ln in old if ln.startswith('| M') and ln[3].isdigit()}
    for mid, bug, test, verdict, first, note in results:
        rows[mid] = '| %s | %s | %s | %s | %s | %s |' % (mid, bug, test, verdict, first.replace('|', '/'), note)
    open(out, 'w').write('\n'.join(head + [rows[k] for k in sorted(rows)]) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
