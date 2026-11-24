"""t_host_babble (cfg_host_utmi8_axim, fault injection): babble (REQ-ERR-002, FM): a device sends a packet longer than the maximum packet size
of the channel. Expected: the channel reports babble (u2_hc_int.babble, u2_irq_raw.babble), the channel halts and no data beyond the maximum
packet size is stored; the next transfer on another channel still works. Arguments: fs for a full-speed device (default high-speed)."""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
FS = 'fs' in sys.argv
s = Scn('host_babble', seed=seed)
s.emit('WD', 60000)
host_bringup(s, hs=not FS)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
MPS = 64
s.mw(0x3000, [0xA5] * 96)
hc_program(s, 0, 0, 2, 1, BULK, MPS, MPS, 1, 0x3000, pid=0, speed=1 if FS else 0)
s.xt(IN, 0, 2, TMO)
s.data(DATA0, s.rnd(MPS + 6))                                    # 70 bytes into a 64-byte channel
s.xn(400)                                                       # babble is not acknowledged (BUG-038)
s.poll('hc_int', 0, tries=900, babble=1)
s.r('irq_raw', babble=0)                                          # longer than the channel maximum only: channel flag, not the global one (DEC-043)
s.bin('cg_babble.fs' if FS else 'cg_babble.hs')
s.w1c('hc_int', 0, **ALL)
# a packet longer than the largest legal packet (1024 bytes) is babble for the whole controller (REQ-ERR-001)
MPS2 = 64
s.mw(0x5000, [0x5A] * 64)
hc_program(s, 2, 0, 2, 1, BULK, MPS2, MPS2, 1, 0x5000, pid=0, speed=1 if FS else 0)
s.xt(IN, 0, 2, TMO)
s.data(DATA1, s.rnd(1030))
s.xn(400)
s.poll('irq_raw', tries=900, babble=1)
s.bin('cg_err.babble')
s.w1c('hc_int', 2, **ALL)
s.w1c('irq_raw', babble=1)
# the port still works: a normal transfer on another channel
pi = s.rnd(24)
hc_program(s, 1, 0, 3, 1, BULK, MPS, 24, 1, 0x4000, pid=0, speed=1 if FS else 0, short_end=1)
p.in_(3, DATA0, pi)
s.poll('hc_int', 1, tries=900, done=1)
s.mc(0x4000, pi)
s.w1c('hc_int', 1, **ALL)
print(s.save('ops/host_babble%s_s%d.ops' % ('_fs' if FS else '', seed)))
