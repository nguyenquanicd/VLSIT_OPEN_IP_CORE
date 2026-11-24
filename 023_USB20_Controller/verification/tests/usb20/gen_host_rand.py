"""t_rand_host_traffic (cfg_host_utmi8_axim): seeded random legal host transfers against a scripted device. Random values and
their bounds: channel 0 to 7, direction, endpoint type bulk or interrupt (control with a setup stage in one of four cases),
maximum packet size 8, 16, 32 or 64 (limits of USB 2.0 chapter 5 for the types at this frame length), 1 to 4 packets with a
short last packet, 0 to 2 NAK answers per IN or OUT packet, buffer addresses anywhere in the 1 MB memory (also next to a 4 KB
boundary), DMA burst length 1 to 16, AXI backpressure 0 to 50 percent. Requirements: REQ-FUNC-004, 008, 015, 026, 027, 031,
REQ-IF-006. Expected data and toggles follow USB 2.0 chapter 8."""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('rand_host_traffic', seed=seed)
R = s.rng
s.emit('WD', 60000)
DEV = R.randrange(0, 1)                                   # the device keeps address 0 (no SET_ADDRESS in this scenario)
burst = R.randrange(1, 17)
host_bringup(s, burst=burst)
p = DevPartner(s, DEV)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
mem_next = [0x20000]
tog = {}                                                 # next data PID per (endpoint, direction)


def buf(n):
    a = mem_next[0]
    if R.randrange(4) == 0:
        a = ((a + 0x1000) & ~0xFFF) - R.choice([4, 8, 36, 60])
    a &= ~3
    mem_next[0] = (a + n + 0x40 + 3) & ~3
    return a


for it in range(14):
    s.emit('BP', R.choice([0, 0, 10, 30, 50]))
    ch = R.randrange(0, 8)
    ep = R.randrange(1, 4)
    direction = R.randrange(2)
    typ = R.choice([BULK, BULK, INTR])
    mps = R.choice([8, 16, 32, 64])
    npk = R.randrange(1, 5)
    last = R.choice([mps, R.randrange(1, mps + 1)])
    lens = [mps] * (npk - 1) + [last]
    total = sum(lens)
    key = (ep, direction)
    pid = tog.get(key, 0)
    a = buf(total + 8)
    if direction == 0:
        data = s.rnd(total)
        s.mw(a, data)
        hc_program(s, ch, DEV, ep, 0, typ, mps, total, npk, a, pid=pid)
        pos = 0
        for i, ln in enumerate(lens):
            for _ in range(R.randrange(0, 3)):
                p.out(ep, DATA1 if pid else DATA0, data[pos:pos + ln], answer=NAK)
            p.out(ep, DATA1 if pid else DATA0, data[pos:pos + ln], answer=ACK)
            pid ^= 1
            pos += ln
        s.poll('hc_int', ch, tries=900, done=1)
    else:
        data = s.rnd(total)
        hc_program(s, ch, DEV, ep, 1, typ, mps, total, npk, a, pid=pid, short_end=1 if last != mps else 0)
        pos = 0
        for i, ln in enumerate(lens):
            for _ in range(R.randrange(0, 3)):
                p.in_hs(ep, NAK)
            p.in_(ep, DATA1 if pid else DATA0, data[pos:pos + ln])
            pid ^= 1
            pos += ln
        s.poll('hc_int', ch, tries=900, done=1)
        s.mc(a, data)
    tog[key] = pid
    s.w1c('hc_int', ch, **ALL)
    s.bin('cg_len.max' if last == mps else 'cg_len.one')
    s.bin('cg_axim.cross4k' if (a & 0xFFF) + total > 0x1000 else 'cg_axim.len1')
s.emit('BP', 0)
s.r('irq_raw', fifo_ovf=0, axi_err=0, dma_err=0, crc_err=0, pid_err=0, babble=0)
s.bin('cg_fifo.map_max')
print(s.save('ops/host_rand_s%d.ops' % seed))
