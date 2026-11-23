#!/usr/bin/env python3
"""Generate rtl/m_usb2_regs.sv: CSR instance, register crossing and hardware-load decode.

Reads csr/regs_usb2.json (register model) and rtl/csr/m_vlsit_csr_usb2.sv (ports of the generated CSR)
and writes the module m_usb2_regs (DEC-001, DEC-002). Every CSR port is connected by name.
Run from the rtl_gen folder: python gen_regs.py
"""
import json
import re
import sys

ROOT = '..'
REGS = json.load(open(ROOT + '/csr/regs_usb2.json'))['registers']
CSR_SRC = open(ROOT + '/rtl/csr/m_vlsit_csr_usb2.sv').read()
COUNT_PARAM = {"dma_map": "PARA_USB2_NUM_DMA_CH", 'epi': 'PARA_USB2_NEP1', 'epo': 'PARA_USB2_NEP1', 'hc': 'PARA_USB2_NHC', 'dmach': 'PARA_USB2_NUM_DMA_CH'}


class Fld:
    def __init__(self, reg, d):
        self.reg = reg
        self.name = d['name']
        m = re.match(r'\[(\d+)(?::(\d+))?\]', d['bits'])
        self.msb = int(m.group(1))
        self.lsb = int(m.group(2)) if m.group(2) else self.msb
        self.w = self.msb - self.lsb + 1
        self.type = d['type']
        self.reset = int(d['reset'], 0) if d.get('reset') else 0


class Reg:
    def __init__(self, d):
        self.name = d['name'][3:]
        self.offset = int(d['offset'], 0)
        self.rep = d.get('repeat')
        self.banked = bool(self.rep)
        self.cp = None
        if self.banked:
            for k, v in COUNT_PARAM.items():
                if self.name.startswith(k + '_') or self.name == k:
                    self.cp = v
        self.fields = [Fld(self, f) for f in d['fields'] if f['name'] != 'reserved']
        self.reset_word = 0
        for f in self.fields:
            if f.type in ('rw', 'rwi'):
                self.reset_word |= (f.reset & ((1 << f.w) - 1)) << f.lsb


R = {r.name: r for r in (Reg(d) for d in REGS)}
SCAN_ACTIVE = ['sts', 'dsts', 'hsts', 'irq_raw', 'dctrl', 'hport', 'phy_acc', 'fifo_ctl', 'lpbk_sts',
               'epi_ctl', 'epi_xfr', 'epi_int', 'epo_ctl', 'epo_xfr', 'epo_int', 'hc_ctrl', 'hc_xfer',
               'hc_int', 'hc_cfg']
CFG_ONLY = ['ctrl', 'sof_cfg', 'fifo_rx', 'fifo_hnp', 'fifo_hpt', 'lpm_cfg', 'epi_buf', 'epi_ien',
            'epo_ien', 'hc_spl', 'hc_ien']
SLOTS = SCAN_ACTIVE + CFG_ONLY
CFG = ['dctrl', 'hport', 'phy_acc', 'fifo_ctl', 'lpbk_sts', 'epi_ctl', 'epi_xfr', 'epo_ctl', 'epo_xfr',
       'hc_ctrl', 'hc_xfer', 'hc_cfg', 'ctrl', 'sof_cfg', 'fifo_rx', 'fifo_hnp', 'fifo_hpt', 'lpm_cfg',
       'epi_buf', 'epi_ien', 'epo_ien', 'hc_spl', 'hc_ien']
PUB = ['sts', 'dsts', 'hsts', 'phy_acc', 'lpbk_sts', 'epi_ctl', 'epi_xfr', 'epo_ctl', 'epo_xfr', 'hc_xfer',
       'hc_cfg']
SET = ['irq_raw', 'epi_int', 'epo_int', 'hc_int']
CLR = ['dctrl', 'hport', 'phy_acc', 'fifo_ctl', 'lpbk_sts', 'epi_ctl', 'epo_ctl', 'hc_ctrl']
BUS_WORDS = ['ctrl', 'dctrl', 'hport', 'hsts', 'dma_cfg', 'dma_hi', 'dma_wbase', 'dma_wlim', 'fifo_hnp', 'fifo_hpt', 'fifo_ctl', 'epi_ctl', 'epi_xfr',
             'epi_dma', 'epi_buf', 'epo_dma', 'hc_ctrl', 'hc_xfer', 'hc_dma', 'dma_map']
BUS_RO = {('sts', 'xq_free'), ('sts', 'phyclk_ok'), ('sts', 'rstbusy'), ('hsts', 'oc_act')}
SPECIAL = ('version', 'build', 'irq_sts', 'ep_sum_i', 'ep_sum_o', 'hc_sum')


def kind(f):
    r = f.reg.name
    if f.type == 'rwi':
        if f.name == 'addr':
            return 'addr'
        if f.name in ('xsize', 'pkt_cnt', 'pid'):
            return 'data'
        if (r, f.name) == ('ctrl', 'swrst'):
            return 'soft'
        return 'cmd'
    if f.type == 'ro':
        if r in SPECIAL:
            return 'special'
        if (r, f.name) in BUS_RO:
            return 'busro'
        return 'pub'
    return f.type


