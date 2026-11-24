"""t_dual_role_switch (cfg_dual_utmi8_axim, PARA_USB2_ROLE = 2; combined: dual_role, port_reset, hs_chirp, connect_detect,
dev_token_addr). REQ-FUNC-023 and TEST-012: the role follows the ID indication of the PHY (mini-B = device, mini-A = host), changes
only after the session ended and the port is detached (the device soft-connect off, or the port power off), and a CSR override
(u2_ctrl.role_ovr_en and role_ovr) wins over the pin. Expected values: role field u2_sts.role (1 = host), the role_chg interrupt
flag, the PHY pull-downs (host: both 1, device: both 0) and traffic of the role that is active.
Sequence: device session over the B-plug, ID changes to the A-plug during the session (the role must stay), detach and change to host,
host session, ID back to the B-plug during the session (stays), power off and change to device, override in both directions."""
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
s.r('sts', role=0, id_a_plug=0)
# ---- device session
d, _ = dev_bringup(s, address=ADDR)
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
s.r('sts', role=0, id_a_plug=1)
s.r('irq_raw', role_chg=0)
s.bin('cg_role.hold_dev'); s.bin('cg_role.held'); s.bin('cg_ulpi_id.a')
# session end: soft-disconnect detaches the device; then the role follows the ID pin
s.w('dctrl', dev_addr=0, soft_conn=0)
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=1, id_a_plug=1)
s.w1c('irq_raw', role_chg=1)
s.bin('cg_role.to_host')
# ---- host session
s.emit('FLUSH')
host_bringup(s)
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
s.r('sts', role=1, id_a_plug=0)
s.r('irq_raw', role_chg=0)
s.bin('cg_role.hold_host')
# session end: power off the port
s.w('hport', oc_en=1, vbus_drv=0, sof_en=0)
s.poll('irq_raw', tries=4000, role_chg=1)
s.r('sts', role=0, id_a_plug=0)
s.w1c('irq_raw', role_chg=1)
s.xp(0, 0x00, 0xC0)
s.bin('cg_role.to_device')
# ---- CSR override while detached: host although the ID says B, then device although the ID says A
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1, role_ovr_en=1, role_ovr=1)
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
