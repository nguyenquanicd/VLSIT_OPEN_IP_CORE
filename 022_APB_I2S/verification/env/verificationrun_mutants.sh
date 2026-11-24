#!/bin/sh
# Injected-bug runs (R-088): builds the testbench against each copy of the RTL in mutants/ (tools/mutate.py make)
# and runs the suite once. A bug is caught when the run reports a failure or does not finish.
# usage: run_mutants.sh [ids...]   result table: logs/mutants.txt
HERE=$(cd "$(dirname "$0")" && pwd)
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:/c/Users/PC/Tools/msys64/usr/bin:/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
mkdir -p "$HERE/logs/mutants"
OUT="$HERE/logs/mutants.txt"
IDS="$*"
[ -z "$IDS" ] && IDS=$(ls "$HERE/mutants")
: > "$OUT"
for id in $IDS; do
  sh "$HERE/build.sh" "mut_$id" "--rtl=$HERE/mutants/$id/rtl" > "$HERE/logs/mutants/$id.build.txt" 2>&1
  EXE="$HERE/build/mut_$id/Vtb_i2s.exe"
  if [ ! -f "$EXE" ]; then echo "$id BUILD-FAILED" >> "$OUT"; continue; fi
  "$EXE" +TEST=ALL +SEED=1 +N=10 +AFIFO_MSYNC_SEED=1 +AFIFO_MSYNC_EN=1 +RSTSYNC_MSYNC_SEED=1 > "$HERE/logs/mutants/$id.log" 2>&1
  res=$(grep -E "^RESULT:" "$HERE/logs/mutants/$id.log" | tail -1)
  first=$(grep -m1 -E "CHECK FAIL|ASSERT FAIL" "$HERE/logs/mutants/$id.log" | cut -c1-150)
  echo "$id $res | $first" >> "$OUT"
  rm -rf "$HERE/build/mut_$id"
done
echo done >> "$OUT"
