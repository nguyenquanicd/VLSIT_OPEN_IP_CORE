"""Pre-layout timing and area on the OSU FreePDK45 standard cells (gscl45nm.lib, typical corner).

Run from the rtl folder with the OSS CAD Suite on PATH:  python ../synth/asic_sta.py [name ...]
Each design is flattened, mapped by Yosys (dfflibmap + abc with the delay target of the clock) and timed by the ABC
`stime` command: load-dependent cell delays of the Liberty tables, no wire load, no clock tree, FIFO RAM macro excluded.
A module that lives in one clock domain is timed against the period of that domain; a top is timed against the shorter
period (CLK-BUS), which bounds both domains. Results go to ../synth/asic_sta_results.txt.
"""
import re
import subprocess
import sys

LIB = '../synth/pdk_freepdk45/gscl45nm.lib'
T_PHY, T_BUS = 8333, 6667          # ps: 120 MHz and 150 MHz
# ABC script: the Yosys default for a Liberty library plus buffering, gate sizing and the timing report.
SCRIPT = ('+strash;&get,-n;&fraig,-x;&put;scorr;dc2;strash;&get,-n;&dch,-f;&nf,{D};&put;'
          'buffer;upsize,{D};dnsize,{D};topo;stime,-p')
DEV = ['PARA_USB2_ROLE=0', 'PARA_USB2_NUM_EP=2', 'PARA_USB2_NUM_HC=1', 'PARA_USB2_FIFO_DEPTH=256', 'PARA_USB2_NUM_DMA_CH=2']
PIPE = ['PARA_USB2_PIPE_PHY_IN=1', 'PARA_USB2_PIPE_RX=1', 'PARA_USB2_PIPE_CRC=1', 'PARA_USB2_PIPE_XREG=1',
        'PARA_USB2_PIPE_MODE=1', 'PARA_USB2_PIPE_AXS=1']
HOST = ['PARA_USB2_ROLE=1', 'PARA_USB2_NUM_EP=1', 'PARA_USB2_NUM_HC=8', 'PARA_USB2_UTMI_W=16', 'PARA_USB2_AXI_DATA_W=64',
        'PARA_USB2_SPLIT_EN=1', 'PARA_USB2_FIFO_DEPTH=1024']
DUAL = ['PARA_USB2_ROLE=2', 'PARA_USB2_NUM_EP=8', 'PARA_USB2_NUM_HC=8', 'PARA_USB2_LPM_EN=1', 'PARA_USB2_SPLIT_EN=1',
        'PARA_USB2_FIFO_DEPTH=1024']
# name: (file list, top, parameters, period in ps)
RUNS = {
    'TOP-MIN-OPT0': ('fl_utmi_axis.f', 'm_usb2_top_utmi_axis', DEV, T_BUS),
    'TOP-MIN-PIPE': ('fl_utmi_axis.f', 'm_usb2_top_utmi_axis', DEV + PIPE, T_BUS),
    'TOP-HOST-OPT0': ('fl_utmi_axim.f', 'm_usb2_top_utmi_axim', HOST, T_BUS),
    'TOP-DUAL-OPT0': ('fl_utmi_axim.f', 'm_usb2_top_utmi_axim', DUAL, T_BUS),
    'TOP-DUAL-PIPE': ('fl_utmi_axim.f', 'm_usb2_top_utmi_axim', DUAL + PIPE[:5], T_BUS),
    'MOD-dev': ('fl_nosram.f', 'm_usb2_dev', [], T_PHY),
    'MOD-host': ('fl_nosram.f', 'm_usb2_host', [], T_PHY),
    'MOD-fifo': ('fl_nosram.f', 'm_usb2_fifo', [], T_PHY),
    'MOD-lnk': ('fl_nosram.f', 'm_usb2_lnk', [], T_PHY),
    'MOD-spd': ('fl_nosram.f', 'm_usb2_spd', [], T_PHY),
    'MOD-axs': ('fl_nosram.f', 'm_usb2_axs', [], T_BUS),
    'MOD-dma': ('fl_nosram.f', 'm_usb2_dma', [], T_BUS),
    'MOD-csr': ('fl_nosram.f', 'm_vlsit_csr_usb2', [], T_BUS),
}


def run(name):
    fl, top, ps, per = RUNS[name]
    g = ' '.join('-G ' + p for p in ps)
    ys = f'../synth/asic_{name}.ys'
    log = f'../synth/asic_{name}.log'
    open(ys, 'w').write(
        f"plugin -i slang\nread_slang -f ../synth/{fl} --top {top} {g} -D VLSIT_SYNTHESIS\n"
        f"hierarchy -top {top}\nsynth -top {top} -flatten\ndfflibmap -liberty {LIB}\n"
        f"abc -liberty {LIB} -D {per} -script {SCRIPT}\nopt_clean\ntee -o ../synth/asic_{name}_stat.txt stat -liberty {LIB}\n")
    r = subprocess.run(['yosys', '-l', log, ys], capture_output=True, text=True, timeout=6000)
    t = open(log, errors='replace').read()
    d = re.findall(r'Delay\s*=\s*([\d.]+)\s*ps', t)
    a = re.findall(r"Chip area for (?:top )?module '[^']*':\s*([\d.]+)", t)
    c = re.findall(r'\n\s+(\d+)\s+(?:[\d.]+\s+)?cells\n', t)
    if r.returncode != 0 or not d:
        return f'{name}: failed (rc={r.returncode})'
    dl = float(d[-1])
    return (f'{name} top={top} period={per} ps delay={dl:.0f} ps slack={per - dl:.0f} ps '
            f'fmax={1e6 / dl:.1f} MHz cells={c[-1] if c else "?"} area={a[-1] if a else "?"} um2')


if __name__ == '__main__':
    for n in (sys.argv[1:] or list(RUNS)):
        line = run(n)
        print(line, flush=True)
        open('../synth/asic_sta_results.txt', 'a').write(line + '\n')
