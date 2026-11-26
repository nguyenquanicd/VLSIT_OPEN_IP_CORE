"""t_dev_suspend_lpm_reset: device suspend, resume, remote wakeup, reset in suspend, LPM L1 and software reset.
Times follow REQ-FUNC-018/019/021 scaled by TSCALE (REQ-VER-002). Also used by t_dir_timing_ts1 (ts1), t_dev_pipe_equiv and
t_dev_ulpi_traffic (ulpi).

Test ID and title: t_dev_suspend_lpm_reset - device suspend timing, host resume, remote wakeup, reset during suspend, LPM L1, soft reset
Priority and rationale: P1, rank 9 of the R-283 list. Low-power entry and exit cross clock domains and stop the PHY clock in a product.
Purpose: show that a high-speed device reverts to full speed between 3.0 and 3.125 ms of idle and suspends on J, resumes on host K,
  drives remote-wakeup K only after 5 ms of idle for 1 to 15 ms, returns to the Default state on a reset during suspend, handles LPM
  (ACK/NYET/STALL by lpm_cfg.resp, bLinkState check, foreign address, run-time disable) and that ctrl.swrst stops the engines.
Requirements and features: REQ-FUNC-013, 018, 019, 021; REQ-RESET-001, 002; REQ-IF-012; REQ-CLK-003; REQ-REG-003. USB 2.0 7.1.7.6,
  7.1.7.7, LPM ECN. Features suspend_resume, lpm, hs_chirp, cdc, reset, utmi_if.
DUT configuration and preconditions: build dev_utmi8_axim (TSCALE 256); lpm_cfg resp 0, lpm_en_rt 1 before ctrl; device bring-up at a
  random address; bulk OUT endpoint 1 used as the "device answers again" probe.
Software flow:
  1. Bring-up with lpm_cfg; one bulk OUT transfer (traffic probe: arm, receive, compare memory) after every event below.
  2. Suspend: poll irq_raw.suspend, read sts.suspended and dsts.susp_det, clear. Resume: poll irq_raw.resume, read sts, clear.
  3. Remote wakeup: dctrl.rmt_wake_en, then rmt_wake during suspend; poll dctrl.rmt_wake = 0.
  4. LPM: poll irq_raw.lpm_evt and sts.suspended, read dsts (l1_state, lpm_hird, lpm_rwake); poll l1_state = 0 after the resume;
     change lpm_cfg.resp to NYET (1), STALL (2), then lpm_en_rt 0.
  5. ctrl core_en 0, then swrst; poll swrst = 0.
Stimulus: host stops SOF (idle), J on the line, host K for 20 ms, an idle shorter than 3 ms, SE0 reset with chirp during suspend, EXT
  plus LPM tokens with different attributes and addresses, an OUT after the soft reset.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DSL-TRAFFIC | REQ-CLK-003, REQ-FUNC-004 | bulk OUT probe after each event | ACK and the 64 bytes in memory | TB XH, GAP, MC | 400 CLK-PHY | the device does not answer after the event
  DSL-SUSP | REQ-FUNC-018 | last host packet, then idle | full-speed row between 3.0 and 3.125 ms (scaled), within 10 ms the suspend row 01 / 1 / 00 with SuspendM low (the D+ pull-up stays; DEC-048 PHY-04), irq_raw.suspend, sts.suspended, dsts.susp_det | TB WP, GAP, P, R | 3.125 ms and 10 ms scaled | early or late reversion, no suspend or flags missing
  DSL-RESUME | REQ-FUNC-018, REQ-IF-012 | host K for 20 ms, then SE0 | high-speed row with suspend_n high within 500 us; irq_raw.resume; sts.suspended 0 | TB WP, P, R | 500 us scaled | no return to high speed or flags wrong
  DSL-NOSUSP | REQ-FUNC-018 | idle of 2.8 ms, then a SOF | still the high-speed row and not suspended; irq_raw.suspend stays 0 | TB XP, R | at 2.8 ms | suspend before 3 ms of idle
  DSL-RWAKE | REQ-FUNC-019 | dctrl.rmt_wake during suspend | TXValid only after 300 us to 3 ms more (5 ms of idle in total), resume row, K for 1 to 15 ms, rmt_wake cleared by hardware | TB WP, GAP, XP, XC, P | 16 ms scaled | K too early, too short/long or the request not cleared
  DSL-RSTSUSP | REQ-RESET-002, REQ-FUNC-013 | SE0 during suspend | device chirp row and chirp of 1 to 7 ms, high speed after the host chirp, busrst and enum, sts speed 0 and suspended 0 | TB WP, XP, XC, P, R | 8 ms scaled | the device stays suspended or skips the handshake
  DSL-L1 | REQ-FUNC-021 | LPM token (L1, HIRD 5, remote wake 1), lpm_cfg.resp ACK | ACK; suspend row 01 / 1 / 00 with SuspendM low within 600 CLK-PHY; lpm_evt; sts.suspended; dsts l1_state 1, lpm_hird 5, lpm_rwake 1 | TB XH, GAP, WP, P, R | 600 CLK-PHY | no ACK, no L1 or wrong attributes
  DSL-L1EXIT | REQ-FUNC-021 | host K for the HIRD time, then SE0 | dsts.l1_state returns to 0 | TB P | 400 polls | L1 not left
  DSL-LPMNYET | REQ-FUNC-021 | lpm_cfg.resp NYET | NYET to the LPM token; l1_state stays 0 | TB XH, R | 400 CLK-PHY | other handshake or L1 entered
  DSL-LPMSTALL | REQ-FUNC-021, LPM ECN | lpm_cfg.resp STALL; then resp ACK with bLinkState 3 | STALL in both cases; l1_state 0 | TB XH, R | 400 CLK-PHY | ACK to an unsupported link state
  DSL-LPMIGN | REQ-FUNC-001, 021 | LPM to another address; LPM with lpm_en_rt 0 | no answer to either | TB XN | 150 CLK-PHY each | an answer
  DSL-SWRST | REQ-RESET-001 | ctrl.swrst with core_en 0 | swrst self-clears; an OUT afterwards gets no answer | TB P, XN | 400 polls, 150 CLK-PHY | swrst stuck or the core still answers
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: every low-power transition and the soft reset behave as listed; the probe transfer succeeds after each one.
Defect/fault targeted: pull-up removed in suspend after high speed (M31, DEC-048 PHY-04); wrong idle timers (early/late suspend), resume not detected, remote wakeup too early or too long, reset ignored
  in suspend, LPM answers ignoring lpm_cfg or bLinkState, soft reset not stopping the core.
Checker/oracle: timing windows from USB 2.0 and REQ-FUNC-018/019/021 (scaled), CSR description; harness WP/XP/XC/GAP/XH/XN/P/R/MC;
  negative-control audit.
Reproducibility: cd tests/usb20; python gen_dev_suspend_lpm_reset.py SEED (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_suspend_lpm_reset dev_utmi8_axim tests/ops/dev_suspend_lpm_reset_sSEED.ops +seed=SEED
Waveform: rank 9 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_dev_suspend_lpm_reset
Evidence: runs of t_dev_suspend_lpm_reset in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_suspend_lpm_reset', seed=seed)
s.emit('WD', 60000)
ADDR = s.rng.randrange(1, 128)
MPS = 64
SUSP_N = 1 << 5                                           # suspend_n bit of pin group 0


def lpm_en(sx):
    sx.w('lpm_cfg', resp=0, lpm_en_rt=1)


d, _ = dev_bringup(s, address=ADDR, extra=lpm_en)


def traffic(tag):
    """A bulk OUT packet proves that the device answers again; CSR writes cross while it runs (REQ-CLK-003)."""
    s.w1c('epo_int', 1, done=1)
    arm_out(s, 1, MPS, 1, MPS, 0x2000 + 0x100 * tag, set_d0=1)
    d.tog_out[1] = 0
    p = s.rnd(MPS)
    s.chk('DSL-TRAFFIC')
    d.out(1, p)
    s.idle_bus(2000)
    s.mc(0x2000 + 0x100 * tag, p)


def go_suspend():
    """Host stops sending: 3 ms of idle, full-speed reversion, J on the line, suspend."""
    s.emit('SG', 0, 300)
    s.token(SOF, 0x12, 0x3)                                # last packet of the host: the idle time starts here
    s.chk('DSL-SUSP')
    s.wp(0, mode(1, 1, 0), MODE_MASK, us(3125) + 40)       # full-speed termination no later than 3.125 ms
    s.gap(us(3000) - 12, us(3125) + 12)                    # and not before 3.0 ms (cycles waited, with harness margin)
    s.linestate(1)                                         # pull-up on D+: the line shows J
    s.wp(0, mode(1, 1, 0), MODE_MASK | SUSP_N, us(10000 - 3000))   # suspended within 10 ms: full-speed row, pull-up kept (DEC-048 PHY-04)
    s.poll('irq_raw', suspend=1)
    s.r('sts', suspended=1)
    s.r('dsts', susp_det=1)
    s.w1c('irq_raw', suspend=1)


def host_resume(hs=True):
    """Host drives K for 20 ms, then the bus returns to high-speed idle."""
    s.linestate(2)
    s.idle(us(20000))
    s.linestate(0)
    s.chk('DSL-RESUME')
    s.wp(0, mode(0, 0, 0) | SUSP_N, MODE_MASK | SUSP_N, us(500))
    s.emit('SG', 1, 300)
    s.poll('irq_raw', resume=1)
    s.r('sts', suspended=0)
    s.w1c('irq_raw', resume=1)


traffic(0)
# ---- 1. suspend and host resume
go_suspend()
s.bin('cg_susp.enter'); s.bin('cg_susp.hs_revert'); s.bin('cg_mode.each_state')
host_resume()
if 'ulpi' in sys.argv:
    s.bin('cg_ulpilp.exit')                                    # the host_resume sequence ends with SuspendM high again (a_ulpi_lp checks the PHY clock restart and the link wake)
traffic(1)
s.bin('cg_xreg.burst'); s.bin('cg_xreg.both_dir')
# ---- 2. idle shorter than 3 ms does not suspend
s.emit('SG', 0, 300)
s.token(SOF, 0x13, 0x3)                                    # last packet of the host
s.wait(us(2800))
s.chk('DSL-NOSUSP')
s.xp(0, mode(0, 0, 0) | SUSP_N, MODE_MASK | SUSP_N)        # still high-speed, not suspended
s.token(SOF, 0x14, 0x3)                                    # the host sends again before 3 ms
s.emit('SG', 1, 300)
s.idle(us(400))
s.r('irq_raw', suspend=0)
traffic(2)
s.bin('cg_susp.no_enter')
# ---- 3. remote wakeup (REQ-FUNC-019): requested early, the device drives K only after 5 ms of idle, for 1 to 15 ms
s.w('dctrl', dev_addr=ADDR, soft_conn=1, rmt_wake_en=1)
s.idle_bus(300)
go_suspend()
s.w('dctrl', dev_addr=ADDR, soft_conn=1, rmt_wake_en=1, rmt_wake=1)
s.chk('DSL-RWAKE')
s.wp(3, 1, 1, us(3000))                                    # TXValid: resume K starts
s.gap(us(300), us(3000))                                   # not right away: the bus must have been idle for 5 ms
s.xp(0, mode(1, 1, 2), MODE_MASK)                          # device resume signaling row of the table
s.linestate(2)
s.xc(us(1000), us(15000), 0x00, us(16000))                 # K for 1 to 15 ms
s.poll('dctrl', rmt_wake=0)                                # hardware clears the request
s.bin('cg_wake.early_req'); s.bin('cg_wake.drive')
host_resume()                                              # the host keeps K for 20 ms and ends the resume
traffic(3)
# ---- 4. bus reset during suspend returns the device to the Default state (REQ-RESET-002)
go_suspend()
s.linestate(0)                                             # SE0: reset
s.chk('DSL-RSTSUSP')
s.wp(3, 1, 1, us(400))
s.xp(0, mode(0, 1, 2), MODE_MASK)
s.linestate(2)
s.xc(us(1000), us(7000), 0x00, us(8000))
s.linestate(0)
for _ in range(3):
    s.linestate(2); s.idle(us(50))
    s.linestate(1); s.idle(us(50))
s.linestate(0)
s.wp(0, mode(0, 0, 0), MODE_MASK, us(500) + 8)
s.emit('SG', 1, 300)
s.poll('irq_raw', busrst=1, enum=1)
s.r('sts', speed=0, suspended=0)
s.wraw('irq_raw', 0, IRQ_ALL)
traffic(4)
s.bin('cg_susp.reset_wake'); s.bin('cg_chirp_d.hs')
# ---- 5. LPM L1 (REQ-FUNC-021): EXT token, LPM token with bLinkState = 1, HIRD and bRemoteWake; ACK; L1; resume
def lpm(hird, rwake, link=1):
    attr = link | (hird << 4) | (rwake << 8)
    s.token(EXT, ADDR, 0)
    s.token(0x3, attr & 0x7F, (attr >> 7) & 0xF)           # SubPID LPM (0011b) with the 11-bit bmAttributes


lpm(hird=5, rwake=1)
s.chk('DSL-L1')
s.xh(ACK)
s.gap(*dev_gap())
s.emit('SG', 0, 300)
s.wp(0, mode(1, 1, 0), MODE_MASK | SUSP_N, 600)           # L1 within 10 us (600 cycles): full-speed row, pull-up kept (DEC-048)
s.linestate(1)                                            # full-speed termination in L1: the line shows J
s.poll('irq_raw', lpm_evt=1)
s.poll('sts', suspended=1)                                # the status word crosses to CLK-BUS
s.r('dsts', l1_state=1, lpm_hird=5, lpm_rwake=1)
s.bin('cg_lpm.ack')
s.linestate(2)                                             # host resume from L1: K for the HIRD time (50 + 5 * 75 us)
s.idle(us(425) + 4)
s.linestate(0)
s.emit('SG', 1, 300)
s.chk('DSL-L1EXIT')
s.poll('dsts', l1_state=0)
s.wraw('irq_raw', 0, IRQ_ALL)
traffic(5)
s.bin('cg_lpm.l1_exit')
s.w('lpm_cfg', resp=1, lpm_en_rt=1); s.idle_bus(300)      # NYET: not ready for L1
s.chk('DSL-LPMNYET')
lpm(hird=2, rwake=0); s.xh(NYET)
s.idle_bus(300)
s.r('dsts', l1_state=0)
s.bin('cg_lpm.nyet')
s.w('lpm_cfg', resp=2, lpm_en_rt=1); s.idle_bus(300)      # STALL
s.chk('DSL-LPMSTALL')
lpm(hird=2, rwake=0); s.xh(STALL)
s.bin('cg_lpm.stall')
s.w('lpm_cfg', resp=0, lpm_en_rt=1); s.idle_bus(300)
lpm(hird=2, rwake=0, link=3); s.xh(STALL)                  # bLinkState other than L1: STALL (LPM ECN, Table 2-3 text)
s.idle_bus(300)
s.r('dsts', l1_state=0)
s.chk('DSL-LPMIGN')
s.token(EXT, ADDR ^ 0x21, 0); s.token(0x3, 0x51, 0); s.xn(150)   # LPM for another device: no answer
s.w('lpm_cfg', resp=0, lpm_en_rt=0); s.idle_bus(300)      # LPM disabled at run time: ignored
lpm(hird=2, rwake=0); s.xn(150)
traffic(6)
# ---- 6. software reset in the middle of register traffic returns the engines to idle (REQ-RESET-001)
s.w('ctrl', core_en=0, dma_en=1, ahb_err_stop=1)
s.w('ctrl', core_en=0, dma_en=1, ahb_err_stop=1, swrst=1)
s.chk('DSL-SWRST')
s.poll('ctrl', swrst=0)
s.token(OUT, ADDR, 1); s.data(DATA0, s.rnd(8)); s.xn(150)  # core disabled: no answer
s.bin('cg_rst.soft')
print(s.save('ops/dev_suspend_lpm_reset%s_s%d.ops' % ('_ts1' if 'ts1' in sys.argv else '', seed)))
