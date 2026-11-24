"""Build and run one unit testbench with Verilator (OSS CAD Suite on Windows).
Usage: python run_unit.py <unit> [plusarg ...]
Units are listed in UNITS: unit -> (top module, testbench file, RTL files). Output and build files go to
verification/sim/<unit>. The exit code is 0 when the log contains 'RESULT: PASS'."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IP = os.path.normpath(os.path.join(HERE, '..', '..', '..')).replace(chr(92), '/')
HASH = os.path.normpath(os.path.join(IP, '..', '019_SHA2_SHA3_Hash', 'rtl')).replace(chr(92), '/')
VBIN = 'C:/Tools/oss-cad-suite/bin/verilator_bin.exe'
GXX = 'C:/Users/PC/Tools/msys64/ucrt64/bin'
R = IP + '/rtl/'
T = IP + '/verification/tests/'
HASHCORES = [HASH + '/m_vlsit_sha_%s.sv' % m for m in ('core256', 'core512', 'keccak', 'pad')]
LIB = [IP + '/../000_Common/rtl_cells/VLSIT_CELL_SRAM_1W1R.sv', IP + '/../000_Common/rtl_lib/m_vlsit_sfifo_ram_macro.sv',
       IP + '/../002_SyncFIFO/rtl/m_vlsit_sfifo_mem.sv', IP + '/../000_Common/rtl_lib/m_vlsit_afifo_cell_sync.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_DFF_RN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_DFF_SN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_2FF_RN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_2FF_SN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_3FF_RN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_3FF_SN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_4FF_RN.sv', IP + '/../000_Common/rtl_cells/VLSIT_CELL_SYNC_4FF_SN.sv']
CSR = [R + 'csr/m_vlsit_csr_sync.sv', R + 'csr/m_vlsit_csr_dsig.sv']
SYS = (HASHCORES + LIB + CSR + [R + f for f in ('m_vlsit_sha_eng.sv', 'm_vlsit_dsig_hseq.sv', 'm_vlsit_dsig_harb.sv', 'm_vlsit_dsig_hfeed.sv',
       'm_vlsit_dsig_brd.sv', 'm_vlsit_dsig_bwr.sv', 'm_vlsit_dsig_ec_rom.sv', 'm_vlsit_dsig_ec.sv', 'm_vlsit_dsig_buf.sv', 'm_vlsit_dsig_ctl.sv',
       'm_vlsit_dsig_axi.sv', 'm_vlsit_dsig_key.sv', 'm_vlsit_dsig_rng.sv', 'm_vlsit_dsig_top.sv')])
HSH = HASHCORES + [R + f for f in ('m_vlsit_sha_eng.sv', 'm_vlsit_dsig_hseq.sv', 'm_vlsit_dsig_harb.sv', 'm_vlsit_dsig_hfeed.sv')]
HBSF = HSH + [R + 'm_vlsit_dsig_hbs_rom.sv', R + 'm_vlsit_dsig_hbs.sv']
LATF = HSH + [R + 'm_vlsit_dsig_lat_rom.sv', R + 'm_vlsit_dsig_lat.sv']
UNITS = {
    'lat': ('tb_lat', T + 'lat/tb_lat.sv', LATF),
    'hbs': ('tb_hbs', T + 'hbs/tb_hbs.sv', HBSF),
    'hfeed': ('tb_hfeed', T + 'hash/tb_hfeed.sv', HSH),
    'hseq': ('tb_hseq', T + 'hash/tb_hseq.sv', HSH),
    'top_pq': ('tb_top_pq', T + 'top/tb_top_pq.sv', SYS + [R + 'm_vlsit_dsig_lat_rom.sv', R + 'm_vlsit_dsig_lat.sv', R + 'm_vlsit_dsig_hbs_rom.sv', R + 'm_vlsit_dsig_hbs.sv']),
    'top_err': ('tb_top_err', T + 'top/tb_top_err.sv', SYS + [R + 'm_vlsit_dsig_lat_rom.sv', R + 'm_vlsit_dsig_lat.sv', R + 'm_vlsit_dsig_hbs_rom.sv', R + 'm_vlsit_dsig_hbs.sv']),
    'top_ec': ('tb_top_ec', T + 'top/tb_top_ec.sv', SYS + [R + 'm_vlsit_dsig_lat_rom.sv', R + 'm_vlsit_dsig_lat.sv', R + 'm_vlsit_dsig_hbs_rom.sv', R + 'm_vlsit_dsig_hbs.sv']),
    'axi': ('tb_axi', T + 'axi/tb_axi.sv', LIB + [R + 'm_vlsit_dsig_buf.sv', R + 'm_vlsit_dsig_axi.sv']),
    'key_rng': ('tb_key_rng', T + 'key_rng/tb_key_rng.sv', [R + 'm_vlsit_dsig_key.sv', R + 'm_vlsit_dsig_rng.sv']),
}


def env_for(bdir):
    os.makedirs(bdir + '/tmp', exist_ok=True)
    os.makedirs(bdir + '/shim', exist_ok=True)
    with open(bdir + '/shim/python3', 'w', newline=chr(10)) as fh:
        fh.write('#!/bin/bash' + chr(10) + 'exec "%s" "$@"' % sys.executable.replace(chr(92), '/') + chr(10))
    env = dict(os.environ)
    env.update(TMP=bdir + '/tmp', TEMP=bdir + '/tmp', TMPDIR=bdir + '/tmp', VERILATOR_ROOT='C:/Tools/oss-cad-suite/share/verilator')
    env['PATH'] = os.pathsep.join([bdir + '/shim', GXX, 'C:/Tools/oss-cad-suite/bin', 'C:/Users/PC/Tools/msys64/usr/bin', env['PATH']])
    return env


def main(argv):
    unit = argv[0]
    top, tb, files = UNITS[unit]
    bdir = IP + '/verification/sim/' + unit + os.environ.get('UNIT_TAG', '')
    os.makedirs(bdir, exist_ok=True)
    exe = bdir + '/obj/V' + top + '.exe'
    cmd = [VBIN, '--binary', '--timing', '-O2', '-Wno-fatal', '-Wno-lint', '-Wno-style', '--top-module', top, '--x-assign', '0', '--x-initial', '0',
           '-Mdir', bdir + '/obj', '-j', '4', '-CFLAGS', '-O2 -std=gnu++17', '-LDFLAGS', '-static-libstdc++ -static-libgcc', '-o', 'V' + top] + files + [tb]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env_for(bdir))
    open(bdir + '/build.log', 'w').write(r.stdout + r.stderr)
    if not os.path.exists(exe):
        print('COMPILE FAIL')
        print((r.stdout + r.stderr)[-4000:])
        return 2
    r = subprocess.run([exe] + argv[1:], capture_output=True, text=True, env=env_for(bdir), cwd=bdir, timeout=3000)
    out = r.stdout + r.stderr
    open(bdir + '/run.log', 'w').write(out)
    print('\n'.join(l for l in out.splitlines() if not l.startswith('- ')))
    return 0 if 'RESULT: PASS' in out else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
