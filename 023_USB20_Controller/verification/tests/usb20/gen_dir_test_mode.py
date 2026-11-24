"""t_dir_test_mode: test selectors of REQ-FUNC-022 on the device port and the mode pins of section 6.3.

Test ID and title: t_dir_test_mode - Test_SE0_NAK, Test_J, Test_K, Test_Packet and a reserved selector on the device
Priority and rationale: P3. Compliance (electrical test) modes; rarely used in a product but mandatory for certification.
Purpose: show that Test_SE0_NAK answers IN tokens with NAK and ignores a corrupted token, Test_J/Test_K transmit continuously in the
  high-speed row with OpMode 10b, Test_Packet repeats the 53-byte pattern of USB 2.0 7.1.20 as DATA0, and a reserved selector leaves
  the device in normal operation.
Requirements and features: REQ-FUNC-022; REQ-IF-012; USB 2.0 7.1.20, 9.4.9 (test selectors). Features test_mode, utmi_if.
DUT configuration and preconditions: build dev_utmi8_axim; before each selector a hardware reset (RST) and a fresh device bring-up.
Software flow:
  1. Per selector: reset, bring-up, write dctrl.test_mode (3 SE0_NAK, 1 J, 2 K, 4 Packet, 5 reserved).
  2. Reserved selector: arm OUT 1 and compare memory.
Stimulus: IN tokens to endpoints 0 to 2 and one with a CRC error; host silent during J/K/Packet; one OUT packet.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DTM-MODE | REQ-FUNC-022, REQ-IF-012 | Test_SE0_NAK selected | high-speed row (HS transceiver, no FS termination, OpMode 00b) | TB XP | after 400 bus cycles | wrong row
  DTM-SE0NAK | REQ-FUNC-022 | IN tokens to endpoints 0, 1, 2; IN with a CRC5 error | NAK to each valid IN; no answer to the corrupted token | TB XH, XN | 400 and 100 CLK-PHY | other handshake or an answer to the bad token
  DTM-JK | REQ-FUNC-022, REQ-IF-012 | Test_J or Test_K selected | TXValid within 3 ms (scaled), OpMode 10b in the high-speed row, still transmitting 4000 cycles later (the byte values FF/00 of the stream are not checked) | TB WP, XP | 3 ms scaled | no stream or wrong row
  DTM-PKT | REQ-FUNC-022, USB 2.0 7.1.20 | Test_Packet selected | three DATA0 packets with exactly the 53 pattern bytes | TB XD | 3 ms scaled + 400 CLK-PHY each | wrong pattern or not repeated
  DTM-RSVD | REQ-FUNC-022 | reserved selector 5 | normal operation: the OUT packet is acknowledged and stored | TB XH, MC | 400 CLK-PHY | the device stops working
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM (once per selector).
Expected outcome: each selector behaves as listed; a reserved value does not enter a test mode.
Defect/fault targeted: selector decode errors, Test_Packet pattern wrong, test mode with the wrong PHY row.
Checker/oracle: USB 2.0 7.1.20 pattern (bytes before bit stuffing) and the section 6.3 mode table in this script; harness XP/WP/XH/XN/XD/MC.
  Known gap: the J/K stream content is not compared.
Reproducibility: cd tests/usb20; python gen_dir_test_mode.py SEED (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dir_test_mode dev_utmi8_axim tests/ops/dir_test_mode_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dir_test_mode in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dir_test_mode', seed=seed)
ADDR = s.rng.randrange(1, 128)
# test packet payload of USB 2.0 section 7.1.20 (JKJKJKJK x9, JJKKJJKK x8, JJJJKKKK x8, JJJJJJJKKKKKKK x8, JJJJJJJK x8,
# {JKKKKKKK x10}, JK): data bytes before bit stuffing
TEST_PACKET = [0x00] * 9 + [0xAA] * 8 + [0xEE] * 8 + [0xFE] + [0xFF] * 11 + [0x7F, 0xBF, 0xDF, 0xEF, 0xF7, 0xFB, 0xFD] + \
              [0xFC, 0x7E, 0xBF, 0xDF, 0xEF, 0xF7, 0xFB, 0xFD, 0x7E]
assert len(TEST_PACKET) == 53


def fresh(sel):
    """Reset, bring-up, then select the test mode (a test mode is left only by reset)."""
    s.emit('SG', 0, 300)
    s.linestate(1)
    s.emit('RST', 8)
    s.emit('FLUSH')
    d, _ = dev_bringup(s, address=ADDR)
    s.token(SOF, 0x21, 0x1)
    s.w('dctrl', dev_addr=ADDR, soft_conn=1, test_mode=sel)
    return d


# Test_SE0_NAK: IN tokens are answered with NAK, other tokens are not answered
d = fresh(3)
s.idle_bus(400)
s.chk('DTM-MODE')
s.xp(0, mode(0, 0, 0), MODE_MASK)
s.chk('DTM-SE0NAK')
for ep in (0, 1, 2):
    s.token(IN, ADDR, ep); s.xh(NAK); s.wait(20)
s.token(IN, ADDR, 0, crc_flip=1); s.xn(100)                # token with a CRC error: no answer
s.bin('cg_test.se0nak')
# Test_J and Test_K: a continuous stream of J (FF) or K (00) bytes with bit stuffing off
for sel, value, name in ((1, 0xFF, 'cg_test.j'), (2, 0x00, 'cg_test.k')):
    d = fresh(sel)
    s.emit('SG', 0, 300)
    s.chk('DTM-JK')
    s.wp(3, 1, 1, us(3000))                                # TXValid within 3 ms of the selection
    s.xp(0, mode(0, 0, 2), MODE_MASK)                      # high-speed, OpMode 10b (no bit stuffing, no NRZI)
    s.wait(4000)
    s.xp(3, 1, 1)                                          # still transmitting
    s.bin(name)
# Test_Packet: the pattern as a DATA0 packet, repeated
d = fresh(4)
s.emit('SG', 0, 300)
s.chk('DTM-PKT')
for _ in range(3):
    s.xd(DATA0, TEST_PACKET, tmo=us(3000) + 400)
s.bin('cg_test.packet')
# reserved selector values: normal operation continues
d = fresh(5)
s.emit('SG', 1, 300)
s.idle_bus(600)
arm_out(s, 1, 64, 1, 64, 0x2000, set_d0=1)
p = s.rnd(64)
d.tog_out[1] = 0
s.chk('DTM-RSVD')
d.out(1, p)
s.idle_bus(2000)
s.mc(0x2000, p)
s.bin('cg_test.invalid')
s.emit('FLUSH')
print(s.save('ops/dir_test_mode_s%d.ops' % seed))
