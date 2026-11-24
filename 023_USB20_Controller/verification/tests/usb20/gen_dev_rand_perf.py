"""t_rand_dev_traffic and t_rand_dev16_traffic (argument rand; w16 for the 16-bit UTMI+ build) and t_perf_iso_in (argument perf).
rand: seeded random legal bulk and interrupt traffic. Bounds: receive region 64 to 256 words, endpoint regions 32 to 160 words within the
1024-word RAM (section 11.3), maximum packet size 8, 16, 32, 64, 512 (USB 2.0 chapter 5 per type), 1 to 4 packets with a remainder, AXI
backpressure 0 to 80 percent, gaps 2 to 200 cycles, DMA burst 1 to 16, buffers anywhere in 1 MB incl. offsets next to a 4 KB boundary.
perf: isochronous IN, three 1024-byte packets per microframe (24.576 MB/s), CLK-BUS 100 MHz, real microframe of 125 us (TSCALE 1).
Also used by t_dev_pipe_equiv and t_dev_ulpi_traffic (rand).

Test ID and title: t_rand_dev_traffic, t_rand_dev16_traffic and t_perf_iso_in - constrained-random device traffic; isochronous IN at full rate
Priority and rationale: P2. Random traffic finds ordering and boundary combinations the directed tests do not list; perf shows REQ-PERF-001.
Purpose: (rand) show that 24 random OUT/IN transfers with random sizes, region maps, burst lengths, 4 KB crossings and backpressure all
  move the exact bytes with correct toggles, residues and flags; (perf) show that the DMA refills three 1024-byte iso packets every
  microframe with no underflow, no incomplete transfer and correct data.
Requirements and features: REQ-FUNC-004, 008, 026, 027; REQ-IF-006; REQ-PERF-001; USB 2.0 5.9.2. Features fifo_mgr, axi_master_dma,
  data_toggle, hb_iso, utmi_if (16-bit for t_rand_dev16_traffic).
DUT configuration and preconditions: builds dev_utmi8_axim (rand), dev_utmi16_axim (rand w16), dev_utmi8_axim_ts1 (perf, TSCALE 1);
  device bring-up with the random region map and burst length (rand) or IN region 1 of 800 words without SOF keep-alive (perf).
Software flow:
  1. (rand) per transfer: choose endpoint, type, packet size; arm OUT (epo_dma/xfr/ctl, set_d0) or IN (memory, epi_dma/xfr/ctl);
     after the traffic compare memory (OUT), read done and the OUT residue; at the end read irq_raw for error flags.
  2. (perf) per microframe: poll the previous epi_int.done, clear, arm the next 3072 bytes (epi_dma, epi_xfr, epi_ctl mult 3); at the
     end read irq_raw and epi_int for underflow and incomplete flags.
Stimulus: random from the seed within the bounds above; perf: SOF every 7500 CLK-PHY cycles and three IN tokens per microframe.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DRP-OUT | REQ-FUNC-004 | each random OUT packet (rand) | ACK inside the response gap | TB XH, GAP | 400 CLK-PHY | NAK or no answer to a legal packet
  DRP-OUTMEM | REQ-IF-006, REQ-FUNC-026 | end of a random OUT transfer (rand) | the bytes at the random buffer (incl. 4 KB crossings), epo_int.done, residue = armed - received | TB MC, R | 1500 + 8 x bytes bus cycles | memory, flag or residue wrong
  DRP-IN | REQ-FUNC-004, 008 | each random IN token (rand) | DATA0/DATA1 alternating with the buffer bytes and the right length | TB XD, GAP | 2000 CLK-PHY | wrong PID, data or length
  DRP-INDONE | REQ-FUNC-027 | end of a random IN transfer (rand) | epi_int.done | TB R | 1200 bus cycles | the transfer does not finish
  DRP-CLEAN | REQ-ERR-001 | end of the random part | irq_raw fifo_ovf, axi_err, dma_err, crc_err, pid_err all 0 | TB R | end | an error flag
  DRP-PERFREARM | REQ-PERF-001 | start of each microframe after the first (perf) | the previous transfer is done (the DMA kept up) | TB P | 400 polls | done missing at the next microframe
  DRP-PERFPID | REQ-PERF-001, REQ-FUNC-009 | three IN tokens per microframe (perf) | DATA2, DATA1, DATA0 with the 3 x 1024 bytes of that microframe | TB XD | 2000 CLK-PHY each | a short, late or wrong packet
  DRP-PERFCLEAN | REQ-PERF-001, REQ-FUNC-033 | end of the perf run | no fifo_ovf, fifo_udf, iso_inc, axi_err, dma_err; epi_int iso_inc and unf 0 | TB R | end | underflow or incomplete transfer
Checkpoints per test: t_rand_dev_traffic and t_rand_dev16_traffic reach DRP-OUT, DRP-OUTMEM, DRP-IN, DRP-INDONE, DRP-CLEAN;
  t_perf_iso_in reaches DRP-PERFREARM, DRP-PERFPID, DRP-PERFCLEAN.
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM.
Expected outcome: (rand) all transfers correct for every seed; (perf) 40 (seed 1) or 200 microframes at 24.576 MB/s without error.
Defect/fault targeted: burst split at 4 KB, region wrap, toggle and residue errors under random sizes, 16-bit odd-byte handling, DMA
  throughput below the iso rate.
Checker/oracle: random choices and expected bytes from this script (bounds from the CSR description and USB 2.0); harness XH/XD/GAP/
  MC/R/P; negative-control audit.
Reproducibility: cd tests/usb20; python gen_dev_rand_perf.py SEED rand (seeds 1 to 10; add w16 for t_rand_dev16_traffic, seeds 1 to 5)
  or SEED perf (seeds 1 2); from verification: python env/scripts/run.py sim t_rand_dev_traffic dev_utmi8_axim tests/ops/dev_rand_sSEED.ops
  +seed=SEED (t_rand_dev16_traffic: dev_utmi16_axim, dev_rand_w16_sSEED.ops; t_perf_iso_in: dev_utmi8_axim_ts1, dev_perf_sSEED.ops)
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of the three tests in sim/index.csv (CHKPT lines in sim.log); review rows in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
part = sys.argv[2] if len(sys.argv) > 2 else 'rand'
s = Scn('dev_%s' % part, seed=seed)
R = s.rng
ADDR = R.randrange(1, 128)

if part == 'rand':
    rx = R.choice([64, 128, 256])
    regions = [(0, 16)] + [(ep, R.choice([32, 64, 128]) if ep != 1 else 160) for ep in (1, 2, 3, 4)]
    burst = R.randrange(1, 17)
    d, _ = dev_bringup(s, address=ADDR, rx_size=rx, ep_regions=tuple(regions), burst=burst)
    size_of = dict(regions)
    s.bin('cg_fifo.map_min' if rx == 64 else 'cg_fifo.map_max')
    mem_next = [0x10000]

    def buf(n):
        """A buffer address; one in four ends next to a 4 KB boundary (burst split, REQ-IF-006)."""
        a = mem_next[0]
        if R.randrange(4) == 0:
            a = ((a + 0x1000) & ~0xFFF) - R.choice([4, 8, 36, 60])
        a &= ~(7 if W == 16 else 3)
        mem_next[0] = (a + n + 0x40 + 7) & ~7
        return a

    for it in range(24):
        s.emit('BP', R.choice([0, 0, 10, 30, 50, 80]))
        ep = R.randrange(1, 5)
        typ = R.choice([BULK, BULK, INTR])
        cap = size_of[ep] * 4                               # bytes that fit the IN region of the endpoint
        mps = R.choice([m for m in (8, 16, 32, 64, 512) if (typ == BULK or m <= 64)])
        if R.randrange(2):
            # ---- OUT transfer
            if mps * 4 > rx * 4:
                mps = 64
            npk = R.randrange(1, 5)
            last = R.choice([mps, R.randrange(0, mps)])
            lens = [mps] * (npk - 1) + [last]
            total = sum(lens)
            a = buf(total + 8)
            s.w1c('epo_int', ep, done=1)
            arm_out(s, ep, mps * npk, npk, mps, a, typ=typ, set_d0=1)
            d.tog_out[ep] = 0
            data = []
            for ln in lens:
                p = s.rnd(ln)
                data += p
                s.chk('DRP-OUT')
                d.out(ep, p)
                if W == 16:
                    s.bin('cg_utmi16.even' if ln % 2 == 0 else 'cg_utmi16.odd')
                s.idle(R.randrange(2, 200))
            s.idle_bus(1500 + total * 8)
            s.chk('DRP-OUTMEM')
            if total:
                s.mc(a, data)
            s.r('epo_int', ep, done=1)
            s.r('epo_xfr', ep, xsize=mps * npk - total)
            s.bin('cg_axim.cross4k' if (a & 0xFFF) + total > 0x1000 else 'cg_axim.len1')
        else:
            # ---- IN transfer
            if mps > cap:
                mps = 64
            npk = R.randrange(1, min(4, cap // mps) + 1)
            last = R.choice([mps, R.randrange(1, mps + 1)])
            lens = [mps] * (npk - 1) + [last]
            total = sum(lens)
            data = s.rnd(total)
            a = buf(total + 8)
            s.w1c('epi_int', ep, done=1)
            arm_in(s, ep, data, mps, a, typ=typ, pkts=npk, set_d0=1, wait=1500 + total * 10)
            d.tog_in[ep] = 0
            pos = 0
            for ln in lens:
                s.chk('DRP-IN')
                d.in_(ep, data[pos:pos + ln])
                pos += ln
                s.idle(R.randrange(2, 200))
            s.idle_bus(1200)
            s.chk('DRP-INDONE')
            s.r('epi_int', ep, done=1)
            s.bin('cg_len.max' if last == mps else 'cg_len.one')
    s.emit('BP', 0)
    s.chk('DRP-CLEAN')
    s.r('irq_raw', fifo_ovf=0, axi_err=0, dma_err=0, crc_err=0, pid_err=0)
else:
    import usb2lib
    usb2lib.TS = 1                                          # build with PARA_USB2_TSCALE = 1: real timers
    NUF = 40 if seed == 1 else 200
    MPS = 1024
    UF = 7500                                               # CLK-PHY cycles of a 125 us microframe at 60 MHz
    s.emit('WD', 60000)
    d, _ = dev_bringup(s, address=ADDR, rx_size=0x40, ep_regions=((0, 16), (1, 800), (2, 32)), sof=False)
    s.emit('CLK', 1000)                                     # CLK-BUS 100 MHz
    fn = 0
    s.token(SOF, 0, 0)
    for uf in range(NUF):
        data = s.rnd(3 * MPS)
        a = 0x20000 + (uf % 8) * 0x1000
        s.mw(a, data)
        if uf:
            s.chk('DRP-PERFREARM')
            s.poll('epi_int', 1, done=1)                    # the driver waits for the end of the previous transfer
            s.w1c('epi_int', 1, done=1)
        s.w('epi_dma', 1, addr=a)                           # software arms the next microframe
        s.w('epi_xfr', 1, xsize=3 * MPS, pkt_cnt=3)
        s.w('epi_ctl', 1, mps=MPS, type=ISO, ep_en=1, mult=3)
        s.wait(UF - 3 * (MPS + 40) - 520)                   # rest of the microframe: the DMA loads 3072 bytes meanwhile
        fn += 1
        s.token(SOF, (fn >> 3) & 0x7F, (fn >> 10) & 0xF)
        s.chk('DRP-PERFPID')
        for i, pid in enumerate((DATA2, DATA1, DATA0)):
            s.token(IN, ADDR, 1)
            s.xd(pid, data[i * MPS:(i + 1) * MPS])
            s.wait(12)
    s.idle_bus(500)
    s.chk('DRP-PERFCLEAN')
    s.r('irq_raw', fifo_ovf=0, fifo_udf=0, iso_inc=0, axi_err=0, dma_err=0)
    s.r('epi_int', 1, iso_inc=0, unf=0)
    s.msg('performance: %d microframes of 3 x %d bytes = %.3f MB/s at CLK-BUS 100 MHz' % (NUF, MPS, 3 * MPS / 125e-6 / 1e6))
    s.bin('cg_perf.rate_met')
print(s.save('ops/dev_%s%s_s%d.ops' % (part, '_w16' if W == 16 else '', seed)))
