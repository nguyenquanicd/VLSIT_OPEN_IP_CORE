"""Structural clock-domain-crossing check of the CSR of the digital signature IP (the only block with two clocks, section 7.2)
with yosys and a graph walk. It is not a CDC sign-off tool (no Spyglass, Questa CDC or VC CDC is available); it checks the
structure that CDC_RDC_NOTES.md describes, on the real RTL:

  1. m_vlsit_csr_dsig is read with PARA_ASYNCHRONOUS = 1 and VLSIT_SYNTHESIS (the synchronizer cells VLSIT_CELL_SYNC_* are
     kept as black boxes), flattened, and written as a JSON netlist.
  2. Every flip-flop gets the domain of its clock net (i_clk_apb or i_clk_reg); every synchronizer cell the domain of CK.
     Input ports: the APB bus pins are in the APB domain, i_protect_en and i_slverr_en are static, every other input (field
     values from the IP) is in the register domain.
  3. For every flip-flop and synchronizer input, the combinational fan-in is walked back to flip-flops, synchronizer outputs
     and ports. A source of the other domain is a crossing. A crossing is accepted when
       - the destination is a synchronizer cell and its D pin is driven directly by one flip-flop (no logic, no glitch); or
       - the destination is a flip-flop whose enable or a multiplexer select on the path is driven (through logic) by a
         synchronizer output of the destination domain (bundled data qualified by the handshake).
     Any other crossing is reported as a violation.
Usage: python check_cdc.py   (prints one line per crossing, a summary and RESULT)"""
import json
import os
import subprocess
import sys
from collections import defaultdict

V = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')).replace(chr(92), '/')
IP = os.path.dirname(V)
R = IP + '/rtl'
CELLS = os.path.normpath(IP + '/../000_Common/rtl_cells').replace(chr(92), '/')
LIB = os.path.normpath(IP + '/../000_Common/rtl_lib').replace(chr(92), '/')
S = V + '/sim/cdc'
YOSYS = 'C:/Tools/oss-cad-suite/bin/yosys.exe'
FF = {'$dff', '$adff', '$dffe', '$adffe', '$sdff', '$sdffe', '$sdffce', '$dffsr', '$dffsre', '$aldff', '$aldffe'}
STATIC = {'i_protect_en', 'i_slverr_en'}


def netlist(csr, out):
    os.makedirs(out, exist_ok=True)
    cells = ' '.join('%s/VLSIT_CELL_SYNC_%s.sv' % (CELLS, t) for t in ('2FF_RN', '2FF_SN', '3FF_RN', '3FF_SN', '4FF_RN', '4FF_SN',
                                                                       'DFF_RN', 'DFF_SN'))
    script = ('read_verilog -sv -lib %s; read_verilog -sv -DVLSIT_SYNTHESIS %s/m_vlsit_afifo_cell_sync.sv %s/csr/m_vlsit_csr_sync.sv '
              '%s; chparam -set PARA_ASYNCHRONOUS 1 m_vlsit_csr_dsig; hierarchy -top m_vlsit_csr_dsig; '
              'proc; flatten; opt_clean; opt -nodffe -nosdff; opt_dff; opt_clean; write_json %s/csr.json' % (cells, LIB, R, csr, out))
    env = dict(os.environ)
    env['PATH'] = 'C:/Tools/oss-cad-suite/bin;C:/Tools/oss-cad-suite/lib;' + env.get('PATH', '')
    r = subprocess.run([YOSYS, '-q', '-l', out + '/yosys.log', '-p', script], capture_output=True, text=True, env=env, timeout=1800)
    if r.returncode != 0:
        print(r.stdout[-2000:] + r.stderr[-2000:])
        raise SystemExit('RESULT: FAIL (yosys)')
    return json.load(open(out + '/csr.json'))


