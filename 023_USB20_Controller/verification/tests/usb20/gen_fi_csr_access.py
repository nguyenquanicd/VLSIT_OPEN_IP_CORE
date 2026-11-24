"""t_fi_csr_access: APB error accesses of section 11.4 with i_slverr_en and i_protect_en 0 and 1 (target u2_dma_wbase).

Test ID and title: t_fi_csr_access - APB byte strobes, PSLVERR on partial strobe and unaligned address, PPROT protection
Priority and rationale: P2. The bus error contract is visible to every SoC integrator.
Purpose: show that with i_slverr_en = 0 byte strobes select the bytes written and no error is returned; with i_slverr_en = 1 a partial
  strobe or an unaligned address returns PSLVERR and changes nothing; a non-secure access (PPROT[1]) is refused only when
  i_protect_en = 1 and i_slverr_en = 1; an unmapped aligned address is OKAY and reads 0.
Requirements and features: REQ-IF-005; ERR-009; section 11.4 (APB error rules). AMBA APB4 (PSTRB, PPROT, PSLVERR). Feature csr_apb.
DUT configuration and preconditions: build dev_utmi8_axim; no bring-up (registers only); pins i_slverr_en and i_protect_en driven by
  the harness (PIN).
Software flow:
  1. i_slverr_en 0, i_protect_en 0: full write, partial-strobe writes, a write without strobes, reads of the unmapped address.
  2. i_slverr_en 1: partial strobe write and unaligned write/read (error), then a full write and the unmapped read (OKAY).
  3. Non-secure accesses with i_protect_en 0 (accepted) and 1 (error); secure and privileged secure accesses (accepted).
  4. i_protect_en 1 with i_slverr_en 0: non-secure write returns no error.
Stimulus: APB accesses with chosen PSTRB, PPROT and addresses; pin changes.
Functional checkpoints and assertions (R-286; ID | requirement | trigger | expected | checker | deadline | fails when):
  FCA-STRB | REQ-IF-005, APB4 PSTRB | writes with strobes 1111, 0011, 1000, 0000 and i_slverr_en 0 | no PSLVERR; only the strobed bytes change (FFFFFFFF, FFFF5678, A5FF5678, unchanged) | TB WS, RS | one access each | an unstrobed byte changes or an error is returned
  FCA-UNMAP | REQ-IF-005, section 11.4 | read and write of 0x7FC | OKAY, reads 0 | TB RS, WS | one access | error or non-zero data
  FCA-ERRSTRB | ERR-009, section 11.4 | partial strobe 0111 with i_slverr_en 1 | PSLVERR; the register keeps A5FF5678 | TB WS, RS | one access | no error or the register changes
  FCA-ALIGN | ERR-009 | write to A+1 and read of A+2 with i_slverr_en 1 | PSLVERR on both; register unchanged; a full aligned write still works; unmapped read still OKAY | TB WS, RS | one access each | no error, a change, or a good access refused
  FCA-PROT | ERR-009, APB4 PPROT | PPROT 010 with i_protect_en 0, then 1 | accepted when 0; PSLVERR on write and read when 1 with the value unchanged; secure and privileged secure accesses accepted | TB WS, RS | one access each | protection ignored or applied to secure accesses
  FCA-PROTOFF | section 11.4 | non-secure write with i_protect_en 1 and i_slverr_en 0 | no PSLVERR (the effect of the write on the register is not checked) | TB WS | one access | an error response without i_slverr_en
Shared checkpoints: none.
Expected outcome: the error and protection matrix of section 11.4 holds for every combination of the two pins.
Defect/fault targeted: strobes ignored, errors returned when disabled, refused accesses still writing, protection on secure accesses.
Checker/oracle: section 11.4 and APB4 rules in this script; harness WS/RS (PSLVERR and data); negative-control audit.
Reproducibility: cd tests/usb20; python gen_fi_csr_access.py SEED (seeds 1 of testlist.csv); from verification:
  python env/scripts/run.py sim t_fi_csr_access dev_utmi8_axim tests/ops/fi_csr_access_sSEED.ops +seed=SEED
Waveform: N/A: outside the ten priority tests of R-283 (sim/waveform_index.csv). To capture one: python env/scripts/build.py BUILD --trace,
  then run.py sim with the trace build and +vcd (+vcd_from=NS +vcd_to=NS for a window).
Evidence: runs of t_fi_csr_access in sim/index.csv (CHKPT lines in sim.log); review row in docs/testcase_review.csv.
AI-generated candidate (R-117).
"""
import sys
from usb2lib import *

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
s = Scn('fi_csr_access', seed=seed)
A = addr('dma_wbase')
FULL = 0xF


