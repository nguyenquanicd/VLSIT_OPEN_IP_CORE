"""t_fi_xq_full: the register command FIFO of the clock crossing (fault injection: CLK-PHY stopped to fill it).

Test ID and title: t_fi_xq_full - xq_free count, xq_ovf on a write to a full command FIFO, in-order drain, no overflow at a slow rate
Priority and rationale: P2. A dropped register write without a flag would be a silent software failure.
Purpose: show that u2_sts.xq_free counts the free entries (8 to 0), that a crossing write while xq_free is 0 is dropped and sets
  irq_raw.xq_ovf, that the accepted commands drain in order (the eighth address is in force, the dropped ones never arrive), and that
  writes at a slow rate never overflow.
Requirements and features: REQ-REG-002; REQ-CLK-003; ERR-016. Features csr_apb, cdc.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up at address 0; harness can stop CLK-PHY (PCLK).
Software flow:
  1. Clear irq_raw; read xq_free 8 and xq_ovf 0.
  2. With CLK-PHY stopped: 8 dctrl writes (read xq_free after each), a ninth write (xq_ovf), clear xq_ovf, a tenth write (xq_ovf again).
  3. CLK-PHY on: read xq_free 8; the device answers only at the eighth address.
  4. 12 dctrl writes with 60 bus cycles between them; read xq_ovf 0 and xq_free 8.
Stimulus: register writes with CLK-PHY stopped and running; IN tokens to the candidate addresses.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FXQ-FREE8 | REQ-REG-002 | idle after bring-up | xq_free 8, xq_ovf 0 | TB R | one access | wrong count or a stale flag
  FXQ-FILL | REQ-REG-002 | 8 writes with CLK-PHY stopped | xq_free 7, 6, ... 0 after each; no xq_ovf | TB R | 12 bus cycles after each write | wrong count or early overflow
  FXQ-OVF | ERR-016 | ninth and tenth writes into the full FIFO | xq_ovf set, xq_free 0; W1C clears xq_ovf; set again by the tenth | TB R | 12 bus cycles | no flag or the flag does not clear
  FXQ-DRAIN | REQ-REG-002, REQ-CLK-003 | CLK-PHY running again | xq_free back to 8; no answer at the dropped addresses; NAK at the eighth address | TB R, XN, XH | 600 bus cycles, 120 CLK-PHY | a dropped write applied or the order broken
  FXQ-SLOW | REQ-CLK-003 | 12 writes 60 bus cycles apart | no xq_ovf, xq_free 8 | TB R | at the end | overflow at a rate the crossing can follow
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: the FIFO accepts 8 commands, drops and flags the rest, and applies the accepted ones in order.
Defect/fault targeted: free count off by one, dropped write without a flag, overwrite of a queued command, order changes.
Checker/oracle: REQ-REG-002 and ERR-016 in this script; harness R/XN/XH; negative-control audit.
Reproducibility: cd tests/usb20; python gen_fi_xq_full.py SEED (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_xq_full dev_utmi8_axim tests/ops/fi_xq_full_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_xq_full in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_xq_full', seed=seed)
d, _ = dev_bringup(s, address=0)
s.wraw('irq_raw', 0, IRQ_ALL)
s.idle_bus(200)
s.chk('FXQ-FREE8')
s.r('sts', xq_free=8)
s.r('irq_raw', xq_ovf=0)
addrs = [s.rng.randrange(1, 128) for _ in range(10)]
# ---- CLK-PHY stopped: eight writes fill the FIFO, the ninth and tenth are dropped
s.emit('SG', 0, 300)
s.emit('PCLK', 0)
s.chk('FXQ-FILL')
for i in range(8):
    s.w('dctrl', dev_addr=addrs[i], soft_conn=1)
    s.emit('IB', 12)
    s.r('sts', xq_free=7 - i)
s.r('irq_raw', xq_ovf=0)
s.chk('FXQ-OVF')
s.w('dctrl', dev_addr=addrs[8], soft_conn=1)
s.emit('IB', 12)
s.r('irq_raw', xq_ovf=1)
s.r('sts', xq_free=0)
s.bin('cg_xq.free0'); s.bin('cg_xq.ovf')
s.w1c('irq_raw', xq_ovf=1)
s.emit('IB', 12)
s.r('irq_raw', xq_ovf=0)
s.w('dctrl', dev_addr=addrs[9], soft_conn=1)
s.emit('IB', 12)
s.r('irq_raw', xq_ovf=1)
s.w1c('irq_raw', xq_ovf=1)
# ---- CLK-PHY runs again: the commands drain in order, the last accepted address (the eighth) is in force
s.chk('FXQ-DRAIN')
s.emit('PCLK', 1)
s.token(SOF, 0x31, 0x2)
s.emit('SG', 1, 300)
s.idle_bus(600)
s.r('sts', xq_free=8)
d.addr = addrs[7]
for a in (addrs[8], addrs[9]):
    if a != addrs[7]:
        s.token(IN, a, 0); s.xn(120)                      # the dropped writes never reached the engine
s.token(IN, addrs[7], 0); s.xh(NAK)                       # the device answers at the eighth address
# ---- slow CLK-BUS writes one by one never overflow
s.chk('FXQ-SLOW')
for i in range(12):
    s.w('dctrl', dev_addr=addrs[i % 10], soft_conn=1)
    s.emit('IB', 60)
s.r('irq_raw', xq_ovf=0)
s.r('sts', xq_free=8)
s.bin('cg_xreg.burst')
print(s.save('ops/fi_xq_full_s%d.ops' % seed))
