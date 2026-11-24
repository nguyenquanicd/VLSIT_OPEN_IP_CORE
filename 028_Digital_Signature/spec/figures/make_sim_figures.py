"""Builds the WaveJSON of the figures that were replaced by simulated waveforms (designer decision of
2026-11-24: the figures WF-003, 005, 007, 008, 009, 011, 012 and 016 of the plan were schematic and
differ from the cycle-accurate simulation of the phase 1 RTL).

Source: the VCD dumps of the scenarios in ../../verification/sim/waveforms_sim/ (run_waveforms.py).
The rows, groups and signal names are those of the former figures (kept in
../../archive/spec_figures_before_sim_2026-11-24/); the wave strings come from the simulation, one
character per core clock cycle. Rows whose signal does not exist in the delivered blocks are dropped.
Usage: python make_sim_figures.py          (writes wf_<n>_*.json here; render with vlsit_waveform_svg.py)
"""
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IP = os.path.dirname(os.path.dirname(HERE))
SIM = os.path.join(IP, 'verification', 'sim', 'waveforms_sim')
OLD = os.path.join(IP, 'archive', 'spec_figures_before_sim_2026-11-24')
spec = importlib.util.spec_from_file_location('vcd_compare', os.path.join(IP, 'verification', 'env', 'dsig_p1', 'vcd_compare.py'))
vc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vc)

NAMES = vc.NAMES

# stem: (slots, anchor signal, slot of the anchor rise, dropped rows, foot text)
CFG = {
    'wf_003_verify_start_done': (24, 'o_dsig_cmd_start', 2, [],
        'Simulated (tb_dsig_p1, synthesis branch, one clock): the start bit is set for one cycle and cleared by hardware in the same cycle; '
        'ENUM_ST_CHECK lasts one cycle; the engine model needs 6 cycles; busy is 1 from ENUM_ST_RUN to the end of ENUM_ST_RESULT.'),
    'wf_005_start_disabled': (20, 'o_dsig_cmd_start', 2, [],
        'Simulated: no engine is started; ENUM_ST_ERR sets the error flag, the interrupt follows the raw event and the mask, '
        'then ENUM_ST_CLEAR waits for the cleared level of the secrets.'),
    'wf_007_abort': (20, 'o_dsig_cmd_abort', 2, [],
        'Simulated: no result is produced; the abort goes to ENUM_ST_CLEAR, the key registers are cleared by the hardware clear, and the '
        'state ends when the zeroization model reports the cleared level (8 cycles in the model).'),
    'wf_008_window_access': (40, 'o_reg_wr_en', 2, [],
        'Simulated: a window write reaches the buffer one cycle after its register event and the address is added after that write '
        '(DEC-039); a window read adds 4 in the event cycle; software writes the address 0x000 first and again 0x000 before the reads.'),
    'wf_009_vas_mismatch': (20, 'i_hw_we_dsig_err_vasmis', 4, [],
        'Simulated: no result is written (resvld stays 0); the alarm stays until software writes 1 to dsig_alarm.fault.'),
    'wf_011_hybrid_verify': (44, 'o_dsig_cmd_start', 2, [],
        'Simulated: Ed25519 verifies valid (edok 1, sigok 0 under the policy both valid); the ML-DSA-65 verification then sets mlok and sigok.'),
    'wf_012_secret_clearing': (24, 'i_hw_clr_dsig_key_0_data', 4, ['w_work_nonzero'],
        'Simulated: the key words are cleared in ENUM_ST_CLEAR (the zeroization model needs 8 cycles); the row of the working registers '
        'of the engines is not drawn because the engines are not written yet.'),
    'wf_016_apb_nonsecure_error': (16, 'i_apb_psel', 2, [],
        'Simulated: the error answers in the first access cycle; PSLVERR stays high after the transfer (section 11.4); '
        'the write is ignored, so the enable bit stays 0.'),
}


def flatten(lst, out):
    for s in lst:
        if isinstance(s, list):
            flatten(s[1:], out)
        elif isinstance(s, dict) and 'name' in s:
            out.append(s)


def sample(changes, edges, name, k, e0):
    idx = e0 + k + 1
    if idx >= len(edges):
        return None
    return vc.value_at(changes[name], edges[idx] - 1)


