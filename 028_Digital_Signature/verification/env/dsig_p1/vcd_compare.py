"""Compare a simulated VCD scenario with a waveform figure of the specification (R-033, R-088).

For the WaveJSON figure of the specification (one character per clock cycle) it
  1. reads the VCD dump of the scenario (signals named like the figure),
  2. finds the window of clock cycles that agrees best with the figure (the figure is a window of the
     scenario, its start is not known),
  3. writes the simulated window as WaveJSON with the same signal rows, groups and slot grid, and
  4. reports MATCH (every row and slot agrees) or DIFFERENT with the list of the differences.
A slot written 'x' in the figure is not compared. A data slot ('=') is compared when its label is a
number or a state name; other labels (W0, W1) are only checked to be a known (not X) value.

Usage: python vcd_compare.py FIGURE.json DUMP.vcd OUT_STEM [--clock i_clk_core]
Writes OUT_STEM.json and prints one result line; appends the result to OUT_STEM_dir/_results.jsonl.
Not part of the RTL.
"""
import argparse
import copy
import json
import os
import sys

STATES = {'ENUM_ST_IDLE': 0, 'ENUM_ST_CHECK': 1, 'ENUM_ST_KEY': 2, 'ENUM_ST_RNG': 3, 'ENUM_ST_RUN': 4,
          'ENUM_ST_VAS': 5, 'ENUM_ST_RESULT': 6, 'ENUM_ST_CLEAR': 7, 'ENUM_ST_ERR': 8}
NAMES = {v: k for k, v in STATES.items()}
SYMBOLS = {'WIN_WR': 0x94, 'WIN_RD': 0x98}


def parse_vcd(path):
    ids = {}        # id -> (name, width)
    changes = {}    # name -> list of (time, value string)
    t = 0
    scale = 1
    with open(path, encoding='utf-8', errors='replace') as f:
        text = f.read().split()
    i = 0
    n = len(text)
    while i < n:
        tok = text[i]
        if tok == '$timescale':
            j = i + 1
            parts = []
            while text[j] != '$end':
                parts.append(text[j]); j += 1
            s = ''.join(parts)
            num = ''.join(c for c in s if c.isdigit())
            unit = ''.join(c for c in s if c.isalpha())
            scale = int(num) * {'s': 10**12, 'ms': 10**9, 'us': 10**6, 'ns': 1000, 'ps': 1, 'fs': 0.001}[unit]
            i = j
        elif tok == '$var':
            width = int(text[i + 2]); vid = text[i + 3]; name = text[i + 4]
            ids.setdefault(vid, []).append((name, width))
            changes.setdefault(name, [])
            j = i
            while text[j] != '$end':
                j += 1
            i = j
        elif tok.startswith('#'):
            t = int(tok[1:]) * scale
        elif tok[0] in 'bB':
            val = tok[1:]; vid = text[i + 1]; i += 1
            for name, _ in ids.get(vid, []):
                changes[name].append((t, val))
        elif tok[0] in '01xXzZ' and len(tok) > 1 and not tok.startswith('$'):
            for name, _ in ids.get(tok[1:], []):
                changes[name].append((t, tok[0].lower()))
        i += 1
    widths = {}
    for vid, lst in ids.items():
        for name, w in lst:
            widths[name] = w
    return changes, widths


def value_at(lst, t):
    v = None
    for tt, val in lst:
        if tt <= t:
            v = val
        else:
            break
    return v


def decode_wave(sig):
    wave = sig['wave']
    data = list(sig.get('data', []))
    di = 0
    out = []
    prev = None
    for ch in wave:
        if ch == '.':
            out.append(prev)
            continue
        if ch in '01':
            prev = ('b', int(ch))
        elif ch in 'lh':
            prev = ('b', 0 if ch == 'l' else 1)
        elif ch == '=':
            lab = data[di] if di < len(data) else ''
            di += 1
            prev = ('d', lab)
        else:
            prev = ('x', None)
        out.append(prev)
    return out


def label_num(lab):
    if lab in STATES:
        return STATES[lab]
    if lab in SYMBOLS:
        return SYMBOLS[lab]
    try:
        return int(lab, 0)
    except ValueError:
        return None


def flatten(sig_list, out):
    for s in sig_list:
        if isinstance(s, list):
            flatten(s[1:], out)
        elif isinstance(s, dict) and 'name' in s:
            out.append(s)


