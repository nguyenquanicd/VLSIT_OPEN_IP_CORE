import re,subprocess,sys,os
mods=sys.argv[1:]
for m in mods:
    open('../synth/s.ys','w').write(f"""plugin -i slang
read_slang -f ../synth/fl_nosram.f --top {m} -D VLSIT_SYNTHESIS
hierarchy -top {m}
synth -top {m}
tee -o ../synth/st_{m}.txt stat
""")
    subprocess.run(['yosys','-q','../synth/s.ys'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=900)
    t=open(f'../synth/st_{m}.txt').read()
    c=re.search(r'\n\s+(\d+) cells',t).group(1)
    ff=sum(int(a) for a,b in re.findall(r'\n\s+(\d+)\s+(\$_\w*DFF\w*)',t))
    print(f'{m:22s} cells={c:>7} flops={ff:>6}')
