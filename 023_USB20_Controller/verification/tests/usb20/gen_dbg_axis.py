import sys
from devlib import *
s = Scn('dbg_axis', seed=1)
ADDR = 9
d, _ = dev_bringup(s, address=ADDR)
s.w('hsts', win_en=1)
s.w('dma_map', 0, region=1, dir_in=1, ch_en=1)
s.w('dma_map', 1, region=2, dir_in=0, ch_en=1)
s.w('epi_xfr', 1, xsize=256, pkt_cnt=4)
s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(200)
s.emit('DR', 0, 1, 2000)
words = [s.rng.getrandbits(32) for _ in range(16)]
s.emit('AW', 1, 0x0000, 16, 0, *words)
s.idle_bus(300)
pin = []
for w in words:
    pin += [(w >> (8 * i)) & 255 for i in range(4)]
s.token(IN, ADDR, 1)
s.xd(DATA0, pin, tmo=400)
s.wait(8); s.hs(ACK)
s.wait(100)
s.emit('DX', 0, 1)
s.show('epi_xfr', 1); s.show('epi_ctl', 1)
s.emit('AW', 1, 0x0000, 16, 0, *words)
s.idle_bus(300)
s.token(IN, ADDR, 1)
s.xd(DATA1, pin, tmo=400)
s.wait(8); s.hs(ACK)
s.idle_bus(200)
# OUT
s.w('epo_xfr', 2, xsize=64, pkt_cnt=2)
s.w('epo_ctl', 2, mps=64, type=BULK, ep_en=1)
s.idle_bus(200)
po = s.rnd(64)
s.token(OUT, ADDR, 2)
s.data(DATA0, po)
s.xh(ACK, tmo=400)
s.idle_bus(300)
s.emit('DX', 1, 1)
pw = [sum(po[4*i+j] << (8*j) for j in range(4)) for i in range(16)]
s.emit('AR', 1, 0x1000, 16, 0, *pw)
s.emit('DR', 1, 0, 40)
s.emit('AR', 1, 0x1000, 16, 2)     # empty region: SLVERR
s.emit('AW', 1, 0x7000, 4, 2, 1, 2, 3, 4)   # outside windows
s.emit('AW', 1, 0x2000, 4, 2, 1, 2, 3, 4)   # unmapped channel
s.emit('AR', 1, 0x0000, 4, 2)               # wrong direction
s.idle_bus(100)
s.save('ops/dbg_axis.ops')
