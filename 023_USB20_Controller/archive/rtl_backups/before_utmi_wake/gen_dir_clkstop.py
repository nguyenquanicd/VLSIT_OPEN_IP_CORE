"""t_dir_clkstop: wake-up with the PHY clock stopped in suspend (review F-005; HDS section 7.4). Tier "open": FND-015 is undecided.
The PHY model stops CLK-PHY 8 cycles after SuspendM falls and restarts it 2 us after SuspendM rises.
    python gen_dir_clkstop.py SEED dev | host ts16|ts1

Test ID and title: t_dir_clkstop - device and host must raise SuspendM while CLK-PHY is stopped; resume and traffic afterwards
Priority and rationale: P1 (product risk): a link that cannot wake without the PHY clock hangs in suspend. Expected to fail until FND-015
  is decided (UTMI+ clock-stop wake path); kept in the "open" tier and not counted as passing.
Purpose: show that a suspended device raises SuspendM on host resume K and a suspended host raises SuspendM on port_res without
  CLK-PHY, after which resume, SOF (and at TSCALE 1 the SOF phase, REQ-FUNC-037) and traffic work.
Requirements and features: REQ-FUNC-019, 020, 037; HDS 7.4; UTMI+ SuspendM clock-stop. Features suspend_resume, cdc.
DUT configuration and preconditions: builds dev_utmi8_axim (dev) and host_utmi8_axim_ts16 (host); the PHY model clock stop is enabled
  with PCLKA 1 after the bring-up.
Software flow:
  1. (dev) Bring-up; host stops; after the suspend the host drives K; poll irq_raw.resume; arm OUT 1; poll done.
  2. (host) Bring-up; hport.port_susp; poll port_susp_sts; hport.port_res (CSR clock running, CLK-PHY stopped).
Stimulus: idle bus, J, host K (dev); register writes (host).
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DCS-DSUSP | REQ-FUNC-018 | 3 ms idle (dev) | full-speed row, then SuspendM low (the PHY stops CLK-PHY) | TB WP | 3.125 ms and 10 ms scaled | no suspend
  DCS-DWAKE | REQ-FUNC-019, HDS 7.4 | host resume K with CLK-PHY stopped (dev) | SuspendM high within 20 ms | TB WP | 20 ms scaled | the device cannot wake without the clock (FND-015)
  DCS-DRES | REQ-FUNC-018 | end of the resume (dev) | high-speed row with SuspendM high; irq_raw.resume; OUT ACK and done | TB WP, P, XH | 500 us scaled, 400 polls | no return to traffic
  DCS-HSUSP | REQ-FUNC-020 | hport.port_susp (host) | hsts.port_susp_sts | TB P | 3000 polls | no suspend
  DCS-HWAKE | REQ-FUNC-020, HDS 7.4 | hport.port_res with CLK-PHY stopped (host) | SuspendM high within 20 ms | TB WP | 20 ms scaled | the host cannot wake without the clock (FND-015)
  DCS-HRESK | REQ-FUNC-020 | after the wake (host) | resume K of 19.5 to 60 ms (scaled) | TB XC | 70 ms scaled | no resume K
  DCS-HSOF | REQ-FUNC-037 | 3 ms after the resume (host) | at least one SOF; at TSCALE 1 the first SOF keeps the phase (k microframes +- 62.5 ns) | TB SOF, SOFQ | 3 ms scaled | no SOF or phase lost
Shared checkpoints also reached (dev): DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Shared checkpoints also reached (host): HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: (per the specification) both wake-ups succeed; current RTL status: open, see FND-015 in docs/bugs.md.
Defect/fault targeted: wake logic clocked by CLK-PHY only (cannot leave suspend when the PHY stops its clock).
Checker/oracle: HDS 7.4 and UTMI+ in this script; PHY clock-stop model in the harness (PCLKA); WP/XC/SOF/SOFQ/P/XH.
Reproducibility: cd tests/usb20; python gen_dir_clkstop.py 1 dev (or 1 host ts16); from verification:
  python env/scripts/run.py sim t_dir_clkstop dev_utmi8_axim tests/ops/dir_clkstop_dev_s1.ops +seed=1 (host: host_utmi8_axim_ts16,
  dir_clkstop_host_s1.ops)
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dir_clkstop in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
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
    s.chk('DCS-DSUSP')
    s.wp(0, mode(1, 1, 0), MODE_MASK, us(3125) + 40)           # full-speed reversion after 3 ms of idle
    s.linestate(1)                                            # J on the line
    s.wp(0, 0, SUSP_N, us(10000))                             # suspended: SuspendM low, the PHY stops its clock
    s.wait(us(2000))
    s.linestate(2)                                            # host resume K (LineState is valid while the clock is stopped)
    s.chk('DCS-DWAKE')
    s.emit('WP', 0, SUSP_N, SUSP_N, us(20000))                # the device must raise SuspendM without CLK-PHY
    s.bin('cg_clkstop.dev_wake')
    s.idle(us(20000))
    s.linestate(0)
    s.chk('DCS-DRES')
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
    s.chk('DCS-HSUSP')
    s.poll('hsts', tries=3000, port_susp_sts=1)
    s.emit('SOFT')                                            # time of the last SOF before the suspend
    s.wait(us(4000))
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_res=1)   # software resume: the CSR clock runs, CLK-PHY is stopped
    s.chk('DCS-HWAKE')
    s.emit('WP', 0, SUSP_N, SUSP_N, us(20000))                # the host must raise SuspendM without CLK-PHY
    s.bin('cg_clkstop.host_wake')
    s.chk('DCS-HRESK')
    s.xc(us(19500), us(60000), 0x00, us(70000))               # resume K
    s.wait(us(3000))
    s.chk('DCS-HSOF')
    s.emit('SOF', 1, 0, 0xFFFFFFF)
    if usb2lib.TS == 1:
        s.emit('SOFQ', int(UF), 63)                          # first SOF after the resume keeps the phase: k microframes +- 62.5 ns
        s.bin('cg_sofphase.clkstop')
print(s.save('ops/dir_clkstop_%s_s%d.ops' % ('dev' if 'dev' in sys.argv else 'host' + ('_ts1' if 'ts1' in sys.argv else ''), seed)))
