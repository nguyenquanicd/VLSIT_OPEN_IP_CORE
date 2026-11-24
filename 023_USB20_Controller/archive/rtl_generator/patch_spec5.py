p = '../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md'
t = open(p, encoding='utf-8').read()
lines = t.split('\n')
for i, l in enumerate(lines):
    if l.startswith('| DEC-025 | Decision'):
        lines.insert(i + 1,
            "| DEC-026 | Decision | NYET decision of the device (`m_usb2_dev`): the free rows reported by the FIFO manager already count the rows of the "
            "packet that just ended, so the high-speed bulk OUT answers NYET when the free rows are fewer than a maximum packet; the first "
            "version subtracted the packet rows a second time, the 17-bit result wrapped around and the device answered ACK with a full FIFO. | "
            "Found with `tb_dev_nyet` (NYET, PING answered NAK while the FIFO is full and ACK after the drain) | Decided 2026-11-21 | spec owner | 2026-11-21 |")
        break
else:
    raise AssertionError
for i, l in enumerate(lines):
    if l.startswith('| TBD-016 |'):
        lines[i] = ("| TBD-016 | Decision | Limits that remain after the verification rounds: the AXI data width is fixed to four chunks of the UTMI+ "
                    "width (DEC-010); the scatter-gather `last` and `ioc` bits are kept but not interpreted and every packet has its own descriptor "
                    "(DEC-013); synthesis was run with generic gates and on one FPGA family, and no ASIC library, ASIC STA, CDC, RDC or formal "
                    "tool was run (the SDC files in `sdc/` are untested). | Sections 3, 8 and 10; DEC-010, DEC-013, DEC-025 | Resolved 2026-11-21 "
                    "as recorded limits; every feature of the specification is implemented and simulated | spec owner | 2026-11-21 |")
t = '\n'.join(lines)
a = "`babble` (with the channel halt) and `iso_inc` are verified in `tb_host_flags`; `poll_miss` and `frm_ovr` are not forced by a directed test"
assert t.count(a) == 1
t = t.replace(a, "all four flags are verified in `tb_host_flags` (`babble` with the channel halt, `iso_inc`, `poll_miss`, `frm_ovr`)")
open(p, 'w', encoding='utf-8').write(t)
print('ok')
