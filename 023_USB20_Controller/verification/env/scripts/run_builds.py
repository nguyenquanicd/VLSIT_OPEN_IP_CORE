"""t_dir_param_builds: elaboration of every configuration of the plan and of illegal parameter sets (REQ-PARAM-001..004,
REQ-FUNC-028). Creates one run folder with the commands, tool versions and one result line per case.
Run from the sim folder:  python scripts/run_builds.py"""
import os
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run as R

SIM = R.SIM
IP = os.path.normpath(os.path.join(SIM, '..'))
RTL = os.path.join(IP, 'rtl')
VL = 'C:/Tools/oss-cad-suite/bin/verilator_bin.exe'
IV = 'C:/Tools/oss-cad-suite/bin/iverilog.exe'
VVP = 'C:/Tools/oss-cad-suite/bin/vvp.exe'
LIBS = ['-y', os.path.join(IP, '..', '000_Common', 'rtl_lib'), '-y', os.path.join(IP, '..', '000_Common', 'rtl_cells'),
        '-y', os.path.join(IP, '..', '001_AsyncGrayFIFO', 'rtl'), '-y', RTL, '-y', os.path.join(RTL, 'csr')]
CONFIGS = {
    'cfg_dev_utmi8_axim': ('m_usb2_top_utmi_axim', 'ROLE=0 NUM_EP=4 UTMI_W=8 FIFO_DEPTH=1024 SG_EN=1 LPM_EN=1'),
    'cfg_dev_utmi16_axim': ('m_usb2_top_utmi_axim', 'ROLE=0 NUM_EP=4 UTMI_W=16 AXI_DATA_W=64 FIFO_DEPTH=1024'),
    'cfg_dev_utmi8_axis': ('m_usb2_top_utmi_axis', 'ROLE=0 NUM_EP=2 UTMI_W=8 FIFO_DEPTH=256 NUM_DMA_CH=2'),
    'cfg_dev_ulpi_axim': ('m_usb2_top_ulpi_axim', 'ROLE=0 NUM_EP=4 FIFO_DEPTH=1024 LPM_EN=1'),
    'cfg_host_utmi8_axim': ('m_usb2_top_utmi_axim', 'ROLE=1 NUM_HC=8 UTMI_W=8 FIFO_DEPTH=1024 SPLIT_EN=1 SG_EN=1 LPM_EN=1'),
    'cfg_host_ulpi_axim': ('m_usb2_top_ulpi_axim', 'ROLE=1 NUM_HC=4 FIFO_DEPTH=1024'),
    'cfg_dev_ulpi_axis': ('m_usb2_top_ulpi_axis', 'ROLE=0 NUM_EP=2 FIFO_DEPTH=256 NUM_DMA_CH=2'),
    'cfg_dual_utmi8_axim': ('m_usb2_top_utmi_axim', 'ROLE=2 NUM_EP=4 NUM_HC=4 FIFO_DEPTH=1024'),
    'cfg_all_pipe': ('m_usb2_top_utmi_axim', 'ROLE=0 NUM_EP=4 PIPE_PHY_IN=1 PIPE_RX=1 PIPE_CRC=1 PIPE_XREG=1 PIPE_MODE=1 PIPE_AXS=1 RAM_1P=1'),
    'cfg_max_counts': ('m_usb2_top_utmi_axim', 'ROLE=2 NUM_EP=15 NUM_HC=15 FIFO_DEPTH=4096'),
}
# (name, parameters of m_usb2_cfgchk, expected o_cfg_err, requirement)
CHK = [('legal default', '', 0, 'REQ-PARAM-001'),
       ('split without host role', 'PARA_USB2_SPLIT_EN=1 PARA_USB2_ROLE=0', 1, 'REQ-PARAM-001'),
       ('split with host role', 'PARA_USB2_SPLIT_EN=1 PARA_USB2_ROLE=1', 0, 'REQ-PARAM-001'),
       ('ULPI with 16-bit', 'PARA_USB2_PHY_IF=1 PARA_USB2_UTMI_W=16', 1, 'REQ-PARAM-001'),
       ('SG with slave interface', 'PARA_USB2_SG_EN=1 PARA_USB2_DATA_IF=1', 1, 'REQ-PARAM-001'),
       ('slave without DMA channel', 'PARA_USB2_DATA_IF=1 PARA_USB2_NUM_DMA_CH=0', 1, 'REQ-PARAM-001'),
       ('depth below 256', 'PARA_USB2_FIFO_DEPTH=128', 1, 'REQ-PARAM-004'),
       ('depth not a power of two', 'PARA_USB2_FIFO_DEPTH=1000', 1, 'REQ-PARAM-001'),
       ('depth above 32768', 'PARA_USB2_FIFO_DEPTH=65536', 1, 'REQ-PARAM-001'),
       ('depth 256 at the minimum', 'PARA_USB2_FIFO_DEPTH=256', 0, 'REQ-PARAM-004'),
       ('TSCALE illegal', 'PARA_USB2_TSCALE=100', 1, 'REQ-PARAM-001'),
       ('TSCALE 4096', 'PARA_USB2_TSCALE=4096', 0, 'REQ-PARAM-001'),
       ('AXI width not 4 x UTMI width', 'PARA_USB2_AXI_DATA_W=64', 1, 'REQ-PARAM-001')]


