#!/usr/bin/env python3
"""Generate rtl/m_usb2_core.sv and the four wrappers m_usb2_top_{utmi,ulpi}_{axim,axis}.sv.

The pin lists of the core and the wrappers come from one table so that they cannot drift apart.
Run from the rtl_gen folder: python gen_core.py
"""
import sys

OUT = '../rtl/'
AIW = 'PARA_USB2_AXI_ID_W'
AAW = 'PARA_USB2_AXI_ADDR_W'
ADW = 'PARA_USB2_AXI_DATA_W'

# (group, direction, name, width expression or None)
UTMI = [('o', 'o_utmi_dataout', 16), ('o', 'o_utmi_txvalid', 1), ('o', 'o_utmi_txvalidh', 1),
        ('i', 'i_utmi_txready', 1), ('i', 'i_utmi_datain', 16), ('i', 'i_utmi_rxvalid', 1),
        ('i', 'i_utmi_rxvalidh', 1), ('i', 'i_utmi_rxactive', 1), ('i', 'i_utmi_rxerror', 1),
        ('i', 'i_utmi_linestate', 2), ('o', 'o_utmi_opmode', 2), ('o', 'o_utmi_xcvrsel', 2),
        ('o', 'o_utmi_termsel', 1), ('o', 'o_utmi_suspend_n', 1), ('o', 'o_utmi_databus16_8', 1),
        ('o', 'o_utmi_bitstuff_en', 1), ('o', 'o_utmi_bitstuff_en_h', 1), ('o', 'o_utmi_dppulldown', 1),
        ('o', 'o_utmi_dmpulldown', 1), ('i', 'i_utmi_hostdisc', 1), ('o', 'o_utmi_drvvbus', 1),
        ('o', 'o_utmi_chrgvbus', 1), ('o', 'o_utmi_dischrgvbus', 1), ('o', 'o_utmi_idpullup', 1),
        ('i', 'i_utmi_iddig', 1), ('i', 'i_utmi_avalid', 1), ('i', 'i_utmi_bvalid', 1),
        ('i', 'i_utmi_vbusvalid', 1), ('i', 'i_utmi_sessend', 1)]
ULPI = [('i', 'i_ulpi_dir', 1), ('i', 'i_ulpi_nxt', 1), ('o', 'o_ulpi_stp', 1), ('i', 'i_ulpi_data', 8),
        ('o', 'o_ulpi_data', 8), ('o', 'o_ulpi_data_oe', 1)]
AXIM = [('o', 'o_axim_awid', AIW), ('o', 'o_axim_awaddr', AAW), ('o', 'o_axim_awlen', 8), ('o', 'o_axim_awsize', 3),
        ('o', 'o_axim_awburst', 2), ('o', 'o_axim_awcache', 4), ('o', 'o_axim_awprot', 3), ('o', 'o_axim_awvalid', 1),
        ('i', 'i_axim_awready', 1), ('o', 'o_axim_wdata', ADW), ('o', 'o_axim_wstrb', ADW + '/8'),
        ('o', 'o_axim_wlast', 1), ('o', 'o_axim_wvalid', 1), ('i', 'i_axim_wready', 1), ('i', 'i_axim_bid', AIW),
        ('i', 'i_axim_bresp', 2), ('i', 'i_axim_bvalid', 1), ('o', 'o_axim_bready', 1), ('o', 'o_axim_arid', AIW),
        ('o', 'o_axim_araddr', AAW), ('o', 'o_axim_arlen', 8), ('o', 'o_axim_arsize', 3), ('o', 'o_axim_arburst', 2),
        ('o', 'o_axim_arcache', 4), ('o', 'o_axim_arprot', 3), ('o', 'o_axim_arvalid', 1), ('i', 'i_axim_arready', 1),
        ('i', 'i_axim_rid', AIW), ('i', 'i_axim_rdata', ADW), ('i', 'i_axim_rresp', 2), ('i', 'i_axim_rlast', 1),
        ('i', 'i_axim_rvalid', 1), ('o', 'o_axim_rready', 1)]
