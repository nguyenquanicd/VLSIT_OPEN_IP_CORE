"""t_host_bigpkt: high-speed bulk IN and OUT with 512-byte packets (USB 2.0 5.8.3).

Test ID and title: t_host_bigpkt - 512-byte bulk IN received completely and acknowledged; 512 + 100 bytes bulk OUT
Priority and rationale: P2. The response time-out must stop counting when the device starts to answer; kills M15 (BUG-039).
Purpose: show that two 512-byte IN packets are received completely and acknowledged and land in memory, and that a 612-byte OUT transfer
  sends a 512-byte and a 100-byte packet with alternating toggles.
Requirements and features: REQ-FUNC-015, 016, 025; REQ-IF-006; USB 2.0 5.8.3. Features host_sched, axi_master_dma, fifo_mgr.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up with a 1024-word receive region.
Software flow:
  1. Program channel 0 (IN 1024 bytes, 2 packets); poll done; wait for the DMA drain; compare memory.
  2. Program channel 1 (OUT 612 bytes from 0x9000); poll done. Read irq_raw.
Stimulus: device DATA0/DATA1 512-byte packets; ACK to the OUT packets.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HBP-IN | REQ-FUNC-025, BUG-039 | two 512-byte IN data packets | IN tokens; ACK of the host after each full packet | TB XT, XH | 2000 CLK-PHY for the ACK | the time-out cuts the long packet
  HBP-INMEM | REQ-IF-006 | after done and the drain | done; the 1024 bytes at 0x8000 | TB P, MC | 1500 polls, 4000 bus cycles | memory wrong
  HBP-OUT | REQ-FUNC-004, 015 | channel 1 OUT | DATA0 with 512 bytes, DATA1 with 100 bytes; done | TB XT, XD, P | 30000 CLK-PHY per packet | wrong split or toggle
  HBP-CLEAN | REQ-ERR-001 | end | no crc_err, pid_err or babble | TB R | end | an error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: maximum-size high-speed bulk packets work in both directions.
Defect/fault targeted: response time-out cutting a long packet (M15, BUG-039); 512-byte packet split errors.
Checker/oracle: USB 2.0 5.8.3 sizes in this script; harness XT/XH/XD/P/MC/R; qualified by M15.
Reproducibility: cd tests/usb20; python gen_host_bigpkt.py SEED ts16 (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_bigpkt host_utmi8_axim_ts16 tests/ops/host_bigpkt_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_bigpkt in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_bigpkt', seed=seed)
s.emit('WD', 120000)
host_bringup(s, rx_size=0x400, hnp=(0x400, 0x100), hpt=(0x500, 0x100))
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
p = DevPartner(s, 0)
MPS = 512
pi = [s.rnd(MPS), s.rnd(MPS)]
hc_program(s, 0, 0, 2, 1, BULK, MPS, 2 * MPS, 2, 0x8000, pid=0)
s.chk('HBP-IN')
p.in_(2, DATA0, pi[0])
p.in_(2, DATA1, pi[1])
s.chk('HBP-INMEM')
s.poll('hc_int', 0, tries=1500, done=1)
s.idle_bus(4000)                                                  # the DMA still drains the 1 KB of the receive queue after the done flag
s.mc(0x8000, pi[0] + pi[1])
s.w1c('hc_int', 0, **ALL)
s.bin('cg_len.max')
po = [s.rnd(MPS), s.rnd(100)]
s.mw(0x9000, po[0] + po[1])
hc_program(s, 1, 0, 3, 0, BULK, MPS, MPS + 100, 2, 0x9000, pid=0)
s.chk('HBP-OUT')
p.out(3, DATA0, po[0])
p.out(3, DATA1, po[1])
s.poll('hc_int', 1, tries=1500, done=1)
s.w1c('hc_int', 1, **ALL)
s.chk('HBP-CLEAN')
s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_bigpkt_s%d.ops' % seed))
