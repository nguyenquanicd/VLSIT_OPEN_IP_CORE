"""t_fi_host_bus_errors: the device partner answers the host with errors (fault injection).

Test ID and title: t_fi_host_bus_errors - host channel on STALL, NAK, no response, CRC error, repeated data PID, STALLed SETUP
Priority and rationale: P1, rank 6 of the R-283 list. Host error recovery decides whether a driver sees the right channel status.
Purpose: show that STALL halts the channel, a NAKed OUT repeats the same packet and toggle, three missing responses halt the channel
  with timeout, a corrupted IN packet is not acknowledged and is reported, and a repeated data PID is acknowledged and dropped.
Requirements and features: REQ-FUNC-004, 025; REQ-ERR-001; ERR-001 to ERR-005. USB 2.0 8.5 (handshakes), 8.6.4 (toggle errors),
  section 11.3 (hc_int flags, fifo_ctl flush).
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up at high speed; channel 0 reused for every case.
Software flow:
  1. Program channel 0 for each case (hc_dma, hc_xfer, hc_ctrl); poll the expected hc_int flags; read hc_ctrl or the extra flags.
  2. After the STALLed OUT flush the non-periodic transmit region (fifo_ctl tx_sel, fl_tx; poll fl_tx = 0).
  3. Clear every hc_int flag and irq_raw after each case.
Stimulus: STALL to IN; STALL to OUT; NAK then ACK to OUT; three IN tokens without answer; IN data with a CRC16 error then good data;
  repeated DATA0 from the device; STALL to a SETUP.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FHB-STALLIN | ERR-001 | IN answered with STALL | hc_int ch_halt and stall; hc_ctrl.ch_en reads 0 | TB XT, P, R | 30000 CLK-PHY, 400 polls | channel not halted
  FHB-STALLOUT | ERR-001, section 11.3 fifo_ctl | OUT answered with STALL | ch_halt and stall; the transmit flush completes (fl_tx back to 0) | TB XT, XD, P | 400 polls | no halt or flush stuck
  FHB-NAK | REQ-FUNC-004, ERR-003 | OUT answered NAK, then ACK | the same packet with DATA0 repeated, then DATA1 with the next packet; done and nak | TB XT, XD, P, R | 30000 CLK-PHY per packet | toggle advanced on NAK or data changed
  FHB-TMO | REQ-FUNC-025, ERR-004 | three IN tokens without answer | each IN repeated after the time-out; after the third the channel halts with timeout | TB XT, P | 30000 CLK-PHY each | fewer or more retries, no halt
  FHB-CRC | ERR-002 | IN data with a CRC16 error, then good data | no ACK for the bad packet (the next packet is the repeated IN), ACK for the good one; done; the good data at 0x1400; xact_err reported | TB XT, XH, P, MC, R | 2000 CLK-PHY for the ACK | bad packet acknowledged or stored
  FHB-DUP | REQ-FUNC-004, ERR-005 | device repeats DATA0 | the host ACKs the duplicate, stores it once; done; p1 + p2 at 0x1500; tog_err | TB XT, XH, P, MC, R | 2000 CLK-PHY | duplicate stored or not acknowledged
  FHB-SETUPSTALL | ERR-001 | SETUP answered with STALL | SETUP token and DATA0 with the 8 bytes, then ch_halt | TB XT, XD, P | 30000 CLK-PHY | the control channel does not halt
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: each error case ends with the channel status of USB 2.0 chapter 8 and memory holds only the good data.
Defect/fault targeted: STALL not halting, toggle advanced on NAK, missing retry or retry limit, corrupted data acknowledged or stored,
  duplicate data stored twice.
Checker/oracle: expected packets and flags from USB 2.0 chapter 8 and the CSR description; harness XT/XD/XH/P/R/MC; negative-control audit.
Reproducibility: cd tests/usb20; python gen_fi_host_bus_errors.py SEED ts16 (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_host_bus_errors host_utmi8_axim_ts16 tests/ops/fi_host_bus_errors_sSEED.ops +seed=SEED
Waveform: rank 6 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_fi_host_bus_errors
Evidence: runs of t_fi_host_bus_errors in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_host_bus_errors', seed=seed)
s.emit('WD', 60000)
DEV = 0
host_bringup(s)
p = DevPartner(s, DEV)
MPS = 64
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)


def flush_hnp():
    """Software discards the data of the non-periodic transmit region after a halted OUT channel (u2_fifo_ctl, section 11.3)."""
    s.w('fifo_ctl', tx_sel=0x10)
    s.w('fifo_ctl', tx_sel=0x10, fl_tx=1)
    s.poll('fifo_ctl', fl_tx=0)


def clear(ch):
    s.w1c('hc_int', ch, **ALL)
    s.wraw('irq_raw', 0, IRQ_ALL)
    s.idle_bus(20)


# ---- A. IN answered with STALL: the channel halts
hc_program(s, 0, DEV, 1, 1, BULK, MPS, MPS, 1, 0x1000, pid=0)
s.chk('FHB-STALLIN')
p.in_hs(1, STALL)
s.poll('hc_int', 0, ch_halt=1, stall=1)
s.r('hc_ctrl', 0, ch_en=0)
clear(0)
s.bin('cg_flow.nak')
# ---- B. OUT answered with STALL
po = s.rnd(MPS)
s.mw(0x1100, po)
hc_program(s, 0, DEV, 1, 0, BULK, MPS, MPS, 1, 0x1100, pid=0)
s.chk('FHB-STALLOUT')
p.out(1, DATA0, po, answer=STALL)
s.poll('hc_int', 0, ch_halt=1, stall=1)
flush_hnp()
clear(0)
# ---- C. OUT answered with NAK, then ACK: the same packet is repeated with the same toggle, then the next toggles
pn = [s.rnd(MPS), s.rnd(MPS)]
s.mw(0x1200, sum(pn, []))
hc_program(s, 0, DEV, 1, 0, BULK, MPS, MPS * 2, 2, 0x1200, pid=0)
s.chk('FHB-NAK')
p.out(1, DATA0, pn[0], answer=NAK)
p.out(1, DATA0, pn[0], answer=ACK)
p.out(1, DATA1, pn[1], answer=ACK)
s.poll('hc_int', 0, done=1)
s.r('hc_int', 0, nak=1)
clear(0)
s.bin('cg_toggle.retry_same')
# ---- D. IN with no response three times: transaction error, retries, halt with xact_err
hc_program(s, 0, DEV, 1, 1, BULK, MPS, MPS, 1, 0x1300, pid=0)
s.chk('FHB-TMO')
for _ in range(3):
    s.xt(IN, DEV, 1, TMO)                                    # no answer from the device
s.poll('hc_int', 0, timeout=1, ch_halt=1)                    # ERR-004: time-out or xact_err; the RTL reports timeout
clear(0)
s.bin('cg_err.timeout')
# ---- E. IN with a CRC error in the data from the device, then good data: the host does not acknowledge the bad packet
pg = s.rnd(MPS)
hc_program(s, 0, DEV, 1, 1, BULK, MPS, MPS, 1, 0x1400, pid=0)
s.chk('FHB-CRC')
s.xt(IN, DEV, 1, TMO); s.wait(8); s.data(DATA0, s.rnd(MPS), crc_flip=0x0010)
p.in_(1, DATA0, pg)
s.poll('hc_int', 0, done=1)
s.mc(0x1400, pg)
s.r('hc_int', 0, xact_err=1)                                  # the error of the corrupted packet is reported (ERR-002)
clear(0)
s.bin('cg_err.crc')
# ---- F. IN where the device repeats the previous data PID (lost ACK on the device side): acknowledged, stored once
p1, p2 = s.rnd(MPS), s.rnd(MPS)
hc_program(s, 0, DEV, 1, 1, BULK, MPS, MPS * 2, 2, 0x1500, pid=0)
s.chk('FHB-DUP')
p.in_(1, DATA0, p1)
s.xt(IN, DEV, 1, TMO); s.wait(8); s.data(DATA0, p1)           # the device sends DATA0 again
s.xh(ACK, 2000)                                               # the host acknowledges the duplicate and drops it
p.in_(1, DATA1, p2)
s.poll('hc_int', 0, done=1)
s.mc(0x1500, p1 + p2)
s.r('hc_int', 0, tog_err=1)
clear(0)
s.bin('cg_toggle.dup_discard')
# ---- G. SETUP answered with a handshake other than ACK (STALL): control transfer halts
setup = [0x00, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]
s.mw(0x1600, setup)
hc_program(s, 0, DEV, 0, 0, CTRL, MPS, 8, 1, 0x1600, pid=0, setup=1)
s.chk('FHB-SETUPSTALL')
s.xt(SETUP, DEV, 0, TMO); s.xd(DATA0, setup, tmo=TMO); s.wait(8); s.hs(STALL)
s.poll('hc_int', 0, ch_halt=1)
clear(0)
s.bin('cg_err.pid')
print(s.save('ops/fi_host_bus_errors_s%d.ops' % seed))
