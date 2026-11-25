"""t_dev_fs_fallback: device falls back to full speed without a host chirp (argument ts1 for the real-timer build).

Test ID and title: t_dev_fs_fallback - no host chirp: full speed, full-speed row, bulk OUT and IN on the last endpoint
Priority and rationale: P2. A high-speed device must work behind a full-speed hub; kills M13 (BUG-035, chirping again in the same reset).
Purpose: show that without the K-J sequence the device stays at full speed (sts.speed 1, full-speed row) and moves bulk data on
  endpoint 4 (the last of the build) with 64-byte packets.
Requirements and features: REQ-FUNC-013, 024; section 6.3 full-speed row; USB 2.0 chapter 8. Features hs_chirp, data_toggle, axi_master_dma.
DUT configuration and preconditions: build dev_utmi8_axim (and dev_utmi8_axim_ts1 with argument ts1); device bring-up without the host
  chirp and without high-speed keep-alive; SOF every scaled frame (SG).
Software flow:
  1. Bring-up (full speed); program endpoint 4 OUT (2 packets) and IN DMA addresses.
  2. After the OUT data compare memory; arm IN 4 with 64 bytes; read irq_raw.
Stimulus: host OUT 64 and 30 bytes; IN token.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DFS-ROW | REQ-FUNC-024, section 6.3 | after the fallback | full-speed row: XcvrSelect 01b, TermSelect 1, OpMode 00b | TB XP | immediately | high-speed row without the handshake
  DFS-OUT | REQ-FUNC-004 | two OUT packets to endpoint 4 | ACK each (DATA0, DATA1) | TB XH, GAP | 400 CLK-PHY | no ACK at full speed
  DFS-MEM | REQ-IF-006 | after the OUT transfer | 94 bytes at 0x2000 | TB MC | 3000 bus cycles | memory wrong
  DFS-IN | REQ-FUNC-004 | IN to endpoint 4 | DATA0 with the 64 bytes | TB XD, GAP | 2000 CLK-PHY | wrong data
  DFS-CLEAN | REQ-ERR-001 | end | no crc_err, pid_err, fifo_ovf, dma_err | TB R | end | an error flag
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-FS, DBU-ENUM.
Expected outcome: the device runs at full speed and both transfers work on the last endpoint.
Defect/fault targeted: second chirp in the same reset after the revert (M13, BUG-035); high speed assumed without the handshake.
Checker/oracle: USB 2.0 7.1.7.5 handshake and the section 6.3 table in this script; harness XP/XH/XD/GAP/MC/R; qualified by M13.
Reproducibility: cd tests/usb20; python gen_dev_fs.py SEED (and SEED ts1 on dev_utmi8_axim_ts1) (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_fs_fallback dev_utmi8_axim tests/ops/dev_fs_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dev_fs_fallback in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_fs', seed=seed)
ADDR = s.rng.randrange(1, 128)
d, speed = dev_bringup(s, address=ADDR, hub_chirp=False, sof=False)
assert speed == 'fs'
s.bin('cg_chirp_d.fs_fallback'); s.bin('cg_speed.fs'); s.bin('cg_chirp_d.short')
s.emit('SG', 1, 2400)                                          # one SOF per (scaled) full-speed frame keeps the device awake
s.chk('DFS-ROW')
s.xp(0, mode(1, 1, 0), MODE_MASK)                              # full-speed row: XcvrSelect 01b, TermSelect 1, OpMode 00b
EP = 4                                                         # the last endpoint of the build (NUM_EP = 4)
s.bin('cg_ep.last')
s.w('epo_dma', EP, addr=0x2000)
s.w('epi_dma', EP, addr=0x4000)
s.w('epo_xfr', EP, xsize=64 * 2, pkt_cnt=2)
s.w('epo_ctl', EP, mps=64, type=BULK, ep_en=1, set_d0=1)
s.idle_bus(400)
po = [s.rnd(64), s.rnd(30)]
s.chk('DFS-OUT')
d.out(EP, po[0]); s.idle(60)
d.out(EP, po[1]); s.idle(60)
s.idle_bus(3000)
s.chk('DFS-MEM')
s.mc(0x2000, sum(po, []))
pin = s.rnd(64)
arm_in(s, EP, pin, 64, 0x4000, pkts=1, set_d0=1)
d.tog_in[EP] = 0
s.chk('DFS-IN')
d.in_(EP, pin)
s.idle_bus(600)
s.chk('DFS-CLEAN')
s.r('irq_raw', crc_err=0, pid_err=0, fifo_ovf=0, dma_err=0)
print(s.save('ops/dev_fs%s_s%d.ops' % ('_ts1' if 'ts1' in sys.argv else '', seed)))
