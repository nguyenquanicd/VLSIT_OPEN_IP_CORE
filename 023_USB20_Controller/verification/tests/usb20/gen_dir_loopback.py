"""t_dir_loopback: link loopback (REQ-FUNC-035, FEAT-022, OP-022, TEST-029) on the host build.
The traffic is the SOF token sent every (scaled) frame, so the good-packet count grows with time.

Test ID and title: t_dir_loopback - ctrl.lpbk: idle PHY pins, loopback row, good-packet counter, saturation at 4095, clear
Priority and rationale: P3. Production test feature; kills M05 (loopback mode pins not forced).
Purpose: show that with ctrl.lpbk the PHY pins show the loopback row and send nothing, u2_lpbk_sts counts good packets, saturates at
  4095, keeps its value after leaving loopback and clears with lpbk_sts.clr.
Requirements and features: REQ-FUNC-035; FEAT-022; OP-022; TEST-029; section 6.3 loopback row. Features loopback.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up at high speed (SOF running).
Software flow:
  1. Bring-up; read lpbk_sts 0.
  2. ctrl.lpbk 1; lpbk_sts.clr; poll pkt_ok bit 3; wait for saturation; read 4095.
  3. ctrl.lpbk 0; read lpbk_sts (still 4095); lpbk_sts.clr; read 0; read irq_raw.
Stimulus: register writes; time for about 4100 SOF tokens.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DLB-OFF | REQ-FUNC-035 | normal operation | pkt_ok 0, pkt_err 0 | TB R | one access | counting outside loopback
  DLB-PINS | REQ-FUNC-035, section 6.3 | ctrl.lpbk 1 | loopback row (FS, TermSelect 1, OpMode 01b, pull-downs) and no packet on the PHY for 400 us | TB WP, XN | 4000 CLK-PHY, 400 us scaled | a packet leaves the IP or a wrong row
  DLB-COUNT | TEST-029 | loopback running | pkt_ok reaches at least 8 | TB P | 400 polls | no good packets counted
  DLB-SAT | TEST-029 | after about 4100 tokens | pkt_ok 4095 (saturated), pkt_err 0; still no packet on the PHY | TB R, XN | 4.3 s scaled | wrap-around or a packet out
  DLB-EXIT | OP-022 | ctrl.lpbk 0 | lpbk_sts still 4095 (the frozen value is only shown by two RP prints; with a saturated counter this does not prove freezing) | TB R | 200 cycles | the counter changes or clears on exit
  DLB-CLR | OP-022 | lpbk_sts.clr | pkt_ok 0, pkt_err 0; no crc_err or pid_err | TB R | 100 cycles | clear does not work
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: loopback isolates the PHY and counts every good packet up to saturation; clear works.
Known gaps: a corrupted packet cannot be made inside the IP, so pkt_err is only checked to stay 0 (TEST-029 bad-packet part not covered).
Defect/fault targeted: loopback mode pins not forced (M05, BUG-029); counter wrap instead of saturation; clear not working.
Checker/oracle: REQ-FUNC-035 and the section 6.3 table in this script; harness WP/XN/P/R; qualified by M05.
Reproducibility: cd tests/usb20; python gen_dir_loopback.py SEED ts16 (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dir_loopback host_utmi8_axim_ts16 tests/ops/dir_loopback_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dir_loopback in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dir_loopback', seed=seed)
s.emit('WD', 120000)
host_bringup(s)
A = addr('lpbk_sts')
s.chk('DLB-OFF')
s.r('lpbk_sts', pkt_ok=0, pkt_err=0)                      # nothing counted in normal operation
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1, lpbk=1)
s.w('lpbk_sts', clr=1)
s.chk('DLB-PINS')
s.wp(0, mode(1, 1, 1, pd=1), MODE_MASK, 4000)              # loopback row of section 6.3: FS, TermSelect 1, OpMode non-driving
s.emit('XN', us(400))                                     # PHY pins idle: no packet leaves the IP for 400 us (scaled)
s.bin('cg_lpbk.pins_idle')
s.chk('DLB-COUNT')
s.emit('P', A, 0x8, 0x8, 400)                             # packets are counted: bit 3 of pkt_ok (at least 8 packets)
s.bin('cg_lpbk.good')
s.wait(us(4300000))                                      # about 4100 SOF tokens at one per (scaled) full-speed frame: the counter stops at 4095
s.wait(us(400))
s.chk('DLB-SAT')
s.r('lpbk_sts', pkt_ok=0xFFF, pkt_err=0)
s.bin('cg_lpbk.saturate')
s.emit('XN', us(400))
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1, lpbk=0)
s.wait(200)
s.chk('DLB-EXIT')
s.emit('RP', A)
s.emit('RP', A)                                           # two reads after leaving loopback show the same value (frozen)
s.r('lpbk_sts', pkt_ok=0xFFF, pkt_err=0)
s.chk('DLB-CLR')
s.w('lpbk_sts', clr=1)
s.wait(100)
s.r('lpbk_sts', pkt_ok=0, pkt_err=0)                      # clear works
s.bin('cg_lpbk.clear')
s.r('irq_raw', crc_err=0, pid_err=0)
print(s.save('ops/dir_loopback_s%d.ops' % seed))
