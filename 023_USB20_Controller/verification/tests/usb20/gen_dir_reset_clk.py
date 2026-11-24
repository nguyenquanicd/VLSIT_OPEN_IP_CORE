"""t_dir_reset_midxfer (argument reset) and t_dir_clk_ratio (argument clk): hardware reset in the middle of traffic, and the
same traffic at five CLK-BUS frequencies.

Test ID and title: t_dir_reset_midxfer and t_dir_clk_ratio - reset during a received packet, a transmitted packet, a DMA burst and a
  register crossing; bulk traffic with CLK-BUS at 20, 33, 60, 100 and 200 MHz
Priority and rationale: P2. Reset in the middle of activity and arbitrary clock ratios are the usual integration failures of a CDC design.
Purpose: (reset) after a hardware reset at any point the registers hold their reset values, the bus is quiet, the interrupt is low and
  a new bring-up and transfer work; (clk) bulk OUT and IN through the DMA work for every CLK-BUS to CLK-PHY ratio.
Requirements and features: REQ-RESET-001; REQ-CLK-001, 002; REQ-FUNC-004; REQ-IF-006. Features reset, cdc, axi_master_dma.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up at a random address; harness reset (RST) and CLK-BUS period
  control (CLK, hundredths of a ns: 5000, 3003, 1667, 1000, 500).
Software flow:
  1. Bring-up; one bulk OUT (64 bytes) and bulk IN (71 bytes) transfer: arm, move, compare memory, read done.
  2. (reset) cause a reset at one of four points; read ctrl, dctrl, irq_en, epo_ctl reset values; bring-up again; transfer again.
  3. (clk) per period: set CLK, random AXI backpressure, two transfers at 0x2000 and 0x6000.
Stimulus: a packet cut by the reset (raw 21 bytes), reset while the device transmits, reset with the AXI stalled at 95 percent,
  reset right after 6 register writes; CLK-BUS period changes with backpressure 0/20/50 percent.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DRC-OUT | REQ-FUNC-004 | bulk OUT of 64 bytes | ACK inside the response gap | TB XH, GAP | 400 CLK-PHY | no ACK
  DRC-IN | REQ-FUNC-004 | bulk IN of 71 bytes | DATA0 with 64 bytes, then DATA1 with 7 | TB XD, GAP | 2000 CLK-PHY | wrong PID or data
  DRC-DONE | REQ-IF-006 | after 3000 bus cycles | the OUT bytes in memory; epo_int and epi_int done | TB MC, R | 3000 bus cycles | memory or flags wrong
  DRC-RSTVAL | REQ-RESET-001 | after each mid-activity reset (reset part) | ctrl core_en/dma_en 0, dctrl address 0 and soft_conn 0, irq_en 0, epo_ctl mps 0 and ep_en 0 | TB R | one access each | a register keeps a pre-reset value
  DRC-QUIET | REQ-RESET-001 | after each reset (reset part) | o_int_usb low and no packet for 60 cycles | TB XP, XN | 60 CLK-PHY | interrupt high or a packet after reset
Checkpoints per test: t_dir_reset_midxfer reaches all five; t_dir_clk_ratio reaches DRC-OUT, DRC-IN, DRC-DONE.
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM (after every reset in the reset part).
Expected outcome: (reset) four resets recover to a working device; (clk) all ten transfers complete at every ratio.
Defect/fault targeted: state surviving a reset (FIFO pointers, crossing commands, DMA burst), crossing logic that depends on a ratio.
Checker/oracle: reset values from the CSR description, transfers from USB 2.0; harness XH/XD/GAP/MC/R/XP/XN; negative-control audit.
Reproducibility: cd tests/usb20; python gen_dir_reset_clk.py SEED reset (t_dir_reset_midxfer, seeds 1 2) or SEED clk (t_dir_clk_ratio,
  seeds 1 2); from verification: python env/scripts/run.py sim t_dir_reset_midxfer dev_utmi8_axim tests/ops/dir_reset_sSEED.ops +seed=SEED
  (t_dir_clk_ratio: tests/ops/dir_clk_sSEED.ops)
Waveform: N/A: both tests are outside the ten priority tests of R-283 (sim/waveform_index.csv); build with --trace and run with +vcd.
Evidence: runs of t_dir_reset_midxfer and t_dir_clk_ratio in sim/index.csv (CHKPT lines in sim.log); review rows in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
part = sys.argv[2] if len(sys.argv) > 2 else 'reset'
s = Scn('dir_%s' % part, seed=seed)
ADDR = s.rng.randrange(1, 128)
MPS = 64


def traffic(d, base):
    po, pi = s.rnd(MPS), s.rnd(MPS + 7)
    s.w1c('epo_int', 1, done=1); s.w1c('epi_int', 2, done=1)
    arm_out(s, 1, MPS, 1, MPS, base, set_d0=1)
    arm_in(s, 2, pi, MPS, base + 0x400, set_d0=1, wait=4000)
    d.tog_out[1] = 0; d.tog_in[2] = 0
    s.chk('DRC-OUT')
    d.out(1, po); s.idle(40)
    s.chk('DRC-IN')
    d.in_(2, pi[:MPS]); s.idle(40)
    d.in_(2, pi[MPS:]); s.idle(40)
    s.idle_bus(3000)
    s.chk('DRC-DONE')
    s.mc(base, po)
    s.r('epo_int', 1, done=1)
    s.r('epi_int', 2, done=1)


def after_reset():
    s.emit('SG', 0, 300)
    s.linestate(1)
    s.emit('FLUSH')
    s.chk('DRC-RSTVAL')
    s.r('ctrl', core_en=0, dma_en=0)                       # reset values of the control registers
    s.r('dctrl', dev_addr=0, soft_conn=0)
    s.r('irq_en', sof=0, busrst=0)
    s.r('epo_ctl', 1, mps=0, ep_en=0)
    s.chk('DRC-QUIET')
    s.xp(1, 0, 1)                                          # interrupt output low after reset
    s.xn(60)                                               # nothing is transmitted
    d, _ = dev_bringup(s, address=ADDR)
    return d


if part == 'reset':
    d, _ = dev_bringup(s, address=ADDR)
    traffic(d, 0x2000)
    # 1. reset in the middle of a received packet
    arm_out(s, 1, MPS, 1, MPS, 0x3000, set_d0=1)
    s.emit('IPG', 0)
    s.token(OUT, ADDR, 1)
    s.raw([0xC3] + s.rnd(20))                              # packet cut short by the reset
    s.emit('IPG', 2)
    s.emit('RST', 6)
    d = after_reset()
    traffic(d, 0x2000)
    s.bin('cg_rst.in_pkt')
    # 2. reset while the device transmits a data packet
    pi = s.rnd(MPS)
    arm_in(s, 2, pi, MPS, 0x4000, set_d0=1)
    s.token(IN, ADDR, 2)
    s.wait(30)                                             # the packet is on the bus
    s.emit('RST', 6)
    d = after_reset()
    traffic(d, 0x2000)
    # 3. reset in the middle of a DMA burst (AXI stalled so that the burst is open)
    arm_out(s, 1, MPS, 1, MPS, 0x5000, set_d0=1)
    d.tog_out[1] = 0
    s.emit('BP', 95)
    d.out(1, s.rnd(MPS))
    s.idle_bus(60)
    s.emit('RST', 6)
    s.emit('BP', 0)
    d = after_reset()
    traffic(d, 0x2000)
    s.bin('cg_rst.in_dma')
    # 4. reset right after a burst of register writes (commands in the crossing)
    for i in range(6):
        s.w('epo_xfr', 1, xsize=64 + i, pkt_cnt=1)
    s.emit('RST', 6)
    d = after_reset()
    traffic(d, 0x2000)
    s.bin('cg_rst.in_xreg')
else:
    d, _ = dev_bringup(s, address=ADDR)
    for period, name in ((5000, 'cg_ratio.slow_bus'), (3003, 'cg_ratio.slow_bus'), (1667, 'cg_ratio.equal'),
                         (1000, 'cg_ratio.fast_bus'), (500, 'cg_ratio.fast_bus')):
        s.emit('CLK', period)                              # CLK-BUS period in hundredths of a nanosecond
        s.idle_bus(100)
        s.emit('BP', s.rng.choice([0, 20, 50]))
        traffic(d, 0x2000)
        traffic(d, 0x6000)
        s.bin(name)
    s.emit('CLK', 1000)
print(s.save('ops/dir_%s_s%d.ops' % (part, seed)))
