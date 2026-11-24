"""t_dev_axis_thr: request threshold u2_dma_cfg.req_thr of a write window (FND-011, DEC-038). Also used by t_ulpi_axis.
The write window of IN endpoint 1 (64-row region) asks for a packet only while its queue has at least req_thr rows free.

Test ID and title: t_dev_axis_thr - o_dma_req follows req_thr = 32 with 16-row packets: above, at and below the threshold, and back
Priority and rationale: P3. The threshold decides when an external DMA is woken; an off-by-one wastes bursts or deadlocks.
Purpose: show that the request is high with 64, 48 and 32 free rows, low with 16, comes back when the host takes a packet, and that the
  four packets go out in order with alternating PIDs.
Requirements and features: REQ-IF-009; FND-011; DEC-038. Features axi_slave, fifo_mgr.
DUT configuration and preconditions: build dev_utmi8_axis; device bring-up; hsts.win_en; dma_cfg burst_len 16, req_thr 32; window 0
  writes IN endpoint 1 (4 packets of 64 bytes).
Software flow:
  1. Bring-up; win_en; dma_cfg; dma_map 0; arm IN 1 for 4 packets.
  2. At the end read irq_raw for error flags.
Stimulus: 16-row write bursts by the external DMA model; IN tokens.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DAT-ABOVE | REQ-IF-009 | 64 and 48 free rows | o_dma_req high; each 16-row burst accepted | TB DR, AW | 2000 and 40 bus cycles | no request above the threshold
  DAT-EQUAL | DEC-038 | exactly 32 free rows | o_dma_req high; burst accepted | TB DR, AW | 40 bus cycles | off by one at the threshold
  DAT-BELOW | DEC-038 | 16 free rows | o_dma_req low and still low 200 cycles later | TB DR, DX | 40 bus cycles | request below the threshold
  DAT-BACK | REQ-IF-009 | the host takes the first packet | DATA0 with packet 1; request back (32 free) | TB XD, DR | 400 CLK-PHY, 2000 bus cycles | the request does not return
  DAT-ORDER | REQ-FUNC-004 | IN tokens for the remaining packets | DATA1, DATA0, DATA1 with packets 2, 3, 4 | TB XD | 400 CLK-PHY each | order or toggle wrong
  DAT-CLEAN | REQ-ERR-001 | end | irq_raw fifo_ovf, fifo_udf, axi_err, dma_err, crc_err, pid_err 0 | TB R | end | an error flag
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: the request follows the threshold exactly and no packet is lost.
Defect/fault targeted: threshold compare off by one, request not re-raised after space returns.
Checker/oracle: FND-011/DEC-038 in this script; harness DR/DX/AW/XD/R.
Reproducibility: cd tests/usb20; python gen_dev_axis_thr.py SEED (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_axis_thr dev_utmi8_axis tests/ops/dev_axis_thr_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dev_axis_thr in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_axis_thr', seed=seed)
R = s.rng
ADDR = R.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR, ep_regions=((0, 16), (1, 64), (2, 64), (3, 16), (4, 64)))
s.w('hsts', win_en=1)
s.w('dma_cfg', burst_len=16, req_thr=32)
s.w('dma_map', 0, region=1, dir_in=1, ch_en=1)
s.w('epi_xfr', 1, xsize=4 * 64, pkt_cnt=4)
s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(200)
pk = [s.rnd(64) for _ in range(4)]


def words(b):
    return [sum(b[4 * i + j] << (8 * j) for j in range(4)) for i in range(len(b) // 4)]


s.chk('DAT-ABOVE')
s.emit('DR', 0, 1, 2000)                                   # 64 free rows >= 32
s.emit('AW', 1, 0x0000, 16, 0, *words(pk[0]))
s.emit('DR', 0, 1, 40)                                     # 48 free rows
s.emit('AW', 1, 0x0000, 16, 0, *words(pk[1]))
s.chk('DAT-EQUAL')
s.emit('DR', 0, 1, 40)                                     # 32 free rows: exactly the threshold
s.emit('AW', 1, 0x0000, 16, 0, *words(pk[2]))
s.chk('DAT-BELOW')
s.emit('DR', 0, 0, 40)                                     # 16 free rows < 32: no request
s.bin('cg_dbuf.both_full')                                 # three packets are queued at once
s.idle_bus(200)
s.emit('DX', 0, 0)
s.bin('cg_dmareq.thr_low')
s.chk('DAT-BACK')
s.token(IN, ADDR, 1)
s.xd(DATA0, pk[0], tmo=400)
s.wait(8)
s.hs(ACK)
s.bin('cg_dbuf.swap')                                      # one packet left while the next ones stay queued
s.emit('DR', 0, 1, 2000)                                   # the packet left: 32 rows free, the request is back
s.bin('cg_dmareq.thr_back')
s.emit('AW', 1, 0x0000, 16, 0, *words(pk[3]))
s.chk('DAT-ORDER')
for i, pid in ((1, DATA1), (2, DATA0), (3, DATA1)):
    s.idle_bus(300)
    s.token(IN, ADDR, 1)
    s.xd(pid, pk[i], tmo=400)
    s.wait(8)
    s.hs(ACK)
s.wait(60)
s.chk('DAT-CLEAN')
s.r('irq_raw', fifo_ovf=0, fifo_udf=0, axi_err=0, dma_err=0, crc_err=0, pid_err=0)
print(s.save('ops/dev_axis_thr_s%d.ops' % seed))
