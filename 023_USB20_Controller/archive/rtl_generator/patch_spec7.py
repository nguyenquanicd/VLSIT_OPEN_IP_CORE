p = '../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md'
lines = open(p, encoding='utf-8').read().split('\n')
for i, l in enumerate(lines):
    if l.startswith('| DEC-028 | Decision'):
        lines.insert(i + 1,
            "| DEC-029 | Decision | Timing options tuned against a target (`syn/fpga_target.py`: CLK-PHY 120 MHz, CLK-BUS 150 MHz, three seeds per "
            "configuration): `PARA_USB2_PIPE_XREG` now also registers the entry that `m_usb2_xreg` writes into the update FIFO (the status words "
            "that feed the scanner are long cones); a new entry is decided only when that stage is empty, so updates take one cycle more and the "
            "rate is at most one entry per two cycles. Every pipeline option is functionally transparent: the device tests are run with all "
            "options off and on (`PIPE` = 0 and 1) in the regression. | The target was not reached by any configuration (about 100 MHz on both "
            "clocks); see `RTL_REPORT.md` for the three-seed results | Decided 2026-11-21 | spec owner | 2026-11-21 |")
        break
else:
    raise AssertionError
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('ok')
