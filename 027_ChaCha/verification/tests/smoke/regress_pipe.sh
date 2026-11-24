#!/bin/bash
# Top-level regression of the pipeline options: all 8 combinations of PC PP PI.
export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
export LINES_MAX=10
pass=0; fail=0
R() { # description then runtop arguments; PC PP PI come from the environment
  out=$(bash runtop.sh "$@" 2>&1 | grep RESULT)
  if echo "$out" | grep -q "errors=0"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL PC=$PC PP=$PP PI=$PI : $* -> $out"; fi
}
E() { # tb_err / tb_hw
  tb=$1
  iverilog -g2012 -DVLSIT_SYNTHESIS -o $tb.vvp -P $tb.PC=$PC -P $tb.PP=$PP -P $tb.PI=$PI $tb.sv $(cat srctop.txt | tr '\n' ' ') 2>&1 | grep -v sorry | head -3
  out=$(vvp $tb.vvp | grep RESULT)
  rm -f $tb.vvp
  if echo "$out" | grep -q "errors=0"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL PC=$PC PP=$PP PI=$PI : $tb -> $out"; fi
}
for pc in 0 1; do for pp in 0 1; do for pi in 0 1; do
  export PC=$pc PP=$pp PI=$pi
  # CFG-BASE style, DW 64: polling encrypt, decrypt, bad tag, long message
  R enc64 64 0 0 12 114 0 17 17 0
  R dec64 64 0 0 12 114 1 19 15 0
  R bad64 64 0 0 12 114 1 19 15 1 1
  R r9_enc 64 0 0 12 1280 0 162 162 0
  R r9_dec 64 0 0 12 1280 1 164 160 0
  # clock relations
  R enc64 64 1 1 12 114 0 17 17 0 1 4 1 1 1 5 5 5
  R dec64 64 0 1 12 114 1 19 15 0 1 4 1 1 1 6 5 5
  # DMA modes
  DMA=1 R enc64 64 0 0 12 114 0 17 17 0
  DMA=1 WM=4 TAIL=1 R dec64 64 0 0 12 114 1 19 15 0
  DMA=1 WM=8 R r9_enc 64 0 0 12 1280 0 162 162 0
  # other data widths
  R enc128 128 0 0 12 114 0 9 9 0
  R dec256 256 0 0 12 114 1 6 4 0
  OUTD=512 R enc32 32 0 0 12 114 0 32 33 0
  OUTD=512 R dec32 32 0 0 12 114 1 36 29 0
  # CFG-HP and CFG-LP shapes
  R enc128 128 0 0 12 114 0 9 9 0 1 4 2 2 2
  R dec128 128 0 0 12 114 1 10 8 0 1 4 2 2 2
  OUTD=512 R enc32 32 0 0 12 114 0 32 33 0 1 1 1 1 0
  OUTD=512 R dec32 32 0 0 12 114 1 36 29 0 1 1 1 1 0
  # other core shapes
  R enc64 64 0 0 12 114 0 17 17 0 1 2 1 2 1
  R enc64 64 0 0 12 114 0 17 17 0 1 4 1 4 1
  E tb_err
  E tb_hw
done; done; done
echo "SUMMARY pass=$pass fail=$fail"
