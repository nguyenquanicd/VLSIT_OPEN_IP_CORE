"""t_dev_iso_int_mix: isochronous (high bandwidth), interrupt and bulk endpoints in the same microframes.
Also used by t_dev_pipe_equiv and t_dev_ulpi_traffic.

Test ID and title: t_dev_iso_int_mix - high-bandwidth iso IN PID order, iso OUT MDATA, iso_inc, interrupt and bulk in the same microframe
Priority and rationale: P1, rank 8 of the R-283 list. Periodic traffic has its own PID rules and no retry; errors there are silent.
Purpose: show the high-bandwidth isochronous IN data PID order (DATA2/DATA1/DATA0 for three transactions), isochronous OUT with MDATA and
  no handshake, iso_inc on an IN token without data and on a corrupted OUT, and interrupt/bulk endpoints served in the same microframe.
Requirements and features: REQ-FUNC-006, 008, 009, 029, 033; REQ-IF-008. USB 2.0 5.9.2 (high-bandwidth), 8.5.5 (iso). Features hb_iso,
  zlp_short, packet_size, fifo_mgr, axi_master_dma, turnaround, interrupt.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up with IN region 1 of 400 words; endpoint interrupt enables set.
Software flow:
  1. Bring-up; write epi_ien 1, 2 and epo_ien 3.
  2. Per microframe (mult 3, 2, 1): arm iso IN 1 (mult), interrupt IN 2, bulk OUT 3; after the traffic read the done flags, ep_xfer,
     o_int_usb; clear everything.
  3. Read iso_inc after the IN without data; arm iso OUT 4 (mult 3), compare memory and done; arm OUT 4 again for the corrupted packet.
  4. Arm bulk OUT 3 for 0, 1 and 64-byte packets; compare and read done each time.
Stimulus: SOF tokens with advancing frame numbers; IN tokens per microframe; iso OUT MDATA, MDATA, DATA2; DATA0 with a CRC16 error.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DIM-HBISO | REQ-FUNC-009, 029 | IN tokens to iso endpoint 1 in one microframe (mult 3, 2, 1) | DATA2, DATA1, DATA0 (mult 3), DATA1, DATA0 (mult 2), DATA0 (mult 1) with the payload slices; response gap | TB XD, GAP | 2000 CLK-PHY each | wrong PID order or data
  DIM-MIX | REQ-FUNC-006, 004 | interrupt IN 2 and bulk OUT 3 after the iso packets | interrupt DATA0 with its 8 bytes; ACK for the bulk OUT; the OUT data at 0x2000 | TB XD, XH, MC | 2000 CLK-PHY | periodic traffic blocks the others or data wrong
  DIM-IRQ | REQ-IF-008 | end of each microframe | epi_int 1 and 2 done, epo_int 3 done, irq_raw.ep_xfer, o_int_usb high | TB R, XP | after 2500 bus cycles | a flag or the interrupt pin missing
  DIM-IRQLOW | REQ-IF-008 | all sources cleared | o_int_usb low | TB XP | immediately | the pin stays high
  DIM-INNODATA | REQ-FUNC-033 | IN token to iso endpoint 1 with nothing armed | zero-length DATA0, epi_int.iso_inc and irq_raw.iso_inc | TB XD, R | 2000 CLK-PHY | no zero-length packet or no flag
  DIM-ISOOUT | REQ-FUNC-009, 029 | iso OUT MDATA, MDATA, DATA2 (mult 3) | no handshake; 612 bytes at 0x20000; epo_int.done | TB XN, MC, R | 60 CLK-PHY per packet | a handshake or data wrong
  DIM-ISOERR | REQ-FUNC-033 | iso OUT DATA0 with a CRC16 error | no handshake; epo_int.iso_inc; memory at 0x21000 unchanged (0xEE) | TB XN, R, MC | 60 CLK-PHY | the corrupted data stored or no flag
  DIM-LEN | REQ-FUNC-008 | bulk OUT packets of 0, 1 and 64 bytes | ACK, done, data in memory for the non-empty ones | TB XH, MC, R | 400 CLK-PHY | a boundary length refused or stored wrong
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: all PID orders and flags as specified, periodic and non-periodic traffic coexist, no unexpected packet left.
Defect/fault targeted: wrong high-bandwidth PID sequence, handshake on iso, retry of iso, missing iso_inc, corrupted iso data stored,
  interrupt pin not following the sources.
Checker/oracle: PID tables of USB 2.0 5.9.2 and REQ-FUNC-009 in this script; harness XD/XN/XH/GAP/R/XP/MC; negative-control audit.
Reproducibility: cd tests/usb20; python gen_dev_iso_int_mix.py SEED (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_iso_int_mix dev_utmi8_axim tests/ops/dev_iso_int_mix_sSEED.ops +seed=SEED
Waveform: rank 8 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_dev_iso_int_mix
Evidence: runs of t_dev_iso_int_mix in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_iso_int_mix', seed=seed)
ADDR = s.rng.randrange(1, 128)
IMPS, OMPS, BMPS = 512, 256, 64
d, _ = dev_bringup(s, address=ADDR, rx_size=0x100, ep_regions=((0, 16), (1, 400), (2, 64), (3, 64), (4, 64)))
fn = [0]


def sof():
    """Start of a microframe (the frame number advances every eighth microframe)."""
    f = fn[0] >> 3
    s.token(SOF, f & 0x7F, (f >> 7) & 0xF)
    fn[0] += 1
    s.wait(20)


def iso_in_frame(payload, mult):
    """One microframe of high-bandwidth IN: data PID order of REQ-FUNC-009."""
    order = {3: [DATA2, DATA1, DATA0], 2: [DATA1, DATA0], 1: [DATA0]}[mult]
    for i, pid in enumerate(order):
        chunk = payload[i * IMPS:(i + 1) * IMPS]
        s.token(IN, ADDR, 1)
        s.xd(pid, chunk)
        s.gap(*dev_gap())
        s.wait(20)


s.wraw('epi_ien', 1, 0x3FF)                               # endpoint interrupts reach o_int_usb through ep_xfer
s.wraw('epi_ien', 2, 0x3FF)
s.wraw('epo_ien', 3, 0x3FF)
sof()
# ---- isochronous IN with three, two and one transaction per microframe; interrupt IN and bulk OUT in the same microframes
intr = s.rnd(8)
for mult, total in ((3, IMPS * 2 + 200), (2, IMPS + 100), (1, 300)):
    pay = s.rnd(total)
    s.w1c('epi_int', 1, done=1)
    arm_in(s, 1, pay, IMPS, 0x10000, typ=ISO, pkts=mult, mult=mult, wait=5000)
    arm_in(s, 2, intr, 8, 0x4000, typ=INTR, wait=1500, set_d0=1)
    arm_out(s, 3, BMPS, 1, BMPS, 0x2000, set_d0=1)
    d.tog_out[3] = 0
    d.tog_in[2] = 0
    sof()
    s.chk('DIM-HBISO')
    iso_in_frame(pay, mult)
    s.chk('DIM-MIX')
    d.in_(2, intr)                                        # interrupt IN in the same microframe
    bo = s.rnd(BMPS)
    d.out(3, bo)                                          # bulk OUT in the same microframe
    s.idle_bus(2500)
    s.mc(0x2000, bo)
    s.chk('DIM-IRQ')
    s.r('epi_int', 1, done=1)
    s.r('epi_int', 2, done=1)
    s.r('epo_int', 3, done=1)
    s.r('irq_raw', ep_xfer=1)
    s.xp(1, 1, 1)                                         # o_int_usb high
    s.wraw('epi_int', 1, 0x3FF); s.wraw('epi_int', 2, 0x3FF); s.wraw('epo_int', 3, 0x3FF)
    s.wraw('irq_raw', 0, IRQ_ALL)
    s.idle_bus(40)
    s.bin('cg_iso.m%d' % mult)
s.chk('DIM-IRQLOW')
s.xp(1, 0, 1)                                             # all sources cleared: o_int_usb low
s.bin('cg_irq.masked'); s.bin('cg_irq.two_pending')
# ---- isochronous IN token without data: zero-length DATA0, iso_inc, no retry (REQ-FUNC-033)
sof()
s.token(IN, ADDR, 1)
s.chk('DIM-INNODATA')
s.xd(DATA0, [])
s.wait(20)
s.idle_bus(600)
s.r('epi_int', 1, iso_inc=1)
s.r('irq_raw', iso_inc=1)
s.wraw('epi_int', 1, 0x3FF); s.wraw('irq_raw', 0, IRQ_ALL)
s.bin('cg_isoinc.in_nodata')
# ---- isochronous OUT, three transactions per microframe: MDATA, MDATA, DATA2; no handshake
po = [s.rnd(OMPS), s.rnd(OMPS), s.rnd(100)]
arm_out(s, 4, OMPS * 3, 3, OMPS, 0x20000, typ=ISO, mult=3)
sof()
s.chk('DIM-ISOOUT')
for pid, p in zip((MDATA, MDATA, DATA2), po):
    s.token(OUT, ADDR, 4)
    s.data(pid, p)
    s.xn(60)                                              # isochronous: no handshake
s.idle_bus(4000)
s.mc(0x20000, sum(po, []))
s.r('epo_int', 4, done=1)
s.wraw('epo_int', 4, 0x3FF)
s.bin('cg_iso.mdata')
# ---- corrupted isochronous OUT packet: iso_inc, nothing stored, no retry
s.mw(0x21000, [0xEE] * OMPS)
arm_out(s, 4, OMPS, 1, OMPS, 0x21000, typ=ISO, mult=1)
sof()
s.token(OUT, ADDR, 4)
s.chk('DIM-ISOERR')
s.data(DATA0, s.rnd(OMPS), crc_flip=0x8000)
s.xn(60)
s.idle_bus(2500)
s.r('epo_int', 4, iso_inc=1)
s.mc(0x21000, [0xEE] * OMPS)
s.wraw('epo_int', 4, 0x3FF); s.wraw('irq_raw', 0, IRQ_ALL)
s.bin('cg_isoinc.out_err')
# ---- data field boundaries on a bulk OUT endpoint (REQ-FUNC-008): 0, 1, max bytes accepted
pass
s.chk('DIM-LEN')
for n, b in ((0, 'cg_len.zero'), (1, 'cg_len.one'), (BMPS, 'cg_len.max')):
    s.w1c('epo_int', 3, done=1)
    arm_out(s, 3, BMPS, 1, BMPS, 0x3000, set_d0=1)
    d.tog_out[3] = 0
    p = s.rnd(n)
    d.out(3, p)
    s.idle_bus(2000)
    if n:
        s.mc(0x3000, p)
    s.r('epo_int', 3, done=1)
    s.bin(b)
print(s.save('ops/dev_iso_int_mix_s%d.ops' % seed))