def main():
    free0, t0 = R.admit(), time.time()
    rid, d = R.new_run('t_dir_param_builds')
    env = R.env()
    envf = R.env(True)                  # iverilog and vvp need the OSS CAD Suite directories first
    res, cmds = {}, []
    ver = subprocess.run([VL, '--version'], capture_output=True, text=True, env=env).stdout.strip()
    for name, (top, ps) in CONFIGS.items():
        g = ['-GPARA_USB2_' + p for p in ps.split()]
        cmd = [VL, '--lint-only', '-Wno-fatal', '-Wno-lint', '-Wno-style', '--top-module', top, '-DVLSIT_SYNTHESIS'] + g + LIBS + [os.path.join(RTL, top + '.sv')]
        cmds.append(' '.join(cmd))
        r = subprocess.run(cmd, cwd=RTL, capture_output=True, text=True, env=env)
        open(os.path.join(d, name + '.log'), 'w').write(r.stdout + r.stderr)
        errs = [x for x in (r.stdout + r.stderr).split('\n') if x.startswith('%Error')]
        res['elab ' + name] = 'PASS' if r.returncode == 0 and not errs else 'FAIL ' + (errs[0][:120] if errs else 'rc=%d' % r.returncode)
    tb = os.path.join(R.P.TB, 'tb_cfgchk.sv')
    R.keep_input(d, tb)
    for name, ps, exp, req in CHK:
        out = os.path.join(d, 'chk.vvp')
        wrap = os.path.join(d, 'chk_wrap.sv')
        defs = ''.join('  defparam dut.%s = %s;\n' % tuple(p.split('=')) for p in ps.split())
        open(wrap, 'w').write(open(tb).read().replace('m_usb2_cfgchk dut (.o_cfg_err(err));', 'm_usb2_cfgchk dut (.o_cfg_err(err));\n' + defs))
        # VLSIT_SYNTHESIS turns the elaboration stop of m_usb2_cfgchk off: this test elaborates illegal sets on purpose
        cmd = [IV, '-g2012', '-DVLSIT_SYNTHESIS', '-o', out, wrap, os.path.join(RTL, 'm_usb2_cfgchk.sv')]
        cmds.append(' '.join(cmd) + ' ; vvp ' + out)
        c = subprocess.run(cmd, capture_output=True, text=True, env=envf)
        v = subprocess.run([VVP, out], capture_output=True, text=True, env=envf) if c.returncode == 0 else c
        m = re.search(r'CFGERR (\d)', v.stdout)
        got = int(m.group(1)) if m else None
        res['check %s (%s)' % (name, req)] = 'PASS' if got == exp else 'FAIL got %s expected %d' % (got, exp)
    ok = all(v.startswith('PASS') for v in res.values())
    bins = []                                                    # functional bins of the elaboration cases (plan section 8, cg_build)
    if all(v.startswith('PASS') for k, v in res.items() if k.startswith('elab ')):
        bins.append('cg_build.cfg_each')
    if res.get('elab cfg_dev_utmi8_axim', '').startswith('PASS'):
        bins += ['cg_build.role0', 'cg_build.opt_off']
    if res.get('elab cfg_host_utmi8_axim', '').startswith('PASS'):
        bins.append('cg_build.role1')
    if all(res.get('check %s (%s)' % (nm, rq), '').startswith('PASS') for nm, ps, ex, rq in CHK if ex == 1):
        bins.append('cg_build.illegal_each')
    if res.get('check depth 256 at the minimum (REQ-PARAM-004)', '').startswith('PASS'):
        bins.append('cg_build.depth_min')
    if res.get('check depth below 256 (REQ-PARAM-004)', '').startswith('PASS'):
        bins.append('cg_build.depth_below')
    open(os.path.join(d, 'bins.txt'), 'w').write(''.join(b + ' 0' + chr(10) for b in bins))
    rec = {'kind': 'elaboration', 'working_directory': 'rtl', 'commands': cmds,
           'input_sha256': dict([(os.path.relpath(tb, SIM).replace(chr(92), '/'), R.sha(tb))] + [('rtl/' + f, R.sha(os.path.join(RTL, f))) for f in sorted(os.listdir(RTL)) if f.endswith('.sv')]),
           'tools': {'verilator': ver, 'iverilog': R.version([IV, '-V'])},
           'seed': 'not applicable', 'timeout_s': 'none', 'results': res, 'verdict': 'PASS' if ok else 'FAIL'}
    wave = {'status': 'not_captured', 'reason': 'elaboration and combinational check', 'signal_scope': 'none',
            'time_window': 'none', 'paths': []}
    R.finish(rid, d, 't_dir_param_builds', rec, free0, t0, wave)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