def check(csr, out, quiet=False):
    nl = netlist(csr, out)
    mod = nl['modules']['m_vlsit_csr_dsig']
    ports = mod['ports']
    names = {}
    for n, d in mod['netnames'].items():
        for b in d['bits']:
            if isinstance(b, int) and (b not in names or len(n) < len(names[b])):
                names[b] = n
    clk_apb = ports['i_clk_apb']['bits'][0]
    clk_reg = ports['i_clk_reg']['bits'][0]
    dom_of_clk = {clk_apb: 'APB', clk_reg: 'REG'}
    driver = {}                 # bit -> (kind, cell name or port)
    port_dom = {}
    for pn, p in ports.items():
        if p['direction'] != 'input':
            continue
        dom = 'STATIC' if pn in STATIC else ('APB' if pn.startswith('i_apb_') else 'REG')
        if pn in ('i_clk_apb', 'i_clk_reg', 'i_rst_n_apb', 'i_rst_n_reg'):
            dom = 'CLOCK/RESET'
        for b in p['bits']:
            if isinstance(b, int):
                driver[b] = ('port', pn)
                port_dom[b] = dom
    seq = {}                    # cell -> (domain, kind)
    for cn, c in mod['cells'].items():
        t = c['type']
        dirs = c.get('port_directions', {})
        if t in FF:
            seq[cn] = (dom_of_clk.get(c['connections']['CLK'][0], 'UNKNOWN'), 'ff')
        elif t.startswith('VLSIT_CELL_SYNC'):
            seq[cn] = (dom_of_clk.get(c['connections']['CK'][0], 'UNKNOWN'), 'sync')
        for pin, bits in c['connections'].items():
            if dirs.get(pin) == 'output':
                for b in bits:
                    if isinstance(b, int):
                        driver[b] = ('cell', cn)
    cells = mod['cells']

    def walk(bits):
        """Combinational fan-in of the bits: (set of source (kind, name, bit)), set of control bits, number of logic cells)."""
        srcs, ctrl, seen, ncomb = set(), set(), set(), 0
        stack = [b for b in bits if isinstance(b, int)]
        while stack:
            b = stack.pop()
            if b in seen:
                continue
            seen.add(b)
            d = driver.get(b)
            if d is None:
                continue
            if d[0] == 'port':
                srcs.add(('port', d[1], b))
                continue
            cn = d[1]
            if cn in seq:
                srcs.add((seq[cn][1], cn, b))
                continue
            ncomb += 1
            c = cells[cn]
            for pin, pb in c['connections'].items():
                if c.get('port_directions', {}).get(pin) == 'input':
                    if c['type'] in ('$mux', '$pmux') and pin == 'S':
                        ctrl.update(x for x in pb if isinstance(x, int))
                    stack.extend(x for x in pb if isinstance(x, int))
        return srcs, ctrl, ncomb

    def src_dom(s):
        kind, name, b = s
        return port_dom.get(b, 'REG') if kind == 'port' else seq[name][0]

    sync_out = {}               # bit -> domain of the synchronizer output
    for cn, (dom, kind) in seq.items():
        if kind == 'sync':
            for b in cells[cn]['connections']['Q']:
                sync_out[b] = dom

    def qualified(ctrl_bits, dom):
        srcs, _, _ = walk(list(ctrl_bits))
        return sorted({names.get(b, str(b)) for k, n, b in srcs if k == 'sync' and seq[n][0] == dom})

    groups = defaultdict(list)
    nviol = 0
    for cn, (dom, kind) in sorted(seq.items()):
        c = cells[cn]
        dpin = 'D'
        dbits = c['connections'][dpin]
        en = c['connections'].get('EN', [])
        srcs, ctrl, ncomb = walk(dbits)
        if en:
            ctrl.update(b for b in en if isinstance(b, int))
            es, _, _ = walk(en)
            srcs |= es
        cross = sorted({(names.get(b, str(b)), src_dom(s)) for s in srcs for b in [s[2]]
                        if src_dom(s) not in (dom, 'STATIC', 'CLOCK/RESET')})
        if not cross:
            continue
        dname = names.get(c['connections']['Q'][0], cn)
        if kind == 'sync':
            ok = ncomb == 0 and len(srcs) == 1
            verdict = 'synchronizer, driven directly by one flip-flop' if ok else 'VIOLATION: logic before the synchronizer'
        else:
            q = qualified(ctrl, dom)
            ok = bool(q)
            verdict = ('bundled data qualified by %s' % ', '.join(q)) if ok else 'VIOLATION: crossing without a synchronized qualifier'
        nviol += not ok
        key = (dom, kind, verdict, tuple(sorted({s[0].rstrip('0123456789[] ') for s in cross})))
        groups[key].append(dname)
    lines = []
    for (dom, kind, verdict, srcn), dsts in sorted(groups.items()):
        lines.append('%-3s <- %s : %d %s (%s ...) from %s' % (dom, verdict, len(dsts), 'synchronizer cells' if kind == 'sync'
                                                             else 'flip-flop cells', ', '.join(sorted(set(dsts))[:3]), ', '.join(srcn)[:120]))
    # reset domains: every flip-flop and synchronizer is reset by the reset of its own clock domain (RDC structure)
    rst = {'APB': ports['i_rst_n_apb']['bits'][0], 'REG': ports['i_rst_n_reg']['bits'][0]}
    nrdc = 0
    for cn, (dom, kind) in seq.items():
        conn = cells[cn]['connections']
        r = conn.get('ARST', conn.get('RN', conn.get('SN', [None])))[0]
        if dom in rst and r is not None and r != rst[dom]:
            nrdc += 1
            lines.append('%s <- RDC VIOLATION: %s is reset by %s' % (dom, names.get(conn.get('Q', [0])[0], cn), names.get(r, str(r))))
    nviol += nrdc
    nsync = sum(1 for d, k in seq.values() if k == 'sync')
    if not quiet:
        print('check_rdc: %d flip-flop and synchronizer cells checked against the reset of their clock domain, %d violations' %
              (len(seq), nrdc))
        for l in lines:
            print(l)
        print('check_cdc: %d flip-flop cells, %d synchronizer cells, %d crossing groups, %d violations' %
              (sum(1 for d, k in seq.values() if k == 'ff'), nsync, len(groups), nviol))
    return nviol, nsync, [l for l in lines if 'VIOLATION' in l]


