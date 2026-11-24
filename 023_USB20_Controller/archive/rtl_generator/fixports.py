#!/usr/bin/env python3
"""Align the port list of SystemVerilog modules to rule FIL-05 (helper of the RTL flow).

Usage: fixports.py file.sv [file.sv ...]
Each port line "  input wire [W-1:0] i_name," inside the port list is rewritten with the columns
keyword, type, width and name, each column as narrow as its longest entry in the file's port list.
Comment lines and blank lines are kept as they are.
"""
import re
import sys

PORT = re.compile(r'^\s*(input|output|inout)\s+(wire|logic|reg)\s*(\[[^\]]*\](?:\s*\[[^\]]*\])*)?\s*(\w+)\s*(,?)\s*(//.*)?$')


def fix(path):
    text = open(path, encoding='utf-8').read()
    lines = text.split('\n')
    # port list: from the line ') (' to the line ');'
    start = None
    end = None
    for i, ln in enumerate(lines):
        if start is None and ln.strip() == ') (':
            start = i
        elif start is not None and ln.strip() == ');':
            end = i
            break
    if start is None or end is None:
        return False
    rows = []
    for i in range(start + 1, end):
        m = PORT.match(lines[i])
        if m:
            rows.append((i, m.group(1), m.group(2), (m.group(3) or '').replace(' ', ''), m.group(4), m.group(5), m.group(6)))
    if not rows:
        return False
    kw = max(len(r[1]) for r in rows)
    ty = max(len(r[2]) for r in rows)
    wd = max(len(r[3]) for r in rows)
    for (i, k, t, w, n, c, cm) in rows:
        parts = f'  {k:<{kw}} {t:<{ty}} '
        if wd:
            parts += f'{w:<{wd}} '
        line = parts + n + c
        if cm:
            line += ' ' + cm
        lines[i] = line.rstrip()
    new = '\n'.join(lines)
    if new != text:
        open(path, 'w', encoding='utf-8', newline='\n').write(new)
        return True
    return False


if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(('fixed ' if fix(p) else 'same  ') + p)
