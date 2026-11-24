"""t_host_periodic (cfg_host_utmi8_axim, combined: host_sched, host_sof): periodic scheduling (REQ-FUNC-032, REQ-FUNC-015). A polled interrupt IN
channel (interval 2 microframes, repeat) and a bulk OUT channel become ready together: the host serves the periodic channel first. The
interrupt channel then polls three times, each poll one interval after the previous (the partner sees no second IN token inside one
microframe after a poll); the bulk OUT transfer completes between the polls."""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_periodic', seed=seed)
s.emit('WD', 200000)
host_bringup(s)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
UF = 125000 // usb2lib.TS * 1.0                                   # one microframe in ns
pi = [s.rnd(8) for _ in range(3)]
po = s.rnd(64)
s.mw(0x6000, po)
s.wait(max(3000, us(500)))
# the bulk channel first, then the periodic one: both become ready within a few cycles
hc_program(s, 0, 0, 2, 0, BULK, 64, 64, 1, 0x6000, pid=0)
hc_program(s, 1, 0, 3, 1, INTR, 8, 24, 3, 0x6100, pid=0, poll_en=1, poll_rep=1, interval=2)
s.xt(IN, 0, 3, TMO)                                              # the periodic IN token comes first (REQ-FUNC-032)
s.bin('cg_sched.periodic_first')
s.data(DATA0, pi[0])
s.xh(ACK, tmo=2000)
p.out(2, DATA0, po)                                              # the bulk OUT follows in the same or the next microframe
s.xn(int(us(125)))                                               # no further IN token within a microframe after a poll
for k in (1, 2):
    p.in_(3, DATA1 if k == 1 else DATA0, pi[k])
s.poll('hc_int', 0, tries=900, done=1)
s.poll('hc_int', 1, tries=900, done=1)
s.idle_bus(600)
s.mc(0x6100, sum(pi, []))                                        # the three interrupt IN packets in memory (oracle audit 2026-11-24: nc_mem GAP)
s.bin('cg_poll.rearm')
s.w1c('hc_int', 0, **ALL); s.w1c('hc_int', 1, **ALL)
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_periodic_s%d.ops' % seed))
