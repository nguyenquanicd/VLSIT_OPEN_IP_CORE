"""Priority-test waveforms (R-283), 2026-11-24: one run-bound waveform for each of the ten highest-risk testcases.

The list below is risk-ranked (reason in the second column). For each entry the script builds the trace variant of the test's
build (env/scripts/build.py <build> --trace), regenerates the scenario with the seed of the testlist, runs it under the test's own
name with +vcd (interface-level dump: the signals of the testbench top, i.e. UTMI+/ULPI, APB, AXI, interrupt and mode pins;
+vcd_full would dump the whole DUT) and records the run ID, waveform path, SHA-256, build, seed and scenario hash in
sim/waveform_index.csv. A failing run keeps its waveform too (it is the evidence of the failure).
    python env/scripts/priority_waves.py [test ...]          (from the verification folder)"""
import csv
import hashlib
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vpaths as P  # noqa: E402

PRIORITY = [
    ('t_host_enum_bulk_dma', 'host bring-up: connect, 50 ms reset (BUG-047), chirp, SOF, control and bulk through the DMA', 'host_utmi8_axim_ts16', 'gen_host_enum_bulk_dma.py:ts16'),
    ('t_dev_enum_bulk_dma', 'device enumeration, chirp, bulk IN/OUT, PING/NYET through the DMA', 'dev_utmi8_axim', 'gen_dev_enum_bulk_dma.py'),
    ('t_dev_xreg_race', 'register crossing ordering under software reaction at once (BUG-044)', 'dev_utmi8_axim', 'gen_dev_xreg_race.py'),
    ('t_host_susp_res', 'host suspend/resume: SOF stop and restart (checks were vacuous before 2026-11-24)', 'host_utmi8_axim_ts16', 'gen_host_susp_res.py:ts16'),
    ('t_fi_bus_errors', 'device error handling: PID, CRC, bit stuffing, time-out, babble', 'dev_utmi8_axim', 'gen_fi_bus_errors.py'),
    ('t_fi_host_bus_errors', 'host error handling: STALL, NAK, time-out retries, CRC, toggle', 'host_utmi8_axim_ts16', 'gen_fi_host_bus_errors.py:ts16'),
    ('t_host_split_poll', 'split transactions through a hub and polled channels', 'host_utmi8_axim_ts16', 'gen_host_split_poll.py:ts16'),
    ('t_dev_iso_int_mix', 'isochronous and interrupt endpoints, iso_inc, short packets', 'dev_utmi8_axim', 'gen_dev_iso_int_mix.py'),
    ('t_dev_suspend_lpm_reset', 'device suspend, resume, remote wakeup, reset in suspend, LPM L1', 'dev_utmi8_axim', 'gen_dev_suspend_lpm_reset.py'),
    ('t_dev_axis_win', 'AXI-slave windows with the DMA handshake and backpressure', 'dev_utmi8_axis', 'gen_dev_axis_win.py'),
]


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def main():
    only = sys.argv[1:]
    os.chdir(P.V)
    seeds = {}
    for r in csv.DictReader(open(P.TESTLIST)):
        seeds.setdefault((r['test'], r['source']), r['seeds'].split()[0] if r['seeds'].strip() else '1')
    built = set()
    out = []
    for rank, (test, why, build, source) in enumerate(PRIORITY, 1):
        if only and test not in only:
            continue
        if build not in built:
            b = subprocess.run([sys.executable, 'env/scripts/build.py', build, '--trace', '--rebuild'], capture_output=True, text=True)
            print(b.stdout.strip().split('\n')[0], flush=True)
            built.add(build)
        seed = seeds.get((test, source), '1')
        src = source.split(':')
        g = subprocess.run([sys.executable, src[0], seed] + src[1:], cwd=P.TESTS, capture_output=True, text=True)
        ops = 'tests/' + g.stdout.strip().split('\n')[-1]
        r = subprocess.run([sys.executable, 'env/scripts/run.py', 'sim', test, build + '_trace', ops, '+seed=%s' % seed, '+vcd'],
                           capture_output=True, text=True)
        first = (r.stdout.strip().split('\n') or [''])[0]
        rid = first.split()[0] if first else ''
        wave = os.path.join(P.run_dir(rid), 'wave.vcd')
        ok = os.path.exists(wave)
        out.append(dict(rank=rank, test=test, reason=why, run=rid, verdict=first.split()[-1] if first else 'no output', build=build + '_trace',
                        seed=seed, scenario=source, scenario_sha256=sha(os.path.join(P.V, ops)), waveform=P.rel(wave) if ok else 'missing',
                        sha256=sha(wave) if ok else '', size_bytes=os.path.getsize(wave) if ok else 0,
                        scope='testbench top level (interfaces, pins, interrupt); whole run'))
        print('%2d %-24s %s %s %s' % (rank, test, first, 'wave' if ok else 'NO WAVE', out[-1]['size_bytes']), flush=True)
    path = os.path.join(P.SIMOUT, 'waveform_index.csv')
    old = {r['test']: r for r in csv.DictReader(open(path))} if os.path.exists(path) else {}
    for o in out:
        old[o['test']] = o
    keys = ['rank', 'test', 'reason', 'run', 'verdict', 'build', 'seed', 'scenario', 'scenario_sha256', 'waveform', 'sha256', 'size_bytes', 'scope']
    with open(path, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for o in sorted(old.values(), key=lambda x: int(x['rank'])):
            w.writerow({k: o.get(k, '') for k in keys})
    return 0


if __name__ == '__main__':
    sys.exit(main())
