"""Rename registers and fields that break the name rules of the generated CSR (NAM-07, NAM-TBL)."""
import glob
import re
import sys

REG = [  # longest first
    ('u2_epi_int_en', 'u2_epi_ien'), ('u2_epo_int_en', 'u2_epo_ien'), ('u2_hc_int_en', 'u2_hc_ien'),
    ('u2_epi_ctrl', 'u2_epi_ctl'), ('u2_epo_ctrl', 'u2_epo_ctl'), ('u2_epi_xfer', 'u2_epi_xfr'),
    ('u2_epo_xfer', 'u2_epo_xfr'), ('u2_epi_fifo', 'u2_epi_buf'), ('u2_hc_split', 'u2_hc_spl'),
    ('u2_dmach_map', 'u2_dma_map'),
]
FLD = [('soft_rst', 'soft_reset'), ('port_rst', 'port_reset'), ('phy_clk_ok', 'phy_clock_ok'),
       ('rst_busy', 'reset_busy')]
# register names without the prefix (generator sources, rtl_gen lists, testbench comments)
BARE = [('epi_int_en', 'epi_ien'), ('epo_int_en', 'epo_ien'), ('hc_int_en', 'hc_ien'), ('epi_ctrl', 'epi_ctl'),
        ('epo_ctrl', 'epo_ctl'), ('epi_xfer', 'epi_xfr'), ('epo_xfer', 'epo_xfr'), ('epi_fifo', 'epi_buf'),
        ('hc_split', 'hc_spl'), ('dmach_map', 'dma_map')]

files = [f for pat in ('../spec/../spec/VLSIT_USB20_CONTROLLER_HDS.md', '../csr/gen_csr.py', '../csr/regs_usb2.json',
                       '../figures/*.json', '../figures/*.svg', '../figures/*.drawio', '../figures/src/*.py',
                       '../verification/env/tb/*.sv', 'gen_regs.py', 'core_body.py', 'core_body2.py', 'gen_core.py')
         for f in glob.glob(pat)]
for f in files:
    t = open(f, encoding='utf-8').read()
    o = t
    for a, b in REG:
        t = re.sub(r'\b' + a + r'\b', b, t)
    for a, b in FLD:
        t = re.sub(r'\b' + a + r'\b', b, t)
    if f.endswith(('gen_csr.py', 'gen_regs.py', 'core_body.py', 'core_body2.py', 'gen_core.py')) or '/figures/src/' in f.replace('\\', '/'):
        for a, b in BARE:
            t = re.sub(r"(?<![\w])" + a + r"(?![\w])", b, t)
    if t != o:
        open(f, 'w', encoding='utf-8', newline='').write(t)
        print('renamed in', f)
