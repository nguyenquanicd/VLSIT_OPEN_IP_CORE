p = '../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md'
t = open(p, encoding='utf-8').read()
lines = t.split('\n')
for i, l in enumerate(lines):
    if l.startswith('| DEC-026 | Decision'):
        lines.insert(i + 1,
            "| DEC-027 | Decision | Resource pass: the pointers and row counters of `m_usb2_fifo` and the credit counters of `m_usb2_dma` are as wide as the RAM "
            "needs (`clog2(rows)` bits for a pointer, one bit more for a count) and no longer 16 and 17 bits; the region base and size words of the "
            "CSR stay 16 bits wide. A region size larger than the RAM depth is a configuration error (it was undefined before). At the default "
            "depth of 1024 words and 8-bit UTMI+ `m_usb2_fifo` went from 13156 to 10001 generic cells (-24 %) and from 1307 to 989 flops. | "
            "Measured with `syn/area.py`; the regression passes unchanged | Decided 2026-11-21 | spec owner | 2026-11-21 |")
        lines.insert(i + 2,
            "| DEC-028 | Decision | Latency budget, measured in simulation (`tb_dev_utmi`, trace of `rxactive`, `dat_end`, the device transmit request and `txvalid`): "
            "the first transmitted byte follows the fall of `rxactive` after 4 CLK-PHY cycles for a data packet and for a token (one cycle to the end of "
            "packet event, one to the transmit request, two to `txvalid`). At 60 MHz one cycle is 8 high-speed bit times, so the answer starts after 32 bit "
            "times, above the minimum of 8 and well below the maximum of 192 bit times of REF-001; a shorter path would only add timing risk, so no cycle "
            "is removed. The testbench measure of 8 cycles (11 with all pipeline options) includes its own receive-end delay. | The pipeline options add "
            "one cycle each on the paths they register | Decided 2026-11-21 | spec owner | 2026-11-21 |")
        break
else:
    raise AssertionError('DEC-026')
t = '\n'.join(lines)
a = "| Section 17 | Resolved 2026-11-21 as constraint variables:"
assert t.count(a) == 1
t = t.replace(a, "| Section 17 | Resolved 2026-11-21 (UTMI+ 1.0 gives no setup or hold numbers, checked in the converted text, so the 50 % budget is the design contract) as constraint variables:")
for k in ('ASM-020', 'ASM-021', 'ASM-022', 'ASM-023'):
    pass
a2 = "Implemented and verified in simulation (`tb_dev_sg`, 228 checks)."
assert t.count(a2) == 1
t = t.replace(a2, "Implemented and verified in simulation (`tb_dev_sg`, `tb_dev_sg64`, `tb_host_sg`). Decided by the author under the delegation of the project goal (\"viết RTL theo bạn đề xuất\"); the user may still revise it.")
open(p, 'w', encoding='utf-8').write(t)
print('ok')
