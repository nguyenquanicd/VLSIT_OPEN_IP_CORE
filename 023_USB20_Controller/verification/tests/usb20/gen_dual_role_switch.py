"""t_dual_role_switch: role selection of the dual-role build (PARA_USB2_ROLE = 2).

Test ID and title: t_dual_role_switch - role follows ID only after detach, held during a session, CSR override wins, traffic in both roles
Priority and rationale: P2. A role change during a session would drop the link; only the dual-role build has this logic.
Purpose: show that the role follows the ID pin (B = device, A = host) only after the session ended (soft-disconnect or port power off),
  is held while a session runs, that role_chg is raised on each change, the PHY pull-downs follow the role, the override bits win over
  the pin, and both roles move data.
Requirements and features: REQ-FUNC-023; TEST-012. Features dual_role, port_reset, hs_chirp, connect_detect, dev_token_addr.
DUT configuration and preconditions: build dual_utmi8_axim_ts16 (ROLE 2); ID pin driven by the harness.
Software flow:
  1. ID = B: read sts (role 0); device bring-up; IN transfer.
  2. ID = A during the session: read sts and role_chg 0; soft-disconnect; poll role_chg; read role 1.
  3. Host bring-up; OUT transfer; ID = B during the session: held; hport power off; poll role_chg; role 0.
  4. ctrl role_ovr_en with role_ovr 1, then 0; ID = A (override still wins); override off (role 1).
Stimulus: ID pin changes, register writes, device and host traffic.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DRS-IDB | REQ-FUNC-023 | ID = B at start | sts.role 0, id_a_plug 0 | TB R | after 200 bus cycles | wrong role
  DRS-DEV | REQ-FUNC-023, TEST-012 | device session | pull-downs off; IN DATA0 with the 64 bytes | TB XP, XD | 400 CLK-PHY | wrong pull-downs or no device traffic
  DRS-HOLDDEV | REQ-FUNC-023 | ID = A during the device session | role stays 0 (id_a_plug 1); no role_chg | TB R | 3000 bus cycles | role changes inside a session
  DRS-TOHOST | REQ-FUNC-023 | soft-disconnect | role_chg; role 1 | TB P, R | 4000 polls | no change after detach
  DRS-HOST | REQ-FUNC-023, TEST-012 | host session | both pull-downs on; OUT token and data; done | TB XP, XT, XD, P | 900 polls | wrong pull-downs or no host traffic
  DRS-HOLDHOST | REQ-FUNC-023 | ID = B during the host session | role stays 1; no role_chg | TB R | 3000 bus cycles | role changes inside a session
  DRS-TODEV | REQ-FUNC-023 | port power off | role_chg; role 0; pull-downs off | TB P, R, XP | 4000 polls | no change
  DRS-OVR | REQ-FUNC-023 | role_ovr_en with role_ovr 1, 0; ID = A; override off | role 1, 0 with role_chg each; role 0 with ID = A; role 1 when the override is off | TB P, R | 4000 polls each | override ignored or pin ignored after it
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM, HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: the role changes exactly at the detach points and by override; both roles work.
Defect/fault targeted: role change during a session, missing role_chg, pull-downs not following the role, override priority.
Checker/oracle: REQ-FUNC-023 rules in this script; harness R/P/XP/XD/XT; negative-control audit.
Reproducibility: cd tests/usb20; python gen_dual_role_switch.py SEED ts16 (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dual_role_switch dual_utmi8_axim_ts16 tests/ops/dual_role_switch_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dual_role_switch in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *
from hostlib import host_bringup, hc_program, DevPartner

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dual_role_switch', seed=seed)
ADDR = s.rng.randrange(1, 128)
s.emit('WD', 120000)
HOST_PD = (0xC0, 0xC0)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)

s.pin('iddig', 1)                                           # mini-B plug: device
s.idle_bus(200)
s.chk('DRS-IDB')
s.r('sts', role=0, id_a_plug=0)
# ---- device session
d, _ = dev_bringup(s, address=ADDR)
s.chk('DRS-DEV')
s.xp(0, 0x00, 0xC0)                                          # device: pull-downs off
pin = s.rnd(64)
arm_in(s, 1, pin, 64, 0x4000, pkts=1, set_d0=1)
s.token(IN, ADDR, 1)
s.xd(DATA0, pin, tmo=400)
s.wait(8); s.hs(ACK)
s.wait(40)
s.bin('cg_role.device'); s.bin('cg_role.dev'); s.bin('cg_ulpi_id.b')
# ID changes during the session: the role is held
s.pin('iddig', 0)
s.idle_bus(3000)
s.chk('DRS-HOLDDEV')
s.r('sts', role=0, id_a_plug=1)
s.r('irq_raw', role_chg=0)
s.bin('cg_role.hold_dev'); s.bin('cg_role.held'); s.bin('cg_ulpi_id.a')
# session end: soft-disconnect detaches the device; then the role follows the ID pin
s.w('dctrl', dev_addr=0, soft_conn=0)
s.chk('DRS-TOHOST')
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=1, id_a_plug=1)
s.w1c('irq_raw', role_chg=1)
s.bin('cg_role.to_host')
# ---- host session
s.emit('FLUSH')
host_bringup(s)
s.chk('DRS-HOST')
s.xp(0, *HOST_PD)                                            # host: both pull-downs on
p = DevPartner(s, 0)
po = s.rnd(24)
s.mw(0x20000, po)
hc_program(s, 0, 0, 1, 0, BULK, 64, 24, 1, 0x20000, pid=0)
p.out(1, DATA0, po, answer=ACK)
s.poll('hc_int', 0, tries=900, done=1)
s.w1c('hc_int', 0, **ALL)
s.bin('cg_role.host')
# ID changes back to the B-plug during the session: held
s.pin('iddig', 1)
s.idle_bus(3000)
s.chk('DRS-HOLDHOST')
s.r('sts', role=1, id_a_plug=0)
s.r('irq_raw', role_chg=0)
s.bin('cg_role.hold_host')
# session end: power off the port
s.w('hport', oc_en=1, vbus_drv=0, sof_en=0)
s.chk('DRS-TODEV')
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=0, id_a_plug=0)
s.w1c('irq_raw', role_chg=1)
s.xp(0, 0x00, 0xC0)
s.bin('cg_role.to_device')
# ---- CSR override while detached: host although the ID says B, then device although the ID says A
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1, role_ovr_en=1, role_ovr=1)
s.chk('DRS-OVR')
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=1)
s.w1c('irq_raw', role_chg=1)
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1, role_ovr_en=1, role_ovr=0)
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=0)
s.w1c('irq_raw', role_chg=1)
s.pin('iddig', 0)
s.idle_bus(500)
s.r('sts', role=0, id_a_plug=1)                              # the override still wins over the A-plug
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1, role_ovr_en=0)
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=1)                                           # override off: the ID pin decides again
s.bin('cg_role.override')
print(s.save('ops/dual_role_switch_s%d.ops' % seed))
