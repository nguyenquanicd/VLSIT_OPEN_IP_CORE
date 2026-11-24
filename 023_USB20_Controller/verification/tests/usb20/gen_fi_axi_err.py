"""t_fi_axi_err: AXI error responses on DMA accesses and DMA addresses outside the window (fault injection).

Test ID and title: t_fi_axi_err - SLVERR on a write burst, DECERR on a read burst, DMA stop and restart, DMA window protection
Priority and rationale: P2. Bus errors must stop the DMA and be visible; the window keeps the DMA out of foreign memory.
Purpose: show that BRESP and RRESP errors set axi_err and dma_err, that with ahb_err_stop the DMA starts nothing new until software
  restarts it, that the endpoint works after recovery, and that buffers below, above or across the window are never accessed.
Requirements and features: REQ-IF-006, 014; REQ-ERR-001; ERR-007, ERR-017. AMBA AXI4 B/R responses. Features axi_master_dma, interrupt.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up at a random address; harness error injection (AXE) and
  window assertion (WIN, a_axim_win).
Software flow:
  1. Arm OUT 1; after the error read irq_raw (axi_err, dma_err); arm IN 2 (gets nothing); clear flags; restart the DMA (dma_en 0 then 1).
  2. Arm OUT 1 again and compare; arm IN 2 with a DECERR injected; read the flags; clear; restart.
  3. dma_wbase 0x6000, dma_wlim 0x6FFF, hsts.win_en; OUT to buffers at 0x5000, 0x7000, 0x6FE0 (dma_err, memory untouched) and 0x6800.
  4. IN buffer at 0x7000 (dma_err, NAK) and at 0x6400 (works).
Stimulus: SLVERR on the next write burst, DECERR on the next read burst, buffers outside the window.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FAE-BRESP | REQ-IF-006, ERR-007 | SLVERR on the burst storing an OUT packet | the OUT is acknowledged; irq_raw axi_err and dma_err set | TB XH, R | 2000 bus cycles | no error flag
  FAE-STOP | ERR-007 (ahb_err_stop) | IN armed after the error | NAK (the stopped DMA fetches nothing); flags clear to 0 | TB XH, R | 400 CLK-PHY | the DMA keeps running after an error
  FAE-RECOVER | REQ-IF-006 | software restarts the DMA | the pending IN job sends its data; done; a new OUT stored at 0x2100; done | TB XD, R, XH, MC | 3000 bus cycles | the endpoint stays dead after recovery
  FAE-RRESP | REQ-IF-006, ERR-007 | DECERR on the read burst fetching an IN packet | irq_raw axi_err and dma_err set | TB R | 3000 bus cycles | no error flag
  FAE-WIN | REQ-IF-014, ERR-017 | OUT buffers below, above and across the window | no AXI access outside the window (assertion a_axim_win), dma_err, the 128 bytes there untouched | TB WIN assertion, R, MC | 2000 bus cycles each | any access outside the window
  FAE-WININ | REQ-IF-014 | OUT buffer inside the window | data stored at 0x6800, no dma_err | TB XH, MC, R | 2000 bus cycles | a good buffer refused
  FAE-WINRD | REQ-IF-014, ERR-017 | IN buffer at 0x7000, then at 0x6400 | dma_err and NAK for the outside one; the inside one sends its data and sets done | TB R, XH, XD | 1500 bus cycles | a read outside the window or the inside buffer refused
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: every injected error is reported, the DMA stops and recovers by software, the window is never left.
Defect/fault targeted: AXI error responses ignored, DMA continuing after an error with ahb_err_stop, window compare off by one or
  ignoring the straddling case.
Checker/oracle: REQ-IF-006/014 and ERR-007/017 in this script; harness AXI slave model with error injection, assertion a_axim_win,
  XH/XD/R/MC; negative-control audit.
Reproducibility: cd tests/usb20; python gen_fi_axi_err.py SEED (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_axi_err dev_utmi8_axim tests/ops/fi_axi_err_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_axi_err in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_axi_err', seed=seed)
ADDR = s.rng.randrange(1, 128)
MPS = 64
d, _ = dev_bringup(s, address=ADDR)


def clear():
    s.wraw('irq_raw', 0, IRQ_ALL)
    s.idle_bus(40)


def restart_dma():
    s.w('ctrl', core_en=1, dma_en=0, ahb_err_stop=1)
    s.idle_bus(40)
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
    s.idle_bus(40)


# 1. write error (SLVERR) on the burst that stores an OUT packet
arm_out(s, 1, MPS, 1, MPS, 0x2000)
s.chk('FAE-BRESP')
s.emit('AXE', 0, 0, 2)                                     # next write burst answers SLVERR
d.out(1, s.rnd(MPS))
s.idle_bus(2000)
s.r('irq_raw', axi_err=1, dma_err=1)
s.bin('cg_aximerr.bresp'); s.bin('cg_err.axi'); s.bin('cg_err.dma')
# the DMA is stopped: an IN endpoint armed now gets no data, so the device answers NAK
pstop = s.rnd(MPS)
arm_in(s, 2, pstop, MPS, 0x4000)
s.chk('FAE-STOP')
d.in_(2, expect=NAK)
clear()
s.r('irq_raw', axi_err=0, dma_err=0)
s.chk('FAE-RECOVER')
restart_dma()                                              # recovery: software restarts the DMA
s.idle_bus(3000)
d.in_(2, pstop)                                            # the pending IN job runs now
s.idle_bus(1500)
s.r('epi_int', 2, done=1)
s.w1c('epi_int', 2, done=1)
p2 = s.rnd(MPS)
s.w1c('epo_int', 1, done=1)
arm_out(s, 1, MPS, 1, MPS, 0x2100, set_d0=1)
d.tog_out[1] = 0
d.out(1, p2)
s.idle_bus(2000)
s.mc(0x2100, p2)
s.r('epo_int', 1, done=1)
s.w1c('epo_int', 1, done=1)
# 2. read error (DECERR) on the burst that fetches an IN packet
pin = s.rnd(MPS)
s.chk('FAE-RRESP')
s.emit('AXE', 1, 0, 3)                                     # next read burst answers DECERR
arm_in(s, 2, pin, MPS, 0x4400)
s.r('irq_raw', axi_err=1, dma_err=1)
s.bin('cg_aximerr.rresp')
clear()
restart_dma()
# 3. DMA window (REQ-IF-014): buffers below, above and straddling the window are not accessed
s.w('dma_wbase', addr=0x6000)
s.w('dma_wlim', addr=0x6FFF)
s.w('hsts', win_en=1)
s.idle_bus(200)
s.emit('WIN', 0x6000, 0x6FFF)                              # harness assertion a_axim_win: no access outside
s.chk('FAE-WIN')
for base, binname in ((0x5000, 'cg_win.below'), (0x7000, 'cg_win.above'), (0x6FE0, 'cg_win.straddle')):
    s.mw(base & ~0x3F, [0xEE] * 128)
    s.w1c('epo_int', 1, done=1)
    arm_out(s, 1, MPS, 1, MPS, base, set_d0=1)
    d.tog_out[1] = 0
    d.out(1, s.rnd(MPS))
    s.idle_bus(2000)
    s.r('irq_raw', dma_err=1)
    s.mc(base & ~0x3F, [0xEE] * 128)                       # nothing was written
    clear()
    s.bin(binname)
s.chk('FAE-WININ')
pw = s.rnd(MPS)                                            # a buffer inside the window works
s.w1c('epo_int', 1, done=1)
arm_out(s, 1, MPS, 1, MPS, 0x6800, set_d0=1)
d.tog_out[1] = 0
d.out(1, pw)
s.idle_bus(2000)
s.mc(0x6800, pw)
s.r('irq_raw', dma_err=0)
# IN buffer outside the window: no read access, dma_err, the endpoint has no data
s.w1c('epi_int', 2, done=1)
s.chk('FAE-WINRD')
arm_in(s, 3, s.rnd(MPS), MPS, 0x7000)
s.r('irq_raw', dma_err=1)
d.in_(3, expect=NAK)
clear()
pwin = s.rnd(MPS)
arm_in(s, 4, pwin, MPS, 0x6400)                            # inside the window
d.in_(4, pwin)
s.idle_bus(1500)
s.r('epi_int', 4, done=1)
print(s.save('ops/fi_axi_err_s%d.ops' % seed))
