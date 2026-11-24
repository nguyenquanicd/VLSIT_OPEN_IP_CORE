"""t_fi_ulpi_abort: the ULPI PHY raises DIR during a transmit and during a register write (fault injection).

Test ID and title: t_fi_ulpi_abort - transmit aborted by DIR at 0 to 30 bytes, repeat with the same data; aborted register write retried
Priority and rationale: P2. ULPI turnaround collisions are normal PHY behaviour; a link that loses state there fails in the field.
Purpose: show that after a DIR abort the repeated IN gets the same data and toggle, that the link performs its PHY register writes, and
  that an aborted function-control write is retried so the PHY ends in full speed and then suspended.
Requirements and features: REQ-IF-003; ERR-010; ULPI 1.1 (3.8.2 DIR abort, 3.8.3 register access). Features ulpi_if.
DUT configuration and preconditions: build dev_ulpi_axim (ULPI wrapper and the ULPI PHY BFM); device bring-up; IN endpoint 2 armed
  with 6 packets.
Software flow:
  1. Bring-up; arm IN 2 (6 packets, set_d0).
  2. lpm_cfg write; the host stops (idle), the device reverts to full speed and suspends (the link writes the PHY registers).
Stimulus: op AB makes the BFM raise DIR after 0, 1, 2, 3, 5, 9 bytes of the device packet; AB 0xFFFFFFFF aborts the next register write.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FUA-RETRY | REQ-IF-003, ERR-010 | IN repeated after the aborted answer | the same 64 bytes with the same data PID (toggle unchanged); ACK accepted | TB XD | 400 CLK-PHY | changed data or toggle, or no answer
  FUA-REGW | REQ-IF-003 | after the IN part | at least four PHY register writes seen by the BFM | TB XR | immediately | fewer writes
  FUA-FSREV | REQ-FUNC-018, ULPI 3.8.3 | 3 ms idle | the PHY function control holds the full-speed row | TB WP (virtual UTMI+ mode pins) | 3.125 ms + 600 cycles scaled | the write is lost
  FUA-SUSP | ERR-010, ULPI 3.8.3 | the next register write is aborted | the write is retried: SuspendM written as 0 within 10 ms | TB WP | 10 ms scaled | the aborted write is never completed
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: no data or toggle lost by an abort; the PHY registers end with the wanted values.
Known gaps: the truncated packet after DIR is discarded unchecked (FLUSH); mutant M09 (abandoned TX CMD left on the data bus after a DIR
  abort, BUG-028, hardening only) survives this test (sim/coverage/mutation_report.md).
Defect/fault targeted: toggle advanced on an aborted packet, register write dropped after an abort.
Checker/oracle: ULPI 1.1 rules in this script and the ULPI PHY BFM (env/tb/ulpi_phy_bfm.sv) with its bus checks; harness XD/XR/WP.
Reproducibility: cd tests/usb20; python gen_fi_ulpi_abort.py SEED (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_ulpi_abort dev_ulpi_axim tests/ops/fi_ulpi_abort_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_ulpi_abort in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_ulpi_abort', seed=seed)
ADDR = s.rng.randrange(1, 128)
MPS = 64
d, _ = dev_bringup(s, address=ADDR)
pin = s.rnd(MPS * 6)
arm_in(s, 2, pin, MPS, 0x4000, pkts=6, set_d0=1)
d.tog_in[2] = 0
n = 0
for after in (0, 1, 2, 3, 5, 9, 17, 30):
    # IN token; the answer is aborted (DIR rises) after a different number of data bytes each time
    s.emit('AB', after)
    s.token(IN, ADDR, 2)
    s.wait(120)
    s.emit('FLUSH')                                          # the truncated packet is not a packet
    s.bin('cg_ulpi.abort_tx')
    # the repeated token gets the same data again; the host acknowledges it only now
    s.token(IN, ADDR, 2)
    s.chk('FUA-RETRY')
    s.xd(DATA0 if d.tog_in[2] == 0 else DATA1, pin[n * MPS:(n + 1) * MPS], tmo=400)
    s.wait(8)
    s.hs(ACK)
    d.tog_in[2] ^= 1
    n += 1
    s.wait(40)
    if n == 6:
        break
s.idle_bus(1500)
# register access abort: change the PHY mode (suspend and wake through CSR) while DIR pulses; the registers must end right
s.chk('FUA-REGW')
s.emit('XR', 4, 0)                                           # at least four register writes so far (two at start, mode changes)
s.bin('cg_ulpi.abort_reg'); s.bin('cg_ulpi.regwr')                          # the XR check above needs at least four PHY register writes
s.w('lpm_cfg', resp=0, lpm_en_rt=1)
s.idle_bus(300)
s.emit('SG', 0, 300)
s.token(SOF, 0x21, 0x1)
s.chk('FUA-FSREV')
s.wp(0, mode(1, 1, 0), MODE_MASK, us(3125) + 600)            # full-speed reversion: the link writes the function control register
s.emit('AB', 0xFFFFFFFF)                                     # the next register write is aborted before the PHY accepts it
s.linestate(1)
s.bin('cg_ulpi.rxcmd_idle')                                      # a line state change in an idle bus travels as an RX CMD
s.chk('FUA-SUSP')
s.wp(0, 0, 1 << 5, us(10000))                                # suspended: SuspendM written as 0
s.bin('cg_ulpilp.enter')
print(s.save('ops/fi_ulpi_abort_s%d.ops' % seed))
