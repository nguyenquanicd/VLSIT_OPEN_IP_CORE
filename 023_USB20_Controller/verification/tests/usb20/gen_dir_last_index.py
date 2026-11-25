"""t_dir_param_max: the largest legal counts of the parameter table work up to the last index (review F-021, NEP1/NHC repro).
The checks use the effect in CLK-PHY, not the CSR read-back (a write the decode does not forward still reads back on the APB side).
    python gen_dir_last_index.py SEED ep=15 | hc=16 ts16 | win=16 | win=15

Test ID and title: t_dir_param_max - last endpoint (NUM_EP 15), last channel (NUM_HC 16), window 15 (NUM_DMA_CH 16) and window 15 refused (15 channels)
Priority and rationale: P2. Parameter-width slices broke the top index; kills M21, M22, M23.
Purpose: show that the last endpoint and the last host channel move data and that their interrupt enables reach the global flag, and that
  window 15 exists on a 16-channel AXI-slave build and is refused with SLVERR on a 15-channel build.
Requirements and features: REQ-PARAM-003; REQ-REG-001; REQ-IF-007; review F-021. Features csr_apb, axi_slave, host_sched.
DUT configuration and preconditions: builds dev_utmi8_axim_epmax (NUM_EP 15), host_utmi8_axim_hcmax_ts16 (NUM_HC 16), dev_utmi8_axis_ch16
  (NUM_DMA_CH 16), dev_utmi8_axis_ch15 (NUM_DMA_CH 15); device or host bring-up.
Software flow:
  1. (ep) epo_ien/epi_ien of endpoint 15; OUT then IN on endpoint 15; poll done and irq_raw.ep_xfer each time.
  2. (hc) hc_ien of channel 15; IN on channel 15; poll done; compare; poll irq_raw.hc_xfer.
  3. (win) win_en; (16) dma_map 15 to IN 1, arm IN 1, write burst to window 15, IN; (15) write burst to window 15.
Stimulus: OUT/IN data on the last index; AXI bursts to window 15.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DLI-EPOUT | REQ-PARAM-003 | OUT to endpoint 15 (ep) | ACK, epo_int.done, the bytes at 0x2000 | TB XH, P, MC | 400 polls | the last endpoint is not served (M22)
  DLI-EPIRQ | REQ-PARAM-003, REQ-IF-008 | after the OUT done (ep) | irq_raw.ep_xfer (the enable of endpoint 15 reached CLK-PHY) | TB P | 400 polls | no global flag
  DLI-EPIN | REQ-PARAM-003 | IN to endpoint 15 (ep) | DATA0 with the bytes; done; ep_xfer | TB XD, P | 400 polls | wrong data or no flag
  DLI-HCIN | REQ-PARAM-003 | IN on channel 15 (hc) | IN token, ACK after the data; done; memory | TB XT, XH, P, MC | 900 polls | the last channel is not served (M23)
  DLI-HCIRQ | REQ-PARAM-003, REQ-IF-008 | after done (hc) | irq_raw.hc_xfer | TB P | 400 polls | no global flag
  DLI-WIN15 | REQ-IF-007 | write burst to window 15 on a 16-channel build (win=16) | BRESP OKAY; the IN packet carries the written bytes | TB AW, XD | 400 CLK-PHY | window 15 refused (M21)
  DLI-WINBEYOND | REQ-IF-007 | write burst to window 15 on a 15-channel build (win=15) | SLVERR with a complete burst | TB AW | burst completes | the non-existent window accepted
Shared checkpoints also reached: DBU-VER, DBR-CHIRP, DBR-HS, DBU-ENUM, HBU-VER, HBU-CONN, HBU-RSTDRV, HBU-CHIRP, HBU-RST50, HBU-RECOV.
Expected outcome: every last index works on its build and the index after the last is refused.
Defect/fault targeted: window channel compare through PARA[3:0] (M21, REV-F-021); endpoint bank decode through PARA[3:0] (M22, REV-NEP1);
  channel bank decode through PARA[3:0] (M23, REV-NHC).
Checker/oracle: parameter table of the HDS in this script; harness XH/XD/XT/P/MC/AW; qualified by M21, M22, M23.
Reproducibility: cd tests/usb20; python gen_dir_last_index.py 1 ep=15 (dev_utmi8_axim_epmax), 1 hc=16 ts16 (host_utmi8_axim_hcmax_ts16),
  1 win=16 (dev_utmi8_axis_ch16), 1 win=15 (dev_utmi8_axis_ch15); from verification:
  python env/scripts/run.py sim t_dir_param_max dev_utmi8_axim_epmax tests/ops/dir_last_index_ep15_s1.ops +seed=1
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dir_param_max in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from devlib import *
import hostlib

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
arg = dict(a.split('=') for a in sys.argv[2:] if '=' in a)
s = Scn('dir_last_index', seed=seed)
MPS = 64
if 'ep' in arg:
    EP = int(arg['ep'])                                       # last endpoint number = NUM_EP
    ADDR = s.rng.randrange(1, 128)
    regions = [(0, 16)] + [(e, 16) for e in range(1, EP)] + [(EP, 64)]
    d, _ = dev_bringup(s, address=ADDR, rx_size=0x100, ep_regions=regions)
    s.w('epo_ien', EP, done=1)
    s.w('epi_ien', EP, done=1)
    # OUT on the last endpoint
    po = s.rnd(MPS)
    arm_out(s, EP, MPS, 1, MPS, 0x2000, set_d0=1)
    d.tog_out[EP] = 0
    s.chk('DLI-EPOUT')
    d.out(EP, po)
    s.poll('epo_int', EP, tries=400, done=1)
    s.idle_bus(600)
    s.mc(0x2000, po)
    s.chk('DLI-EPIRQ')
    s.poll('irq_raw', tries=400, ep_xfer=1)                   # the interrupt enable of the last endpoint reached CLK-PHY
    s.w1c('irq_raw', ep_xfer=1)
    s.w1c('epo_int', EP, done=1)
    # IN on the last endpoint
    pi = s.rnd(MPS)
    arm_in(s, EP, pi, MPS, 0x3000, set_d0=1)
    d.tog_in[EP] = 0
    s.chk('DLI-EPIN')
    d.in_(EP, pi)
    s.poll('epi_int', EP, tries=400, done=1)
    s.poll('irq_raw', tries=400, ep_xfer=1)
    s.w1c('epi_int', EP, done=1)
    s.bin('cg_param.ep_max')
elif 'win' in arg:
    NCH = int(arg['win'])                                     # PARA_USB2_NUM_DMA_CH of the build
    ADDR = s.rng.randrange(1, 128)
    d, _ = dev_bringup(s, address=ADDR, ep_regions=((0, 16), (1, 64), (2, 64), (3, 16), (4, 64)))
    s.w('hsts', win_en=1)
    data = s.rnd(32)
    wd = [sum(data[4 * i + j] << (8 * j) for j in range(4)) for i in range(8)]
    if NCH == 16:
        s.w('dma_map', 15, region=1, dir_in=1, ch_en=1)       # window 15: write rows of the IN endpoint 1
        s.poll('epi_ctl', 1, tries=300, ep_en=0)
        s.w('epi_xfr', 1, xsize=32, pkt_cnt=1)
        s.w('epi_ctl', 1, mps=64, type=BULK, ep_en=1, set_d0=1)
        s.idle_bus(300)
        s.chk('DLI-WIN15')
        s.emit('AW', 1, 15 * 0x1000, 8, 0, *wd)               # OKAY expected: channel 15 exists
        s.idle_bus(300)
        s.token(IN, ADDR, 1)
        s.xd(DATA0, data, tmo=400)
        s.wait(8)
        s.hs(ACK)
        s.bin('cg_param.win_max')
    else:
        s.chk('DLI-WINBEYOND')
        s.emit('AW', 1, (NCH) * 0x1000, 8, 2, *wd)            # window NCH does not exist: SLVERR
        s.bin('cg_param.win_beyond')
elif 'hc' in arg:
    CH = int(arg['hc']) - 1                                   # last channel
    s.emit('WD', 60000)
    hostlib.host_bringup(s)
    p = hostlib.DevPartner(s, 0)
    s.w('hc_ien', CH, done=1)
    pi = s.rnd(MPS)
    hostlib.hc_program(s, CH, 0, 1, 1, BULK, MPS, MPS, 1, 0x1000, pid=0)
    s.chk('DLI-HCIN')
    p.in_(1, DATA0, pi)
    s.poll('hc_int', CH, tries=900, done=1)
    s.idle_bus(600)
    s.mc(0x1000, pi)
    s.chk('DLI-HCIRQ')
    s.poll('irq_raw', tries=400, hc_xfer=1)                   # the interrupt enable of the last channel reached CLK-PHY
    s.w1c('hc_int', CH, done=1)
    s.bin('cg_param.hc_max')
print(s.save('ops/dir_last_index_%s_s%d.ops' % ('_'.join('%s%s' % kv for kv in sorted(arg.items())), seed)))
