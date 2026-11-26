"""t_fi_ocp: over-current input of the host port (fault injection). Also used by t_host_ulpi_ocp (argument ulpi).
Pins of group 2 are {DrvVbus, o_vbus_pwr_en}.

Test ID and title: t_fi_ocp (its ULPI part with FOC-EXTVBUS also runs in t_host_ulpi_ocp) - over-current filter (15 cycles ignored, 16 trip), power off within 2 cycles, re-arm rules, oc_en 0, software off
Priority and rationale: P1. Port power protection is a safety function; kills M07 (BUG-024, DrvVbus not following the power-off).
Purpose: show that with oc_en the input low for 16 consecutive CLK-BUS cycles turns o_vbus_pwr_en and DrvVbus off within 2 cycles and sets
  ocur and oc_act; shorter pulses change nothing; the port stays off until software clears ocur and writes vbus_drv again; a persistent
  over-current keeps power off even after a re-arm; with oc_en 0 the input is ignored; DrvVbus follows a software power-off.
Requirements and features: REQ-FUNC-034, 041; REQ-IF-010; ERR-013; BUG-003. Features port_power.
DUT configuration and preconditions: build host_utmi8_axim_ts16 (or host_ulpi_axim_ts16 with argument ulpi: DrvVbus of the PHY register
  0Ah); no device; registers only.
Software flow:
  1. Read u2_version; FIFO regions, irq_en, ctrl; hport oc_en, vbus_drv.
  2. After each trip: poll irq_raw.ocur; clear ocur; hport vbus_drv 0 then 1.
  3. hport oc_en 0, vbus_drv 1; later vbus_drv 0.
Stimulus: ovrcur_n pulses of 10, 15, 16 cycles and a long one; a persistent low during a re-arm; a 60-cycle pulse with oc_en 0.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FOC-OFF | REQ-FUNC-041 | after reset | power pins {DrvVbus, pwr_en} 00 | TB XP | immediately | power on at reset
  FOC-ON | REQ-FUNC-041 | hport vbus_drv with oc_en | both pins 1 | TB WP | 400 CLK-PHY | power not on
  FOC-GLITCH | REQ-FUNC-034 | pulses of 10 and 15 cycles | power stays on; ocur 0; oc_act 0 | TB XP, R | 40 bus cycles after the pulse | a short pulse trips
  FOC-TRIP | REQ-FUNC-034, ERR-013 | input low 14 cycles, then 26 | still on at 14; both pins off within 40 cycles; oc_act 1 while low | TB XP, WP, R | 40 bus cycles | late or missing power-off
  FOC-HOLD | REQ-FUNC-034 | input high again | irq_raw.ocur set; power stays off | TB P, XP | 400 polls | power returns by itself
  FOC-REARM | REQ-FUNC-034 | ocur cleared | still off until vbus_drv is written 0 then 1; then on | TB XP, WP | 400 CLK-PHY | power returns without software
  FOC-EXACT16 | REQ-FUNC-034 | pulse of exactly 16 cycles | trip and ocur | TB WP, P | 100 bus cycles | filter off by one
  FOC-PERSIST | BUG-003 | re-arm while the input is still low | power stays off; on only after the input is high and a new re-arm | TB WP, XP | 100 bus cycles | power returns into a persistent short
  FOC-DISABLED | REQ-FUNC-034 | 60-cycle pulse with oc_en 0 | power stays on, ocur 0 | TB XP, R | 40 bus cycles | the input acts while disabled
  FOC-SWOFF | REQ-FUNC-041 | hport vbus_drv 0 | both pins off | TB WP | 400 CLK-PHY | DrvVbus does not follow (BUG-024 class)
  FOC-EXTVBUS | DEC-048 PHY-06, u2_hport.ext_vbus | ULPI builds only (argument ulpi, t_host_ulpi_ocp): vbus_drv with ext_vbus 0, then 1, then vbus_drv 0 | OTG Control read through u2_phy_acc: bits 6:5 = 01b, 11b, 00b | TB P, R | 2000 polls per read | DrvVbusExternal not written or not following DrvVbus
Shared checkpoints: none (no bring-up).
Expected outcome: the power state follows the filter and re-arm rules exactly.
Defect/fault targeted: DrvVbus not following the over-current power-off (M07, BUG-024); filter length off by one; automatic re-arm;
  power into a persistent short (BUG-003).
Checker/oracle: REQ-FUNC-034/041 timing in this script; harness XP/WP/P/R on the power pins; qualified by M07; formal t_fml_ocp_irq_rst.
Reproducibility: cd tests/usb20; python gen_fi_ocp.py SEED (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_ocp host_utmi8_axim_ts16 tests/ops/fi_ocp_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_ocp in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_ocp', seed=seed)
s.emit('WD', 60000)
s.r('version', major=1)
s.w('fifo_rx', start=0, size=0x100); s.w('fifo_hnp', start=0x100, size=0x100); s.w('fifo_hpt', start=0x200, size=0x100)
s.wraw('irq_en', 0, IRQ_ALL)
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
s.chk('FOC-OFF')
s.xp(2, 0, 3)                                            # power off at reset
s.w('hport', oc_en=1, vbus_drv=1)
s.chk('FOC-ON')
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
    s.chk('FOC-REARM')
    s.xp(2, 0, 3)                                        # still off: software has not written vbus_drv again
    s.w('hport', oc_en=1, vbus_drv=0)
    s.idle_bus(40)
    s.w('hport', oc_en=1, vbus_drv=1)
    s.wp(2, 3, 3, 400)


s.chk('FOC-GLITCH')
pulse(10, 'cg_ocp.short')                                # glitch: ignored
s.xp(2, 3, 3); s.r('irq_raw', ocur=0)
pulse(15, 'cg_ocp.short')                                # one cycle short of the filter
s.xp(2, 3, 3); s.r('irq_raw', ocur=0); s.r('hsts', oc_act=0)
s.pin('ovrcur_n', 0)
s.chk('FOC-TRIP')
s.idle_bus(14)
s.xp(2, 3, 3)
s.idle_bus(12)                                           # 16 cycles low plus the synchronizer: power drops within 2 cycles
s.wp(2, 0, 3, 40)
s.r('hsts', oc_act=1)                                       # the input state is shown while it is active (REQ-FUNC-034)
s.pin('ovrcur_n', 1)
s.idle_bus(40)
s.chk('FOC-HOLD')
s.poll('irq_raw', ocur=1)
s.xp(2, 0, 3)                                            # the flag is the last event; power stays off with the input high again
s.bin('cg_ocp.trip')
clear_and_rearm()
s.r('irq_raw', ocur=0)
s.bin('cg_ocp.rearm')
s.chk('FOC-EXACT16')
pulse(16, 'cg_ocp.trip')                                 # exactly 16 cycles trips (REQ-FUNC-034: 16 consecutive cycles)
s.wp(2, 0, 3, 100)
s.poll('irq_raw', ocur=1)
clear_and_rearm()
# persistent over-current: software re-arms while the input is still low: power must not return (BUG-003)
s.pin('ovrcur_n', 0)
s.chk('FOC-PERSIST')
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
s.chk('FOC-DISABLED')
pulse(60, 'cg_ocp.disabled')
s.xp(2, 3, 3); s.r('irq_raw', ocur=0)
# software power off: DrvVbus follows
s.chk('FOC-SWOFF')
s.w('hport', oc_en=0, vbus_drv=0)
s.wp(2, 0, 3, 400)
s.bin('cg_ocin.async_edge')
if 'ulpi' in sys.argv:
    # u2_hport.ext_vbus (DEC-048 PHY-06): OTG Control (0Ah) bit 6 DrvVbusExternal follows DrvVbus (bit 5) only when ext_vbus is 1
    def otg_read(bits):
        s.idle_bus(400)
        s.w('phy_acc', reg_addr=0x0A, rd_wr=0, start=1)
        s.poll('phy_acc', tries=2000, start=0, busy=0)
        s.emit('R', addr('phy_acc'), bits << 16, 0x60 << 16)
    s.chk('FOC-EXTVBUS')
    s.w('hport', oc_en=0, vbus_drv=1)
    otg_read(0x20)                                       # DrvVbus 1, DrvVbusExternal 0 (ext_vbus 0)
    s.w('hport', oc_en=0, vbus_drv=1, ext_vbus=1)
    otg_read(0x60)                                       # both 1: the PHY drives its CPEN pin
    s.w('hport', oc_en=0, vbus_drv=0, ext_vbus=1)
    otg_read(0x00)                                       # DrvVbusExternal follows DrvVbus off
print(s.save('ops/fi_ocp_s%d.ops' % seed))
