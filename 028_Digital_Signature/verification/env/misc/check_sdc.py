"""Static check of sdc/m_vlsit_dsig_top.sdc against the RTL (no timing tool in this environment): every port of
m_vlsit_dsig_top is constrained (a clock, an input delay or an output delay), every get_ports pattern matches at least one
port, inputs only get input delays and outputs only output delays, and the two clocks of section 17.1.1 exist.
Usage: python check_sdc.py"""
import fnmatch
import os
import re
import sys

IP = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')).replace(chr(92), '/')


def ports():
    t = open(IP + '/rtl/m_vlsit_dsig_top.sv', encoding='utf-8').read()
    body = t[t.index(') (', t.index('module m_vlsit_dsig_top')):t.index(');', t.index('module m_vlsit_dsig_top'))]
    return {m.group(2): m.group(1) for m in re.finditer(r'^\s*(input|output)\s+(?:wire|logic)\s*(?:\[[^\]]*\])?\s*(\w+)', body, re.M)}


def main():
    p = ports()
    sdc = open(IP + '/sdc/m_vlsit_dsig_top.sdc', encoding='utf-8').read()
    nfail = 0
    covered = {}
    for cmd, pats in re.findall(r'^\s*(create_clock|create_generated_clock|set_input_delay|set_output_delay)\b.*?\[get_ports \{?([^\]}]+)\}?\]\s*$',
                                sdc, re.M):
        for pat in pats.split():
            hit = [q for q in p if fnmatch.fnmatch(q, pat)]
            if not hit:
                nfail += 1
                print('FAIL: %s pattern %s matches no port' % (cmd, pat))
            for q in hit:
                covered.setdefault(q, set()).add(cmd)
                if cmd == 'set_input_delay' and p[q] != 'input' or cmd == 'set_output_delay' and p[q] != 'output':
                    nfail += 1
                    print('FAIL: %s on %s port %s' % (cmd, p[q], q))
    for q in p:
        if q not in covered:
            nfail += 1
            print('FAIL: port %s has no constraint' % q)
    for clk in ('CLK_CORE', 'CLK_APB'):
        if not re.search(r'-name %s\b' % clk, sdc):
            nfail += 1
            print('FAIL: clock %s not created' % clk)
    if 'set_clock_groups' in re.sub(r'#.*', '', sdc):
        nfail += 1
        print('FAIL: set_clock_groups would override the max_delay of the bundled CSR data')
    print('check_sdc: %d ports, %d constrained, %d failures' % (len(p), len(covered), nfail))
    print('RESULT: %s' % ('PASS' if nfail == 0 else 'FAIL'))
    return nfail


if __name__ == '__main__':
    sys.exit(1 if main() else 0)
