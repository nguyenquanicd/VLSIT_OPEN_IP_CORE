"""t_host_bigpkt (cfg_host_utmi8_axim, directed): high-speed bulk IN and OUT with 512-byte packets (the high-speed maximum for bulk,
USB 2.0 5.8.3). A response time-out must count only until the device starts to answer, so a long packet is received completely and
acknowledged. Expected: payload equal, data toggles, ACK after the packet."""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_bigpkt', seed=seed)
s.emit('WD', 120000)
host_bringup(s, rx_size=0x400, hnp=(0x400, 0x100), hpt=(0x500, 0x100))
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
MPS = 512
pi = [s.rnd(MPS), s.rnd(MPS)]
hc_program(s, 0, 0, 2, 1, BULK, MPS, 2 * MPS, 2, 0x8000, pid=0)
p.in_(2, DATA0, pi[0])
p.in_(2, DATA1, pi[1])
s.poll('hc_int', 0, tries=1500, done=1)
s.idle_bus(4000)                                                  # the DMA still drains the 1 KB of the receive queue after the done flag
s.mc(0x8000, pi[0] + pi[1])
s.w1c('hc_int', 0, **ALL)
s.bin('cg_len.max')
po = [s.rnd(MPS), s.rnd(100)]
s.mw(0x9000, po[0] + po[1])
hc_program(s, 1, 0, 3, 0, BULK, MPS, MPS + 100, 2, 0x9000, pid=0)
p.out(3, DATA0, po[0])
p.out(3, DATA1, po[1])
s.poll('hc_int', 1, tries=1500, done=1)
s.w1c('hc_int', 1, **ALL)
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_bigpkt_s%d.ops' % seed))
