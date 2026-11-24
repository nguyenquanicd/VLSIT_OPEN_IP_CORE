"""t_dev_axis_udf: FIFO underflow of an IN packet in the AXI-slave build (FND-005, BUG-037).
The transfer registers announce a 64-byte packet but the write window delivers only 8 rows (32 bytes).

Test ID and title: t_dev_axis_udf - incomplete IN packet in the write window: the device answers NAK
Priority and rationale: P3. Guards against sending a short or corrupt packet as good data.
Purpose: show that when only half of an announced packet has been written through the window, the device answers the IN with NAK.
Requirements and features: REQ-FUNC-027; ERR-006; FND-005; BUG-037. Features axi_slave, fifo_mgr.
DUT configuration and preconditions: build dev_utmi8_axis; device bring-up; hsts.win_en; window 0 writes IN endpoint 1; epi_xfr 64 bytes.
Software flow:
  1. Bring-up; hsts.win_en; dma_map 0; arm IN 1 for 64 bytes.
  2. After the IN, print irq_raw and epi_int (diagnostic reads only, not compared).
Stimulus: one INCR write burst of 8 rows to window 0; one IN token.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DAU-WR | REQ-IF-007 | 8-row write burst to window 0 | accepted with BRESP OKAY | TB AW | burst completes | error response or hang
  DAU-NAK | REQ-FUNC-027, ERR-006 | IN token with half a packet in the queue | NAK (no short or corrupt DATA packet) | TB XH | 600 CLK-PHY | a data packet or no answer
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: NAK; the incomplete packet is never sent.
Known gaps: the XP 0 0 0 op before the NAK has mask 0 and checks nothing; fifo_udf and epi_int.unf are only printed (RP), so the
  "underflow flag" branch of the docstring before 2026-11-25 is not verified.
Defect/fault targeted: an IN packet started before its data is complete (BUG-037).
Checker/oracle: REQ-FUNC-027 in this script; harness AW (AXI BFM), XH.
Reproducibility: cd tests/usb20; python gen_dev_axis_udf.py SEED (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_axis_udf dev_utmi8_axis tests/ops/dev_axis_udf_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dev_axis_udf in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_axis_udf', seed=seed)
ADDR = s.rng.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR, ep_regions=((0, 16), (1, 64), (2, 64), (3, 16), (4, 64)))
s.w('hsts', win_en=1)
s.w('dma_map', 0, region=1, dir_in=1, ch_en=1)
s.w('epi_xfr', 1, xsize=64, pkt_cnt=1)
s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(200)
words = [s.rng.getrandbits(32) for _ in range(8)]
s.chk('DAU-WR')
s.emit('AW', 1, 0x0000, 8, 0, *words)
s.idle_bus(400)
s.chk('DAU-NAK')
s.token(IN, ADDR, 1)
s.emit('XP', 0, 0, 0)
s.xh(NAK, tmo=600)
s.idle_bus(300)
s.show('irq_raw'); s.show('epi_int', 1)
print(s.save('ops/dev_axis_udf_s%d.ops' % seed))