def cexpr(r):
    return r.cp if r.banked else "32'd1"


def base(r):
    return 'LPARA_B_' + r.name.upper()


def rng_ports(w, r):
    s = ''
    if r.banked:
        s += f'[{r.cp}-1:0]'
    if w > 1:
        s += f'[{w-1}:0]'
    return s


L = []


def e(s=''):
    L.append(s)


# ------------------------------------------------------------------ header and parameters
e('''/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : CSR integration of the USB 2.0 controller (section 11, DEC-001, DEC-002). Generated
 *                by rtl_gen/gen_regs.py from the register model; do not edit by hand. It holds the
 *                generated CSR m_vlsit_csr_usb2, the register crossing m_usb2_xreg and the interrupt
 *                block m_usb2_irq. Software writes reach CLK-PHY as command words, the engines of
 *                CLK-PHY return published words, event sets and command clears, and this module
 *                loads them into the hardware ports of the CSR. The words of the register ports
 *                have the natural bit positions of the CSR.
 */
`timescale 1ns/1ps
''')
e('module m_usb2_regs #(')
for nm, desc, vals, unit, dflt in [
    ('PARA_USB2_NEP1', 'device endpoint entries per direction (EP0 and the others)', '1 to 16; default is 9', 'count', 9),
    ('PARA_USB2_NHC', 'number of host channels', '1 to 16; default is 8', 'count', 8),
    ('PARA_USB2_NUM_DMA_CH', 'number of external DMA handshake channels', '1 to 16; default is 4', 'count', 4),
    ('PARA_USB2_ROLE_CFG', 'role of the build: 0 device, 1 host, 2 dual-role', '0, 1 or 2; default is 2', 'none', 2),
    ('PARA_USB2_PHY_ULPI', 'PHY interface of the build: 0 UTMI+, 1 ULPI', '0 or 1; default is 0', 'none', 0),
    ('PARA_USB2_UTMI_16', 'UTMI+ data width is 16 bit', '0 or 1; default is 0', 'none', 0),
    ('PARA_USB2_AXI_SLAVE', 'data interface of the build: 0 AXI master, 1 AXI slave', '0 or 1; default is 0', 'none', 0),
    ('PARA_USB2_LPM_CFG', 'LPM support in the build', '0 or 1; default is 0', 'none', 0),
    ('PARA_USB2_SPLIT_CFG', 'host split support in the build', '0 or 1; default is 0', 'none', 0),
    ('PARA_USB2_FIFO_LOG2', 'log2 of the FIFO depth in 32-bit words', '8 to 15; default is 10', 'none', 10),
    ('PARA_USB2_SG_CFG', 'scatter-gather support in the build', '0 or 1; default is 0', 'none', 0),
    ('PARA_USB2_DBUF_CFG', 'double buffer support in the build', '0 or 1; default is 1', 'none', 1),
    ('PARA_USB2_PAR_CFG', 'FIFO RAM parity in the build', '0 or 1; default is 1', 'none', 1),
    ('PARA_USB2_PIPE_XREG', 'register stage on the shadow words', '0 or 1; default is 0', 'none', 0)]:
    e(f'  // Parameter Description: {desc}.')
    e(f'  // Parameter values: {vals}.')
    e(f'  // Parameter unit: {unit}')
    e(f'  parameter logic [31:0] {nm} = {dflt},')
na = ' + '.join(cexpr(R[n]) for n in SCAN_ACTIVE)
ns = ' + '.join(cexpr(R[n]) for n in SLOTS)
e(f'  localparam logic [31:0] LPARA_NA = {na},')
e(f'  localparam logic [31:0] LPARA_NS = {ns},')
prev = None
for n in SLOTS:
    r = R[n]
    ex = "32'd0" if prev is None else f'{base(prev)} + {cexpr(prev)}'
    e(f'  localparam logic [31:0] {base(r)} = {ex},')
    prev = r
e("  localparam logic [31:0] LPARA_SLOT_W   = 8,")
e("  localparam logic [31:0] LPARA_IRQ_N    = 25,")
e("  localparam logic [31:0] LPARA_KIND_SET = 1,")
e("  localparam logic [31:0] LPARA_KIND_CLR = 2,")
e("  localparam logic [31:0] LPARA_KIND_PUB = 3")
e(') (')

PORTS = []


def P(d, rng, nm):
    PORTS.append((d, rng, nm))


def S(t):
    PORTS.append(('sect', t, None))


S('Clocks and resets')
for n in ('i_clk_bus', 'i_rst_n_bus', 'i_clk_phy', 'i_rst_n_phy'):
    P('input', '', n)
S('APB4 slave')
for n, w in (('psel', 1), ('penable', 1), ('pwrite', 1), ('paddr', 16), ('pwdata', 32), ('pstrb', 4), ('pprot', 3)):
    P('input', f'[{w-1}:0]' if w > 1 else '', f'i_apb_{n}')
