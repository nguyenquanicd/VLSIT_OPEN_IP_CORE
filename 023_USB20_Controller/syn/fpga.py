"""FPGA place-and-route timing of the USB 2.0 controller on a Lattice ECP5 (Yosys synth_ecp5 + nextpnr-ecp5).

Run from the rtl folder with the OSS CAD Suite on PATH:  python ../syn/fpga.py [config ...]
It gives real placed-and-routed Fmax of CLK-PHY and CLK-BUS on one FPGA family, to compare the timing
options of the design (the numbers are not ASIC numbers). Results go to ../syn/fpga_results.txt.
"""
import re
import subprocess
import sys

BASE = ['PARA_USB2_ROLE=0', 'PARA_USB2_NUM_EP=2', 'PARA_USB2_NUM_HC=1', 'PARA_USB2_FIFO_DEPTH=256', 'PARA_USB2_NUM_DMA_CH=2']
ALLPIPE = ['PARA_USB2_PIPE_PHY_IN=1', 'PARA_USB2_PIPE_RX=1', 'PARA_USB2_PIPE_CRC=1', 'PARA_USB2_PIPE_XREG=1']
CFG = {
    'MIN-P0': ('m_usb2_top_utmi_axis', 'utmi_axis', BASE),
    'MIN-ALLPIPE': ('m_usb2_top_utmi_axis', 'utmi_axis', BASE + ALLPIPE),
    'MIN-ALLPIPE-MODE': ('m_usb2_top_utmi_axis', 'utmi_axis', BASE + ALLPIPE + ['PARA_USB2_PIPE_MODE=1']),
    'MIN-ALLPIPE-RAM1P': ('m_usb2_top_utmi_axis', 'utmi_axis', BASE + ALLPIPE + ['PARA_USB2_RAM_1P=1']),
    'CAM-HOST-P0': ('m_usb2_top_utmi_axim', 'utmi_axim',
                    ['PARA_USB2_ROLE=1', 'PARA_USB2_NUM_EP=1', 'PARA_USB2_NUM_HC=8', 'PARA_USB2_UTMI_W=16',
                     'PARA_USB2_AXI_DATA_W=64', 'PARA_USB2_SPLIT_EN=1', 'PARA_USB2_FIFO_DEPTH=1024']),
}


def run(name):
    top, fl, ps = CFG[name]
    g = ' '.join('-G ' + p for p in ps)
    ys = (f"plugin -i slang\nread_slang -f filelist_{fl}.f --top {top} {g} -D VLSIT_SYNTHESIS\n"
          f"synth_ecp5 -top {top} -json ../syn/fpga_{name}.json\n")
    open('../syn/fpga.ys', 'w').write(ys)
    r = subprocess.run(['yosys', '-q', '-l', f'../syn/fpga_{name}_yosys.log', '../syn/fpga.ys'],
                       capture_output=True, text=True, timeout=3000)
    if r.returncode != 0:
        return f'{name}: yosys failed {r.stderr[-300:]}'
    r = subprocess.run(['nextpnr-ecp5', '--um5g-85k', '--package', 'CABGA381', '--speed', '8', '--json',
                        f'../syn/fpga_{name}.json', '--freq', '60', '--lpf-allow-unconstrained',
                        '--timing-allow-fail', '--seed', '1', '-l', f'../syn/fpga_{name}_pnr.log'],
                       capture_output=True, text=True, timeout=3000)
    log = open(f'../syn/fpga_{name}_pnr.log').read()
    mx = re.findall(r"Max frequency for clock\s+'([^']+)':\s+([\d.]+) MHz", log)
    lut = re.findall(r'TRELLIS_COMB:\s+(\d+)/', log)
    ff = re.findall(r'TRELLIS_FF:\s+(\d+)/', log)
    last = {}
    for c, f in mx:
        last[c] = f
    return f"{name}: top={top} LUT4={lut[-1] if lut else '?'} FF={ff[-1] if ff else '?'} fmax(MHz, last report)={last}"


if __name__ == '__main__':
    names = sys.argv[1:] or list(CFG)
    for n in names:
        line = run(n)
        print(line, flush=True)
        open('../syn/fpga_results.txt', 'a').write(line + '\n')
