"""t_dev_enum_bulk_dma: device enumeration, SET_ADDRESS, bulk OUT/IN, PING/NYET flow control through the DMA.
Also used by t_dir_timing_ts1 (ts1), t_dev_pipe_equiv and t_dev_ulpi_traffic (ulpi) through their own headers.

Test ID and title: t_dev_enum_bulk_dma - device bus reset with chirp, SET_ADDRESS, bulk OUT/IN, PING and NYET under DMA backpressure
Priority and rationale: P1, rank 2 of the R-283 list. The base device flow; kills mutants M01, M06 and M12.
Purpose: show that the device selects high speed, answers only its own address, takes a new address, moves bulk data through the
  AXI4 master DMA with correct toggles, repeats unacknowledged IN data, and applies NYET, NAK and PING when the receive FIFO is full.
Requirements and features: REQ-FUNC-001, 003, 004, 005, 006, 007, 013, 024, 027; REQ-IF-001, 005, 006, 008; REQ-CLK-001. Features hs_chirp,
  dev_token_addr, crc, data_toggle, ping_nyet, fifo_mgr, axi_master_dma, interrupt, csr_apb, utmi_if, cdc. USB 2.0 8.4, 8.5.1, 8.6.
DUT configuration and preconditions: build dev_utmi8_axim (ROLE device, UTMI+ 8 bit, TSCALE 256, NUM_EP 4); harness plays the host;
  memory zero; FIFO: receive region 64 words, IN regions 16 and 64 words.
Software flow:
  1. Read u2_version and u2_build; program fifo_rx, epi_buf 0/1, dma_cfg, the endpoint DMA addresses, irq_en; ctrl core_en, dma_en.
  2. dctrl soft_conn at address 0; after the bus reset poll irq_raw busrst and enum, read sts.speed; clear irq_raw.
  3. Receive SET_ADDRESS (setup data delivered to memory 0x1000, epo_int.setup); arm a zero-length status IN; apply the address.
  4. Arm bulk OUT endpoint 1 for 3 packets at 0x2000; after the data read epo_int.done, epo_xfr.xsize, epo_dma.addr.
  5. Arm bulk IN endpoint 1 with 151 bytes at 0x4000; read epi_int.done.
  6. Clear done; arm OUT endpoint 1 for 8 packets at 0x2400 while the AXI is held not ready; release it with backpressure; compare.
Stimulus: tokens to another address and to the non-existent endpoint 9, SETUP/OUT/IN/PING from the host model, one IN without ACK,
  AXI never ready (BP 100) then ready 30 percent (BP 30); random address and payloads from the seed.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DEB-ID | section 11.3 (u2_version, u2_build) | first APB reads | major 1; build fields role device, UTMI+ (or ULPI with argument ulpi), 8 bit, AXI master | TB R | one access each | a field differs
  DEB-ENUM | REQ-FUNC-013, REQ-IF-008 | end of the bus reset | irq_raw busrst and enum, sts.speed high speed, o_int_usb high while enabled flags are set and low after they are cleared | TB P, R, XP | 400 polls | flag, speed or interrupt pin wrong
  DEB-ADDR | REQ-FUNC-001 | SETUP to address 0x55 | no answer | TB XN | 150 CLK-PHY | the device answers another address
  DEB-SETUP | REQ-FUNC-004, REQ-IF-006 | SETUP DATA0 to address 0 | ACK inside the response gap, the 8 bytes at 0x1000, epo_int.setup | TB XH, GAP, MC, R | 400 CLK-PHY for the ACK | no ACK, gap outside 1 to 24 cycles, memory or flag wrong
  DEB-STATUS | REQ-FUNC-004 | IN to endpoint 0 after arming a zero-length transfer | zero-length DATA1 | TB XD, GAP | 2000 CLK-PHY | wrong PID or length
  DEB-NEWADDR | REQ-FUNC-001, 003 | after the new address is applied | IN to the old address 0 and OUT to endpoint 9 get no answer | TB XN | 150 CLK-PHY each | an answer
  DEB-BOUT | REQ-FUNC-004, 005, REQ-IF-006 | bulk OUT endpoint 1 armed for 192 bytes | PING ACK, ACK for each packet, 192 bytes at 0x2000, done, xsize 0, epo_dma.addr advanced by 192 | TB XH, MC, R | 400 CLK-PHY per handshake | missing ACK, memory, residue or address wrong
  DEB-BIN | REQ-FUNC-004, 006 | bulk IN endpoint 1 armed with 151 bytes | DATA0, DATA1, the same DATA1 again after the missing ACK, DATA0 short packet; done; NAK when nothing is armed | TB XD, R, XH | 2000 CLK-PHY per packet | toggle advances without ACK, data wrong, no NAK
  DEB-NYET | REQ-FUNC-005, 027 | receive FIFO fills while the AXI is not ready | ACK for 3 packets, NYET for the 4th, PING NAK, OUT NAK | TB XH, GAP | 400 CLK-PHY each | an ACK into a full FIFO or no NYET
  DEB-DRAIN | REQ-FUNC-005, REQ-IF-006 | DMA released with backpressure | PING ACK, the refused packet accepted on retry, all 6 packets (384 bytes) at 0x2400 in order, epo_dma.addr advanced by 384 | TB XH, MC, R | 400 CLK-PHY per handshake | data lost, duplicated or out of order
Shared checkpoints also reached: DBR-CHIRP, DBR-HS (usb2lib.py).
Expected outcome: device at high speed with the random address, every transfer complete with the right memory contents and flags,
  no unexpected device packet left.
Defect/fault targeted: CRC5 bit order (M01), TermSelect during chirp (M06), chirp before the mode pins settle (M12), toggle advance
  without ACK, ACK into a full FIFO, DMA address advance errors. Negative controls caught (sim/oracle_audit.csv).
Checker/oracle: host model and expected memory in this script (usb2lib DevModel: address and toggles from USB 2.0); harness checks
  XH/XD/XN/GAP/MC/R/XP; qualified by M01, M06, M12 and the negative-control audit.
Reproducibility: cd tests/usb20; python gen_dev_enum_bulk_dma.py SEED (seeds 1 2 3); from verification:
  python env/scripts/run.py sim t_dev_enum_bulk_dma dev_utmi8_axim tests/ops/dev_enum_bulk_dma_sSEED.ops +seed=SEED
Waveform: rank 2 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_dev_enum_bulk_dma
Evidence: runs of t_dev_enum_bulk_dma in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from usb2lib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_enum_bulk_dma', seed=seed)
ADDR = s.rng.randrange(1, 128)
# S02..S10: identify, divide the FIFO, program the DMA, enable
s.chk('DEB-ID')
s.r('version', major=1)
s.bin('cg_tscale.one' if TS == 1 else 'cg_tscale.scaled')
s.r('build', role_cfg=0, phy_ulpi=1 if 'ulpi' in sys.argv else 0, utmi_16=0, axi_slave=0)
s.w('fifo_rx', start=0, size=0x40)                    # 64 words: four 64-byte packets
s.w('epi_buf', 0, start=0x40, size=16)
s.w('epi_buf', 1, start=0x50, size=64)
s.w('dma_cfg', burst_len=16)
s.w('epo_dma', 0, addr=0x1000)
s.w('epo_dma', 1, addr=0x2000)
s.w('epi_dma', 0, addr=0x3000)
s.w('epi_dma', 1, addr=0x4000)
s.wraw('irq_en', 0, 0x003FFFFF)
s.w('ctrl', core_en=1, dma_en=1, ahb_err_stop=1)
s.w('dctrl', dev_addr=0, soft_conn=1)                 # S12: connect at address 0
s.idle_bus(400)
speed = dev_bus_reset(s)                              # S12: bus reset, chirp, high-speed
s.chk('DEB-ENUM')
s.poll('irq_raw', busrst=1, enum=1)
s.r('sts', speed=0)                                   # 0 = high-speed
s.emit('SG', 1, 300)                                  # host keep-alive: SOF while the bus is free
s.xp(1, 1, 1)                                         # o_int_usb high: enabled status set (REQ-IF-008)
s.bin('cg_chirp_d.hs'); s.bin('cg_speed.hs'); s.bin('cg_irq.each_source')
s.wraw('irq_raw', 0, 0x003FFFFF)                      # clear every flag raised so far
s.idle_bus(40)
s.xp(1, 0, 1)
d = DevModel(s, address=0)
# a token for another address gets no answer (REQ-FUNC-001)
s.chk('DEB-ADDR')
s.token(SETUP, 0x55, 0); s.data(DATA0, s.rnd(8)); s.xn(150)
s.bin('cg_tok_addr.other')
# control transfer SET_ADDRESS at address 0: SETUP, status IN (zero length, DATA1), then the new address
setup = [0x00, 0x05, ADDR, 0x00, 0x00, 0x00, 0x00, 0x00]
s.chk('DEB-SETUP')
d.setup(0, setup)
s.idle_bus(600)
s.mc(0x1000, setup)                                   # setup data delivered through the DMA
s.r('epo_int', 0, setup=1)
s.bin('cg_toggle.setup'); s.bin('cg_tok_addr.own'); s.bin('cg_ep.ep0'); s.bin('cg_crc.good5'); s.bin('cg_crc.good16')
s.w('epi_xfr', 0, xsize=0, pkt_cnt=1)                 # status stage: zero-length IN
s.w('epi_ctl', 0, mps=64, type=CTRL, ep_en=1)
s.idle_bus(600)
s.chk('DEB-STATUS')
d.in_(0, [])                                          # DATA1 after SETUP (REQ-FUNC-004)
s.idle_bus(300)
s.w('dctrl', dev_addr=ADDR, soft_conn=1)              # S13: software applies the address
s.idle_bus(400)
d.addr = ADDR
s.chk('DEB-NEWADDR')
s.token(IN, 0, 0); s.xn(150)                          # the old address is no longer answered
s.token(OUT, ADDR, 9); s.data(DATA0, s.rnd(8)); s.xn(150)   # endpoint 9 does not exist in this build (NUM_EP = 4)
s.bin('cg_tok_addr.uninit_ep')
# bulk OUT on endpoint 1 through the DMA
s.w('epo_xfr', 1, xsize=64 * 3, pkt_cnt=3)
s.w('epo_ctl', 1, mps=64, type=BULK, ep_en=1)
s.idle_bus(400)
po = [s.rnd(64) for _ in range(3)]
s.chk('DEB-BOUT')
d.ping(1, ACK)
for p in po:
    d.out(1, p)
    s.idle(60)
s.idle_bus(2000)
s.mc(0x2000, po[0] + po[1] + po[2])
s.r('epo_int', 1, done=1)
s.r('epo_xfr', 1, xsize=0)
s.r('epo_dma', 1, addr=0x2000 + 192)                  # hardware advances the address as data moves
for b in ('cg_toggle.d0', 'cg_toggle.d1', 'cg_flow.ack', 'cg_flow.ping_ack', 'cg_gap_dev.min', 'cg_axim.len16'):
    s.bin(b)
# bulk IN on endpoint 1: two full packets and a short one
pin = s.rnd(64 * 2 + 23)
s.mw(0x4000, pin)
s.w('epi_xfr', 1, xsize=len(pin), pkt_cnt=3)
s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1)
s.idle_bus(3000)
s.chk('DEB-BIN')
d.in_(1, pin[0:64])
s.idle(40)
d.in_(1, pin[64:128], ack=False)                      # host does not acknowledge: the device repeats the packet
s.idle(us(400))
d.in_(1, pin[64:128])
s.idle(40)
d.in_(1, pin[128:])
s.idle_bus(2000)
s.r('epi_int', 1, done=1)
d.in_(1, expect=NAK)                                  # nothing armed any more
s.bin('cg_toggle.retry_same'); s.bin('cg_fifo.empty_nak')
# PING and NYET flow control with the DMA stalled: the receive region holds four 64-byte packets (REQ-FUNC-005, 027)
s.w1c('epo_int', 1, done=1)
s.emit('BP', 100)                                     # AXI never ready: nothing drains
s.w('epo_dma', 1, addr=0x2400)
s.w('epo_xfr', 1, xsize=64 * 8, pkt_cnt=8)
s.w('epo_ctl', 1, mps=64, type=BULK, ep_en=1)
s.idle_bus(400)
pf = [s.rnd(64) for _ in range(6)]
s.chk('DEB-NYET')
d.out(1, pf[0]); s.idle(60)
d.out(1, pf[1]); s.idle(60)
d.out(1, pf[2]); s.idle(60)
d.out(1, pf[3], expect=NYET); s.idle(60)              # accepted, but no room for another maximum packet
d.ping(1, NAK)
d.out(1, pf[4], expect=NAK); s.idle(60)               # not accepted: toggle unchanged
for b in ('cg_flow.nyet', 'cg_flow.nak', 'cg_flow.ping_nak', 'cg_fifo.full_nak'):
    s.bin(b)
s.emit('BP', 30)                                      # DMA runs again with backpressure
s.idle_bus(6000)
s.chk('DEB-DRAIN')
d.ping(1, ACK)
d.out(1, pf[4]); s.idle(60)
d.out(1, pf[5]); s.idle(60)
s.idle_bus(6000)
s.mc(0x2400, sum(pf, []))
s.r('epo_dma', 1, addr=0x2400 + 64 * 6)
for b in ('cg_axim.bp', 'cg_utmi.tx_wait', 'cg_utmi.rx_gap', 'cg_apb.read', 'cg_apb.write', 'cg_ratio.fast_bus'):
    s.bin(b)
print(s.save('ops/dev_enum_bulk_dma%s%s_s%d.ops' % ('_ts1' if 'ts1' in sys.argv else '', '_ulpi' if 'ulpi' in sys.argv else '', seed)))