# Mutants of the checker: each puts one CDC defect into a copy of the CSR; the check must report a violation.
MUTANTS = [
    ('C1 logic before a synchronizer', ".i_d         (reg_wr_req),", ".i_d         (reg_wr_req & i_apb_psel),"),
    ('C2 register write enabled by an APB-domain signal', "assign w_wr_en  = ~reg_wr_req_reg_dly & w_wr_req_reg;",
     "assign w_wr_en  = i_apb_penable;"),
    ('C3 register-side flip-flop reset by the APB reset', "        .i_rst_n_dst (i_rst_n_reg),\n        .i_d         (reg_wr_req),",
     "        .i_rst_n_dst (i_rst_n_apb),\n        .i_d         (reg_wr_req),"),
]


def main():
    nviol, nsync, _ = check(R + '/csr/m_vlsit_csr_dsig.sv', S)
    src = open(R + '/csr/m_vlsit_csr_dsig.sv', encoding='utf-8').read()
    caught = 0
    for name, old, new in MUTANTS:
        assert src.count(old) == 1, name
        d = S + '/mut_' + name[:2]
        os.makedirs(d, exist_ok=True)
        open(d + '/m_vlsit_csr_dsig.sv', 'w', encoding='utf-8').write(src.replace(old, new))
        mv, _, viol = check(d + '/m_vlsit_csr_dsig.sv', d, quiet=True)
        caught += mv > 0
        print('mutant %s: %s %s' % (name, 'CAUGHT' if mv else 'NOT CAUGHT', (viol[0][:110] if viol else '')))
    print('check_cdc mutants: %d of %d caught' % (caught, len(MUTANTS)))
    ok = nviol == 0 and nsync == 4 and caught == len(MUTANTS)
    print('RESULT: %s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
