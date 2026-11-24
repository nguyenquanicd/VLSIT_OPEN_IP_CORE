"""t_host_enum_bulk_dma: host bring-up, control transfer, bulk OUT and bulk IN through the DMA.
Also used by t_dir_timing_ts1 and t_host_ulpi_ocp (argument ts1, real timer values) through their own headers.

Test ID and title: t_host_enum_bulk_dma - host attach, 50 ms reset with chirp, SOF, GET_DESCRIPTOR, bulk OUT and bulk IN
Priority and rationale: P1, rank 1 of the R-283 list. Every host feature starts with this flow; it hid BUG-047 (5 ms reset) until 2026-11-24.
Purpose: show that the host detects a device, resets it for 50 ms with the high-speed handshake, starts SOF at 125 us, and moves a
  control transfer and bulk data in both directions through the AXI4 master DMA with correct PIDs, toggles and channel status.
Requirements and features: REQ-FUNC-004, 010, 011, 012, 014, 015, 016; REQ-IF-006, 008. Features connect_detect, port_reset, hs_chirp,
  host_sof, host_sched, data_toggle, crc, fifo_mgr, axi_master_dma, interrupt, utmi_if. USB 2.0 clauses 7.1.7.5, 8.4.3, 8.5.
DUT configuration and preconditions: build host_utmi8_axim_ts16 (m_usb2_top_utmi_axim, ROLE host, UTMI+ 8 bit, PARA_USB2_TSCALE 16);
  reset released by the harness; memory all zero; harness plays a high-speed device (scripted answers). Watchdog 60 s (WD).
Software flow:
  1. Read u2_version; set the FIFO regions (fifo_rx, fifo_hnp, fifo_hpt), dma_cfg.burst_len 16, irq_en all; ctrl core_en, dma_en.
  2. hport oc_en, vbus_drv; wait for hsts.port_conn and irq_raw.conn, clear conn; set hport.prst.
  3. Wait for irq_raw.enum; read hsts (port_en, high speed); clear the flags; set hport.sof_en after the recovery time.
  4. Channel 0: write the SETUP bytes to memory 0x1000, program hc_dma/hc_xfer(setup=1)/hc_ctrl; poll hc_int.done, clear.
  5. Channel 0 data IN of 18 bytes to 0x1100 (pid DATA1), then status OUT of zero length (DATA1); poll and clear done each time.
  6. Channel 1 bulk OUT of 148 bytes (3 packets) from 0x2000; poll done.
  7. Channel 2 bulk IN up to 192 bytes to 0x3000 with short_end; poll done, read nak, read the xsize residue; compare memory.
Stimulus: device attach (J), device chirp K, scripted DATA/handshake answers: NAK before the first bulk IN data, a short last IN packet
  of 23 bytes; random payloads from the seed.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  HEB-SOF1 | REQ-FUNC-010 | three microframes after sof_en | at least 3 SOF since the last SOF check, every interval 125 us +- 0.0625 us at TSCALE 1, +-10 percent when scaled (FND-009) | TB SOF | after 500 us (scaled) | fewer SOF or an interval outside the window
  HEB-SETUP | REQ-FUNC-004, 015 | channel 0 enabled with setup=1 | SETUP token to address 0 endpoint 0, DATA0 with the 8 bytes from memory, hc_int.done after the ACK | TB XT, XD, P | 30000 CLK-PHY per packet, 400 polls | wrong token, PID or payload, no done
  HEB-CIN | REQ-FUNC-004, 016, REQ-IF-006 | channel 0 data stage IN, pid DATA1 | IN token, ACK of the host after the DATA1 answer, done, the 18 descriptor bytes in memory at 0x1100 | TB XT, XH, P, MC | 2000 CLK-PHY for the ACK | no ACK, no done or memory mismatch
  HEB-CSTAT | REQ-FUNC-004 | channel 0 status stage | OUT token and a zero-length DATA1 packet, done | TB XT, XD, P | 30000 CLK-PHY | wrong PID or length, no done
  HEB-BOUT | REQ-FUNC-004, 015, REQ-IF-006 | channel 1 bulk OUT of 148 bytes in 3 packets | OUT tokens to endpoint 2 with DATA0, DATA1, DATA0 and the 64, 64, 20 bytes read from 0x2000; done | TB XT, XD, P | 30000 CLK-PHY per packet | toggle, payload or length wrong, no done
  HEB-BIN | REQ-FUNC-015, 016 | channel 2 bulk IN, NAK first, short last packet | the IN is retried after the NAK, ACK after each data packet, done and nak set, 151 bytes at 0x3000, hc_xfer.xsize residue 41 | TB XT, XH, P, R, MC | 2000 CLK-PHY for each ACK | no retry, missing ACK, wrong residue or memory
  HEB-SOF2 | REQ-FUNC-010 | end of the data transfers | at least 3 SOF since HEB-SOF1, intervals inside the window (transfers do not disturb the frame) | TB SOF | after 500 us (scaled) | SOF missing or late
Shared checkpoints of hostlib.py also reached: HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: the port is enabled at high speed after a 50 to 52 ms reset, SOF runs, the four transfers finish with done, the IN
  data is in memory and no unexpected packet of the host is left (the harness fails on a leftover packet).
Defect/fault targeted: short or missing port reset (M26, BUG-047), wrong toggle sequence, NAK not retried, short-packet residue wrong,
  DMA address or length errors, SOF timer drift. Negative controls nc_dead, nc_silent, nc_data, nc_mem caught (sim/oracle_audit.csv).
Checker/oracle: expected packets and memory from this script (USB 2.0 and the CSR description, not from RTL); harness checks
  XT/XD/XH/SOF/TC/MC; qualified by mutant M26 and the negative-control audit.
Reproducibility: cd tests/usb20; python gen_host_enum_bulk_dma.py SEED ts16 (seeds 1 2 3 of testlist.csv); from verification:
  python env/scripts/run.py sim t_host_enum_bulk_dma host_utmi8_axim_ts16 tests/ops/host_enum_bulk_dma_ts16_sSEED.ops +seed=SEED
Waveform: rank 1 of sim/waveform_index.csv (run, path and SHA-256 listed there; testbench top level, whole run); regenerate with
  python env/scripts/priority_waves.py t_host_enum_bulk_dma
Evidence: runs of t_host_enum_bulk_dma in sim/index.csv (sim.log has the CHKPT lines); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from hostlib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('host_enum_bulk_dma', seed=seed)
s.emit('WD', 60000)
DEV = 0
speed = host_bringup(s)
import usb2lib as _u
s.bin('cg_tscale.one' if _u.TS == 1 else 'cg_tscale.scaled')
s.bin('cg_conn.hs_disc') if False else None
s.bin('cg_chirp_h.detect'); s.bin('cg_chirp_h.kj'); s.bin('cg_chirp_h.end'); s.bin('cg_prst.duration'); s.bin('cg_prst.recovery')
import usb2lib
SOF_NS = 125000 / usb2lib.TS                              # microframe, divided by TSCALE in simulation (FND-009)
# at TSCALE > 1 the host also divides its transaction time estimate, so SOF jitter appears (FND-009): +-10 percent there, +-0.0625 us at 1
TOL = 62.5 if usb2lib.TS == 1 else SOF_NS * 0.10
SOF_LO, SOF_HI = int(SOF_NS - TOL), int(SOF_NS + TOL)
s.wait(max(3000, us(500)))                           # at least three microframes pass before the SOF check (TSCALE = 1: 7500 cycles each)
s.chk('HEB-SOF1')
s.emit('SOF', 3, SOF_LO, SOF_HI)                         # SOF interval 125 us +- 0.0625 us at TSCALE = 1 (REQ-FUNC-010)
s.bin('cg_sof.hs')
p = DevPartner(s, DEV)
# ---- control transfer on channel 0: GET_DESCRIPTOR
setup = [0x80, 0x06, 0x00, 0x01, 0x00, 0x00, 0x12, 0x00]
desc = s.rnd(18)
s.mw(0x1000, setup)
hc_program(s, 0, DEV, 0, 0, CTRL, 64, 8, 1, 0x1000, pid=0, setup=1)
s.chk('HEB-SETUP')
p.setup(0, setup)
s.poll('hc_int', 0, done=1)
s.w1c('hc_int', 0, done=1)
s.bin('cg_toggle.setup')
hc_program(s, 0, DEV, 0, 1, CTRL, 64, 18, 1, 0x1100, pid=1)
s.chk('HEB-CIN')
p.in_(0, DATA1, desc)
s.poll('hc_int', 0, done=1)
s.w1c('hc_int', 0, done=1)
s.mc(0x1100, desc)
hc_program(s, 0, DEV, 0, 0, CTRL, 64, 0, 1, 0x1200, pid=1)  # status stage: zero-length OUT, DATA1
s.chk('HEB-CSTAT')
p.out(0, DATA1, [])
s.poll('hc_int', 0, done=1)
s.w1c('hc_int', 0, done=1)
# ---- bulk OUT, three packets on channel 1
po = [s.rnd(64), s.rnd(64), s.rnd(20)]
s.mw(0x2000, sum(po, []))
hc_program(s, 1, DEV, 2, 0, BULK, 64, 148, 3, 0x2000, pid=0)
s.chk('HEB-BOUT')
p.out(2, DATA0, po[0])
p.out(2, DATA1, po[1])
p.out(2, DATA0, po[2])
s.poll('hc_int', 1, done=1)
s.w1c('hc_int', 1, done=1)
s.bin('cg_toggle.d0'); s.bin('cg_toggle.d1'); s.bin('cg_flow.ack')
# ---- bulk IN, 64 + 64 + 23 bytes with a NAK first, short_end
pi = [s.rnd(64), s.rnd(64), s.rnd(23)]
hc_program(s, 2, DEV, 3, 1, BULK, 64, 64 * 3, 3, 0x3000, pid=0, short_end=1)
s.chk('HEB-BIN')
p.in_hs(3, NAK)
p.in_(3, DATA0, pi[0])
p.in_(3, DATA1, pi[1])
p.in_(3, DATA0, pi[2])
s.poll('hc_int', 2, done=1)
s.r('hc_int', 2, nak=1)
s.w1c('hc_int', 2, done=1, nak=1)
s.mc(0x3000, sum(pi, []))
s.r('hc_xfer', 2, xsize=64 * 3 - 151)                    # bytes not received after the short packet
s.bin('cg_short.last')
s.wait(max(3000, us(500)))                           # at least three SOF packets since the previous SOF check (counted per check since 2026-11-24)
s.chk('HEB-SOF2')
s.emit('SOF', 3, SOF_LO, SOF_HI)
s.bin('cg_sched.guard'); s.bin('cg_axim.len16'); s.bin('cg_irq.each_source'); s.bin('cg_utmi.tx_wait'); s.bin('cg_utmi.rx_gap')
# cg_gap_host.min/max are marked by t_host_edge (section gaps), which measures the gaps; this scenario does not (2026-11-24 oracle audit)
print(s.save('ops/host_enum_bulk_dma%s_s%d.ops' % ('_ts16' if 'ts16' in sys.argv else ('_ts1' if 'ts1' in sys.argv else ''), seed)))
