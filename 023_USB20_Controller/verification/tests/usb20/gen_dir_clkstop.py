"""t_dir_clkstop: wake-up with the PHY clock stopped in suspend (review F-005, FND-015; DEC-049, REQ-IF-015; HDS sections 6.3, 7.4).
The PHY model stops CLK-PHY 8 cycles after SuspendM falls and restarts it PCLKD ns (default 2 us) after SuspendM rises.
While CLK-PHY is stopped every wait counts CLK-BUS cycles (op IB), because CLK-PHY cycles do not pass.
    python gen_dir_clkstop.py SEED dev | devrst | host ts16 | hostrw ts16 | hostdisc ts16   (host modes also ts1)

Test ID and title: t_dir_clkstop - device and host raise SuspendM while CLK-PHY is stopped; resume, reset, remote wake and disconnect
Priority and rationale: P1 (product risk): a link that cannot wake without the PHY clock hangs in suspend (FND-015, fixed by DEC-049);
  kills M35 (wake detector off), M36 (no glitch filter), M37 (hand-off without waiting for the engine), M38 (no host remote-wake
  exit), M39 (device chirp back to 1.6 ms).
Purpose: show that the always-on UTMI+ wake detector m_usb2_utmilp raises SuspendM on a line change of 4 CLK-BUS cycles or a software
  wake request, ignores a shorter glitch, drops SuspendM again after a short spurious change, hands SuspendM back to the speed engine,
  and that the engine then resumes, resets (chirp end within 7.0 ms of the reset start with a 5.6 ms PHY clock start), takes a host
  remote wake or reports a host disconnect.
Requirements and features: REQ-IF-015, REQ-FUNC-013, REQ-FUNC-016, REQ-FUNC-018, REQ-FUNC-019, REQ-FUNC-020, REQ-FUNC-037; DEC-049;
  UTMI 1.05 p. 21 and p. 48 (SuspendM negated without CLK; CLK within 5.6 ms); USB 2.0 7.1.7.5 (TUCHEND 7.0 ms), 7.1.7.7.
DUT configuration and preconditions: builds dev_utmi8_axim (dev, devrst; TSCALE 256) and host_utmi8_axim_ts16 (host modes); PHY
  clock-stop model enabled with PCLKA 1 after the bring-up; devrst sets PCLKD to 5.6 ms scaled by TSCALE.
Software flow:
  1. (dev) Bring-up; the host stops; 3 ms idle, suspend, clock stops; a 2-cycle K glitch (no wake); a 12-cycle K that ends at once
     (wake, then SuspendM low again); host resume K (wake, resume, irq_raw.resume); arm OUT 1, poll done.
  2. (devrst) Bring-up; suspend, clock stops; PCLKD 5.6 ms scaled; SE0 (reset from suspend); chirp; host chirps; high speed.
  3. (host) Bring-up; hport.port_susp; poll port_susp_sts; hport.port_res while CLK-PHY is stopped; resume K; SOF.
  4. (hostrw) Bring-up; port_susp; after 6 ms the device drives K; the host wakes, resumes by itself, irq_raw.resume, SOF.
  5. (hostdisc) Bring-up; port_susp; SE0 on the line (device removed); the host wakes, irq_raw.disc, port_conn and port_en 0.
Stimulus: idle bus, J, K glitches, host K, SE0 (dev, devrst); register writes, device K, SE0 (host modes).
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DCS-DSUSP | REQ-FUNC-018 | 3 ms idle (dev, devrst) | full-speed row, then SuspendM low (the PHY stops CLK-PHY) | TB WP | 3.125 ms and 10 ms scaled | no suspend
  DCS-GLITCH | REQ-IF-015, DEC-049 | K for 2 CLK-BUS cycles (dev) | SuspendM stays low, no wake request | TB XP, XWAKE | 50 CLK-BUS cycles | a glitch wakes the PHY (M36)
  DCS-SPUR | REQ-IF-015, DEC-049 | K for 12 CLK-BUS cycles, then J (dev) | one wake, then SuspendM low again (spurious-wake release) | TB XWAKE, XP, SVA-017 | 50 CLK-BUS cycles | no wake or SuspendM stuck high
  DCS-DWAKE | REQ-IF-015, REQ-FUNC-019 | host resume K with CLK-PHY stopped (dev) | SuspendM high | TB WP | 20 ms scaled | the device cannot wake without the clock (M35)
  DCS-DRES | REQ-FUNC-018 | end of the resume (dev) | high-speed row with SuspendM high; irq_raw.resume; OUT ACK and done | TB WP, P, XH | 500 us scaled, 400 polls | no return to traffic
  DCS-RSTWAKE | REQ-IF-015 | SE0 with CLK-PHY stopped (devrst) | SuspendM high | TB WP | 20 ms scaled | no wake on a reset
  DCS-RSTCH | REQ-FUNC-013, DEC-049 Q3 | reset from suspend, PHY clock start 5.6 ms scaled (devrst) | chirp K of 1.0 to 7.0 ms that ends no later than 7.0 ms after the SE0 start (TUCHEND) | TB WP, XC, TC | 8 ms scaled | chirp too long or too late (M39)
  DCS-RSTHS | REQ-FUNC-013 | host chirp K-J-K-J-K-J (devrst) | high-speed row | TB WP | 500 us scaled | no high speed after a reset from suspend
  DCS-HSUSP | REQ-FUNC-020 | hport.port_susp (host modes) | hsts.port_susp_sts | TB P | 3000 polls | no suspend
  DCS-HWAKE | REQ-IF-015, REQ-FUNC-020 | hport.port_res with CLK-PHY stopped (host) | SuspendM high | TB WP | 20 ms scaled | the host cannot wake without the clock (M35)
  DCS-HRESK | REQ-FUNC-020 | after the wake (host, hostrw) | resume K of 19.5 to 60 ms (scaled) | TB XC | 70 ms scaled | no resume K
  DCS-HSOF | REQ-FUNC-037 | 3 ms after the resume (host, hostrw) | at least one SOF; at TSCALE 1 the first SOF keeps the phase | TB SOF, SOFQ | 3 ms scaled | no SOF or phase lost
  DCS-HRWAKE | REQ-IF-015, REQ-FUNC-020 | device K with CLK-PHY stopped (hostrw) | SuspendM high | TB WP | 1 ms scaled | the host misses the remote wake
  DCS-HRWRESM | REQ-FUNC-020, DEC-049 Q2 | device K for 3 us (hostrw) | host resume row (01b/1/10b) and TXValid within 1 ms | TB WP | 1 ms scaled | no hardware resume (M38)
  DCS-HRWIRQ | REQ-FUNC-020 | end of the host resume (hostrw) | irq_raw.resume, port_susp_sts 0, no disconnect | TB P, R | 3000 polls | wrong events
  DCS-HDWAKE | REQ-IF-015, REQ-FUNC-016 | SE0 with CLK-PHY stopped (hostdisc) | SuspendM high | TB WP | 1 ms scaled | no wake on a disconnect
  DCS-HDDISC | REQ-FUNC-016, DEC-049 Q2 | SE0 after the reversion window (hostdisc) | irq_raw.disc; hsts port_conn 0 and port_en 0 | TB P, R | 3000 polls | the disconnect is not reported
  SVA-017 a_susp_handoff (every UTMI+ run) | REQ-IF-015 | every fall of the wake request | engine request already 1 or line back at idle; no pin pulse shorter than one CLK-BUS period | TB assertion | always | glitch or early release (M37)
Shared checkpoints also reached (dev, devrst): DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Shared checkpoints also reached (host modes): HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: every wake succeeds without CLK-PHY, the glitch is ignored, the spurious wake ends in suspend again.
Defect/fault targeted: wake logic clocked by CLK-PHY only (FND-015); no glitch filter; early hand-off; lost host remote wake; chirp too
  long after a slow PHY clock start.
Checker/oracle: UTMI 1.05 and USB 2.0 timing in this script; PHY clock-stop model (PCLKA, PCLKD); WP/XP/XC/TC/SOF/SOFQ/P/R/XWAKE;
  assertion a_susp_handoff (SVA-017) and a_phy_row (SVA-016).
Reproducibility: cd tests/usb20; python gen_dir_clkstop.py 1 dev (devrst; host ts16; hostrw ts16; hostdisc ts16); from verification:
  python env/scripts/run.py sim t_dir_clkstop dev_utmi8_axim tests/ops/dir_clkstop_dev_s1.ops +seed=1 (host modes: host_utmi8_axim_ts16,
  dir_clkstop_hostrw_s1.ops and the other mode names)
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dir_clkstop in sim/index.csv (CHKPT and UTMILP lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *
import hostlib
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
MODE = next((m for m in ('devrst', 'dev', 'hostrw', 'hostdisc', 'host') if m in sys.argv[2:]), 'host')
s = Scn('dir_clkstop', seed=seed)
s.emit('WD', 400 if 'ts1' not in sys.argv else 1500)                # ms of simulated time: a link that cannot wake hangs on a stopped clock
SUSP_N = 1 << 5
T_BUS_NS = 10                                                        # CLK-BUS period of the harness (t_bus)


def bus_us(t):
    """Microseconds of bus time (scaled by TSCALE) as CLK-BUS cycles: the only time base while CLK-PHY is stopped."""
    return max(1, int(t * 1000 / usb2lib.TS / T_BUS_NS))


def dev_suspend(d):
    s.emit('PCLKA', 1)
    s.emit('SG', 0, 300)
    s.token(SOF, 0x12, 0x3)
    s.chk('DCS-DSUSP')
    s.wp(0, mode(1, 1, 0), MODE_MASK, us(3125) + 40)           # full-speed reversion after 3 ms of idle
    s.linestate(1)                                            # J on the line
    s.wp(0, 0, SUSP_N, us(10000))                             # suspended: SuspendM low, the PHY stops its clock
    s.idle_bus(bus_us(2000))


if MODE == 'dev':
    ADDR = s.rng.randrange(1, 128)
    d, _ = dev_bringup(s, address=ADDR)
    dev_suspend(d)
    s.chk('DCS-GLITCH')
    s.linestate(2)                                            # K for 2 CLK-BUS cycles: shorter than the 4-cycle filter
    s.idle_bus(2)
    s.linestate(1)
    s.idle_bus(50)
    s.xp(0, 0, SUSP_N)
    s.emit('XWAKE', 0, 0)
    s.chk('DCS-SPUR')
    s.linestate(2)                                            # K for 12 cycles, then J before the PHY clock is back
    s.idle_bus(12)
    s.linestate(1)
    s.idle_bus(50)
    s.emit('XWAKE', 1, 1)
    s.xp(0, 0, SUSP_N)
    s.idle_bus(400)                                           # the model restarts and stops CLK-PHY again; the engine stays suspended
    s.xp(0, 0, SUSP_N)
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
    s.emit('XWAKE', 2, 1)
elif MODE == 'devrst':
    ADDR = s.rng.randrange(1, 128)
    d, _ = dev_bringup(s, address=ADDR)
    s.emit('PCLKD', int(5600 * 1000 / usb2lib.TS))            # PHY clock start 5.6 ms after SuspendM (UTMI 1.05), scaled
    dev_suspend(d)
    s.emit('TM')                                              # T0: start of the reset
    s.linestate(0)                                            # SE0 while CLK-PHY is stopped
    s.chk('DCS-RSTWAKE')
    s.emit('WP', 0, SUSP_N, SUSP_N, us(20000))
    s.chk('DCS-RSTCH')
    s.wp(3, 1, 1, us(7000))                                   # chirp K starts once the clock runs
    s.xp(0, mode(0, 1, 2), MODE_MASK)
    s.linestate(2)
    s.xc(us(1000), us(7000), 0x00, us(8000))                  # chirp K of 1.0 to 7.0 ms
    s.emit('TC', 0, us(7000))                                 # TUCHEND: the chirp ended no later than 7.0 ms after T0
    s.linestate(0)
    for _ in range(3):
        s.linestate(2)
        s.idle(us(50))
        s.linestate(1)
        s.idle(us(50))
    s.linestate(0)
    s.chk('DCS-RSTHS')
    s.wp(0, mode(0, 0, 0) | SUSP_N, MODE_MASK | SUSP_N, us(500) + 8)
    s.emit('XWAKE', 1, 0)
else:
    hostlib.host_bringup(s)
    UF = 125000 / usb2lib.TS
    s.wait(max(3000, us(500)))
    s.emit('PCLKA', 1)
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_susp=1)
    s.chk('DCS-HSUSP')
    s.poll('hsts', tries=3000, port_susp_sts=1)
    s.emit('SOFT')                                            # time of the last SOF before the suspend
    s.idle_bus(bus_us(6000))                                  # CLK-PHY stopped: wait in CLK-BUS cycles
    if MODE == 'host':
        s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, port_res=1)   # software resume: the CSR clock runs, CLK-PHY is stopped
        s.chk('DCS-HWAKE')
        s.emit('WP', 0, SUSP_N, SUSP_N, us(20000))            # the host must raise SuspendM without CLK-PHY
        s.bin('cg_clkstop.host_wake')
    elif MODE == 'hostrw':
        s.linestate(2)                                        # remote wakeup: the device drives K
        s.chk('DCS-HRWAKE')
        s.emit('WP', 0, SUSP_N, SUSP_N, us(1000))
        s.chk('DCS-HRWRESM')
        s.wp(0, mode(1, 1, 2, pd=1) | SUSP_N, MODE_MASK | SUSP_N, us(1000))   # host resume row within 1 ms (TURSM)
        s.bin('cg_clkstop.host_rwake')
    else:
        s.linestate(0)                                        # device removed: SE0 under the host pull-downs
        s.chk('DCS-HDWAKE')
        s.emit('WP', 0, SUSP_N, SUSP_N, us(1000))
        s.chk('DCS-HDDISC')
        s.poll('irq_raw', tries=3000, disc=1)
        s.r('hsts', port_conn=0, port_en=0)
        s.r('irq_raw', resume=0)
        s.emit('XWAKE', 1, 0)
        s.bin('cg_clkstop.host_disc')
    if MODE in ('host', 'hostrw'):
        s.chk('DCS-HRESK')
        s.xc(us(19500), us(60000), 0x00, us(70000))           # resume K
        if MODE == 'hostrw':
            s.emit('LSR', 0, 1)                               # the device stopped its K; high-speed idle again (SE0 of the HS row)
            s.chk('DCS-HRWIRQ')
            s.poll('irq_raw', tries=3000, resume=1)
            s.r('hsts', port_susp_sts=0)
            s.r('irq_raw', disc=0)
        s.wait(us(3000))
        s.chk('DCS-HSOF')
        s.emit('SOF', 1, 0, 0xFFFFFFF)
        if usb2lib.TS == 1 and MODE == 'host':
            s.emit('SOFQ', int(UF), 63)                      # first SOF after the resume keeps the phase: k microframes +- 62.5 ns
            s.bin('cg_sofphase.clkstop')
        s.emit('XWAKE', 1, 0)
print(s.save('ops/dir_clkstop_%s_s%d.ops' % (MODE + ('_ts1' if 'ts1' in sys.argv else ''), seed)))