P('output', '', 'o_apb_pready')
P('output', '', 'o_apb_pslverr')
P('output', '[31:0]', 'o_apb_prdata')
P('input', '', 'i_protect_en')
P('input', '', 'i_slverr_en')
S('Interrupt, status and events of CLK-BUS')
P('output', '', 'o_int_usb')
P('input', '', 'i_phy_alive')
P('input', '', 'i_soft_busy')
P('input', '', 'i_oc_act')
P('input', '', 'i_evt_ocur')
P('input', '', 'i_evt_axi_err')
P('input', '', 'i_evt_dma_err')
P('output', '', 'o_role_host')
P('output', '', 'o_ocur_flag')
P('output', '', 'o_soft_req')
P('output', '', 'o_phy_hold')
P('input', '', 'i_soft_clr')
S('Buffer address updates of the DMA (CLK-BUS)')
P('input', '[31:0]', 'i_ld_addr')
P('input', '[PARA_USB2_NEP1-1:0]', 'i_ld_epi_we')
P('input', '[PARA_USB2_NEP1-1:0]', 'i_ld_epo_we')
P('input', '[PARA_USB2_NHC-1:0]', 'i_ld_hc_we')
S('Register words for the blocks of CLK-BUS (natural bit positions)')
for nm in BUS_WORDS:
    r = R[nm]
    P('output', (f'[{r.cp}-1:0]' if r.banked else '') + '[31:0]', f'o_bus_{nm}')
S('Shadow words of CLK-PHY (natural bit positions)')
for nm in CFG:
    r = R[nm]
    P('output', (f'[{r.cp}-1:0]' if r.banked else '') + '[31:0]', f'o_ph_{nm}')
S('Published words, event sets and command clears of the engines (CLK-PHY)')
for pref, lst in (('pub', PUB), ('set', SET), ('clr', CLR)):
    for nm in lst:
        r = R[nm]
        P('input', (f'[{r.cp}-1:0]' if r.banked else '') + '[31:0]', f'i_ph_{pref}_{nm}')
first = True
lines = []
for d, rng, nm in PORTS:
    if d == 'sect':
        if not first:
            lines.append('')
        lines.append(f'  // {rng}')
        first = False
    else:
        lines.append(f'  {d} {"wire" if d == "input" else "logic"} {rng} {nm},'.replace('  ' + d + ' ' + ('wire' if d == 'input' else 'logic') + '  ', '  ' + d + ' ' + ('wire' if d == 'input' else 'logic') + ' '))
lines[-1] = lines[-1].rstrip(',')
L.extend(lines)
e(');')
e()

# ------------------------------------------------------------------ declarations
e('  // Internal signal declarations')
D = []
for ln in ['w_cfg_all', 'w_shadow', 'w_shadow_init']:
    D.append(f'  logic [LPARA_NS*32-1:0] {ln};')
for ln in ['w_pub_all', 'w_set_all', 'w_clr_all']:
    D.append(f'  logic [LPARA_NA*32-1:0] {ln};')
D += ['  logic                    w_reg_wr_en;', '  logic [15:0]             w_reg_wr_addr;',
      '  logic                    w_reg_rd_en;', '  logic [15:0]             w_reg_rd_addr;',
      '  logic                    reg_wr_vld;', '  logic [LPARA_SLOT_W-1:0] reg_wr_slot;',
      '  logic                    w_dec_vld;', '  logic [LPARA_SLOT_W-1:0] w_dec_slot;',
      '  logic [31:0]             w_wr_word;', '  logic [5:0]              w_xq_free;',
      '  logic                    w_xq_ovf;', '  logic                    w_ld_en;',
      '  logic [3:0]              w_ld_kind;', '  logic [LPARA_SLOT_W-1:0] w_ld_slot;',
      '  logic [31:0]             w_ld_val;', '  logic                    reg_ld_en;',
      '  logic [3:0]              reg_ld_kind;', '  logic [LPARA_SLOT_W-1:0] reg_ld_slot;',
      '  logic [31:0]             reg_ld_val;', '  logic                    w_k_set;',
      '  logic                    w_k_clr;', '  logic                    w_k_pub;',
      '  logic [LPARA_IRQ_N-1:0]  w_irq_evt;', '  logic [LPARA_IRQ_N-1:0]  w_irq_set_ph;',
      '  logic [LPARA_IRQ_N-1:0]  w_irq_evt_bus;', '  logic [LPARA_IRQ_N-1:0]  w_irq_raw;',
      '  logic [LPARA_IRQ_N-1:0]  w_irq_en;', '  logic [LPARA_IRQ_N-1:0]  w_irq_inj;',
      '  logic [LPARA_IRQ_N-1:0]  w_irq_set;', '  logic [LPARA_IRQ_N-1:0]  w_irq_sts;',
      '  logic [31:0]             w_epsum_i;', '  logic [31:0]             w_epsum_o;',
      '  logic [31:0]             w_hcsum;']
