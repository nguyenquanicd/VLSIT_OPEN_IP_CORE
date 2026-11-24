"""t_dev_axis_win: device traffic through the AXI4 slave windows and the external DMA handshake. Also used by t_ulpi_axis.
Window c is the 4 KB block with address bits [15:12] = c; one AXI beat is one 32-bit RAM row; a write window (dma_map.dir_in = 1, see
FND-013) fills the transmit queue of an IN endpoint and its last beat commits the packet; a read window reads the head packet of an
OUT region and releases it after its rows.

Test ID and title: t_dev_axis_win - AXI4 slave write/read windows, o_dma_req/i_dma_ack handshake, write held back on a full region
Priority and rationale: P1, rank 10 of the R-283 list. The only data path of the AXI-slave builds; kills M02, M03, M11.
Purpose: show that window writes become IN packets with the right PID and payload, window reads return the queued OUT packets row by
  row, o_dma_req rises when a packet can move, holds until a burst or acknowledge and falls on i_dma_ack or release, and a write to a
  full region is held (WREADY low) until the host has taken a packet, without loss or duplication.
Requirements and features: REQ-FUNC-027; REQ-IF-007, 009; DEC-010, DEC-011; AMBA AXI4 (A3.4 bursts FIXED/INCR, B/R responses).
  Features axi_slave, fifo_mgr, dev_token_addr, data_toggle, interrupt.
DUT configuration and preconditions: build dev_utmi8_axis (m_usb2_top_utmi_axis); device bring-up at a random address; hsts.win_en;
  dma_map windows 0 and 1 write IN endpoints 1 and 3, windows 2 and 3 read OUT endpoints 2 and 4.
Software flow:
  1. Bring-up; write hsts.win_en and the four dma_map entries.
  2. Per IN transfer: wait for epi_ctl.ep_en = 0, program epi_xfr and epi_ctl (set_d0); the external DMA writes each packet.
  3. Per OUT transfer: wait for epo_ctl.ep_en = 0, program epo_xfr and epo_ctl; the external DMA reads each packet.
  4. Full-region case on endpoint 3 (16-word region), then read irq_raw for error flags.
Stimulus: random packet sizes, FIXED or INCR bursts, random start offset, AXI throttling 0/20/50 percent (BP), i_dma_ack pulses (DA),
  one or two OUT packets queued before a read, a background write burst (AWN) into a full region.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DAW-REQ | REQ-IF-009 | IN endpoint armed with space in its region | o_dma_req of the window rises and stays high 60 bus cycles later | TB DR, DX | 3000 bus cycles | no request or it drops without a burst
  DAW-WR | REQ-IF-007, AXI4 A3.4 | write burst of the packet rows | every beat accepted, BRESP OKAY | TB AW | burst completes | SLVERR/DECERR or a hang
  DAW-ACK | REQ-IF-009, DEC-011 | i_dma_ack pulse after the burst | o_dma_req falls within 4 bus cycles | TB DR | 4 bus cycles | the request stays high
  DAW-INPKT | REQ-FUNC-004, REQ-IF-007 | IN token to the endpoint | DATA0/DATA1 alternating with exactly the written bytes | TB XD | 400 CLK-PHY | wrong PID, payload or length
  DAW-OUT | REQ-FUNC-004 | host OUT to endpoint 2 | ACK, toggles alternating from DATA0 | TB XH | 400 CLK-PHY | no ACK
  DAW-RD | REQ-IF-007, 009 | packet waiting in OUT region 2 | o_dma_req high; the read burst returns the packet rows (bytes past the packet masked), RRESP OKAY, RID and RLAST correct | TB DR, AR | 600 bus cycles | wrong rows, response or ordering
  DAW-REL | REQ-IF-009 | last queued packet read | o_dma_req withdrawn (nothing waits) | TB DR | 80 bus cycles | the request stays high after release
  DAW-FULL | REQ-FUNC-027 | second packet written into the 16-word region holding a packet | no request (no credit); the background write is still held after 400 bus cycles; the first packet goes out as DATA0 | TB DR, AW, AWS, XD | 400 bus cycles | the write is accepted into a full region (overwrite)
  DAW-RESUME | REQ-FUNC-027 | the host took the first packet | the held burst completes; packets 2 and 3 go out as DATA1 and DATA0 with their own bytes | TB AWJ, XD, AW | 20000 bus cycles | loss, duplication or a hang
  DAW-CLEAN | REQ-ERR-001 | end of the test | irq_raw fifo_ovf, fifo_udf, axi_err, dma_err, crc_err, pid_err all 0 | TB R | end | an error flag set
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: every random IN/OUT transfer moves the exact bytes through the windows with the handshake of REQ-IF-009; the full
  region holds the writer without loss; no error flag.
Defect/fault targeted: bus write into a full queue not held back (M02, BUG-031); request not re-raised after acknowledge (M03, BUG-030);
  no limit on outstanding read requests (M11, BUG-033, seed 3); wrong row order; toggle errors.
Checker/oracle: AXI4 rules and the window map of DEC-010/011 in this script; harness AXI master BFM (AW/AR/AWS/AWJ response, ID, LAST
  checks), DR/DX, XD/XH; qualified by M02, M03, M11 and the negative-control audit.
Reproducibility: cd tests/usb20; python gen_dev_axis_win.py SEED (seeds 1 2 3 4 5 6 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dev_axis_win dev_utmi8_axis tests/ops/dev_axis_win_sSEED.ops +seed=SEED
Waveform: rank 10 of sim/waveform_index.csv (testbench top level, whole run); python env/scripts/priority_waves.py t_dev_axis_win
Evidence: runs of t_dev_axis_win in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('dev_axis_win', seed=seed)
R = s.rng
ADDR = R.randrange(1, 128)
d, _ = dev_bringup(s, address=ADDR, ep_regions=((0, 16), (1, 64), (2, 64), (3, 16), (4, 64)))
s.w('hsts', win_en=1)
s.w('dma_map', 0, region=1, dir_in=1, ch_en=1)         # window 0: write rows of the IN endpoint 1
s.w('dma_map', 1, region=3, dir_in=1, ch_en=1)         # window 1: write rows of the IN endpoint 3 (small region)
s.w('dma_map', 2, region=2, dir_in=0, ch_en=1)         # window 2: read the packets of the OUT endpoint 2
s.w('dma_map', 3, region=4, dir_in=0, ch_en=1)         # window 3: read the packets of the OUT endpoint 4
BOTH = (0x00000000, 0x00000000)


def padded(data):
    return list(data) + [R.randrange(256) for _ in range((-len(data)) % 4)]


def words(b):
    return [sum(b[4 * i + j] << (8 * j) for j in range(4)) for i in range(len(b) // 4)]


def masks(n):
    """Compare mask per row: the bytes of the last partial row beyond the packet are not defined."""
    m = [0xFFFFFFFF] * (n // 4)
    if n % 4:
        m.append((1 << (8 * (n % 4))) - 1)
    return m


def addr_in(ch, rows, burst):
    off = 4 * R.randrange(0, 1024 - rows + 1) if burst == 1 else 4 * R.randrange(0, 1024)
    return ch * 0x1000 + off


tog_in = {1: 0, 3: 0}
tog_out = {2: 0, 4: 0}


def arm_in_ep(ep, mps, lens):
    s.poll('epi_ctl', ep, tries=300, ep_en=0)
    s.w('epi_xfr', ep, xsize=sum(lens), pkt_cnt=len(lens))
    s.w('epi_ctl', ep, mps=mps, type=BULK, ep_en=1, set_d0=1)
    tog_in[ep] = 0


def in_packet(ep, ch, data, burst=None, ack_pulse=True):
    rows = (len(data) + 3) // 4
    burst = R.choice([0, 1]) if burst is None else burst
    bp = R.choice([0, 0, 20, 50])
    s.emit('BP', bp)
    if bp:
        s.bin('cg_axis.bp')
    if rows == 16:
        s.bin('cg_axis.len16')
    s.chk('DAW-REQ')
    s.emit('DR', ch, 1, 3000)                              # the channel can move a packet
    s.bin('cg_dmareq.rise')
    s.idle_bus(60)
    s.emit('DX', ch, 1)                                    # the request is held until a burst starts or it is acknowledged (REQ-IF-009)
    s.bin('cg_dmareq.hold')
    s.chk('DAW-WR')
    s.emit('AW', burst, addr_in(ch, rows, burst), rows, 0, *words(padded(data)))
    s.bin('cg_axis.wr_fixed' if burst == 0 else 'cg_axis.wr_incr')
    if ack_pulse and R.random() < 0.5:
        s.chk('DAW-ACK')
        s.emit('DA', ch)
        s.emit('DR', ch, 0, 4)                             # the acknowledge withdraws the request
        s.bin('cg_dmareq.ack')
    s.emit('BP', 0)
    s.idle_bus(300)
    s.chk('DAW-INPKT')
    s.token(IN, ADDR, ep)
    s.xd(DATA0 if tog_in[ep] == 0 else DATA1, data, tmo=400)
    s.wait(8)
    s.hs(ACK)
    tog_in[ep] ^= 1
    s.wait(40)


# ---- random IN transfers through window 0
for it in range(5):
    mps = R.choice([8, 16, 32, 64])
    npk = R.randrange(1, 4)
    lens = [mps] * (npk - 1) + [R.choice([mps, R.randrange(1, mps + 1)])]
    arm_in_ep(1, mps, lens)
    for ln in lens:
        in_packet(1, 0, s.rnd(ln))
        s.bin('cg_axis.len_max' if ln == mps else 'cg_axis.len_odd')

# ---- random OUT transfers through window 2 (one or two packets queued before the read)
for it in range(5):
    mps = R.choice([8, 16, 32, 64])
    npk = R.randrange(1, 4)
    lens = [mps] * (npk - 1) + [R.choice([mps, R.randrange(1, mps + 1)])]
    s.poll('epo_ctl', 2, tries=300, ep_en=0)
    s.w('epo_xfr', 2, xsize=sum(lens), pkt_cnt=len(lens))
    s.w('epo_ctl', 2, mps=mps, type=BULK, ep_en=1, set_d0=1)
    tog_out[2] = 0
    s.idle_bus(300)
    i = 0
    while i < len(lens):
        group = lens[i:i + R.choice([1, 2])]
        packets = []
        for ln in group:
            p = s.rnd(ln)
            s.token(OUT, ADDR, 2)
            s.data(DATA0 if tog_out[2] == 0 else DATA1, p)
            s.chk('DAW-OUT')
            s.xh(ACK, tmo=400)
            tog_out[2] ^= 1
            packets.append(p)
            s.idle_bus(120)
        s.bin('cg_axis.out_queued' if len(group) > 1 else 'cg_axis.out_one')
        for p in packets:
            rows = (len(p) + 3) // 4
            burst = R.choice([0, 1])
            s.emit('BP', R.choice([0, 0, 20, 50]))
            s.chk('DAW-RD')
            s.emit('DR', 2, 1, 600)                        # a packet of this region is waiting
            w, m = words(padded(p)), masks(len(p))
            args = []
            for a, b in zip(w, m):
                args += [a, b]
            s.emit('AR', burst, addr_in(2, rows, burst), rows, 0, *args)
            s.bin('cg_axis.rd_fixed' if burst == 0 else 'cg_axis.rd_incr')
            s.emit('BP', 0)
            if p is packets[-1]:
                s.chk('DAW-REL')
                s.emit('DR', 2, 0, 80)                     # released: nothing waits any more, the request is withdrawn
                s.bin('cg_dmareq.rd_release')
        i += len(group)

# ---- write to a full region: the second packet waits for space (REQ-FUNC-027), nothing is lost or duplicated
s.poll('epi_ctl', 3, tries=300, ep_en=0)
mps = 64
p1, p2, p3 = s.rnd(mps), s.rnd(mps), s.rnd(mps)
s.w('epi_xfr', 3, xsize=3 * mps, pkt_cnt=3)
s.w('epi_ctl', 3, mps=mps, type=BULK, ep_en=1, set_d0=1)
tog_in[3] = 0
s.chk('DAW-FULL')
s.emit('DR', 1, 1, 3000)
s.emit('AW', 1, 0x1000, 16, 0, *words(p1))
s.emit('DR', 1, 0, 20)                                      # the region has no credit left: no request
s.emit('AWN', 1, 0x1000, 16, 0, *words(p2))                  # background write burst of the next packet
s.emit('AWS', 400)                                           # still held back after 400 bus cycles (WREADY low)
s.bin('cg_axis.full_region')
s.idle_bus(200)
s.token(IN, ADDR, 3)
s.xd(DATA0, p1, tmo=400)
s.wait(8)
s.hs(ACK)
tog_in[3] ^= 1
s.chk('DAW-RESUME')
s.emit('AWJ', 20000)                                         # space is back: the held burst completes
s.idle_bus(300)
s.token(IN, ADDR, 3)
s.xd(DATA1, p2, tmo=400)
s.wait(8)
s.hs(ACK)
s.emit('AW', 1, 0x1000, 16, 0, *words(p3))
s.idle_bus(300)
s.token(IN, ADDR, 3)
s.xd(DATA0, p3, tmo=400)
s.wait(8)
s.hs(ACK)
s.wait(60)
s.chk('DAW-CLEAN')
s.r('irq_raw', fifo_ovf=0, fifo_udf=0, axi_err=0, dma_err=0, crc_err=0, pid_err=0)
print(s.save('ops/dev_axis_win_s%d.ops' % seed))
