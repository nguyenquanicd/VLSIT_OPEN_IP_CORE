"""t_dir_param_max (review 2026-11-22 F-021 and the NEP1/NHC repro): the largest legal counts of the HDS parameter table
(PARA_USB2_NUM_EP = 15, so 16 endpoints with endpoint 0; PARA_USB2_NUM_HC = 16) must work up to the last index. The checks
use the effect in CLK-PHY, not the CSR read-back (a write that the decode does not forward to the engines still reads back
on the APB side): the last endpoint receives an OUT transfer and sends an IN transfer, and its interrupt enable reaches the
global flag; on a host build the last channel runs an IN transfer and its interrupt enable reaches the global flag.
    python gen_dir_last_index.py <seed> ep=15            (device build with NUM_EP = 15)
    python gen_dir_last_index.py <seed> hc=16 ts16       (host build with NUM_HC = 16)
    python gen_dir_last_index.py <seed> win=16           (AXI-slave device build with NUM_DMA_CH = 16: window 15 accepted,
                                                          and with win=15 on a 15-channel build window 15 refused with SLVERR)"""
import sys
from devlib import *
import hostlib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
arg = dict(a.split('=') for a in sys.argv[2:] if '=' in a)
s = Scn('dir_last_index', seed=seed)
MPS = 64
if 'ep' in arg:
    EP = int(arg['ep'])                                       # last endpoint number = NUM_EP
    ADDR = s.rng.randrange(1, 128)
    regions = [(0, 16)] + [(e, 16) for e in range(1, EP)] + [(EP, 64)]
    d, _ = dev_bringup(s, address=ADDR, rx_size=0x100, ep_regions=regions)
    s.w('epo_ien', EP, done=1)
    s.w('epi_ien', EP, done=1)
    # OUT on the last endpoint
    po = s.rnd(MPS)
    arm_out(s, EP, MPS, 1, MPS, 0x2000, set_d0=1)
    d.tog_out[EP] = 0
    d.out(EP, po)
    s.poll('epo_int', EP, tries=400, done=1)
    s.idle_bus(600)
    s.mc(0x2000, po)
    s.poll('irq_raw', tries=400, ep_xfer=1)                   # the interrupt enable of the last endpoint reached CLK-PHY
    s.w1c('irq_raw', ep_xfer=1)
    s.w1c('epo_int', EP, done=1)
    # IN on the last endpoint
    pi = s.rnd(MPS)
    arm_in(s, EP, pi, MPS, 0x3000, set_d0=1)
    d.tog_in[EP] = 0
    d.in_(EP, pi)
    s.poll('epi_int', EP, tries=400, done=1)
    s.poll('irq_raw', tries=400, ep_xfer=1)
    s.w1c('epi_int', EP, done=1)
    s.bin('cg_param.ep_max')
elif 'win' in arg:
    NCH = int(arg['win'])                                     # PARA_USB2_NUM_DMA_CH of the build
    ADDR = s.rng.randrange(1, 128)
    d, _ = dev_bringup(s, address=ADDR, ep_regions=((0, 16), (1, 64), (2, 64), (3, 16), (4, 64)))
    s.w('hsts', win_en=1)
    data = s.rnd(32)
    wd = [sum(data[4 * i + j] << (8 * j) for j in range(4)) for i in range(8)]
    if NCH == 16:
        s.w('dma_map', 15, region=1, dir_in=1, ch_en=1)       # window 15: write rows of the IN endpoint 1
        s.poll('epi_ctl', 1, tries=300, ep_en=0)
        s.w('epi_xfr', 1, xsize=32, pkt_cnt=1)
        s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1, set_d0=1)
        s.idle_bus(300)
        s.emit('AW', 1, 15 * 0x1000, 8, 0, *wd)               # OKAY expected: channel 15 exists
        s.idle_bus(300)
        s.token(IN, ADDR, 1)
        s.xd(DATA0, data, tmo=400)
        s.wait(8)
        s.hs(ACK)
        s.bin('cg_param.win_max')
    else:
        s.emit('AW', 1, (NCH) * 0x1000, 8, 2, *wd)            # window NCH does not exist: SLVERR
        s.bin('cg_param.win_beyond')
elif 'hc' in arg:
    CH = int(arg['hc']) - 1                                   # last channel
    s.emit('WD', 60000)
    hostlib.host_bringup(s)
    p = hostlib.DevPartner(s, 0)
    s.w('hc_ien', CH, done=1)
    pi = s.rnd(MPS)
    hostlib.hc_program(s, CH, 0, 1, 1, BULK, MPS, MPS, 1, 0x1000, pid=0)
    p.in_(1, DATA0, pi)
    s.poll('hc_int', CH, tries=900, done=1)
    s.idle_bus(600)
    s.mc(0x1000, pi)
    s.poll('irq_raw', tries=400, hc_xfer=1)                   # the interrupt enable of the last channel reached CLK-PHY
    s.w1c('hc_int', CH, done=1)
    s.bin('cg_param.hc_max')
print(s.save('ops/dir_last_index_%s_s%d.ops' % ('_'.join('%s%s' % kv for kv in sorted(arg.items())), seed)))
