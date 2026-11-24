"""t_dir_csr_regs: register walk generated from the CSR description (spec/csr/regs_usb2.json).
Registers with side effects on the engines or the PHY are read only (SKIP_WRITE).

Test ID and title: t_dir_csr_regs - reset values, read-write patterns, reserved bits, bank limits, unmapped address
Priority and rationale: P2. Software relies on every reset value and field; a wrong decode is found here first.
Purpose: show that every software field and reserved bit has its documented reset value, every plain read-write field holds
  0x55555555, 0xAAAAAAAA and a random pattern, the entry after the last bank entry does not exist, and an unmapped aligned address reads 0.
Requirements and features: REQ-REG-001; REQ-IF-005; REQ-PARAM-003; section 11.3 register map. Features csr_apb.
DUT configuration and preconditions: build dev_utmi8_axim (ROLE device, NUM_EP 4: endpoint banks of 5 entries, no host channels);
  register map from spec/csr/regs_usb2.json (not from RTL).
Software flow:
  1. Read u2_version.
  2. For every register (first and last bank entry): read the reset value; unless in SKIP_WRITE, write three patterns masked to the
     read-write fields and read each back, then restore the reset value.
  3. For a repeated register whose bank is smaller than its maximum: write all ones to the entry after the last and read 0.
  4. Read the unmapped address 0x7FC.
Stimulus: APB writes and reads only; random third pattern from the seed.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  DCR-VER | section 11.3 u2_version | first read | major 1, minor 0 | TB R | one access | other value
  DCR-RESET | REQ-REG-001 | read of each register after reset | documented reset value of every rw/rwi/w1c field; reserved bits 0 | TB R | one access | a field differs
  DCR-RW | REQ-REG-001, REQ-IF-005 | write of 0x55555555, 0xAAAAAAAA and a random value (read-write fields only) | each read returns the written value in the read-write fields | TB R | one access | a field does not hold the value or another field changes it
  DCR-BANK | REQ-PARAM-003 | write all ones to the entry after the last of a bank | reads 0 | TB R | one access | an entry beyond the configured count exists
  DCR-UNMAP | REQ-IF-005 | read of 0x7FC | 0 | TB R | one access | non-zero data
Shared checkpoints: none (this test does not use the bus-reset library).
Expected outcome: the register map matches the CSR description for this configuration.
Defect/fault targeted: wrong reset value, field width or position, missing write enable, bank decode through a narrowed parameter
  (the REV-NEP1/REV-NHC class, mutants M22/M23 are caught by t_dir_param_max), reserved bits not reading 0.
Checker/oracle: values computed from spec/csr/regs_usb2.json; harness R. The side-effect registers in SKIP_WRITE are only read here.
Reproducibility: cd tests/usb20; python gen_dir_csr_regs.py SEED (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_dir_csr_regs dev_utmi8_axim tests/ops/dir_csr_regs_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_dir_csr_regs in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from usb2lib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
NUM_EP, NUM_HC, NUM_DMA_CH, ROLE = 4, 4, 4, 0          # cfg_dev_utmi8_axim (wrapper defaults for the counts not set)
s = Scn('dir_csr_regs', seed=seed)
SKIP_WRITE = {'ctrl', 'hport', 'phy_acc', 'irq_inj', 'fifo_ctl', 'lpbk_sts', 'dctrl', 'irq_raw', 'hsts'}
COUNT = {'epi': NUM_EP + 1, 'epo': NUM_EP + 1, 'hc_': 0 if ROLE == 0 else NUM_HC, 'dma': None}


def count_of(reg):
    name = reg['name'][3:]
    if not reg.get('repeat'):
        return 1
    if name.startswith(('epi_', 'epo_')):
        return NUM_EP + 1
    if name.startswith('hc_'):
        return NUM_HC if ROLE != 0 else 0
    return None                                           # dma_map: the AXI master wrapper has no DMA channel map check here


def masks(reg):
    rw = rst = rstmask = 0
    for f in reg['fields']:
        hi, lo = bits(f['bits'])
        w = (1 << (hi - lo + 1)) - 1
        if f['type'] == 'rw' and f['name'] != 'reserved':
            rw |= w << lo
        if f['type'] in ('rw', 'rwi', 'w1c') and f['name'] != 'reserved':
            rst |= int(f['reset'], 16) << lo
            rstmask |= w << lo
        if f['name'] == 'reserved':
            rstmask |= w << lo                              # reserved bits read 0
    return rw, rst, rstmask


s.chk('DCR-VER')
s.r('version', major=1, minor=0)
s.bin('cg_reg.reset_each')
for reg in REGS:
    name = reg['name'][3:]
    n = count_of(reg)
    if n is None or n == 0:
        continue
    rw, rst, rstmask = masks(reg)
    base = int(reg['offset'], 16)
    for i in sorted({0, n - 1}):
        a = base + 4 * i
        s.chk('DCR-RESET')
        s.emit('R', a, rst, rstmask)                        # reset value of every software field and of reserved bits
        if name in SKIP_WRITE or rw == 0:
            continue
        s.chk('DCR-RW')
        for pat in (0x55555555, 0xAAAAAAAA, s.rng.getrandbits(32)):
            s.emit('W', a, pat & rw)
            s.emit('IB', 6)
            s.emit('R', a, pat & rw, rw | (rstmask & ~rst & ~rw & 0))   # read-write fields hold the written value
        s.emit('W', a, rst & rw)                             # back to the reset value
        s.emit('IB', 6)
    if reg.get('repeat') and n < int(reg['repeat']['max']):
        s.chk('DCR-BANK')
        a = base + 4 * n                                     # the entry after the last one does not exist
        s.emit('W', a, 0xFFFFFFFF)
        s.emit('R', a, 0, 0xFFFFFFFF)
        s.bin('cg_bank.beyond')
        s.bin('cg_bank.last')
s.chk('DCR-UNMAP')
s.emit('R', 0x7FC, 0, 0xFFFFFFFF)                            # aligned address that is not a register: reads 0
s.bin('cg_reg.access_each')
s.bin('cg_apb.read'); s.bin('cg_apb.write')
print(s.save('ops/dir_csr_regs_s%d.ops' % seed))
