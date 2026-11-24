#!/bin/sh
# Build a retained scratch testbench with the canonical production RTL filelist.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY=$(dirname "$HERE")
RTL=$(CDPATH= cd -- "$VERIFY/../rtl" && pwd)
TOP=$1
NAME=$2
shift 2
case "$NAME" in ''|*[!a-zA-Z0-9_-]*) echo "Invalid run name: $NAME" >&2; exit 2;; esac
BENCH="$VERIFY/tests/legacy_tb/$TOP.sv"
test -f "$BENCH"
RUN="$VERIFY/sim/$NAME"
mkdir -p "$VERIFY/sim"
mkdir "$RUN"
cd "$RTL"
if ! "${VERILATOR:-verilator}" --binary --timing -j "${USB20_BUILD_JOBS:-1}" -f filelist.f     --top-module "$TOP" --Mdir "$RUN" "$BENCH" "$@" >"$RUN/build.log" 2>&1; then
    cat "$RUN/build.log" >&2
    exit 1
fi
