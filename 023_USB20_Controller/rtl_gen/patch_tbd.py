p = '../VLSIT_USB20_CONTROLLER_HDS.md'
lines = open(p, encoding='utf-8').read().split('\n')
n = 0
for i, l in enumerate(lines):
    if l.startswith('| TBD-016 |'):
        lines[i] = ("| TBD-016 | Decision | What the RTL does not implement or the simulations do not reach: the AXI data width "
                    "is fixed to four chunks of the UTMI+ width (DEC-010); the scatter-gather `last` and `ioc` bits are "
                    "kept but not interpreted and every packet has its own descriptor (DEC-013); no directed test forces "
                    "the host `poll_miss`, `frm_ovr`, `babble` and `iso_inc` flags (DEC-018), the device remote wake out "
                    "of ULPI low power (DEC-022), scatter-gather on a host channel or on a 64-bit AXI bus, or the "
                    "corner cases of NYET and PING beyond the basic path; synthesis was run with generic gates and no "
                    "technology library, and no STA, CDC, RDC or formal tool was run. | Sections 3, 8 and 10; DEC-010, "
                    "DEC-013, DEC-018, DEC-022 | Open | spec owner | 2026-11-21 |")
        n += 1
assert n == 1
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('ok')
