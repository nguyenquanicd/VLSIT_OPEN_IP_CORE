"""t_host_xreg_race: host twin of t_dev_xreg_race plus the immediate re-arm of an OUT channel (BUG-049).
    python gen_host_xreg_race.py SEED ts16

Test ID and title: t_host_xreg_race - host channel: final xsize/pkt_cnt/pid at done, no stale overwrite, OUT re-arm right after done
Priority and rationale: P1. Found BUG-049 (a re-arm right after done was lost and the channel hung); kills M25.
Purpose: show that when hc_int.done of an IN channel is visible the residue, packet count and next PID are final, that a software
  write right after done is not overwritten by an older hardware update, and that an OUT channel re-armed at once sends its new data.
Requirements and features: REQ-REG-003, CDC-002, REQ-FUNC-015, 016, REQ-IF-006; flow S15 of section 11.2. Features csr_apb, cdc,
  host_sched, axi_master_dma.
DUT configuration and preconditions: build host_utmi8_axim_ts16; host bring-up (hostlib.host_bringup) at high speed; IN rounds on
  channel 0 (32 rounds, four CLK-BUS periods, random scanner phase), OUT rounds on channel 7 (16 rounds).
Software flow:
  1. Per IN round: program channel 0 (bulk IN, 2 packets, short_end); poll hc_int.done at once; read hc_xfer; clear every flag;
     write hc_xfer (xsize 192, pkt_cnt 3) and read it 8 times; compare the received data in memory.
  2. Per OUT round: write 32 bytes to memory, program channel 7 (bulk OUT, 2 packets of 16 bytes); poll done; clear; next round re-arms
     the same channel at once with new data.
Stimulus: device answers DATA0/DATA1 IN packets (64 bytes and a short one of 1 to 63 bytes) and ACKs the OUT data; CLK-BUS period
  changes every round (op CLK).
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HXR-IN | REQ-FUNC-016 | channel 0 IN token, device data | IN token to endpoint 1, ACK of the host after each data packet | TB XT, XH | 30000 CLK-PHY for the token, 2000 for the ACK | no token or no ACK
  HXR-FINAL | REQ-REG-003, flow S15 | first read that sees hc_int.done | hc_xfer xsize = 64 - short, pkt_cnt 0, pid back to the first PID | TB P, R | 4000 polls | a stale residue, count or PID at done
  HXR-NOSTALE | REQ-REG-003 | 8 reads after the software write | xsize 192, pkt_cnt 3 and the pid at every read | TB R | 8 reads | an older hardware update overwrites the software value
  HXR-MEM | REQ-IF-006 | end of the IN round | the 64 + short bytes at 0x1000 + 0x200 * (round mod 4) | TB MC | end of round | memory mismatch
  HXR-REARM | REQ-REG-003, REQ-FUNC-015 (BUG-049) | channel 7 re-armed right after the previous done | OUT tokens to endpoint 2 with DATA0 then DATA1 and the new 16-byte payloads of this round; done | TB XT, XD, P | 30000 CLK-PHY per packet, 4000 polls | the channel sends nothing (hang) or old data
Shared checkpoints also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV (hostlib.py).
Expected outcome: 32 IN rounds with final values at done and correct memory; 16 OUT rounds each sending their own data.
Defect/fault targeted: done overtaking the clear of the command bit so a re-arm is lost (M25, BUG-049); stale update after a software
  write (F-001); residue published after done.
Checker/oracle: values from the CSR description and flow S15; harness XT/XD/XH/P/R/MC; qualified by M25 and the negative-control audit.
Reproducibility: cd tests/usb20; python gen_host_xreg_race.py 1 ts16; from verification:
  python env/scripts/run.py sim t_host_xreg_race host_utmi8_axim_ts16 tests/ops/host_xreg_race_s1.ops +seed=1
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_host_xreg_race in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_xreg_race', seed=seed)
s.emit('WD', 400000)
host_bringup(s)
p = DevPartner(s, 0)
MPS = 64
ALL = dict(done=1, ch_halt=1, timeout=1, nak=1, nyet=1, stall=1, ack=1, xact_err=1, babble=1, tog_err=1, frm_ovr=1, poll_miss=1, iso_inc=1)
pid = 0
for k, per in enumerate([1000, 400, 250, 3000] * 8):
    s.emit('CLK', per)
    s.idle_bus(50)
    short = s.rng.randrange(1, MPS)
    hc_program(s, 0, 0, 1, 1, BULK, MPS, 2 * MPS, 2, 0x1000 + 0x200 * (k % 4), pid=pid, short_end=1)
    d1 = s.rnd(MPS)
    s.chk('HXR-IN')
    p.in_(1, DATA1 if pid else DATA0, d1)
    s.wait(s.rng.randrange(0, 97))
    d2 = s.rnd(short)
    p.in_(1, DATA0 if pid else DATA1, d2)
    s.chk('HXR-FINAL')
    s.emit('P', addr('hc_int', 0), 1, 1, 4000)               # react to done as soon as it is visible
    s.r('hc_xfer', 0, xsize=MPS - short, pkt_cnt=0, pid=pid)  # final values: two packets taken, PID back to the first one
    s.w1c('hc_int', 0, **ALL)
    s.w('hc_xfer', 0, xsize=3 * MPS, pkt_cnt=3, pid=pid)      # software value right after done
    s.chk('HXR-NOSTALE')
    for _ in range(8):
        s.r('hc_xfer', 0, xsize=3 * MPS, pkt_cnt=3, pid=pid)
    s.idle_bus(300)
    s.chk('HXR-MEM')
    s.mc(0x1000 + 0x200 * (k % 4), d1 + d2)                    # the IN data in memory (nc_mem GAP)
# BUG-049: an OUT channel re-armed at once after done must send its new data. Before the fix the command bit ch_en of the bus
# side was still 1 from the previous arming (its clear came back later), so the DMA saw no arming edge and the channel hung.
for k, per in enumerate([1000, 250, 3000, 400] * 4):
    s.emit('CLK', per)
    po = [s.rnd(16), s.rnd(16)]
    a = 0x8000 + 0x100 * (k % 8)
    s.mw(a, po[0] + po[1])
    hc_program(s, 7, 0, 2, 0, BULK, 16, 32, 2, a, pid=0)
    s.chk('HXR-REARM')
    p.out(2, DATA0, po[0])
    p.out(2, DATA1, po[1])
    s.emit('P', addr('hc_int', 7), 1, 1, 4000)               # done visible: re-arm immediately
    s.w1c('hc_int', 7, **ALL)
s.bin('cg_tag.stale_drop')
s.emit('CLK', 1000)
print(s.save('ops/host_xreg_race_s%d.ops' % seed))
