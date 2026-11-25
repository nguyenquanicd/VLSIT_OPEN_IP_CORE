"""t_rand_host_traffic: seeded random legal host transfers against a scripted device.
Bounds: channel 0 to 7, direction, bulk or interrupt, maximum packet size 8 to 64, 1 to 4 packets with a short last packet, 0 to 2 NAK
answers per packet, buffers anywhere in 1 MB (also next to a 4 KB boundary), DMA burst 1 to 16, AXI backpressure 0 to 50 percent.

Test ID and title: t_rand_host_traffic - constrained-random host bulk/interrupt OUT and IN with NAK retries and toggle tracking
Priority and rationale: P2. Random channel, size and NAK mixes exercise the scheduler and DMA paths beyond the directed tests.
Purpose: show that 14 random transfers move the exact bytes with the toggle carried across transfers on the same endpoint, NAKed
  packets repeated unchanged, done set for each channel and no error flag.
Requirements and features: REQ-FUNC-004, 008, 015, 026, 027, 031; REQ-IF-006. Features host_sched, data_toggle, axi_master_dma, fifo_mgr.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up with a random DMA burst length.
Software flow:
  1. Bring-up; per transfer: OUT: write memory, program the channel; IN: program the channel (short_end when the last packet is short).
  2. Poll hc_int.done; compare memory for IN; clear every flag. At the end read irq_raw.
Stimulus: random from the seed; the device partner answers NAK 0 to 2 times before each ACK or data packet.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HRT-OUT | REQ-FUNC-004, 015 | random OUT transfer | OUT token and the data packet with the expected PID and bytes, repeated unchanged after each NAK | TB XT, XD | 30000 CLK-PHY per packet | toggle advanced on NAK, wrong data
  HRT-OUTDONE | REQ-FUNC-027 | last ACK of the OUT transfer | hc_int.done of that channel | TB P | 900 polls | no done
  HRT-IN | REQ-FUNC-004, 008 | random IN transfer | IN tokens repeated after NAK, ACK of the host after each data packet | TB XT, XH | 30000 and 2000 CLK-PHY | no retry or no ACK
  HRT-INDONE | REQ-FUNC-031, REQ-IF-006 | end of the IN transfer | done; the received bytes at the random buffer (incl. 4 KB crossings) | TB P, MC | 900 polls | memory wrong
  HRT-CLEAN | REQ-ERR-001 | end | irq_raw fifo_ovf, axi_err, dma_err, crc_err, pid_err, babble 0 | TB R | end | an error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: all 14 transfers correct for every seed; no unexpected packet of the host left.
Defect/fault targeted: toggle lost between transfers, NAK handling, burst split at 4 KB, channel interaction.
Checker/oracle: toggle model (tog per endpoint and direction) and data in this script; harness XT/XD/XH/P/MC/R; negative-control audit.
Reproducibility: cd tests/usb20; python gen_host_rand.py SEED ts16 (seeds 1 to 10 of testlist.csv); from verification:
  python env/scripts/run.py sim t_rand_host_traffic host_utmi8_axim_ts16 tests/ops/host_rand_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_rand_host_traffic in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('rand_host_traffic', seed=seed)
R = s.rng
s.emit('WD', 60000)
DEV = R.randrange(0, 1)                                   # the device keeps address 0 (no SET_ADDRESS in this scenario)
burst = R.randrange(1, 17)
host_bringup(s, burst=burst)
p = DevPartner(s, DEV)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
mem_next = [0x20000]
tog = {}                                                 # next data PID per (endpoint, direction)


def buf(n):
    a = mem_next[0]
    if R.randrange(4) == 0:
        a = ((a + 0x1000) & ~0xFFF) - R.choice([4, 8, 36, 60])
    a &= ~3
    mem_next[0] = (a + n + 0x40 + 3) & ~3
    return a


for it in range(14):
    s.emit('BP', R.choice([0, 0, 10, 30, 50]))
    ch = R.randrange(0, 8)
    ep = R.randrange(1, 4)
    direction = R.randrange(2)
    typ = R.choice([BULK, BULK, INTR])
    mps = R.choice([8, 16, 32, 64])
    npk = R.randrange(1, 5)
    last = R.choice([mps, R.randrange(1, mps + 1)])
    lens = [mps] * (npk - 1) + [last]
    total = sum(lens)
    key = (ep, direction)
    pid = tog.get(key, 0)
    a = buf(total + 8)
    if direction == 0:
        data = s.rnd(total)
        s.mw(a, data)
        hc_program(s, ch, DEV, ep, 0, typ, mps, total, npk, a, pid=pid)
        pos = 0
        s.chk('HRT-OUT')
        for i, ln in enumerate(lens):
            for _ in range(R.randrange(0, 3)):
                p.out(ep, DATA1 if pid else DATA0, data[pos:pos + ln], answer=NAK)
            p.out(ep, DATA1 if pid else DATA0, data[pos:pos + ln], answer=ACK)
            pid ^= 1
            pos += ln
        s.chk('HRT-OUTDONE')
        s.poll('hc_int', ch, tries=900, done=1)
    else:
        data = s.rnd(total)
        hc_program(s, ch, DEV, ep, 1, typ, mps, total, npk, a, pid=pid, short_end=1 if last != mps else 0)
        pos = 0
        s.chk('HRT-IN')
        for i, ln in enumerate(lens):
            for _ in range(R.randrange(0, 3)):
                p.in_hs(ep, NAK)
            p.in_(ep, DATA1 if pid else DATA0, data[pos:pos + ln])
            pid ^= 1
            pos += ln
        s.chk('HRT-INDONE')
        s.poll('hc_int', ch, tries=900, done=1)
        s.mc(a, data)
    tog[key] = pid
    s.w1c('hc_int', ch, **ALL)
    s.bin('cg_len.max' if last == mps else 'cg_len.one')
    s.bin('cg_axim.cross4k' if (a & 0xFFF) + total > 0x1000 else 'cg_axim.len1')
s.emit('BP', 0)
s.chk('HRT-CLEAN')
s.r('irq_raw', fifo_ovf=0, axi_err=0, dma_err=0, crc_err=0, pid_err=0, babble=0)
s.bin('cg_fifo.map_max')
print(s.save('ops/host_rand_s%d.ops' % seed))
