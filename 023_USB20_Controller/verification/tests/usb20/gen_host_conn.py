"""t_host_conn (cfg_host_utmi8_axim, directed): connect and disconnect (REQ-FUNC-016, FM-017). Argument disc: a high-speed device is
disconnected (HostDisconnect from the PHY): the port reports the disconnect (u2_irq_raw.disc), port_conn and port_en fall and the port
returns to the full-speed idle mode. Argument ls: a low-speed device attaches (D- pulled up: K state in full-speed terms); after the
reset u2_hsts.port_speed = 2 (low-speed) and the mode pins are the low-speed host row of section 6.3."""
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
    s.poll('irq_raw', tries=3000, disc=1)
    s.bin('cg_conn.hs_disc')
    s.pin('hostdisc', 0)
    s.poll('hsts', tries=3000, port_conn=0)
    s.r('hsts', port_en=0)
else:
    s.r('version', major=1)
    s.w('fifo_rx', start=0, size=0x100); s.w('fifo_hnp', start=0x100, size=0x100); s.w('fifo_hpt', start=0x200, size=0x100)
    s.wraw('irq_en', 0, IRQ_ALL)
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
    s.w('hport', oc_en=1, vbus_drv=1)
    s.linestate(2)                                             # low-speed device: D- high, which is the K state
    s.wait(us(105000))
    s.poll('hsts', port_conn=1, tries=2000)
    s.poll('irq_raw', conn=1)
    s.w1c('irq_raw', conn=1)
    s.w('hport', oc_en=1, vbus_drv=1, prst=1)
    s.wait(us(51000))
    s.poll('irq_raw', enum=1, tries=3000)
    s.r('hsts', port_en=1, port_speed=2)
    s.xp(0, mode(2, 1, 0, pd=1), MODE_MASK)                    # low-speed direct row: XcvrSelect 10b, TermSelect 1, OpMode 00b, pull-downs on
    s.bin('cg_conn.ls')
print(s.save('ops/host_conn_%s_s%d.ops' % (mode_arg, seed)))
