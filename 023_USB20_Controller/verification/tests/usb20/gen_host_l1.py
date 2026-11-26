"""t_host_l1: host LPM L1 entry and exit.

Test ID and title: t_host_l1 - host LPM transaction (EXT + LPM token), L1 entry stops SOF, short resume K, SOF continues
Priority and rationale: P2. L1 shares the quiet-port logic fixed by BUG-048; its check was vacuous before 2026-11-24.
Purpose: show that hport.lpm_req makes the host send an EXT token followed by an LPM token with SubPID 0011b, bLinkState 1, HIRD and
  bRemoteWake; after the device ACK the port enters L1 (lpm_evt, port_susp_sts, no SOF); port_res ends L1 and SOF continues.
Requirements and features: REQ-FUNC-021, 037, REQ-FUNC-010; USB 2.0 LPM ECN (L1, token format, resume).
DUT configuration and preconditions: build host_utmi8_axim_ts16; lpm_cfg resp 0, lpm_en_rt 1 before ctrl; host bring-up at high speed.
Software flow:
  1. Bring-up with lpm_cfg; clear irq_raw lpm_evt, suspend, resume.
  2. Write hport lpm_req with lpm_hird 5, lpm_rwake 1, lpm_addr 0; poll irq_raw.lpm_evt and hsts.port_susp_sts.
  3. Write hport.port_res; poll hsts.port_susp_sts = 0.
Stimulus: device ACK to the LPM token; idle line during L1.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HL1-SOF | REQ-FUNC-010 | before the LPM request | at least 3 SOF at 125 us +-10 percent (scaled) | TB SOF | 500 us scaled | SOF missing
  HL1-LPM | REQ-FUNC-021, LPM ECN token format | hport.lpm_req written | EXT token to address 0, then the LPM token whose address/endpoint fields carry bLinkState 1, HIRD 5, bRemoteWake 1 | TB XT | 30000 CLK-PHY each | wrong token or attribute bits
  HL1-ENTER | REQ-FUNC-021, DEC-048 | device ACK | irq_raw.lpm_evt and hsts.port_susp_sts set; suspend row 01 / 1 / 00 with SuspendM 0 | TB P, XP | 3000 polls each | no L1 entry or the high-speed row kept
  HL1-QUIET | REQ-FUNC-021 (BUG-048) | port in L1 | no SOF for 2 ms (scaled) and no other packet | TB NSOF, XN | 2 ms scaled | any packet in L1
  HL1-RESK | REQ-FUNC-021, DEC-048 | hport.port_res written | resume row 01 / 1 / 10, resume K of 40 us to 30 ms (scaled) | TB WP, XC | 40 ms scaled | no resume K or the high-speed row
  HL1-EXIT | REQ-FUNC-021, 037 | end of the resume | at least one SOF within 3 ms; hsts.port_susp_sts 0 | TB SOF, P | 3 ms scaled, 400 polls | no SOF or status stays set
  HL1-SOF2 | REQ-FUNC-010 | after L1 | at least 3 SOF at the regular interval; no crc_err or pid_err | TB SOF, R | 500 us scaled | irregular SOF or error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV (hostlib.py).
Expected outcome: one LPM transaction, L1 with a silent port, resume and regular SOF afterwards.
Defect/fault targeted: SOF during L1 (BUG-048, M27 class); wrong LPM attribute packing; L1 not left after port_res.
Checker/oracle: token fields from the LPM ECN and the CSR description; harness XT/SOF/NSOF/XN/XC/P/R; negative-control audit.
Reproducibility: cd tests/usb20; python gen_host_l1.py 1 ts16; from verification:
  python env/scripts/run.py sim t_host_l1 host_utmi8_axim_ts16 tests/ops/host_l1_s1.ops +seed=1
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_l1 in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_l1', seed=seed)
s.emit('WD', 120000)
host_bringup(s, extra=lambda sx: sx.w('lpm_cfg', resp=0, lpm_en_rt=1))
SOF_NS = 125000 / usb2lib.TS
TOL = 62.5 if usb2lib.TS == 1 else SOF_NS * 0.10
LO, HI = int(SOF_NS - TOL), int(SOF_NS + TOL)
s.wait(max(3000, us(500)))
s.chk('HL1-SOF')
s.emit('SOF', 3, LO, HI)
HIRD, RW = 5, 1
attr = 1 | (HIRD << 4) | (RW << 8)
s.w1c('irq_raw', lpm_evt=1, suspend=1, resume=1)
s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, lpm_req=1, lpm_hird=HIRD, lpm_rwake=RW, lpm_addr=0)
s.chk('HL1-LPM')
s.xt(EXT, 0, 0, TMO)
s.xt(0x3, attr & 0x7F, (attr >> 7) & 0xF, TMO)
s.wait(8)
s.hs(ACK)
s.chk('HL1-ENTER')
s.poll('irq_raw', tries=3000, lpm_evt=1)
s.poll('hsts', tries=3000, port_susp_sts=1)
s.xp(0, mode(1, 1, 0, pd=1), MODE_MASK | (1 << 5))              # L1: suspend row 01 / 1 / 00 with SuspendM 0 (DEC-048 PHY-02)
s.emit('SOF', 0, 0, 0xFFFFFFF)
s.chk('HL1-QUIET')
s.emit('NSOF', us(2000))                                        # no SOF while the port is in L1 (SOF packets do not reach XN)
s.emit('XN', 20)
s.bin('cg_sofphase.l1')
s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_res=1)
s.chk('HL1-RESK')
s.wp(0, mode(1, 1, 2, pd=1) | (1 << 5), MODE_MASK | (1 << 5), us(2000))   # resume row 01 / 1 / 10 (DEC-048 PHY-03)
s.xc(us(40), us(30000), 0x00, us(40000))                        # L1 resume K, much shorter than the 20 ms of a selective suspend
s.emit('SOF', 0, 0, 0xFFFFFFF)
s.wait(us(3000))
s.chk('HL1-EXIT')
s.emit('SOF', 1, 0, 0xFFFFFFF)
s.poll('hsts', tries=400, port_susp_sts=0)
s.wait(max(3000, us(500)))
s.chk('HL1-SOF2')
s.emit('SOF', 3, LO, HI)
s.r('irq_raw', crc_err=0, pid_err=0)
print(s.save('ops/host_l1_s%d.ops' % seed))
