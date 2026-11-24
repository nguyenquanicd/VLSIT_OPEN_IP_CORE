#!/bin/sh
# usage: build_run.sh TB_TOP "files" NAME [verilator args]
# Builds with Verilator --binary and the MSYS2 compiler (same recipe as verification/build.sh of this project) and runs the binary.
# The build folder is in the temporary folder, not in the project. Files are given with absolute paths or as names found in rtl/.
HERE=$(cd "$(dirname "$0")" && pwd)
RTL=$HERE/../../../rtl
LIB=$RTL/../..
TOP=$1; FILES=$2; NAME=$3; shift 3
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:/c/Users/PC/Tools/msys64/usr/bin:/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
export VERILATOR_ROOT=C:/Tools/oss-cad-suite/share/verilator
OUT=${REPRO_OUT:-/c/Users/PC/AppData/Local/Temp}/usb2_repro/$NAME
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$RTL" || exit 1
verilator_bin.exe --binary --timing -Wno-fatal -Wno-lint -Wno-style -j 0 --top-module $TOP --Mdir "$OUT" \
  -MAKEFLAGS PYTHON3=C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe -CFLAGS -D_GLIBCXX_USE_CXX11_ABI=0 \
  -y "$LIB/000_Common/rtl_lib" -y "$LIB/000_Common/rtl_cells" -y "$LIB/001_AsyncGrayFIFO/rtl" -y "$RTL" -y "$RTL/csr" \
  $FILES "$@" > "$OUT/build.log" 2>&1 || { grep -E "^%Error" "$OUT/build.log" | head -20; exit 1; }
"$OUT/V$TOP.exe"
