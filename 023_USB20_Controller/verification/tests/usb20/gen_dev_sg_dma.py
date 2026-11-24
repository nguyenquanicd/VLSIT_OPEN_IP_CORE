"""t_dev_sg_dma: plain DMA end conditions (ZLP, short packet) and scatter-gather descriptor lists.
Descriptor (section 9): word 0 buffer address; word 1 len[15:0], last[16], ioc[17], software bits [23:18], done[24], err[25],
short[26]; after the packet len is the number of bytes not transferred and the pointer moves by 8. Also used by t_dev_pipe_equiv and
t_dev_ulpi_traffic.

Test ID and title: t_dev_sg_dma - IN ZLP on/off, OUT short and zero-length end, scatter-gather OUT/IN with status write-back
Priority and rationale: P2. Descriptor write-back is what a driver reads; a wrong status bit corrupts the driver's view silently.
Purpose: show that zlp_en sends a zero-length packet after a transfer of whole packets (and not without it), that short_end ends an OUT
  transfer at a short or zero-length packet with the right residue, and that the descriptor lists store data per buffer, refuse a
  packet that does not fit its buffer (err, dma_err, buffer untouched), and write back length, done, short and the software bits.
Requirements and features: REQ-FUNC-030, 031, 036; REQ-IF-006, 008, 014; section 9 descriptor. Features sg_dma, axi_master_dma,
  zlp_short, interrupt.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up at a random address.
Software flow:
  1. Arm IN 2 with 128 bytes, 3 packets, zlp_en; read done; then 128 bytes, 2 packets, no zlp_en; read done.
  2. Arm OUT 1 with short_end for 256 bytes; read done and the residue; again with a zero-length first packet.
  3. hsts.sg_mode; build an OUT list of 4 descriptors at 0x8000; arm OUT 1 with the list; compare the buffers, the written-back list,
     epo_dma (pointer +32) and irq_raw.dma_err.
  4. Build an IN list of 3 descriptors and a terminator at 0x8100; arm IN 2; compare the written-back list and epi_dma (+24).
Stimulus: host IN/OUT transactions; OUT packets of 64, 20, 64 (into a 32-byte buffer) and 64 bytes; IN packets of 64, 64, 23 bytes.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DSG-ZLP | REQ-FUNC-030 | IN transfer of 128 bytes with zlp_en | DATA0, DATA1, then a zero-length DATA0; done; NAK afterwards | TB XD, R, XH | 2000 CLK-PHY | no ZLP or an extra packet
  DSG-NOZLP | REQ-FUNC-030 | the same without zlp_en | two packets, done, NAK (no ZLP) | TB XD, R, XH | 2000 CLK-PHY | a ZLP is sent
  DSG-SHORT | REQ-FUNC-031 | OUT 64 then 10 bytes with short_end | ACKs; 74 bytes at 0x2000; done; residue 182 | TB XH, MC, R | 400 CLK-PHY | the transfer does not end or the residue is wrong
  DSG-ZLPOUT | REQ-FUNC-031 | zero-length OUT first | ACK; done; residue 256 | TB XH, R | 400 CLK-PHY | the transfer does not end
  DSG-SGOUT | REQ-FUNC-036 | 4 OUT packets with the descriptor list | ACK each; packets 1, 2, 4 in their buffers; the 32-byte buffer of packet 3 untouched (0xEE) | TB XH, MC | 1200 bus cycles per packet | data in the wrong buffer or an overflow written
  DSG-SGWB | REQ-FUNC-036, section 9 | after the list | descriptors written back: len 0/44/32/0, done, short on 2, err on 3, software bits kept; epo_dma +32; irq_raw.dma_err | TB MC, R | end of the list | a status bit, length or pointer wrong
  DSG-SGIN | REQ-FUNC-036 | IN list of 3 descriptors and a terminator | packets with the buffer data and alternating PIDs; done; descriptors written back with len 0 and done; epi_dma +24 | TB XD, R, MC | 1500 bus cycles per packet | wrong data, write-back or pointer
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: all transfers end as specified and the descriptor lists hold the documented status.
Defect/fault targeted: ZLP logic inverted, short packet not ending a transfer, residue errors, buffer overflow written, wrong write-back.
Checker/oracle: descriptor layout of section 9 and REQ-FUNC-030/031/036 in this script; harness XD/XH/R/MC; negative-control audit.
Reproducibility: cd tests/usb20; python gen_dev_sg_dma.py SEED (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_sg_dma dev_utmi8_axim tests/ops/dev_sg_dma_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dev_sg_dma in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_sg_dma', seed=seed)
ADDR = s.rng.randrange(1, 128)
MPS = 64
DONE, ERRB, SHORT = 1 << 24, 1 << 25, 1 << 26


def le32(v):
    return [(v >> (8 * i)) & 0xFF for i in range(4)]


def desc(buf, length, sw=0):
    return le32(buf) + le32(length | (sw << 16))


# ---- part 1: plain DMA, zero-length packet and short-packet end (REQ-FUNC-030, 031)
d, _ = dev_bringup(s, address=ADDR)
pin = s.rnd(MPS * 2)
arm_in(s, 2, pin, MPS, 0x4000, pkts=3, zlp_en=1)          # size is a multiple of the packet size: a ZLP ends it
s.chk('DSG-ZLP')
d.in_(2, pin[:MPS]); s.idle(40)
d.in_(2, pin[MPS:]); s.idle(40)
d.in_(2, []); s.idle(40)                                  # the zero-length packet
s.idle_bus(1500)
s.r('epi_int', 2, done=1)
d.in_(2, expect=NAK)
s.bin('cg_zlp.sent')
s.w1c('epi_int', 2, done=1)
pin2 = s.rnd(MPS * 2)
arm_in(s, 2, pin2, MPS, 0x4400, pkts=2)                   # zlp_en = 0: no ZLP after the two full packets
s.chk('DSG-NOZLP')
d.in_(2, pin2[:MPS]); s.idle(40)
d.in_(2, pin2[MPS:]); s.idle(40)
s.idle_bus(1500)
s.r('epi_int', 2, done=1)
d.in_(2, expect=NAK)
s.bin('cg_zlp.not_sent')
arm_out(s, 1, MPS * 4, 4, MPS, 0x2000, short_end=1)       # ends at the first short packet
o1, o2 = s.rnd(MPS), s.rnd(10)
s.chk('DSG-SHORT')
d.out(1, o1); s.idle(60)
d.out(1, o2); s.idle(60)
s.idle_bus(2000)
s.mc(0x2000, o1 + o2)
s.r('epo_int', 1, done=1)
s.r('epo_xfr', 1, xsize=MPS * 4 - MPS - 10)               # bytes not received
s.bin('cg_short.mid')
s.w1c('epo_int', 1, done=1)
arm_out(s, 1, MPS * 4, 4, MPS, 0x2400, short_end=1)
s.chk('DSG-ZLPOUT')
d.out(1, [])                                              # a zero-length packet first also ends the transfer
s.idle_bus(1500)
s.r('epo_int', 1, done=1)
s.r('epo_xfr', 1, xsize=MPS * 4)
s.bin('cg_short.first')
s.w1c('epo_int', 1, done=1)
# ---- part 2: scatter-gather lists
s.w('hsts', sg_mode=1)
s.idle_bus(200)
LIST_O, LIST_I = 0x8000, 0x8100
bufs = [0x9000, 0x9100, 0x9200, 0x9300]
sw = [0b000001, 0b101000, 0b000010, 0b111111]             # last, software bits, ioc, all software bits
lens = [MPS, MPS, 32, MPS]
tbl = []
for b, l, w in zip(bufs, lens, sw):
    tbl += desc(b, l, w)
s.mw(LIST_O, tbl)
s.mw(0x9200, [0xEE] * 64)                                 # must stay untouched: the packet does not fit
s.w('epo_dma', 1, addr=LIST_O)
s.w('epo_xfr', 1, xsize=MPS * 4, pkt_cnt=4)
s.w('epo_ctl', 1, mps=MPS, type=BULK, ep_en=1)
s.idle_bus(600)
po = [s.rnd(MPS), s.rnd(20), s.rnd(MPS), s.rnd(MPS)]      # full, short, longer than its 32-byte buffer, full
s.chk('DSG-SGOUT')
for p in po:
    d.out(1, p)
    s.idle_bus(1200)
s.mc(0x9000, po[0])
s.mc(0x9100, po[1])
s.mc(0x9200, [0xEE] * 64)
s.mc(0x9300, po[3])
exp = [le32(bufs[0]) + le32(0 | (sw[0] << 16) | DONE),
       le32(bufs[1]) + le32((MPS - 20) | (sw[1] << 16) | DONE | SHORT),
       le32(bufs[2]) + le32(32 | (sw[2] << 16) | DONE | ERRB),
       le32(bufs[3]) + le32(0 | (sw[3] << 16) | DONE)]
s.chk('DSG-SGWB')
s.mc(LIST_O, sum(exp, []))
s.r('epo_dma', 1, addr=LIST_O + 32)                       # the pointer moved by 8 per packet
s.r('irq_raw', dma_err=1)
s.w1c('irq_raw', dma_err=1)
for b in ('cg_sg.chain', 'cg_sg.short', 'cg_sg.ioc', 'cg_irq.each_source'):
    s.bin(b)
# IN list: 64, 64, 23 bytes and a terminating descriptor with len = 0
ibufs = [0xA000, 0xA100, 0xA200]
ilen = [MPS, MPS, 23]
pi = [s.rnd(l) for l in ilen]
tbl = []
for b, l in zip(ibufs, ilen):
    tbl += desc(b, l, 0b000001)
tbl += desc(0xA300, 0, 0)
s.mw(LIST_I, tbl)
for b, p in zip(ibufs, pi):
    s.mw(b, p)
s.w('epi_dma', 2, addr=LIST_I)
s.w('epi_xfr', 2, xsize=sum(ilen), pkt_cnt=3)
s.w('epi_ctl', 2, mps=MPS, type=BULK, ep_en=1)
s.idle_bus(3000)
s.chk('DSG-SGIN')
for p in pi:
    d.in_(2, p)
    s.idle_bus(1500)
s.r('epi_int', 2, done=1)
exp = [le32(b) + le32(0 | (1 << 16) | DONE) for b in ibufs]
s.mc(LIST_I, sum(exp, []))
s.r('epi_dma', 2, addr=LIST_I + 24)
s.bin('cg_sg.single')
print(s.save('ops/dev_sg_dma_s%d.ops' % seed))
