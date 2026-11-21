#!/bin/sh
# usage: build.sh TOP NAME "files..." [extra verilator args]  (builds verification/build/NAME)
# Scratch simulation build of the USB 2.0 controller blocks (Verilator, see memory recipe).
HERE=$(cd "$(dirname "$0")" && pwd)
RTL=$HERE/../rtl
LIB=$HERE/../..
TOP=$1; NAME=$2; FILES=$3; shift 3
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:/c/Users/PC/Tools/msys64/usr/bin:/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
export VERILATOR_ROOT=C:/Tools/oss-cad-suite/share/verilator
mkdir -p "$HERE/build" "$HERE/logs"
rm -rf "$HERE/build/$NAME"
cd "$RTL" || exit 1
verilator_bin.exe --binary --timing -Wno-fatal -Wno-lint -Wno-style -j 0 --top-module $TOP \
  --Mdir "$HERE/build/$NAME" \
  -MAKEFLAGS PYTHON3=C:/Users/PC/AppData/Local/Programs/Python/Python312/python.exe \
  -CFLAGS -D_GLIBCXX_USE_CXX11_ABI=0 \
  -y "$LIB/000_Common/rtl_lib" -y "$LIB/000_Common/rtl_cells" -y "$LIB/001_AsyncGrayFIFO/rtl" -y "$RTL" -y "$RTL/csr" \
  $FILES "$@" > "$HERE/logs/build_$NAME.log" 2>&1
grep -E "^%Error" "$HERE/logs/build_$NAME.log" | head -20
ls "$HERE/build/$NAME/V$TOP.exe" 2>&1 | tail -1