for n in SLOTS:
    r = R[n]
    b = f'[{r.cp}-1:0]' if r.banked else ''
    D.append(f'  logic {b + " " if b else ""}w_hit_{n};')
for n in SET:
    r = R[n]
    b = f'[{r.cp}-1:0]' if r.banked else ''
    D.append(f'  logic {b + " " if b else ""}w_sethit_{n};')
for n in CLR:
    r = R[n]
    b = f'[{r.cp}-1:0]' if r.banked else ''
    D.append(f'  logic {b + " " if b else ""}w_clrhit_{n};')
for n in PUB:
    r = R[n]
    b = f'[{r.cp}-1:0]' if r.banked else ''
    D.append(f'  logic {b + " " if b else ""}w_pubhit_{n};')
for r in R.values():
    b = f'[{r.cp}-1:0]' if r.banked else ''
    D.append(f'  logic {b}[31:0] w_cfg_{r.name};')
for n in ('epi_int', 'epo_int', 'hc_int'):
    r = R[n]
    D.append(f'  logic [{r.cp}-1:0][31:0] w_flg_{n};')
for r in R.values():
    for f in r.fields:
        rg = rng_ports(f.w, r)
        if f.type in ('rw', 'rwi', 'w1c'):
            D.append(f'  logic {rg + " " if rg else ""}w_o_{r.name}_{f.name};')
        if f.type == 'ro':
            D.append(f'  logic {rg + " " if rg else ""}w_i_{r.name}_{f.name};')
        if f.type in ('rwi', 'w1c'):
            b1 = f'[{r.cp}-1:0]' if r.banked else ''
            D.append(f'  logic {b1 + " " if b1 else ""}w_hwe_{r.name}_{f.name};')
            D.append(f'  logic {rg + " " if rg else ""}w_hwd_{r.name}_{f.name};')
        if kind(f) == 'pub':
            D.append(f'  logic {rg + " " if rg else ""}reg_pub_{r.name}_{f.name};')
L.extend(D)
e()

# ------------------------------------------------------------------ natural words
e('  // Natural words of every register: the output fields of the CSR at their bit positions.')


def word_expr(r, fields, idx=None):
    parts = []
    pos = 31
    for f in sorted(fields, key=lambda x: -x.msb):
        if f.msb < pos:
            parts.append(f"{pos - f.msb}'d0")
        parts.append(f'w_o_{r.name}_{f.name}' + (f'[{idx}]' if idx else ''))
        pos = f.lsb - 1
    if pos >= 0:
        parts.append(f"{pos + 1}'d0")
    return '{' + ', '.join(parts) + '}'


for r in R.values():
    outs = [f for f in r.fields if f.type in ('rw', 'rwi')]
    flg = [f for f in r.fields if f.type == 'w1c']
    if r.banked:
        e('  generate')
        e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_word_{r.name}')
        e(f"      assign w_cfg_{r.name}[gen_i] = {word_expr(r, outs, 'gen_i') if outs else chr(39) + '0'};")
        if r.name in ('epi_int', 'epo_int', 'hc_int'):
            e(f"      assign w_flg_{r.name}[gen_i] = {word_expr(r, flg, 'gen_i')};")
        e('    end')
        e('  endgenerate')
    else:
        e(f"  assign w_cfg_{r.name} = {word_expr(r, outs) if outs else chr(39) + '0'};")
e()
e('  // Register words for the blocks of CLK-BUS.')
for nm in BUS_WORDS:
    e(f'  assign o_bus_{nm} = w_cfg_{nm};')
e()

# slots
e('  // Command words of the crossing: the CSR words in slot positions.')
e('  always_comb begin : p_com_cfg_all')
e("    w_cfg_all = '0;")
for n in SLOTS:
    r = R[n]
    if n in CFG:
        if r.banked:
            e(f'    for (int idx = 0; idx < {r.cp}; idx++) begin')
            e(f'      w_cfg_all[({base(r)} + idx)*32 +: 32] = w_cfg_{n}[idx];')
            e('    end')
        else:
            e(f'    w_cfg_all[{base(r)}*32 +: 32] = w_cfg_{n};')
e('  end')
e()
e('  // Shadow words back to the register ports.')
for n in CFG:
    r = R[n]
    if r.banked:
        e('  generate')
        e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_sh_{n}')
        e(f'      assign o_ph_{n}[gen_i] = w_shadow[({base(r)} + gen_i)*32 +: 32];')
        e('    end')
        e('  endgenerate')
    else:
        e(f'  assign o_ph_{n} = w_shadow[{base(r)}*32 +: 32];')
e()
e('  // Reset values of the shadow words equal the reset values of the CSR fields.')
e('  always_comb begin : p_com_shadow_init')
e("    w_shadow_init = '0;")
for n in SLOTS:
    r = R[n]
    if n in CFG and r.reset_word:
        if r.banked:
            e(f'    for (int idx = 0; idx < {r.cp}; idx++) begin')
            e(f"      w_shadow_init[({base(r)} + idx)*32 +: 32] = 32'h{r.reset_word:08X};")
            e('    end')
        else:
            e(f"    w_shadow_init[{base(r)}*32 +: 32] = 32'h{r.reset_word:08X};")
