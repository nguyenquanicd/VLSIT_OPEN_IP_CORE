#!/bin/bash
# Structural logic depth of an RTL module (not a synthesis result and not a timing report).
# usage: bash depth.sh TOP "FILE FILE ..." "-G PARA_X=3 -G PARA_Y=2"   (files relative to ../rtl)
# Method: yosys + slang front end, coarse synthesis, adders mapped as Kogge-Stone (yosys choices/kogge-stone.v),
# techmap to 2-input gates, no timing-driven restructuring, then `ltp -noff`: the longest topological path
# between flip-flops and ports, one level per gate (AND, OR, XOR, MUX count as one level).
# Needs the OSS CAD Suite (PATH below) and Windows-style paths for yosys.
export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
R=$(cd "$(dirname "$0")/../rtl" && pwd -W)
TOP=$1; FILES=""; for f in $2; do FILES="$FILES $R/$f"; done; GS=$3
cat > run_$TOP.ys <<YS
plugin -i slang
read_slang --top $TOP $GS $FILES
hierarchy -top $TOP
synth -top $TOP -flatten -run :fine
techmap -map +/choices/kogge-stone.v -map +/techmap.v
opt -fast
opt_clean
tee -o stat_$TOP.txt stat
tee -o ltp_$TOP.txt ltp -noff
YS
yosys -q -l log_$TOP.txt run_$TOP.ys > /dev/null 2>&1
echo "$TOP $GS: $(grep -o 'length=[0-9]*' ltp_$TOP.txt | head -1)"
