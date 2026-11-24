"""t_fi_bus_errors: errors seen by a device on the bus (fault injection). Also used by t_dev_pipe_equiv and t_dev_ulpi_traffic.

Test ID and title: t_fi_bus_errors - device ignores packets with PID, CRC5, CRC16, bit-stuff errors; handshake time-out and late ACK
Priority and rationale: P1, rank 5 of the R-283 list. Error handling decides data integrity; kills M10 (ACK time-out too short).
Purpose: show that a packet with an error gets no handshake, delivers no data and leaves the toggle unchanged, that the matching error
  flag is set and clears, that retries succeed with each packet stored once, and that the IN handshake time-out follows REQ-FUNC-025.
Requirements and features: REQ-FUNC-002, 003, 004, 025; REQ-ERR-001. USB 2.0 8.3.5 (CRC), 8.4 (PID check), 8.6.4 (duplicate data),
  7.1.19 (bus turn-around time-out 736 to 816 bit times).
DUT configuration and preconditions: build dev_utmi8_axim; device bring-up at a random address; bulk OUT endpoint 1 armed for 4 packets
  at 0x2000; later bulk IN endpoint 2 armed with 4 packets from 0x4000.
Software flow:
  1. Bring-up (devlib), arm OUT endpoint 1.
  2. After each corrupted packet read irq_raw (pid_err, crc_err or stuf_err set), clear it, read it again (0).
  3. After the good retries read epo_int.done and epo_xfr.xsize 0; compare memory.
  4. Arm IN endpoint 2; after the missing ACK read and clear epi_int.timeout; at the end read epi_int.done; clear irq_raw.
Stimulus: OUT PID with a flipped check bit; token with a CRC5 error; DATA0 with a CRC16 error; RXError inside a data packet; SPLIT
  token and a stray ACK; good retries; duplicate DATA1; IN with ACK after 70 cycles (inside), no ACK, ACK after 112 cycles (late),
  a token for another device while the device waits, and a handshake with a bad PID.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FBE-PID | REQ-FUNC-002, REQ-ERR-001 | OUT PID whose check bits are not the complement | no handshake; irq_raw.pid_err set, cleared by W1C | TB XN, R | 150 CLK-PHY | an answer or no flag
  FBE-CRC5 | REQ-FUNC-002, REQ-ERR-001 | OUT token with a CRC5 error | no handshake; irq_raw.crc_err set and cleared | TB XN, R | 150 CLK-PHY | an answer or no flag
  FBE-CRC16 | REQ-FUNC-002, 004 | DATA0 with a CRC16 error | no handshake; crc_err set and cleared; toggle unchanged (checked by FBE-RETRY) | TB XN, R | 150 CLK-PHY | an ACK of corrupted data
  FBE-RXERR | REQ-FUNC-002, REQ-ERR-001 | RXError inside the data packet | no handshake; irq_raw.stuf_err set and cleared | TB XN, R | 150 CLK-PHY | an answer or no flag
  FBE-UNSUP | REQ-FUNC-003 | SPLIT token and a stray ACK sent to a device | no response to either | TB XN | 150 CLK-PHY each | any answer
  FBE-RETRY | REQ-FUNC-004 | retries of the first two packets with DATA0 and DATA1 | ACK each (the corrupted attempts did not advance the toggle) | TB XH, GAP | 400 CLK-PHY each | NAK, no answer or a toggle mismatch
  FBE-DUP | REQ-FUNC-004, USB 2.0 8.6.4 | DATA1 repeated after an ACK | ACK but not stored; the four packets at 0x2000 exactly once; epo_int.done; xsize 0 | TB XH, MC, R | 400 CLK-PHY, end of OUT part | duplicate stored or data lost
  FBE-TMOIN | REQ-FUNC-025 | IN, ACK 70 cycles after the data | accepted: the next IN gets DATA1 | TB XD | 2000 CLK-PHY | the ACK inside the window is ignored
  FBE-TMO | REQ-FUNC-025, REQ-ERR-001 | IN data not acknowledged | epi_int.timeout set and cleared by W1C | TB XD, R | 300 CLK-PHY wait | no time-out flag
  FBE-LATE | REQ-FUNC-025 | ACK 112 cycles after the data; token for another device during the wait | both treated as no ACK: DATA1 repeated each time; no answer to the foreign token; the repeat with a good ACK is accepted | TB XD, XN | 2000 and 150 CLK-PHY | the late ACK accepted or a reply to another address
  FBE-BADHS | REQ-FUNC-002, 025 | handshake with a bad PID after DATA0 | not an ACK: DATA0 repeated; last packets accepted; epi_int.done | TB XD, R | 300 CLK-PHY wait | the bad handshake taken as ACK
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: every corrupted packet ignored with the right flag, the OUT data stored once in order, the IN transfer finished
  with the right toggles after time-outs, no unexpected device packet left.
Defect/fault targeted: ACK time-out shorter than the allowed response time (M10, BUG-006); corrupted data acknowledged; toggle advanced
  on an error; duplicate data stored twice; late handshake accepted.
Checker/oracle: USB 2.0 rules and REQ-FUNC-025 timing in this script; harness XN/XH/XD/GAP/R/MC; qualified by M10 and the
  negative-control audit.
Reproducibility: cd tests/usb20; python gen_fi_bus_errors.py SEED (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_bus_errors dev_utmi8_axim tests/ops/fi_bus_errors_sSEED.ops +seed=SEED
Waveform: rank 5 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_fi_bus_errors
Evidence: runs of t_fi_bus_errors in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_bus_errors', seed=seed)
ADDR = s.rng.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR)
MPS = 64
arm_out(s, 1, MPS * 4, 4, MPS, 0x2000)
good = [s.rnd(MPS) for _ in range(4)]


def flag(name):
    s.r('irq_raw', **{name: 1})
    s.w1c('irq_raw', **{name: 1})
    s.idle_bus(30)
    s.r('irq_raw', **{name: 0})


# 1. PID whose check bits are not the complement: ignored, pid_err
s.chk('FBE-PID')
s.raw([0xE1 ^ 0x10, ADDR | 0x80, 0x00])                     # OUT PID with one check bit flipped
s.data(DATA0, good[0])
s.xn(150)
flag('pid_err')
s.bin('cg_pid.bad_check'); s.bin('cg_err.pid')
# 2. token with a CRC5 error: ignored, crc_err
s.chk('FBE-CRC5')
s.token(OUT, ADDR, 1, crc_flip=0x04)
s.data(DATA0, good[0])
s.xn(150)
flag('crc_err')
s.bin('cg_crc.bad5'); s.bin('cg_err.crc')
# 3. data packet with a CRC16 error: no handshake, nothing delivered, toggle unchanged
s.token(OUT, ADDR, 1)
s.chk('FBE-CRC16')
s.data(DATA0, good[0], crc_flip=0x0100)
s.xn(150)
flag('crc_err')
s.bin('cg_crc.bad16')
# 4. RXError inside the data packet: no handshake, stuf_err
s.token(OUT, ADDR, 1)
s.chk('FBE-RXERR')
p = [0xC3] + good[0] + [0x00, 0x00]
s.raw(p, rxerr_at=20)
s.xn(150)
flag('stuf_err')
s.bin('cg_err.stuff')
if 'ulpi' in sys.argv:
    s.bin('cg_ulpi.rxcmd_in_pkt')                              # over ULPI the RxError reaches the link as an RX CMD inside the packet
# 5. a PID that a device does not support in this direction (SPLIT token, stray handshake): no response
s.chk('FBE-UNSUP')
s.raw([0x78, ADDR, 0x00, 0x00])
s.xn(150)
s.hs(ACK)
s.xn(150)
s.bin('cg_pid.unsupported')
# 6. the retries succeed with the original toggle, each packet delivered once
s.chk('FBE-RETRY')
d.out(1, good[0]); s.idle(60)
d.out(1, good[1]); s.idle(60)
# 7. duplicate data (host missed the ACK and repeats DATA1): acknowledged, not delivered again
s.chk('FBE-DUP')
s.token(OUT, ADDR, 1); s.data(DATA1, good[1]); s.xh(ACK); s.idle(60)
s.bin('cg_toggle.dup_discard')
d.out(1, good[2]); s.idle(60)
d.out(1, good[3]); s.idle(60)
s.idle_bus(3000)
s.mc(0x2000, sum(good, []))
s.r('epo_int', 1, done=1)
s.r('epo_xfr', 1, xsize=0)
# 8. IN: handshake timing (REQ-FUNC-025: time-out between 736 and 816 bit times = 92 to 102 cycles at 60 MHz)
pin = [s.rnd(MPS) for _ in range(4)]
arm_in(s, 2, sum(pin, []), MPS, 0x4000)
s.chk('FBE-TMOIN')
s.token(IN, ADDR, 2); s.xd(DATA0, pin[0]); s.wait(70); s.hs(ACK)        # ACK inside the window: accepted
s.idle(60)
s.bin('cg_tmo.inside')
s.chk('FBE-TMO')
s.token(IN, ADDR, 2); s.xd(DATA1, pin[1])                                # no ACK at all: time-out
s.wait(300)
s.r('epi_int', 2, timeout=1)                                             # the endpoint reports the lost response
s.w1c('epi_int', 2, timeout=1)
s.bin('cg_err.timeout')
s.chk('FBE-LATE')
s.token(IN, ADDR, 2); s.xd(DATA1, pin[1]); s.wait(112); s.hs(ACK)       # ACK after the window: ignored, packet repeated
s.wait(100)
# a token for another device arrives while the device waits for the ACK: no ACK was received, the packet is repeated
s.token(IN, ADDR, 2); s.xd(DATA1, pin[1]); s.wait(12); s.token(OUT, ADDR ^ 0x40, 1); s.data(DATA0, s.rnd(8)); s.xn(150)
s.wait(100)
s.bin('cg_tmo.late_edge')
s.token(IN, ADDR, 2); s.xd(DATA1, pin[1]); s.hs(ACK); s.idle(60)
s.bin('cg_toggle.retry_same')
s.chk('FBE-BADHS')
s.token(IN, ADDR, 2); s.xd(DATA0, pin[2]); s.raw([0xD2 ^ 0x20]); s.wait(300)   # handshake with a bad PID: not an ACK
s.token(IN, ADDR, 2); s.xd(DATA0, pin[2]); s.hs(ACK); s.idle(60)
s.token(IN, ADDR, 2); s.xd(DATA1, pin[3]); s.hs(ACK); s.idle(60)
s.idle_bus(2000)
s.r('epi_int', 2, done=1)
s.wraw('irq_raw', 0, IRQ_ALL)
print(s.save('ops/fi_bus_errors_s%d.ops' % seed))
