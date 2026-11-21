import re,subprocess
CFG={
 'CFG-MIN':   ('m_usb2_top_utmi_axis',['PARA_USB2_ROLE=0','PARA_USB2_NUM_EP=2','PARA_USB2_NUM_HC=1','PARA_USB2_FIFO_DEPTH=256','PARA_USB2_NUM_DMA_CH=2']),
 'CFG-FC-DEV':('m_usb2_top_ulpi_axis',['PARA_USB2_ROLE=0','PARA_USB2_NUM_EP=6','PARA_USB2_NUM_HC=1','PARA_USB2_FIFO_DEPTH=1024','PARA_USB2_NUM_DMA_CH=4']),
 'CFG-CAM-HOST':('m_usb2_top_utmi_axim',['PARA_USB2_ROLE=1','PARA_USB2_NUM_EP=1','PARA_USB2_NUM_HC=8','PARA_USB2_UTMI_W=16','PARA_USB2_AXI_DATA_W=64','PARA_USB2_SPLIT_EN=1','PARA_USB2_FIFO_DEPTH=1024']),
 'CFG-CAM-HOST-SG':('m_usb2_top_utmi_axim',['PARA_USB2_ROLE=1','PARA_USB2_NUM_EP=1','PARA_USB2_NUM_HC=8','PARA_USB2_UTMI_W=16','PARA_USB2_AXI_DATA_W=64','PARA_USB2_SPLIT_EN=1','PARA_USB2_SG_EN=1','PARA_USB2_FIFO_DEPTH=1024']),
 'CFG-DUAL-FULL':('m_usb2_top_utmi_axim',['PARA_USB2_ROLE=2','PARA_USB2_NUM_EP=8','PARA_USB2_NUM_HC=8','PARA_USB2_LPM_EN=1','PARA_USB2_SPLIT_EN=1','PARA_USB2_FIFO_DEPTH=1024']),
}
for name,(top,ps) in CFG.items():
    fl=top.replace('m_usb2_top_','')
    g=' '.join(f'-G {p}' for p in ps)
    open('../synth/s.ys','w').write(f"""plugin -i slang
read_slang -f ../synth/fl_{fl}.f --top {top} {g} -D VLSIT_SYNTHESIS
hierarchy -top {top}
synth -top {top} -flatten
tee -o ../synth/st_{name}.txt stat
tee -o ../synth/ltp_{name}.txt ltp -noff
""")
    # file list without SRAM for this wrapper
    src=open(f'filelist_{fl}.f').read().split('\n')
    out=[l for l in src if 'VLSIT_CELL_SRAM_1W1R' not in l]+['../synth/sram_bb.sv']
    open(f'../synth/fl_{fl}.f','w').write('\n'.join(out))
    r=subprocess.run(['yosys','-q','../synth/s.ys'],capture_output=True,text=True,timeout=1500)
    try:
        t=open(f'../synth/st_{name}.txt').read()
        c=re.search(r'\n\s+(\d+) cells',t).group(1)
        ff=sum(int(a) for a,b in re.findall(r'\n\s+(\d+)\s+(\$_\w*DFF\w*)',t))
        l=open(f'../synth/ltp_{name}.txt').read()
        d=re.search(r'Longest topological path in .*?\(length=(\d+)\)',l)
        print(f'{name:14s} top={top} cells={c} flops={ff} ltp_len={d.group(1) if d else "?"}')
    except Exception as e: print(name,'failed',e, r.stderr[-300:])
