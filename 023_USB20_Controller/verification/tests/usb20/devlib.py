"""Device bring-up shared by the device scenarios (flow S02 to S13 of section 11.2). AI-generated candidate (R-117).

Checkpoint catalogue (op CHK, R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DBU-VER | u2_version, section 11.3 | first APB read after reset | major version 1 | TB R | one APB access | other value or PSLVERR
  DBU-ENUM | REQ-FUNC-013, REQ-IF-008 | end of the bus reset and speed detection | irq_raw.busrst and irq_raw.enum set; sts.speed is the detected speed | TB P, R | 400 polls | a flag missing or a wrong speed"""
from usb2lib import *

IRQ_ALL = 0x01FFFFFF


def dev_bringup(s, address=None, rx_size=0x100, ep_regions=((0, 16), (1, 64), (2, 64), (3, 64), (4, 64)), burst=16,
                hub_chirp=True, pairs=3, sof=True, extra=None):
    """Configure, connect, run the bus reset and (optionally) set an address. Returns (DevModel, speed)."""
    s.chk('DBU-VER')
    s.r('version', major=1)
    s.w('fifo_rx', start=0, size=rx_size)
    start = rx_size
    for ep, size in ep_regions:
        s.w('epi_buf', ep, start=start, size=size)
        start += size
    s.w('dma_cfg', burst_len=burst)
    s.wraw('irq_en', 0, IRQ_ALL)
    if extra:
        extra(s)
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
    s.w('dctrl', dev_addr=0, soft_conn=1)
    s.idle_bus(400)
    speed = dev_bus_reset(s, hub_chirp=hub_chirp, pairs=pairs)
    s.chk('DBU-ENUM')
    s.poll('irq_raw', busrst=1, enum=1)
    s.r('sts', speed=0 if speed == 'hs' else 1)
    s.emit('FLUSH')                                         # remaining part of a chirp stream that the monitor split
    if sof and speed == 'hs':
        s.emit('SG', 1, 150 if W == 16 else 300)
    s.wraw('irq_raw', 0, IRQ_ALL)
    d = DevModel(s, address=0)
    if address:
        s.w('dctrl', dev_addr=address, soft_conn=1)
        s.idle_bus(400)
        d.addr = address
    return d, speed


def arm_out(s, ep, xsize, pkts, mps, addr, typ=BULK, **more):
    s.w('epo_dma', ep, addr=addr)
    s.w('epo_xfr', ep, xsize=xsize, pkt_cnt=pkts)
    s.w('epo_ctl', ep, mps=mps, type=typ, ep_en=1, **more)
    s.idle_bus(400)


def arm_in(s, ep, payload, mps, addr, typ=BULK, pkts=None, wait=3000, **more):
    s.mw(addr, payload)
    s.w('epi_dma', ep, addr=addr)
    n = pkts if pkts is not None else max(1, -(-len(payload) // mps))
    s.w('epi_xfr', ep, xsize=len(payload), pkt_cnt=n)
    s.w('epi_ctl', ep, mps=mps, type=typ, ep_en=1, **more)
    s.idle_bus(wait)