def wr(a, d, strb, prot, err):
    s.emit('WS', a, d, strb, prot, err)


def rd(a, d, m, prot, err):
    s.emit('RS', a, d, m, prot, err)


# i_slverr_en = 0: no error response; byte strobes still select the bytes written
s.pin('slverr_en', 0); s.pin('protect_en', 0); s.idle_bus(4)
s.chk('FCA-STRB')
wr(A, 0xFFFFFFFF, FULL, 0, 0)
rd(A, 0xFFFFFFFF, 0xFFFFFFFF, 0, 0)
wr(A, 0x12345678, 0b0011, 0, 0)
rd(A, 0xFFFF5678, 0xFFFFFFFF, 0, 0)
wr(A, 0xA5A5A5A5, 0b1000, 0, 0)
rd(A, 0xA5FF5678, 0xFFFFFFFF, 0, 0)
s.bin('cg_apberr.strobe_noerr')
wr(A, 0x00000000, 0b0000, 0, 0)                           # no strobe: nothing written
rd(A, 0xA5FF5678, 0xFFFFFFFF, 0, 0)
s.chk('FCA-UNMAP')
rd(0x7FC, 0, 0xFFFFFFFF, 0, 0)                            # unmapped aligned address: OKAY, reads 0
wr(0x7FC, 0xFFFFFFFF, FULL, 0, 0)
rd(0x7FC, 0, 0xFFFFFFFF, 0, 0)
s.bin('cg_apberr.unmapped')
# i_slverr_en = 1: partial strobe, unaligned address give PSLVERR and change nothing
s.pin('slverr_en', 1); s.idle_bus(4)
s.chk('FCA-ERRSTRB')
wr(A, 0x0BADF00D, 0b0111, 0, 1)
rd(A, 0xA5FF5678, 0xFFFFFFFF, 0, 0)
s.bin('cg_apberr.strobe')
s.chk('FCA-ALIGN')
wr(A + 1, 0x0BADF00D, FULL, 0, 1)
rd(A + 2, 0, 0, 0, 1)
rd(A, 0xA5FF5678, 0xFFFFFFFF, 0, 0)
s.bin('cg_apberr.align')
wr(A, 0x11223344, FULL, 0, 0)                             # a full write still works
rd(A, 0x11223344, 0xFFFFFFFF, 0, 0)
rd(0x7FC, 0, 0xFFFFFFFF, 0, 0)                            # unmapped aligned address: still OKAY
# protection: PPROT[1] = 1 is a non-secure access; error only with i_protect_en = 1 and i_slverr_en = 1
s.chk('FCA-PROT')
wr(A, 0x55667788, FULL, 0b010, 0)                         # i_protect_en = 0: accepted
rd(A, 0x55667788, 0xFFFFFFFF, 0b010, 0)
s.pin('protect_en', 1); s.idle_bus(4)
wr(A, 0x0BADF00D, FULL, 0b010, 1)
rd(A, 0, 0, 0b010, 1)
rd(A, 0x55667788, 0xFFFFFFFF, 0, 0)                       # secure access still works, value unchanged
wr(A, 0x99AABBCC, FULL, 0b001, 0)                         # privileged secure access accepted
rd(A, 0x99AABBCC, 0xFFFFFFFF, 0, 0)
s.bin('cg_apberr.prot')
s.pin('slverr_en', 0); s.idle_bus(4)                      # protection on but error response off: no PSLVERR
s.chk('FCA-PROTOFF')
wr(A, 0x0BADF00D, FULL, 0b010, 0)
s.pin('protect_en', 0)
print(s.save('ops/fi_csr_access_s%d.ops' % seed))