def build(stem, n, anchor, aslot, drop, foot):
    old = json.load(open(os.path.join(OLD, stem + '.json'), encoding='utf-8'))
    changes, widths = vc.parse_vcd(os.path.join(SIM, stem + '.vcd'))
    clk = changes['i_clk_core']
    edges = [t for (t, v), (tp, vp) in zip(clk[1:], clk[:-1]) if v == '1' and vp == '0']
    e0 = None
    for j in range(1, len(edges) - 1):
        if vc.value_at(changes[anchor], edges[j] - 1) == '0' and vc.value_at(changes[anchor], edges[j + 1] - 1) == '1':
            e0 = max(0, j - aslot)
            break
    if e0 is None:
        raise SystemExit('anchor %s never rises in %s' % (anchor, stem))
    if e0 + n + 1 >= len(edges):
        raise SystemExit('dump of %s too short for %d slots' % (stem, n))

    def conv(item):
        if isinstance(item, list):
            rows = [conv(x) for x in item[1:]]
            rows = [r for r in rows if r]
            return [item[0]] + rows if rows else None
        if item['name'] == 'i_clk_core':
            return {'name': 'i_clk_core', 'wave': 'p' + '.' * (n - 1)}
        if item['name'] in drop:
            return None
        w = widths[item['name']]
        wave = ''
        data = []
        prev = None
        for k in range(n):
            v = sample(changes, edges, item['name'], k, e0)
            if v is None or any(c in v for c in 'xXzZ'):
                ch = 'x'
            elif w == 1:
                ch = v[-1]
            else:
                ch = '='
            key = v if w > 1 else ch
            if k > 0 and key == prev:
                ch = '.'
            elif ch == '=':
                num = int(v, 2)
                if item['name'] == 'reg_fsm_ctl_current_state':
                    data.append(NAMES.get(num, 'STATE_%d' % num))
                elif item['name'] == 'o_reg_wr_addr':
                    data.append('WIN_WR' if num == 0x94 else '0x%X' % num)
                else:
                    data.append('0x%X' % num)
            prev = key
            wave += ch
        d = {'name': item['name'], 'wave': wave}
        if data:
            d['data'] = data
        return d

    sig = [conv(x) for x in old['signal']]
    sig = [x for x in sig if x]
    return {'signal': sig, 'head': {'text': old['head']['text']}, 'foot': {'text': foot}, 'config': {'hscale': 1}}


SKILL = os.path.join(os.path.expanduser('~'), '.claude', 'skills', 'vlsit-asic-ip-microspec', 'scripts', 'vlsit_waveform_svg.py')
HDS = os.path.join(os.path.dirname(HERE), 'VLSIT_DIGITAL_SIGNATURE_HDS.md')


def fits(path):
    r = subprocess.run([sys.executable, SKILL, 'check', path], capture_output=True, text=True)
    return r.returncode == 0


def update_md(stem, doc):
    """Replaces the wavedrom block that follows the image link of the figure in the HDS."""
    text = open(HDS, encoding='utf-8').read()
    link = '](figures/%s.svg)' % stem
    # the figure link of the section 10.3.1 is followed by the wavedrom block
    pos = [i for i in range(len(text)) if text.startswith(link, i)]
    done = 0
    for i in pos:
        j = text.find('```wavedrom', i)
        k = text.find('```', j + 11)
        if j == -1 or k == -1 or j - (i + len(link)) > 4:
            continue
        text = text[:j] + '```wavedrom' + chr(10) + json.dumps(doc, indent=1) + chr(10) + text[k:]
        done += 1
        break
    open(HDS, 'w', encoding='utf-8').write(text)
    return done


def main():
    for stem, (n, anchor, aslot, drop, foot) in CFG.items():
        doc = build(stem, n, anchor, aslot, drop, foot)
        path = os.path.join(HERE, stem + '.json')
        for hs in (1, 2, 3, 4, 5):
            doc['config'] = {'hscale': hs}
            json.dump(doc, open(path, 'w', encoding='utf-8'), indent=1)
            if fits(path):
                break
        subprocess.run([sys.executable, SKILL, 'render', path, '--out', os.path.join(HERE, stem + '.svg'), '--force'],
                       capture_output=True, text=True)
        print('written', stem, 'hscale', hs, 'fits', fits(path), 'md blocks', update_md(stem, doc))


if __name__ == '__main__':
    sys.exit(main())