e('  end')
e()
e('  // Published words, event sets and command clears of the engines in slot positions.')
for lst, pref, vn in ((PUB, 'pub', 'w_pub_all'), (SET, 'set', 'w_set_all'), (CLR, 'clr', 'w_clr_all')):
    e(f'  always_comb begin : p_com_{pref}_all')
    e(f"    {vn} = '0;")
    for n in lst:
        r = R[n]
        if r.banked:
            e(f'    for (int idx = 0; idx < {r.cp}; idx++) begin')
            e(f'      {vn}[({base(r)} + idx)*32 +: 32] = i_ph_{pref}_{n}[idx];')
            e('    end')
        else:
            e(f'    {vn}[{base(r)}*32 +: 32] = i_ph_{pref}_{n};')
    e('  end')
    e()

# write decode
e('  // Write decode: the written address becomes the slot of the register in the crossing.')
e('  // index is zero-extended before the compare with the full bank count, so a count of 16 accepts')
e('  // indices 0 to 15 (review 2026-11-22: the compare used the count [3:0], which is 0 for 16).')
e('  always_comb begin : p_com_dec')
e("    w_dec_vld  = 1'b0;")
e("    w_dec_slot = '0;")
e('    casez (w_reg_wr_addr[15:2])')
for n in SLOTS:
    r = R[n]
    if n not in CFG:
        continue
    if r.banked:
        pat = format(r.offset >> 6, '010b') + '????'
        e(f"      14'b{pat}: begin")
        e(f"        w_dec_vld  = ({{28'd0, w_reg_wr_addr[5:2]}} < {r.cp});")
        e(f"        w_dec_slot = ({base(r)}[LPARA_SLOT_W-1:0] + {{4'd0, w_reg_wr_addr[5:2]}});")
        e('      end')
    else:
        pat = format(r.offset >> 2, '014b')
        e(f"      14'b{pat}: begin")
        e("        w_dec_vld  = 1'b1;")
        e(f'        w_dec_slot = {base(r)}[LPARA_SLOT_W-1:0];')
        e('      end')
e('      default: begin')
e("        w_dec_vld = 1'b0;")
e('      end')
e('    endcase')
e('  end')
e()
e('  // The command word is the CSR word one cycle after the accepted write (the registers have the')
e('  // new value then); a write while the command FIFO is full is dropped by the crossing.')
e('  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_wr')
e('    if (!i_rst_n_bus) begin')
e("      reg_wr_vld  <= 1'b0;")
e("      reg_wr_slot <= '0;")
e('    end else begin')
e('      reg_wr_vld  <= w_reg_wr_en & w_dec_vld;')
e('      reg_wr_slot <= w_dec_slot;')
e('    end')
e('  end')
e()
e('  assign w_wr_word = w_cfg_all[reg_wr_slot*32 +: 32];')
e()

# crossing instance
e('  // Register crossing between CLK-BUS and CLK-PHY.')
e('  m_usb2_xreg #(')
e('    .PARA_USB2_XREG_NS  (LPARA_NS),')
e('    .PARA_USB2_XREG_NA  (LPARA_NA),')
e('    .PARA_USB2_PIPE_XREG (PARA_USB2_PIPE_XREG)')
e('  ) u_xreg (')
e('    .i_clk_bus     (i_clk_bus),')
e('    .i_rst_n_bus   (i_rst_n_bus),')
e('    .i_clk_phy     (i_clk_phy),')
e('    .i_rst_n_phy   (i_rst_n_phy),')
e('    .i_wr_en       (reg_wr_vld),')
e('    .i_wr_slot     (reg_wr_slot),')
e('    .i_wr_word     (w_wr_word),')
e('    .o_xq_free     (w_xq_free),')
e('    .o_xq_ovf      (w_xq_ovf),')
e('    .o_ld_en       (w_ld_en),')
e('    .o_ld_kind     (w_ld_kind),')
e('    .o_ld_slot     (w_ld_slot),')
e('    .o_ld_val      (w_ld_val),')
e('    .i_shadow_init (w_shadow_init),')
e('    .o_shadow      (w_shadow),')
e('    .i_pub         (w_pub_all),')
e('    .i_set         (w_set_all),')
e('    .i_clr         (w_clr_all)')
e('  );')
e()

