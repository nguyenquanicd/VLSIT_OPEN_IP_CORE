"""t_host_fs: host with a full-speed device (no chirp).

Test ID and title: t_host_fs - full-speed attach and reset, 1 ms SOF, bulk OUT and IN at full speed
Priority and rationale: P2. Full-speed devices behind a high-speed host port are common (keyboards, serial adapters).
Purpose: show that without a device chirp the port ends the reset at full speed (port_speed 1) after 50 ms, sends SOF every frame and
  moves one bulk OUT and one bulk IN packet.
Requirements and features: REQ-FUNC-010, 011, 012, 015, 016. Features connect_detect, port_reset, host_sof, host_sched, data_toggle.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up with hs=False (the device never chirps).
Software flow:
  1. Bring-up (full speed); after 3.5 ms check SOF.
  2. Channel 0 OUT 40 bytes (speed full); poll done. Channel 1 IN 24 bytes (short_end); poll done; compare memory. Read irq_raw.
Stimulus: J on attach, no chirp; DATA0 from the device.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HFS-SOF | REQ-FUNC-010 | after sof_en | at least 3 SOF, interval 1 ms +-10 percent (scaled) | TB SOF | 3.5 ms scaled | microframe SOF on a full-speed port
  HFS-OUT | REQ-FUNC-015, 016 | channel 0 OUT | OUT token and DATA0 with the 40 bytes; done | TB XT, XD, P | 30000 CLK-PHY | wrong packet or no done
  HFS-IN | REQ-FUNC-016 | channel 1 IN | IN token, ACK after the 24 bytes; done; memory | TB XT, XH, P, MC | 2000 CLK-PHY | no ACK or memory wrong
  HFS-CLEAN | REQ-ERR-001 | end | no crc_err, pid_err, babble | TB R | end | an error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-RST50, HBU-RECOV (full-speed reset: no chirp).
Expected outcome: the port runs at full speed with frame SOF and both transfers complete.
Defect/fault targeted: high speed assumed without a chirp, microframe timing on a full-speed port, reset shorter than 50 ms (BUG-047).
Checker/oracle: USB 2.0 7.1.7.5 and chapter 8 in this script; harness WP/TC/SOF/XT/XD/XH/P/MC/R.
Reproducibility: cd tests/usb20; python gen_host_fs.py SEED ts16 (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_fs host_utmi8_axim_ts16 tests/ops/host_fs_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_fs in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_fs', seed=seed)
s.emit('WD', 60000)
speed = host_bringup(s, hs=False)
assert speed == 'fs'
s.bin('cg_conn.fs'); s.bin('cg_speed.fs')
FR = 1000000 / usb2lib.TS                                   # frame in ns
TOL = 62.5 if usb2lib.TS == 1 else FR * 0.10
s.wait(max(3000, us(3500)))
s.chk('HFS-SOF')
s.emit('SOF', 3, int(FR - TOL), int(FR + TOL))
s.bin('cg_sof.fs')
p = DevPartner(s, 0)
po = s.rnd(40)
s.mw(0x1000, po)
hc_program(s, 0, 0, 1, 0, BULK, 64, 40, 1, 0x1000, pid=0, speed=1)
s.chk('HFS-OUT')
p.out(1, DATA0, po)
s.poll('hc_int', 0, done=1)
s.w1c('hc_int', 0, done=1)
pi = s.rnd(24)
hc_program(s, 1, 0, 2, 1, BULK, 64, 24, 1, 0x2000, pid=0, speed=1, short_end=1)
s.chk('HFS-IN')
p.in_(2, DATA0, pi)
s.poll('hc_int', 1, done=1)
s.mc(0x2000, pi)
s.w1c('hc_int', 1, done=1)
s.chk('HFS-CLEAN')
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_fs_s%d.ops' % seed))
