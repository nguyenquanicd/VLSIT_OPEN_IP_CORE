"""Re-applies the local generator patch of 2026-11-21 (generator a8fb7d4 + VLSIT_SYNTHESIS guard around the invalid-count checks).
usage: csr_guard.py <generated m_vlsit_csr_usb2.sv> <reference header file>"""
import sys, re
p, ref = sys.argv[1], sys.argv[2]
s = open(p, newline='').read()
crlf = '\r\n' in s
s = s.replace('\r\n', '\n')
pat = re.compile(r'(  // Flag parameter overrides outside the declared bank size; legal values omit this branch\.\n)(  generate\n(?:.*\n)*?  endgenerate\n)')
n = 0
def rep(m):
    global n; n += 1
    return m.group(1) + "  // Simulation-only check; VLSIT_SYNTHESIS excludes it from synthesis and lint (SCP-03).\n`ifndef VLSIT_SYNTHESIS\n" + m.group(2) + "`endif\n"
s = pat.sub(rep, s)
# keep the header of the delivered file (project, author, original date) and add a regeneration note
r = open(ref, newline='').read().replace('\r\n', '\n')
hdr_ref = r[:r.index('*/') + 2]
s = hdr_ref + s[s.index('*/') + 2:]
open(p, 'w', newline='').write(s.replace('\n', '\r\n') if crlf else s)
print('guards', n)
