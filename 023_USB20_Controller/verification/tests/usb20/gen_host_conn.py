"""t_host_conn: connect and disconnect on the host port (argument disc or ls).

Test ID and title: t_host_conn - high-speed disconnect (HostDisconnect) and low-speed attach with reset and the low-speed row
Priority and rationale: P2. Disconnect handling and low-speed detection; kills M14 (BUG-036, low speed taken for a chirp candidate).
Purpose: (disc) show that HostDisconnect sets irq_raw.disc and clears port_conn and port_en; (ls) show that a device pulling D- up is
  detected, reset, reported as low speed (port_speed 2) and that the mode pins show the low-speed host row.
Requirements and features: REQ-FUNC-012, 016; FM-017; section 6.3 low-speed row. Features connect_detect, port_reset.
DUT configuration and preconditions: build host_utmi8_axim_ts16; (disc) host bring-up at high speed; (ls) manual bring-up (no library).
Software flow:
  1. (disc) Bring-up; clear disc; after HostDisconnect poll irq_raw.disc, then hsts.port_conn 0 and read port_en 0.
  2. (ls) read u2_version; FIFO regions, irq_en, ctrl, hport power; poll port_conn and conn; clear; hport.prst; wait 51 ms; poll enum;
     read hsts (port_en, port_speed 2); check the mode pins.
Stimulus: pin hostdisc 1 then 0 (disc); K on the line at attach (ls).
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HCN-DISC | REQ-FUNC-012, FM-017 | HostDisconnect high (disc) | irq_raw.disc set | TB P | 3000 polls | no disconnect event
  HCN-DISCSTS | REQ-FUNC-012 | HostDisconnect low again (disc) | hsts.port_conn 0 and port_en 0 | TB P, R | 3000 polls | port still enabled
  HCN-VER | section 11.3 | start (ls) | u2_version major 1 | TB R | one access | other value
  HCN-LSCONN | REQ-FUNC-012 | K on the line for the debounce (ls) | hsts.port_conn and irq_raw.conn | TB P | 2000 polls | no connect
  HCN-LSRST | REQ-FUNC-011, DEC-048 | hport.prst with a low-speed device (ls) | reset row 00 / 0 / 00 gives SE0 with the D- pull-up; the reset ends in the low-speed row after 50 to 52 ms (scaled) and the line returns to low-speed idle | TB WP, TC, LSR | 60 ms scaled | no SE0, reset shorter than 50 ms or wrong end row
  HCN-LSENUM | REQ-FUNC-016 | after the reset (ls) | irq_raw.enum; hsts port_en 1 and port_speed 2 | TB P, R | 3000 polls | wrong speed (BUG-036 class)
  HCN-LSROW | section 6.3 | low-speed port enabled (ls) | mode pins XcvrSelect 10b, TermSelect 1, OpMode 00b, pull-downs on | TB XP | immediately | wrong row
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV (disc part only).
Expected outcome: (disc) disconnect reported and the port disabled; (ls) low-speed port enabled in the low-speed row.
Known gaps: (disc) the return to the full-speed idle row is not checked.
Defect/fault targeted: low-speed device taken for a high-speed candidate (M14, BUG-036); reset SE0 that a PHY cannot produce (M28); disconnect not clearing the port state.
Checker/oracle: REQ-FUNC-012/016 and section 6.3 in this script; harness P/R/XP; qualified by M14.
Reproducibility: cd tests/usb20; python gen_host_conn.py 1 disc ts16 (or 1 ls ts16); from verification:
  python env/scripts/run.py sim t_host_conn host_utmi8_axim_ts16 tests/ops/host_conn_disc_s1.ops +seed=1 (ls: host_conn_ls_s1.ops)
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv); build with --trace and run with +vcd.
Evidence: runs of t_host_conn in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
mode_arg = 'ls' if 'ls' in sys.argv else 'disc'
s = Scn('host_conn_' + mode_arg, seed=seed)
s.emit('WD', 60000)
if mode_arg == 'disc':
    host_bringup(s)
    s.wait(3000)
    s.w1c('irq_raw', disc=1)
    s.pin('hostdisc', 1)                                       # the PHY sees the far-end terminations disappear
    s.chk('HCN-DISC')
    s.poll('irq_raw', tries=3000, disc=1)
    s.bin('cg_conn.hs_disc')
    s.pin('hostdisc', 0)
    s.chk('HCN-DISCSTS')
    s.poll('hsts', tries=3000, port_conn=0)
    s.r('hsts', port_en=0)
else:
    s.chk('HCN-VER')
    s.r('version', major=1)
    s.w('fifo_rx', start=0, size=0x100); s.w('fifo_hnp', start=0x100, size=0x100); s.w('fifo_hpt', start=0x200, size=0x100)
    s.wraw('irq_en', 0, IRQ_ALL)
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
    s.w('hport', oc_en=1, vbus_drv=1)
    s.linestate(2)                                             # low-speed device: D- high, which is the K state
    s.wait(us(105000))
    s.chk('HCN-LSCONN')
    s.poll('hsts', port_conn=1, tries=2000)
    s.poll('irq_raw', conn=1)
    s.w1c('irq_raw', conn=1)
    s.w('hport', oc_en=1, vbus_drv=1, prst=1)
    s.chk('HCN-LSRST')
    s.wp(0, mode(0, 0, 0, pd=1), MODE_MASK, 4000)              # reset SE0 with the HS terminations (Table 40, DEC-048 PHY-01)
    s.emit('TM')
    s.emit('LSR', 0, 2)                                        # the row gives SE0 with the low-speed device (pull-up on D-)
    s.wp(0, mode(2, 1, 0, pd=1), MODE_MASK, us(60000))         # end of the reset: low-speed row
    s.emit('TC', us(50000) - 2, us(52000))                     # REQ-FUNC-011: at least 50 ms
    s.emit('LSR', 2, 2)                                        # low-speed idle (J of low speed) again
    s.chk('HCN-LSENUM')
    s.poll('irq_raw', enum=1, tries=3000)
    s.r('hsts', port_en=1, port_speed=2)
    s.chk('HCN-LSROW')
    s.xp(0, mode(2, 1, 0, pd=1), MODE_MASK)                    # low-speed direct row: XcvrSelect 10b, TermSelect 1, OpMode 00b, pull-downs on
    s.bin('cg_conn.ls')
print(s.save('ops/host_conn_%s_s%d.ops' % (mode_arg, seed)))
