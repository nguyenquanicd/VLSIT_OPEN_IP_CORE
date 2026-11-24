"""Code coverage of the retained campaign (Verilator coverage builds cov_dev and cov_host): rebuilds both builds with --coverage, runs the listed
scenarios (one seed each) as runs t_cov_*, merges the coverage.dat files and writes coverage/code_coverage_dev.txt and _host.txt.
Run from the verification folder:  python env/scripts/run_coverage.py     (about 15 minutes; one job at a time)"""
import glob
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402
SIM = P.V
os.chdir(SIM)
TOOLS = 'C:/Tools/oss-cad-suite/bin'
DEV = ['dev_enum_bulk_dma', 'dev_iso_int_mix', 'dev_suspend_lpm_reset', 'fi_bus_errors', 'dev_sg_dma', 'fi_axi_err', 'dir_csr_regs', 'fi_csr_access',
       'dir_test_mode', 'fi_xq_full', 'dev_rand', 'dir_reset', 'dev_fs', 'dev_edge_len', 'dev_edge_pid', 'dev_edge_gap', 'dev_edge_tmo',
       'dev_edge_abort', 'dev_edge_ovf']
HOST = ['host_enum_bulk_dma_ts16', 'host_rand', 'host_split_poll', 'fi_host_bus_errors', 'fi_ocp', 'host_fs', 'host_edge_force', 'host_edge_rxerr', 'host_edge_iso', 'host_edge_miss', 'host_edge_psplit',
        'host_edge_bsplit', 'host_edge_gaps']


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def main():
    sh([sys.executable, 'env/scripts/rebuild_all.py', 'cov_dev', 'cov_host'])
    sh([sys.executable, 'gen_dev_fs.py', '1'], cwd=P.TESTS)
    runs = {'dev': [], 'host': []}
    for kind, names, build, pre in (('dev', DEV, 'cov_dev', 't_cov_'), ('host', HOST, 'cov_host', 't_cov_h_')):
        for n in names:
            r = sh([sys.executable, 'env/scripts/run.py', 'sim', pre + n, build, 'tests/ops/%s_s1.ops' % n])
            line = r.stdout.strip().split('\n')[0]
            print(line, flush=True)
            runs[kind].append(line.split()[0])
    env = dict(os.environ)
    env['PATH'] = TOOLS + ';' + env['PATH']
    for kind in ('dev', 'host'):
        cdir = os.path.join(P.SIMOUT, 'coverage_' + kind)            # merged database and annotated sources, flat
        os.makedirs(cdir, exist_ok=True)
        os.makedirs(P.COV, exist_ok=True)
        dats = [os.path.join(P.run_dir(r), 'coverage.dat') for r in runs[kind]]
        sh([TOOLS + '/verilator_coverage_bin.exe', '--write', os.path.join(cdir, 'merged.dat')] + dats, env=env)
        a = sh([TOOLS + '/verilator_coverage_bin.exe', '--annotate', cdir, '--annotate-min', '1', os.path.join(cdir, 'merged.dat')], env=env)
        open(os.path.join(P.COV, 'code_coverage_%s.txt' % kind), 'w').write('\n'.join(a.stdout.split('\n')[:6]) + '\n')


if __name__ == '__main__':
    main()
