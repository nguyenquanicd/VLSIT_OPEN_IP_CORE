#!/bin/sh
# Retained scratch regression. Each configuration writes to a distinct run directory.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY=$(dirname "$HERE")
TAG=${USB20_RUN_TAG:-$(date +%Y%m%d_%H%M%S)}
run() {
  top=$1
  run_id="legacy_${TAG}_$2"
  shift 2
  sh "$HERE/build_legacy.sh" "$top" "$run_id" "$@"
  dir="$VERIFY/sim/$run_id"
  exe="$dir/V$top"
  if [ ! -x "$exe" ]; then exe="$exe.exe"; fi
  (cd "$dir" && "$exe") > "$dir/sim.log" 2>&1
  grep -E 'TB_|FAIL|TIMEOUT' "$dir/sim.log" || :
}
for w in 8 16; do run tb_lnk_loop lnk$w -GW=$w; done
for c in "8 0" "16 0" "8 1" "16 1"; do set -- $c; run tb_fifo fifo$1$2 -GW=$1 -GP1=$2; done
run tb_dev_utmi dev_utmi -GPIPE=0
run tb_dev_utmi dev_utmi_pipe -GPIPE=1
run tb_dev_utmi16 dev_utmi16
run tb_dev_ulpi dev_ulpi
run tb_dev_axis dev_axis
run tb_host_utmi host_utmi
run tb_dev_chirp dev_chirp
run tb_dev_feat dev_feat
run tb_dev_hbiso dev_hbiso
run tb_host_feat host_feat
run tb_dev_sg dev_sg -GPIPE=0
run tb_host_split host_split
run tb_host16 host16
run tb_host_iso host_iso
run tb_host_ulpi host_ulpi
run tb_dev_ulpi_lp dev_ulpi_lp
run tb_host_flags host_flags
run tb_dev_sg64 dev_sg64
run tb_dev_nyet dev_nyet
run tb_host_sg host_sg
run tb_dev_feat dev_feat_p1 -GPIPE=1
run tb_dev_hbiso dev_hbiso_p1 -GPIPE=1
run tb_dev_chirp dev_chirp_p1 -GPIPE=1
run tb_dev_sg dev_sg_p1 -GPIPE=1
run tb_dev_nyet dev_nyet_p1 -GPIPE=1
run tb_dev_axis dev_axis_p1 -GPIPE=1
