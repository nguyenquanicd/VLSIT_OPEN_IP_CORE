#!/usr/bin/env python3
"""Rewrap the Description block of the file header and long // comment lines to 96 columns."""
import re, sys, textwrap

W = 96

def rewrap(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    out = []
    i = 0
    # header description
    while i < len(lines):
        ln = lines[i]
        if ln.startswith(' * Description  :'):
            block = [ln[len(' * Description  :'):].strip()]
            i += 1
            while i < len(lines) and lines[i].startswith(' *') and lines[i].strip() != '*/':
                block.append(lines[i][2:].strip())
                i += 1
            text = ' '.join(b for b in block if b)
            wrapped = textwrap.wrap(text, width=W - 17)
            out.append(' * Description  : ' + wrapped[0])
            for w in wrapped[1:]:
                out.append(' *                ' + w)
            continue
        m = re.match(r'^(\s*)// (.*)$', ln)
        if m and len(ln) > 100:
            # wrap a long // comment, continuing lines with the same indent
            ind = m.group(1)
            wrapped = textwrap.wrap(m.group(2), width=W - len(ind) - 3)
            for w in wrapped:
                out.append(f'{ind}// {w}')
            i += 1
            continue
        out.append(ln)
        i += 1
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))

for p in sys.argv[1:]:
    rewrap(p)