# update apply
e('  // Update words of the crossing are registered once and decoded into the hardware loads.')
e('  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_ld')
e('    if (!i_rst_n_bus) begin')
e("      reg_ld_en   <= 1'b0;")
e("      reg_ld_kind <= '0;")
e("      reg_ld_slot <= '0;")
e("      reg_ld_val  <= '0;")
e('    end else begin')
e('      reg_ld_en   <= w_ld_en;')
e('      reg_ld_kind <= w_ld_kind;')
e('      reg_ld_slot <= w_ld_slot;')
e('      reg_ld_val  <= w_ld_val;')
e('    end')
e('  end')
e()
e('  assign w_k_set = reg_ld_en & (reg_ld_kind == LPARA_KIND_SET[3:0]);')
e('  assign w_k_clr = reg_ld_en & (reg_ld_kind == LPARA_KIND_CLR[3:0]);')
e('  assign w_k_pub = reg_ld_en & (reg_ld_kind == LPARA_KIND_PUB[3:0]);')
e()
for n in SLOTS:
    r = R[n]
    if r.banked:
        e('  generate')
        e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_hit_{n}')
        e(f'      assign w_hit_{n}[gen_i] = (reg_ld_slot == ({base(r)}[LPARA_SLOT_W-1:0] + gen_i[LPARA_SLOT_W-1:0]));')
        if n in SET:
            e(f'      assign w_sethit_{n}[gen_i] = w_k_set & w_hit_{n}[gen_i];')
        if n in CLR:
            e(f'      assign w_clrhit_{n}[gen_i] = w_k_clr & w_hit_{n}[gen_i];')
        if n in PUB:
            e(f'      assign w_pubhit_{n}[gen_i] = w_k_pub & w_hit_{n}[gen_i];')
        e('    end')
        e('  endgenerate')
    else:
        e(f'  assign w_hit_{n} = (reg_ld_slot == {base(r)}[LPARA_SLOT_W-1:0]);')
        if n in SET:
            e(f'  assign w_sethit_{n} = w_k_set & w_hit_{n};')
        if n in CLR:
            e(f'  assign w_clrhit_{n} = w_k_clr & w_hit_{n};')
        if n in PUB:
            e(f'  assign w_pubhit_{n} = w_k_pub & w_hit_{n};')
e()

# hold registers
e('  // Hold registers of the status fields that the engines publish.')
e('  always_ff @(posedge i_clk_bus, negedge i_rst_n_bus) begin : p_ff_pub')
e('    if (!i_rst_n_bus) begin')
for r in R.values():
    for f in r.fields:
        if kind(f) == 'pub':
            e(f"      reg_pub_{r.name}_{f.name} <= '0;")
e('    end else begin')
for r in R.values():
    for f in r.fields:
        if kind(f) == 'pub':
            sl = f'[{f.msb}:{f.lsb}]' if f.w > 1 else f'[{f.lsb}]'
            if r.banked:
                e(f'      for (int idx = 0; idx < {r.cp}; idx++) begin')
                e(f'        if (w_pubhit_{r.name}[idx])')
                e(f'          reg_pub_{r.name}_{f.name}[idx] <= reg_ld_val{sl};')
                e('      end')
            else:
                e(f'      if (w_pubhit_{r.name})')
                e(f'        reg_pub_{r.name}_{f.name} <= reg_ld_val{sl};')
e('    end')
e('  end')
e()

# CSR inputs
e('  // Inputs of the CSR: published status, constants of the build and the computed fields.')
build_src = {'role_cfg': 'PARA_USB2_ROLE_CFG[1:0]', 'phy_ulpi': 'PARA_USB2_PHY_ULPI[0]',
             'utmi_16': 'PARA_USB2_UTMI_16[0]', 'axi_slave': 'PARA_USB2_AXI_SLAVE[0]',
             'lpm_cfg': 'PARA_USB2_LPM_CFG[0]', 'split_cfg': 'PARA_USB2_SPLIT_CFG[0]',
             'num_ep': "PARA_USB2_NEP1[4:0] - 5'd1", 'num_hc': 'PARA_USB2_NHC[4:0]',
             'fifo_log2': 'PARA_USB2_FIFO_LOG2[3:0]', 'sg_cfg': 'PARA_USB2_SG_CFG[0]',
             'dbuf_cfg': 'PARA_USB2_DBUF_CFG[0]', 'par_cfg': 'PARA_USB2_PAR_CFG[0]'}
for r in R.values():
    for f in r.fields:
        if f.type != 'ro':
            continue
        nm = f'w_i_{r.name}_{f.name}'
        if r.name == 'version':
            e(f"  assign {nm} = {'16' + chr(39) + 'd1' if f.name == 'major' else '16' + chr(39) + 'd0'};")
        elif r.name == 'build':
            e(f'  assign {nm} = {build_src[f.name]};')
        elif r.name == 'irq_sts':
            e(f'  assign {nm} = w_irq_sts[{f.lsb}];')
        elif r.name == 'ep_sum_i':
            e(f'  assign {nm} = w_epsum_i[15:0];')
        elif r.name == 'ep_sum_o':
            e(f'  assign {nm} = w_epsum_o[15:0];')
        elif r.name == 'hc_sum':
            e(f'  assign {nm} = w_hcsum[15:0];')
        elif (r.name, f.name) == ('sts', 'xq_free'):
            e(f'  assign {nm} = w_xq_free;')
        elif (r.name, f.name) == ('sts', 'phyclk_ok'):
            e(f'  assign {nm} = i_phy_alive;')
        elif (r.name, f.name) == ('sts', 'rstbusy'):
            e(f'  assign {nm} = i_soft_busy;')
        elif (r.name, f.name) == ('hsts', 'oc_act'):
            e(f'  assign {nm} = i_oc_act;')
        else:
            e(f'  assign {nm} = reg_pub_{r.name}_{f.name};')
