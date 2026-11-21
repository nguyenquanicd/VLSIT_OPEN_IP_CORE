#!/bin/sh
# Full regression of the APB I2S testbench. usage: regress.sh [quick]
#   cdc    : synthesis branch + metastability model with seeds 1, 2, 3 (logs/cdc/)
#   matrix : build configurations of the design parameters (logs/matrix/)
# Every log ends with "assertion failures: N, assertions never exercised: M" and is labelled SIM-BRANCH.
HERE=$(cd "$(dirname "$0")" && pwd)
SH="sh"
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:/c/Users/PC/Tools/msys64/usr/bin:/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
mkdir -p "$HERE/logs/cdc" "$HERE/logs/matrix"
SUM="$HERE/logs/summary.txt"
: > "$SUM"
N=${N:-20}
run_one() {   # name logfile seed extra-plusargs
  "$HERE/build/$1/Vtb_i2s.exe" +TEST=ALL +SEED=$3 +N=$N $4 > "$2" 2>&1
  res=$(grep -E "^RESULT:" "$2" | tail -1)
  fails=$(grep -E "^assertion failures:" "$2" | tail -1)
  echo "$1 seed=$3 $4 : $res | $fails" >> "$SUM"
}
# ---- CDC branches of the full build
$SH "$HERE/build.sh" full
for s in 1 2 3; do
  run_one full "$HERE/logs/cdc/metastable_seed$s.log" $s "+AFIFO_MSYNC_SEED=$s +AFIFO_MSYNC_EN=1 +RSTSYNC_MSYNC_SEED=$s"
done
$SH "$HERE/build.sh" full_syn --syn
run_one full_syn "$HERE/logs/cdc/synthesis.log" 1 ""
[ "$1" = "quick" ] && exit 0
# ---- configuration matrix
cfg() {   # name args...
  nm=$1; shift
  $SH "$HERE/build.sh" "$nm" "$@"
  run_one "$nm" "$HERE/logs/matrix/${nm}_seed1.log" 1 "+AFIFO_MSYNC_SEED=1 +AFIFO_MSYNC_EN=1 +RSTSYNC_MSYNC_SEED=1"
}
cfg lines2  -GLINES=2 -GDEPTH=8
cfg dual    -GLINES=4 -GDEPTH=64
cfg mic     -GTX_EN=0 -GLINES=4 -GDEPTH=32 -GMASTER_EN=0 -GONDEM_EN=0
cfg min     -GFMT_EXT_EN=0 -GMAX_SLOTS=2 -GPACK_EN=0 -GMASTER_EN=0 -GONDEM_EN=0 -GTRI_EN=0 -GHUNG_EN=0 -GDMA_EN=0 -GDEPTH=4
cfg rxonly  -GTX_EN=0
cfg txonly  -GRX_EN=0
cfg sync3   -GSYNC_DEPTH=3
echo "done" >> "$SUM"
