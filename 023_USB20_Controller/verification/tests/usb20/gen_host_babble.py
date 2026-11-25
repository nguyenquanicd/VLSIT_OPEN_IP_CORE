"""t_host_babble: babble seen by the host (fault injection; argument fs for a full-speed device).

Test ID and title: t_host_babble - packet longer than the channel maximum and longer than 1024 bytes: no ACK, babble flags, port still works
Priority and rationale: P2. Acknowledging babble corrupts the device state; kills M16 (BUG-038).
Purpose: show that a packet longer than the channel maximum is not acknowledged and sets hc_int.babble only (DEC-043), that a packet
  longer than 1024 bytes sets the global irq_raw.babble, and that the port still moves data afterwards.
Requirements and features: REQ-ERR-001, 002; DEC-043; BUG-038. Features host_sched, fifo_mgr.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up at high speed (full speed with argument fs).
Software flow:
  1. Program channel 0 (IN, 64 bytes); poll hc_int.babble; read irq_raw.babble 0; clear.
  2. Program channel 2 (IN, 64 bytes); poll irq_raw.babble; clear both.
  3. Program channel 1 (IN 24 bytes, short_end); poll done; compare memory.
Stimulus: device answers 70 bytes, then 1030 bytes, then a normal 24-byte packet.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HBB-NOACK | REQ-ERR-002, BUG-038 | 70-byte DATA0 into a 64-byte channel | IN token, then no ACK of the host | TB XT, XN | 400 CLK-PHY | the babble packet is acknowledged
  HBB-CHFLAG | REQ-ERR-002, DEC-043 | after the babble packet | hc_int.babble set; irq_raw.babble stays 0 | TB P, R | 900 polls | flag missing or the global flag set
  HBB-GLOBAL | REQ-ERR-001 | 1030-byte DATA1 | IN token, no ACK, irq_raw.babble set | TB XT, XN, P | 900 polls | no global babble
  HBB-RECOVER | REQ-ERR-002 | normal IN on channel 1 | ACK after the 24 bytes, done, data in memory | TB XT, XH, P, MC | 900 polls | the port no longer works
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV. (HBU-CHIRP only at high speed)
Expected outcome: babble is never acknowledged, reported at the right level, and does not break the port.
Known gaps: the channel halt (ch_halt) and the memory behind the babble buffers (0x3000, 0x5000, prefilled) are not compared, so "no
  data beyond the maximum packet size is stored" is not verified.
Defect/fault targeted: babble acknowledged (M16, BUG-038); wrong flag level.
Checker/oracle: REQ-ERR-002 and DEC-043 in this script; harness XT/XN/XH/P/R/MC; qualified by M16.
Reproducibility: cd tests/usb20; python gen_host_babble.py SEED ts16 (and SEED fs ts16) (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_babble host_utmi8_axim_ts16 tests/ops/host_babble_sSEED.ops (host_babble_fs_sSEED.ops) +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_babble in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
FS = 'fs' in sys.argv
s = Scn('host_babble', seed=seed)
s.emit('WD', 60000)
host_bringup(s, hs=not FS)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
MPS = 64
s.mw(0x3000, [0xA5] * 96)
hc_program(s, 0, 0, 2, 1, BULK, MPS, MPS, 1, 0x3000, pid=0, speed=1 if FS else 0)
s.chk('HBB-NOACK')
s.xt(IN, 0, 2, TMO)
s.data(DATA0, s.rnd(MPS + 6))                                    # 70 bytes into a 64-byte channel
s.xn(400)                                                       # babble is not acknowledged (BUG-038)
s.chk('HBB-CHFLAG')
s.poll('hc_int', 0, tries=900, babble=1)
s.r('irq_raw', babble=0)                                          # longer than the channel maximum only: channel flag, not the global one (DEC-043)
s.bin('cg_babble.fs' if FS else 'cg_babble.hs')
s.w1c('hc_int', 0, **ALL)
# a packet longer than the largest legal packet (1024 bytes) is babble for the whole controller (REQ-ERR-001)
MPS2 = 64
s.mw(0x5000, [0x5A] * 64)
hc_program(s, 2, 0, 2, 1, BULK, MPS2, MPS2, 1, 0x5000, pid=0, speed=1 if FS else 0)
s.chk('HBB-GLOBAL')
s.xt(IN, 0, 2, TMO)
s.data(DATA1, s.rnd(1030))
s.xn(400)
s.poll('irq_raw', tries=900, babble=1)
s.bin('cg_err.babble')
s.w1c('hc_int', 2, **ALL)
s.w1c('irq_raw', babble=1)
# the port still works: a normal transfer on another channel
pi = s.rnd(24)
hc_program(s, 1, 0, 3, 1, BULK, MPS, 24, 1, 0x4000, pid=0, speed=1 if FS else 0, short_end=1)
s.chk('HBB-RECOVER')
p.in_(3, DATA0, pi)
s.poll('hc_int', 1, tries=900, done=1)
s.mc(0x4000, pi)
s.w1c('hc_int', 1, **ALL)
print(s.save('ops/host_babble%s_s%d.ops' % ('_fs' if FS else '', seed)))
