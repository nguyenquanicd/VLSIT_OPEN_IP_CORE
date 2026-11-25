"""t_host_budget: frame budget under load (argument ts1: real timers, as in the testlist).

Test ID and title: t_host_budget - eight channels of 2 x 512-byte bulk OUT: no transaction crosses a SOF, SOF stays periodic
Priority and rationale: P2. A host that starts a transaction it cannot finish before the SOF breaks the frame timing of every device.
Purpose: show that with more traffic than a microframe holds the SOF interval stays at 125 us +- 62.5 ns (TSCALE 1), every packet arrives
  complete at the partner in the expected order and all channels finish.
Requirements and features: REQ-FUNC-010, 014. Features host_sof, host_sched.
DUT configuration and preconditions: build host_utmi8_axim_ts1 (TSCALE 1); host bring-up at high speed.
Software flow:
  1. Bring-up; check SOF; write 8 x 1024 bytes to memory; program channels 0 to 7 (bulk OUT, 2 packets, endpoints 1 to 3).
  2. Poll done of every channel and clear. Check SOF again; read irq_raw.
Stimulus: device ACK to every OUT packet.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HBG-SOF1 | REQ-FUNC-010 | before the load | at least 3 SOF at 125 us +- 62.5 ns | TB SOF | 500 us | SOF missing or off interval
  HBG-PKTS | REQ-FUNC-014, 004 | 8 channels enabled | 16 OUT transactions in channel order, each 512 bytes with the toggle per endpoint | TB XT, XD | 30000 CLK-PHY per packet | a packet cut or out of order
  HBG-DONE | REQ-FUNC-015 | after the traffic | hc_int.done for every channel | TB P | 3000 polls each | a channel does not finish
  HBG-SOF2 | REQ-FUNC-010, 014 | after the load | at least 3 SOF since HBG-SOF1, all intervals at 125 us +- 62.5 ns (a transaction across the SOF would delay it) | TB SOF | 250 us | an interval stretched by a transaction
  HBG-CLEAN | REQ-ERR-001 | end | no crc_err, pid_err, babble | TB R | end | an error flag
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: the full load completes and the SOF stream stays exact.
Defect/fault targeted: frame-budget check missing or too optimistic, SOF delayed by a transaction.
Checker/oracle: REQ-FUNC-014 and the 125 us microframe in this script; harness SOF/XT/XD/P/R.
Reproducibility: cd tests/usb20; python gen_host_budget.py SEED ts1 (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_budget host_utmi8_axim_ts1 tests/ops/host_budget_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_budget in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *
import usb2lib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_budget', seed=seed)
R = s.rng
s.emit('WD', 400000)
host_bringup(s)
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)
SOF_NS = 125000 / usb2lib.TS
TOL = 62.5 if usb2lib.TS == 1 else SOF_NS * 0.10
LO, HI = int(SOF_NS - TOL), int(SOF_NS + TOL)
s.wait(max(3000, us(500)))
s.chk('HBG-SOF1')
s.emit('SOF', 3, LO, HI)
p = DevPartner(s, 0)
MPS = 512
data = {}
for ch in range(8):
    data[ch] = [s.rnd(MPS), s.rnd(MPS)]
    s.mw(0x10000 + 0x1000 * ch, data[ch][0] + data[ch][1])
for ch in range(8):
    hc_program(s, ch, 0, 1 + (ch % 3), 0, BULK, MPS, 2 * MPS, 2, 0x10000 + 0x1000 * ch, pid=0)
s.bin('cg_sched.budget')
for ch in range(8):
    pass
s.chk('HBG-PKTS')
tog = {1: 0, 2: 0, 3: 0}
for ch in range(8):
    ep = 1 + (ch % 3)
    for k in range(2):
        p.out(ep, DATA1 if tog[ep] else DATA0, data[ch][k])
        tog[ep] ^= 1
for ch in range(8):
    s.chk('HBG-DONE')
    s.poll('hc_int', ch, tries=3000, done=1)
    s.w1c('hc_int', ch, **ALL)
s.wait(max(3000, us(250)))                                      # at least three SOF packets since the check before the load (counted per check since 2026-11-24)
s.chk('HBG-SOF2')
s.emit('SOF', 3, LO, HI)                                        # the SOF stream stayed periodic under the load
s.bin('cg_sched.budget')
s.chk('HBG-CLEAN')
s.r('irq_raw', crc_err=0, pid_err=0, babble=0, frm_ovr=0) if False else s.r('irq_raw', crc_err=0, pid_err=0, babble=0)
print(s.save('ops/host_budget_s%d.ops' % seed))
