"""Post-processing of the generated ROM modules so that they meet the file rules of the RTL design rule (header, port group
comment, aligned ports, defaults in the combinational processes). Called at the end of gen_ec_rom.py, gen_hbs_rom.py and
gen_lat_rom.py: python rom_postfix.py <file.sv>."""
import re
import sys

PROJECT = 'VLSIT Common RTL library'
AUTHOR = 'Nguyen Quan and Claude Sonnet 5.5 (user)'
DATE = '2026-11-25'


def wrap(text, first, cont, width=97):
    words = text.split()
    lines, cur = [], first
    for w in words:
        if len(cur) + len(w) + (0 if cur.endswith(' ') else 1) > width:
            lines.append(cur.rstrip())
            cur = cont + w
        else:
            cur += (w if cur.endswith(' ') else ' ' + w)
    lines.append(cur.rstrip())
    return lines


def finish(path):
    t = open(path, encoding='utf-8').read()
    lines = t.split('\n')
    j = next(k for k, l in enumerate(lines) if l.strip() == '*/')
    desc = ' '.join(re.sub(r'^\s*\*?\s*', '', l) for l in lines[1:j]).replace('/*', '').strip()
    head = ['/*', ' * Project      : ' + PROJECT, ' * Author       : ' + AUTHOR, ' * AI Flow      : VLSIT RTL Generator AI Automation Flow',
            ' * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model', ' * Date         : ' + DATE]
    head += wrap(desc, ' * Description  : ', ' *                ') + [' */']
    lines = head + lines[j + 1:]
    # group comment at the start of the port list
    k = next(i for i, l in enumerate(lines) if l.startswith('module '))
    lines.insert(k + 1, '  // Lookup ports')
    t = '\n'.join(lines)
    # widths of the output ports
    widths = {}
    for m in re.finditer(r'output\s+logic\s*(\[(\d+):0\])?\s+(\w+)', t):
        widths[m.group(3)] = int(m.group(2)) + 1 if m.group(2) else 1
    out = []
    src = t.split('\n')
    i = 0
    while i < len(src):
        out.append(src[i])
        m = re.match(r'^  always_comb begin : \w+$', src[i])
        if m:
            # the first output assigned in the block
            n = i + 1
            while n < len(src) and not re.search(r'(o_\w+)\s*=', src[n]):
                n += 1
            o = re.search(r'(o_\w+)\s*=', src[n]).group(1)
            if not re.match(r'^\s+%s\s*=' % o, src[i + 1]):
                out.append("    %s = %d'd0;" % (o, widths[o]))
        i += 1
    t = '\n'.join(out)
    open(path, 'w', encoding='utf-8').write(t)
    # port alignment
    lines = t.split('\n')
    s = next(i for i, l in enumerate(lines) if l.startswith('module '))
    e = next(i for i in range(s, len(lines)) if lines[i].startswith(');'))
    pat = re.compile(r'^\s*(input|output|inout)\s+(wire|logic)\s*(\[[^\]]*\])?\s*([A-Za-z_]\w*)(,?)\s*$')
    rows = [(i, pat.match(lines[i]).groups()) for i in range(s + 1, e) if pat.match(lines[i])]
    wd = max((len(g[2]) for _, g in rows if g[2]), default=0)
    for i, (d, ty, w, n, c) in rows:
        lines[i] = '  ' + d.ljust(6) + ' ' + ty.ljust(5) + ' ' + (w or '').ljust(wd) + ' ' + n + c
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))


if __name__ == '__main__':
    finish(sys.argv[1])
