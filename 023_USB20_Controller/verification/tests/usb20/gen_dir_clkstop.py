"""t_dir_clkstop (review 2026-11-22 F-005; REQ-FUNC-019, REQ-FUNC-020, REQ-FUNC-037, HDS section 7.4: "suspend and L1 stop the PHY
clock; the clock-stop and restart sequence uses UTMI+ SuspendM"). The PHY model stops CLK-PHY 8 cycles after SuspendM falls and
restarts it 2 us after SuspendM rises (UTMI+ allows the PHY to stop its clock in suspend; the link must raise SuspendM without
that clock). Device (argument dev): suspend, then the host drives resume K: the device must raise SuspendM, the clock comes
back and traffic works. Host (argument host): selective suspend, then software writes port_res: the host must raise SuspendM and
drive resume K, SOF must restart, and with argument ts1 the first SOF must keep the phase of the SOFs before the suspend
(REQ-FUNC-037; harness check SOFT/SOFQ).
    python gen_dir_clkstop.py <seed> dev
    python gen_dir_clkstop.py <seed> host ts16|ts1"""
import sys
from devlib import *
import hostlib
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dir_clkstop', seed=seed)
s.emit('WD', 400 if 'ts1' not in sys.argv else 1500)                # ms of simulated time: a link that cannot wake hangs on a stopped clock
SUSP_N = 1 << 5
if 'dev' in sys.argv:
    ADDR = s.rng.randrange(1, 128)
    d, _ = dev_bringup(s, address=ADDR)
    s.emit('PCLKA', 1)
    s.emit('SG', 0, 300)
    s.token(SOF, 0x12, 0x3)
    s.wp(0, mode(1, 1, 0), MODE_MASK, us(3125) + 40)           # full-speed reversion after 3 ms of idle
    s.linestate(1)                                            # J on the line
    s.wp(0, 0, SUSP_N, us(10000))                             # suspended: SuspendM low, the PHY stops its clock
    s.wait(us(2000))
    s.linestate(2)                                            # host resume K (LineState is valid while the clock is stopped)
    s.emit('WP', 0, SUSP_N, SUSP_N, us(20000))                # the device must raise SuspendM without CLK-PHY
    s.bin('cg_clkstop.dev_wake')
    s.idle(us(20000))
    s.linestate(0)
    s.wp(0, mode(0, 0, 0) | SUSP_N, MODE_MASK | SUSP_N, us(500))
    s.emit('SG', 1, 300)
    s.poll('irq_raw', resume=1)
    arm_out(s, 1, 64, 1, 64, 0x2000)
    p = s.rnd(64)
    d.out(1, p)
    s.poll('epo_int', 1, tries=400, done=1)
else:
    hostlib.host_bringup(s)
    UF = 125000 / usb2lib.TS
    s.wait(max(3000, us(500)))
    s.emit('PCLKA', 1)
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_susp=1)
    s.poll('hsts', tries=3000, port_susp_sts=1)
    s.emit('SOFT')                                            # time of the last SOF before the suspend
    s.wait(us(4000))
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_res=1)   # software resume: the CSR clock runs, CLK-PHY is stopped
    s.emit('WP', 0, SUSP_N, SUSP_N, us(20000))                # the host must raise SuspendM without CLK-PHY
    s.bin('cg_clkstop.host_wake')
    s.xc(us(19500), us(60000), 0x00, us(70000))               # resume K
    s.wait(us(3000))
    s.emit('SOF', 1, 0, 0xFFFFFFF)
    if usb2lib.TS == 1:
        s.emit('SOFQ', int(UF), 63)                          # first SOF after the resume keeps the phase: k microframes +- 62.5 ns
        s.bin('cg_sofphase.clkstop')
print(s.save('ops/dir_clkstop_%s_s%d.ops' % ('dev' if 'dev' in sys.argv else 'host' + ('_ts1' if 'ts1' in sys.argv else ''), seed)))
