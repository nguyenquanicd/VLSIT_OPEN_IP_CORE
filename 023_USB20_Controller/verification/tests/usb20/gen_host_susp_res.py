"""t_host_susp_res: selective suspend and resume of the host port (high speed; argument fs: full speed).
The SOF phase of REQ-FUNC-037 is not checked here (SOF jitter at TSCALE 16, FND-009); t_dir_clkstop checks it at TSCALE 1.

Test ID and title: t_host_susp_res - host port suspend stops SOF, resume K of at least 20 ms, SOF restarts within 3 ms
Priority and rationale: P1, rank 4 of the R-283 list. Its checks were vacuous before 2026-11-24 (INTEGRITY_HOLD); BUG-048 (SOF during
  suspend) hid behind them; kills M27.
Purpose: show that hport.port_susp stops every packet of the host, sets port_susp_sts and the suspend interrupt, that port_res drives
  resume K for 20 ms or more, and that SOF restarts within 3 ms with the resume interrupt and port_susp_sts cleared.
Requirements and features: REQ-FUNC-020, 037, REQ-FUNC-010; FEAT-012. USB 2.0 7.1.7.6, 7.1.7.7, 11.9.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up at high speed (full speed with argument fs); SOF on.
Software flow:
  1. Bring-up (hostlib); after three microframes clear irq_raw suspend and resume.
  2. Write hport.port_susp; poll hsts.port_susp_sts and irq_raw.suspend.
  3. Clear suspend; write hport.port_res; after the resume poll irq_raw.resume; read hsts (port_susp_sts 0, port_en 1).
Stimulus: register writes only; the device partner is idle (J) during suspend.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HSR-SOF | REQ-FUNC-010 | before the suspend | at least 3 SOF since the last check, interval 125 us (1 ms full speed) +-10 percent scaled | TB SOF | 500 us (3.5 ms fs) scaled | SOF missing or off interval
  HSR-SUSP | REQ-FUNC-020, DEC-048 | hport.port_susp written | hsts.port_susp_sts and irq_raw.suspend set; mode pins in the suspend row 01 / 1 / 00 with SuspendM 0 (also for a high-speed port: the high-speed terminations would hold SE0 and reset the device) | TB P, XP | 3000 and 400 polls | status, interrupt or row wrong
  HSR-QUIET | REQ-FUNC-020 (BUG-048) | port suspended | no SOF for 4 ms (scaled) and no other packet | TB NSOF, XN | 4 ms scaled | any packet while suspended
  HSR-RESK | REQ-FUNC-020, USB 2.0 7.1.7.7, DEC-048 | hport.port_res written | resume row 01 / 1 / 10 (full-speed signaling also for a high-speed port), resume K stream of 19.5 to 60 ms (scaled) | TB WP, XC | 70 ms scaled | no resume K, shorter than 20 ms or the high-speed row
  HSR-SOFRST | REQ-FUNC-020, 037 | end of the resume K | at least one SOF within 3 ms | TB SOF | 3 ms scaled | no SOF after the resume
  HSR-RESSTS | REQ-FUNC-020 | after the resume | irq_raw.resume set; hsts port_susp_sts 0 and port_en 1 | TB P, R | 400 polls | flag missing or the port disabled
  HSR-SOF2 | REQ-FUNC-010 | after the resume | back in the speed row (00 / 0 / 00 high speed, 01 / 1 / 00 full speed); at least 3 SOF at the regular interval; no crc_err, pid_err or babble flag | TB XP, SOF, R | 500 us scaled | wrong row, irregular SOF or an error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP (high speed only), HBU-RST50, HBU-RECOV (hostlib.py).
Expected outcome: suspend silences the port, resume restores SOF; no error flags.
Defect/fault targeted: SOF sent while suspended (M27, BUG-048); high-speed row kept in suspend or used for resume (M29, M30, DEC-048);
  resume K too short; status not cleared after resume.
Checker/oracle: timing values from USB 2.0 and REQ-FUNC-020 (scaled by TSCALE); harness SOF/NSOF/XN/XC/P/R; qualified by M27 and the
  negative-control audit.
Reproducibility: cd tests/usb20; python gen_host_susp_res.py 1 ts16 (and 1 fs ts16); from verification:
  python env/scripts/run.py sim t_host_susp_res host_utmi8_axim_ts16 tests/ops/host_susp_res_s1.ops +seed=1
Waveform: rank 4 of sim/waveform_index.csv (high-speed variant; testbench top level, whole run);
  python env/scripts/priority_waves.py t_host_susp_res
Evidence: runs of t_host_susp_res in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_susp_res', seed=seed)
s.emit('WD', 120000)
FS = 'fs' in sys.argv
host_bringup(s, hs=not FS)
SOF_NS = (1000000 if FS else 125000) / usb2lib.TS
TOL = 62.5 if usb2lib.TS == 1 else SOF_NS * 0.10
LO, HI = int(SOF_NS - TOL), int(SOF_NS + TOL)
s.wait(max(3000, us(3500 if FS else 500)))
s.chk('HSR-SOF')
s.emit('SOF', 3, LO, HI)
s.w1c('irq_raw', suspend=1, resume=1)
# ---- selective suspend
s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_susp=1)
s.chk('HSR-SUSP')
s.poll('hsts', tries=3000, port_susp_sts=1)
s.poll('irq_raw', tries=400, suspend=1)
s.xp(0, mode(1, 1, 0, pd=1), MODE_MASK | (1 << 5))              # suspend row 01 / 1 / 00 with SuspendM 0 also for a HS port (DEC-048 PHY-02)
s.emit('SOF', 0, 0, 0xFFFFFFF)                                   # restart the SOF statistics
s.chk('HSR-QUIET')
s.emit('NSOF', us(4000))                                        # no SOF while suspended (SOF packets do not reach XN)
s.emit('XN', 20)                                                # and no other packet
s.bin('cg_sofphase.suspend')
# ---- resume: K for at least 20 ms, then SOF within 3 ms
s.w1c('irq_raw', suspend=1)
s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_res=1)
s.chk('HSR-RESK')
s.wp(0, mode(1, 1, 2, pd=1) | (1 << 5), MODE_MASK | (1 << 5), us(2000))   # resume row 01 / 1 / 10 (DEC-048 PHY-03)
s.xc(us(19500), us(60000), 0x00, us(70000))                      # resume K stream
s.bin('cg_hres.fs' if FS else 'cg_hres.hs')
s.emit('SOF', 0, 0, 0xFFFFFFF)
s.wait(us(3000))
s.chk('HSR-SOFRST')
s.emit('SOF', 1, 0, 0xFFFFFFF)                                  # at least one SOF within 3 ms after the end of the resume
s.bin('cg_hres.sof')
s.chk('HSR-RESSTS')
s.poll('irq_raw', tries=400, resume=1)
s.r('hsts', port_susp_sts=0, port_en=1)
s.wait(max(3000, us(3500 if FS else 500)))
s.chk('HSR-SOF2')
s.xp(0, (mode(1, 1, 0, pd=1) if FS else mode(0, 0, 0, pd=1)) | (1 << 5), MODE_MASK | (1 << 5))   # back to the speed row
s.emit('SOF', 3, LO, HI)
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_susp_res%s_s%d.ops' % ('_fs' if FS else '', seed)))
