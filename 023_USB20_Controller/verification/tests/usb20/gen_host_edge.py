"""t_host_edge (cfg_host_utmi8_axim, TSCALE 16): host-side bins of the coverage plan that the main scenarios do not reach.
Sections (arguments, default all): force = Test_Force_Enable (u2_hport.test_mode = 5, REQ-FUNC-022): the host stops its SOF
packets and all transactions while the port stays connected and enabled; sof = the SOF frame number counts through the
roll-over 7FFh to 000h in 2048 frames and never jumps (REQ-FUNC-010, USB 2.0 section 8.4.3); rxerr = RxError inside
an IN data packet from the device: the host sends no ACK, flags the error and gets the good packet at the retry (REQ-ERR-001; with the
argument ulpi the error is an RX CMD inside the packet, REQ-IF-003); iso = isochronous IN with a silent device: iso_inc in the
channel and global flags, no retry (REQ-FUNC-033); miss = a polled interrupt channel that cannot start (no room in the receive region)
sets poll_miss at the second tick (REQ-FUNC-032); psplit = interrupt IN split transaction whose complete-splits are answered NYET:
one complete-split per microframe and at most three (REQ-FUNC-038); bsplit = bulk split start-split answered with errors three times (REQ-FUNC-039); gaps = host packet gaps in high-speed, measured by the testbench (REQ-FUNC-014: at least 88 and at most 192 bit times between its own packets, 8 to 192 bit
times after a received packet; one CLK-PHY cycle is 8 bit times at 60 MHz); imax = interval 65535 microframes (the maximum of u2_hc_cfg.interval).
    python gen_host_edge.py <seed> [force] [sof] ts16"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
SEC = [a for a in sys.argv[2:] if a in ('force', 'sof', 'rxerr', 'iso', 'miss', 'imax', 'psplit', 'bsplit', 'gaps', 'rxhold')] or ['force', 'sof', 'rxerr', 'iso', 'miss', 'imax', 'psplit', 'bsplit', 'gaps', 'rxhold']
s = Scn('host_edge_' + '_'.join(SEC) if False else 'host_edge', seed=seed)
s.emit('WD', 1500000 if 'imax' in SEC else 400000)
speed = host_bringup(s)
s.wait(max(3000, us(500)))
if 'force' in SEC:
    s.emit('SOF', 3, 0, 10 ** 9)                              # SOF packets flow before the test mode
    s.emit('SOFW', 0)
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, test_mode=5)
    s.wait(us(2000))
    s.emit('NSOF', us(3000))                                  # Test_Force_Enable: the host sends nothing
    s.r('hsts', port_conn=1, port_en=1)                       # port stays connected and enabled
    s.bin('cg_test.force_en')
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, test_mode=0)  # leaving the mode: SOF resumes
    s.wait(us(2000))
    s.emit('SOFR', 8)                                         # SOF packets are back
if 'sof' in SEC:
    s.emit('SOFW', 0)
    for _ in range(2200):                                     # 2200 frames of 1 ms (scaled): past 2048
        s.wait(us(1000))
    s.emit('SOFW', 1)
    s.bin('cg_sof.rollover')
if 'rxerr' in SEC:
    DEV, MPS = 0, 64
    p = DevPartner(s, DEV)
    pg = s.rnd(MPS)
    hc_program(s, 0, DEV, 1, 1, BULK, MPS, MPS, 1, 0x1400, pid=0)
    s.xt(IN, DEV, 1, TMO)
    s.wait(8)
    s.raw([0xC3] + s.rnd(MPS) + [0x00, 0x00], rxerr_at=20)    # the PHY flags a receive error in the middle of the packet
    if 'ulpi' in sys.argv:
        s.bin('cg_ulpi.rxcmd_in_pkt')
    p.in_(1, DATA0, pg)                                       # the next packet of the host is the retried IN token, not an ACK; it takes the good packet
    s.poll('hc_int', 0, done=1)
    s.mc(0x1400, pg)
    s.r('hc_int', 0, xact_err=1)
    s.w1c('hc_int', 0, done=1, xact_err=1)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1, poll_miss=1, iso_inc=1)
if 'iso' in SEC:
    hc_program(s, 0, 0, 4, 1, ISO, 64, 64, 1, 0x1800, pid=0)
    s.xt(IN, 0, 4, TMO)                                       # the device does not answer in its microframe
    s.poll('hc_int', 0, tries=900, iso_inc=1)                 # the channel flag
    s.poll('irq_raw', tries=900, iso_inc=1)                   # the global flag (after the clock crossing)
    s.xn(int(us(250)))                                        # no retry: an isochronous transfer is not repeated
    s.bin('cg_isoinc.host_late')
    s.w1c('hc_int', 0, **ALL)
    s.wraw('irq_raw', 0, IRQ_ALL)
if 'miss' in SEC:
    po = s.rnd(8)
    s.mw(0x1900, po)
    s.w('ctrl', core_en=1, dma_en=0, ahb_err_stop=1)           # the DMA is off: the data of the OUT channel never reaches the transmit region
    s.idle_bus(100)
    hc_program(s, 1, 0, 5, 0, INTR, 8, 8, 1, 0x1900, pid=0, poll_en=1, poll_rep=1, interval=1)
    s.poll('hc_int', 1, tries=2000, poll_miss=1)              # due at one tick and still not served at the next one: poll_miss
    s.bin('cg_poll.miss')
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)          # the DMA comes back: the channel is served
    p = DevPartner(s, 0)
    p.out(5, DATA0, po)
    s.poll('hc_int', 1, tries=2000, done=1)
    s.w1c('hc_int', 1, **ALL)
if 'imax' in SEC:
    IMAX = 0xFFFF
    p = DevPartner(s, 0)
    hc_program(s, 2, 0, 6, 1, INTR, 8, 16, 2, 0x1A00, pid=0, poll_en=1, poll_rep=1, interval=IMAX)      # two packets: the second poll is the one the interval delays
    p.in_(6, DATA0, s.rnd(8))                                 # the first poll goes out at once
    s.emit('WSOF', IMAX - 8)                                  # then nothing for the interval (counted in SOF packets: one per microframe)
    s.xt(IN, 0, 6, us(125 * 16))                              # the next poll comes after 65535 microframes
    s.wait(8)
    s.data(DATA1, s.rnd(8))
    s.xh(ACK, 2000)
    s.bin('cg_poll.int_max')
HUB, PORT, FSDEV = 2, 3, 5


def hc_split(ch):
    s.w('hc_spl', ch, hub_addr=HUB, port_addr=PORT, xact_pos=0, comp_split=0, split_en=1)


if 'psplit' in SEC:
    pi = s.rnd(8)
    s.mw(0x1B00, [0] * 8)
    hc_split(3)
    hc_program(s, 3, FSDEV, 2, 1, INTR, 8, 8, 1, 0x1B00, pid=0, speed=1, poll_en=1, poll_rep=0, interval=1)
    s.xs(HUB, 0, PORT, 0, 0, 3, TMO)                         # start-split of the interrupt IN transaction
    s.xt(IN, FSDEV, 2, 3000)
    s.wait(8)
    s.hs(ACK)
    for k in range(3):                                       # three complete-splits, each in its own microframe, answered NYET
        s.xs(HUB, 1, PORT, 0, 0, 3, TMO)
        s.xt(IN, FSDEV, 2, 3000)
        s.wait(8)
        s.hs(NYET)
        if k > 0:
            s.emit('SOFD', 1, 1)                                 # exactly one microframe after the previous complete-split
        s.emit('SOFM')
    s.bin('cg_psplit.uf_each')
    s.bin('cg_psplit.third_cs')
    s.xs(HUB, 0, PORT, 0, 0, 3, us(125 * 4))                 # no fourth complete-split: the next packet is a new start-split (REQ-FUNC-038)
if 'bsplit' in SEC:
    pb = s.rnd(64)
    s.mw(0x1C00, pb)
    hc_split(4)
    hc_program(s, 4, FSDEV, 1, 0, BULK, 64, 64, 1, 0x1C00, pid=0, speed=1)
    for k in range(3):                                       # the hub answers the start-split with a transaction error (no handshake) three times
        s.xs(HUB, 0, PORT, 0, 0, 2, TMO)
        s.xt(OUT, FSDEV, 1, 3000)
        s.xd(DATA0, pb, tmo=3000)
    s.poll('hc_int', 4, tries=900, ch_halt=1)                # REQ-FUNC-039: the third error ends the transfer
    s.bin('cg_bsplit.err3')
    s.w1c('hc_int', 4, **ALL)
if 'gaps' in SEC:
    p = DevPartner(s, 0)
    po, pi = s.rnd(64), s.rnd(64)
    s.mw(0x1D00, po)
    hc_program(s, 6, 0, 1, 0, BULK, 64, 64, 1, 0x1D00, pid=0)
    s.xt(OUT, 0, 1, TMO)
    s.xd(DATA0, po, tmo=TMO)
    s.gapb(*((6, 12) if 'w16' in sys.argv else (11, 24)))     # token to data: 88 to 192 bit times (11 to 24 cycles of 8 bit times, 6 to 12 of 16)
    s.bin('cg_gap_host.b2b')
    s.wait(8)
    s.hs(ACK)
    s.poll('hc_int', 6, tries=900, done=1)
    s.w1c('hc_int', 6, **ALL)
    hc_program(s, 6, 0, 1, 1, BULK, 64, 64, 1, 0x1E00, pid=0)
    s.xt(IN, 0, 1, TMO)
    s.wait(8)
    s.data(DATA0, pi)
    s.xh(ACK, 2000)
    s.gap(1, 24)                                              # response of the host to a data packet: 8 to 192 bit times
    s.bin('cg_gap_host.min'); s.bin('cg_gap_host.max')
    s.poll('hc_int', 6, tries=900, done=1)
    s.idle_bus(600)
    s.mc(0x1E00, pi)                                          # the IN data in memory (nc_mem GAP)
    s.w1c('hc_int', 6, **ALL)
if 'rxhold' in SEC:
    # review 2026-11-22 F-019: the PHY keeps RXActive high after the start of a data packet (no more data, no end). UTMI+ does not
    # let the link transmit while RXActive is high, so no protocol action is possible until it falls; expected: no ACK, the
    # transaction counts as an error when RXActive falls, the channel retries and finishes with the good packet, nothing of the
    # broken packet is committed (the memory holds only the good data).
    p = DevPartner(s, 0)
    pg = s.rnd(MPS if 'MPS' in dir() else 64)
    hc_program(s, 7, 0, 2, 1, BULK, 64, 64, 1, 0x1F00, pid=0)
    s.mw(0x1F00, [0xEE] * 64)
    s.xt(IN, 0, 2, TMO)
    s.wait(8)
    s.emit('RXH', 20000, 12, 0xC3, *s.rnd(11))                # DATA0 PID and 11 bytes, then RXActive stuck for 20000 cycles
    p.in_(2, DATA0, pg)                                       # the next packet of the host is the retried IN token, not an ACK
    s.poll('hc_int', 7, tries=900, done=1)
    s.idle_bus(600)
    s.mc(0x1F00, pg)
    s.r('hc_int', 7, xact_err=1)
    s.w1c('hc_int', 7, done=1, xact_err=1)
    s.bin('cg_err.rx_stuck')
s.emit('FLUSH')
print(s.save('ops/host_edge_%s_s%d.ops' % ('_'.join(SEC), seed)))
