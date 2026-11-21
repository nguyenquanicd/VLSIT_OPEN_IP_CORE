#!/bin/sh
# Scratch regression of the USB 2.0 controller blocks (Verilator, see build.sh). Prints one summary line per test.
HERE=$(cd "$(dirname "$0")" && pwd)
export PATH="/c/Users/PC/Tools/msys64/ucrt64/bin:$PATH"
cd "$HERE"
RTLF=$(cd ../rtl && ls m_usb2_*.sv | tr '\n' ' ')
ALL="$RTLF csr/m_vlsit_csr_usb2.sv csr/m_vlsit_csr_sync.sv"
run() { # top name files extra...
  top=$1; name=$2; files=$3; shift 3
  ./build.sh $top $name "$files" "$@" > /dev/null 2>&1
  ./build/$name/V$top.exe 2>&1 | grep -E "TB_|FAIL|TIMEOUT" | head -3
}
for w in 8 16; do run tb_lnk_loop lnk$w "m_usb2_crc5.sv m_usb2_crc16.sv m_usb2_lnktx.sv m_usb2_lnkrx.sv $HERE/tb/tb_lnk_loop.sv" -GW=$w; done
for c in "8 0" "16 0" "8 1" "16 1"; do set -- $c; run tb_fifo fifo$1$2 "m_usb2_fifo.sv $HERE/tb/tb_fifo.sv" -GW=$1 -GP1=$2; done
run tb_dev_utmi dev_utmi "$ALL $HERE/tb/tb_dev_utmi.sv" -GPIPE=0
run tb_dev_utmi dev_utmi_pipe "$ALL $HERE/tb/tb_dev_utmi.sv" -GPIPE=1
run tb_dev_utmi16 dev_utmi16 "$ALL $HERE/tb/tb_dev_utmi16.sv"
run tb_dev_ulpi dev_ulpi "$ALL $HERE/tb/tb_dev_ulpi.sv"
run tb_dev_axis dev_axis "$ALL $HERE/tb/tb_dev_axis.sv"
run tb_host_utmi host_utmi "$ALL $HERE/tb/tb_host_utmi.sv"
run tb_dev_chirp dev_chirp "$ALL $HERE/tb/tb_dev_chirp.sv"
run tb_dev_feat dev_feat "$ALL $HERE/tb/tb_dev_feat.sv"
run tb_dev_hbiso dev_hbiso "$ALL $HERE/tb/tb_dev_hbiso.sv"
run tb_host_feat host_feat "$ALL $HERE/tb/tb_host_feat.sv"
run tb_dev_sg dev_sg "$ALL $HERE/tb/tb_dev_sg.sv" -GPIPE=0
run tb_host_split host_split "$ALL $HERE/tb/tb_host_split.sv"
run tb_host16 host16 "$ALL $HERE/tb/tb_host16.sv"
run tb_host_iso host_iso "$ALL $HERE/tb/tb_host_iso.sv"
run tb_host_ulpi host_ulpi "$ALL $HERE/tb/tb_host_ulpi.sv"
run tb_dev_ulpi_lp dev_ulpi_lp "$ALL $HERE/tb/tb_dev_ulpi_lp.sv"
run tb_host_flags host_flags "$ALL $HERE/tb/tb_host_flags.sv"
run tb_dev_sg64 dev_sg64 "$ALL $HERE/tb/tb_dev_sg64.sv"
run tb_dev_nyet dev_nyet "$ALL $HERE/tb/tb_dev_nyet.sv"
run tb_host_sg host_sg "$ALL $HERE/tb/tb_host_sg.sv"
run tb_dev_feat dev_feat_p1 "$ALL $HERE/tb/tb_dev_feat.sv" -GPIPE=1
run tb_dev_hbiso dev_hbiso_p1 "$ALL $HERE/tb/tb_dev_hbiso.sv" -GPIPE=1
run tb_dev_chirp dev_chirp_p1 "$ALL $HERE/tb/tb_dev_chirp.sv" -GPIPE=1
run tb_dev_sg dev_sg_p1 "$ALL $HERE/tb/tb_dev_sg.sv" -GPIPE=1
run tb_dev_nyet dev_nyet_p1 "$ALL $HERE/tb/tb_dev_nyet.sv" -GPIPE=1
run tb_dev_axis dev_axis_p1 "$ALL $HERE/tb/tb_dev_axis.sv" -GPIPE=1
