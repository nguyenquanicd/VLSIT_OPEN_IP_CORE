"""t_host_bigpkt (cfg_host_utmi8_axim, directed): high-speed bulk IN and OUT with 512-byte packets (the high-speed maximum for bulk,
USB 2.0 5.8.3). A response time-out must count only until the device starts to answer, so a long packet is received completely and
acknowledged. Expected: payload equal, data toggles, ACK after the packet."""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_bigpkt', seed=seed)
s.emit('WD', 120000)
host_bringup(s)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
MPS = 512
pi = [s.rnd(MPS), s.rnd(MPS)]
hc_program(s, 0, 0, 2, 1, BULK, MPS, MPS, 1, 0x8000, pid=0)
p.in_(2, DATA0, pi[0])
s.poll('hc_int', 0, tries=1500, done=1)
s.mc(0x8000, pi[0])
s.w1c('hc_int', 0, **ALL)
s.bin('cg_len.max')
print(s.save('ops/dbg_big1_s%d.ops' % seed))
