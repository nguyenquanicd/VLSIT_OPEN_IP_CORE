"""t_host_edge: host corner cases, one section per testlist row (argument force, sof, rxerr, iso, miss, imax, psplit, bsplit, gaps,
rxhold; default all). The rxerr section is also used by t_host_ulpi_ocp (argument ulpi: the error is an RX CMD inside the packet).
    python gen_host_edge.py SEED [SECTION ...] ts16

Test ID and title: t_host_edge - Test_Force_Enable, frame number roll-over, RxError in IN data, iso miss, poll_miss, interval 65535,
  periodic complete-split limit, bulk split errors, host packet gaps, RXActive stuck
Priority and rationale: P2. Host corner cases; kills M18 (iso retried), M19 (no complete-split limit) and M20 (no inter-packet gap).
Purpose: show the host behaviour at the edges listed in the title, each with a check of the observable result.
Requirements and features: REQ-FUNC-010, 014, 022, 032, 033, 038, 039; REQ-ERR-001; REQ-IF-003; USB 2.0 7.1.18 (gaps), 8.4.3 (frame
  number), 11.18 (split rules). Features host_sof, host_sched, split, test_mode.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up at high speed; SOF running.
Software flow (per section):
  force: hport.test_mode 5; read hsts; test_mode 0. sof: none (wait 2200 frames). rxerr/iso/gaps/rxhold: program a channel, poll the
  flag, compare memory, clear. miss: ctrl.dma_en 0, program a polled OUT, poll poll_miss, dma_en 1, poll done. imax: polled IN with
  interval 65535. psplit/bsplit: hc_spl and a split channel; (bsplit) poll ch_halt.
Stimulus: device silence (iso), RxError at byte 20 (rxerr), RXActive held 20000 cycles after 12 bytes (rxhold), NYET to complete-splits
  (psplit), hub errors to start-splits (bsplit), scripted answers elsewhere.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HED-FORCE | REQ-FUNC-022 | hport.test_mode 5 (force) | no SOF for 3 ms (scaled); hsts port_conn and port_en stay 1 | TB NSOF, R | 3 ms scaled | the host transmits or disables the port
  HED-FORCEX | REQ-FUNC-022 | test_mode 0 (force) | at least 8 SOF since the quiet period | TB SOFR | 2 ms scaled | SOF does not resume
  HED-ROLL | REQ-FUNC-010, USB 2.0 8.4.3 | 2200 frames (sof) | frame numbers consecutive through 7FFh to 000h, at least one roll-over | TB SOFW | 2200 ms scaled | a jump or no roll-over
  HED-RXERR | REQ-ERR-001, REQ-IF-003 | RxError inside the IN data (rxerr) | no ACK (the next packet is the retried IN), ACK for the good data; done; memory; xact_err | TB XT, XH, P, MC, R | 30000 CLK-PHY | the corrupted packet is acknowledged
  HED-ISO | REQ-FUNC-033 | iso IN with a silent device (iso) | hc_int.iso_inc and irq_raw.iso_inc; no retry for 250 us | TB XT, P, XN | 900 polls | an iso transfer is retried (M18)
  HED-MISS | REQ-FUNC-032 | polled OUT that cannot start (miss) | poll_miss at the second tick; after dma_en the OUT data goes out and done | TB P, XT, XD | 2000 polls | no poll_miss or no recovery
  HED-IMAX | REQ-FUNC-032 | polled IN with interval 65535 (imax) | first poll at once; no packet for 65527 SOF; the second poll then comes with ACK after the data | TB XT, XH, WSOF | 65535 microframes | early or missing second poll
  HED-PSPLIT | REQ-FUNC-038 | interrupt IN split, complete-splits answered NYET (psplit) | start-split (ET interrupt), then three complete-splits, each exactly one microframe after the previous | TB XS, XT, SOFD | 30000 CLK-PHY | two complete-splits in a microframe
  HED-PSPLIT4 | REQ-FUNC-038 | after the third NYET (psplit) | no fourth complete-split: the next packet is a new start-split | TB XS | 4 microframes scaled | a fourth complete-split (M19)
  HED-BSPLIT | REQ-FUNC-039 | start-split of a bulk OUT answered with errors (bsplit) | the start-split repeated three times with the same DATA0, then ch_halt | TB XS, XT, XD, P | 900 polls | more or fewer attempts or no halt
  HED-GAPTD | REQ-FUNC-014, USB 2.0 7.1.18 | bulk OUT token and data (gaps) | gap from the token to the data packet 11 to 24 cycles (88 to 192 bit times); done | TB XT, XD, GAPB, P | 30000 CLK-PHY | data sent back to back (M20)
  HED-GAPRSP | REQ-FUNC-014 | IN data from the device (gaps) | ACK 1 to 24 cycles after the data; done; memory | TB XT, XH, GAP, P, MC | 2000 CLK-PHY | gap out of window or memory wrong
  HED-RXHOLD | review F-019, REQ-ERR-001 | RXActive held high after 12 bytes (rxhold) | no ACK; the retried IN gets the good packet; done; only the good bytes at 0x1F00; xact_err | TB XT, XH, P, MC, R | 20000 CLK-PHY hold | the broken packet committed or the channel stuck
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: every section ends with the listed observation.
Known gaps: the first SOF count before Test_Force_Enable uses an unbounded interval window (only the count is meaningful).
Defect/fault targeted: iso retried (M18, BUG-041), complete-split limit missing (M19, BUG-042), inter-packet gap too short (M20, BUG-043),
  frame number errors, test mode leaking traffic, stuck receive.
Checker/oracle: USB 2.0 and REQ-FUNC rules in this script; harness NSOF/SOFR/SOFW/SOFD/WSOF/XS/XT/XD/XH/XN/GAP/GAPB/P/MC/R;
  qualified by M18, M19, M20.
Reproducibility: cd tests/usb20; python gen_host_edge.py 1 SECTION ts16; from verification:
  python env/scripts/run.py sim t_host_edge host_utmi8_axim_ts16 tests/ops/host_edge_SECTION_s1.ops +seed=1
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_edge in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
SEC = [a for a in sys.argv[2:] if a in ('force', 'sof', 'rxerr', 'iso', 'miss', 'imax', 'psplit', 'bsplit', 'gaps', 'rxhold')] or ['force', 'sof', 'rxerr', 'iso', 'miss', 'imax', 'psplit', 'bsplit', 'gaps', 'rxhold']
s = Scn('host_edge_' + '_'.join(SEC) if False else 'host_edge', seed=seed)
s.emit('WD', 1500000 if 'imax' in SEC else 400000)
speed = host_bringup(s)
s.wait(max(3000, us(500)))
if 'force' in SEC:
    s.emit('SOF', 3, 0, 10 ** 9)                              # SOF packets flow before the test mode
    s.emit('SOFW', 0)
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, test_mode=5)
    s.wait(us(2000))
    s.chk('HED-FORCE')
    s.emit('NSOF', us(3000))                                  # Test_Force_Enable: the host sends nothing
    s.r('hsts', port_conn=1, port_en=1)                       # port stays connected and enabled
    s.bin('cg_test.force_en')
    s.w('hport', oc_en=1, vbus_drv=1, sof_en=1, test_mode=0)  # leaving the mode: SOF resumes
    s.wait(us(2000))
    s.chk('HED-FORCEX')
    s.emit('SOFR', 8)                                         # SOF packets are back
if 'sof' in SEC:
    s.emit('SOFW', 0)
    for _ in range(2200):                                     # 2200 frames of 1 ms (scaled): past 2048
        s.wait(us(1000))
    s.chk('HED-ROLL')
    s.emit('SOFW', 1)
    s.bin('cg_sof.rollover')
if 'rxerr' in SEC:
    DEV, MPS = 0, 64
    p = DevPartner(s, DEV)
    pg = s.rnd(MPS)
    hc_program(s, 0, DEV, 1, 1, BULK, MPS, MPS, 1, 0x1400, pid=0)
    s.chk('HED-RXERR')
    s.xt(IN, DEV, 1, TMO)
    s.wait(8)
    s.raw([0xC3] + s.rnd(MPS) + [0x00, 0x00], rxerr_at=20)    # the PHY flags a receive error in the middle of the packet
    if 'ulpi' in sys.argv:
        s.bin('cg_ulpi.rxcmd_in_pkt')
    p.in_(1, DATA0, pg)                                       # the next packet of the host is the retried IN token, not an ACK; it takes the good packet
    s.poll('hc_int', 0, done=1)
    s.mc(0x1400, pg)
    s.r('hc_int', 0, xact_err=1)
    s.w1c('hc_int', 0, done=1, xact_err=1)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1, poll_miss=1, iso_inc=1)
if 'iso' in SEC:
    hc_program(s, 0, 0, 4, 1, ISO, 64, 64, 1, 0x1800, pid=0)
    s.chk('HED-ISO')
    s.xt(IN, 0, 4, TMO)                                       # the device does not answer in its microframe
    s.poll('hc_int', 0, tries=900, iso_inc=1)                 # the channel flag
    s.poll('irq_raw', tries=900, iso_inc=1)                   # the global flag (after the clock crossing)
    s.xn(int(us(250)))                                        # no retry: an isochronous transfer is not repeated
    s.bin('cg_isoinc.host_late')
    s.w1c('hc_int', 0, **ALL)
    s.wraw('irq_raw', 0, IRQ_ALL)
if 'miss' in SEC:
    po = s.rnd(8)
    s.mw(0x1900, po)
    s.w('ctrl', core_en=1, dma_en=0, ahb_err_stop=1)           # the DMA is off: the data of the OUT channel never reaches the transmit region
    s.idle_bus(100)
    hc_program(s, 1, 0, 5, 0, INTR, 8, 8, 1, 0x1900, pid=0, poll_en=1, poll_rep=1, interval=1)
    s.chk('HED-MISS')
    s.poll('hc_int', 1, tries=2000, poll_miss=1)              # due at one tick and still not served at the next one: poll_miss
    s.bin('cg_poll.miss')
    s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)          # the DMA comes back: the channel is served
    p = DevPartner(s, 0)
    p.out(5, DATA0, po)
    s.poll('hc_int', 1, tries=2000, done=1)
    s.w1c('hc_int', 1, **ALL)
if 'imax' in SEC:
    IMAX = 0xFFFF
    p = DevPartner(s, 0)
    hc_program(s, 2, 0, 6, 1, INTR, 8, 16, 2, 0x1A00, pid=0, poll_en=1, poll_rep=1, interval=IMAX)      # two packets: the second poll is the one the interval delays
    s.chk('HED-IMAX')
    p.in_(6, DATA0, s.rnd(8))                                 # the first poll goes out at once
    s.emit('WSOF', IMAX - 8)                                  # then nothing for the interval (counted in SOF packets: one per microframe)
    s.xt(IN, 0, 6, us(125 * 16))                              # the next poll comes after 65535 microframes
    s.wait(8)
    s.data(DATA1, s.rnd(8))
    s.xh(ACK, 2000)
    s.bin('cg_poll.int_max')
HUB, PORT, FSDEV = 2, 3, 5


def hc_split(ch):
    s.w('hc_spl', ch, hub_addr=HUB, port_addr=PORT, xact_pos=0, comp_split=0, split_en=1)


if 'psplit' in SEC:
    pi = s.rnd(8)
    s.mw(0x1B00, [0] * 8)
    hc_split(3)
    hc_program(s, 3, FSDEV, 2, 1, INTR, 8, 8, 1, 0x1B00, pid=0, speed=1, poll_en=1, poll_rep=0, interval=1)
    s.chk('HED-PSPLIT')
    s.xs(HUB, 0, PORT, 0, 0, 3, TMO)                         # start-split of the interrupt IN transaction
    s.xt(IN, FSDEV, 2, 3000)
    s.wait(8)
    s.hs(ACK)
    for k in range(3):                                       # three complete-splits, each in its own microframe, answered NYET
        s.xs(HUB, 1, PORT, 0, 0, 3, TMO)
        s.xt(IN, FSDEV, 2, 3000)
        s.wait(8)
        s.hs(NYET)
        if k > 0:
            s.emit('SOFD', 1, 1)                                 # exactly one microframe after the previous complete-split
        s.emit('SOFM')
    s.bin('cg_psplit.uf_each')
    s.bin('cg_psplit.third_cs')
    s.chk('HED-PSPLIT4')
    s.xs(HUB, 0, PORT, 0, 0, 3, us(125 * 4))                 # no fourth complete-split: the next packet is a new start-split (REQ-FUNC-038)
if 'bsplit' in SEC:
    pb = s.rnd(64)
    s.mw(0x1C00, pb)
    hc_split(4)
    hc_program(s, 4, FSDEV, 1, 0, BULK, 64, 64, 1, 0x1C00, pid=0, speed=1)
    s.chk('HED-BSPLIT')
    for k in range(3):                                       # the hub answers the start-split with a transaction error (no handshake) three times
        s.xs(HUB, 0, PORT, 0, 0, 2, TMO)
        s.xt(OUT, FSDEV, 1, 3000)
        s.xd(DATA0, pb, tmo=3000)
    s.poll('hc_int', 4, tries=900, ch_halt=1)                # REQ-FUNC-039: the third error ends the transfer
    s.bin('cg_bsplit.err3')
    s.w1c('hc_int', 4, **ALL)
if 'gaps' in SEC:
    p = DevPartner(s, 0)
    po, pi = s.rnd(64), s.rnd(64)
    s.mw(0x1D00, po)
    hc_program(s, 6, 0, 1, 0, BULK, 64, 64, 1, 0x1D00, pid=0)
    s.chk('HED-GAPTD')
    s.xt(OUT, 0, 1, TMO)
    s.xd(DATA0, po, tmo=TMO)
    s.gapb(*((6, 12) if 'w16' in sys.argv else (11, 24)))     # token to data: 88 to 192 bit times (11 to 24 cycles of 8 bit times, 6 to 12 of 16)
    s.bin('cg_gap_host.b2b')
    s.wait(8)
    s.hs(ACK)
    s.poll('hc_int', 6, tries=900, done=1)
    s.w1c('hc_int', 6, **ALL)
    hc_program(s, 6, 0, 1, 1, BULK, 64, 64, 1, 0x1E00, pid=0)
    s.chk('HED-GAPRSP')
    s.xt(IN, 0, 1, TMO)
    s.wait(8)
    s.data(DATA0, pi)
    s.xh(ACK, 2000)
    s.gap(1, 24)                                              # response of the host to a data packet: 8 to 192 bit times
    s.bin('cg_gap_host.min'); s.bin('cg_gap_host.max')
    s.poll('hc_int', 6, tries=900, done=1)
    s.idle_bus(600)
    s.mc(0x1E00, pi)                                          # the IN data in memory (nc_mem GAP)
    s.w1c('hc_int', 6, **ALL)
if 'rxhold' in SEC:
    # review 2026-11-22 F-019: the PHY keeps RXActive high after the start of a data packet (no more data, no end). UTMI+ does not
    # let the link transmit while RXActive is high, so no protocol action is possible until it falls; expected: no ACK, the
    # transaction counts as an error when RXActive falls, the channel retries and finishes with the good packet, nothing of the
    # broken packet is committed (the memory holds only the good data).
    p = DevPartner(s, 0)
    pg = s.rnd(MPS if 'MPS' in dir() else 64)
    hc_program(s, 7, 0, 2, 1, BULK, 64, 64, 1, 0x1F00, pid=0)
    s.mw(0x1F00, [0xEE] * 64)
    s.xt(IN, 0, 2, TMO)
    s.wait(8)
    s.chk('HED-RXHOLD')
    s.emit('RXH', 20000, 12, 0xC3, *s.rnd(11))                # DATA0 PID and 11 bytes, then RXActive stuck for 20000 cycles
    p.in_(2, DATA0, pg)                                       # the next packet of the host is the retried IN token, not an ACK
    s.poll('hc_int', 7, tries=900, done=1)
    s.idle_bus(600)
    s.mc(0x1F00, pg)
    s.r('hc_int', 7, xact_err=1)
    s.w1c('hc_int', 7, done=1, xact_err=1)
    s.bin('cg_err.rx_stuck')
s.emit('FLUSH')
print(s.save('ops/host_edge_%s_s%d.ops' % ('_'.join(SEC), seed)))