def to_int(v):
    if v is None or any(c in v for c in 'xXzZ'):
        return None
    return int(v, 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('figure')
    ap.add_argument('vcd')
    ap.add_argument('out')
    ap.add_argument('--clock', default='i_clk_core')
    ap.add_argument('--anchor', default='', help='signal whose first rising edge fixes the window start')
    a = ap.parse_args()
    fig = json.load(open(a.figure, encoding='utf-8'))
    changes, widths = parse_vcd(a.vcd)
    sigs = []
    flatten(fig['signal'], sigs)
    clk = changes.get(a.clock, [])
    edges = [t for (t, v), (tp, vp) in zip(clk[1:], clk[:-1]) if v == '1' and vp == '0']
    nslot = max(len(s['wave']) for s in sigs)
    rows = []
    missing = []
    for s in sigs:
        if s['name'] == a.clock or s['wave'][0] in 'pPnN':
            continue
        if s['name'] not in changes or not changes[s['name']]:
            missing.append(s['name'])
            continue
        rows.append((s, decode_wave(s)))

    def sample(name, k, e0):
        idx = e0 + k + 1
        if idx >= len(edges):
            return None
        return value_at(changes[name], edges[idx] - 1)

    best = None
    anchor_e0 = None
    if a.anchor and a.anchor in changes:
        fexp = [x for s, x in rows if s['name'] == a.anchor]
        if fexp:
            sf = None
            for k in range(1, len(fexp[0])):
                if fexp[0][k] == ('b', 1) and fexp[0][k - 1] == ('b', 0):
                    sf = k
                    break
            if sf is not None:
                for j in range(1, len(edges) - 1):
                    v0 = value_at(changes[a.anchor], edges[j] - 1)
                    v1 = value_at(changes[a.anchor], edges[j + 1] - 1)
                    if v0 == '0' and v1 == '1':
                        anchor_e0 = max(0, j - sf + 1 - 1) if False else max(0, (j) - sf)
                        break
    cand = [anchor_e0] if anchor_e0 is not None else range(0, max(1, len(edges) - nslot - 1))
    for e0 in cand:
        tot = 0; ok = 0; act = 0
        for s, exp in rows:
            if len(set(x for x in exp if x is not None)) < 2:
                continue    # a row that never changes does not fix the position of the window
            prevv = None
            for k, ex in enumerate(exp):
                v = sample(s['name'], k, e0)
                if prevv is not None and v != prevv:
                    act += 1
                prevv = v
                if ex is None or ex[0] == 'x':
                    continue
                tot += 1
                if ex[0] == 'b':
                    if v is not None and v[-1] in '01' and int(v[-1]) == ex[1]:
                        ok += 1
                else:
                    num = label_num(ex[1])
                    got = to_int(v)
                    if num is None:
                        if got is not None:
                            ok += 1
                    elif got == num:
                        ok += 1
        score = (ok / tot if tot else 0.0, act)
        if best is None or score > best[0]:
            best = (score, e0, ok, tot)
    if best is None:
        print('NO WINDOW: the dump has too few clock edges')
        return 2
    score, e0, ok, tot = best
    # slots compared in the whole figure at the chosen window
    ok = 0; tot = 0
    for s, exp in rows:
        for k, ex in enumerate(exp):
            if ex is None or ex[0] == 'x':
                continue
            tot += 1
            v = sample(s['name'], k, e0)
            if ex[0] == 'b':
                ok += 1 if (v is not None and v[-1] in '01' and int(v[-1]) == ex[1]) else 0
            else:
                num = label_num(ex[1]); got = to_int(v)
                ok += 1 if ((got == num) if num is not None else (got is not None)) else 0
    # differences at the best window
    diffs = []
    for s, exp in rows:
        for k, ex in enumerate(exp):
            if ex is None or ex[0] == 'x':
                continue
            v = sample(s['name'], k, e0)
            if ex[0] == 'b':
                good = v is not None and v[-1] in '01' and int(v[-1]) == ex[1]
                expt = str(ex[1])
            else:
                num = label_num(ex[1])
                got = to_int(v)
                good = (got == num) if num is not None else (got is not None)
                expt = ex[1] if num is None else '%s(%d)' % (ex[1], num)
            if not good:
                gv = to_int(v)
                diffs.append('%s slot %d expected %s got %s' % (s['name'], k, expt,
                             ('0x%X' % gv) if gv is not None and widths.get(s['name'], 1) > 1 else (v if v is not None else 'none')))
    # simulated WaveJSON with the same rows and grid
    sim = copy.deepcopy(fig)
    rows_by_name = {}
    flat = []
    flatten(sim['signal'], flat)
    for s in flat:
        rows_by_name[s['name']] = s
        if s['name'] in missing:
            s['wave'] = 'x' * len(s['wave'])
            s.pop('data', None)
            continue
        if s['name'] == a.clock or s['wave'][0] in 'pPnN':
            continue
        w = widths.get(s['name'], 1)
        wave = ''
        data = []
        prev = None
        for k in range(len(s['wave'])):
            v = sample(s['name'], k, e0)
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
                if s['name'] == 'reg_fsm_ctl_current_state':
                    data.append(NAMES.get(num, 'STATE_%d' % num))
                elif s['name'] == 'o_reg_wr_addr':
                    data.append('WIN_WR' if num == 0x94 else '0x%X' % num)
                else:
                    data.append('0x%X' % num)
            prev = key
            wave += ch
        s['wave'] = wave
        if data:
            s['data'] = data
        else:
            s.pop('data', None)
    head = sim.setdefault('head', {})
    head['text'] = (head.get('text', '') + ' (simulated)').strip()
    foot = sim.setdefault('foot', {})
    foot['text'] = ('Simulated by tb_dsig_p1 from dump %s, window from clock edge %d; ' % (os.path.basename(a.vcd), e0)) + \
                   ('MATCH with the figure of the specification.' if not diffs else 'DIFFERENT from the figure of the specification.')
    with open(a.out + '.json', 'w', encoding='utf-8') as f:
        json.dump(sim, f, indent=1)
    res = {'figure': os.path.basename(a.figure), 'window_edge': e0, 'compared': tot, 'matched': ok,
           'missing_signals': missing, 'result': 'MATCH' if (not diffs and tot > 0) else 'DIFFERENT',
           'differences': diffs}
    with open(os.path.join(os.path.dirname(os.path.abspath(a.out)), '_results.jsonl'), 'a', encoding='utf-8') as f:
        f.write(json.dumps(res) + '\n')
    print('%s: %s (%d of %d compared slots agree, window from edge %d, missing signals: %s)' %
          (os.path.basename(a.figure), res['result'], ok, tot, e0, ','.join(missing) or 'none'))
    for d in diffs[:12]:
        print('   ', d)
    if len(diffs) > 12:
        print('    ... %d more' % (len(diffs) - 12))
    return 0


if __name__ == '__main__':
    sys.exit(main())
