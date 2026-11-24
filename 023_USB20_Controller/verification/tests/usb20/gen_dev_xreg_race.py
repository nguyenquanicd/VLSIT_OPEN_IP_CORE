"""t_dev_xreg_race: register crossing ordering when software reacts to the done flag of an OUT endpoint at once.
    python gen_dev_xreg_race.py SEED [periods...]   (CLK-BUS periods in units of 10 ps, default 1000 400 250 3000)

Test ID and title: t_dev_xreg_race - device OUT endpoint: final xsize at done, immediate re-arm, no stale overwrite, no ep_en/active gap
Priority and rationale: P1, rank 3 of the R-283 list. Review 2026-11-22 F-001 and BUG-044 (events overtaking the published word) live here.
Purpose: show that (1) when epo_int.done is visible the remaining xsize of the finished transfer is final, (2) a value written right
  after done is never overwritten by an older hardware update still in the crossing (REQ-REG-003), and (3) a re-armed endpoint never
  reads ep_en = 0 and active = 0 at the same time until its new transfer ends.
Requirements and features: REQ-REG-003, CDC-002, REQ-FUNC-004, REQ-IF-006; flow S10 of section 11.2. Features csr_apb, cdc, fifo_mgr,
  axi_master_dma.
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up (devlib.dev_bringup) at a random address; 32 rounds, each
  with one of four CLK-BUS periods (10, 4, 2.5, 30 ns) and a random wait (0 to 96 CLK-PHY) before the short packet.
Software flow (per round):
  1. Wait for epo_ctl.active = 0; program epo_dma, epo_xfr (2 packets, 128 bytes), epo_ctl (bulk, ep_en, short_end).
  2. After the host data: poll epo_int.done with a single read loop (reaction at once), read epo_xfr.xsize, clear done.
  3. Re-arm at once (epo_xfr 3 packets, epo_ctl ep_en); read epo_ctl 40 times back to back, then epo_xfr 5 times and epo_ctl.active.
  4. After the short packet of the re-armed transfer: poll done, read the xsize residue, clear done; compare the first transfer in memory.
Stimulus: host OUT DATA0 of 64 bytes and a short DATA1 of 1 to 63 bytes, then a 5-byte packet for the re-armed transfer; CLK-BUS
  period changed by op CLK every round to move the APB reaction against the crossing scan.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DXR-IDLE | REQ-REG-003, flow S10 | start of a round | epo_ctl.active reads 0 (the previous transfer is retired) | TB P | 400 polls | active stays 1
  DXR-OUT | REQ-FUNC-004 | two host OUT packets | ACK for both inside the response gap | TB XH, GAP | 400 CLK-PHY each | no ACK or gap outside 1 to 24 cycles
  DXR-FINAL | REQ-REG-003, flow S10 | first read that sees epo_int.done | epo_xfr.xsize = 128 - 64 - short already at that read | TB P, R | 4000 polls | the residue is stale when done is visible
  DXR-HANDOVER | REQ-REG-003, CDC-002 | 40 reads right after the re-arm | every read has ep_en = 1 or active = 1 | TB RANY | each read | a read with both bits 0 (BUG-044 class)
  DXR-NOSTALE | REQ-REG-003 | reads after the software write of xsize 192, pkt_cnt 3 | the software value at every read and after 400 bus cycles; active = 1 | TB R | 5 reads | an older hardware update overwrites the new value
  DXR-REARM | REQ-FUNC-004, flow S10 | 5-byte packet to the re-armed endpoint | ACK, done, xsize residue 187 | TB XH, P, R | 400 polls | the re-armed transfer does not run or finishes wrong
  DXR-MEM | REQ-IF-006 | end of the round | the 64 + short bytes of the first transfer at 0x2000 + 0x200 * (round mod 4) | TB MC | at the end of the round | memory mismatch
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM (devlib.py, usb2lib.py).
Expected outcome: 32 rounds complete with final residues at done, no stale overwrite, no gap between ep_en and active, memory correct.
Defect/fault targeted: events and clears overtaking the published word changed by the same step (M24, BUG-044); a stale hardware update
  applied after a software write (REQ-REG-003 tag/ordering, open decision F-001); a lost re-arm.
Checker/oracle: values from the CSR description and flow S10 (not from RTL); harness R/RANY/P/MC; qualified by M24 and the
  negative-control audit (nc_mem caught after MC was added on 2026-11-24).
Reproducibility: cd tests/usb20; python gen_dev_xreg_race.py SEED (seeds 1 2); from verification:
  python env/scripts/run.py sim t_dev_xreg_race dev_utmi8_axim tests/ops/dev_xreg_race_sSEED.ops +seed=SEED
Waveform: rank 3 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_dev_xreg_race
Evidence: runs of t_dev_xreg_race in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
PER = ([int(a) for a in sys.argv[2:] if a.isdigit()] or [1000, 400, 250, 3000]) * 8      # 32 rounds
s = Scn('dev_xreg_race', seed=seed)
ADDR = s.rng.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR)
MPS = 64
for k, per in enumerate(PER):
    s.emit('CLK', per)
    s.idle_bus(50)
    short = s.rng.randrange(1, MPS)
    s.chk('DXR-IDLE')
    s.poll('epo_ctl', 1, tries=400, active=0)
    s.w('epo_dma', 1, addr=0x2000 + 0x200 * (k % 4))
    s.w('epo_xfr', 1, xsize=2 * MPS, pkt_cnt=2)
    s.w('epo_ctl', 1, mps=MPS, type=BULK, ep_en=1, short_end=1, set_d0=1 if k == 0 else 0)
    if k == 0:
        d.tog_out[1] = 0
    s.idle_bus(300)
    p1 = s.rnd(MPS)
    s.chk('DXR-OUT')
    d.out(1, p1)
    s.wait(s.rng.randrange(0, 97))                            # random phase of the update scanner at the end of the transfer
    p2 = s.rnd(short)
    d.out(1, p2)                                              # short packet ends the transfer
    s.chk('DXR-FINAL')
    s.emit('P', addr('epo_int', 1), 1, 1, 4000)               # react to done as soon as it is visible
    s.r('epo_xfr', 1, xsize=2 * MPS - MPS - short)            # (1) remaining length already final at done
    s.w1c('epo_int', 1, done=1)
    s.w('epo_xfr', 1, xsize=3 * MPS, pkt_cnt=3)               # (2) immediate re-arm
    s.w('epo_ctl', 1, mps=MPS, type=BULK, ep_en=1, short_end=1)
    ARMED = val('epo_ctl', ep_en=1)[0] | val('epo_ctl', active=1)[0]
    s.chk('DXR-HANDOVER')
    for _ in range(40):                                       # back-to-back reads across the hand-over from the command bit
        s.emit('RANY', addr('epo_ctl', 1), ARMED)             # (ep_en, written by software) to the status bit (active, published)
    s.chk('DXR-NOSTALE')
    for _ in range(4):
        s.r('epo_xfr', 1, xsize=3 * MPS, pkt_cnt=3)
    s.idle_bus(400)
    s.r('epo_xfr', 1, xsize=3 * MPS, pkt_cnt=3)
    s.r('epo_ctl', 1, active=1)
    s.chk('DXR-REARM')
    d.out(1, s.rnd(5))                                        # finish the re-armed transfer with a short packet
    s.poll('epo_int', 1, tries=400, done=1)
    s.r('epo_xfr', 1, xsize=3 * MPS - 5)
    s.w1c('epo_int', 1, done=1)
    s.idle_bus(300)
    s.chk('DXR-MEM')
    s.mc(0x2000 + 0x200 * (k % 4), p1 + p2)                    # the first transfer in memory (nc_mem GAP)
s.emit('CLK', 1000)
s.bin('cg_tag.stale_drop')
s.bin('cg_tag.fresh_apply')
print(s.save('ops/dev_xreg_race_s%d.ops' % seed))
