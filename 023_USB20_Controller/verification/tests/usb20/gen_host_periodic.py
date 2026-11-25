"""t_host_periodic: periodic scheduling before bulk.

Test ID and title: t_host_periodic - polled interrupt IN served before a bulk OUT that became ready together; three polls
Priority and rationale: P2. Periodic-first scheduling is a USB 2.0 rule; violating it breaks interrupt latency guarantees.
Purpose: show that the periodic IN token comes first, the bulk OUT follows, no second IN token comes within a microframe after a poll,
  the interrupt channel polls three times and both channels finish with the data in memory.
Requirements and features: REQ-FUNC-015, 032; USB 2.0 5.7.4, 11.18. Features host_sched, host_sof.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up at high speed.
Software flow:
  1. Program channel 0 (bulk OUT 64 bytes) and channel 1 (interrupt IN 3 x 8 bytes, poll_en, poll_rep, interval 2).
  2. Poll done of both; compare the interrupt data; clear; read irq_raw.
Stimulus: device answers DATA0, DATA1, DATA0 to the polls and ACK to the bulk OUT.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HPD-FIRST | REQ-FUNC-032 | both channels ready | the first token is the periodic IN to endpoint 3; ACK after its data | TB XT, XH | 30000 CLK-PHY | the bulk OUT goes first
  HPD-BULK | REQ-FUNC-015 | after the poll | OUT token and DATA0 with the 64 bytes | TB XT, XD | 30000 CLK-PHY | bulk starved or wrong data
  HPD-INTERVAL | REQ-FUNC-032 | after the first poll | no further packet for one microframe (125 us scaled) | TB XN | 125 us scaled | a second poll inside the interval
  HPD-POLLS | REQ-FUNC-032 | next intervals | two more IN tokens, ACK after DATA1 and DATA0 | TB XT, XH | 30000 CLK-PHY | a poll missing
  HPD-DONE | REQ-FUNC-015, REQ-IF-006 | end | done on both channels; the 24 interrupt bytes at 0x6100 | TB P, MC | 900 polls | done missing or memory wrong
  HPD-CLEAN | REQ-ERR-001 | end | no crc_err, pid_err, babble | TB R | end | an error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: periodic first, interval respected after the first poll, all data delivered.
Known gaps: only the interval after the first poll is measured; the spacing of the second and third polls is not.
Defect/fault targeted: bulk scheduled before periodic, polling faster than the interval, re-arm of the polled channel missing.
Checker/oracle: USB 2.0 periodic-first rule and REQ-FUNC-032 in this script; harness XT/XD/XH/XN/P/MC/R.
Reproducibility: cd tests/usb20; python gen_host_periodic.py SEED ts16 (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_periodic host_utmi8_axim_ts16 tests/ops/host_periodic_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_periodic in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_periodic', seed=seed)
s.emit('WD', 200000)
host_bringup(s)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
UF = 125000 // usb2lib.TS * 1.0                                   # one microframe in ns
pi = [s.rnd(8) for _ in range(3)]
po = s.rnd(64)
s.mw(0x6000, po)
s.wait(max(3000, us(500)))
# the bulk channel first, then the periodic one: both become ready within a few cycles
hc_program(s, 0, 0, 2, 0, BULK, 64, 64, 1, 0x6000, pid=0)
hc_program(s, 1, 0, 3, 1, INTR, 8, 24, 3, 0x6100, pid=0, poll_en=1, poll_rep=1, interval=2)
s.chk('HPD-FIRST')
s.xt(IN, 0, 3, TMO)                                              # the periodic IN token comes first (REQ-FUNC-032)
s.bin('cg_sched.periodic_first')
s.data(DATA0, pi[0])
s.xh(ACK, tmo=2000)
s.chk('HPD-BULK')
p.out(2, DATA0, po)                                              # the bulk OUT follows in the same or the next microframe
s.chk('HPD-INTERVAL')
s.xn(int(us(125)))                                               # no further IN token within a microframe after a poll
s.chk('HPD-POLLS')
for k in (1, 2):
    p.in_(3, DATA1 if k == 1 else DATA0, pi[k])
s.chk('HPD-DONE')
s.poll('hc_int', 0, tries=900, done=1)
s.poll('hc_int', 1, tries=900, done=1)
s.idle_bus(600)
s.mc(0x6100, sum(pi, []))                                        # the three interrupt IN packets in memory (oracle audit 2026-11-24: nc_mem GAP)
s.bin('cg_poll.rearm')
s.w1c('hc_int', 0, **ALL); s.w1c('hc_int', 1, **ALL)
s.chk('HPD-CLEAN')
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_periodic_s%d.ops' % seed))
