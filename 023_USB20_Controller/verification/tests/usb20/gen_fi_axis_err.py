"""t_fi_axis_err: AXI4 slave accesses that the windows must refuse (fault injection). Also used by t_ulpi_axis.

Test ID and title: t_fi_axis_err - SLVERR with complete bursts outside the windows, on disabled channels, wrong direction, empty region, tag mismatch
Priority and rationale: P2. A slave that hangs or corrupts on a bad access breaks the SoC interconnect; kills M04.
Purpose: show SLVERR with the full number of beats and RLAST for every refused access, axi_err for accesses outside the windows (W1C),
  and that refused accesses have no side effect (IN still NAK, the waiting OUT packet read unchanged through the right window).
Requirements and features: REQ-IF-007; ERR-008; DEC-011; AMBA AXI4 A3.4 and B/R responses. Features axi_slave.
DUT configuration and preconditions: build dev_utmi8_axis; device bring-up; win_en; windows 0 (write IN 1), 1 (read OUT 2), 2 (read
  OUT 4), 3 (configured, not enabled).
Software flow:
  1. Bring-up; win_en; four dma_map entries; read axi_err 0.
  2. After the first outside access poll axi_err, clear it, read 0; clear again after the others.
  3. Arm IN 1 and OUT 2 for the side-effect checks; at the end read irq_raw for data-path errors and clear axi_err.
Stimulus: write/read bursts at channel 4+, the disabled channel 3, the wrong direction, the empty read window, the window of another tag.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FAX-OUTSIDE | ERR-008, REQ-IF-007 | accesses with address bits [15:12] >= 4 | SLVERR on every beat with RLAST at the last; axi_err set, cleared by W1C | TB AW, AR, P, R | 40 polls | OKAY, a short burst or no flag
  FAX-DISABLED | REQ-IF-007 | write and read of the disabled window 3 | SLVERR, complete bursts | TB AW, AR | burst completes | accepted
  FAX-DIR | REQ-IF-007, DEC-011 | read of a write window, write of a read window | SLVERR, complete bursts | TB AR, AW | burst completes | accepted
  FAX-EMPTY | DEC-011 | read of the read window with no packet | SLVERR, complete burst | TB AR | burst completes | data returned or a hang
  FAX-NOSIDE | REQ-IF-007 | refused writes to windows 1, 4, 3 with IN 1 armed | IN 1 still answered NAK; the OUT packet to endpoint 2 acknowledged | TB AW, XH | 400 CLK-PHY | a refused write reached the queue
  FAX-TAG | DEC-011 | read of window 2 (tag 4) while the head packet has tag 2 | SLVERR, complete bursts (INCR and FIXED) | TB AR | burst completes | the wrong window returns the packet
  FAX-RECOVER | REQ-IF-007, 009 | read through the right window 1 | the 16 rows of the OUT packet unchanged, RRESP OKAY; o_dma_req withdrawn; no fifo/dma/crc/pid error | TB AR, DR, R | 80 bus cycles | packet damaged by the refused reads
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: every refused access ends cleanly with SLVERR and no side effect; the good path still works.
Defect/fault targeted: axi_err never set in the AXI-slave builds (M04, BUG-032); short error bursts; refused writes reaching the queue.
Checker/oracle: AXI4 rules and DEC-011 in this script; harness AXI master BFM (response, beat count, RLAST, RID), DR, XH, R;
  qualified by M04.
Reproducibility: cd tests/usb20; python gen_fi_axis_err.py SEED (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_axis_err dev_utmi8_axis tests/ops/fi_axis_err_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_axis_err in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_axis_err', seed=seed)
R = s.rng
ADDR = R.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR)
s.w('hsts', win_en=1)
s.w('dma_map', 0, region=1, dir_in=1, ch_en=1)         # window 0: write rows of IN endpoint 1
s.w('dma_map', 1, region=2, dir_in=0, ch_en=1)         # window 1: read packets of OUT endpoint 2
s.w('dma_map', 2, region=4, dir_in=0, ch_en=1)         # window 2: read packets of OUT endpoint 4 (tag differs from endpoint 2)
s.w('dma_map', 3, region=3, dir_in=1, ch_en=0)         # window 3: configured but not enabled
ALL_ERR = dict(axi_err=1)


def junk(n):
    return [R.getrandbits(32) for _ in range(n)]


def bad_write(addr, beats, burst=1):
    s.emit('AW', burst, addr, beats, 2, *junk(beats))


def bad_read(addr, beats, burst=1):
    s.emit('AR', burst, addr, beats, 2)


s.r('irq_raw', axi_err=0)
# ---- outside the windows: the channel number (bits 15:12) is 4 or above
s.chk('FAX-OUTSIDE')
bad_write(0x4000, 4)
s.bin('cg_axiserr.outside')
s.poll('irq_raw', tries=40, axi_err=1)                      # ERR-008: the access outside the windows sets axi_err
s.w1c('irq_raw', **ALL_ERR)
s.r('irq_raw', axi_err=0)
bad_read(0x7000, 3)
bad_write(0xF000 + 4 * R.randrange(0, 1000), 1, burst=0)
bad_read(0xA000, 16, burst=0)
s.w1c('irq_raw', **ALL_ERR)
# ---- channel not enabled, wrong direction
s.chk('FAX-DISABLED')
bad_write(0x3000, 2)
bad_read(0x3000, 2)
s.bin('cg_axiserr.disabled')
s.chk('FAX-DIR')
bad_read(0x0000, 4)                                         # read of a write window
bad_write(0x1000, 4)                                        # write of a read window
s.bin('cg_axiserr.direction')
# ---- empty region: nothing to read
s.chk('FAX-EMPTY')
bad_read(0x1000, 16)
s.bin('cg_axiserr.empty')
# ---- a refused write has no effect: the armed IN endpoint still answers NAK
s.w('epi_xfr', 1, xsize=64, pkt_cnt=1)
s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(300)
s.chk('FAX-NOSIDE')
bad_write(0x1000, 16)
bad_write(0x4000, 16)
bad_write(0x3000, 16)
s.idle_bus(400)
s.token(IN, ADDR, 1)
s.xh(NAK, tmo=400)
s.bin('cg_axiserr.no_side_effect')
# ---- an OUT packet of endpoint 2 waits; the window of tag 4 refuses it, the window of tag 2 returns it unchanged
s.w('epo_xfr', 2, xsize=64, pkt_cnt=1)
s.w('epo_ctl', 2, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(300)
po = s.rnd(64)
s.token(OUT, ADDR, 2)
s.data(DATA0, po)
s.xh(ACK, tmo=400)
s.idle_bus(400)
s.chk('FAX-TAG')
bad_read(0x2000, 16)                                        # head packet has tag 2, window 2 serves tag 4
s.bin('cg_axiserr.tag')
bad_read(0x2000, 4, burst=0)
w = [sum(po[4 * i + j] << (8 * j) for j in range(4)) for i in range(16)]
args = []
for x in w:
    args += [x, 0xFFFFFFFF]
s.chk('FAX-RECOVER')
s.emit('AR', 1, 0x1000, 16, 0, *args)                       # the right window still returns the whole packet
s.emit('DR', 1, 0, 80)
s.bin('cg_axiserr.recover')
# ---- no data errors were reported by the data path itself
s.r('irq_raw', fifo_ovf=0, fifo_udf=0, dma_err=0, crc_err=0, pid_err=0)
s.w1c('irq_raw', **ALL_ERR)
print(s.save('ops/fi_axis_err_s%d.ops' % seed))
