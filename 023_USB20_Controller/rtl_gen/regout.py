#!/usr/bin/env python3
"""Turn output ports that are assigned in always_ff into reg_<name> flops plus an assign.

Usage: regout.py file.sv
For every output port o_<name> that appears on the left of '<=' inside the file, the '<=' targets
are renamed reg_<name>, a declaration with the width of the port is added before the first
'always' or 'assign' line after the port list, and 'assign o_<name> = reg_<name>;' lines are added
before 'endmodule'.
"""
import re, sys

def run(path):
    text = open(path, encoding='utf-8').read()
    lines = text.split('\n')
    # port declarations
    ports = {}
    for ln in lines:
        m = re.match(r'^\s*output\s+(?:logic|wire|reg)\s*(\[[^\]]*\](?:\s*\[[^\]]*\])*)?\s*(o_\w+)', ln)
        if m:
            ports[m.group(2)] = (m.group(1) or '').replace(' ', '')
    targets = []
    for name in ports:
        pat = re.compile(r'\b' + name + r'\s*<=')
        if any(pat.search(l) for l in lines):
            targets.append(name)
    if not targets:
        return
    new = []
    for l in lines:
        for name in targets:
            l = re.sub(r'\b' + name + r'(\s*<=)', 'reg_' + name[2:] + r'\1', l)
        new.append(l)
    # find insertion point: first line index of 'always' or 'assign' or a comment before it, after ');'
    idx = None
    for i, l in enumerate(new):
        if l.strip() == ');':
            idx = i
            break
    # insert declarations right after the first line that starts the internal declarations
    decl = []
    for name in targets:
        w = ports[name]
        decl.append(f'  logic {w + " " if w else ""}reg_{name[2:]};')
    # place after the last 'logic' declaration line before first always/assign, else after ');'
    ins = idx + 1
    for i in range(idx + 1, len(new)):
        s = new[i].strip()
        if s.startswith('always') or s.startswith('assign') or s.startswith('m_') or s.startswith('function'):
            break
        if re.match(r'^(logic|ulpi_state|\w+_type_def|typedef|localparam)\b', s) or s.endswith(';'):
            ins = i + 1
    new[ins:ins] = decl
    # assigns before endmodule
    for i in range(len(new) - 1, -1, -1):
        if new[i].strip() == 'endmodule':
            assigns = [f'  assign {n} = reg_{n[2:]};' for n in targets]
            new[i:i] = ['  // Registered outputs.'] + assigns + ['']
            break
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(new))

for p in sys.argv[1:]:
    run(p)
