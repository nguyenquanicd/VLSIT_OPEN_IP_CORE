"""Host bring-up and host transactions for the host scenarios (flow S06 to S15 of section 11.2). AI-generated candidate (R-117).
The harness plays the device partner: after a packet of the DUT it sends the scripted answer (ops TK, DT, HS) and checks the
next packet of the DUT (ops XT, XD, XH). Stimulus and expected values come from USB 2.0 and the CSR description.

Checkpoint catalogue (op CHK, R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HBU-VER | u2_version, section 11.3 | first APB read after reset | major version 1 | TB R | one APB access | other value
  HBU-CONN | REQ-FUNC-012 | J on the line for the 100 ms debounce | hsts.port_conn and irq_raw.conn set | TB P | 2000 polls | no connect
  HBU-RSTDRV | REQ-FUNC-011, section 6.3, DEC-048 (ULPI 1.1 Table 40) | software sets hport.prst | the host drives SE0 with the high-speed terminations: row 00 / 0 / 00 with the pull-downs on; the line state that this row gives with a full-speed device attached is SE0 (TB LSR derives it from the row, the scenario no longer forces it) | TB WP on the mode pins, LSR | 4000 CLK-PHY cycles | OpMode 11b or a row that leaves the line at J
  HBU-CHIRP | REQ-FUNC-014 | device chirp K ends | the host sends alternating K and J chirps (at least 4 transitions) | TB XK on the transmit stream | 15 ms (scaled) | no host chirp
  HBU-RST50 | REQ-FUNC-011 (BUG-047) | from the start of the reset drive | the reset ends (high speed: irq_raw.enum; full speed: the full-speed idle row 01 / 1 / 00, whose line state is J) 50 to 52 ms after it started; hsts.port_en and port_speed | TB P or WP, TC, LSR, R | 60 ms (scaled) | reset shorter than 50 ms or longer than 52 ms, wrong speed
  HBU-RECOV | REQ-FUNC-011 recovery, REQ-FUNC-010 | port enabled, SOF not yet enabled | no SOF and no packet for 10.5 ms (scaled) | TB NSOF, XN | 10.5 ms | any packet of the host before software enables SOF"""
from usb2lib import *

IRQ_ALL = 0x01FFFFFF
TMO = 30000                       # CLK-PHY cycles to wait for a packet of the host (the host waits for the SOF)


def host_bringup(s, hs=True, rx_size=0x100, hnp=(0x100, 0x100), hpt=(0x200, 0x100), burst=16, extra=None, uf_len=None):
    """Power the port, attach a device, run reset and the chirp handshake, enable SOF. Returns the speed."""
    s.chk('HBU-VER')
    s.r('version', major=1)
    s.w('fifo_rx', start=0, size=rx_size)
    s.w('fifo_hnp', start=hnp[0], size=hnp[1])
    s.w('fifo_hpt', start=hpt[0], size=hpt[1])
    s.w('dma_cfg', burst_len=burst)
    s.wraw('irq_en', 0, IRQ_ALL)
    if extra:
        extra(s)
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
    s.w('hport', oc_en=1, vbus_drv=1)
    s.linestate(1)                                       # a full-speed device attaches: J
    s.wait(us(105000))                                   # connect debounce of 100 ms (scaled)
    s.chk('HBU-CONN')
    s.poll('hsts', port_conn=1, tries=2000)
    s.poll('irq_raw', conn=1)
    s.w1c('irq_raw', conn=1)
    s.w('hport', oc_en=1, vbus_drv=1, prst=1)
    s.chk('HBU-RSTDRV')
    s.wp(0, mode(0, 0, 0, pd=1), MODE_MASK, 4000)      # the host drives SE0 with the HS terminations (Table 40, DEC-048)
    s.emit('TM')                                         # start of the reset (REQ-FUNC-011: at least 50 ms in total)
    s.emit('LSR', 0, 1)                                  # the row gives SE0 with the full-speed device attached
    s.wait(us(3300))                                     # reset SE0 for 3 ms, then the listen window starts
    if hs:
        s.linestate(2)                                   # device chirp K
        s.wait(us(1600))
        s.emit('LSR', 0, 1)                              # end of the device chirp: SE0 under the host terminations
        s.chk('HBU-CHIRP')
        s.xk(us(100), us(30000), 4, us(15000))           # host chirps: alternating K and J
        # end of the reset of a high-speed port: the high-speed idle row is the SE0 of the reset too, so the end is the port
        # enable (enum); REQ-FUNC-011: the reset lasted at least 50 ms (2026-11-24 oracle audit, BUG-047)
        s.chk('HBU-RST50')
        s.poll('irq_raw', enum=1, tries=max(4000, us(60000) // 10))   # one poll is about 14 CLK-PHY cycles
        s.emit('TC', us(50000) - 2, us(52000))
        s.r('hsts', port_en=1, port_speed=0)
        speed = 'hs'
    else:
        s.chk('HBU-RST50')
        s.wp(0, mode(1, 1, 0, pd=1), MODE_MASK, us(60000))   # end of the reset: the host stops driving SE0 (full-speed idle row)
        s.emit('TC', us(50000) - 2, us(52000))           # REQ-FUNC-011: the reset lasted at least 50 ms (BUG-047)
        s.emit('LSR', 1, 1)                              # the full-speed idle row gives J again
        s.poll('irq_raw', enum=1, tries=3000)
        s.r('hsts', port_en=1, port_speed=1)
        speed = 'fs'
    s.w1c('irq_raw', busrst=1, enum=1)
    s.chk('HBU-RECOV')
    s.emit('NSOF', us(10500))                            # reset recovery: no SOF and no packet before software enables SOF
    s.xn(20)
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1)
    s.wraw('irq_raw', 0, IRQ_ALL)
    return speed


def hc_program(s, ch, addr_dev, ep, direction, typ, mps, xsize, pkts, dma, pid=0, setup=0, speed=0, mc=0, **cfg):
    """Program one channel and enable it (flow S15)."""
    s.w('hc_dma', ch, addr=dma)
    s.w('hc_xfer', ch, xsize=xsize, pkt_cnt=pkts, pid=pid, setup=setup)
    if cfg:
        s.w('hc_cfg', ch, **cfg)
    s.w('hc_ctrl', ch, mps=mps, ep_num=ep, ep_dir=direction, ep_type=typ, speed=speed, dev_addr=addr_dev, mc=mc, ch_en=1)


class DevPartner:
    """Scripted device behind the host port: answers tokens of the DUT with the given packets."""

    def __init__(self, s, addr=0):
        self.s, self.addr = s, addr

    def setup(self, ep, payload, ack=True):
        s = self.s
        s.xt(SETUP, self.addr, ep, TMO)
        s.xd(DATA0, payload, tmo=TMO)
        s.wait(8)
        if ack:
            s.hs(ACK)

    def out(self, ep, pid, payload, answer=ACK):
        s = self.s
        s.xt(OUT, self.addr, ep, TMO)
        s.xd(pid, payload, tmo=TMO)
        s.wait(8)
        if answer is not None:
            s.hs(answer)

    def in_(self, ep, pid, payload, xack=True):
        """IN token, device sends data, the host answers ACK."""
        s = self.s
        s.xt(IN, self.addr, ep, TMO)
        s.wait(8)
        s.data(pid, payload)
        if xack:
            s.xh(ACK, 2000)

    def in_hs(self, ep, answer):
        """IN token answered with a handshake (NAK, STALL) instead of data."""
        s = self.s
        s.xt(IN, self.addr, ep, TMO)
        s.wait(8)
        s.hs(answer)
