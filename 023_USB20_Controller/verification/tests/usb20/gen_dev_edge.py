"""t_dev_edge: device corner cases, one section per testlist row (argument len, pid, gap, tmo, abort or ovf; default all).
Also used by t_dev_pipe_equiv and t_dev_ulpi_traffic (with ulpi).

Test ID and title: t_dev_edge - oversize data, undecoded PIDs, shortest/longest response gaps, early ACK, CRC rollback, receive overflow
Priority and rationale: P2. Boundary behaviour of the receive path; kills M17 (BUG-040, oversize OUT acknowledged and stored).
Purpose: show that data longer than the endpoint maximum (65 bytes) or than any legal packet (1025 bytes) is dropped without a handshake,
  that undecoded PIDs get no answer, that the response gap stays in the window for zero-length and maximum packets, that a CRC-error
  packet is rolled back so the retry lands at the buffer start, and that a packet larger than the free receive region raises fifo_ovf.
Requirements and features: REQ-FUNC-002, 006, 008, 025, 026, 033; REQ-ERR-001; USB 2.0 chapters 5 and 8. Features packet_size,
  turnaround, fifo_mgr, crc.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up at a random address; OUT 1 DMA at 0x2000, IN 1 at 0x4000.
Software flow:
  1. Bring-up; endpoint DMA addresses.
  2. Per section: wait for epo_ctl.ep_en 0 and arm OUT 1 (or arm IN 1); (ovf) shrink fifo_rx to 20 rows, clear fifo_ovf, then poll it,
     clear it and restore fifo_rx.
Stimulus: OUT DATA0 of 65 and 1025 bytes; tokens with PID 0xC and 0x8; zero-length and 64-byte OUT; host ACK one byte time after the IN
  data; OUT with a CRC16 error then the good packet; a 100-byte OUT into a 20-row region.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DEG-LEN65 | REQ-FUNC-008, REQ-ERR-001 | 65-byte DATA0 to a 64-byte endpoint (len) | no handshake | TB XN | 400 CLK-PHY | the oversize packet is acknowledged (M17)
  DEG-LEN1025 | REQ-FUNC-008 | 1025-byte DATA0 (len) | no handshake | TB XN | 400 CLK-PHY | acknowledged
  DEG-LENOK | REQ-FUNC-004, 008 | good 64-byte packet after the dropped ones (len) | ACK with DATA0 (toggle unchanged); only the good bytes at 0x2000 | TB XH, GAP, MC | 600 bus cycles | toggle advanced or the dropped data stored
  DEG-PID | REQ-FUNC-002 | tokens with PID 0xC and 0x8 and a good check field (pid) | no answer | TB XN | 300 CLK-PHY each | an answer
  DEG-GAP | REQ-FUNC-006 | zero-length and 64-byte OUT (gap) | ACK with the response gap in 1 to 24 cycles for both | TB XH, GAP | 400 CLK-PHY | gap outside the window
  DEG-EARLY | REQ-FUNC-025 | IN to endpoint 1 (tmo) | DATA0 with the 64 bytes (the host then ACKs after one byte time; whether that ACK is accepted is not checked, no further IN follows) | TB XD | 400 CLK-PHY | wrong data packet
  DEG-ABORT | REQ-FUNC-002, 026 | OUT with a CRC16 error, then the good packet (abort) | no handshake for the bad one; ACK for the retry; the good bytes at the start of the buffer (0x2000) | TB XN, XH, MC | 3000 bus cycles | the bad rows not rolled back
  DEG-OVF | REQ-ERR-001 | 100-byte OUT into a 20-row receive region (ovf) | no handshake; irq_raw.fifo_ovf set | TB XN, P | 200 polls | ACK or no flag
  DEG-OVFREC | REQ-FUNC-004 | after restoring the region (ovf) | the next 64-byte OUT is acknowledged | TB XH, GAP | 400 CLK-PHY | the endpoint stays blocked
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: every corner case is handled as listed and the endpoint keeps working.
Known gaps: (len) the error reporting is only printed (RP), not compared; (tmo) the acceptance of the earliest ACK is not checked (the
  latest-ACK edge is checked by t_fi_bus_errors FBE-TMOIN/FBE-LATE).
Defect/fault targeted: oversize OUT acknowledged and stored (M17, BUG-040); rollback missing; gap out of window; overflow not flagged.
Checker/oracle: USB 2.0 limits in this script; harness XN/XH/XD/GAP/MC/P; qualified by M17.
Reproducibility: cd tests/usb20; python gen_dev_edge.py SEED SECTION (SECTION len, pid, gap, tmo, abort, ovf; seeds 1 2); from verification:
  python env/scripts/run.py sim t_dev_edge dev_utmi8_axim tests/ops/dev_edge_SECTION_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dev_edge in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
SEC = [a for a in sys.argv[2:] if a in ('len', 'pid', 'gap', 'tmo', 'abort', 'ovf')] or ['len', 'pid', 'gap', 'tmo', 'abort', 'ovf']
s = Scn('dev_edge', seed=seed)
R = s.rng
ADDR = R.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR)
s.w('epo_dma', 1, addr=0x2000)
s.w('epi_dma', 1, addr=0x4000)
s.idle_bus(200)


def arm_out_ep(mps, xsize, pkts, typ=BULK, **more):
    s.poll('epo_ctl', 1, tries=300, ep_en=0)
    s.w('epo_xfr', 1, xsize=xsize, pkt_cnt=pkts)
    s.w('epo_ctl', 1, mps=mps, type=typ, ep_en=1, set_d0=1, **more)
    d.tog_out[1] = 0
    s.idle_bus(300)


if 'len' in SEC:
    arm_out_ep(64, 192, 3)
    s.token(OUT, ADDR, 1)
    s.chk('DEG-LEN65')
    s.data(DATA0, s.rnd(65))                                      # max + 1
    s.xn(400)                                                       # babble: dropped, no handshake
    s.bin('cg_len.over')
    s.idle_bus(300)
    s.token(OUT, ADDR, 1)
    s.chk('DEG-LEN1025')
    s.data(DATA0, s.rnd(1025))                                    # 1025 bytes: longer than any legal packet
    s.xn(400)
    s.idle_bus(300)
    s.show('irq_raw'); s.show('epo_int', 1)
    s.chk('DEG-LENOK')
    pg = s.rnd(64)
    d.out(1, pg)                                                    # the endpoint still works afterwards (toggle unchanged)
    s.idle_bus(600)
    s.mc(0x2000, pg)                                                # only the good packet reached memory: the dropped ones wrote nothing (nc_mem GAP)
if 'pid' in SEC:
    s.chk('DEG-PID')
    for pid in (0xC, 0x8):                                          # ERR/PRE and SPLIT are not decoded by a device
        s.token(pid, ADDR, 1)
        s.xn(300)
    s.bin('cg_pid.undefined')
if 'gap' in SEC:
    arm_out_ep(64, 128, 2)
    s.chk('DEG-GAP')
    d.out(1, [])                                                    # zero-length packet: shortest response
    if 'ulpi' in sys.argv:
        s.bin('cg_gap_ulpi.min')
    d.out(1, s.rnd(64))                                             # longest packet of the endpoint
    s.bin('cg_gap_dev.max')
    if 'ulpi' in sys.argv:
        s.bin('cg_gap_ulpi.max')
if 'tmo' in SEC:
    pin = s.rnd(64)
    arm_in(s, 1, pin, 64, 0x4000, pkts=2, set_d0=1)
    d.tog_in[1] = 0
    s.token(IN, ADDR, 1)
    s.chk('DEG-EARLY')
    s.xd(DATA0, pin, tmo=400)
    s.wait(1)
    s.hs(ACK)                                                       # earliest ACK gap: one byte time
    s.bin('cg_tmo.early_edge')
    d.tog_in[1] = 1
    s.idle_bus(300)
if 'abort' in SEC:
    arm_out_ep(64, 128, 2)
    good = s.rnd(64)
    s.token(OUT, ADDR, 1)
    s.chk('DEG-ABORT')
    s.data(DATA0, s.rnd(64), crc_flip=1)                           # bad CRC16: no ACK, the rows written so far are rolled back
    s.xn(400)
    s.idle_bus(300)
    d.out(1, good)                                                  # the repeated packet is accepted
    s.idle_bus(3000)
    s.mc(0x2000, good)                                              # and sits at the start of the buffer
    s.bin('cg_fifo.abort_restore')
if 'ovf' in SEC:
    arm_out_ep(64, 192, 3)
    s.w('fifo_rx', start=0, size=20)                                # 20 rows: room for one maximum packet (16 rows), not for 100 bytes
    s.idle_bus(100)
    s.w1c('irq_raw', fifo_ovf=1)
    s.token(OUT, ADDR, 1)
    s.chk('DEG-OVF')
    s.data(DATA0, s.rnd(100))
    s.xn(400)
    s.idle_bus(300)
    s.poll('irq_raw', tries=200, fifo_ovf=1)                        # REQ-ERR-001: the overflow reaches the interrupt status
    s.bin('cg_err.fifo')
    s.w1c('irq_raw', fifo_ovf=1)
    s.w('fifo_rx', start=0, size=0x100)
    s.idle_bus(100)
    s.chk('DEG-OVFREC')
    d.out(1, s.rnd(64))
print(s.save('ops/dev_edge_%s_s%d.ops' % ('_'.join(SEC), seed)))
