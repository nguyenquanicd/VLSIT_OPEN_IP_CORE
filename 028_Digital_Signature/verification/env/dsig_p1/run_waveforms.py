"""Produces the simulated waveform evidence of the specification plan (R-033).

For every waveform of the plan that the delivered blocks can show (see PLAN) it runs the scenario of
the testbench (+WAVE=<n>) in the synthesis branch, dumps a VCD with the stem of the specification
figure, compares the window with the figure (vcd_compare.py), renders the simulated WaveJSON to SVG
(vlsit_waveform_svg.py of the skill vlsit-asic-ip-microspec) and writes waveform_compare.md.
The result column is MATCH or DIFFERENT with the reason; a waveform that needs signals of blocks
that are not written yet is NOT-SIMULATED with the reason (designer decision of 2026-11-24).

Usage: python run_waveforms.py [--skill DIR] [--python PY]
Not part of the RTL.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))          # verification/env/dsig_p1
VER = os.path.dirname(os.path.dirname(HERE))               # verification
IP = os.path.dirname(VER)
RTL = os.path.join(IP, 'rtl')
FIG = os.path.join(IP, 'spec', 'figures')
OUT = os.path.join(VER, 'sim', 'waveforms_sim')
MODELS = os.path.join(VER, 'models', 'dsig_p1')
TESTS = os.path.join(VER, 'tests', 'dsig_p1')
DOCS = os.path.join(VER, 'docs')
BUILD = os.path.join(VER, 'sim', 'build')

# waveform id -> (scenario number, figure stem)
PLAN = [
    ('WF-003', 3, 'wf_003_verify_start_done'),
    ('WF-005', 5, 'wf_005_start_disabled'),
    ('WF-007', 7, 'wf_007_abort'),
    ('WF-008', 8, 'wf_008_window_access'),
    ('WF-009', 9, 'wf_009_vas_mismatch'),
    ('WF-011', 11, 'wf_011_hybrid_verify'),
    ('WF-012', 12, 'wf_012_secret_clearing'),
    ('WF-015', 15, 'wf_015_apb_write_read'),
    ('WF-016', 16, 'wf_016_apb_nonsecure_error'),
]
# signal whose first rising edge fixes the start of the compared window
ANCHOR = {
    'wf_003_verify_start_done': 'o_dsig_cmd_start', 'wf_005_start_disabled': 'o_dsig_cmd_start',
    'wf_007_abort': 'o_dsig_cmd_abort', 'wf_008_window_access': 'o_reg_wr_en',
    'wf_009_vas_mismatch': 'i_hw_we_dsig_err_vasmis', 'wf_011_hybrid_verify': 'o_dsig_cmd_start',
    'wf_012_secret_clearing': 'i_hw_clr_dsig_key_0_data', 'wf_015_apb_write_read': 'i_apb_psel',
    'wf_016_apb_nonsecure_error': 'i_apb_psel',
}
NOT_SIM = [
    ('WF-001', 'wf_001_axi_write_burst', 'AXI4 channel signals belong to m_vlsit_dsig_axi, not written yet'),
    ('WF-002', 'wf_002_axi_write_overflow', 'AXI4 channel signals belong to m_vlsit_dsig_axi, not written yet'),
    ('WF-004', 'wf_004_sign_key_input', 'key request and key data ports belong to m_vlsit_dsig_key, not written yet'),
    ('WF-006', 'wf_006_entropy_timeout', 'entropy request port belongs to m_vlsit_dsig_rng, not written yet'),
    ('WF-010', 'wf_010_keygen', 'key and entropy ports belong to blocks that are not written yet'),
    ('WF-013', 'wf_013_random_request', 'random block signals, block not written yet'),
    ('WF-014', 'wf_014_hash_request', 'hash arbiter and stream signals, blocks not written yet'),
    ('WF-017', 'wf_017_dma_request_ack', 'DMA handshake belongs to m_vlsit_dsig_axi, not written yet'),
    ('WF-018', 'wf_018_key_timeout', 'key request port belongs to m_vlsit_dsig_key, not written yet (the control block start pulse o_key_start is checked by TEST-030)'),
]


REPLACED = {'wf_003_verify_start_done', 'wf_005_start_disabled', 'wf_007_abort', 'wf_008_window_access',
            'wf_009_vas_mismatch', 'wf_011_hybrid_verify', 'wf_012_secret_clearing', 'wf_016_apb_nonsecure_error'}
GENERIC = ('the figure is schematic: it draws each state over two slots, leaves out the one-cycle states and draws set pulses as '
           'levels, while the simulation shows the real cycle counts. Designer decision needed (R-090, R-091): replace the figure by '
           'the simulated waveform, or change the RTL')
CAUSE = {
    'wf_016_apb_nonsecure_error': 'PSLVERR stays high after the transfer in the simulation, as section 11.4 states for the generated '
                                  'flip-flop (allowed because IHI0024D 3.4 only recommends a low value); the figure drops it. '
                                  'All request and response edges agree. Designer decision needed: correct the figure',
    'wf_012_secret_clearing': GENERIC + '; the row w_work_nonzero is a signal of the engines, not written yet',
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skill', default=os.path.expanduser('~/.claude/skills/vlsit-asic-ip-microspec'))
    ap.add_argument('--python', default=sys.executable)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)
    res_file = os.path.join(OUT, '_results.jsonl')
    if os.path.exists(res_file):
        os.remove(res_file)
    vvp = os.path.join(BUILD, 'wf.vvp')
    cmd = ['iverilog', '-g2012', '-DVLSIT_SYNTHESIS', '-DCSR_ASYNC=0', '-s', 'tb_dsig_p1', '-I', HERE, '-I', MODELS, '-I', TESTS,
           '-o', vvp, '-f', os.path.join(RTL, 'filelist.f')]
    cmd += [os.path.join(HERE, f) for f in ('dsig_p1_wrap.sv', 'dsig_apb_assert.sv', 'dsig_p1_assert.sv', 'dsig_wf_probe.sv')]
    cmd += [os.path.join(TESTS, 'tb_dsig_p1.sv')]
    r = subprocess.run(cmd, cwd=RTL, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[:2000])
        return 2
    svg_tool = os.path.join(a.skill, 'scripts', 'vlsit_waveform_svg.py')
    rows = []
    for wid, num, stem in PLAN:
        vcd = os.path.join(OUT, stem + '.vcd')
        subprocess.run(['vvp', vvp, '+WAVE=%d' % num, '+DUMP=' + vcd], cwd=RTL, capture_output=True, text=True)
        before = os.path.getsize(res_file) if os.path.exists(res_file) else 0
        r = subprocess.run([a.python, os.path.join(HERE, 'vcd_compare.py'), os.path.join(FIG, stem + '.json'), vcd,
                            os.path.join(OUT, stem), '--anchor', ANCHOR[stem]], capture_output=True, text=True)
        print(r.stdout.rstrip())
        last = json.loads(open(res_file, encoding='utf-8').read().strip().splitlines()[-1])
        sc = subprocess.run([a.python, svg_tool, 'check', os.path.join(OUT, stem + '.json')], capture_output=True, text=True)
        rd = subprocess.run([a.python, svg_tool, 'render', os.path.join(OUT, stem + '.json'), '--out', os.path.join(OUT, stem + '.svg'),
                             '--force'], capture_output=True, text=True)
        if rd.returncode != 0:
            print('render failed', stem, rd.stdout[-300:], rd.stderr[-300:])
        if last['result'] == 'MATCH' and stem in REPLACED:
            note = ('The specification figure was replaced by this simulated waveform on 2026-11-24 (designer decision). Before the '
                    'replacement the comparison was DIFFERENT because the former figure was schematic (states drawn over two slots, '
                    'one-cycle states left out, set pulses drawn as levels); the former figure is in '
                    'archive/spec_figures_before_sim_2026-11-24/. The match is by construction; the evidence is the simulation itself')
        elif last['result'] == 'MATCH':
            note = 'Same edges and values'
        else:
            cause = CAUSE.get(stem, GENERIC)
            note = '%d of %d compared slots differ: %s | Cause: %s' % (
                last['compared'] - last['matched'], last['compared'], '; '.join(last['differences'][:4]), cause)
        if last['missing_signals']:
            note += ' | signals not in the dump: ' + ', '.join(last['missing_signals'])
        result = last['result']
        if stem in REPLACED:
            # the figure is now generated from this simulation: agreement is by construction and is not evidence
            result = 'DIFFERENT'
            note = ('Resolved by replacing the specification figure with this simulated waveform on 2026-11-24 (designer decision). '
                    'The former figure was schematic (states drawn over two slots, one-cycle states left out, set pulses drawn as levels); '
                    'it is kept in archive/spec_figures_before_sim_2026-11-24/. No independent MATCH is claimed: the figure now agrees '
                    'with the simulation because it is made from it, so it shows the behavior of the RTL, not a check of the RTL against '
                    'the specification. The behavior is checked by the assertions and tests named in section 15.')
        rows.append((wid, 'figures/%s.svg' % stem, 'waveforms_sim/%s.svg' % stem, result, note))
    for wid, stem, why in NOT_SIM:
        rows.append((wid, 'figures/%s.svg' % stem, '-', 'NOT-SIMULATED', why))
    rows.sort()
    with open(os.path.join(OUT, 'waveform_compare.md'), 'w', encoding='utf-8') as f:
        f.write('# Simulated waveforms against the specification figures\n\n')
        f.write('Generated by `verification/scripts/run_waveforms.py` (synthesis branch, `CSR_ASYNC=0`: the APB clock is the core clock,\n')
        f.write('the condition of the figures of section 10.3.1). A DIFFERENT row is analysed under R-026; only the designer\n')
        f.write('decides whether the figure or the RTL changes (R-090, R-091).\n\n')
        f.write('| Waveform ID | Specification figure | Simulated waveform | Result | Note |\n|---|---|---|---|---|\n')
        for r in rows:
            f.write('| %s | %s | %s | %s | %s |\n' % r)
    shutil.copyfile(os.path.join(OUT, 'waveform_compare.md'), os.path.join(DOCS, 'waveform_compare.md'))
    print('written', os.path.join(OUT, 'waveform_compare.md'), 'and a copy in docs/')
    return 0


if __name__ == '__main__':
    sys.exit(main())
