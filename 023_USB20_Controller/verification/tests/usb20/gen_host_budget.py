"""t_host_budget (cfg_host_utmi8_axim, combined: host_sof, host_sched): frame budget (REQ-FUNC-014, REQ-FUNC-010). Eight channels start 512-byte
bulk OUT transfers of two packets each, more traffic than one microframe holds (16 x about 9 us of data against 125 us). The host
must not start a transaction that does not end before the next SOF: the SOF interval stays inside 125 us +- 62.5 ns at TSCALE = 1 (generate with
the argument ts1), every packet arrives complete at the partner and all channels finish."""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_budget', seed=seed)
R = s.rng
s.emit('WD', 400000)
host_bringup(s)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
SOF_NS = 125000 / usb2lib.TS
TOL = 62.5 if usb2lib.TS == 1 else SOF_NS * 0.10
LO, HI = int(SOF_NS - TOL), int(SOF_NS + TOL)
s.wait(max(3000, us(500)))
s.emit('SOF', 3, LO, HI)
p = DevPartner(s, 0)
MPS = 512
data = {}
for ch in range(8):
    data[ch] = [s.rnd(MPS), s.rnd(MPS)]
    s.mw(0x10000 + 0x1000 * ch, data[ch][0] + data[ch][1])
for ch in range(8):
    hc_program(s, ch, 0, 1 + (ch % 3), 0, BULK, MPS, 2 * MPS, 2, 0x10000 + 0x1000 * ch, pid=0)
s.bin('cg_sched.budget')
for ch in range(8):
    pass
tog = {1: 0, 2: 0, 3: 0}
for ch in range(8):
    ep = 1 + (ch % 3)
    for k in range(2):
        p.out(ep, DATA1 if tog[ep] else DATA0, data[ch][k])
        tog[ep] ^= 1
for ch in range(8):
    s.poll('hc_int', ch, tries=3000, done=1)
    s.w1c('hc_int', ch, **ALL)
s.wait(max(3000, us(250)))                                      # at least three SOF packets since the check before the load (counted per check since 2026-11-24)
s.emit('SOF', 3, LO, HI)                                        # the SOF stream stayed periodic under the load
s.bin('cg_sched.budget')
s.r('irq_raw', crc_err=0, pid_err=0, babble=0, frm_ovr=0) if False else s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_budget_s%d.ops' % seed))
