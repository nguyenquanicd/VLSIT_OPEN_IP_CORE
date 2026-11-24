"""t_fi_ocp (cfg_host_utmi8_axim, fault injection): over-current input of the host port (REQ-FUNC-034, REQ-FUNC-041, REQ-IF-010,
ERR-013). Pins of group 2 are {DrvVbus, o_vbus_pwr_en}. Expected: with oc_en = 1 and the input low for 16 consecutive CLK-BUS
cycles, o_vbus_pwr_en falls within 2 cycles, ocur and oc_act are set, the port stays off until software clears ocur and writes
vbus_drv again; a shorter pulse changes nothing; with oc_en = 0 the input is ignored; DrvVbus follows the power state."""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_ocp', seed=seed)
s.emit('WD', 60000)
s.r('version', major=1)
s.w('fifo_rx', start=0, size=0x100); s.w('fifo_hnp', start=0x100, size=0x100); s.w('fifo_hpt', start=0x200, size=0x100)
s.wraw('irq_en', 0, IRQ_ALL)
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
s.xp(2, 0, 3)                                            # power off at reset
s.w('hport', oc_en=1, vbus_drv=1)
s.wp(2, 3, 3, 400)                                       # power on and DrvVbus high (REQ-FUNC-041, 4 CLK-PHY cycles after the command)
s.bin('cg_drvvbus.ulpi' if 'ulpi' in sys.argv else 'cg_drvvbus.utmi'); s.bin('cg_ocin.async_edge')   # argument ulpi: the pin group 2 shows the DrvVbus bit of the PHY register 0Ah


def pulse(n, name):
    s.pin('ovrcur_n', 0)
    s.idle_bus(n)
    s.pin('ovrcur_n', 1)
    s.idle_bus(40)
    s.bin(name)


def clear_and_rearm():
    s.w1c('irq_raw', ocur=1)
    s.idle_bus(40)
    s.xp(2, 0, 3)                                        # still off: software has not written vbus_drv again
    s.w('hport', oc_en=1, vbus_drv=0)
    s.idle_bus(40)
    s.w('hport', oc_en=1, vbus_drv=1)
    s.wp(2, 3, 3, 400)


pulse(10, 'cg_ocp.short')                                # glitch: ignored
s.xp(2, 3, 3); s.r('irq_raw', ocur=0)
pulse(15, 'cg_ocp.short')                                # one cycle short of the filter
s.xp(2, 3, 3); s.r('irq_raw', ocur=0); s.r('hsts', oc_act=0)
s.pin('ovrcur_n', 0)
s.idle_bus(14)
s.xp(2, 3, 3)
s.idle_bus(12)                                           # 16 cycles low plus the synchronizer: power drops within 2 cycles
s.wp(2, 0, 3, 40)
s.r('hsts', oc_act=1)                                       # the input state is shown while it is active (REQ-FUNC-034)
s.pin('ovrcur_n', 1)
s.idle_bus(40)
s.poll('irq_raw', ocur=1)
s.xp(2, 0, 3)                                            # the flag is the last event; power stays off with the input high again
s.bin('cg_ocp.trip')
clear_and_rearm()
s.r('irq_raw', ocur=0)
s.bin('cg_ocp.rearm')
pulse(16, 'cg_ocp.trip')                                 # exactly 16 cycles trips (REQ-FUNC-034: 16 consecutive cycles)
s.wp(2, 0, 3, 100)
s.poll('irq_raw', ocur=1)
clear_and_rearm()
# persistent over-current: software re-arms while the input is still low: power must not return (BUG-003)
s.pin('ovrcur_n', 0)
s.idle_bus(60)
s.wp(2, 0, 3, 100)
s.w1c('irq_raw', ocur=1)
s.w('hport', oc_en=1, vbus_drv=0)
s.idle_bus(40)
s.w('hport', oc_en=1, vbus_drv=1)
s.idle_bus(100)
s.xp(2, 0, 3)
s.pin('ovrcur_n', 1)
s.idle_bus(40)
s.w1c('irq_raw', ocur=1)
s.w('hport', oc_en=1, vbus_drv=0)
s.idle_bus(40)
s.w('hport', oc_en=1, vbus_drv=1)
s.wp(2, 3, 3, 400)
# oc_en = 0: the input is ignored
s.w('hport', oc_en=0, vbus_drv=1)
s.idle_bus(40)
pulse(60, 'cg_ocp.disabled')
s.xp(2, 3, 3); s.r('irq_raw', ocur=0)
# software power off: DrvVbus follows
s.w('hport', oc_en=0, vbus_drv=0)
s.wp(2, 0, 3, 400)
s.bin('cg_ocin.async_edge')
print(s.save('ops/fi_ocp_s%d.ops' % seed))
