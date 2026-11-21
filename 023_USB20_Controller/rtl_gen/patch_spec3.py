p = '../VLSIT_USB20_CONTROLLER_HDS.md'
lines = open(p, encoding='utf-8').read().split('\n')


def add_note(prefix, note):
    n = 0
    for i, l in enumerate(lines):
        if l.startswith(prefix):
            cells = l.split(' | ')
            # status cell is the fifth cell (index 4)
            cells[4] = cells[4].rstrip() + ' ' + note
            lines[i] = ' | '.join(cells)
            n += 1
    assert n == 1, prefix


add_note("|  ASM-020 |", "Implemented and verified in simulation (`tb_dev_sg`, 228 checks).")
add_note("|  ASM-021 |", "Implemented and verified in simulation (`tb_host_iso`: one isochronous packet per interval; `tb_host_flags`: `babble`, `iso_inc`).")
add_note("|  ASM-022 |", "Implemented and verified in simulation (`tb_host_flags`: a 5-cycle pulse is filtered, a long pulse sets `oc_act` and switches the power off, the power stays off); the load-switch datasheet check stays in TBD-012.")
add_note("|  ASM-023 |", "Implemented and verified in simulation (`tb_dev_feat`: loopback counters).")
for i, l in enumerate(lines):
    if l.startswith('| TBD-015 |'):
        lines[i] = ("| TBD-015 | Decision | Drive of SE0 for a host port reset and the PHY mode for it (OpMode 3 is assumed in `m_usb2_spd`); "
                    "confirm with the PHY datasheet and REF-003 section 3. | Section 10.1, DEC-009 | Open, external: only the PHY datasheet "
                    "can settle it; the mode value is one assignment in the host reset state of `m_usb2_spd`, so the answer changes no "
                    "structure | spec owner | 2026-11-21 |")
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('ok')