AXIS = [('i', 'i_axis_awid', AIW), ('i', 'i_axis_awaddr', AAW), ('i', 'i_axis_awlen', 8), ('i', 'i_axis_awsize', 3),
        ('i', 'i_axis_awburst', 2), ('i', 'i_axis_awvalid', 1), ('o', 'o_axis_awready', 1), ('i', 'i_axis_wdata', ADW),
        ('i', 'i_axis_wstrb', ADW + '/8'), ('i', 'i_axis_wlast', 1), ('i', 'i_axis_wvalid', 1), ('o', 'o_axis_wready', 1),
        ('o', 'o_axis_bid', AIW), ('o', 'o_axis_bresp', 2), ('o', 'o_axis_bvalid', 1), ('i', 'i_axis_bready', 1),
        ('i', 'i_axis_arid', AIW), ('i', 'i_axis_araddr', AAW), ('i', 'i_axis_arlen', 8), ('i', 'i_axis_arsize', 3),
        ('i', 'i_axis_arburst', 2), ('i', 'i_axis_arvalid', 1), ('o', 'o_axis_arready', 1), ('o', 'o_axis_rid', AIW),
        ('o', 'o_axis_rdata', ADW), ('o', 'o_axis_rresp', 2), ('o', 'o_axis_rlast', 1), ('o', 'o_axis_rvalid', 1),
        ('i', 'i_axis_rready', 1), ('o', 'o_dma_req', 'PARA_USB2_NUM_DMA_CH'), ('i', 'i_dma_ack', 'PARA_USB2_NUM_DMA_CH')]
COMMON_IN = [('i_clk_phy', 1), ('i_clk_bus', 1), ('i_rst_n_phy', 1), ('i_rst_n_bus', 1)]
APB = [('i', 'i_apb_paddr', 16), ('i', 'i_apb_pwdata', 32), ('i', 'i_apb_pwrite', 1), ('i', 'i_apb_penable', 1),
       ('i', 'i_apb_psel', 1), ('i', 'i_apb_pstrb', 4), ('i', 'i_apb_pprot', 3), ('o', 'o_apb_pready', 1),
       ('o', 'o_apb_pslverr', 1), ('o', 'o_apb_prdata', 32), ('i', 'i_protect_en', 1), ('i', 'i_slverr_en', 1)]
MISC = [('i', 'i_ovrcur_n', 1), ('o', 'o_vbus_pwr_en', 1), ('i', 'i_dft_test_en', 1), ('i', 'i_dft_scan_en', 1),
        ('o', 'o_int_usb', 1), ('o', 'o_phy_rst_n', 1)]
CLKRST = [('i', 'i_clk_phy', 1), ('i', 'i_clk_bus', 1), ('i', 'i_rst_n_phy', 1), ('i', 'i_rst_n_bus', 1)]