e()

# sums
e('  // Summaries: flag i is 1 when an interrupt status bit of endpoint or channel i and its enable are set.')
e('  always_comb begin : p_com_sum')
e("    w_epsum_i = '0;")
e("    w_epsum_o = '0;")
e("    w_hcsum   = '0;")
e('    for (int idx = 0; idx < PARA_USB2_NEP1; idx++) begin')
e('      w_epsum_i[idx] = |(w_flg_epi_int[idx] & w_cfg_epi_ien[idx]);')
e('      w_epsum_o[idx] = |(w_flg_epo_int[idx] & w_cfg_epo_ien[idx]);')
e('    end')
e('    for (int idx = 0; idx < PARA_USB2_NHC; idx++) begin')
e('      w_hcsum[idx] = |(w_flg_hc_int[idx] & w_cfg_hc_ien[idx]);')
e('    end')
e('  end')
e()

# interrupt block
e('  // Interrupt block: events of both domains set the raw flags; the enable and injection words come')
e('  // from the CSR; the masked status and the interrupt output go back.')
irq = R['irq_raw']
sets = ' | '.join(f'w_irq_bit_{f.name}' for f in irq.fields[:0])
e("  assign w_irq_set_ph = w_sethit_irq_raw ? reg_ld_val[LPARA_IRQ_N-1:0] : '0;")
evt_map = {'ocur': 'i_evt_ocur', 'axi_err': 'i_evt_axi_err', 'dma_err': 'i_evt_dma_err', 'xq_ovf': 'w_xq_ovf'}
bus_terms = []
e("  always_comb begin : p_com_evt_bus")
e("    w_irq_evt_bus = '0;")
for f in irq.fields:
    if f.name in evt_map:
        e(f'    w_irq_evt_bus[{f.lsb}] = {evt_map[f.name]};')
e('  end')
e('  assign w_irq_evt = w_irq_set_ph | w_irq_evt_bus;')
e()
raw_parts = []
for tag, nm in (('raw', 'irq_raw'), ('en', 'irq_en'), ('inj', 'irq_inj')):
    r = R[nm]
    e(f'  always_comb begin : p_com_irq_{tag}')
    e(f"    w_irq_{tag} = '0;")
    for f in r.fields:
        e(f'    w_irq_{tag}[{f.lsb}] = w_o_{nm}_{f.name};')
    e('  end')
    e()
e('  m_usb2_irq #(')
e('    .PARA_USB2_IRQ_N (LPARA_IRQ_N)')
e('  ) u_irq (')
e('    .i_clk_bus   (i_clk_bus),')
e('    .i_rst_n_bus (i_rst_n_bus),')
e('    .i_evt       (w_irq_evt),')
e('    .i_raw       (w_irq_raw),')
e('    .i_en        (w_irq_en),')
e('    .i_inj       (w_irq_inj),')
e('    .o_set       (w_irq_set),')
e('    .o_sts       (w_irq_sts),')
e('    .o_int_usb   (o_int_usb)')
e('  );')
e()

# hardware loads
e('  // Hardware loads: event sets (write 1), command clears (write 0), published data and the DMA address.')
for r in R.values():
    for f in r.fields:
        k = kind(f)
        if f.type not in ('rwi', 'w1c'):
            continue
        we = f'w_hwe_{r.name}_{f.name}'
        wd = f'w_hwd_{r.name}_{f.name}'
        sl = f'[{f.msb}:{f.lsb}]' if f.w > 1 else f'[{f.lsb}]'
        if f.type == 'w1c' and r.name == 'irq_raw':
            e(f'  assign {we} = w_irq_set[{f.lsb}];')
            e(f"  assign {wd} = 1'b1;")
        elif f.type == 'w1c':
            e('  generate')
            e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_{r.name}_{f.name}')
            e(f'      assign {we}[gen_i] = w_sethit_{r.name}[gen_i] & reg_ld_val[{f.lsb}];')
            e(f"      assign {wd}[gen_i] = 1'b1;")
            e('    end')
            e('  endgenerate')
        elif k == 'soft':
            e(f'  assign {we} = i_soft_clr;')
            e(f"  assign {wd} = 1'b0;")
        elif k == 'cmd':
            if r.banked:
                e('  generate')
                e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_{r.name}_{f.name}')
                e(f'      assign {we}[gen_i] = w_clrhit_{r.name}[gen_i] & reg_ld_val[{f.lsb}];')
                e(f"      assign {wd}[gen_i] = 1'b0;")
                e('    end')
                e('  endgenerate')
            else:
                e(f'  assign {we} = w_clrhit_{r.name} & reg_ld_val[{f.lsb}];')
                e(f"  assign {wd} = 1'b0;")
        elif k == 'data':
            e('  generate')
            e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_{r.name}_{f.name}')
            e(f'      assign {we}[gen_i] = w_pubhit_{r.name}[gen_i];')
            e(f'      assign {wd}[gen_i] = reg_ld_val{sl};')
            e('    end')
            e('  endgenerate')
        elif k == 'addr':
            src = {'epi_dma': 'i_ld_epi_we', 'epo_dma': 'i_ld_epo_we', 'hc_dma': 'i_ld_hc_we'}[r.name]
            e('  generate')
            e(f'    for (genvar gen_i = 0; gen_i < {r.cp}; gen_i++) begin : gen_{r.name}_{f.name}')
            e(f'      assign {we}[gen_i] = {src}[gen_i];')
            e(f'      assign {wd}[gen_i] = i_ld_addr;')
            e('    end')
            e('  endgenerate')
