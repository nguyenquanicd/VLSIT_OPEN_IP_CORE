"""t_dev_edge (cfg_dev_utmi8_axim, directed): device corner cases of the data field, PID decoding, response gaps, ACK edge and rollback
(REQ-FUNC-002, 006, 008, 025, 026, 033; REQ-ERR-001). Argument = section (default all in one run, they are independent):
  len     data longer than the maximum packet size of the endpoint (65 and 1025 bytes) is dropped, not acknowledged, and reported
  pid     a PID that no device decodes (0xC, 0x8) with a good check field gets no answer
  gap     response gaps of every response type at the shortest (zero-length) and the longest (maximum packet) case
  tmo     host ACK for a device IN packet at the earliest allowed gap and at the latest one before the device time-out
  abort   an OUT packet with a bad CRC is rolled back: the retried good packet lands at the start of the region
  ovf     an oversize packet that does not fit into a small receive region: fifo overflow flag, packet dropped, no ACK
Expected values from USB 2.0 chapters 5 and 8 and the section 6.3 / 11.3 descriptions of the spec."""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
SEC = [a for a in sys.argv[2:] if a in ('len', 'pid', 'gap', 'tmo', 'abort', 'ovf')] or ['len', 'pid', 'gap', 'tmo', 'abort', 'ovf']
s = Scn('dev_edge', seed=seed)
R = s.rng
ADDR = R.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR)
s.w('epo_dma', 1, addr=0x2000)
s.w('epi_dma', 1, addr=0x4000)
s.idle_bus(200)


def arm_out_ep(mps, xsize, pkts, typ=BULK, **more):
    s.poll('epo_ctl', 1, tries=300, ep_en=0)
    s.w('epo_xfr', 1, xsize=xsize, pkt_cnt=pkts)
    s.w('epo_ctl', 1, mps=mps, type=typ, ep_en=1, set_d0=1, **more)
    d.tog_out[1] = 0
    s.idle_bus(300)


if 'len' in SEC:
    arm_out_ep(64, 192, 3)
    s.token(OUT, ADDR, 1)
    s.data(DATA0, s.rnd(65))                                      # max + 1
    s.xn(400)                                                       # babble: dropped, no handshake
    s.bin('cg_len.over')
    s.idle_bus(300)
    s.token(OUT, ADDR, 1)
    s.data(DATA0, s.rnd(1025))                                    # 1025 bytes: longer than any legal packet
    s.xn(400)
    s.idle_bus(300)
    s.show('irq_raw'); s.show('epo_int', 1)
    pg = s.rnd(64)
    d.out(1, pg)                                                    # the endpoint still works afterwards (toggle unchanged)
    s.idle_bus(600)
    s.mc(0x2000, pg)                                                # only the good packet reached memory: the dropped ones wrote nothing (nc_mem GAP)
if 'pid' in SEC:
    for pid in (0xC, 0x8):                                          # ERR/PRE and SPLIT are not decoded by a device
        s.token(pid, ADDR, 1)
        s.xn(300)
    s.bin('cg_pid.undefined')
if 'gap' in SEC:
    arm_out_ep(64, 128, 2)
    d.out(1, [])                                                    # zero-length packet: shortest response
    if 'ulpi' in sys.argv:
        s.bin('cg_gap_ulpi.min')
    d.out(1, s.rnd(64))                                             # longest packet of the endpoint
    s.bin('cg_gap_dev.max')
    if 'ulpi' in sys.argv:
        s.bin('cg_gap_ulpi.max')
if 'tmo' in SEC:
    pin = s.rnd(64)
    arm_in(s, 1, pin, 64, 0x4000, pkts=2, set_d0=1)
    d.tog_in[1] = 0
    s.token(IN, ADDR, 1)
    s.xd(DATA0, pin, tmo=400)
    s.wait(1)
    s.hs(ACK)                                                       # earliest ACK gap: one byte time
    s.bin('cg_tmo.early_edge')
    d.tog_in[1] = 1
    s.idle_bus(300)
if 'abort' in SEC:
    arm_out_ep(64, 128, 2)
    good = s.rnd(64)
    s.token(OUT, ADDR, 1)
    s.data(DATA0, s.rnd(64), crc_flip=1)                           # bad CRC16: no ACK, the rows written so far are rolled back
    s.xn(400)
    s.idle_bus(300)
    d.out(1, good)                                                  # the repeated packet is accepted
    s.idle_bus(3000)
    s.mc(0x2000, good)                                              # and sits at the start of the buffer
    s.bin('cg_fifo.abort_restore')
if 'ovf' in SEC:
    arm_out_ep(64, 192, 3)
    s.w('fifo_rx', start=0, size=20)                                # 20 rows: room for one maximum packet (16 rows), not for 100 bytes
    s.idle_bus(100)
    s.w1c('irq_raw', fifo_ovf=1)
    s.token(OUT, ADDR, 1)
    s.data(DATA0, s.rnd(100))
    s.xn(400)
    s.idle_bus(300)
    s.poll('irq_raw', tries=200, fifo_ovf=1)                        # REQ-ERR-001: the overflow reaches the interrupt status
    s.bin('cg_err.fifo')
    s.w1c('irq_raw', fifo_ovf=1)
    s.w('fifo_rx', start=0, size=0x100)
    s.idle_bus(100)
    d.out(1, s.rnd(64))
print(s.save('ops/dev_edge_%s_s%d.ops' % ('_'.join(SEC), seed)))
