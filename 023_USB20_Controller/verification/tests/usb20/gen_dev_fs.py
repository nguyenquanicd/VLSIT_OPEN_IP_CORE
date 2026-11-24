"""t_dev_fs_fallback (cfg_dev_utmi8_axim): the device falls back to full-speed when the host sends no chirp sequence (REQ-FUNC-013,
REQ-FUNC-024), then serves bulk OUT and IN transfers at full-speed (64-byte maximum packet) through the DMA. Expected: u2_sts.speed = 1
(full-speed), the mode pins of the full-speed row of section 6.3, payload and data toggles as in USB 2.0 chapter 8."""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_fs', seed=seed)
ADDR = s.rng.randrange(1, 128)
d, speed = dev_bringup(s, address=ADDR, hub_chirp=False, sof=False)
assert speed == 'fs'
s.bin('cg_chirp_d.fs_fallback'); s.bin('cg_speed.fs'); s.bin('cg_chirp_d.short')
s.emit('SG', 1, 2400)                                          # one SOF per (scaled) full-speed frame keeps the device awake
s.xp(0, mode(1, 1, 0), MODE_MASK)                              # full-speed row: XcvrSelect 01b, TermSelect 1, OpMode 00b
EP = 4                                                         # the last endpoint of the build (NUM_EP = 4)
s.bin('cg_ep.last')
s.w('epo_dma', EP, addr=0x2000)
s.w('epi_dma', EP, addr=0x4000)
s.w('epo_xfr', EP, xsize=64 * 2, pkt_cnt=2)
s.w('epo_ctl', EP, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(400)
po = [s.rnd(64), s.rnd(30)]
d.out(EP, po[0]); s.idle(60)
d.out(EP, po[1]); s.idle(60)
s.idle_bus(3000)
s.mc(0x2000, sum(po, []))
pin = s.rnd(64)
arm_in(s, EP, pin, 64, 0x4000, pkts=1, set_d0=1)
d.tog_in[EP] = 0
d.in_(EP, pin)
s.idle_bus(600)
s.r('irq_raw', crc_err=0, pid_err=0, fifo_ovf=0, dma_err=0)
print(s.save('ops/dev_fs%s_s%d.ops' % ('_ts1' if 'ts1' in sys.argv else '', seed)))