e()
e('  // Control outputs of the reset block and the flags for the blocks of CLK-BUS.')
e('  assign o_role_host = reg_pub_sts_role;')
e('  assign o_ocur_flag = w_o_irq_raw_ocur;')
e('  assign o_soft_req = w_o_ctrl_swrst;')
e('  assign o_phy_hold = w_o_ctrl_phy_rst;')
e()

# the CSR instance
e('  // The generated CSR with every port connected by name.')
cp = []
for m in re.finditer(r'parameter logic \[31:0\] (PARA_\w+)', CSR_SRC):
    cp.append(m.group(1))
e('  m_vlsit_csr_usb2 #(')
conns = []
for nm in cp:
    if nm == 'PARA_ASYNCHRONOUS':
        conns.append(f"    .{nm} (32'd0)")
    else:
        m = re.match(r'PARA_U2_(\w+)_COUNT', nm)
        rn = m.group(1).lower()
        conns.append(f'    .{nm} ({R[rn].cp})')
e(',\n'.join(conns))
e('  ) u_csr (')
ports = []
PORT_RE = re.compile(r'^\s*(input|output)\s+(?:wire|logic)\s*((?:\[[^\]]+\])*)\s*(\w+)\s*,?\s*$')
inp = False
for ln in CSR_SRC.split('\n'):
    if ln.strip() == ') (':
        inp = True
        continue
    if inp and ln.strip() == ');':
        break
    if inp:
        m = PORT_RE.match(ln)
        if m:
            ports.append((m.group(1), m.group(3)))
fixed = {'i_clk_apb': 'i_clk_bus', 'i_rst_n_apb': 'i_rst_n_bus', 'i_clk_reg': 'i_clk_bus', 'i_rst_n_reg': 'i_rst_n_bus',
         'i_apb_psel': 'i_apb_psel', 'i_apb_penable': 'i_apb_penable', 'i_apb_pwrite': 'i_apb_pwrite',
         'i_apb_paddr': 'i_apb_paddr', 'i_apb_pwdata': 'i_apb_pwdata', 'i_apb_pstrb': 'i_apb_pstrb',
         'i_apb_pprot': 'i_apb_pprot', 'o_apb_pready': 'o_apb_pready', 'o_apb_pslverr': 'o_apb_pslverr',
         'o_apb_prdata': 'o_apb_prdata', 'i_protect_en': 'i_protect_en', 'i_slverr_en': 'i_slverr_en',
         'o_reg_rd_en': 'w_reg_rd_en', 'o_reg_rd_addr': 'w_reg_rd_addr', 'o_reg_wr_en': 'w_reg_wr_en',
         'o_reg_wr_addr': 'w_reg_wr_addr'}
fnames = {}
for r in R.values():
    for f in r.fields:
        fnames[f'o_u2_{r.name}_{f.name}'] = f'w_o_{r.name}_{f.name}'
        fnames[f'i_u2_{r.name}_{f.name}'] = f'w_i_{r.name}_{f.name}'
        fnames[f'i_hw_wdata_u2_{r.name}_{f.name}'] = f'w_hwd_{r.name}_{f.name}'
        fnames[f'i_hw_we_u2_{r.name}_{f.name}'] = f'w_hwe_{r.name}_{f.name}'
miss = []
cl = []
for d, nm in ports:
    if nm in fixed:
        cl.append(f'    .{nm} ({fixed[nm]})')
    elif nm in fnames:
        cl.append(f'    .{nm} ({fnames[nm]})')
    else:
        miss.append(nm)
e(',\n'.join(cl))
e('  );')
e()
e('endmodule')
if miss:
    print('UNCONNECTED CSR PORTS:', miss, file=sys.stderr)
out = '\n'.join(L).replace('{16\'d1}', "16'd1")
open(ROOT + '/rtl/m_usb2_regs.sv', 'w').write(out + '\n')
print('written m_usb2_regs.sv, lines', len(L), 'csr ports', len(ports), file=sys.stderr)
