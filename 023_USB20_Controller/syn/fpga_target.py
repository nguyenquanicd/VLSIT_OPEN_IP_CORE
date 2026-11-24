"""Timing-driven FPGA runs against a clock target, several seeds per configuration (nextpnr-ecp5).

Run from the rtl folder with the OSS CAD Suite on PATH:  python ../syn/fpga_target.py
The targets are written as LPF FREQUENCY constraints so that the placer works toward them: CLK-PHY 120 MHz (twice the 60 MHz
of a UTMI+ 8-bit PHY) and CLK-BUS 150 MHz. Results (one line per run) go to ../syn/fpga_target_results.txt.
"""
import re
import subprocess

BASE = ['PARA_USB2_ROLE=0', 'PARA_USB2_NUM_EP=2', 'PARA_USB2_NUM_HC=1', 'PARA_USB2_FIFO_DEPTH=256', 'PARA_USB2_NUM_DMA_CH=2']
CFG = {
    'OPT0': BASE,
    'PIPE-ALL': BASE + ['PARA_USB2_PIPE_PHY_IN=1', 'PARA_USB2_PIPE_RX=1', 'PARA_USB2_PIPE_CRC=1', 'PARA_USB2_PIPE_XREG=1',
                        'PARA_USB2_PIPE_MODE=1', 'PARA_USB2_PIPE_AXS=1'],
}
TOP, FL = 'm_usb2_top_utmi_axis', 'utmi_axis'
FPHY, FBUS = 120, 150
SEEDS = (1, 2, 3)


def synth(name):
    g = ' '.join('-G ' + p for p in CFG[name])
    open('../syn/fpgat.ys', 'w').write(
        f"plugin -i slang\nread_slang -f filelist.f --top {TOP} {g} -D VLSIT_SYNTHESIS\n"
        f"synth_ecp5 -top {TOP} -json ../syn/fpgat_{name}.json\n")
    r = subprocess.run(['yosys', '-q', '../syn/fpgat.ys'], capture_output=True, text=True, timeout=3000)
    return r.returncode == 0


def pnr(name, seed):
    lpf = f'../syn/fpgat_{name}.lpf'
    open(lpf, 'w').write(f'FREQUENCY PORT "i_clk_phy" {FPHY} MHz;\nFREQUENCY PORT "i_clk_bus" {FBUS} MHz;\n')
    log = f'../syn/fpgat_{name}_s{seed}.log'
    subprocess.run(['nextpnr-ecp5', '--um5g-85k', '--package', 'CABGA381', '--speed', '8', '--json',
                    f'../syn/fpgat_{name}.json', '--lpf', lpf, '--lpf-allow-unconstrained', '--timing-allow-fail',
                    '--placer-heap-critexp', '4', '--placer-heap-timingweight', '20',
                    '--seed', str(seed), '-l', log], capture_output=True, text=True, timeout=3000)
    t = open(log).read()
    last = {}
    for c, f in re.findall(r"Max frequency for clock\s+'([^']+)':\s+([\d.]+) MHz", t):
        last[c] = float(f)
    ph = [v for k, v in last.items() if 'clk_phy' in k]
    bu = [v for k, v in last.items() if 'clk_bus' in k]
    lut = re.findall(r'TRELLIS_COMB:\s+(\d+)/', t)
    ff = re.findall(r'TRELLIS_FF:\s+(\d+)/', t)
    return (ph[0] if ph else 0.0), (bu[0] if bu else 0.0), (lut[-1] if lut else '?'), (ff[-1] if ff else '?')


if __name__ == '__main__':
    for name in CFG:
        if not synth(name):
            line = f'{name}: yosys failed'
            print(line, flush=True)
            open('../syn/fpga_target_results.txt', 'a').write(line + '\n')
            continue
        for seed in SEEDS:
            ph, bu, lut, ff = pnr(name, seed)
            line = f'{name} seed={seed} LUT4={lut} FF={ff} phy={ph:.1f} MHz (target {FPHY}) bus={bu:.1f} MHz (target {FBUS})'
            print(line, flush=True)
            open('../syn/fpga_target_results.txt', 'a').write(line + '\n')
