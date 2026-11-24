"""Builds wf_018_block_pair.json, wf_019_pair_freeze.json and wf_020_block_pair_base.json from the traces of tb_pair.sv (scratch).
Traces: iverilog tb_pair.sv with -P tb_pair.CNT=3 -P tb_pair.TAKE_FROM=0 -P tb_pair.NCYC=52 and
CNT=4 TAKE_FROM=60 NCYC=72; for trace_wf020.txt add -P tb_pair.QN=4 -P tb_pair.RC=1 with CNT=2 TAKE_FROM=0 NCYC=48; keep the lines that start with S.  Render with vlsit_waveform_svg.py render.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', '..', 'spec', 'figures')
STATE = {'0': 'IDLE', '1': 'LDB', '2': 'RUN'}


def parse(path, lo, hi):
    rows = []
    for line in open(path):
        if not line.startswith('S '):
            continue
        d = dict(kv.split('=') for kv in line.split()[1:])
        c = int(d['c'])
        if lo <= c <= hi:
            rows.append(d)
    return rows


def digital(rows, key):
    out = ''
    prev = None
    for r in rows:
        v = r[key]
        out += '.' if v == prev else v
        prev = v
    return out


def bus(rows, fn):
    out = ''
    data = []
    prev = None
    for r in rows:
        v = fn(r)
        if v is None:
            tok = 'x'
            out += '.' if prev == 'x' else 'x'
            prev = 'x'
        elif v == prev:
            out += '.'
        else:
            out += '='
            data.append(v)
            prev = v
    return out, data


def build(rows, head, foot, name):
    n = len(rows)
    sig = [{'name': 'i_clk_core', 'wave': 'p' + '.' * (n - 1)}]
    sig.append({'name': 'i_load', 'wave': digital(rows, 'load')})
    w, d = bus(rows, lambda r: STATE[r['st']] if r['st'] in STATE else None)
    sig.append({'name': 'reg_fsm_blk_current_state', 'wave': w, 'data': d})
    sig.append({'name': 'reg_ph', 'wave': digital(rows, 'ph')})
    w, d = bus(rows, lambda r: r['left'])
    sig.append({'name': 'reg_left', 'wave': w, 'data': d})
    sig.append({'name': 'w_stall', 'wave': digital(rows, 'stall')})
    sig.append({'name': 'w_dlv', 'wave': digital(rows, 'dlv')})
    sig.append(['queue', {'name': 'reg_q0_v', 'wave': digital(rows, 'q0v')}, {'name': 'reg_q1_v', 'wave': digital(rows, 'q1v')}])
    w, d = bus(rows, lambda r: 'c' + r['ctr0'] if r['q0v'] == '1' else None)
    sig[-1].append({'name': 'reg_q0_ctr', 'wave': w, 'data': d})
    sig.append(['consumer', {'name': 'o_blk_vld', 'wave': digital(rows, 'vld')}, {'name': 'i_take', 'wave': digital(rows, 'take')}])
    doc = {'signal': sig, 'head': {'text': head}, 'foot': {'text': foot}, 'config': {'hscale': 1}}
    open(os.path.join(OUT, name + '.json'), 'w', encoding='utf8').write(json.dumps(doc, indent=1) + '\n')
    return doc


base = HERE
r18 = parse(os.path.join(base, 'trace_wf018.txt'), 0, 47)
build(r18,
      'PARA_PIPE_CHACHA = 1: three blocks, a pair and a block without a partner (QN = 4, RC = 2)',
      'Cycle 0 is the load. Block 0 and block 1 (a pair) run through the ring with reg_ph = 0 for block 0 and 1 for block 1; the pair is delivered in the cycle in which w_dlv is high (cycle 21 = 2 * 10 + 1 after the load) and both blocks are in the queue in the next cycle (reg_q0_v, reg_q1_v), the next pair is loaded in the same edge. Block 2 has no partner and takes the same 21 cycles as a pair. Measured with the RTL, the consumer takes a block as soon as it is valid',
      'wf_018_block_pair')
r19 = parse(os.path.join(base, 'trace_wf019.txt'), 38, 66)
build(r19,
      'PARA_PIPE_CHACHA = 1: the ring freezes while the queue cannot take the next pair (QN = 4, RC = 2)',
      'Excerpt of cycles 38 to 66 of a message of four blocks; the consumer takes the first block of the first pair in cycle 60 and the second in cycle 61. The second pair is ready in cycle 42, but the queue holds both blocks of the first pair, so w_stall is high and reg_left, reg_ph and the ring registers hold; in cycle 61 the second block is taken, the queue is empty after that take (a pair needs both entries free) and w_dlv is high in cycle 61. Measured with the RTL',
      'wf_019_pair_freeze')
r20 = parse(os.path.join(base, 'trace_wf020.txt'), 0, 46)
build(r20,
      'PARA_PIPE_CHACHA = 1 on the CFG-BASE core: the key block and the first data block form one pair (QN = 4, RC = 1)',
      'Cycle 0 is the load of a message with one data block, so the blocks are block 0 (the Poly1305 one-time key) and block 1. With one round per cycle a block needs 20 iterations of two cycles; the pair is delivered in cycle 41 (2 * 20 + 1 after the load), against 20 cycles for the key block alone without the option, and both blocks are in the queue in cycle 42. Measured with the RTL, the consumer takes a block as soon as it is valid',
      'wf_020_block_pair_base')
print(len(r18), len(r19))
