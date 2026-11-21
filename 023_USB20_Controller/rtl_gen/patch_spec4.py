p = '../VLSIT_USB20_CONTROLLER_HDS.md'
lines = open(p, encoding='utf-8').read().split('\n')
for i, l in enumerate(lines):
    if l.startswith('| DEC-024 | Decision'):
        lines.insert(i + 1,
            "| DEC-025 | Decision | Timing round (FPGA place-and-route, `synth/fpga.py`): (1) the scanner of `m_usb2_xreg` decides a push of a "
            "published word from the registered dirty flag (one cycle old) instead of the 32-bit comparison, which was the head of the "
            "longest path of CLK-PHY; a changed value is still pushed with its current value and an extra push of an unchanged value is "
            "harmless; (2) new option `PARA_USB2_PIPE_MODE` registers the PHY mode outputs of `m_usb2_spd` (transceiver select, "
            "termination, operation mode, suspend, pull-downs) at the cost of one cycle on those outputs; (3) the OpMode that the host drives "
            "for the SE0 of a port reset is the parameter `PARA_USB2_RST_OPMODE` (default 3), so the PHY datasheet answer of TBD-015 is "
            "a build value and not a code change. | The measured effect is in `RTL_REPORT.md` | Decided 2026-11-21 | spec owner | 2026-11-21 |")
        break
else:
    raise AssertionError('DEC-024')
for i, l in enumerate(lines):
    if l.startswith('| TBD-015 |'):
        lines[i] = ("| TBD-015 | Decision | Drive of SE0 for a host port reset and the PHY mode for it. | Section 10.1, DEC-009, DEC-025 | "
                    "Resolved 2026-11-21 as a build parameter: `PARA_USB2_RST_OPMODE`, default 3 (author decision); a PHY datasheet that "
                    "asks for another OpMode is a parameter value, not a design change | spec owner | 2026-11-21 |")
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('ok')
