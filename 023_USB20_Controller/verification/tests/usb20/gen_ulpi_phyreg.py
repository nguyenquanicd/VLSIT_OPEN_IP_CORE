"""t_ulpi_phyreg: PHY register read through u2_phy_acc over ULPI.

Test ID and title: t_ulpi_phyreg - two reads of the ULPI function control register (04h) after high-speed entry return 40h
Priority and rationale: P3. Software access to PHY registers is a debug and bring-up feature.
Purpose: show that a read started through u2_phy_acc completes (start and busy fall) and returns the function control value 40h
  (XcvrSelect 00b, TermSelect 0, OpMode 00b, SuspendM 1) twice in a row, without bus errors.
Requirements and features: REQ-IF-003; OP-020; ULPI 1.1 4.2 (function control register). Features ulpi_if, csr_apb.
DUT configuration and preconditions: build dev_ulpi_axim; device bring-up at a random address (high speed).
Software flow:
  1. Bring-up.
  2. Twice: write phy_acc (reg_addr 04h, rd_wr 0, start); poll start 0 and busy 0; read rdata.
  3. Read irq_raw crc_err and pid_err.
Stimulus: register accesses only.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  UPR-DONE | OP-020 | phy_acc.start written | start and busy return to 0 | TB P | 2000 polls | the access never completes
  UPR-DATA | REQ-IF-003, ULPI 4.2 | read completed | rdata 40h | TB R | one access | another value
  UPR-CLEAN | REQ-ERR-001 | after both reads | no crc_err or pid_err | TB R | 300 bus cycles | an error flag (the register access disturbed the receive path)
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: both reads return 40h; no error flag.
Defect/fault targeted: register read turnaround on ULPI, stale or shifted read data, access never completing.
Checker/oracle: ULPI register map in this script; ULPI PHY BFM register model; harness P/R.
Reproducibility: cd tests/usb20; python gen_ulpi_phyreg.py SEED (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_ulpi_phyreg dev_ulpi_axim tests/ops/ulpi_phyreg_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_ulpi_phyreg in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('ulpi_phyreg', seed=seed)
d, speed = dev_bringup(s, address=s.rng.randrange(1, 128))
assert speed == 'hs'
for _ in range(2):
    s.w('phy_acc', reg_addr=0x04, rd_wr=0, start=1)
    s.chk('UPR-DONE')
    s.poll('phy_acc', tries=2000, start=0, busy=0)
    s.chk('UPR-DATA')
    s.r('phy_acc', rdata=0x40)
    s.bin('cg_ulpi.regrd')
s.idle_bus(300)
s.chk('UPR-CLEAN')
s.r('irq_raw', crc_err=0, pid_err=0)
print(s.save('ops/ulpi_phyreg_s%d.ops' % seed))
