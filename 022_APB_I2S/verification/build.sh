#!/bin/sh
# usage: build.sh NAME [--syn] [--cov] [--wave] [--rtl=<folder>] [verilator args such as -GLINES=2]
# Builds tb_i2s with the design files of rtl/filelist.f; the testbench files are never in filelist.f. Run from any folder;
# the result is verification/build/NAME/Vtb_i2s.exe and the log verification/logs/build_NAME.log.
#   --syn   synthesis branch (+define+VLSIT_SYNTHESIS and the library cell models)
#   --cov   line and toggle coverage instrumentation (Verilator --coverage-line --coverage-toggle)
#   --wave  VCD tracing (Verilator --trace)
#   --rtl=  design folder with a filelist.f (default ../rtl; used for the injected-bug runs)
# The options are arguments, not environment variables: the msys shell of this machine drops unknown variables.
HERE=$(cd "$(dirname "$0")" && pwd)
RTL=$HERE/../rtl
NAME=$1; shift
SYN=0; COV=0; WAVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --syn) SYN=1; shift ;;
    --cov) COV=1; shift ;;
    --wave) WAVE=1; shift ;;
    --rtl=*) RTL=${1#--rtl=}; shift ;;
    *) break ;;
  esac
done
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:/c/Users/PC/Tools/msys64/usr/bin:/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
export VERILATOR_ROOT=C:/Tools/oss-cad-suite/share/verilator
# a background shell may have no temporary folder: g++ then cannot create its temporary files
mkdir -p "$HERE/build/tmp"
export TMP="$HERE/build/tmp" TEMP="$HERE/build/tmp" TMPDIR="$HERE/build/tmp"
mkdir -p "$HERE/build" "$HERE/logs"
rm -rf "$HERE/build/$NAME"
EXTRA=""
if [ "$SYN" = "1" ]; then
  EXTRA="$EXTRA +define+VLSIT_SYNTHESIS -y $HERE/../../000_Common/rtl_cells +libext+.sv"
fi
if [ "$COV" = "1" ]; then EXTRA="$EXTRA --coverage-line --coverage-toggle"; fi
if [ "$WAVE" = "1" ]; then EXTRA="$EXTRA --trace"; fi
cd "$RTL" || exit 1
verilator_bin.exe --binary --timing -Wno-fatal -Wno-lint -Wno-style -j 0 --top-module tb_i2s \
  --Mdir "$HERE/build/$NAME" \
  -MAKEFLAGS PYTHON3=C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe \
  -CFLAGS -D_GLIBCXX_USE_CXX11_ABI=0 $EXTRA \
  -f filelist.f -I"$HERE/tb" "$HERE/tb/i2s_apb_chk.sv" "$HERE/tb/i2s_dev.sv" "$HERE/tb/tb_i2s.sv" "$@" \
  > "$HERE/logs/build_$NAME.log" 2>&1
grep -E "^%Error" "$HERE/logs/build_$NAME.log" | head -20
ls "$HERE/build/$NAME/Vtb_i2s.exe" 2>&1 | tail -1
