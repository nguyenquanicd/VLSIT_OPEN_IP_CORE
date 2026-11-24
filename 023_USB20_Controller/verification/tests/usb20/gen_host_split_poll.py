"""t_host_split_poll: split transactions through a hub and a polled interrupt channel.

Test ID and title: t_host_split_poll - bulk OUT start/complete split with NYET, ERR and NAK from the hub; polled interrupt IN
Priority and rationale: P1, rank 7 of the R-283 list. Split handling is the most stateful host path (BUG-042 lived next to it).
Purpose: show the SPLIT token fields (hub, SC, port, S, E, ET), the retry of a complete-split after NYET or ERR, the retry of a
  start-split after NAK, the data toggle across split transfers, and a polled interrupt channel that retries a NAK in the next interval.
Requirements and features: REQ-FUNC-017, 032, 039, 010. USB 2.0 8.4.2.2 (SPLIT token), 11.17-11.18 (split rules). Features split,
  host_sched, host_sof, data_toggle, fifo_mgr.
DUT configuration and preconditions: build host_utmi8_axim_ts16 (SPLIT_EN 1); host bring-up at high speed; hub address 2, port 3,
  full-speed device address 5.
Software flow:
  1. Program hc_spl of channel 0 (hub_addr, port_addr, split_en) and channel 0 for bulk OUT to device 5 (speed full).
  2. Poll hc_int.done (and read nyet); clear; repeat for the ERR and NAK cases.
  3. Disable split on channel 1; program a polled interrupt IN (poll_en, interval 2); poll done; compare memory; read nak.
Stimulus: hub answers: ACK to start-splits, NYET then ACK to complete-splits, ERR then ACK, NAK to a start-split; device answers NAK
  then DATA0 to the polled IN.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HSP-SS | REQ-FUNC-017, USB 2.0 8.4.2.2 | channel 0 enabled with split_en | SPLIT token (hub 2, SC 0, port 3, S 0, E 0, ET bulk), OUT to device 5 endpoint 1, DATA0 with the first 64 bytes | TB XS, XT, XD | 30000 and 3000 CLK-PHY | wrong token fields or data
  HSP-CSNYET | REQ-FUNC-017, 039 | complete-split answered NYET | the complete-split (SC 1) repeated; after ACK the next start-split carries DATA1 and the 30 bytes; done and nyet | TB XS, XT, XD, P, R | 900 polls | no retry, wrong toggle or no done
  HSP-CSERR | REQ-FUNC-039 | complete-split answered ERR | complete-split repeated, then done | TB XS, XT, P | 900 polls | ERR halts the channel or is not retried
  HSP-SSNAK | REQ-FUNC-039 | start-split answered NAK (TT busy) | the start-split with the same DATA0 repeated, then the complete-split, done | TB XS, XT, XD, P | 900 polls | NAK not retried or data changed
  HSP-POLL | REQ-FUNC-032 | polled interrupt IN, first poll NAKed | IN repeated in the next interval, ACK after DATA0; done; 8 bytes at 0x1300; nak set | TB XT, XH, P, MC, R | 900 polls | the poll not repeated or data wrong
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: three split transfers and one polled transfer complete with the specified retries and status.
Defect/fault targeted: wrong SPLIT fields, complete-split not retried, toggle lost across splits, polled channel not re-armed.
Checker/oracle: token layout of USB 2.0 8.4.2.2 and split rules of chapter 11 in this script; harness XS/XT/XD/XH/P/R/MC;
  negative-control audit.
Reproducibility: cd tests/usb20; python gen_host_split_poll.py SEED ts16 (seeds 1 2 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_split_poll host_utmi8_axim_ts16 tests/ops/host_split_poll_sSEED.ops +seed=SEED
Waveform: rank 7 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_host_split_poll
Evidence: runs of t_host_split_poll in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_split_poll', seed=seed)
R = s.rng
s.emit('WD', 60000)
HUB, PORT, FSDEV = 2, 3, 5
host_bringup(s)
MPS = 64
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1)


def hc_split(ch, comp=0):
    s.w('hc_spl', ch, hub_addr=HUB, port_addr=PORT, xact_pos=0, comp_split=comp, split_en=1)


def ss_out(data, pid):
    """Start-split of a bulk OUT: SPLIT token, OUT token, DATA; the hub accepts with ACK."""
    s.xs(HUB, 0, PORT, 0, 0, 2)
    s.xt(OUT, FSDEV, 1, 3000)
    s.xd(pid, data, tmo=3000)
    s.wait(8)
    s.hs(ACK)


def cs_out(answer):
    """Complete-split of a bulk OUT: SPLIT token (SC = 1) and OUT token; the hub answers with the handshake of the device."""
    s.xs(HUB, 1, PORT, 0, 0, 2, TMO)
    s.xt(OUT, FSDEV, 1, 3000)
    s.wait(8)
    s.hs(answer)


# ---- bulk OUT through the hub: start-split, complete-split answered NYET once, then ACK
po = [s.rnd(MPS), s.rnd(30)]
s.mw(0x1000, sum(po, []))
hc_split(0)
hc_program(s, 0, FSDEV, 1, 0, BULK, MPS, MPS + 30, 2, 0x1000, pid=0, speed=1)
s.chk('HSP-SS')
ss_out(po[0], DATA0)
s.chk('HSP-CSNYET')
cs_out(NYET)
cs_out(ACK)
ss_out(po[1], DATA1)
cs_out(ACK)
s.poll('hc_int', 0, tries=900, done=1)
s.r('hc_int', 0, nyet=1)
s.w1c('hc_int', 0, **ALL)
s.bin('cg_split.ss'); s.bin('cg_split.cs'); s.bin('cg_split.nyet'); s.bin('cg_bsplit.cs_retry'); s.bin('cg_toggle.d1')
# ---- bulk OUT: complete-split answered with ERR (hub transaction error handshake): the complete-split is retried
pe = s.rnd(MPS)
s.mw(0x1100, pe)
hc_split(0)
hc_program(s, 0, FSDEV, 1, 0, BULK, MPS, MPS, 1, 0x1100, pid=0, speed=1)
ss_out(pe, DATA0)
s.chk('HSP-CSERR')
cs_out(ERR)
cs_out(ACK)                                                    # REQ-FUNC-039: the complete-split is retried on NYET or error
s.poll('hc_int', 0, tries=900, done=1)
s.w1c('hc_int', 0, **ALL)
s.bin('cg_split.err')
# ---- bulk OUT: start-split NAKed by the hub (TT busy): retried
pn = s.rnd(MPS)
s.mw(0x1200, pn)
hc_split(0)
hc_program(s, 0, FSDEV, 1, 0, BULK, MPS, MPS, 1, 0x1200, pid=0, speed=1)
s.chk('HSP-SSNAK')
s.xs(HUB, 0, PORT, 0, 0, 2); s.xt(OUT, FSDEV, 1, 3000); s.xd(DATA0, pn, tmo=3000); s.wait(8); s.hs(NAK)
ss_out(pn, DATA0)
s.bin('cg_bsplit.ss_retry')
cs_out(ACK)
s.poll('hc_int', 0, tries=900, done=1)
s.w1c('hc_int', 0, **ALL)
# ---- polled interrupt IN channel (high-speed device behind no hub): one transaction per interval, NAK retried in the next interval
s.w('hc_spl', 1, split_en=0)
pi = s.rnd(8)
hc_program(s, 1, 0, 2, 1, INTR, 8, 8, 1, 0x1300, pid=0, poll_en=1, poll_rep=0, interval=2)
p = DevPartner(s, 0)
s.chk('HSP-POLL')
p.in_hs(2, NAK)                                                # the first poll is NAKed
p.in_(2, DATA0, pi)                                            # the next interval gets the data
s.poll('hc_int', 1, tries=900, done=1)
s.mc(0x1300, pi)
s.r('hc_int', 1, nak=1)
s.w1c('hc_int', 1, **ALL)
s.bin('cg_poll.int1'); s.bin('cg_poll.rearm')
print(s.save('ops/host_split_poll_s%d.ops' % seed))
