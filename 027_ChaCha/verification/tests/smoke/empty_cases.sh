#!/bin/bash
# Encryption and decryption of the ten messages r0..r9 (lengths 0 to 1280, including empty parts) on three core shapes.
export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
pass=0; fail=0
W=8
for shape in "4 1 1 1" "1 1 1 0" "4 2 2 2"; do
  set -- $shape; Q=$1; R=$2; N=$3; PA=$4
  for i in 0 1 2 3 4 5 6 7 8 9; do
    a=$(cut -d' ' -f1 r$i.len | tr -d '\r\n')
    m=$(cut -d' ' -f2 r$i.len | tr -d '\r\n')
    nA=$(( (a + W - 1) / W ))
    nM=$(( (m + W - 1) / W ))
    for dir in 0 1; do
      if [ $dir = 0 ]; then
        nin=$((nA + nM)); nout=$((nM + 2)); pfx=r${i}_enc
      else
        nin=$((nA + nM + 2)); nout=$nM; pfx=r${i}_dec
      fi
      out=$(bash runcore.sh $pfx 64 $Q $R $N $PA $a $m $dir $nin $nout 0 2>&1 | grep RESULT)
      if echo "$out" | grep -q "errors=0"; then
        pass=$((pass+1))
      else
        fail=$((fail+1))
        echo "FAIL shape=$shape msg=($a,$m) dir=$dir : $out"
      fi
    done
  done
done
echo "EMPTY-CASES pass=$pass fail=$fail"
