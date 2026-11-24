#!/bin/bash
# All pipeline combinations at core level for LP, BASE and HP (KD = 2).
for c in LP BASE HP; do
  for pc in 0 1; do
    for pp in 0 1; do
      PC=$pc PP=$pp PI=0 bash runperf.sh $c 2 > res_${c}_c${pc}p${pp}.txt 2>&1
      echo "$c C$pc P$pp lines=$(wc -l < res_${c}_c${pc}p${pp}.txt) bad=$(grep -vc 'errors=0' res_${c}_c${pc}p${pp}.txt)"
    done
  done
  PC=1 PP=1 PI=1 bash runperf.sh $c 2 > res_${c}_c1p1i1.txt 2>&1
  echo "$c C1 P1 I1 lines=$(wc -l < res_${c}_c1p1i1.txt) bad=$(grep -vc 'errors=0' res_${c}_c1p1i1.txt) cycle_diff_vs_C1P1=$(diff <(awk '{print $(NF-2)}' res_${c}_c1p1i1.txt) <(awk '{print $(NF-2)}' res_${c}_c1p1.txt) | wc -l)"
done