PARAMS = [
    ('PARA_USB2_ROLE', 2, 'role: 0 device, 1 host, 2 dual-role by the ID pin', '0, 1 or 2; default is 2', 'none'),
    ('PARA_USB2_PHY_IF', 0, 'PHY interface: 0 UTMI+, 1 ULPI', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_UTMI_W', 8, 'UTMI+ data width', '8 or 16; default is 8', 'bit'),
    ('PARA_USB2_DATA_IF', 0, 'data interface: 0 AXI4 master DMA, 1 AXI4 slave with DMA handshake', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_NUM_EP', 8, 'device endpoints besides EP0', '1 to 15; default is 8', 'count'),
    ('PARA_USB2_NUM_HC', 8, 'host channels', '1 to 16; default is 8', 'count'),
    ('PARA_USB2_FIFO_DEPTH', 1024, 'FIFO RAM depth in 32-bit words', 'power of two, 256 to 32768; default is 1024', 'word'),
    ('PARA_USB2_LPM_EN', 0, 'LPM L1 support', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_SPLIT_EN', 0, 'host split transactions', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_AXI_ADDR_W', 32, 'AXI address width', '32, 40 or 64; default is 32', 'bit'),
    ('PARA_USB2_AXI_DATA_W', 32, 'AXI data width, four times the UTMI+ width (DEC-010)', '32 or 64; default is 32', 'bit'),
    ('PARA_USB2_AXI_ID_W', 4, 'AXI ID width', '1 to 8; default is 4', 'bit'),
    ('PARA_USB2_NUM_DMA_CH', 4, 'external DMA handshake channels', '1 to 16; default is 4', 'count'),
    ('PARA_USB2_DBUF_EN', 1, 'double-buffered status bit of endpoints and channels', '0 or 1; default is 1', 'none'),
    ('PARA_USB2_SG_EN', 0, 'scatter-gather descriptor engine of the AXI master DMA (DEC-013)', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_RAM_PAR_EN', 1, 'one parity bit per FIFO RAM row', '0 or 1; default is 1', 'none'),
    ('PARA_USB2_RAM_1P', 0, 'single-port serialization of the FIFO RAM accesses', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_PIPE_PHY_IN', 0, 'register stage on the UTMI+ receive pins', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_PIPE_RX', 0, 'register stage on the PHY inputs of the link', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_PIPE_CRC', 0, 'register stage before the CRC16 and field processing', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_PIPE_MODE', 0, 'register stage on the PHY mode outputs of the speed engine', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_RST_OPMODE', 3, 'OpMode driven by the host for the SE0 of a port reset (TBD-015)', '0 to 3; default is 3', 'none'),
    ('PARA_USB2_PIPE_AXS', 0, 'register slice on the AXI4 slave read data channel', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_PIPE_XREG', 0, 'register stage on the shadow words of CLK-PHY', '0 or 1; default is 0', 'none'),
    ('PARA_USB2_TSCALE', 1, 'divider of the timers, simulation only (must be 1 in a netlist)', '1, 16, 256 or 4096; default is 1', 'none'),
]


def width(w):
    return w if isinstance(w, str) else str(w)


def pdecl(direction, name, w):
    rng = ''
    if isinstance(w, str):
        rng = f'[{w}-1:0]'
    elif w > 1:
        rng = f'[{w-1}:0]'
    kw = 'input ' if direction == 'i' else 'output'
    ty = 'wire ' if direction == 'i' else 'logic'
    return (kw, ty, rng, name)


def render(groups, params, module, header, body, locals_=()):
    """groups: list of (title, [(dir, name, width)])"""
    out = [header.rstrip('\n'), '`timescale 1ns/1ps', '', f'module {module} #(']
    for i, (pn, dflt, desc, vals, unit) in enumerate(params):
        out.append(f'  // Parameter Description: {desc}.')
        out.append(f'  // Parameter values: {vals}.')
        out.append(f'  // Parameter unit: {unit}')
        out.append(f'  parameter logic [31:0] {pn} = {dflt}' + (',' if (i < len(params) - 1 or locals_) else ''))
    for j, (ln, lx) in enumerate(locals_):
        out.append(f'  localparam logic [31:0] {ln} = {lx}' + (',' if j < len(locals_) - 1 else ''))
    out.append(') (')
    first = True
    for title, plist in groups:
        if not first:
            out.append('')
        first = False
        out.append(f'  // {title}')
        for d, n, w in plist:
            kw, ty, rng, nm = pdecl(d, n, w)
            out.append(f'  {kw} {ty} {rng} {nm},')
    out[-1] = out[-1].rstrip(',')
    out.append(');')
    out.append('')
    out.extend(body)
    out.append('endmodule')
    return '\n'.join(out) + '\n'


HDR = '''/*
 * Project      : USB 2.0 Controller
 * Author       : Nguyen Hung Quan (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : 2026-11-20
 * Description  : %s
 */'''

# ---------------------------------------------------------------------------- the core
core_groups = [('Clocks, resets and the PHY reset request', CLKRST + [('o', 'o_phy_rst_n', 1)]),
               ('APB4 slave of the CSR', APB),
               ('Power switch, test and interrupt', [m for m in MISC if m[1] != 'o_phy_rst_n']),
               ('UTMI+ pins', UTMI), ('ULPI pins', ULPI), ('AXI4 master', AXIM), ('AXI4 slave and DMA handshake', AXIS)]
from core_body import build_body
core_body, LOCALS = build_body()
core_hdr = HDR % ('Structural core of the USB 2.0 controller (section 5 and 14.2, DEC-012). It holds the parameter\n'
                  ' *                check, the resets, the over-current block, the CSR integration, the PHY adapter, the\n'
                  ' *                link, the speed engine, the device and host engines, the FIFO manager, its crossing and\n'
                  ' *                the DMA or the AXI slave. The four wrappers tie off the pins of the interfaces that a\n'
                  ' *                build does not have.')
open(OUT + 'm_usb2_core.sv', 'w').write(render(core_groups, PARAMS, 'm_usb2_core', core_hdr, core_body, LOCALS))

# ---------------------------------------------------------------------------- wrappers
core_params = [p[0] for p in PARAMS]
all_core_ports = []
for _, plist in core_groups:
    all_core_ports.extend(plist)


def wrapper(phy, data):
    name = f'm_usb2_top_{phy}_{data}'
    pins = []
    if phy == 'utmi':
        pins += UTMI
    else:
        pins += ULPI
    if data == 'axim':
        pins += AXIM
    else:
        pins += AXIS
    groups = [('Clocks and resets', CLKRST + [('o', 'o_phy_rst_n', 1)]), ('APB4 slave of the CSR', APB),
              ('Power switch, test and interrupt', [m for m in MISC if m[1] != 'o_phy_rst_n']),
              ('PHY interface', UTMI if phy == 'utmi' else ULPI),
              ('Data interface', AXIM if data == 'axim' else AXIS)]
    fixed = {'PARA_USB2_PHY_IF': 0 if phy == 'utmi' else 1, 'PARA_USB2_DATA_IF': 0 if data == 'axim' else 1}
    wparams = []
    for pn, dflt, desc, vals, unit in PARAMS:
        if pn in ('PARA_USB2_PHY_IF', 'PARA_USB2_DATA_IF'):
            continue
        if pn == 'PARA_USB2_UTMI_W' and phy == 'ulpi':
            continue
        if pn == 'PARA_USB2_NUM_DMA_CH' and data == 'axim':
            continue
        if pn in ('PARA_USB2_AXI_ADDR_W',) and data == 'axis' and False:
            continue
        wparams.append((pn, dflt, desc, vals, unit))
    present = {n for _, plist in groups for _, n, _ in plist}
    body = ['  // Core with the fixed interface selection; the pins of the other interfaces are tied off.']
    inst_params = []
    for pn, dflt, *_ in PARAMS:
        if pn == 'PARA_USB2_PHY_IF':
            inst_params.append(f"    .{pn} (32'd{fixed[pn]})")
        elif pn == 'PARA_USB2_DATA_IF':
            inst_params.append(f"    .{pn} (32'd{fixed[pn]})")
        elif pn == 'PARA_USB2_UTMI_W' and phy == 'ulpi':
            inst_params.append(f"    .{pn} (32'd8)")
        elif pn == 'PARA_USB2_NUM_DMA_CH' and data == 'axim':
            inst_params.append(f"    .{pn} (32'd1)")
        else:
            inst_params.append(f'    .{pn} ({pn})')
    body.append('  m_usb2_core #(')
    body.append(',\n'.join(inst_params))
    body.append('  ) u_core (')
    conns = []
    for _, plist in core_groups:
        for d, n, w in plist:
            if n in present:
                conns.append(f'    .{n} ({n})')
            elif d == 'i':
                conns.append(f"    .{n} ('0)")
            else:
                conns.append(f'    .{n} ()')
    body.append(',\n'.join(conns))
    body.append('  );')
    body.append('')
    desc = (f'Wrapper of the USB 2.0 controller with {"UTMI+" if phy == "utmi" else "ULPI"} PHY pins and the '
            f'{"AXI4 master DMA" if data == "axim" else "AXI4 slave with DMA handshake"} (section 6.2, ASM-002).\n'
            ' *                The wrapper fixes the interface parameters of the core and ties off the pins of the\n'
            ' *                interfaces that this build does not have. It holds one instance and nothing else.')
    open(OUT + name + '.sv', 'w').write(render(groups, wparams, name, HDR % desc, body))
    return name


for phy in ('utmi', 'ulpi'):
    for data in ('axim', 'axis'):
        print('wrote', wrapper(phy, data), file=sys.stderr)
print('wrote m_usb2_core', file=sys.stderr)
