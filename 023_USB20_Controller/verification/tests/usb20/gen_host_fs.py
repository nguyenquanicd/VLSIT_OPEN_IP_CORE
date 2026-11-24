"""t_host_fs (cfg_host_utmi8_axim, combined: connect_detect, port_reset, host_sof, host_sched, data_toggle): host with a full-speed device
(REQ-FUNC-016, 010, 012, 015). The device does not chirp, so the port ends the reset at full-speed (u2_hsts.port_speed = 1); the SOF
interval is one frame (1 ms, divided by TSCALE like every timer, FND-009 tolerance as in t_host_enum_bulk_dma); one bulk OUT packet and
one bulk IN packet are exchanged at full-speed."""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_fs', seed=seed)
s.emit('WD', 60000)
speed = host_bringup(s, hs=False)
assert speed == 'fs'
s.bin('cg_conn.fs'); s.bin('cg_speed.fs')
FR = 1000000 / usb2lib.TS                                   # frame in ns
TOL = 62.5 if usb2lib.TS == 1 else FR * 0.10
s.wait(max(3000, us(3500)))
s.emit('SOF', 3, int(FR - TOL), int(FR + TOL))
s.bin('cg_sof.fs')
p = DevPartner(s, 0)
po = s.rnd(40)
s.mw(0x1000, po)
hc_program(s, 0, 0, 1, 0, BULK, 64, 40, 1, 0x1000, pid=0, speed=1)
p.out(1, DATA0, po)
s.poll('hc_int', 0, done=1)
s.w1c('hc_int', 0, done=1)
pi = s.rnd(24)
hc_program(s, 1, 0, 2, 1, BULK, 64, 24, 1, 0x2000, pid=0, speed=1, short_end=1)
p.in_(2, DATA0, pi)
s.poll('hc_int', 1, done=1)
s.mc(0x2000, pi)
s.w1c('hc_int', 1, done=1)
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_fs_s%d.ops' % seed))
