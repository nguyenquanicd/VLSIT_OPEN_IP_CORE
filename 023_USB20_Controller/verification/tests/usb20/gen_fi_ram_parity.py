"""t_fi_ram_parity: RAM parity error on the packet path (faulty RAM model sim/models/sram_fault.sv; argument in or out).
The fault flips one bit of the N-th RAM read (+par_nth=N +par_bit=B from the extra column of testlist.csv); the scenario assumes the
first RAM reads after bring-up are those of the packet under test.

Test ID and title: t_fi_ram_parity - parity error on an IN packet read and on an OUT packet drain: flag, recovery
Priority and rationale: P2. The only RAM protection of the IP (REQ-FUNC-040).
Purpose: show that a parity error on a RAM read sets irq_raw.ram_par, and that after clearing the flag and re-arming the same transfer
  works (the RAM is not damaged).
Requirements and features: REQ-FUNC-040; REQ-ERR-001. Features fifo_mgr (RAM parity).
DUT configuration and preconditions: build dev_utmi8_axim_fault (fault RAM model replaces the RAM cell); device bring-up at a random
  address; plusargs +par_nth/+par_bit select the faulty read (four rows of testlist.csv: in 5/0, in 7/32, out 3/0, out 9/17).
Software flow:
  1. Bring-up; read ram_par 0.
  2. (in) arm IN 2; after the faulty read read ram_par 1; clear; re-arm and receive; read done and ram_par 0.
  3. (out) arm OUT 1; after the drain read ram_par 1; clear; re-arm at 0x2200; compare memory; read ram_par 0.
Stimulus: one IN token (in) or one OUT packet (out) whose RAM read is corrupted, then a clean repeat.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FRP-FLAG0 | REQ-FUNC-040 | after bring-up | irq_raw.ram_par 0 (no false alarm) | TB R | one access | flag already set
  FRP-INFLAG | REQ-FUNC-040 | IN token whose packet read hits the fault (in) | irq_raw.ram_par 1 | TB R | 400 CLK-PHY + 300 bus cycles | no flag
  FRP-INRETRY | REQ-FUNC-040 | re-armed IN after clearing (in) | DATA0 with the original 64 bytes, done, ram_par 0 | TB XD, R | 2000 CLK-PHY | the repeat fails or the flag returns
  FRP-OUTACK | REQ-FUNC-004 | OUT packet (out) | ACK (the error happens later, during the drain) | TB XH, GAP | 400 CLK-PHY | no ACK
  FRP-OUTFLAG | REQ-FUNC-040 | drain of the OUT packet hits the fault (out) | irq_raw.ram_par 1 | TB R | 2500 bus cycles | no flag
  FRP-OUTRETRY | REQ-FUNC-040 | re-armed OUT at 0x2200 (out) | ACK, the 64 bytes in memory, ram_par 0 | TB XH, MC, R | 2500 bus cycles | the repeat fails
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: the flag is raised by each injected fault and the path works again after recovery.
Known gaps (not checked, so not claimed): (in) whatever the device sent after the faulty read is discarded unchecked (FLUSH), so "no
  wrong data is sent" is not verified; (out) the memory at 0x2000 after the faulty drain is not compared, so "the corrupted packet is
  not written" is not verified.
Defect/fault targeted: parity not generated or not checked, flag not raised, RAM state broken after an error.
Checker/oracle: fault model with a known flipped bit; REQ-FUNC-040 in this script; harness R/XD/XH/MC.
Reproducibility: cd tests/usb20; python gen_fi_ram_parity.py 1 in (or out); from verification:
  python env/scripts/run.py sim t_fi_ram_parity dev_utmi8_axim_fault tests/ops/fi_ram_parity_in_s1.ops +seed=1 +par_nth=5 +par_bit=0
  (the other rows: in +par_nth=7 +par_bit=32; out +par_nth=3 +par_bit=0; out +par_nth=9 +par_bit=17)
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_ram_parity in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
part = sys.argv[2] if len(sys.argv) > 2 else 'in'
s = Scn('fi_ram_parity_' + part, seed=seed)
ADDR = s.rng.randrange(1, 128)
MPS = 64
d, _ = dev_bringup(s, address=ADDR)
s.chk('FRP-FLAG0')
s.r('irq_raw', ram_par=0)
if part == 'in':
    pin = s.rnd(MPS)
    arm_in(s, 2, pin, MPS, 0x4000, set_d0=1)
    s.token(IN, ADDR, 2)
    s.wait(400)                                            # the faulty read aborts the packet: whatever was sent is not a good packet
    s.emit('FLUSH')
    s.idle_bus(300)
    s.chk('FRP-INFLAG')
    s.r('irq_raw', ram_par=1)
    s.bin('cg_par.in')
    s.wraw('irq_raw', 0, IRQ_ALL)
    s.w1c('epi_int', 2, done=1)
    arm_in(s, 2, pin, MPS, 0x4000, set_d0=1)               # re-arm: the transfer works again
    d.tog_in[2] = 0
    s.chk('FRP-INRETRY')
    d.in_(2, pin)
    s.idle_bus(1500)
    s.r('epi_int', 2, done=1)
    s.r('irq_raw', ram_par=0)
else:
    po = s.rnd(MPS)
    arm_out(s, 1, MPS, 1, MPS, 0x2000, set_d0=1)
    s.chk('FRP-OUTACK')
    d.out(1, po)                                           # the packet is received and acknowledged
    s.idle_bus(2500)                                       # the drain reads the rows: the faulty read is among them
    s.chk('FRP-OUTFLAG')
    s.r('irq_raw', ram_par=1)
    s.bin('cg_par.out')
    s.wraw('irq_raw', 0, IRQ_ALL)
    s.w1c('epo_int', 1, done=1)
    arm_out(s, 1, MPS, 1, MPS, 0x2200, set_d0=1)
    d.tog_out[1] = 0
    p2 = s.rnd(MPS)
    s.chk('FRP-OUTRETRY')
    d.out(1, p2)
    s.idle_bus(2500)
    s.mc(0x2200, p2)
    s.r('irq_raw', ram_par=0)
print(s.save('ops/fi_ram_parity_%s_s%d.ops' % (part, seed)))
